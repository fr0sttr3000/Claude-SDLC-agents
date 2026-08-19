#!/usr/bin/env bash
# Shared fail-closed path boundary for primary and worker dispatchers.

RUNTIME_BOUNDARY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SDLC_SYSTEM_ROOT="$(cd "$RUNTIME_BOUNDARY_DIR/.." && pwd -P)"
RUNTIME_LANDLOCK_SOURCE="$RUNTIME_BOUNDARY_DIR/cycle-landlock.c"
RUNTIME_LANDLOCK_BIN=""
RUNTIME_SESSION_DIR=""
declare -a RUNTIME_DENY_PATHS=()

runtime_boundary_fail() {
  echo "runtime boundary: $*" >&2
  return 2
}

runtime_prompt_has_secret_like() {
  local value="${1:-}" lower
  lower="${value,,}"
  [[ "$lower" =~ akia[0-9a-z]{8,} ]] ||
    [[ "$lower" =~ gh[pousr]_[a-z0-9]{8,} ]] ||
    [[ "$lower" =~ (^|[^a-z0-9])sk-[a-z0-9]{8,} ]] ||
    [[ "$lower" =~ (password|passwd|token|api[_-]?key|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]+ ]]
}

runtime_validate_prompt() {
  local value="${1:-}"
  if runtime_prompt_has_secret_like "$value"; then
    echo 'runtime boundary: prompt contains a secret-like value; use a pass reference instead' >&2
    return 2
  fi
}

resolve_existing_directory() {
  local label="$1" candidate="${2:-}"
  if [[ -z "$candidate" || ! -d "$candidate" ]]; then
    runtime_boundary_fail "$label must point to an existing directory"
    return 2
  fi
  (cd "$candidate" 2>/dev/null && pwd -P) || {
    runtime_boundary_fail "$label could not be resolved"
    return 2
  }
}

resolve_active_agent_dir() {
  local candidate="${1:-}" canonical parent
  canonical="$(resolve_existing_directory --agent-dir "$candidate")" || return 2
  parent="$(dirname "$canonical")"

  if [[ "$parent" != "$SDLC_SYSTEM_ROOT/cycle1-dev" &&
        "$parent" != "$SDLC_SYSTEM_ROOT/_tools" ]]; then
    runtime_boundary_fail \
      "FROZEN / NOT READY: dispatch is limited to canonical Cycle 1 and _tools agent directories"
    return 2
  fi
  if [[ ! -f "$canonical/CLAUDE.md" ]]; then
    runtime_boundary_fail "active agent directory has no canonical CLAUDE.md: $canonical"
    return 2
  fi
  printf '%s\n' "$canonical"
}

resolve_write_scope() {
  local option="$1" candidate="${2:-}" canonical canonical_home=""
  canonical="$(resolve_existing_directory "$option" "$candidate")" || return 2
  if [[ -n "${HOME:-}" ]]; then
    canonical_home="$(resolve_existing_directory HOME "$HOME")" || return 2
  fi
  if [[ "$canonical" == / ||
        ( -n "$canonical_home" && "$canonical" == "$canonical_home" ) ]]; then
    runtime_boundary_fail "$option must be a bounded directory, not filesystem root or HOME"
    return 2
  fi
  if [[ "$canonical" == "$SDLC_SYSTEM_ROOT" || "$canonical" == "$SDLC_SYSTEM_ROOT/"* ]]; then
    runtime_boundary_fail "$option must be outside the SDLC agent system"
    return 2
  fi
  printf '%s\n' "$canonical"
}

runtime_prepare_cycle_sandbox() {
  local temporary_parent target

  if [[ "$(uname -s)" != Linux ]]; then
    runtime_boundary_fail \
      "cycle runtime requires Linux Landlock; this platform is not supported"
    return 2
  fi
  [[ -r "$RUNTIME_LANDLOCK_SOURCE" ]] || {
    runtime_boundary_fail "missing Landlock source: $RUNTIME_LANDLOCK_SOURCE"
    return 2
  }
  command -v cc >/dev/null 2>&1 || {
    runtime_boundary_fail "cycle runtime requires a C compiler (cc) to build its Landlock boundary"
    return 2
  }
  temporary_parent="${TMPDIR:-/tmp}"
  [[ -d "$temporary_parent" ]] || {
    runtime_boundary_fail "TMPDIR must point to an existing directory"
    return 2
  }
  RUNTIME_SESSION_DIR="$(mktemp -d "$temporary_parent/sdlc-agent-runtime.XXXXXX")" || {
    runtime_boundary_fail "cannot create isolated runtime directory"
    return 2
  }
  chmod 700 "$RUNTIME_SESSION_DIR" || {
    runtime_cleanup_cycle_sandbox
    runtime_boundary_fail "cannot protect isolated runtime directory"
    return 2
  }
  mkdir -p "$RUNTIME_SESSION_DIR/home" "$RUNTIME_SESSION_DIR/tmp" || {
    runtime_cleanup_cycle_sandbox
    runtime_boundary_fail "cannot prepare isolated runtime HOME/TMPDIR"
    return 2
  }
  target="$RUNTIME_SESSION_DIR/cycle-landlock"
  if ! cc -O2 -std=c11 -Wall -Wextra -Werror \
    "$RUNTIME_LANDLOCK_SOURCE" -o "$target"; then
    runtime_cleanup_cycle_sandbox
    runtime_boundary_fail "cannot compile Landlock boundary"
    return 2
  fi
  RUNTIME_LANDLOCK_BIN="$target"
  printf '%s\n' "$target"
}

runtime_cleanup_cycle_sandbox() {
  local candidate="${RUNTIME_SESSION_DIR:-}"

  [[ -n "$candidate" ]] || return 0
  if [[ ! "$candidate" =~ /sdlc-agent-runtime\.[A-Za-z0-9]+$ ||
        "$candidate" == / || ! -d "$candidate" ]]; then
    runtime_boundary_fail "refusing to remove an invalid runtime directory"
    return 2
  fi
  rm -rf -- "$candidate"
  RUNTIME_SESSION_DIR=""
  RUNTIME_LANDLOCK_BIN=""
}

runtime_same_inode() {
  local first="$1" second="$2"
  [[ "$(stat -Lc '%d:%i' "$first")" == "$(stat -Lc '%d:%i' "$second")" ]]
}

runtime_add_cycle_deny() {
  local candidate="$1" label="$2" canonical existing

  canonical="$(realpath -e -- "$candidate")" || {
    runtime_boundary_fail "cannot resolve $label"
    return 2
  }
  [[ "$canonical" != / && "$canonical" != "${HOME:-}" ]] || {
    runtime_boundary_fail "$label is too broad"
    return 2
  }
  for existing in "${RUNTIME_DENY_PATHS[@]}"; do
    [[ "$existing" != "$canonical" ]] || return 0
  done
  RUNTIME_DENY_PATHS+=("$canonical")
}

runtime_load_cycle_denies() {
  local configured git_path

  RUNTIME_DENY_PATHS=()
  if [[ -e "$SDLC_SYSTEM_ROOT/.git" || -L "$SDLC_SYSTEM_ROOT/.git" ]]; then
    command -v git >/dev/null 2>&1 || {
      runtime_boundary_fail "git is required to load local runtime deny paths"
      return 2
    }
    runtime_add_cycle_deny "$SDLC_SYSTEM_ROOT/.git" "agent-system Git entry" || return 2
    git_path="$(git -C "$SDLC_SYSTEM_ROOT" rev-parse --absolute-git-dir 2>/dev/null)" || {
      runtime_boundary_fail "cannot resolve agent-system Git directory"
      return 2
    }
    runtime_add_cycle_deny "$git_path" "agent-system Git directory" || return 2
    git_path="$(git -C "$SDLC_SYSTEM_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
      runtime_boundary_fail "cannot resolve agent-system common Git directory"
      return 2
    }
    runtime_add_cycle_deny "$git_path" "agent-system common Git directory" || return 2

    while IFS= read -r configured; do
      [[ -n "$configured" ]] || continue
      runtime_add_cycle_deny "$configured" "configured runtime deny path" || return 2
    done < <(
      git -C "$SDLC_SYSTEM_ROOT" config --local --path --get-all \
        sdlc.runtimeDenyPath 2>/dev/null || true
    )
  fi
  (("${#RUNTIME_DENY_PATHS[@]}" > 0)) || {
    runtime_boundary_fail "no capability-enforced runtime deny path is available"
    return 2
  }
}

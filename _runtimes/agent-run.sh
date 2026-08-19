#!/usr/bin/env bash
# Universal SDLC agent runtime dispatcher.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/runtime-boundary.sh"
RUNTIME="${AGENT_RUNTIME:-}"
MODE="task"
ACCESS="write"
AGENT_DIR_VALUE=""
PROJECT_DIR_VALUE=""
NOTES_DIR_VALUE=""
PROMPT=""
LOCAL_HOST_REGISTRY="${LOCAL_HOST_REGISTRY:-$SCRIPT_DIR/local-hosts}"
LOCAL_HOST_PATH=""
RUNTIME_BIN_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      RUNTIME="${2:-}"
      shift 2
      ;;
    --agent-dir)
      AGENT_DIR_VALUE="${2:-}"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR_VALUE="${2:-}"
      shift 2
      ;;
    --notes-dir)
      NOTES_DIR_VALUE="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --access)
      ACCESS="${2:-}"
      shift 2
      ;;
    --prompt)
      PROMPT="${2:-}"
      shift 2
      ;;
    --)
      shift
      PROMPT="${*:-$PROMPT}"
      break
      ;;
    --*)
      echo "agent-run.sh: unknown option '$1'" >&2
      exit 2
      ;;
    *)
      PROMPT="${PROMPT}${PROMPT:+ }$1"
      shift
      ;;
  esac
done

runtime_validate_prompt "$PROMPT" || exit 2

if [[ -z "$AGENT_DIR_VALUE" ]]; then
  echo "agent-run.sh: --agent-dir is required" >&2
  exit 2
fi
AGENT_DIR_VALUE="$(resolve_active_agent_dir "$AGENT_DIR_VALUE")" || exit 2
if [[ -z "$PROJECT_DIR_VALUE" ]]; then
  echo "agent-run.sh: --project-dir is required for every primary execution" >&2
  exit 2
fi
PROJECT_DIR_VALUE="$(resolve_write_scope --project-dir "$PROJECT_DIR_VALUE")" || exit 2
SDLC_VAULT_VALUE="$(cd "$SDLC_SYSTEM_ROOT/.." && pwd -P)"
SDLC_PROJECTS_DIR_VALUE="$(dirname "$PROJECT_DIR_VALUE")"
SDLC_PROJECTS_MODE_VALUE="${SDLC_PROJECTS_MODE:-collection}"
case "$SDLC_PROJECTS_MODE_VALUE" in collection|single) ;; *) echo "agent-run.sh: SDLC_PROJECTS_MODE must be collection or single" >&2; exit 2 ;; esac
SDLC_SINGLE_PROJECT_VALUE="${SDLC_SINGLE_PROJECT:-}"
if [[ "$SDLC_PROJECTS_MODE_VALUE" == single ]]; then
  [[ -n "$SDLC_SINGLE_PROJECT_VALUE" ]] || SDLC_SINGLE_PROJECT_VALUE="$(basename "$PROJECT_DIR_VALUE")"
  [[ "$SDLC_SINGLE_PROJECT_VALUE" == "$(basename "$PROJECT_DIR_VALUE")" ]] || { echo "agent-run.sh: SDLC_SINGLE_PROJECT does not match --project-dir" >&2; exit 2; }
fi
if [[ -n "$NOTES_DIR_VALUE" ]]; then
  NOTES_DIR_VALUE="$(resolve_write_scope --notes-dir "$NOTES_DIR_VALUE")" || exit 2
fi

normalize_runtime() {
  local runtime="${1:-}"
  if [[ -z "$runtime" ]]; then
    echo "agent-run.sh: runtime is required (expected: claude, codex, gemini, local)" >&2
    exit 2
  fi
  runtime="${runtime,,}"
  case "$runtime" in
    claude|codex|gemini|local)
      echo "$runtime"
      ;;
    *)
      echo "agent-run.sh: unknown runtime '$1' (expected: claude, codex, gemini, local)" >&2
      exit 2
      ;;
  esac
}

runtime_bin() {
  case "$RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
    local) echo "$LOCAL_HOST_PATH" ;;
  esac
}

validate_scalar() {
  local name="$1" value="${2:-}"
  if [[ -z "$value" || "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    echo "agent-run.sh: $name must be an explicit single-line value" >&2
    exit 2
  fi
}

resolve_local_host() {
  local host="${LOCAL_AGENT_HOST:-}" candidate
  validate_scalar LOCAL_AGENT_HOST "$host"
  validate_scalar LOCAL_MODEL_PROVIDER "${LOCAL_MODEL_PROVIDER:-}"
  validate_scalar LOCAL_MODEL "${LOCAL_MODEL:-}"
  if [[ ! "$host" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "agent-run.sh: invalid LOCAL_AGENT_HOST id '$host'" >&2
    exit 2
  fi
  candidate="$LOCAL_HOST_REGISTRY/$host"
  if [[ ! -f "$candidate" || ! -x "$candidate" ]]; then
    echo "agent-run.sh: local agent host '$host' is not registered and executable in $LOCAL_HOST_REGISTRY" >&2
    exit 127
  fi
  LOCAL_HOST_PATH="$candidate"
}

ensure_runtime_available() {
  local bin resolved canonical_home=""
  if [[ "$RUNTIME" == "local" ]]; then
    resolve_local_host
    bin="$LOCAL_HOST_PATH"
  else
    bin="$(runtime_bin)"
    if ! command -v "$bin" >/dev/null 2>&1; then
      echo "agent-run.sh: runtime '$RUNTIME' requires command '$bin', but it was not found in PATH" >&2
      echo "agent-run.sh: select another explicit runtime or override ${RUNTIME^^}_BIN" >&2
      exit 127
    fi
    resolved="$(command -v "$bin")"
    bin="$resolved"
  fi
  RUNTIME_BIN_PATH="$(realpath -e -- "$bin")" || {
    echo "agent-run.sh: runtime executable could not be resolved: $bin" >&2
    exit 127
  }
  if [[ -n "${HOME:-}" ]]; then
    canonical_home="$(resolve_existing_directory HOME "$HOME")" || exit 2
  fi
  if [[ -n "$canonical_home" &&
        "$RUNTIME_BIN_PATH" == "$canonical_home/"* &&
        "$RUNTIME_BIN_PATH" != "$SDLC_SYSTEM_ROOT/"* ]]; then
    echo 'agent-run.sh: BLOCKED: runtime executable is inside ambient HOME and cannot satisfy the capability matrix' >&2
    exit 2
  fi
}

RUNTIME="$(normalize_runtime "$RUNTIME")"
case "$ACCESS" in
  write|read-only) ;;
  *) echo "agent-run.sh: --access must be write or read-only" >&2; exit 2 ;;
esac
case "$MODE" in
  task|session-start|interactive) ;;
  continue)
    echo 'agent-run.sh: unbound continue is disabled; resume from the Execution Journal with a new isolated launch' >&2
    exit 2
    ;;
  *) echo "agent-run.sh: unsupported mode: $MODE" >&2; exit 2 ;;
esac
if [[ "$ACCESS" == read-only && "$MODE" != task ]]; then
  echo 'agent-run.sh: read-only access supports task mode only' >&2
  exit 2
fi

configure_subagents() {
  local policy="${SDLC_SUBAGENTS:-off}" max="${SDLC_SUBAGENT_MAX:-2}"
  policy="${policy,,}"
  case "$policy" in
    off|auto|cross-runtime) ;;
    *)
      echo "agent-run.sh: SDLC_SUBAGENTS must be off, auto or cross-runtime" >&2
      exit 2
      ;;
  esac
  if [[ ! "$max" =~ ^[1-9][0-9]*$ ]] || (( 10#$max < 1 || 10#$max > 16 )); then
    echo "agent-run.sh: SDLC_SUBAGENT_MAX must be an integer from 1 to 16" >&2
    exit 2
  fi
  SDLC_SUBAGENTS="$policy"
  SDLC_SUBAGENT_MAX="$max"
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX
  if [[ "$policy" != off ]]; then
    echo 'agent-run.sh: BLOCKED: worker execution is disabled until a capability-enforced bounded read scope exists' >&2
    exit 2
  fi
}

configure_subagents
ensure_runtime_available

case "$RUNTIME:${LOCAL_AGENT_HOST:-}" in
  codex:*|local:codex-oss)
    if [[ "$MODE" != task ]]; then
      echo 'agent-run.sh: BLOCKED: interactive Codex cannot disable ambient user configuration; use a registered command in task mode' >&2
      exit 2
    fi
    ;;
esac

runtime_prepare_cycle_sandbox >/dev/null || exit 2
CYCLE_SANDBOX_BIN="$RUNTIME_LANDLOCK_BIN"
trap 'runtime_cleanup_cycle_sandbox' EXIT
runtime_load_cycle_denies || exit 2
for runtime_deny_path in "${RUNTIME_DENY_PATHS[@]}"; do
  if [[ "$PROJECT_DIR_VALUE" == "$runtime_deny_path" ||
        "$PROJECT_DIR_VALUE" == "$runtime_deny_path/"* ||
        "$NOTES_DIR_VALUE" == "$runtime_deny_path" ||
        "$NOTES_DIR_VALUE" == "$runtime_deny_path/"* ]] ||
      runtime_same_inode "$PROJECT_DIR_VALUE" "$runtime_deny_path" ||
      { [[ -n "$NOTES_DIR_VALUE" ]] &&
        runtime_same_inode "$NOTES_DIR_VALUE" "$runtime_deny_path"; }; then
    echo 'agent-run.sh: project/notes scope intersects a runtime-denied path' >&2
    exit 2
  fi
done

PROMPT="SDLC CANONICAL CONTEXT
Global instructions: $SDLC_SYSTEM_ROOT/CLAUDE.md
Role instructions: $AGENT_DIR_VALUE/CLAUDE.md
Mandatory standards: $SDLC_SYSTEM_ROOT/_standards/
The canonical agent system is read-only during this launch. Work only in the exact project and optional notes scopes supplied by the launcher.

$PROMPT"

run_sanitized() {
  local -a cycle_boundary=("$CYCLE_SANDBOX_BIN")
  local -a clean_env=(
    env -i
    "HOME=$RUNTIME_SESSION_DIR/home"
    "PATH=${PATH:-/usr/bin:/bin}"
    "TMPDIR=$RUNTIME_SESSION_DIR/tmp"
    "LANG=${LANG:-C.UTF-8}"
    "TERM=${TERM:-dumb}"
    "AGENT_RUNTIME=$RUNTIME"
    "AGENT_DIR=$AGENT_DIR_VALUE"
    "SDLC_VAULT=$SDLC_VAULT_VALUE"
    "SDLC_PROJECTS_DIR=$SDLC_PROJECTS_DIR_VALUE"
    "SDLC_PROJECTS_MODE=$SDLC_PROJECTS_MODE_VALUE"
    "SDLC_SINGLE_PROJECT=$SDLC_SINGLE_PROJECT_VALUE"
    "SDLC_PROJECT_DIR=$PROJECT_DIR_VALUE"
    "SDLC_NOTES_DIR=$NOTES_DIR_VALUE"
    "SDLC_EXECUTION_RUN_ID=${SDLC_EXECUTION_RUN_ID:-}"
    "SDLC_EXECUTION_PLAN_SHA256=${SDLC_EXECUTION_PLAN_SHA256:-}"
    "SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256=${SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256:-}"
    "SDLC_SUBAGENTS=off"
    "SDLC_SUBAGENT_MAX=$SDLC_SUBAGENT_MAX"
    "LOCAL_AGENT_HOST=${LOCAL_AGENT_HOST:-}"
    "LOCAL_MODEL_PROVIDER=${LOCAL_MODEL_PROVIDER:-}"
    "LOCAL_MODEL=${LOCAL_MODEL:-}"
    "LOCAL_MODEL_ENDPOINT=${LOCAL_MODEL_ENDPOINT:-}"
    "LOCAL_HOST_REGISTRY=$LOCAL_HOST_REGISTRY"
    "LOCAL_CODEX_BIN=${LOCAL_CODEX_BIN:-codex}"
  )
  for runtime_read_root in /usr /bin /lib /lib64 /etc /proc /sys; do
    [[ -e "$runtime_read_root" ]] && cycle_boundary+=(--read "$runtime_read_root")
  done
  [[ -e /dev/null ]] && cycle_boundary+=(--write /dev/null)
  cycle_boundary+=(--read "$SDLC_SYSTEM_ROOT")
  cycle_boundary+=(--read "$RUNTIME_BIN_PATH")
  cycle_boundary+=(--write "$RUNTIME_SESSION_DIR")
  if [[ "$ACCESS" == write ]]; then
    cycle_boundary+=(--write "$PROJECT_DIR_VALUE")
    [[ -n "$NOTES_DIR_VALUE" ]] && cycle_boundary+=(--write "$NOTES_DIR_VALUE")
  else
    cycle_boundary+=(--read "$PROJECT_DIR_VALUE")
    [[ -n "$NOTES_DIR_VALUE" ]] && cycle_boundary+=(--read "$NOTES_DIR_VALUE")
  fi
  for runtime_deny_path in "${RUNTIME_DENY_PATHS[@]}"; do
    cycle_boundary+=(--deny "$runtime_deny_path")
  done
  cycle_boundary+=(--)
  [[ -n "${LC_ALL:-}" ]] && clean_env+=("LC_ALL=$LC_ALL")
  "${clean_env[@]}" "${cycle_boundary[@]}" "$@"
}

run_claude() {
  local bin="$RUNTIME_BIN_PATH"
  local -a scope_args=()
  [[ -n "$NOTES_DIR_VALUE" ]] && scope_args+=(--add-dir "$NOTES_DIR_VALUE")
  case "$MODE" in
    task)
      if [[ "$ACCESS" == read-only ]]; then
        run_sanitized "$bin" --print --permission-mode dontAsk --tools Read,Glob,Grep \
          "${scope_args[@]}" \
          --no-session-persistence "$PROMPT"
      else
        run_sanitized "$bin" --print "${scope_args[@]}" --no-session-persistence "$PROMPT"
      fi
      ;;
    session-start)
      run_sanitized "$bin" "${scope_args[@]}" "$PROMPT"
      ;;
    interactive)
      if [[ -n "$PROMPT" ]]; then
        run_sanitized "$bin" "${scope_args[@]}" "$PROMPT"
      else
        run_sanitized "$bin" "${scope_args[@]}"
      fi
      ;;
    *)
      echo "agent-run.sh: unsupported mode for claude: $MODE" >&2
      exit 2
      ;;
  esac
}

run_codex() {
  local bin="$RUNTIME_BIN_PATH"
  local -a scope_args=(--cd "$PROJECT_DIR_VALUE")
  [[ -n "$NOTES_DIR_VALUE" ]] && scope_args+=(--add-dir "$NOTES_DIR_VALUE")
  case "$MODE" in
    task)
      if [[ "$ACCESS" == read-only ]]; then
        run_sanitized "$bin" exec --ignore-user-config --sandbox read-only --ephemeral \
          "${scope_args[@]}" "$PROMPT"
      else
        run_sanitized "$bin" exec --ignore-user-config --sandbox workspace-write --ephemeral \
          "${scope_args[@]}" "$PROMPT"
      fi
      ;;
    session-start|interactive)
      echo 'agent-run.sh: BLOCKED: interactive Codex cannot disable ambient user configuration; use a registered command in task mode' >&2
      exit 2
      ;;
    *)
      echo "agent-run.sh: unsupported mode for codex: $MODE" >&2
      exit 2
      ;;
  esac
}

run_gemini() {
  local bin="$RUNTIME_BIN_PATH"
  if [[ "$ACCESS" == read-only ]]; then
    echo 'agent-run.sh: Gemini read-only worker adapter is not capability-enforced; refusing execution' >&2
    exit 2
  fi
  case "$MODE" in
    task|session-start)
      run_sanitized "$bin" -p "$PROMPT"
      ;;
    interactive)
      if [[ -n "$PROMPT" ]]; then
        run_sanitized "$bin" -p "$PROMPT"
      else
        run_sanitized "$bin"
      fi
      ;;
    *)
      echo "agent-run.sh: unsupported mode for gemini: $MODE" >&2
      exit 2
      ;;
  esac
}

run_local() {
  if [[ "$ACCESS" == read-only && "${LOCAL_AGENT_HOST:-}" != codex-oss ]]; then
    echo "agent-run.sh: local host '${LOCAL_AGENT_HOST:-}' has no registered read-only capability" >&2
    exit 2
  fi
  local -a scope_args=(--project-dir "$PROJECT_DIR_VALUE")
  [[ -n "$NOTES_DIR_VALUE" ]] && scope_args+=(--notes-dir "$NOTES_DIR_VALUE")
  run_sanitized "$RUNTIME_BIN_PATH" \
    --agent-dir "$AGENT_DIR_VALUE" \
    "${scope_args[@]}" \
    --mode "$MODE" \
    --access "$ACCESS" \
    --prompt "$PROMPT"
}

cd "$PROJECT_DIR_VALUE"

case "$RUNTIME" in
  claude)
    run_claude
    ;;
  codex)
    run_codex
    ;;
  gemini)
    run_gemini
    ;;
  local)
    run_local
    ;;
esac

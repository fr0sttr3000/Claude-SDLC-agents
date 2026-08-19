#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-launcher-scopes.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_arg_pair() {
  local file="$1" flag="$2" value="$3"
  awk -v first="ARG=$flag" -v second="ARG=$value" '
    previous == first && $0 == second { found = 1 }
    { previous = $0 }
    END { exit(found ? 0 : 1) }
  ' "$file" || fail "missing adjacent launcher arguments: $flag $value"
}

FAKE_RUNNER="$TMP_DIR/fake-runner"
cat > "$FAKE_RUNNER" <<'FAKE'
#!/usr/bin/env bash
printf 'ARG=%s\n' "$@" > "$LAUNCHER_SCOPE_CAPTURE"
FAKE
chmod +x "$FAKE_RUNNER"

SDLC_PROJECTS="$TMP_DIR/sdlc-projects"
mkdir -p "$SDLC_PROJECTS/Alpha"
SDLC_CAPTURE="$TMP_DIR/sdlc.capture"

XDG_CONFIG_HOME="$TMP_DIR/sdlc-config" \
AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single \
SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2 LAUNCHER_SCOPE_CAPTURE="$SDLC_CAPTURE" \
bash -c '
  set -euo pipefail
  source "$1"
  PROJECTS="$2"
  PROJECT=Alpha
  BASE_PROFILE="codex||||"
  ACTIVE_EXECUTION_PROFILE="$BASE_PROFILE"
  AGENT_RUNNER="$3"
  run_agent s1-pm Alpha /vision <<< "" >/dev/null
' _ "$ROOT/sdlc.sh" "$SDLC_PROJECTS" "$FAKE_RUNNER"

assert_arg_pair "$SDLC_CAPTURE" '--agent-dir' "$ROOT/cycle1-dev/s1-pm"
assert_arg_pair "$SDLC_CAPTURE" '--project-dir' "$SDLC_PROJECTS/Alpha"
assert_arg_pair "$SDLC_CAPTURE" '--mode' 'task'
if grep -Fq 'ARG=--notes-dir' "$SDLC_CAPTURE"; then
  fail 'main launcher passed an unexpected notes scope'
fi

rm -f "$SDLC_CAPTURE"
if env XDG_CONFIG_HOME="$TMP_DIR/sdlc-interactive-config" AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2 LAUNCHER_SCOPE_CAPTURE="$SDLC_CAPTURE" bash -c '
    source "$1"
    PROJECTS="$2"
    PROJECT=Alpha
    BASE_PROFILE="codex||||"
    ACTIVE_EXECUTION_PROFILE="$BASE_PROFILE"
    AGENT_RUNNER="$3"
    run_agent s1-pm Alpha "" <<< "i"
  ' _ "$ROOT/sdlc.sh" "$SDLC_PROJECTS" "$FAKE_RUNNER" >"$TMP_DIR/sdlc-interactive.out" 2>&1; then
  fail 'main launcher accepted interactive Codex'
fi
grep -Fq 'BLOCKED: interactive Codex cannot disable ambient user configuration' "$TMP_DIR/sdlc-interactive.out" ||
  fail 'main launcher did not explain task-only Codex'
[[ ! -e "$SDLC_CAPTURE" ]] || fail 'main launcher invoked runner for blocked interactive Codex'

LOCAL_PROJECTS="$TMP_DIR/local-projects"
LOCAL_NOTES="$TMP_DIR/local-notes"
mkdir -p "$LOCAL_PROJECTS/Repo"
LOCAL_CAPTURE="$TMP_DIR/localrun.capture"

XDG_CONFIG_HOME="$TMP_DIR/local-config" \
AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single \
SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2 LAUNCHER_SCOPE_CAPTURE="$LOCAL_CAPTURE" \
bash -c '
  set -euo pipefail
  source "$1"
  PROJECTS="$2"
  NOTES="$3"
  BASE_PROFILE="codex||||"
  AGENT_RUNNER="$4"
  run_agent l1-analyze Repo /analyze <<< "" >/dev/null
' _ "$ROOT/localrun.sh" "$LOCAL_PROJECTS" "$LOCAL_NOTES" "$FAKE_RUNNER"

assert_arg_pair "$LOCAL_CAPTURE" '--agent-dir' "$ROOT/cycle1-dev/l1-analyze"
assert_arg_pair "$LOCAL_CAPTURE" '--project-dir' "$LOCAL_PROJECTS/Repo"
assert_arg_pair "$LOCAL_CAPTURE" '--notes-dir' "$LOCAL_NOTES/Repo"
assert_arg_pair "$LOCAL_CAPTURE" '--mode' 'task'
[[ -d "$LOCAL_NOTES/Repo" ]] || fail 'Local Run did not prepare the exact notes directory'

rm -f "$LOCAL_CAPTURE"
if env XDG_CONFIG_HOME="$TMP_DIR/local-interactive-config" AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2 LAUNCHER_SCOPE_CAPTURE="$LOCAL_CAPTURE" bash -c '
    source "$1"
    PROJECTS="$2"
    NOTES="$3"
    BASE_PROFILE="codex||||"
    AGENT_RUNNER="$4"
    run_agent l1-analyze Repo "" <<< ""
  ' _ "$ROOT/localrun.sh" "$LOCAL_PROJECTS" "$LOCAL_NOTES" "$FAKE_RUNNER" >"$TMP_DIR/local-interactive.out" 2>&1; then
  fail 'Local Run accepted interactive Codex'
fi
grep -Fq 'BLOCKED: interactive Codex cannot disable ambient user configuration' "$TMP_DIR/local-interactive.out" ||
  fail 'Local Run did not explain task-only Codex'
[[ ! -e "$LOCAL_CAPTURE" ]] || fail 'Local Run invoked runner for blocked interactive Codex'

echo 'PASS: launcher runtime scopes smoke'

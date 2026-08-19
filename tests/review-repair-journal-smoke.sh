#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

export XDG_CONFIG_HOME="$TMP_DIR/config"
export XDG_STATE_HOME="$TMP_DIR/state"
export AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2
source "$ROOT/sdlc.sh"

PROJECTS="$TMP_DIR/projects"
PROJECT=ReviewFixture
BASE_PROFILE='codex||||'
mkdir -p "$PROJECTS/$PROJECT"
printf '%s\n' '# Dashboard' > "$PROJECTS/$PROJECT/Dashboard.md"

review_output() {
  printf 'REVIEW_FINDING\tFND-001\tHIGH\tDashboard.md\t_contract/GLOBAL.md\tproject\tRepair dashboard\n'
}

run_agent() {
  case "$3" in
    /review*) review_output ;;
    *) return 1 ;;
  esac
}

EXECUTION_STEP_PROFILES=('codex||||')
prepare_scoped_project_action review project
run_scoped_project_action >/dev/null || fail 'valid Review was rejected'
review_run="$CURRENT_RUN_ID"
review_file="$(journal_run_dir "$PROJECT" "$review_run")/review-findings.tsv"
review_findings_valid "$review_file" project || fail 'Review findings artifact is invalid'

chmod 0644 "$review_file"
printf '\nFND-TAMPER\tLOW\tnone\tnone\tproject\ttampered\n' >> "$review_file"
EXECUTION_STEP_PROFILES=('codex||||')
prepare_scoped_project_action repair project
if run_scoped_project_action >/dev/null 2>&1; then
  fail 'Repair accepted tampered Review findings'
fi

run_agent() {
  case "$3" in
    /review*) review_output ;;
    *) return 1 ;;
  esac
}
EXECUTION_STEP_PROFILES=('codex||||')
prepare_scoped_project_action review project
run_scoped_project_action >/dev/null || fail 'second Review was rejected'
printf '\nExternal change after review.\n' >> "$PROJECTS/$PROJECT/Dashboard.md"
EXECUTION_STEP_PROFILES=('codex||||')
prepare_scoped_project_action repair project
if run_scoped_project_action >/dev/null 2>&1; then
  fail 'Repair accepted a stale Review snapshot'
fi

run_agent() {
  case "$3" in
    /review*) review_output ;;
    /repair*) return 0 ;;
    *) return 1 ;;
  esac
}
EXECUTION_STEP_PROFILES=('codex||||')
prepare_scoped_project_action review project
run_scoped_project_action >/dev/null || fail 'third Review was rejected'
EXECUTION_STEP_PROFILES=('codex||||')
prepare_scoped_project_action repair project
if run_scoped_project_action >/dev/null 2>&1; then
  fail 'Repair passed without changing the Project snapshot'
fi

echo 'PASS: Review/Repair Journal smoke'

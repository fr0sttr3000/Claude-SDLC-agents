#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-launcher-journal.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
source "$ROOT/sdlc.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

for fn in journal_root journal_run_dir journal_create_run journal_write_state \
  journal_append_event journal_latest_unfinished journal_mark_interrupted_runs; do
  declare -F "$fn" >/dev/null || fail "missing journal function: $fn"
done

PROJECTS="$TMP_DIR/projects"
mkdir -p "$PROJECTS/Alpha" "$PROJECTS/Beta"
RUN_CYCLE=("s1-pm:/vision" "s4-dev:/dev-report")
RUN_OPTIONAL=(0 0)
AGENT_RUNTIME=codex
BASE_PROFILE="codex||||"
SDLC_RUNTIME_ROUTING=single
SDLC_SUBAGENTS=off
SDLC_SUBAGENT_MAX=2

PROJECT=Alpha
journal_create_run CYCLE "ТОЛЬКО Cycle 1" "Cycle 2, Cycle 3"
alpha_run="$CURRENT_RUN_ID"
[[ -n "$alpha_run" ]] || fail "Alpha run id not created"
alpha_dir="$(journal_run_dir Alpha "$alpha_run")"
[[ -f "$alpha_dir/plan.md" ]] || fail "Alpha plan missing"
[[ -f "$alpha_dir/state.md" ]] || fail "Alpha state missing"
[[ -f "$alpha_dir/events.jsonl" ]] || fail "Alpha events missing"
grep -Fq 'project: "Alpha"' "$alpha_dir/plan.md" || fail "plan has no safely quoted project"
grep -Fq 'scope: "ТОЛЬКО Cycle 1"' "$alpha_dir/plan.md" || fail "plan has no safely quoted scope"
grep -Fq 'excluded: "Cycle 2, Cycle 3"' "$alpha_dir/plan.md" || fail "plan has no safely quoted excluded scope"
grep -Fq 's1-pm' "$alpha_dir/plan.md" || fail "plan has no ordered steps"

journal_write_state "$alpha_run" RUNNING 1 2 RUNNING "s1-pm /vision"
journal_append_event "$alpha_run" step_started RUNNING 1 RUNNING s1-pm /vision "started"
grep -Fq 'status: RUNNING' "$alpha_dir/state.md" || fail "RUNNING state not persisted"
grep -Fq '"event":"step_started"' "$alpha_dir/events.jsonl" || fail "event not appended"
[[ "$(journal_latest_unfinished Alpha)" == "$alpha_run" ]] || fail "unfinished Alpha run not found"

PROJECT=Beta
journal_create_run REVIEW "project review: # read only" "mutation: false # excluded"
beta_run="$CURRENT_RUN_ID"
beta_dir="$(journal_run_dir Beta "$beta_run")"
[[ "$beta_dir" != "$alpha_dir" ]] || fail "projects share journal directory"
[[ -f "$beta_dir/plan.md" ]] || fail "Beta plan missing"
grep -Fq 'project: "Beta"' "$beta_dir/plan.md" || fail "Beta plan has wrong project"
grep -Fq 'scope: "project review: # read only"' "$beta_dir/plan.md" || fail "YAML-sensitive scope was not quoted"
grep -Fq 'project: "Alpha"' "$alpha_dir/plan.md" || fail "Beta run changed Alpha plan"

PROJECT=Alpha
journal_mark_interrupted_runs
grep -Fq 'status: INTERRUPTED' "$alpha_dir/state.md" || fail "stale RUNNING run not interrupted"
grep -Fq 'step_status: UNKNOWN' "$alpha_dir/state.md" || fail "interrupted step not UNKNOWN"

journal_append_event "$alpha_run" note INTERRUPTED 0 UNKNOWN '' '' 'misleading evidence "step":999'
[[ "$(journal_resume_point Alpha "$alpha_run")" == 1 ]] ||
  fail 'resume parser trusted a fake step number from evidence text'
journal_append_event "$alpha_run" step_succeeded RUNNING 1 SUCCEEDED s1-pm /vision ok
[[ "$(journal_resume_point Alpha "$alpha_run")" == 2 ]] ||
  fail 'resume parser did not trust the anchored step_succeeded event'

if command -v jq >/dev/null 2>&1; then
  while IFS= read -r event; do
    jq -e . >/dev/null <<< "$event" || fail "invalid JSONL event"
  done < "$alpha_dir/events.jsonl"
fi

[[ ! -e "$TMP_DIR/global-checkpoint" ]] || fail "unexpected global checkpoint"

PROJECT=Alpha
RUN_CYCLE=("s1-pm:/vision" "s1-pmo:/charter")
RUN_OPTIONAL=(0 0)
EXECUTION_STEP_PROFILES=("$BASE_PROFILE" "$BASE_PROFILE")
EXECUTION_STEP_SOURCES=(single single)
USE_EXISTING_FROZEN_ROUTES=1
EXECUTION_TYPE=CYCLE
EXECUTION_SCOPE='journal failing-step regression'
EXECUTION_EXCLUDED='none'
EXECUTION_TITLE='Journal failure test'
EXECUTION_CYCLE_ID=1
run_agent() {
  [[ "$1" == 's1-pm' ]] && return 0
  return 7
}
set +e
execute_previewed_cycle >/dev/null 2>&1
failure_rc=$?
set -e
[[ $failure_rc -eq 1 ]] || fail "failing cycle returned $failure_rc instead of blocked=1"
failure_state="$(journal_run_dir Alpha "$CURRENT_RUN_ID")/state.md"
grep -Fq 'status: BLOCKED' "$failure_state" || fail 'failed run was not marked BLOCKED'
grep -Fq 'step: 2' "$failure_state" || fail 'failed run lost the exact failing step'
grep -Fq 'step_status: FAILED' "$failure_state" || fail 'failed run lost FAILED step status'
grep -Fq 'current: "s1-pmo /charter"' "$failure_state" || fail 'failed run lost the failing action'
failure_events="$(journal_run_dir Alpha "$CURRENT_RUN_ID")/events.jsonl"
grep -Eq '"event":"run_blocked".*"step":2.*"agent":"s1-pmo".*"task":"/charter"' "$failure_events" ||
  fail 'run_blocked event lost the exact failing agent/task'

echo "PASS: launcher Execution Journal smoke"

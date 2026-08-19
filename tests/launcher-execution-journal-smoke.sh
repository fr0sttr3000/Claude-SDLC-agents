#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-launcher-journal.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export XDG_STATE_HOME="$TMP_DIR/state"
source "$ROOT/sdlc.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

for fn in journal_root journal_run_dir journal_create_run journal_write_state \
  journal_append_event journal_latest_unfinished journal_mark_interrupted_runs; do
  declare -F "$fn" >/dev/null || fail "missing journal function: $fn"
done

PROJECTS="$TMP_DIR/projects"
mkdir -p "$PROJECTS/Alpha" "$PROJECTS/Beta"
printf '%s\n' '# Dashboard' > "$PROJECTS/Alpha/Dashboard.md"
mkdir -p "$PROJECTS/Alpha/tracking"
printf '%s\n' 'schema_version: 5' 'revision: 1' > "$PROJECTS/Alpha/tracking/product-ci-profile.yaml"
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
[[ "$alpha_dir" != "$PROJECTS/Alpha/"* ]] || fail "canonical Journal remains inside agent Project write scope"
[[ "$alpha_dir" == "$XDG_STATE_HOME/sdlc-agents/execution-journal/projects/"* ]] || fail "Journal is not in launcher-owned state"
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
journal_append_event "$alpha_run" step_process_ok RUNNING 1 PROCESS_OK s1-pm /vision 'runtime exit code 0'
[[ "$(journal_resume_point Alpha "$alpha_run")" == 1 ]] ||
  fail 'resume parser treated PROCESS_OK as completed work'
journal_append_event "$alpha_run" step_artifact_verified RUNNING 1 ARTIFACT_VERIFIED s1-pm /vision 'declared output changed'
[[ "$(journal_resume_point Alpha "$alpha_run")" == 2 ]] ||
  fail 'resume parser did not trust the anchored step_artifact_verified event'

if command -v jq >/dev/null 2>&1; then
  while IFS= read -r event; do
    jq -e . >/dev/null <<< "$event" || fail "invalid JSONL event"
  done < "$alpha_dir/events.jsonl"
fi
grep -Eq '"sequence":1,.*"prev_hash":"GENESIS","event_hash":"[0-9a-f]{64}"' \
  "$alpha_dir/events.jsonl" || fail 'Journal genesis event is not hash-chain anchored'
cp "$alpha_dir/events.jsonl" "$TMP_DIR/alpha-events.valid"
sed -i '0,/started/s//altered/' "$alpha_dir/events.jsonl"
if journal_validate_run Alpha "$alpha_run" >/dev/null 2>&1; then
  fail 'digest-invalid Journal event tampering was accepted'
fi
cp "$TMP_DIR/alpha-events.valid" "$alpha_dir/events.jsonl"
journal_validate_run Alpha "$alpha_run" || fail 'restored hash chain was rejected'

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
  if [[ "$1:$3" == 's1-pm:/vision' ]]; then
    mkdir -p "$PROJECTS/$PROJECT/stage1-planning/outputs"
    write_artifact_metadata_fixture \
      "$PROJECTS/$PROJECT/stage1-planning/outputs/PM-2026-07-27-vision.md" \
      "$PROJECTS/$PROJECT" PM-VISION-001 vision S1 s1-pm none APPROVED 'Vision produced by test'
    return 0
  fi
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
grep -Eq '"event":"step_process_ok".*"step":1.*"step_status":"PROCESS_OK"' "$failure_events" ||
  fail 'runtime exit 0 was not recorded separately as PROCESS_OK'
grep -Eq '"event":"step_artifact_verified".*"step":1.*"step_status":"ARTIFACT_VERIFIED"' "$failure_events" ||
  fail 'declared output verification was not recorded separately'

RUN_CYCLE=("s1-pm:/vision")
RUN_OPTIONAL=(0)
EXECUTION_STEP_PROFILES=("$BASE_PROFILE")
EXECUTION_STEP_SOURCES=(single)
run_agent() { return 0; }
set +e
execute_previewed_cycle >/dev/null 2>&1
unverified_rc=$?
set -e
[[ $unverified_rc -eq 1 ]] || fail 'runtime exit 0 without declared output did not block the run'
unverified_state="$(journal_run_dir Alpha "$CURRENT_RUN_ID")/state.md"
grep -Fq 'step_status: UNVERIFIED' "$unverified_state" ||
  fail 'missing declared output was not persisted as UNVERIFIED'
unverified_events="$(journal_run_dir Alpha "$CURRENT_RUN_ID")/events.jsonl"
grep -Eq '"event":"step_artifact_unverified".*"step_status":"UNVERIFIED"' "$unverified_events" ||
  fail 'missing declared output did not produce a distinct unverified event'

PROJECT=Beta
printf 'tampered: true\n' >> "$beta_dir/plan.md"
if journal_resume_point Beta "$beta_run" >/dev/null 2>&1; then fail "tampered immutable plan was accepted"; fi
mkdir -p "$PROJECTS/Gamma"
printf '%s\n' '# Dashboard' > "$PROJECTS/Gamma/Dashboard.md"
PROJECT=Gamma
USE_EXISTING_FROZEN_ROUTES=0
EXECUTION_STEP_PROFILES=()
EXECUTION_STEP_SOURCES=()
RUN_CYCLE=("s1-pm:/vision" "s1-pmo:/charter")
RUN_OPTIONAL=(0 0)
journal_create_run CYCLE "sequential resume" "none"
gamma_run="$CURRENT_RUN_ID"
journal_append_event "$gamma_run" step_artifact_verified RUNNING 2 ARTIFACT_VERIFIED s1-pmo /charter evidence
[[ "$(journal_resume_point Gamma "$gamma_run")" == 1 ]] || fail "out-of-order verified event skipped step 1"

# Resume never skips a step whose registered Gate/DoD/completion postcondition is absent.
PROJECT=Gamma
USE_EXISTING_FROZEN_ROUTES=0
EXECUTION_STEP_PROFILES=()
EXECUTION_STEP_SOURCES=()
RUN_CYCLE=("s4-techlead:/review" "s0-tracker:/report")
RUN_OPTIONAL=(0 0)
journal_create_run CYCLE "hook-aware resume" "none"
hook_run="$CURRENT_RUN_ID"
journal_append_event "$hook_run" step_artifact_verified RUNNING 1 ARTIFACT_VERIFIED s4-techlead /review evidence
[[ "$(journal_resume_point Gamma "$hook_run")" == 1 ]] ||
  fail 'resume skipped Tech Lead step without full DoD hooks'
journal_append_event "$hook_run" software_dod_auto_pass RUNNING 1 DOD_AUTO_PASS s4-techlead /review evidence
journal_append_event "$hook_run" software_dod_approved RUNNING 1 DOD_PASS s4-techlead /review evidence
[[ "$(journal_resume_point Gamma "$hook_run")" == 2 ]] ||
  fail 'resume rejected a step with both full DoD hooks'
journal_append_event "$hook_run" step_artifact_verified RUNNING 2 ARTIFACT_VERIFIED s0-tracker /report evidence
[[ "$(journal_resume_point Gamma "$hook_run")" == 2 ]] ||
  fail 'resume skipped /report without verified completion proof'
journal_append_event "$hook_run" cycle1_completion_pass RUNNING 2 ARTIFACT_VERIFIED s0-tracker /report evidence
[[ "$(journal_resume_point Gamma "$hook_run")" == 3 ]] ||
  fail 'resume rejected /report with verified completion proof'

RUN_CYCLE=("s2-ba:/extract-requirements")
RUN_OPTIONAL=(0)
journal_create_run CYCLE "gate-aware resume" "none"
gate_run="$CURRENT_RUN_ID"
journal_append_event "$gate_run" step_artifact_verified RUNNING 1 ARTIFACT_VERIFIED s2-ba /extract-requirements evidence
[[ "$(journal_resume_point Gamma "$gate_run")" == 1 ]] ||
  fail 'resume skipped a step without its required Gate 1 event'
journal_append_event "$gate_run" gate_pass RUNNING 1 GATE_PASS '' 'Gate 1' evidence
[[ "$(journal_resume_point Gamma "$gate_run")" == 2 ]] ||
  fail 'resume rejected a step with its required Gate 1 event'

# Retry must slice the immutable parent plan at the proven resume point and dispatch the same
# unified preview executor used by normal Cycle/One Agent execution.
RETRY_RENDER=''
RETRY_DISPATCH=''
render_execution_preview() {
  RETRY_RENDER="$1|$2|$3"
}
confirm_execution_preview() {
  [[ "$1" == execute_previewed_cycle ]] || fail 'Retry selected a non-canonical executor'
  "$1"
}
execute_previewed_cycle() {
  RETRY_DISPATCH="${EXECUTION_TYPE}|${EXECUTION_CYCLE_ID}|${PARENT_RUN_ID}|${USE_EXISTING_FROZEN_ROUTES}|${RUN_CYCLE[*]}|${EXECUTION_STEP_PROFILES[*]}|${EXECUTION_STEP_SOURCES[*]}"
}
PROJECT=Alpha
retry_journal_run "$alpha_run" >/dev/null || fail 'Retry rejected a valid immutable parent run'
[[ "$RETRY_RENDER" == "RESUME|child retry of $alpha_run from original step 2/2|proven steps 1-1; all scopes outside parent plan" ]] ||
  fail 'Retry preview did not preserve the exact parent/resume boundary'
[[ "$RETRY_DISPATCH" == "RESUME|1|$alpha_run|1|s4-dev:/dev-report|codex|||||single profile" ]] ||
  fail 'Retry did not dispatch the remaining frozen step through the unified executor'
echo "PASS: launcher Execution Journal smoke"

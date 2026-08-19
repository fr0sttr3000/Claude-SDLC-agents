#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-launcher-advanced.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export XDG_STATE_HOME="$TMP_DIR/state"
export AGENT_RUNTIME=codex
export CODEX_BIN=/bin/true
export SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off
export SDLC_SUBAGENT_MAX=2
source "$ROOT/sdlc.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "output does not contain: $2"
}

for fn in freeze_execution_routes execution_route_source project_ai_config_path \
  activate_project_ai_config save_project_ai_config journal_resume_point \
  render_project_review_menu render_project_repair_menu prepare_scoped_project_action \
  run_scoped_project_action run_agent_with_preview; do
  declare -F "$fn" >/dev/null || fail "missing advanced launcher function: $fn"
done

PROJECTS="$TMP_DIR/projects"
mkdir -p "$PROJECTS/Alpha/tracking" "$PROJECTS/Beta/tracking"
printf '%s\n' '# Dashboard' > "$PROJECTS/Alpha/Dashboard.md"
printf '%s\n' 'schema_version: 5' 'revision: 1' > \
  "$PROJECTS/Alpha/tracking/product-ci-profile.yaml"
printf '%s\n' 'schema_version: 5' 'revision: 1' > \
  "$PROJECTS/Beta/tracking/product-ci-profile.yaml"
PROJECT=Alpha
LAUNCHER_BASE_PROFILE='codex||||'
LAUNCHER_ROUTING_POLICY=single
BASE_PROFILE="$LAUNCHER_BASE_PROFILE"

[[ "$(project_ai_config_path Alpha)" != "$(project_ai_config_path Beta)" ]] ||
  fail "projects share AI config"
save_project_ai_config 'codex||||' single
PROJECT=Beta
save_project_ai_config 'local|ollama|qwen2.5-coder:14b|codex-oss|' single
PROJECT=Alpha
activate_project_ai_config
[[ "$BASE_PROFILE" == 'codex||||' ]] || fail "Alpha AI profile leaked"
PROJECT=Beta
activate_project_ai_config
[[ "$BASE_PROFILE" == 'local|ollama|qwen2.5-coder:14b|codex-oss|' ]] ||
  fail "Beta AI profile not loaded"

PROJECT=Alpha
BASE_PROFILE='codex||||'
apply_profile "$BASE_PROFILE"
RUN_CYCLE=('s1-pm:/vision' 's4-dev:/dev-report')
RUN_OPTIONAL=(0 0)
freeze_execution_routes
[[ ${#EXECUTION_STEP_PROFILES[@]} -eq 2 ]] || fail "route snapshot incomplete"
[[ "${EXECUTION_STEP_PROFILES[0]}" == 'codex||||' ]] || fail "route snapshot wrong"
[[ "$(execution_route_source s1-pm)" == 'single profile' ]] ||
  fail "route source not explicit"

journal_create_run CYCLE 'ТОЛЬКО Cycle 1' 'Cycle 2, Cycle 3'
run_id="$CURRENT_RUN_ID"
run_dir="$(journal_run_dir Alpha "$run_id")"
grep -Fq 'step_1_profile: codex||||' "$run_dir/plan.md" ||
  fail "journal did not freeze exact step profile"
journal_append_event "$run_id" step_artifact_verified RUNNING 1 ARTIFACT_VERIFIED s1-pm /vision evidence
[[ "$(journal_resume_point Alpha "$run_id")" == 2 ]] ||
  fail "resume point is not the step after proven success"

review="$(render_project_review_menu)"
assert_contains "$review" 'Весь Project'
assert_contains "$review" 'Один Cycle'
assert_contains "$review" 'Один Stage'
assert_contains "$review" 'Один Agent'
assert_contains "$review" 'AI routes'

prepare_scoped_project_action review project
[[ "${RUN_CYCLE[*]}" == 's0-validate:/review scope=project' ]] ||
  fail 'whole-project Review did not create an explicit project scope'
[[ "$SCOPED_ACTION_ACCESS" == read-only ]] || fail 'Review is not capability-enforced read-only'
project_scope="$EXECUTION_SCOPE"

EXECUTION_STEP_PROFILES=("codex||||")
prepare_scoped_project_action review cycle:1
[[ "${RUN_CYCLE[*]}" == 's0-validate:/review scope=cycle:1' ]] ||
  fail 'Cycle 1 Review did not create a distinct cycle scope'
[[ "$EXECUTION_SCOPE" != "$project_scope" ]] || fail 'Project and Cycle Review scopes are indistinguishable'

prepare_scoped_project_action review stage:4
[[ "${RUN_CYCLE[*]}" == 's0-validate:/review scope=stage:4' ]] ||
  fail 'Stage Review did not create a distinct stage scope'

prepare_scoped_project_action review agent:s4-dev
[[ "${RUN_CYCLE[*]}" == 's0-validate:/review scope=agent:s4-dev' ]] ||
  fail 'Agent Review did not create a distinct agent scope'

if prepare_scoped_project_action review agent:not-real; then
  fail 'Review accepted an unknown agent scope'
fi
if prepare_scoped_project_action review cycle:4; then
  fail 'Review accepted a nonexistent cycle'
fi
if prepare_scoped_project_action review cycle:2; then
  fail 'Review accepted frozen Cycle 2'
fi
if prepare_scoped_project_action repair stage:6; then
  fail 'Repair accepted frozen Stage 6'
fi
if prepare_scoped_project_action repair agent:s6-sre; then
  fail 'Repair accepted frozen Agent'
fi

prepare_scoped_project_action repair structure
[[ "${RUN_CYCLE[*]}" == 's0-validate:/repair scope=structure' ]] ||
  fail 'Structure Repair is not an explicit scope'
[[ "$SCOPED_ACTION_ACCESS" == write ]] || fail 'Repair was mislabeled read-only'

repair="$(render_project_repair_menu)"
assert_contains "$repair" 'Весь Project'
assert_contains "$repair" 'Один Cycle'
assert_contains "$repair" 'Один Stage'
assert_contains "$repair" 'Один Agent'
assert_contains "$repair" 'Только структуру'

SCOPED_CALLS="$TMP_DIR/scoped-calls"
: > "$SCOPED_CALLS"
run_agent() {
  local task_head="${3%%$'\n'*}"
  printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$task_head" \
    "${ACTIVE_AGENT_ACCESS:-write}" "${ACTIVE_EXECUTION_PROFILE:-missing}" >> "$SCOPED_CALLS"
  case "$3" in
    /review*verification_of=*)
      printf 'REVIEW_FINDING\tCLEAN\tINFO\tnone\tnone\tagent:s4-dev\tNo findings\n'
      ;;
    /review*)
      printf 'REVIEW_FINDING\tFND-SYNTH-001\tHIGH\tDashboard.md\t_contract/GLOBAL.md\tagent:s4-dev\tDashboard requires repair\n'
      ;;
    /repair*)
      grep -Fq 'VERIFIED REVIEW FINDINGS TSV:' <<< "$3" || return 9
      printf '\nRepaired by fixture.\n' >> "$PROJECTS/Alpha/Dashboard.md"
      ;;
    *) return 1 ;;
  esac
}
EXECUTION_STEP_PROFILES=("codex||||")
prepare_scoped_project_action review agent:s4-dev
run_scoped_project_action
review_run="$CURRENT_RUN_ID"
review_file="$(journal_run_dir Alpha "$review_run")/review-findings.tsv"
review_findings_valid "$review_file" agent:s4-dev ||
  fail 'scoped Review did not persist verified immutable findings'
grep -Fqx 'verdict: FINDINGS' "$review_file" || fail 'Review findings verdict was not persisted'
grep -Fq 's0-validate|Alpha|/review scope=agent:s4-dev|read-only|codex||||' "$SCOPED_CALLS" ||
  fail 'scoped Review did not dispatch the exact scope in read-only mode'

EXECUTION_STEP_PROFILES=("codex||||")
prepare_scoped_project_action repair agent:s4-dev
run_scoped_project_action
repair_run="$CURRENT_RUN_ID"
repair_dir="$(journal_run_dir Alpha "$repair_run")"
grep -Fqx "parent_run_id: $review_run" "$repair_dir/plan.md" ||
  fail 'Repair run is not linked to its Review parent'
review_findings_valid "$repair_dir/repair-verification-findings.tsv" agent:s4-dev ||
  fail 'Repair did not persist the re-review artifact'
grep -Fqx 'verdict: CLEAN' "$repair_dir/repair-verification-findings.tsv" ||
  fail 'Repair passed without CLEAN re-review'
grep -Fq 's0-validate|Alpha|/repair scope=agent:s4-dev' "$SCOPED_CALLS" ||
  fail 'scoped Repair did not dispatch the exact writable scope'
grep -Fq '|write|codex||||' "$SCOPED_CALLS" || fail 'Repair did not receive write access'

HOOKS=()
require_cycle_tdd_red() { HOOKS+=(tdd-red); return 0; }
cycle1_gate_before_entry() { return 0; }
cycle1_gate_after_entry() { return 0; }
cycle1_software_dod_after_entry() { HOOKS+=(dod-applicable); return 0; }
run_cycle1_software_dod_validator() { HOOKS+=(dod-validator); return 0; }
run_cycle1_full_dod_validator() { HOOKS+=(dod-approval-blocked); return 1; }
CALLS=()
CALL_SERIAL=0
run_agent() {
  CALLS+=(run)
  CALL_SERIAL=$((CALL_SERIAL + 1))
  write_artifact_metadata_fixture \
    "$PROJECTS/Alpha/stage4-dev/outputs/DEV-2026-07-27-PR-${CALL_SERIAL}-summary.md" \
    "$PROJECTS/Alpha" "DEV-PR${CALL_SERIAL}-SUMMARY" dev-summary S4 s4-dev none PASS "PR summary $CALL_SERIAL"
  write_artifact_metadata_fixture \
    "$PROJECTS/Alpha/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR${CALL_SERIAL}.md" \
    "$PROJECTS/Alpha" "DEV-PR${CALL_SERIAL}-NOTES" update-notes S4 s4-dev none PASS "Update notes $CALL_SERIAL"
}
run_agent_with_preview s4-dev Alpha /dev-report <<< 'b' >/dev/null || true
[[ ${#CALLS[@]} -eq 0 ]] || fail "One Agent cancel dispatched work"
if run_agent_with_preview s4-dev Alpha /dev-report <<< 'r' >/dev/null 2>&1; then
  fail 'One Agent passed full Software DoD without independent approval'
fi
blocked_dod_events="$(journal_run_dir Alpha "$CURRENT_RUN_ID")/events.jsonl"
grep -Eq '"event":"software_dod_auto_pass".*"step_status":"DOD_AUTO_PASS"' "$blocked_dod_events" ||
  fail 'automated DoD subset did not emit DOD_AUTO_PASS'
if grep -Fq '"step_status":"DOD_PASS"' "$blocked_dod_events"; then
  fail 'automated DoD subset was promoted to full DOD_PASS'
fi

run_cycle1_full_dod_validator() { HOOKS+=(dod-approval); return 0; }
CALLS=()
run_agent_with_preview s4-dev Alpha /dev-report <<< 'r' >/dev/null
[[ "${CALLS[*]}" == run ]] || fail "One Agent explicit run did not dispatch exactly once"
dod_events="$(journal_run_dir Alpha "$CURRENT_RUN_ID")/events.jsonl"
grep -Eq '"event":"software_dod_approved".*"step_status":"DOD_PASS"' "$dod_events" ||
  fail 'independent full DoD approval did not emit DOD_PASS'

CALLS=()
cycle1_gate_before_entry() { printf '2\n'; }
run_cycle1_gate_validator() { return 1; }
if run_agent_with_preview s3-arch Alpha /hld <<< 'r' >/dev/null 2>&1; then fail "One Agent crossed a blocked Gate 2"; fi
[[ ${#CALLS[@]} -eq 0 ]] || fail "One Agent dispatched after blocked gate"
[[ "${HOOKS[*]}" == *"tdd-red"* && "${HOOKS[*]}" == *"dod-validator"* &&
   "${HOOKS[*]}" == *"dod-approval"* ]] || fail "One Agent skipped TDD/DoD hooks"
(
  source "$ROOT/localrun.sh"
  declare -F render_localrun_execution_preview >/dev/null ||
    fail "missing Local Repositories execution preview"
  PROJECTS="$TMP_DIR/repos"
  NOTES="$TMP_DIR/notes"
  mkdir -p "$PROJECTS/Repo" "$NOTES"
  output="$(render_localrun_execution_preview Repo "${PIPELINE[@]}")"
  assert_contains "$output" "$PROJECTS/Repo"
  assert_contains "$output" "$NOTES/Repo"
  assert_contains "$output" 'Analyze'
  assert_contains "$output" 'Install & configure'
  assert_contains "$output" 'Build'
  assert_contains "$output" 'Start & smoke'
  assert_contains "$output" 'GIT PUSH: ЗАПРЕЩЁН'
)

echo 'PASS: launcher advanced parity smoke'

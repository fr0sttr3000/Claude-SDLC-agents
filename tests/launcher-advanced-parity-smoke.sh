#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-launcher-advanced.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
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
journal_append_event "$run_id" step_succeeded RUNNING 1 SUCCEEDED s1-pm /vision evidence
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

prepare_scoped_project_action review cycle:2
[[ "${RUN_CYCLE[*]}" == 's0-validate:/review scope=cycle:2' ]] ||
  fail 'Cycle Review did not create a distinct cycle scope'
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

CALLS=()
run_agent() { CALLS+=("$1|$2|$3|${ACTIVE_AGENT_ACCESS:-write}"); }
prepare_scoped_project_action review cycle:3
run_scoped_project_action
[[ "${CALLS[*]}" == 's0-validate|Alpha|/review scope=cycle:3|read-only' ]] ||
  fail 'scoped Review did not dispatch the exact scope in read-only mode'
CALLS=()
prepare_scoped_project_action repair agent:s4-dev
run_scoped_project_action
[[ "${CALLS[*]}" == 's0-validate|Alpha|/repair scope=agent:s4-dev|write' ]] ||
  fail 'scoped Repair did not dispatch the exact writable scope'

CALLS=()
run_agent() { CALLS+=(run); }
run_agent_with_preview s4-dev Alpha /dev-report <<< 'b' >/dev/null || true
[[ ${#CALLS[@]} -eq 0 ]] || fail "One Agent cancel dispatched work"
run_agent_with_preview s4-dev Alpha /dev-report <<< 'r' >/dev/null
[[ "${CALLS[*]}" == run ]] || fail "One Agent explicit run did not dispatch exactly once"

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

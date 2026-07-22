#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-cycle23-goal.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

AGENT_RUNTIME=codex
CODEX_BIN=/bin/true
SDLC_RUNTIME_ROUTING=single
SDLC_SUBAGENTS=auto
SDLC_SUBAGENT_MAX=3
source "$ROOT/sdlc.sh"

for fn in goal_profile_path goal_profile_history_path load_goal_profile save_goal_profile goal_profile_mode_consistent goal_profile_complete_for_cycle goal_route_label set_goal_route_from_choice set_goal_cycle_enabled prompt_goal_route_selection prompt_goal_deliverables read_cycle_tdd_status require_cycle_tdd_red run_cycle_tdd_repair_loop run_cycle2 run_cycle3 run_goal_mode; do
  [[ "$(type -t "$fn")" == "function" ]] || fail "missing function: $fn"
done

GOAL_VALUES=()
set_goal_route_from_choice 1
[[ "${GOAL_VALUES[goal_mode]}:${GOAL_VALUES[cycle2_enabled]}:${GOAL_VALUES[cycle3_enabled]}" == "cycle1-only:no:no" ]] ||
  fail "explicit Cycle 1-only route mapping is wrong"
[[ "$(goal_route_label)" == *"Только Cycle 1"* ]] ||
  fail "Cycle 1-only route has no informative label"

set_goal_route_from_choice 2
[[ "${GOAL_VALUES[goal_mode]}:${GOAL_VALUES[cycle2_enabled]}:${GOAL_VALUES[cycle3_enabled]}" == "through-cycle2:yes:no" ]] ||
  fail "Cycle 1→2 route mapping is wrong"

set_goal_route_from_choice 3
[[ "${GOAL_VALUES[goal_mode]}:${GOAL_VALUES[cycle2_enabled]}:${GOAL_VALUES[cycle3_enabled]}" == "through-cycle3:yes:yes" ]] ||
  fail "Cycle 1→2→3 route mapping is wrong"

set_goal_route_from_choice 4 no yes
[[ "${GOAL_VALUES[goal_mode]}:${GOAL_VALUES[cycle2_enabled]}:${GOAL_VALUES[cycle3_enabled]}" == "custom:no:yes" ]] ||
  fail "custom route mapping is wrong"
set_goal_cycle_enabled 3 no
[[ "${GOAL_VALUES[goal_mode]}:${GOAL_VALUES[cycle2_enabled]}:${GOAL_VALUES[cycle3_enabled]}" == "cycle1-only:no:no" ]] ||
  fail "partial cycle correction did not normalize the route"

GOAL_VALUES=()
prompt_goal_route_selection no <<< "1" >/dev/null
[[ "${GOAL_VALUES[goal_mode]}:${GOAL_VALUES[cycle2_enabled]}:${GOAL_VALUES[cycle3_enabled]}" == "cycle1-only:no:no" ]] ||
  fail "interactive Cycle 1-only selection is broken"
GOAL_VALUES[cycle2_deliverables]=""
prompt_goal_deliverables 2 <<< "1,5" >/dev/null
[[ "${GOAL_VALUES[cycle2_deliverables]}" == "images,cicd" ]] ||
  fail "interactive Cycle 2 deliverable selection is broken"

array_index() {
  local needle="$1"
  shift
  local i=0 value
  for value in "$@"; do
    [[ "$value" == "$needle" ]] && { printf '%s\n' "$i"; return 0; }
    ((i++))
  done
  return 1
}

[[ "${#CYCLE2_AGENTS[@]}" -eq 8 ]] || fail "Cycle 2 must have 8 mandatory steps"
[[ "${#CYCLE3_AGENTS[@]}" -eq 6 ]] || fail "Cycle 3 must have 6 mandatory steps"

c2_tests="$(array_index "s4-devops:/write-deploy-tests" "${CYCLE2_AGENTS[@]}")"
c2_pipeline="$(array_index "s4-devops:/pipeline" "${CYCLE2_AGENTS[@]}")"
c2_prepare="$(array_index "s4-devops:/prepare-delivery" "${CYCLE2_AGENTS[@]}")"
c2_run="$(array_index "s4-devops:/run-deploy-tests" "${CYCLE2_AGENTS[@]}")"
c2_notes="$(array_index "s6-release:/release-notes" "${CYCLE2_AGENTS[@]}")"
c2_checklist="$(array_index "s6-release:/release-checklist" "${CYCLE2_AGENTS[@]}")"
(( c2_tests < c2_pipeline && c2_pipeline < c2_prepare && c2_prepare < c2_run )) ||
  fail "Cycle 2 is not test-first"
(( c2_run < c2_notes && c2_notes < c2_checklist )) ||
  fail "Cycle 2 release preparation order is wrong"

c3_tests="$(array_index "s6-sre:/write-ops-tests" "${CYCLE3_AGENTS[@]}")"
c3_config="$(array_index "s6-sre:/configure-ops" "${CYCLE3_AGENTS[@]}")"
c3_run="$(array_index "s6-sre:/run-ops-tests" "${CYCLE3_AGENTS[@]}")"
(( c3_tests < c3_config && c3_config < c3_run )) || fail "Cycle 3 is not test-first"

for command_file in \
  cycle2-deploy/s4-devops/.claude/commands/deploy-intake.md \
  cycle2-deploy/s4-devops/.claude/commands/write-deploy-tests.md \
  cycle2-deploy/s4-devops/.claude/commands/prepare-delivery.md \
  cycle2-deploy/s4-devops/.claude/commands/run-deploy-tests.md \
  cycle3-ops/s6-sre/.claude/commands/ops-intake.md \
  cycle3-ops/s6-sre/.claude/commands/write-ops-tests.md \
  cycle3-ops/s6-sre/.claude/commands/configure-ops.md \
  cycle3-ops/s6-sre/.claude/commands/run-ops-tests.md; do
  [[ -f "$ROOT/$command_file" ]] || fail "missing command contract: $command_file"
done

for contract in \
  cycle2-deploy/s4-devops/CLAUDE.md \
  cycle2-deploy/s6-release/CLAUDE.md \
  cycle3-ops/s6-sre/CLAUDE.md; do
  rg -q 'tracking/SDLC-goals.md' "$ROOT/$contract" ||
    fail "role does not consume goal profile: $contract"
done
rg -q 'DEPLOY-TDD-status.md.*PASS' "$ROOT/_standards/quality.md" ||
  fail "Gate 6 does not require DEPLOY TDD PASS"
rg -q 'OPS-TDD-status.md.*PASS' "$ROOT/_standards/quality.md" ||
  fail "Gate 7 does not require OPS TDD PASS"
if rg -q 'целевой workflow.*разв|⏳ в разработке' \
  "$ROOT/CLAUDE.md" "$ROOT/README.md" "$ROOT/GETTING_STARTED.md" \
  "$ROOT/OVERVIEW.md" "$ROOT/plans/roadmap.md" "$ROOT/sdlc.sh"; then
  fail "current documentation still describes Cycle 2/3 as unimplemented"
fi
rg -q 'Только Cycle 1' "$ROOT/sdlc.sh" ||
  fail "launcher has no explicit Cycle 1-only choice"
rg -q 'Выбери deliverables' "$ROOT/sdlc.sh" ||
  fail "launcher has no informative deliverable selector"

PROJECTS="$TMP_DIR/projects"
PROJECT="demo"
mkdir -p "$PROJECTS/$PROJECT/tracking" "$PROJECTS/$PROJECT/stage6-deploy/outputs" "$PROJECTS/$PROJECT/stage7-ops/outputs"

GOAL_VALUES=()
GOAL_VALUES[goal_mode]="through-cycle3"
GOAL_VALUES[revision_reason]="initial-goal"
GOAL_VALUES[cycle2_enabled]="yes"
GOAL_VALUES[cycle3_enabled]="yes"
for key in "${CYCLE2_GOAL_KEYS[@]}"; do GOAL_VALUES["$key"]="verified-$key"; done
for key in "${CYCLE3_GOAL_KEYS[@]}"; do GOAL_VALUES["$key"]="verified-$key"; done
GOAL_VALUES[cycle2_enabled]="yes"
GOAL_VALUES[cycle3_enabled]="yes"
GOAL_VALUES[cycle2_deliverables]="images,cicd,operations-pack"
GOAL_VALUES[cycle3_deliverables]="monitoring,alerts,runbooks"

save_goal_profile
PROFILE="$(goal_profile_path)"
HISTORY="$(goal_profile_history_path)"
[[ -f "$PROFILE" ]] || fail "goal profile was not written"
[[ -f "$HISTORY" ]] || fail "goal profile history was not written"
[[ "${GOAL_VALUES[revision]}" == "1" ]] || fail "first revision must be 1"
goal_profile_complete_for_cycle 2 || fail "saved Cycle 2 goal is incomplete"
goal_profile_complete_for_cycle 3 || fail "saved Cycle 3 goal is incomplete"

cycle3_before="${GOAL_VALUES[cycle3_goal]}"
GOAL_VALUES[cycle2_goal]="late-deploy-adjustment"
GOAL_VALUES[revision_reason]="registry-changed-after-development"
save_goal_profile
[[ "${GOAL_VALUES[revision]}" == "2" ]] || fail "partial update did not increment revision"
GOAL_VALUES=()
load_goal_profile
[[ "${GOAL_VALUES[revision]}" == "2" ]] || fail "revision was not persisted"
[[ "$(rg -c '^revision: ' "$HISTORY")" -eq 2 ]] || fail "history is not append-only"
[[ "${GOAL_VALUES[cycle2_goal]}" == "late-deploy-adjustment" ]] ||
  fail "partial Cycle 2 update was not persisted"
[[ "${GOAL_VALUES[cycle3_goal]}" == "$cycle3_before" ]] ||
  fail "partial Cycle 2 update overwrote Cycle 3"

GOAL_VALUES[goal_mode]="through-cycle3"
GOAL_VALUES[cycle2_enabled]="no"
if goal_profile_mode_consistent; then
  fail "through-cycle3 accepted disabled Cycle 2"
fi
GOAL_VALUES[cycle2_enabled]="yes"
goal_profile_mode_consistent || fail "valid goal mode was rejected"

write_cycle_status() {
  local cycle="$1" status="$2" revision="${3:-${GOAL_VALUES[revision]}}" file
  file="$(cycle_tdd_status_file "$cycle")"
  printf 'status: %s\nproject: demo\ngoal_profile_revision: %s\nfailed_tests: 1\n' "$status" "$revision" > "$file"
}

write_cycle_status 2 RED 1
if require_cycle_tdd_red 2 >/dev/null 2>&1; then
  fail "Cycle 2 accepted stale goal profile revision"
fi
write_cycle_status 2 RED
require_cycle_tdd_red 2 || fail "Cycle 2 RED was rejected"
write_cycle_status 3 RED
require_cycle_tdd_red 3 || fail "Cycle 3 RED was rejected"

CALLS_FILE="$TMP_DIR/calls"
run_agent() {
  local agent="$1" task="$3"
  printf '%s:%s\n' "$agent" "$task" >> "$CALLS_FILE"
  [[ "$agent:$task" == "s4-devops:/run-deploy-tests" ]] && write_cycle_status 2 PASS
  [[ "$agent:$task" == "s6-sre:/run-ops-tests" ]] && write_cycle_status 3 PASS
  return 0
}

write_cycle_status 2 FAIL
TDD_MAX_REPAIR_ITERATIONS=2 run_cycle_tdd_repair_loop 2 ||
  fail "Cycle 2 repair loop did not recover"
mapfile -t c2_calls < "$CALLS_FILE"
[[ "${c2_calls[*]}" == "s4-devops:/pipeline s4-devops:/runbook s4-devops:/prepare-delivery s4-devops:/run-deploy-tests" ]] ||
  fail "Cycle 2 repair sequence is wrong: ${c2_calls[*]}"

: > "$CALLS_FILE"
write_cycle_status 3 FAIL
TDD_MAX_REPAIR_ITERATIONS=2 run_cycle_tdd_repair_loop 3 ||
  fail "Cycle 3 repair loop did not recover"
mapfile -t c3_calls < "$CALLS_FILE"
[[ "${c3_calls[*]}" == "s6-sre:/configure-ops s6-sre:/run-ops-tests" ]] ||
  fail "Cycle 3 repair sequence is wrong: ${c3_calls[*]}"

run_agent() { return 0; }
write_cycle_status 3 FAIL
if TDD_MAX_REPAIR_ITERATIONS=1 run_cycle_tdd_repair_loop 3 >/dev/null 2>&1; then
  fail "Cycle 3 silently passed after repair exhaustion"
fi
[[ "$(read_cycle_tdd_status 3)" == "BLOCKED" ]] ||
  fail "Cycle 3 exhaustion did not persist BLOCKED"

echo "PASS: Cycle 2/3 goal orchestration smoke"

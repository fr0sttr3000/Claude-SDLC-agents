#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-launcher-gates.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export XDG_STATE_HOME="$TMP_DIR/state"
source "$ROOT/sdlc.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

for fn in cycle1_gate_before_entry cycle1_gate_after_entry \
  cycle1_software_dod_after_entry run_cycle1_gate_validator \
  run_cycle1_software_dod_validator; do
  declare -F "$fn" >/dev/null || fail "missing automatic boundary hook: $fn"
done

[[ "$(cycle1_gate_before_entry s2-ba /extract-requirements)" == 1 ]] ||
  fail 'Gate 1 is not scheduled before Stage 2'
[[ "$(cycle1_gate_before_entry s3-arch /hld)" == 2 ]] ||
  fail 'Gate 2 is not scheduled before Stage 3'
[[ "$(cycle1_gate_before_entry s4-qa-auto /write-tests)" == 3 ]] ||
  fail 'Gate 3 is not scheduled before Stage 4'
[[ "$(cycle1_gate_before_entry s5-qa /test-plan)" == 4 ]] ||
  fail 'Gate 4 is not scheduled before Stage 5'
[[ "$(cycle1_gate_after_entry s5-qa /go-no-go)" == 5 ]] ||
  fail 'Gate 5 is not scheduled after Go/No-Go'
cycle1_software_dod_after_entry s4-techlead /review ||
  fail 'software DoD is not scheduled at the completed implementation-unit boundary'

PROJECTS="$TMP_DIR/projects"
PROJECT=Alpha
mkdir -p "$PROJECTS/$PROJECT/stage1-planning/outputs" \
  "$PROJECTS/$PROJECT/stage2-requirements/outputs" "$PROJECTS/$PROJECT/tracking"
printf '%s\n' '# Dashboard' > "$PROJECTS/$PROJECT/Dashboard.md"
printf '%s\n' 'schema_version: 5' 'revision: 1' > \
  "$PROJECTS/$PROJECT/tracking/product-ci-profile.yaml"
RUN_CYCLE=('s1-pm:/vision' 's2-ba:/extract-requirements')
RUN_OPTIONAL=(0 0)
BASE_PROFILE='codex||||'
EXECUTION_STEP_PROFILES=("$BASE_PROFILE" "$BASE_PROFILE")
EXECUTION_STEP_SOURCES=(single single)
USE_EXISTING_FROZEN_ROUTES=1
EXECUTION_TYPE=CYCLE
EXECUTION_SCOPE='automatic boundary test'
EXECUTION_EXCLUDED='none'
EXECUTION_TITLE='Automatic boundary test'
EXECUTION_CYCLE_ID=1
ORDER="$TMP_DIR/order"

run_agent() {
  printf 'agent:%s:%s\n' "$1" "$3" >> "$ORDER"
  case "$1:$3" in
    's1-pm:/vision')
      write_artifact_metadata_fixture \
        "$PROJECTS/$PROJECT/stage1-planning/outputs/PM-2026-07-27-vision.md" \
        "$PROJECTS/$PROJECT" PM-VISION-001 vision S1 s1-pm none APPROVED Vision ;;
    's2-ba:/extract-requirements')
      write_artifact_metadata_fixture \
        "$PROJECTS/$PROJECT/stage2-requirements/outputs/BA-2026-07-27-BRD.md" \
        "$PROJECTS/$PROJECT" BA-BRD-001 brd S2 s2-ba none APPROVED BRD ;;
  esac
}
run_cycle1_gate_validator() {
  printf 'gate:%s\n' "$1" >> "$ORDER"
  printf '%s\n' 'PR EVIDENCE VERIFIED: source=fixture evidence_ids=EV-UNIT,EV-SECRETS'
}
run_cycle1_software_dod_validator() { printf '%s\n' dod >> "$ORDER"; }

execute_previewed_cycle >/dev/null || fail 'valid boundary fixture did not complete'
mapfile -t order < "$ORDER"
[[ "${order[*]}" == 'agent:s1-pm:/vision gate:1 agent:s2-ba:/extract-requirements' ]] ||
  fail "Gate 1 did not execute exactly before Stage 2: ${order[*]}"
events="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/events.jsonl"
grep -Eq '"event":"gate_pass".*"step_status":"GATE_PASS".*"task":"Gate 1"' "$events" ||
  fail 'Gate PASS was not journaled separately from artifact verification'
grep -Fq 'evidence_ids=EV-UNIT,EV-SECRETS' "$events" ||
  fail 'Gate event did not retain concise evidence ids from deterministic verifier'

echo 'PASS: launcher gate orchestration smoke'

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-tdd-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

AGENT_RUNTIME=codex
CODEX_BIN=/bin/true
SDLC_RUNTIME_ROUTING=single
SDLC_SUBAGENTS=off
SDLC_SUBAGENT_MAX=2
source "$ROOT/sdlc.sh"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"

# This unit fixture isolates TDD ordering/result verification. Change Scope pre/postflight has
# its own positive/negative launcher smoke and is stubbed here so the mocked runtime can focus
# on the repair sequence.
prepare_change_scope_step() { return 0; }
verify_change_scope_step() { return 0; }

PROJECTS="$TMP_DIR/projects"
PROJECT="demo"
STATUS_FILE="$PROJECTS/$PROJECT/stage4-dev/outputs/QA-TDD-status.md"
CALLS_FILE="$TMP_DIR/calls"
mkdir -p "$(dirname "$STATUS_FILE")"
BASE_PROFILE="codex||||"
SOURCE_REVISION=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

write_status() {
  local status="$1" failed="${2:-0}" source="${3:-$SOURCE_REVISION}"
  local regression=not-yet-run manifest=none digest=none expected=0 executed=0 red='expected functional failure'
  mkdir -p "$PROJECTS/$PROJECT/tests"
  if [[ "$status" == PASS || "$status" == FAIL ]]; then
    regression=full-affected
    manifest=stage4-dev/outputs/QA-affected-tests-v1.tsv
    printf '%s\n' 'native test' > "$PROJECTS/$PROJECT/tests/test_feature.txt"
    {
      printf '%s\n' $'test_id\ttest_uri\tchange_id\tresult\tsource_revision'
      printf 'TEST-001\ttests/test_feature.txt\tFR-001\t%s\t%s\n' \
        "$([[ "$status" == PASS ]] && printf PASS || printf FAIL)" "$source"
    } > "$PROJECTS/$PROJECT/$manifest"
    digest="$(sha256sum "$PROJECTS/$PROJECT/$manifest" | awk '{print $1}')"
    expected=1; executed=1; red=none
  fi
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: tdd-status' "status: $status" 'project: demo' 'scope: FR-001' \
      "source_revision: $source" 'test_command: make test-affected' "red_evidence: $red" \
      'last_run: 2026-07-27T12:00:00Z' "failed_tests: $failed" 'repair_iteration: 0' \
      "regression_scope: $regression" "affected_test_manifest: $manifest" \
      "affected_test_manifest_sha256: $digest" "expected_test_count: $expected" \
      "executed_test_count: $executed" '---' '' '# TDD Status'
  } > "$STATUS_FILE"
  complete_artifact_metadata_fixture "$STATUS_FILE" "$PROJECTS/$PROJECT" \
    QA-TDD-STATUS-V1 S4 s4-qa-auto "$source" "$status"
}

write_status RED 0 missing
if require_tdd_red >/dev/null 2>&1; then
  fail "require_tdd_red accepted a non-exact source revision"
fi
write_status RED
require_tdd_red || fail "require_tdd_red rejected RED"
write_status PASS
if require_tdd_red >/dev/null 2>&1; then
  fail "require_tdd_red accepted PASS before initial implementation"
fi

run_agent() {
  local agent="$1" task="$3"
  printf '%s:%s\n' "$agent" "$task" >> "$CALLS_FILE"
  case "$agent:$task" in
    's4-dev:/dev-report')
      write_artifact_metadata_fixture \
        "$PROJECTS/$PROJECT/stage4-dev/outputs/DEV-2026-07-27-PR-1-summary.md" \
        "$PROJECTS/$PROJECT" DEV-PR-1 dev-pr-summary S4 s4-dev "$SOURCE_REVISION" PASS "PR summary $RANDOM"
      write_artifact_metadata_fixture \
        "$PROJECTS/$PROJECT/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR1.md" \
        "$PROJECTS/$PROJECT" DEV-UPDATE-PR1 update-notes S4 s4-dev "$SOURCE_REVISION" PASS "Update notes $RANDOM"
      ;;
    's4-qa-auto:/run-tests')
      write_artifact_metadata_fixture \
        "$PROJECTS/$PROJECT/stage4-dev/outputs/QA-2026-07-27-tdd-report.md" \
        "$PROJECTS/$PROJECT" QA-TDD-REPORT-V1 tdd-report S4 s4-qa-auto "$SOURCE_REVISION" PASS "TDD report $RANDOM"
      write_status PASS
      ;;
  esac
  return 0
}

write_status FAIL 1
TDD_MAX_REPAIR_ITERATIONS=3 run_tdd_repair_loop ||
  fail "repair loop did not recover FAIL to PASS"
[[ "$(read_tdd_status)" == "PASS" ]] || fail "repair loop did not persist PASS"
[[ "$(sed -n '1p' "$CALLS_FILE")" == "s4-dev:/dev-report" ]] ||
  fail "repair loop did not return to s4-dev first"
[[ "$(sed -n '2p' "$CALLS_FILE")" == "s4-qa-auto:/run-tests" ]] ||
  fail "repair loop did not rerun independent tests second"

cycle1_pr_evidence_check() {
  printf '%s\n' 'PR EVIDENCE VERIFIED: source=fixture evidence_ids=EV-UNIT'
}
cycle1_evidence_summary() {
  printf '%s\n' '# Verified summary' '- source: exact'
}
prepare_cycle1_techlead_evidence > "$TMP_DIR/techlead-evidence.out" ||
  fail 'launcher did not prepare Tech Lead evidence handoff'
[[ -f "$PROJECTS/$PROJECT/stage4-dev/outputs/EVIDENCE-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.md" ]] ||
  fail 'Tech Lead evidence summary was not written to the exact-source path'
grep -Fq 'EVIDENCE SUMMARY VERIFIED' "$TMP_DIR/techlead-evidence.out" ||
  fail 'Tech Lead evidence handoff did not emit verified summary status'

rm "$PROJECTS/$PROJECT/stage4-dev/outputs/EVIDENCE-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.md"
cycle1_pr_evidence_check() { return 1; }
if prepare_cycle1_techlead_evidence >/dev/null 2>&1; then
  fail 'Tech Lead handoff accepted failed PR evidence'
fi
[[ ! -e "$PROJECTS/$PROJECT/stage4-dev/outputs/EVIDENCE-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.md" ]] ||
  fail 'failed PR evidence still produced a Tech Lead summary'

run_agent() {
  return 0
}

write_status FAIL 1
if TDD_MAX_REPAIR_ITERATIONS=2 run_tdd_repair_loop >/dev/null 2>&1; then
  fail "repair loop silently passed after exhausting its limit"
fi
[[ "$(read_tdd_status)" == "BLOCKED" ]] ||
  fail "exhausted repair loop did not persist BLOCKED"

write_status PASS 0 stale
if run_tdd_repair_loop >/dev/null 2>&1; then
  fail "repair loop accepted PASS without an exact source revision"
fi

echo "PASS: TDD orchestration smoke"

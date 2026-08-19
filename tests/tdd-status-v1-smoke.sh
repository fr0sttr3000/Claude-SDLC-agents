#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-tdd-status.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECK="$ROOT/cycle1-dev/s0-validate/tdd-status-check.sh"
SOURCE=4444444444444444444444444444444444444444
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_manifest() {
  local project="$1" second_result="${2:-PASS}"
  mkdir -p "$project/stage4-dev/outputs" "$project/tests/unit" "$project/tests/integration"
  printf '%s\n' 'FR-001 test' > "$project/tests/unit/test_plan.txt"
  printf '%s\n' 'FR-002 test' > "$project/tests/integration/test_invite.txt"
  {
    printf '%s\n' $'test_id\ttest_uri\tchange_id\tresult\tsource_revision'
    printf 'TEST-001\ttests/unit/test_plan.txt\tFR-001\tPASS\t%s\n' "$SOURCE"
    printf 'TEST-002\ttests/integration/test_invite.txt\tFR-002\t%s\t%s\n' "$second_result" "$SOURCE"
  } > "$project/stage4-dev/outputs/QA-affected-tests-v1.tsv"
}

write_status() {
  local project="$1" status="$2" regression="$3" failed="$4" expected="$5" executed="$6"
  local manifest=none digest=none red='none'
  if [[ "$regression" == full-affected || "$regression" == selective ]]; then
    manifest=stage4-dev/outputs/QA-affected-tests-v1.tsv
    digest="$(sha256sum "$project/$manifest" | awk '{print $1}')"
  fi
  [[ "$status" != RED ]] || red='missing functionality produced the expected assertion failure'
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: tdd-status' "status: $status" "project: $(basename "$project")" \
      'scope: FR-001,FR-002' "source_revision: $SOURCE" 'test_command: make test-affected' \
      "red_evidence: $red" 'last_run: 2026-07-27T12:00:00Z' "failed_tests: $failed" \
      'repair_iteration: 0' "regression_scope: $regression" \
      "affected_test_manifest: $manifest" "affected_test_manifest_sha256: $digest" \
      "expected_test_count: $expected" "executed_test_count: $executed" '---' '' '# TDD Status'
  } > "$project/stage4-dev/outputs/QA-TDD-status.md"
  complete_artifact_metadata_fixture "$project/stage4-dev/outputs/QA-TDD-status.md" \
    "$project" QA-TDD-STATUS-V1 S4 s4-qa-auto "$SOURCE" "$status"
}

expect_blocked() {
  local label="$1" project="$2" output="$3"
  if bash "$CHECK" "$project" >"$output" 2>&1; then fail "$label"; fi
  grep -Fq 'TDD STATUS BLOCKED' "$output" || fail "$label did not emit BLOCKED"
}

P_PASS="$TMP_DIR/pass"
write_manifest "$P_PASS"
write_status "$P_PASS" PASS full-affected 0 2 2
bash "$CHECK" "$P_PASS" PASS > "$TMP_DIR/pass.out" || fail 'valid full affected PASS was rejected'
grep -Fq 'TDD STATUS VERIFIED' "$TMP_DIR/pass.out" || fail 'verified verdict missing'

P_RED="$TMP_DIR/red"
mkdir -p "$P_RED/stage4-dev/outputs"
write_status "$P_RED" RED not-yet-run 0 0 0
bash "$CHECK" "$P_RED" RED >/dev/null || fail 'valid pre-Green RED was rejected'

P_RED_ENV="$TMP_DIR/red-environment-error"
cp -a "$P_RED" "$P_RED_ENV"
sed -i \
  -e 's/^project: red$/project: red-environment-error/' \
  -e 's/^red_evidence:.*/red_evidence: environment setup failed before the test runner started/' \
  "$P_RED_ENV/stage4-dev/outputs/QA-TDD-status.md"
expect_blocked 'environment/setup failure was accepted as functional RED' \
  "$P_RED_ENV" "$TMP_DIR/red-environment-error.out"

P_SELECTIVE="$TMP_DIR/selective"
write_manifest "$P_SELECTIVE"
write_status "$P_SELECTIVE" PASS selective 0 2 2
expect_blocked 'selective PASS was accepted' "$P_SELECTIVE" "$TMP_DIR/selective.out"

P_SKIPPED="$TMP_DIR/skipped"
write_manifest "$P_SKIPPED" SKIPPED
write_status "$P_SKIPPED" PASS full-affected 0 2 2
expect_blocked 'PASS with skipped affected test was accepted' "$P_SKIPPED" "$TMP_DIR/skipped.out"

P_COUNT="$TMP_DIR/count"
write_manifest "$P_COUNT"
write_status "$P_COUNT" PASS full-affected 0 2 1
expect_blocked 'PASS with incomplete executed count was accepted' "$P_COUNT" "$TMP_DIR/count.out"

P_SCOPE="$TMP_DIR/scope"
write_manifest "$P_SCOPE"
sed -i '/FR-002/d' "$P_SCOPE/stage4-dev/outputs/QA-affected-tests-v1.tsv"
write_status "$P_SCOPE" PASS full-affected 0 1 1
expect_blocked 'PASS omitted a declared change from affected set' "$P_SCOPE" "$TMP_DIR/scope.out"

P_TAMPER="$TMP_DIR/tamper"
write_manifest "$P_TAMPER"
write_status "$P_TAMPER" PASS full-affected 0 2 2
printf '%s\n' '# tampered' >> "$P_TAMPER/stage4-dev/outputs/QA-affected-tests-v1.tsv"
expect_blocked 'tampered affected manifest was accepted' "$P_TAMPER" "$TMP_DIR/tamper.out"

grep -Fq 'tdd-status-check.sh' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" ||
  fail 'Gate 4 does not invoke TDD status validator'

echo 'PASS: TDD Status v1 smoke'

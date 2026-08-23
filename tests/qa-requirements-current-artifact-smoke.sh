#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-qa-current.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECK="$ROOT/cycle1-dev/s0-validate/qa-requirements-review-check.sh"
PLAN_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
HEADER=$'schema_version\tlogical_id\tmember_index\tartifact_ref\tartifact_sha256\tproducer\tcommand\toutput_group\tsource_revision\tproduct_profile_revision\trun_id\tplan_sha256\trecorded_at'

fail() { echo "FAIL: $*" >&2; exit 1; }

expect_blocked() {
  local label="$1" project="$2" output="$3"
  if bash "$CHECK" "$project" >"$output" 2>&1; then fail "$label"; fi
  grep -Fq 'QA REQUIREMENTS REVIEW BLOCKED' "$output" ||
    fail "$label did not emit QA REQUIREMENTS REVIEW BLOCKED"
}

write_profile() {
  local project="$1"
  mkdir -p "$project/tracking" "$project/stage2-requirements/outputs"
  printf '%s\n' 'schema_version: 5' 'revision: 1' > \
    "$project/tracking/product-ci-profile.yaml"
}

write_review() {
  local project="$1" date="$2"
  printf '%s\n' '# Requirements review' 'QA contribution: PASS' > \
    "$project/stage2-requirements/outputs/QA-REQ-$date-review.md"
}

write_decision() {
  local project="$1" ref="$2" digest
  digest="$(sha256sum "$project/$ref" | awk '{print $1}')"
  printf '%s\n' 'schema_version: 1' 'review_id: QA-REQ-001' 'status: PASS' \
    "project: $(basename "$project")" 'owner: s2-qa-req' \
    'product_profile_revision: 1' 'reviewed_at: 2026-08-23T12:00:00Z' \
    "review_ref: $ref" "review_sha256: $digest" 'blocker_count: 0' > \
    "$project/stage2-requirements/outputs/QA-REQ-review-v1.yaml"
}

write_valid() {
  local project="$1"
  write_profile "$project"
  write_review "$project" 2026-08-23
  write_decision "$project" stage2-requirements/outputs/QA-REQ-2026-08-23-review.md
}

append_current_row() {
  local project="$1" logical="$2" ref="$3" group="$4" digest
  digest="$(sha256sum "$project/$ref" | awk '{print $1}')"
  printf '1\t%s\t1\t%s\t%s\ts2-qa-req\t/testability-review\t%s\tnone\t1\tRUN-QA\t%s\t2026-08-23T12:00:00Z\n' \
    "$logical" "$ref" "$digest" "$group" "$PLAN_SHA" >> \
    "$project/tracking/current-artifacts-v1.tsv"
}

write_manifest() {
  local project="$1" review_ref="$2" include_decision="$3" include_review="$4"
  printf '%s\n' "$HEADER" > "$project/tracking/current-artifacts-v1.tsv"
  if [[ "$include_decision" == yes ]]; then
    append_current_row "$project" qa-requirements-decision \
      stage2-requirements/outputs/QA-REQ-review-v1.yaml 2
  fi
  if [[ "$include_review" == yes ]]; then
    append_current_row "$project" qa-requirements-review "$review_ref" 1
  fi
}

P_VALID="$TMP_DIR/valid-manifest"
write_valid "$P_VALID"
write_review "$P_VALID" 2026-08-22
write_manifest "$P_VALID" stage2-requirements/outputs/QA-REQ-2026-08-23-review.md yes yes
bash "$CHECK" "$P_VALID" >"$TMP_DIR/valid.out" ||
  fail 'manifest-selected QA decision/review was rejected because retained history exists'

P_LEGACY="$TMP_DIR/legacy"
write_valid "$P_LEGACY"
bash "$CHECK" "$P_LEGACY" >"$TMP_DIR/legacy.out" 2>"$TMP_DIR/legacy.err" ||
  fail 'unique legacy QA decision/review was rejected'
grep -Fq 'LEGACY / UNVERIFIED' "$TMP_DIR/legacy.err" ||
  fail 'legacy QA resolution was not disclosed'

P_MISSING_REVIEW="$TMP_DIR/missing-current-review"
write_valid "$P_MISSING_REVIEW"
write_manifest "$P_MISSING_REVIEW" stage2-requirements/outputs/QA-REQ-2026-08-23-review.md yes no
expect_blocked 'manifest without current QA review fell back to the matching Markdown file' \
  "$P_MISSING_REVIEW" "$TMP_DIR/missing-review.out"

P_MISSING_DECISION="$TMP_DIR/missing-current-decision"
write_valid "$P_MISSING_DECISION"
write_manifest "$P_MISSING_DECISION" stage2-requirements/outputs/QA-REQ-2026-08-23-review.md no yes
expect_blocked 'manifest without current QA decision fell back to the fixed YAML name' \
  "$P_MISSING_DECISION" "$TMP_DIR/missing-decision.out"

P_STALE_DECISION="$TMP_DIR/stale-decision"
write_valid "$P_STALE_DECISION"
write_manifest "$P_STALE_DECISION" stage2-requirements/outputs/QA-REQ-2026-08-23-review.md yes yes
printf '%s\n' '# harmless-to-schema tamper' >> \
  "$P_STALE_DECISION/stage2-requirements/outputs/QA-REQ-review-v1.yaml"
expect_blocked 'stale manifest digest for QA decision was ignored' \
  "$P_STALE_DECISION" "$TMP_DIR/stale-decision.out"

P_WRONG_REVIEW="$TMP_DIR/noncurrent-review-ref"
write_valid "$P_WRONG_REVIEW"
write_review "$P_WRONG_REVIEW" 2026-08-22
write_decision "$P_WRONG_REVIEW" stage2-requirements/outputs/QA-REQ-2026-08-22-review.md
write_manifest "$P_WRONG_REVIEW" stage2-requirements/outputs/QA-REQ-2026-08-23-review.md yes yes
expect_blocked 'QA decision was allowed to bind a historical non-current review' \
  "$P_WRONG_REVIEW" "$TMP_DIR/noncurrent-review.out"

grep -Fq 'qa-requirements-review-check.sh' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" ||
  fail 'Gate 2 does not invoke QA requirements review validator'

echo 'PASS: QA requirements current-artifact smoke'

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-current-artifact.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/CurrentFixture"
CHECK="$ROOT/cycle1-dev/s0-validate/current-artifact.sh"
PLAN1="$(printf run-1 | sha256sum | awk '{print $1}')"
PLAN2="$(printf run-2 | sha256sum | awk '{print $1}')"

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_blocked() {
  local label="$1"; shift
  if "$@" >"$TMP_DIR/blocked.out" 2>&1; then fail "$label"; fi
  grep -Fq 'CURRENT ARTIFACT BLOCKED' "$TMP_DIR/blocked.out" ||
    fail "$label did not emit BLOCKED"
}

mkdir -p "$PROJECT/tracking/product-ci-profile-history" "$PROJECT/stage1-planning/outputs"
printf '%s\n' 'schema_version: 5' 'revision: 1' > "$PROJECT/tracking/product-ci-profile.yaml"
printf '%s\n' 'old vision' > "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md"

bash "$CHECK" update "$PROJECT" s1-pm /vision RUN-ONE "$PLAN1" \
  stage1-planning/outputs/PM-2026-07-28-vision.md >"$TMP_DIR/update1.out"
grep -Fq 'CURRENT ARTIFACTS UPDATED' "$TMP_DIR/update1.out" || fail 'first update verdict missing'
[[ "$(bash "$CHECK" resolve-one "$PROJECT" product-vision)" == stage1-planning/outputs/PM-2026-07-28-vision.md ]] ||
  fail 'run one ref not resolved'

printf '%s\n' 'revised vision at the same registered path' > \
  "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md"
bash "$CHECK" update "$PROJECT" s1-pm /vision RUN-ONE "$PLAN1" \
  stage1-planning/outputs/PM-2026-07-28-vision.md >/dev/null ||
  fail 'updater rejected a legitimate replacement of the same current path'
bash "$CHECK" validate "$PROJECT" >/dev/null ||
  fail 'same-path replacement did not refresh the current digest'

printf '%s\n' 'charter' > "$PROJECT/stage1-planning/outputs/PMO-2026-07-28-charter.md"
printf '%s\n' 'constraints' > "$PROJECT/tracking/PMO-constraints.md"
bash "$CHECK" update "$PROJECT" s1-pmo /charter RUN-ONE "$PLAN1" \
  stage1-planning/outputs/PMO-2026-07-28-charter.md,tracking/PMO-constraints.md >/dev/null
cp "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md" "$TMP_DIR/vision.valid"
cp "$PROJECT/stage1-planning/outputs/PMO-2026-07-28-charter.md" "$TMP_DIR/charter.valid"
cp "$PROJECT/tracking/PMO-constraints.md" "$TMP_DIR/constraints.valid"
printf '%s\n' 'unrelated tamper' >> "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md"
printf '%s\n' 'revised charter' > "$PROJECT/stage1-planning/outputs/PMO-2026-07-28-charter.md"
printf '%s\n' 'revised constraints' > "$PROJECT/tracking/PMO-constraints.md"
expect_blocked 'updater ignored tampering outside its replaced logical id' \
  bash "$CHECK" update "$PROJECT" s1-pmo /charter RUN-ONE "$PLAN1" \
  stage1-planning/outputs/PMO-2026-07-28-charter.md,tracking/PMO-constraints.md
cp "$TMP_DIR/vision.valid" "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md"
cp "$TMP_DIR/charter.valid" "$PROJECT/stage1-planning/outputs/PMO-2026-07-28-charter.md"
cp "$TMP_DIR/constraints.valid" "$PROJECT/tracking/PMO-constraints.md"

printf '%s\n' 'new vision' > "$PROJECT/stage1-planning/outputs/PM-2026-07-29-vision.md"
bash "$CHECK" begin-run "$PROJECT" RUN-TWO "$PLAN2" >/dev/null
if bash "$CHECK" resolve-one "$PROJECT" product-vision >/dev/null 2>&1; then
  fail 'new full-cycle generation retained a prior-run current row'
fi
bash "$CHECK" update "$PROJECT" s1-pm /vision RUN-TWO "$PLAN2" \
  stage1-planning/outputs/PM-2026-07-29-vision.md >/dev/null
[[ "$(bash "$CHECK" resolve-one "$PROJECT" product-vision RUN-TWO)" == stage1-planning/outputs/PM-2026-07-29-vision.md ]] ||
  fail 'second run did not replace current ref'
[[ -f "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md" ]] ||
  fail 'historical artifact was removed'

printf '%s\n' 'historical mutation is outside current selection' \
  >> "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md"
bash "$CHECK" validate "$PROJECT" >/dev/null ||
  fail 'historical non-current file affected current validation'

printf '%s\n' 'tampered current' >> "$PROJECT/stage1-planning/outputs/PM-2026-07-29-vision.md"
expect_blocked 'current artifact digest tampering was accepted' \
  bash "$CHECK" validate "$PROJECT"

rm -f "$PROJECT/tracking/current-artifacts-v1.tsv"
rm -f "$PROJECT/stage1-planning/outputs/PM-2026-07-28-vision.md"
[[ "$(bash "$CHECK" resolve-compatible-one "$PROJECT" product-vision 2>"$TMP_DIR/legacy.err")" == stage1-planning/outputs/PM-2026-07-29-vision.md ]] ||
  fail 'unique legacy artifact did not resolve'
grep -Fq 'LEGACY / UNVERIFIED' "$TMP_DIR/legacy.err" || fail 'legacy resolution was not disclosed'
printf '%s\n' 'another historical vision' > "$PROJECT/stage1-planning/outputs/PM-2026-07-30-vision.md"
expect_blocked 'ambiguous legacy history was accepted' \
  bash "$CHECK" resolve-compatible-one "$PROJECT" product-vision

rm -f "$PROJECT/stage1-planning/outputs/PM-2026-07-30-vision.md"
printf '%s\n' 'schema_version: 5' 'revision: 2' > "$PROJECT/tracking/product-ci-profile.yaml"
cp "$PROJECT/tracking/product-ci-profile.yaml" \
  "$PROJECT/tracking/product-ci-profile-history/revision-2.yaml"
bash "$CHECK" update "$PROJECT" s0-kickoff /product-ci-profile PROFILE-TWO "$PLAN2" \
  tracking/product-ci-profile.yaml,tracking/product-ci-profile-history/revision-2.yaml >/dev/null
[[ "$(bash "$CHECK" resolve-one "$PROJECT" product-ci-profile PROFILE-TWO)" == tracking/product-ci-profile.yaml ]] ||
  fail 'profile revision update did not reset current manifest'
if bash "$CHECK" resolve-one "$PROJECT" product-vision >/dev/null 2>&1; then
  fail 'old-profile current artifact survived profile revision change'
fi

printf '%s\n' 'schema_version: 5' 'revision: 3' > "$PROJECT/tracking/product-ci-profile.yaml"
bash "$CHECK" begin-run "$PROJECT" RUN-THREE "$PLAN1" >/dev/null ||
  fail 'begin-run rejected a valid manifest from the previous Product Profile revision'
[[ "$(wc -l < "$PROJECT/tracking/current-artifacts-v1.tsv")" -eq 1 ]] ||
  fail 'profile-revision begin-run did not reset the current selection'
[[ -f "$PROJECT/stage1-planning/outputs/PM-2026-07-29-vision.md" ]] ||
  fail 'profile-revision begin-run removed historical artifacts'

PR_PROJECT="$TMP_DIR/PrSetFixture"
PR_SOURCE=2222222222222222222222222222222222222222
PR_SOURCE_REVISED=4444444444444444444444444444444444444444
mkdir -p "$PR_PROJECT/tracking" "$PR_PROJECT/stage4-dev/outputs"
printf '%s\n' 'schema_version: 5' 'revision: 1' > \
  "$PR_PROJECT/tracking/product-ci-profile.yaml"
write_pr_pair() {
  local pr="$1" date="$2" source="$3"
  printf 'source_revision: %s\nPR %s summary\n' "$source" "$pr" > \
    "$PR_PROJECT/stage4-dev/outputs/DEV-$date-PR-$pr-summary.md"
  printf 'source_revision: %s\nPR %s update notes\n' "$source" "$pr" > \
    "$PR_PROJECT/stage4-dev/outputs/DEV-$date-update-notes-PR$pr.md"
  bash "$CHECK" update "$PR_PROJECT" s4-dev /dev-report RUN-PR "$PLAN1" \
    "stage4-dev/outputs/DEV-$date-PR-$pr-summary.md,stage4-dev/outputs/DEV-$date-update-notes-PR$pr.md" \
    >/dev/null
}
write_pr_review() {
  local pr="$1" date="$2" source="$3"
  printf 'source_revision: %s\nstatus: PASS\nAPPROVED\n' "$source" > \
    "$PR_PROJECT/stage4-dev/outputs/TL-$date-review-PR$pr.md"
  bash "$CHECK" update "$PR_PROJECT" s4-techlead /review RUN-PR "$PLAN1" \
    "stage4-dev/outputs/TL-$date-review-PR$pr.md" >/dev/null
}
for pr in 2 1 3; do
  write_pr_pair "$pr" 2026-08-17 "$PR_SOURCE"
  write_pr_review "$pr" 2026-08-17 "$PR_SOURCE"
done
[[ "$(bash "$CHECK" resolve "$PR_PROJECT" development-pr-summary | wc -l)" -eq 3 ]] ||
  fail 'incremental PR summaries did not preserve the complete three-member set'
[[ "$(bash "$CHECK" resolve "$PR_PROJECT" development-update-notes | wc -l)" -eq 3 ]] ||
  fail 'incremental PR update notes did not preserve the complete three-member set'
[[ "$(bash "$CHECK" resolve "$PR_PROJECT" techlead-reviews | wc -l)" -eq 3 ]] ||
  fail 'incremental PR reviews did not preserve the complete three-member set'

write_pr_pair 2 2026-08-18 "$PR_SOURCE_REVISED"
write_pr_review 2 2026-08-18 "$PR_SOURCE_REVISED"
mapfile -t current_summaries < <(bash "$CHECK" resolve "$PR_PROJECT" development-pr-summary)
mapfile -t current_notes < <(bash "$CHECK" resolve "$PR_PROJECT" development-update-notes)
mapfile -t current_reviews < <(bash "$CHECK" resolve "$PR_PROJECT" techlead-reviews)
[[ ${#current_summaries[@]} -eq 3 && ${#current_notes[@]} -eq 3 &&
  ${#current_reviews[@]} -eq 3 ]] ||
  fail 're-reviewing PR 2 changed full-set cardinality'
[[ " ${current_summaries[*]} " == *' stage4-dev/outputs/DEV-2026-08-18-PR-2-summary.md '* &&
  " ${current_summaries[*]} " != *' stage4-dev/outputs/DEV-2026-08-17-PR-2-summary.md '* ]] ||
  fail 'PR 2 summary member key was not deterministically replaced'
[[ " ${current_notes[*]} " == *' stage4-dev/outputs/DEV-2026-08-18-update-notes-PR2.md '* &&
  " ${current_reviews[*]} " == *' stage4-dev/outputs/TL-2026-08-18-review-PR2.md '* ]] ||
  fail 'PR 2 notes/review member keys were not deterministically replaced'
[[ -f "$PR_PROJECT/stage4-dev/outputs/TL-2026-08-17-review-PR2.md" ]] ||
  fail 're-review removed immutable historical PR 2 evidence'

for current_pr3 in \
  "$PR_PROJECT/stage4-dev/outputs/DEV-2026-08-17-PR-3-summary.md" \
  "$PR_PROJECT/stage4-dev/outputs/DEV-2026-08-17-update-notes-PR3.md" \
  "$PR_PROJECT/stage4-dev/outputs/TL-2026-08-17-review-PR3.md"; do
  mv "$current_pr3" "$TMP_DIR/${current_pr3##*/}"
done
expect_blocked 'deleting a PR member set without a new recorded inventory was accepted' \
  bash "$CHECK" validate "$PR_PROJECT"
for current_pr3 in \
  DEV-2026-08-17-PR-3-summary.md \
  DEV-2026-08-17-update-notes-PR3.md \
  TL-2026-08-17-review-PR3.md; do
  mv "$TMP_DIR/$current_pr3" "$PR_PROJECT/stage4-dev/outputs/$current_pr3"
done
bash "$CHECK" validate "$PR_PROJECT" >/dev/null ||
  fail 'restored complete PR inventory did not validate'

printf 'source_revision: %s\nduplicate key candidate\n' "$PR_SOURCE" > \
  "$PR_PROJECT/stage4-dev/outputs/DEV-2026-08-19-PR-1-summary.md"
printf 'source_revision: %s\nduplicate key candidate\n' "$PR_SOURCE" > \
  "$PR_PROJECT/stage4-dev/outputs/DEV-2026-08-20-PR-1-summary.md"
printf 'source_revision: %s\nnotes candidate\n' "$PR_SOURCE" > \
  "$PR_PROJECT/stage4-dev/outputs/DEV-2026-08-19-update-notes-PR1.md"
expect_blocked 'one invocation accepted duplicate stable PR member keys' \
  bash "$CHECK" update "$PR_PROJECT" s4-dev /dev-report RUN-PR "$PLAN1" \
  stage4-dev/outputs/DEV-2026-08-19-PR-1-summary.md,stage4-dev/outputs/DEV-2026-08-20-PR-1-summary.md,stage4-dev/outputs/DEV-2026-08-19-update-notes-PR1.md

bash -c '
  source "$1"
  cycle1_tracks_current_outputs s1-pm /vision
  ! cycle1_tracks_current_outputs s0-tracker /report
  ! cycle1_tracks_current_outputs s0-tracker "/release-notes v1.2.3"
' _ "$ROOT/sdlc.sh" || fail 'launcher track_current predicate diverges from output registry'

DOD_CHECK="$ROOT/cycle1-dev/s0-validate/dod-check.sh"
grep -Fq 'current_refs techlead-reviews' "$DOD_CHECK" ||
  fail 'automated DoD does not resolve current Tech Lead reviews'
grep -Fq 'current_one development-update-notes' "$DOD_CHECK" ||
  fail 'automated DoD does not resolve current update notes'
if rg -q 'ls .*TL-|ls .*update-notes|ls .*PERF-' "$DOD_CHECK"; then
  fail 'automated DoD still selects historical artifacts with ls/head'
fi
GATE1_CHECK="$ROOT/cycle1-dev/s0-validate/gate1-planning-check.sh"
DOR_CHECK="$ROOT/cycle1-dev/s0-validate/dor-check.sh"
grep -Fq 'resolve_current_one feasibility-study' "$GATE1_CHECK" ||
  fail 'Gate 1 planning still infers current feasibility from a glob'
grep -Fq 'current_one_path business-requirements' "$DOR_CHECK" ||
  fail 'DoR content checks do not use current logical requirements'
if rg -q 'first_match|feasibility=\("\$OUTPUTS"' "$GATE1_CHECK" "$DOR_CHECK"; then
  fail 'Gate validators still contain first-match historical artifact selection'
fi

echo 'PASS: Current Artifacts v1 smoke'

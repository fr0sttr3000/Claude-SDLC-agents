#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-artifact-metadata.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/MetadataFixture"
CHECK="$ROOT/cycle1-dev/s0-validate/artifact-metadata-check.sh"
SOURCE=7777777777777777777777777777777777777777

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_unverified() {
  local label="$1" output="$2"
  if bash "$CHECK" "$PROJECT" stage5-testing/outputs/QA-report.md >"$output" 2>&1; then fail "$label"; fi
  grep -Fq 'ARTIFACT METADATA UNVERIFIED' "$output" || fail "$label did not emit UNVERIFIED"
}

mkdir -p "$PROJECT/stage5-testing/outputs" "$PROJECT/tracking/validation"
printf '%s\n' '# Dashboard' > "$PROJECT/Dashboard.md"
printf '%s\n' '# Input' > "$PROJECT/tracking/validation/input.md"
write_valid() {
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_id: QA-REPORT-001' \
      'artifact_type: test-analysis' 'project: MetadataFixture' 'stage: S5' \
      'producer: s5-qa' "source_revision: $SOURCE" 'status: VALIDATED' \
      'inputs: tracking/validation/input.md' \
      'outputs: stage5-testing/outputs/QA-report.md' 'tags: sdlc,cycle1,stage5,qa' \
      '---' '' '# Test Analysis' '' '## Obsidian Links' \
      '- Dashboard: [[Dashboard]]' '- Inputs: [[tracking/validation/input]]' \
      '- Outputs: [[stage5-testing/outputs/QA-report]]'
  } > "$PROJECT/stage5-testing/outputs/QA-report.md"
}

write_valid
bash "$CHECK" "$PROJECT" stage5-testing/outputs/QA-report.md >/dev/null || fail 'valid metadata was rejected'

sed -i '/^producer:/d' "$PROJECT/stage5-testing/outputs/QA-report.md"
expect_unverified 'missing producer was accepted' "$TMP_DIR/producer.out"
write_valid
sed -i 's#inputs: tracking/validation/input.md#inputs: ../outside.md#' "$PROJECT/stage5-testing/outputs/QA-report.md"
expect_unverified 'path traversal was accepted' "$TMP_DIR/traversal.out"
write_valid
sed -i '/Dashboard: /d' "$PROJECT/stage5-testing/outputs/QA-report.md"
expect_unverified 'missing Dashboard link was accepted' "$TMP_DIR/dashboard.out"
write_valid
cp "$PROJECT/stage5-testing/outputs/QA-report.md" "$PROJECT/stage5-testing/outputs/QA-duplicate.md"
sed -i 's#outputs: stage5-testing/outputs/QA-report.md#outputs: stage5-testing/outputs/QA-duplicate.md#; s#\[\[stage5-testing/outputs/QA-report\]\]#[[stage5-testing/outputs/QA-duplicate]]#' \
  "$PROJECT/stage5-testing/outputs/QA-duplicate.md"
expect_unverified 'duplicate artifact_id was accepted' "$TMP_DIR/duplicate.out"
rm "$PROJECT/stage5-testing/outputs/QA-duplicate.md"
write_valid
sed -i 's/tags: sdlc,cycle1,stage5,qa/tags: sdlc,cycle1,qa/' "$PROJECT/stage5-testing/outputs/QA-report.md"
expect_unverified 'missing stage tag was accepted' "$TMP_DIR/stage-tag.out"
write_valid
sed -i '/^---$/,/^---$/d' "$PROJECT/stage5-testing/outputs/QA-report.md"
expect_unverified 'legacy Markdown was accepted as verified metadata' "$TMP_DIR/legacy.out"

export XDG_CONFIG_HOME="$TMP_DIR/config"
source "$ROOT/sdlc.sh"
PROJECTS="$TMP_DIR"
PROJECT=MetadataFixture
PROJECT_ROOT="$PROJECTS/$PROJECT"
before="$(declared_output_fingerprint s1-pm /vision)"
mkdir -p "$PROJECT_ROOT/stage1-planning/outputs"
printf '%s\n' '# Vision without metadata' > \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md"
if verify_declared_outputs s1-pm /vision "$before"; then
  fail 'launcher accepted changed Project Markdown without common metadata'
fi
[[ "$DECLARED_OUTPUT_REASON" == *'metadata invalid'* ]] ||
  fail 'launcher did not expose the metadata validation reason'
write_artifact_metadata_fixture \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md" "$PROJECT_ROOT" \
  PM-VISION-001 vision S1 s1-pm none APPROVED Vision
verify_declared_outputs s1-pm /vision "$before" ||
  fail "launcher rejected valid changed Project Markdown: $DECLARED_OUTPUT_REASON"
[[ "$DECLARED_OUTPUT_CHANGED_REFS" == 'stage1-planning/outputs/PM-2026-07-29-vision.md' ]] ||
  fail 'launcher did not retain the exact changed Markdown path'

owner_before="$(declared_output_fingerprint s1-pm /vision)"
sed -i 's/^producer: s1-pm$/producer: s2-ba/' \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md"
if verify_declared_outputs s1-pm /vision "$owner_before"; then
  fail 'launcher accepted metadata owned by a different producer'
fi
[[ "$DECLARED_OUTPUT_REASON" == *'producer mismatch'* ]] ||
  fail 'producer mismatch reason was not exposed'
write_artifact_metadata_fixture \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md" "$PROJECT_ROOT" \
  PM-VISION-001 vision S1 s1-pm none APPROVED Vision
sed -i 's/^stage: S1$/stage: S2/; s/stage1/stage2/' \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md"
if bash "$CHECK" "$PROJECT_ROOT" stage1-planning/outputs/PM-2026-07-29-vision.md \
  s1-pm S1 vision >/dev/null 2>&1; then
  fail 'registry-bound validator accepted a different stage'
fi
write_artifact_metadata_fixture \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md" "$PROJECT_ROOT" \
  PM-VISION-001 vision S1 s1-pm none APPROVED Vision
sed -i 's/^artifact_type: vision$/artifact_type: business-requirements/' \
  "$PROJECT_ROOT/stage1-planning/outputs/PM-2026-07-29-vision.md"
if bash "$CHECK" "$PROJECT_ROOT" stage1-planning/outputs/PM-2026-07-29-vision.md \
  s1-pm S1 vision,product-vision >/dev/null 2>&1; then
  fail 'registry-bound validator accepted a different artifact type'
fi

 mkdir -p "$PROJECT_ROOT/stage2-requirements/outputs"
for spec in "BRD|BA-BRD-001|business-requirements" "NFR|BA-NFR-001|nonfunctional-requirements" "RTM|BA-RTM-001|requirements-traceability"; do
  IFS="|" read -r suffix id type <<< "$spec"
  write_artifact_metadata_fixture "$PROJECT_ROOT/stage2-requirements/outputs/BA-2026-07-29-$suffix.md" "$PROJECT_ROOT" "$id" "$type" S2 s2-ba none APPROVED "$suffix"
done
brd_before="$(declared_output_fingerprint s2-ba /brd)"
printf '\nCurrent BRD change only.\n' >> "$PROJECT_ROOT/stage2-requirements/outputs/BA-2026-07-29-BRD.md"
if verify_declared_outputs s2-ba /brd "$brd_before"; then
  fail 'launcher accepted stale NFR/RTM groups'
fi
[[ "$DECLARED_OUTPUT_REASON" == *'stale declared output group'* ]] ||
  fail 'stale group reason was not exposed'

grep -Fq 'artifact-metadata-check.sh` must not be used on that platform scope' \
  "$ROOT/_standards/artifact-metadata.md" ||
  fail 'metadata standard does not explicitly exclude Platform governance Markdown'
if bash "$CHECK" "$ROOT" plans/roadmap.md >/dev/null 2>&1; then
  fail 'Project artifact validator accepted a Platform governance document'
fi

echo 'PASS: Artifact Metadata v1 smoke'

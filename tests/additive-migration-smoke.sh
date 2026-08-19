#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-additive-migration.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/Project With Spaces"
CHECK="$ROOT/cycle1-dev/s0-validate/legacy-migration-report.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$PROJECT/stage1-planning/outputs" "$PROJECT/tracking/evidence/legacy" \
  "$PROJECT/tracking/evidence/v1" "$PROJECT/stage6-deploy/outputs" "$PROJECT/stage7-ops/outputs"

printf '%s\n' '---' 'date: 2025-01-01' '---' '# Legacy plan' > "$PROJECT/stage1-planning/outputs/PM-legacy.md"
printf '%s\n' 'status: PASS' '# Self-attested result' > "$PROJECT/tracking/evidence/legacy/result.md"
printf '%s\n' 'schema_version: 1' 'evidence_id: EV-CURRENT' > "$PROJECT/tracking/evidence/v1/current.yaml"
printf '%s\n' '# Historical release' > "$PROJECT/stage6-deploy/outputs/REL-old.md"
printf '%s\n' '# Historical ops' > "$PROJECT/stage7-ops/outputs/SRE-old.md"
cat > "$PROJECT/tracking/current-view.md" <<'CURRENT'
---
schema_version: 1
artifact_id: CURRENT-VIEW
artifact_type: current-view
project: Project With Spaces
stage: TRACKING
producer: s0-validate
source_revision: none
status: UNVERIFIED
inputs: none
outputs: tracking/current-view.md
tags: sdlc,cycle1,tracking
---
# Current view
CURRENT

snapshot() {
  find "$PROJECT" -type f -print0 | sort -z | xargs -0 sha256sum
}

before="$(snapshot)"
bash "$CHECK" "$PROJECT" > "$TMP_DIR/report.tsv" 2> "$TMP_DIR/report.err"
after="$(snapshot)"

[[ "$before" == "$after" ]] || fail 'migration dry-run changed Project files'
grep -Fq $'stage1-planning/outputs/PM-legacy.md\tLEGACY_MARKDOWN\tUNVERIFIED\tUPGRADE_ON_OWNER_TOUCH' "$TMP_DIR/report.tsv" ||
  fail 'legacy Markdown was not classified as UNVERIFIED'
grep -Fq $'tracking/evidence/legacy/result.md\tLEGACY_SELF_ATTESTED_EVIDENCE\tUNVERIFIED\tNEVER_PROMOTE_PASS_REGENERATE_FROM_MACHINE_EVIDENCE' "$TMP_DIR/report.tsv" ||
  fail 'self-attested PASS was not rejected for automatic promotion'
grep -Fq $'tracking/evidence/v1/current.yaml\tCURRENT_MACHINE_EVIDENCE\tREVALIDATE_REQUIRED\tVALIDATE_EXACT_SOURCE_AND_POLICY' "$TMP_DIR/report.tsv" ||
  fail 'current machine evidence was not marked for revalidation'
grep -Fq $'tracking/current-view.md\tCURRENT_MARKDOWN\tVALIDATION_REQUIRED\tVALIDATE_WITH_OWNING_CONTRACT' "$TMP_DIR/report.tsv" ||
  fail 'current Artifact Metadata v1 Markdown was misclassified'
grep -Fq $'stage6-deploy/outputs/REL-old.md\tHISTORICAL_EXCLUDED\tEXCLUDED_FROM_ACTIVE_VERDICT\tPRESERVE_NO_ACTIVE_MIGRATION' "$TMP_DIR/report.tsv" ||
  fail 'historical Stage 6 artifact was not excluded from active verdict'
grep -Fq $'stage7-ops/outputs/SRE-old.md\tHISTORICAL_EXCLUDED\tEXCLUDED_FROM_ACTIVE_VERDICT\tPRESERVE_NO_ACTIVE_MIGRATION' "$TMP_DIR/report.tsv" ||
  fail 'historical Stage 7 artifact was not excluded from active verdict'
grep -Fq 'no Project files were changed' "$TMP_DIR/report.err" ||
  fail 'dry-run completion did not state its non-mutating boundary'

echo 'PASS: additive migration dry-run smoke'

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-product-acceptance.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROFILE_CHECK="$ROOT/cycle1-dev/s0-validate/product-ci-profile-check.sh"
ACCEPTANCE_CHECK="$ROOT/cycle1-dev/s0-validate/product-acceptance-check.sh"
CHECKS=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom
source "$ROOT/tests/lib/quality-characteristics-fixture.sh"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile_v3() {
  local project="$1" interface="$2" requirement="$3"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 3' 'revision: 1' 'previous_revision: 0'
    printf '%s\n' 'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: acceptance fixture'
    for pair in \
      'product_type=service' 'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' 'scm_review_policy=required-review' \
      "scm_required_checks=$CHECKS" 'ci_provider=github-actions' \
      'ci_runners=hosted-linux' 'ci_trust_boundary=protected-workflow' \
      'ci_report_formats=junit,tap,sarif,json' 'build_toolchain=native-project-toolchain' \
      'build_command=make test-build' 'package_command=not-applicable' \
      'build_output_contract=not-applicable' 'secret_provider=pass' \
      'ci_identity_references=github-actions:security-job' 'compliance_constraints=none' \
      'offline_mode=online' 'approval_constraints=required-review' 'quality_overrides=none' \
      'evidence_source_profile=repository-ci' 'evidence_repository_path=.' \
      'evidence_executor_identity=github-actions:workflow-security' \
      'evidence_trusted_producers=github-actions:security-job' \
      'evidence_freshness_seconds=3600' 'evidence_signature_policy=if-produced' \
      'evidence_merge_blocking=required' 'build_subject=source-only' 'sbom_requirement=not-applicable' \
      "user_interface=$interface" "ux_brief_requirement=$requirement"; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_profile_v5() {
  local project="$1" interface="$2" requirement="$3" accessibility="$4"
  write_profile_v3 "$project" "$interface" "$requirement"
  sed -i 's/^schema_version: 3/schema_version: 5/' "$project/tracking/product-ci-profile.yaml"
  for pair in \
    'validation_environment_profile=connected-representative' \
    'validation_environment_identity=qa-service' \
    'validation_environment_authorization=required' \
    'performance_validation=required' \
    'runtime_security_validation=required' \
    'compatibility_validation=required' \
    "accessibility_validation=$accessibility" \
    'flexibility_validation=required' \
    'safety_validation=not-applicable'; do
    key="${pair%%=*}"; value="${pair#*=}"
    printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key" >> \
      "$project/tracking/product-ci-profile.yaml"
  done
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
  write_quality_characteristics_fixture "$project"
}

write_inputs() {
  local project="$1"
  mkdir -p "$project/stage1-planning/outputs" "$project/stage2-requirements/outputs"
  printf '%s\n' '# BRD' 'FR-001 — create household plan' 'FR-002 — invite family member' > \
    "$project/stage2-requirements/outputs/BA-2026-07-27-BRD.md"
  printf '%s\n' '| Requirement | Priority |' '|---|---|' '| FR-001 | Must |' '| FR-002 | Must |' > \
    "$project/stage2-requirements/outputs/BA-2026-07-27-RTM.md"
  printf '%s\n' '# Risks' 'RISK-001 — user cannot complete shared flow' > \
    "$project/stage1-planning/outputs/PMO-2026-07-27-risk-register.md"
  printf '%s\n' '# Product Backlog' 'US-001' 'US-002' > \
    "$project/stage2-requirements/outputs/PO-2026-07-27-backlog.md"
}

write_uat() {
  local project="$1" ux_flow="$2"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: uat-criteria' \
      'owner: s2-po' 'product_profile_revision: 1' \
      'acceptance_scope: product-end-to-end' '---' '' '# Product Acceptance Criteria' '' \
      '## Product Acceptance Scenarios' \
      '- UAT-001: FR-001 and FR-002 complete one shared household flow.' \
      '- Risk: RISK-001.' \
      "- UX flow: $ux_flow." \
      '- Sign-off criterion: invited member sees and updates the same plan without data loss.'
  } > "$project/stage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md"
  {
    printf '%s\n' $'uat_id\tmust_fr_id\trisk_id\tux_flow_id\tcriteria_uri'
    printf 'UAT-001\tFR-001\tRISK-001\t%s\tstage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md\n' "$ux_flow"
    printf 'UAT-001\tFR-002\tRISK-001\t%s\tstage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md\n' "$ux_flow"
  } > "$project/stage2-requirements/outputs/UAT-product-acceptance-v1.tsv"
  complete_artifact_metadata_fixture \
    "$project/stage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md" \
    "$project" UAT-ACCEPTANCE-V1 S2 s2-po none APPROVED
}

finalize_ux_metadata() {
  local project="$1" file="$2" id="$3"
  complete_artifact_metadata_fixture "$file" "$project" "$id" S2 s2-po none APPROVED
}

write_ui_acceptance() {
  local project="$1"
  write_profile_v3 "$project" graphical required
  write_inputs "$project"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: ux-brief' 'owner: s2-po' \
      'product_profile_revision: 1' 'applicability: REQUIRED' 'user_interface: graphical' \
      '---' '' '# UX Brief' '' '## User Flows' \
      '- UXF-001: owner creates a plan, invites a member, member updates it.' '' \
      '## UX Acceptance Constraints' \
      '- UXC-001: the same plan identity remains visible across the complete flow.'
  } > "$project/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"
  finalize_ux_metadata "$project" "$project/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md" UX-BRIEF-V1
  write_uat "$project" UXF-001
}

write_non_ui_acceptance() {
  local project="$1"
  write_profile_v3 "$project" api-only not-applicable
  write_inputs "$project"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: ux-not-applicable' 'owner: s2-po' \
      'product_profile_revision: 1' 'applicability: NOT_APPLICABLE' 'user_interface: api-only' \
      'applicability_reason: product exposes an API contract without a user interface' \
      '---' '' '# UX Brief — Not Applicable'
  } > "$project/stage2-requirements/outputs/PO-2026-07-27-ux-not-applicable.md"
  finalize_ux_metadata "$project" "$project/stage2-requirements/outputs/PO-2026-07-27-ux-not-applicable.md" UX-NOT-APPLICABLE-V1
  write_uat "$project" NOT_APPLICABLE
}

write_v5_accessible_ui() {
  local project="$1"
  write_profile_v5 "$project" graphical required required
  write_inputs "$project"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: ux-brief' 'owner: s2-po' \
      'product_profile_revision: 1' 'applicability: REQUIRED' 'user_interface: graphical' \
      'accessibility_applicability: REQUIRED' 'accessibility_standard: WCAG-2.2-AA' \
      '---' '' '# UX Brief' '' '## User Flows' \
      '- UXF-001: owner creates a plan, invites a member, member updates it.' '' \
      '## UX Acceptance Constraints' \
      '- UXC-001: the same plan identity remains visible. Measure: 100 percent of the complete flow retains one plan id.' '' \
      '## Accessibility Criteria' \
      '- A11Y-001: keyboard-only completion matches pointer input. Measure: 100 percent of critical flow actions complete without a pointer.'
  } > "$project/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"
  finalize_ux_metadata "$project" "$project/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md" UX-BRIEF-V1
  write_uat "$project" UXF-001
}

write_v5_non_ui() {
  local project="$1"
  write_profile_v5 "$project" api-only not-applicable not-applicable
  write_inputs "$project"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: ux-not-applicable' 'owner: s2-po' \
      'product_profile_revision: 1' 'applicability: NOT_APPLICABLE' 'user_interface: api-only' \
      'applicability_reason: product exposes an API contract without a user interface' \
      'accessibility_applicability: NOT_APPLICABLE' 'accessibility_standard: not-applicable' \
      'accessibility_reason: no human interaction surface exists in the confirmed product scope' \
      '---' '' '# UX Brief — Not Applicable'
  } > "$project/stage2-requirements/outputs/PO-2026-07-27-ux-not-applicable.md"
  finalize_ux_metadata "$project" "$project/stage2-requirements/outputs/PO-2026-07-27-ux-not-applicable.md" UX-NOT-APPLICABLE-V1
  write_uat "$project" NOT_APPLICABLE
}

expect_blocked() {
  local label="$1" output="$2" project="$3"
  if bash "$ACCEPTANCE_CHECK" "$project" > "$output" 2>&1; then fail "$label"; fi
  grep -Fq 'PRODUCT ACCEPTANCE BLOCKED' "$output" || fail "$label did not emit BLOCKED"
}

P_UI="$TMP_DIR/ui"
write_ui_acceptance "$P_UI"
bash "$PROFILE_CHECK" "$P_UI" >/dev/null || fail 'valid profile schema v3 was rejected'
bash "$ACCEPTANCE_CHECK" "$P_UI" > "$TMP_DIR/ui.out" || fail 'valid UI acceptance was rejected'
grep -Fq 'PRODUCT ACCEPTANCE VERIFIED' "$TMP_DIR/ui.out" || fail 'UI verdict missing'
if grep -Fqi 'wireframe' "$P_UI/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"; then
  fail 'UI fixture unexpectedly requires a wireframe'
fi

P_API="$TMP_DIR/api"
write_non_ui_acceptance "$P_API"
bash "$PROFILE_CHECK" "$P_API" >/dev/null || fail 'valid non-UI profile schema v3 was rejected'
bash "$ACCEPTANCE_CHECK" "$P_API" >/dev/null || fail 'valid non-UI N/A + UAT was rejected'

P_A11Y="$TMP_DIR/accessible-v5"
write_v5_accessible_ui "$P_A11Y"
bash "$ACCEPTANCE_CHECK" "$P_A11Y" >/dev/null || fail 'valid required accessibility criteria were rejected'

P_A11Y_NA="$TMP_DIR/accessibility-na-v5"
write_v5_non_ui "$P_A11Y_NA"
bash "$ACCEPTANCE_CHECK" "$P_A11Y_NA" >/dev/null || fail 'valid profile-bound accessibility N/A was rejected'

P_A11Y_MISSING="$TMP_DIR/accessibility-missing-v5"
write_v5_accessible_ui "$P_A11Y_MISSING"
sed -i '/## Accessibility Criteria/,$d' \
  "$P_A11Y_MISSING/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"
expect_blocked 'required accessibility without A11Y criteria was accepted' \
  "$TMP_DIR/accessibility-missing.out" "$P_A11Y_MISSING"

P_UXC_MEASURE="$TMP_DIR/interaction-measure-missing-v5"
write_v5_accessible_ui "$P_UXC_MEASURE"
sed -i 's/ Measure: 100 percent of the complete flow retains one plan id\.//' \
  "$P_UXC_MEASURE/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"
expect_blocked 'schema v5 interaction criterion without Measure was accepted' \
  "$TMP_DIR/interaction-measure.out" "$P_UXC_MEASURE"

P_PROFILE_MISMATCH="$TMP_DIR/profile-mismatch"
write_profile_v3 "$P_PROFILE_MISMATCH" graphical not-applicable
if bash "$PROFILE_CHECK" "$P_PROFILE_MISMATCH" > "$TMP_DIR/profile-mismatch.out" 2>&1; then
  fail 'graphical profile accepted ux_brief_requirement=not-applicable'
fi
grep -Fq 'PROFILE BLOCKED' "$TMP_DIR/profile-mismatch.out" ||
  fail 'profile applicability mismatch did not emit PROFILE BLOCKED'

P_UI_NA="$TMP_DIR/ui-na"
write_ui_acceptance "$P_UI_NA"
rm "$P_UI_NA/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"
printf '%s\n' 'applicability: NOT_APPLICABLE' > \
  "$P_UI_NA/stage2-requirements/outputs/PO-2026-07-27-ux-not-applicable.md"
expect_blocked 'graphical UI accepted UX N/A' "$TMP_DIR/ui-na.out" "$P_UI_NA"

P_MUST="$TMP_DIR/missing-must"
write_ui_acceptance "$P_MUST"
sed -i '/FR-002/d' "$P_MUST/stage2-requirements/outputs/UAT-product-acceptance-v1.tsv"
expect_blocked 'UAT index omitted a Must-FR' "$TMP_DIR/missing-must.out" "$P_MUST"

P_REV="$TMP_DIR/wrong-revision"
write_ui_acceptance "$P_REV"
sed -i 's/product_profile_revision: 1/product_profile_revision: 2/' \
  "$P_REV/stage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md"
expect_blocked 'UAT criteria bound to wrong profile revision' "$TMP_DIR/wrong-revision.out" "$P_REV"

for consumer in cycle1-dev/s2-qa-req/CLAUDE.md cycle1-dev/s2-test-strategy/CLAUDE.md \
  cycle1-dev/s3-arch/CLAUDE.md cycle1-dev/s5-qa/CLAUDE.md \
  cycle1-dev/s5-qa/.claude/commands/test-plan.md cycle1-dev/s5-qa/.claude/commands/go-no-go.md; do
  grep -Fq 'uat-criteria' "$ROOT/$consumer" ||
    fail "$consumer does not consume the current product acceptance criteria logical id"
  grep -Fq 'product-acceptance-index' "$ROOT/$consumer" ||
    fail "$consumer does not consume the current product acceptance trace logical id"
done

grep -Fq 'product-acceptance-check.sh' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" ||
  fail 'Gate 2 does not invoke product acceptance validator'
grep -Fq $'s2-po\t/stories\t4\tproduct-acceptance-index\tone\tyes\tstage2-requirements/outputs/UAT-product-acceptance-v1.tsv' \
  "$ROOT/_contract/current-artifact-groups-v1.tsv" ||
  fail 'authoritative registry does not declare the product acceptance trace output'
grep -Fq 'CURRENT_ARTIFACT_GROUPS_FILE' "$ROOT/sdlc.sh" ||
  fail 'launcher does not consume the authoritative output registry'

echo 'PASS: product acceptance smoke'

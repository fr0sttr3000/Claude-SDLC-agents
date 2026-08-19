#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
source "$ROOT/tests/lib/quality-characteristics-fixture.sh"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-gate-validator.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/human-approval-receipts"
CHECKS=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_project() {
  local project="$1" stage
  for stage in stage1-planning stage2-requirements stage3-design stage4-dev \
    stage5-testing stage6-deploy stage7-ops; do
    mkdir -p "$project/$stage/inputs" "$project/$stage/outputs"
  done
  mkdir -p "$project/tracking" "$project/tests"
}

write_artifact() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' 'status: PASS' 'No open blockers.' > "$path"
}

write_profile_v3() {
  local project="$1"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 3' 'revision: 1' 'previous_revision: 0' \
      'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: gate fixture'
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
      'user_interface=none' 'ux_brief_requirement=not-applicable'; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

upgrade_profile_v5_with_architecture_applicability() {
  local project="$1" pair key value
  sed -i 's/^schema_version: 3/schema_version: 5/' "$project/tracking/product-ci-profile.yaml"
  for pair in \
    validation_environment_profile=connected-representative \
    validation_environment_identity=qa-service \
    validation_environment_authorization=required \
    performance_validation=required runtime_security_validation=required \
    compatibility_validation=required accessibility_validation=not-applicable \
    flexibility_validation=required safety_validation=not-applicable \
    api_contract_design=not-applicable data_store_design=not-applicable \
    authorization_design=not-applicable; do
    key="${pair%%=*}"; value="${pair#*=}"
    printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key" >> \
      "$project/tracking/product-ci-profile.yaml"
  done
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_applicability_decision() {
  local file="$1" project="$2" artifact_id="$3" producer="$4" capability="$5" profile_field="$6"
  local rel project_name
  rel="${file#"$project/"}"
  project_name="$(basename "$project")"
  printf '%s\n' \
    '---' 'schema_version: 1' "artifact_id: $artifact_id" \
    'artifact_type: applicability-decision' "project: $project_name" 'stage: S3' \
    "producer: $producer" 'source_revision: none' 'status: NOT_APPLICABLE' \
    'inputs: tracking/product-ci-profile.yaml' "outputs: $rel" \
    'tags: sdlc,cycle1,stage3,applicability' "capability: $capability" \
    'applicability: NOT_APPLICABLE' "profile_field: $profile_field" \
    'profile_value: not-applicable' 'product_profile_revision: 1' \
    'applicability_owner: s0-kickoff' 'applicability_reason: gate fixture' \
    '---' '' "# $capability — Not Applicable" '' \
    'The current Product Profile revision explicitly confirms this capability is not applicable.' \
    '' '## Obsidian Links' '' '- Dashboard: [[Dashboard]]' \
    '- Inputs: `tracking/product-ci-profile.yaml`' "- Outputs: [[${rel%.md}]]" > "$file"
}

write_architecture_trace() {
  local project="$1"
  mkdir -p "$project/stage1-planning/inputs"
  printf '%s\n' '# Idea' 'Runtime Constraints: network service requests finish within 500 ms p95' > \
    "$project/stage1-planning/inputs/idea.md"
  printf '%s\n' 'cycle1:' \
    '  runtime_constraints: "network service requests finish within 500 ms p95"' \
    '  runtime_constraints_source: "stage1-planning/inputs/idea.md#Runtime Constraints"' > \
    "$project/tracking/PMO-constraints.md"
  printf '%s\n' 'NFR-001: p95 latency is less than 500 ms.' \
    '## Runtime Constraints' \
    'Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints' \
    'Runtime Constraints scope: application-design-only' \
    'Runtime Constraints status: CONFIRMED' \
    'RC-001 | limitation | request p95 is below 500 ms | tracking/PMO-constraints.md#cycle1.runtime_constraints' > \
    "$project/stage2-requirements/outputs/BA-2026-07-21-NFR.md"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: architecture-hld' \
      'owner: s3-arch' 'product_profile_revision: 1' \
      'assumption_policy: no-unconfirmed-stack-or-topology' '---' '' '# HLD' '' \
      '## Runtime Constraints' \
      'Runtime Constraints source: stage2-requirements/outputs/BA-2026-07-21-NFR.md#Runtime Constraints' \
      'Runtime Constraints scope: application-design-only' \
      'Runtime Constraints status: CONFIRMED' \
      'Deployment/operations authorization: NOT_GRANTED' \
      'RC-001: bounded application timeout and latency verification.' '' \
      '## Architecture Decision Trace' \
      'DEC-001: NFR-001 → QA-Performance → TACTIC-Bound-Latency → PATTERN-Timeout → ADR-001.' \
      '' '## Quality Characteristic Scope' \
      'Reliability scope: REQUIRED' 'Reliability evidence: REL-001' \
      'Reliability dimensions: maturity,availability,fault-tolerance,recoverability' \
      'Maintainability scope: REQUIRED' 'Maintainability evidence: MAINT-001' \
      'Maintainability dimensions: modularity,reusability,analysability,modifiability,testability' \
      'Performance scope: REQUIRED' 'Performance evidence: PERF-001' \
      'Compatibility scope: REQUIRED' 'Compatibility evidence: COMPAT-001' \
      'Compatibility dimensions: co-existence,interoperability' \
      'Flexibility scope: REQUIRED' 'Flexibility evidence: FLEX-001' \
      'Flexibility dimensions: install,update,replaceability,configuration-portability' \
      'Safety scope: NOT_APPLICABLE' \
      'Safety evidence: NOT_APPLICABLE: no safety-critical harm scenario exists in confirmed scope'
  } > "$project/stage3-design/outputs/ARCH-2026-07-21-HLD.md"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: architecture-decision' \
      'owner: s3-arch' 'product_profile_revision: 1' '---' '' '# ADR-001' '' \
      'Decision ID: DEC-001' 'NFR: NFR-001' 'Quality Attribute: QA-Performance' \
      'Tactic: TACTIC-Bound-Latency' 'Pattern: PATTERN-Timeout' 'ADR: ADR-001' \
      'Trade-off gain: bounded response time.' 'Trade-off cost: controlled early failure.'
  } > "$project/stage3-design/outputs/ARCH-2026-07-21-ADR-001.md"
  complete_artifact_metadata_fixture \
    "$project/stage3-design/outputs/ARCH-2026-07-21-HLD.md" "$project" \
    ARCH-HLD-001 S3 s3-arch none APPROVED
  complete_artifact_metadata_fixture \
    "$project/stage3-design/outputs/ARCH-2026-07-21-ADR-001.md" "$project" \
    ARCH-ADR-001 S3 s3-arch none APPROVED
  {
    printf '%s\n' $'decision_id\tnfr_id\tquality_attribute_id\ttactic_id\tpattern_id\tadr_id\tadr_uri\tproduct_profile_revision'
    printf '%s\n' $'DEC-001\tNFR-001\tQA-Performance\tTACTIC-Bound-Latency\tPATTERN-Timeout\tADR-001\tstage3-design/outputs/ARCH-2026-07-21-ADR-001.md\t1'
  } > "$project/stage3-design/outputs/ARCH-decision-trace-v1.tsv"
}

DOR="$ROOT/cycle1-dev/s0-validate/dor-check.sh"
DOD="$ROOT/cycle1-dev/s0-validate/dod-check.sh"

P1="$TMP_DIR/gate1"
GATE1_SOURCE=1111111111111111111111111111111111111111
make_project "$P1"
printf '%s\n' 'schema_version: 5' 'revision: 1' > "$P1/tracking/product-ci-profile.yaml"
write_artifact "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
write_artifact "$P1/stage1-planning/outputs/PMO-2026-07-21-charter.md"
write_artifact "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
if bash "$DOR" "$P1" 1 > "$TMP_DIR/gate1-weak.out" 2>&1; then fail 'Gate 1 accepted existence-only artifacts'; fi
grep -Fq 'GATE 1 PLANNING BLOCKED' "$TMP_DIR/gate1-weak.out" || fail 'weak Gate 1 did not emit BLOCKED'
printf '%s\n' '---' 'schema_version: 1' 'artifact_type: feasibility' 'owner: s1-pm' \
  'product_profile_revision: 1' \
  'stakeholder_acknowledgement_ref: tracking/approvals/APPROVAL-FEASIBILITY.yaml' \
  '---' '' '# Feasibility' 'Assessment status: COMPLETE' 'Decision: CONDITIONAL_GO' \
  'decision_status: PRE_FINANCE' 'finance_dependency: OPEN' \
  'Axis: technical | Verdict: PASS | Evidence: architecture boundary confirmed | Owner: tech-sponsor' \
  'Axis: economic | Verdict: PASS | Evidence: funded business case confirmed | Owner: finance-sponsor' \
  'Axis: operational | Verdict: PASS | Evidence: Cycle 1 validation scope confirmed | Owner: qa-owner' \
  'Axis: legal | Verdict: PASS | Evidence: applicable obligations reviewed | Owner: legal-owner' \
  '## Scope In' '- confirmed Cycle 1 product scope' '## Scope Out' '- deployment and operations' > \
  "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
complete_artifact_metadata_fixture "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md" "$P1" PM-FEASIBILITY-001 S1 s1-pm "$GATE1_SOURCE" APPROVED
feasibility_sha="$(sha256sum "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md" | awk '{print $1}')"
printf '%s\n' '---' 'schema_version: 1' 'artifact_type: business-case' 'owner: s1-finance' \
  'product_profile_revision: 1' "feasibility_sha256: $feasibility_sha" \
  'finance_status: PASS' 'base_npv: 1000' \
  'base_roi_percent: 20' 'base_payback_months: 12' '---' '' '# Business Case' > \
  "$P1/stage1-planning/outputs/FIN-2026-07-21-business-case.md"
complete_artifact_metadata_fixture "$P1/stage1-planning/outputs/FIN-2026-07-21-business-case.md" "$P1" FIN-CASE-001 S1 s1-finance "$GATE1_SOURCE" APPROVED
business_case_sha="$(sha256sum "$P1/stage1-planning/outputs/FIN-2026-07-21-business-case.md" | awk '{print $1}')"
printf '%s\n' '---' 'schema_version: 1' 'artifact_type: project-charter' 'owner: s1-pmo' \
  'product_profile_revision: 1' "feasibility_sha256: $feasibility_sha" \
  "business_case_sha256: $business_case_sha" 'gate1_decision: GO' \
  'charter_approval_ref: tracking/approvals/APPROVAL-CHARTER.yaml' '---' '' '# Charter' \
  'Charter status: SIGNED' '## Objectives' '- deliver the confirmed Cycle 1 outcome' > \
  "$P1/stage1-planning/outputs/PMO-2026-07-21-charter.md"
{
  printf '%s\n' '---' 'schema_version: 1' 'artifact_type: risk-register' 'owner: s1-pmo' \
    'product_profile_revision: 1' "feasibility_sha256: $feasibility_sha" \
    "business_case_sha256: $business_case_sha" 'gate1_decision: GO' '---' '' '# Risk Register'
  for n in $(seq 1 10); do
    printf 'RISK-%03d | Category: delivery | Probability: 2 | Impact: 3 | Score: 6 | Owner: PMO | Mitigation: verify contract before transition | Trigger: required evidence missing | Status: OPEN | Constraint: GATE1-CONTEXT\n' "$n"
  done
} > "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
complete_artifact_metadata_fixture "$P1/stage1-planning/outputs/PMO-2026-07-21-charter.md" "$P1" PMO-CHARTER-001 S1 s1-pmo "$GATE1_SOURCE" APPROVED
complete_artifact_metadata_fixture "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md" "$P1" PMO-RISKS-001 S1 s1-pmo "$GATE1_SOURCE" APPROVED
mkdir -p "$P1/tracking/approvals"
for spec in \
  'APPROVAL-FEASIBILITY|PM-2026-07-21-feasibility.md|feasibility-acknowledgement|stakeholder' \
  'APPROVAL-CHARTER|PMO-2026-07-21-charter.md|charter-signature|product-sponsor'; do
  IFS='|' read -r approval_id artifact_name scope approver <<< "$spec"
  artifact="$P1/stage1-planning/outputs/$artifact_name"
  approval="$P1/tracking/approvals/$approval_id.yaml"
  printf '%s\n' 'schema_version: 1' "approval_id: $approval_id" \
    'approval_origin: launcher-human-v1' "approver_identity: $approver" 'decision: APPROVE' \
    "scope: $scope" 'rationale: reviewed complete current planning artifact' \
    "source_revision: $GATE1_SOURCE" \
    "subject_digest: $(sha256sum "$artifact" | awk '{print $1}')" \
    'observed_at: 2026-07-21T12:00:00Z' > "$approval"
  record_human_approval_receipt "$P1" "$approval"
done
gate1_output="$(bash "$DOR" "$P1" 1)" || { printf '%s
' "$gate1_output"; fail 'valid Gate 1 fixture was rejected'; }
[[ "$gate1_output" == *'DoR PASSED'* ]] || fail 'Gate 1 did not reach its final verdict'
[[ "$gate1_output" == *'GATE 1 PLANNING VERIFIED'* ]] || fail 'Gate 1 did not run planning validator'

GATE1_CHECK="$ROOT/cycle1-dev/s0-validate/gate1-planning-check.sh"
cp "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md" "$TMP_DIR/gate1-feasibility.valid"
sed -i 's/- confirmed Cycle 1 product scope/scope:minimal/' \
  "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
if bash "$GATE1_CHECK" "$P1" >"$TMP_DIR/gate1-minimal-scope.out" 2>&1; then
  fail 'Gate 1 accepted scope:minimal'
fi
grep -Fq 'Scope In is empty or placeholder' "$TMP_DIR/gate1-minimal-scope.out" ||
  fail 'scope:minimal blocker did not identify Scope In'
cp "$TMP_DIR/gate1-feasibility.valid" "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"

sed -i 's/architecture boundary confirmed/skip:technical/' \
  "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
if bash "$GATE1_CHECK" "$P1" >"$TMP_DIR/gate1-skip-axis.out" 2>&1; then
  fail 'Gate 1 accepted skipped mandatory feasibility axis'
fi
grep -Fq 'technical evidence is incomplete' "$TMP_DIR/gate1-skip-axis.out" ||
  fail 'skipped axis blocker did not identify technical evidence'
cp "$TMP_DIR/gate1-feasibility.valid" "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"

cp "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md" "$TMP_DIR/gate1-risks.valid"
sed -n '/^RISK-001 /p' "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md" >> \
  "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
if bash "$GATE1_CHECK" "$P1" >"$TMP_DIR/gate1-duplicate-risk.out" 2>&1; then
  fail 'Gate 1 accepted duplicate risk id'
fi
grep -Fq 'duplicate risk id: RISK-001' "$TMP_DIR/gate1-duplicate-risk.out" ||
  fail 'duplicate risk blocker did not identify RISK-001'
cp "$TMP_DIR/gate1-risks.valid" "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"

cp "$P1/stage1-planning/outputs/FIN-2026-07-21-business-case.md" "$TMP_DIR/gate1-finance.valid"
sed -i 's/^finance_status: PASS/finance_status: FAIL/' \
  "$P1/stage1-planning/outputs/FIN-2026-07-21-business-case.md"
if bash "$GATE1_CHECK" "$P1" >"$TMP_DIR/gate1-finance-fail.out" 2>&1; then
  fail 'Gate 1 accepted Finance FAIL after PM candidate verdict'
fi
grep -Fq 'finance_status is blocking' "$TMP_DIR/gate1-finance-fail.out" ||
  fail 'Finance FAIL blocker was not controlled'
cp "$TMP_DIR/gate1-finance.valid" "$P1/stage1-planning/outputs/FIN-2026-07-21-business-case.md"

P1_CONDITIONAL="$TMP_DIR/gate1-conditional"
cp -a "$P1" "$P1_CONDITIONAL"
while IFS= read -r artifact; do
  sed -i "s/^project: $(basename "$P1")$/project: $(basename "$P1_CONDITIONAL")/" "$artifact"
done < <(find "$P1_CONDITIONAL" -type f -name '*.md')
conditional_feasibility="$P1_CONDITIONAL/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
conditional_business="$P1_CONDITIONAL/stage1-planning/outputs/FIN-2026-07-21-business-case.md"
conditional_charter="$P1_CONDITIONAL/stage1-planning/outputs/PMO-2026-07-21-charter.md"
conditional_risks="$P1_CONDITIONAL/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
sed -i 's/Axis: technical | Verdict: PASS/Axis: technical | Verdict: CONDITIONAL/' \
  "$conditional_feasibility"
printf '%s\n' \
  'Condition: COND-TECH-001 | Axis: technical | Status: OPEN | Owner: tech-sponsor | Resolution: validate architecture boundary before S2' \
  'Condition: COND-FIN-001 | Axis: finance | Status: OPEN | Owner: finance-sponsor | Resolution: close sensitivity assumption before commitment' >> \
  "$conditional_feasibility"
sed -i 's/^finance_status: PASS/finance_status: CONDITIONAL/' "$conditional_business"
conditional_feasibility_sha="$(sha256sum "$conditional_feasibility" | awk '{print $1}')"
sed -i "s/^feasibility_sha256:.*/feasibility_sha256: $conditional_feasibility_sha/" \
  "$conditional_business" "$conditional_charter" "$conditional_risks"
conditional_business_sha="$(sha256sum "$conditional_business" | awk '{print $1}')"
sed -i \
  -e "s/^business_case_sha256:.*/business_case_sha256: $conditional_business_sha/" \
  -e 's/^gate1_decision: GO/gate1_decision: CONDITIONAL_GO/' \
  "$conditional_charter" "$conditional_risks"
for spec in \
  "APPROVAL-FEASIBILITY.yaml|$conditional_feasibility" \
  "APPROVAL-CHARTER.yaml|$conditional_charter"; do
  IFS='|' read -r approval_name subject_file <<< "$spec"
  approval="$P1_CONDITIONAL/tracking/approvals/$approval_name"
  subject_sha="$(sha256sum "$subject_file" | awk '{print $1}')"
  sed -i "s/^subject_digest:.*/subject_digest: $subject_sha/" "$approval"
  record_human_approval_receipt "$P1_CONDITIONAL" "$approval"
done
conditional_output="$(bash "$GATE1_CHECK" "$P1_CONDITIONAL")" ||
  fail 'valid Conditional GO fixture was rejected'
[[ "$conditional_output" == *'effective=CONDITIONAL_GO'* ]] ||
  fail 'Conditional GO fixture did not produce effective CONDITIONAL_GO'

P1_STALE="$TMP_DIR/gate1-stale-charter"
cp -a "$P1" "$P1_STALE"
while IFS= read -r artifact; do
  sed -i "s/^project: $(basename "$P1")$/project: $(basename "$P1_STALE")/" "$artifact"
done < <(find "$P1_STALE" -type f -name '*.md')
stale_feasibility="$P1_STALE/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
stale_business="$P1_STALE/stage1-planning/outputs/FIN-2026-07-21-business-case.md"
stale_charter="$P1_STALE/stage1-planning/outputs/PMO-2026-07-21-charter.md"
stale_risks="$P1_STALE/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
stale_feasibility_sha="$(sha256sum "$stale_feasibility" | awk '{print $1}')"
sed -i "s/^feasibility_sha256:.*/feasibility_sha256: $stale_feasibility_sha/" \
  "$stale_business" "$stale_risks"
stale_business_sha="$(sha256sum "$stale_business" | awk '{print $1}')"
sed -i "s/^business_case_sha256:.*/business_case_sha256: $stale_business_sha/" \
  "$stale_charter" "$stale_risks"
sed -i 's/^feasibility_sha256:.*/feasibility_sha256: 0000000000000000000000000000000000000000000000000000000000000000/' \
  "$stale_charter"
for spec in \
  "APPROVAL-FEASIBILITY.yaml|$stale_feasibility" \
  "APPROVAL-CHARTER.yaml|$stale_charter"; do
  IFS='|' read -r approval_name subject_file <<< "$spec"
  approval="$P1_STALE/tracking/approvals/$approval_name"
  subject_sha="$(sha256sum "$subject_file" | awk '{print $1}')"
  sed -i "s/^subject_digest:.*/subject_digest: $subject_sha/" "$approval"
  record_human_approval_receipt "$P1_STALE" "$approval"
done
if bash "$GATE1_CHECK" "$P1_STALE" >"$TMP_DIR/gate1-stale-charter.out" 2>&1; then
  fail 'Gate 1 accepted charter bound to stale feasibility'
fi
grep -Fq 'stale feasibility binding' "$TMP_DIR/gate1-stale-charter.out" ||
  { cat "$TMP_DIR/gate1-stale-charter.out" >&2; fail 'stale charter blocker did not identify feasibility binding'; }

P2="$TMP_DIR/gate2"
make_project "$P2"
write_profile_v3 "$P2"
sed -i 's/^schema_version: 3/schema_version: 5/' "$P2/tracking/product-ci-profile.yaml"
for pair in validation_environment_profile=connected-representative validation_environment_identity=qa-service validation_environment_authorization=required performance_validation=required runtime_security_validation=required compatibility_validation=required accessibility_validation=not-applicable flexibility_validation=required safety_validation=not-applicable; do key="${pair%%=*}"; value="${pair#*=}"; printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key" >> "$P2/tracking/product-ci-profile.yaml"; done
cp "$P2/tracking/product-ci-profile.yaml" "$P2/tracking/product-ci-profile-history/revision-1.yaml"
write_quality_characteristics_fixture "$P2"
mkdir -p "$P2/stage1-planning/inputs"
printf '%s\n' '# Idea' 'Runtime Constraints: network service requests finish within 500 ms p95' > \
  "$P2/stage1-planning/inputs/idea.md"
printf '%s\n' 'cycle1:' \
  '  runtime_constraints: "network service requests finish within 500 ms p95"' \
  '  runtime_constraints_source: "stage1-planning/inputs/idea.md#Runtime Constraints"' > \
  "$P2/tracking/PMO-constraints.md"
write_artifact "$P2/stage2-requirements/outputs/BA-2026-07-21-BRD.md"
printf '%s\n' 'Latency p95 < 500ms' '## Runtime Constraints' \
  'Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints' \
  'Runtime Constraints scope: application-design-only' \
  'Runtime Constraints status: CONFIRMED' \
  'RC-001 | limitation | request p95 is below 500 ms | tracking/PMO-constraints.md#cycle1.runtime_constraints' > \
  "$P2/stage2-requirements/outputs/BA-2026-07-21-NFR.md"
write_artifact "$P2/stage2-requirements/outputs/BA-2026-07-21-RTM.md"
printf '%s\n' '## Story' 'Given a user' 'When an action occurs' 'Then the result is visible' > "$P2/stage2-requirements/outputs/PO-2026-07-21-backlog.md"
printf '%s\n' '# BRD' 'FR-001: user completes a testable flow.' > "$P2/stage2-requirements/outputs/BA-2026-07-21-BRD.md"
printf '%s\n' '| Requirement | Priority |' '|---|---|' '| FR-001 | Must |' > "$P2/stage2-requirements/outputs/BA-2026-07-21-RTM.md"
printf '%s\n' '# Risks' 'RISK-001: user cannot complete the flow.' > "$P2/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
printf '%s\n' '---' 'schema_version: 1' 'artifact_type: ux-not-applicable' 'owner: s2-po' 'product_profile_revision: 1' 'applicability: NOT_APPLICABLE' 'user_interface: none' 'applicability_reason: confirmed service has no human interaction surface' 'accessibility_applicability: NOT_APPLICABLE' 'accessibility_standard: not-applicable' 'accessibility_reason: no human interaction surface exists in confirmed scope' '---' '' '# UX Not Applicable' > "$P2/stage2-requirements/outputs/PO-2026-07-21-ux-not-applicable.md"
complete_artifact_metadata_fixture "$P2/stage2-requirements/outputs/PO-2026-07-21-ux-not-applicable.md" "$P2" UX-NA-001 S2 s2-po none APPROVED
printf '%s\n' '---' 'schema_version: 1' 'artifact_type: uat-criteria' 'owner: s2-po' 'product_profile_revision: 1' 'acceptance_scope: product-end-to-end' '---' '' '# UAT Criteria' '' '## Product Acceptance Scenarios' '- UAT-001: FR-001 completes the service flow; risk RISK-001; UX NOT_APPLICABLE.' '- Sign-off criterion: service returns the confirmed result without data loss.' > "$P2/stage2-requirements/outputs/UAT-2026-07-21-acceptance-criteria.md"
complete_artifact_metadata_fixture "$P2/stage2-requirements/outputs/UAT-2026-07-21-acceptance-criteria.md" "$P2" UAT-001 S2 s2-po none APPROVED
printf '%s\n' $'uat_id\tmust_fr_id\trisk_id\tux_flow_id\tcriteria_uri' $'UAT-001\tFR-001\tRISK-001\tNOT_APPLICABLE\tstage2-requirements/outputs/UAT-2026-07-21-acceptance-criteria.md' > "$P2/stage2-requirements/outputs/UAT-product-acceptance-v1.tsv"
printf '%s\n' 'GATE 2 PASSED' > "$P2/stage2-requirements/outputs/QA-REQ-2026-07-21-review.md"
if bash "$DOR" "$P2" 2 > "$TMP_DIR/gate2-missing.out" 2>&1; then
  fail 'Gate 2 accepted missing test strategy and SG1 requirements'
fi
grep -Fq 'QA test strategy — current resolution BLOCKED' "$TMP_DIR/gate2-missing.out" ||
  fail 'Gate 2 did not report missing test strategy'
grep -Fq 'Security requirements / SG1 — BLOCKED' "$TMP_DIR/gate2-missing.out" ||
  fail 'Gate 2 did not report missing SG1 requirements'
write_artifact "$P2/stage2-requirements/outputs/QA-2026-07-21-test-strategy.md"
write_artifact "$P2/stage2-requirements/outputs/SEC-2026-07-21-security-requirements.md"
if bash "$DOR" "$P2" 2 > "$TMP_DIR/gate2-unverified.out" 2>&1; then
  fail 'Gate 2 accepted a plain Markdown PASS as verified machine evidence'
fi
grep -Fq 'QA REQUIREMENTS REVIEW BLOCKED' "$TMP_DIR/gate2-unverified.out" ||
  fail 'Gate 2 did not identify the plain Markdown verdict as UNVERIFIED/BLOCKED'
printf '%s\n' 'QA contribution: PASS' > "$P2/stage2-requirements/outputs/QA-REQ-2026-07-21-review.md"
qa_sha="$(sha256sum "$P2/stage2-requirements/outputs/QA-REQ-2026-07-21-review.md" | awk '{print $1}')"
printf '%s\n' 'schema_version: 1' 'review_id: QA-REQ-001' 'status: PASS' "project: $(basename "$P2")" 'owner: s2-qa-req' 'product_profile_revision: 1' 'reviewed_at: 2026-07-21T12:00:00Z' 'review_ref: stage2-requirements/outputs/QA-REQ-2026-07-21-review.md' "review_sha256: $qa_sha" 'blocker_count: 0' > "$P2/stage2-requirements/outputs/QA-REQ-review-v1.yaml"
brd_sha="$(sha256sum "$P2/stage2-requirements/outputs/BA-2026-07-21-BRD.md" | awk '{print $1}')"
nfr_sha="$(sha256sum "$P2/stage2-requirements/outputs/BA-2026-07-21-NFR.md" | awk '{print $1}')"
backlog_sha="$(sha256sum "$P2/stage2-requirements/outputs/PO-2026-07-21-backlog.md" | awk '{print $1}')"
constraints_sha="$(sha256sum "$P2/tracking/PMO-constraints.md" | awk '{print $1}')"
printf '%s\n' 'product_profile_revision: 1' "brd_sha256: $brd_sha" "nfr_sha256: $nfr_sha" \
  "backlog_sha256: $backlog_sha" "constraints_sha256: $constraints_sha" \
  'asvs_version: 5.0.0' 'asvs_level: L2' 'data_classification_scope: DATA-001' \
  'sg1_status: PASS' 'critical_fr_scope: FR-001' \
  'Data classification: DATA-001 | Entity: account-metadata | Class: internal | Rationale: authenticated account context' \
  'Scenario: SEC-SC-001 | FR: FR-001 | Abuse: ABUSE-001 | ASVS: v5.0.0-1.2.3 | Countermeasure: SEC-NFR-001' > \
  "$P2/stage2-requirements/outputs/SEC-2026-07-21-security-requirements.md"
bash "$DOR" "$P2" 2 > "$TMP_DIR/gate2-valid.out" || { cat "$TMP_DIR/gate2-valid.out"; fail 'valid machine Gate 2 fixture was rejected'; }
grep -Fq 'DoR PASSED' "$TMP_DIR/gate2-valid.out" || fail 'valid Gate 2 did not reach PASSED'

P3="$TMP_DIR/gate3-non-api"
make_project "$P3"
write_profile_v3 "$P3"
upgrade_profile_v5_with_architecture_applicability "$P3"
write_quality_characteristics_fixture "$P3"
write_architecture_trace "$P3"
printf '%s\n' '# BRD' 'FR-001: user completes a testable flow.' > \
  "$P3/stage2-requirements/outputs/BA-2026-07-21-BRD.md"
printf '%s\n' '# Backlog' 'Given a user' 'When an action occurs' 'Then the result is visible' > \
  "$P3/stage2-requirements/outputs/PO-2026-07-21-backlog.md"
printf '%s\n' 'applicability: not-applicable' 'reason: no API boundary in HLD' > \
  "$P3/stage3-design/outputs/ARCH-2026-07-21-api-not-applicable.md"
brd_sha="$(sha256sum "$P3/stage2-requirements/outputs/BA-2026-07-21-BRD.md" | awk '{print $1}')"
nfr_sha="$(sha256sum "$P3/stage2-requirements/outputs/BA-2026-07-21-NFR.md" | awk '{print $1}')"
backlog_sha="$(sha256sum "$P3/stage2-requirements/outputs/PO-2026-07-21-backlog.md" | awk '{print $1}')"
constraints_sha="$(sha256sum "$P3/tracking/PMO-constraints.md" | awk '{print $1}')"
printf '%s\n' 'product_profile_revision: 1' "brd_sha256: $brd_sha" \
  "nfr_sha256: $nfr_sha" "backlog_sha256: $backlog_sha" \
  "constraints_sha256: $constraints_sha" 'asvs_version: 5.0.0' 'asvs_level: L2' \
  'data_classification_scope: DATA-001' 'critical_fr_scope: FR-001' 'sg1_status: PASS' \
  'Data classification: DATA-001 | Entity: account-metadata | Class: internal | Rationale: authenticated account context' \
  'Scenario: SEC-SC-001 | FR: FR-001 | Abuse: ABUSE-001 | ASVS: v5.0.0-1.2.3 | Countermeasure: SEC-NFR-001' > \
  "$P3/stage2-requirements/outputs/SEC-2026-07-21-security-requirements.md"
sg1_sha="$(sha256sum "$P3/stage2-requirements/outputs/SEC-2026-07-21-security-requirements.md" | awk '{print $1}')"
hld_sha="$(sha256sum "$P3/stage3-design/outputs/ARCH-2026-07-21-HLD.md" | awk '{print $1}')"
printf '%s\n' 'product_profile_revision: 1' "sg1_sha256: $sg1_sha" "hld_sha256: $hld_sha" \
  'asvs_version: 5.0.0' 'api_applicability: NOT_APPLICABLE' \
  'authorization_applicability: NOT_APPLICABLE' 'sg2_status: PASS' 'component_scope: CMP-APP' \
  'Threat trace: THREAT-001 | Scenario: SEC-SC-001 | Component: CMP-APP | Control: CTRL-001 | Test: SEC-TEST-001 | ASVS: v5.0.0-1.2.3 | Severity: Medium | Status: MITIGATED' > \
  "$P3/stage3-design/outputs/SEC-2026-07-21-threat-model.md"
printf '%s\n' 'applicability: not-applicable' 'reason: no protected subjects/resources' > \
  "$P3/stage3-design/outputs/RBAC-2026-07-21-not-applicable.md"
printf '%s\n' 'applicability: not-applicable' 'reason: no persistent data store' > \
  "$P3/stage3-design/outputs/DBA-2026-07-21-not-applicable.md"
if bash "$DOR" "$P3" 3 > "$TMP_DIR/gate3-plain-na.out" 2>&1; then
  fail 'Gate 3 accepted plain Markdown N/A without profile/revision binding'
fi
grep -Fq 'NOT_APPLICABLE decision invalid/stale' "$TMP_DIR/gate3-plain-na.out" ||
  fail 'Gate 3 plain N/A rejection did not identify invalid structured decision'

write_applicability_decision \
  "$P3/stage3-design/outputs/ARCH-2026-07-21-api-not-applicable.md" "$P3" \
  ARCH-API-NA-001 s3-arch api-contract api_contract_design
write_applicability_decision \
  "$P3/stage3-design/outputs/RBAC-2026-07-21-not-applicable.md" "$P3" \
  AUTH-NA-001 s3-rbac authorization authorization_design
write_applicability_decision \
  "$P3/stage3-design/outputs/DBA-2026-07-21-not-applicable.md" "$P3" \
  DATA-NA-001 s3-dba data-store data_store_design
bash "$DOR" "$P3" 3 > "$TMP_DIR/gate3-non-api.out" || {
  sed -n '1,240p' "$TMP_DIR/gate3-non-api.out" >&2
  fail 'Gate 3 rejected explicit API/RBAC/data-store not-applicable evidence'
}

sed -i 's/^product_profile_revision: 1/product_profile_revision: 0/' \
  "$P3/stage3-design/outputs/ARCH-2026-07-21-api-not-applicable.md"
if bash "$ROOT/cycle1-dev/s0-validate/applicability-resolve.sh" validate "$P3" api-contract \
  stage3-design/outputs/ARCH-2026-07-21-api-not-applicable.md s3-arch >/dev/null 2>&1; then
  fail 'applicability resolver accepted stale Product Profile revision'
fi
sed -i 's/^product_profile_revision: 0/product_profile_revision: 1/' \
  "$P3/stage3-design/outputs/ARCH-2026-07-21-api-not-applicable.md"

sed -i 's/^api_contract_design: not-applicable/api_contract_design: required/' \
  "$P3/tracking/product-ci-profile.yaml" "$P3/tracking/product-ci-profile-history/revision-1.yaml"
if bash "$DOR" "$P3" 3 > "$TMP_DIR/gate3-required-with-na.out" 2>&1; then
  fail 'Gate 3 accepted N/A artifact contrary to REQUIRED Product Profile'
fi
grep -Fq 'current N/A decision противоречит REQUIRED profile' \
  "$TMP_DIR/gate3-required-with-na.out" ||
  fail 'Gate 3 did not report REQUIRED/N-A contradiction'
sed -i 's/^api_contract_design: required/api_contract_design: not-applicable/' \
  "$P3/tracking/product-ci-profile.yaml" "$P3/tracking/product-ci-profile-history/revision-1.yaml"

P6="$TMP_DIR/gate6"
make_project "$P6"
printf '%s\n' 'status: PASS' > "$P6/stage6-deploy/outputs/DEPLOY-TDD-status.md"
write_artifact "$P6/stage6-deploy/outputs/REL-2026-07-21-checklist-v1.0.0.md"
write_artifact "$P6/stage6-deploy/outputs/REL-2026-07-21-release-notes-v1.0.0.md"
printf '%s\n' 'status: PASS' 'Rollback: tested' > "$P6/stage6-deploy/outputs/DEVOPS-2026-07-21-runbook.md"
printf '%s\n' '# Changelog' '## 1.0.0' > "$P6/CHANGELOG.md"
if bash "$DOR" "$P6" 6 > "$TMP_DIR/gate6-frozen.out" 2>&1; then
  fail 'DoR validator accepted frozen Gate 6'
fi
grep -Fq 'FROZEN / NOT SUPPORTED' "$TMP_DIR/gate6-frozen.out" ||
  fail 'DoR Gate 6 rejection did not explain frozen status'

PD="$TMP_DIR/document"
make_project "$PD"
write_artifact "$PD/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
write_artifact "$PD/stage1-planning/outputs/PM-2026-07-21-review.md"
document_output="$(bash "$DOD" "$PD" D 1)" ||
  fail 'valid document auto-check was rejected'
[[ "$document_output" == *'DoD auto-check PASSED'* ]] ||
  fail 'DoD validator did not distinguish its automatic verdict from full DoD sign-off'

if bash "$DOD" "$P6" D 6 > "$TMP_DIR/dod6-frozen.out" 2>&1; then
  fail 'DoD validator accepted frozen Stage 6'
fi
grep -Fq 'FROZEN / NOT SUPPORTED' "$TMP_DIR/dod6-frozen.out" ||
  fail 'DoD Stage 6 rejection did not explain frozen status'

if rg -n 'SDLC_RELEASE_PREPARATION|stage6-deploy|stage7-ops' "$DOD" > "$TMP_DIR/dod-frozen-reference.out"; then
  fail 'active DoD validator still reads frozen Stage 6/7 or release-preparation state'
fi

if bash "$DOD" "$PD" X 1 > "$TMP_DIR/invalid-type.out" 2>&1; then
  fail 'DoD validator accepted an unknown artifact type'
fi

echo 'PASS: gate validator behavior smoke'

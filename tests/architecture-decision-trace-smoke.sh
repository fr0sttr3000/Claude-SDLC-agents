#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-architecture-trace.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECK="$ROOT/cycle1-dev/s0-validate/architecture-decision-trace-check.sh"
CHECKS=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom
source "$ROOT/tests/lib/quality-characteristics-fixture.sh"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile() {
  local project="$1"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 3' 'revision: 1' 'previous_revision: 0' \
      'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: architecture trace fixture'
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
      'user_interface=graphical' 'ux_brief_requirement=required'; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_valid() {
  local project="$1"
  write_profile "$project"
  mkdir -p "$project/stage1-planning/inputs" "$project/stage2-requirements/outputs" \
    "$project/stage3-design/outputs"
  printf '%s\n' '# Idea' 'Runtime Constraints: network service requests finish within 500 ms p95' > \
    "$project/stage1-planning/inputs/idea.md"
  printf '%s\n' 'cycle1:' \
    '  runtime_constraints: "network service requests finish within 500 ms p95"' \
    '  runtime_constraints_source: "stage1-planning/inputs/idea.md#Runtime Constraints"' > \
    "$project/tracking/PMO-constraints.md"
  printf '%s\n' '# NFR' 'NFR-001: p95 latency is less than 500 ms.' \
    '## Runtime Constraints' \
    'Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints' \
    'Runtime Constraints scope: application-design-only' \
    'Runtime Constraints status: CONFIRMED' \
    'RC-001 | limitation | request p95 is below 500 ms | tracking/PMO-constraints.md#cycle1.runtime_constraints' > \
    "$project/stage2-requirements/outputs/BA-2026-07-27-NFR.md"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: architecture-hld' \
      'owner: s3-arch' 'product_profile_revision: 1' \
      'assumption_policy: no-unconfirmed-stack-or-topology' '---' '' '# HLD' '' \
      '## Runtime Constraints' \
      'Runtime Constraints source: stage2-requirements/outputs/BA-2026-07-27-NFR.md#Runtime Constraints' \
      'Runtime Constraints scope: application-design-only' \
      'Runtime Constraints status: CONFIRMED' \
      'Deployment/operations authorization: NOT_GRANTED' \
      'RC-001: bounded application timeout and latency verification.' '' \
      '## Architecture Decision Trace' \
      'DEC-001: NFR-001 → QA-Performance → TACTIC-Bound-Latency → PATTERN-Timeout → ADR-001.'
  } > "$project/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_type: architecture-decision' \
      'owner: s3-arch' 'product_profile_revision: 1' '---' '' '# ADR-001: Bound external latency' '' \
      'Decision ID: DEC-001' 'NFR: NFR-001' 'Quality Attribute: QA-Performance' \
      'Tactic: TACTIC-Bound-Latency' 'Pattern: PATTERN-Timeout' 'ADR: ADR-001' \
      'Trade-off gain: requests fail within the confirmed latency budget.' \
      'Trade-off cost: slow dependencies can return controlled failures.'
  } > "$project/stage3-design/outputs/ARCH-2026-07-27-ADR-001.md"
  {
    printf '%s\n' $'decision_id\tnfr_id\tquality_attribute_id\ttactic_id\tpattern_id\tadr_id\tadr_uri\tproduct_profile_revision'
    printf '%s\n' $'DEC-001\tNFR-001\tQA-Performance\tTACTIC-Bound-Latency\tPATTERN-Timeout\tADR-001\tstage3-design/outputs/ARCH-2026-07-27-ADR-001.md\t1'
  } > "$project/stage3-design/outputs/ARCH-decision-trace-v1.tsv"
  complete_artifact_metadata_fixture \
    "$project/stage3-design/outputs/ARCH-2026-07-27-HLD.md" "$project" \
    ARCH-HLD-V1 S3 s3-arch none APPROVED
  complete_artifact_metadata_fixture \
    "$project/stage3-design/outputs/ARCH-2026-07-27-ADR-001.md" "$project" \
    ARCH-ADR-001 S3 s3-arch none APPROVED
}

upgrade_to_v5() {
  local project="$1"
  sed -i 's/^schema_version: 3/schema_version: 5/' "$project/tracking/product-ci-profile.yaml"
  for pair in \
    'validation_environment_profile=connected-representative' \
    'validation_environment_identity=qa-service' \
    'validation_environment_authorization=required' \
    'performance_validation=required' \
    'runtime_security_validation=required' \
    'compatibility_validation=required' \
    'accessibility_validation=required' \
    'flexibility_validation=required' \
    'safety_validation=not-applicable'; do
    key="${pair%%=*}"; value="${pair#*=}"
    printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key" >> \
      "$project/tracking/product-ci-profile.yaml"
  done
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
  write_quality_characteristics_fixture "$project"
  {
    printf '%s\n' '' '## Quality Characteristic Scope' \
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
      'Safety evidence: NOT_APPLICABLE: no safety-critical harm scenario exists in confirmed PMO scope'
  } >> "$project/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
}

write_valid_v5() {
  local project="$1"
  write_valid "$project"
  upgrade_to_v5 "$project"
}

expect_blocked() {
  local label="$1" project="$2" output="$3"
  if bash "$CHECK" "$project" >"$output" 2>&1; then fail "$label"; fi
  grep -Fq 'ARCHITECTURE TRACE BLOCKED' "$output" || fail "$label did not emit BLOCKED"
}

P_VALID="$TMP_DIR/valid"
write_valid "$P_VALID"
bash "$CHECK" "$P_VALID" > "$TMP_DIR/valid.out" || fail 'valid decision trace was rejected'
grep -Fq 'ARCHITECTURE TRACE VERIFIED' "$TMP_DIR/valid.out" || fail 'verified verdict missing'

P_V5="$TMP_DIR/valid-v5"
write_valid_v5 "$P_V5"
bash "$CHECK" "$P_V5" >/dev/null || fail 'valid schema v5 quality scope was rejected'

P_V5_COMPAT="$TMP_DIR/missing-v5-compatibility"
write_valid_v5 "$P_V5_COMPAT"
sed -i '/^Compatibility evidence:/d' "$P_V5_COMPAT/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
expect_blocked 'required compatibility without HLD evidence id was accepted' \
  "$P_V5_COMPAT" "$TMP_DIR/v5-compatibility.out"

P_V5_SAFETY="$TMP_DIR/invalid-v5-safety-na"
write_valid_v5 "$P_V5_SAFETY"
sed -i 's/Safety evidence: NOT_APPLICABLE:.*/Safety evidence: NOT_APPLICABLE: unknown/' \
  "$P_V5_SAFETY/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
expect_blocked 'placeholder Safety N/A rationale was accepted' "$P_V5_SAFETY" "$TMP_DIR/v5-safety.out"

P_V5_FLEX="$TMP_DIR/incomplete-v5-flexibility"
write_valid_v5 "$P_V5_FLEX"
sed -i '/^Flexibility dimensions:/d' "$P_V5_FLEX/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
expect_blocked 'required Flexibility without install/update/configuration dimensions was accepted' \
  "$P_V5_FLEX" "$TMP_DIR/v5-flexibility.out"

P_COST="$TMP_DIR/missing-cost"
write_valid "$P_COST"
sed -i '/Trade-off cost:/d' "$P_COST/stage3-design/outputs/ARCH-2026-07-27-ADR-001.md"
expect_blocked 'ADR without trade-off cost was accepted' "$P_COST" "$TMP_DIR/cost.out"

P_NFR="$TMP_DIR/unknown-nfr"
write_valid "$P_NFR"
sed -i 's/NFR-001/NFR-999/g' "$P_NFR/stage3-design/outputs/ARCH-2026-07-27-HLD.md" \
  "$P_NFR/stage3-design/outputs/ARCH-2026-07-27-ADR-001.md" \
  "$P_NFR/stage3-design/outputs/ARCH-decision-trace-v1.tsv"
expect_blocked 'unknown NFR source was accepted' "$P_NFR" "$TMP_DIR/nfr.out"

P_ADR="$TMP_DIR/untraced-adr"
write_valid "$P_ADR"
cp "$P_ADR/stage3-design/outputs/ARCH-2026-07-27-ADR-001.md" \
  "$P_ADR/stage3-design/outputs/ARCH-2026-07-27-ADR-002.md"
expect_blocked 'untraced ADR artifact was accepted' "$P_ADR" "$TMP_DIR/adr.out"

P_REV="$TMP_DIR/wrong-revision"
write_valid "$P_REV"
sed -i 's/product_profile_revision: 1/product_profile_revision: 2/' \
  "$P_REV/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
expect_blocked 'HLD bound to wrong profile revision was accepted' "$P_REV" "$TMP_DIR/rev.out"

P_ASSUMPTION="$TMP_DIR/assumption-policy"
write_valid "$P_ASSUMPTION"
sed -i 's/no-unconfirmed-stack-or-topology/allow-default-stack/' \
  "$P_ASSUMPTION/stage3-design/outputs/ARCH-2026-07-27-HLD.md"
expect_blocked 'HLD allowed unconfirmed stack defaults' "$P_ASSUMPTION" "$TMP_DIR/assumption.out"

for producer in cycle1-dev/s3-arch/.claude/commands/hld.md cycle1-dev/s3-arch/.claude/commands/adr.md; do
  grep -Fq 'ARCH-decision-trace-v1.tsv' "$ROOT/$producer" || fail "$producer does not declare decision trace"
done
grep -Fq 'architecture-decision-trace-check.sh' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" ||
  fail 'Gate 3 does not invoke architecture decision trace validator'

echo 'PASS: architecture decision trace smoke'

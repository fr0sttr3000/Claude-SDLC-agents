#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SG1_CHECK="$ROOT/cycle1-dev/s0-validate/sg1-check.sh"
SG2_CHECK="$ROOT/cycle1-dev/s0-validate/sg2-check.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-sg12.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() {
  local label="$1"
  shift
  if "$@" >"$TMP_DIR/fail.out" 2>&1; then fail "$label was accepted"; fi
}

write_profile_v5() {
  local project="$1" pair key value
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 5' 'revision: 1' 'previous_revision: 0' \
      'updated_at: 2026-08-17T12:00:00Z' 'revision_reason: confirmed security validation fixture'
    for pair in \
      'product_type=service' 'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' 'scm_review_policy=required-review' \
      'scm_required_checks=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom' \
      'ci_provider=github-actions' 'ci_runners=hosted-linux' \
      'ci_trust_boundary=protected-workflow' 'ci_report_formats=junit,tap,sarif,json' \
      'build_toolchain=native-project-toolchain' 'build_command=make test-build' \
      'package_command=not-applicable' 'build_output_contract=not-applicable' \
      'secret_provider=pass' 'ci_identity_references=github-actions:security-job' \
      'compliance_constraints=none' 'offline_mode=online' \
      'approval_constraints=required-review' 'quality_overrides=none' \
      'evidence_source_profile=repository-ci' 'evidence_repository_path=.' \
      'evidence_executor_identity=github-actions:workflow-security' \
      'evidence_trusted_producers=github-actions:security-job' \
      'evidence_freshness_seconds=3600' 'evidence_signature_policy=if-produced' \
      'evidence_merge_blocking=required' 'build_subject=source-only' \
      'sbom_requirement=not-applicable' 'user_interface=none' \
      'ux_brief_requirement=not-applicable' \
      'validation_environment_profile=connected-representative' \
      'validation_environment_identity=qa-service' \
      'validation_environment_authorization=required' \
      'performance_validation=required' 'runtime_security_validation=required' \
      'compatibility_validation=required' 'accessibility_validation=not-applicable' \
      'flexibility_validation=required' 'safety_validation=not-applicable' \
      'api_contract_design=required' 'data_store_design=required' \
      'authorization_design=required'; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

set_architecture_applicability() {
  local project="$1" value="$2"
  sed -i "s/^api_contract_design: .*/api_contract_design: $value/" \
    "$project/tracking/product-ci-profile.yaml"
  sed -i "s/^authorization_design: .*/authorization_design: $value/" \
    "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

[[ -x "$SG1_CHECK" && -x "$SG2_CHECK" ]] || fail 'SG1/SG2 validators are missing'

PROJECT="$TMP_DIR/Project"
mkdir -p "$PROJECT/tracking" "$PROJECT/stage2-requirements/outputs"
mkdir -p "$PROJECT/stage3-design/outputs"
write_profile_v5 "$PROJECT"
printf 'constraints\n' >"$PROJECT/tracking/PMO-constraints.md"
printf 'brd\n' >"$PROJECT/stage2-requirements/outputs/BA-2026-BRD.md"
printf 'nfr\n' >"$PROJECT/stage2-requirements/outputs/BA-2026-NFR.md"
printf 'backlog\n' >"$PROJECT/stage2-requirements/outputs/PO-2026-backlog.md"
printf 'hld\n' >"$PROJECT/stage3-design/outputs/ARCH-2026-HLD.md"

digest() { sha256sum "$1" | awk '{print $1}'; }
BRD_SHA="$(digest "$PROJECT/stage2-requirements/outputs/BA-2026-BRD.md")"
NFR_SHA="$(digest "$PROJECT/stage2-requirements/outputs/BA-2026-NFR.md")"
BACKLOG_SHA="$(digest "$PROJECT/stage2-requirements/outputs/PO-2026-backlog.md")"
CONSTRAINTS_SHA="$(digest "$PROJECT/tracking/PMO-constraints.md")"
HLD_SHA="$(digest "$PROJECT/stage3-design/outputs/ARCH-2026-HLD.md")"

write_sg1() {
  local second_fr="${1:-yes}"
  cat >"$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md" <<EOF
product_profile_revision: 1
brd_sha256: $BRD_SHA
nfr_sha256: $NFR_SHA
backlog_sha256: $BACKLOG_SHA
constraints_sha256: $CONSTRAINTS_SHA
asvs_version: 5.0.0
asvs_level: L2
data_classification_scope: DATA-001
critical_fr_scope: FR-001,FR-002
sg1_status: PASS
Data classification: DATA-001 | Entity: account-metadata | Class: internal | Rationale: authenticated account context
Scenario: SEC-SC-001 | FR: FR-001 | Abuse: ABUSE-001 | ASVS: v5.0.0-1.2.3 | Countermeasure: SEC-NFR-001
EOF
  if [[ "$second_fr" == yes ]]; then
    printf '%s\n' 'Scenario: SEC-SC-002 | FR: FR-002 | Abuse: ABUSE-002 | ASVS: v5.0.0-4.1.1 | Countermeasure: SEC-NFR-002' \
      >>"$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md"
  fi
}

write_sg1 yes
"$SG1_CHECK" "$PROJECT" >/dev/null || fail 'valid SG1 was rejected'
sed -i '/^Data classification:/d' "$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md"
expect_fail 'SG1 missing data classification record' "$SG1_CHECK" "$PROJECT"
write_sg1 yes
sed -i 's/ASVS: v5\.0\.0-1\.2\.3/ASVS: 1.2.3/' \
  "$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md"
expect_fail 'SG1 unversioned ASVS reference' "$SG1_CHECK" "$PROJECT"
write_sg1 yes
sed -i 's/^asvs_version: 5\.0\.0/asvs_version: 4.0.3/' \
  "$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md"
expect_fail 'SG1 wrong ASVS version' "$SG1_CHECK" "$PROJECT"
write_sg1 yes
sed -n '/^Scenario: SEC-SC-001/p' "$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md" >> \
  "$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md"
expect_fail 'SG1 duplicate scenario id' "$SG1_CHECK" "$PROJECT"
write_sg1 no
expect_fail 'SG1 missing critical FR coverage' "$SG1_CHECK" "$PROJECT"
write_sg1 yes
printf 'changed\n' >>"$PROJECT/stage2-requirements/outputs/BA-2026-BRD.md"
expect_fail 'SG1 stale BRD digest' "$SG1_CHECK" "$PROJECT"
printf 'brd\n' >"$PROJECT/stage2-requirements/outputs/BA-2026-BRD.md"
write_sg1 yes

write_sg2() {
  local applicability="${1:-REQUIRED}"
  SG1_SHA="$(digest "$PROJECT/stage2-requirements/outputs/SEC-2026-security-requirements.md")"
  cat >"$PROJECT/stage3-design/outputs/SEC-2026-threat-model.md" <<EOF
product_profile_revision: 1
sg1_sha256: $SG1_SHA
hld_sha256: $HLD_SHA
asvs_version: 5.0.0
api_applicability: $applicability
authorization_applicability: $applicability
component_scope: CMP-API,CMP-STORE
sg2_status: PASS
Threat trace: THREAT-001 | Scenario: SEC-SC-001 | Component: CMP-API | Control: CTRL-001 | Test: SEC-TEST-001 | ASVS: v5.0.0-1.2.3 | Severity: Medium | Status: MITIGATED
Threat trace: THREAT-002 | Scenario: SEC-SC-002 | Component: CMP-STORE | Control: CTRL-002 | Test: SEC-TEST-002 | ASVS: v5.0.0-4.1.1 | Severity: High | Status: CLOSED
EOF
}

write_sg2 REQUIRED
"$SG2_CHECK" "$PROJECT" >/dev/null || fail 'valid SG2 was rejected'
sed -i '/^api_applicability:/d' "$PROJECT/stage3-design/outputs/SEC-2026-threat-model.md"
expect_fail 'SG2 missing API applicability binding' "$SG2_CHECK" "$PROJECT"
write_sg2 REQUIRED
sed -i 's/ASVS: v5\.0\.0-1\.2\.3/ASVS: v5.0.0-9.9.9/' \
  "$PROJECT/stage3-design/outputs/SEC-2026-threat-model.md"
expect_fail 'SG2 scenario ASVS does not match SG1' "$SG2_CHECK" "$PROJECT"
write_sg2 REQUIRED
sed -i 's/Status: CLOSED/Status: OPEN/' "$PROJECT/stage3-design/outputs/SEC-2026-threat-model.md"
expect_fail 'SG2 open High threat' "$SG2_CHECK" "$PROJECT"
write_sg2 REQUIRED
sed -i '/SEC-SC-002/d' "$PROJECT/stage3-design/outputs/SEC-2026-threat-model.md"
expect_fail 'SG2 missing scenario/component coverage' "$SG2_CHECK" "$PROJECT"
write_sg2 REQUIRED
printf 'changed HLD\n' >> "$PROJECT/stage3-design/outputs/ARCH-2026-HLD.md"
expect_fail 'SG2 stale HLD digest' "$SG2_CHECK" "$PROJECT"
printf 'hld\n' > "$PROJECT/stage3-design/outputs/ARCH-2026-HLD.md"

set_architecture_applicability "$PROJECT" not-applicable
write_sg2 REQUIRED
expect_fail 'SG2 applicability contrary to current Product Profile' "$SG2_CHECK" "$PROJECT"
write_sg2 NOT_APPLICABLE
"$SG2_CHECK" "$PROJECT" >/dev/null || fail 'valid non-API SG2 was rejected'

echo 'PASS: SG1/SG2 semantic validation smoke'

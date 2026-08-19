#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CHECK="$ROOT/cycle1-dev/s0-validate/known-issue-lifecycle-check.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-known-issue-lifecycle.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
SOURCE=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SUBJECT=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
CHECKS=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom
fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile() {
  local project="$1"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 2' 'revision: 1' 'previous_revision: 0' \
      'updated_at: 2026-08-17T12:00:00Z' 'revision_reason: KI lifecycle fixture'
    for pair in \
      'product_type=service' 'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' 'scm_review_policy=required-review' \
      "scm_required_checks=$CHECKS" 'ci_provider=github-actions' \
      'ci_runners=hosted-linux' 'ci_trust_boundary=protected-workflow' \
      'ci_report_formats=junit,tap,sarif,json' 'build_toolchain=native-project-toolchain' \
      'build_command=make build' 'package_command=make package' \
      'build_output_contract=dist/release.bin' 'secret_provider=pass' \
      'ci_identity_references=github-actions:release-job' 'compliance_constraints=none' \
      'offline_mode=online' 'approval_constraints=required-review' 'quality_overrides=none' \
      'evidence_source_profile=repository-ci' 'evidence_repository_path=.' \
      'evidence_executor_identity=github-actions:workflow-release' \
      'evidence_trusted_producers=github-actions:release-job' \
      'evidence_freshness_seconds=3600' 'evidence_signature_policy=if-produced' \
      'evidence_merge_blocking=required' 'build_subject=build-artifact' \
      'sbom_requirement=required'; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_trace() {
  local project="$1"
  mkdir -p "$project/stage2-requirements/outputs" "$project/stage3-design/outputs" \
    "$project/tests" "$project/tracking"
  printf '%s\n' 'FR-001' > "$project/stage2-requirements/outputs/BRD.md"
  printf '%s\n' 'ARCH-001' > "$project/stage3-design/outputs/ARCH-HLD.md"
  printf '%s\n' 'TEST-KI-001 verifies KI-001 fix' > "$project/tests/test_ki_fix.txt"
  printf '%s\n' \
    $'requirement_id\trequirement_uri\tspecification_id\tspecification_uri\ttest_id\ttest_uri\tsource_revision' \
    $'FR-001\tstage2-requirements/outputs/BRD.md\tARCH-001\tstage3-design/outputs/ARCH-HLD.md\tTEST-KI-001\ttests/test_ki_fix.txt\t'"$SOURCE" \
    > "$project/tracking/traceability-v1.tsv"
}

write_build_evidence() {
  local project="$1" fix_id="${2:-KI-001}" raw_sha
  mkdir -p "$project/tracking/evidence/v1" "$project/tracking/evidence/raw"
  printf '{"schema_version":1,"check_id":"build","source_revision":"%s","subject_digest":"%s","build_identity":"release:v1.2.3","release_version":"v1.2.3","verdict":"PASS","included_fix_ids":["%s"],"verification_test_ids":["TEST-KI-001"]}\n' \
    "$SOURCE" "$SUBJECT" "$fix_id" > "$project/tracking/evidence/raw/release-build.json"
  raw_sha="$(sha256sum "$project/tracking/evidence/raw/release-build.json" | awk '{print $1}')"
  {
    printf '%s\n' 'schema_version: 1' 'evidence_id: EV-RELEASE-BUILD-001' \
      'check_id: build' 'category: build' 'source_profile: repository-ci' \
      'execution_mode: live' 'executor_identity: github-actions:workflow-release' \
      'producer_identity: github-actions:release-job' 'tool_name: release-builder' \
      'tool_version: 1.0.0' "source_revision: $SOURCE" \
      'subject_kind: build-artifact' "subject_digest: $SUBJECT" \
      'build_identity: release:v1.2.3' 'config_revision: release-config-v1' \
      'policy_revision: release-build-v1' 'product_profile_revision: 1' \
      "observed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" 'freshness_seconds: 3600' \
      'raw_format: json' 'raw_result_uri: tracking/evidence/raw/release-build.json' \
      "raw_result_sha256: $raw_sha" 'signature_status: not-provided' 'verdict: PASS' \
      'applicability_reason: none' 'applicability_owner: none' \
      'requirement_ids: FR-001' 'specification_ids: ARCH-001' \
      'test_ids: TEST-KI-001' 'human_approval_ref: none' 'risk_exception_ref: none'
  } > "$project/tracking/evidence/v1/EV-RELEASE-BUILD-001.yaml"
}

write_td() {
  local project="$1" status="$2"
  printf '%s\n' '# Tech Debt — fixture' '' '### TD-001 — Fix KI-001' \
    "- Статус: $status" > "$project/tracking/tech-debt.md"
}

write_ki() {
  local project="$1" status="$2" operational="${3:-FROZEN_NOT_READY}"
  local version=none ref=none sha=none source=none test_id=none
  local alert=none runbook=none
  if [[ "$status" == FIXED ]]; then
    version=v1.2.3
    ref=tracking/evidence/v1/EV-RELEASE-BUILD-001.yaml
    sha="$(sha256sum "$project/$ref" | awk '{print $1}')"
    source="$SOURCE"
    test_id=TEST-KI-001
    if [[ "$operational" == ACTIVE ]]; then
      mkdir -p "$project/tracking/operations/evidence"
      printf '%s\n' 'alert KI-001 removed' > "$project/tracking/operations/evidence/alert.md"
      printf '%s\n' 'runbook KI-001 retired' > "$project/tracking/operations/evidence/runbook.md"
      alert="ref=tracking/operations/evidence/alert.md;sha256=$(sha256sum "$project/tracking/operations/evidence/alert.md" | awk '{print $1}')"
      runbook="ref=tracking/operations/evidence/runbook.md;sha256=$(sha256sum "$project/tracking/operations/evidence/runbook.md" | awk '{print $1}')"
    fi
  fi
  {
    printf '%s\n' '# Known Issues — fixture' '' '### KI-001 — Released fix fixture' \
      '- Severity: S3' '- Trigger: user opens the affected flow' \
      '- Impact: user-facing — bounded incorrect response' \
      '- Workaround: retry through the alternate flow' \
      '- Detection signal: exact KI-001 validation event' '- Auto-remediation: нет' \
      '- → tech-debt: TD-001' \
      '- Human Approval v1: tracking/approvals/APPROVAL-KI-001.yaml' \
      "- Fix release version: $version" "- Fix build evidence ref: $ref" \
      "- Fix build evidence sha256: $sha" "- Fix source revision: $source" \
      "- Fix verification test id: $test_id" "- Operational scope: $operational" \
      "- Alert cleanup evidence: $alert" "- Runbook cleanup evidence: $runbook" \
      "- Status: $status"
  } > "$project/tracking/known-issues.md"
}

expect_blocked() {
  local label="$1" output="$2" project="$3"
  if bash "$CHECK" "$project" > "$output" 2>&1; then fail "$label"; fi
  grep -Fq 'KNOWN ISSUE LIFECYCLE BLOCKED' "$output" ||
    fail "$label did not emit fail-closed reason"
}

BASE="$TMP_DIR/base"
mkdir -p "$BASE/tracking"
write_profile "$BASE"
write_trace "$BASE"
write_build_evidence "$BASE"
write_td "$BASE" OPEN
write_ki "$BASE" OPEN
bash "$CHECK" "$BASE" >/dev/null || fail 'valid OPEN template instance was rejected'

for severity in S3 S4 CVSS-MEDIUM CVSS-LOW; do
  P_SEVERITY="$TMP_DIR/open-${severity,,}"
  cp -a "$BASE" "$P_SEVERITY"
  sed -i "s/^- Severity: S3/- Severity: $severity/" \
    "$P_SEVERITY/tracking/known-issues.md"
  bash "$CHECK" "$P_SEVERITY" >/dev/null ||
    fail "valid OPEN severity was rejected: $severity"
done

P_IMPACT_FIELD="$TMP_DIR/impact-field"
cp -a "$BASE" "$P_IMPACT_FIELD"
sed -i 's/^- Impact:/- Impact \/ blast radius:/' "$P_IMPACT_FIELD/tracking/known-issues.md"
expect_blocked 'legacy Impact / blast radius field was accepted' \
  "$TMP_DIR/impact-field.out" "$P_IMPACT_FIELD"

P_NUMERIC_CVSS="$TMP_DIR/numeric-cvss"
cp -a "$BASE" "$P_NUMERIC_CVSS"
sed -i 's/^- Severity: S3/- Severity: CVSS 5.5/' "$P_NUMERIC_CVSS/tracking/known-issues.md"
expect_blocked 'numeric CVSS severity was accepted in Known Issue schema' \
  "$TMP_DIR/numeric-cvss.out" "$P_NUMERIC_CVSS"

P_OPEN_CLAIM="$TMP_DIR/open-claims-fix"
cp -a "$BASE" "$P_OPEN_CLAIM"
sed -i 's/Fix release version: none/Fix release version: v1.2.3/' \
  "$P_OPEN_CLAIM/tracking/known-issues.md"
expect_blocked 'OPEN KI claiming fix version was accepted' "$TMP_DIR/open-claim.out" "$P_OPEN_CLAIM"

P_FIXED="$TMP_DIR/fixed"
cp -a "$BASE" "$P_FIXED"
write_td "$P_FIXED" RESOLVED
write_ki "$P_FIXED" FIXED
bash "$CHECK" "$P_FIXED" >/dev/null || fail 'valid released-build FIXED transition was rejected'

P_UNRESOLVED="$TMP_DIR/fixed-unresolved"
cp -a "$P_FIXED" "$P_UNRESOLVED"
write_td "$P_UNRESOLVED" OPEN
expect_blocked 'FIXED KI with active Tech Debt was accepted' "$TMP_DIR/unresolved.out" "$P_UNRESOLVED"

P_WRONG_FIX="$TMP_DIR/wrong-fix"
cp -a "$BASE" "$P_WRONG_FIX"
write_build_evidence "$P_WRONG_FIX" KI-OTHER
write_td "$P_WRONG_FIX" RESOLVED
write_ki "$P_WRONG_FIX" FIXED
expect_blocked 'released build omitting exact KI fix was accepted' "$TMP_DIR/wrong-fix.out" "$P_WRONG_FIX"

P_VALIDATION_ONLY="$TMP_DIR/validation-only"
cp -a "$P_FIXED" "$P_VALIDATION_ONLY"
sed -i -e 's/check_id: build/check_id: unit/' -e 's/category: build/category: test/' \
  "$P_VALIDATION_ONLY/tracking/evidence/v1/EV-RELEASE-BUILD-001.yaml"
evidence_sha="$(sha256sum "$P_VALIDATION_ONLY/tracking/evidence/v1/EV-RELEASE-BUILD-001.yaml" | awk '{print $1}')"
sed -i "s/^Fix build evidence sha256:.*/Fix build evidence sha256: $evidence_sha/" \
  "$P_VALIDATION_ONLY/tracking/known-issues.md"
expect_blocked 'validation-only Evidence closed KI' "$TMP_DIR/validation-only.out" "$P_VALIDATION_ONLY"

P_ACTIVE_MISSING="$TMP_DIR/active-missing"
cp -a "$P_FIXED" "$P_ACTIVE_MISSING"
sed -i 's/Operational scope: FROZEN_NOT_READY/Operational scope: ACTIVE/' \
  "$P_ACTIVE_MISSING/tracking/known-issues.md"
expect_blocked 'ACTIVE operational scope without cleanup evidence was accepted' \
  "$TMP_DIR/active-missing.out" "$P_ACTIVE_MISSING"

P_ACTIVE="$TMP_DIR/active"
cp -a "$BASE" "$P_ACTIVE"
write_td "$P_ACTIVE" RESOLVED
write_ki "$P_ACTIVE" FIXED ACTIVE
bash "$CHECK" "$P_ACTIVE" >/dev/null ||
  fail 'ACTIVE operational scope with digest-bound cleanup evidence was rejected'

echo 'PASS: Known Issue lifecycle smoke'

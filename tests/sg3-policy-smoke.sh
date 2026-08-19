#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-sg3-policy.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
SG3_CHECK="$ROOT/cycle1-dev/s0-validate/sg3-policy-check.sh"
SOURCE_REVISION=4444444444444444444444444444444444444444

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile() {
  local project="$1"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 2' 'revision: 1' 'previous_revision: 0'
    printf '%s\n' 'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: SG3 fixture'
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
      'sbom_requirement=not-applicable'; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_record() {
  local project="$1" check="$2" verdict="${3:-PASS}" id raw raw_sha reason=none owner=none
  id="${check^^}"; id="${id//-/_}"
  raw="tracking/evidence/raw/$check.json"
  mkdir -p "$project/tracking/evidence/v1" "$project/tracking/evidence/raw"
  printf '{"schema_version":1,"check_id":"%s","source_revision":"%s","secret_count":0,"integrity_status":"pass","tampered_dependencies":0,"malicious_dependencies":0,"findings":[]}\n' \
    "$check" "$SOURCE_REVISION" > "$project/$raw"
  raw_sha="$(sha256sum "$project/$raw" | awk '{print $1}')"
  mkdir -p "$project/stage2-requirements/outputs" "$project/stage3-design/outputs" "$project/tests"
  printf '%s\n' 'SEC-001' > "$project/stage2-requirements/outputs/SEC-requirements.md"
  printf '%s\n' 'TM-001' > "$project/stage3-design/outputs/SEC-threat-model.md"
  printf 'SG3-%s\n' "$id" >> "$project/tests/trace-security.txt"
  trace="$project/tracking/traceability-v1.tsv"
  if [[ ! -f "$trace" ]]; then
    printf '%s\n' $'requirement_id\trequirement_uri\tspecification_id\tspecification_uri\ttest_id\ttest_uri\tsource_revision' > "$trace"
  fi
  printf 'SEC-001\tstage2-requirements/outputs/SEC-requirements.md\tTM-001\tstage3-design/outputs/SEC-threat-model.md\tSG3-%s\ttests/trace-security.txt\t%s\n' \
    "$id" "$SOURCE_REVISION" >> "$trace"
  [[ "$verdict" != NOT_APPLICABLE ]] || { reason='no image subject'; owner=s0-kickoff; }
  {
    printf '%s\n' 'schema_version: 1'
    printf 'evidence_id: EV-%s\ncheck_id: %s\ncategory: security\n' "$id" "$check"
    printf '%s\n' 'source_profile: repository-ci' 'execution_mode: live' \
      'executor_identity: github-actions:workflow-security' \
      'producer_identity: github-actions:security-job' \
      'tool_name: normalized-security-adapter' 'tool_version: 1.0.0'
    printf 'source_revision: %s\n' "$SOURCE_REVISION"
    printf '%s\n' 'subject_kind: source' 'subject_digest: none' 'build_identity: none' \
      'config_revision: cfg-1' 'policy_revision: security-v1' 'product_profile_revision: 1'
    printf 'observed_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' 'freshness_seconds: 3600' 'raw_format: json'
    printf 'raw_result_uri: %s\nraw_result_sha256: %s\n' "$raw" "$raw_sha"
    printf 'signature_status: not-provided\nverdict: %s\n' "$verdict"
    printf 'applicability_reason: %s\napplicability_owner: %s\n' "$reason" "$owner"
    printf '%s\n' 'requirement_ids: SEC-001' 'specification_ids: TM-001' \
      "test_ids: SG3-$id" 'human_approval_ref: none' 'risk_exception_ref: none'
  } > "$project/tracking/evidence/v1/EV-$id.yaml"
}

write_sg3_set() {
  local project="$1"
  write_profile "$project"
  write_record "$project" secrets
  write_record "$project" sast
  write_record "$project" sca
  write_record "$project" dependency-integrity
  write_record "$project" image-scan NOT_APPLICABLE
}

replace_raw() {
  local project="$1" check="$2" json="$3" id sha
  id="${check^^}"; id="${id//-/_}"
  printf '%s\n' "$json" > "$project/tracking/evidence/raw/$check.json"
  sha="$(sha256sum "$project/tracking/evidence/raw/$check.json" | awk '{print $1}')"
  sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $sha/" \
    "$project/tracking/evidence/v1/EV-$id.yaml"
}

expect_blocked() {
  local label="$1" output="$2" project="$3"
  if bash "$SG3_CHECK" "$project" "$SOURCE_REVISION" > "$output" 2>&1; then fail "$label"; fi
  grep -Eq 'SG3 BLOCKED|UNVERIFIED|FAIL' "$output" || fail "$label did not explain blocker"
}

P_VALID="$TMP_DIR/valid"
write_sg3_set "$P_VALID"
bash "$SG3_CHECK" "$P_VALID" "$SOURCE_REVISION" > "$TMP_DIR/valid.out" ||
  fail 'valid zero-finding SG3 set was rejected'
grep -Fq 'SG3 VERIFIED' "$TMP_DIR/valid.out" || fail 'SG3 did not emit VERIFIED'

P_SECRET="$TMP_DIR/secret"
write_sg3_set "$P_SECRET"
replace_raw "$P_SECRET" secrets \
  "{\"schema_version\":1,\"check_id\":\"secrets\",\"source_revision\":\"$SOURCE_REVISION\",\"secret_count\":1,\"integrity_status\":\"pass\",\"tampered_dependencies\":0,\"malicious_dependencies\":0,\"findings\":[]}"
expect_blocked 'SG3 accepted a secret finding' "$TMP_DIR/secret.out" "$P_SECRET"

P_HIGH="$TMP_DIR/high"
write_sg3_set "$P_HIGH"
replace_raw "$P_HIGH" sast \
  "{\"schema_version\":1,\"check_id\":\"sast\",\"source_revision\":\"$SOURCE_REVISION\",\"secret_count\":0,\"integrity_status\":\"pass\",\"tampered_dependencies\":0,\"malicious_dependencies\":0,\"findings\":[{\"id\":\"CWE-79\",\"cvss\":7.0,\"status\":\"open\"}]}"
expect_blocked 'SG3 accepted a High finding' "$TMP_DIR/high.out" "$P_HIGH"

P_SARIF="$TMP_DIR/sarif"
write_sg3_set "$P_SARIF"
printf '%s\n' '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"fixture"}},"results":[]}]}' > \
  "$P_SARIF/tracking/evidence/raw/sast.sarif"
sarif_sha="$(sha256sum "$P_SARIF/tracking/evidence/raw/sast.sarif" | awk '{print $1}')"
sed -i \
  -e 's/raw_format: json/raw_format: sarif/' \
  -e 's#raw_result_uri: tracking/evidence/raw/sast.json#raw_result_uri: tracking/evidence/raw/sast.sarif#' \
  -e "s/^raw_result_sha256:.*/raw_result_sha256: $sarif_sha/" \
  "$P_SARIF/tracking/evidence/v1/EV-SAST.yaml"
bash "$SG3_CHECK" "$P_SARIF" "$SOURCE_REVISION" >/dev/null || fail 'clean SARIF SG3 result was rejected'
printf '%s\n' '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"fixture"}},"results":[{"ruleId":"CWE-89","properties":{"security-severity":"7.5"}}]}]}' > \
  "$P_SARIF/tracking/evidence/raw/sast.sarif"
sarif_sha="$(sha256sum "$P_SARIF/tracking/evidence/raw/sast.sarif" | awk '{print $1}')"
sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $sarif_sha/" \
  "$P_SARIF/tracking/evidence/v1/EV-SAST.yaml"
expect_blocked 'SG3 accepted High SARIF finding' "$TMP_DIR/sarif-high.out" "$P_SARIF"

P_DEP="$TMP_DIR/dependency"
write_sg3_set "$P_DEP"
replace_raw "$P_DEP" dependency-integrity \
  "{\"schema_version\":1,\"check_id\":\"dependency-integrity\",\"source_revision\":\"$SOURCE_REVISION\",\"secret_count\":0,\"integrity_status\":\"fail\",\"tampered_dependencies\":1,\"malicious_dependencies\":1,\"findings\":[]}"
expect_blocked 'SG3 accepted tampered/malicious dependencies' "$TMP_DIR/dependency.out" "$P_DEP"

P_LOW="$TMP_DIR/low"
write_sg3_set "$P_LOW"
replace_raw "$P_LOW" sca \
  "{\"schema_version\":1,\"check_id\":\"sca\",\"source_revision\":\"$SOURCE_REVISION\",\"secret_count\":0,\"integrity_status\":\"pass\",\"tampered_dependencies\":0,\"malicious_dependencies\":0,\"findings\":[{\"id\":\"CVE-TEST-LOW\",\"cvss\":2.5,\"status\":\"open\"}]}"
expect_blocked 'SG3 accepted Low without tech debt' "$TMP_DIR/low-missing.out" "$P_LOW"
low_deadline="$(date -u -d '+60 days' +%Y-%m-%d)"
low_sprint_end="$(date -u -d '+65 days' +%Y-%m-%d)"
mkdir -p "$P_LOW/tracking/sprints"
printf '%s\n' '---' 'sprint: 1' 'start: 2026-07-01' 'end: 2026-07-14' 'status: CLOSED' '---' > \
  "$P_LOW/tracking/sprints/sprint-01.md"
printf '%s\n' '---' 'sprint: 3' "start: $(date -u +%Y-%m-%d)" "end: $low_sprint_end" 'status: PLANNED' '---' > \
  "$P_LOW/tracking/sprints/sprint-03.md"
{
  printf '%s\n' '# Tech Debt Log — fixture' '### TD-SEC-LOW — Low dependency finding'
  printf '%s\n' '- Source sprint: 1' '- Target sprint: 3' "- Дедлайн устранения: $low_deadline"
  printf '%s\n' '- Owner: product-security-owner' '- Exception type: security' \
    '- Finding severity: SECURITY_LOW' '- Finding IDs: CVE-TEST-LOW' '- CVSS: 2.5' \
    '- Risk exception: none' '- Статус: OPEN'
} > "$P_LOW/tracking/tech-debt.md"
bash "$SG3_CHECK" "$P_LOW" "$SOURCE_REVISION" >/dev/null ||
  fail 'valid Low finding tech debt was rejected'

P_LOW_LATE="$TMP_DIR/low-late"
cp -a "$P_LOW" "$P_LOW_LATE"
sed -i 's/Target sprint: 3/Target sprint: 5/' "$P_LOW_LATE/tracking/tech-debt.md"
mv "$P_LOW_LATE/tracking/sprints/sprint-03.md" "$P_LOW_LATE/tracking/sprints/sprint-05.md"
sed -i 's/sprint: 3/sprint: 5/' "$P_LOW_LATE/tracking/sprints/sprint-05.md"
expect_blocked 'SG3 accepted Low remediation beyond three sprints' "$TMP_DIR/low-late.out" "$P_LOW_LATE"

P_MEDIUM="$TMP_DIR/medium"
write_sg3_set "$P_MEDIUM"
replace_raw "$P_MEDIUM" sca \
  "{\"schema_version\":1,\"check_id\":\"sca\",\"source_revision\":\"$SOURCE_REVISION\",\"secret_count\":0,\"integrity_status\":\"pass\",\"tampered_dependencies\":0,\"malicious_dependencies\":0,\"findings\":[{\"id\":\"CVE-TEST-MEDIUM\",\"cvss\":5.5,\"status\":\"open\"}]}"
expect_blocked 'SG3 accepted Medium without risk exception' "$TMP_DIR/medium-missing.out" "$P_MEDIUM"
mkdir -p "$P_MEDIUM/tracking/risk-exceptions"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
expires_at="$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)"
deadline="$(date -u -d '+30 days' +%Y-%m-%d)"
sprint_end="$(date -u -d '+35 days' +%Y-%m-%d)"
mkdir -p "$P_MEDIUM/tracking/sprints"
printf '%s\n' '---' 'sprint: 1' 'start: 2026-07-01' 'end: 2026-07-14' 'status: CLOSED' '---' > \
  "$P_MEDIUM/tracking/sprints/sprint-01.md"
printf '%s\n' '---' 'sprint: 2' "start: $(date -u +%Y-%m-%d)" "end: $sprint_end" 'status: ACTIVE' '---' > \
  "$P_MEDIUM/tracking/sprints/sprint-02.md"
{
  printf '%s\n' '# Tech Debt Log — fixture' '### TD-SEC-MEDIUM — Medium dependency finding'
  printf '%s\n' '- Source sprint: 1' '- Target sprint: 2' "- Дедлайн устранения: $deadline"
  printf '%s\n' '- Owner: product-security-owner' '- Exception type: security' \
    '- Finding severity: SECURITY_MEDIUM' '- Finding IDs: CVE-TEST-MEDIUM' '- CVSS: 5.5' \
    '- Risk exception: RISK-MEDIUM' '- Статус: OPEN'
} > "$P_MEDIUM/tracking/tech-debt.md"
{
  printf '%s\n' 'schema_version: 3' 'exception_id: RISK-MEDIUM' \
    'exception_type: security' 'finding_severity: SECURITY_MEDIUM' \
    'tech_debt_id: TD-SEC-MEDIUM' 'known_issue_id: none' \
    'owner: product-security-owner' 'approved_by: s4-techlead' \
    'rationale: bounded remediation accepted for current source' \
    'scope: sca CVE-TEST-MEDIUM only' 'check_id: sca' \
    'finding_ids: CVE-TEST-MEDIUM'
  printf 'source_revision: %s\n' "$SOURCE_REVISION"
  printf 'subject_digest: none\ncreated_at: %s\nexpires_at: %s\nstatus: ACTIVE\n' \
    "$created_at" "$expires_at"
} > "$P_MEDIUM/tracking/risk-exceptions/RISK-MEDIUM.yaml"
sed -i 's#risk_exception_ref: none#risk_exception_ref: tracking/risk-exceptions/RISK-MEDIUM.yaml#' \
  "$P_MEDIUM/tracking/evidence/v1/EV-SCA.yaml"
bash "$SG3_CHECK" "$P_MEDIUM" "$SOURCE_REVISION" >/dev/null ||
  fail 'valid scoped Medium risk exception was rejected'

P_LEGACY="$TMP_DIR/medium-legacy"
cp -a "$P_MEDIUM" "$P_LEGACY"
sed -i -e 's/schema_version: 3/schema_version: 2/' -e '/^exception_type:/d' \
  -e '/^finding_severity:/d' -e '/^known_issue_id:/d' \
  "$P_LEGACY/tracking/risk-exceptions/RISK-MEDIUM.yaml"
expect_blocked 'SG3 accepted legacy Risk Exception v2 for new verdict' "$TMP_DIR/medium-legacy.out" "$P_LEGACY"

P_91="$TMP_DIR/medium-91-days"
cp -a "$P_MEDIUM" "$P_91"
expires_91="$(date -u -d '+91 days' +%Y-%m-%dT%H:%M:%SZ)"
sed -i "s/expires_at: $expires_at/expires_at: $expires_91/" \
  "$P_91/tracking/risk-exceptions/RISK-MEDIUM.yaml"
expect_blocked 'SG3 accepted a 91-day risk exception' "$TMP_DIR/medium-91.out" "$P_91"

P_NO_TD="$TMP_DIR/medium-no-td"
cp -a "$P_MEDIUM" "$P_NO_TD"
sed -i 's/tech_debt_id: TD-SEC-MEDIUM/tech_debt_id: TD-MISSING/' \
  "$P_NO_TD/tracking/risk-exceptions/RISK-MEDIUM.yaml"
expect_blocked 'SG3 accepted exception without linked tech debt' "$TMP_DIR/medium-no-td.out" "$P_NO_TD"

P_NO_SPRINT="$TMP_DIR/medium-no-sprint-boundary"
cp -a "$P_MEDIUM" "$P_NO_SPRINT"
rm "$P_NO_SPRINT/tracking/sprints/sprint-02.md"
expect_blocked 'SG3 accepted exception without target sprint boundary' "$TMP_DIR/medium-no-sprint.out" "$P_NO_SPRINT"

sed -i "s/expires_at: $expires_at/expires_at: 2000-01-01T00:00:00Z/" \
  "$P_MEDIUM/tracking/risk-exceptions/RISK-MEDIUM.yaml"
expect_blocked 'SG3 accepted expired risk exception' "$TMP_DIR/medium-expired.out" "$P_MEDIUM"

echo 'PASS: SG3 policy smoke'

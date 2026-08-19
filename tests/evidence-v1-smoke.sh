#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-evidence-v1.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/human-approval-receipts"
PROFILE_VALIDATOR="$ROOT/cycle1-dev/s0-validate/product-ci-profile-check.sh"
EVIDENCE_VALIDATOR="$ROOT/cycle1-dev/s0-validate/evidence-v1-check.sh"
SECRETS_VALIDATOR="$ROOT/cycle1-dev/s0-validate/secrets-result-check.sh"
SUMMARY_GENERATOR="$ROOT/cycle1-dev/s0-validate/evidence-v1-summary.sh"
CONTROLS_VALIDATOR="$ROOT/cycle1-dev/s0-validate/executor-controls-check.sh"
SOURCE_REVISION=1111111111111111111111111111111111111111
REQUIRED_CHECKS=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile_v2() {
  local project="$1" source_profile="$2"
  local provider runner trust executor producer offline merge
  case "$source_profile" in
    repository-ci)
      provider=github-actions
      runner=hosted-linux
      trust=protected-workflow
      executor=github-actions:workflow-security
      producer=github-actions:security-job
      offline=online
      merge=required
      ;;
    connected-runner)
      provider=connected-service
      runner=authorized-runner
      trust=approved-service-boundary
      executor=runner-service:trusted
      producer=runner-service:scanner
      offline=online
      merge=required
      ;;
    local-offline)
      provider=local-validator
      runner=local-isolated-process
      trust=project-worktree
      executor=local-validator:approved
      producer=local-validator:toolchain
      offline=air-gapped
      merge=not-applicable
      ;;
    *) fail "unknown fixture source profile: $source_profile" ;;
  esac

  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 2'
    printf '%s\n' 'revision: 1' 'previous_revision: 0'
    printf '%s\n' 'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: evidence contract fixture'
    for pair in \
      'product_type=service' \
      'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' \
      'scm_review_policy=required-review' \
      "scm_required_checks=$REQUIRED_CHECKS" \
      "ci_provider=$provider" \
      "ci_runners=$runner" \
      "ci_trust_boundary=$trust" \
      'ci_report_formats=junit,tap,sarif,json' \
      'build_toolchain=native-project-toolchain' \
      'build_command=make test-build' \
      'package_command=not-applicable' \
      'build_output_contract=not-applicable' \
      'secret_provider=pass' \
      "ci_identity_references=$producer" \
      'compliance_constraints=none' \
      "offline_mode=$offline" \
      'approval_constraints=required-review' \
      'quality_overrides=none' \
      "evidence_source_profile=$source_profile" \
      'evidence_repository_path=.' \
      "evidence_executor_identity=$executor" \
      "evidence_trusted_producers=$producer" \
      'evidence_freshness_seconds=3600' \
      'evidence_signature_policy=if-produced' \
      "evidence_merge_blocking=$merge" \
      'build_subject=source-only' \
      'sbom_requirement=not-applicable'; do
      key="${pair%%=*}"
      value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

profile_identity() {
  case "$1" in
    repository-ci) printf '%s\n' 'github-actions:workflow-security github-actions:security-job' ;;
    connected-runner) printf '%s\n' 'runner-service:trusted runner-service:scanner' ;;
    local-offline) printf '%s\n' 'local-validator:approved local-validator:toolchain' ;;
  esac
}

write_evidence() {
  local project="$1" source_profile="$2" mode="${3:-live}" verdict="${4:-PASS}"
  local observed_at="${5:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  local executor producer raw_path raw_sha
  read -r executor producer <<< "$(profile_identity "$source_profile")"
  mkdir -p "$project/tracking/evidence/v1" "$project/tracking/evidence/raw"
  raw_path=tracking/evidence/raw/unit.json
  printf '%s\n' '{"check":"unit","failures":0,"status":"pass"}' > "$project/$raw_path"
  raw_sha="$(sha256sum "$project/$raw_path" | awk '{print $1}')"
  mkdir -p "$project/stage2-requirements/outputs" "$project/stage3-design/outputs" "$project/tests"
  printf '%s\n' 'FR-001' > "$project/stage2-requirements/outputs/BRD.md"
  printf '%s\n' 'ARCH-001' > "$project/stage3-design/outputs/ARCH-HLD.md"
  printf '%s\n' 'TEST-UNIT-001' > "$project/tests/trace-tests.txt"
  printf '%s\n' $'requirement_id\trequirement_uri\tspecification_id\tspecification_uri\ttest_id\ttest_uri\tsource_revision' \
    $'FR-001\tstage2-requirements/outputs/BRD.md\tARCH-001\tstage3-design/outputs/ARCH-HLD.md\tTEST-UNIT-001\ttests/trace-tests.txt\t'"$SOURCE_REVISION" \
    > "$project/tracking/traceability-v1.tsv"
  {
    printf '%s\n' \
      'schema_version: 1' \
      'evidence_id: EV-UNIT-001' \
      'check_id: unit' \
      'category: test'
    printf 'source_profile: %s\nexecution_mode: %s\n' "$source_profile" "$mode"
    printf 'executor_identity: %s\nproducer_identity: %s\n' "$executor" "$producer"
    printf '%s\n' \
      'tool_name: project-test-runner' \
      'tool_version: 1.0.0'
    printf 'source_revision: %s\n' "$SOURCE_REVISION"
    printf '%s\n' \
      'subject_kind: source' \
      'subject_digest: none' \
      'build_identity: none' \
      'config_revision: cfg-1' \
      'policy_revision: policy-1' \
      'product_profile_revision: 1'
    printf 'observed_at: %s\nfreshness_seconds: 3600\n' "$observed_at"
    printf 'raw_format: json\nraw_result_uri: %s\nraw_result_sha256: %s\n' "$raw_path" "$raw_sha"
    printf '%s\n' \
      'signature_status: not-provided'
    printf 'verdict: %s\n' "$verdict"
    printf '%s\n' \
      'applicability_reason: none' \
      'applicability_owner: none' \
      'requirement_ids: FR-001' \
      'specification_ids: ARCH-001' \
      'test_ids: TEST-UNIT-001' \
      'human_approval_ref: none' \
      'risk_exception_ref: none'
  } > "$project/tracking/evidence/v1/EV-UNIT-001.yaml"
}

convert_to_secrets_evidence() {
  local project="$1" raw_sha
  printf '{"schema_version":1,"check_id":"secrets","source_revision":"%s","secret_count":0,"findings":[]}\n' \
    "$SOURCE_REVISION" > "$project/tracking/evidence/raw/unit.json"
  raw_sha="$(sha256sum "$project/tracking/evidence/raw/unit.json" | awk '{print $1}')"
  sed -i \
    -e 's/evidence_id: EV-UNIT-001/evidence_id: EV-SECRETS-001/' \
    -e 's/check_id: unit/check_id: secrets/' \
    -e 's/category: test/category: security/' \
    -e "s/^raw_result_sha256:.*/raw_result_sha256: $raw_sha/" \
    "$project/tracking/evidence/v1/EV-UNIT-001.yaml"
}

expect_blocked() {
  local label="$1" output="$2"
  shift 2
  if "$@" > "$output" 2>&1; then
    fail "$label"
  fi
  grep -Eq 'BLOCKED|UNVERIFIED|FAIL' "$output" ||
    fail "$label did not emit a fail-closed verdict"
}

for source_profile in repository-ci connected-runner local-offline; do
  project="$TMP_DIR/$source_profile"
  write_profile_v2 "$project" "$source_profile"
  bash "$PROFILE_VALIDATOR" "$project" >/dev/null ||
    fail "valid schema v2 $source_profile profile was rejected"
  write_evidence "$project" "$source_profile"
  bash "$EVIDENCE_VALIDATOR" "$project" \
    "$project/tracking/evidence/v1/EV-UNIT-001.yaml" \
    --expected-source "$SOURCE_REVISION" --expected-check unit > "$TMP_DIR/$source_profile.out" ||
    fail "valid $source_profile evidence was rejected"
  grep -Fq 'EVIDENCE VERIFIED' "$TMP_DIR/$source_profile.out" ||
    fail "$source_profile result was not marked VERIFIED"

  untrusted_pr=pass
  [[ "$source_profile" != local-offline ]] || untrusted_pr=not-applicable
  printf '{"schema_version":1,"check_id":"pipeline-policy","source_revision":"%s","controls":{"immutable_dependencies":"pass","least_privilege":"pass","untrusted_pr_isolation":"%s","protected_policy_files":"pass","artifact_cache_integrity":"pass"},"remediation":[]}\n' \
    "$SOURCE_REVISION" "$untrusted_pr" > "$project/tracking/evidence/raw/unit.json"
  control_sha="$(sha256sum "$project/tracking/evidence/raw/unit.json" | awk '{print $1}')"
  sed -i \
    -e 's/evidence_id: EV-UNIT-001/evidence_id: EV-PIPELINE-POLICY-001/' \
    -e 's/check_id: unit/check_id: pipeline-policy/' \
    -e 's/category: test/category: policy/' \
    -e 's/policy_revision: policy-1/policy_revision: executor-controls-v1/' \
    -e "s/^raw_result_sha256:.*/raw_result_sha256: $control_sha/" \
    "$project/tracking/evidence/v1/EV-UNIT-001.yaml"
  bash "$CONTROLS_VALIDATOR" "$project" "$SOURCE_REVISION" >/dev/null ||
    fail "$source_profile executor controls were rejected"
done

P_PROPOSAL="$TMP_DIR/proposal"
write_profile_v2 "$P_PROPOSAL" local-offline
write_evidence "$P_PROPOSAL" local-offline proposal
expect_blocked 'offline proposal was accepted as live proof' "$TMP_DIR/proposal.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_PROPOSAL" \
  "$P_PROPOSAL/tracking/evidence/v1/EV-UNIT-001.yaml"
grep -Fq 'UNVERIFIED' "$TMP_DIR/proposal.out" ||
  fail 'offline proposal rejection did not say UNVERIFIED'

P_STALE="$TMP_DIR/stale"
write_profile_v2 "$P_STALE" repository-ci
write_evidence "$P_STALE" repository-ci live PASS 2000-01-01T00:00:00Z
expect_blocked 'stale evidence was accepted' "$TMP_DIR/stale.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_STALE" \
  "$P_STALE/tracking/evidence/v1/EV-UNIT-001.yaml"

P_TAMPERED="$TMP_DIR/tampered"
write_profile_v2 "$P_TAMPERED" repository-ci
write_evidence "$P_TAMPERED" repository-ci
printf '%s\n' '{"tampered":true}' > "$P_TAMPERED/tracking/evidence/raw/unit.json"
expect_blocked 'tampered raw result was accepted' "$TMP_DIR/tampered.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_TAMPERED" \
  "$P_TAMPERED/tracking/evidence/v1/EV-UNIT-001.yaml"

P_SUBJECT="$TMP_DIR/wrong-subject"
write_profile_v2 "$P_SUBJECT" repository-ci
write_evidence "$P_SUBJECT" repository-ci
expect_blocked 'wrong-subject evidence was accepted' "$TMP_DIR/wrong-subject.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_SUBJECT" \
  "$P_SUBJECT/tracking/evidence/v1/EV-UNIT-001.yaml" \
  --expected-source 2222222222222222222222222222222222222222

P_SECRETS="$TMP_DIR/secrets-zero"
write_profile_v2 "$P_SECRETS" repository-ci
write_evidence "$P_SECRETS" repository-ci
convert_to_secrets_evidence "$P_SECRETS"
bash "$SECRETS_VALIDATOR" "$P_SECRETS" \
  "$P_SECRETS/tracking/evidence/v1/EV-UNIT-001.yaml" "$SOURCE_REVISION" >/dev/null ||
  fail 'exact-source full-repository zero secrets result was rejected'

P_SECRETS_FINDING="$TMP_DIR/secrets-finding"
cp -a "$P_SECRETS" "$P_SECRETS_FINDING"
printf '{"schema_version":1,"check_id":"secrets","source_revision":"%s","secret_count":1,"findings":[{"id":"SECRET-1"}]}\n' \
  "$SOURCE_REVISION" > "$P_SECRETS_FINDING/tracking/evidence/raw/unit.json"
secrets_sha="$(sha256sum "$P_SECRETS_FINDING/tracking/evidence/raw/unit.json" | awk '{print $1}')"
sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $secrets_sha/" \
  "$P_SECRETS_FINDING/tracking/evidence/v1/EV-UNIT-001.yaml"
expect_blocked 'nonzero raw secrets result was accepted' "$TMP_DIR/secrets-finding.out" \
  bash "$SECRETS_VALIDATOR" "$P_SECRETS_FINDING" \
  "$P_SECRETS_FINDING/tracking/evidence/v1/EV-UNIT-001.yaml" "$SOURCE_REVISION"

P_SECRETS_SCOPE="$TMP_DIR/secrets-partial-scope"
cp -a "$P_SECRETS" "$P_SECRETS_SCOPE"
sed -i 's/evidence_repository_path: \.$/evidence_repository_path: src/' \
  "$P_SECRETS_SCOPE/tracking/product-ci-profile.yaml" \
  "$P_SECRETS_SCOPE/tracking/product-ci-profile-history/revision-1.yaml"
expect_blocked 'partial repository secrets scope was accepted' "$TMP_DIR/secrets-scope.out" \
  bash "$SECRETS_VALIDATOR" "$P_SECRETS_SCOPE" \
  "$P_SECRETS_SCOPE/tracking/evidence/v1/EV-UNIT-001.yaml" "$SOURCE_REVISION"

P_PRODUCER="$TMP_DIR/unknown-producer"
write_profile_v2 "$P_PRODUCER" repository-ci
write_evidence "$P_PRODUCER" repository-ci
sed -i 's/producer_identity: github-actions:security-job/producer_identity: unknown:producer/' \
  "$P_PRODUCER/tracking/evidence/v1/EV-UNIT-001.yaml"
expect_blocked 'unknown producer was accepted' "$TMP_DIR/unknown-producer.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_PRODUCER" \
  "$P_PRODUCER/tracking/evidence/v1/EV-UNIT-001.yaml"

P_NA="$TMP_DIR/na"
write_profile_v2 "$P_NA" repository-ci
write_evidence "$P_NA" repository-ci live NOT_APPLICABLE
expect_blocked 'N/A without reason and owner was accepted' "$TMP_DIR/na.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_NA" \
  "$P_NA/tracking/evidence/v1/EV-UNIT-001.yaml"
sed -i \
  -e 's/applicability_reason: none/applicability_reason: no external interface/' \
  -e 's/applicability_owner: none/applicability_owner: s2-test-strategy/' \
  "$P_NA/tracking/evidence/v1/EV-UNIT-001.yaml"
bash "$EVIDENCE_VALIDATOR" "$P_NA" \
  "$P_NA/tracking/evidence/v1/EV-UNIT-001.yaml" >/dev/null ||
  fail 'structured NOT_APPLICABLE evidence was rejected'

P_MARKDOWN="$TMP_DIR/markdown-only"
write_profile_v2 "$P_MARKDOWN" repository-ci
write_evidence "$P_MARKDOWN" repository-ci
sed -i 's#raw_result_uri: tracking/evidence/raw/unit.json#raw_result_uri: stage4-dev/outputs/QA-status.md#' \
  "$P_MARKDOWN/tracking/evidence/v1/EV-UNIT-001.yaml"
mkdir -p "$P_MARKDOWN/stage4-dev/outputs"
printf '%s\n' 'status: PASS' > "$P_MARKDOWN/stage4-dev/outputs/QA-status.md"
expect_blocked 'Markdown-only PASS was accepted as raw evidence' "$TMP_DIR/markdown-only.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_MARKDOWN" \
  "$P_MARKDOWN/tracking/evidence/v1/EV-UNIT-001.yaml"

P_TRACE="$TMP_DIR/missing-trace"
write_profile_v2 "$P_TRACE" repository-ci
write_evidence "$P_TRACE" repository-ci
rm "$P_TRACE/tracking/traceability-v1.tsv"
expect_blocked 'evidence without trace index was accepted' "$TMP_DIR/missing-trace.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_TRACE" \
  "$P_TRACE/tracking/evidence/v1/EV-UNIT-001.yaml"

P_APPROVAL="$TMP_DIR/approval"
write_profile_v2 "$P_APPROVAL" repository-ci
write_evidence "$P_APPROVAL" repository-ci
mkdir -p "$P_APPROVAL/tracking/approvals"
{
  printf '%s\n' 'schema_version: 1' 'approval_id: APPROVAL-TL-001' 'approval_origin: launcher-human-v1' \
    'approver_identity: s4-techlead' 'decision: APPROVE' \
    'scope: Gate 4 source review' 'rationale: reviewed exact-source verified evidence'
  printf 'source_revision: %s\n' "$SOURCE_REVISION"
  printf 'subject_digest: none\nobserved_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$P_APPROVAL/tracking/approvals/APPROVAL-TL-001.yaml"
record_human_approval_receipt "$P_APPROVAL" "$P_APPROVAL/tracking/approvals/APPROVAL-TL-001.yaml"
sed -i 's#human_approval_ref: none#human_approval_ref: tracking/approvals/APPROVAL-TL-001.yaml#' \
  "$P_APPROVAL/tracking/evidence/v1/EV-UNIT-001.yaml"
bash "$EVIDENCE_VALIDATOR" "$P_APPROVAL" \
  "$P_APPROVAL/tracking/evidence/v1/EV-UNIT-001.yaml" >/dev/null ||
  fail 'valid separate human approval was rejected'
sed -i 's/subject_digest: none/subject_digest: sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' \
  "$P_APPROVAL/tracking/approvals/APPROVAL-TL-001.yaml"
expect_blocked 'approval bound to wrong subject was accepted' "$TMP_DIR/approval-subject.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_APPROVAL" \
  "$P_APPROVAL/tracking/evidence/v1/EV-UNIT-001.yaml"

P_BUILD="$TMP_DIR/build-subject"
write_profile_v2 "$P_BUILD" repository-ci
sed -i 's/build_subject: source-only/build_subject: build-artifact/' \
  "$P_BUILD/tracking/product-ci-profile.yaml"
cp "$P_BUILD/tracking/product-ci-profile.yaml" \
  "$P_BUILD/tracking/product-ci-profile-history/revision-1.yaml"
write_evidence "$P_BUILD" repository-ci
printf '%s\n' '{"check":"build","failures":0,"status":"pass"}' > \
  "$P_BUILD/tracking/evidence/raw/unit.json"
build_raw_sha="$(sha256sum "$P_BUILD/tracking/evidence/raw/unit.json" | awk '{print $1}')"
sed -i \
  -e 's/evidence_id: EV-UNIT-001/evidence_id: EV-BUILD-001/' \
  -e 's/check_id: unit/check_id: build/' \
  -e 's/category: test/category: build/' \
  -e 's/subject_kind: source/subject_kind: build-artifact/' \
  -e 's/subject_digest: none/subject_digest: sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' \
  -e 's/build_identity: none/build_identity: build-001/' \
  -e "s/^raw_result_sha256:.*/raw_result_sha256: $build_raw_sha/" \
  "$P_BUILD/tracking/evidence/v1/EV-UNIT-001.yaml"
bash "$EVIDENCE_VALIDATOR" "$P_BUILD" \
  "$P_BUILD/tracking/evidence/v1/EV-UNIT-001.yaml" --expected-check build >/dev/null ||
  fail 'valid source→build identity→artifact digest binding was rejected'
sed -i 's/subject_digest: sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/subject_digest: none/' \
  "$P_BUILD/tracking/evidence/v1/EV-UNIT-001.yaml"
expect_blocked 'artifact subject without digest was accepted' "$TMP_DIR/build-subject.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_BUILD" \
  "$P_BUILD/tracking/evidence/v1/EV-UNIT-001.yaml" --expected-check build

P_JUNIT="$TMP_DIR/junit"
write_profile_v2 "$P_JUNIT" repository-ci
write_evidence "$P_JUNIT" repository-ci
printf '%s\n' '<testsuite name="unit" tests="1" failures="0" errors="0"><testcase name="ok"/></testsuite>' > \
  "$P_JUNIT/tracking/evidence/raw/unit.xml"
junit_sha="$(sha256sum "$P_JUNIT/tracking/evidence/raw/unit.xml" | awk '{print $1}')"
sed -i \
  -e 's/raw_format: json/raw_format: junit/' \
  -e 's#raw_result_uri: tracking/evidence/raw/unit.json#raw_result_uri: tracking/evidence/raw/unit.xml#' \
  -e "s/^raw_result_sha256:.*/raw_result_sha256: $junit_sha/" \
  "$P_JUNIT/tracking/evidence/v1/EV-UNIT-001.yaml"
bash "$EVIDENCE_VALIDATOR" "$P_JUNIT" \
  "$P_JUNIT/tracking/evidence/v1/EV-UNIT-001.yaml" >/dev/null ||
  fail 'valid JUnit PASS result was rejected'
printf '%s\n' '<testsuite name="unit" tests="1" failures="1" errors="0"><testcase name="bad"><failure/></testcase></testsuite>' > \
  "$P_JUNIT/tracking/evidence/raw/unit.xml"
junit_sha="$(sha256sum "$P_JUNIT/tracking/evidence/raw/unit.xml" | awk '{print $1}')"
sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $junit_sha/" \
  "$P_JUNIT/tracking/evidence/v1/EV-UNIT-001.yaml"
expect_blocked 'record PASS contradicted by JUnit failure was accepted' "$TMP_DIR/junit-conflict.out" \
  bash "$EVIDENCE_VALIDATOR" "$P_JUNIT" \
  "$P_JUNIT/tracking/evidence/v1/EV-UNIT-001.yaml"

P_TAP="$TMP_DIR/tap"
write_profile_v2 "$P_TAP" repository-ci
write_evidence "$P_TAP" repository-ci
printf '%s\n' 'TAP version 13' '1..1' 'ok 1 - unit' > "$P_TAP/tracking/evidence/raw/unit.tap"
tap_sha="$(sha256sum "$P_TAP/tracking/evidence/raw/unit.tap" | awk '{print $1}')"
sed -i \
  -e 's/raw_format: json/raw_format: tap/' \
  -e 's#raw_result_uri: tracking/evidence/raw/unit.json#raw_result_uri: tracking/evidence/raw/unit.tap#' \
  -e "s/^raw_result_sha256:.*/raw_result_sha256: $tap_sha/" \
  "$P_TAP/tracking/evidence/v1/EV-UNIT-001.yaml"
bash "$EVIDENCE_VALIDATOR" "$P_TAP" \
  "$P_TAP/tracking/evidence/v1/EV-UNIT-001.yaml" >/dev/null ||
  fail 'valid TAP PASS result was rejected'

P_SUMMARY="$TMP_DIR/summary"
write_profile_v2 "$P_SUMMARY" connected-runner
write_evidence "$P_SUMMARY" connected-runner
bash "$SUMMARY_GENERATOR" "$P_SUMMARY" "$SOURCE_REVISION" > "$P_SUMMARY/summary.md" ||
  fail 'summary generator rejected verified evidence'
grep -Fq 'EV-UNIT-001' "$P_SUMMARY/summary.md" ||
  fail 'generated summary does not reference evidence id'
grep -Fq 'Generated from verified Evidence Contract v1 records' "$P_SUMMARY/summary.md" ||
  fail 'summary does not identify its machine-record source'
if grep -Fq '{"check":"unit"' "$P_SUMMARY/summary.md"; then
  fail 'summary copied raw result contents into Markdown'
fi

echo 'PASS: Evidence Contract v1 smoke'

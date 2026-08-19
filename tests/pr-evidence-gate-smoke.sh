#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-pr-evidence.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/human-approval-receipts"
PR_CHECK="$ROOT/cycle1-dev/s0-validate/pr-evidence-check.sh"
DOR="$ROOT/cycle1-dev/s0-validate/dor-check.sh"
SOURCE_REVISION=3333333333333333333333333333333333333333
CHECKS=(build unit integration contract lint typecheck secrets sast sca dependency-integrity pipeline-policy image-scan sbom)
source "$ROOT/tests/lib/quality-characteristics-fixture.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile() {
  local project="$1"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 2' 'revision: 1' 'previous_revision: 0'
    printf '%s\n' 'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: PR evidence fixture'
    for pair in \
      'product_type=service' \
      'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' \
      'scm_review_policy=required-review' \
      'scm_required_checks=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom' \
      'ci_provider=github-actions' \
      'ci_runners=hosted-linux' \
      'ci_trust_boundary=protected-workflow' \
      'ci_report_formats=junit,tap,sarif,json' \
      'build_toolchain=native-project-toolchain' \
      'build_command=make test-build' \
      'package_command=not-applicable' \
      'build_output_contract=not-applicable' \
      'secret_provider=pass' \
      'ci_identity_references=github-actions:security-job' \
      'compliance_constraints=none' \
      'offline_mode=online' \
      'approval_constraints=required-review' \
      'quality_overrides=none' \
      'evidence_source_profile=repository-ci' \
      'evidence_repository_path=.' \
      'evidence_executor_identity=github-actions:workflow-security' \
      'evidence_trusted_producers=github-actions:security-job' \
      'evidence_freshness_seconds=3600' \
      'evidence_signature_policy=if-produced' \
      'evidence_merge_blocking=required' \
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

write_record() {
  local project="$1" check="$2" verdict="$3" category id raw raw_sha reason=none owner=none
  case "$check" in
    build) category=build ;;
    unit|integration|contract|lint|typecheck) category=test ;;
    secrets|sast|sca|dependency-integrity|image-scan|sbom) category=security ;;
    pipeline-policy) category=policy ;;
  esac
  [[ "$verdict" != NOT_APPLICABLE ]] || { reason='no artifact subject in Product Profile'; owner=s0-kickoff; }
  id="${check^^}"
  id="${id//-/_}"
  raw="tracking/evidence/raw/$check.json"
  mkdir -p "$project/tracking/evidence/v1" "$project/tracking/evidence/raw"
  case "$category" in
    security)
      printf '{"schema_version":1,"check_id":"%s","source_revision":"%s","secret_count":0,"integrity_status":"pass","tampered_dependencies":0,"malicious_dependencies":0,"findings":[]}\n' \
        "$check" "$SOURCE_REVISION" > "$project/$raw"
      ;;
    policy)
      printf '{"schema_version":1,"check_id":"pipeline-policy","source_revision":"%s","controls":{"immutable_dependencies":"pass","least_privilege":"pass","untrusted_pr_isolation":"pass","protected_policy_files":"pass","artifact_cache_integrity":"pass"},"remediation":[]}\n' \
        "$SOURCE_REVISION" > "$project/$raw"
      ;;
    test)
      case "$check" in
        unit)
          printf '{"check_id":"unit","status":"%s","quality_metrics":[{"metric_id":"branch_coverage_percent","operator":">=","threshold":80,"observed":92,"unit":"percent","verdict":"PASS","policy_revision":"quality-global-v1"},{"metric_id":"mutation_score_percent","operator":">=","threshold":60,"observed":75,"unit":"percent","verdict":"PASS","policy_revision":"quality-global-v1"}]}\n' \
            "${verdict,,}" > "$project/$raw"
          ;;
        lint)
          printf '{"check_id":"lint","status":"%s","quality_metrics":[{"metric_id":"complexity_max","operator":"<=","threshold":10,"observed":7,"unit":"cyclomatic-complexity","verdict":"PASS","policy_revision":"quality-global-v1"}]}\n' \
            "${verdict,,}" > "$project/$raw"
          ;;
        *) printf '{"check_id":"%s","status":"%s"}\n' "$check" "${verdict,,}" > "$project/$raw" ;;
      esac
      ;;
    *) printf '{"check_id":"%s","status":"%s"}\n' "$check" "${verdict,,}" > "$project/$raw" ;;
  esac
  raw_sha="$(sha256sum "$project/$raw" | awk '{print $1}')"
  mkdir -p "$project/stage2-requirements/outputs" "$project/stage3-design/outputs" "$project/tests"
  printf '%s\n' 'FR-001' > "$project/stage2-requirements/outputs/BRD.md"
  printf '%s\n' 'ARCH-001' > "$project/stage3-design/outputs/ARCH-HLD.md"
  printf 'CHECK-%s\n' "$id" >> "$project/tests/trace-tests.txt"
  trace="$project/tracking/traceability-v1.tsv"
  if [[ ! -f "$trace" ]]; then
    printf '%s\n' $'requirement_id\trequirement_uri\tspecification_id\tspecification_uri\ttest_id\ttest_uri\tsource_revision' > "$trace"
  fi
  printf 'FR-001\tstage2-requirements/outputs/BRD.md\tARCH-001\tstage3-design/outputs/ARCH-HLD.md\tCHECK-%s\ttests/trace-tests.txt\t%s\n' \
    "$id" "$SOURCE_REVISION" >> "$trace"
  {
    printf '%s\n' 'schema_version: 1'
    printf 'evidence_id: EV-%s\ncheck_id: %s\ncategory: %s\n' "$id" "$check" "$category"
    printf '%s\n' \
      'source_profile: repository-ci' \
      'execution_mode: live' \
      'executor_identity: github-actions:workflow-security' \
      'producer_identity: github-actions:security-job' \
      'tool_name: fixture-runner' \
      'tool_version: 1.0.0'
    printf 'source_revision: %s\n' "$SOURCE_REVISION"
    printf '%s\n' \
      'subject_kind: source' \
      'subject_digest: none' \
      'build_identity: none' \
      'config_revision: cfg-1' \
      "policy_revision: $([[ $category == security ]] && printf security-v1 || { [[ $category == policy ]] && printf executor-controls-v1 || printf quality-global-v1; })" \
      'product_profile_revision: 1'
    printf 'observed_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' 'freshness_seconds: 3600' 'raw_format: json'
    printf 'raw_result_uri: %s\nraw_result_sha256: %s\n' "$raw" "$raw_sha"
    printf '%s\n' 'signature_status: not-provided'
    printf 'verdict: %s\napplicability_reason: %s\napplicability_owner: %s\n' \
      "$verdict" "$reason" "$owner"
    printf '%s\n' \
      'requirement_ids: FR-001' \
      'specification_ids: ARCH-001' \
      "test_ids: CHECK-$id" \
      'human_approval_ref: none' \
      'risk_exception_ref: none'
  } > "$project/tracking/evidence/v1/EV-$id.yaml"
}

write_full_set() {
  local project="$1" check verdict
  write_profile "$project"
  for check in "${CHECKS[@]}"; do
    verdict=PASS
    case "$check" in image-scan|sbom) verdict=NOT_APPLICABLE ;; esac
    write_record "$project" "$check" "$verdict"
  done
}

write_dod_approval() {
  local project="$1" review review_ref review_sha subject
  local scope='DOD-1,DOD-2,DOD-3,DOD-4,DOD-5,DOD-6,DOD-7,DOD-8,DOD-9,DOD-10,DOD-11'
  while IFS= read -r review; do
    review_ref="${review#"$project/"}"
    review_sha="$(sha256sum "$review" | awk '{print $1}')"
    scope+=";techlead-review:$review_ref@$review_sha"
  done < <(find "$project/stage4-dev/outputs" -maxdepth 1 -type f -name 'TL-*review-PR*.md' | sort)
  subject="$(awk -F: '$1 == "subject_digest" {sub(/^[^:]*:[[:space:]]*/, "", $0); print; exit}' \
    "$project/tracking/evidence/v1/EV-BUILD.yaml")"
  mkdir -p "$project/tracking/approvals"
  {
    printf '%s\n' 'schema_version: 1' 'approval_id: APPROVAL-DOD-001' 'approval_origin: launcher-human-v1' \
      'approver_identity: s4-techlead' 'decision: APPROVE'
    printf 'scope: %s\n' "$scope"
    printf '%s\n' 'rationale: independent review confirms every applicable full Software DoD item' \
      "source_revision: $SOURCE_REVISION" "subject_digest: $subject" \
      "observed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$project/tracking/approvals/APPROVAL-DOD-001.yaml"
  record_human_approval_receipt "$project" "$project/tracking/approvals/APPROVAL-DOD-001.yaml"
}

write_strict_quality_policy() {
  local project="$1"
  mkdir -p "$project/tracking/quality-gates-history"
  [[ -f "$project/Dashboard.md" ]] || printf '%s\n' '# Dashboard' > "$project/Dashboard.md"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_id: QUALITY-POLICY-R1' \
      'artifact_type: quality-policy' "project: $(basename "$project")" 'stage: TRACKING' \
      'producer: s0-quality-gates' 'source_revision: none' 'status: VALIDATED' \
      'inputs: tracking/product-ci-profile.yaml' 'outputs: tracking/quality-gates.md' \
      'tags: sdlc,cycle1,tracking,quality-gates' 'revision: 1' 'previous_revision: 0' \
      'policy_revision: quality-v1-r1' 'product_profile_revision: 1' 'date: 2026-07-27' \
      '---' '' '# Quality Gates — strict fixture' '' \
      '| Metric id | Project threshold | Rationale |' '|---|---:|---|' \
      '| branch_coverage_percent | >= 90 | project risk requires stricter branch coverage |' \
      '| mutation_score_percent | >= 70 | project risk requires stricter mutation score |' \
      '| test_pass_rate_percent | >= 98 | global minimum |' \
      '| response_time_p95_ms | <= 500 | global maximum |' \
      '| response_time_p99_ms | <= 2000 | global maximum |' \
      '| error_rate_percent | <= 0.1 | global maximum |' \
      '| availability_percent | >= 99.9 | global minimum |' \
      '| rto_hours | <= 1 | global maximum |' \
      '| rpo_hours | <= 24 | global maximum |' \
      '| e2e_automation_percent | >= 95 | global minimum |' \
      '| complexity_max | <= 8 | project risk requires lower complexity |' \
      '| security_critical_high_max | <= 0 | zero tolerance |' '' \
      '## Obsidian Links' '' '- Dashboard: [[Dashboard]]' \
      '- Profile: `tracking/product-ci-profile.yaml`' '- Output: [[tracking/quality-gates]]'
  } > "$project/tracking/quality-gates.md"
  cp "$project/tracking/quality-gates.md" \
    "$project/tracking/quality-gates-history/revision-1.md"
}

upgrade_profile_to_v5() {
  local project="$1" compatibility="$2"
  sed -i 's/^schema_version: 2/schema_version: 5/' "$project/tracking/product-ci-profile.yaml"
  for pair in \
    'user_interface=api-only' 'ux_brief_requirement=not-applicable' \
    'validation_environment_profile=connected-representative' \
    'validation_environment_identity=qa-service' \
    'validation_environment_authorization=required' \
    'performance_validation=required' 'runtime_security_validation=required' \
    "compatibility_validation=$compatibility" 'accessibility_validation=not-applicable' \
    'flexibility_validation=required' 'safety_validation=not-applicable' \
    'api_contract_design=not-applicable' 'data_store_design=not-applicable' \
    'authorization_design=not-applicable' 'environment_format_validation=not-applicable'; do
    key="${pair%%=*}"; value="${pair#*=}"
    printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key" >> \
      "$project/tracking/product-ci-profile.yaml"
  done
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
  write_quality_characteristics_fixture "$project"
}

make_check_not_applicable() {
  local project="$1" check="$2" safe="${2^^}" record
  safe="${safe//-/_}"
  record="$project/tracking/evidence/v1/EV-$safe.yaml"
  sed -i 's/^verdict: PASS/verdict: NOT_APPLICABLE/' "$record"
  sed -i 's/^applicability_reason: none/applicability_reason: no compatible boundary in confirmed profile/' "$record"
  sed -i 's/^applicability_owner: none/applicability_owner: s0-kickoff/' "$record"
}

P_VALID="$TMP_DIR/valid"
write_full_set "$P_VALID"
bash "$PR_CHECK" "$P_VALID" "$SOURCE_REVISION" > "$TMP_DIR/valid.out" ||
  fail 'complete PR evidence set was rejected'
grep -Fq 'PR EVIDENCE VERIFIED' "$TMP_DIR/valid.out" ||
  fail 'aggregate verifier did not emit a verified verdict'
grep -Fq 'EV-SECRETS' "$TMP_DIR/valid.out" ||
  fail 'aggregate verdict did not expose concise evidence ids'

P_PROJECT_POLICY="$TMP_DIR/project-policy-consumer"
write_full_set "$P_PROJECT_POLICY"
sed -i 's#^quality_overrides: none#quality_overrides: tracking/quality-gates.md#' \
  "$P_PROJECT_POLICY/tracking/product-ci-profile.yaml" \
  "$P_PROJECT_POLICY/tracking/product-ci-profile-history/revision-1.yaml"
write_strict_quality_policy "$P_PROJECT_POLICY"
if bash "$PR_CHECK" "$P_PROJECT_POLICY" "$SOURCE_REVISION" > \
  "$TMP_DIR/project-policy-stale.out" 2>&1; then
  fail 'PR evidence bound to global thresholds bypassed stricter project policy'
fi
grep -Eq 'policy binding mismatch|threshold differs|stale/wrong quality policy revision' \
  "$TMP_DIR/project-policy-stale.out" ||
  fail 'stricter project policy rejection did not reach evidence/metric binding'

sed -i -e 's/"threshold":80/"threshold":90/' \
  -e 's/"threshold":60/"threshold":70/' \
  -e 's/"policy_revision":"quality-global-v1"/"policy_revision":"quality-v1-r1"/g' \
  "$P_PROJECT_POLICY/tracking/evidence/raw/unit.json"
sed -i -e 's/"threshold":10/"threshold":8/' \
  -e 's/"policy_revision":"quality-global-v1"/"policy_revision":"quality-v1-r1"/g' \
  "$P_PROJECT_POLICY/tracking/evidence/raw/lint.json"
sed -i 's/^policy_revision: quality-global-v1/policy_revision: quality-v1-r1/' \
  "$P_PROJECT_POLICY"/tracking/evidence/v1/*.yaml
for check in UNIT LINT; do
  raw_name="${check,,}"
  metric_sha="$(sha256sum "$P_PROJECT_POLICY/tracking/evidence/raw/$raw_name.json" | awk '{print $1}')"
  sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $metric_sha/" \
    "$P_PROJECT_POLICY/tracking/evidence/v1/EV-$check.yaml"
done
bash "$PR_CHECK" "$P_PROJECT_POLICY" "$SOURCE_REVISION" >/dev/null ||
  fail 'PR evidence matching stricter project thresholds was rejected'

P_METRIC_SELF="$TMP_DIR/metric-self-verdict"
write_full_set "$P_METRIC_SELF"
sed -i 's/"observed":75/"observed":50/' "$P_METRIC_SELF/tracking/evidence/raw/unit.json"
metric_sha="$(sha256sum "$P_METRIC_SELF/tracking/evidence/raw/unit.json" | awk '{print $1}')"
sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $metric_sha/" \
  "$P_METRIC_SELF/tracking/evidence/v1/EV-UNIT.yaml"
if bash "$PR_CHECK" "$P_METRIC_SELF" "$SOURCE_REVISION" > "$TMP_DIR/metric-self.out" 2>&1; then
  fail 'PR gate accepted metric PASS contradicting observed value'
fi
grep -Fq 'QUALITY METRIC BLOCKED' "$TMP_DIR/metric-self.out" ||
  fail 'metric contradiction did not reach the metric validator'

P_COMPAT_V5="$TMP_DIR/compatibility-required-v5"
write_full_set "$P_COMPAT_V5"
upgrade_profile_to_v5 "$P_COMPAT_V5" required
bash "$PR_CHECK" "$P_COMPAT_V5" "$SOURCE_REVISION" >/dev/null ||
  fail 'schema v5 required compatibility PASS evidence was rejected'

P_COMPAT_FAIL="$TMP_DIR/compatibility-required-na-v5"
write_full_set "$P_COMPAT_FAIL"
upgrade_profile_to_v5 "$P_COMPAT_FAIL" required
make_check_not_applicable "$P_COMPAT_FAIL" integration
if bash "$PR_CHECK" "$P_COMPAT_FAIL" "$SOURCE_REVISION" > "$TMP_DIR/compatibility-required-na.out" 2>&1; then
  fail 'required compatibility accepted integration NOT_APPLICABLE'
fi
grep -Fq 'compatibility required' "$TMP_DIR/compatibility-required-na.out" ||
  fail 'required compatibility blocker was not identified'

P_COMPAT_NA="$TMP_DIR/compatibility-na-v5"
write_full_set "$P_COMPAT_NA"
upgrade_profile_to_v5 "$P_COMPAT_NA" not-applicable
make_check_not_applicable "$P_COMPAT_NA" integration
make_check_not_applicable "$P_COMPAT_NA" contract
bash "$PR_CHECK" "$P_COMPAT_NA" "$SOURCE_REVISION" >/dev/null ||
  fail 'profile-confirmed compatibility N/A records were rejected'

P_MISSING="$TMP_DIR/missing"
write_full_set "$P_MISSING"
rm "$P_MISSING/tracking/evidence/v1/EV-SBOM.yaml"
if bash "$PR_CHECK" "$P_MISSING" "$SOURCE_REVISION" > "$TMP_DIR/missing.out" 2>&1; then
  fail 'aggregate accepted a missing required check'
fi
grep -Fq 'BLOCKED' "$TMP_DIR/missing.out" || fail 'missing check did not produce BLOCKED'

P_DUPLICATE="$TMP_DIR/duplicate"
write_full_set "$P_DUPLICATE"
cp "$P_DUPLICATE/tracking/evidence/v1/EV-UNIT.yaml" \
  "$P_DUPLICATE/tracking/evidence/v1/EV-UNIT-DUPLICATE.yaml"
sed -i 's/evidence_id: EV-UNIT/evidence_id: EV-UNIT-DUPLICATE/' \
  "$P_DUPLICATE/tracking/evidence/v1/EV-UNIT-DUPLICATE.yaml"
if bash "$PR_CHECK" "$P_DUPLICATE" "$SOURCE_REVISION" >/dev/null 2>&1; then
  fail 'aggregate accepted duplicate current evidence for one check'
fi

P_FAIL="$TMP_DIR/fail"
write_full_set "$P_FAIL"
sed -i 's/verdict: PASS/verdict: FAIL/' "$P_FAIL/tracking/evidence/v1/EV-SECRETS.yaml"
if bash "$PR_CHECK" "$P_FAIL" "$SOURCE_REVISION" > "$TMP_DIR/fail.out" 2>&1; then
  fail 'aggregate accepted a verified FAIL verdict'
fi
grep -Eq 'FAIL|BLOCKED' "$TMP_DIR/fail.out" || fail 'failed check did not explain gate blocker'

P_CONTROL="$TMP_DIR/executor-control"
write_full_set "$P_CONTROL"
sed -i 's/"least_privilege":"pass"/"least_privilege":"fail"/' \
  "$P_CONTROL/tracking/evidence/raw/pipeline-policy.json"
control_sha="$(sha256sum "$P_CONTROL/tracking/evidence/raw/pipeline-policy.json" | awk '{print $1}')"
sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $control_sha/" \
  "$P_CONTROL/tracking/evidence/v1/EV-PIPELINE_POLICY.yaml"
if bash "$PR_CHECK" "$P_CONTROL" "$SOURCE_REVISION" > "$TMP_DIR/executor-control.out" 2>&1; then
  fail 'aggregate accepted executor without least privilege'
fi
grep -Fq 'EXECUTOR CONTROLS BLOCKED' "$TMP_DIR/executor-control.out" ||
  fail 'executor control failure did not identify its contract'

P_GATE="$TMP_DIR/gate4"
write_full_set "$P_GATE"
mkdir -p "$P_GATE/stage4-dev/outputs"
mkdir -p "$P_GATE/tests"
write_artifact_metadata_fixture "$P_GATE/stage4-dev/outputs/TL-2026-07-27-review-PR1.md" \
  "$P_GATE" TL-REVIEW-PR1 techlead-review S4 s4-techlead "$SOURCE_REVISION" PASS 'Tech Lead Review'
sed -i '/^schema_version: 1$/a product_profile_revision: 1' \
  "$P_GATE/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
printf '%s\n' '' 'APPROVED' >> "$P_GATE/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
write_artifact_metadata_fixture "$P_GATE/stage4-dev/outputs/DEV-2026-07-27-PR-1-summary.md" \
  "$P_GATE" DEV-PR-1 dev-pr-summary S4 s4-dev "$SOURCE_REVISION" PASS 'PR summary: no open blockers'
write_artifact_metadata_fixture "$P_GATE/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR1.md" \
  "$P_GATE" DEV-UPDATE-PR1 update-notes S4 s4-dev "$SOURCE_REVISION" PASS 'Update notes: no open blockers'
for artifact in \
  "$P_GATE/stage4-dev/outputs/DEV-2026-07-27-PR-1-summary.md" \
  "$P_GATE/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR1.md"; do
  sed -i '/^schema_version: 1$/a product_profile_revision: 1' "$artifact"
done
printf '%s\n' 'native test' > "$P_GATE/tests/test_feature.txt"
{
  printf '%s\n' $'test_id\ttest_uri\tchange_id\tresult\tsource_revision'
  printf 'TEST-001\ttests/test_feature.txt\tFR-001\tPASS\t%s\n' "$SOURCE_REVISION"
} > "$P_GATE/stage4-dev/outputs/QA-affected-tests-v1.tsv"
tdd_manifest_sha="$(sha256sum "$P_GATE/stage4-dev/outputs/QA-affected-tests-v1.tsv" | awk '{print $1}')"
{
  printf '%s\n' '---' 'schema_version: 1' 'artifact_type: tdd-status' 'status: PASS' "project: $(basename "$P_GATE")" 'scope: FR-001' \
    "source_revision: $SOURCE_REVISION" 'test_command: make test-affected' 'red_evidence: none' \
    'last_run: 2026-07-27T12:00:00Z' 'failed_tests: 0' 'repair_iteration: 0' \
    'regression_scope: full-affected' 'affected_test_manifest: stage4-dev/outputs/QA-affected-tests-v1.tsv' \
    "affected_test_manifest_sha256: $tdd_manifest_sha" 'expected_test_count: 1' 'executed_test_count: 1' \
    '---' '' '# TDD Status'
} > "$P_GATE/stage4-dev/outputs/QA-TDD-status.md"
complete_artifact_metadata_fixture "$P_GATE/stage4-dev/outputs/QA-TDD-status.md" \
  "$P_GATE" QA-TDD-STATUS-V1 S4 s4-qa-auto "$SOURCE_REVISION" PASS
write_dod_approval "$P_GATE"
bash "$DOR" "$P_GATE" 4 > "$TMP_DIR/gate4.out" || {
  cat "$TMP_DIR/gate4.out"
  fail 'Gate 4 rejected complete exact-source machine evidence'
}
grep -Fq 'PR EVIDENCE VERIFIED' "$TMP_DIR/gate4.out" ||
  fail 'Gate 4 output did not retain aggregate evidence ids'

P_GATE_MULTI="$TMP_DIR/gate4-three-prs"
cp -a "$P_GATE" "$P_GATE_MULTI"
for pr in 2 3; do
  write_artifact_metadata_fixture "$P_GATE_MULTI/stage4-dev/outputs/DEV-2026-07-27-PR-$pr-summary.md" \
    "$P_GATE_MULTI" "DEV-PR-$pr" dev-pr-summary S4 s4-dev "$SOURCE_REVISION" PASS "PR $pr summary"
  write_artifact_metadata_fixture "$P_GATE_MULTI/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR$pr.md" \
    "$P_GATE_MULTI" "DEV-UPDATE-PR$pr" update-notes S4 s4-dev "$SOURCE_REVISION" PASS "PR $pr update notes"
  write_artifact_metadata_fixture "$P_GATE_MULTI/stage4-dev/outputs/TL-2026-07-27-review-PR$pr.md" \
    "$P_GATE_MULTI" "TL-REVIEW-PR$pr" techlead-review S4 s4-techlead "$SOURCE_REVISION" PASS "PR $pr review"
  for artifact in \
    "$P_GATE_MULTI/stage4-dev/outputs/DEV-2026-07-27-PR-$pr-summary.md" \
    "$P_GATE_MULTI/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR$pr.md" \
    "$P_GATE_MULTI/stage4-dev/outputs/TL-2026-07-27-review-PR$pr.md"; do
    sed -i '/^schema_version: 1$/a product_profile_revision: 1' "$artifact"
  done
  printf '%s\n' '' 'APPROVED' >> "$P_GATE_MULTI/stage4-dev/outputs/TL-2026-07-27-review-PR$pr.md"
done
while IFS= read -r artifact; do
  sed -i "s/^project: $(basename "$P_GATE")$/project: $(basename "$P_GATE_MULTI")/" "$artifact"
done < <(find "$P_GATE_MULTI" -type f -name '*.md')
write_dod_approval "$P_GATE_MULTI"
if ! bash "$DOR" "$P_GATE_MULTI" 4 >"$TMP_DIR/gate4-three-prs.out" 2>&1; then
  fail "Gate 4 rejected a complete three-PR set: $(tr '\n' ' ' < "$TMP_DIR/gate4-three-prs.out")"
fi
rm "$P_GATE_MULTI/stage4-dev/outputs/DEV-2026-07-27-update-notes-PR3.md"
if bash "$DOR" "$P_GATE_MULTI" 4 >"$TMP_DIR/gate4-three-prs-missing.out" 2>&1; then
  fail 'Gate 4 accepted a three-PR set with one missing update-notes member'
fi
grep -Fq 'PR SET BLOCKED' "$TMP_DIR/gate4-three-prs-missing.out" ||
  fail 'incomplete three-PR set did not identify PR SET BLOCKED'

P_GATE_V5="$TMP_DIR/gate4-v5"
cp -a "$P_GATE" "$P_GATE_V5"
sed -i "s/^project: $(basename "$P_GATE")$/project: $(basename "$P_GATE_V5")/" \
  "$P_GATE_V5/stage4-dev/outputs/QA-TDD-status.md"
upgrade_profile_to_v5 "$P_GATE_V5" required
{
  printf '%s\n' '---' 'schema_version: 1' 'artifact_type: techlead-review' \
    'product_profile_revision: 1' "source_revision: $SOURCE_REVISION" \
    'status: PASS' '---' '' '# Tech Lead Review' 'No open blockers.' '' '## Maintainability Review' \
    'Modularity: PASS' 'Reusability: PASS' 'Analysability: PASS' 'Modifiability: PASS' \
    'Testability: PASS' \
    'Maintainability rationale: module boundaries and change impact were reviewed against HLD and exact tests.' \
    'Maintainability evidence ids: EV-UNIT,EV-INTEGRATION,EV-CONTRACT,EV-LINT'
} > "$P_GATE_V5/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
complete_artifact_metadata_fixture "$P_GATE_V5/stage4-dev/outputs/TL-2026-07-27-review-PR1.md" \
  "$P_GATE_V5" TL-REVIEW-PR1 S4 s4-techlead "$SOURCE_REVISION" PASS
printf '%s\n' '' 'APPROVED' >> "$P_GATE_V5/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
write_dod_approval "$P_GATE_V5"
bash "$DOR" "$P_GATE_V5" 4 >/dev/null ||
  fail 'Gate 4 rejected complete schema v5 maintainability review'

DOD="$ROOT/cycle1-dev/s0-validate/dod-check.sh"
if ! bash "$DOD" "$P_GATE_V5" K 4 1 "$SOURCE_REVISION" >"$TMP_DIR/dod-format-na.out" 2>&1; then
  fail "Software DoD rejected profile-confirmed ENV/DB/API N/A: $(tr '\n' ' ' < "$TMP_DIR/dod-format-na.out")"
fi
grep -Fq 'Repository-scope secrets Evidence v1 verified' "$TMP_DIR/dod-format-na.out" ||
  fail 'Software DoD did not prove full-repository secrets evidence'

P_DOD_MIGRATION="$TMP_DIR/dod-migration"
cp -a "$P_GATE_V5" "$P_DOD_MIGRATION"
while IFS= read -r artifact; do
  sed -i 's/^project: gate4-v5$/project: dod-migration/' "$artifact"
done < <(find "$P_DOD_MIGRATION" -type f -name '*.md')
printf '%s\n' '# Migration Runbook' 'Design only; executable migration follows QA-owned Red.' > \
  "$P_DOD_MIGRATION/stage3-design/outputs/DBA-2026-08-18-migration-runbook.md"
printf '%s\n' 'test performs upgrade then downgrade then upgrade on a clean database' > \
  "$P_DOD_MIGRATION/tests/test_feature.txt"
sed -i 's/\tFR-001\tPASS\t/\tMIG-001\tPASS\t/' \
  "$P_DOD_MIGRATION/stage4-dev/outputs/QA-affected-tests-v1.tsv"
migration_manifest="$P_DOD_MIGRATION/stage4-dev/outputs/QA-affected-tests-v1.tsv"
migration_manifest_sha="$(sha256sum "$migration_manifest" | awk '{print $1}')"
sed -i \
  -e 's/^scope: FR-001/scope: MIG-001/' \
  -e "s/^affected_test_manifest_sha256:.*/affected_test_manifest_sha256: $migration_manifest_sha/" \
  "$P_DOD_MIGRATION/stage4-dev/outputs/QA-TDD-status.md"
if ! bash "$DOD" "$P_DOD_MIGRATION" I 4 1 "$SOURCE_REVISION" \
  >"$TMP_DIR/dod-migration.out" 2>&1; then
  fail "Type-I DoD rejected a complete migration regression: $(tr '\n' ' ' < "$TMP_DIR/dod-migration.out")"
fi
grep -Fq 'Executable migration TDD verified' "$TMP_DIR/dod-migration.out" ||
  fail 'Type-I DoD did not emit its exact migration TDD verdict'

P_DOD_MIGRATION_PARTIAL="$TMP_DIR/dod-migration-partial"
cp -a "$P_DOD_MIGRATION" "$P_DOD_MIGRATION_PARTIAL"
sed -i 's/^project: dod-migration$/project: dod-migration-partial/' \
  "$P_DOD_MIGRATION_PARTIAL/stage4-dev/outputs/QA-TDD-status.md"
printf '%s\n' 'test performs upgrade only' > "$P_DOD_MIGRATION_PARTIAL/tests/test_feature.txt"
if bash "$DOD" "$P_DOD_MIGRATION_PARTIAL" I 4 1 "$SOURCE_REVISION" \
  >"$TMP_DIR/dod-migration-partial.out" 2>&1; then
  fail 'Type-I DoD accepted migration evidence without downgrade and second upgrade'
fi
grep -Fq 'Migration test does not exercise upgrade→downgrade→upgrade' \
  "$TMP_DIR/dod-migration-partial.out" ||
  fail 'Type-I DoD did not identify the incomplete migration lifecycle'

P_DOD_REVIEW_BLOCKED="$TMP_DIR/dod-review-blocked"
cp -a "$P_GATE_V5" "$P_DOD_REVIEW_BLOCKED"
printf '%s\n' '[BLOCKER] unresolved authorization boundary' >> \
  "$P_DOD_REVIEW_BLOCKED/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
if bash "$DOD" "$P_DOD_REVIEW_BLOCKED" K 4 1 "$SOURCE_REVISION" \
  >"$TMP_DIR/dod-review-blocked.out" 2>&1; then
  fail 'Software DoD accepted an explicit open review BLOCKER'
fi
grep -Fq 'Current TL review set содержит BLOCKER/REQUEST_CHANGES' \
  "$TMP_DIR/dod-review-blocked.out" ||
  fail 'Software DoD did not identify the explicit review blocker'

P_DOD_FORMAT_REQUIRED="$TMP_DIR/dod-format-required"
cp -a "$P_GATE_V5" "$P_DOD_FORMAT_REQUIRED"
while IFS= read -r artifact; do
  sed -i 's/^project: gate4-v5$/project: dod-format-required/' "$artifact"
done < <(find "$P_DOD_FORMAT_REQUIRED" -type f -name '*.md')
for field in api_contract_design data_store_design environment_format_validation; do
  sed -i "s/^$field: not-applicable/$field: required/" \
    "$P_DOD_FORMAT_REQUIRED/tracking/product-ci-profile.yaml"
done
cp "$P_DOD_FORMAT_REQUIRED/tracking/product-ci-profile.yaml" \
  "$P_DOD_FORMAT_REQUIRED/tracking/product-ci-profile-history/revision-1.yaml"
if bash "$DOD" "$P_DOD_FORMAT_REQUIRED" K 4 1 "$SOURCE_REVISION" \
  >"$TMP_DIR/dod-format-missing.out" 2>&1; then
  fail 'Software DoD accepted missing REQUIRED ENV/DB/API format tests'
fi
for test_ref in tests/test_env_format.py tests/test_db_format.py tests/test_api_format.py; do
  grep -Fq "REQUIRED, но exact-source PASS test отсутствует: $test_ref" \
    "$TMP_DIR/dod-format-missing.out" ||
    fail "Software DoD did not identify missing required format test: $test_ref"
  printf '%s\n' '# exact format regression fixture' > "$P_DOD_FORMAT_REQUIRED/$test_ref"
  printf 'TEST-%s\t%s\tFR-001\tPASS\t%s\n' \
    "$(basename "$test_ref" .py | tr '[:lower:]' '[:upper:]')" "$test_ref" "$SOURCE_REVISION" >> \
    "$P_DOD_FORMAT_REQUIRED/stage4-dev/outputs/QA-affected-tests-v1.tsv"
done
format_manifest="$P_DOD_FORMAT_REQUIRED/stage4-dev/outputs/QA-affected-tests-v1.tsv"
format_manifest_sha="$(sha256sum "$format_manifest" | awk '{print $1}')"
sed -i \
  -e "s/^affected_test_manifest_sha256:.*/affected_test_manifest_sha256: $format_manifest_sha/" \
  -e 's/^expected_test_count: 1/expected_test_count: 4/' \
  -e 's/^executed_test_count: 1/executed_test_count: 4/' \
  "$P_DOD_FORMAT_REQUIRED/stage4-dev/outputs/QA-TDD-status.md"
if ! bash "$DOD" "$P_DOD_FORMAT_REQUIRED" K 4 1 "$SOURCE_REVISION" \
  >"$TMP_DIR/dod-format-pass.out" 2>&1; then
  fail "Software DoD rejected complete required format tests: $(tr '\n' ' ' < "$TMP_DIR/dod-format-pass.out")"
fi

for secret_path in app.js config.yaml notes.md native.conf; do
  P_DOD_SECRET="$TMP_DIR/dod-secret-${secret_path//./-}"
  cp -a "$P_GATE_V5" "$P_DOD_SECRET"
  printf '%s\n' 'synthetic scanner finding fixture' > "$P_DOD_SECRET/$secret_path"
  printf '{"schema_version":1,"check_id":"secrets","source_revision":"%s","secret_count":1,"findings":[{"path":"%s"}]}\n' \
    "$SOURCE_REVISION" "$secret_path" > "$P_DOD_SECRET/tracking/evidence/raw/secrets.json"
  secret_sha="$(sha256sum "$P_DOD_SECRET/tracking/evidence/raw/secrets.json" | awk '{print $1}')"
  sed -i "s/^raw_result_sha256:.*/raw_result_sha256: $secret_sha/" \
    "$P_DOD_SECRET/tracking/evidence/v1/EV-SECRETS.yaml"
  if bash "$DOD" "$P_DOD_SECRET" K 4 1 "$SOURCE_REVISION" \
    >"$TMP_DIR/dod-secret.out" 2>&1; then
    fail "Software DoD accepted a secrets finding in $secret_path"
  fi
  grep -Fq 'Нет PASS secrets Evidence v1 для exact source и полного repository scope' \
    "$TMP_DIR/dod-secret.out" ||
    fail "Software DoD did not fail at repository-scope secrets evidence for $secret_path"
done

P_GATE_NO_DOD="$TMP_DIR/gate4-missing-full-dod"
cp -a "$P_GATE_V5" "$P_GATE_NO_DOD"
rm "$P_GATE_NO_DOD/tracking/approvals/APPROVAL-DOD-001.yaml"
if bash "$DOR" "$P_GATE_NO_DOD" 4 >"$TMP_DIR/gate4-no-dod.out" 2>&1; then
  fail 'Gate 4 accepted DOD_AUTO-compatible evidence without full independent DoD approval'
fi
grep -Fq 'DOD APPROVAL BLOCKED' "$TMP_DIR/gate4-no-dod.out" ||
  fail 'missing full DoD approval did not identify its blocking contract'

P_GATE_V5_BAD="$TMP_DIR/gate4-v5-missing-dimension"
cp -a "$P_GATE_V5" "$P_GATE_V5_BAD"
write_quality_characteristics_fixture "$P_GATE_V5_BAD"
sed -i '/^Modifiability: PASS$/d' "$P_GATE_V5_BAD/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
if bash "$DOR" "$P_GATE_V5_BAD" 4 >/dev/null 2>&1; then
  fail 'Gate 4 accepted maintainability review without Modifiability PASS'
fi

echo 'PASS: PR evidence and Gate 4 smoke'

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-s5-validation.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/human-approval-receipts"
CHECK="$ROOT/cycle1-dev/s0-validate/s5-validation-check.sh"
PROFILE_CHECK="$ROOT/cycle1-dev/s0-validate/product-ci-profile-check.sh"
SOURCE=5555555555555555555555555555555555555555
DIGEST=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
CHECKS=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom
source "$ROOT/tests/lib/quality-characteristics-fixture.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile_v4() {
  local project="$1" product_type="$2" build_subject="$3" perf="$4" security="$5" env_profile="$6"
  local sbom=required env_id=qa-env-1 env_auth=required interface=graphical ux=required
  [[ "$build_subject" != source-only ]] || sbom=not-applicable
  if [[ "$product_type" == library ]]; then interface=library-only; ux=not-applicable; fi
  if [[ "$env_profile" == not-available ]]; then env_id=not-applicable; env_auth=not-applicable; fi
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 4' 'revision: 1' 'previous_revision: 0' \
      'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: s5 validation fixture'
    for pair in \
      "product_type=$product_type" 'scm_repository_model=single-repo' \
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
      'evidence_merge_blocking=required' "build_subject=$build_subject" "sbom_requirement=$sbom" \
      "user_interface=$interface" "ux_brief_requirement=$ux" \
      "validation_environment_profile=$env_profile" "validation_environment_identity=$env_id" \
      "validation_environment_authorization=$env_auth" \
      "performance_validation=$perf" "runtime_security_validation=$security"; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_build_evidence() {
  local project="$1" artifact="$2" subject=none build=none kind=source
  if [[ "$artifact" == yes ]]; then subject="$DIGEST"; build=build-001; kind=build-artifact; fi
  mkdir -p "$project/tracking/evidence/v1" "$project/tracking/evidence/raw" \
    "$project/stage2-requirements/outputs" "$project/stage3-design/outputs" "$project/tests"
  printf '%s\n' 'FR-001' > "$project/stage2-requirements/outputs/BRD.md"
  printf '%s\n' 'ARCH-001' > "$project/stage3-design/outputs/HLD.md"
  printf '%s\n' 'TEST-BUILD' > "$project/tests/build-check.txt"
  printf '%s\n' $'requirement_id\trequirement_uri\tspecification_id\tspecification_uri\ttest_id\ttest_uri\tsource_revision' \
    $'FR-001\tstage2-requirements/outputs/BRD.md\tARCH-001\tstage3-design/outputs/HLD.md\tTEST-BUILD\ttests/build-check.txt\t5555555555555555555555555555555555555555' > \
    "$project/tracking/traceability-v1.tsv"
  printf '{"schema_version":1,"check_id":"build","source_revision":"%s","status":"pass"}\n' "$SOURCE" > \
    "$project/tracking/evidence/raw/build.json"
  raw_sha="$(sha256sum "$project/tracking/evidence/raw/build.json" | awk '{print $1}')"
  {
    printf '%s\n' 'schema_version: 1' 'evidence_id: EV-BUILD-S5' 'check_id: build' 'category: build' \
      'source_profile: repository-ci' 'execution_mode: live' \
      'executor_identity: github-actions:workflow-security' \
      'producer_identity: github-actions:security-job' 'tool_name: fixture-builder' 'tool_version: 1.0.0' \
      "source_revision: $SOURCE" "subject_kind: $kind" "subject_digest: $subject" \
      "build_identity: $build" 'config_revision: cfg-1' 'policy_revision: quality-global-v1' \
      'product_profile_revision: 1' "observed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      'freshness_seconds: 3600' 'raw_format: json' 'raw_result_uri: tracking/evidence/raw/build.json' \
      "raw_result_sha256: $raw_sha" 'signature_status: not-provided' 'verdict: PASS' \
      'applicability_reason: none' 'applicability_owner: none' 'requirement_ids: FR-001' \
      'specification_ids: ARCH-001' 'test_ids: TEST-BUILD' 'human_approval_ref: none' \
      'risk_exception_ref: none'
  } > "$project/tracking/evidence/v1/EV-BUILD-S5.yaml"
}

write_approval() {
  local project="$1" name="$2" approver="$3" scope="$4" subject="$5"
  mkdir -p "$project/tracking/approvals"
  {
    printf '%s\n' 'schema_version: 1' "approval_id: $name" 'approval_origin: launcher-human-v1' "approver_identity: $approver" \
      'decision: APPROVE' "scope: $scope" \
      'rationale: representative environment and observed result were reviewed and accepted' \
      "source_revision: $SOURCE" "subject_digest: $subject" \
      "observed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$project/tracking/approvals/$name.yaml"
  record_human_approval_receipt "$project" "$project/tracking/approvals/$name.yaml"
}

write_known_issue_approval() {
  local project="$1" defect_id="$2" source_stream="$3" source_finding="$4"
  local severity="$5" known_issue="$6" tech_debt="$7" approval_id="$8"
  local defect_digest approval_ref
  defect_digest="sha256:$(printf '%s\t%s\t%s\t%s\tyes\tKNOWN_ISSUE\t%s\t%s\n' \
    "$defect_id" "$source_stream" "$source_finding" "$severity" "$known_issue" "$tech_debt" |
    sha256sum | awk '{print $1}')"
  approval_ref="tracking/approvals/$approval_id.yaml"
  write_approval "$project" "$approval_id" product-owner \
    "known-issue:$known_issue defect:$defect_id" "$defect_digest"
  printf '%s\n' "$approval_ref"
}

write_known_issue_record() {
  local project="$1" known_issue="$2" severity="$3" tech_debt="$4" approval_ref="$5"
  {
    printf '%s\n' '# Known Issues — fixture' '' "### $known_issue — Accepted user-facing defect" \
      "- Severity: $severity" \
      '- Trigger: representative user action reaches the affected validation path' \
      '- Impact: user-facing — the action reports a bounded incorrect result' \
      '- Workaround: repeat the action through the documented alternate path' \
      '- Detection signal: validation log contains the exact source finding id' \
      '- Auto-remediation: нет' "- → tech-debt: $tech_debt" \
      "- Human Approval v1: $approval_ref" \
      '- Fix release version: none' '- Fix build evidence ref: none' \
      '- Fix build evidence sha256: none' '- Fix source revision: none' \
      '- Fix verification test id: none' '- Operational scope: FROZEN_NOT_READY' \
      '- Alert cleanup evidence: none' '- Runbook cleanup evidence: none' '- Status: OPEN'
  } > "$project/tracking/known-issues.md"
}

metadata_header() {
  local project="$1" artifact_id="$2" artifact_type="$3" producer="$4" status="$5" inputs="$6" output="$7"
  printf '%s\n' '---' 'schema_version: 1' "artifact_id: $artifact_id" \
    "artifact_type: $artifact_type" "project: $(basename "$project")" 'stage: S5' \
    "producer: $producer" "source_revision: $SOURCE" "status: $status" \
    "inputs: $inputs" "outputs: $output" 'tags: sdlc,cycle1,stage5,validation'
}

write_s5() {
  local project="$1" artifact="$2" perf="$3" security="$4"
  local subject=none build=none env=qa-env-1 perf_app=REQUIRED sec_app=REQUIRED
  local profile_schema criterion_results='[]'
  profile_schema="$(awk -F: '$1 == "schema_version" {gsub(/[[:space:]]/, "", $2); print $2; exit}' \
    "$project/tracking/product-ci-profile.yaml")"
  if [[ "$profile_schema" == 5 &&
        "$(awk -F: '$1 == "ux_brief_requirement" {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$project/tracking/product-ci-profile.yaml")" == required ]]; then
    criterion_results='[{"criterion_id":"UXC-001","test_id":"TEST-UXC-001","result":"PASS"}]'
    if [[ "$(awk -F: '$1 == "accessibility_validation" {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$project/tracking/product-ci-profile.yaml")" == required ]]; then
      criterion_results='[{"criterion_id":"UXC-001","test_id":"TEST-UXC-001","result":"PASS"},{"criterion_id":"A11Y-001","test_id":"TEST-A11Y-001","result":"PASS"}]'
    fi
  fi
  [[ "$artifact" != yes ]] || { subject="$DIGEST"; build=build-001; }
  [[ "$perf" != not-applicable ]] || perf_app=NOT_APPLICABLE
  [[ "$security" != not-applicable ]] || sec_app=NOT_APPLICABLE
  mkdir -p "$project/tracking/validation/raw" "$project/stage5-testing/outputs"
  printf '%s\n' '# Dashboard' > "$project/Dashboard.md"
  write_approval "$project" APPROVAL-ENV-QA qa-owner "environment:$env" "$subject"
  write_approval "$project" APPROVAL-UAT-001 product-owner "uat:UAT-001 environment:$env" "$subject"
  mkdir -p "$project/stage2-requirements/outputs"
  printf '%s\n' $'uat_id\tmust_fr_id\trisk_id\tux_flow_id\tcriteria_uri' \
    $'UAT-001\tFR-001\tRISK-001\tNOT_APPLICABLE\tstage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md' > \
    "$project/stage2-requirements/outputs/UAT-product-acceptance-v1.tsv"
  printf '%s\n' '# UAT' 'UAT-001' > "$project/stage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md"

  printf '{"schema_version":1,"stream_id":"automation","source_revision":"%s","subject_digest":"%s","build_identity":"%s","environment_id":"%s","regression_scope":"full-affected","expected_tests":2,"executed_tests":2,"passed":2,"failed":0,"skipped":0,"test_results":[{"test_id":"TEST-AUTO-001","path_id":"UAT-001","result":"PASS"},{"test_id":"TEST-AUTO-002","path_id":"UAT-001","result":"PASS"}],"critical_paths_total":1,"critical_paths_automated":1,"automation_coverage_percent":100,"critical_path_results":[{"path_id":"UAT-001","automated":true,"test_id":"TEST-AUTO-001","result":"PASS"}],"criterion_results":%s,"quality_metrics":[{"metric_id":"test_pass_rate_percent","operator":">=","threshold":98,"observed":100,"unit":"percent","verdict":"PASS","policy_revision":"quality-global-v1"},{"metric_id":"e2e_automation_percent","operator":">=","threshold":95,"observed":100,"unit":"percent","verdict":"PASS","policy_revision":"quality-global-v1"}],"findings":[]}\n' \
    "$SOURCE" "$subject" "$build" "$env" "$criterion_results" > "$project/tracking/validation/raw/automation.json"
  if [[ "$perf" == required ]]; then
    printf '{"schema_version":1,"stream_id":"performance","source_revision":"%s","subject_digest":"%s","build_identity":"%s","environment_id":"%s","verdict":"PASS","metrics_total":1,"metrics_evaluated":1,"metrics_failed":0,"quality_metrics":[{"metric_id":"response_time_p95_ms","operator":"<=","threshold":500,"observed":450,"unit":"ms","verdict":"PASS","policy_revision":"quality-global-v1"}],"findings":[]}\n' \
      "$SOURCE" "$subject" "$build" "$env" > "$project/tracking/validation/raw/performance.json"
  else
    printf '{"schema_version":1,"stream_id":"performance","source_revision":"%s","subject_digest":"%s","build_identity":"%s","environment_id":"not-applicable","verdict":"NOT_APPLICABLE","profile_revision":1,"applicability_owner":"s0-kickoff","applicability_reason":"s5 validation fixture","metrics_total":0,"metrics_evaluated":0,"metrics_failed":0,"quality_metrics":[],"findings":[]}\n' \
      "$SOURCE" "$subject" "$build" > "$project/tracking/validation/raw/performance.json"
  fi
  if [[ "$security" == required ]]; then
    mkdir -p "$project/stage3-design/outputs"
    printf '%s\n' '# SG1 Security Requirements' 'asvs_version: 5.0.0' 'ASVS-ref: v5.0.0-1.2.3' 'SEC-SCENARIO-SG1-001: abuse case is denied.' > "$project/stage2-requirements/outputs/SEC-2026-07-27-security-requirements.md"
    printf '%s\n' '# SG2 Threat Model' 'asvs_version: 5.0.0' 'SEC-SCENARIO-SG2-001: threat mitigation is exercised.' > "$project/stage3-design/outputs/SEC-2026-07-27-threat-model.md"
    printf '{"schema_version":1,"stream_id":"security","source_revision":"%s","subject_digest":"%s","build_identity":"%s","environment_id":"%s","verdict":"PASS","scenarios_total":2,"scenarios_evaluated":2,"scenario_results":[{"scenario_id":"SEC-SCENARIO-SG1-001","test_id":"TEST-SEC-SG1-001","result":"PASS"},{"scenario_id":"SEC-SCENARIO-SG2-001","test_id":"TEST-SEC-SG2-001","result":"PASS"}],"findings":[]}\n' \
      "$SOURCE" "$subject" "$build" "$env" > "$project/tracking/validation/raw/security.json"
  else
    printf '{"schema_version":1,"stream_id":"security","source_revision":"%s","subject_digest":"%s","build_identity":"%s","environment_id":"not-applicable","verdict":"NOT_APPLICABLE","profile_revision":1,"applicability_owner":"s0-kickoff","applicability_reason":"s5 validation fixture","scenarios_total":0,"scenarios_evaluated":0,"scenario_results":[],"findings":[]}\n' \
      "$SOURCE" "$subject" "$build" > "$project/tracking/validation/raw/security.json"
  fi
  {
    metadata_header "$project" QA-EXPLORATORY-20260727 exploratory-report s5-qa PASS \
      stage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria.md \
      stage5-testing/outputs/QA-2026-07-27-exploratory-report.md
    printf '%s\n' 'owner: s5-qa' \
      "subject_digest: $subject" "build_identity: $build" \
      "environment_id: $env" 'duration_minutes: 45' '---' '' '# Exploratory Session' '' \
      '## Charter' 'Explore shared-plan state transitions and error recovery.' '' \
      '## Observations' 'Bounded session completed.' '' '## Findings' 'None.' '' \
      '## Obsidian Links' '- Dashboard: [[Dashboard]]' \
      '- Inputs: [[stage2-requirements/outputs/UAT-2026-07-27-acceptance-criteria]]' \
      '- Outputs: [[stage5-testing/outputs/QA-2026-07-27-exploratory-report]]'
  } > "$project/stage5-testing/outputs/QA-2026-07-27-exploratory-report.md"
  printf '%s\n' $'uat_id\tresult\tsource_revision\tenvironment_id' \
    "UAT-001"$'\tPASS\t'"$SOURCE"$'\t'"$env" > "$project/tracking/validation/raw/uat-results.tsv"

  for report in \
    'AUTO-2026-07-27-e2e-report.md|AUTO-E2E-20260727|automation-report|s5-qa-auto|qa-env-1' \
    'AUTO-2026-07-27-coverage.md|AUTO-COVERAGE-20260727|automation-coverage|s5-qa-auto|qa-env-1'; do
    IFS='|' read -r filename artifact_id artifact_type owner report_env <<< "$report"
    {
      metadata_header "$project" "$artifact_id" "$artifact_type" "$owner" PASS \
        tracking/validation/raw/automation.json "stage5-testing/outputs/$filename"
      printf '%s\n' "owner: $owner" \
        "subject_digest: $subject" "build_identity: $build" \
        "environment_id: $report_env" '---' '' "# $artifact_type" '' 'Verified summary.' '' \
        '## Obsidian Links' '- Dashboard: [[Dashboard]]' \
        '- Inputs: `tracking/validation/raw/automation.json`' \
        "- Outputs: [[stage5-testing/outputs/${filename%.md}]]"
    } > "$project/stage5-testing/outputs/$filename"
  done
  perf_env="$env"; sec_env="$env"
  perf_status=PASS; sec_status=PASS
  [[ "$perf" == required ]] || perf_env=not-applicable
  [[ "$security" == required ]] || sec_env=not-applicable
  [[ "$perf" == required ]] || perf_status=NOT_APPLICABLE
  [[ "$security" == required ]] || sec_status=NOT_APPLICABLE
  for report in \
    "PERF-2026-07-27-report.md|PERF-REPORT-20260727|performance-report|s5-perf|$perf_env|$perf_status|performance.json" \
    "SEC-2026-07-27-pentest-report.md|SEC-REPORT-20260727|security-report|s5-security|$sec_env|$sec_status|security.json"; do
    IFS='|' read -r filename artifact_id artifact_type owner report_env report_status raw_name <<< "$report"
    {
      metadata_header "$project" "$artifact_id" "$artifact_type" "$owner" "$report_status" \
        "tracking/validation/raw/$raw_name" "stage5-testing/outputs/$filename"
      printf '%s\n' "owner: $owner" \
        "subject_digest: $subject" "build_identity: $build" \
        "environment_id: $report_env" '---' '' "# $artifact_type" '' 'Verified summary.' '' \
        '## Obsidian Links' '- Dashboard: [[Dashboard]]' \
        "- Inputs: \`tracking/validation/raw/$raw_name\`" \
        "- Outputs: [[stage5-testing/outputs/${filename%.md}]]"
    } > "$project/stage5-testing/outputs/$filename"
  done

  auto_sha="$(sha256sum "$project/tracking/validation/raw/automation.json" | awk '{print $1}')"
  perf_sha="$(sha256sum "$project/tracking/validation/raw/performance.json" | awk '{print $1}')"
  sec_sha="$(sha256sum "$project/tracking/validation/raw/security.json" | awk '{print $1}')"
  exp_sha="$(sha256sum "$project/stage5-testing/outputs/QA-2026-07-27-exploratory-report.md" | awk '{print $1}')"
  uat_sha="$(sha256sum "$project/tracking/validation/raw/uat-results.tsv" | awk '{print $1}')"
  {
    printf '%s\n' $'stream_id\towner\tapplicability\tverdict\tsource_revision\tsubject_digest\tbuild_identity\tenvironment_id\traw_format\traw_result_uri\traw_result_sha256\tfinding_ids\tenvironment_approval_ref\thuman_approval_ref\trisk_exception_ref'
    printf 'automation\ts5-qa-auto\tREQUIRED\tPASS\t%s\t%s\t%s\t%s\tjson\ttracking/validation/raw/automation.json\t%s\tnone\ttracking/approvals/APPROVAL-ENV-QA.yaml\tnone\tnone\n' "$SOURCE" "$subject" "$build" "$env" "$auto_sha"
    printf 'performance\ts5-perf\t%s\t%s\t%s\t%s\t%s\t%s\tjson\ttracking/validation/raw/performance.json\t%s\tnone\t%s\tnone\tnone\n' \
      "$perf_app" "$([[ "$perf" == required ]] && printf PASS || printf NOT_APPLICABLE)" "$SOURCE" "$subject" "$build" \
      "$([[ "$perf" == required ]] && printf %s "$env" || printf not-applicable)" "$perf_sha" \
      "$([[ "$perf" == required ]] && printf tracking/approvals/APPROVAL-ENV-QA.yaml || printf none)"
    printf 'security\ts5-security\t%s\t%s\t%s\t%s\t%s\t%s\tjson\ttracking/validation/raw/security.json\t%s\tnone\t%s\tnone\tnone\n' \
      "$sec_app" "$([[ "$security" == required ]] && printf PASS || printf NOT_APPLICABLE)" "$SOURCE" "$subject" "$build" \
      "$([[ "$security" == required ]] && printf %s "$env" || printf not-applicable)" "$sec_sha" \
      "$([[ "$security" == required ]] && printf tracking/approvals/APPROVAL-ENV-QA.yaml || printf none)"
    printf 'exploratory\ts5-qa\tREQUIRED\tPASS\t%s\t%s\t%s\t%s\tmarkdown\tstage5-testing/outputs/QA-2026-07-27-exploratory-report.md\t%s\tnone\ttracking/approvals/APPROVAL-ENV-QA.yaml\tnone\tnone\n' "$SOURCE" "$subject" "$build" "$env" "$exp_sha"
    printf 'uat\ts5-qa\tREQUIRED\tPASS\t%s\t%s\t%s\t%s\ttsv\ttracking/validation/raw/uat-results.tsv\t%s\tnone\ttracking/approvals/APPROVAL-ENV-QA.yaml\ttracking/approvals/APPROVAL-UAT-001.yaml\tnone\n' "$SOURCE" "$subject" "$build" "$env" "$uat_sha"
  } > "$project/tracking/validation/S5-validation-v1.tsv"

  printf '%s\n' $'defect_id\tsource_stream\tsource_finding_id\tseverity\tuser_facing\tdisposition\tknown_issue_id\ttech_debt_id\tacceptance_approval_ref' > \
    "$project/stage5-testing/outputs/DEF-defects-v1.tsv"
  {
    metadata_header "$project" DEF-REGISTER-20260727 defect-register s5-qa PASS \
      tracking/validation/S5-validation-v1.tsv stage5-testing/outputs/DEF-2026-07-27-defects.md
    printf '%s\n' 'owner: s5-qa' \
      "subject_digest: $subject" "build_identity: $build" \
      'machine_index: stage5-testing/outputs/DEF-defects-v1.tsv' '---' '' '# Defect Register' '' \
      'No findings in the current validation bundle.' '' '## Obsidian Links' \
      '- Dashboard: [[Dashboard]]' '- Inputs: `tracking/validation/S5-validation-v1.tsv`' \
      '- Outputs: [[stage5-testing/outputs/DEF-2026-07-27-defects]]'
  } > "$project/stage5-testing/outputs/DEF-2026-07-27-defects.md"
  {
    metadata_header "$project" QA-ANALYSIS-20260727 test-analysis s5-qa PASS \
      stage5-testing/outputs/DEF-defects-v1.tsv stage5-testing/outputs/QA-2026-07-27-test-analysis.md
    printf '%s\n' 'owner: s5-qa' \
      "subject_digest: $subject" "build_identity: $build" '---' \
      '' '# Test Analysis' '' '## Failure Analysis' 'No failures.' '' '## Flaky Tests' 'None.' \
      '' '## Coverage Gaps' 'None in the declared scope.' '' '## Quality Trend' 'Stable baseline.' '' \
      '## Obsidian Links' '- Dashboard: [[Dashboard]]' \
      '- Inputs: `stage5-testing/outputs/DEF-defects-v1.tsv`' \
      '- Outputs: [[stage5-testing/outputs/QA-2026-07-27-test-analysis]]'
  } > "$project/stage5-testing/outputs/QA-2026-07-27-test-analysis.md"
  index_sha="$(sha256sum "$project/tracking/validation/S5-validation-v1.tsv" | awk '{print $1}')"
  defects_sha="$(sha256sum "$project/stage5-testing/outputs/DEF-defects-v1.tsv" | awk '{print $1}')"
  {
    metadata_header "$project" QA-GATE5-20260727 gate5-decision s5-qa APPROVED \
      tracking/validation/S5-validation-v1.tsv,stage5-testing/outputs/DEF-defects-v1.tsv,tracking/approvals/APPROVAL-UAT-001.yaml \
      stage5-testing/outputs/QA-2026-07-27-go-no-go.md
    printf '%s\n' 'owner: s5-qa' \
      'product_profile_revision: 1' "subject_digest: $subject" \
      "build_identity: $build" "validation_index_sha256: $index_sha" \
      "defect_index_sha256: $defects_sha" \
      'uat_approval_ref: tracking/approvals/APPROVAL-UAT-001.yaml' 'verdict: GO' '---' '' \
      '# Go/No-Go' 'Verified machine evidence and separate human UAT approval were reviewed.' '' \
      '## Obsidian Links' '- Dashboard: [[Dashboard]]' \
      '- Inputs: `tracking/validation/S5-validation-v1.tsv`, `stage5-testing/outputs/DEF-defects-v1.tsv`, `tracking/approvals/APPROVAL-UAT-001.yaml`' \
      '- Outputs: [[stage5-testing/outputs/QA-2026-07-27-go-no-go]]'
  } > "$project/stage5-testing/outputs/QA-2026-07-27-go-no-go.md"
}

write_valid_project() {
  local project="$1" kind="$2"
  if [[ "$kind" == service ]]; then
    write_profile_v4 "$project" service build-artifact required required connected-representative
    write_build_evidence "$project" yes
    write_s5 "$project" yes required required
  else
    write_profile_v4 "$project" library source-only not-applicable not-applicable local-representative
    write_build_evidence "$project" no
    write_s5 "$project" no not-applicable not-applicable
  fi
}

upgrade_profile_to_v5() {
  local project="$1"
  sed -i 's/^schema_version: 4/schema_version: 5/' "$project/tracking/product-ci-profile.yaml"
  for pair in 'compatibility_validation=required' 'accessibility_validation=required' \
    'flexibility_validation=required' 'safety_validation=not-applicable'; do
    key="${pair%%=*}"; value="${pair#*=}"
    printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key" >> \
      "$project/tracking/product-ci-profile.yaml"
  done
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
  write_quality_characteristics_fixture "$project"
  mkdir -p "$project/stage2-requirements/outputs"
  printf '%s\n' '# UX Brief' '## UX Acceptance Constraints' \
    '- UXC-001: exact interaction flow succeeds. Measure: 100 percent completion.' \
    '## Accessibility Criteria' \
    '- A11Y-001: keyboard flow succeeds. Measure: 100 percent completion.' > \
    "$project/stage2-requirements/outputs/PO-2026-07-27-ux-brief.md"
}

expect_blocked() {
  local label="$1" project="$2" output="$3" expected="${4:-}"
  if bash "$CHECK" "$project" "$SOURCE" >"$output" 2>&1; then fail "$label"; fi
  grep -Fq 'S5 VALIDATION BLOCKED' "$output" || fail "$label did not emit BLOCKED"
  [[ -z "$expected" ]] || grep -Fq "$expected" "$output" ||
    fail "$label did not report expected reason: $expected"
}

refresh_s5_bindings() {
  local project="$1" raw_uri old_sha new_sha index_sha defects_sha
  while IFS=$'\t' read -r raw_uri old_sha; do
    new_sha="$(sha256sum "$project/$raw_uri" | awk '{print $1}')"
    sed -i "s/$old_sha/$new_sha/" "$project/tracking/validation/S5-validation-v1.tsv"
  done < <(awk -F'\t' 'NR>1 {print $10 "\t" $11}' \
    "$project/tracking/validation/S5-validation-v1.tsv")
  index_sha="$(sha256sum "$project/tracking/validation/S5-validation-v1.tsv" | awk '{print $1}')"
  defects_sha="$(sha256sum "$project/stage5-testing/outputs/DEF-defects-v1.tsv" | awk '{print $1}')"
  sed -i -e "s/^validation_index_sha256:.*/validation_index_sha256: $index_sha/" \
    -e "s/^defect_index_sha256:.*/defect_index_sha256: $defects_sha/" \
    "$project/stage5-testing/outputs/QA-2026-07-27-go-no-go.md"
}

write_sprint_boundaries() {
  local project="$1" target="$2" target_end="$3"
  mkdir -p "$project/tracking/sprints"
  printf '%s\n' '---' 'sprint: 1' 'start: 2026-07-01' 'end: 2026-07-14' \
    'status: CLOSED' '---' > "$project/tracking/sprints/sprint-01.md"
  printf '%s\n' '---' "sprint: $target" "start: $(date -u +%Y-%m-%d)" \
    "end: $target_end" 'status: PLANNED' '---' > \
    "$project/tracking/sprints/sprint-$(printf '%02d' "$target").md"
}

rebind_fixture_project() {
  local project="$1" old_name="$2" new_name file
  new_name="$(basename "$project")"
  while IFS= read -r file; do
    sed -i "s/^project: $old_name$/project: $new_name/" "$file"
  done < <(rg -l "^project: $old_name$" "$project")
  while IFS= read -r file; do
    record_human_approval_receipt "$project" "$file"
  done < <(find "$project/tracking/approvals" -maxdepth 1 -type f -name 'APPROVAL-*.yaml' | sort)
}

service_fixture_name=service
if [[ -n "${S5_FIXTURE_EXPORT_DIR:-}" ]]; then
  service_fixture_name="$(basename "$S5_FIXTURE_EXPORT_DIR")"
fi
P_SERVICE="$TMP_DIR/$service_fixture_name"
write_valid_project "$P_SERVICE" service
bash "$PROFILE_CHECK" "$P_SERVICE" >/dev/null || fail 'valid Product Profile v4 was rejected'
bash "$CHECK" "$P_SERVICE" "$SOURCE" > "$TMP_DIR/service.out" || fail 'valid service S5 bundle was rejected'
grep -Fq 'S5 VALIDATION VERIFIED' "$TMP_DIR/service.out" || fail 'S5 verified verdict missing'

P_ASVS_UNVERSIONED="$TMP_DIR/asvs-unversioned"
cp -a "$P_SERVICE" "$P_ASVS_UNVERSIONED"
rebind_fixture_project "$P_ASVS_UNVERSIONED" "$service_fixture_name"
sed -i 's/v5\.0\.0-1\.2\.3/1.2.3/' "$P_ASVS_UNVERSIONED/stage2-requirements/outputs/SEC-2026-07-27-security-requirements.md"
expect_blocked 'unversioned ASVS requirement reference was accepted' "$P_ASVS_UNVERSIONED" "$TMP_DIR/asvs-unversioned.out" 'unversioned ASVS requirement reference'

P_ASVS_MISMATCH="$TMP_DIR/asvs-version-mismatch"
cp -a "$P_SERVICE" "$P_ASVS_MISMATCH"
rebind_fixture_project "$P_ASVS_MISMATCH" "$service_fixture_name"
sed -i 's/asvs_version: 5\.0\.0/asvs_version: 4.0.3/' "$P_ASVS_MISMATCH/stage3-design/outputs/SEC-2026-07-27-threat-model.md"
expect_blocked 'SG2 ASVS version mismatch was accepted' "$P_ASVS_MISMATCH" "$TMP_DIR/asvs-version-mismatch.out" 'SG2 asvs_version must match SG1'

P_SERVICE_V5="$TMP_DIR/service-v5"
write_valid_project "$P_SERVICE_V5" service
upgrade_profile_to_v5 "$P_SERVICE_V5"
write_s5 "$P_SERVICE_V5" yes required required
bash "$PROFILE_CHECK" "$P_SERVICE_V5" >/dev/null || fail 'valid Product Profile v5 was rejected'
bash "$CHECK" "$P_SERVICE_V5" "$SOURCE" >/dev/null || fail 'valid schema v5 S5 bundle was rejected'

P_POLICY_METRIC="$TMP_DIR/performance-policy-mismatch"
cp -a "$P_SERVICE" "$P_POLICY_METRIC"
rebind_fixture_project "$P_POLICY_METRIC" "$service_fixture_name"
sed -i 's/"threshold":500/"threshold":499/' \
  "$P_POLICY_METRIC/tracking/validation/raw/performance.json"
refresh_s5_bindings "$P_POLICY_METRIC"
expect_blocked 'performance metric detached from effective policy was accepted' \
  "$P_POLICY_METRIC" "$TMP_DIR/performance-policy.out"
grep -Fq 'quality metric threshold mismatch' "$TMP_DIR/performance-policy.out" ||
  fail "performance threshold mismatch did not fail at effective policy binding: $(tr '\n' ' ' < "$TMP_DIR/performance-policy.out")"

P_PATH_SCOPE="$TMP_DIR/critical-path-scope"
cp -a "$P_SERVICE" "$P_PATH_SCOPE"
rebind_fixture_project "$P_PATH_SCOPE" "$service_fixture_name"
sed -i 's/UAT-001/UAT-OTHER/g' "$P_PATH_SCOPE/tracking/validation/raw/automation.json"
refresh_s5_bindings "$P_PATH_SCOPE"
expect_blocked 'automation with a different critical-path set was accepted' \
  "$P_PATH_SCOPE" "$TMP_DIR/path-scope.out"
grep -Fq 'critical path ids do not match' "$TMP_DIR/path-scope.out" ||
  fail 'critical path mismatch did not fail against the S2 catalog'

P_SECURITY_SCOPE="$TMP_DIR/security-scenario-scope"
cp -a "$P_SERVICE" "$P_SECURITY_SCOPE"
rebind_fixture_project "$P_SECURITY_SCOPE" "$service_fixture_name"
sed -i 's/SEC-SCENARIO-SG2-001/SEC-SCENARIO-OTHER-001/g' \
  "$P_SECURITY_SCOPE/tracking/validation/raw/security.json"
refresh_s5_bindings "$P_SECURITY_SCOPE"
expect_blocked 'security result with a different SG1/SG2 scenario set was accepted' \
  "$P_SECURITY_SCOPE" "$TMP_DIR/security-scope.out"
grep -Fq 'scenario ids do not match' "$TMP_DIR/security-scope.out" ||
  fail 'security scenario mismatch did not fail against SG1/SG2 artifacts'

P_A11Y_RESULT="$TMP_DIR/accessibility-result-missing"
cp -a "$P_SERVICE_V5" "$P_A11Y_RESULT"
rebind_fixture_project "$P_A11Y_RESULT" service-v5
sed -i 's/,{"criterion_id":"A11Y-001","test_id":"TEST-A11Y-001","result":"PASS"}//' \
  "$P_A11Y_RESULT/tracking/validation/raw/automation.json"
refresh_s5_bindings "$P_A11Y_RESULT"
expect_blocked 'required accessibility criteria without execution result were accepted' \
  "$P_A11Y_RESULT" "$TMP_DIR/a11y-result.out"
grep -Fq 'UX/A11Y execution results do not match' "$TMP_DIR/a11y-result.out" ||
  fail 'missing A11Y result did not fail against required criteria'

P_LIBRARY="$TMP_DIR/library"
write_valid_project "$P_LIBRARY" library
bash "$CHECK" "$P_LIBRARY" "$SOURCE" >/dev/null || fail 'valid library/source-only S5 bundle was rejected'

P_NA_REASON="$TMP_DIR/na-reason-tamper"
cp -a "$P_LIBRARY" "$P_NA_REASON"
rebind_fixture_project "$P_NA_REASON" library
sed -i 's/"applicability_reason":"s5 validation fixture"/"applicability_reason":"unbound local reason"/' \
  "$P_NA_REASON/tracking/validation/raw/performance.json"
refresh_s5_bindings "$P_NA_REASON"
expect_blocked 'S5 N/A with reason detached from resolver was accepted' \
  "$P_NA_REASON" "$TMP_DIR/na-reason.out"
grep -Fq 'invalid performance N/A' "$TMP_DIR/na-reason.out" ||
  fail 'tampered S5 N/A reason did not fail exact resolver binding'

P_SELECTIVE="$TMP_DIR/selective"
write_valid_project "$P_SELECTIVE" service
sed -i 's/full-affected/selective/' "$P_SELECTIVE/tracking/validation/raw/automation.json"
old_sha="$(awk -F'\t' '$1=="automation" {print $11}' "$P_SELECTIVE/tracking/validation/S5-validation-v1.tsv")"
new_sha="$(sha256sum "$P_SELECTIVE/tracking/validation/raw/automation.json" | awk '{print $1}')"
sed -i "s/$old_sha/$new_sha/" "$P_SELECTIVE/tracking/validation/S5-validation-v1.tsv"
expect_blocked 'selective S5 automation PASS was accepted' "$P_SELECTIVE" "$TMP_DIR/selective.out"

P_UAT="$TMP_DIR/missing-uat-approval"
write_valid_project "$P_UAT" service
rm "$P_UAT/tracking/approvals/APPROVAL-UAT-001.yaml"
expect_blocked 'missing human UAT approval was accepted' "$P_UAT" "$TMP_DIR/uat.out"

P_SUBJECT="$TMP_DIR/wrong-subject"
write_valid_project "$P_SUBJECT" service
sed -i '0,/sha256:aaaaaaaa/s//sha256:bbbbbbbb/' "$P_SUBJECT/tracking/validation/S5-validation-v1.tsv"
expect_blocked 'wrong build subject was accepted' "$P_SUBJECT" "$TMP_DIR/subject.out"

P_SECURITY="$TMP_DIR/security-high"
write_valid_project "$P_SECURITY" service
printf '{"schema_version":1,"stream_id":"security","source_revision":"%s","subject_digest":"%s","build_identity":"build-001","environment_id":"qa-env-1","verdict":"FAIL","scenarios_total":2,"scenarios_evaluated":2,"scenario_results":[{"scenario_id":"SEC-SCENARIO-SG1-001","test_id":"TEST-SEC-SG1-001","result":"PASS"},{"scenario_id":"SEC-SCENARIO-SG2-001","test_id":"TEST-SEC-SG2-001","result":"FAIL"}],"findings":[{"id":"SG4-001","cvss":9.1,"status":"open"}]}\n' "$SOURCE" "$DIGEST" > "$P_SECURITY/tracking/validation/raw/security.json"
old_sha="$(awk -F'\t' '$1=="security" {print $11}' "$P_SECURITY/tracking/validation/S5-validation-v1.tsv")"
new_sha="$(sha256sum "$P_SECURITY/tracking/validation/raw/security.json" | awk '{print $1}')"
sed -i -e "s/$old_sha/$new_sha/" -e $'s/security\ts5-security\tREQUIRED\tPASS/security\ts5-security\tREQUIRED\tFAIL/' \
  -e $'s/\tnone\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\tnone$/\tSG4-001\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\tnone/' \
  "$P_SECURITY/tracking/validation/S5-validation-v1.tsv"
expect_blocked 'open Critical/High SG4 finding was accepted' "$P_SECURITY" "$TMP_DIR/security.out"

P_SECURITY_LOW_MISSING="$TMP_DIR/security-low-missing-td"
write_valid_project "$P_SECURITY_LOW_MISSING" service
printf '{"schema_version":1,"stream_id":"security","source_revision":"%s","subject_digest":"%s","build_identity":"build-001","environment_id":"qa-env-1","verdict":"PASS","scenarios_total":2,"scenarios_evaluated":2,"scenario_results":[{"scenario_id":"SEC-SCENARIO-SG1-001","test_id":"TEST-SEC-SG1-001","result":"PASS"},{"scenario_id":"SEC-SCENARIO-SG2-001","test_id":"TEST-SEC-SG2-001","result":"PASS"}],"findings":[{"id":"SG4-LOW","cvss":2.5,"status":"open"}]}\n' \
  "$SOURCE" "$DIGEST" > "$P_SECURITY_LOW_MISSING/tracking/validation/raw/security.json"
sed -i $'/^security\t/s/\tnone\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\tnone$/\tSG4-LOW\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\tnone/' \
  "$P_SECURITY_LOW_MISSING/tracking/validation/S5-validation-v1.tsv"
printf '%s\n' $'DEF-SG4-LOW\tsecurity\tSG4-LOW\tCVSS-LOW\tno\tTECH_DEBT\tnone\tnone\tnone' >> \
  "$P_SECURITY_LOW_MISSING/stage5-testing/outputs/DEF-defects-v1.tsv"
refresh_s5_bindings "$P_SECURITY_LOW_MISSING"
expect_blocked 'open SG4 Low without exact tech debt was accepted' \
  "$P_SECURITY_LOW_MISSING" "$TMP_DIR/security-low-missing.out"

P_SECURITY_LOW_SPOOF="$TMP_DIR/security-low-spoofed-severity"
cp -a "$P_SECURITY_LOW_MISSING" "$P_SECURITY_LOW_SPOOF"
rebind_fixture_project "$P_SECURITY_LOW_SPOOF" security-low-missing-td
sed -i 's/CVSS-LOW/CVSS-MEDIUM/' "$P_SECURITY_LOW_SPOOF/stage5-testing/outputs/DEF-defects-v1.tsv"
refresh_s5_bindings "$P_SECURITY_LOW_SPOOF"
expect_blocked 'defect severity contradicting raw CVSS was accepted' \
  "$P_SECURITY_LOW_SPOOF" "$TMP_DIR/security-low-spoof.out"
grep -Fq 'severity contradicts raw CVSS' "$TMP_DIR/security-low-spoof.out" ||
  fail "spoofed severity did not fail at the exact raw CVSS binding: $(tr '\n' ' ' < "$TMP_DIR/security-low-spoof.out")"

P_SECURITY_LOW="$TMP_DIR/security-low-valid"
cp -a "$P_SECURITY_LOW_MISSING" "$P_SECURITY_LOW"
rebind_fixture_project "$P_SECURITY_LOW" security-low-missing-td
low_deadline="$(date -u -d '+60 days' +%Y-%m-%d)"
low_sprint_end="$(date -u -d '+65 days' +%Y-%m-%d)"
write_sprint_boundaries "$P_SECURITY_LOW" 3 "$low_sprint_end"
{
  printf '%s\n' '# Tech Debt Log — fixture' '### TD-SG4-LOW — Low runtime finding'
  printf '%s\n' '- Owner: product-security-owner' '- Source sprint: 1' '- Target sprint: 3' \
    "- Дедлайн устранения: $low_deadline" '- Exception type: security' \
    '- Finding severity: SECURITY_LOW' '- Finding IDs: SG4-LOW' '- CVSS: 2.5' \
    '- Risk exception: none' '- Статус: OPEN'
} > "$P_SECURITY_LOW/tracking/tech-debt.md"
sed -i $'s/\tTECH_DEBT\tnone\tnone\tnone$/\tTECH_DEBT\tnone\tTD-SG4-LOW\tnone/' \
  "$P_SECURITY_LOW/stage5-testing/outputs/DEF-defects-v1.tsv"
refresh_s5_bindings "$P_SECURITY_LOW"
bash "$CHECK" "$P_SECURITY_LOW" "$SOURCE" >/dev/null ||
  fail 'valid SG4 Low lifecycle was rejected'

P_SECURITY_MEDIUM="$TMP_DIR/security-medium-valid"
write_valid_project "$P_SECURITY_MEDIUM" service
printf '{"schema_version":1,"stream_id":"security","source_revision":"%s","subject_digest":"%s","build_identity":"build-001","environment_id":"qa-env-1","verdict":"CONDITIONAL_PASS","scenarios_total":2,"scenarios_evaluated":2,"scenario_results":[{"scenario_id":"SEC-SCENARIO-SG1-001","test_id":"TEST-SEC-SG1-001","result":"PASS"},{"scenario_id":"SEC-SCENARIO-SG2-001","test_id":"TEST-SEC-SG2-001","result":"FAIL"}],"findings":[{"id":"SG4-MEDIUM","cvss":5.5,"status":"open"}]}\n' \
  "$SOURCE" "$DIGEST" > "$P_SECURITY_MEDIUM/tracking/validation/raw/security.json"
mkdir -p "$P_SECURITY_MEDIUM/tracking/risk-exceptions"
sed -i -e $'/^security\t/s/\tPASS\t/\tCONDITIONAL_PASS\t/' \
  -e $'/^security\t/s/\tnone\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\tnone$/\tSG4-MEDIUM\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\ttracking\/risk-exceptions\/RISK-SG4-MEDIUM.yaml/' \
  "$P_SECURITY_MEDIUM/tracking/validation/S5-validation-v1.tsv"
printf '%s\n' $'DEF-SG4-MEDIUM\tsecurity\tSG4-MEDIUM\tCVSS-MEDIUM\tno\tTECH_DEBT\tnone\tTD-SG4-MEDIUM\tnone' >> \
  "$P_SECURITY_MEDIUM/stage5-testing/outputs/DEF-defects-v1.tsv"
medium_deadline="$(date -u -d '+30 days' +%Y-%m-%d)"
medium_sprint_end="$(date -u -d '+35 days' +%Y-%m-%d)"
write_sprint_boundaries "$P_SECURITY_MEDIUM" 2 "$medium_sprint_end"
{
  printf '%s\n' '# Tech Debt Log — fixture' '### TD-SG4-MEDIUM — Medium runtime finding'
  printf '%s\n' '- Owner: product-security-owner' \
    '- План устранения: исправить finding и повторить affected validation' \
    '- Source sprint: 1' '- Target sprint: 2' \
    "- Дедлайн устранения: $medium_deadline" '- Exception type: security' \
    '- Finding severity: SECURITY_MEDIUM' '- Finding IDs: SG4-MEDIUM' '- CVSS: 5.5' \
    '- Risk exception: RISK-SG4-MEDIUM' '- Статус: OPEN'
} > "$P_SECURITY_MEDIUM/tracking/tech-debt.md"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
expires_at="$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)"
{
  printf '%s\n' 'schema_version: 3' 'exception_id: RISK-SG4-MEDIUM' \
    'exception_type: security' 'finding_severity: SECURITY_MEDIUM' \
    'tech_debt_id: TD-SG4-MEDIUM' 'known_issue_id: none' \
    'owner: product-security-owner' 'approved_by: s4-techlead' \
    'rationale: bounded runtime remediation accepted for this source' \
    'scope: s5-security SG4-MEDIUM only' 'check_id: s5-security' \
    'finding_ids: SG4-MEDIUM' "source_revision: $SOURCE" "subject_digest: $DIGEST" \
    "created_at: $created_at" "expires_at: $expires_at" 'status: ACTIVE'
} > "$P_SECURITY_MEDIUM/tracking/risk-exceptions/RISK-SG4-MEDIUM.yaml"
refresh_s5_bindings "$P_SECURITY_MEDIUM"
bash "$CHECK" "$P_SECURITY_MEDIUM" "$SOURCE" >/dev/null ||
  fail 'valid SG4 Medium Risk Exception lifecycle was rejected'

P_SECURITY_MEDIUM_USER="$TMP_DIR/security-medium-user-facing"
cp -a "$P_SECURITY_MEDIUM" "$P_SECURITY_MEDIUM_USER"
rebind_fixture_project "$P_SECURITY_MEDIUM_USER" security-medium-valid
write_known_issue_record "$P_SECURITY_MEDIUM_USER" KI-SG4-MEDIUM CVSS-MEDIUM \
  TD-SG4-MEDIUM tracking/approvals/APPROVAL-KI-SG4-MEDIUM.yaml
sed -i 's/known_issue_id: none/known_issue_id: KI-SG4-MEDIUM/' \
  "$P_SECURITY_MEDIUM_USER/tracking/risk-exceptions/RISK-SG4-MEDIUM.yaml"
sed -i $'s/\tno\tTECH_DEBT\tnone\tTD-SG4-MEDIUM\tnone$/\tyes\tKNOWN_ISSUE\tKI-SG4-MEDIUM\tTD-SG4-MEDIUM\tnone/' \
  "$P_SECURITY_MEDIUM_USER/stage5-testing/outputs/DEF-defects-v1.tsv"
refresh_s5_bindings "$P_SECURITY_MEDIUM_USER"
expect_blocked 'user-facing Medium accepted without separate Known Issue Human Approval' \
  "$P_SECURITY_MEDIUM_USER" "$TMP_DIR/security-medium-user.out"
grep -Fq 'Known Issue approval missing' "$TMP_DIR/security-medium-user.out" ||
  fail 'user-facing Medium did not fail at missing Known Issue approval'

P_SECURITY_MEDIUM_APPROVED="$TMP_DIR/security-medium-approved"
cp -a "$P_SECURITY_MEDIUM_USER" "$P_SECURITY_MEDIUM_APPROVED"
rebind_fixture_project "$P_SECURITY_MEDIUM_APPROVED" security-medium-user-facing
ki_approval_ref="$(write_known_issue_approval "$P_SECURITY_MEDIUM_APPROVED" \
  DEF-SG4-MEDIUM security SG4-MEDIUM CVSS-MEDIUM KI-SG4-MEDIUM TD-SG4-MEDIUM \
  APPROVAL-KI-SG4-MEDIUM)"
sed -i $'s|\tnone$|\t'"$ki_approval_ref"'|' \
  "$P_SECURITY_MEDIUM_APPROVED/stage5-testing/outputs/DEF-defects-v1.tsv"
refresh_s5_bindings "$P_SECURITY_MEDIUM_APPROVED"
bash "$CHECK" "$P_SECURITY_MEDIUM_APPROVED" "$SOURCE" >/dev/null ||
  fail 'valid separately approved user-facing Security Medium Known Issue was rejected'

P_SECURITY_MEDIUM_WRONG_DIGEST="$TMP_DIR/security-medium-wrong-defect-digest"
cp -a "$P_SECURITY_MEDIUM_APPROVED" "$P_SECURITY_MEDIUM_WRONG_DIGEST"
rebind_fixture_project "$P_SECURITY_MEDIUM_WRONG_DIGEST" security-medium-approved
refresh_s5_bindings "$P_SECURITY_MEDIUM_WRONG_DIGEST"
sed -i 's/^subject_digest:.*/subject_digest: sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/' \
  "$P_SECURITY_MEDIUM_WRONG_DIGEST/tracking/approvals/APPROVAL-KI-SG4-MEDIUM.yaml"
expect_blocked 'Known Issue approval bound to the wrong defect digest was accepted' \
  "$P_SECURITY_MEDIUM_WRONG_DIGEST" "$TMP_DIR/security-medium-wrong-digest.out"
grep -Fq 'wrong subject digest' "$TMP_DIR/security-medium-wrong-digest.out" ||
  fail 'Known Issue approval did not fail at exact defect digest binding'

P_PERFORMANCE_EXCEPTION="$TMP_DIR/performance-exception-valid"
write_valid_project "$P_PERFORMANCE_EXCEPTION" service
printf '{"schema_version":1,"stream_id":"performance","source_revision":"%s","subject_digest":"%s","build_identity":"build-001","environment_id":"qa-env-1","verdict":"CONDITIONAL_PASS","metrics_total":1,"metrics_evaluated":1,"metrics_failed":1,"quality_metrics":[{"metric_id":"response_time_p95_ms","operator":"<=","threshold":500,"observed":600,"unit":"ms","verdict":"FAIL","policy_revision":"quality-global-v1"}],"findings":[{"id":"PERF-P95"}]}\n' \
  "$SOURCE" "$DIGEST" > "$P_PERFORMANCE_EXCEPTION/tracking/validation/raw/performance.json"
perf_old_sha="$(awk -F'\t' '$1=="performance" {print $11}' "$P_PERFORMANCE_EXCEPTION/tracking/validation/S5-validation-v1.tsv")"
perf_new_sha="$(sha256sum "$P_PERFORMANCE_EXCEPTION/tracking/validation/raw/performance.json" | awk '{print $1}')"
sed -i -e "s/$perf_old_sha/$perf_new_sha/" \
  -e $'/^performance\t/s/\tPASS\t/\tCONDITIONAL_PASS\t/' \
  -e $'/^performance\t/s/\tnone\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\tnone$/\tPERF-P95\ttracking\/approvals\/APPROVAL-ENV-QA.yaml\tnone\ttracking\/risk-exceptions\/RISK-PERF-P95.yaml/' \
  "$P_PERFORMANCE_EXCEPTION/tracking/validation/S5-validation-v1.tsv"
printf '%s\n' $'DEF-PERF-P95\tperformance\tPERF-P95\tS3\tno\tTECH_DEBT\tnone\tTD-PERF-P95\tnone' >> \
  "$P_PERFORMANCE_EXCEPTION/stage5-testing/outputs/DEF-defects-v1.tsv"
mkdir -p "$P_PERFORMANCE_EXCEPTION/tracking/risk-exceptions"
write_sprint_boundaries "$P_PERFORMANCE_EXCEPTION" 2 "$medium_sprint_end"
{
  printf '%s\n' '# Tech Debt Log — fixture' '### TD-PERF-P95 — Performance threshold'
  printf '%s\n' '- Owner: performance-owner' '- Source sprint: 1' '- Target sprint: 2' \
    "- Дедлайн устранения: $medium_deadline" '- Exception type: performance' \
    '- Finding severity: PERFORMANCE_THRESHOLD' '- Finding IDs: PERF-P95' '- CVSS: N/A' \
    '- Risk exception: RISK-PERF-P95' '- Статус: OPEN'
} > "$P_PERFORMANCE_EXCEPTION/tracking/tech-debt.md"
{
  printf '%s\n' 'schema_version: 3' 'exception_id: RISK-PERF-P95' \
    'exception_type: performance' 'finding_severity: PERFORMANCE_THRESHOLD' \
    'tech_debt_id: TD-PERF-P95' 'known_issue_id: none' 'owner: performance-owner' \
    'approved_by: s4-techlead' 'rationale: bounded performance remediation accepted for this source' \
    'scope: s5-performance PERF-P95 only' 'check_id: s5-performance' 'finding_ids: PERF-P95' \
    "source_revision: $SOURCE" "subject_digest: $DIGEST" "created_at: $created_at" \
    "expires_at: $expires_at" 'status: ACTIVE'
} > "$P_PERFORMANCE_EXCEPTION/tracking/risk-exceptions/RISK-PERF-P95.yaml"
index_sha="$(sha256sum "$P_PERFORMANCE_EXCEPTION/tracking/validation/S5-validation-v1.tsv" | awk '{print $1}')"
defects_sha="$(sha256sum "$P_PERFORMANCE_EXCEPTION/stage5-testing/outputs/DEF-defects-v1.tsv" | awk '{print $1}')"
sed -i -e "s/^validation_index_sha256:.*/validation_index_sha256: $index_sha/" \
  -e "s/^defect_index_sha256:.*/defect_index_sha256: $defects_sha/" \
  "$P_PERFORMANCE_EXCEPTION/stage5-testing/outputs/QA-2026-07-27-go-no-go.md"
bash "$CHECK" "$P_PERFORMANCE_EXCEPTION" "$SOURCE" >/dev/null ||
  fail 'valid typed performance Risk Exception was rejected'

P_PERFORMANCE_LATE="$TMP_DIR/performance-exception-late"
cp -a "$P_PERFORMANCE_EXCEPTION" "$P_PERFORMANCE_LATE"
rebind_fixture_project "$P_PERFORMANCE_LATE" performance-exception-valid
sed -i 's/Target sprint: 2/Target sprint: 3/' "$P_PERFORMANCE_LATE/tracking/tech-debt.md"
mv "$P_PERFORMANCE_LATE/tracking/sprints/sprint-02.md" \
  "$P_PERFORMANCE_LATE/tracking/sprints/sprint-03.md"
sed -i 's/sprint: 2/sprint: 3/' "$P_PERFORMANCE_LATE/tracking/sprints/sprint-03.md"
refresh_s5_bindings "$P_PERFORMANCE_LATE"
expect_blocked 'typed performance exception beyond next sprint was accepted' \
  "$P_PERFORMANCE_LATE" "$TMP_DIR/performance-late.out"
grep -Fq 'в пределах 1 sprint' "$TMP_DIR/performance-late.out" ||
  fail "performance exception did not fail at common next-sprint SLA: $(tr '\n' ' ' < "$TMP_DIR/performance-late.out")"

P_DEFECT="$TMP_DIR/parallel-defects"
write_valid_project "$P_DEFECT" service
cp "$P_DEFECT/stage5-testing/outputs/DEF-2026-07-27-defects.md" \
  "$P_DEFECT/stage5-testing/outputs/DEF-2026-07-27-defects-copy.md"
expect_blocked 'parallel defect registers were accepted' "$P_DEFECT" "$TMP_DIR/defect.out"

P_METADATA="$TMP_DIR/missing-artifact-metadata"
write_valid_project "$P_METADATA" service
sed -i '/^producer:/d' "$P_METADATA/stage5-testing/outputs/AUTO-2026-07-27-e2e-report.md"
expect_blocked 'S5 report without shared producer metadata was accepted' "$P_METADATA" "$TMP_DIR/metadata.out"

for role in cycle1-dev/s5-qa-auto/CLAUDE.md cycle1-dev/s5-perf/CLAUDE.md \
  cycle1-dev/s5-security/CLAUDE.md cycle1-dev/s5-qa/CLAUDE.md; do
  grep -Fq 'S5-validation-v1.tsv' "$ROOT/$role" || fail "$role does not consume/produce S5 index"
done

s5_dag="$(XDG_CONFIG_HOME="$TMP_DIR/config" bash -c '
  source "$1"
  for step in "${CYCLE1_AGENTS[@]}"; do
    if [[ "$step" == s5-* ]]; then printf "%s " "$step"; fi
  done
' _ "$ROOT/sdlc.sh")"
[[ "$s5_dag" == 's5-qa:/test-plan s5-qa-auto:/e2e-report s5-perf:/load-test s5-security:/security-test s5-qa:/go-no-go ' ]] ||
  fail "S5 DAG order/owners changed: $s5_dag"
XDG_CONFIG_HOME="$TMP_DIR/config" bash -c '
  source "$1"
  [[ "$(cycle1_gate_after_entry s5-qa /go-no-go)" == 5 ]]
  cycle1_declared_output_groups s5-qa-auto /e2e-report | grep -Fq tracking/validation/raw/automation.json
  cycle1_declared_output_groups s5-perf /load-test | grep -Fq tracking/validation/raw/performance.json
  cycle1_declared_output_groups s5-security /security-test | grep -Fq tracking/validation/raw/security.json
  cycle1_declared_output_groups s5-qa /go-no-go | grep -Fq stage5-testing/outputs/DEF-defects-v1.tsv
' _ "$ROOT/sdlc.sh" || fail 'launcher does not enforce the S5 native output DAG'
grep -Fq 's5-validation-check.sh' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" ||
  fail 'Gate 5 does not invoke the S5 machine validator'
if sed -n '/  5)/,/    ;;/p' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" | grep -Fq 'check_status_pass'; then
  fail 'Gate 5 still accepts plain Markdown status'
fi

if [[ -n "${S5_FIXTURE_EXPORT_DIR:-}" ]]; then
  export_source="$P_SERVICE"
  case "${S5_FIXTURE_EXPORT_VARIANT:-service}" in
    service) ;;
    performance-exception) export_source="$P_PERFORMANCE_EXCEPTION" ;;
    *) fail "unknown S5_FIXTURE_EXPORT_VARIANT=${S5_FIXTURE_EXPORT_VARIANT}" ;;
  esac
  mkdir -p "$S5_FIXTURE_EXPORT_DIR"
  cp -a "$export_source/." "$S5_FIXTURE_EXPORT_DIR/"
  export_old_name="$(basename "$export_source")"
  if [[ "$export_old_name" != "$(basename "$S5_FIXTURE_EXPORT_DIR")" ]]; then
    rebind_fixture_project "$S5_FIXTURE_EXPORT_DIR" "$export_old_name"
    refresh_s5_bindings "$S5_FIXTURE_EXPORT_DIR"
  fi
fi

echo 'PASS: S5 Validation v1 smoke'

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-quality-characteristics.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECK="$ROOT/cycle1-dev/s0-quality-gates/quality-characteristics-check.sh"
PROFILE_CHECK="$ROOT/cycle1-dev/s0-validate/product-ci-profile-check.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile_v5() {
  local project="$1" interface="$2" ux="$3" performance="$4" compatibility="$5"
  local accessibility="$6" flexibility="$7" safety="$8" offline="${9:-online}"
  local product_type="${10:-service}"
  local evidence_profile=repository-ci merge=required environment=connected-representative
  local environment_id=qa-service environment_auth=required ci_provider=github-actions
  if [[ "$offline" != online ]]; then
    evidence_profile=local-offline
    merge=not-applicable
    environment=local-representative
    environment_id=local-qa
    ci_provider=local-validator
  fi
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' \
      'schema_version: 5' \
      'revision: 1' \
      'previous_revision: 0' \
      'updated_at: 2026-07-27T12:00:00Z' \
      'revision_reason: confirmed quality applicability'
    for pair in \
      "product_type=$product_type" \
      'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' \
      'scm_review_policy=required-review' \
      'scm_required_checks=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom' \
      "ci_provider=$ci_provider" \
      'ci_runners=trusted-linux' \
      'ci_trust_boundary=protected-ci' \
      'ci_report_formats=junit,sarif' \
      'build_toolchain=native-project-toolchain' \
      'build_command=make verify' \
      'package_command=not-applicable' \
      'build_output_contract=not-applicable' \
      'secret_provider=pass' \
      'ci_identity_references=quality-executor' \
      'compliance_constraints=confirmed-project-constraints' \
      "offline_mode=$offline" \
      'approval_constraints=required-review' \
      'quality_overrides=none' \
      "evidence_source_profile=$evidence_profile" \
      'evidence_repository_path=.' \
      'evidence_executor_identity=quality-executor' \
      'evidence_trusted_producers=quality-executor' \
      'evidence_freshness_seconds=86400' \
      'evidence_signature_policy=not-supported' \
      "evidence_merge_blocking=$merge" \
      'build_subject=source-only' \
      'sbom_requirement=not-applicable' \
      "user_interface=$interface" \
      "ux_brief_requirement=$ux" \
      "validation_environment_profile=$environment" \
      "validation_environment_identity=$environment_id" \
      "validation_environment_authorization=$environment_auth" \
      "performance_validation=$performance" \
      'runtime_security_validation=required' \
      "compatibility_validation=$compatibility" \
      "accessibility_validation=$accessibility" \
      "flexibility_validation=$flexibility" \
      "safety_validation=$safety"; do
      key="${pair%%=*}"
      value="${pair#*=}"
      printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_quality_artifacts() {
  local project="$1" performance="$2" compatibility="$3" ux="$4" accessibility="$5"
  local flexibility="$6" safety="$7" project_name
  project_name="$(basename "$project")"
  mkdir -p "$project/tracking"
  printf '%s\n' '# Dashboard' > "$project/Dashboard.md"
  printf '%s\n' '# PMO Constraints' 'cycle1.criticality_tier: 2' > "$project/tracking/PMO-constraints.md"

  app() { [[ "$1" == required ]] && printf REQUIRED || printf NOT_APPLICABLE; }
  {
    printf '%s\n' $'characteristic_id\tapplicability\towner\tevidence_type\tevidence_contract\tgate\tprofile_field\tprofile_value\tminimum_policy\trationale_ref'
    printf '%s\n' \
      $'functional-suitability\tREQUIRED\ts2-po+s5-qa\thybrid\tPRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1\tGATE2+GATE5\talways-required\talways-required\tGLOBAL_MINIMUM_OR_STRICTER\ttracking/quality-characteristics.md' \
      "performance-efficiency$(printf '\t')$(app "$performance")$(printf '\t')s2-test-strategy+s3-arch+s5-perf$(printf '\t')hybrid$(printf '\t')QUALITY_POLICY_V1+ARCHITECTURE_DECISION_TRACE_V1+S5_VALIDATION_V1$(printf '\t')GATE2+GATE3+GATE5$(printf '\t')performance_validation$(printf '\t')$performance$(printf '\t')GLOBAL_MINIMUM_OR_STRICTER$(printf '\t')tracking/quality-characteristics.md" \
      "compatibility$(printf '\t')$(app "$compatibility")$(printf '\t')s3-arch+s4-qa-auto+s4-techlead$(printf '\t')hybrid$(printf '\t')ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1$(printf '\t')GATE3+GATE4$(printf '\t')compatibility_validation$(printf '\t')$compatibility$(printf '\t')GLOBAL_MINIMUM_OR_STRICTER$(printf '\t')tracking/quality-characteristics.md" \
      "interaction-capability$(printf '\t')$(app "$ux")$(printf '\t')s2-po+s5-qa$(printf '\t')hybrid$(printf '\t')PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1$(printf '\t')GATE2+GATE5$(printf '\t')ux_brief_requirement$(printf '\t')$ux$(printf '\t')GLOBAL_MINIMUM_OR_STRICTER$(printf '\t')tracking/quality-characteristics.md" \
      "accessibility$(printf '\t')$(app "$accessibility")$(printf '\t')s2-po+s2-qa-req+s5-qa$(printf '\t')hybrid$(printf '\t')PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1$(printf '\t')GATE2+GATE5$(printf '\t')accessibility_validation$(printf '\t')$accessibility$(printf '\t')GLOBAL_MINIMUM_OR_STRICTER$(printf '\t')tracking/quality-characteristics.md" \
      $'reliability\tREQUIRED\ts2-ba+s3-arch\thybrid\tARCHITECTURE_DECISION_TRACE_V1\tGATE2+GATE3\talways-required\talways-required\tGLOBAL_MINIMUM_OR_STRICTER\ttracking/quality-characteristics.md' \
      $'security\tREQUIRED\ts2-security+s3-security+s4-techlead+s5-security\thybrid\tSECURITY_SG1_SG4\tGATE2+GATE3+GATE4+GATE5\talways-required\talways-required\tGLOBAL_MINIMUM_OR_STRICTER\ttracking/quality-characteristics.md' \
      $'maintainability\tREQUIRED\ts3-arch+s4-techlead\thybrid\tARCHITECTURE_DECISION_TRACE_V1+TECH_LEAD_REVIEW\tGATE3+GATE4\talways-required\talways-required\tGLOBAL_MINIMUM_OR_STRICTER\ttracking/quality-characteristics.md' \
      "flexibility-installability$(printf '\t')$(app "$flexibility")$(printf '\t')s3-arch+s4-qa-auto$(printf '\t')hybrid$(printf '\t')ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1$(printf '\t')GATE3+GATE4$(printf '\t')flexibility_validation$(printf '\t')$flexibility$(printf '\t')GLOBAL_MINIMUM_OR_STRICTER$(printf '\t')tracking/quality-characteristics.md" \
      "safety$(printf '\t')$(app "$safety")$(printf '\t')s1-pmo+s2-ba+s3-arch$(printf '\t')hybrid$(printf '\t')PMO_CONSTRAINTS+ARCHITECTURE_DECISION_TRACE_V1$(printf '\t')GATE1+GATE3$(printf '\t')safety_validation$(printf '\t')$safety$(printf '\t')GLOBAL_MINIMUM_OR_STRICTER$(printf '\t')tracking/quality-characteristics.md" \
      $'quality-in-use\tREQUIRED\ts2-po+s5-qa\thybrid\tPRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1\tGATE2+GATE5\talways-required\talways-required\tGLOBAL_MINIMUM_OR_STRICTER\ttracking/quality-characteristics.md'
  } > "$project/tracking/quality-characteristics-v1.tsv"

  {
    printf '%s\n' \
      '---' \
      'schema_version: 1' \
      'artifact_id: QUALITY-CHARACTERISTICS-V1' \
      'artifact_type: quality-characteristics-view' \
      "project: $project_name" \
      'stage: TRACKING' \
      'producer: s0-quality-gates' \
      'source_revision: none' \
      'status: VALIDATED' \
      'inputs: tracking/product-ci-profile.yaml,tracking/PMO-constraints.md,tracking/quality-characteristics-v1.tsv' \
      'outputs: tracking/quality-characteristics.md' \
      'tags: sdlc,cycle1,tracking,quality' \
      'quality_schema_version: 1' \
      'product_profile_revision: 1' \
      'applicability_index: tracking/quality-characteristics-v1.tsv' \
      'minimum_policy: GLOBAL_MINIMUM_OR_STRICTER' \
      '---' \
      "# Quality Characteristics — $project_name" \
      '' \
      'SG1-SG4 active; SG5 FROZEN / NOT SUPPORTED.' \
      'Cycle 2/3 FROZEN / NOT REQUIRED.'
    while IFS=$'\t' read -r id applicability owner evidence_type evidence_contract gate profile_field profile_value minimum_policy rationale_ref; do
      [[ "$id" == characteristic_id ]] && continue
      printf '\n## %s\n\n' "$id"
      printf '%s\n' \
        "- Applicability: $applicability" \
        "- Owner: $owner" \
        "- Evidence type: $evidence_type" \
        "- Evidence contract: $evidence_contract" \
        "- Gate: $gate" \
        "- Profile field: $profile_field" \
        "- Profile value: $profile_value" \
        "- Minimum policy: $minimum_policy" \
        "- Rationale ($id): confirmed profile applicability is bound to the listed existing Cycle 1 evidence and gate."
    done < "$project/tracking/quality-characteristics-v1.tsv"
    printf '%s\n' '' '## Obsidian Links' '' \
      '- [[Dashboard]]' \
      '- [[tracking/PMO-constraints]]' \
      '- [[tracking/quality-characteristics]]'
  } > "$project/tracking/quality-characteristics.md"
}

clone_project() {
  local source="$1" target="$2"
  cp -a "$source" "$target"
  sed -i "s/^project: .*/project: $(basename "$target")/" "$target/tracking/quality-characteristics.md"
}

P_REQUIRED="$TMP_DIR/service-required"
write_profile_v5 "$P_REQUIRED" graphical required required required required required not-applicable
write_quality_artifacts "$P_REQUIRED" required required required required required not-applicable
bash "$PROFILE_CHECK" "$P_REQUIRED" >/dev/null || fail 'valid schema v5 profile was rejected'
bash "$CHECK" "$P_REQUIRED" >/dev/null || fail 'valid required-characteristics index was rejected'

P_NA="$TMP_DIR/offline-library"
write_profile_v5 "$P_NA" library-only not-applicable not-applicable not-applicable not-applicable not-applicable not-applicable air-gapped library
write_quality_artifacts "$P_NA" not-applicable not-applicable not-applicable not-applicable not-applicable not-applicable
bash "$CHECK" "$P_NA" >/dev/null || fail 'valid profile-confirmed N/A index was rejected'

P_CLI="$TMP_DIR/cli-terminal"
write_profile_v5 "$P_CLI" terminal required required required required required not-applicable online cli
write_quality_artifacts "$P_CLI" required required required required required not-applicable
bash "$PROFILE_CHECK" "$P_CLI" >/dev/null || fail 'valid CLI schema v5 profile was rejected'
bash "$CHECK" "$P_CLI" >/dev/null || fail 'valid CLI quality-characteristics index was rejected'

P_MISSING="$TMP_DIR/missing-characteristic"
clone_project "$P_REQUIRED" "$P_MISSING"
sed -i '/^quality-in-use/d' "$P_MISSING/tracking/quality-characteristics-v1.tsv"
if bash "$CHECK" "$P_MISSING" >/dev/null 2>&1; then fail 'missing characteristic was accepted'; fi

P_CONTRADICT="$TMP_DIR/contradict-profile"
clone_project "$P_REQUIRED" "$P_CONTRADICT"
sed -i 's/^compatibility\tREQUIRED/compatibility\tNOT_APPLICABLE/' "$P_CONTRADICT/tracking/quality-characteristics-v1.tsv"
if bash "$CHECK" "$P_CONTRADICT" >/dev/null 2>&1; then fail 'N/A contrary to Product Profile was accepted'; fi

P_RATIONALE="$TMP_DIR/missing-rationale"
clone_project "$P_REQUIRED" "$P_RATIONALE"
sed -i '/^- Rationale (accessibility):/d' "$P_RATIONALE/tracking/quality-characteristics.md"
if bash "$CHECK" "$P_RATIONALE" >/dev/null 2>&1; then fail 'missing rationale was accepted'; fi

P_WEAK="$TMP_DIR/weak-minimum"
clone_project "$P_REQUIRED" "$P_WEAK"
sed -i '0,/GLOBAL_MINIMUM_OR_STRICTER/s//BELOW_GLOBAL_ALLOWED/' "$P_WEAK/tracking/quality-characteristics-v1.tsv"
if bash "$CHECK" "$P_WEAK" >/dev/null 2>&1; then fail 'weakened global minimum was accepted'; fi

P_STALE="$TMP_DIR/stale-profile"
clone_project "$P_REQUIRED" "$P_STALE"
sed -i 's/^product_profile_revision: 1/product_profile_revision: 2/' "$P_STALE/tracking/quality-characteristics.md"
if bash "$CHECK" "$P_STALE" >/dev/null 2>&1; then fail 'stale profile revision was accepted'; fi

P_BAD_A11Y="$TMP_DIR/bad-accessibility"
write_profile_v5 "$P_BAD_A11Y" library-only not-applicable not-applicable not-applicable required not-applicable not-applicable
if bash "$PROFILE_CHECK" "$P_BAD_A11Y" >/dev/null 2>&1; then fail 'required accessibility with non-UI profile was accepted'; fi

echo 'PASS: Quality Characteristics v1 smoke'

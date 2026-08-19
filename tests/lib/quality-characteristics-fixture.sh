#!/usr/bin/env bash

write_quality_characteristics_fixture() {
  local project="$1" profile="$1/tracking/product-ci-profile.yaml" project_name revision
  local record id profile_field owner evidence_type evidence_contract gate profile_value applicability
  local index="$1/tracking/quality-characteristics-v1.tsv"
  local view="$1/tracking/quality-characteristics.md"
  project_name="$(basename "$project")"
  revision="$(awk -F: '$1 == "revision" { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }' "$profile")"
  mkdir -p "$project/tracking"
  [[ -f "$project/Dashboard.md" ]] || printf '%s\n' '# Dashboard' > "$project/Dashboard.md"
  [[ -f "$project/tracking/PMO-constraints.md" ]] ||
    printf '%s\n' '# PMO Constraints' 'cycle1.criticality_tier: 2' > "$project/tracking/PMO-constraints.md"

  local -a records=(
    'functional-suitability|always-required|s2-po+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
    'performance-efficiency|performance_validation|s2-test-strategy+s3-arch+s5-perf|hybrid|QUALITY_POLICY_V1+ARCHITECTURE_DECISION_TRACE_V1+S5_VALIDATION_V1|GATE2+GATE3+GATE5'
    'compatibility|compatibility_validation|s3-arch+s4-qa-auto+s4-techlead|hybrid|ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1|GATE3+GATE4'
    'interaction-capability|ux_brief_requirement|s2-po+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
    'accessibility|accessibility_validation|s2-po+s2-qa-req+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
    'reliability|always-required|s2-ba+s3-arch|hybrid|ARCHITECTURE_DECISION_TRACE_V1|GATE2+GATE3'
    'security|always-required|s2-security+s3-security+s4-techlead+s5-security|hybrid|SECURITY_SG1_SG4|GATE2+GATE3+GATE4+GATE5'
    'maintainability|always-required|s3-arch+s4-techlead|hybrid|ARCHITECTURE_DECISION_TRACE_V1+TECH_LEAD_REVIEW|GATE3+GATE4'
    'flexibility-installability|flexibility_validation|s3-arch+s4-qa-auto|hybrid|ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1|GATE3+GATE4'
    'safety|safety_validation|s1-pmo+s2-ba+s3-arch|hybrid|PMO_CONSTRAINTS+ARCHITECTURE_DECISION_TRACE_V1|GATE1+GATE3'
    'quality-in-use|always-required|s2-po+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
  )
  printf '%s\n' $'characteristic_id\tapplicability\towner\tevidence_type\tevidence_contract\tgate\tprofile_field\tprofile_value\tminimum_policy\trationale_ref' > "$index"
  for record in "${records[@]}"; do
    IFS='|' read -r id profile_field owner evidence_type evidence_contract gate <<< "$record"
    if [[ "$profile_field" == always-required ]]; then
      profile_value=always-required; applicability=REQUIRED
    else
      profile_value="$(awk -F: -v key="$profile_field" '$1 == key { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }' "$profile")"
      [[ "$profile_value" == required ]] && applicability=REQUIRED || applicability=NOT_APPLICABLE
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tGLOBAL_MINIMUM_OR_STRICTER\ttracking/quality-characteristics.md\n' \
      "$id" "$applicability" "$owner" "$evidence_type" "$evidence_contract" "$gate" "$profile_field" "$profile_value" >> "$index"
  done

  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_id: QUALITY-CHARACTERISTICS-V1' \
      'artifact_type: quality-characteristics-view' "project: $project_name" 'stage: TRACKING' \
      'producer: s0-quality-gates' 'source_revision: none' 'status: VALIDATED' \
      'inputs: tracking/product-ci-profile.yaml,tracking/PMO-constraints.md,tracking/quality-characteristics-v1.tsv' \
      'outputs: tracking/quality-characteristics.md' 'tags: sdlc,cycle1,tracking,quality' \
      'quality_schema_version: 1' "product_profile_revision: $revision" \
      'applicability_index: tracking/quality-characteristics-v1.tsv' \
      'minimum_policy: GLOBAL_MINIMUM_OR_STRICTER' '---' \
      "# Quality Characteristics — $project_name" '' \
      'SG1-SG4 active; SG5 FROZEN / NOT SUPPORTED.' \
      'Cycle 2/3 FROZEN / NOT REQUIRED.'
    while IFS=$'\t' read -r id applicability owner evidence_type evidence_contract gate profile_field profile_value minimum_policy _; do
      [[ "$id" == characteristic_id ]] && continue
      printf '\n## %s\n\n' "$id"
      printf '%s\n' "- Applicability: $applicability" "- Owner: $owner" \
        "- Evidence type: $evidence_type" "- Evidence contract: $evidence_contract" \
        "- Gate: $gate" "- Profile field: $profile_field" "- Profile value: $profile_value" \
        "- Minimum policy: $minimum_policy" \
        "- Rationale ($id): confirmed applicability is bound to the listed Cycle 1 evidence and gate."
    done < "$index"
    printf '%s\n' '' '## Obsidian Links' '' '- [[Dashboard]]' \
      '- [[tracking/PMO-constraints]]' '- [[tracking/quality-characteristics]]'
  } > "$view"
}

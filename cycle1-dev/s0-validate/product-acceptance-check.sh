#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
blocked() { echo "PRODUCT ACCEPTANCE BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
OUTPUTS="$PROJECT_PATH/stage2-requirements/outputs"
APPLICABILITY_RESOLVER="$SCRIPT_DIR/applicability-resolve.sh"
CURRENT_ARTIFACT_TOOL="$SCRIPT_DIR/current-artifact.sh"

bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Product & CI Profile не прошёл deterministic validation'
[[ -d "$OUTPUTS" ]] || blocked 'stage2-requirements/outputs отсутствует'

yaml_field() {
  local file="$1" wanted="$2"
  awk -v wanted="$wanted" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    {
      key=$0; sub(/:.*/, "", key)
      if (key == wanted) {
        value=$0; sub(/^[^:]*:[[:space:]]*/, "", value)
        print value; exit
      }
    }
  ' "$file"
}

profile_field() {
  local wanted="$1"
  awk -v wanted="$wanted" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      key=$0; sub(/:.*/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key == wanted) {
        value=$0; sub(/^[^:]*:[[:space:]]*/, "", value)
        gsub(/[[:space:]]+$/, "", value); print value; exit
      }
    }
  ' "$PROFILE"
}

resolved_profile_value() {
  local capability="$1" expected_field="$2" output resolved_capability applicability
  local profile_field profile_value revision owner reason extra
  output="$(bash "$APPLICABILITY_RESOLVER" resolve "$PROJECT_PATH" "$capability")" ||
    blocked "applicability resolution failed: $capability"
  IFS=$'\t' read -r resolved_capability applicability profile_field profile_value \
    revision owner reason extra <<< "$output"
  [[ -z "$extra" && "$resolved_capability" == "$capability" && "$profile_field" == "$expected_field" ]] ||
    blocked "invalid applicability resolver output: $capability"
  printf '%s\n' "$profile_value"
}

require_measured_ids() {
  local file="$1" prefix="$2" id
  local -a measured_ids=()
  mapfile -t measured_ids < <(grep -oE "${prefix}-[A-Za-z0-9._-]+" "$file" | sort -u)
  (( ${#measured_ids[@]} > 0 )) || blocked "$(basename "$file"): $prefix ids отсутствуют"
  for id in "${measured_ids[@]}"; do
    grep -Eq "${id}.*Measure:[[:space:]]*[^[:space:]].*" "$file" ||
      blocked "$(basename "$file"): $id не содержит measurable Measure: target"
  done
}

expect_meta() {
  local file="$1" key="$2" expected="$3" actual
  actual="$(yaml_field "$file" "$key")"
  [[ "$actual" == "$expected" ]] ||
    blocked "$(basename "$file"): $key должен быть $expected, получено ${actual:-MISSING}"
}

current_one() {
  local logical_id="$1" ref
  ref="$(bash "$CURRENT_ARTIFACT_TOOL" resolve-compatible-one "$PROJECT_PATH" "$logical_id")" ||
    blocked "$logical_id current resolution failed"
  printf '%s\n' "$PROJECT_PATH/$ref"
}

profile_schema="$(profile_field schema_version)"
profile_revision="$(profile_field revision)"
user_interface="$(profile_field user_interface)"
ux_requirement="$(resolved_profile_value interaction ux_brief_requirement)"
accessibility_requirement='legacy-unverified'
if [[ "$profile_schema" == 5 ]]; then
  accessibility_requirement="$(resolved_profile_value accessibility accessibility_validation)"
fi
[[ "$profile_schema" == 3 || "$profile_schema" == 4 || "$profile_schema" == 5 ]] ||
  blocked 'Stage 2 product acceptance требует Product Profile schema_version: 3|4|5'
if [[ "$profile_schema" == 5 ]]; then
  bash "$SCRIPT_DIR/../s0-quality-gates/quality-characteristics-check.sh" "$PROJECT_PATH" >/dev/null ||
    blocked 'Quality Characteristics v1 invalid'
fi

ux_file="$(current_one ux-requirements)"
case "$ux_requirement" in
  required)
    [[ "${ux_file##*/}" == PO-*-ux-brief.md ]] ||
      blocked 'UI profile current UX artifact must be a UX brief'
    expect_meta "$ux_file" schema_version 1
    expect_meta "$ux_file" artifact_type ux-brief
    expect_meta "$ux_file" owner s2-po
    expect_meta "$ux_file" product_profile_revision "$profile_revision"
    expect_meta "$ux_file" applicability REQUIRED
    expect_meta "$ux_file" user_interface "$user_interface"
    grep -Fq '## User Flows' "$ux_file" || blocked 'UX brief не содержит ## User Flows'
    grep -Eq '(^|[^A-Za-z0-9_-])UXF-[A-Za-z0-9._-]+' "$ux_file" || blocked 'UX brief не содержит UXF id'
    grep -Fq '## UX Acceptance Constraints' "$ux_file" ||
      blocked 'UX brief не содержит ## UX Acceptance Constraints'
    grep -Eq '(^|[^A-Za-z0-9_-])UXC-[A-Za-z0-9._-]+' "$ux_file" || blocked 'UX brief не содержит UXC id'
    if [[ "$profile_schema" == 5 ]]; then
      require_measured_ids "$ux_file" UXC
      case "$accessibility_requirement" in
        required)
          expect_meta "$ux_file" accessibility_applicability REQUIRED
          accessibility_standard="$(yaml_field "$ux_file" accessibility_standard)"
          [[ -n "$accessibility_standard" && "$accessibility_standard" != unknown &&
            "$accessibility_standard" != none && "$accessibility_standard" != not-applicable ]] ||
            blocked 'required accessibility требует подтверждённый accessibility_standard'
          grep -Fq '## Accessibility Criteria' "$ux_file" ||
            blocked 'UX brief не содержит ## Accessibility Criteria'
          grep -Eq '(^|[^A-Za-z0-9_-])A11Y-[A-Za-z0-9._-]+' "$ux_file" ||
            blocked 'UX brief не содержит A11Y id'
          require_measured_ids "$ux_file" A11Y
          ;;
        not-applicable)
          expect_meta "$ux_file" accessibility_applicability NOT_APPLICABLE
          expect_meta "$ux_file" accessibility_standard not-applicable
          accessibility_reason="$(yaml_field "$ux_file" accessibility_reason)"
          [[ -n "$accessibility_reason" && "$accessibility_reason" != unknown &&
            "$accessibility_reason" != none ]] ||
            blocked 'accessibility NOT_APPLICABLE требует concrete accessibility_reason'
          ;;
        *) blocked "unsupported accessibility_validation: $accessibility_requirement" ;;
      esac
    fi
    ;;
  not-applicable)
    [[ "${ux_file##*/}" == PO-*-ux-not-applicable.md ]] ||
      blocked 'non-UI profile current UX artifact must be structured NOT_APPLICABLE'
    expect_meta "$ux_file" schema_version 1
    expect_meta "$ux_file" artifact_type ux-not-applicable
    expect_meta "$ux_file" owner s2-po
    expect_meta "$ux_file" product_profile_revision "$profile_revision"
    expect_meta "$ux_file" applicability NOT_APPLICABLE
    expect_meta "$ux_file" user_interface "$user_interface"
    applicability_reason="$(yaml_field "$ux_file" applicability_reason)"
    [[ -n "$applicability_reason" && "$applicability_reason" != unknown && "$applicability_reason" != none ]] ||
      blocked 'UX NOT_APPLICABLE требует конкретный applicability_reason'
    if [[ "$profile_schema" == 5 ]]; then
      expect_meta "$ux_file" accessibility_applicability NOT_APPLICABLE
      expect_meta "$ux_file" accessibility_standard not-applicable
      accessibility_reason="$(yaml_field "$ux_file" accessibility_reason)"
      [[ -n "$accessibility_reason" && "$accessibility_reason" != unknown &&
        "$accessibility_reason" != none ]] ||
        blocked 'non-UI accessibility N/A требует concrete accessibility_reason'
    fi
    ;;
  *) blocked "неподдерживаемый ux_brief_requirement: $ux_requirement" ;;
esac

uat_doc="$(current_one uat-criteria)"
uat_index="$(current_one product-acceptance-index)"
for metadata_doc in "$ux_file" "$uat_doc"; do
  metadata_ref="${metadata_doc#"$PROJECT_PATH/"}"
  bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" "$metadata_ref" >/dev/null ||
    blocked "$(basename "$metadata_doc"): common Artifact Metadata invalid"
done
expect_meta "$uat_doc" schema_version 1
expect_meta "$uat_doc" artifact_type uat-criteria
expect_meta "$uat_doc" owner s2-po
expect_meta "$uat_doc" product_profile_revision "$profile_revision"
expect_meta "$uat_doc" acceptance_scope product-end-to-end
grep -Fq '## Product Acceptance Scenarios' "$uat_doc" ||
  blocked 'UAT criteria не содержит ## Product Acceptance Scenarios'
grep -Eq '(^|[^A-Za-z0-9_-])UAT-[A-Za-z0-9._-]+' "$uat_doc" || blocked 'UAT criteria не содержит UAT id'
grep -Fq 'Sign-off criterion:' "$uat_doc" || blocked 'UAT criteria не содержит PO sign-off criterion'

rtm_file="$(current_one requirements-traceability)"
mapfile -t must_frs < <(
  awk 'BEGIN { IGNORECASE=1 } /Must/ { while (match($0, /FR-[A-Za-z0-9._-]+/)) { print substr($0, RSTART, RLENGTH); $0=substr($0, RSTART+RLENGTH) } }' \
    "$rtm_file" | sort -u
)
(( ${#must_frs[@]} > 0 )) || blocked 'RTM не содержит ни одного Must FR'

risk_file="$(current_one risk-register)"

expected_uri="stage2-requirements/outputs/$(basename "$uat_doc")"
IFS= read -r header < "$uat_index" || blocked 'product acceptance trace index пуст'
[[ "$header" == $'uat_id\tmust_fr_id\trisk_id\tux_flow_id\tcriteria_uri' ]] ||
  blocked 'product acceptance trace index имеет неверный header'

declare -A covered=() tuples=()
row_count=0
while IFS=$'\t' read -r uat_id must_fr_id risk_id ux_flow_id criteria_uri extra ||
  [[ -n "${uat_id}${must_fr_id}${risk_id}${ux_flow_id}${criteria_uri}${extra}" ]]; do
  ((row_count+=1))
  [[ -z "$extra" ]] || blocked "trace row $row_count содержит лишние columns"
  [[ "$uat_id" =~ ^UAT-[A-Za-z0-9._-]+$ ]] || blocked "trace row $row_count: invalid uat_id"
  [[ "$must_fr_id" =~ ^FR-[A-Za-z0-9._-]+$ ]] || blocked "trace row $row_count: invalid must_fr_id"
  [[ "$risk_id" =~ ^RISK-[A-Za-z0-9._-]+$ ]] || blocked "trace row $row_count: invalid risk_id"
  [[ "$criteria_uri" == "$expected_uri" ]] || blocked "trace row $row_count: wrong criteria_uri"
  grep -Fq "$uat_id" "$uat_doc" || blocked "$uat_id отсутствует в UAT criteria"
  grep -Fq "$must_fr_id" "$uat_doc" || blocked "$must_fr_id отсутствует в UAT criteria"
  grep -Fq "$risk_id" "$risk_file" || blocked "$risk_id отсутствует в current PMO risk register"
  if [[ "$ux_requirement" == required ]]; then
    [[ "$ux_flow_id" =~ ^UXF-[A-Za-z0-9._-]+$ ]] || blocked "trace row $row_count: invalid ux_flow_id"
    grep -Fq "$ux_flow_id" "$ux_file" || blocked "$ux_flow_id отсутствует в UX brief"
    grep -Fq "$ux_flow_id" "$uat_doc" || blocked "$ux_flow_id отсутствует в UAT criteria"
  else
    [[ "$ux_flow_id" == NOT_APPLICABLE ]] || blocked 'non-UI UAT trace требует ux_flow_id=NOT_APPLICABLE'
    grep -Fq 'NOT_APPLICABLE' "$uat_doc" || blocked 'non-UI UAT criteria не фиксирует UX NOT_APPLICABLE'
  fi
  tuple="$uat_id|$must_fr_id|$risk_id|$ux_flow_id"
  [[ -z "${tuples[$tuple]+x}" ]] || blocked "duplicate trace tuple: $tuple"
  tuples["$tuple"]=1
  covered["$must_fr_id"]=1
done < <(tail -n +2 "$uat_index")
(( row_count > 0 )) || blocked 'product acceptance trace index не содержит rows'

for must_fr in "${must_frs[@]}"; do
  [[ -n "${covered[$must_fr]:-}" ]] || blocked "Must requirement не имеет UAT path: $must_fr"
done

if grep -Eiq '(AKIA[0-9A-Z]{8,}|gh[pousr]_[A-Za-z0-9]+|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{8,}|password=|token=|secret=)' \
  "$ux_file" "$uat_doc" "$uat_index"; then
  blocked 'secret-like value запрещён в product acceptance artifacts'
fi

echo "PRODUCT ACCEPTANCE VERIFIED: profile_revision=$profile_revision interface=$user_interface ux=$ux_requirement accessibility=$accessibility_requirement uat_rows=$row_count must_fr_ids=${#must_frs[@]}"

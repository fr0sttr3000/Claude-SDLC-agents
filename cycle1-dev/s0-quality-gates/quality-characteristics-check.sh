#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
blocked() { echo "QUALITY CHARACTERISTICS BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VALIDATE_DIR="$(cd "$SCRIPT_DIR/../s0-validate" && pwd -P)"
APPLICABILITY_RESOLVER="$VALIDATE_DIR/applicability-resolve.sh"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
INDEX="$PROJECT_PATH/tracking/quality-characteristics-v1.tsv"
VIEW="$PROJECT_PATH/tracking/quality-characteristics.md"

bash "$VALIDATE_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Product & CI Profile invalid'
quality_output="$(bash "$SCRIPT_DIR/quality-gates-check.sh" "$PROJECT_PATH" 2>&1)" || {
  printf '%s\n' "$quality_output" >&2
  blocked 'effective quality policy weakens or cannot prove global minima'
}

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}
frontmatter_field() {
  local file="$1" wanted="$2"
  awk -v wanted="$wanted" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    {
      key=$0; sub(/:.*/, "", key)
      if (key == wanted) {
        value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit
      }
    }
  ' "$file"
}
expect_view_meta() {
  local key="$1" expected="$2" actual
  actual="$(frontmatter_field "$VIEW" "$key")"
  [[ "$actual" == "$expected" ]] ||
    blocked "quality-characteristics.md: $key должен быть $expected, получено ${actual:-MISSING}"
}

profile_schema="$(field "$PROFILE" schema_version)"
profile_revision="$(field "$PROFILE" revision)"
[[ "$profile_schema" == 5 ]] ||
  blocked 'verified quality-characteristic coverage требует Product Profile schema_version: 5'
[[ -f "$INDEX" && ! -L "$INDEX" ]] || blocked 'quality-characteristics-v1.tsv absent or symlink'
[[ -f "$VIEW" && ! -L "$VIEW" ]] || blocked 'quality-characteristics.md absent or symlink'

expected_header=$'characteristic_id\tapplicability\towner\tevidence_type\tevidence_contract\tgate\tprofile_field\tprofile_value\tminimum_policy\trationale_ref'
IFS= read -r header < "$INDEX" || blocked 'quality-characteristics-v1.tsv пуст'
[[ "$header" == "$expected_header" ]] || blocked 'quality-characteristics-v1.tsv имеет неверный header'

records=(
  'functional-suitability|always-required|always-required|s2-po+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
  'performance-efficiency|performance|performance_validation|s2-test-strategy+s3-arch+s5-perf|hybrid|QUALITY_POLICY_V1+ARCHITECTURE_DECISION_TRACE_V1+S5_VALIDATION_V1|GATE2+GATE3+GATE5'
  'compatibility|compatibility|compatibility_validation|s3-arch+s4-qa-auto+s4-techlead|hybrid|ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1|GATE3+GATE4'
  'interaction-capability|interaction|ux_brief_requirement|s2-po+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
  'accessibility|accessibility|accessibility_validation|s2-po+s2-qa-req+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
  'reliability|always-required|always-required|s2-ba+s3-arch|hybrid|ARCHITECTURE_DECISION_TRACE_V1|GATE2+GATE3'
  'security|always-required|always-required|s2-security+s3-security+s4-techlead+s5-security|hybrid|SECURITY_SG1_SG4|GATE2+GATE3+GATE4+GATE5'
  'maintainability|always-required|always-required|s3-arch+s4-techlead|hybrid|ARCHITECTURE_DECISION_TRACE_V1+TECH_LEAD_REVIEW|GATE3+GATE4'
  'flexibility-installability|flexibility|flexibility_validation|s3-arch+s4-qa-auto|hybrid|ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1|GATE3+GATE4'
  'safety|safety|safety_validation|s1-pmo+s2-ba+s3-arch|hybrid|PMO_CONSTRAINTS+ARCHITECTURE_DECISION_TRACE_V1|GATE1+GATE3'
  'quality-in-use|always-required|always-required|s2-po+s5-qa|hybrid|PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1|GATE2+GATE5'
)

declare -A seen=()
row_count=0
section_text=''
while IFS=$'\t' read -r characteristic applicability owner evidence_type evidence_contract gate profile_field profile_value minimum_policy rationale_ref extra ||
  [[ -n "${characteristic}${applicability}${owner}${evidence_type}${evidence_contract}${gate}${profile_field}${profile_value}${minimum_policy}${rationale_ref}${extra}" ]]; do
  ((row_count+=1))
  [[ "$row_count" -le "${#records[@]}" ]] || blocked 'quality index содержит лишние rows'
  [[ -z "$extra" ]] || blocked "row $row_count содержит лишние columns"
  IFS='|' read -r expected_id expected_capability expected_field expected_owner expected_type expected_contract expected_gate <<< "${records[$((row_count - 1))]}"
  [[ "$characteristic" == "$expected_id" ]] || blocked "row $row_count: ожидался $expected_id"
  [[ -z "${seen[$characteristic]+x}" ]] || blocked "duplicate characteristic_id: $characteristic"
  seen["$characteristic"]=1
  [[ "$profile_field" == "$expected_field" ]] || blocked "$characteristic: wrong profile_field"
  [[ "$owner" == "$expected_owner" ]] || blocked "$characteristic: wrong owner"
  [[ "$evidence_type" == "$expected_type" ]] || blocked "$characteristic: wrong evidence_type"
  [[ "$evidence_contract" == "$expected_contract" ]] || blocked "$characteristic: wrong evidence_contract"
  [[ "$gate" == "$expected_gate" ]] || blocked "$characteristic: wrong gate"
  if [[ "$profile_field" == always-required ]]; then
    expected_value=always-required
    expected_applicability=REQUIRED
  else
    resolver_output="$(bash "$APPLICABILITY_RESOLVER" resolve "$PROJECT_PATH" "$expected_capability")" ||
      blocked "$characteristic: applicability resolution failed"
    IFS=$'\t' read -r resolved_capability expected_applicability resolved_field expected_value \
      resolved_revision resolved_owner resolved_reason resolver_extra <<< "$resolver_output"
    [[ -z "$resolver_extra" && "$resolved_capability" == "$expected_capability" &&
      "$resolved_field" == "$profile_field" && "$resolved_revision" == "$profile_revision" ]] ||
      blocked "$characteristic: invalid/stale applicability resolver output"
  fi
  [[ "$profile_value" == "$expected_value" ]] || blocked "$characteristic: stale/wrong profile_value"
  [[ "$applicability" == "$expected_applicability" ]] || blocked "$characteristic: applicability contradicts Product Profile"
  [[ "$minimum_policy" == GLOBAL_MINIMUM_OR_STRICTER ]] || blocked "$characteristic: global minimum may not be weakened"
  [[ "$rationale_ref" == tracking/quality-characteristics.md ]] || blocked "$characteristic: wrong rationale_ref"

  [[ "$(grep -Fxc "## $characteristic" "$VIEW")" == 1 ]] || blocked "$characteristic: view section missing or duplicate"
  section_text="$(awk -v heading="## $characteristic" '
    $0 == heading { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$VIEW")"
  for expected_line in \
    "- Applicability: $applicability" \
    "- Owner: $owner" \
    "- Evidence type: $evidence_type" \
    "- Evidence contract: $evidence_contract" \
    "- Gate: $gate" \
    "- Profile field: $profile_field" \
    "- Profile value: $profile_value" \
    "- Minimum policy: GLOBAL_MINIMUM_OR_STRICTER"; do
    grep -Fqx -- "$expected_line" <<< "$section_text" || blocked "$characteristic: view mismatch: $expected_line"
  done
  [[ "$(grep -Ec "^- Rationale \($characteristic\): .+" <<< "$section_text")" == 1 ]] ||
    blocked "$characteristic: rationale missing or duplicate"
  rationale_line="$(grep -E "^- Rationale \($characteristic\): .+" <<< "$section_text")"
  [[ -n "$rationale_line" ]] || blocked "$characteristic: concrete rationale missing"
  [[ ! "${rationale_line,,}" =~ (unknown|tbd|todo|placeholder) ]] || blocked "$characteristic: placeholder rationale"
done < <(tail -n +2 "$INDEX")
[[ "$row_count" -eq "${#records[@]}" ]] || blocked "ожидалось ${#records[@]} characteristics, найдено $row_count"

bash "$VALIDATE_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" tracking/quality-characteristics.md >/dev/null ||
  blocked 'quality-characteristics.md не прошёл shared Artifact Metadata v1'
expect_view_meta quality_schema_version 1
expect_view_meta product_profile_revision "$profile_revision"
expect_view_meta applicability_index tracking/quality-characteristics-v1.tsv
expect_view_meta minimum_policy GLOBAL_MINIMUM_OR_STRICTER
expect_view_meta inputs tracking/product-ci-profile.yaml,tracking/PMO-constraints.md,tracking/quality-characteristics-v1.tsv
grep -Fq 'SG1-SG4 active; SG5 FROZEN / NOT SUPPORTED' "$VIEW" || blocked 'security scope boundary missing'
grep -Fq 'Cycle 2/3 FROZEN / NOT REQUIRED' "$VIEW" || blocked 'frozen Cycle 2/3 boundary missing'

if grep -Eiq '(AKIA[0-9A-Z]{8,}|gh[pousr]_[A-Za-z0-9]+|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{8,}|password=|token=|secret=)' "$INDEX"; then
  blocked 'secret-like value in quality characteristic index'
fi

policy_revision="$(sed -n 's/.*policy_revision=\([^ ]*\).*/\1/p' <<< "$quality_output" | head -1)"
echo "QUALITY CHARACTERISTICS VERIFIED: profile_revision=$profile_revision policy_revision=$policy_revision characteristics=$row_count"

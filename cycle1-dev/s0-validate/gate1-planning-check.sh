#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
blocked() { echo "GATE 1 PLANNING BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT_TOOL="$SCRIPT_DIR/current-artifact.sh"

resolve_current_one() {
  local ref
  ref="$(bash "$CURRENT_TOOL" resolve-compatible-one "$PROJECT" "$1" 2>/dev/null)" ||
    blocked "$1 current resolution failed"
  printf '%s/%s\n' "$PROJECT" "$ref"
}
field() {
  local file="$1" key="$2" count
  count="$(awk -F: -v key="$key" '$1 == key {n++} END {print n+0}' "$file")"
  [[ "$count" == 1 ]] || blocked "$(basename "$file"): $key must occur exactly once"
  awk -F: -v key="$key" '$1 == key {v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); print v}' "$file"
}
verify_human_decision() {
  local artifact="$1" ref_field="$2" producer="$3" expected_scope="$4"
  local ref source digest approval
  ref="$(field "$artifact" "$ref_field")"
  [[ "$ref" == tracking/approvals/APPROVAL-*.yaml && "$ref" != *..* ]] ||
    blocked "$(basename "$artifact"): invalid $ref_field"
  source="$(field "$artifact" source_revision)"
  [[ "$source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
    blocked "$(basename "$artifact"): source_revision is not exact"
  digest="$(sha256sum "$artifact" | awk '{print $1}')"
  bash "$SCRIPT_DIR/human-approval-check.sh" "$PROJECT" "$ref" "$source" "$digest" "$producer" >/dev/null ||
    blocked "$(basename "$artifact"): launcher-owned human decision invalid"
  approval="$PROJECT/$ref"
  [[ "$(field "$approval" decision)" == APPROVE ]] ||
    blocked "$(basename "$artifact"): human decision is not APPROVE"
  [[ "$(field "$approval" scope)" == "$expected_scope" ]] ||
    blocked "$(basename "$artifact"): human scope mismatch"
}
section_has_concrete_content() {
  local file="$1" heading="$2"
  awk -v heading="$heading" '
    $0 == heading {inside=1; next}
    inside && /^##[[:space:]]/ {exit(found ? 0 : 1)}
    inside && /[[:alnum:]]/ &&
      tolower($0) !~ /(tbd|todo|placeholder|unknown|scope:minimal)/ {found=1}
    END {exit(found ? 0 : 1)}
  ' "$file"
}

feasibility="$(resolve_current_one feasibility-study)"
business_case="$(resolve_current_one business-case)"
charter="$(resolve_current_one project-charter)"
risk_register="$(resolve_current_one risk-register)"
for file in "$feasibility" "$business_case" "$charter" "$risk_register"; do
  [[ -f "$file" && ! -L "$file" ]] || blocked "$(basename "$file") absent or symlink"
  bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT" "${file#"$PROJECT/"}" >/dev/null ||
    blocked "$(basename "$file"): common Artifact Metadata invalid"
done

profile="$PROJECT/tracking/product-ci-profile.yaml"
[[ -f "$profile" && ! -L "$profile" ]] || blocked 'Product Profile is missing or symlink'
profile_revision="$(field "$profile" revision)"
[[ "$profile_revision" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid Product Profile revision'
context_source="$(field "$feasibility" source_revision)"
[[ "$context_source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  blocked 'feasibility source_revision is not exact'
for file in "$feasibility" "$business_case" "$charter" "$risk_register"; do
  [[ "$(field "$file" product_profile_revision)" == "$profile_revision" ]] ||
    blocked "$(basename "$file"): stale product_profile_revision"
  [[ "$(field "$file" source_revision)" == "$context_source" ]] ||
    blocked "$(basename "$file"): source_revision differs from Gate 1 context"
done

decision="$(field "$feasibility" Decision)"
[[ "$decision" == CONDITIONAL_GO ]] ||
  blocked 'pre-finance feasibility Decision must be CONDITIONAL_GO'
[[ "$(field "$feasibility" decision_status)" == PRE_FINANCE ]] ||
  blocked 'feasibility decision_status must be PRE_FINANCE'
[[ "$(field "$feasibility" finance_dependency)" == OPEN ]] ||
  blocked 'feasibility finance_dependency must remain OPEN until Business Case'
[[ "$(field "$feasibility" 'Assessment status')" == COMPLETE ]] ||
  blocked 'feasibility assessment is not COMPLETE'
grep -Fqx '## Scope In' "$feasibility" || blocked 'feasibility has no Scope In'
grep -Fqx '## Scope Out' "$feasibility" || blocked 'feasibility has no Scope Out'
section_has_concrete_content "$feasibility" '## Scope In' ||
  blocked 'feasibility Scope In is empty or placeholder'
section_has_concrete_content "$feasibility" '## Scope Out' ||
  blocked 'feasibility Scope Out is empty or placeholder'

declare -A axis_seen=() conditional_axis=() condition_axis=() condition_seen=()
axis_count=0
while IFS=$'\t' read -r axis verdict evidence owner; do
  [[ "$axis" =~ ^(technical|economic|operational|legal)$ ]] || blocked "invalid axis: $axis"
  [[ "$verdict" =~ ^(PASS|CONDITIONAL)$ ]] || blocked "$axis has blocking verdict"
  [[ "$evidence" =~ [A-Za-z0-9] && "$owner" =~ [A-Za-z0-9] ]] ||
    blocked "$axis lacks evidence/owner"
  [[ ! "${evidence,,}" =~ (skip|tbd|todo|placeholder|unknown) ]] ||
    blocked "$axis evidence is incomplete"
  [[ -z "${axis_seen[$axis]:-}" ]] || blocked "duplicate axis: $axis"
  axis_seen["$axis"]=1
  [[ "$verdict" != CONDITIONAL ]] || conditional_axis["$axis"]=1
  axis_count=$((axis_count + 1))
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^Axis:[[:space:]]*/ {
    if (NF != 4 ||
        $1 !~ /^Axis:[[:space:]]*/ ||
        $2 !~ /^Verdict:[[:space:]]*/ ||
        $3 !~ /^Evidence:[[:space:]]*/ ||
        $4 !~ /^Owner:[[:space:]]*/) next
    for (i=1; i<=4; i++) sub(/^[^:]+:[[:space:]]*/, "", $i)
    print $1 "\t" $2 "\t" $3 "\t" $4
  }' "$feasibility")
axis_record_count="$(grep -Ec '^Axis:[[:space:]]*' "$feasibility" || true)"
(( axis_record_count == axis_count )) || blocked 'malformed feasibility Axis record'
for axis in technical economic operational legal; do
  [[ -n "${axis_seen[$axis]:-}" ]] || blocked "missing feasibility axis: $axis"
done
while IFS=$'\t' read -r id axis status owner resolution; do
  [[ "$id" =~ ^COND-[A-Za-z0-9._-]+$ ]] || blocked "invalid condition id: $id"
  [[ "$axis" =~ ^(technical|economic|operational|legal|finance)$ ]] ||
    blocked "$id has invalid condition axis"
  [[ "$status" == OPEN ]] || blocked "$id condition status must be OPEN"
  for value in "$owner" "$resolution"; do
    [[ "$value" =~ [A-Za-z0-9] && ! "${value,,}" =~ (tbd|todo|placeholder|unknown) ]] ||
      blocked "$id condition owner/resolution is incomplete"
  done
  [[ -z "${condition_seen[$id]:-}" ]] || blocked "duplicate condition id: $id"
  condition_seen["$id"]=1
  condition_axis["$axis"]=1
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^Condition:[[:space:]]*/ {
    if (NF != 5 ||
        $1 !~ /^Condition:[[:space:]]*/ ||
        $2 !~ /^Axis:[[:space:]]*/ ||
        $3 !~ /^Status:[[:space:]]*/ ||
        $4 !~ /^Owner:[[:space:]]*/ ||
        $5 !~ /^Resolution:[[:space:]]*/) next
    for (i=1; i<=5; i++) sub(/^[^:]+:[[:space:]]*/, "", $i)
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5
  }' "$feasibility")
condition_count="${#condition_seen[@]}"
condition_record_count="$(grep -Ec '^Condition:[[:space:]]*' "$feasibility" || true)"
(( condition_record_count == condition_count )) ||
  blocked 'malformed feasibility Condition record'
for axis in "${!conditional_axis[@]}"; do
  [[ -n "${condition_axis[$axis]:-}" ]] ||
    blocked "conditional $axis axis has no concrete Condition record"
done
verify_human_decision "$feasibility" stakeholder_acknowledgement_ref s1-pm feasibility-acknowledgement

feasibility_sha="$(sha256sum "$feasibility" | awk '{print $1}')"
[[ "$(field "$business_case" feasibility_sha256)" == "$feasibility_sha" ]] ||
  blocked 'Business Case is not bound to current feasibility'
finance_status="$(field "$business_case" finance_status)"
[[ "$finance_status" =~ ^(PASS|CONDITIONAL)$ ]] || blocked 'finance_status is blocking'
for metric in base_npv base_roi_percent base_payback_months; do
  [[ "$(field "$business_case" "$metric")" =~ ^-?[0-9]+([.][0-9]+)?$ ]] ||
    blocked "Business Case has invalid $metric"
done
if [[ "$finance_status" == CONDITIONAL ]]; then
  [[ -n "${condition_axis[finance]:-}" ]] ||
    blocked 'conditional Finance requires a concrete finance Condition in feasibility'
fi
if (( ${#conditional_axis[@]} == 0 )) && [[ "$finance_status" == PASS ]]; then
  effective_decision=GO
else
  effective_decision=CONDITIONAL_GO
fi

[[ "$(field "$charter" 'Charter status')" == SIGNED ]] || blocked 'charter is not SIGNED'
grep -Fqx '## Objectives' "$charter" || blocked 'charter has no Objectives'
section_has_concrete_content "$charter" '## Objectives' ||
  blocked 'charter Objectives are empty or placeholder'
verify_human_decision "$charter" charter_approval_ref s1-pmo charter-signature

business_case_sha="$(sha256sum "$business_case" | awk '{print $1}')"
for file in "$charter" "$risk_register"; do
  [[ "$(field "$file" feasibility_sha256)" == "$feasibility_sha" ]] ||
    blocked "$(basename "$file"): stale feasibility binding"
  [[ "$(field "$file" business_case_sha256)" == "$business_case_sha" ]] ||
    blocked "$(basename "$file"): stale Business Case binding"
  [[ "$(field "$file" gate1_decision)" == "$effective_decision" ]] ||
    blocked "$(basename "$file"): Gate 1 decision differs from effective decision"
done

declare -A seen=()
risk_count=0
while IFS=$'\t' read -r id category probability impact score owner mitigation trigger status constraint; do
  [[ "$id" =~ ^RISK-[A-Za-z0-9._-]+$ ]] || blocked "invalid risk id: $id"
  [[ -z "${seen[$id]:-}" ]] || blocked "duplicate risk id: $id"
  seen["$id"]=1
  [[ "$category" =~ ^[A-Za-z][A-Za-z0-9._-]*$ ]] || blocked "$id category invalid"
  [[ "$probability" =~ ^[1-5]$ && "$impact" =~ ^[1-5]$ && "$score" =~ ^([1-9]|1[0-9]|2[0-5])$ ]] ||
    blocked "$id probability/impact/score invalid"
  (( probability * impact == score )) || blocked "$id score is not P*I"
  for value in "$owner" "$mitigation" "$trigger"; do
    [[ "$value" =~ [A-Za-z0-9] && ! "${value,,}" =~ (tbd|todo|placeholder|unknown) ]] ||
      blocked "$id has incomplete owner/mitigation/trigger"
  done
  [[ "$status" =~ ^(OPEN|MITIGATED|CLOSED)$ ]] || blocked "$id status invalid"
  [[ "$constraint" =~ ^[A-Za-z][A-Za-z0-9._-]*$ &&
    ! "${constraint,,}" =~ (tbd|todo|placeholder|unknown) ]] ||
    blocked "$id has no decision constraint link"
  if (( score >= 15 )) && [[ "$status" == OPEN && ${#mitigation} -lt 10 ]]; then
    blocked "$id high risk has no concrete mitigation"
  fi
  risk_count=$((risk_count + 1))
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^RISK-[A-Za-z0-9._-]+[[:space:]]*\|/ {
    if (NF != 10 ||
        $2 !~ /^Category:[[:space:]]*/ ||
        $3 !~ /^Probability:[[:space:]]*/ ||
        $4 !~ /^Impact:[[:space:]]*/ ||
        $5 !~ /^Score:[[:space:]]*/ ||
        $6 !~ /^Owner:[[:space:]]*/ ||
        $7 !~ /^Mitigation:[[:space:]]*/ ||
        $8 !~ /^Trigger:[[:space:]]*/ ||
        $9 !~ /^Status:[[:space:]]*/ ||
        $10 !~ /^Constraint:[[:space:]]*/) next
    id=$1
    for (i=2; i<=10; i++) sub(/^[^:]+:[[:space:]]*/, "", $i)
    print id "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10
  }' "$risk_register")
risk_record_count="$(grep -Ec '^RISK-[A-Za-z0-9._-]+[[:space:]]*[|]' "$risk_register" || true)"
(( risk_record_count == risk_count )) || blocked 'malformed risk record'
(( risk_count >= 10 )) || blocked "risk register requires at least 10 complete risks, found $risk_count"

echo "GATE 1 PLANNING VERIFIED: candidate=$decision finance=$finance_status effective=$effective_decision axes=4 risks=$risk_count human_decisions=2"

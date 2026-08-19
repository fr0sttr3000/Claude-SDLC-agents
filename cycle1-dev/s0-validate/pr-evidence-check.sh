#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
SOURCE_REVISION="${2:?Укажи exact source revision}"
blocked() { echo "PR EVIDENCE BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$SOURCE_REVISION" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  blocked 'source revision должен быть full immutable revision'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Product & CI Profile invalid'
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
APPLICABILITY_RESOLVER="$SCRIPT_DIR/applicability-resolve.sh"
EVIDENCE_DIR="$PROJECT_PATH/tracking/evidence/v1"
[[ -d "$EVIDENCE_DIR" ]] || blocked 'tracking/evidence/v1 отсутствует'

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

resolved_applicability() {
  local capability="$1" output resolved_capability applicability profile_field profile_value
  local revision owner reason extra
  output="$(bash "$APPLICABILITY_RESOLVER" resolve "$PROJECT_PATH" "$capability")" ||
    blocked "applicability resolution failed: $capability"
  IFS=$'\t' read -r resolved_capability applicability profile_field profile_value \
    revision owner reason extra <<< "$output"
  [[ -z "$extra" && "$resolved_capability" == "$capability" ]] ||
    blocked "invalid applicability resolver output: $capability"
  printf '%s\n' "$applicability"
}

profile_schema="$(field "$PROFILE" schema_version)"
[[ "$profile_schema" =~ ^(2|3|4|5)$ ]] ||
  blocked 'minimum PR verification требует Product Profile schema_version: 2|3|4|5'
profile_revision="$(field "$PROFILE" revision)"
image_scan_applicability="$(resolved_applicability image-scan)"
sbom_applicability="$(resolved_applicability sbom)"
compatibility_requirement='legacy-unverified'
if [[ "$profile_schema" == 5 ]]; then
  compatibility_applicability="$(resolved_applicability compatibility)"
  [[ "$compatibility_applicability" == REQUIRED ]] && compatibility_requirement=required ||
    compatibility_requirement=not-applicable
fi
required_csv="$(field "$PROFILE" scm_required_checks)"
IFS=',' read -r -a required_checks <<< "$required_csv"
quality_output="$(bash "$SCRIPT_DIR/../s0-quality-gates/quality-gates-check.sh" "$PROJECT_PATH" 2>&1)" || {
  printf '%s\n' "$quality_output" >&2
  blocked 'quality policy FAIL/BLOCKED/UNVERIFIED'
}
quality_policy_revision="$(sed -n 's/.*policy_revision=\([^ ]*\).*/\1/p' <<< "$quality_output" | head -1)"
[[ -n "$quality_policy_revision" ]] || blocked 'quality policy verifier did not return revision'
if [[ "$profile_schema" == 5 ]]; then
  characteristics_output="$(bash "$SCRIPT_DIR/../s0-quality-gates/quality-characteristics-check.sh" "$PROJECT_PATH" 2>&1)" || {
    printf '%s\n' "$characteristics_output" >&2
    blocked 'Quality Characteristics v1 FAIL/BLOCKED/UNVERIFIED'
  }
fi

evidence_ids=()
for check in "${required_checks[@]}"; do
  matches=()
  while IFS= read -r -d '' record; do
    [[ "$(field "$record" check_id)" == "$check" ]] || continue
    [[ "$(field "$record" source_revision)" == "$SOURCE_REVISION" ]] || continue
    matches+=("$record")
  done < <(find "$EVIDENCE_DIR" -maxdepth 1 -type f -name '*.yaml' -print0 | sort -z)

  (( ${#matches[@]} == 1 )) ||
    blocked "check=$check требует ровно один current record; найдено ${#matches[@]}"
  record="${matches[0]}"
  verifier_output="$(bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$record" \
    --expected-source "$SOURCE_REVISION" --expected-check "$check" 2>&1)" || {
      printf '%s\n' "$verifier_output" >&2
      blocked "check=$check имеет FAIL/BLOCKED/UNVERIFIED evidence"
    }
  verdict="$(field "$record" verdict)"
  case "$check" in
    build|unit|integration|contract|lint|typecheck)
      [[ "$(field "$record" policy_revision)" == "$quality_policy_revision" ]] ||
        blocked "check=$check bound to stale/wrong quality policy revision"
      ;;
  esac
  case "$check" in
    unit)
      bash "$SCRIPT_DIR/quality-metric-result-check.sh" "$PROJECT_PATH" "$record" \
        branch_coverage_percent,mutation_score_percent >/dev/null ||
        blocked 'unit quality metrics do not satisfy effective policy'
      ;;
    lint)
      bash "$SCRIPT_DIR/quality-metric-result-check.sh" "$PROJECT_PATH" "$record" \
        complexity_max >/dev/null || blocked 'lint complexity metric does not satisfy effective policy'
      ;;
  esac
  case "$check" in
    build|unit|lint|secrets|sast|sca|dependency-integrity)
      [[ "$verdict" == PASS ]] || blocked "check=$check не допускает NOT_APPLICABLE в minimum v1"
      ;;
    image-scan)
      if [[ "$image_scan_applicability" == REQUIRED ]]; then
        [[ "$verdict" == PASS ]] || blocked 'image subject требует PASS image-scan'
      else
        [[ "$verdict" == NOT_APPLICABLE ]] || blocked 'image-scan без image subject должен быть structured NOT_APPLICABLE'
      fi
      ;;
    sbom)
      if [[ "$sbom_applicability" == REQUIRED ]]; then
        [[ "$verdict" == PASS ]] || blocked 'applicable SBOM требует PASS evidence'
      else
        [[ "$verdict" == NOT_APPLICABLE ]] || blocked 'неприменимый SBOM должен быть structured NOT_APPLICABLE'
      fi
      ;;
    integration|contract)
      if [[ "$profile_schema" == 5 && "$compatibility_requirement" == required ]]; then
        [[ "$verdict" == PASS ]] || blocked "compatibility required: check=$check требует PASS"
      elif [[ "$profile_schema" == 5 && "$compatibility_requirement" == not-applicable ]]; then
        [[ "$verdict" == NOT_APPLICABLE ]] ||
          blocked "compatibility not-applicable: check=$check требует structured NOT_APPLICABLE"
      else
        [[ "$verdict" == PASS || "$verdict" == NOT_APPLICABLE ]] ||
          blocked "check=$check имеет blocking verdict=$verdict"
      fi
      ;;
    typecheck)
      [[ "$verdict" == PASS || "$verdict" == NOT_APPLICABLE ]] ||
        blocked "check=$check имеет blocking verdict=$verdict"
      ;;
    pipeline-policy)
      [[ "$verdict" == PASS ]] || blocked 'pipeline-policy controls require PASS'
      ;;
  esac
  evidence_ids+=("$(field "$record" evidence_id)")
done

sg3_output="$(bash "$SCRIPT_DIR/sg3-policy-check.sh" "$PROJECT_PATH" "$SOURCE_REVISION" 2>&1)" || {
  printf '%s\n' "$sg3_output" >&2
  blocked 'independent SG3 policy FAIL/BLOCKED/UNVERIFIED'
}
printf '%s\n' "$sg3_output"
controls_output="$(bash "$SCRIPT_DIR/executor-controls-check.sh" "$PROJECT_PATH" "$SOURCE_REVISION" 2>&1)" || {
  printf '%s\n' "$controls_output" >&2
  blocked 'selected executor controls FAIL/BLOCKED/UNVERIFIED'
}
printf '%s\n' "$controls_output"
printf '%s\n' "$quality_output"
if [[ "$profile_schema" == 5 ]]; then printf '%s\n' "$characteristics_output"; fi
ids_csv="$(IFS=','; printf '%s' "${evidence_ids[*]}")"
echo "PR EVIDENCE VERIFIED: source=$SOURCE_REVISION profile_revision=$profile_revision compatibility=$compatibility_requirement evidence_ids=$ids_csv"

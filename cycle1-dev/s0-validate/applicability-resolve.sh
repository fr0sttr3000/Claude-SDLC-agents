#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-}"
PROJECT_INPUT="${2:-}"
CAPABILITY="${3:-}"
DECISION_REF="${4:-}"
EXPECTED_PRODUCER="${5:-}"

blocked() { echo "APPLICABILITY BLOCKED: $*" >&2; exit 1; }
usage() {
  blocked 'usage: applicability-resolve.sh resolve <PROJECT> <capability> | validate <PROJECT> <capability> <decision-ref> <producer>'
}

[[ "$MODE" == resolve || "$MODE" == validate ]] || usage
[[ -n "$PROJECT_INPUT" && -n "$CAPABILITY" ]] || usage
[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"

bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Product & CI Profile invalid'

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key {
    value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value)
    print value; exit
  }' "$file"
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

profile_field=''
case "$CAPABILITY" in
  api-contract) profile_field=api_contract_design ;;
  environment-format) profile_field=environment_format_validation ;;
  data-store) profile_field=data_store_design ;;
  authorization) profile_field=authorization_design ;;
  performance) profile_field=performance_validation ;;
  runtime-security) profile_field=runtime_security_validation ;;
  interaction) profile_field=ux_brief_requirement ;;
  accessibility) profile_field=accessibility_validation ;;
  compatibility) profile_field=compatibility_validation ;;
  flexibility) profile_field=flexibility_validation ;;
  safety) profile_field=safety_validation ;;
  sbom) profile_field=sbom_requirement ;;
  image-scan) profile_field=build_subject ;;
  *) blocked "unknown capability: $CAPABILITY" ;;
esac

profile_value="$(field "$PROFILE" "$profile_field")"
[[ -n "$profile_value" ]] ||
  blocked "capability=$CAPABILITY требует подтверждённое поле $profile_field; refresh Product Profile"

if [[ "$CAPABILITY" == image-scan ]]; then
  case "$profile_value" in
    image) applicability=REQUIRED ;;
    source-only|build-artifact) applicability=NOT_APPLICABLE ;;
    *) blocked "unsupported build_subject: $profile_value" ;;
  esac
else
  case "$profile_value" in
    required) applicability=REQUIRED ;;
    not-applicable) applicability=NOT_APPLICABLE ;;
    *) blocked "unsupported applicability value: $profile_field=$profile_value" ;;
  esac
fi

profile_revision="$(field "$PROFILE" revision)"
applicability_owner=s0-kickoff
applicability_reason="$(field "$PROFILE" revision_reason)"
[[ -n "$applicability_reason" && ! "$applicability_reason" =~ [[:cntrl:]] &&
  ! "${applicability_reason,,}" =~ (unknown|inferred|tbd|todo|placeholder) ]] ||
  blocked 'Product Profile revision_reason не является конкретным подтверждённым основанием'

result="$CAPABILITY"$'\t'"$applicability"$'\t'"$profile_field"$'\t'"$profile_value"$'\t'"$profile_revision"$'\t'"$applicability_owner"$'\t'"$applicability_reason"

if [[ "$MODE" == resolve ]]; then
  printf '%s\n' "$result"
  exit 0
fi

[[ -n "$DECISION_REF" && -n "$EXPECTED_PRODUCER" ]] || usage
[[ "$applicability" == NOT_APPLICABLE ]] ||
  blocked "capability=$CAPABILITY REQUIRED; N/A decision запрещён"
[[ "$DECISION_REF" =~ ^[A-Za-z0-9._/-]+\.md$ && "$DECISION_REF" != /* &&
  "$DECISION_REF" != ../* && "$DECISION_REF" != *'/../'* && "$DECISION_REF" != */.. ]] ||
  blocked "unsafe decision reference: $DECISION_REF"
DECISION="$PROJECT_PATH/$DECISION_REF"
[[ -f "$DECISION" && ! -L "$DECISION" ]] || blocked "decision missing/symlink: $DECISION_REF"

bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" "$DECISION_REF" \
  "$EXPECTED_PRODUCER" S3 applicability-decision >/dev/null ||
  blocked 'structured applicability decision has invalid common Artifact Metadata'

expect_field() {
  local key="$1" expected="$2" actual
  actual="$(frontmatter_field "$DECISION" "$key")"
  [[ "$actual" == "$expected" ]] ||
    blocked "$(basename "$DECISION"): $key должен быть $expected, получено ${actual:-MISSING}"
}

expect_field status NOT_APPLICABLE
expect_field source_revision none
expect_field capability "$CAPABILITY"
expect_field applicability NOT_APPLICABLE
expect_field profile_field "$profile_field"
expect_field profile_value "$profile_value"
expect_field product_profile_revision "$profile_revision"
expect_field applicability_owner "$applicability_owner"
expect_field applicability_reason "$applicability_reason"

inputs="$(frontmatter_field "$DECISION" inputs)"
[[ ",$inputs," == *,tracking/product-ci-profile.yaml,* ]] ||
  blocked 'applicability decision inputs must include tracking/product-ci-profile.yaml'

echo "APPLICABILITY DECISION VERIFIED: capability=$CAPABILITY profile_revision=$profile_revision ref=$DECISION_REF"

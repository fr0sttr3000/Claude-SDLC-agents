#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
SOURCE_REVISION="${2:?Укажи exact source revision}"
blocked() { echo "EXECUTOR CONTROLS BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
command -v jq >/dev/null 2>&1 || blocked 'jq capability отсутствует'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
EVIDENCE_DIR="$PROJECT_PATH/tracking/evidence/v1"
bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null || blocked 'Product Profile invalid'

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

matches=()
while IFS= read -r -d '' record; do
  [[ "$(field "$record" check_id)" == pipeline-policy ]] || continue
  [[ "$(field "$record" source_revision)" == "$SOURCE_REVISION" ]] || continue
  matches+=("$record")
done < <(find "$EVIDENCE_DIR" -maxdepth 1 -type f -name '*.yaml' -print0 | sort -z)
(( ${#matches[@]} == 1 )) || blocked "pipeline-policy требует один current record; найдено ${#matches[@]}"
record="${matches[0]}"
verifier_output="$(bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$record" \
  --expected-source "$SOURCE_REVISION" --expected-check pipeline-policy 2>&1)" || {
    printf '%s\n' "$verifier_output" >&2
    blocked 'pipeline-policy evidence FAIL/BLOCKED/UNVERIFIED'
  }
[[ "$(field "$record" verdict)" == PASS ]] || blocked 'pipeline-policy verdict must be PASS'
[[ "$(field "$record" raw_format)" == json ]] || blocked 'executor controls v1 require normalized JSON'
[[ "$(field "$record" policy_revision)" == executor-controls-v1 ]] || blocked 'unsupported executor controls policy revision'
raw_path="$PROJECT_PATH/$(field "$record" raw_result_uri)"

jq -e --arg source "$SOURCE_REVISION" '
  type == "object" and
  ((keys - ["schema_version","check_id","source_revision","controls","remediation"]) | length == 0) and
  .schema_version == 1 and .check_id == "pipeline-policy" and .source_revision == $source and
  (.controls | type == "object") and
  ((.controls | keys) == ["artifact_cache_integrity","immutable_dependencies","least_privilege","protected_policy_files","untrusted_pr_isolation"]) and
  all(.controls[]; . == "pass" or . == "fail" or . == "unknown" or . == "not-applicable") and
  (.remediation | type == "array") and all(.remediation[]; type == "string" and length > 0)
' "$raw_path" >/dev/null || blocked 'invalid normalized executor-controls JSON'

for control in immutable_dependencies least_privilege protected_policy_files artifact_cache_integrity; do
  value="$(jq -r --arg control "$control" '.controls[$control]' "$raw_path")"
  [[ "$value" == pass ]] || blocked "$control=$value; remediation=$(jq -c '.remediation' "$raw_path")"
done
source_profile="$(field "$PROFILE" evidence_source_profile)"
untrusted="$(jq -r '.controls.untrusted_pr_isolation' "$raw_path")"
case "$source_profile" in
  repository-ci|connected-runner)
    [[ "$untrusted" == pass ]] || blocked "untrusted_pr_isolation=$untrusted для $source_profile"
    ;;
  local-offline)
    [[ "$untrusted" == pass || "$untrusted" == not-applicable ]] ||
      blocked "untrusted_pr_isolation=$untrusted для local-offline"
    ;;
esac

echo "EXECUTOR CONTROLS VERIFIED: source=$SOURCE_REVISION profile=$source_profile evidence_id=$(field "$record" evidence_id)"

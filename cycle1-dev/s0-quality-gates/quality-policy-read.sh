#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
REQUESTED_METRIC="${2:?Укажи metric id или --all}"
blocked() { echo "QUALITY POLICY READ BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REGISTRY="$(cd "$SCRIPT_DIR/../.." && pwd -P)/_contract/quality-policy-v1.tsv"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}
trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

quality_output="$(bash "$SCRIPT_DIR/quality-gates-check.sh" "$PROJECT_PATH" 2>&1)" || {
  printf '%s\n' "$quality_output" >&2
  blocked 'effective Quality Policy invalid'
}
policy_revision="$(sed -n 's/.*policy_revision=\([^ ]*\).*/\1/p' <<< "$quality_output" | head -1)"
profile_revision="$(field "$PROFILE" revision)"
[[ -n "$policy_revision" && "$profile_revision" =~ ^[1-9][0-9]*$ ]] ||
  blocked 'policy/profile revision unavailable'

[[ -f "$REGISTRY" && ! -L "$REGISTRY" ]] || blocked 'quality metric registry missing/symlink'
[[ "$(head -1 "$REGISTRY")" == $'metric_id\toperator\tglobal_threshold\tunit' ]] ||
  blocked 'quality metric registry header mismatch'

emit_metric() {
  local metric="$1" registry_operator global_threshold unit threshold operator number policy
  IFS=$'\t' read -r _ registry_operator global_threshold unit extra < <(
    awk -F'\t' -v wanted="$metric" '$1 == wanted {print; found+=1} END {if (found != 1) exit 1}' "$REGISTRY"
  ) || blocked "unknown/duplicate metric id: $metric"
  [[ -z "${extra:-}" && "$registry_operator" =~ ^(\>=|\<=)$ &&
      "$global_threshold" =~ ^[0-9]+([.][0-9]+)?$ &&
      "$unit" =~ ^[A-Za-z][A-Za-z0-9._-]*$ ]] || blocked "invalid registry row: $metric"
  operator="$registry_operator"
  number="$global_threshold"
  policy="$(field "$PROFILE" quality_overrides)"
  if [[ "$policy" == tracking/quality-gates.md ]]; then
    threshold="$(awk -F'|' -v wanted="$metric" '
      { key=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", key) }
      key == wanted { value=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); print value; found+=1 }
      END {if (found != 1) exit 1}
    ' "$PROJECT_PATH/$policy")" || blocked "metric missing/duplicate in effective policy: $metric"
    [[ "$threshold" =~ ^(\>=|\<=)[[:space:]]+([0-9]+([.][0-9]+)?)$ ]] ||
      blocked "invalid effective threshold: $metric"
    operator="${BASH_REMATCH[1]}"
    number="${BASH_REMATCH[2]}"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$metric" "$operator" "$number" "$unit" "$policy_revision" "$profile_revision"
}

if [[ "$REQUESTED_METRIC" == --all ]]; then
  while IFS=$'\t' read -r metric _; do emit_metric "$metric"; done < <(tail -n +2 "$REGISTRY")
else
  [[ "$REQUESTED_METRIC" =~ ^[a-z][a-z0-9_]*$ ]] || blocked 'invalid metric id'
  emit_metric "$REQUESTED_METRIC"
fi

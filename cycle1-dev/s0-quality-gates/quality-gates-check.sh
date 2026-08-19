#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
blocked() { echo "QUALITY POLICY BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
VALIDATOR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../s0-validate" && pwd -P)/product-ci-profile-check.sh"
METADATA_VALIDATOR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../s0-validate" && pwd -P)/artifact-metadata-check.sh"
REGISTRY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)/_contract/quality-policy-v1.tsv"
bash "$VALIDATOR" "$PROJECT_PATH" >/dev/null || blocked 'Product & CI Profile invalid'

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

override="$(field "$PROFILE" quality_overrides)"
profile_revision="$(field "$PROFILE" revision)"
if [[ "$override" == none ]]; then
  echo "QUALITY POLICY VERIFIED: policy_revision=quality-global-v1 product_profile_revision=$profile_revision"
  exit 0
fi
[[ "$override" == tracking/quality-gates.md ]] || blocked 'unsupported quality_overrides path'
POLICY="$PROJECT_PATH/$override"
[[ -f "$POLICY" && ! -L "$POLICY" ]] || blocked 'quality-gates.md absent or symlink'
bash "$METADATA_VALIDATOR" "$PROJECT_PATH" "$override" \
  s0-quality-gates TRACKING quality-policy >/dev/null ||
  blocked 'quality-gates.md violates common Artifact Metadata contract'

for key in schema_version revision previous_revision policy_revision product_profile_revision date tags; do
  value="$(field "$POLICY" "$key")"
  [[ -n "$value" ]] || blocked "missing metadata: $key"
done
[[ "$(field "$POLICY" schema_version)" == 1 ]] || blocked 'schema_version must be 1'
revision="$(field "$POLICY" revision)"
previous="$(field "$POLICY" previous_revision)"
[[ "$revision" =~ ^[1-9][0-9]*$ ]] || blocked 'revision must be positive integer'
[[ "$previous" =~ ^[0-9]+$ && "$previous" -eq $((revision - 1)) ]] || blocked 'invalid previous_revision chain'
policy_revision="$(field "$POLICY" policy_revision)"
[[ "$policy_revision" == "quality-v1-r$revision" ]] || blocked 'policy_revision does not match revision'
[[ "$(field "$POLICY" product_profile_revision)" == "$profile_revision" ]] ||
  blocked 'quality policy bound to another Product Profile revision'
[[ "$(field "$POLICY" date)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || blocked 'date must be YYYY-MM-DD'

snapshot="$PROJECT_PATH/tracking/quality-gates-history/revision-$revision.md"
[[ -f "$snapshot" ]] || blocked "missing immutable snapshot revision-$revision.md"
cmp -s "$POLICY" "$snapshot" || blocked 'quality-gates.md differs from revision snapshot'
if (( revision > 1 )); then
  for ((chain_revision=2; chain_revision<=revision; chain_revision++)); do
    chain_previous=$((chain_revision - 1))
    previous_snapshot="$PROJECT_PATH/tracking/quality-gates-history/revision-$chain_previous.md"
    [[ -f "$previous_snapshot" && ! -L "$previous_snapshot" ]] ||
      blocked "previous policy snapshot missing/symlink: revision-$chain_previous"
    invalidations="$PROJECT_PATH/tracking/quality-policy-invalidations/revision-$chain_revision.md"
    [[ -f "$invalidations" && ! -L "$invalidations" ]] ||
      blocked "policy invalidation record missing/symlink: revision-$chain_revision"
    grep -Fqx "policy_revision: quality-v1-r$chain_revision" "$invalidations" ||
      blocked "invalidation not bound to policy revision $chain_revision"
    grep -Fqx "invalidates: quality-v1-r< $chain_revision" "$invalidations" ||
      blocked "invalidation range mismatch at revision $chain_revision"
    grep -Fqx "previous_snapshot_sha256: $(sha256sum "$previous_snapshot" | awk '{print $1}')" \
      "$invalidations" || blocked "historical snapshot digest mismatch at revision $chain_previous"
  done
fi

[[ -f "$REGISTRY" && ! -L "$REGISTRY" ]] || blocked 'quality metric registry missing/symlink'
[[ "$(head -1 "$REGISTRY")" == $'metric_id\toperator\tglobal_threshold\tunit' ]] ||
  blocked 'quality metric registry header mismatch'
metrics=()
declare -A direction=() global=() registry_operator=() registry_unit=()
while IFS=$'\t' read -r metric operator threshold unit extra; do
  [[ -z "$extra" && "$metric" =~ ^[a-z][a-z0-9_]*$ && "$operator" =~ ^(\>=|\<=)$ &&
      "$threshold" =~ ^[0-9]+([.][0-9]+)?$ && "$unit" =~ ^[A-Za-z][A-Za-z0-9._-]*$ ]] ||
    blocked 'invalid quality metric registry row'
  [[ -z "${global[$metric]+x}" ]] || blocked "duplicate registry metric: $metric"
  metrics+=("$metric")
  registry_operator["$metric"]="$operator"
  global["$metric"]="$threshold"
  registry_unit["$metric"]="$unit"
  [[ "$operator" == '>=' ]] && direction["$metric"]=up || direction["$metric"]=down
done < <(tail -n +2 "$REGISTRY")
(( ${#metrics[@]} == 12 )) || blocked 'quality metric registry must contain exactly 12 metrics'
declare -A seen=()
while IFS='|' read -r _ metric threshold rationale _; do
  metric="$(trim "${metric:-}")"
  [[ " ${metrics[*]} " == *" $metric "* ]] || continue
  [[ -z "${seen[$metric]+x}" ]] || blocked "duplicate metric: $metric"
  seen["$metric"]=1
  threshold="$(trim "${threshold:-}")"
  rationale="$(trim "${rationale:-}")"
  [[ "$threshold" =~ ^(\>=|\<=)[[:space:]]+([0-9]+([.][0-9]+)?)$ ]] || blocked "invalid threshold syntax for $metric: $threshold"
  operator="${BASH_REMATCH[1]}"; number="${BASH_REMATCH[2]}"
  [[ "$operator" == "${registry_operator[$metric]}" ]] || blocked "$metric has wrong direction"
  [[ -n "$rationale" && "$rationale" != '-' ]] || blocked "missing rationale for $metric"
  if [[ "${direction[$metric]}" == up ]]; then
    [[ "$operator" == '>=' ]] || blocked "$metric has wrong direction"
    awk -v value="$number" -v minimum="${global[$metric]}" 'BEGIN { exit !(value >= minimum) }' ||
      blocked "$metric=$number weakens global minimum ${global[$metric]}"
  else
    [[ "$operator" == '<=' ]] || blocked "$metric has wrong direction"
    awk -v value="$number" -v maximum="${global[$metric]}" 'BEGIN { exit !(value <= maximum) }' ||
      blocked "$metric=$number weakens global maximum ${global[$metric]}"
  fi
done < "$POLICY"
for metric in "${metrics[@]}"; do [[ -n "${seen[$metric]:-}" ]] || blocked "missing metric: $metric"; done

if rg -n -i '(akia[0-9a-z]{8,}|gh[pousr]_[a-z0-9]+|password=|token=|secret=)' "$POLICY" >/dev/null; then
  blocked 'secret-like value in quality policy'
fi
echo "QUALITY POLICY VERIFIED: policy_revision=$policy_revision product_profile_revision=$profile_revision"

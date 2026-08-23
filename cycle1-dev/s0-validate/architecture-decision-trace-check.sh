#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
blocked() { echo "ARCHITECTURE TRACE BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
OUTPUTS="$PROJECT_PATH/stage3-design/outputs"

bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Product & CI Profile не прошёл deterministic validation'
[[ -d "$OUTPUTS" ]] || blocked 'stage3-design/outputs отсутствует'

flat_field() {
  local file="$1" wanted="$2"
  awk -v wanted="$wanted" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      key=$0; sub(/:.*/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key == wanted) {
        value=$0; sub(/^[^:]*:[[:space:]]*/, "", value)
        gsub(/[[:space:]]+$/, "", value); print value; exit
      }
    }
  ' "$file"
}

frontmatter_field() {
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

expect_meta() {
  local file="$1" key="$2" expected="$3" actual
  actual="$(frontmatter_field "$file" "$key")"
  [[ "$actual" == "$expected" ]] ||
    blocked "$(basename "$file"): $key должен быть $expected, получено ${actual:-MISSING}"
}

resolve_one_ref() {
  local logical="$1" output
  if ! output="$(bash "$SCRIPT_DIR/current-artifact.sh" \
      resolve-compatible-one "$PROJECT_PATH" "$logical")"; then
    blocked "current artifact resolution failed: $logical"
  fi
  [[ -n "$output" && "$output" != *$'\n'* ]] ||
    blocked "current artifact cardinality invalid: $logical"
  printf '%s\n' "$output"
}

resolve_refs() {
  local logical="$1" output
  if ! output="$(bash "$SCRIPT_DIR/current-artifact.sh" \
      resolve-compatible "$PROJECT_PATH" "$logical")"; then
    blocked "current artifact resolution failed: $logical"
  fi
  [[ -n "$output" ]] || blocked "current artifact set is empty: $logical"
  printf '%s\n' "$output"
}

project_file_from_ref() {
  local ref="$1" path canonical
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != ../* &&
    "$ref" != *'/../'* && "$ref" != */.. ]] || blocked "unsafe current artifact ref: $ref"
  path="$PROJECT_PATH/$ref"
  [[ -f "$path" && ! -L "$path" ]] || blocked "current artifact missing/symlink: $ref"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/"* ]] || blocked "current artifact escapes Project: $ref"
  printf '%s\n' "$path"
}

hld_ref="$(resolve_one_ref high-level-design)"
trace_ref="$(resolve_one_ref architecture-decision-index)"
nfr_ref="$(resolve_one_ref nonfunctional-requirements)"
adr_output="$(resolve_refs architecture-decisions)"
mapfile -t adr_refs <<< "$adr_output"

hld="$(project_file_from_ref "$hld_ref")"
trace="$(project_file_from_ref "$trace_ref")"
nfr_file="$(project_file_from_ref "$nfr_ref")"
adrs=()
for adr_ref in "${adr_refs[@]}"; do
  adrs+=("$(project_file_from_ref "$adr_ref")")
done
nfr_files=("$nfr_file")

runtime_output="$(bash "$SCRIPT_DIR/runtime-constraints-check.sh" \
  "$PROJECT_PATH" architecture 2>&1)" || {
  printf '%s\n' "$runtime_output" >&2
  blocked 'Runtime Constraints v1 trace invalid'
}

for metadata_doc in "$hld" "${adrs[@]}"; do
  metadata_ref="${metadata_doc#"$PROJECT_PATH/"}"
  bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" "$metadata_ref" >/dev/null ||
    blocked "$(basename "$metadata_doc"): common Artifact Metadata invalid"
done
profile_revision="$(flat_field "$PROFILE" revision)"
profile_schema="$(flat_field "$PROFILE" schema_version)"
[[ "$profile_schema" == 3 || "$profile_schema" == 4 || "$profile_schema" == 5 ]] ||
  blocked 'Stage 3 architecture trace требует Product Profile schema_version: 3|4|5'
expect_meta "$hld" schema_version 1
expect_meta "$hld" artifact_type architecture-hld
expect_meta "$hld" owner s3-arch
expect_meta "$hld" product_profile_revision "$profile_revision"
expect_meta "$hld" assumption_policy no-unconfirmed-stack-or-topology
grep -Fq '## Architecture Decision Trace' "$hld" ||
  blocked 'HLD не содержит ## Architecture Decision Trace'

if [[ "$profile_schema" == 5 ]]; then
  quality_output="$(bash "$SCRIPT_DIR/../s0-quality-gates/quality-characteristics-check.sh" "$PROJECT_PATH" 2>&1)" || {
    printf '%s\n' "$quality_output" >&2
    blocked 'Quality Characteristics v1 invalid'
  }
  grep -Fq '## Quality Characteristic Scope' "$hld" ||
    blocked 'HLD не содержит ## Quality Characteristic Scope'
  grep -Fqx 'Reliability scope: REQUIRED' "$hld" || blocked 'Reliability scope должен быть REQUIRED'
  grep -Eq '^Reliability evidence: REL-[A-Za-z0-9._-]+$' "$hld" || blocked 'Reliability evidence id отсутствует'
  grep -Fqx 'Reliability dimensions: maturity,availability,fault-tolerance,recoverability' "$hld" ||
    blocked 'Reliability dimensions incomplete'
  grep -Fqx 'Maintainability scope: REQUIRED' "$hld" || blocked 'Maintainability scope должен быть REQUIRED'
  grep -Eq '^Maintainability evidence: MAINT-[A-Za-z0-9._-]+$' "$hld" || blocked 'Maintainability evidence id отсутствует'
  grep -Fqx 'Maintainability dimensions: modularity,reusability,analysability,modifiability,testability' "$hld" ||
    blocked 'Maintainability dimensions incomplete'

  for binding in \
    'Performance|performance_validation|PERF' \
    'Compatibility|compatibility_validation|COMPAT' \
    'Flexibility|flexibility_validation|FLEX' \
    'Safety|safety_validation|SAFETY'; do
    IFS='|' read -r label profile_key id_prefix <<< "$binding"
    expected="$(flat_field "$PROFILE" "$profile_key")"
    case "$expected" in
      required)
        grep -Fqx "$label scope: REQUIRED" "$hld" || blocked "$label scope должен быть REQUIRED"
        grep -Eq "^$label evidence: $id_prefix-[A-Za-z0-9._-]+$" "$hld" ||
          blocked "$label required evidence id отсутствует"
        if [[ "$label" == Compatibility ]]; then
          grep -Fqx 'Compatibility dimensions: co-existence,interoperability' "$hld" ||
            blocked 'Compatibility dimensions incomplete'
        fi
        if [[ "$label" == Flexibility ]]; then
          grep -Fqx 'Flexibility dimensions: install,update,replaceability,configuration-portability' "$hld" ||
            blocked 'Flexibility dimensions incomplete'
        fi
        ;;
      not-applicable)
        grep -Fqx "$label scope: NOT_APPLICABLE" "$hld" || blocked "$label scope должен быть NOT_APPLICABLE"
        na_line="$(grep -E "^$label evidence: NOT_APPLICABLE: .+" "$hld" || true)"
        [[ -n "$na_line" && ! "${na_line,,}" =~ (unknown|tbd|todo|placeholder) ]] ||
          blocked "$label N/A требует concrete reason"
        ;;
      *) blocked "$label имеет unsupported profile applicability=$expected" ;;
    esac
  done
fi

IFS= read -r header < "$trace" || blocked 'architecture decision trace пуст'
[[ "$header" == $'decision_id\tnfr_id\tquality_attribute_id\ttactic_id\tpattern_id\tadr_id\tadr_uri\tproduct_profile_revision' ]] ||
  blocked 'architecture decision trace имеет неверный header'

declare -A seen_decisions=() seen_adrs=() seen_uris=() current_adr_uris=()
for adr_ref in "${adr_refs[@]}"; do
  current_adr_uris["$adr_ref"]=1
done
row_count=0
while IFS=$'\t' read -r decision_id nfr_id qa_id tactic_id pattern_id adr_id adr_uri row_revision extra ||
  [[ -n "${decision_id}${nfr_id}${qa_id}${tactic_id}${pattern_id}${adr_id}${adr_uri}${row_revision}${extra}" ]]; do
  ((row_count+=1))
  [[ -z "$extra" ]] || blocked "trace row $row_count содержит лишние columns"
  [[ "$decision_id" =~ ^DEC-[A-Z0-9][A-Z0-9_-]*$ ]] || blocked "trace row $row_count: invalid decision_id"
  [[ "$nfr_id" =~ ^NFR-[A-Z0-9][A-Z0-9_-]*$ ]] || blocked "trace row $row_count: invalid nfr_id"
  case "$qa_id" in
    QA-Availability|QA-Reliability|QA-Performance|QA-Security|QA-Usability|QA-InteractionCapability|QA-Maintainability|QA-Portability|QA-Flexibility|QA-Compatibility|QA-Safety|QA-Operability) ;;
    *) blocked "trace row $row_count: unsupported quality_attribute_id=$qa_id" ;;
  esac
  [[ "$tactic_id" =~ ^TACTIC-[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || blocked "trace row $row_count: invalid tactic_id"
  [[ "$pattern_id" =~ ^PATTERN-[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || blocked "trace row $row_count: invalid pattern_id"
  [[ "$adr_id" =~ ^ADR-[A-Z0-9][A-Z0-9_-]*$ ]] || blocked "trace row $row_count: invalid adr_id"
  [[ "$row_revision" == "$profile_revision" ]] || blocked "trace row $row_count связан с другой Product Profile revision"
  [[ "$adr_uri" =~ ^stage3-design/outputs/ARCH-[A-Za-z0-9._-]+-ADR-[A-Za-z0-9_-]+\.md$ ]] ||
    blocked "trace row $row_count: invalid adr_uri"
  [[ -n "${current_adr_uris[$adr_uri]:-}" ]] ||
    blocked "trace row $row_count: ADR is not in the current manifest set: $adr_uri"
  adr_path="$PROJECT_PATH/$adr_uri"
  [[ -f "$adr_path" && ! -L "$adr_path" ]] || blocked "trace row $row_count: ADR отсутствует или symlink"
  canonical="$(readlink -f "$adr_path")"
  [[ "$canonical" == "$OUTPUTS/"* ]] || blocked "trace row $row_count: ADR выходит за пределы outputs"

  nfr_found=0
  for nfr_file in "${nfr_files[@]}"; do
    if grep -Eq "(^|[^A-Za-z0-9_-])${nfr_id}([^A-Za-z0-9_-]|$)" "$nfr_file"; then nfr_found=1; break; fi
  done
  (( nfr_found == 1 )) || blocked "$nfr_id отсутствует в BA NFR"

  for id in "$decision_id" "$nfr_id" "$qa_id" "$tactic_id" "$pattern_id" "$adr_id"; do
    grep -Fq "$id" "$hld" || blocked "$id отсутствует в HLD"
  done

  expect_meta "$adr_path" schema_version 1
  expect_meta "$adr_path" artifact_type architecture-decision
  expect_meta "$adr_path" owner s3-arch
  expect_meta "$adr_path" product_profile_revision "$profile_revision"
  grep -Fqx "Decision ID: $decision_id" "$adr_path" || blocked "$decision_id не связан с exact ADR"
  grep -Fqx "NFR: $nfr_id" "$adr_path" || blocked "$nfr_id не связан с exact ADR"
  grep -Fqx "Quality Attribute: $qa_id" "$adr_path" || blocked "$qa_id не связан с exact ADR"
  grep -Fqx "Tactic: $tactic_id" "$adr_path" || blocked "$tactic_id не связан с exact ADR"
  grep -Fqx "Pattern: $pattern_id" "$adr_path" || blocked "$pattern_id не связан с exact ADR"
  grep -Fqx "ADR: $adr_id" "$adr_path" || blocked "$adr_id не связан с exact ADR"
  grep -Eq '^Trade-off gain:[[:space:]]*[^[:space:]].*$' "$adr_path" || blocked "$adr_id не содержит Trade-off gain"
  grep -Eq '^Trade-off cost:[[:space:]]*[^[:space:]].*$' "$adr_path" || blocked "$adr_id не содержит Trade-off cost"

  [[ -z "${seen_decisions[$decision_id]+x}" ]] || blocked "duplicate decision_id: $decision_id"
  [[ -z "${seen_adrs[$adr_id]+x}" ]] || blocked "duplicate adr_id: $adr_id"
  [[ -z "${seen_uris[$adr_uri]+x}" ]] || blocked "duplicate adr_uri: $adr_uri"
  seen_decisions["$decision_id"]=1
  seen_adrs["$adr_id"]=1
  seen_uris["$adr_uri"]=1
done < <(tail -n +2 "$trace")
(( row_count > 0 )) || blocked 'architecture decision trace не содержит rows'

for adr_file in "${adrs[@]}"; do
  uri="stage3-design/outputs/$(basename "$adr_file")"
  [[ -n "${seen_uris[$uri]:-}" ]] || blocked "ADR artifact не имеет trace row: $uri"
done

mapfile -t hld_adr_ids < <(grep -oE 'ADR-[A-Z0-9][A-Z0-9_-]*' "$hld" | sort -u)
for hld_adr_id in "${hld_adr_ids[@]}"; do
  [[ -n "${seen_adrs[$hld_adr_id]:-}" ]] || blocked "HLD ADR candidate не имеет trace row: $hld_adr_id"
done

if grep -Eiq '(AKIA[0-9A-Z]{8,}|gh[pousr]_[A-Za-z0-9]+|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{8,}|password=|token=|secret=)' \
  "$hld" "$trace" "${adrs[@]}"; then
  blocked 'secret-like value запрещён в architecture artifacts'
fi

echo "ARCHITECTURE TRACE VERIFIED: profile_revision=$profile_revision decisions=$row_count adr_files=${#adrs[@]}"

#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-}"
PROJECT_INPUT="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
REGISTRY="$ROOT/_contract/current-artifact-groups-v1.tsv"
STEPS="$ROOT/_contract/cycle1-steps-v1.tsv"
HEADER=$'schema_version\tlogical_id\tmember_index\tartifact_ref\tartifact_sha256\tproducer\tcommand\toutput_group\tsource_revision\tproduct_profile_revision\trun_id\tplan_sha256\trecorded_at'

blocked() {
  echo "CURRENT ARTIFACT BLOCKED: $*" >&2
  exit 1
}

[[ -n "$MODE" ]] || blocked 'mode is required'
[[ -n "$PROJECT_INPUT" && -d "$PROJECT_INPUT" ]] || blocked 'Project directory is required'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
MANIFEST="$PROJECT_PATH/tracking/current-artifacts-v1.tsv"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
[[ -f "$REGISTRY" && ! -L "$REGISTRY" ]] || blocked 'current artifact registry missing/symlink'
[[ -f "$STEPS" && ! -L "$STEPS" ]] || blocked 'Cycle 1 step registry missing/symlink'

profile_revision() {
  [[ -f "$PROFILE" && ! -L "$PROFILE" ]] || blocked 'Product Profile missing/symlink'
  local revision
  revision="$(awk -F: '$1 == "revision" {
    value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value);
    print value; exit
  }' "$PROFILE")"
  [[ "$revision" =~ ^(0|[1-9][0-9]*)$ ]] || blocked 'invalid Product Profile revision'
  printf '%s\n' "$revision"
}

safe_ref() {
  local ref="$1" path canonical
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != ../* &&
    "$ref" != *'/../'* && "$ref" != */.. ]] || blocked "unsafe artifact_ref: $ref"
  path="$PROJECT_PATH/$ref"
  [[ -f "$path" && ! -L "$path" ]] || blocked "artifact missing/symlink: $ref"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/"* ]] || blocked "artifact escapes Project: $ref"
  printf '%s\n' "$path"
}

path_matches_patterns() {
  local ref="$1" patterns="$2" pattern
  IFS='|' read -r -a pattern_list <<< "$patterns"
  for pattern in "${pattern_list[@]}"; do
    if [[ "$ref" == $pattern ]]; then return 0; fi
  done
  return 1
}

logical_member_key() {
  local logical="$1" ref="$2" base
  base="$(basename "$ref")"
  case "$logical" in
    development-pr-summary)
      base="${base#*PR-}"; base="${base%-summary.md}"
      ;;
    development-update-notes)
      base="${base#*update-notes-PR}"; base="${base%.md}"
      ;;
    techlead-reviews)
      base="${base#*review-PR}"; base="${base%.md}"
      ;;
    *)
      printf '%s\n' "$ref"
      return
      ;;
  esac
  [[ "$base" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
    blocked "$logical has invalid stable PR member key: $ref"
  printf '%s\n' "$base"
}

run_matches_expected() {
  local actual="$1" expected_csv="$2" expected
  [[ -z "$expected_csv" ]] && return 0
  IFS=',' read -r -a expected_runs <<< "$expected_csv"
  for expected in "${expected_runs[@]}"; do
    [[ "$actual" == "$expected" ]] && return 0
  done
  return 1
}

validate_registries() {
  local expected_index=1 step agent command gate_before gate_after dod_after completion_after extra
  local registry_header=$'agent\tcommand\tgroup_index\tlogical_id\tcardinality\ttrack_current\tpath_patterns'
  [[ "$(head -1 "$REGISTRY")" == "$registry_header" ]] ||
    blocked 'current artifact registry header mismatch'
  awk -F'\t' '
    NR == 1 { next }
    NF != 7 ||
    $1 !~ /^[a-z0-9][a-z0-9-]*$/ ||
    $2 !~ /^\/[a-z0-9][a-z0-9-]*$/ ||
    $3 !~ /^[1-9][0-9]*$/ ||
    $4 !~ /^[a-z0-9][a-z0-9-]*$/ ||
    ($5 != "one" && $5 != "one-or-more") ||
    ($6 != "yes" && $6 != "no") ||
    $7 == "" { exit 1 }
  ' "$REGISTRY" || blocked 'invalid current artifact registry row'
  while IFS=$'\t' read -r step agent command gate_before gate_after dod_after completion_after extra; do
    [[ -z "$extra" && "$step" == "$expected_index" &&
      "$agent" =~ ^[a-z0-9][a-z0-9-]*$ && "$command" =~ ^/[a-z0-9][a-z0-9-]*$ ]] ||
      blocked 'invalid/non-sequential Cycle 1 step registry'
    case "$gate_before" in none|1|2|3|4|5) ;; *) blocked 'invalid gate_before' ;; esac
    case "$gate_after" in none|1|2|3|4|5) ;; *) blocked 'invalid gate_after' ;; esac
    case "$dod_after" in none|full) ;; *) blocked 'invalid dod_after' ;; esac
    case "$completion_after" in none|full) ;; *) blocked 'invalid completion_after' ;; esac
    expected_index=$((expected_index + 1))
  done < <(tail -n +2 "$STEPS")
  [[ $expected_index -eq 29 ]] || blocked 'Cycle 1 registry must contain exactly 28 steps'
}

artifact_source_revision() {
  local path="$1" ref="$2" value=''
  case "$ref" in
    *.json)
      if command -v jq >/dev/null 2>&1; then
        value="$(jq -r '.source_revision // empty' "$path" 2>/dev/null || true)"
      fi
      ;;
    *.tsv)
      value="$(awk -F'\t' '
        NR == 1 {
          for (i=1; i<=NF; i++) if ($i == "source_revision") column=i
          next
        }
        column && $column != "" { values[$column]=1 }
        END {
          count=0
          for (value in values) { selected=value; count++ }
          if (count == 1) print selected
        }
      ' "$path")"
      ;;
    *)
      value="$(awk -F: '$1 == "source_revision" {
        result=$0; sub(/^[^:]*:[[:space:]]*/, "", result);
        sub(/[[:space:]]+$/, "", result); print result; exit
      }' "$path")"
      ;;
  esac
  [[ -n "$value" ]] || value=none
  [[ "$value" == none || "$value" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
    blocked "$ref has invalid source_revision"
  printf '%s\n' "$value"
}

validate_manifest() {
  local ignored_csv="${1:-}" ignored_id
  local revision line schema logical member ref digest producer command group source row_profile
  local run_id plan_sha recorded extra path patterns cardinality track count expected_member
  local member_key
  declare -A seen=() seen_member_key=() counts=() cardinalities=() ignored=()
  if [[ -n "$ignored_csv" ]]; then
    IFS=',' read -r -a ignored_ids <<< "$ignored_csv"
    for ignored_id in "${ignored_ids[@]}"; do
      [[ "$ignored_id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || blocked 'invalid ignored logical id'
      ignored["$ignored_id"]=1
    done
  fi
  [[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] || blocked 'current artifact manifest missing/symlink'
  [[ "$(head -1 "$MANIFEST")" == "$HEADER" ]] || blocked 'current artifact manifest header mismatch'
  revision="$(profile_revision)"
  while IFS=$'\t' read -r schema logical member ref digest producer command group source row_profile \
    run_id plan_sha recorded extra; do
    [[ -n "$schema" ]] || continue
    [[ -z "$extra" && "$schema" == 1 &&
      "$logical" =~ ^[a-z0-9][a-z0-9-]*$ &&
      "$member" =~ ^[1-9][0-9]*$ &&
      "$digest" =~ ^[0-9a-f]{64}$ &&
      "$producer" =~ ^[a-z0-9][a-z0-9-]*$ &&
      "$command" =~ ^/[a-z0-9][a-z0-9-]*$ &&
      "$group" =~ ^[1-9][0-9]*$ &&
      "$row_profile" == "$revision" &&
      "$run_id" =~ ^[A-Za-z0-9._-]+$ &&
      "$plan_sha" =~ ^[0-9a-f]{64}$ &&
      "$recorded" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
      blocked "invalid manifest row: ${logical:-UNKNOWN}"
    [[ "$source" == none || "$source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
      blocked "$logical has invalid source_revision"
    [[ -z "${seen[$logical:$member]+x}" ]] || blocked "duplicate logical member: $logical:$member"
    seen["$logical:$member"]=1
    member_key="$(logical_member_key "$logical" "$ref")"
    [[ -z "${seen_member_key[$logical:$member_key]+x}" ]] ||
      blocked "duplicate stable logical member key: $logical:$member_key"
    seen_member_key["$logical:$member_key"]=1
    if [[ -n "${ignored[$logical]:-}" ]]; then
      [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != ../* &&
        "$ref" != *'/../'* && "$ref" != */.. ]] || blocked "unsafe artifact_ref: $ref"
    else
      path="$(safe_ref "$ref")"
      [[ "$(sha256sum "$path" | awk '{print $1}')" == "$digest" ]] ||
        blocked "artifact digest mismatch: $ref"
    fi
    IFS=$'\t' read -r patterns cardinality track < <(
      awk -F'\t' -v producer="$producer" -v command="$command" -v group="$group" \
        -v logical="$logical" '
        NR > 1 && $1 == producer && $2 == command && $3 == group && $4 == logical {
          print $7 "\t" $5 "\t" $6; exit
        }
      ' "$REGISTRY"
    )
    [[ -n "${patterns:-}" && "$track" == yes ]] ||
      blocked "$logical is not a tracked registered output"
    path_matches_patterns "$ref" "$patterns" ||
      blocked "$logical ref does not match registered patterns: $ref"
    counts["$logical"]=$(( ${counts[$logical]:-0} + 1 ))
    cardinalities["$logical"]="$cardinality"
  done < <(tail -n +2 "$MANIFEST")
  for logical in "${!counts[@]}"; do
    count="${counts[$logical]}"
    [[ "${cardinalities[$logical]}" == one-or-more || "$count" -eq 1 ]] ||
      blocked "$logical requires exactly one current member"
    expected_member=1
    while (( expected_member <= count )); do
      [[ -n "${seen[$logical:$expected_member]:-}" ]] ||
        blocked "$logical member_index is not contiguous"
      expected_member=$((expected_member + 1))
    done
  done
}

resolve_manifest() {
  local logical="$1" expected_run="${2:-}" expected_source="${3:-}" count=0
  validate_manifest
  while IFS=$'\t' read -r ref run_id source; do
    [[ -n "$ref" ]] || continue
    run_matches_expected "$run_id" "$expected_run" ||
      blocked "$logical belongs to run $run_id, expected one of $expected_run"
    [[ -z "$expected_source" || "$source" == none || "$source" == "$expected_source" ]] ||
      blocked "$logical belongs to source $source, expected $expected_source"
    printf '%s\n' "$ref"
    count=$((count + 1))
  done < <(awk -F'\t' -v logical="$logical" 'NR > 1 && $2 == logical {
    print $4 "\t" $11 "\t" $9
  }' "$MANIFEST")
  (( count > 0 )) || blocked "logical artifact is not current: $logical"
}

resolve_compatible() {
  local logical="$1" expected_run="${2:-}" expected_source="${3:-}"
  local cardinality='' patterns pattern ref
  local -a refs=()
  if [[ -e "$MANIFEST" ]]; then
    resolve_manifest "$logical" "$expected_run" "$expected_source"
    return
  fi
  while IFS=$'\t' read -r row_cardinality row_patterns; do
    [[ -n "$row_cardinality" ]] || continue
    if [[ -n "$cardinality" && "$cardinality" != "$row_cardinality" ]]; then
      blocked "$logical has inconsistent registry cardinality"
    fi
    cardinality="$row_cardinality"
    IFS='|' read -r -a pattern_list <<< "$row_patterns"
    for pattern in "${pattern_list[@]}"; do
      while IFS= read -r -d '' ref; do refs+=("${ref#"$PROJECT_PATH/"}"); done < <(
        find "$PROJECT_PATH" -type f -path "$PROJECT_PATH/$pattern" -print0 2>/dev/null
      )
    done
  done < <(awk -F'\t' -v logical="$logical" 'NR > 1 && $4 == logical && $6 == "yes" {
    print $5 "\t" $7
  }' "$REGISTRY")
  [[ -n "$cardinality" ]] || blocked "unknown logical artifact: $logical"
  mapfile -t refs < <(printf '%s\n' "${refs[@]}" | sed '/^$/d' | sort -u)
  (( ${#refs[@]} > 0 )) || blocked "legacy artifact absent: $logical"
  [[ "$cardinality" == one-or-more || ${#refs[@]} -eq 1 ]] ||
    blocked "$logical legacy compatibility is ambiguous: ${#refs[@]} matches"
  echo "CURRENT ARTIFACT LEGACY / UNVERIFIED: $logical resolved by unique registered naming" >&2
  printf '%s\n' "${refs[@]}"
}

update_manifest() {
  local agent="${3:-}" task="${4:-}" run_id="${5:-}" plan_sha="${6:-}" changed_csv="${7:-}"
  local command="${task%% *}" revision recorded row group logical cardinality track patterns
  local ref path source member manifest_revision=''
  local ignored_logical_ids=''
  local -a changed_refs=() selected=() new_rows=()
  local member_key existing_ref existing_key
  declare -A replaced=() replaced_member=() selected_member=() touched=()
  [[ "$agent" =~ ^[a-z0-9][a-z0-9-]*$ && "$command" =~ ^/[a-z0-9][a-z0-9-]*$ ]] ||
    blocked 'invalid producer/command'
  [[ "$run_id" =~ ^[A-Za-z0-9._-]+$ ]] || blocked 'invalid run_id'
  [[ "$plan_sha" =~ ^[0-9a-f]{64}$ ]] || blocked 'invalid plan_sha256'
  [[ -n "$changed_csv" ]] || blocked 'changed refs are required'
  IFS=',' read -r -a changed_refs <<< "$changed_csv"
  revision="$(profile_revision)"
  recorded="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ -f "$MANIFEST" && ! -L "$MANIFEST" ]]; then
    manifest_revision="$(awk -F'\t' 'NR == 2 {print $10; exit}' "$MANIFEST")"
  fi
  while IFS=$'\t' read -r group logical cardinality track patterns; do
    [[ -n "$group" ]] || continue
    selected=()
    IFS='|' read -r -a pattern_list <<< "$patterns"
    for ref in "${changed_refs[@]}"; do
      for pattern in "${pattern_list[@]}"; do
        if [[ "$ref" == $pattern ]]; then selected+=("$ref"); break; fi
      done
    done
    mapfile -t selected < <(printf '%s\n' "${selected[@]}" | sed '/^$/d' | sort -u)
    (( ${#selected[@]} > 0 )) || blocked "$logical output group was not changed"
    [[ "$cardinality" == one-or-more || ${#selected[@]} -eq 1 ]] ||
      blocked "$logical requires exactly one changed current artifact"
    [[ "$track" == yes ]] || continue
    touched["$logical"]=1
    if [[ "$cardinality" == one ]]; then
      replaced["$logical"]=1
    elif [[ "$manifest_revision" == "$revision" ]]; then
      for ref in "${selected[@]}"; do
        member_key="$(logical_member_key "$logical" "$ref")"
        [[ -z "${selected_member[$logical:$member_key]:-}" ]] ||
          blocked "$logical invocation contains duplicate stable member key: $member_key"
        selected_member["$logical:$member_key"]=1
        if awk -F'\t' -v logical="$logical" -v ref="$ref" 'NR > 1 && $2 == logical && $4 == ref {found=1} END {exit(found ? 0 : 1)}' "$MANIFEST"; then
          blocked "$logical member already current; create a new immutable artifact instead of overwriting $ref"
        fi
        while IFS= read -r existing_ref; do
          [[ -n "$existing_ref" ]] || continue
          existing_key="$(logical_member_key "$logical" "$existing_ref")"
          if [[ "$existing_key" == "$member_key" ]]; then
            replaced_member["$logical:$member_key"]=1
          fi
        done < <(awk -F'\t' -v logical="$logical" 'NR > 1 && $2 == logical {print $4}' "$MANIFEST")
      done
    else
      for ref in "${selected[@]}"; do
        member_key="$(logical_member_key "$logical" "$ref")"
        [[ -z "${selected_member[$logical:$member_key]:-}" ]] ||
          blocked "$logical invocation contains duplicate stable member key: $member_key"
        selected_member["$logical:$member_key"]=1
      done
    fi
    member=0
    for ref in "${selected[@]}"; do
      member=$((member + 1))
      path="$(safe_ref "$ref")"
      source="$(artifact_source_revision "$path" "$ref")"
      new_rows+=("1"$'\t'"$logical"$'\t'"$member"$'\t'"$ref"$'\t'"$(sha256sum "$path" | awk '{print $1}')"$'\t'"$agent"$'\t'"$command"$'\t'"$group"$'\t'"$source"$'\t'"$revision"$'\t'"$run_id"$'\t'"$plan_sha"$'\t'"$recorded")
    done
  done < <(awk -F'\t' -v agent="$agent" -v command="$command" '
    NR > 1 && $1 == agent && $2 == command { print $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 }
  ' "$REGISTRY")
  (( ${#new_rows[@]} > 0 )) || {
    # A registered no-current command still has its declared outputs verified by the launcher.
    awk -F'\t' -v agent="$agent" -v command="$command" \
      'NR > 1 && $1 == agent && $2 == command { found=1 } END { exit(found ? 0 : 1) }' "$REGISTRY" ||
      blocked "command has no registered output groups: $agent $command"
    return 0
  }
  mkdir -p "$PROJECT_PATH/tracking"
  if [[ -f "$MANIFEST" && ! -L "$MANIFEST" ]]; then
    if [[ -z "$manifest_revision" || "$manifest_revision" == "$revision" ]]; then
      ignored_logical_ids="$(printf '%s\n' "${!replaced[@]}" | sort | paste -sd, -)"
      validate_manifest "$ignored_logical_ids"
    fi
  elif [[ -e "$MANIFEST" ]]; then
    blocked 'current artifact manifest is not a regular file'
  fi
  local tmp data_tmp
  tmp="$(mktemp "$PROJECT_PATH/tracking/.current-artifacts-v1.XXXXXX")"
  data_tmp="$(mktemp "$PROJECT_PATH/tracking/.current-artifacts-data.XXXXXX")"
  : > "$data_tmp"
  if [[ -f "$MANIFEST" && "$manifest_revision" == "$revision" ]]; then
    while IFS=$'\t' read -r schema logical member ref digest producer row_command group source \
      row_profile row_run row_plan row_recorded extra; do
      [[ -n "$schema" ]] || continue
      [[ -z "$extra" ]] || blocked "invalid manifest row while updating: $logical"
      member_key="$(logical_member_key "$logical" "$ref")"
      if [[ -n "${replaced[$logical]:-}" ||
        -n "${replaced_member[$logical:$member_key]:-}" ]]; then
        continue
      fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$schema" "$logical" "$member" "$ref" "$digest" "$producer" "$row_command" \
        "$group" "$source" "$row_profile" "$row_run" "$row_plan" "$row_recorded" >> "$data_tmp"
    done < <(tail -n +2 "$MANIFEST")
  fi
  printf '%s\n' "${new_rows[@]}" >> "$data_tmp"
  {
    printf '%s\n' "$HEADER"
    sort -t $'\t' -k2,2 -k4,4 "$data_tmp" |
      awk -F'\t' 'BEGIN {OFS=FS} {$3=++member[$2]; print}'
  } > "$tmp"
  mv "$tmp" "$MANIFEST"
  rm -f "$data_tmp"
  validate_manifest
  printf 'CURRENT ARTIFACTS UPDATED: run=%s manifest_sha256=%s logical_ids=' \
    "$run_id" "$(sha256sum "$MANIFEST" | awk '{print $1}')"
  printf '%s\n' "${!touched[@]}" | sort | paste -sd, -
}

begin_run() {
  local run_id="${3:-}" plan_sha="${4:-}" tmp revision manifest_revision=''
  [[ "$run_id" =~ ^[A-Za-z0-9._-]+$ ]] || blocked 'begin-run requires a valid run_id'
  [[ "$plan_sha" =~ ^[0-9a-f]{64}$ ]] || blocked 'begin-run requires plan_sha256'
  revision="$(profile_revision)"
  mkdir -p "$PROJECT_PATH/tracking"
  if [[ -f "$MANIFEST" && ! -L "$MANIFEST" ]]; then
    [[ "$(head -1 "$MANIFEST")" == "$HEADER" ]] ||
      blocked 'current artifact manifest header mismatch'
    manifest_revision="$(awk -F'\t' 'NR == 2 {print $10; exit}' "$MANIFEST")"
    if [[ -z "$manifest_revision" || "$manifest_revision" == "$revision" ]]; then
      validate_manifest
    fi
  elif [[ -e "$MANIFEST" ]]; then
    blocked 'current artifact manifest is not a regular file'
  fi
  tmp="$(mktemp "$PROJECT_PATH/tracking/.current-artifacts-v1.XXXXXX")"
  printf '%s\n' "$HEADER" > "$tmp"
  mv "$tmp" "$MANIFEST"
  printf 'CURRENT ARTIFACT RUN STARTED: run=%s plan_sha256=%s manifest_sha256=%s\n' \
    "$run_id" "$plan_sha" "$(sha256sum "$MANIFEST" | awk '{print $1}')"
}

validate_run() {
  local run_ids="${3:-}" expected_source="${4:-}" logical row_count
  local -a required=()
  [[ "$run_ids" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]] ||
    blocked 'validate-run requires one run_id or an ordered run_id chain'
  validate_manifest
  mapfile -t required < <(
    awk -F'\t' '
      FNR == NR { if (NR > 1) mandatory[$2 SUBSEP $3]=1; next }
      FNR > 1 && $6 == "yes" && (($1 SUBSEP $2) in mandatory) { print $4 }
    ' "$STEPS" "$REGISTRY" | sort -u
  )
  (( ${#required[@]} > 0 )) || blocked 'no mandatory current artifacts resolved from registries'
  for logical in "${required[@]}"; do
    row_count="$(awk -F'\t' -v logical="$logical" -v runs="$run_ids" \
      -v source="$expected_source" '
      BEGIN {
        count_runs=split(runs, run_list, ",")
        for (i=1; i<=count_runs; i++) allowed[run_list[i]]=1
      }
      NR > 1 && $2 == logical && ($11 in allowed) &&
        (source == "" || $9 == "none" || $9 == source) { count++ }
      END { print count+0 }
    ' "$MANIFEST")"
    (( row_count > 0 )) || blocked "$logical is not bound to the full-cycle run chain/source"
  done
  echo "CURRENT ARTIFACT RUN CHAIN VERIFIED: runs=$run_ids logical_ids=${#required[@]}"
}

validate_registries
case "$MODE" in
  validate) validate_manifest ;;
  begin-run) begin_run "$@" ;;
  update) update_manifest "$@" ;;
  resolve)
    [[ -n "${3:-}" ]] || blocked 'logical_id is required'
    resolve_manifest "$3" "${4:-}" "${5:-}"
    ;;
  resolve-one)
    [[ -n "${3:-}" ]] || blocked 'logical_id is required'
    mapfile -t resolved < <(resolve_manifest "$3" "${4:-}" "${5:-}")
    (( ${#resolved[@]} == 1 )) || blocked "$3 expected one current member, found ${#resolved[@]}"
    printf '%s\n' "${resolved[0]}"
    ;;
  resolve-compatible)
    [[ -n "${3:-}" ]] || blocked 'logical_id is required'
    resolve_compatible "$3" "${4:-}" "${5:-}"
    ;;
  resolve-compatible-one)
    [[ -n "${3:-}" ]] || blocked 'logical_id is required'
    mapfile -t resolved < <(resolve_compatible "$3" "${4:-}" "${5:-}")
    (( ${#resolved[@]} == 1 )) || blocked "$3 expected one compatible member, found ${#resolved[@]}"
    printf '%s\n' "${resolved[0]}"
    ;;
  validate-run) validate_run "$@" ;;
  *) blocked "unsupported mode: $MODE" ;;
esac

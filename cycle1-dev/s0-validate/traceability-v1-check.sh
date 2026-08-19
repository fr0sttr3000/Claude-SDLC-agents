#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
RECORD_INPUT="${2:?Укажи Evidence v1 record}"
blocked() { echo "TRACE BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$RECORD_INPUT" == /* ]] || RECORD_INPUT="$PROJECT_PATH/$RECORD_INPUT"
[[ -f "$RECORD_INPUT" && ! -L "$RECORD_INPUT" ]] || blocked 'evidence record absent or symlink'
INDEX="$PROJECT_PATH/tracking/traceability-v1.tsv"
[[ -f "$INDEX" && ! -L "$INDEX" ]] || blocked 'tracking/traceability-v1.tsv absent or symlink'

field() {
  local wanted="$1"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$RECORD_INPUT"
}
requirements="$(field requirement_ids)"
specifications="$(field specification_ids)"
tests="$(field test_ids)"
source_revision="$(field source_revision)"
[[ -n "$requirements" && -n "$specifications" && -n "$tests" && -n "$source_revision" ]] ||
  blocked 'evidence trace fields incomplete'
IFS=',' read -r -a requirement_ids <<< "$requirements"
IFS=',' read -r -a specification_ids <<< "$specifications"
IFS=',' read -r -a test_ids <<< "$tests"
(( ${#requirement_ids[@]} == ${#specification_ids[@]} && ${#requirement_ids[@]} == ${#test_ids[@]} )) ||
  blocked 'trace id lists must have equal length'

IFS= read -r header < "$INDEX" || blocked 'empty trace index'
expected_header=$'requirement_id\trequirement_uri\tspecification_id\tspecification_uri\ttest_id\ttest_uri\tsource_revision'
[[ "$header" == "$expected_header" ]] || blocked 'invalid trace index header'

validate_uri() {
  local uri="$1" id="$2" path canonical
  [[ "$uri" =~ ^[A-Za-z0-9._/-]+$ && "$uri" != /* && "$uri" != '..' && "$uri" != ../* &&
    "$uri" != */../* && "$uri" != */.. ]] || blocked "unsafe artifact uri: $uri"
  path="$PROJECT_PATH/$uri"
  [[ -f "$path" && ! -L "$path" ]] || blocked "dangling/symlink artifact uri: $uri"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/"* ]] || blocked "artifact uri outside Project: $uri"
  grep -Fq -- "$id" "$canonical" || blocked "artifact $uri does not contain id=$id"
}

declare -A rows=()
line_no=1
while IFS=$'\t' read -r req req_uri spec spec_uri test test_uri source extra ||
  [[ -n "${req:-}${req_uri:-}${spec:-}${spec_uri:-}${test:-}${test_uri:-}${source:-}${extra:-}" ]]; do
  line_no=$((line_no + 1))
  [[ -n "$req" && -n "$req_uri" && -n "$spec" && -n "$spec_uri" && -n "$test" && -n "$test_uri" && -n "$source" && -z "${extra:-}" ]] ||
    blocked "invalid row at line $line_no"
  for id in "$req" "$spec" "$test"; do
    [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || blocked "invalid trace id at line $line_no: $id"
  done
  key="$req"$'\t'"$spec"$'\t'"$test"$'\t'"$source"
  [[ -z "${rows[$key]+x}" ]] || blocked "duplicate trace tuple at line $line_no"
  rows["$key"]="$req_uri"$'\t'"$spec_uri"$'\t'"$test_uri"
done < <(tail -n +2 "$INDEX")

for ((i=0; i<${#requirement_ids[@]}; i++)); do
  req="${requirement_ids[$i]}"; spec="${specification_ids[$i]}"; test="${test_ids[$i]}"
  key="$req"$'\t'"$spec"$'\t'"$test"$'\t'"$source_revision"
  [[ -n "${rows[$key]:-}" ]] || blocked "missing exact trace tuple: $req -> $spec -> $test -> $source_revision"
  IFS=$'\t' read -r req_uri spec_uri test_uri <<< "${rows[$key]}"
  validate_uri "$req_uri" "$req"
  validate_uri "$spec_uri" "$spec"
  validate_uri "$test_uri" "$test"
done

echo "TRACE VERIFIED: source=$source_revision tuples=${#requirement_ids[@]}"

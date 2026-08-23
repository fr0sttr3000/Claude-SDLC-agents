#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
blocked() { echo "QA REQUIREMENTS REVIEW BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
PROFILE="$PROJECT/tracking/product-ci-profile.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

resolve_one_ref() {
  local logical="$1" output
  if ! output="$(bash "$SCRIPT_DIR/current-artifact.sh" \
      resolve-compatible-one "$PROJECT" "$logical")"; then
    blocked "current artifact resolution failed: $logical"
  fi
  [[ -n "$output" && "$output" != *$'\n'* ]] ||
    blocked "current artifact cardinality invalid: $logical"
  printf '%s\n' "$output"
}

project_file_from_ref() {
  local ref="$1" path canonical
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != ../* &&
    "$ref" != *'/../'* && "$ref" != */.. ]] || blocked "unsafe current artifact ref: $ref"
  path="$PROJECT/$ref"
  [[ -f "$path" && ! -L "$path" ]] || blocked "current artifact missing/symlink: $ref"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT/"* ]] || blocked "current artifact escapes Project: $ref"
  printf '%s\n' "$path"
}

decision_ref="$(resolve_one_ref qa-requirements-decision)"
current_review_ref="$(resolve_one_ref qa-requirements-review)"
record="$(project_file_from_ref "$decision_ref")"
current_review="$(project_file_from_ref "$current_review_ref")"

field() { awk -F: -v k="$2" '$1==k {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$1"; }
expected='schema_version review_id status project owner product_profile_revision reviewed_at review_ref review_sha256 blocker_count'
declare -A seen=()
while IFS=: read -r key value; do
  [[ -n "$key" && "$key" != *' '* ]] || continue
  [[ " $expected " == *" $key "* ]] || blocked "unknown field: $key"
  [[ -z "${seen[$key]+x}" ]] || blocked "duplicate field: $key"
  seen["$key"]=1
done < "$record"
for key in $expected; do [[ -n "${seen[$key]:-}" ]] || blocked "missing field: $key"; done

[[ "$(field "$record" schema_version)" == 1 ]] || blocked 'schema_version должен быть 1'
[[ "$(field "$record" status)" == PASS ]] || blocked 'status должен быть PASS'
[[ "$(field "$record" project)" == "$(basename "$PROJECT")" ]] || blocked 'project mismatch'
[[ "$(field "$record" owner)" == s2-qa-req ]] || blocked 'owner должен быть s2-qa-req'
[[ "$(field "$record" blocker_count)" == 0 ]] || blocked 'blocker_count должен быть 0'
revision="$(field "$PROFILE" revision)"
[[ -n "$revision" && "$(field "$record" product_profile_revision)" == "$revision" ]] ||
  blocked 'Product Profile revision mismatch'
ref="$(field "$record" review_ref)"
[[ "$ref" =~ ^stage2-requirements/outputs/QA-REQ-[A-Za-z0-9._-]+-review\.md$ ]] ||
  blocked 'invalid review_ref'
[[ "$ref" == "$current_review_ref" ]] || blocked 'review_ref не является current QA review'
review="$current_review"
[[ -f "$review" && ! -L "$review" ]] || blocked 'current QA review отсутствует или symlink'
actual="$(sha256sum "$review" | awk '{print $1}')"
[[ "$(field "$record" review_sha256)" == "$actual" ]] || blocked 'review digest mismatch'
grep -Fq 'QA contribution: PASS' "$review" || blocked 'review не содержит QA contribution: PASS'

echo "QA REQUIREMENTS REVIEW VERIFIED: id=$(field "$record" review_id) profile_revision=$revision"

#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
EXPECTED_STATUS="${2:-}"
blocked() { echo "TDD STATUS BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
STATUS_FILE="$PROJECT_PATH/stage4-dev/outputs/QA-TDD-status.md"
[[ -f "$STATUS_FILE" && ! -L "$STATUS_FILE" ]] || blocked 'QA-TDD-status.md отсутствует или является symlink'
frontmatter_end="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$STATUS_FILE")"
[[ "$(head -1 "$STATUS_FILE")" == --- && "$frontmatter_end" =~ ^[0-9]+$ ]] ||
  blocked 'QA-TDD-status.md requires Artifact Metadata frontmatter'

fields=(
  schema_version artifact_id artifact_type project stage producer status inputs outputs tags
  scope source_revision test_command red_evidence last_run
  failed_tests repair_iteration regression_scope affected_test_manifest
  affected_test_manifest_sha256 expected_test_count executed_test_count
)
declare -A allowed=() values=()
for key in "${fields[@]}"; do allowed["$key"]=1; done

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" == *:* ]] || blocked "некорректная строка без key:value: $line"
  key="${line%%:*}"; value="${line#*:}"
  key="${key#${key%%[![:space:]]*}}"; key="${key%${key##*[![:space:]]}}"
  value="${value#${value%%[![:space:]]*}}"; value="${value%${value##*[![:space:]]}}"
  [[ -n "${allowed[$key]:-}" ]] || blocked "unknown field: $key"
  [[ -z "${values[$key]+x}" ]] || blocked "duplicate field: $key"
  [[ -n "$value" ]] || blocked "empty field: $key"
  values["$key"]="$value"
done < <(sed -n "2,$((frontmatter_end - 1))p" "$STATUS_FILE")
for key in "${fields[@]}"; do
  [[ -n "${values[$key]:-}" ]] || blocked "missing field: $key"
done

[[ "${values[schema_version]}" == 1 ]] || blocked 'поддерживается только schema_version: 1'
[[ "${values[artifact_type]}" == tdd-status && "${values[stage]}" == S4 &&
    "${values[producer]}" == s4-qa-auto ]] || blocked 'TDD status metadata owner/type/stage mismatch'
bash "$(dirname "${BASH_SOURCE[0]}")/artifact-metadata-check.sh" "$PROJECT_PATH" \
  'stage4-dev/outputs/QA-TDD-status.md' >/dev/null || blocked 'common Artifact Metadata invalid'
case "${values[status]}" in RED|PASS|FAIL|BLOCKED) ;; *) blocked 'invalid status' ;; esac
[[ -z "$EXPECTED_STATUS" || "${values[status]}" == "$EXPECTED_STATUS" ]] ||
  blocked "ожидался status=$EXPECTED_STATUS, получено ${values[status]}"
[[ "${values[project]}" != unknown && "${values[project]}" != none ]] || blocked 'project должен быть явным'
[[ "${values[scope]}" =~ ^[A-Z][A-Z0-9]*-[A-Za-z0-9._-]+(,[A-Z][A-Z0-9]*-[A-Za-z0-9._-]+)*$ ]] ||
  blocked 'scope должен быть comma-separated набором requirement/change ids'
[[ "${values[source_revision]}" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  blocked 'source_revision должен быть exact immutable revision'
[[ "${values[test_command]}" != unknown && "${values[test_command]}" != none ]] || blocked 'test_command должен быть exact command'
[[ "${values[last_run]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  blocked 'last_run должен быть ISO-8601 UTC'
for key in failed_tests repair_iteration expected_test_count executed_test_count; do
  [[ "${values[$key]}" =~ ^[0-9]+$ ]] || blocked "$key должен быть non-negative integer"
done

lower_all="${values[*],,}"
[[ ! "$lower_all" =~ (akia[0-9a-z]{8,}|gh[pousr]_[a-z0-9]+|(^|[^a-z0-9])sk-[a-z0-9]{8,}|password=|token=|secret=) ]] ||
  blocked 'secret-like value запрещён в QA-TDD-status.md'

case "${values[status]}" in
  RED)
    [[ "${values[regression_scope]}" == not-yet-run ]] || blocked 'RED требует regression_scope: not-yet-run'
    [[ "${values[red_evidence]}" != none && "${values[red_evidence]}" != unknown ]] || blocked 'RED требует functional red_evidence'
    red_evidence_lower="${values[red_evidence],,}"
    [[ ! "$red_evidence_lower" =~ (environment|infrastructure|setup[[:space:]_-]*fail|runner[[:space:]_-]*(did[[:space:]]+not|failed)|tool[[:space:]_-]*missing|dependency[[:space:]_-]*unavailable|permission[[:space:]_-]*denied|network[[:space:]_-]*error) ]] ||
      blocked 'RED должен быть expected functional/test failure, а не environment/setup failure'
    [[ "$red_evidence_lower" =~ (expected|assert|test|failing|failure|ошиб|паден|тест) ]] ||
      blocked 'RED evidence не доказывает ожидаемое функциональное падение теста'
    [[ "${values[affected_test_manifest]}" == none && "${values[affected_test_manifest_sha256]}" == none ]] ||
      blocked 'RED не должен заявлять post-Green affected manifest'
    (( values[failed_tests] == 0 && values[expected_test_count] == 0 && values[executed_test_count] == 0 )) ||
      blocked 'RED post-Green counters должны быть zero'
    echo "TDD STATUS VERIFIED: status=RED source=${values[source_revision]} scope=${values[scope]}"
    exit 0
    ;;
  BLOCKED)
    case "${values[regression_scope]}" in not-yet-run|partial|full-affected) ;; *) blocked 'invalid BLOCKED regression_scope' ;; esac
    echo "TDD STATUS VERIFIED: status=BLOCKED source=${values[source_revision]} scope=${values[scope]}"
    [[ "$EXPECTED_STATUS" == BLOCKED ]] && exit 0
    blocked 'status=BLOCKED не закрывает workflow/gate'
    ;;
  PASS|FAIL)
    [[ "${values[regression_scope]}" == full-affected ]] ||
      blocked "${values[status]} требует regression_scope: full-affected; selective/partial запрещён"
    ;;
esac

manifest_uri="${values[affected_test_manifest]}"
[[ "$manifest_uri" == stage4-dev/outputs/QA-affected-tests-v1.tsv ]] || blocked 'invalid affected_test_manifest path'
manifest="$PROJECT_PATH/$manifest_uri"
[[ -f "$manifest" && ! -L "$manifest" ]] || blocked 'affected test manifest отсутствует или является symlink'
[[ "${values[affected_test_manifest_sha256]}" =~ ^[0-9a-f]{64}$ ]] || blocked 'invalid affected manifest digest'
actual_sha="$(sha256sum "$manifest" | awk '{print $1}')"
[[ "$actual_sha" == "${values[affected_test_manifest_sha256]}" ]] || blocked 'tampered affected test manifest'

IFS= read -r header < "$manifest" || blocked 'affected test manifest пуст'
[[ "$header" == $'test_id\ttest_uri\tchange_id\tresult\tsource_revision' ]] || blocked 'affected test manifest имеет неверный header'
IFS=',' read -r -a scope_ids <<< "${values[scope]}"
declare -A covered=() tuples=()
row_count=0
failed_count=0
while IFS=$'\t' read -r test_id test_uri change_id result row_source extra ||
  [[ -n "${test_id}${test_uri}${change_id}${result}${row_source}${extra}" ]]; do
  ((row_count+=1))
  [[ -z "$extra" ]] || blocked "manifest row $row_count содержит лишние columns"
  [[ "$test_id" =~ ^TEST-[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || blocked "manifest row $row_count: invalid test_id"
  [[ "$change_id" =~ ^[A-Z][A-Z0-9]*-[A-Za-z0-9._-]+$ ]] || blocked "manifest row $row_count: invalid change_id"
  case "$result" in PASS) ;; FAIL) ((failed_count+=1)) ;; *) blocked "manifest row $row_count: result=$result запрещён" ;; esac
  [[ "$row_source" == "${values[source_revision]}" ]] || blocked "manifest row $row_count связан с другой source revision"
  [[ "$test_uri" =~ ^[A-Za-z0-9._/-]+$ && "$test_uri" != /* && "$test_uri" != ../* && "$test_uri" != */../* ]] ||
    blocked "manifest row $row_count: unsafe test_uri"
  test_path="$PROJECT_PATH/$test_uri"
  [[ -f "$test_path" && ! -L "$test_path" ]] || blocked "manifest row $row_count: native test file отсутствует/symlink"
  test_canonical="$(readlink -f "$test_path")"
  [[ "$test_canonical" == "$PROJECT_PATH/"* ]] || blocked "manifest row $row_count: test_uri выходит из Project"
  [[ "$test_canonical" != "$PROJECT_PATH/stage4-dev/outputs/"* ]] ||
    blocked "manifest row $row_count: test code должен оставаться в native repository structure"
  in_scope=0
  for scope_id in "${scope_ids[@]}"; do
    if [[ "$change_id" == "$scope_id" ]]; then in_scope=1; break; fi
  done
  (( in_scope == 1 )) || blocked "manifest row $row_count: change_id=$change_id отсутствует в scope"
  tuple="$test_id|$change_id"
  [[ -z "${tuples[$tuple]+x}" ]] || blocked "duplicate manifest tuple: $tuple"
  tuples["$tuple"]=1
  covered["$change_id"]=1
done < <(tail -n +2 "$manifest")

(( row_count > 0 )) || blocked 'affected test manifest не содержит rows'
for scope_id in "${scope_ids[@]}"; do
  [[ -n "${covered[$scope_id]:-}" ]] || blocked "declared scope не имеет affected test: $scope_id"
done
(( values[expected_test_count] == row_count )) || blocked 'expected_test_count не совпадает с manifest rows'
(( values[executed_test_count] == row_count )) || blocked 'executed_test_count не покрывает весь affected manifest'
(( values[failed_tests] == failed_count )) || blocked 'failed_tests не совпадает с manifest results'
if [[ "${values[status]}" == PASS ]]; then
  (( failed_count == 0 )) || blocked 'PASS содержит failed affected tests'
else
  (( failed_count > 0 )) || blocked 'FAIL не содержит failed affected tests'
fi

echo "TDD STATUS VERIFIED: status=${values[status]} source=${values[source_revision]} scope=${values[scope]} tests=$row_count failed=$failed_count"

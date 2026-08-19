#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
SOURCE_REVISION="${2:?Укажи exact source revision}"
blocked() { echo "S5 VALIDATION BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$SOURCE_REVISION" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] || blocked 'invalid source revision'
command -v jq >/dev/null 2>&1 || blocked 'jq capability отсутствует'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
INDEX=''
OUTPUTS="$PROJECT_PATH/stage5-testing/outputs"
POLICY_READER="$SCRIPT_DIR/../s0-quality-gates/quality-policy-read.sh"
APPLICABILITY_RESOLVER="$SCRIPT_DIR/applicability-resolve.sh"
CURRENT_ARTIFACT_TOOL="$SCRIPT_DIR/current-artifact.sh"

field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

resolved_profile_value() {
  local capability="$1" expected_field="$2" output resolved_capability applicability
  local profile_field profile_value revision owner reason extra
  output="$(bash "$APPLICABILITY_RESOLVER" resolve "$PROJECT_PATH" "$capability")" ||
    blocked "applicability resolution failed: $capability"
  IFS=$'\t' read -r resolved_capability applicability profile_field profile_value \
    revision owner reason extra <<< "$output"
  [[ -z "$extra" && "$resolved_capability" == "$capability" && "$profile_field" == "$expected_field" ]] ||
    blocked "invalid applicability resolver output: $capability"
  printf '%s\n' "$profile_value"
}

frontmatter_field() {
  local file="$1" wanted="$2"
  awk -v wanted="$wanted" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    { key=$0; sub(/:.*/, "", key); if (key == wanted) { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit } }
  ' "$file"
}

expect_meta() {
  local file="$1" key="$2" expected="$3" actual
  actual="$(frontmatter_field "$file" "$key")"
  [[ "$actual" == "$expected" ]] || blocked "$(basename "$file"): $key должен быть $expected, получено ${actual:-MISSING}"
}

verify_metric_binding() {
  local raw="$1" metric="$2" expected_observed="$3"
  local operator threshold observed unit verdict policy_revision
  local expected_operator expected_threshold expected_unit expected_policy expected_profile extra
  [[ "$(jq -r --arg metric "$metric" '[.quality_metrics[] | select(.metric_id == $metric)] | length' "$raw")" == 1 ]] ||
    blocked "quality metric missing/duplicate: $metric"
  IFS=$'\t' read -r operator threshold observed unit verdict policy_revision extra < <(
    jq -r --arg metric "$metric" '.quality_metrics[] | select(.metric_id == $metric) |
      [.operator,(.threshold|tostring),(.observed|tostring),.unit,.verdict,.policy_revision] | @tsv' "$raw"
  )
  [[ -z "$extra" ]] || blocked "quality metric has extra fields: $metric"
  IFS=$'\t' read -r _ expected_operator expected_threshold expected_unit expected_policy expected_profile extra < <(
    bash "$POLICY_READER" "$PROJECT_PATH" "$metric"
  ) || blocked "effective policy unavailable: $metric"
  [[ -z "$extra" && "$operator" == "$expected_operator" && "$unit" == "$expected_unit" &&
      "$policy_revision" == "$expected_policy" ]] || blocked "quality metric policy binding mismatch: $metric"
  awk -v actual="$threshold" -v expected="$expected_threshold" 'BEGIN { exit !(actual == expected) }' ||
    blocked "quality metric threshold mismatch: $metric"
  awk -v actual="$observed" -v expected="$expected_observed" 'BEGIN { exit !(actual == expected) }' ||
    blocked "quality metric observed value contradicts raw counters/results: $metric"
  derived=FAIL
  if [[ "$operator" == '>=' ]]; then
    awk -v value="$observed" -v limit="$threshold" 'BEGIN { exit !(value >= limit) }' && derived=PASS
  else
    awk -v value="$observed" -v limit="$threshold" 'BEGIN { exit !(value <= limit) }' && derived=PASS
  fi
  [[ "$verdict" == "$derived" ]] || blocked "quality metric self-verdict contradicts observed: $metric"
}

validate_metric_array_schema() {
  local raw="$1"
  jq -e '(.quality_metrics | type == "array") and all(.quality_metrics[];
    ((keys | sort) == ["metric_id","observed","operator","policy_revision","threshold","unit","verdict"]) and
    (.metric_id | type == "string" and test("^[a-z][a-z0-9_]*$")) and
    (.operator == ">=" or .operator == "<=") and (.threshold | type == "number") and
    (.observed | type == "number") and (.unit | type == "string" and length > 0) and
    (.verdict == "PASS" or .verdict == "FAIL") and
    (.policy_revision | type == "string" and length > 0)) and
    (([.quality_metrics[].metric_id] | unique | length) == (.quality_metrics | length))' \
    "$raw" >/dev/null || blocked 'invalid/duplicate quality_metrics rows'
}

current_one() {
  local logical_id="$1" ref
  ref="$(bash "$CURRENT_ARTIFACT_TOOL" resolve-compatible-one "$PROJECT_PATH" "$logical_id" '' "$SOURCE_REVISION")" ||
    blocked "$logical_id current resolution failed"
  printf '%s\n' "$PROJECT_PATH/$ref"
}

bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null || blocked 'Product Profile invalid'
INDEX="$(current_one s5-validation-index)"
profile_schema="$(field "$PROFILE" schema_version)"
profile_revision="$(field "$PROFILE" revision)"
[[ "$profile_schema" == 4 || "$profile_schema" == 5 ]] ||
  blocked 'S5 Validation v1 требует Product Profile schema_version: 4|5'
if [[ "$profile_schema" == 5 ]]; then
  bash "$SCRIPT_DIR/../s0-quality-gates/quality-characteristics-check.sh" "$PROJECT_PATH" >/dev/null ||
    blocked 'Quality Characteristics v1 invalid'
fi
environment_profile="$(field "$PROFILE" validation_environment_profile)"
environment_id="$(field "$PROFILE" validation_environment_identity)"
[[ "$environment_profile" != not-available ]] || blocked 'representative validation environment unavailable'
[[ "$(field "$PROFILE" validation_environment_authorization)" == required ]] || blocked 'environment authorization is not required by profile'
performance_resolution="$(bash "$APPLICABILITY_RESOLVER" resolve "$PROJECT_PATH" performance)" ||
  blocked 'performance applicability resolution failed'
IFS=$'\t' read -r performance_capability performance_applicability performance_field \
  performance_requirement performance_revision performance_applicability_owner \
  performance_applicability_reason performance_extra <<< "$performance_resolution"
[[ -z "$performance_extra" && "$performance_capability" == performance &&
  "$performance_field" == performance_validation && "$performance_revision" == "$profile_revision" ]] ||
  blocked 'invalid/stale performance applicability resolution'

security_resolution="$(bash "$APPLICABILITY_RESOLVER" resolve "$PROJECT_PATH" runtime-security)" ||
  blocked 'runtime-security applicability resolution failed'
IFS=$'\t' read -r security_capability security_applicability security_field \
  security_requirement security_revision security_applicability_owner \
  security_applicability_reason security_extra <<< "$security_resolution"
[[ -z "$security_extra" && "$security_capability" == runtime-security &&
  "$security_field" == runtime_security_validation && "$security_revision" == "$profile_revision" ]] ||
  blocked 'invalid/stale runtime-security applicability resolution'
interaction_requirement="$(resolved_profile_value interaction ux_brief_requirement)"
accessibility_requirement=legacy-unverified
if [[ "$profile_schema" == 5 ]]; then
  accessibility_requirement="$(resolved_profile_value accessibility accessibility_validation)"
fi

build_records=()
while IFS= read -r -d '' record; do
  [[ "$(field "$record" check_id)" == build ]] || continue
  [[ "$(field "$record" source_revision)" == "$SOURCE_REVISION" ]] || continue
  build_records+=("$record")
done < <(find "$PROJECT_PATH/tracking/evidence/v1" -maxdepth 1 -type f -name '*.yaml' -print0 2>/dev/null | sort -z)
(( ${#build_records[@]} == 1 )) || blocked "exact source требует один build Evidence record; найдено ${#build_records[@]}"
build_record="${build_records[0]}"
bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$build_record" \
  --expected-source "$SOURCE_REVISION" --expected-check build >/dev/null || blocked 'build Evidence v1 invalid'
[[ "$(field "$build_record" verdict)" == PASS ]] || blocked 'build evidence must PASS'
subject_digest="$(field "$build_record" subject_digest)"
build_identity="$(field "$build_record" build_identity)"

UAT_TRACE="$(current_one product-acceptance-index)"
[[ -f "$UAT_TRACE" && ! -L "$UAT_TRACE" ]] || blocked 'S2 UAT trace missing/symlink'
[[ "$(head -1 "$UAT_TRACE")" == $'uat_id\tmust_fr_id\trisk_id\tux_flow_id\tcriteria_uri' ]] ||
  blocked 'S2 UAT trace header invalid'
mapfile -t expected_uat_ids < <(tail -n +2 "$UAT_TRACE" | cut -f1 | sort -u)
(( ${#expected_uat_ids[@]} > 0 )) || blocked 'S2 UAT trace has no scenarios'

expected_criterion_ids=()
if [[ "$profile_schema" == 5 && "$interaction_requirement" == required ]]; then
  ux_brief="$(current_one ux-requirements)"
  [[ "${ux_brief##*/}" == PO-*-ux-brief.md ]] ||
    blocked 'required interaction current artifact is not a UX brief'
  mapfile -t interaction_ids < <(rg -o 'UXC-[A-Za-z0-9._-]+' "$ux_brief" | sort -u)
  (( ${#interaction_ids[@]} > 0 )) || blocked 'required interaction has no stable UXC criteria'
  expected_criterion_ids+=("${interaction_ids[@]}")
  if [[ "$accessibility_requirement" == required ]]; then
    mapfile -t accessibility_ids < <(rg -o 'A11Y-[A-Za-z0-9._-]+' "$ux_brief" | sort -u)
    (( ${#accessibility_ids[@]} > 0 )) || blocked 'required accessibility has no stable A11Y criteria'
    expected_criterion_ids+=("${accessibility_ids[@]}")
  fi
fi

expected_security_scenarios=()
if [[ "$security_requirement" == required ]]; then
  sg1_file="$(current_one security-requirements)"
  sg2_file="$(current_one threat-model)"
  sg1_asvs_version="$(field "$sg1_file" asvs_version)"
  sg2_asvs_version="$(field "$sg2_file" asvs_version)"
  [[ "$sg1_asvs_version" == 5.0.0 ]] ||
    blocked "SG1 asvs_version must match active baseline 5.0.0"
  [[ "$sg2_asvs_version" == "$sg1_asvs_version" ]] ||
    blocked "SG2 asvs_version must match SG1"
  mapfile -t asvs_refs < <(
    rg -o 'v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+' "$sg1_file" | sort -u
  )
  if rg -q '(?i)ASVS[-_ ]?ref:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+|\|[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*\|' "$sg1_file"; then
    blocked "unversioned ASVS requirement reference"
  fi
  (( ${#asvs_refs[@]} > 0 )) ||
    blocked "SG1 artifact has no versioned ASVS requirement reference"
  for asvs_ref in "${asvs_refs[@]}"; do
    [[ "$asvs_ref" =~ ^v5\.0\.0-[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
      blocked "unversioned ASVS requirement reference: $asvs_ref"
  done
  mapfile -t sg1_scenarios < <(rg -o 'SEC-SCENARIO-[A-Za-z0-9._-]+' "$sg1_file" | sort -u)
  mapfile -t sg2_scenarios < <(rg -o 'SEC-SCENARIO-[A-Za-z0-9._-]+' "$sg2_file" | sort -u)
  (( ${#sg1_scenarios[@]} > 0 && ${#sg2_scenarios[@]} > 0 )) ||
    blocked 'SG1/SG2 artifacts must expose stable SEC-SCENARIO ids'
  mapfile -t expected_security_scenarios < <(
    printf '%s\n' "${sg1_scenarios[@]}" "${sg2_scenarios[@]}" | sort -u
  )
fi

[[ -f "$INDEX" && ! -L "$INDEX" ]] || blocked 'S5-validation-v1.tsv отсутствует или symlink'
IFS= read -r header < "$INDEX" || blocked 'S5 validation index пуст'
[[ "$header" == $'stream_id\towner\tapplicability\tverdict\tsource_revision\tsubject_digest\tbuild_identity\tenvironment_id\traw_format\traw_result_uri\traw_result_sha256\tfinding_ids\tenvironment_approval_ref\thuman_approval_ref\trisk_exception_ref' ]] ||
  blocked 'S5 validation index имеет неверный header'

approval_check() {
  local ref="$1" producer="$2" required_scope="$3" approval_path output
  [[ "$ref" != none ]] || blocked "approval отсутствует для $required_scope"
  output="$(bash "$SCRIPT_DIR/human-approval-check.sh" "$PROJECT_PATH" "$ref" "$SOURCE_REVISION" "$subject_digest" "$producer" 2>&1)" || {
    printf '%s\n' "$output" >&2; blocked "invalid approval: $ref"
  }
  approval_path="$PROJECT_PATH/$ref"
  [[ "$(field "$approval_path" decision)" == APPROVE ]] || blocked "approval rejected: $ref"
  grep -Fq "$required_scope" "$approval_path" || blocked "approval scope не содержит $required_scope"
}

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

known_issue_block() {
  local registry="$1" wanted="$2"
  awk -v wanted="$wanted" '
    $1 == "###" && $2 == wanted { active=1 }
    active && $1 == "###" && $2 ~ /^KI-/ && $2 != wanted { exit }
    active { print }
  ' "$registry"
}

known_issue_field() {
  local block="$1" wanted="$2"
  awk -v wanted="$wanted" '
    index($0, "- " wanted ":") == 1 {
      value=$0
      sub("^- " wanted ":[[:space:]]*", "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' <<< "$block"
}

validate_known_issue() {
  local defect_id="$1" source_stream="$2" source_finding="$3" severity="$4"
  local known_issue="$5" tech_debt="$6" approval_ref="$7"
  local registry block trigger impact workaround detection auto_remediation record_td record_approval
  local defect_digest approval_path output

  [[ "$approval_ref" =~ ^tracking/approvals/APPROVAL-KI-[A-Z0-9][A-Z0-9._-]*\.yaml$ ]] ||
    blocked "Known Issue approval missing/invalid: $defect_id"
  registry="$PROJECT_PATH/tracking/known-issues.md"
  [[ -f "$registry" && ! -L "$registry" ]] || blocked 'tracking/known-issues.md missing/symlink'
  block="$(known_issue_block "$registry" "$known_issue")"
  [[ -n "$block" ]] || blocked "known issue record missing: $known_issue"
  [[ "$(known_issue_field "$block" Severity)" == "$severity" ]] ||
    blocked "Known Issue severity mismatch: $known_issue"
  trigger="$(known_issue_field "$block" Trigger)"
  impact="$(known_issue_field "$block" Impact)"
  workaround="$(known_issue_field "$block" Workaround)"
  detection="$(known_issue_field "$block" 'Detection signal')"
  auto_remediation="$(known_issue_field "$block" 'Auto-remediation')"
  record_td="$(known_issue_field "$block" '→ tech-debt')"
  record_approval="$(known_issue_field "$block" 'Human Approval v1')"
  [[ ${#trigger} -ge 5 && ${#workaround} -ge 5 && ${#detection} -ge 5 && ${#auto_remediation} -ge 2 ]] ||
    blocked "Known Issue operational fields incomplete: $known_issue"
  [[ "$impact" =~ ^user-facing([[:space:]]|—|-|:) ]] ||
    blocked "Known Issue Impact must be user-facing: $known_issue"
  [[ "$record_td" == "$tech_debt" ]] || blocked "Known Issue tech debt mismatch: $known_issue"
  [[ "$record_approval" == "$approval_ref" ]] || blocked "Known Issue approval ref mismatch: $known_issue"
  [[ "$(known_issue_field "$block" Status)" == OPEN ]] || blocked "Known Issue must be OPEN at Gate 5: $known_issue"

  defect_digest="sha256:$(printf '%s\t%s\t%s\t%s\tyes\tKNOWN_ISSUE\t%s\t%s\n' \
    "$defect_id" "$source_stream" "$source_finding" "$severity" "$known_issue" "$tech_debt" |
    sha256sum | awk '{print $1}')"
  output="$(bash "$SCRIPT_DIR/human-approval-check.sh" "$PROJECT_PATH" "$approval_ref" \
    "$SOURCE_REVISION" "$defect_digest" s5-qa 2>&1)" || {
      printf '%s\n' "$output" >&2
      blocked "invalid Known Issue Human Approval: $known_issue"
    }
  approval_path="$PROJECT_PATH/$approval_ref"
  [[ "$(field "$approval_path" decision)" == APPROVE ]] || blocked "Known Issue approval rejected: $known_issue"
  grep -Fq "known-issue:$known_issue" "$approval_path" || blocked "approval scope missing Known Issue id: $known_issue"
  grep -Fq "defect:$defect_id" "$approval_path" || blocked "approval scope missing defect id: $defect_id"
}

safe_raw_path() {
  local uri="$1" path canonical
  [[ "$uri" =~ ^(tracking/validation/raw|stage5-testing/outputs)/[A-Za-z0-9._/-]+$ ]] || blocked "unsafe raw_result_uri: $uri"
  [[ "$uri" != *'/../'* && "$uri" != */.. ]] || blocked "raw path traversal: $uri"
  path="$PROJECT_PATH/$uri"
  [[ -f "$path" && ! -L "$path" ]] || blocked "raw result отсутствует/symlink: $uri"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/tracking/validation/raw/"* || "$canonical" == "$OUTPUTS/"* ]] || blocked "raw result выходит из allowed roots: $uri"
  printf '%s\n' "$path"
}

validate_json_binding() {
  local raw="$1" stream="$2" expected_env="$3"
  jq -e --arg stream "$stream" --arg source "$SOURCE_REVISION" --arg subject "$subject_digest" \
    --arg build "$build_identity" --arg env "$expected_env" '
    type == "object" and .schema_version == 1 and .stream_id == $stream and
    .source_revision == $source and .subject_digest == $subject and
    .build_identity == $build and .environment_id == $env and (.findings | type == "array") and
    all(.findings[]; (.id | type == "string") and (.id | test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")))
  ' "$raw" >/dev/null || blocked "invalid normalized JSON binding for stream=$stream"
}

declare -A seen=() stream_findings=() stream_verdicts=() stream_exception_refs=()
declare -A security_levels=() security_statuses=()
uat_approval_ref=''
row_count=0
while IFS=$'\t' read -r stream owner applicability verdict row_source row_subject row_build row_env raw_format raw_uri raw_sha findings env_approval human_approval exception_ref extra ||
  [[ -n "${stream}${owner}${applicability}${verdict}${row_source}${row_subject}${row_build}${row_env}${raw_format}${raw_uri}${raw_sha}${findings}${env_approval}${human_approval}${exception_ref}${extra}" ]]; do
  ((row_count+=1))
  [[ -z "$extra" ]] || blocked "stream row $row_count содержит лишние columns"
  [[ -z "${seen[$stream]+x}" ]] || blocked "duplicate stream: $stream"
  case "$stream:$owner" in
    automation:s5-qa-auto|performance:s5-perf|security:s5-security|exploratory:s5-qa|uat:s5-qa) ;;
    *) blocked "invalid stream owner: $stream:$owner" ;;
  esac
  [[ "$row_source" == "$SOURCE_REVISION" && "$row_subject" == "$subject_digest" && "$row_build" == "$build_identity" ]] ||
    blocked "stream=$stream связан с wrong source/build subject"
  case "$stream" in
    performance) expected_requirement="$performance_requirement" ;;
    security) expected_requirement="$security_requirement" ;;
    *) expected_requirement=required ;;
  esac
  if [[ "$expected_requirement" == not-applicable ]]; then
    [[ "$applicability" == NOT_APPLICABLE && "$verdict" == NOT_APPLICABLE ]] || blocked "stream=$stream должен быть structured NOT_APPLICABLE"
    [[ "$row_env" == not-applicable && "$env_approval" == none && "$human_approval" == none && "$exception_ref" == none ]] ||
      blocked "stream=$stream N/A содержит invented environment/approval"
  else
    [[ "$applicability" == REQUIRED ]] || blocked "stream=$stream обязан быть REQUIRED"
    [[ "$row_env" == "$environment_id" ]] || blocked "stream=$stream использует wrong environment"
    approval_check "$env_approval" "$owner" "environment:$environment_id"
    case "$verdict" in PASS) ;;
      CONDITIONAL_PASS)
        [[ "$stream" == performance || "$stream" == security ]] || blocked "conditional verdict запрещён для $stream"
        [[ "$findings" != none && "$exception_ref" != none ]] || blocked "conditional $stream требует findings + exception"
        ;;
      FAIL) : ;;
      *) blocked "invalid required stream verdict=$verdict for $stream" ;;
    esac
  fi

  raw="$(safe_raw_path "$raw_uri")"
  [[ "$raw_sha" =~ ^[0-9a-f]{64}$ ]] || blocked "stream=$stream invalid raw digest"
  [[ "$(sha256sum "$raw" | awk '{print $1}')" == "$raw_sha" ]] || blocked "stream=$stream raw digest mismatch"

  case "$stream" in
    automation)
      [[ "$raw_format" == json ]] || blocked 'automation requires normalized JSON'
      validate_json_binding "$raw" automation "$environment_id"
      validate_metric_array_schema "$raw"
      jq -e '
        .regression_scope == "full-affected" and
        ([.expected_tests,.executed_tests,.passed,.failed,.skipped,.critical_paths_total,.critical_paths_automated,.automation_coverage_percent] | all(type == "number")) and
        .expected_tests > 0 and .executed_tests == .expected_tests and
        (.test_results | type == "array" and length > 0) and
        all(.test_results[];
          ((keys | sort) == ["path_id","result","test_id"]) and
          (.test_id | type == "string" and test("^TEST-[A-Za-z0-9._-]+$")) and
          (.path_id | type == "string" and test("^UAT-[A-Za-z0-9._-]+$")) and
          (.result == "PASS" or .result == "FAIL" or .result == "SKIPPED")) and
        (([.test_results[].test_id] | unique | length) == (.test_results | length)) and
        (.critical_path_results | type == "array" and length > 0) and
        all(.critical_path_results[];
          ((keys | sort) == ["automated","path_id","result","test_id"]) and
          (.path_id | type == "string" and test("^UAT-[A-Za-z0-9._-]+$")) and
          (.automated | type == "boolean") and
          ((.automated == true and (.test_id | type == "string" and test("^TEST-[A-Za-z0-9._-]+$")) and .result == "PASS") or
           (.automated == false and .test_id == "none" and .result == "NOT_AUTOMATED"))) and
        (([.critical_path_results[].path_id] | unique | length) == (.critical_path_results | length)) and
        (.criterion_results | type == "array") and
        all(.criterion_results[];
          ((keys | sort) == ["criterion_id","result","test_id"]) and
          (.criterion_id | type == "string" and test("^(UXC|A11Y)-[A-Za-z0-9._-]+$")) and
          (.test_id | type == "string" and test("^TEST-[A-Za-z0-9._-]+$")) and
          .result == "PASS") and
        (([.criterion_results[].criterion_id] | unique | length) == (.criterion_results | length))
      ' "$raw" >/dev/null || blocked 'automation selective/incomplete/skipped/below coverage threshold'
      tests_total="$(jq '.test_results | length' "$raw")"
      tests_passed="$(jq '[.test_results[] | select(.result == "PASS")] | length' "$raw")"
      tests_failed="$(jq '[.test_results[] | select(.result == "FAIL")] | length' "$raw")"
      tests_skipped="$(jq '[.test_results[] | select(.result == "SKIPPED")] | length' "$raw")"
      [[ "$(jq -r '.expected_tests' "$raw")" == "$tests_total" &&
          "$(jq -r '.executed_tests' "$raw")" == "$tests_total" &&
          "$(jq -r '.passed' "$raw")" == "$tests_passed" &&
          "$(jq -r '.failed' "$raw")" == "$tests_failed" &&
          "$(jq -r '.skipped' "$raw")" == "$tests_skipped" ]] ||
        blocked 'automation counters contradict exact test_results'
      (( tests_failed == 0 && tests_skipped == 0 )) || blocked 'automation exact test results contain FAIL/SKIPPED'
      expected_paths="$(printf '%s\n' "${expected_uat_ids[@]}" | sort -u | paste -sd, -)"
      actual_paths="$(jq -r '[.critical_path_results[].path_id] | sort | join(",")' "$raw")"
      [[ "$actual_paths" == "$expected_paths" ]] || blocked 'critical path ids do not match S2 UAT catalog'
      paths_total="$(jq '.critical_path_results | length' "$raw")"
      paths_automated="$(jq '[.critical_path_results[] | select(.automated == true)] | length' "$raw")"
      [[ "$(jq -r '.critical_paths_total' "$raw")" == "$paths_total" &&
          "$(jq -r '.critical_paths_automated' "$raw")" == "$paths_automated" ]] ||
        blocked 'critical path counters contradict exact path rows'
      automation_percent="$(awk -v automated="$paths_automated" -v total="$paths_total" 'BEGIN { printf "%.10g", automated * 100 / total }')"
      awk -v declared="$(jq -r '.automation_coverage_percent' "$raw")" -v derived="$automation_percent" \
        'BEGIN { exit !(declared == derived) }' || blocked 'automation coverage contradicts critical path rows'
      pass_rate="$(awk -v passed="$tests_passed" -v total="$tests_total" 'BEGIN { printf "%.10g", passed * 100 / total }')"
      verify_metric_binding "$raw" test_pass_rate_percent "$pass_rate"
      verify_metric_binding "$raw" e2e_automation_percent "$automation_percent"
      [[ "$(jq '.quality_metrics | length' "$raw")" == 2 &&
          "$(jq '[.quality_metrics[] | select(.verdict == "PASS")] | length' "$raw")" == 2 ]] ||
        blocked 'automation effective policy metrics did not PASS exactly'
      expected_criteria="$(printf '%s\n' "${expected_criterion_ids[@]}" | sed '/^$/d' | sort -u | paste -sd, -)"
      actual_criteria="$(jq -r '[.criterion_results[].criterion_id] | sort | join(",")' "$raw")"
      [[ "$actual_criteria" == "$expected_criteria" ]] ||
        blocked 'UX/A11Y execution results do not match required criteria'
      [[ "$verdict" == PASS ]] || blocked 'automation must PASS'
      ;;
    performance)
      [[ "$raw_format" == json ]] || blocked 'performance requires normalized JSON'
      validate_json_binding "$raw" performance "$row_env"
      if [[ "$applicability" == REQUIRED ]]; then
        validate_metric_array_schema "$raw"
        jq -e --arg verdict "$verdict" '.verdict == $verdict and
          ([.metrics_total,.metrics_evaluated,.metrics_failed] | all(type == "number")) and
          (.quality_metrics | length) > 0 and .metrics_total == (.quality_metrics | length) and
          .metrics_evaluated == .metrics_total and
          (($verdict == "PASS" and .metrics_failed == 0) or $verdict == "CONDITIONAL_PASS" or $verdict == "FAIL")' "$raw" >/dev/null ||
          blocked 'performance metrics are incomplete or contradict verdict'
        perf_failed=0
        while IFS= read -r metric; do
          case "$metric" in
            response_time_p95_ms|response_time_p99_ms|error_rate_percent|availability_percent|rto_hours|rpo_hours) ;;
            *) blocked "unsupported performance policy metric: $metric" ;;
          esac
          metric_observed="$(jq -r --arg metric "$metric" '.quality_metrics[] | select(.metric_id == $metric) | .observed' "$raw")"
          verify_metric_binding "$raw" "$metric" "$metric_observed"
          [[ "$(jq -r --arg metric "$metric" '.quality_metrics[] | select(.metric_id == $metric) | .verdict' "$raw")" == PASS ]] ||
            ((perf_failed+=1))
        done < <(jq -r '.quality_metrics[].metric_id' "$raw")
        [[ "$(jq -r '.metrics_failed' "$raw")" == "$perf_failed" ]] ||
          blocked 'performance metrics_failed contradicts exact metric rows'
      else
        jq -e --argjson revision "$profile_revision" --arg owner "$performance_applicability_owner" \
          --arg reason "$performance_applicability_reason" '.verdict == "NOT_APPLICABLE" and .profile_revision == $revision and
          .applicability_owner == $owner and .applicability_reason == $reason and
          .metrics_total == 0 and .metrics_evaluated == 0 and .metrics_failed == 0 and
          .quality_metrics == []' "$raw" >/dev/null || blocked 'invalid performance N/A'
      fi
      ;;
    security)
      [[ "$raw_format" == json ]] || blocked 'security requires normalized JSON'
      validate_json_binding "$raw" security "$row_env"
      if [[ "$applicability" == REQUIRED ]]; then
        jq -e --arg verdict "$verdict" '.verdict == $verdict and
          (.scenarios_total | type == "number") and (.scenarios_evaluated | type == "number") and
          (.scenario_results | type == "array" and length > 0) and
          all(.scenario_results[];
            ((keys | sort) == ["result","scenario_id","test_id"]) and
            (.scenario_id | type == "string" and test("^SEC-SCENARIO-[A-Za-z0-9._-]+$")) and
            (.test_id | type == "string" and test("^TEST-SEC-[A-Za-z0-9._-]+$")) and
            (.result == "PASS" or .result == "FAIL")) and
          (([.scenario_results[].scenario_id] | unique | length) == (.scenario_results | length)) and
          .scenarios_total == (.scenario_results | length) and .scenarios_evaluated == .scenarios_total and
          all(.findings[]; (.cvss | type == "number") and .cvss >= 0 and .cvss <= 10 and (.status == "open" or .status == "fixed"))' "$raw" >/dev/null || blocked 'invalid/incomplete SG4 normalized result'
        expected_scenarios="$(printf '%s\n' "${expected_security_scenarios[@]}" | sort -u | paste -sd, -)"
        actual_scenarios="$(jq -r '[.scenario_results[].scenario_id] | sort | join(",")' "$raw")"
        [[ "$actual_scenarios" == "$expected_scenarios" ]] ||
          blocked 'SG4 scenario ids do not match exact SG1/SG2 catalog'
        high_ids="$(jq -r '[.findings[] | select(.status == "open" and .cvss >= 7.0) | .id] | join(",")' "$raw")"
        [[ -z "$high_ids" ]] || blocked "open SG4 Critical/High findings: $high_ids"
        security_medium_ids=''
        while IFS=$'\t' read -r finding_id cvss finding_status; do
          if awk -v score="$cvss" 'BEGIN { exit !(score >= 9.0) }'; then
            level=CRITICAL
          elif awk -v score="$cvss" 'BEGIN { exit !(score >= 7.0) }'; then
            level=HIGH
          elif awk -v score="$cvss" 'BEGIN { exit !(score >= 4.0) }'; then
            level=MEDIUM
          elif awk -v score="$cvss" 'BEGIN { exit !(score > 0) }'; then
            level=LOW
          else
            level=NONE
          fi
          [[ "$finding_status" != open || "$level" != NONE ]] ||
            blocked "open SG4 finding has CVSS 0.0 and no actionable severity: $finding_id"
          security_levels["$finding_id"]="$level"
          security_statuses["$finding_id"]="$finding_status"
          if [[ "$finding_status" == open && "$level" == MEDIUM ]]; then
            [[ -z "$security_medium_ids" ]] || security_medium_ids+=','
            security_medium_ids+="$finding_id"
          fi
        done < <(jq -r '.findings[] | [.id, (.cvss|tostring), .status] | @tsv' "$raw")
      else
        jq -e --argjson revision "$profile_revision" --arg owner "$security_applicability_owner" \
          --arg reason "$security_applicability_reason" '.verdict == "NOT_APPLICABLE" and .profile_revision == $revision and
          .applicability_owner == $owner and .applicability_reason == $reason and
          .scenarios_total == 0 and .scenarios_evaluated == 0 and .scenario_results == []' "$raw" >/dev/null || blocked 'invalid security N/A'
      fi
      ;;
    exploratory)
      [[ "$raw_format" == markdown ]] || blocked 'exploratory requires Markdown report'
      expect_meta "$raw" schema_version 1
      expect_meta "$raw" artifact_type exploratory-report
      expect_meta "$raw" owner s5-qa
      expect_meta "$raw" source_revision "$SOURCE_REVISION"
      expect_meta "$raw" subject_digest "$subject_digest"
      expect_meta "$raw" build_identity "$build_identity"
      expect_meta "$raw" environment_id "$environment_id"
      duration="$(frontmatter_field "$raw" duration_minutes)"
      [[ "$duration" =~ ^[1-9][0-9]*$ ]] || blocked 'exploratory duration must be positive'
      grep -Fq '## Charter' "$raw" && grep -Fq '## Observations' "$raw" && grep -Fq '## Findings' "$raw" || blocked 'exploratory report incomplete'
      [[ "$verdict" == PASS ]] || blocked 'exploratory stream must PASS or expose findings through a blocking bundle'
      ;;
    uat)
      [[ "$raw_format" == tsv ]] || blocked 'UAT requires TSV results'
      [[ "$verdict" == PASS ]] || blocked 'UAT stream must PASS'
      uat_approval_ref="$human_approval"
      [[ "$uat_approval_ref" != none ]] || blocked 'UAT human approval missing'
      ;;
  esac

  raw_finding_ids=none
  if [[ "$raw_format" == json ]]; then
    raw_finding_ids="$(jq -r '[.findings[].id] | if length == 0 then "none" else join(",") end' "$raw")"
  elif [[ "$findings" != none ]]; then
    IFS=',' read -r -a markdown_ids <<< "$findings"
    for finding in "${markdown_ids[@]}"; do grep -Fq "$finding" "$raw" || blocked "finding=$finding absent from $stream raw report"; done
    raw_finding_ids="$findings"
  fi
  [[ "$findings" == "$raw_finding_ids" ]] || blocked "stream=$stream finding_ids contradict raw result"
  if [[ "$verdict" == CONDITIONAL_PASS ]]; then
    exception_findings="$findings"
    if [[ "$stream" == security ]]; then
      [[ -n "$security_medium_ids" ]] || blocked 'security CONDITIONAL_PASS has no open Medium finding'
      exception_findings="$security_medium_ids"
    fi
    bash "$SCRIPT_DIR/risk-exception-check.sh" "$PROJECT_PATH" "$exception_ref" "s5-$stream" \
      "$SOURCE_REVISION" "$subject_digest" "$owner" "$exception_findings" "$stream" >/dev/null ||
      blocked "invalid S5 risk exception for $stream"
  elif [[ "$stream" == security && -n "${security_medium_ids:-}" ]]; then
    blocked 'open SG4 Medium findings require CONDITIONAL_PASS and exact Risk Exception'
  fi
  seen["$stream"]=1
  stream_findings["$stream"]="$findings"
  stream_verdicts["$stream"]="$verdict"
  stream_exception_refs["$stream"]="$exception_ref"
done < <(tail -n +2 "$INDEX")

(( row_count == 5 )) || blocked "S5 index должен содержать 5 streams, найдено $row_count"
for stream in automation performance security exploratory uat; do [[ -n "${seen[$stream]:-}" ]] || blocked "missing stream: $stream"; done

uat_raw_uri="$(awk -F'\t' '$1=="uat" {print $10}' "$INDEX")"
uat_raw="$PROJECT_PATH/$uat_raw_uri"
[[ "$(head -1 "$uat_raw")" == $'uat_id\tresult\tsource_revision\tenvironment_id' ]] || blocked 'UAT result header invalid'
declare -A uat_seen=()
while IFS=$'\t' read -r uat_id result row_source row_env extra; do
  [[ -z "$extra" && "$uat_id" =~ ^UAT-[A-Za-z0-9._-]+$ ]] || blocked 'invalid UAT result row'
  [[ "$result" == PASS && "$row_source" == "$SOURCE_REVISION" && "$row_env" == "$environment_id" ]] || blocked "UAT result blocks: $uat_id"
  [[ -z "${uat_seen[$uat_id]+x}" ]] || blocked "duplicate UAT result: $uat_id"
  uat_seen["$uat_id"]=1
done < <(tail -n +2 "$uat_raw")
for uat_id in "${expected_uat_ids[@]}"; do [[ -n "${uat_seen[$uat_id]:-}" ]] || blocked "missing UAT result: $uat_id"; done
approval_check "$uat_approval_ref" s5-qa "environment:$environment_id"
uat_approval_path="$PROJECT_PATH/$uat_approval_ref"
for uat_id in "${expected_uat_ids[@]}"; do grep -Fq "$uat_id" "$uat_approval_path" || blocked "UAT approval scope missing $uat_id"; done

automation_report="$(current_one s5-automation-report)"
automation_coverage="$(current_one s5-coverage-report)"
performance_report="$(current_one s5-performance-report)"
security_report="$(current_one s5-security-report)"
defect_doc="$(current_one defect-register)"
defect_index="$(current_one defect-index)"
analysis_doc="$(current_one s5-test-analysis)"
go_doc="$(current_one gate5-decision)"
exploratory_doc="$(current_one s5-exploratory-report)"
[[ "${exploratory_doc#"$PROJECT_PATH/"}" == "$(awk -F'\t' '$1=="exploratory" {print $10}' "$INDEX")" ]] ||
  blocked 'current exploratory report contradicts S5 index'

for doc in "$exploratory_doc" "$automation_report" "$automation_coverage" \
  "$performance_report" "$security_report" "$defect_doc" "$analysis_doc" "$go_doc"; do
  doc_ref="${doc#"$PROJECT_PATH/"}"
  metadata_output="$(bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" "$doc_ref" 2>&1)" || {
    printf '%s\n' "$metadata_output" >&2
    blocked "$(basename "$doc"): Artifact Metadata v1 invalid"
  }
done

for record in \
  "$automation_report|automation-report|s5-qa-auto|$environment_id" \
  "$automation_coverage|automation-coverage|s5-qa-auto|$environment_id" \
  "$performance_report|performance-report|s5-perf|$(awk -F'\t' '$1=="performance" {print $8}' "$INDEX")" \
  "$security_report|security-report|s5-security|$(awk -F'\t' '$1=="security" {print $8}' "$INDEX")" \
  "$defect_doc|defect-register|s5-qa|none" \
  "$analysis_doc|test-analysis|s5-qa|none"; do
  IFS='|' read -r doc type owner report_environment <<< "$record"
  expect_meta "$doc" schema_version 1
  expect_meta "$doc" artifact_type "$type"
  expect_meta "$doc" owner "$owner"
  expect_meta "$doc" source_revision "$SOURCE_REVISION"
  expect_meta "$doc" subject_digest "$subject_digest"
  expect_meta "$doc" build_identity "$build_identity"
  [[ "$report_environment" == none ]] || expect_meta "$doc" environment_id "$report_environment"
done
for section in '## Failure Analysis' '## Flaky Tests' '## Coverage Gaps' '## Quality Trend'; do grep -Fq "$section" "$analysis_doc" || blocked "test analysis missing $section"; done

[[ "$(head -1 "$defect_index")" == $'defect_id\tsource_stream\tsource_finding_id\tseverity\tuser_facing\tdisposition\tknown_issue_id\ttech_debt_id\tacceptance_approval_ref' ]] || blocked 'defect index header invalid'
declare -A finding_covered=() defect_ids=()
blockers=0
while IFS=$'\t' read -r defect_id source_stream source_finding severity user_facing disposition known_issue tech_debt acceptance_approval extra ||
  [[ -n "${defect_id}${source_stream}${source_finding}${severity}${user_facing}${disposition}${known_issue}${tech_debt}${acceptance_approval}${extra}" ]]; do
  [[ -z "$extra" && "$defect_id" =~ ^DEF-[A-Za-z0-9._-]+$ ]] || blocked 'invalid defect row'
  [[ -n "${seen[$source_stream]:-}" ]] || blocked "defect references unknown stream=$source_stream"
  [[ ",${stream_findings[$source_stream]}," == *",$source_finding,"* ]] || blocked "defect finding not present in stream: $source_finding"
  [[ -z "${finding_covered[$source_stream:$source_finding]+x}" ]] || blocked "duplicate defect aggregation: $source_stream:$source_finding"
  case "$severity" in S1|S2|S3|S4|CVSS-CRITICAL|CVSS-HIGH|CVSS-MEDIUM|CVSS-LOW) ;; *) blocked "invalid defect severity=$severity" ;; esac
  case "$user_facing" in yes|no) ;; *) blocked 'user_facing must be yes|no' ;; esac
  case "$disposition" in BLOCKING|KNOWN_ISSUE|BACKLOG|TECH_DEBT|CLOSED) ;; *) blocked "invalid defect disposition=$disposition" ;; esac
  if [[ "$severity" =~ ^(S1|S2|CVSS-CRITICAL|CVSS-HIGH)$ && "$disposition" != CLOSED ]]; then
    [[ "$disposition" == BLOCKING ]] || blocked "blocking severity requires CLOSED|BLOCKING: $defect_id"
  fi
  [[ "$disposition" != BLOCKING ]] || ((blockers+=1))
  if [[ "$severity" =~ ^S(3|4)$ && "$user_facing" == yes && "$disposition" != CLOSED ]]; then
    [[ "$disposition" == KNOWN_ISSUE && "$known_issue" =~ ^KI-[A-Za-z0-9._-]+$ ]] || blocked "user-facing S3/S4 requires known issue: $defect_id"
  fi
  if [[ "$source_stream" == security ]]; then
    derived_level="${security_levels[$source_finding]:-MISSING}"
    raw_security_status="${security_statuses[$source_finding]:-MISSING}"
    [[ "$derived_level" != MISSING && "$raw_security_status" != MISSING ]] ||
      blocked "security defect has no exact raw CVSS binding: $defect_id"
    [[ "$severity" == "CVSS-$derived_level" ]] ||
      blocked "security defect severity contradicts raw CVSS: $defect_id"
    [[ "$raw_security_status" != fixed || "$disposition" == CLOSED ]] ||
      blocked "fixed security finding must be CLOSED: $defect_id"
  fi
  if [[ "$source_stream" == security && "$severity" =~ ^CVSS-(MEDIUM|LOW)$ && "$disposition" != CLOSED ]]; then
    [[ "$tech_debt" =~ ^TD-[A-Za-z0-9._-]+$ && -f "$PROJECT_PATH/tracking/tech-debt.md" ]] ||
      blocked "open security Medium/Low requires exact tech debt: $defect_id"
    security_level="${severity#CVSS-}"
    lifecycle_exception=none
    if [[ "$security_level" == MEDIUM ]]; then
      risk_ref="${stream_exception_refs[security]:-none}"
      [[ "$risk_ref" != none ]] || blocked "open security Medium has no stream Risk Exception: $defect_id"
      risk_path="$PROJECT_PATH/$risk_ref"
      [[ "$(field "$risk_path" tech_debt_id)" == "$tech_debt" ]] ||
        blocked "security Medium defect points to a different tech debt than Risk Exception: $defect_id"
      lifecycle_exception="$(field "$risk_path" exception_id)"
    fi
    bash "$SCRIPT_DIR/tech-debt-check.sh" "$PROJECT_PATH" security-lifecycle \
      "$tech_debt" "$source_finding" "$security_level" "$lifecycle_exception" >/dev/null ||
      blocked "invalid security finding lifecycle: $defect_id"
    if [[ "$user_facing" == yes ]]; then
      [[ "$disposition" == KNOWN_ISSUE && "$known_issue" =~ ^KI-[A-Za-z0-9._-]+$ ]] ||
        blocked "user-facing security Medium/Low requires known issue: $defect_id"
      if [[ "$security_level" == MEDIUM ]]; then
        [[ "$(field "$risk_path" known_issue_id)" == "$known_issue" ]] ||
          blocked "security Medium Risk Exception known_issue_id mismatch: $defect_id"
      fi
    fi
  fi
  if [[ "$disposition" == KNOWN_ISSUE ]]; then
    [[ "$user_facing" == yes && "$severity" =~ ^(S3|S4|CVSS-MEDIUM|CVSS-LOW)$ ]] ||
      blocked "KNOWN_ISSUE is allowed only for user-facing S3/S4 or Security Medium/Low: $defect_id"
    [[ "$known_issue" =~ ^KI-[A-Za-z0-9._-]+$ && "$tech_debt" =~ ^TD-[A-Za-z0-9._-]+$ ]] ||
      blocked "KNOWN_ISSUE requires exact KI and Tech Debt ids: $defect_id"
    bash "$SCRIPT_DIR/tech-debt-check.sh" "$PROJECT_PATH" known-issue \
      "$tech_debt" "$source_finding" "$severity" >/dev/null ||
      blocked "invalid Known Issue Tech Debt/Patch SLA: $defect_id"
    validate_known_issue "$defect_id" "$source_stream" "$source_finding" "$severity" \
      "$known_issue" "$tech_debt" "$acceptance_approval"
  fi
  [[ "$disposition" == TECH_DEBT || "$disposition" == KNOWN_ISSUE || "$tech_debt" == none ]] ||
    blocked "unexpected tech_debt_id for $defect_id"
  [[ "$disposition" == KNOWN_ISSUE || "$known_issue" == none ]] || blocked "unexpected known_issue_id for $defect_id"
  [[ "$disposition" == KNOWN_ISSUE || "$acceptance_approval" == none ]] ||
    blocked "unexpected acceptance_approval_ref for $defect_id"
  finding_covered["$source_stream:$source_finding"]=1
  defect_ids["$defect_id"]=1
done < <(tail -n +2 "$defect_index")
if [[ -e "$PROJECT_PATH/tracking/known-issues.md" ]]; then
  bash "$SCRIPT_DIR/known-issue-lifecycle-check.sh" "$PROJECT_PATH" >/dev/null ||
    blocked 'Known Issue lifecycle/schema invalid'
fi
for stream in automation performance security exploratory uat; do
  [[ "${stream_findings[$stream]}" == none ]] && continue
  IFS=',' read -r -a ids <<< "${stream_findings[$stream]}"
  for id in "${ids[@]}"; do [[ -n "${finding_covered[$stream:$id]:-}" ]] || blocked "unaggregated finding: $stream:$id"; done
done

expect_meta "$go_doc" schema_version 1
expect_meta "$go_doc" artifact_type gate5-decision
expect_meta "$go_doc" owner s5-qa
expect_meta "$go_doc" product_profile_revision "$profile_revision"
expect_meta "$go_doc" source_revision "$SOURCE_REVISION"
expect_meta "$go_doc" subject_digest "$subject_digest"
expect_meta "$go_doc" build_identity "$build_identity"
expect_meta "$go_doc" validation_index_sha256 "$(sha256sum "$INDEX" | awk '{print $1}')"
expect_meta "$go_doc" defect_index_sha256 "$(sha256sum "$defect_index" | awk '{print $1}')"
expect_meta "$go_doc" uat_approval_ref "$uat_approval_ref"
expect_meta "$go_doc" verdict GO
(( blockers == 0 )) || blocked "Gate 5 has open blocking defects: $blockers"
for stream in automation exploratory uat; do [[ "${stream_verdicts[$stream]}" == PASS ]] || blocked "Gate 5 required stream not PASS: $stream"; done
for stream in performance security; do [[ "${stream_verdicts[$stream]}" =~ ^(PASS|CONDITIONAL_PASS|NOT_APPLICABLE)$ ]] || blocked "Gate 5 stream blocks: $stream"; done

if grep -Eiq '(AKIA[0-9A-Z]{8,}|gh[pousr]_[A-Za-z0-9]+|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{8,}|password=|token=|secret=)' \
  "$INDEX" "$automation_report" "$automation_coverage" "$performance_report" "$security_report" \
  "$defect_doc" "$defect_index" "$analysis_doc" "$go_doc"; then
  blocked 'secret-like value in S5 governance artifacts'
fi

echo "S5 VALIDATION VERIFIED: source=$SOURCE_REVISION subject=$subject_digest build=$build_identity environment=$environment_id streams=5 blockers=0 uat_approval=$(field "$uat_approval_path" approval_id)"

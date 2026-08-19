#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
RECORD_INPUT="${2:?Укажи Evidence v1 record}"
shift 2

EXPECTED_SOURCE=''
EXPECTED_CHECK=''
INSPECT=0
while (( $# > 0 )); do
  case "$1" in
    --expected-source)
      (( $# >= 2 )) || { echo 'EVIDENCE BLOCKED: --expected-source требует значение' >&2; exit 2; }
      EXPECTED_SOURCE="$2"
      shift 2
      ;;
    --expected-check)
      (( $# >= 2 )) || { echo 'EVIDENCE BLOCKED: --expected-check требует значение' >&2; exit 2; }
      EXPECTED_CHECK="$2"
      shift 2
      ;;
    --inspect)
      INSPECT=1
      shift
      ;;
    *) echo "EVIDENCE BLOCKED: unknown option: $1" >&2; exit 2 ;;
  esac
done

blocked() { echo "EVIDENCE BLOCKED: $*" >&2; exit 1; }
unverified() { echo "EVIDENCE UNVERIFIED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
if [[ "$RECORD_INPUT" != /* ]]; then RECORD_INPUT="$PROJECT_PATH/$RECORD_INPUT"; fi
[[ -f "$RECORD_INPUT" && ! -L "$RECORD_INPUT" ]] || blocked "record не найден или является symlink: $RECORD_INPUT"
RECORD_PATH="$(readlink -f "$RECORD_INPUT")"
EVIDENCE_ROOT="$PROJECT_PATH/tracking/evidence/v1"
[[ "$RECORD_PATH" == "$EVIDENCE_ROOT/"*.yaml ]] ||
  blocked 'record должен быть обычным .yaml файлом в tracking/evidence/v1/'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Product & CI Profile не прошёл deterministic validation'

declare -A profile=() record=() allowed=()
read_flat_yaml() {
  local file="$1" target_name="$2" line key value
  local -n target="$target_name"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" == *:* ]] || blocked "некорректная строка без key:value в ${file#$PROJECT_PATH/}"
    key="${line%%:*}"
    value="${line#*:}"
    key="${key#${key%%[![:space:]]*}}"; key="${key%${key##*[![:space:]]}}"
    value="${value#${value%%[![:space:]]*}}"; value="${value%${value##*[![:space:]]}}"
    [[ "$key" =~ ^[a-z][a-z0-9_]*$ ]] || blocked "недопустимый key: $key"
    [[ -z "${target[$key]+x}" ]] || blocked "duplicate field: $key"
    [[ -n "$value" ]] || blocked "пустое поле: $key"
    target["$key"]="$value"
  done < "$file"
}

read_flat_yaml "$PROFILE" profile
[[ "${profile[schema_version]:-}" =~ ^(2|3|4|5)$ ]] ||
  blocked 'Evidence v1 требует Product & CI Profile schema_version: 2|3|4|5'

fields=(
  schema_version evidence_id check_id category source_profile execution_mode
  executor_identity producer_identity tool_name tool_version source_revision subject_kind
  subject_digest build_identity config_revision policy_revision product_profile_revision
  observed_at freshness_seconds raw_format raw_result_uri raw_result_sha256 signature_status
  verdict applicability_reason applicability_owner requirement_ids specification_ids test_ids
  human_approval_ref risk_exception_ref
)
for key in "${fields[@]}"; do allowed["$key"]=1; done
read_flat_yaml "$RECORD_PATH" record
for key in "${!record[@]}"; do
  [[ -n "${allowed[$key]:-}" ]] || blocked "unknown field: $key"
done
for key in "${fields[@]}"; do
  [[ -n "${record[$key]:-}" ]] || blocked "отсутствует обязательное поле: $key"
done

[[ "${record[schema_version]}" == 1 ]] || blocked 'поддерживается только evidence schema_version: 1'
[[ "${record[evidence_id]}" =~ ^EV-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid evidence_id'
checks=(build unit integration contract lint typecheck secrets sast sca dependency-integrity pipeline-policy image-scan sbom)
[[ " ${checks[*]} " == *" ${record[check_id]} "* ]] || blocked "unsupported check_id: ${record[check_id]}"
[[ -z "$EXPECTED_CHECK" || "${record[check_id]}" == "$EXPECTED_CHECK" ]] ||
  blocked "wrong check: expected=$EXPECTED_CHECK actual=${record[check_id]}"

case "${record[check_id]}" in
  build) expected_category=build ;;
  unit|integration|contract|lint|typecheck) expected_category=test ;;
  secrets|sast|sca|dependency-integrity|image-scan|sbom) expected_category=security ;;
  pipeline-policy) expected_category=policy ;;
esac
[[ "${record[category]}" == "$expected_category" ]] ||
  blocked "wrong category for ${record[check_id]}: ${record[category]}"

case "${record[source_profile]}" in repository-ci|connected-runner|local-offline) ;; *) blocked 'unknown source_profile' ;; esac
[[ "${record[source_profile]}" == "${profile[evidence_source_profile]}" ]] ||
  blocked 'source_profile не совпадает с Product & CI Profile'
case "${record[execution_mode]}" in live|proposal) ;; *) blocked 'execution_mode должен быть live|proposal' ;; esac
[[ "${record[execution_mode]}" == live ]] ||
  unverified 'proposal не является live proof и не закрывает check/gate'
[[ "${record[executor_identity]}" == "${profile[evidence_executor_identity]}" ]] ||
  blocked 'executor_identity не совпадает с выбранным executor'

trusted=",${profile[evidence_trusted_producers]},"
[[ "$trusted" == *",${record[producer_identity]},"* ]] ||
  blocked "unknown producer: ${record[producer_identity]}"
identity_re='^[A-Za-z0-9][A-Za-z0-9._:+/-]*$'
for key in tool_name tool_version config_revision policy_revision; do
  [[ "${record[$key]}" =~ $identity_re && "${record[$key]}" != unknown && "${record[$key]}" != none ]] ||
    blocked "invalid $key"
done

source_re='^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$'
[[ "${record[source_revision]}" =~ $source_re ]] || blocked 'source_revision должен быть full immutable revision'
[[ -z "$EXPECTED_SOURCE" || "${record[source_revision]}" == "$EXPECTED_SOURCE" ]] ||
  blocked "wrong subject/source: expected=$EXPECTED_SOURCE actual=${record[source_revision]}"
[[ "${record[product_profile_revision]}" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid product_profile_revision'
[[ "${record[product_profile_revision]}" == "${profile[revision]}" ]] ||
  blocked 'evidence связано с другой Product Profile revision'

case "${record[subject_kind]}" in source|build-artifact|package|image) ;; *) blocked 'invalid subject_kind' ;; esac
if [[ "${record[subject_kind]}" == source ]]; then
  [[ "${record[subject_digest]}" == none && "${record[build_identity]}" == none ]] ||
    blocked 'source subject не должен выдумывать artifact digest/build identity'
else
  [[ "${record[subject_digest]}" =~ ^sha256:[0-9a-f]{64}$ ]] ||
    blocked 'artifact subject требует sha256 digest'
  [[ "${record[build_identity]}" != none && "${record[build_identity]}" != unknown ]] ||
    blocked 'artifact subject требует build_identity'
  [[ "${profile[build_subject]}" != source-only ]] ||
    blocked 'Product Profile не объявляет artifact subject'
fi
if [[ "${record[check_id]}" == build && "${record[verdict]}" == PASS ]]; then
  case "${profile[build_subject]}" in
    source-only) [[ "${record[subject_kind]}" == source ]] || blocked 'build subject mismatch' ;;
    build-artifact) [[ "${record[subject_kind]}" == build-artifact || "${record[subject_kind]}" == package ]] || blocked 'build subject mismatch' ;;
    image) [[ "${record[subject_kind]}" == image ]] || blocked 'build subject mismatch' ;;
  esac
fi

[[ "${record[observed_at]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  blocked 'observed_at должен быть ISO-8601 UTC'
observed_epoch="$(date -u -d "${record[observed_at]}" +%s 2>/dev/null)" || blocked 'observed_at не является valid timestamp'
now_epoch="$(date -u +%s)"
age=$((now_epoch - observed_epoch))
(( age >= -300 )) || blocked 'evidence timestamp находится в будущем'
[[ "${record[freshness_seconds]}" =~ ^[1-9][0-9]*$ ]] || blocked 'freshness_seconds должен быть positive integer'
(( record[freshness_seconds] <= profile[evidence_freshness_seconds] )) ||
  blocked 'record freshness ослабляет Product Profile maximum'
(( age <= record[freshness_seconds] )) || blocked "stale evidence: age=${age}s"

case "${record[raw_format]}" in junit|tap|sarif|json) ;; *) blocked 'raw_format должен быть junit|tap|sarif|json' ;; esac
formats=",${profile[ci_report_formats]},"
[[ "$formats" == *",${record[raw_format]},"* ]] || blocked 'raw_format отсутствует в Product Profile capability'
raw_uri="${record[raw_result_uri]}"
[[ "$raw_uri" =~ ^tracking/evidence/raw/[A-Za-z0-9._/-]+$ ]] ||
  blocked 'raw_result_uri должен быть project-relative path внутри tracking/evidence/raw/'
[[ "$raw_uri" != *'/../'* && "$raw_uri" != */.. ]] || blocked 'raw_result_uri path traversal запрещён'
case "${record[raw_format]}" in
  junit) [[ "$raw_uri" == *.xml ]] || blocked 'JUnit raw result должен иметь .xml' ;;
  tap) [[ "$raw_uri" == *.tap ]] || blocked 'TAP raw result должен иметь .tap' ;;
  sarif) [[ "$raw_uri" == *.sarif || "$raw_uri" == *.sarif.json ]] || blocked 'SARIF raw result должен иметь .sarif или .sarif.json' ;;
  json) [[ "$raw_uri" == *.json ]] || blocked 'JSON raw result должен иметь .json' ;;
esac
raw_path="$PROJECT_PATH/$raw_uri"
[[ -f "$raw_path" && ! -L "$raw_path" ]] || blocked 'native raw result отсутствует или является symlink'
raw_canonical="$(readlink -f "$raw_path")"
[[ "$raw_canonical" == "$PROJECT_PATH/tracking/evidence/raw/"* ]] || blocked 'raw result разрешился за пределы evidence/raw'
[[ "${record[raw_result_sha256]}" =~ ^[0-9a-f]{64}$ ]] || blocked 'invalid raw_result_sha256'
actual_raw_sha="$(sha256sum "$raw_canonical" | awk '{print $1}')"
[[ "$actual_raw_sha" == "${record[raw_result_sha256]}" ]] || blocked 'tampered raw result: digest mismatch'
if [[ "${record[category]}" == test && "${record[raw_format]}" =~ ^(junit|tap)$ ]]; then
  bash "$SCRIPT_DIR/native-test-result-check.sh" "${record[raw_format]}" "$raw_canonical" \
    "${record[verdict]}" >/dev/null || blocked 'native test result contradicts Evidence verdict'
fi

case "${record[signature_status]}" in verified|not-provided|invalid) ;; *) blocked 'invalid signature_status' ;; esac
[[ "${record[signature_status]}" != invalid ]] || blocked 'producer signature invalid'
case "${profile[evidence_signature_policy]}" in
  required) [[ "${record[signature_status]}" == verified ]] || blocked 'trusted producer signature required' ;;
  if-produced) : ;;
  not-supported) [[ "${record[signature_status]}" == not-provided ]] || blocked 'profile does not support signatures' ;;
esac

case "${record[verdict]}" in PASS|FAIL|BLOCKED|NOT_APPLICABLE) ;; *) blocked 'invalid verdict' ;; esac
if [[ "${record[verdict]}" == NOT_APPLICABLE ]]; then
  [[ "${record[applicability_reason]}" != none && "${record[applicability_reason]}" != unknown ]] ||
    blocked 'NOT_APPLICABLE требует reason'
  [[ "${record[applicability_owner]}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] ||
    blocked 'NOT_APPLICABLE требует owner identity'
fi
for key in requirement_ids specification_ids test_ids; do
  [[ "${record[$key]}" != none && "${record[$key]}" != unknown ]] ||
    blocked "trace chain incomplete: $key"
done
bash "$SCRIPT_DIR/traceability-v1-check.sh" "$PROJECT_PATH" "$RECORD_PATH" >/dev/null ||
  blocked 'requirement→specification→test→source trace is incomplete or invalid'

validate_separate_ref() {
  local field="$1" prefix="$2" ref path canonical
  ref="${record[$field]}"
  [[ "$ref" == none ]] && return 0
  [[ "$ref" =~ ^tracking/$prefix/[A-Za-z0-9._/-]+\.yaml$ ]] || blocked "$field должен ссылаться на отдельный YAML record"
  path="$PROJECT_PATH/$ref"
  [[ -f "$path" && ! -L "$path" ]] || blocked "$field ссылается на отсутствующий/symlink record"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/tracking/$prefix/"* ]] || blocked "$field выходит за пределы Project"
  grep -Eq "^source_revision:[[:space:]]*${record[source_revision]}[[:space:]]*$" "$canonical" ||
    blocked "$field не связан с exact source revision"
  grep -Eq "^subject_digest:[[:space:]]*${record[subject_digest]}[[:space:]]*$" "$canonical" ||
    blocked "$field не связан с exact subject"
}
validate_separate_ref risk_exception_ref risk-exceptions
if [[ "${record[human_approval_ref]}" != none ]]; then
  bash "$SCRIPT_DIR/human-approval-check.sh" "$PROJECT_PATH" "${record[human_approval_ref]}" \
    "${record[source_revision]}" "${record[subject_digest]}" "${record[producer_identity]}" >/dev/null ||
    blocked 'linked human approval is invalid or bound to another subject'
fi

for key in "${fields[@]}"; do
  lower_value="${record[$key],,}"
  [[ ! "$lower_value" =~ (akia[0-9a-z]{8,}|gh[pousr]_[a-z0-9]+|(^|[^a-z0-9])sk-[a-z0-9]{8,}|password=|token=|secret=) ]] ||
    blocked "secret-like value запрещён: $key"
done

echo "EVIDENCE VERIFIED: id=${record[evidence_id]} check=${record[check_id]} verdict=${record[verdict]} source=${record[source_revision]}"
if [[ "${record[verdict]}" == PASS || "${record[verdict]}" == NOT_APPLICABLE || $INSPECT -eq 1 ]]; then
  exit 0
fi
echo "EVIDENCE FAIL: verified machine verdict ${record[verdict]} blocks the gate" >&2
exit 1

#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
EXCEPTION_INPUT="${2:?Укажи risk exception record}"
EXPECTED_CHECK="${3:?Укажи check id}"
EXPECTED_SOURCE="${4:?Укажи source revision}"
EXPECTED_SUBJECT="${5:?Укажи subject digest или none}"
EVIDENCE_PRODUCER="${6:?Укажи evidence producer}"
EXPECTED_FINDINGS="${7:?Укажи comma-separated finding ids}"
EXPECTED_TYPE="${8:?Укажи exception type}"

blocked() { echo "RISK EXCEPTION BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$EXCEPTION_INPUT" == /* ]] || EXCEPTION_INPUT="$PROJECT_PATH/$EXCEPTION_INPUT"
[[ -f "$EXCEPTION_INPUT" && ! -L "$EXCEPTION_INPUT" ]] || blocked 'record отсутствует или является symlink'
EXCEPTION_PATH="$(readlink -f "$EXCEPTION_INPUT")"
[[ "$EXCEPTION_PATH" == "$PROJECT_PATH/tracking/risk-exceptions/"*.yaml ]] ||
  blocked 'record должен находиться в tracking/risk-exceptions/'

fields=(schema_version exception_id exception_type finding_severity tech_debt_id known_issue_id owner approved_by rationale scope check_id finding_ids source_revision subject_digest created_at expires_at status)
declare -A allowed=() values=()
for key in "${fields[@]}"; do allowed["$key"]=1; done
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" == *:* ]] || blocked 'строка без key:value'
  key="${line%%:*}"; value="${line#*:}"
  key="${key#${key%%[![:space:]]*}}"; key="${key%${key##*[![:space:]]}}"
  value="${value#${value%%[![:space:]]*}}"; value="${value%${value##*[![:space:]]}}"
  [[ -n "${allowed[$key]:-}" ]] || blocked "unknown field: $key"
  [[ -z "${values[$key]+x}" ]] || blocked "duplicate field: $key"
  [[ -n "$value" ]] || blocked "empty field: $key"
  values["$key"]="$value"
done < "$EXCEPTION_PATH"
for key in "${fields[@]}"; do [[ -n "${values[$key]:-}" ]] || blocked "missing field: $key"; done

[[ "${values[schema_version]}" == 3 ]] || blocked 'schema_version должен быть 3; v1/v2 are LEGACY / UNVERIFIED'
[[ "${values[exception_id]}" =~ ^RISK-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid exception_id'
[[ "${values[exception_type]}" =~ ^(security|performance|quality|reliability|accessibility|compatibility|safety)$ ]] || blocked 'invalid exception_type'
[[ "${values[exception_type]}" == "$EXPECTED_TYPE" ]] || blocked 'exception_type does not match the evidence stream'
case "${values[exception_type]}:${values[finding_severity]}" in
  security:SECURITY_MEDIUM|performance:PERFORMANCE_THRESHOLD|quality:QUALITY_THRESHOLD|reliability:RELIABILITY_THRESHOLD|accessibility:ACCESSIBILITY_GAP|compatibility:COMPATIBILITY_GAP|safety:SAFETY_GAP) ;;
  *) blocked 'finding_severity is invalid for exception_type' ;;
esac
[[ "${values[tech_debt_id]}" =~ ^TD-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid tech_debt_id'
[[ "${values[known_issue_id]}" == none || "${values[known_issue_id]}" =~ ^KI-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid known_issue_id'
identity_re='^[A-Za-z0-9][A-Za-z0-9._:-]*$'
[[ "${values[owner]}" =~ $identity_re && "${values[owner]}" != s4-dev ]] || blocked 'invalid/forbidden owner'
[[ "${values[approved_by]}" =~ $identity_re && "${values[approved_by]}" != s4-dev ]] || blocked 'invalid/forbidden approver'
[[ "${values[approved_by]}" != "$EVIDENCE_PRODUCER" ]] || blocked 'approver must be independent from evidence producer'
(( ${#values[rationale]} >= 10 )) || blocked 'rationale слишком короткий'
(( ${#values[scope]} >= 5 )) || blocked 'scope слишком короткий'
[[ "${values[check_id]}" == "$EXPECTED_CHECK" ]] || blocked 'wrong check scope'
if [[ "$EXPECTED_TYPE" == security ]]; then
  [[ "$EXPECTED_CHECK" != secrets && "$EXPECTED_CHECK" != dependency-integrity ]] ||
    blocked 'zero-tolerance check cannot be waived'
fi
if [[ "${values[known_issue_id]}" != none ]]; then
  [[ -f "$PROJECT_PATH/tracking/known-issues.md" && ! -L "$PROJECT_PATH/tracking/known-issues.md" ]] ||
    blocked 'known issue lifecycle file missing or symlink'
  grep -Fq "${values[known_issue_id]}" "$PROJECT_PATH/tracking/known-issues.md" ||
    blocked 'known issue record missing'
fi
[[ "${values[source_revision]}" == "$EXPECTED_SOURCE" ]] || blocked 'wrong source revision'
[[ "${values[subject_digest]}" == "$EXPECTED_SUBJECT" ]] || blocked 'wrong subject digest'
[[ "${values[status]}" == ACTIVE ]] || blocked 'risk exception is not ACTIVE'

for key in created_at expires_at; do
  [[ "${values[$key]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || blocked "$key must be ISO-8601 UTC"
done
created_epoch="$(date -u -d "${values[created_at]}" +%s 2>/dev/null)" || blocked 'invalid created_at'
expires_epoch="$(date -u -d "${values[expires_at]}" +%s 2>/dev/null)" || blocked 'invalid expires_at'
now_epoch="$(date -u +%s)"
(( created_epoch <= now_epoch + 300 )) || blocked 'created_at is in the future'
(( expires_epoch > now_epoch )) || blocked 'risk exception expired'
(( expires_epoch > created_epoch )) || blocked 'expires_at must be after created_at'
(( expires_epoch - created_epoch <= 7776000 )) || blocked 'risk exception duration exceeds 90 days'

normalize_findings() {
  local input="$1" finding
  IFS=',' read -r -a ids <<< "$input"
  (( ${#ids[@]} > 0 )) || blocked 'finding set is empty'
  for finding in "${ids[@]}"; do
    [[ "$finding" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || blocked "invalid finding id: $finding"
    printf '%s\n' "$finding"
  done | sort
}
actual_findings="$(normalize_findings "${values[finding_ids]}")"
expected_findings="$(normalize_findings "$EXPECTED_FINDINGS")"
[[ "$(printf '%s\n' "$actual_findings" | uniq -d)" == '' ]] || blocked 'duplicate finding_ids in exception'
[[ "$(printf '%s\n' "$expected_findings" | uniq -d)" == '' ]] || blocked 'duplicate expected finding ids'
[[ "$actual_findings" == "$expected_findings" ]] || blocked 'exception finding_ids are not the exact evidence finding set'

bash "$(dirname "${BASH_SOURCE[0]}")/tech-debt-check.sh" "$PROJECT_PATH" exception \
  "${values[tech_debt_id]}" "${values[exception_id]}" "${values[owner]}" "$EXPECTED_FINDINGS" \
  "${values[exception_type]}" >/dev/null ||
  blocked 'linked tech debt or next-sprint remediation boundary invalid'

echo "RISK EXCEPTION VERIFIED: id=${values[exception_id]} td=${values[tech_debt_id]} check=$EXPECTED_CHECK expires=${values[expires_at]}"

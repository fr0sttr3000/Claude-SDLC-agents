#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
APPROVAL_INPUT="${2:?Укажи approval record}"
EXPECTED_SOURCE="${3:?Укажи source revision}"
EXPECTED_SUBJECT="${4:?Укажи subject digest или none}"
EVIDENCE_PRODUCER="${5:?Укажи evidence producer}"
blocked() { echo "HUMAN APPROVAL BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$APPROVAL_INPUT" == /* ]] || APPROVAL_INPUT="$PROJECT_PATH/$APPROVAL_INPUT"
[[ -f "$APPROVAL_INPUT" && ! -L "$APPROVAL_INPUT" ]] || blocked 'approval absent or symlink'
APPROVAL_PATH="$(readlink -f "$APPROVAL_INPUT")"
[[ "$APPROVAL_PATH" == "$PROJECT_PATH/tracking/approvals/"*.yaml ]] ||
  blocked 'approval must be in tracking/approvals/'

fields=(schema_version approval_id approval_origin approver_identity decision scope rationale source_revision subject_digest observed_at)
declare -A allowed=() values=()
for key in "${fields[@]}"; do allowed["$key"]=1; done
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" == *:* ]] || blocked 'line without key:value'
  key="${line%%:*}"; value="${line#*:}"
  key="${key#${key%%[![:space:]]*}}"; key="${key%${key##*[![:space:]]}}"
  value="${value#${value%%[![:space:]]*}}"; value="${value%${value##*[![:space:]]}}"
  [[ -n "${allowed[$key]:-}" ]] || blocked "unknown field: $key"
  [[ -z "${values[$key]+x}" ]] || blocked "duplicate field: $key"
  [[ -n "$value" ]] || blocked "empty field: $key"
  values["$key"]="$value"
done < "$APPROVAL_PATH"
for key in "${fields[@]}"; do [[ -n "${values[$key]:-}" ]] || blocked "missing field: $key"; done

[[ "${values[schema_version]}" == 1 ]] || blocked 'schema_version must be 1'
[[ "${values[approval_id]}" =~ ^APPROVAL-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid approval_id'
[[ "$(basename "$APPROVAL_PATH")" == "${values[approval_id]}.yaml" ]] ||
  blocked 'approval filename must exactly match approval_id'
[[ "${values[approval_origin]}" == launcher-human-v1 ]] ||
  blocked 'approval_origin must be launcher-human-v1'
[[ "${values[approver_identity]}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || blocked 'invalid approver identity'
[[ "${values[approver_identity]}" != s4-dev && "${values[approver_identity]}" != "$EVIDENCE_PRODUCER" ]] ||
  blocked 'approver must be independent from developer/evidence producer'
case "${values[decision]}" in APPROVE|REJECT) ;; *) blocked 'decision must be APPROVE|REJECT' ;; esac
(( ${#values[scope]} >= 5 && ${#values[rationale]} >= 10 )) || blocked 'scope/rationale too short'
[[ "${values[source_revision]}" == "$EXPECTED_SOURCE" ]] || blocked 'wrong source revision'
[[ "${values[subject_digest]}" == "$EXPECTED_SUBJECT" ]] || blocked 'wrong subject digest'
[[ "${values[observed_at]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || blocked 'invalid observed_at format'
observed_epoch="$(date -u -d "${values[observed_at]}" +%s 2>/dev/null)" || blocked 'invalid observed_at'
(( observed_epoch <= $(date -u +%s) + 300 )) || blocked 'approval timestamp is in the future'

receipt_root="${SDLC_HUMAN_APPROVAL_RECEIPT_ROOT:-${XDG_CONFIG_HOME:-${HOME:?HOME required}/.config}/sdlc-agents/human-approvals}"
project_hash="$(printf '%s' "$PROJECT_PATH" | sha256sum | awk '{print $1}')"
receipt="$receipt_root/$project_hash/${values[approval_id]}.receipt"
[[ -f "$receipt" && ! -L "$receipt" ]] || blocked 'launcher-owned approval receipt absent'
declare -A receipt_values=()
receipt_fields=(schema_version approval_id project_path_sha256 approval_sha256 recorded_at)
receipt_line_count="$(awk 'NF && $0 !~ /^[[:space:]]*#/ {n++} END {print n+0}' "$receipt")"
(( receipt_line_count == ${#receipt_fields[@]} )) ||
  blocked 'launcher receipt has unknown, duplicate or missing fields'
for key in "${receipt_fields[@]}"; do
  value="$(awk -F: -v wanted="$key" '$1 == wanted {v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); print v}' "$receipt")"
  count="$(awk -F: -v wanted="$key" '$1 == wanted {n++} END {print n+0}' "$receipt")"
  [[ "$count" == 1 && -n "$value" ]] || blocked "invalid receipt field: $key"
  receipt_values["$key"]="$value"
done
[[ "${receipt_values[schema_version]}" == 1 ]] || blocked 'invalid receipt schema'
[[ "${receipt_values[approval_id]}" == "${values[approval_id]}" ]] ||
  blocked 'receipt approval id mismatch'
[[ "${receipt_values[project_path_sha256]}" == "$project_hash" ]] ||
  blocked 'receipt Project binding mismatch'
[[ "${receipt_values[recorded_at]}" == "${values[observed_at]}" ]] ||
  blocked 'receipt timestamp mismatch'
approval_sha="$(sha256sum "$APPROVAL_PATH" | awk '{print $1}')"
[[ "${receipt_values[approval_sha256]}" == "$approval_sha" ]] ||
  blocked 'approval file does not match launcher receipt'

for key in "${fields[@]}"; do
  lower="${values[$key],,}"
  [[ ! "$lower" =~ (akia[0-9a-z]{8,}|gh[pousr]_[a-z0-9]+|password=|token=|secret=) ]] || blocked "secret-like value: $key"
done
echo "HUMAN APPROVAL VERIFIED: id=${values[approval_id]} decision=${values[decision]} source=$EXPECTED_SOURCE"

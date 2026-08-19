#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: human-approval-record.sh <Project> <approval-id> <source> <subject-digest> <scope> <evidence-producer>}"
APPROVAL_ID="${2:?approval id required}"
SOURCE_REVISION="${3:?source revision required}"
SUBJECT_DIGEST="${4:?subject digest required}"
SCOPE="${5:?scope required}"
EVIDENCE_PRODUCER="${6:?evidence producer required}"

fail() { echo "HUMAN APPROVAL ACTION BLOCKED: $*" >&2; exit 1; }
single_line() {
  local label="$1" value="$2"
  [[ -n "$value" && "$value" != *$'\n'* && "$value" != *$'\r'* ]] ||
    fail "$label must be a non-empty single line"
}

[[ -d "$PROJECT_INPUT" ]] || fail 'Project not found'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$APPROVAL_ID" =~ ^APPROVAL-[A-Z0-9][A-Z0-9._-]*$ ]] || fail 'invalid approval id'
[[ "$SOURCE_REVISION" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  fail 'source revision must be exact'
[[ "$SUBJECT_DIGEST" == none || "$SUBJECT_DIGEST" =~ ^[0-9a-f]{64}$ ]] ||
  fail 'subject digest must be none or SHA-256'
single_line scope "$SCOPE"
single_line evidence_producer "$EVIDENCE_PRODUCER"

printf 'Approver identity: '
IFS= read -r APPROVER
printf 'Decision (APPROVE or REJECT): '
IFS= read -r DECISION
printf 'Rationale (at least 10 characters): '
IFS= read -r RATIONALE
single_line approver_identity "$APPROVER"
single_line rationale "$RATIONALE"
[[ "$APPROVER" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || fail 'invalid approver identity'
[[ "$APPROVER" != s4-dev && "$APPROVER" != "$EVIDENCE_PRODUCER" ]] ||
  fail 'approver must be independent'
case "$DECISION" in APPROVE|REJECT) ;; *) fail 'invalid decision' ;; esac
(( ${#RATIONALE} >= 10 )) || fail 'rationale is too short'

printf '%s\n' "Approval: $APPROVAL_ID" "Project: $(basename "$PROJECT")"
printf '%s\n' "Approver: $APPROVER" "Decision: $DECISION"
printf '%s\n' "Source: $SOURCE_REVISION" "Subject digest: $SUBJECT_DIGEST" "Scope: $SCOPE"
printf 'Type "%s %s" to record this human decision: ' "$DECISION" "$APPROVAL_ID"
IFS= read -r CONFIRMATION
[[ "$CONFIRMATION" == "$DECISION $APPROVAL_ID" ]] || fail 'confirmation did not match'

APPROVAL_DIR="$PROJECT/tracking/approvals"
APPROVAL_PATH="$APPROVAL_DIR/$APPROVAL_ID.yaml"
[[ ! -e "$APPROVAL_PATH" && ! -L "$APPROVAL_PATH" ]] || fail 'approval target already exists'
RECEIPT_ROOT="${SDLC_HUMAN_APPROVAL_RECEIPT_ROOT:-${XDG_CONFIG_HOME:-${HOME:?HOME required}/.config}/sdlc-agents/human-approvals}"
PROJECT_HASH="$(printf '%s' "$PROJECT" | sha256sum | awk '{print $1}')"
RECEIPT_DIR="$RECEIPT_ROOT/$PROJECT_HASH"
RECEIPT_PATH="$RECEIPT_DIR/$APPROVAL_ID.receipt"
[[ ! -e "$RECEIPT_PATH" && ! -L "$RECEIPT_PATH" ]] || fail 'approval receipt already exists'
OBSERVED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$APPROVAL_DIR" "$RECEIPT_DIR" || fail 'cannot create approval/receipt directory'
chmod 700 "$RECEIPT_ROOT" "$RECEIPT_DIR" || fail 'cannot protect receipt directory'
APPROVAL_TMP="$(mktemp "$APPROVAL_DIR/.approval.XXXXXX")" || fail 'cannot create approval temp'
RECEIPT_TMP=''
cleanup() {
  [[ -z "${APPROVAL_TMP:-}" ]] || rm -f -- "$APPROVAL_TMP"
  [[ -z "${RECEIPT_TMP:-}" ]] || rm -f -- "$RECEIPT_TMP"
}
trap cleanup EXIT
{
  printf '%s\n' 'schema_version: 1' "approval_id: $APPROVAL_ID"
  printf '%s\n' 'approval_origin: launcher-human-v1' "approver_identity: $APPROVER"
  printf '%s\n' "decision: $DECISION" "scope: $SCOPE" "rationale: $RATIONALE"
  printf '%s\n' "source_revision: $SOURCE_REVISION" "subject_digest: $SUBJECT_DIGEST"
  printf '%s\n' "observed_at: $OBSERVED_AT"
} >"$APPROVAL_TMP"
chmod 600 "$APPROVAL_TMP"
APPROVAL_SHA="$(sha256sum "$APPROVAL_TMP" | awk '{print $1}')"

RECEIPT_TMP="$(mktemp "$RECEIPT_DIR/.receipt.XXXXXX")" || fail 'cannot create receipt temp'
{
  printf '%s\n' 'schema_version: 1' "approval_id: $APPROVAL_ID"
  printf '%s\n' "project_path_sha256: $PROJECT_HASH" "approval_sha256: $APPROVAL_SHA"
  printf '%s\n' "recorded_at: $OBSERVED_AT"
} >"$RECEIPT_TMP"
chmod 600 "$RECEIPT_TMP"
mv "$APPROVAL_TMP" "$APPROVAL_PATH"
APPROVAL_TMP=''
if ! mv "$RECEIPT_TMP" "$RECEIPT_PATH"; then
  rm -f -- "$APPROVAL_PATH"
  fail 'cannot commit launcher receipt'
fi
RECEIPT_TMP=''
echo "HUMAN APPROVAL RECORDED: $APPROVAL_ID"

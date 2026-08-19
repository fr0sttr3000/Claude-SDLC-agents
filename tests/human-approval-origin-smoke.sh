#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACTION="$ROOT/_runtimes/human-approval-record.sh"
CHECK="$ROOT/cycle1-dev/s0-validate/human-approval-check.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-human-approval.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/Project"
RECEIPTS="$TMP_DIR/operator-receipts"
mkdir -p "$PROJECT/tracking/approvals"
SOURCE='0123456789abcdef0123456789abcdef01234567'
SUBJECT='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
SCOPE='DOD-1 DOD-2 DOD-3 DOD-4 DOD-5 DOD-6 DOD-7 DOD-8 DOD-9 DOD-10 DOD-11'

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() {
  local label="$1"
  shift
  if "$@" >"$TMP_DIR/fail.out" 2>&1; then fail "$label was accepted"; fi
}

grep -Fq '_runtimes/human-approval-record.sh' "$ROOT/sdlc.sh" ||
  fail 'launcher does not own the interactive Human Approval action'
grep -Fq 'dod-approval-check.sh"' "$ROOT/sdlc.sh" ||
  fail 'launcher does not obtain a deterministic DoD approval request'

cat >"$PROJECT/tracking/approvals/APPROVAL-DOD-FORGED.yaml" <<EOF
schema_version: 1
approval_id: APPROVAL-DOD-FORGED
approval_origin: launcher-human-v1
approver_identity: tech-lead
decision: APPROVE
scope: $SCOPE
rationale: independent review completed
source_revision: $SOURCE
subject_digest: $SUBJECT
observed_at: 2026-08-17T10:00:00Z
EOF
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" expect_fail forged "$CHECK" "$PROJECT" tracking/approvals/APPROVAL-DOD-FORGED.yaml "$SOURCE" "$SUBJECT" s4-dev
rm "$PROJECT/tracking/approvals/APPROVAL-DOD-FORGED.yaml"

printf '%s\n' tech-lead APPROVE 'independent review completed' 'APPROVE APPROVAL-DOD-VALID' |
  SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" "$ACTION" "$PROJECT" APPROVAL-DOD-VALID "$SOURCE" "$SUBJECT" "$SCOPE" s4-dev >/dev/null ||
  fail 'launcher-owned human action failed'
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" "$CHECK" "$PROJECT" tracking/approvals/APPROVAL-DOD-VALID.yaml "$SOURCE" "$SUBJECT" s4-dev >/dev/null ||
  fail 'valid launcher-owned approval was rejected'

cp "$PROJECT/tracking/approvals/APPROVAL-DOD-VALID.yaml" \
  "$PROJECT/tracking/approvals/APPROVAL-KI-RENAMED.yaml"
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" expect_fail renamed "$CHECK" "$PROJECT" \
  tracking/approvals/APPROVAL-KI-RENAMED.yaml "$SOURCE" "$SUBJECT" s4-dev
rm "$PROJECT/tracking/approvals/APPROVAL-KI-RENAMED.yaml"

OTHER_PROJECT="$TMP_DIR/OtherProject"
mkdir -p "$OTHER_PROJECT/tracking/approvals"
cp "$PROJECT/tracking/approvals/APPROVAL-DOD-VALID.yaml" \
  "$OTHER_PROJECT/tracking/approvals/APPROVAL-DOD-VALID.yaml"
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" expect_fail cross-project "$CHECK" "$OTHER_PROJECT" \
  tracking/approvals/APPROVAL-DOD-VALID.yaml "$SOURCE" "$SUBJECT" s4-dev

OTHER_SOURCE='1111111111111111111111111111111111111111'
OTHER_SUBJECT='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" expect_fail wrong-source "$CHECK" "$PROJECT" \
  tracking/approvals/APPROVAL-DOD-VALID.yaml "$OTHER_SOURCE" "$SUBJECT" s4-dev
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" expect_fail wrong-subject "$CHECK" "$PROJECT" \
  tracking/approvals/APPROVAL-DOD-VALID.yaml "$SOURCE" "$OTHER_SUBJECT" s4-dev

sed -i 's/independent review completed/tampered approval rationale/' "$PROJECT/tracking/approvals/APPROVAL-DOD-VALID.yaml"
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" expect_fail tampered "$CHECK" "$PROJECT" tracking/approvals/APPROVAL-DOD-VALID.yaml "$SOURCE" "$SUBJECT" s4-dev

printf '%s\n' product-owner REJECT 'evidence does not justify approval' \
  'REJECT APPROVAL-DOD-REJECTED' |
  SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" "$ACTION" "$PROJECT" \
    APPROVAL-DOD-REJECTED "$SOURCE" "$SUBJECT" "$SCOPE" s4-dev >/dev/null ||
  fail 'launcher-owned REJECT action failed'
SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" "$CHECK" "$PROJECT" \
  tracking/approvals/APPROVAL-DOD-REJECTED.yaml "$SOURCE" "$SUBJECT" s4-dev >/dev/null ||
  fail 'authentic REJECT record was not preserved as a human decision'
if printf '%s\n' product-owner APPROVE 'second decision must not overwrite reject' \
  'APPROVE APPROVAL-DOD-REJECTED' |
  SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" "$ACTION" "$PROJECT" \
    APPROVAL-DOD-REJECTED "$SOURCE" "$SUBJECT" "$SCOPE" s4-dev >/dev/null 2>&1; then
  fail 'REJECT record was overwritten by an automatic repair approval'
fi

if printf '%s\n' product-owner |
  SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$RECEIPTS" "$ACTION" "$PROJECT" \
    APPROVAL-DOD-INTERRUPTED "$SOURCE" "$SUBJECT" "$SCOPE" s4-dev >/dev/null 2>&1; then
  fail 'interrupted human action unexpectedly succeeded'
fi
[[ ! -e "$PROJECT/tracking/approvals/APPROVAL-DOD-INTERRUPTED.yaml" ]] ||
  fail 'interrupted human action left a Project approval record'

echo 'PASS: Human Approval launcher origin smoke'

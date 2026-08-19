#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: task-dod-check.sh <Project> <task-id>}"
TASK_ID="${2:?usage: task-dod-check.sh <Project> <task-id>}"
blocked() { echo "TASK DOD BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project not found'
[[ "$TASK_ID" =~ ^T-[0-9]+$ ]] || blocked 'task id must be T-NNN'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
LEDGER="$PROJECT/tracking/task-dod-v1.tsv"
[[ -f "$LEDGER" && ! -L "$LEDGER" ]] || blocked 'tracking/task-dod-v1.tsv missing/symlink'
expected_header=$'task_id\ttask_type\tstage\tpr_number\tsource_revision\tauto_check_status\tevidence_refs\tproducer\tmanual_approval_ref\tverdict'
[[ "$(sed -n '1p' "$LEDGER")" == "$expected_header" ]] || blocked 'ledger header mismatch'
mapfile -t rows < <(awk -F '\t' -v id="$TASK_ID" 'NR > 1 && $1 == id {print}' "$LEDGER")
(( ${#rows[@]} == 1 )) || blocked "$TASK_ID must have exactly one DoD row"
IFS=$'\t' read -r task_id task_type stage pr source auto_status refs producer approval_ref verdict extra <<< "${rows[0]}"
[[ -z "$extra" ]] || blocked 'unexpected extra columns'
[[ "$task_type" =~ ^(K|D|I)$ && "$stage" =~ ^[1-5]$ ]] || blocked 'invalid task type/stage'
[[ "$pr" == none || "$pr" =~ ^[0-9]+$ ]] || blocked 'invalid PR number'
[[ "$source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] || blocked 'source revision is not exact'
[[ "$auto_status" == PASS && "$verdict" == PASS ]] || blocked 'DoD verdict is not PASS'
[[ "$producer" =~ ^[a-z][a-z0-9-]+$ && "$producer" != s0-tracker ]] || blocked 'invalid/independent producer'
[[ "$refs" != none ]] || blocked 'evidence refs are required'
IFS=',' read -r -a evidence_refs <<< "$refs"
for ref in "${evidence_refs[@]}"; do
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != ../* &&
    "$ref" != */../* && "$ref" != */.. ]] ||
    blocked "unsafe evidence ref: $ref"
  [[ -f "$PROJECT/$ref" && ! -L "$PROJECT/$ref" ]] || blocked "evidence missing/symlink: $ref"
done
[[ "$approval_ref" == tracking/approvals/APPROVAL-*.yaml &&
  "$approval_ref" != */../* && "$approval_ref" != */.. ]] ||
  blocked 'manual DoD approval ref invalid'
canonical="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
  "$task_id" "$task_type" "$stage" "$pr" "$source" "$auto_status" "$refs" "$producer" "$verdict")"
subject="$(printf '%s' "$canonical" | sha256sum | awk '{print $1}')"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$SCRIPT_DIR/human-approval-check.sh" "$PROJECT" "$approval_ref" "$source" "$subject" "$producer" >/dev/null ||
  blocked 'launcher-owned manual DoD approval invalid'
grep -Fq "task-dod:$TASK_ID" "$PROJECT/$approval_ref" || blocked 'manual approval scope mismatch'

echo "TASK DOD VERIFIED: task=$TASK_ID source=$source evidence=${#evidence_refs[@]}"

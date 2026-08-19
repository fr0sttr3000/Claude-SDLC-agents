#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: tracker-sprint-close-check.sh <Project> <sprint-number>}"
SPRINT_NUMBER="${2:?usage: tracker-sprint-close-check.sh <Project> <sprint-number>}"
blocked() { echo "TRACKER SPRINT BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project not found'
[[ "$SPRINT_NUMBER" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid sprint number'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SPRINT="$PROJECT/tracking/sprints/sprint-$(printf '%02d' "$SPRINT_NUMBER").md"
[[ -f "$SPRINT" && ! -L "$SPRINT" ]] || blocked 'sprint artifact missing/symlink'
for ledger in dor-violations.md tech-debt.md known-issues.md task-dod-v1.tsv; do
  [[ -f "$PROJECT/tracking/$ledger" && ! -L "$PROJECT/tracking/$ledger" ]] ||
    blocked "governance ledger missing/symlink: $ledger"
done
bash "$SCRIPT_DIR/tech-debt-check.sh" "$PROJECT" sprint-close "$SPRINT_NUMBER" >/dev/null ||
  blocked 'Tech Debt/Patch SLA prevents sprint close'

mapfile -t done_rows < <(awk -F'|' '
  function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
  /^\|/ {
    if (!status_col) {
      for (i=1; i<=NF; i++) {
        name=trim($i)
        if (name == "Статус" || name == "Status") status_col=i
        if (name == "SP") sp_col=i
      }
    }
    id=trim($2)
    if (id ~ /^T-[0-9]+$/ && status_col && trim($status_col) == "DONE")
      print id "\t" (sp_col ? trim($sp_col) : "0")
  }
' "$SPRINT")

velocity=0
declare -A seen=()
for row in "${done_rows[@]}"; do
  IFS=$'\t' read -r task_id points <<< "$row"
  [[ -z "${seen[$task_id]:-}" ]] || blocked "duplicate DONE task: $task_id"
  seen["$task_id"]=1
  [[ "$points" =~ ^(0|1|2|3|5|8|13)$ ]] || blocked "$task_id invalid story points"
  bash "$SCRIPT_DIR/task-dod-check.sh" "$PROJECT" "$task_id" >/dev/null ||
    blocked "$task_id is DONE without verified DoD"
  velocity=$((velocity + points))
done

echo "TRACKER SPRINT VERIFIED: sprint=$SPRINT_NUMBER done=${#done_rows[@]} velocity=$velocity"

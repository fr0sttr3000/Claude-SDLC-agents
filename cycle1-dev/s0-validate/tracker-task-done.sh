#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: tracker-task-done.sh <Project> <task-id>}"
TASK_ID="${2:?usage: tracker-task-done.sh <Project> <task-id>}"
blocked() { echo "TRACKER TASK BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project not found'
[[ "$TASK_ID" =~ ^T-[0-9]+$ ]] || blocked 'task id must be T-NNN'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$SCRIPT_DIR/task-dod-check.sh" "$PROJECT" "$TASK_ID" >/dev/null ||
  blocked "$TASK_ID DoD is not VERIFIED"

current="$PROJECT/tracking/current-sprint.md"
[[ -f "$current" && ! -L "$current" ]] || blocked 'current-sprint.md missing/symlink'
sprint_number="$(awk -F: '$1 == "sprint" {value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit}' "$current")"
[[ "$sprint_number" =~ ^[1-9][0-9]*$ ]] || blocked 'current sprint number missing/invalid'
sprint="$PROJECT/tracking/sprints/sprint-$(printf '%02d' "$sprint_number").md"
backlog="$PROJECT/tracking/backlog.md"
for file in "$sprint" "$backlog"; do
  [[ -f "$file" && ! -L "$file" ]] || blocked "${file#$PROJECT/} missing/symlink"
done

task_status() {
  local file="$1"
  awk -F'|' -v wanted="$TASK_ID" '
    function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
    /^\|/ {
      if (!status_col) {
        for (i=1; i<=NF; i++) if (trim($i) == "Статус" || trim($i) == "Status") status_col=i
      }
      if (trim($2) == wanted && status_col) {print trim($status_col); found++}
    }
    END {if (found != 1) exit 1}
  ' "$file"
}

files=("$sprint" "$backlog" "$current")
for file in "${files[@]}"; do
  status="$(task_status "$file")" ||
    blocked "$TASK_ID must occur exactly once in ${file#$PROJECT/}"
  [[ "$status" =~ ^(TODO|IN_PROGRESS|BLOCKED)$ ]] ||
    blocked "$TASK_ID status cannot transition to DONE from $status in ${file#$PROJECT/}"
done

temps=()
backups=()
cleanup() {
  local path
  for path in "${temps[@]:-}" "${backups[@]:-}"; do
    [[ -z "$path" || ! -e "$path" ]] || rm -f "$path"
  done
}
trap cleanup EXIT

for file in "${files[@]}"; do
  tmp="$(mktemp "$(dirname "$file")/.tracker-task.XXXXXX")"
  awk -F'|' -v wanted="$TASK_ID" '
    BEGIN {OFS="|"}
    function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
    /^\|/ {
      if (!status_col) {
        for (i=1; i<=NF; i++) if (trim($i) == "Статус" || trim($i) == "Status") status_col=i
      }
      if (trim($2) == wanted && status_col) {$status_col=" DONE "; changed++}
    }
    {print}
    END {if (changed != 1) exit 1}
  ' "$file" > "$tmp" || { rm -f "$tmp"; blocked "cannot prepare ${file#$PROJECT/}"; }
  temps+=("$tmp")
done

published=0
for index in "${!files[@]}"; do
  file="${files[$index]}"
  backup="$(mktemp "$(dirname "$file")/.tracker-backup.XXXXXX")"
  cp -p "$file" "$backup"
  backups+=("$backup")
  mv "${temps[$index]}" "$file"
  temps[$index]=''
  published=$((published + 1))
  if [[ "${TRACKER_FAULT_AFTER_PUBLISH:-0}" == "$published" ]]; then
    for rollback in $(seq 0 $((published - 1))); do
      cp -p "${backups[$rollback]}" "${files[$rollback]}"
    done
    blocked "fault injection after publish $published; transaction rolled back"
  fi
done

for file in "${files[@]}"; do
  [[ "$(task_status "$file")" == DONE ]] ||
    blocked "post-transaction status mismatch: ${file#$PROJECT/}"
done
echo "TRACKER TASK VERIFIED: task=$TASK_ID status=DONE files=3 source=$(awk -F '\t' -v id="$TASK_ID" '$1 == id {print $5}' "$PROJECT/tracking/task-dod-v1.tsv")"

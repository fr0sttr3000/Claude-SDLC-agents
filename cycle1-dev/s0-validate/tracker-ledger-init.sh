#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: tracker-ledger-init.sh <Project>}"
blocked() { echo "TRACKER INIT BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project not found'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
TRACKING="$PROJECT/tracking"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
mkdir -p "$TRACKING"
project_name="${PROJECT##*/}"
created=0

install_template() {
  local target="$1" template="$2" tmp
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] || blocked "${target##*/} is not a regular file"
    return 0
  fi
  [[ -f "$template" && ! -L "$template" ]] || blocked "canonical template missing: ${template##*/}"
  tmp="$(mktemp "$TRACKING/.tracker-ledger.XXXXXX")"
  sed "s/{PROJECT}/$project_name/g" "$template" > "$tmp"
  [[ -s "$tmp" ]] || { rm -f "$tmp"; blocked "template rendered empty: ${template##*/}"; }
  mv "$tmp" "$target"
  created=$((created + 1))
}

install_template "$TRACKING/dor-violations.md" "$ROOT/_standards/dor-violations-template.md"
install_template "$TRACKING/tech-debt.md" "$ROOT/_standards/tech-debt-template.md"
install_template "$TRACKING/known-issues.md" "$ROOT/_standards/known-issues-template.md"

task_ledger="$TRACKING/task-dod-v1.tsv"
if [[ -e "$task_ledger" || -L "$task_ledger" ]]; then
  [[ -f "$task_ledger" && ! -L "$task_ledger" ]] ||
    blocked 'task-dod-v1.tsv is not a regular file'
else
  tmp="$(mktemp "$TRACKING/.task-dod.XXXXXX")"
  printf '%s\n' $'task_id\ttask_type\tstage\tpr_number\tsource_revision\tauto_check_status\tevidence_refs\tproducer\tmanual_approval_ref\tverdict' > "$tmp"
  mv "$tmp" "$task_ledger"
  created=$((created + 1))
fi

echo "TRACKER LEDGERS VERIFIED: created=$created preserved=$((4 - created))"

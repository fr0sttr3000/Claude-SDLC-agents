#!/bin/bash
set -euo pipefail

project="${1:-}"
mode="${2:-check}"

fail() {
  echo "STRUCTURE BLOCKED: $*" >&2
  exit 1
}

[[ "$mode" == check || "$mode" == fix ]] || fail 'mode must be check or fix'
[[ -n "$project" && -d "$project" && ! -L "$project" ]] ||
  fail 'Project root must be an existing non-symlink directory'

project="$(cd "$project" && pwd -P)"
missing=0
changed=0

ensure_dir() {
  local ref="$1" target
  target="$project/$ref"
  if [[ -d "$target" && ! -L "$target" ]]; then
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    fail "$ref exists but is not a safe directory"
  fi
  if [[ "$mode" == fix ]]; then
    mkdir -p "$target"
    echo "CREATED DIR: $ref"
    changed=$((changed + 1))
  else
    echo "MISSING DIR: $ref"
    missing=$((missing + 1))
  fi
}

ensure_file() {
  local ref="$1" content="$2" target
  target="$project/$ref"
  if [[ -f "$target" && ! -L "$target" ]]; then
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    fail "$ref exists but is not a safe regular file"
  fi
  if [[ "$mode" == fix ]]; then
    printf '%s\n' "$content" > "$target"
    echo "CREATED FILE: $ref"
    changed=$((changed + 1))
  else
    echo "MISSING FILE: $ref"
    missing=$((missing + 1))
  fi
}

for stage in stage1-planning stage2-requirements stage3-design stage4-dev stage5-testing; do
  ensure_dir "$stage/inputs"
  ensure_dir "$stage/outputs"
done

ensure_file stage1-planning/inputs/idea.md \
  $'# Идея проекта\n\nОпишите проблему, пользователей, ожидаемый результат и ограничения.'
ensure_file Dashboard.md \
  $'# Project Dashboard\n\n| Stage | Status |\n|---|---|\n| S1 Planning | Pending |\n| S2 Requirements | Pending |\n| S3 Design | Pending |\n| S4 Development | Pending |\n| S5 Testing | Pending |'

if [[ "$mode" == check && "$missing" -gt 0 ]]; then
  fail "$missing required path(s) missing"
fi

echo "STRUCTURE VERIFIED: mode=$mode changed=$changed project=$project"

#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: tracker-tech-debt-materialize.sh <Project> <sprint-number> <sprint-end-date>}"
TARGET_SPRINT="${2:?usage: tracker-tech-debt-materialize.sh <Project> <sprint-number> <sprint-end-date>}"
SPRINT_END="${3:?usage: tracker-tech-debt-materialize.sh <Project> <sprint-number> <sprint-end-date>}"

blocked() { echo "TECH DEBT MATERIALIZATION BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project not found'
[[ "$TARGET_SPRINT" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid sprint number'
[[ "$SPRINT_END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || blocked 'invalid sprint end date'
[[ "$(date -u -d "$SPRINT_END" +%Y-%m-%d 2>/dev/null || true)" == "$SPRINT_END" ]] ||
  blocked 'invalid calendar sprint end date'

PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
LEDGER="$PROJECT/tracking/tech-debt.md"
SPRINT="$PROJECT/tracking/sprints/sprint-$(printf '%02d' "$TARGET_SPRINT").md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[[ -f "$LEDGER" && ! -L "$LEDGER" ]] || blocked 'tracking/tech-debt.md missing/symlink'
[[ -f "$SPRINT" && ! -L "$SPRINT" ]] || blocked 'target sprint artifact missing/symlink'
[[ "$(awk -F: '$1 == "sprint" {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$SPRINT")" == "$TARGET_SPRINT" ]] ||
  blocked 'target sprint artifact number mismatch'
[[ "$(awk -F: '$1 == "end" {value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit}' "$SPRINT")" == "$SPRINT_END" ]] ||
  blocked 'confirmed sprint end date mismatch'

block_for() {
  local td_id="$1"
  awk -v wanted="$td_id" '
    $0 ~ "^###[[:space:]]+" wanted "([[:space:]]|—|-)" {active=1}
    active && $0 ~ "^###[[:space:]]+TD-" &&
      $0 !~ "^###[[:space:]]+" wanted "([[:space:]]|—|-)" {exit}
    active {print}
  ' "$LEDGER"
}

entry_field() {
  local block="$1" wanted="$2"
  awk -v wanted="$wanted" '
    index($0, "- " wanted ":") == 1 {
      value=$0; sub("^- " wanted ":[[:space:]]*", "", value)
      sub(/[[:space:]]+$/, "", value); print value; exit
    }
  ' <<< "$block"
}

changed=0
while IFS= read -r td_id; do
  block="$(block_for "$td_id")"
  [[ "$(entry_field "$block" 'Target sprint')" == NEXT ]] || continue
  source_sprint="$(entry_field "$block" 'Source sprint')"
  severity="$(entry_field "$block" 'Finding severity')"
  deadline="$(entry_field "$block" 'Дедлайн устранения')"
  status="$(entry_field "$block" 'Статус')"
  [[ "$source_sprint" =~ ^[1-9][0-9]*$ ]] || blocked "$td_id has invalid Source sprint"
  [[ "$status" == OPEN || "$status" == IN_PROGRESS ]] ||
    blocked "$td_id with Target sprint NEXT is not active"
  case "$severity" in
    S4|SECURITY_LOW) max_sprints=3 ;;
    *) max_sprints=1 ;;
  esac
  (( TARGET_SPRINT > source_sprint && TARGET_SPRINT <= source_sprint + max_sprints )) ||
    blocked "$td_id target sprint exceeds the allowed remediation window"
  if [[ "$deadline" != PENDING ]]; then
    [[ "$deadline" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ &&
      "$(date -u -d "$deadline" +%Y-%m-%d 2>/dev/null || true)" == "$deadline" ]] ||
      blocked "$td_id has invalid remediation deadline"
    (( $(date -u -d "$deadline" +%s) <= $(date -u -d "$SPRINT_END" +%s) )) ||
      blocked "$td_id remediation deadline is after target sprint end"
  fi
  changed=$((changed + 1))
done < <(sed -n -E 's/^###[[:space:]]+(TD-[A-Z0-9][A-Z0-9._-]*).*/\1/p' "$LEDGER")

if (( changed == 0 )); then
  bash "$SCRIPT_DIR/tech-debt-check.sh" "$PROJECT" sprint-init "$TARGET_SPRINT" >/dev/null ||
    blocked 'existing materialized Tech Debt does not satisfy sprint-init validation'
  echo "TECH DEBT MATERIALIZATION VERIFIED: sprint=$TARGET_SPRINT changed=0"
  exit 0
fi

tmp="$(mktemp "$PROJECT/tracking/.tech-debt-materialized.XXXXXX")"
backup="$(mktemp "$PROJECT/tracking/.tech-debt-backup.XXXXXX")"
cleanup() { rm -f "$tmp" "$backup"; }
trap cleanup EXIT
cp "$LEDGER" "$backup"
awk -v target="$TARGET_SPRINT" -v deadline="$SPRINT_END" '
  /^###[[:space:]]+TD-[A-Z0-9]/ {in_entry=1; materialize=0}
  /^###[[:space:]]+/ && $0 !~ /^###[[:space:]]+TD-[A-Z0-9]/ {in_entry=0; materialize=0}
  in_entry && $0 == "- Target sprint: NEXT" {
    print "- Target sprint: " target
    materialize=1
    next
  }
  in_entry && materialize && $0 == "- Дедлайн устранения: PENDING" {
    print "- Дедлайн устранения: " deadline
    next
  }
  {print}
' "$LEDGER" > "$tmp"
[[ -s "$tmp" ]] || blocked 'materialized ledger is empty'
mv "$tmp" "$LEDGER"
if ! bash "$SCRIPT_DIR/tech-debt-check.sh" "$PROJECT" sprint-init "$TARGET_SPRINT" >/dev/null; then
  mv "$backup" "$LEDGER"
  blocked 'materialized ledger failed sprint-init validation and was rolled back'
fi
rm -f "$backup"
echo "TECH DEBT MATERIALIZATION VERIFIED: sprint=$TARGET_SPRINT changed=$changed"

#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
MODE="${2:?Укажи mode: exception|security-low|security-lifecycle|known-issue|sprint-init|sprint-close}"
blocked() { echo "TECH DEBT BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
LEDGER="$PROJECT_PATH/tracking/tech-debt.md"
[[ -f "$LEDGER" && ! -L "$LEDGER" ]] || blocked 'tracking/tech-debt.md отсутствует или является symlink'

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

block_for() {
  local td_id="$1"
  awk -v wanted="$td_id" '
    $0 ~ "^###[[:space:]]+" wanted "([[:space:]]|—|-)" { active=1 }
    active && $0 ~ "^###[[:space:]]+TD-" && $0 !~ "^###[[:space:]]+" wanted "([[:space:]]|—|-)" { exit }
    active { print }
  ' "$LEDGER"
}

entry_field() {
  local block="$1" wanted="$2"
  awk -v wanted="$wanted" '
    index($0, "- " wanted ":") == 1 {
      value=$0
      sub("^- " wanted ":[[:space:]]*", "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' <<< "$block"
}

sprint_file_for() {
  local wanted="$1" file value
  while IFS= read -r -d '' file; do
    value="$(awk -F: '$1 == "sprint" { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$file")"
    [[ "$value" == "$wanted" ]] && { printf '%s\n' "$file"; return 0; }
  done < <(find "$PROJECT_PATH/tracking/sprints" -maxdepth 1 -type f -name 'sprint-*.md' -print0 2>/dev/null)
  return 1
}

validate_entry_schedule() {
  local td_id="$1" max_sprints="${2:-1}" block source_sprint target_sprint deadline sprint_file sprint_end
  block="$(block_for "$td_id")"
  [[ -n "$block" ]] || blocked "$td_id отсутствует в tracking/tech-debt.md"
  source_sprint="$(trim "$(entry_field "$block" 'Source sprint')")"
  target_sprint="$(trim "$(entry_field "$block" 'Target sprint')")"
  deadline="$(trim "$(entry_field "$block" 'Дедлайн устранения')")"
  [[ "$source_sprint" =~ ^[1-9][0-9]*$ ]] || blocked "$td_id: Source sprint должен быть числом"
  [[ "$target_sprint" != NEXT ]] || blocked "$td_id: Target sprint NEXT ещё не материализован /sprint-init"
  [[ "$target_sprint" =~ ^[1-9][0-9]*$ ]] || blocked "$td_id: Target sprint должен быть числом"
  (( target_sprint > source_sprint && target_sprint <= source_sprint + max_sprints )) ||
    blocked "$td_id: remediation должна быть в пределах $max_sprints sprint после Source sprint"
  [[ "$deadline" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || blocked "$td_id: invalid remediation deadline"
  sprint_file="$(sprint_file_for "$target_sprint")" || blocked "$td_id: sprint boundary $target_sprint не задан Project artifact"
  sprint_end="$(awk -F: '$1 == "end" { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit }' "$sprint_file")"
  [[ "$sprint_end" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || blocked "$td_id: target sprint end invalid"
  (( $(date -u -d "$deadline" +%s) <= $(date -u -d "$sprint_end" +%s) )) ||
    blocked "$td_id: remediation deadline позже конца target sprint"
}

entry_owner() {
  local block="$1" value
  value="$(entry_field "$block" 'Owner')"
  [[ -n "$value" ]] || value="$(entry_field "$block" 'Security owner')"
  printf '%s' "$value"
}

entry_finding_ids() {
  local block="$1" value
  value="$(entry_field "$block" 'Finding IDs')"
  [[ -n "$value" ]] || value="$(entry_field "$block" 'Security finding IDs')"
  printf '%s' "$value"
}

entry_exception_type() {
  local block="$1" value cvss
  value="$(entry_field "$block" 'Exception type')"
  if [[ -z "$value" ]]; then
    cvss="$(entry_field "$block" 'CVSS')"
    [[ "$cvss" =~ ^[0-9]+([.][0-9]+)?$ ]] && value=security
  fi
  printf '%s' "$value"
}

entry_finding_severity() {
  local block="$1" value cvss
  value="$(entry_field "$block" 'Finding severity')"
  if [[ -z "$value" ]]; then
    cvss="$(entry_field "$block" 'CVSS')"
    if [[ "$cvss" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      if awk -v score="$cvss" 'BEGIN { exit !(score >= 4.0 && score < 7.0) }'; then
        value=SECURITY_MEDIUM
      elif awk -v score="$cvss" 'BEGIN { exit !(score > 0 && score < 4.0) }'; then
        value=SECURITY_LOW
      fi
    fi
  fi
  printf '%s' "$value"
}

entry_covers_finding() {
  local block="$1" wanted="$2" value
  IFS=',' read -r -a values <<< "$(entry_finding_ids "$block")"
  for value in "${values[@]}"; do
    [[ "$(trim "$value")" == "$wanted" ]] && return 0
  done
  return 1
}

expected_exception_severity() {
  case "$1" in
    security) printf '%s' SECURITY_MEDIUM ;;
    performance) printf '%s' PERFORMANCE_THRESHOLD ;;
    quality) printf '%s' QUALITY_THRESHOLD ;;
    reliability) printf '%s' RELIABILITY_THRESHOLD ;;
    accessibility) printf '%s' ACCESSIBILITY_GAP ;;
    compatibility) printf '%s' COMPATIBILITY_GAP ;;
    safety) printf '%s' SAFETY_GAP ;;
    *) blocked "unsupported exception type: $1" ;;
  esac
}

validate_typed_entry() {
  local td_id="$1" expected_type="$2" expected_severity="$3" expected_owner="$4"
  local expected_findings="$5" expected_exception="$6" max_sprints="${7:-1}"
  local block finding status cvss
  block="$(block_for "$td_id")"
  [[ -n "$block" ]] || blocked "$td_id отсутствует в tracking/tech-debt.md"
  [[ "$(entry_exception_type "$block")" == "$expected_type" ]] ||
    blocked "$td_id: Exception type mismatch"
  [[ "$(entry_finding_severity "$block")" == "$expected_severity" ]] ||
    blocked "$td_id: Finding severity mismatch"
  [[ "$(entry_owner "$block")" == "$expected_owner" ]] ||
    blocked "$td_id: owner mismatch"
  [[ "$(entry_field "$block" 'Risk exception')" == "$expected_exception" ]] ||
    blocked "$td_id: risk exception mismatch"
  IFS=',' read -r -a expected_ids <<< "$expected_findings"
  for finding in "${expected_ids[@]}"; do
    finding="$(trim "$finding")"
    [[ -n "$finding" ]] || blocked "$td_id: empty finding id"
    entry_covers_finding "$block" "$finding" ||
      blocked "$td_id: finding $finding отсутствует"
  done
  if [[ "$expected_type" == security ]]; then
    cvss="$(entry_field "$block" 'CVSS')"
    [[ "$cvss" =~ ^[0-9]+([.][0-9]+)?$ ]] || blocked "$td_id: CVSS отсутствует"
    case "$expected_severity" in
      SECURITY_MEDIUM)
        awk -v value="$cvss" 'BEGIN { exit !(value >= 4.0 && value < 7.0) }' ||
          blocked "$td_id: SECURITY_MEDIUM требует CVSS 4.0–6.9"
        ;;
      SECURITY_LOW)
        awk -v value="$cvss" 'BEGIN { exit !(value > 0 && value < 4.0) }' ||
          blocked "$td_id: SECURITY_LOW требует CVSS 0.1–3.9"
        ;;
      *) blocked "$td_id: unsupported security severity" ;;
    esac
  fi
  status="$(entry_field "$block" 'Статус')"
  [[ "$status" == OPEN || "$status" == IN_PROGRESS ]] ||
    blocked "$td_id: status не активен"
  validate_entry_schedule "$td_id" "$max_sprints"
}

case "$MODE" in
  exception)
    TD_ID="${3:?Укажи tech debt id}"
    EXCEPTION_ID="${4:?Укажи exception id}"
    EXPECTED_OWNER="${5:?Укажи owner}"
    EXPECTED_FINDINGS="${6:?Укажи finding ids}"
    EXPECTED_TYPE="${7:?Укажи exception type}"
    [[ "$TD_ID" =~ ^TD-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid tech_debt_id'
    EXPECTED_SEVERITY="$(expected_exception_severity "$EXPECTED_TYPE")"
    validate_typed_entry "$TD_ID" "$EXPECTED_TYPE" "$EXPECTED_SEVERITY" \
      "$EXPECTED_OWNER" "$EXPECTED_FINDINGS" "$EXCEPTION_ID" 1
    echo "TECH DEBT VERIFIED: id=$TD_ID type=$EXPECTED_TYPE exception=$EXCEPTION_ID"
    ;;
  security-low)
    EXPECTED_FINDINGS="${3:?Укажи security finding ids}"
    IFS=',' read -r -a expected_ids <<< "$EXPECTED_FINDINGS"
    for finding in "${expected_ids[@]}"; do
      finding="$(trim "$finding")"
      [[ -n "$finding" ]] || blocked 'empty Low security finding id'
      matched=''
      while IFS= read -r td_id; do
        block="$(block_for "$td_id")"
        entry_covers_finding "$block" "$finding" || continue
        owner="$(entry_owner "$block")"
        [[ -n "$owner" ]] || blocked "$td_id: Owner отсутствует"
        validate_typed_entry "$td_id" security SECURITY_LOW "$owner" "$finding" none 3
        matched="$td_id"
        break
      done < <(sed -n -E 's/^###[[:space:]]+(TD-[A-Z0-9][A-Z0-9._-]*).*/\1/p' "$LEDGER")
      [[ -n "$matched" ]] || blocked "Low security finding $finding отсутствует в tracking/tech-debt.md"
    done
    echo "TECH DEBT LOW VERIFIED: findings=$EXPECTED_FINDINGS"
    ;;
  security-lifecycle)
    TD_ID="${3:?Укажи tech debt id}"
    EXPECTED_FINDING="${4:?Укажи security finding id}"
    EXPECTED_LEVEL="${5:?Укажи LOW или MEDIUM}"
    EXPECTED_EXCEPTION="${6:-none}"
    [[ "$TD_ID" =~ ^TD-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid tech_debt_id'
    block="$(block_for "$TD_ID")"
    owner="$(entry_owner "$block")"
    [[ -n "$owner" ]] || blocked "$TD_ID: Owner отсутствует"
    case "$EXPECTED_LEVEL" in
      LOW)
        [[ "$EXPECTED_EXCEPTION" == none ]] ||
          blocked "$TD_ID: Low finding не требует Risk Exception"
        validate_typed_entry "$TD_ID" security SECURITY_LOW "$owner" \
          "$EXPECTED_FINDING" none 3
        ;;
      MEDIUM)
        [[ "$EXPECTED_EXCEPTION" =~ ^RISK-[A-Z0-9][A-Z0-9._-]*$ ]] ||
          blocked "$TD_ID: Medium finding требует exact Risk Exception"
        validate_typed_entry "$TD_ID" security SECURITY_MEDIUM "$owner" \
          "$EXPECTED_FINDING" "$EXPECTED_EXCEPTION" 1
        ;;
      *) blocked 'security-lifecycle level должен быть LOW|MEDIUM' ;;
    esac
    echo "TECH DEBT SECURITY VERIFIED: id=$TD_ID finding=$EXPECTED_FINDING severity=$EXPECTED_LEVEL"
    ;;
  known-issue)
    TD_ID="${3:?Укажи tech debt id}"
    EXPECTED_FINDING="${4:?Укажи finding id}"
    EXPECTED_SEVERITY="${5:?Укажи S3|S4|CVSS-MEDIUM|CVSS-LOW}"
    [[ "$TD_ID" =~ ^TD-[A-Z0-9][A-Z0-9._-]*$ ]] || blocked 'invalid tech_debt_id'
    block="$(block_for "$TD_ID")"
    [[ -n "$block" ]] || blocked "$TD_ID отсутствует в tracking/tech-debt.md"
    owner="$(entry_owner "$block")"
    plan="$(entry_field "$block" 'План устранения')"
    status="$(entry_field "$block" 'Статус')"
    [[ -n "$owner" ]] || blocked "$TD_ID: Owner отсутствует"
    [[ ${#plan} -ge 10 ]] || blocked "$TD_ID: план устранения отсутствует или слишком краткий"
    entry_covers_finding "$block" "$EXPECTED_FINDING" ||
      blocked "$TD_ID: finding $EXPECTED_FINDING отсутствует"
    [[ "$status" == OPEN || "$status" == IN_PROGRESS ]] ||
      blocked "$TD_ID: status не активен"
    case "$EXPECTED_SEVERITY" in
      S3|CVSS-MEDIUM) max_sprints=1 ;;
      S4|CVSS-LOW) max_sprints=3 ;;
      *) blocked 'Known Issue severity должна быть S3|S4|CVSS-MEDIUM|CVSS-LOW' ;;
    esac
    validate_entry_schedule "$TD_ID" "$max_sprints"
    echo "TECH DEBT KNOWN ISSUE VERIFIED: id=$TD_ID finding=$EXPECTED_FINDING severity=$EXPECTED_SEVERITY"
    ;;
  sprint-init)
    TARGET_SPRINT="${3:?Укажи новый sprint number}"
    [[ "$TARGET_SPRINT" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid sprint number'
    open_count="$(rg -c '^- Статус: (OPEN|IN_PROGRESS)$' "$LEDGER" || true)"
    (( open_count <= 3 )) || blocked "open tech debt count $open_count exceeds 3"
    if rg -n '^- Target sprint: NEXT$' "$LEDGER" >/dev/null; then
      blocked 'Target sprint NEXT должен быть материализован новым sprint number/end date'
    fi
    if rg -n '^- Дедлайн устранения: PENDING$' "$LEDGER" >/dev/null; then
      blocked 'Дедлайн устранения PENDING должен быть материализован подтверждённой датой'
    fi
    while IFS= read -r td_id; do
      block="$(block_for "$td_id")"
      status="$(entry_field "$block" 'Статус')"
      [[ "$status" == OPEN || "$status" == IN_PROGRESS ]] || continue
      severity="$(entry_finding_severity "$block")"
      case "$severity" in
        S4|SECURITY_LOW) max_sprints=3 ;;
        *) max_sprints=1 ;;
      esac
      validate_entry_schedule "$td_id" "$max_sprints"
    done < <(sed -n -E 's/^###[[:space:]]+(TD-[A-Z0-9][A-Z0-9._-]*).*/\1/p' "$LEDGER")
    echo "TECH DEBT SPRINT INIT VERIFIED: sprint=$TARGET_SPRINT open=$open_count"
    ;;
  sprint-close)
    CLOSING_SPRINT="${3:?Укажи closing sprint number}"
    [[ "$CLOSING_SPRINT" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid sprint number'
    while IFS= read -r td_id; do
      block="$(block_for "$td_id")"
      status="$(entry_field "$block" 'Статус')"
      [[ "$status" == OPEN || "$status" == IN_PROGRESS ]] || continue
      target="$(entry_field "$block" 'Target sprint')"
      [[ "$target" != NEXT ]] || blocked "$td_id: unresolved Target sprint NEXT"
      [[ "$target" =~ ^[1-9][0-9]*$ ]] || blocked "$td_id: invalid Target sprint"
      (( target > CLOSING_SPRINT )) || blocked "$td_id unresolved at sprint-close"
    done < <(sed -n -E 's/^###[[:space:]]+(TD-[A-Z0-9][A-Z0-9._-]*).*/\1/p' "$LEDGER")
    echo "TECH DEBT SPRINT CLOSE VERIFIED: sprint=$CLOSING_SPRINT"
    ;;
  *) blocked 'mode должен быть exception|security-low|security-lifecycle|known-issue|sprint-init|sprint-close' ;;
esac

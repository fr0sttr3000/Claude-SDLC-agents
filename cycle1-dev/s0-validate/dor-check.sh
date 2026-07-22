#!/usr/bin/env bash
# DoR Auto-Check — автоматизируемая часть готовности Quality Gate.
# Использование: bash dor-check.sh <PROJECT_PATH> <GATE>
# GATE: 1|2|3|4|5|6 (номер закрываемого gate, не номер следующего stage).

set -euo pipefail

PROJECT_PATH="${1:?Укажи путь к проекту}"
GATE="${2:?Укажи gate: 1|2|3|4|5|6}"

[[ -d "$PROJECT_PATH" ]] || { echo "Проект не найден: $PROJECT_PATH" >&2; exit 2; }
[[ "$GATE" =~ ^[1-6]$ ]] || { echo 'Gate должен быть целым числом 1..6' >&2; exit 2; }
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

pass() { echo -e "  ${GREEN}✅ $1${NC}"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}❌ $1${NC}"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; WARN=$((WARN + 1)); }

first_match() {
  local pattern="$1"
  find "$PROJECT_PATH" -type f -path "$PROJECT_PATH/$pattern" -print -quit 2>/dev/null
}

check_file_exists() {
  local pattern="$1" label="$2" match
  match="$(first_match "$pattern")"
  if [[ -n "$match" ]]; then
    pass "$label"
  else
    fail "$label — НЕ НАЙДЕН"
  fi
}

check_file_or_na() {
  local pattern="$1" na_pattern="$2" label="$3" match na
  match="$(first_match "$pattern")"
  na="$(first_match "$na_pattern")"
  if [[ -n "$match" ]]; then
    pass "$label"
  elif [[ -n "$na" ]] && grep -Eqi 'applicability:[[:space:]]*not-applicable|status:[[:space:]]*not-applicable' "$na"; then
    pass "$label — явно not-applicable"
  else
    fail "$label — нет артефакта или обоснованного not-applicable decision"
  fi
}

check_status_pass() {
  local pattern="$1" label="$2" match
  match="$(first_match "$pattern")"
  if [[ -z "$match" ]]; then
    fail "$label — НЕ НАЙДЕН"
  elif grep -Eqi '(^|[[:space:]])(status:[[:space:]]*PASS|GATE[[:space:]]+[0-9]+[[:space:]]+PASSED)([[:space:]]|$)' "$match"; then
    pass "$label — PASS"
  else
    fail "$label — PASS/PASSED не подтверждён"
  fi
}

echo
echo "╔═ DoR Auto-Check — Gate ${GATE} ══════════════════════════════╗"
echo "  Проект: ${PROJECT_PATH}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo
echo '  [DoR-1] Обязательные артефакты и evidence'

case "$GATE" in
  1)
    check_file_exists 'stage1-planning/outputs/PM-*feasibility*.md' 'PM-feasibility.md'
    check_file_exists 'stage1-planning/outputs/PMO-*charter*.md' 'PMO-charter.md'
    check_file_exists 'stage1-planning/outputs/PMO-*risk-register*.md' 'PMO-risk-register.md'
    ;;
  2)
    check_file_exists 'stage2-requirements/outputs/BA-*BRD*.md' 'BA-BRD.md'
    check_file_exists 'stage2-requirements/outputs/BA-*NFR*.md' 'BA-NFR.md'
    check_file_exists 'stage2-requirements/outputs/BA-*RTM*.md' 'BA-RTM.md'
    check_file_exists 'stage2-requirements/outputs/PO-*backlog*.md' 'PO-backlog.md'
    check_status_pass 'stage2-requirements/outputs/QA-REQ-*review*.md' 'QA-REQ-review.md / Gate 2'
    check_file_exists 'stage2-requirements/outputs/QA-*test-strategy*.md' 'QA-test-strategy.md'
    check_file_exists 'stage2-requirements/outputs/SEC-*security-requirements*.md' 'SEC-security-requirements.md / SG1'
    ;;
  3)
    check_file_exists 'stage3-design/outputs/ARCH-*HLD*.md' 'ARCH-HLD.md'
    check_file_or_na 'stage3-design/outputs/ARCH-*api-spec*.yaml' \
      'stage3-design/outputs/ARCH-*api-not-applicable*.md' 'API contract decision'
    check_file_exists 'stage3-design/outputs/SEC-*threat-model*.md' 'SEC-threat-model.md / SG2'
    check_file_or_na 'stage3-design/outputs/RBAC-*model*.md' \
      'stage3-design/outputs/RBAC-*not-applicable*.md' 'RBAC model decision'
    check_file_or_na 'stage3-design/outputs/RBAC-*matrix*.md' \
      'stage3-design/outputs/RBAC-*not-applicable*.md' 'RBAC matrix decision'
    check_file_or_na 'stage3-design/outputs/DBA-schema*' \
      'stage3-design/outputs/DBA-*not-applicable*.md' 'Data-store schema decision'
    ;;
  4)
    check_file_exists 'stage4-dev/outputs/TL-*review-PR*.md' 'TL-review (хотя бы один)'
    check_file_exists 'stage4-dev/outputs/DEV-*update-notes-PR*.md' 'DEV-update-notes'
    check_status_pass 'stage4-dev/outputs/QA-TDD-status.md' 'QA-TDD-status.md'
    check_file_exists 'stage4-dev/outputs/SEC-*build-scan-PR*.md' 'SEC build scan / SG3'
    ;;
  5)
    check_status_pass 'stage5-testing/outputs/QA-*go-no-go*.md' 'QA-go-no-go.md / Gate 5'
    check_file_exists 'stage5-testing/outputs/PERF-*report*.md' 'PERF-report.md'
    check_file_exists 'stage5-testing/outputs/AUTO-*coverage*.md' 'AUTO-coverage.md'
    check_status_pass 'stage5-testing/outputs/SEC-*pentest-report*.md' 'SEC pentest / SG4'
    ;;
  6)
    check_status_pass 'stage6-deploy/outputs/DEPLOY-TDD-status.md' 'DEPLOY-TDD-status.md'
    check_status_pass 'stage6-deploy/outputs/REL-*checklist*.md' 'REL-checklist.md'
    check_file_exists 'stage6-deploy/outputs/REL-*release-notes*.md' 'REL-release-notes.md'
    if [[ -f "$PROJECT_PATH/CHANGELOG.md" ]]; then
      pass 'CHANGELOG.md'
    else
      fail 'CHANGELOG.md — НЕ НАЙДЕН в корне проекта'
    fi
    ;;
esac

echo
echo '  [DoR-5] Открытые BLOCKER-вопросы (частичная проверка)'
BLOCKER_COUNT=0
while IFS= read -r -d '' file; do
  count="$(grep -Ei 'BLOCKER.*OPEN|OPEN.*BLOCKER' "$file" 2>/dev/null |
    grep -Evi 'no[[:space:]]+open[[:space:]]+blocker|нет[[:space:]]+открытых[[:space:]]+blocker' |
    wc -l || true)"
  BLOCKER_COUNT=$((BLOCKER_COUNT + count))
done < <(find "$PROJECT_PATH" -type f -name '*.md' -path '*/outputs/*' -print0 2>/dev/null)
if (( BLOCKER_COUNT == 0 )); then
  pass '0 открытых BLOCKER найдено в outputs/'
else
  fail "$BLOCKER_COUNT BLOCKER(ов) со статусом OPEN — требуется ручная проверка"
fi

if [[ "$GATE" == 2 ]]; then
  echo
  echo '  [DoR-2..4] Качество требований (частичная проверка)'
  BRD_FILE="$(first_match 'stage2-requirements/outputs/BA-*BRD*.md')"
  BACKLOG="$(first_match 'stage2-requirements/outputs/PO-*backlog*.md')"
  NFR_FILE="$(first_match 'stage2-requirements/outputs/BA-*NFR*.md')"
  if [[ -n "$BRD_FILE" ]]; then
    FUZZY="$(grep -Eci 'и/или|обычно|при необходимости|TBD|по возможности' "$BRD_FILE" 2>/dev/null || true)"
    (( FUZZY == 0 )) && pass 'Размытых формулировок не найдено в BRD' ||
      warn "$FUZZY потенциально размытых формулировок в BRD — проверить вручную"
  fi
  if [[ -n "$BACKLOG" ]] && grep -Eqi 'Given|When|Then' "$BACKLOG"; then
    pass 'Given/When/Then найдены в backlog'
  else
    fail 'Given/When/Then не найдены в backlog — AC отсутствуют'
  fi
  if [[ -n "$NFR_FILE" ]] && grep -Eq '[0-9]+([[:space:]]*)?(ms|сек|sec|%|мин|min|RPS|rps|MB|GB)' "$NFR_FILE"; then
    pass 'NFR содержит числовые пороги с единицами'
  else
    fail 'Числовые NFR-пороги с единицами не найдены'
  fi
fi

if [[ "$GATE" == 6 ]]; then
  echo
  echo '  [DoR-8] Rollback-план Cycle 2'
  RUNBOOK="$(first_match 'stage6-deploy/outputs/DEVOPS-*runbook*.md')"
  if [[ -n "$RUNBOOK" ]] && grep -Eqi 'rollback|откат' "$RUNBOOK"; then
    pass 'Rollback-раздел найден в stage6 runbook'
  elif [[ -f "$PROJECT_PATH/tracking/SDLC-goals.md" ]] &&
       grep -Eq '^cycle2_deliverables:[[:space:]]*images[[:space:]]*$' \
         "$PROJECT_PATH/tracking/SDLC-goals.md"; then
    pass 'Rollback runbook — N/A для images-only delivery; version fallback проверяется в checklist'
  else
    fail 'Проверенный Rollback-раздел в stage6 runbook не найден'
  fi
fi

echo
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  Итог: ${GREEN}✅ ${PASS} прошло${NC} / ${YELLOW}⚠️  ${WARN} предупреждений${NC} / ${RED}❌ ${FAIL} провалено${NC}"
if (( FAIL > 0 )); then
  echo -e "  ${RED}DoR НЕ ПРОЙДЕН — этап не может начаться.${NC}"
  echo '  Зафиксируй возврат в tracking/dor-violations.md'
  echo '╚══════════════════════════════════════════════════════════════╝'
  exit 1
fi

echo -e "  ${GREEN}DoR PASSED (автопроверка). DoR-6 и смысловые критерии подтверждаются владельцем gate.${NC}"
echo '╚══════════════════════════════════════════════════════════════╝'

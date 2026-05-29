#!/usr/bin/env bash
# DoR Auto-Check — проверяет автоматизируемые пункты DoR
# Использование: bash dor-check.sh <PROJECT_PATH> <GATE>
# GATE: 1|2|3|4|5|6
#
# Автоматически проверяет: DoR-1, DoR-2*, DoR-3*, DoR-4*, DoR-5, DoR-7, DoR-8
# Пометка * — частичная проверка (выявляет грубые нарушения, не гарантирует полноту)
# Не автоматизированы: DoR-6 (scope/команда — субъективно)

set -euo pipefail

PROJECT_PATH="${1:?Укажи путь к проекту}"
GATE="${2:?Укажи gate: 1|2|3|4|5|6}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✅ $1${NC}"; ((PASS++)); }
fail() { echo -e "  ${RED}❌ $1${NC}"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; ((WARN++)); }

echo ""
echo "╔═ DoR Auto-Check — Gate ${GATE} ══════════════════════════════╗"
echo "  Проект: ${PROJECT_PATH}"
echo "╠══════════════════════════════════════════════════════════════╣"

# ── DoR-1: Артефакты предыдущего этапа ─────────────────────────────
echo ""
echo "  [DoR-1] Артефакты предыдущего этапа"

check_file_exists() {
  local pattern="$1"
  local label="$2"
  if ls ${PROJECT_PATH}/${pattern} 2>/dev/null | grep -q .; then
    pass "${label}"
  else
    fail "${label} — НЕ НАЙДЕН"
  fi
}

case "${GATE}" in
  2) # Gate 1 → S2: проверяем outputs S1
    check_file_exists "stage1-planning/outputs/PM-*feasibility*.md"  "PM-feasibility.md"
    check_file_exists "stage1-planning/outputs/PMO-*charter*.md"      "PMO-charter.md"
    ;;
  3) # Gate 2 → S3: проверяем outputs S2
    check_file_exists "stage2-requirements/outputs/BA-*BRD*.md"       "BA-BRD.md"
    check_file_exists "stage2-requirements/outputs/BA-*NFR*.md"       "BA-NFR.md"
    check_file_exists "stage2-requirements/outputs/PO-*backlog*.md"   "PO-backlog.md"
    check_file_exists "stage2-requirements/outputs/QA-REQ-*review*.md" "QA-REQ-review.md"
    ;;
  4) # Gate 3 → S4: проверяем outputs S3
    check_file_exists "stage3-design/outputs/ARCH-*HLD*.md"           "ARCH-HLD.md"
    check_file_exists "stage3-design/outputs/ARCH-*api-spec*.yaml"    "ARCH-api-spec.yaml"
    check_file_exists "stage3-design/outputs/SEC-*threat-model*.md"   "SEC-threat-model.md"
    check_file_exists "stage3-design/outputs/DBA-schema*"             "DBA-schema"
    check_file_exists "stage3-design/outputs/RBAC-*model*.md"         "RBAC-model.md"
    check_file_exists "stage3-design/outputs/RBAC-*matrix*.md"        "RBAC-matrix.md"
    ;;
  5) # Gate 4 → S5: проверяем outputs S4
    check_file_exists "stage4-dev/outputs/TL-*review-PR*.md"          "TL-review (хотя бы один)"
    check_file_exists "stage4-dev/outputs/DEV-*update-notes-PR*.md"   "DEV-update-notes"
    ;;
  6) # Gate 5 → S6: проверяем outputs S5
    check_file_exists "stage5-testing/outputs/QA-*go-no-go*.md"       "QA-go-no-go.md"
    check_file_exists "stage5-testing/outputs/PERF-*report*.md"       "PERF-report.md"
    check_file_exists "stage5-testing/outputs/AUTO-*coverage*.md"     "AUTO-coverage.md"
    ;;
  7) # Gate 6 → PROD: проверяем outputs S6
    check_file_exists "stage6-deploy/outputs/REL-*checklist*.md"      "REL-checklist.md"
    check_file_exists "stage6-deploy/outputs/REL-*release-notes*.md"  "REL-release-notes.md"
    ;;
esac

# ── DoR-5: Нет открытых BLOCKER-вопросов ───────────────────────────
echo ""
echo "  [DoR-5] Открытые BLOCKER-вопросы (частичная проверка)"

BLOCKER_COUNT=0
for f in $(find "${PROJECT_PATH}" -name "*.md" -path "*/outputs/*" 2>/dev/null); do
  count=$(grep -ci "BLOCKER.*OPEN\|OPEN.*BLOCKER" "$f" 2>/dev/null || true)
  BLOCKER_COUNT=$((BLOCKER_COUNT + count))
done

if [ "${BLOCKER_COUNT}" -eq 0 ]; then
  pass "0 открытых BLOCKER найдено в outputs/"
else
  fail "${BLOCKER_COUNT} BLOCKER(ов) со статусом OPEN — требуется ручная проверка"
fi

# ── DoR-2: Запрещённые маркеры в BRD (частичная проверка) ──────────
if [ "${GATE}" -ge 3 ]; then
  echo ""
  echo "  [DoR-2] Размытые формулировки в BRD (частичная проверка)"
  BRD_FILE=$(ls ${PROJECT_PATH}/stage2-requirements/outputs/BA-*BRD*.md 2>/dev/null | head -1 || true)
  if [ -n "${BRD_FILE}" ]; then
    FUZZY=$(grep -ci "и/или\|обычно\|при необходимости\|TBD\|tbd\|по возможности" "${BRD_FILE}" 2>/dev/null || true)
    if [ "${FUZZY}" -eq 0 ]; then
      pass "Размытых формулировок не найдено в BRD"
    else
      warn "${FUZZY} потенциально размытых формулировок в BRD — проверить вручную"
    fi
  else
    warn "BRD не найден — DoR-2 пропущен"
  fi
fi

# ── DoR-3: AC в формате Given/When/Then (частичная проверка) ────────
if [ "${GATE}" -ge 3 ]; then
  echo ""
  echo "  [DoR-3] Acceptance Criteria (частичная проверка)"
  BACKLOG=$(ls ${PROJECT_PATH}/stage2-requirements/outputs/PO-*backlog*.md 2>/dev/null | head -1 || true)
  if [ -n "${BACKLOG}" ]; then
    GWT=$(grep -ci "Given\|When\|Then" "${BACKLOG}" 2>/dev/null || true)
    STORIES=$(grep -ci "^## \|^### \|Story\|As a" "${BACKLOG}" 2>/dev/null || true)
    if [ "${GWT}" -gt 0 ]; then
      pass "Given/When/Then найдены в backlog (${GWT} вхождений)"
    else
      fail "Given/When/Then не найдены в backlog — AC отсутствуют"
    fi
  else
    warn "Backlog не найден — DoR-3 пропущен"
  fi
fi

# ── DoR-4: NFR с числами (частичная проверка) ───────────────────────
if [ "${GATE}" -ge 3 ]; then
  echo ""
  echo "  [DoR-4] NFR с числовыми порогами (частичная проверка)"
  NFR_FILE=$(ls ${PROJECT_PATH}/stage2-requirements/outputs/BA-*NFR*.md 2>/dev/null | head -1 || true)
  if [ -n "${NFR_FILE}" ]; then
    NUMBERS=$(grep -cE "[0-9]+(ms|сек|sec|%|мин|min|RPS|rps|MB|GB)" "${NFR_FILE}" 2>/dev/null || true)
    if [ "${NUMBERS}" -gt 0 ]; then
      pass "NFR содержит числовые пороги (${NUMBERS} вхождений с единицами)"
    else
      warn "Числовые пороги с единицами не найдены в NFR — проверить вручную"
    fi
  else
    warn "NFR-файл не найден — DoR-4 пропущен"
  fi
fi

# ── DoR-7: Threat Model начат (для Gate 3+) ─────────────────────────
if [ "${GATE}" -ge 4 ]; then
  echo ""
  echo "  [DoR-7] Threat Model"
  if ls ${PROJECT_PATH}/stage3-design/outputs/SEC-*threat-model*.md 2>/dev/null | grep -q .; then
    pass "SEC-threat-model.md существует"
  else
    fail "SEC-threat-model.md не найден — Gate ${GATE} заблокирован"
  fi
fi

# ── DoR-8: Rollback-план (для Gate 6+) ──────────────────────────────
if [ "${GATE}" -ge 7 ]; then
  echo ""
  echo "  [DoR-8] Rollback-план"
  RUNBOOK=$(ls ${PROJECT_PATH}/stage4-dev/outputs/DEVOPS-*runbook*.md 2>/dev/null | head -1 || true)
  if [ -n "${RUNBOOK}" ]; then
    ROLLBACK=$(grep -ci "rollback\|откат" "${RUNBOOK}" 2>/dev/null || true)
    if [ "${ROLLBACK}" -gt 0 ]; then
      pass "Rollback-раздел найден в runbook"
    else
      fail "Rollback-раздел отсутствует в runbook"
    fi
  else
    fail "DEVOPS-runbook.md не найден"
  fi
fi

# ── Итог ─────────────────────────────────────────────────────────────
echo ""
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  Итог: ${GREEN}✅ ${PASS} прошло${NC} / ${YELLOW}⚠️  ${WARN} предупреждений${NC} / ${RED}❌ ${FAIL} провалено${NC}"

if [ "${FAIL}" -gt 0 ]; then
  echo ""
  echo -e "  ${RED}DoR НЕ ПРОЙДЕН — этап не может начаться.${NC}"
  echo "  Зафиксируй возврат в tracking/dor-violations.md"
  echo "╚══════════════════════════════════════════════════════════════╝"
  exit 1
else
  echo ""
  echo -e "  ${GREEN}DoR PASSED (автопроверка). Рекомендуется ручная проверка DoR-6.${NC}"
  echo "╚══════════════════════════════════════════════════════════════╝"
  exit 0
fi

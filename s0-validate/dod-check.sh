#!/usr/bin/env bash
# DoD Auto-Check — проверяет автоматизируемые пункты DoD
# Использование: bash dod-check.sh <PROJECT_PATH> <TYPE> <STAGE> [PR_NUM]
#
# TYPE:  K — Код (s4-dev PR)
#        D — Документ (s1-*, s2-*, s3-*, s5-*, s6-*)
#        I — Инфраструктура (s3-dba, s4-devops)
# STAGE: 1..7 — текущий этап (для поиска артефактов в нужной папке)
# PR_NUM: номер PR (только для TYPE=K, опционально)
#
# Автоматически: DoD-1(частично), DoD-2, DoD-3(файл), DoD-5, DoD-6, DoD-8, DoD-10, DoD-11
# Вручную:       DoD-4, DoD-7, DoD-9

set -euo pipefail

PROJECT_PATH="${1:?Укажи путь к проекту}"
TYPE="${2:?Укажи тип: K|D|I}"
STAGE="${3:?Укажи этап: 1..7}"
PR_NUM="${4:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0; SKIP=0

pass() { echo -e "  ${GREEN}✅ $1${NC}"; ((PASS++)); }
fail() { echo -e "  ${RED}❌ $1${NC}"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; ((WARN++)); }
skip() { echo -e "  ${BLUE}—  $1 (не применимо для типа ${TYPE})${NC}"; ((SKIP++)); }

STAGE_DIR="stage${STAGE}"
case "${STAGE}" in
  1) STAGE_DIR="stage1-planning" ;;
  2) STAGE_DIR="stage2-requirements" ;;
  3) STAGE_DIR="stage3-design" ;;
  4) STAGE_DIR="stage4-dev" ;;
  5) STAGE_DIR="stage5-testing" ;;
  6) STAGE_DIR="stage6-deploy" ;;
  7) STAGE_DIR="stage7-ops" ;;
esac

OUTPUTS="${PROJECT_PATH}/${STAGE_DIR}/outputs"

echo ""
echo "╔═ DoD Auto-Check ══════════════════════════════════════════════╗"
echo "  Проект:  ${PROJECT_PATH##*/}"
echo "  Тип:     ${TYPE} (K=Код / D=Документ / I=Инфраструктура)"
echo "  Этап:    S${STAGE} → ${OUTPUTS##*/Project*/}"
[ -n "${PR_NUM}" ] && echo "  PR:      #${PR_NUM}"
echo "╠═══════════════════════════════════════════════════════════════╣"

# ── DoD-1: Complexity (только Тип К, частично) ─────────────────────
echo ""
echo "  [DoD-1] Стандарты кода (complexity ≤10, SRP)"
if [ "${TYPE}" = "K" ]; then
  # Ищем Python-файлы с функциями длиннее 50 строк как прокси для complexity
  LONG_FUNCS=0
  if find "${PROJECT_PATH}" -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" 2>/dev/null | grep -q .; then
    LONG_FUNCS=$(find "${PROJECT_PATH}" -name "*.py" -not -path "*/venv/*" 2>/dev/null \
      -exec awk '/^def |^    def /{count=0; fname=$0} {count++} /^def |^    def |^class /{if(count>50) print FILENAME}' {} \; \
      | sort -u | wc -l || echo 0)
    if [ "${LONG_FUNCS}" -eq 0 ]; then
      pass "Функций > 50 строк не найдено (прокси для complexity)"
    else
      warn "${LONG_FUNCS} файл(ов) с потенциально сложными функциями — проверить radon/flake8"
    fi
  else
    warn "Python-файлы не найдены — DoD-1 пропущен"
  fi
else
  skip "DoD-1 complexity — только для Тип К"
fi

# ── DoD-2: Unit tests / миграции ───────────────────────────────────
echo ""
echo "  [DoD-2] Unit-тесты / тесты миграций"
if [ "${TYPE}" = "K" ]; then
  # Ищем coverage report
  if [ -f "${PROJECT_PATH}/.coverage" ] || [ -f "${PROJECT_PATH}/coverage.xml" ] || \
     [ -d "${PROJECT_PATH}/htmlcov" ] || [ -f "${PROJECT_PATH}/coverage-report.txt" ]; then
    # Пытаемся прочитать процент покрытия
    COVERAGE_PCT=""
    if [ -f "${PROJECT_PATH}/coverage-report.txt" ]; then
      COVERAGE_PCT=$(grep -E "TOTAL.*[0-9]+%" "${PROJECT_PATH}/coverage-report.txt" | grep -oE "[0-9]+%" | tail -1 || true)
    fi
    if [ -n "${COVERAGE_PCT}" ]; then
      COV_NUM="${COVERAGE_PCT//%/}"
      if [ "${COV_NUM}" -ge 80 ]; then
        pass "Coverage ${COVERAGE_PCT} ≥ 80%"
      else
        fail "Coverage ${COVERAGE_PCT} < 80% — требуется доработка"
      fi
    else
      pass "Coverage report существует (процент требует ручной проверки)"
    fi
  else
    fail "Coverage report не найден (.coverage / coverage.xml / htmlcov/)"
  fi
elif [ "${TYPE}" = "I" ]; then
  # Для инфраструктуры — тест миграций
  MIGRATION_TEST=$(find "${PROJECT_PATH}" -name "test_migration*" -o -name "*migration*test*" 2>/dev/null | head -1 || true)
  if [ -n "${MIGRATION_TEST}" ]; then
    pass "Тест миграций найден: ${MIGRATION_TEST##*/}"
  else
    fail "Тест миграций не найден (upgrade→downgrade→upgrade)"
  fi
else
  skip "DoD-2 unit tests — не применимо для Тип Д"
fi

# ── DoD-3: Code review (файловая проверка) ─────────────────────────
echo ""
echo "  [DoD-3] Code review / артефакт-ревью"
if [ "${TYPE}" = "K" ]; then
  if [ -n "${PR_NUM}" ]; then
    REVIEW_FILE=$(ls "${OUTPUTS}"/TL-*-review-PR${PR_NUM}*.md 2>/dev/null | head -1 || true)
  else
    REVIEW_FILE=$(ls "${OUTPUTS}"/TL-*-review-PR*.md 2>/dev/null | head -1 || true)
  fi
  if [ -n "${REVIEW_FILE}" ]; then
    APPROVED=$(grep -ci "APPROVE\|✅.*PASS\|LGTM" "${REVIEW_FILE}" 2>/dev/null || true)
    BLOCKED=$(grep -ci "BLOCKER\|REQUEST_CHANGES\|❌" "${REVIEW_FILE}" 2>/dev/null || true)
    if [ "${BLOCKED}" -gt 0 ]; then
      fail "TL-review содержит BLOCKER/REQUEST_CHANGES — ${REVIEW_FILE##*/}"
    elif [ "${APPROVED}" -gt 0 ]; then
      pass "TL-review с approve найден — ${REVIEW_FILE##*/}"
    else
      warn "TL-review найден, но статус неясен — проверить вручную"
    fi
  else
    fail "TL-*-review-PR*.md не найден в ${STAGE_DIR}/outputs/"
  fi
else
  # Для Д и И — проверяем наличие любого review-файла
  REVIEW=$(ls "${OUTPUTS}"/*review*.md 2>/dev/null | head -1 || true)
  if [ -n "${REVIEW}" ]; then
    pass "Review-файл найден — ${REVIEW##*/}"
  else
    warn "Review-файл не найден — DoD-3 требует ручной проверки"
  fi
fi

# ── DoD-4: Документация (ручная) ───────────────────────────────────
echo ""
echo "  [DoD-4] Документация обновлена"
warn "DoD-4 требует ручной проверки (README/API-spec/docstring)"

# ── DoD-5: CHANGELOG ───────────────────────────────────────────────
echo ""
echo "  [DoD-5] CHANGELOG.md обновлён"
CHANGELOG=$(find "${PROJECT_PATH}" -maxdepth 3 -name "CHANGELOG.md" 2>/dev/null | head -1 || true)
if [ -n "${CHANGELOG}" ]; then
  # Проверяем что файл не пустой и содержит запись с датой
  ENTRIES=$(grep -cE "^## \[|^## v[0-9]|^### [0-9]{4}-[0-9]{2}" "${CHANGELOG}" 2>/dev/null || true)
  if [ "${ENTRIES}" -gt 0 ]; then
    pass "CHANGELOG.md существует, содержит ${ENTRIES} версий/секций"
  else
    warn "CHANGELOG.md найден, но записи не распознаны — проверить формат"
  fi
else
  fail "CHANGELOG.md не найден в корне проекта"
fi

# ── DoD-6: Update notes (только Тип К) ────────────────────────────
echo ""
echo "  [DoD-6] Update notes (DEV-*-update-notes-PR*.md)"
if [ "${TYPE}" = "K" ]; then
  if [ -n "${PR_NUM}" ]; then
    NOTES=$(ls "${PROJECT_PATH}/stage4-dev/outputs/DEV-"*"-update-notes-PR${PR_NUM}"*.md 2>/dev/null | head -1 || true)
  else
    NOTES=$(ls "${PROJECT_PATH}/stage4-dev/outputs/DEV-"*"-update-notes-PR"*.md 2>/dev/null | head -1 || true)
  fi
  if [ -n "${NOTES}" ]; then
    pass "Update notes найдены — ${NOTES##*/}"
  else
    fail "DEV-*-update-notes-PR*.md не найден в stage4-dev/outputs/"
  fi
else
  skip "DoD-6 update notes — только для Тип К"
fi

# ── DoD-7: 0 S1/S2 багов (ручная) ─────────────────────────────────
echo ""
echo "  [DoD-7] Нет известных S1/S2 багов без митигации"
warn "DoD-7 требует ручной проверки (проверить tracking/backlog.md на S1/S2)"

# ── DoD-8: Secrets scan ────────────────────────────────────────────
echo ""
echo "  [DoD-8] Секреты не в коде / логах / артефактах"
SECRET_PATTERNS="password\s*=\s*['\"][^'\"]\|api_key\s*=\s*['\"][^'\"]\|token\s*=\s*['\"][^'\"]\|secret\s*=\s*['\"][^'\"]"
SECRET_COUNT=0

# Проверяем outputs/ текущего этапа
if [ -d "${OUTPUTS}" ]; then
  SECRET_COUNT=$(grep -ril "${SECRET_PATTERNS}" "${OUTPUTS}" 2>/dev/null | wc -l || true)
fi
# Проверяем Python-файлы (для Тип К/И)
if [ "${TYPE}" != "D" ]; then
  PY_SECRETS=$(find "${PROJECT_PATH}" -name "*.py" -not -path "*/venv/*" 2>/dev/null \
    -exec grep -lE "password\s*=\s*['\"][^'\"]|api_key\s*=\s*['\"][^'\"]" {} \; 2>/dev/null | wc -l || true)
  SECRET_COUNT=$((SECRET_COUNT + PY_SECRETS))
fi

if [ "${SECRET_COUNT}" -eq 0 ]; then
  pass "Паттерны секретов не найдены (частичная проверка)"
else
  fail "${SECRET_COUNT} файл(ов) с возможными секретами — проверить вручную"
fi

# ── DoD-9: NFR (ручная) ────────────────────────────────────────────
echo ""
echo "  [DoD-9] NFR проверены"
if [ "${TYPE}" = "K" ] || [ "${TYPE}" = "I" ]; then
  PERF_REPORT=$(ls "${PROJECT_PATH}/stage5-testing/outputs/PERF-"*"-report"*.md 2>/dev/null | head -1 || true)
  if [ -n "${PERF_REPORT}" ]; then
    warn "PERF-report найден — требует ручной проверки вердикта (PASS/FAIL)"
  else
    warn "PERF-report не найден — DoD-9 ещё не проверялся"
  fi
else
  warn "DoD-9 для документа: NFR должны быть адресованы в тексте — ручная проверка"
fi

# ── DoD-10: Артефакт в outputs/ ────────────────────────────────────
echo ""
echo "  [DoD-10] Артефакт передан в outputs/"
if [ -d "${OUTPUTS}" ]; then
  FILE_COUNT=$(find "${OUTPUTS}" -name "*.md" -o -name "*.yaml" -o -name "*.sql" -o -name "*.py" 2>/dev/null | wc -l || true)
  if [ "${FILE_COUNT}" -gt 0 ]; then
    pass "${FILE_COUNT} файл(ов) в ${STAGE_DIR}/outputs/"
  else
    fail "outputs/ пуст — артефакт не записан в outputs/ текущего этапа"
  fi
else
  fail "Папка ${STAGE_DIR}/outputs/ не существует"
fi

# ── DoD-11: Тесты форматов (Тип К и И) ────────────────────────────
echo ""
echo "  [DoD-11] Тесты форматов данных"
if [ "${TYPE}" = "K" ] || [ "${TYPE}" = "I" ]; then
  TESTS_DIR="${PROJECT_PATH}/tests"
  ENV_TEST=$([ -f "${TESTS_DIR}/test_env_format.py" ] && echo "✅" || echo "❌")
  DB_TEST=$([ -f "${TESTS_DIR}/test_db_format.py" ] && echo "✅" || echo "❌")
  API_TEST=$([ -f "${TESTS_DIR}/test_api_format.py" ] && echo "✅" || echo "❌")
  MISSING=0
  [ "${ENV_TEST}" = "❌" ] && ((MISSING++))
  [ "${DB_TEST}" = "❌" ] && ((MISSING++))
  [ "${API_TEST}" = "❌" ] && ((MISSING++))
  if [ "${MISSING}" -eq 0 ]; then
    pass "test_env_format.py ✅ test_db_format.py ✅ test_api_format.py ✅"
  elif [ "${MISSING}" -lt 3 ]; then
    warn "test_env_format ${ENV_TEST} | test_db_format ${DB_TEST} | test_api_format ${API_TEST} — проверить применимость"
  else
    fail "Все тесты форматов отсутствуют в tests/"
  fi
else
  skip "DoD-11 тесты форматов — только для Тип К и И"
fi

# ── Итог ─────────────────────────────────────────────────────────────
echo ""
echo "╠═══════════════════════════════════════════════════════════════╣"
echo -e "  ✅ ${PASS} прошло  ⚠️  ${WARN} предупреждений  ❌ ${FAIL} провалено  — ${SKIP} пропущено"

if [ "${FAIL}" -gt 0 ]; then
  echo ""
  echo -e "  ${RED}DoD НЕ ПРОЙДЕН — задача остаётся IN_PROGRESS.${NC}"
  echo "  При осознанном пропуске — зафиксировать в tracking/tech-debt.md"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  exit 1
else
  echo ""
  echo -e "  ${GREEN}DoD PASSED (авто). Пункты 👤 требуют ручного подтверждения.${NC}"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  exit 0
fi

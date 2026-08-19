#!/usr/bin/env bash
# DoD Auto-Check — проверяет автоматизируемые пункты DoD
# Использование: bash dod-check.sh <PROJECT_PATH> <TYPE> <STAGE> [PR_NUM] [SOURCE_REVISION]
#
# TYPE:  K — Код (s4-dev PR)
#        D — Документ (s1-*, s2-*, s3-*, s5-*)
#        I — Executable migration (s4-dev, только Stage 4)
# STAGE: 1..5 active; Stage 6/7 are FROZEN / NOT SUPPORTED.
# PR_NUM: номер PR (для TYPE=K|I, опционально)
#
# Автоматически: DoD-1(частично), DoD-2, DoD-3(файл), DoD-5, DoD-6, DoD-8, DoD-10, DoD-11
# Вручную:       DoD-4, DoD-7, DoD-9

set -euo pipefail

PROJECT_PATH="${1:?Укажи путь к проекту}"
TYPE="${2:?Укажи тип: K|D|I}"
STAGE="${3:?Укажи этап: 1..5}"
PR_NUM="${4:-}"
SOURCE_REVISION="${5:-}"

[[ -d "$PROJECT_PATH" ]] || { echo "Проект не найден: $PROJECT_PATH" >&2; exit 2; }
[[ "$TYPE" =~ ^(K|D|I)$ ]] || { echo 'Тип должен быть K, D или I' >&2; exit 2; }
if [[ "$STAGE" =~ ^(6|7)$ ]]; then
  echo "Stage $STAGE — FROZEN / NOT SUPPORTED; active DoD validator covers Cycle 1 Stages 1..5." >&2
  exit 2
fi
[[ "$STAGE" =~ ^[1-5]$ ]] || { echo 'Этап должен быть целым числом 1..5' >&2; exit 2; }
[[ -z "$PR_NUM" || "$PR_NUM" =~ ^[0-9]+$ ]] || { echo 'PR_NUM должен быть числом' >&2; exit 2; }
if [[ "$TYPE" == K || "$TYPE" == I ]]; then
  [[ "$SOURCE_REVISION" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] || {
    echo 'Type K/I требует exact SOURCE_REVISION для Evidence/Quality Policy binding' >&2
    exit 2
  }
fi
if [[ "$TYPE" == I && "$STAGE" != 4 ]]; then
  echo 'Type I допустим только для executable migration в Stage 4' >&2
  exit 2
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0; SKIP=0

pass() { echo -e "  ${GREEN}✅ $1${NC}"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}❌ $1${NC}"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; WARN=$((WARN + 1)); }
skip() { echo -e "  ${BLUE}—  $1${NC}"; SKIP=$((SKIP + 1)); }

STAGE_DIR="stage${STAGE}"
case "${STAGE}" in
  1) STAGE_DIR="stage1-planning" ;;
  2) STAGE_DIR="stage2-requirements" ;;
  3) STAGE_DIR="stage3-design" ;;
  4) STAGE_DIR="stage4-dev" ;;
  5) STAGE_DIR="stage5-testing" ;;
esac

OUTPUTS="${PROJECT_PATH}/${STAGE_DIR}/outputs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT_TOOL="$SCRIPT_DIR/current-artifact.sh"

record_field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}
current_evidence_record() {
  local check="$1" record
  local -a matches=()
  while IFS= read -r -d '' record; do
    [[ "$(record_field "$record" check_id)" == "$check" ]] || continue
    [[ "$(record_field "$record" source_revision)" == "$SOURCE_REVISION" ]] || continue
    matches+=("$record")
  done < <(find "$PROJECT_PATH/tracking/evidence/v1" -maxdepth 1 -type f -name '*.yaml' -print0 2>/dev/null | sort -z)
  (( ${#matches[@]} == 1 )) || return 1
  printf '%s\n' "${matches[0]}"
}
current_refs() {
  bash "$CURRENT_TOOL" resolve-compatible "$PROJECT_PATH" "$1"
}
current_one() {
  bash "$CURRENT_TOOL" resolve-compatible-one "$PROJECT_PATH" "$1"
}

echo ""
echo "╔═ DoD Auto-Check ══════════════════════════════════════════════╗"
echo "  Проект:  ${PROJECT_PATH##*/}"
echo "  Тип:     ${TYPE} (K=Код / D=Документ / I=Executable migration)"
echo "  Этап:    S${STAGE} → ${OUTPUTS##*/Project*/}"
[ -n "${PR_NUM}" ] && echo "  PR:      #${PR_NUM}"
echo "╠═══════════════════════════════════════════════════════════════╣"

# ── DoD-1: Complexity ──────────────────────────────────────────────
echo ""
echo "  [DoD-1] Стандарты кода (effective-policy complexity)"
if [[ "${TYPE}" == K || "${TYPE}" == I ]]; then
  if lint_record="$(current_evidence_record lint)" &&
    bash "$SCRIPT_DIR/quality-metric-result-check.sh" "$PROJECT_PATH" "$lint_record" \
      complexity_max >/dev/null; then
    pass 'Complexity metric связан с exact source и effective Quality Policy'
  else
    fail 'Нет verified complexity_max metric для exact source/effective policy'
  fi
else
  skip "DoD-1 complexity — только для software Тип K/I"
fi

# ── DoD-2: Unit tests / миграции ───────────────────────────────────
echo ""
echo "  [DoD-2] Unit-тесты / тесты миграций"
if [ "${TYPE}" = "K" ]; then
  if unit_record="$(current_evidence_record unit)" &&
    bash "$SCRIPT_DIR/quality-metric-result-check.sh" "$PROJECT_PATH" "$unit_record" \
      branch_coverage_percent,mutation_score_percent >/dev/null; then
    pass 'Branch coverage и mutation score связаны с exact source/effective policy'
  else
    fail 'Нет verified branch/mutation metrics для exact source/effective policy'
  fi
  for evidence_check in integration contract; do
    if evidence_record="$(current_evidence_record "$evidence_check")" &&
      bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$evidence_record" \
        --expected-source "$SOURCE_REVISION" --expected-check "$evidence_check" >/dev/null; then
      pass "$evidence_check Evidence v1 verified для exact source"
    else
      fail "$evidence_check Evidence v1 отсутствует/invalid для exact source"
    fi
  done
elif [ "${TYPE}" = "I" ]; then
  MIGRATION_REF="$(current_one migration-runbook 2>/dev/null || true)"
  TDD_REF="$(current_one tdd-status 2>/dev/null || true)"
  if [[ -z "$MIGRATION_REF" || "${MIGRATION_REF##*/}" == *not-applicable* ]]; then
    fail 'Executable migration требует current migration design, а не N/A'
  elif [[ -z "$TDD_REF" ]] ||
    ! bash "$SCRIPT_DIR/tdd-status-check.sh" "$PROJECT_PATH" PASS >/dev/null ||
    [[ "$(record_field "$PROJECT_PATH/$TDD_REF" source_revision)" != "$SOURCE_REVISION" ]] ||
    [[ ! "$(record_field "$PROJECT_PATH/$TDD_REF" scope)" =~ (^|,)MIG-[A-Za-z0-9._-]+(,|$) ]]; then
    fail 'Executable migration требует exact-source PASS TDD status со scope MIG-*'
  else
    FORMAT_MANIFEST="$PROJECT_PATH/stage4-dev/outputs/QA-affected-tests-v1.tsv"
    migration_test_ref="$(awk -F '\t' -v source="$SOURCE_REVISION" \
      'NR > 1 && $3 ~ /^MIG-/ && $4 == "PASS" && $5 == source {print $2; exit}' \
      "$FORMAT_MANIFEST" 2>/dev/null || true)"
    if [[ -z "$migration_test_ref" || ! -f "$PROJECT_PATH/$migration_test_ref" ||
      -L "$PROJECT_PATH/$migration_test_ref" ]]; then
      fail 'Affected regression has no exact-source PASS migration test'
    elif ! tr '\n' ' ' < "$PROJECT_PATH/$migration_test_ref" |
      grep -Eiq 'upgrade.*downgrade.*upgrade'; then
      fail 'Migration test does not exercise upgrade→downgrade→upgrade'
    else
      pass "Executable migration TDD verified: ${MIGRATION_REF##*/} / $migration_test_ref"
    fi
  fi
else
  skip "DoD-2 unit tests — не применимо для Тип Д"
fi

# ── DoD-3: Code review (файловая проверка) ─────────────────────────
echo ""
echo "  [DoD-3] Code review / артефакт-ревью"
if [[ "${TYPE}" == K || "${TYPE}" == I ]]; then
  mapfile -t REVIEW_REFS < <(current_refs techlead-reviews || true)
  REVIEW_FILES=()
  for REVIEW_REF in "${REVIEW_REFS[@]}"; do
    if [ -z "${PR_NUM}" ] || [[ "${REVIEW_REF##*/}" == *"review-PR${PR_NUM}"* ]]; then
      REVIEW_FILES+=("$PROJECT_PATH/$REVIEW_REF")
    fi
  done
  if [ "${#REVIEW_FILES[@]}" -gt 0 ]; then
    REVIEW_BLOCKED=0; REVIEW_APPROVED=0
    for REVIEW_FILE in "${REVIEW_FILES[@]}"; do
      APPROVED=$(grep -Eci '(^|[^A-Z])(APPROVED|LGTM)([^A-Z]|$)|✅.*PASS' \
        "${REVIEW_FILE}" 2>/dev/null || true)
      BLOCKED=$(grep -Eci 'CHANGES[ _-]?REQUESTED|REQUEST_CHANGES|\[BLOCKER\]|\[MAJOR\]|❌' \
        "${REVIEW_FILE}" 2>/dev/null || true)
      [ "${BLOCKED}" -eq 0 ] || REVIEW_BLOCKED=1
      [ "${APPROVED}" -eq 0 ] || REVIEW_APPROVED=1
    done
    if [ "${REVIEW_BLOCKED}" -ne 0 ]; then
      fail 'Current TL review set содержит BLOCKER/REQUEST_CHANGES'
    elif [ "${REVIEW_APPROVED}" -ne 0 ]; then
      pass "Current TL review set подтверждён (${#REVIEW_FILES[@]})"
    else
      warn 'Current TL review set найден, но статус неясен — проверить вручную'
    fi
  else
    fail 'Current techlead-reviews не найден либо legacy history неоднозначна'
  fi
else
  warn 'DoD-3 для D/I не выбирает произвольный historical review; требуется current owner review/полный approval'
fi

# ── DoD-4: Документация (ручная) ───────────────────────────────────
echo ""
echo "  [DoD-4] Документация обновлена"
warn "DoD-4 требует ручной проверки (README/API-spec/docstring)"

# ── DoD-5: release docs ────────────────────────────────────────────
echo ""
echo "  [DoD-5] Release documentation"
skip 'DoD-5 — N/A для active Cycle 1; release preparation является отдельным действием'

# ── DoD-6: Update notes (software Тип K/I) ────────────────────────
echo ""
echo "  [DoD-6] Update notes (DEV-*-update-notes-PR*.md)"
if [[ "${TYPE}" == K || "${TYPE}" == I ]]; then
  NOTES_REF="$(current_one development-update-notes || true)"
  if [ -n "${NOTES_REF}" ] && { [ -z "${PR_NUM}" ] || [[ "${NOTES_REF##*/}" == *"PR${PR_NUM}"* ]]; }; then
    pass "Current update notes найдены — ${NOTES_REF##*/}"
  else
    fail 'Current development-update-notes не найден, не соответствует PR либо legacy history неоднозначна'
  fi
else
  skip "DoD-6 update notes — только для software Тип K/I"
fi

# ── DoD-7: 0 S1/S2 багов (ручная) ─────────────────────────────────
echo ""
echo "  [DoD-7] Нет известных S1/S2 багов без митигации"
warn "DoD-7 требует ручной проверки (проверить tracking/backlog.md на S1/S2)"

# ── DoD-8: Secrets scan ────────────────────────────────────────────
echo ""
echo "  [DoD-8] Секреты не в коде / логах / артефактах"
if [[ "${TYPE}" == K || "${TYPE}" == I ]]; then
  if secrets_record="$(current_evidence_record secrets)" &&
    bash "$SCRIPT_DIR/secrets-result-check.sh" "$PROJECT_PATH" "$secrets_record" \
      "$SOURCE_REVISION" >/dev/null; then
    pass 'Repository-scope secrets Evidence v1 verified для exact source'
  else
    fail 'Нет PASS secrets Evidence v1 для exact source и полного repository scope'
  fi
else
  warn 'DoD-8 для design/document требует owner review; автоматический PASS не заявляется'
fi

# ── DoD-9: NFR (ручная) ────────────────────────────────────────────
echo ""
echo "  [DoD-9] NFR проверены"
if [ "${TYPE}" = "K" ] || [ "${TYPE}" = "I" ]; then
  PERF_REF="$(current_one s5-performance-report 2>/dev/null || true)"
  if [ -n "${PERF_REF}" ]; then
    warn "Current performance report найден — требует ручной проверки вердикта (PASS/FAIL)"
  else
    warn 'Current performance report отсутствует/N/A или legacy history неоднозначна — DoD-9 требует полного approval'
  fi
else
  warn "DoD-9 для документа: NFR должны быть адресованы в тексте — ручная проверка"
fi

# ── DoD-10: Артефакт в outputs/ ────────────────────────────────────
echo ""
echo "  [DoD-10] Артефакт передан в outputs/"
if [ -d "${OUTPUTS}" ]; then
  FILE_COUNT=$(find "${OUTPUTS}" -type f 2>/dev/null | wc -l || true)
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
if [[ "${TYPE}" == K || "${TYPE}" == I ]]; then
  FORMAT_MANIFEST="$PROJECT_PATH/stage4-dev/outputs/QA-affected-tests-v1.tsv"
  TDD_REF="$(current_one tdd-status 2>/dev/null || true)"
  FORMAT_TDD_VERIFIED=0
  if [[ "$TDD_REF" == stage4-dev/outputs/QA-TDD-status.md ]] &&
    bash "$SCRIPT_DIR/tdd-status-check.sh" "$PROJECT_PATH" PASS >/dev/null &&
    [[ "$(record_field "$PROJECT_PATH/$TDD_REF" source_revision)" == "$SOURCE_REVISION" ]]; then
    FORMAT_TDD_VERIFIED=1
  else
    fail 'DoD-11 требует current exact-source PASS TDD status с digest-bound full-affected manifest'
  fi
  for spec in \
    'environment-format|tests/test_env_format.py' \
    'data-store|tests/test_db_format.py' \
    'api-contract|tests/test_api_format.py'; do
    capability="${spec%%|*}"; test_ref="${spec#*|}"
    if applicability_row="$(bash "$SCRIPT_DIR/applicability-resolve.sh" resolve "$PROJECT_PATH" "$capability" 2>/dev/null)"; then
      applicability="$(cut -f2 <<< "$applicability_row")"
    else
      fail "DoD-11 applicability unresolved: $capability"
      continue
    fi
    if [[ "$applicability" == NOT_APPLICABLE ]]; then
      skip "DoD-11 $capability — profile-confirmed N/A"
    elif (( FORMAT_TDD_VERIFIED == 1 )) &&
      [[ -f "$PROJECT_PATH/$test_ref" && ! -L "$PROJECT_PATH/$test_ref" ]] &&
      awk -F '\t' -v ref="$test_ref" -v source="$SOURCE_REVISION" \
        'NR > 1 && $2 == ref && $4 == "PASS" && $5 == source {found=1} END {exit !found}' \
        "$FORMAT_MANIFEST" 2>/dev/null; then
      pass "DoD-11 $capability verified: $test_ref"
    else
      fail "DoD-11 $capability REQUIRED, но exact-source PASS test отсутствует: $test_ref"
    fi
  done
else
  skip "DoD-11 executable format tests — только для software Тип K/I; design фиксирует требования"
fi

# ── Итог ─────────────────────────────────────────────────────────────
echo ""
echo "╠═══════════════════════════════════════════════════════════════╣"
echo -e "  ✅ ${PASS} прошло  ⚠️  ${WARN} предупреждений  ❌ ${FAIL} провалено  — ${SKIP} пропущено"

if [ "${FAIL}" -gt 0 ]; then
  echo ""
  echo -e "  ${RED}DoD НЕ ПРОЙДЕН — задача остаётся IN_PROGRESS.${NC}"
  echo "  Устрани failed пункты и повтори проверку; tech debt не является waiver."
  echo "╚═══════════════════════════════════════════════════════════════╝"
  exit 1
else
  echo ""
  echo -e "  ${GREEN}DoD auto-check PASSED. Полный DoD подписывается только после ручных пунктов.${NC}"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  exit 0
fi

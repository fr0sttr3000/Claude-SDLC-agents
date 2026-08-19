#!/usr/bin/env bash
# DoR Auto-Check — автоматизируемая часть готовности Quality Gate.
# Использование: bash dor-check.sh <PROJECT_PATH> <GATE>
# GATE: 1|2|3|4|5 active; Gate 6/7 are FROZEN / NOT SUPPORTED.

set -euo pipefail

PROJECT_PATH="${1:?Укажи путь к проекту}"
GATE="${2:?Укажи gate: 1|2|3|4|5}"

[[ -d "$PROJECT_PATH" ]] || { echo "Проект не найден: $PROJECT_PATH" >&2; exit 2; }
if [[ "$GATE" =~ ^(6|7)$ ]]; then
  echo "Gate $GATE — FROZEN / NOT SUPPORTED; active DoR validator covers Cycle 1 Gates 1..5." >&2
  exit 2
fi
[[ "$GATE" =~ ^[1-5]$ ]] || { echo 'Gate должен быть целым числом 1..5' >&2; exit 2; }
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"
CURRENT_ARTIFACT_TOOL="$(dirname "${BASH_SOURCE[0]}")/current-artifact.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

pass() { echo -e "  ${GREEN}✅ $1${NC}"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}❌ $1${NC}"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; WARN=$((WARN + 1)); }

flat_field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

check_quality_characteristics() {
  local profile="$PROJECT_PATH/tracking/product-ci-profile.yaml" schema output
  [[ -f "$profile" ]] || { fail 'Product Profile для Quality Characteristics отсутствует'; return; }
  schema="$(flat_field "$profile" schema_version)"
  if [[ "$schema" != 5 ]]; then
    if [[ "$GATE" == 2 ]]; then fail "Quality Characteristics v1 требует Product Profile schema 5; сначала refresh"; else warn "Quality Characteristics v1 — legacy Product Profile schema $schema; coverage UNVERIFIED до refresh"; fi
    return
  fi
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/../s0-quality-gates/quality-characteristics-check.sh" "$PROJECT_PATH" 2>&1)"; then
    printf '  %s\n' "$output"
    pass 'Quality Characteristics v1: applicability, owners, evidence и only-up VERIFIED'
  else
    printf '  %s\n' "$output"
    fail 'Quality Characteristics v1 — BLOCKED'
  fi
}

check_quality_policy() {
  local output
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/../s0-quality-gates/quality-gates-check.sh" "$PROJECT_PATH" 2>&1)"; then
    printf '  %s\n' "$output"
    pass 'Effective Quality Policy: current Product Profile binding VERIFIED'
  else
    printf '  %s\n' "$output"
    fail 'Effective Quality Policy — missing/stale/BLOCKED'
  fi
}

current_refs() {
  bash "$CURRENT_ARTIFACT_TOOL" resolve-compatible "$PROJECT_PATH" "$1"
}

current_one_path() {
  local ref
  ref="$(bash "$CURRENT_ARTIFACT_TOOL" resolve-compatible-one "$PROJECT_PATH" "$1")" || return 1
  printf '%s/%s\n' "$PROJECT_PATH" "$ref"
}

check_current_exists() {
  local logical_id="$1" label="$2" output
  if output="$(current_refs "$logical_id" 2>&1)"; then
    printf '  %s\n' "$output"
    pass "$label — current logical artifact"
  else
    printf '  %s\n' "$output"
    fail "$label — current resolution BLOCKED"
  fi
}

check_applicable_artifact_group() {
  local capability="$1" producer="$2" label="$3"
  shift 3
  local resolver output resolved_capability applicability profile_field profile_value
  local profile_revision applicability_owner applicability_reason extra logical ref
  local -a logical_ids=("$@") refs=()
  resolver="$(dirname "${BASH_SOURCE[0]}")/applicability-resolve.sh"
  if ! output="$(bash "$resolver" resolve "$PROJECT_PATH" "$capability" 2>&1)"; then
    printf '  %s\n' "$output"
    fail "$label — applicability BLOCKED"
    return
  fi
  IFS=$'\t' read -r resolved_capability applicability profile_field profile_value \
    profile_revision applicability_owner applicability_reason extra <<< "$output"
  if [[ -n "$extra" || "$resolved_capability" != "$capability" ]]; then
    fail "$label — invalid applicability resolver output"
    return
  fi

  for logical in "${logical_ids[@]}"; do
    if ! output="$(current_refs "$logical")"; then
      if [[ "$applicability" == REQUIRED ]]; then
        fail "$label — current $logical resolution BLOCKED"
        return
      fi
      continue
    fi
    while IFS= read -r ref; do [[ -n "$ref" ]] && refs+=("$ref"); done <<< "$output"
  done
  (( ${#refs[@]} > 0 )) || { fail "$label — current refs отсутствуют"; return; }
  if [[ "$applicability" == REQUIRED ]]; then
    for ref in "${refs[@]}"; do
      if [[ "$ref" == *not-applicable*.md ]]; then
        fail "$label — current N/A decision противоречит REQUIRED profile"
        return
      fi
    done
    pass "$label — REQUIRED current artifacts VERIFIED"
    return
  fi

  [[ "$applicability" == NOT_APPLICABLE ]] || {
    fail "$label — unsupported applicability=$applicability"; return;
  }
  declare -A validated_na=()
  for ref in "${refs[@]}"; do
    if [[ "$ref" != *not-applicable*.md ]]; then
      fail "$label — current artifact противоречит NOT_APPLICABLE profile"
      return
    fi
    [[ -z "${validated_na[$ref]:-}" ]] || continue
    if output="$(bash "$resolver" validate "$PROJECT_PATH" "$capability" "$ref" "$producer" 2>&1)"; then
      printf '  %s\n' "$output"
      validated_na["$ref"]=1
    else
      printf '  %s\n' "$output"
      fail "$label — NOT_APPLICABLE decision invalid/stale"
      return
    fi
  done
  pass "$label — profile-bound current NOT_APPLICABLE VERIFIED"
}

check_product_acceptance() {
  local output
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/product-acceptance-check.sh" "$PROJECT_PATH" 2>&1)"; then
    printf '  %s\n' "$output"
    pass 'Product acceptance: UX applicability + UAT Must-FR trace'
  else
    printf '  %s\n' "$output"
    fail 'Product acceptance — BLOCKED'
  fi
}

check_architecture_trace() {
  local output
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/architecture-decision-trace-check.sh" "$PROJECT_PATH" 2>&1)"; then
    printf '  %s\n' "$output"
    pass 'Architecture decisions: NFR→QA→Tactic→Pattern→ADR trace'
  else
    printf '  %s\n' "$output"
    fail 'Architecture decision trace — BLOCKED'
  fi
}

check_runtime_constraints() {
  local mode="$1" output
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/runtime-constraints-check.sh" \
    "$PROJECT_PATH" "$mode" 2>&1)"; then
    printf '  %s\n' "$output"
    pass "Runtime Constraints v1: $mode trace"
  else
    printf '  %s\n' "$output"
    fail "Runtime Constraints v1: $mode trace — BLOCKED"
  fi
}

check_gate4_evidence() {
  local status_file source_revision status_output evidence_output
  status_file="$(current_one_path tdd-status || true)"
  if [[ -z "$status_file" ]]; then
    fail 'QA-TDD-status.md — НЕ НАЙДЕН'
    return
  fi
  source_revision="$(awk -F: '$1 == "source_revision" { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit }' "$status_file")"
  if status_output="$(bash "$(dirname "${BASH_SOURCE[0]}")/tdd-status-check.sh" "$PROJECT_PATH" PASS 2>&1)"; then
    printf '  %s\n' "$status_output"
  else
    printf '  %s\n' "$status_output"
    fail 'QA-TDD status/affected regression — BLOCKED'
    return
  fi
  if evidence_output="$(bash "$(dirname "${BASH_SOURCE[0]}")/pr-evidence-check.sh" \
    "$PROJECT_PATH" "$source_revision" 2>&1)"; then
    printf '  %s\n' "$evidence_output"
  else
    printf '  %s\n' "$evidence_output"
    fail 'PR Evidence aggregate — BLOCKED'
    return
  fi
  pass 'QA-TDD full-affected handoff связан с exact final source'
}

check_gate4_pr_set() {
  local output
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/gate4-pr-set-check.sh" "$PROJECT_PATH" 2>&1)"; then
    printf '  %s\n' "$output"
    pass 'Gate 4 full current PR set'
  else
    printf '  %s\n' "$output"
    fail 'Gate 4 full current PR set — BLOCKED'
  fi
}

check_maintainability_review() {
  local profile="$PROJECT_PATH/tracking/product-ci-profile.yaml" schema profile_revision
  local status_file source_revision review rationale evidence_ids
  local -a reviews=()
  schema="$(flat_field "$profile" schema_version)"
  profile_revision="$(flat_field "$profile" revision)"
  status_file="$(current_one_path tdd-status || true)"
  [[ -n "$status_file" ]] || { fail 'Maintainability review: source anchor отсутствует'; return; }
  source_revision="$(flat_field "$status_file" source_revision)"
  mapfile -t review_refs < <(current_refs techlead-reviews)
  for review in "${review_refs[@]}"; do reviews+=("$PROJECT_PATH/$review"); done
  (( ${#reviews[@]} > 0 )) || { fail 'Maintainability review: TL artifacts отсутствуют'; return; }
  for review in "${reviews[@]}"; do
    bash "$(dirname "${BASH_SOURCE[0]}")/artifact-metadata-check.sh" "$PROJECT_PATH" \
      "${review#"$PROJECT_PATH/"}" >/dev/null || {
      fail "$(basename "$review"): common Artifact Metadata invalid"; return;
    }
  done
  [[ "$schema" == 5 ]] || { pass "Tech Lead review metadata VERIFIED для ${#reviews[@]} review(s)"; return; }
  for review in "${reviews[@]}"; do
    [[ "$(flat_field "$review" product_profile_revision)" == "$profile_revision" ]] || {
      fail "$(basename "$review"): stale product_profile_revision"; return;
    }
    grep -Fq '## Maintainability Review' "$review" || {
      fail "$(basename "$review"): Maintainability Review section отсутствует"; return;
    }
    for dimension in Modularity Reusability Analysability Modifiability Testability; do
      grep -Fqx "$dimension: PASS" "$review" || {
        fail "$(basename "$review"): $dimension не имеет PASS"; return;
      }
    done
    rationale="$(grep -E '^Maintainability rationale:[[:space:]]*[^[:space:]].+$' "$review" || true)"
    [[ -n "$rationale" && ! "${rationale,,}" =~ (unknown|tbd|todo|placeholder) ]] || {
      fail "$(basename "$review"): concrete maintainability rationale отсутствует"; return;
    }
    evidence_ids="$(grep -E '^Maintainability evidence ids:[[:space:]]*[A-Za-z0-9._:-]+([,][A-Za-z0-9._:-]+)*$' "$review" || true)"
    [[ -n "$evidence_ids" ]] || {
      fail "$(basename "$review"): maintainability evidence ids отсутствуют"; return;
    }
  done
  pass "Maintainability: 5 dimensions PASS для ${#reviews[@]} TL review(s)"
}

check_full_dod_approval() {
  local status_file source_revision output
  status_file="$(current_one_path tdd-status || true)"
  [[ -n "$status_file" ]] || { fail 'Full DoD approval: TDD source anchor отсутствует'; return; }
  source_revision="$(flat_field "$status_file" source_revision)"
  if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/dod-approval-check.sh" \
    "$PROJECT_PATH" "$source_revision" 2>&1)"; then
    printf '  %s\n' "$output"
    pass 'Full Software DoD: independent approval VERIFIED'
  else
    printf '  %s\n' "$output"
    fail 'Full Software DoD approval — BLOCKED'
  fi
}

check_gate5_validation() {
  local status_file source_revision status_output s5_output
  status_file="$(current_one_path tdd-status || true)"
  if [[ -z "$status_file" ]]; then
    fail 'QA-TDD-status.md — exact source для Gate 5 НЕ НАЙДЕН'
    return
  fi
  source_revision="$(awk -F: '$1 == "source_revision" { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit }' "$status_file")"
  if status_output="$(bash "$(dirname "${BASH_SOURCE[0]}")/tdd-status-check.sh" "$PROJECT_PATH" PASS 2>&1)"; then
    printf '  %s\n' "$status_output"
  else
    printf '  %s\n' "$status_output"
    fail 'Gate 5 source anchor — QA-TDD PASS evidence invalid'
    return
  fi
  if s5_output="$(bash "$(dirname "${BASH_SOURCE[0]}")/s5-validation-check.sh" \
    "$PROJECT_PATH" "$source_revision" 2>&1)"; then
    printf '  %s\n' "$s5_output"
    pass 'Gate 5: five-stream exact-source validation + defects + UAT approval VERIFIED'
  else
    printf '  %s\n' "$s5_output"
    fail 'Gate 5 — S5 Validation FAIL/BLOCKED/UNVERIFIED'
  fi
}

echo
echo "╔═ DoR Auto-Check — Gate ${GATE} ══════════════════════════════╗"
echo "  Проект: ${PROJECT_PATH}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo
echo '  [DoR-1] Обязательные артефакты и evidence'

if (( GATE >= 2 )); then
  check_quality_policy
  check_quality_characteristics
fi

case "$GATE" in
  1)
    if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/gate1-planning-check.sh" "$PROJECT_PATH" 2>&1)"; then printf '  %s\n' "$output"; pass 'Gate 1 planning contract'; else printf '  %s\n' "$output"; fail 'Gate 1 planning contract — BLOCKED'; fi
    ;;
  2)
    check_runtime_constraints requirements
    check_current_exists business-requirements 'Business requirements'
    check_current_exists nonfunctional-requirements 'Nonfunctional requirements'
    check_current_exists requirements-traceability 'Requirements traceability'
    check_current_exists product-backlog 'Product backlog'
    check_product_acceptance
    if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/qa-requirements-review-check.sh" "$PROJECT_PATH" 2>&1)"; then printf '  %s
' "$output"; pass 'QA requirements review v1'; else printf '  %s
' "$output"; fail 'QA requirements review v1 — BLOCKED'; fi
    check_current_exists test-strategy 'QA test strategy'
    if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/sg1-check.sh" "$PROJECT_PATH" 2>&1)"; then
      printf '  %s\n' "$output"; pass 'Security requirements / SG1 semantic contract'
    else
      printf '  %s\n' "$output"; fail 'Security requirements / SG1 — BLOCKED'
    fi
    ;;
  3)
    check_current_exists high-level-design 'High-level design'
    check_architecture_trace
    check_applicable_artifact_group api-contract s3-arch 'API contract decision' api-contract
    if output="$(bash "$(dirname "${BASH_SOURCE[0]}")/sg2-check.sh" "$PROJECT_PATH" 2>&1)"; then
      printf '  %s\n' "$output"; pass 'Threat model / SG2 semantic contract'
    else
      printf '  %s\n' "$output"; fail 'Threat model / SG2 — BLOCKED'
    fi
    check_applicable_artifact_group authorization s3-rbac 'Authorization design decision' \
      authorization-model authorization-matrix
    check_applicable_artifact_group data-store s3-dba 'Data-store schema/migration decision' \
      data-schema migration-runbook
    ;;
  4)
    check_current_exists techlead-reviews 'Tech Lead reviews'
    check_current_exists development-update-notes 'Development update notes'
    check_maintainability_review
    check_gate4_evidence
    check_gate4_pr_set
    check_full_dod_approval
    ;;
  5)
    check_gate5_validation
    ;;
esac

echo
echo '  [DoR-5] Открытые BLOCKER-вопросы (частичная проверка)'
BLOCKER_COUNT=0
CURRENT_MANIFEST="$PROJECT_PATH/tracking/current-artifacts-v1.tsv"
declare -a blocker_files=()
if [[ -e "$CURRENT_MANIFEST" ]]; then
  if bash "$CURRENT_ARTIFACT_TOOL" validate "$PROJECT_PATH" >/dev/null; then
    while IFS= read -r ref; do blocker_files+=("$PROJECT_PATH/$ref"); done < <(
      awk -F'\t' 'NR > 1 && $4 ~ /\.md$/ {print $4}' "$CURRENT_MANIFEST" | sort -u
    )
  else
    fail 'Current artifact manifest invalid; blocker scan не может использовать history fallback'
  fi
else
  while IFS= read -r -d '' file; do blocker_files+=("$file"); done < <(
    find "$PROJECT_PATH" -type f -name '*.md' -path '*/outputs/*' -print0 2>/dev/null
  )
  warn 'Blocker scan использует legacy outputs: current manifest ещё отсутствует'
fi
for file in "${blocker_files[@]}"; do
  count="$(grep -Ei 'BLOCKER.*OPEN|OPEN.*BLOCKER' "$file" 2>/dev/null |
    grep -Evi 'no[[:space:]]+open[[:space:]]+blocker|нет[[:space:]]+открытых[[:space:]]+blocker' |
    wc -l || true)"
  BLOCKER_COUNT=$((BLOCKER_COUNT + count))
done
if (( BLOCKER_COUNT == 0 )); then
  pass '0 открытых BLOCKER найдено в outputs/'
else
  fail "$BLOCKER_COUNT BLOCKER(ов) со статусом OPEN — требуется ручная проверка"
fi

if [[ "$GATE" == 2 ]]; then
  echo
  echo '  [DoR-2..4] Качество требований (частичная проверка)'
  BRD_FILE="$(current_one_path business-requirements || true)"
  BACKLOG="$(current_one_path product-backlog || true)"
  NFR_FILE="$(current_one_path nonfunctional-requirements || true)"
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

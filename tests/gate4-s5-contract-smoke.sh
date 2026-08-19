#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
require_text() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$ROOT/$file" || fail "$file missing contract text: $text"
}
forbid_text() {
  local file="$1" text="$2"
  ! grep -Fq -- "$text" "$ROOT/$file" || fail "$file retains forbidden contract text: $text"
}

TL=cycle1-dev/s4-techlead/.claude/commands/review.md
require_text "$TL" 'переход S4 → S5'
require_text "$TL" 'tdd-status-check.sh'
require_text "$TL" 'pr-evidence-check.sh'
require_text "$TL" 'sg3-policy-check.sh'
require_text "$TL" 'Maintainability evidence ids:'
for dimension in Modularity Reusability Analysability Modifiability Testability; do
  require_text "$TL" "$dimension: PASS|FAIL"
done
forbid_text "$TL" 'блокирует релиз'
forbid_text "$TL" 'SAST прошёл без Critical/High'

QA_ROLE=cycle1-dev/s5-qa/CLAUDE.md
QA_PLAN=cycle1-dev/s5-qa/.claude/commands/test-plan.md
QA_GO=cycle1-dev/s5-qa/.claude/commands/go-no-go.md
AUTO_ROLE=cycle1-dev/s5-qa-auto/CLAUDE.md
AUTO_CMD=cycle1-dev/s5-qa-auto/.claude/commands/e2e-report.md
PERF_ROLE=cycle1-dev/s5-perf/CLAUDE.md
PERF_CMD=cycle1-dev/s5-perf/.claude/commands/load-test.md

for file in "$QA_ROLE" "$QA_PLAN" "$QA_GO" "$AUTO_ROLE" "$AUTO_CMD" "$PERF_ROLE" "$PERF_CMD"; do
  require_text "$file" '_standards/data-formats.md'
done
require_text "$QA_ROLE" 'S5 → CYCLE 1 VALIDATED'
require_text "$QA_ROLE" 'full-affected'
require_text "$QA_ROLE" 'отдельный UAT Human Approval v1'
require_text "$QA_ROLE" 'current Product Profile, BRD/NFR, HLD, risk register'
require_text "$QA_ROLE" 'Не переноси stack/project-specific кейсы между продуктами автоматически'
require_text "$QA_GO" 'full-affected'
for file in "$QA_ROLE" "$QA_GO"; do
  forbid_text "$file" 'S5 → S6'
  forbid_text "$file" 'Sprint N-1'
done

require_text "$AUTO_ROLE" 'UI automation — только когда применимо'
require_text "$AUTO_ROLE" 'API-only, library, CLI и non-UI'
require_text "$AUTO_ROLE" 'не создавай и не исправляй executable test code'
require_text "$AUTO_ROLE" 'Тип Д — Документ'
require_text "$AUTO_CMD" 'effective quality policy; UI только если применим'
for file in "$AUTO_ROLE" "$AUTO_CMD"; do
  forbid_text "$file" '≤20'
  forbid_text "$file" '<30 сек'
done
require_text "$PERF_ROLE" 'Тип Д — Документ'
require_text "$PERF_CMD" 'не создавай и не исправляй executable load-test code'
forbid_text "$PERF_CMD" 'PERF-[дата]-k6-load.js'

echo 'PASS: Gate 4 and S5 applicability contract smoke'

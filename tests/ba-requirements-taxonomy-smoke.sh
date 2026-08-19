#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROLE="$ROOT/cycle1-dev/s2-ba/CLAUDE.md"
COMMAND="$ROOT/cycle1-dev/s2-ba/.claude/commands/brd.md"
QUALITY="$ROOT/_standards/quality.md"
fail() { echo "FAIL: $*" >&2; exit 1; }
contains() { grep -Fq "$2" "$1" || fail "$1 missing: $2"; }
not_contains() { ! grep -Fq "$2" "$1" || fail "$1 contains forbidden default: $2"; }

for characteristic in 'Functional Suitability' 'Performance Efficiency' Compatibility \
  'Interaction Capability' Reliability Security Maintainability Flexibility Safety; do
  contains "$ROLE" "$characteristic"
done
contains "$ROLE" '_contract/QUALITY_CHARACTERISTICS_V1.md'
contains "$ROLE" 'Не выводи применимость из Tier'
contains "$ROLE" 'Множество значений открыто'
contains "$ROLE" 'native type выбирается только в HLD/ADR'
contains "$COMMAND" 'девять current ISO/IEC 25010:2023 characteristics'

for forbidden in \
  'GET /health' 'если Tier ≥ 1' 'Runtime Constraint = multi-instance' \
  '| `single-container`' '| `multi-instance`' '| `serverless`' \
  'Финансовые поля: явно "NUMERIC(p,s)"' \
  'Performance / Scalability / Availability / Security / Usability'; do
  not_contains "$ROLE" "$forbidden"
done

while IFS=$'\t' read -r shape required_text forbidden_text; do
  [[ "$shape" != shape ]] || continue
  contains "$ROLE" "$required_text"
  if [[ "$forbidden_text" != none ]]; then not_contains "$required_text" "$forbidden_text"; fi
done <<'MATRIX'
shape	required_text	forbidden_text
http-service	Network service + liveness REQUIRED	none
cli	CLI | Exit code/stdout/stderr	none
library	Library | Import/API/package compatibility	none
desktop	Desktop/mobile | Startup/UI/platform outcome	none
event-worker	Scheduled/event worker | Job/heartbeat/queue-consumer outcome	none
non-sql-finance	currency, decimal precision, scale, rounding mode	none
MATRIX

contains "$QUALITY" 'CLI/library/desktop/worker не получают'
contains "$QUALITY" 'stack-native exact-decimal type выбирается в HLD/ADR'
echo 'PASS: BA requirements taxonomy smoke'

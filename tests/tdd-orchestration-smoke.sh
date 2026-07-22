#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-tdd-smoke.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

AGENT_RUNTIME=codex
CODEX_BIN=/bin/true
SDLC_RUNTIME_ROUTING=single
SDLC_SUBAGENTS=off
SDLC_SUBAGENT_MAX=2
source "$ROOT/sdlc.sh"

PROJECTS="$TMP_DIR/projects"
PROJECT="demo"
STATUS_FILE="$PROJECTS/$PROJECT/stage4-dev/outputs/QA-TDD-status.md"
CALLS_FILE="$TMP_DIR/calls"
mkdir -p "$(dirname "$STATUS_FILE")"
BASE_PROFILE="codex||||"

write_status() {
  printf 'status: %s\nproject: demo\nfailed_tests: %s\n' "$1" "${2:-0}" > "$STATUS_FILE"
}

write_status RED
require_tdd_red || fail "require_tdd_red rejected RED"
write_status PASS
if require_tdd_red >/dev/null 2>&1; then
  fail "require_tdd_red accepted PASS before initial implementation"
fi

run_agent() {
  local agent="$1" task="$3"
  printf '%s:%s\n' "$agent" "$task" >> "$CALLS_FILE"
  if [[ "$agent:$task" == "s4-qa-auto:/run-tests" ]]; then
    write_status PASS
  fi
  return 0
}

write_status FAIL 1
TDD_MAX_REPAIR_ITERATIONS=3 run_tdd_repair_loop ||
  fail "repair loop did not recover FAIL to PASS"
[[ "$(read_tdd_status)" == "PASS" ]] || fail "repair loop did not persist PASS"
[[ "$(sed -n '1p' "$CALLS_FILE")" == "s4-dev:/dev-report" ]] ||
  fail "repair loop did not return to s4-dev first"
[[ "$(sed -n '2p' "$CALLS_FILE")" == "s4-qa-auto:/run-tests" ]] ||
  fail "repair loop did not rerun independent tests second"

run_agent() {
  return 0
}

write_status FAIL 1
if TDD_MAX_REPAIR_ITERATIONS=2 run_tdd_repair_loop >/dev/null 2>&1; then
  fail "repair loop silently passed after exhausting its limit"
fi
[[ "$(read_tdd_status)" == "BLOCKED" ]] ||
  fail "exhausted repair loop did not persist BLOCKED"

echo "PASS: TDD orchestration smoke"

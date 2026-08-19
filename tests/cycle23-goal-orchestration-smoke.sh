#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-cycle23-frozen.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "output does not contain: $needle"
}

AGENT_RUNTIME=codex
CODEX_BIN=/bin/true
SDLC_RUNTIME_ROUTING=single
SDLC_SUBAGENTS=off
SDLC_SUBAGENT_MAX=2
source "$ROOT/sdlc.sh"

for fn in cycle23_support_status cycle23_execution_available cycle23_frozen_notice \
  run_cycle2 run_cycle3 run_goal_mode offer_goal_profile_at_cycle1_entry; do
  [[ "$(type -t "$fn")" == "function" ]] || fail "missing frozen-scope function: $fn"
done

[[ "$(cycle23_support_status)" == "FROZEN / NOT READY" ]] ||
  fail "Cycle 2/3 support status is not explicit"
if cycle23_execution_available; then
  fail "Cycle 2/3 execution is available in the supported launcher"
fi

# Historical implementation remains in the repository, but is not an active product route.
[[ "${#CYCLE2_AGENTS[@]}" -eq 8 ]] || fail "historical Cycle 2 baseline was deleted"
[[ "${#CYCLE3_AGENTS[@]}" -eq 6 ]] || fail "historical Cycle 3 baseline was deleted"
for path in \
  cycle2-deploy/s4-devops/CLAUDE.md \
  cycle2-deploy/s6-release/CLAUDE.md \
  cycle3-ops/s6-sre/CLAUDE.md \
  cycle2-deploy/s4-devops/.claude/commands/write-deploy-tests.md \
  cycle3-ops/s6-sre/.claude/commands/write-ops-tests.md; do
  [[ -f "$ROOT/$path" ]] || fail "historical Cycle 2/3 artifact was deleted: $path"
done

PROJECTS="$TMP_DIR/projects"
PROJECT=demo
mkdir -p "$PROJECTS/$PROJECT"

CALLS=()
header() { :; }
pick_project() { CALLS+=(pick-project); }
ensure_goal_profile_for_cycle() { CALLS+=(goal-profile); return 0; }
preview_and_execute_cycle() { CALLS+=(execute); return 0; }
run_agent() { CALLS+=(agent); return 0; }

run_cycle2 selected >"$TMP_DIR/cycle2.out" 2>&1 || true
cycle2_output="$(<"$TMP_DIR/cycle2.out")"
assert_contains "$cycle2_output" "FROZEN / NOT READY"
[[ "${#CALLS[@]}" -eq 0 ]] || fail "Cycle 2 reached an execution path: ${CALLS[*]}"

run_cycle3 selected >"$TMP_DIR/cycle3.out" 2>&1 || true
cycle3_output="$(<"$TMP_DIR/cycle3.out")"
assert_contains "$cycle3_output" "FROZEN / NOT READY"
[[ "${#CALLS[@]}" -eq 0 ]] || fail "Cycle 3 reached an execution path: ${CALLS[*]}"

run_cycle1() { CALLS+=("cycle1:${1:-}"); return 0; }
configure_goal_profile() { CALLS+=(goal-config); return 0; }
load_goal_profile() { CALLS+=(goal-load); return 1; }
run_goal_mode selected >"$TMP_DIR/goal.out" 2>&1
goal_output="$(<"$TMP_DIR/goal.out")"
assert_contains "$goal_output" "Cycle 1"
[[ "${CALLS[*]}" == "cycle1:selected" ]] ||
  fail "legacy goal mode did not collapse to Cycle 1-only: ${CALLS[*]}"

CALLS=()
offer_goal_profile_at_cycle1_entry
[[ "${#CALLS[@]}" -eq 0 ]] ||
  fail "Cycle 1 entry still opens the frozen goal configurator: ${CALLS[*]}"

for file in CLAUDE.md README.md OVERVIEW.md plans/roadmap.md; do
  grep -Fq 'FROZEN / NOT READY' "$ROOT/$file" ||
    fail "$file does not expose the frozen Cycle 2/3 status"
done

grep -Fq 'historical implementation baseline' "$ROOT/_standards/tdd.md" ||
  fail "TDD standard does not separate the historical Cycle 2/3 baseline"
grep -Fq 'FROZEN / NOT SUPPORTED' "$ROOT/_standards/quality.md" ||
  fail "quality standard does not freeze Gate 6/7"

echo "PASS: Cycle 2/3 frozen scope smoke"

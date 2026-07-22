#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-launcher-preview.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_RUNTIME=codex
export CODEX_BIN=/bin/true
export SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off
export SDLC_SUBAGENT_MAX=2

source "$ROOT/sdlc.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "preview does not contain: $needle"
}

for fn in render_execution_preview confirm_execution_preview preview_route_label; do
  declare -F "$fn" >/dev/null || fail "missing preview function: $fn"
done

PROJECTS="$TMP_DIR/projects"
PROJECT=Alpha
mkdir -p "$PROJECTS/$PROJECT"
BASE_PROFILE="codex||||"
apply_profile "$BASE_PROFILE"
RUN_CYCLE=("s1-pm:/vision" "s4-dev:/dev-report")
RUN_OPTIONAL=(0 0)

preview="$(render_execution_preview CYCLE 'ТОЛЬКО Cycle 1' 'Cycle 2, Cycle 3')"
assert_contains "$preview" "ПРОВЕРКА ЗАПУСКА"
assert_contains "$preview" "PROJECT:  Alpha"
assert_contains "$preview" "$PROJECTS/Alpha"
assert_contains "$preview" "SCOPE:    ТОЛЬКО Cycle 1"
assert_contains "$preview" "EXCLUDED: Cycle 2, Cycle 3"
assert_contains "$preview" "s1-pm"
assert_contains "$preview" "/vision"
assert_contains "$preview" "Codex / external CLI"
assert_contains "$preview" "No action has run yet"
assert_contains "$preview" "Fallback OFF"

CALLS=()
preview_executor_spy() { CALLS+=(executed); }
confirm_execution_preview preview_executor_spy <<< "b" >/dev/null || true
[[ ${#CALLS[@]} -eq 0 ]] || fail "Back dispatched execution"
confirm_execution_preview preview_executor_spy <<< "?" >/dev/null || true
[[ ${#CALLS[@]} -eq 0 ]] || fail "Help dispatched execution"
confirm_execution_preview preview_executor_spy <<< "r" >/dev/null
[[ "${CALLS[*]}" == "executed" ]] || fail "explicit run confirmation did not dispatch"

BASE_PROFILE="local|ollama|qwen2.5-coder:14b|codex-oss|"
apply_profile "$BASE_PROFILE"
local_preview="$(render_execution_preview AGENT 's4-dev /dev-report' 'другие primary Agents')"
assert_contains "$local_preview" "Local / codex-oss / ollama / qwen2.5-coder:14b"

echo "PASS: launcher preview/dispatch smoke"

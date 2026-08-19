#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-workers-fail-closed.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "output does not contain: $2"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "output unexpectedly contains: $2"; }

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_RUNTIME=codex
export CODEX_BIN=/bin/true
export SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off
export SDLC_SUBAGENT_MAX=2

source "$ROOT/sdlc.sh"

for fn in render_subagent_execution_summary render_subagent_mode_choice \
  configure_subagent_settings ensure_subagent_settings configure_cross_runtime_subagents; do
  declare -F "$fn" >/dev/null || fail "missing fail-closed worker function: $fn"
done

choice="$(render_subagent_mode_choice first-run)"
assert_contains "$choice" 'Шаг 2 из 2 — статус AI-помощников'
assert_contains "$choice" 'Workers временно недоступны'
assert_contains "$choice" 'Prompt-only ограничение недостаточно'
assert_contains "$choice" 'единственный доступный режим'
assert_not_contains "$choice" 'Помощники той же AI-системы'
assert_not_contains "$choice" 'Отдельная AI-модель как помощник'

summary="$(render_subagent_execution_summary)"
assert_contains "$summary" 'Workers: BLOCKED until capability-enforced bounded read scope exists'
assert_contains "$summary" 'Fallback: OFF'

SDLC_SUBAGENTS=off
SDLC_SUBAGENT_PROFILE='legacy||||'
SDLC_SUBAGENT_TASKS=analysis
configure_subagent_settings >/dev/null
[[ "$SDLC_SUBAGENTS" == off ]] || fail 'worker configurator did not force off'
[[ -z "$SDLC_SUBAGENT_PROFILE" ]] || fail 'worker configurator retained a legacy profile'
[[ -z "$SDLC_SUBAGENT_TASKS" ]] || fail 'worker configurator retained legacy tasks'

for policy in auto cross-runtime; do
  SDLC_SUBAGENTS="$policy"
  if ensure_subagent_settings >"$TMP_DIR/sdlc-$policy.out" 2>&1; then
    fail "main launcher accepted unsupported worker policy: $policy"
  fi
  grep -Fq 'BLOCKED: worker execution' "$TMP_DIR/sdlc-$policy.out" ||
    fail "main launcher did not explain blocked worker policy: $policy"
done

if configure_cross_runtime_subagents >"$TMP_DIR/configure-cross.out" 2>&1; then
  fail 'cross-runtime configurator succeeded while workers are disabled'
fi
grep -Fq 'BLOCKED: cross-runtime workers' "$TMP_DIR/configure-cross.out" ||
  fail 'cross-runtime configurator did not return a clear BLOCKED reason'

PROJECTS="$TMP_DIR/projects"
PROJECT=Alpha
mkdir -p "$PROJECTS/$PROJECT/tracking"
BASE_PROFILE='codex||||'
SDLC_SUBAGENTS=off
save_project_ai_config "$BASE_PROFILE" single || fail 'off project worker policy was not persisted'
SDLC_SUBAGENTS=auto
if save_project_ai_config "$BASE_PROFILE" single; then
  fail 'unsupported worker policy was persisted in project config'
fi

for policy in auto cross-runtime; do
  if AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_SUBAGENTS="$policy" \
    SDLC_SUBAGENT_PROFILE='codex||||' SDLC_SUBAGENT_TASKS=analysis \
    "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
      --project-dir "$PROJECTS/$PROJECT" --mode task --prompt smoke \
      >"$TMP_DIR/dispatcher-$policy.out" 2>&1; then
    fail "dispatcher accepted unsupported worker policy: $policy"
  fi
  if ! grep -Fq 'BLOCKED: worker execution is disabled' "$TMP_DIR/dispatcher-$policy.out"; then
    sed 's/^/dispatcher: /' "$TMP_DIR/dispatcher-$policy.out" >&2
    fail "dispatcher did not explain blocked worker policy: $policy"
  fi
done

if SDLC_PROJECTS_DIR="$PROJECTS" SDLC_SUBAGENT_PROFILE='codex||||' \
  SDLC_SUBAGENT_TASKS=analysis CODEX_BIN=/bin/true \
  bash "$ROOT/_runtimes/subagent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --kind analysis --task inspect --read-scope "$PROJECTS/$PROJECT" \
    --response-format Markdown >"$TMP_DIR/direct-worker.out" 2>&1; then
  fail 'direct worker invocation succeeded'
fi
grep -Fq 'BLOCKED: worker execution is disabled' "$TMP_DIR/direct-worker.out" ||
  fail 'direct worker invocation did not return a clear BLOCKED reason'

XDG_CONFIG_HOME="$TMP_DIR/localrun-config" AGENT_RUNTIME=codex CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING=single SDLC_SUBAGENTS=cross-runtime SDLC_SUBAGENT_MAX=2 \
  bash -c 'source "$1"; ensure_subagent_settings' _ "$ROOT/localrun.sh" \
  >"$TMP_DIR/localrun-cross.out" 2>&1 &&
  fail 'Local Run accepted unsupported cross-runtime workers'
grep -Fq 'BLOCKED: worker execution' "$TMP_DIR/localrun-cross.out" ||
  fail 'Local Run did not explain blocked workers'

echo 'PASS: workers fail-closed smoke'

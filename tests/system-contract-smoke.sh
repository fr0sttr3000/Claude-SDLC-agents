#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-contract-smoke.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$ROOT/$1" ]] || fail "missing file: $1"
}

assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$ROOT/$file" || fail "$file does not contain: $text"
}

assert_order() {
  local file="$1" first="$2" second="$3" first_line second_line
  first_line="$(grep -nF -- "$first" "$ROOT/$file" | head -1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$ROOT/$file" | head -1 | cut -d: -f1)"
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] || \
    fail "$file order violation: '$first' must be before '$second'"
}

assert_file "_standards/tdd.md"
assert_file "_contract/SUBAGENTS.md"

while IFS= read -r -d '' canonical; do
  agent_dir="${canonical%/CLAUDE.md}"
  for adapter in AGENTS.md GEMINI.md; do
    [[ -L "$agent_dir/$adapter" ]] ||
      fail "${agent_dir#"$ROOT/"}: $adapter is not a canonical symlink"
    [[ "$(readlink "$agent_dir/$adapter")" == 'CLAUDE.md' ]] ||
      fail "${agent_dir#"$ROOT/"}: $adapter does not point to CLAUDE.md"
  done
done < <(find "$ROOT/cycle1-dev" "$ROOT/cycle2-deploy" "$ROOT/cycle3-ops" "$ROOT/_tools" \
  -mindepth 2 -maxdepth 2 -name CLAUDE.md -type f -print0)
assert_file "_runtimes/adapters/local.md"
assert_file "_runtimes/local-hosts/codex-oss"
assert_file "_runtimes/subagent-run.sh"
assert_file "cycle1-dev/s2-test-strategy/CLAUDE.md"
assert_file "cycle1-dev/s4-qa-auto/CLAUDE.md"
assert_file "cycle1-dev/s4-qa-auto/.claude/commands/write-tests.md"
assert_file "cycle1-dev/s4-qa-auto/.claude/commands/run-tests.md"

assert_contains "sdlc.sh" '"s2-test-strategy:/strategy"'
assert_contains "sdlc.sh" '"s4-qa-auto:/write-tests"'
assert_contains "sdlc.sh" '"s4-qa-auto:/run-tests"'
assert_contains "sdlc.sh" "run_tdd_repair_loop"
assert_contains "sdlc.sh" "SDLC_RUNTIME_ROUTING"
assert_contains "sdlc.sh" "resolve_step_runtime"
assert_contains "sdlc.sh" "LOCAL_AGENT_HOST"
assert_contains "sdlc.sh" 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]'
assert_contains "localrun.sh" "LOCAL_AGENT_HOST"
assert_contains "localrun.sh" "resolve_step_runtime"
assert_contains "localrun.sh" "SDLC_SUBAGENTS"
assert_contains "localrun.sh" 'SDLC_SUBAGENT_PROFILE=""'
assert_contains "localrun.sh" 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]'
assert_order "sdlc.sh" '"s4-qa-auto:/write-tests"' '"s4-dev:/dev-report"'
assert_order "sdlc.sh" '"s4-dev:/dev-report"' '"s4-qa-auto:/run-tests"'
bash -c 'source "$1"; [[ "${#CYCLE1_AGENTS[@]}" -eq 28 ]]' _ "$ROOT/sdlc.sh" || fail "Cycle 1 must contain exactly 28 mandatory steps"

assert_contains "cycle1-dev/s0-kickoff/CLAUDE.md" "Monitoring Stack"
assert_contains "cycle1-dev/s0-kickoff/CLAUDE.md" "Playbook Executor"
assert_contains "cycle1-dev/s0-kickoff/CLAUDE.md" "Operations Owner"
assert_contains "cycle1-dev/s0-kickoff/CLAUDE.md" "Auto-Heal Authorization"
assert_contains "_standards/quality.md" "Alert Deduplication"
assert_contains "cycle1-dev/s0-validate/dod-check.sh" "N/A вне подготовки релиза"
assert_contains "cycle1-dev/s0-validate/CLAUDE.md" "вне release preparation сообщает N/A"
assert_contains "cycle2-deploy/s4-devops/CLAUDE.md" "dedup_key"
assert_contains "cycle2-deploy/s4-devops/CLAUDE.md" "idempotency test (Red)"
assert_contains "cycle3-ops/s6-sre/CLAUDE.md" "один incident/notification"
assert_contains "cycle3-ops/s6-sre/CLAUDE.md" "failure-injection scenario (Red)"

# Active documentation must describe the implemented baseline, not the previous one.
assert_contains "CLAUDE.md" "28 обязательных шагов"
assert_contains "README.md" "32 специализированных AI-агента"
assert_contains "README.md" "AGENT_RUNTIME=local"
assert_contains "GETTING_STARTED.md" "28 обязательных шагов"
assert_contains "OVERVIEW.md" "28 обязательных шагов"
assert_contains "plans/document-map.md" "28 обязательных шагов"
assert_contains "plans/principles.md" "single|per-stage|per-agent|ask"
assert_contains "plans/principles.md" "Specify → Red → Green → Run → Repair → Refactor"
assert_contains "CLAUDE.md" "cross-runtime"
assert_contains "_contract/SUBAGENTS.md" "Supervisor + Worker"
assert_contains "_contract/EXECUTION_JOURNAL.md" "exact worker profile"
assert_contains "plans/principles.md" "Supervisor + Worker"
assert_contains "plans/roadmap.md" "Локальные модели, TDD, subagents и operational-контракт"
assert_contains "_contract/README.md" "_runtimes/adapters/local.md"

FAKE_CODEX="$TMP_DIR/fake-codex"
CAPTURE="$TMP_DIR/capture.txt"
cat > "$FAKE_CODEX" <<'FAKE'
#!/usr/bin/env bash
{
  printf 'ARG=%s\n' "$@"
  printf 'SUBAGENTS=%s\n' "${SDLC_SUBAGENTS:-}"
  printf 'SUBAGENT_MAX=%s\n' "${SDLC_SUBAGENT_MAX:-}"
} > "$CAPTURE_FILE"
FAKE
chmod +x "$FAKE_CODEX"

CAPTURE_FILE="$CAPTURE" \
AGENT_RUNTIME=local \
LOCAL_AGENT_HOST=codex-oss \
LOCAL_MODEL_PROVIDER=ollama \
LOCAL_MODEL=test-model:latest \
LOCAL_CODEX_BIN="$FAKE_CODEX" \
SDLC_SUBAGENTS=auto \
SDLC_SUBAGENT_MAX=2 \
  "$ROOT/_runtimes/agent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --mode task \
    --prompt "contract smoke"

grep -Fq 'ARG=--oss' "$CAPTURE" || fail "local runtime did not pass --oss"
grep -Fq 'ARG=--local-provider' "$CAPTURE" || fail "local runtime did not pass provider flag"
grep -Fq 'ARG=ollama' "$CAPTURE" || fail "local runtime did not pass ollama provider"
grep -Fq 'ARG=-m' "$CAPTURE" || fail "local runtime did not pass model flag"
grep -Fq 'ARG=test-model:latest' "$CAPTURE" || fail "local runtime did not pass exact model"
grep -Fq 'SUBAGENTS=auto' "$CAPTURE" || fail "subagent mode not propagated"
grep -Fq 'SUBAGENT_MAX=2' "$CAPTURE" || fail "subagent max not propagated"
grep -Fq 'SUBAGENT MODE: auto' "$CAPTURE" || fail "subagent policy not injected into prompt"

if AGENT_RUNTIME=local LOCAL_AGENT_HOST=codex-oss LOCAL_MODEL_PROVIDER=ollama LOCAL_CODEX_BIN="$FAKE_CODEX" \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" --mode task --prompt smoke \
  >"$TMP_DIR/missing-model.out" 2>&1; then
  fail "local runtime accepted an empty LOCAL_MODEL"
fi

if AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_SUBAGENTS=auto SDLC_SUBAGENT_MAX=08 \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
  --mode task --prompt smoke >"$TMP_DIR/invalid-worker-max.out" 2>&1; then
  fail "runtime accepted a non-canonical worker max with a leading zero"
fi
grep -Fq 'must be an integer from 1 to 16' "$TMP_DIR/invalid-worker-max.out" ||
  fail 'invalid worker max did not return a controlled validation error'

if AGENT_RUNTIME=local LOCAL_MODEL_PROVIDER=ollama LOCAL_MODEL=test-model:latest \
  LOCAL_CODEX_BIN="$FAKE_CODEX" \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" --mode task --prompt smoke \
  >"$TMP_DIR/missing-host.out" 2>&1; then
  fail "local runtime accepted an empty LOCAL_AGENT_HOST"
fi

FAKE_HOST="$TMP_DIR/fake-local-host"
CUSTOM_CAPTURE="$TMP_DIR/custom-capture.txt"
cat > "$FAKE_HOST" <<'FAKE'
#!/usr/bin/env bash
{
  printf 'ARG=%s\n' "$@"
  printf 'PROVIDER=%s\n' "${LOCAL_MODEL_PROVIDER:-}"
  printf 'MODEL=%s\n' "${LOCAL_MODEL:-}"
} > "$CUSTOM_CAPTURE_FILE"
FAKE
chmod +x "$FAKE_HOST"

CUSTOM_CAPTURE_FILE="$CUSTOM_CAPTURE" \
AGENT_RUNTIME=local \
LOCAL_AGENT_HOST=custom-smoke \
LOCAL_MODEL_PROVIDER=openai-compatible \
LOCAL_MODEL=org/exact-model \
LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
  bash -c '
    mkdir -p "$LOCAL_HOST_REGISTRY"
    ln -s "$1" "$LOCAL_HOST_REGISTRY/custom-smoke"
    exec "$2" --agent-dir "$3" --mode task --prompt "custom adapter smoke"
  ' _ "$FAKE_HOST" "$ROOT/_runtimes/agent-run.sh" "$ROOT/cycle1-dev/s1-pm"

grep -Fq 'PROVIDER=openai-compatible' "$CUSTOM_CAPTURE" || fail "custom host did not receive provider"
grep -Fq 'MODEL=org/exact-model' "$CUSTOM_CAPTURE" || fail "custom host did not receive exact model"

ROUTING_FILE="$TMP_DIR/routing.conf"
cat > "$ROUTING_FILE" <<'ROUTING'
agent:s4-dev=local|openai-compatible|org/exact-model|custom-smoke|http://127.0.0.1:8000/v1
ROUTING

AGENT_RUNTIME=codex \
CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING=per-agent \
SDLC_SUBAGENTS=off \
SDLC_SUBAGENT_MAX=2 \
LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
SDLC_ROUTING_FILE="$ROUTING_FILE" \
  bash -c '
    source "$1"
    BASE_PROFILE="codex||||"
    resolve_step_runtime s4-dev
    [[ "$AGENT_RUNTIME" == "local" ]]
    [[ "$LOCAL_AGENT_HOST" == "custom-smoke" ]]
    [[ "$LOCAL_MODEL_PROVIDER" == "openai-compatible" ]]
    [[ "$LOCAL_MODEL" == "org/exact-model" ]]
  ' _ "$ROOT/sdlc.sh" || fail "per-agent route did not apply the exact local profile"

if AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=per-agent \
  SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2 \
  LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" SDLC_ROUTING_FILE="$ROUTING_FILE" \
  bash -c 'source "$1"; BASE_PROFILE="codex||||"; resolve_step_runtime s3-arch' _ "$ROOT/sdlc.sh" \
  >"$TMP_DIR/missing-route.out" 2>&1; then
  fail "per-agent routing silently fell back when route was missing"
fi

if AGENT_RUNTIME=local LOCAL_AGENT_HOST=not-registered \
  LOCAL_MODEL_PROVIDER=openai-compatible LOCAL_MODEL=org/exact-model \
  LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" --mode task --prompt smoke \
  >"$TMP_DIR/unregistered-host.out" 2>&1; then
  fail "local runtime accepted an unregistered agent host"
fi

assert_contains "_contract/GLOBAL.md" "single|per-stage|per-agent|ask"
assert_contains "_contract/GLOBAL.md" "silent fallback"
assert_contains "_runtimes/adapters/local.md" "vLLM"
assert_contains "_runtimes/adapters/local.md" "llama.cpp"

bash "$ROOT/tests/tdd-orchestration-smoke.sh"
bash "$ROOT/tests/cycle23-goal-orchestration-smoke.sh"
bash "$ROOT/tests/launcher-ui-navigation-smoke.sh"
bash "$ROOT/tests/launcher-preview-dispatch-smoke.sh"
bash "$ROOT/tests/launcher-execution-journal-smoke.sh"
bash "$ROOT/tests/local-repositories-ux-smoke.sh"
bash "$ROOT/tests/launcher-advanced-parity-smoke.sh"
bash "$ROOT/tests/launcher-first-run-smoke.sh"
bash "$ROOT/tests/supervisor-worker-subagents-smoke.sh"

echo "PASS: system contract smoke"

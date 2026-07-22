#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-supervisor-worker.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "output does not contain: $2"
}
assert_not_contains() {
  [[ "$1" != *"$2"* ]] || fail "output unexpectedly contains: $2"
}

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_RUNTIME=codex
export CODEX_BIN=/bin/true
export SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=cross-runtime
export SDLC_SUBAGENT_MAX=3
export SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|codex-oss|'
export SDLC_SUBAGENT_TASKS='analysis,research,review,test-interpretation'

source "$ROOT/sdlc.sh"

for fn in normalize_subagent_tasks validate_subagent_profile subagent_profile_label \
  render_subagent_execution_summary render_first_run_ai_routing_choice \
  render_subagent_mode_choice complete_pending_first_run_ai_setup; do
  declare -F "$fn" >/dev/null || fail "missing supervisor/worker function: $fn"
done

routing_choice="$(render_first_run_ai_routing_choice)"
assert_contains "$routing_choice" 'Какая AI-модель будет выполнять основные этапы проекта?'
assert_contains "$routing_choice" 'создаёт итоговые файлы проекта и отвечает за результат этапа'
assert_contains "$routing_choice" 'не меняет состав или порядок SDLC-этапов'
assert_contains "$routing_choice" 'Одна AI-модель для всего проекта'
assert_contains "$routing_choice" 'Своя AI-модель для каждого цикла'
assert_contains "$routing_choice" 'Настроить исключения для отдельных ролей'
assert_contains "$routing_choice" 'Спрашивать при подготовке каждого запуска'
assert_contains "$routing_choice" 'Сейчас ничего не запускается'
assert_contains "$routing_choice" 'Следующий шаг: выберем, нужны ли основному исполнителю помощники.'
subagent_choice="$(render_subagent_mode_choice first-run)"
assert_contains "$subagent_choice" 'Шаг 2 из 2 — AI-помощники'
assert_contains "$subagent_choice" 'Нужны ли основному исполнителю AI-помощники?'
assert_contains "$subagent_choice" 'не изменяет файлы проекта и не закрывает quality gates'
assert_contains "$subagent_choice" 'Основной исполнитель проверяет результат помощника'
assert_contains "$subagent_choice" 'Работать без помощников'
assert_contains "$subagent_choice" 'Помощники той же AI-системы'
assert_contains "$subagent_choice" 'Отдельная AI-модель как помощник'
assert_contains "$subagent_choice" 'Сейчас ничего не запускается'
standalone_subagent_choice="$(render_subagent_mode_choice)"
assert_contains "$standalone_subagent_choice" 'AI-помощники'
assert_not_contains "$standalone_subagent_choice" 'Шаг 2 из 2'

validate_subagent_profile "$SDLC_SUBAGENT_PROFILE" || fail "exact local worker profile rejected"
if validate_subagent_profile 'local|ollama||codex-oss|'; then
  fail "worker profile without exact model accepted"
fi
[[ "$(normalize_subagent_tasks 'review,analysis,review')" == 'analysis,review' ]] ||
  fail "worker task policy was not normalized"

summary="$(render_subagent_execution_summary)"
assert_contains "$summary" 'Supervisor: Codex / external CLI'
assert_contains "$summary" 'Worker: Local / codex-oss / ollama / qwen3:14b'
assert_contains "$summary" 'Verification: supervisor always verifies'
assert_contains "$summary" 'Worker fallback: OFF'

PROJECTS="$TMP_DIR/projects"
PROJECT=Alpha
mkdir -p "$PROJECTS/$PROJECT/tracking"
LAUNCHER_BASE_PROFILE='codex||||'
LAUNCHER_ROUTING_POLICY=single
LAUNCHER_SUBAGENTS=off
LAUNCHER_SUBAGENT_MAX=2
LAUNCHER_SUBAGENT_PROFILE=
LAUNCHER_SUBAGENT_TASKS=
BASE_PROFILE='codex||||'
save_project_ai_config "$BASE_PROFILE" single
SDLC_SUBAGENTS=off
SDLC_SUBAGENT_MAX=2
SDLC_SUBAGENT_PROFILE=
SDLC_SUBAGENT_TASKS=
activate_project_ai_config
[[ "$SDLC_SUBAGENTS" == cross-runtime ]] || fail "project worker mode not restored"
[[ "$SDLC_SUBAGENT_MAX" == 3 ]] || fail "project worker limit not restored"
[[ "$SDLC_SUBAGENT_PROFILE" == 'local|ollama|qwen3:14b|codex-oss|' ]] ||
  fail "project worker profile not restored"

RUN_CYCLE=('s1-pm:/vision')
RUN_OPTIONAL=(0)
preview="$(render_execution_preview CYCLE 'Cycle 1' 'Cycle 2, Cycle 3')"
assert_contains "$preview" 'supervisor=Codex / external CLI'
assert_contains "$preview" 'worker=Local / codex-oss / ollama / qwen3:14b'
assert_contains "$preview" 'verify=supervisor'

FAKE_CODEX="$TMP_DIR/fake-codex"
CODEX_CAPTURE="$TMP_DIR/codex-capture"
cat > "$FAKE_CODEX" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CODEX_CAPTURE"
FAKE
chmod +x "$FAKE_CODEX"

CODEX_CAPTURE="$CODEX_CAPTURE" \
CODEX_BIN="$FAKE_CODEX" \
AGENT_RUNTIME=codex \
SDLC_SUBAGENTS=cross-runtime \
SDLC_SUBAGENT_MAX=3 \
SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|codex-oss|' \
SDLC_SUBAGENT_TASKS='analysis,review' \
SDLC_SUBAGENT_RUNNER=/bin/true \
  "$ROOT/_runtimes/agent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" --mode task --prompt smoke

primary_prompt="$(cat "$CODEX_CAPTURE")"
assert_contains "$primary_prompt" 'SUPERVISOR MODE: cross-runtime'
assert_contains "$primary_prompt" 'sole writer and gate signer'
assert_contains "$primary_prompt" 'SDLC_SUBAGENT_RUNNER: /bin/true'
assert_contains "$primary_prompt" 'must verify every worker finding'
assert_contains "$primary_prompt" 'no silent fallback'

FAKE_HOST="$TMP_DIR/fake-worker-host"
mkdir -p "$TMP_DIR/local-hosts"
cat > "$FAKE_HOST" <<'FAKE'
#!/usr/bin/env bash
printf 'ARG=%s\n' "$@"
printf 'PROVIDER=%s\n' "${LOCAL_MODEL_PROVIDER:-}"
printf 'MODEL=%s\n' "${LOCAL_MODEL:-}"
printf 'SUBAGENTS=%s\n' "${SDLC_SUBAGENTS:-}"
printf 'SECRET=%s\n' "${TOP_SECRET_SENTINEL:-absent}"
FAKE
chmod +x "$FAKE_HOST"
ln -s "$FAKE_HOST" "$TMP_DIR/local-hosts/worker-host"

if TOP_SECRET_SENTINEL='must-not-reach-worker' \
  LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
  SDLC_PROJECTS_DIR="$TMP_DIR/projects" \
  SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|worker-host|' \
  SDLC_SUBAGENT_TASKS='analysis,review' \
  bash "$ROOT/_runtimes/subagent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" --kind analysis \
    --task inspect --read-scope "$TMP_DIR/projects/Alpha" --response-format Markdown \
    > "$TMP_DIR/custom-worker.out" 2>&1; then
  fail 'custom local worker without enforceable read-only capability was accepted'
fi

FAKE_LOCAL_CODEX="$TMP_DIR/fake-local-codex"
cat > "$FAKE_LOCAL_CODEX" <<'FAKE'
#!/usr/bin/env bash
printf 'ARG=%s\n' "$@"
printf 'SECRET=%s\n' "${TOP_SECRET_SENTINEL:-absent}"
FAKE
chmod +x "$FAKE_LOCAL_CODEX"
builtin_output="$(TOP_SECRET_SENTINEL='must-not-reach-worker' \
LOCAL_CODEX_BIN="$FAKE_LOCAL_CODEX" \
LOCAL_HOST_REGISTRY="$ROOT/_runtimes/local-hosts" \
SDLC_PROJECTS_DIR="$TMP_DIR/projects" \
SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|codex-oss|' \
SDLC_SUBAGENT_TASKS='analysis' \
  bash "$ROOT/_runtimes/subagent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" --kind analysis \
    --task inspect --read-scope "$TMP_DIR/projects/Alpha" --response-format Markdown)"
assert_contains "$builtin_output" 'ARG=--sandbox'
assert_contains "$builtin_output" 'ARG=read-only'
assert_contains "$builtin_output" 'ARG=--ephemeral'
assert_contains "$builtin_output" 'SECRET=absent'

FAKE_CLOUD_CODEX="$TMP_DIR/fake-cloud-codex"
cat > "$FAKE_CLOUD_CODEX" <<'FAKE'
#!/usr/bin/env bash
printf 'ARG=%s\n' "$@"
FAKE
chmod +x "$FAKE_CLOUD_CODEX"
cloud_codex_output="$(CODEX_BIN="$FAKE_CLOUD_CODEX" \
  SDLC_PROJECTS_DIR="$TMP_DIR/projects" \
  SDLC_SUBAGENT_PROFILE='codex||||' SDLC_SUBAGENT_TASKS='review' \
  bash "$ROOT/_runtimes/subagent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --kind review --task inspect --read-scope "$TMP_DIR/projects/Alpha" --response-format Markdown)"
assert_contains "$cloud_codex_output" 'ARG=--sandbox'
assert_contains "$cloud_codex_output" 'ARG=read-only'
assert_contains "$cloud_codex_output" 'ARG=--ephemeral'

FAKE_CLAUDE="$TMP_DIR/fake-claude"
cat > "$FAKE_CLAUDE" <<'FAKE'
#!/usr/bin/env bash
printf 'ARG=%s\n' "$@"
FAKE
chmod +x "$FAKE_CLAUDE"
claude_output="$(CLAUDE_BIN="$FAKE_CLAUDE" \
  SDLC_PROJECTS_DIR="$TMP_DIR/projects" \
  SDLC_SUBAGENT_PROFILE='claude||||' SDLC_SUBAGENT_TASKS='analysis' \
  bash "$ROOT/_runtimes/subagent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --kind analysis --task inspect --read-scope "$TMP_DIR/projects/Alpha" --response-format Markdown)"
assert_contains "$claude_output" 'ARG=--tools'
assert_contains "$claude_output" 'ARG=Read,Glob,Grep'
assert_contains "$claude_output" 'ARG=--no-session-persistence'

if CODEX_BIN="$FAKE_CLOUD_CODEX" SDLC_PROJECTS_DIR="$TMP_DIR/projects" \
  SDLC_SUBAGENT_PROFILE='codex||||' SDLC_SUBAGENT_TASKS='analysis' \
  bash "$ROOT/_runtimes/subagent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --kind analysis --task inspect --read-scope / --response-format Markdown \
    > "$TMP_DIR/broad-scope.out" 2>&1; then
  fail 'worker accepted filesystem root as bounded read scope'
fi

if GEMINI_BIN=/bin/true SDLC_PROJECTS_DIR="$TMP_DIR/projects" \
  SDLC_SUBAGENT_PROFILE='gemini||||' SDLC_SUBAGENT_TASKS='analysis' \
  bash "$ROOT/_runtimes/subagent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --kind analysis --task inspect --read-scope "$TMP_DIR/projects/Alpha" --response-format Markdown \
    > "$TMP_DIR/gemini-worker.out" 2>&1; then
  fail 'Gemini worker was accepted without an enforceable read-only adapter'
fi

if LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
  SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|worker-host|' \
  SDLC_SUBAGENT_TASKS='analysis,review' \
  bash "$ROOT/_runtimes/subagent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" --kind deploy \
    --task forbidden --read-scope "$TMP_DIR" --response-format text \
    >"$TMP_DIR/forbidden.out" 2>&1; then
  fail "worker runner accepted a forbidden task kind"
fi

XDG_CONFIG_HOME="$TMP_DIR/localrun-config" \
AGENT_RUNTIME=codex CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING=single \
SDLC_SUBAGENTS=cross-runtime SDLC_SUBAGENT_MAX=2 \
SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|worker-host|' \
SDLC_SUBAGENT_TASKS='analysis,review' \
  bash -c '
    set -euo pipefail
    source "$1"
    declare -F validate_subagent_profile >/dev/null
    ensure_subagent_settings
  ' _ "$ROOT/localrun.sh" && fail 'Local Repositories accepted a custom local worker without enforceable read-only capability'

XDG_CONFIG_HOME="$TMP_DIR/localrun-config-ok" \
AGENT_RUNTIME=codex CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING=single \
SDLC_SUBAGENTS=cross-runtime SDLC_SUBAGENT_MAX=2 \
SDLC_SUBAGENT_PROFILE='local|ollama|qwen3:14b|codex-oss|' \
SDLC_SUBAGENT_TASKS='analysis,review' \
  bash -c '
    set -euo pipefail
    source "$1"
    ensure_subagent_settings
  ' _ "$ROOT/localrun.sh" || fail 'Local Repositories rejected capability-enforced codex-oss worker settings'

echo 'PASS: supervisor/worker subagents smoke'

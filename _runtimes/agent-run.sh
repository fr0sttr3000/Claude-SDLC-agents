#!/usr/bin/env bash
# Universal SDLC agent runtime dispatcher.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
RUNTIME="${AGENT_RUNTIME:-}"
MODE="task"
ACCESS="write"
AGENT_DIR_VALUE=""
PROMPT=""
LOCAL_HOST_REGISTRY="${LOCAL_HOST_REGISTRY:-$SCRIPT_DIR/local-hosts}"
LOCAL_HOST_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      RUNTIME="${2:-}"
      shift 2
      ;;
    --agent-dir)
      AGENT_DIR_VALUE="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --access)
      ACCESS="${2:-}"
      shift 2
      ;;
    --prompt)
      PROMPT="${2:-}"
      shift 2
      ;;
    --)
      shift
      PROMPT="${*:-$PROMPT}"
      break
      ;;
    *)
      PROMPT="${PROMPT}${PROMPT:+ }$1"
      shift
      ;;
  esac
done

if [[ -z "$AGENT_DIR_VALUE" || ! -d "$AGENT_DIR_VALUE" ]]; then
  echo "agent-run.sh: --agent-dir is required and must point to an existing directory" >&2
  exit 2
fi

AGENT_DIR_VALUE="$(cd "$AGENT_DIR_VALUE" && pwd -P)"

normalize_runtime() {
  local runtime="${1:-}"
  if [[ -z "$runtime" ]]; then
    echo "agent-run.sh: runtime is required (expected: claude, codex, gemini, local)" >&2
    exit 2
  fi
  runtime="${runtime,,}"
  case "$runtime" in
    claude|codex|gemini|local)
      echo "$runtime"
      ;;
    *)
      echo "agent-run.sh: unknown runtime '$1' (expected: claude, codex, gemini, local)" >&2
      exit 2
      ;;
  esac
}

runtime_bin() {
  case "$RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
    local) echo "$LOCAL_HOST_PATH" ;;
  esac
}

validate_scalar() {
  local name="$1" value="${2:-}"
  if [[ -z "$value" || "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    echo "agent-run.sh: $name must be an explicit single-line value" >&2
    exit 2
  fi
}

resolve_local_host() {
  local host="${LOCAL_AGENT_HOST:-}" candidate
  validate_scalar LOCAL_AGENT_HOST "$host"
  validate_scalar LOCAL_MODEL_PROVIDER "${LOCAL_MODEL_PROVIDER:-}"
  validate_scalar LOCAL_MODEL "${LOCAL_MODEL:-}"
  if [[ ! "$host" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "agent-run.sh: invalid LOCAL_AGENT_HOST id '$host'" >&2
    exit 2
  fi
  candidate="$LOCAL_HOST_REGISTRY/$host"
  if [[ ! -f "$candidate" || ! -x "$candidate" ]]; then
    echo "agent-run.sh: local agent host '$host' is not registered and executable in $LOCAL_HOST_REGISTRY" >&2
    exit 127
  fi
  LOCAL_HOST_PATH="$candidate"
}

ensure_runtime_available() {
  local bin
  if [[ "$RUNTIME" == "local" ]]; then
    resolve_local_host
    return 0
  fi
  bin="$(runtime_bin)"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "agent-run.sh: runtime '$RUNTIME' requires command '$bin', but it was not found in PATH" >&2
    echo "agent-run.sh: select another explicit runtime or override ${RUNTIME^^}_BIN" >&2
    exit 127
  fi
}

RUNTIME="$(normalize_runtime "$RUNTIME")"
case "$ACCESS" in
  write|read-only) ;;
  *) echo "agent-run.sh: --access must be write or read-only" >&2; exit 2 ;;
esac
if [[ "$ACCESS" == read-only && "$MODE" != task ]]; then
  echo 'agent-run.sh: read-only access supports task mode only' >&2
  exit 2
fi

configure_subagents() {
  local policy="${SDLC_SUBAGENTS:-off}" max="${SDLC_SUBAGENT_MAX:-2}"
  policy="${policy,,}"
  case "$policy" in
    off|auto|cross-runtime) ;;
    *)
      echo "agent-run.sh: SDLC_SUBAGENTS must be off, auto or cross-runtime" >&2
      exit 2
      ;;
  esac
  if [[ ! "$max" =~ ^[1-9][0-9]*$ ]] || (( 10#$max < 1 || 10#$max > 16 )); then
    echo "agent-run.sh: SDLC_SUBAGENT_MAX must be an integer from 1 to 16" >&2
    exit 2
  fi
  SDLC_SUBAGENTS="$policy"
  SDLC_SUBAGENT_MAX="$max"
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX
  if [[ "$policy" == "cross-runtime" ]]; then
    local profile="${SDLC_SUBAGENT_PROFILE:-}" tasks="${SDLC_SUBAGENT_TASKS:-}"
    local runner="${SDLC_SUBAGENT_RUNNER:-$SCRIPT_DIR/subagent-run.sh}"
    local worker_runtime provider model host endpoint extra item
    validate_scalar SDLC_SUBAGENT_PROFILE "$profile"
    validate_scalar SDLC_SUBAGENT_TASKS "$tasks"
    IFS='|' read -r worker_runtime provider model host endpoint extra <<< "$profile"
    [[ -z "$extra" ]] || { echo 'agent-run.sh: invalid SDLC_SUBAGENT_PROFILE' >&2; exit 2; }
    case "$worker_runtime" in
      claude|codex)
        [[ -z "$provider$model$host$endpoint" ]] || {
          echo 'agent-run.sh: cloud worker profile has unexpected local fields' >&2
          exit 2
        }
        ;;
      local)
        validate_scalar worker_provider "$provider"
        validate_scalar worker_model "$model"
        validate_scalar worker_host "$host"
        [[ "$host" == codex-oss ]] || {
          echo "agent-run.sh: local worker host '$host' has no registered read-only capability" >&2
          exit 2
        }
        ;;
      gemini)
        echo 'agent-run.sh: Gemini worker has no capability-enforced read-only adapter' >&2
        exit 2
        ;;
      *) echo 'agent-run.sh: invalid worker runtime in SDLC_SUBAGENT_PROFILE' >&2; exit 2 ;;
    esac
    IFS=',' read -r -a worker_task_items <<< "$tasks"
    for item in "${worker_task_items[@]}"; do
      case "$item" in analysis|research|review|test-interpretation) ;; *)
        echo "agent-run.sh: forbidden worker task kind '$item'" >&2
        exit 2
      esac
    done
    [[ -x "$runner" ]] || {
      echo "agent-run.sh: cross-runtime worker runner is not executable: $runner" >&2
      exit 127
    }
    SDLC_SUBAGENT_RUNNER="$runner"
    export SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS SDLC_SUBAGENT_RUNNER
    PROMPT="${PROMPT}${PROMPT:+$'\n\n'}SUPERVISOR MODE: cross-runtime
You are the primary stage agent, sole writer and gate signer.
Worker profile: $profile
Allowed worker task kinds: $tasks
Worker concurrency limit: $max
SDLC_SUBAGENT_RUNNER: $runner
Delegate only bounded read-only work by invoking the runner with --agent-dir, --kind, --task, --read-scope and --response-format. You must verify every worker finding against canonical files before using it. Worker output is advisory and cannot sign a gate or become evidence by itself. If a worker fails, report BLOCKED or retry explicitly; no silent fallback, no nested delegation and no worker writes."
    return
  fi
  PROMPT="${PROMPT}${PROMPT:+$'\n\n'}SUBAGENT MODE: $policy
SUBAGENT MAX: $max
Read $SCRIPT_DIR/../_contract/SUBAGENTS.md. The primary stage agent remains the sole writer and gate signer. Subagents, when enabled and supported, are bounded read-only workers. If mode is auto but this host cannot provide subagents, report that explicitly; do not ignore it and do not switch runtime or model."
}

configure_subagents
ensure_runtime_available

run_claude() {
  local bin="${CLAUDE_BIN:-claude}"
  case "$MODE" in
    task)
      if [[ "$ACCESS" == read-only ]]; then
        AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
          "$bin" --print --permission-mode dontAsk --tools Read,Glob,Grep \
          --no-session-persistence "$PROMPT"
      else
        AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
          "$bin" --print --no-session-persistence "$PROMPT"
      fi
      ;;
    session-start)
      AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT "$bin" "$PROMPT"
      ;;
    interactive)
      if [[ -n "$PROMPT" ]]; then
        AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT "$bin" "$PROMPT"
        AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT "$bin" --continue
      else
        AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT "$bin"
      fi
      ;;
    continue)
      AGENT_DIR="$AGENT_DIR_VALUE" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT "$bin" --continue
      ;;
    *)
      echo "agent-run.sh: unsupported mode for claude: $MODE" >&2
      exit 2
      ;;
  esac
}

run_codex() {
  local bin="${CODEX_BIN:-codex}"
  case "$MODE" in
    task)
      if [[ "$ACCESS" == read-only ]]; then
        AGENT_DIR="$AGENT_DIR_VALUE" "$bin" exec --sandbox read-only --ephemeral \
          --cd "$AGENT_DIR_VALUE" "$PROMPT"
      else
        AGENT_DIR="$AGENT_DIR_VALUE" "$bin" exec --cd "$AGENT_DIR_VALUE" "$PROMPT"
      fi
      ;;
    session-start|interactive)
      if [[ -n "$PROMPT" ]]; then
        AGENT_DIR="$AGENT_DIR_VALUE" "$bin" --cd "$AGENT_DIR_VALUE" "$PROMPT"
      else
        AGENT_DIR="$AGENT_DIR_VALUE" "$bin" --cd "$AGENT_DIR_VALUE"
      fi
      ;;
    continue)
      AGENT_DIR="$AGENT_DIR_VALUE" "$bin" --cd "$AGENT_DIR_VALUE"
      ;;
    *)
      echo "agent-run.sh: unsupported mode for codex: $MODE" >&2
      exit 2
      ;;
  esac
}

run_gemini() {
  local bin="${GEMINI_BIN:-gemini}"
  if [[ "$ACCESS" == read-only ]]; then
    echo 'agent-run.sh: Gemini read-only worker adapter is not capability-enforced; refusing execution' >&2
    exit 2
  fi
  case "$MODE" in
    task|session-start)
      AGENT_DIR="$AGENT_DIR_VALUE" "$bin" -p "$PROMPT"
      ;;
    interactive)
      if [[ -n "$PROMPT" ]]; then
        AGENT_DIR="$AGENT_DIR_VALUE" "$bin" -p "$PROMPT"
      else
        AGENT_DIR="$AGENT_DIR_VALUE" "$bin"
      fi
      ;;
    continue)
      AGENT_DIR="$AGENT_DIR_VALUE" "$bin"
      ;;
    *)
      echo "agent-run.sh: unsupported mode for gemini: $MODE" >&2
      exit 2
      ;;
  esac
}

run_local() {
  if [[ "$ACCESS" == read-only && "${LOCAL_AGENT_HOST:-}" != codex-oss ]]; then
    echo "agent-run.sh: local host '${LOCAL_AGENT_HOST:-}' has no registered read-only capability" >&2
    exit 2
  fi
  AGENT_DIR="$AGENT_DIR_VALUE" "$LOCAL_HOST_PATH" \
    --agent-dir "$AGENT_DIR_VALUE" \
    --mode "$MODE" \
    --access "$ACCESS" \
    --prompt "$PROMPT"
}

cd "$AGENT_DIR_VALUE"

case "$RUNTIME" in
  claude)
    run_claude
    ;;
  codex)
    run_codex
    ;;
  gemini)
    run_gemini
    ;;
  local)
    run_local
    ;;
esac

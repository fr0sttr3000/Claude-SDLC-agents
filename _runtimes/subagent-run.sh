#!/usr/bin/env bash
# Universal bounded read-only worker dispatcher for Supervisor + Worker mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AGENT_RUNNER="$SCRIPT_DIR/agent-run.sh"
PROFILE="${SDLC_SUBAGENT_PROFILE:-}"
TASKS="${SDLC_SUBAGENT_TASKS:-}"
AGENT_DIR_VALUE=""
KIND=""
TASK=""
READ_SCOPE=""
RESPONSE_FORMAT=""

fail() {
  echo "subagent-run.sh: $*" >&2
  exit 2
}

validate_scalar() {
  local name="$1" value="${2:-}"
  [[ -n "$value" && "$value" != *$'\n'* && "$value" != *$'\r'* ]] ||
    fail "$name must be an explicit single-line value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-dir) AGENT_DIR_VALUE="${2:-}"; shift 2 ;;
    --kind) KIND="${2:-}"; shift 2 ;;
    --task) TASK="${2:-}"; shift 2 ;;
    --read-scope) READ_SCOPE="${2:-}"; shift 2 ;;
    --response-format) RESPONSE_FORMAT="${2:-}"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -d "$AGENT_DIR_VALUE" ]] || fail '--agent-dir must point to an existing agent directory'
AGENT_DIR_VALUE="$(cd "$AGENT_DIR_VALUE" && pwd -P)"
validate_scalar kind "$KIND"
validate_scalar task "$TASK"
validate_scalar read_scope "$READ_SCOPE"
validate_scalar response_format "$RESPONSE_FORMAT"
[[ "$READ_SCOPE" == /* ]] || fail '--read-scope must be an explicit absolute path'
[[ -e "$READ_SCOPE" ]] || fail '--read-scope must exist'
READ_SCOPE="$(cd "$READ_SCOPE" 2>/dev/null && pwd -P)" || fail '--read-scope must resolve to a directory'
[[ "$READ_SCOPE" != / && "$READ_SCOPE" != "${HOME:-}" ]] ||
  fail '--read-scope must be a bounded project path, not filesystem root or HOME'

projects_root="${SDLC_PROJECTS_DIR:-${LOCALRUN_PROJECTS:-}}"
validate_scalar projects_root "$projects_root"
[[ -d "$projects_root" ]] || fail 'configured project root does not exist'
projects_root="$(cd "$projects_root" && pwd -P)"
case "$READ_SCOPE/" in
  "$projects_root"/*/) ;;
  *) fail '--read-scope must be inside the configured project root' ;;
esac

case "$KIND" in analysis|research|review|test-interpretation) ;; *)
  fail "forbidden worker task kind: $KIND"
esac
case ",$TASKS," in
  *",$KIND,"*) ;;
  *) fail "worker task kind '$KIND' is not allowed by SDLC_SUBAGENT_TASKS" ;;
esac

validate_scalar SDLC_SUBAGENT_PROFILE "$PROFILE"
local_runtime="" provider="" model="" host="" endpoint="" extra=""
IFS='|' read -r local_runtime provider model host endpoint extra <<< "$PROFILE"
[[ -z "$extra" ]] || fail 'invalid SDLC_SUBAGENT_PROFILE'
case "$local_runtime" in
  claude|codex)
    [[ -z "$provider$model$host$endpoint" ]] || fail 'cloud worker profile has unexpected local fields'
    ;;
  local)
    validate_scalar worker_provider "$provider"
    validate_scalar worker_model "$model"
    validate_scalar worker_host "$host"
    [[ "$host" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'invalid local worker host id'
    [[ "$host" == codex-oss ]] ||
      fail "local worker host '$host' has no registered read-only capability"
    ;;
  gemini) fail 'Gemini worker has no capability-enforced read-only adapter' ;;
  *) fail 'worker runtime must be claude, codex or local codex-oss' ;;
esac

worker_prompt="CROSS-RUNTIME READ-ONLY WORKER
TASK KIND: $KIND
TASK: $TASK
ALLOWED READ SCOPE: $READ_SCOPE
RESPONSE FORMAT: $RESPONSE_FORMAT

Read the applicable canonical agent instructions and _contract/SUBAGENTS.md. Do not edit files, run write-capable commands, deploy, approve gates, access secrets, start nested subagents or read outside the allowed scope. Return findings only to the supervisor. Clearly separate observed evidence from inference and include file references."

env -i \
  HOME="${HOME:-}" \
  PATH="${PATH:-/usr/bin:/bin}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-}" \
  CODEX_HOME="${CODEX_HOME:-}" \
  TMPDIR="${TMPDIR:-/tmp}" \
  LANG="${LANG:-C.UTF-8}" \
  LC_ALL="${LC_ALL:-}" \
  TERM="${TERM:-dumb}" \
  SDLC_VAULT="${SDLC_VAULT:-}" \
  SDLC_PROJECTS_DIR="${SDLC_PROJECTS_DIR:-}" \
  LOCALRUN_PROJECTS="${LOCALRUN_PROJECTS:-}" \
  SDLC_PROJECTS_MODE="${SDLC_PROJECTS_MODE:-}" \
  SDLC_SINGLE_PROJECT="${SDLC_SINGLE_PROJECT:-}" \
  LOCAL_HOST_REGISTRY="${LOCAL_HOST_REGISTRY:-$SCRIPT_DIR/local-hosts}" \
  CLAUDE_BIN="${CLAUDE_BIN:-claude}" \
  CODEX_BIN="${CODEX_BIN:-codex}" \
  GEMINI_BIN="${GEMINI_BIN:-gemini}" \
  LOCAL_CODEX_BIN="${LOCAL_CODEX_BIN:-codex}" \
  AGENT_RUNTIME="$local_runtime" \
  LOCAL_AGENT_HOST="$host" \
  LOCAL_MODEL_PROVIDER="$provider" \
  LOCAL_MODEL="$model" \
  LOCAL_MODEL_ENDPOINT="$endpoint" \
  SDLC_SUBAGENTS=off \
  SDLC_SUBAGENT_MAX=1 \
  SDLC_WORKER=1 \
  "$AGENT_RUNNER" --runtime "$local_runtime" --agent-dir "$AGENT_DIR_VALUE" \
    --mode task --access read-only --prompt "$worker_prompt"

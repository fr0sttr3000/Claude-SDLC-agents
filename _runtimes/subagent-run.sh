#!/usr/bin/env bash
# Universal bounded read-only worker dispatcher for Supervisor + Worker mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/runtime-boundary.sh"
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

AGENT_DIR_VALUE="$(resolve_active_agent_dir "$AGENT_DIR_VALUE")" || exit 2
fail 'BLOCKED: worker execution is disabled until a capability-enforced bounded read scope exists'

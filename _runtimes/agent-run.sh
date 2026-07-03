#!/usr/bin/env bash
# Universal SDLC agent runtime dispatcher.

set -euo pipefail

RUNTIME="${AGENT_RUNTIME:-}"
MODE="task"
AGENT_DIR_VALUE=""
PROMPT=""

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
    echo "agent-run.sh: runtime is required (expected: claude, codex, gemini)" >&2
    exit 2
  fi
  runtime="${runtime,,}"
  case "$runtime" in
    claude|codex|gemini)
      echo "$runtime"
      ;;
    gemeni|gqmeni)
      echo "gemini"
      ;;
    *)
      echo "agent-run.sh: unknown runtime '$1' (expected: claude, codex, gemini)" >&2
      exit 2
      ;;
  esac
}

runtime_bin() {
  case "$RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
  esac
}

ensure_runtime_available() {
  local bin
  bin="$(runtime_bin)"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "agent-run.sh: runtime '$RUNTIME' requires command '$bin', but it was not found in PATH" >&2
    echo "agent-run.sh: set AGENT_RUNTIME=claude|codex|gemini or override ${RUNTIME^^}_BIN" >&2
    exit 127
  fi
}

RUNTIME="$(normalize_runtime "$RUNTIME")"
ensure_runtime_available

run_claude() {
  local bin="${CLAUDE_BIN:-claude}"
  case "$MODE" in
    task|session-start)
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
      AGENT_DIR="$AGENT_DIR_VALUE" "$bin" exec --cd "$AGENT_DIR_VALUE" "$PROMPT"
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
esac

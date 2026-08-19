#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUNNER="$ROOT/_runtimes/agent-run.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-codex-app-compat.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$file" || fail "$file does not contain: $text"
}
assert_arg_pair() {
  local file="$1" flag="$2" value="$3"
  awk -v first="ARG=$flag" -v second="ARG=$value" '
    previous == first && $0 == second { found = 1 }
    { previous = $0 }
    END { exit(found ? 0 : 1) }
  ' "$file" || fail "missing adjacent arguments: $flag $value"
}

GUIDE="$ROOT/README.md"
ADAPTER="$ROOT/_runtimes/adapters/codex.md"
for url in \
  'https://learn.chatgpt.com/docs/app' \
  'https://learn.chatgpt.com/docs/integrated-terminal' \
  'https://learn.chatgpt.com/docs/environments/modes' \
  'https://learn.chatgpt.com/docs/environments/git-worktrees' \
  'https://learn.chatgpt.com/docs/agent-configuration/agents-md' \
  'https://learn.chatgpt.com/docs/windows/windows-app'; do
  assert_contains "$GUIDE" "$url"
done
assert_contains "$GUIDE" '## Fast Start'
assert_contains "$GUIDE" 'AGENT_RUNTIME=codex SDLC_SUBAGENTS=off bash sdlc.sh'
assert_contains "$GUIDE" 'Полный live Project E2E'
assert_contains "$GUIDE" 'SDLC_PROJECTS_DIR="/path/with spaces/Projects"'
assert_contains "$GUIDE" "./sdlc.ps1"
assert_contains "$GUIDE" 'danger-full-access'
assert_contains "$ADAPTER" 'tests/codex-app-launcher-compat-smoke.sh'
assert_contains "$ADAPTER" 'LIVE EXECUTION REQUIRED'
assert_contains "$ADAPTER" 'full live Project E2E remains experimental'

PROJECT="$TMP_DIR/Projects With Spaces/Demo Project"
NOTES="$TMP_DIR/Notes With Spaces/Demo Project"
mkdir -p "$PROJECT/.test-bin" "$NOTES"

FAKE_CODEX="$PROJECT/.test-bin/fake-codex"
cat > "$FAKE_CODEX" <<'FAKE'
#!/usr/bin/env bash
printf 'ARG=%s\n' "$@"
printf 'THREAD=%s\n' "${CODEX_THREAD_ID:-absent}"
FAKE
chmod +x "$FAKE_CODEX"
CAPTURE="$TMP_DIR/fake-codex.capture"

CODEX_THREAD_ID=outer-app-chat-must-not-propagate \
AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --project-dir "$PROJECT" \
    --mode task --access write --prompt 'compatibility smoke' > "$CAPTURE"

assert_contains "$CAPTURE" 'ARG=exec'
assert_contains "$CAPTURE" 'ARG=--ignore-user-config'
assert_arg_pair "$CAPTURE" '--sandbox' 'workspace-write'
assert_arg_pair "$CAPTURE" '--cd' "$PROJECT"
assert_contains "$CAPTURE" 'ARG=--ephemeral'
assert_contains "$CAPTURE" 'THREAD=absent'
if grep -Fq 'ARG=--add-dir' "$CAPTURE"; then
  fail 'SDLC task unexpectedly received a notes scope'
fi

AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" \
    --agent-dir "$ROOT/cycle1-dev/l1-analyze" \
    --project-dir "$PROJECT" --notes-dir "$NOTES" \
    --mode task --access write --prompt 'local notes compatibility smoke' > "$CAPTURE"

assert_arg_pair "$CAPTURE" '--cd' "$PROJECT"
assert_arg_pair "$CAPTURE" '--add-dir' "$NOTES"
assert_contains "$CAPTURE" 'ARG=--ephemeral'

AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" \
    --agent-dir "$ROOT/cycle1-dev/s0-validate" \
    --project-dir "$PROJECT" \
    --mode task --access read-only --prompt 'review compatibility smoke' > "$CAPTURE"

assert_arg_pair "$CAPTURE" '--sandbox' 'read-only'
assert_arg_pair "$CAPTURE" '--cd' "$PROJECT"
assert_contains "$CAPTURE" 'ARG=--ephemeral'

rm -f "$CAPTURE"
if AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --project-dir "$PROJECT" \
    --mode interactive --access write --prompt 'unsafe interactive compatibility smoke' \
    >"$TMP_DIR/interactive.out" 2>&1; then
  fail 'nested interactive Codex was accepted'
fi
assert_contains "$TMP_DIR/interactive.out" \
  'BLOCKED: interactive Codex cannot disable ambient user configuration'
[[ ! -e "$CAPTURE" ]] || fail 'blocked interactive Codex invoked the runtime'

bash "$ROOT/tests/launcher-first-run-smoke.sh" >/dev/null
bash "$ROOT/tests/windows-launcher-adapter-smoke.sh" >/dev/null

echo 'PASS: Codex App launcher compatibility smoke'

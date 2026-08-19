#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-secret-boundary.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/project"
FAKE_RUNTIME="$TMP_DIR/fake-codex"
MARKER='stage8-secret-marker-value'

fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$PROJECT"

cat > "$FAKE_RUNTIME" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${0}.capture"
FAKE
chmod +x "$FAKE_RUNTIME"

if AGENT_RUNTIME=codex CODEX_BIN="$FAKE_RUNTIME" SDLC_SUBAGENTS=off \
  "$ROOT/_runtimes/agent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --project-dir "$PROJECT" \
    --mode task \
    --prompt "inspect token=$MARKER" \
    > "$TMP_DIR/dispatch.out" 2>&1; then
  fail 'runtime accepted a secret-like prompt'
fi
[[ ! -e "$FAKE_RUNTIME.capture" ]] || fail 'secret-like prompt reached runtime argv'
if grep -Fq "$MARKER" "$TMP_DIR/dispatch.out"; then
  fail 'secret-like value leaked into dispatcher output'
fi
grep -Fq 'use a pass reference instead' "$TMP_DIR/dispatch.out" ||
  fail 'secret-like prompt rejection did not provide safe remediation'

source "$ROOT/_runtimes/runtime-boundary.sh"
if runtime_validate_prompt "api_key=$MARKER" > "$TMP_DIR/shared.out" 2>&1; then
  fail 'shared runtime boundary accepted a secret-like value'
fi
if grep -Fq "$MARKER" "$TMP_DIR/shared.out"; then
  fail 'shared runtime boundary printed the rejected secret-like value'
fi
runtime_validate_prompt 'Проверь управление API keys через pass' >/dev/null ||
  fail 'safe secret-management instruction was rejected'

for launcher in sdlc.sh localrun.sh; do
  guard_line="$(grep -nF 'runtime_validate_prompt "$prompt"' "$ROOT/$launcher" | head -1 | cut -d: -f1)"
  output_line="$(grep -nF 'Prompt:' "$ROOT/$launcher" | head -1 | cut -d: -f1)"
  [[ -n "$guard_line" && -n "$output_line" && "$guard_line" -lt "$output_line" ]] ||
    fail "$launcher does not reject secret-like prompt before terminal output"
done

mkdir -p "$PROJECT/tracking"
cat > "$PROJECT/Dashboard.md" <<'DASHBOARD'
# Dashboard
DASHBOARD
cat > "$PROJECT/tracking/unsafe.md" <<UNSAFE
---
schema_version: 1
artifact_id: UNSAFE-SECRET-CHECK
artifact_type: security-review
project: project
stage: TRACKING
producer: s0-validate
source_revision: none
status: UNVERIFIED
inputs: none
outputs: tracking/unsafe.md
tags: sdlc,cycle1,tracking
---
# Unsafe

token=$MARKER

## Obsidian Links

- Dashboard: [[Dashboard]]
- Outputs: [[tracking/unsafe]]
UNSAFE
if bash "$ROOT/cycle1-dev/s0-validate/artifact-metadata-check.sh" \
  "$PROJECT" tracking/unsafe.md > "$TMP_DIR/markdown.out" 2>&1; then
  fail 'Artifact Metadata validator accepted secret-like Markdown'
fi
if grep -Fq "$MARKER" "$TMP_DIR/markdown.out"; then
  fail 'Markdown validator printed the secret-like value'
fi
grep -Fq 'secret-like' "$TMP_DIR/markdown.out" ||
  fail 'Markdown validator did not explain the safe rejection class'

echo 'PASS: secret boundary smoke'

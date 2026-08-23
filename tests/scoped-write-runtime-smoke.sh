#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUNNER="$ROOT/_runtimes/agent-run.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-scoped-write-runtime.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

PROJECT="$TMP_DIR/projects/Alpha"
mkdir -p "$PROJECT/src/allowed-create" "$PROJECT/src/protected" "$TMP_DIR/home"
printf '%s\n' old > "$PROJECT/src/allowed.py"
printf '%s\n' protected > "$PROJECT/src/protected/locked.py"
printf '%s\n' unrelated > "$PROJECT/src/unrelated.py"

SCOPE_FILE="$TMP_DIR/runtime-scope.tsv"
printf '%s\n' $'schema_version\tcapability\tpath' \
  $'1\twrite\tsrc/allowed.py' \
  $'1\twrite\tsrc/allowed-create' \
  $'1\tdeny\tsrc/protected' > "$SCOPE_FILE"
SCOPE_SHA="$(sha256sum "$SCOPE_FILE" | awk '{print $1}')"

FAKE_RUNTIME="$TMP_DIR/fake-codex"
cat > "$FAKE_RUNTIME" <<'RUNTIME'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' changed > "$SDLC_PROJECT_DIR/src/allowed.py"
printf '%s\n' created > "$SDLC_PROJECT_DIR/src/allowed-create/new.py"
if printf '%s\n' bad > "$SDLC_PROJECT_DIR/src/protected/locked.py" 2>/dev/null; then exit 20; fi
if printf '%s\n' bad > "$SDLC_PROJECT_DIR/src/unrelated.py" 2>/dev/null; then exit 21; fi
if printf '%s\n' bad > "$SDLC_PROJECT_DIR/src/new-unapproved.py" 2>/dev/null; then exit 22; fi
printf '%s\n' SCOPED_WRITE_RUNTIME_PASS
RUNTIME
chmod +x "$FAKE_RUNTIME"

OUTPUT="$TMP_DIR/run.out"
env HOME="$TMP_DIR/home" AGENT_RUNTIME=codex CODEX_BIN="$FAKE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" \
  --agent-dir "$ROOT/cycle1-dev/s4-dev" --project-dir "$PROJECT" \
  --mode task --access scoped-write --scope-file "$SCOPE_FILE" \
  --scope-sha256 "$SCOPE_SHA" --prompt scoped-write-probe > "$OUTPUT" 2>&1 || {
    cat "$OUTPUT" >&2
    fail 'valid scoped-write run was rejected'
  }
grep -Fq SCOPED_WRITE_RUNTIME_PASS "$OUTPUT" || fail 'scoped runtime did not execute'
[[ "$(sed -n '1p' "$PROJECT/src/allowed.py")" == changed ]] || fail 'exact allowed file was not writable'
[[ "$(sed -n '1p' "$PROJECT/src/allowed-create/new.py")" == created ]] || fail 'allowed create directory was not writable'
[[ "$(sed -n '1p' "$PROJECT/src/protected/locked.py")" == protected ]] || fail 'protected path changed'
[[ "$(sed -n '1p' "$PROJECT/src/unrelated.py")" == unrelated ]] || fail 'unrelated path changed'
[[ ! -e "$PROJECT/src/new-unapproved.py" ]] || fail 'unapproved new file was created'

if env HOME="$TMP_DIR/home" AGENT_RUNTIME=codex CODEX_BIN="$FAKE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" --agent-dir "$ROOT/cycle1-dev/s4-dev" \
  --project-dir "$PROJECT" --mode task --access scoped-write \
  --scope-file "$SCOPE_FILE" --scope-sha256 "${SCOPE_SHA%?}0" \
  --prompt tampered-scope > "$TMP_DIR/tampered.out" 2>&1; then
  fail 'tampered runtime scope digest was accepted'
fi
grep -Fq 'scope digest mismatch' "$TMP_DIR/tampered.out" || fail 'tampered scope reason is unclear'

printf '%s\n' $'schema_version\tcapability\tpath' $'1\twrite\t../escape' > "$TMP_DIR/traversal.tsv"
TRAVERSAL_SHA="$(sha256sum "$TMP_DIR/traversal.tsv" | awk '{print $1}')"
if env HOME="$TMP_DIR/home" AGENT_RUNTIME=codex CODEX_BIN="$FAKE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" --agent-dir "$ROOT/cycle1-dev/s4-dev" \
  --project-dir "$PROJECT" --mode task --access scoped-write \
  --scope-file "$TMP_DIR/traversal.tsv" --scope-sha256 "$TRAVERSAL_SHA" \
  --prompt traversal-scope > "$TMP_DIR/traversal.out" 2>&1; then
  fail 'runtime scope traversal was accepted'
fi

echo 'PASS: scoped-write runtime smoke'

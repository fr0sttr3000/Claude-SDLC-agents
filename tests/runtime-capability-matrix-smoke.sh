#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BOUNDARY="$ROOT/_runtimes/runtime-boundary.sh"
RUNNER="$ROOT/_runtimes/agent-run.sh"
MATRIX="$ROOT/_contract/runtime-access-v1.tsv"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-runtime-capabilities.XXXXXX")"
ROOT_MARKER="$ROOT/.runtime-capability-negative-probe"
cleanup() {
  rm -f -- "$ROOT_MARKER"
  rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ "$(head -n 1 "$MATRIX")" == $'schema_version\taccess\tscope\tread\twrite' ]] ||
  fail 'invalid Runtime Access v1 header'
grep -Fqx $'1\twrite\tpublic-canon\tallow\tdeny' "$MATRIX" ||
  fail 'write mode does not keep public canon read-only'
grep -Fqx $'1\twrite\texact-project\tallow\tallow' "$MATRIX" ||
  fail 'write mode does not declare exact Project write access'
grep -Fqx $'1\tread-only\texact-project\tallow\tdeny' "$MATRIX" ||
  fail 'read-only mode does not deny exact Project writes'
grep -Fqx $'1\twrite\tambient-home\tdeny\tdeny' "$MATRIX" ||
  fail 'ambient HOME is not denied'
grep -Fqx $'1\twrite\tsibling-project\tdeny\tdeny' "$MATRIX" ||
  fail 'sibling Project is not denied'

source "$BOUNDARY"
runtime_prepare_cycle_sandbox >/dev/null || fail 'cannot prepare Landlock helper'
SANDBOX_BIN="$RUNTIME_LANDLOCK_BIN"
[[ -x "$SANDBOX_BIN" ]] || fail 'Landlock helper is not executable'

PUBLIC="$TMP_DIR/public-canon"
DENIED="$PUBLIC/denied"
PROJECT="$TMP_DIR/projects/Alpha"
SIBLING="$TMP_DIR/projects/Beta"
NOTES="$TMP_DIR/notes/Alpha"
AMBIENT_HOME="$TMP_DIR/ambient-home"
mkdir -p "$DENIED" "$PROJECT" "$SIBLING" "$NOTES" "$AMBIENT_HOME"
printf 'canon\n' >"$PUBLIC/rule.md"
printf 'denied\n' >"$DENIED/private.txt"
printf 'project\n' >"$PROJECT/input.txt"
printf 'sibling\n' >"$SIBLING/input.txt"
printf 'home\n' >"$AMBIENT_HOME/input.txt"
ln -s "$AMBIENT_HOME/input.txt" "$PROJECT/home-link"
ln -s "$AMBIENT_HOME/input.txt" "$PUBLIC/home-link"

WRITE_PROBE="$TMP_DIR/write-probe.sh"
cat >"$WRITE_PROBE" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail

[[ "$(cat "$PUBLIC/rule.md")" == canon ]]
[[ "$(cat "$PROJECT/input.txt")" == project ]]
printf 'ok\n' >"$PROJECT/result.txt"
printf 'ok\n' >"$NOTES/result.txt"

if printf 'bad\n' >"$PUBLIC/changed.md" 2>/dev/null; then exit 10; fi
if cat "$DENIED/private.txt" >/dev/null 2>&1; then exit 11; fi
if printf 'bad\n' >"$DENIED/changed.txt" 2>/dev/null; then exit 12; fi
if cat "$SIBLING/input.txt" >/dev/null 2>&1; then exit 13; fi
if printf 'bad\n' >"$SIBLING/changed.txt" 2>/dev/null; then exit 14; fi
if cat "$AMBIENT_HOME/input.txt" >/dev/null 2>&1; then exit 15; fi
if printf 'bad\n' >"$AMBIENT_HOME/changed.txt" 2>/dev/null; then exit 16; fi
if cat "$PROJECT/home-link" >/dev/null 2>&1; then exit 17; fi
if cat "$PUBLIC/home-link" >/dev/null 2>&1; then exit 18; fi
PROBE
chmod +x "$WRITE_PROBE"

HOME="$AMBIENT_HOME" AMBIENT_HOME="$AMBIENT_HOME" PUBLIC="$PUBLIC" DENIED="$DENIED" PROJECT="$PROJECT" \
SIBLING="$SIBLING" NOTES="$NOTES" \
  "$SANDBOX_BIN" \
    --read /usr --read /bin --read /lib --read /lib64 --read /etc \
    --write /dev/null --read "$PUBLIC" --write "$PROJECT" --write "$NOTES" \
    --read "$WRITE_PROBE" --deny "$DENIED" -- "$WRITE_PROBE" ||
  fail 'write capability matrix was not enforced'

[[ "$(cat "$PROJECT/result.txt")" == ok ]] || fail 'Project write was blocked'
[[ "$(cat "$NOTES/result.txt")" == ok ]] || fail 'notes write was blocked'
[[ ! -e "$PUBLIC/changed.md" && ! -e "$DENIED/changed.txt" ]] ||
  fail 'public or denied content was changed'
[[ ! -e "$SIBLING/changed.txt" && ! -e "$AMBIENT_HOME/changed.txt" ]] ||
  fail 'sibling or ambient HOME was changed'

READ_ONLY_PROBE="$TMP_DIR/read-only-probe.sh"
cat >"$READ_ONLY_PROBE" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail

[[ "$(cat "$PROJECT/input.txt")" == project ]]
if printf 'bad\n' >"$PROJECT/read-only-write.txt" 2>/dev/null; then exit 20; fi
if printf 'bad\n' >"$NOTES/read-only-write.txt" 2>/dev/null; then exit 21; fi
PROBE
chmod +x "$READ_ONLY_PROBE"

HOME="$AMBIENT_HOME" PROJECT="$PROJECT" NOTES="$NOTES" \
  "$SANDBOX_BIN" \
    --read /usr --read /bin --read /lib --read /lib64 --read /etc \
    --write /dev/null --read "$PROJECT" --read "$NOTES" \
    --read "$READ_ONLY_PROBE" -- "$READ_ONLY_PROBE" ||
  fail 'read-only capability matrix was not enforced'

[[ ! -e "$PROJECT/read-only-write.txt" && ! -e "$NOTES/read-only-write.txt" ]] ||
  fail 'read-only mode changed an allowed read scope'

runtime_cleanup_cycle_sandbox

PROFILE_PROJECT="$TMP_DIR/profile-projects/Alpha"
PROFILE_SIBLING="$TMP_DIR/profile-projects/Beta"
PROFILE_AMBIENT_HOME="$TMP_DIR/profile-ambient-home"
PROFILE_NOTES="$TMP_DIR/profile-notes/Alpha"
mkdir -p "$PROFILE_PROJECT" "$PROFILE_SIBLING" "$PROFILE_AMBIENT_HOME" "$PROFILE_NOTES"
printf 'sibling\n' >"$PROFILE_SIBLING/input.txt"
printf 'ambient\n' >"$PROFILE_AMBIENT_HOME/input.txt"

WRITE_RUNTIME="$PROFILE_PROJECT/fake-write-runtime"
cat >"$WRITE_RUNTIME" <<PROBE
#!/usr/bin/env bash
set -euo pipefail
[[ -r "$ROOT/CLAUDE.md" ]]
printf 'ok\n' >"\$SDLC_PROJECT_DIR/profile-write.txt"
printf 'ok\n' >"\$SDLC_NOTES_DIR/profile-write.txt"
if printf 'bad\n' >"$ROOT_MARKER" 2>/dev/null; then exit 30; fi
if cat "$PROFILE_SIBLING/input.txt" >/dev/null 2>&1; then exit 31; fi
if printf 'bad\n' >"$PROFILE_SIBLING/changed.txt" 2>/dev/null; then exit 32; fi
if cat "$PROFILE_AMBIENT_HOME/input.txt" >/dev/null 2>&1; then exit 33; fi
if printf 'bad\n' >"$PROFILE_AMBIENT_HOME/changed.txt" 2>/dev/null; then exit 34; fi
printf 'CAPABILITY_PROFILE_WRITE_PASS\n'
PROBE
chmod +x "$WRITE_RUNTIME"

READ_RUNTIME="$PROFILE_PROJECT/fake-read-runtime"
cat >"$READ_RUNTIME" <<PROBE
#!/usr/bin/env bash
set -euo pipefail
[[ -r "$ROOT/CLAUDE.md" ]]
if printf 'bad\n' >"\$SDLC_PROJECT_DIR/profile-read-only-write.txt" 2>/dev/null; then exit 40; fi
if printf 'bad\n' >"\$SDLC_NOTES_DIR/profile-read-only-write.txt" 2>/dev/null; then exit 41; fi
if printf 'bad\n' >"$ROOT_MARKER" 2>/dev/null; then exit 42; fi
if cat "$PROFILE_SIBLING/input.txt" >/dev/null 2>&1; then exit 43; fi
if cat "$PROFILE_AMBIENT_HOME/input.txt" >/dev/null 2>&1; then exit 44; fi
printf 'CAPABILITY_PROFILE_READ_PASS\n'
PROBE
chmod +x "$READ_RUNTIME"

run_write_profile() {
  local label="$1" output="$2"
  shift 2
  rm -f "$PROFILE_PROJECT/profile-write.txt" "$PROFILE_NOTES/profile-write.txt"
  if ! "$@" >"$output" 2>&1; then
    cat "$output" >&2
    fail "$label write profile was rejected"
  fi
  grep -Fq 'CAPABILITY_PROFILE_WRITE_PASS' "$output" ||
    fail "$label write profile did not execute the capability probe"
  [[ "$(cat "$PROFILE_PROJECT/profile-write.txt")" == ok ]] ||
    fail "$label could not write the exact Project"
  [[ "$(cat "$PROFILE_NOTES/profile-write.txt")" == ok ]] ||
    fail "$label could not write the exact notes scope"
  [[ ! -e "$ROOT_MARKER" && ! -e "$PROFILE_SIBLING/changed.txt" &&
     ! -e "$PROFILE_AMBIENT_HOME/changed.txt" ]] ||
    fail "$label changed a denied scope"
}

run_read_profile() {
  local label="$1" output="$2"
  shift 2
  rm -f "$PROFILE_PROJECT/profile-read-only-write.txt" \
    "$PROFILE_NOTES/profile-read-only-write.txt"
  if ! "$@" >"$output" 2>&1; then
    cat "$output" >&2
    fail "$label read-only profile was rejected"
  fi
  grep -Fq 'CAPABILITY_PROFILE_READ_PASS' "$output" ||
    fail "$label read-only profile did not execute the capability probe"
  [[ ! -e "$PROFILE_PROJECT/profile-read-only-write.txt" &&
     ! -e "$PROFILE_NOTES/profile-read-only-write.txt" && ! -e "$ROOT_MARKER" ]] ||
    fail "$label read-only profile changed a denied scope"
}

ACTIVE_AGENT="$ROOT/cycle1-dev/s1-pm"
COMMON_ARGS=(--agent-dir "$ACTIVE_AGENT" --project-dir "$PROFILE_PROJECT" \
  --notes-dir "$PROFILE_NOTES" --mode task --prompt capability-profile-smoke)

run_write_profile codex "$TMP_DIR/codex-write.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=codex CODEX_BIN="$WRITE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access write
run_write_profile claude "$TMP_DIR/claude-write.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=claude CLAUDE_BIN="$WRITE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access write
run_write_profile gemini "$TMP_DIR/gemini-write.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=gemini GEMINI_BIN="$WRITE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access write

LOCAL_REGISTRY="$TMP_DIR/local-hosts"
mkdir -p "$LOCAL_REGISTRY"
ln -s "$WRITE_RUNTIME" "$LOCAL_REGISTRY/custom-probe"
run_write_profile local-custom "$TMP_DIR/local-custom-write.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=local LOCAL_AGENT_HOST=custom-probe \
  LOCAL_MODEL_PROVIDER=test-provider LOCAL_MODEL=test-model \
  LOCAL_HOST_REGISTRY="$LOCAL_REGISTRY" SDLC_SUBAGENTS=off \
  "$RUNNER" "${COMMON_ARGS[@]}" --access write
run_write_profile local-codex-oss "$TMP_DIR/local-codex-write.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=local LOCAL_AGENT_HOST=codex-oss \
  LOCAL_MODEL_PROVIDER=ollama LOCAL_MODEL=test-model LOCAL_CODEX_BIN="$WRITE_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access write

run_read_profile codex "$TMP_DIR/codex-read.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=codex CODEX_BIN="$READ_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access read-only
run_read_profile claude "$TMP_DIR/claude-read.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=claude CLAUDE_BIN="$READ_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access read-only
run_read_profile local-codex-oss "$TMP_DIR/local-codex-read.out" \
  env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=local LOCAL_AGENT_HOST=codex-oss \
  LOCAL_MODEL_PROVIDER=ollama LOCAL_MODEL=test-model LOCAL_CODEX_BIN="$READ_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access read-only

if env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=gemini GEMINI_BIN="$READ_RUNTIME" \
  SDLC_SUBAGENTS=off "$RUNNER" "${COMMON_ARGS[@]}" --access read-only \
  >"$TMP_DIR/gemini-read.out" 2>&1; then
  fail 'Gemini read-only profile was accepted without a registered capability'
fi
grep -Fq 'Gemini read-only worker adapter is not capability-enforced' \
  "$TMP_DIR/gemini-read.out" || fail 'Gemini read-only block reason is missing'

if env HOME="$PROFILE_AMBIENT_HOME" AGENT_RUNTIME=local LOCAL_AGENT_HOST=custom-probe \
  LOCAL_MODEL_PROVIDER=test-provider LOCAL_MODEL=test-model \
  LOCAL_HOST_REGISTRY="$LOCAL_REGISTRY" SDLC_SUBAGENTS=off \
  "$RUNNER" "${COMMON_ARGS[@]}" --access read-only \
  >"$TMP_DIR/local-custom-read.out" 2>&1; then
  fail 'custom local read-only profile was accepted without a registered capability'
fi
grep -Fq 'has no registered read-only capability' "$TMP_DIR/local-custom-read.out" ||
  fail 'custom local read-only block reason is missing'

echo 'PASS: runtime capability matrix smoke'

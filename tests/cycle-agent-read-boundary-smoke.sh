#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BOUNDARY="$ROOT/_runtimes/runtime-boundary.sh"
RUNNER="$ROOT/_runtimes/agent-run.sh"
LANDLOCK_SOURCE="$ROOT/_runtimes/cycle-landlock.c"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-cycle-read-boundary.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$LANDLOCK_SOURCE" ]] || fail "missing Landlock source: $LANDLOCK_SOURCE"
source "$BOUNDARY"
declare -F runtime_prepare_cycle_sandbox >/dev/null ||
  fail 'runtime boundary does not expose runtime_prepare_cycle_sandbox'

runtime_prepare_cycle_sandbox >/dev/null ||
  fail 'Landlock sandbox could not be prepared'
SANDBOX_BIN="$RUNTIME_LANDLOCK_BIN"
[[ -x "$SANDBOX_BIN" ]] || fail 'prepared Landlock sandbox is not executable'

SYSTEM="$TMP_DIR/system"
DENIED_LOCAL="$SYSTEM/denied-local"
DENIED_VCS="$SYSTEM/vcs-metadata"
PUBLIC="$SYSTEM/public"
PROJECT="$TMP_DIR/project"
mkdir -p "$DENIED_LOCAL" "$DENIED_VCS" "$PUBLIC" "$PROJECT"
printf '%s\n' 'denied fixture content' >"$DENIED_LOCAL/data.txt"
printf '%s\n' 'denied metadata fixture content' >"$DENIED_VCS/config"
printf '%s\n' 'public fixture content' >"$PUBLIC/readable.txt"
ln -s "$DENIED_LOCAL/data.txt" "$PUBLIC/denied-link"
printf '%s\n' 'movable project content' >"$PROJECT/movable.txt"

PROBE="$TMP_DIR/probe.sh"
cat >"$PROBE" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail

if cat "$DENIED_LOCAL/data.txt" >/dev/null 2>&1; then
  echo 'denied file was readable' >&2
  exit 10
fi
if find "$DENIED_LOCAL" -mindepth 1 -print -quit >/dev/null 2>&1; then
  echo 'denied directory was listable' >&2
  exit 11
fi
if (printf '%s\n' hacked >"$DENIED_LOCAL/new.txt") 2>/dev/null; then
  echo 'denied directory was writable' >&2
  exit 12
fi
if cat "$PUBLIC/denied-link" >/dev/null 2>&1; then
  echo 'denied content was readable through an allowed symlink' >&2
  exit 13
fi
if cat "$DENIED_VCS/config" >/dev/null 2>&1; then
  echo 'agent-system Git metadata was readable' >&2
  exit 14
fi
if mv "$PROJECT/movable.txt" "$DENIED_LOCAL/moved.txt" 2>/dev/null; then
  echo 'project content could be moved into a denied area' >&2
  exit 15
fi
[[ "$(cat "$PUBLIC/readable.txt")" == 'public fixture content' ]] || {
  echo 'public system content was not readable' >&2
  exit 16
}
printf '%s\n' 'project write passed' >"$PROJECT/result.txt"
PROBE
chmod +x "$PROBE"

DENIED_LOCAL="$DENIED_LOCAL" DENIED_VCS="$DENIED_VCS" PUBLIC="$PUBLIC" PROJECT="$PROJECT" \
  "$SANDBOX_BIN" \
    --read /usr --read /bin --read /lib --read /lib64 --read /etc \
    --write /dev/null --read "$PUBLIC" --write "$PROJECT" --read "$PROBE" \
    --deny "$DENIED_LOCAL" --deny "$DENIED_VCS" -- "$PROBE" ||
  fail 'Landlock negative/positive boundary probe failed'

[[ "$(cat "$PROJECT/result.txt")" == 'project write passed' ]] ||
  fail 'sandbox blocked the allowed Project write'
[[ ! -e "$DENIED_LOCAL/new.txt" && ! -e "$DENIED_LOCAL/moved.txt" ]] ||
  fail 'sandbox changed denied fixture content'
runtime_cleanup_cycle_sandbox

grep -Fq 'runtime_prepare_cycle_sandbox' "$RUNNER" ||
  fail 'agent dispatcher does not prepare the Landlock boundary'
grep -Fq 'runtime_load_cycle_denies' "$RUNNER" ||
  fail 'agent dispatcher does not load checkout-local deny paths'
grep -Fq -- '--absolute-git-dir' "$BOUNDARY" ||
  fail 'runtime boundary does not resolve the actual Git directory'
grep -Fq -- '--git-common-dir' "$BOUNDARY" ||
  fail 'runtime boundary does not resolve the Git common directory'
grep -Fq 'sdlc.runtimeDenyPath' "$BOUNDARY" ||
  fail 'runtime boundary does not read checkout-local deny-path configuration'
if grep -Fq 'clean_env+=("CODEX_HOME=' "$RUNNER"; then
  fail 'agent dispatcher propagates an outer CODEX_HOME'
fi
if grep -Fq 'clean_env+=("XDG_' "$RUNNER"; then
  fail 'agent dispatcher propagates outer XDG config/state paths'
fi

echo 'PASS: cycle agent read boundary smoke'

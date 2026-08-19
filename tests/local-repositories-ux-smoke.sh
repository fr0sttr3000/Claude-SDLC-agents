#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-local-repositories.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_RUNTIME=codex
export CODEX_BIN=/bin/true
export SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off
export SDLC_SUBAGENT_MAX=2
source "$ROOT/localrun.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "output does not contain: $2"
}

for fn in valid_local_folder local_repository_source_kind local_repository_default_folder \
  local_repository_root_is_exact local_repositories_action_map \
  render_local_repositories_menu localrun_exit_code valid_menu_index \
  localrun_step_output_ref localrun_step_output_fingerprint run_verified_local_step; do
  declare -F "$fn" >/dev/null || fail "missing Local Repositories function: $fn"
done

valid_menu_index 4 4 || fail 'valid Local Repositories menu index rejected'
for value in '' 0 04 5 -1 abc '1+1' 'x[0]'; do
  if valid_menu_index "$value" 4; then
    fail "unsafe Local Repositories menu index accepted: $value"
  fi
done

valid_local_folder repo-2 || fail "safe repository folder rejected"
valid_local_folder 'repo with space' || fail "safe repository folder with spaces rejected"
for unsafe in '../escape' 'nested/repo' '.' '..' '.hidden' ' leading' 'trailing ' $'tab\tname' ''; do
  if valid_local_folder "$unsafe"; then
    fail "unsafe repository folder accepted: $unsafe"
  fi
done

[[ "$(local_repository_default_folder 'https://example.test/org/repo.git')" == repo ]] ||
  fail 'HTTPS repository folder was not derived'
SSH_USER=git
SSH_HOST=example.test
SSH_AUTHORITY="${SSH_USER}@${SSH_HOST}"
[[ "$(local_repository_default_folder "ssh://${SSH_AUTHORITY}/org/repo-name.git")" == repo-name ]] ||
  fail 'SSH repository folder was not derived'
[[ "$(local_repository_default_folder "${SSH_AUTHORITY}:org/repo with space.git")" == 'repo with space' ]] ||
  fail 'SCP-style repository folder with spaces was not derived'
mkdir -p "$TMP_DIR/source repo"
[[ "$(local_repository_default_folder "$TMP_DIR/source repo")" == 'source repo' ]] ||
  fail 'local repository folder with spaces was not derived'
for ambiguous in 'example.test/org/repo.git' 'missing local repo' '--upload-pack=bad'; do
  if local_repository_source_kind "$ambiguous" >/dev/null; then
    fail "ambiguous or option-like repository source accepted: $ambiguous"
  fi
done

expected=$'1|add-or-update\n2|full-preparation\n3|one-step\n4|update-notes\n5|list\n6|settings\np|parent\n?|help\nq|quit'
SDLC_UI_VIEW=detailed
detailed_map="$(local_repositories_action_map)"
detailed="$(render_local_repositories_menu)"
SDLC_UI_VIEW=compact
compact_map="$(local_repositories_action_map)"
compact="$(render_local_repositories_menu)"
[[ "$detailed_map" == "$compact_map" && "$compact_map" == "$expected" ]] ||
  fail "detailed and compact views have different actions"
assert_contains "$detailed" 'ЛОКАЛЬНЫЕ РЕПОЗИТОРИИ'
assert_contains "$detailed" 'Добавить или обновить repository'
assert_contains "$detailed" 'Git push: ЗАПРЕЩЁН'
assert_contains "$compact" 'Один шаг'
assert_contains "$compact" 'p Вернуться'

[[ "$(localrun_exit_code parent embedded)" == 0 ]] || fail "embedded parent return code is wrong"
[[ "$(localrun_exit_code quit embedded)" == 86 ]] || fail "embedded quit code is wrong"
[[ "$(localrun_exit_code quit standalone)" == 0 ]] || fail "standalone quit code is wrong"

mkdir -p "$TMP_DIR/bin"
printf '#!/usr/bin/env bash\nexit 7\n' > "$TMP_DIR/bin/fail-runner"
chmod +x "$TMP_DIR/bin/fail-runner"
AGENT_RUNNER="$TMP_DIR/bin/fail-runner"
AGENT_RUNTIME=codex
BASE_PROFILE='codex||||'
PROJECTS="$TMP_DIR/repos"
LOCALRUN_PROJECTS="$PROJECTS"
mkdir -p "$PROJECTS/Repo" "$PROJECTS/Repo With Space"
if run_agent l1-analyze Repo /analyze <<< '' >/dev/null; then
  fail "Local Repositories agent hid dispatcher failure"
else
  rc=$?
  [[ $rc -eq 7 ]] || fail "dispatcher exit code changed: $rc"
fi

run_agent() { return 3; }
LOCAL_PROJECT=Repo
NOTES="$TMP_DIR/notes"
mkdir -p "$NOTES"
set +e
pipeline_output="$(run_pipeline Repo <<< 'r' 2>&1)"
pipeline_rc=$?
set -e
[[ $pipeline_rc -eq 3 ]] || fail "skipped required pipeline step returned $pipeline_rc instead of incomplete=3"
assert_contains "$pipeline_output" 'Pipeline не завершён'
if [[ "$pipeline_output" == *'Pipeline завершён'* ]]; then
  fail 'full pipeline claimed success after a skipped required step'
fi

run_agent() { return 0; }
if run_verified_local_step l1-analyze Repo /analyze <<< '' >/dev/null 2>&1; then
  fail 'Local Repositories accepted exit 0 without overview.md'
fi
run_agent() {
  mkdir -p "$NOTES/$2"
  printf '%s\n' '# Verified overview' > "$NOTES/$2/overview.md"
}
run_verified_local_step l1-analyze Repo /analyze <<< '' >/dev/null ||
  fail 'Local Repositories rejected a changed non-empty overview.md'
run_agent() { return 0; }
if run_verified_local_step l1-analyze Repo /analyze <<< '' >/dev/null 2>&1; then
  fail 'Local Repositories accepted a stale existing overview.md'
fi

run_agent() { return 3; }
header() { :; }
pick_local_project() { LOCAL_PROJECT=Repo; return 0; }
set +e
notes_output="$(menu_update_notes <<< $'2\n1\nr\n\n' 2>&1)"
notes_rc=$?
set -e
[[ $notes_rc -eq 3 ]] || fail "skipped notes update returned $notes_rc instead of incomplete=3"
assert_contains "$notes_output" 'ПРОВЕРКА ЗАПУСКА · ЛОКАЛЬНЫЕ РЕПОЗИТОРИИ'
assert_contains "$notes_output" 'Обновление заметок не завершено'

echo 'PASS: Local Repositories UX smoke'

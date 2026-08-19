#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-launcher-ui.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_RUNTIME=codex
export CODEX_BIN=/bin/true
export SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off
export SDLC_SUBAGENT_MAX=2

source "$ROOT/sdlc.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "output does not contain: $needle"
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "output unexpectedly contains: $needle"
}

for fn in normalize_ui_view set_ui_view toggle_ui_view render_ui_view_choice \
  console_action_map render_project_selector render_project_console \
  render_launcher_entry_intro render_project_console_intro \
  render_action_help render_cycle23_frozen_status dispatch_console_action \
  post_kickoff_menu valid_project_name \
  valid_menu_index; do
  declare -F "$fn" >/dev/null || fail "missing launcher UX function: $fn"
done

for value in 1 2 9; do
  valid_menu_index "$value" 9 || fail "valid menu index rejected: $value"
done
for value in '' 0 08 10 -1 abc '1+1' 'x[0]'; do
  if valid_menu_index "$value" 9; then
    fail "unsafe or out-of-range menu index accepted: $value"
  fi
done

[[ "$(normalize_ui_view detailed)" == "detailed" ]] || fail "detailed view rejected"
[[ "$(normalize_ui_view compact)" == "compact" ]] || fail "compact view rejected"
if normalize_ui_view unknown >/dev/null 2>&1; then
  fail "unknown UI view accepted"
fi

valid_project_name "ExampleProject-2" || fail "safe project name rejected"
for unsafe in "../escape" "nested/name" ".hidden" "" "name with spaces"; do
  if valid_project_name "$unsafe"; then
    fail "unsafe project name accepted: $unsafe"
  fi
done

set_ui_view detailed
[[ "$SDLC_UI_VIEW" == "detailed" ]] || fail "detailed view not applied"
[[ "$(read_config_value SDLC_UI_VIEW)" == "detailed" ]] || fail "view not persisted"
toggle_ui_view >/dev/null
[[ "$SDLC_UI_VIEW" == "compact" ]] || fail "view toggle did not switch to compact"
toggle_ui_view >/dev/null
[[ "$SDLC_UI_VIEW" == "detailed" ]] || fail "view toggle did not switch back"

choice_output="$(render_ui_view_choice)"
assert_contains "$choice_output" "Подробный вид"
assert_contains "$choice_output" "Краткий вид"
assert_contains "$choice_output" "показать оба"

SDLC_UI_VIEW=detailed
entry_intro="$(render_launcher_entry_intro)"
assert_contains "$entry_intro" "LAUNCHER ГОТОВ"
assert_contains "$entry_intro" "Выбор проекта ничего не запускает"
assert_contains "$entry_intro" "Project Console"

console_intro="$(render_project_console_intro)"
assert_contains "$console_intro" "Сейчас ничего не запущено"
assert_contains "$console_intro" "без изменений"
assert_contains "$console_intro" "предпросмотр"

SDLC_UI_VIEW=compact
compact_entry_intro="$(render_launcher_entry_intro)"
assert_contains "$compact_entry_intro" "ничего не запускает"
compact_console_intro="$(render_project_console_intro)"
assert_contains "$compact_console_intro" "Действие ещё не запущено"

PROJECTS="$TMP_DIR/projects"
PROJECTS_MODE=collection
mkdir -p "$PROJECTS/Alpha/stage1-planning/inputs" \
  "$PROJECTS/Alpha/stage1-planning/outputs" \
  "$PROJECTS/Beta/stage1-planning/inputs" \
  "$PROJECTS/Beta/stage1-planning/outputs"
: > "$PROJECTS/Alpha/Dashboard.md"
: > "$PROJECTS/Beta/Dashboard.md"

selector_output="$(render_project_selector)"
assert_contains "$selector_output" "Alpha"
assert_contains "$selector_output" "$PROJECTS/Alpha"
assert_contains "$selector_output" "Создать новый SDLC Project"
assert_contains "$selector_output" "Локальные репозитории"
assert_contains "$selector_output" "Настройки launcher-а"

PROJECT=Alpha
SDLC_UI_VIEW=detailed
detailed_output="$(render_project_console)"
assert_contains "$detailed_output" "PROJECT: Alpha"
assert_contains "$detailed_output" "$PROJECTS/Alpha"
assert_contains "$detailed_output" "Пройти или обновить Kickoff"
assert_contains "$detailed_output" "Разработка не стартует сама"
assert_contains "$detailed_output" "Запустить Cycle 1"
assert_contains "$detailed_output" "Cycle 2/3 — FROZEN / NOT READY"
assert_contains "$detailed_output" "Локальные репозитории"
assert_contains "$detailed_output" "v Краткий вид"
assert_not_contains "$detailed_output" "Вариант A"
assert_not_contains "$detailed_output" "A/B/C"

detailed_map="$(console_action_map)"
SDLC_UI_VIEW=compact
compact_output="$(render_project_console)"
compact_map="$(console_action_map)"
[[ "$detailed_map" == "$compact_map" ]] || fail "view changed action mapping"
assert_contains "$compact_output" "PROJECT: Alpha"
assert_contains "$compact_output" "1 Kickoff"
assert_contains "$compact_output" "5 Cycle 1"
assert_contains "$compact_output" "6 Cycle 2/3 — FROZEN / NOT READY"
assert_contains "$compact_output" "v Подробный вид"
assert_not_contains "$compact_output" "Разработка не стартует сама"

expected_map=$'0|unfinished\n1|kickoff\n2|overview\n3|review\n4|repair\n5|cycle1\n6|cycle23-frozen\n7|agent\n9|ai\nu|utilities\np|projects\nl|local-repositories\ng|launcher-settings\nv|view\n?|help\nq|exit'
[[ "$compact_map" == "$expected_map" ]] || fail "unexpected Project Console action map"

help_output="$(render_action_help cycle)"
assert_contains "$help_output" "ТОЛЬКО CYCLE 1"
assert_contains "$help_output" "FROZEN / NOT READY"
assert_contains "$help_output" "Проверка запуска"

CALLS=()
menu_kickoff() { CALLS+=(kickoff); }
menu_project_overview() { CALLS+=(overview); }
menu_project_review() { CALLS+=(review); }
menu_project_repair() { CALLS+=(repair); }
run_cycle1() { CALLS+=(cycle1); }
render_cycle23_frozen_status() { CALLS+=(cycle23-frozen); }
menu_single_agent() { CALLS+=(agent); }
menu_ai_assignment() { CALLS+=(ai); }
menu_utilities() { CALLS+=(utilities); }
project_selector() { CALLS+=(projects); }
menu_local_repositories() { CALLS+=(local-repositories); }
menu_launcher_settings() { CALLS+=(launcher-settings); }

for key in 1 2 3 4 5 6 7 9 u p l g; do
  dispatch_console_action "$key"
done
[[ "${CALLS[*]}" == "kickoff overview review repair cycle1 cycle23-frozen agent ai utilities projects local-repositories launcher-settings" ]] ||
  fail "Project Console dispatch mismatch: ${CALLS[*]}"

CALLS=()
run_cycle1() { CALLS+=("cycle1:$1"); }
post_kickoff_menu <<< "1" >/dev/null
[[ "${CALLS[*]}" == "cycle1:selected" ]] || fail "Kickoff does not hand off to only Cycle 1"

CALLS=()
post_output="$(post_kickoff_menu <<< "3")"
assert_contains "$post_output" "FROZEN / NOT READY"
assert_not_contains "$post_output" "режим цели"
[[ "${#CALLS[@]}" -eq 0 ]] || fail "Kickoff still exposes a frozen continuation: ${CALLS[*]}"

echo "PASS: launcher UI/navigation smoke"

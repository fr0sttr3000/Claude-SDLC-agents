#!/bin/bash
# SDLC Interactive Agent Launcher

export PATH="$HOME/.local/bin:$PATH"

# Пути вычисляются от расположения скрипта — переносимо между окружениями
AGENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$AGENTS")"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sdlc-agents"
CONFIG_FILE="$CONFIG_DIR/config"
ROUTING_FILE="${SDLC_ROUTING_FILE:-$CONFIG_DIR/runtime-routing}"
PROJECTS=""
PROJECTS_MODE=""
SINGLE_PROJECT=""
PROJECTS_DIR_NOTE=""

# Экспортируем пути в окружение — агенты используют их вместо
# захардкоженных абсолютных путей (по образцу AGENT_DIR).
export SDLC_VAULT="$VAULT"
export AGENT_RUNTIME="${AGENT_RUNTIME:-}"
export LOCAL_AGENT_HOST="${LOCAL_AGENT_HOST:-}"
export LOCAL_MODEL_PROVIDER="${LOCAL_MODEL_PROVIDER:-}"
export LOCAL_MODEL="${LOCAL_MODEL:-}"
export LOCAL_MODEL_ENDPOINT="${LOCAL_MODEL_ENDPOINT:-}"
export SDLC_SUBAGENTS="${SDLC_SUBAGENTS:-}"
export SDLC_SUBAGENT_MAX="${SDLC_SUBAGENT_MAX:-}"
export SDLC_SUBAGENT_PROFILE="${SDLC_SUBAGENT_PROFILE:-}"
export SDLC_SUBAGENT_TASKS="${SDLC_SUBAGENT_TASKS:-}"
export SDLC_SUBAGENT_RUNNER="${SDLC_SUBAGENT_RUNNER:-$AGENTS/_runtimes/subagent-run.sh}"
export SDLC_RUNTIME_ROUTING="${SDLC_RUNTIME_ROUTING:-}"
AGENT_RUNNER="$AGENTS/_runtimes/agent-run.sh"
BASE_PROFILE=""
LAUNCHER_BASE_PROFILE=""
LAUNCHER_ROUTING_POLICY=""
LAUNCHER_SUBAGENTS=""
LAUNCHER_SUBAGENT_MAX=""
LAUNCHER_SUBAGENT_PROFILE=""
LAUNCHER_SUBAGENT_TASKS=""
PROJECT="${PROJECT:-}"
SDLC_UI_VIEW="${SDLC_UI_VIEW:-}"
CURRENT_RUN_ID="${CURRENT_RUN_ID:-}"
FIRST_RUN_WIZARD=0
PROJECT_CONSOLE_INTRO_PENDING=1
PENDING_FIRST_RUN_AI_SETUP=""
EXECUTION_PREVIEW_BLOCKED=0
declare -a EXECUTION_STEP_PROFILES=()
declare -a EXECUTION_STEP_SOURCES=()

# ─── цвета ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'


# ─── конфигурация runtime и проектов ─────────────────────────────────────────
read_config_value() {
  local key="$1"
  [[ -f "$CONFIG_FILE" ]] || return 1
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value=$0
      sub(/^[^=]*=/, "", value)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  ' "$CONFIG_FILE"
}

write_config_value() {
  local key="$1" value="$2" tmp
  [[ "$key" =~ ^[A-Z0-9_]+$ ]] || return 1
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *'"'* ]]; then
    echo "Недопустимое значение настройки $key" >&2
    return 1
  fi
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  tmp="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")" || return 1
  if [[ -f "$CONFIG_FILE" ]]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { written=0 }
      index($0, key "=") == 1 { print key "=\"" value "\""; written=1; next }
      { print }
      END { if (written == 0) print key "=\"" value "\"" }
    ' "$CONFIG_FILE" > "$tmp"
  else
    printf '%s="%s"\n' "$key" "$value" > "$tmp"
  fi
  chmod 600 "$tmp"
  mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
}

is_first_run() {
  [[ ! -s "$CONFIG_FILE" ]]
}

render_first_run_intro() {
  printf '%s\n' \
    'Добро пожаловать. Этот launcher помогает выбрать проект и безопасно запустить нужный SDLC-сценарий.' \
    '' \
    'Что сейчас произойдёт:' \
    '  1. Runtime — выберем primary routing и способ использования AI-помощников.' \
    '  2. Projects — укажем, где launcher ищет доступные SDLC-проекты.' \
    '  3. View — выберем подробный или краткий вид одного и того же меню.' \
    '' \
    'После настройки откроется выбор проекта, затем Project Console с доступными действиями.' \
    'Настройка ничего не запускает и не изменяет файлы проектов.' \
    ''
}

render_first_run_step_context() {
  case "$1" in
    1)
      printf '%s\n' \
        'Зачем: runtime определяет, какой установленный AI-инструмент будет вызывать agents.' \
        'Что изменится: сохранятся primary routing, worker mode и точные профили без silent fallback.' \
        'Что дальше: launcher зафиксирует безопасный execution profile и перейдёт к Projects.'
      ;;
    2)
      printf '%s\n' \
        'Зачем: Projects ограничивает каталог, в котором launcher показывает и создаёт проекты.' \
        'Что изменится: сохранится путь и режим — коллекция проектов или один конкретный проект.' \
        'Что дальше: файлы проектов не меняются; затем выбирается вид интерфейса.'
      ;;
    3)
      printf '%s\n' \
        'Зачем: подробный вид объясняет действия, краткий оставляет те же команды без длинных описаний.' \
        'Что изменится: сохранится только плотность интерфейса; функции и правила безопасности одинаковы.' \
        'Что дальше: откроется launcher, где сначала нужно выбрать проект и только потом действие.'
      ;;
  esac
  echo
}

render_first_run_step() {
  local step="$1" title="$2"
  [[ "$step" == "1" ]] && render_first_run_intro
  echo -e "${W}ПЕРВЫЙ ЗАПУСК · ШАГ ${step} ИЗ 3${N}"
  echo -e "${W}${title}${N}"
  echo
  render_first_run_step_context "$step"
}

initialize_first_run_execution_policy() {
  case "${SDLC_RUNTIME_ROUTING:-}" in
    "") SDLC_RUNTIME_ROUTING="single" ;;
    single|per-stage|per-agent|ask) ;;
    *) echo -e "${R}Некорректный SDLC_RUNTIME_ROUTING: $SDLC_RUNTIME_ROUTING${N}"; return 1 ;;
  esac

  case "${SDLC_SUBAGENTS:-}" in
    "") SDLC_SUBAGENTS="off" ;;
    off|auto|cross-runtime) ;;
    *) echo -e "${R}SDLC_SUBAGENTS должен быть off, auto или cross-runtime${N}"; return 1 ;;
  esac
  [[ -n "${SDLC_SUBAGENT_MAX:-}" ]] || SDLC_SUBAGENT_MAX=2
  valid_menu_index "$SDLC_SUBAGENT_MAX" 16 || {
      echo -e "${R}SDLC_SUBAGENT_MAX должен быть 1..16${N}"
      return 1
    }

  export SDLC_RUNTIME_ROUTING SDLC_SUBAGENTS SDLC_SUBAGENT_MAX
  write_config_value SDLC_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
  write_config_value SDLC_SUBAGENTS "$SDLC_SUBAGENTS"
  write_config_value SDLC_SUBAGENT_MAX "$SDLC_SUBAGENT_MAX"
}

render_first_run_execution_policy() {
  echo -e "  Профиль исполнения: ${C}${SDLC_RUNTIME_ROUTING}${N}"
  echo -e "  Silent fallback: ${C}выключен${N}"
  echo -e "  Subagents: ${C}${SDLC_SUBAGENTS}${N} (лимит: ${SDLC_SUBAGENT_MAX})"
  if [[ "$SDLC_SUBAGENTS" == "cross-runtime" ]]; then
    render_subagent_execution_summary
  fi
  echo -e "  Изменить позже: ${W}Project Console → Configuration${N}"
  echo
}

# ─── interface state and safe project identity ───────────────────────────────
normalize_ui_view() {
  case "${1:-}" in
    detailed|compact) printf '%s\n' "$1" ;;
    *) return 1 ;;
  esac
}

set_ui_view() {
  local view
  view="$(normalize_ui_view "${1:-}")" || return 1
  SDLC_UI_VIEW="$view"
  export SDLC_UI_VIEW
  write_config_value SDLC_UI_VIEW "$view"
}

toggle_ui_view() {
  case "${SDLC_UI_VIEW:-detailed}" in
    detailed) set_ui_view compact ;;
    compact) set_ui_view detailed ;;
    *) set_ui_view detailed ;;
  esac
  printf '%s\n' "$SDLC_UI_VIEW"
}

render_ui_view_choice() {
  printf '%s\n' \
    'Как показывать launcher?' \
    '  1) Подробный вид — действия сразу сопровождаются пояснениями' \
    '  2) Краткий вид — те же действия без длинных описаний' \
    '  ?) Сначала показать оба вида; выбор при этом не сохраняется'
}

ensure_ui_view() {
  local saved choice
  if saved="$(read_config_value SDLC_UI_VIEW 2>/dev/null)" && normalize_ui_view "$saved" >/dev/null; then
    SDLC_UI_VIEW="$saved"
    export SDLC_UI_VIEW
    return 0
  fi
  while true; do
    if [[ "$FIRST_RUN_WIZARD" == "1" ]]; then
      header
      render_first_run_step 3 "Как показывать меню?"
    fi
    render_ui_view_choice
    read -rp 'Выбери [1/2/?/q]: ' choice
    case "$choice" in
      1) set_ui_view detailed; return ;;
      2) set_ui_view compact; return ;;
      \?) printf '\nПодробный — больше контекста. Краткий — тот же порядок, клавиши и безопасность.\n\n' ;;
      q|Q|'') return 1 ;;
      *) echo 'Выбери показанный вариант.' ;;
    esac
  done
}

valid_project_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]]
}

valid_menu_index() {
  local value="${1:-}" maximum="${2:-0}"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] &&
    [[ "$maximum" =~ ^[0-9]+$ ]] &&
    (( 10#$value >= 1 && 10#$value <= 10#$maximum ))
}

project_path() {
  printf '%s/%s\n' "$PROJECTS" "${1:-$PROJECT}"
}

is_recognized_sdlc_project() {
  local dir="$1"
  is_sdlc_project_dir "$dir" && return 0
  [[ -f "$dir/Dashboard.md" &&
     -d "$dir/stage1-planning/inputs" &&
     -d "$dir/stage1-planning/outputs" ]]
}

# ─── Project Console: one action catalog, two renderers ──────────────────────
console_action_map() {
  printf '%s\n' \
    '0|unfinished' '1|kickoff' '2|overview' '3|review' '4|repair' \
    '5|goal' '6|cycle' '7|agent' '8|goal-config' '9|ai' \
    'u|utilities' 'p|projects' 'l|local-repositories' \
    'g|launcher-settings' 'v|view' '?|help' 'q|exit'
}

render_project_selector() {
  local d name
  printf 'SDLC PROJECTS\n\n'
  if [[ "${PROJECTS_MODE:-}" == single && -n "${SINGLE_PROJECT:-}" ]]; then
    printf '  1 %s — %s/%s\n' "$SINGLE_PROJECT" "$PROJECTS" "$SINGLE_PROJECT"
  elif [[ -d "${PROJECTS:-}" ]]; then
    while IFS= read -r -d '' d; do
      name="$(basename "$d")"
      [[ "$name" == _* || "$name" == .* ]] && continue
      is_recognized_sdlc_project "$d" || continue
      printf '  %s — %s\n' "$name" "$d"
    done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
  fi
  printf '%s\n' \
    '' '  n Создать новый SDLC Project' \
    '  l Локальные репозитории' \
    '  g Настройки launcher-а' \
    '  q Завершить launcher'
}

render_launcher_entry_intro() {
  if [[ "${SDLC_UI_VIEW:-detailed}" == "compact" ]]; then
    printf '%s\n' 'LAUNCHER ГОТОВ — выбор проекта ничего не запускает; он только открывает Project Console.'
    return
  fi
  printf '%s\n' \
    'LAUNCHER ГОТОВ' \
    'Настройка завершена. Теперь выберите проект — контекст, с которым будете работать.' \
    'Выбор проекта ничего не запускает и не изменяет его файлы.' \
    'После выбора откроется Project Console: Kickoff, обзор, Review, Repair, Goal, Cycle или один Agent.' \
    'Работа начинается только после выбора действия; операции запуска показывают границы и предпросмотр.'
}

render_project_console_intro() {
  if [[ "${SDLC_UI_VIEW:-detailed}" == "compact" ]]; then
    printf '%s\n' 'Действие ещё не запущено — выберите нужную команду Project Console.'
    return
  fi
  printf '%s\n' \
    'КОНТЕКСТ ПРОЕКТА ОТКРЫТ' \
    'Сейчас ничего не запущено: launcher ждёт, что именно вы хотите сделать.' \
    'Обзор и Review работают без изменений; Repair отделён от проверки.' \
    'Для Goal, Cycle и Agent сначала показываются границы и предпросмотр запуска.'
}

render_project_console() {
  local view="${SDLC_UI_VIEW:-detailed}" next_view='Краткий вид'
  [[ "$view" == compact ]] && next_view='Подробный вид'
  printf 'PROJECT: %s\nPATH:    %s\nVIEW:    %s\n\n' "$PROJECT" "$(project_path)" "$view"
  if [[ "$view" == compact ]]; then
    printf '%s\n' \
      '0 Незавершённый запуск' '1 Kickoff' '2 Обзор проекта' \
      '3 Review' '4 Repair' '5 Режим цели' '6 Один Cycle' \
      '7 Один Agent' '8 Настроить Goal/Cycle 2/Cycle 3' \
      '9 AI routing/workers' 'u Утилиты проекта' 'p Другой проект' \
      'l Локальные репозитории' 'g Настройки launcher-а' \
      "v $next_view" '? Пояснить действие' 'q Завершить launcher'
  else
    printf '%s\n' \
      '0 Продолжить незавершённый запуск — открыть его план и доказанную точку восстановления' \
      '1 Пройти или обновить Kickoff — Разработка не стартует сама' \
      '2 Обзор проекта — входы, результаты, циклы и состояние без изменений' \
      '3 Review проекта — только проверить, ничего не исправлять' \
      '4 Repair проекта — сначала показать точные изменения, затем запросить запуск' \
      '5 Режим цели — Cycle 1 и явно выбранное продолжение Cycle 2/Cycle 3' \
      '6 Запустить только один Cycle — Cycle 1, Cycle 2 или Cycle 3' \
      '7 Запустить только один Agent — один агент и одна команда' \
      '8 Настроить Goal/Cycle 2/Cycle 3 — изменить маршрут без полного перезапуска' \
      '9 Настроить AI — выбрать основных исполнителей и AI-помощников' \
      'u Утилиты проекта — secrets, tracker, gates, GitHub и validation' \
      'p Выбрать другой SDLC Project' \
      'l Локальные репозитории — clone, setup, build и local run' \
      'g Настройки launcher-а — каталоги, интерфейс и общие параметры' \
      "v $next_view" '? Пояснить действие' 'q Завершить launcher'
  fi
}

render_action_help() {
  case "${1:-}" in
    cycle)
      printf '%s\n' \
        'Результат: один явно выбранный Cycle.' \
        'Входит: ТОЛЬКО CYCLE 1, либо отдельно Cycle 2, либо отдельно Cycle 3.' \
        'Не входит: остальные циклы и режим цели.' \
        'Сейчас: выбор ничего не запускает.' \
        'Далее: Проверка запуска покажет проект, шаги, AI и исключённый scope.' ;;
    *)
      printf '%s\n' \
        'Результат: действие из Project Console.' \
        'Входит: только явно показанный scope.' \
        'Не входит: скрытые действия и silent fallback.' \
        'Сейчас: справка ничего не запускает и не изменяет.' \
        'Далее: вернуться в Console и выбрать действие.' ;;
  esac
}

dispatch_console_action() {
  case "${1:-}" in
    0) menu_unfinished_run ;;
    1) menu_kickoff ;;
    2) menu_project_overview ;;
    3) menu_project_review ;;
    4) menu_project_repair ;;
    5) run_goal_mode selected ;;
    6) menu_cycle_select ;;
    7) menu_single_agent ;;
    8) menu_goal_profile ;;
    9) menu_ai_assignment ;;
    u) menu_utilities ;;
    p) project_selector ;;
    l) menu_local_repositories ;;
    g) menu_launcher_settings ;;
    v) toggle_ui_view >/dev/null ;;
    \?) render_action_help console ;;
    q|Q) return 2 ;;
    *) return 1 ;;
  esac
}

# ─── frozen execution preview ────────────────────────────────────────────────
preview_route_label() {
  case "${AGENT_RUNTIME:-}" in
    claude) printf 'Claude / external CLI\n' ;;
    codex) printf 'Codex / external CLI\n' ;;
    gemini) printf 'Gemini / external CLI\n' ;;
    local)
      [[ -n "${LOCAL_AGENT_HOST:-}" && -n "${LOCAL_MODEL_PROVIDER:-}" && -n "${LOCAL_MODEL:-}" ]] || return 1
      printf 'Local / %s / %s / %s\n' "$LOCAL_AGENT_HOST" "$LOCAL_MODEL_PROVIDER" "$LOCAL_MODEL"
      ;;
    *) return 1 ;;
  esac
}

render_execution_preview() {
  local type="${1:-ACTION}" scope="${2:-не указан}" excluded="${3:-не указан}"
  local saved_profile entry agent task route source idx=0
  saved_profile="$(current_profile)"
  if [[ "${USE_EXISTING_FROZEN_ROUTES:-0}" != 1 ]]; then
    freeze_execution_routes >/dev/null 2>&1 || true
  fi
  printf '%s\n' 'ПРОВЕРКА ЗАПУСКА'
  printf 'TYPE:     %s\nPROJECT:  %s\nPATH:     %s\nSCOPE:    %s\nEXCLUDED: %s\n' \
    "$type" "$PROJECT" "$(project_path)" "$scope" "$excluded"
  printf 'Fallback OFF\n\n'
  printf 'ORDERED STEPS:\n'
  for entry in "${RUN_CYCLE[@]:-}"; do
    [[ -n "$entry" ]] || continue
    agent="${entry%%:*}"
    task="${entry#*:}"
    if [[ -n "${EXECUTION_STEP_PROFILES[$idx]:-}" ]] &&
       apply_profile "${EXECUTION_STEP_PROFILES[$idx]}" >/dev/null 2>&1; then
      route="$(preview_route_label 2>/dev/null || printf 'BLOCKED: incomplete route')"
      source="${EXECUTION_STEP_SOURCES[$idx]:-unknown}"
    else
      route='BLOCKED: route is not configured'
      source='missing'
      EXECUTION_PREVIEW_BLOCKED=1
    fi
    if [[ "${SDLC_SUBAGENTS:-off}" == "cross-runtime" ]]; then
      local worker_label
      worker_label="$(subagent_profile_label 2>/dev/null || printf 'BLOCKED: incomplete worker')"
      [[ "$worker_label" == BLOCKED:* ]] && EXECUTION_PREVIEW_BLOCKED=1
      printf '  - %s | %s | supervisor=%s | source=%s | worker=%s | tasks=%s | max=%s | verify=supervisor\n' \
        "$agent" "$task" "$route" "$source" "$worker_label" \
        "${SDLC_SUBAGENT_TASKS:-missing}" "${SDLC_SUBAGENT_MAX:-?}"
    else
      printf '  - %s | %s | %s | source=%s | subagents=%s/%s\n' \
        "$agent" "$task" "$route" "$source" "${SDLC_SUBAGENTS:-?}" "${SDLC_SUBAGENT_MAX:-?}"
    fi
    idx=$((idx + 1))
  done
  apply_profile "$saved_profile" >/dev/null 2>&1 || true
  printf '\nNo action has run yet.\n'
}

confirm_execution_preview() {
  local executor="$1" choice
  printf '%s\n' 'r Запустить точно этот план' 'b Назад без запуска' '? Пояснить безопасность'
  read -r choice
  case "$choice" in
    r|R)
      if [[ "${EXECUTION_PREVIEW_BLOCKED:-0}" -ne 0 ]]; then
        echo 'BLOCKED: execution routes/models are incomplete.'
        return 1
      fi
      "$executor"
      ;;
    \?) render_action_help preview; return 1 ;;
    b|B|q|Q|'') return 1 ;;
    *) return 1 ;;
  esac
}

# ─── project-local Execution Journal ─────────────────────────────────────────
journal_root() {
  local project="${1:-$PROJECT}"
  printf '%s/%s/tracking/execution-journal\n' "$PROJECTS" "$project"
}

journal_run_dir() {
  local project="$1" run_id="$2"
  printf '%s/runs/%s\n' "$(journal_root "$project")" "$run_id"
}

journal_json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}

journal_yaml_quote() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '"%s"' "$value"
}

journal_yaml_unquote() {
  local value="${1:-}"
  if [[ "$value" == \"*\" ]]; then
    value="${value#\"}"
    value="${value%\"}"
    value="${value//\\r/$'\r'}"
    value="${value//\\n/$'\n'}"
    value="${value//\\\"/\"}"
    value="${value//\\\\/\\}"
  fi
  printf '%s' "$value"
}

journal_append_event() {
  local run_id="$1" event="$2" status="$3" step="${4:-0}" step_status="${5:-UNKNOWN}"
  local agent="${6:-}" task="${7:-}" evidence="${8:-}" dir
  dir="$(journal_run_dir "$PROJECT" "$run_id")"
  [[ -d "$dir" ]] || return 1
  printf '{"time":"%s","event":"%s","status":"%s","step":%s,"step_status":"%s","agent":"%s","task":"%s","evidence":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(journal_json_escape "$event")" "$(journal_json_escape "$status")" \
    "${step:-0}" "$(journal_json_escape "$step_status")" \
    "$(journal_json_escape "$agent")" "$(journal_json_escape "$task")" \
    "$(journal_json_escape "$evidence")" >> "$dir/events.jsonl"
}

journal_write_state() {
  local run_id="$1" status="$2" step="${3:-0}" total="${4:-0}"
  local step_status="${5:-UNKNOWN}" current="${6:-}" dir tmp
  dir="$(journal_run_dir "$PROJECT" "$run_id")"
  [[ -d "$dir" ]] || return 1
  tmp="$(mktemp "$dir/state.md.tmp.XXXXXX")" || return 1
  {
    printf '%s\n' '---'
    printf 'run_id: %s\nproject: %s\nstatus: %s\nstep: %s\ntotal: %s\nstep_status: %s\ncurrent: %s\nupdated_at: %s\n' \
      "$run_id" "$(journal_yaml_quote "$PROJECT")" "$status" "$step" "$total" "$step_status" \
      "$(journal_yaml_quote "$current")" \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' '---' '' '# Execution state'
  } > "$tmp"
  mv "$tmp" "$dir/state.md"
}

journal_ensure_root() {
  local root readme tmp
  root="$(journal_root "$PROJECT")"
  readme="$root/README.md"
  mkdir -p "$root/runs"
  [[ -f "$readme" ]] && return 0
  tmp="$(mktemp "$root/README.md.tmp.XXXXXX")" || return 1
  printf '%s\n' \
    '# Execution Journal' '' \
    'Project-local, runtime-neutral orchestration evidence.' \
    'Each run has an immutable plan, atomic state and append-only events.' \
    'Interrupted/unknown work is never treated as success.' > "$tmp"
  mv "$tmp" "$readme"
}

journal_create_run() {
  local type="$1" scope="$2" excluded="$3" dir entry idx=0 agent task plan_tmp
  local stamp goal_revision='none'
  if [[ "${USE_EXISTING_FROZEN_ROUTES:-0}" == 1 ]]; then
    [[ ${#EXECUTION_STEP_PROFILES[@]} -eq ${#RUN_CYCLE[@]} ]] || return 1
  else
    freeze_execution_routes || return 1
  fi
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  CURRENT_RUN_ID="$stamp-${BASHPID:-$$}-$RANDOM"
  dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  journal_ensure_root || return 1
  mkdir -p "$dir"
  plan_tmp="$(mktemp "$dir/plan.md.tmp.XXXXXX")" || return 1
  if [[ -f "$(goal_profile_path)" ]]; then
    goal_revision="$(awk -F': ' '$1 == "revision" { print $2; exit }' "$(goal_profile_path)")"
    goal_revision="${goal_revision:-unknown}"
  fi
  {
    printf '%s\n' '---'
    printf 'run_id: %s\nproject: %s\nproject_path: %s\ntype: %s\nscope: %s\nexcluded: %s\n' \
      "$CURRENT_RUN_ID" "$(journal_yaml_quote "$PROJECT")" "$(journal_yaml_quote "$(project_path)")" \
      "$type" "$(journal_yaml_quote "$scope")" "$(journal_yaml_quote "$excluded")"
    printf 'runtime_routing: %s\nsubagents: %s\nsubagent_max: %s\nsubagent_profile: %s\nsubagent_tasks: %s\ncreated_at: %s\n' \
      "${SDLC_RUNTIME_ROUTING:-}" "${SDLC_SUBAGENTS:-}" "${SDLC_SUBAGENT_MAX:-}" \
      "${SDLC_SUBAGENT_PROFILE:-none}" "${SDLC_SUBAGENT_TASKS:-none}" \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'goal_profile_revision: %s\ntdd_cycle1: %s\ntdd_cycle2: %s\ntdd_cycle3: %s\n' \
      "$goal_revision" "$(read_cycle_tdd_status 1 2>/dev/null || printf 'UNKNOWN')" \
      "$(read_cycle_tdd_status 2 2>/dev/null || printf 'UNKNOWN')" \
      "$(read_cycle_tdd_status 3 2>/dev/null || printf 'UNKNOWN')"
    printf '%s\n' '---' '' '# Frozen execution plan' ''
    for entry in "${RUN_CYCLE[@]:-}"; do
      [[ -n "$entry" ]] || continue
      idx=$((idx + 1))
      agent="${entry%%:*}"
      task="${entry#*:}"
      printf '%s. %s\n' "$idx" "$entry"
      printf 'step_%s_agent: %s\nstep_%s_task: %s\nstep_%s_profile: %s\nstep_%s_route_source: %s\n' \
        "$idx" "$agent" "$idx" "$task" "$idx" "${EXECUTION_STEP_PROFILES[$((idx - 1))]}" \
        "$idx" "${EXECUTION_STEP_SOURCES[$((idx - 1))]}"
    done
  } > "$plan_tmp"
  mv "$plan_tmp" "$dir/plan.md"
  : > "$dir/events.jsonl"
  journal_write_state "$CURRENT_RUN_ID" PLANNED 0 "$idx" PENDING ''
  journal_append_event "$CURRENT_RUN_ID" run_created PLANNED 0 PENDING '' '' 'immutable plan snapshot created'
}

journal_process_start() {
  local pid="$1" stat rest
  [[ -r "/proc/$pid/stat" ]] || return 1
  IFS= read -r stat < "/proc/$pid/stat" || return 1
  rest="${stat##*) }"
  awk '{print $20}' <<< "$rest"
}

journal_acquire_lease() {
  local run_id="$1" dir lease existing_pid existing_start live_start own_start
  dir="$(journal_run_dir "$PROJECT" "$run_id")"
  lease="$dir/lease"
  if [[ -f "$lease" ]]; then
    existing_pid="$(awk -F': ' '$1 == "pid" { print $2; exit }' "$lease")"
    existing_start="$(awk -F': ' '$1 == "pid_start" { print $2; exit }' "$lease")"
    if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
      live_start="$(journal_process_start "$existing_pid" 2>/dev/null || true)"
      [[ -n "$existing_start" && "$existing_start" == "$live_start" ]] && return 1
    fi
  fi
  own_start="$(journal_process_start "$$" 2>/dev/null || true)"
  printf 'project: %s\nrun_id: %s\npid: %s\npid_start: %s\nstarted_at: %s\n' \
    "$(journal_yaml_quote "$PROJECT")" "$run_id" "$$" "$own_start" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$lease"
}

journal_release_lease() {
  local run_id="$1" lease
  lease="$(journal_run_dir "$PROJECT" "$run_id")/lease"
  [[ -f "$lease" ]] || return 0
  : > "$lease"
}

journal_latest_unfinished() {
  local project="${1:-$PROJECT}" root state status newest=''
  root="$(journal_root "$project")/runs"
  [[ -d "$root" ]] || return 1
  while IFS= read -r -d '' state; do
    status="$(awk -F': ' '$1 == "status" { print $2; exit }' "$state")"
    case "$status" in COMPLETED|CANCELLED) continue ;; esac
    newest="$(basename "$(dirname "$state")")"
  done < <(find "$root" -mindepth 2 -maxdepth 2 -name state.md -print0 2>/dev/null | sort -z)
  [[ -n "$newest" ]] || return 1
  printf '%s\n' "$newest"
}

journal_mark_interrupted_runs() {
  local root state status run_id step total current lease lease_pid lease_start live_start
  root="$(journal_root "$PROJECT")/runs"
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' state; do
    status="$(awk -F': ' '$1 == "status" { print $2; exit }' "$state")"
    [[ "$status" == RUNNING ]] || continue
    run_id="$(basename "$(dirname "$state")")"
    lease="$(journal_run_dir "$PROJECT" "$run_id")/lease"
    if [[ -s "$lease" ]]; then
      lease_pid="$(awk -F': ' '$1 == "pid" { print $2; exit }' "$lease")"
      lease_start="$(awk -F': ' '$1 == "pid_start" { print $2; exit }' "$lease")"
      live_start="$(journal_process_start "$lease_pid" 2>/dev/null || true)"
      [[ "$lease_pid" =~ ^[0-9]+$ && -n "$lease_start" && "$lease_start" == "$live_start" ]] && continue
    fi
    step="$(awk -F': ' '$1 == "step" { print $2; exit }' "$state")"
    total="$(awk -F': ' '$1 == "total" { print $2; exit }' "$state")"
    current="$(awk -F': ' '$1 == "current" { sub(/^[^:]*: /, ""); print; exit }' "$state")"
    current="$(journal_yaml_unquote "$current")"
    journal_write_state "$run_id" INTERRUPTED "${step:-0}" "${total:-0}" UNKNOWN "$current"
    journal_append_event "$run_id" stale_run_detected INTERRUPTED "${step:-0}" UNKNOWN '' '' 'previous RUNNING state has no live launcher'
  done < <(find "$root" -mindepth 2 -maxdepth 2 -name state.md -print0 2>/dev/null)
}

journal_resume_point() {
  local project="$1" run_id="$2" events last=0 step event
  events="$(journal_run_dir "$project" "$run_id")/events.jsonl"
  [[ -f "$events" ]] || return 1
  while IFS= read -r event; do
    [[ "$event" =~ ^\{\"time\":\"[^\"]*\",\"event\":\"(step_succeeded|step_skipped)\",\"status\":\"[^\"]*\",\"step\":([0-9]+), ]] || continue
    step="${BASH_REMATCH[2]}"
    [[ "$step" =~ ^[0-9]+$ ]] && (( step > last )) && last="$step"
  done < "$events"
  printf '%s\n' "$((last + 1))"
}

expand_path() {
  local value="$1"
  [[ "$value" == "~" ]] && value="$HOME"
  [[ "$value" == "~/"* ]] && value="$HOME/${value#~/}"
  echo "$value"
}

normalize_runtime() {
  local runtime="${1:-}"
  [[ -z "$runtime" ]] && return 1
  runtime="${runtime,,}"
  case "$runtime" in
    claude|codex|gemini|local) echo "$runtime" ;;
    *) return 1 ;;
  esac
}

init_runtime() {
  local requested="${1:-${AGENT_RUNTIME:-}}"
  local normalized
  if ! normalized="$(normalize_runtime "$requested")"; then
    [[ -n "$requested" ]] && echo -e "${R}Неизвестный runtime: ${requested}${N}"
    [[ -n "$requested" ]] && echo -e "Ожидается: ${C}claude${N}, ${C}codex${N}, ${C}gemini${N} или ${C}local${N}"
    return 1
  fi
  AGENT_RUNTIME="$normalized"
  export AGENT_RUNTIME
}

runtime_label() {
  case "$AGENT_RUNTIME" in
    claude) echo "Claude" ;;
    codex) echo "Codex" ;;
    gemini) echo "Gemini" ;;
    local) echo "Local model" ;;
    "") echo "не выбран" ;;
    *) echo "$AGENT_RUNTIME" ;;
  esac
}

runtime_bin() {
  case "$AGENT_RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
    local)
      if [[ -n "${LOCAL_AGENT_HOST:-}" ]]; then
        echo "$AGENTS/_runtimes/local-hosts/$LOCAL_AGENT_HOST"
      else
        echo "не выбран"
      fi
      ;;
    *) echo "" ;;
  esac
}

ensure_runtime_available() {
  local bin
  if [[ -z "${AGENT_RUNTIME:-}" ]]; then
    echo -e "${R}Runtime не выбран.${N}"
    return 1
  fi
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    if [[ -z "${LOCAL_AGENT_HOST:-}" || -z "${LOCAL_MODEL_PROVIDER:-}" || -z "${LOCAL_MODEL:-}" ]]; then
      echo -e "${R}Local runtime требует явные agent host, provider и model id.${N}"
      return 1
    fi
    if [[ ! "$LOCAL_AGENT_HOST" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo -e "${R}Недопустимый id local agent host: $LOCAL_AGENT_HOST${N}"
      return 1
    fi
    bin="${LOCAL_HOST_REGISTRY:-$AGENTS/_runtimes/local-hosts}/$LOCAL_AGENT_HOST"
    if [[ ! -f "$bin" || ! -x "$bin" ]]; then
      echo -e "${R}Local agent host '$LOCAL_AGENT_HOST' не зарегистрирован или не исполняемый: $bin${N}"
      return 1
    fi
    if [[ "$LOCAL_AGENT_HOST" == "codex-oss" ]] && ! command -v "${LOCAL_CODEX_BIN:-codex}" >/dev/null 2>&1; then
      echo -e "${R}codex-oss требует Codex CLI (${LOCAL_CODEX_BIN:-codex}).${N}"
      return 1
    fi
    return 0
  fi
  bin="$(runtime_bin)"
  if [[ -z "$bin" ]] || ! command -v "$bin" >/dev/null 2>&1; then
    echo -e "${R}Runtime '${AGENT_RUNTIME}' выбран, но команда '${bin}' не найдена в PATH.${N}"
    echo -e "Установи CLI, выбери другой runtime в настройках или задай ${W}${AGENT_RUNTIME^^}_BIN${N}."
    return 1
  fi
}

load_runtime() {
  local configured=""
  if [[ -n "${AGENT_RUNTIME:-}" ]]; then
    configured="$AGENT_RUNTIME"
  else
    configured="$(read_config_value AGENT_RUNTIME || true)"
  fi
  [[ -n "$configured" ]] && init_runtime "$configured" || return 1

  [[ -n "${LOCAL_AGENT_HOST:-}" ]] || LOCAL_AGENT_HOST="$(read_config_value LOCAL_AGENT_HOST || true)"
  [[ -n "${LOCAL_MODEL_PROVIDER:-}" ]] || LOCAL_MODEL_PROVIDER="$(read_config_value LOCAL_MODEL_PROVIDER || true)"
  [[ -n "${LOCAL_MODEL:-}" ]] || LOCAL_MODEL="$(read_config_value LOCAL_MODEL || true)"
  [[ -n "${LOCAL_MODEL_ENDPOINT:-}" ]] || LOCAL_MODEL_ENDPOINT="$(read_config_value LOCAL_MODEL_ENDPOINT || true)"
  [[ -n "${SDLC_SUBAGENTS:-}" ]] || SDLC_SUBAGENTS="$(read_config_value SDLC_SUBAGENTS || true)"
  [[ -n "${SDLC_SUBAGENT_MAX:-}" ]] || SDLC_SUBAGENT_MAX="$(read_config_value SDLC_SUBAGENT_MAX || true)"
  [[ -n "${SDLC_SUBAGENT_PROFILE:-}" ]] || SDLC_SUBAGENT_PROFILE="$(read_config_value SDLC_SUBAGENT_PROFILE || true)"
  [[ -n "${SDLC_SUBAGENT_TASKS:-}" ]] || SDLC_SUBAGENT_TASKS="$(read_config_value SDLC_SUBAGENT_TASKS || true)"
  [[ -n "${SDLC_RUNTIME_ROUTING:-}" ]] || SDLC_RUNTIME_ROUTING="$(read_config_value SDLC_RUNTIME_ROUTING || true)"
  export LOCAL_AGENT_HOST LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_MODEL_ENDPOINT
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS SDLC_RUNTIME_ROUTING
}

configure_local_profile() {
  local persist="${1:-yes}" host provider model endpoint
  echo
  echo -e "${W}Local agent host${N} — зарегистрированный адаптер из _runtimes/local-hosts/"
  echo -e "  Встроенный: ${C}codex-oss${N} (Ollama или LM Studio)"
  read -rp "Agent host id: " host
  [[ "$host" =~ ^[A-Za-z0-9._-]+$ ]] || { echo -e "${R}Некорректный host id${N}"; return 1; }

  if [[ "$host" == "codex-oss" ]]; then
    read -rp "Provider [ollama/lmstudio]: " provider
    [[ "$provider" == "ollama" || "$provider" == "lmstudio" ]] || {
      echo -e "${R}codex-oss поддерживает provider ollama или lmstudio${N}"
      return 1
    }
    endpoint=""
  else
    read -rp "Provider id (например openai-compatible/vllm/llama.cpp): " provider
    read -rp "Endpoint URL (без токена): " endpoint
    [[ -n "$endpoint" ]] || { echo -e "${R}Endpoint для custom host обязателен${N}"; return 1; }
  fi
  read -rp "Точный model id: " model
  for value in "$provider" "$model" "$endpoint"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'|'* && "$value" != *'"'* ]] || {
      echo -e "${R}Недопустимые символы в local profile${N}"
      return 1
    }
  done
  [[ -n "$provider" && -n "$model" ]] || { echo -e "${R}Provider и точный model id обязательны${N}"; return 1; }

  LOCAL_AGENT_HOST="$host"
  LOCAL_MODEL_PROVIDER="$provider"
  LOCAL_MODEL="$model"
  LOCAL_MODEL_ENDPOINT="$endpoint"
  export LOCAL_AGENT_HOST LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_MODEL_ENDPOINT
  if [[ "$persist" == "yes" ]]; then
    write_config_value LOCAL_AGENT_HOST "$LOCAL_AGENT_HOST"
    write_config_value LOCAL_MODEL_PROVIDER "$LOCAL_MODEL_PROVIDER"
    write_config_value LOCAL_MODEL "$LOCAL_MODEL"
    write_config_value LOCAL_MODEL_ENDPOINT "$LOCAL_MODEL_ENDPOINT"
  fi
}

select_runtime() {
  local allow_back="${1:-yes}"
  local choice prompt_suffix
  while true; do
    header
    if [[ "$FIRST_RUN_WIZARD" == "1" ]]; then
      render_first_run_step 1 "Как запускать AI agents?"
    else
      echo -e "${W}── Runtime AI-вендора ───────────────────────────────${N}"
      echo
    fi
    echo -e "Текущий runtime: ${C}$(runtime_label)${N}${AGENT_RUNTIME:+ ($AGENT_RUNTIME)}"
    echo
    echo -e "  ${Y}1)${N} Claude"
    echo -e "     Claude Code CLI выполняет выбранные agents"
    echo -e "  ${Y}2)${N} Codex"
    echo -e "     Codex CLI выполняет выбранные agents"
    echo -e "  ${Y}3)${N} Gemini"
    echo -e "     Gemini CLI выполняет выбранные agents"
    echo -e "  ${Y}4)${N} Local model (registered agent host)"
    echo -e "     Явные host, provider и точный model id; silent fallback запрещён"
    if [[ "$allow_back" == "yes" ]]; then
      echo -e "  ${Y}b)${N} Назад"
      prompt_suffix="1-4/b"
    else
      prompt_suffix="1-4"
    fi
    echo
    read -rp "$(echo -e "${W}Выбери runtime [${prompt_suffix}]:${N} ")" choice
    case "$choice" in
      1) AGENT_RUNTIME="claude" ;;
      2) AGENT_RUNTIME="codex" ;;
      3) AGENT_RUNTIME="gemini" ;;
      4)
        AGENT_RUNTIME="local"
        configure_local_profile || continue
        ;;
      b|B)
        if [[ "$allow_back" == "yes" ]]; then
          return 1
        fi
        echo -e "${R}Неверный выбор${N}"
        sleep 0.5
        continue
        ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; continue ;;
    esac
    export AGENT_RUNTIME
    write_config_value AGENT_RUNTIME "$AGENT_RUNTIME"
    BASE_PROFILE="$AGENT_RUNTIME|$LOCAL_MODEL_PROVIDER|$LOCAL_MODEL|$LOCAL_AGENT_HOST|$LOCAL_MODEL_ENDPOINT"
    echo
    echo -e "${G}✓ Runtime: ${W}$(runtime_label)${N}"
    ensure_runtime_available || true
    echo
    if [[ "$FIRST_RUN_WIZARD" != "1" ]]; then
      read -rp "$(echo -e "${W}Нажми Enter для продолжения...${N} ")" _
    fi
    return 0
  done
}

ensure_runtime() {
  load_runtime && return 0
  select_runtime no
}

ensure_first_run_runtime() {
  if load_runtime; then
    header
    render_first_run_step 1 "Как запускать AI agents?"
    echo -e "${G}✓ Runtime задан явно: ${W}$(runtime_label)${N}"
    echo
    read -rp "$(echo -e "${W}Нажми Enter, чтобы перейти к Projects...${N} ")" _
    return 0
  fi
  select_runtime no
}

is_sdlc_project_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -d "$dir/stage1-planning" ]] || return 1
  [[ -d "$dir/stage2-requirements" ]] || return 1
  [[ -d "$dir/stage3-design" ]] || return 1
  [[ -d "$dir/stage4-dev" ]] || return 1
  [[ -d "$dir/stage5-testing" ]] || return 1
}

set_project_collection_dir() {
  local dir
  PROJECTS_DIR_NOTE=""
  dir="$(expand_path "$1")"
  [[ -z "$dir" ]] && return 1
  mkdir -p "$dir" || return 1
  PROJECTS="$(cd "$dir" && pwd -P)"
  PROJECTS_MODE="collection"
  SINGLE_PROJECT=""
  export SDLC_PROJECTS_DIR="$PROJECTS"
  unset SDLC_SINGLE_PROJECT
}

set_single_project_dir() {
  local dir project_dir
  PROJECTS_DIR_NOTE=""
  dir="$(expand_path "$1")"
  [[ -z "$dir" ]] && return 1
  if ! is_sdlc_project_dir "$dir"; then
    echo -e "${R}Это не похоже на папку SDLC-проекта: $dir${N}"
    echo -e "Ожидаются stage1-planning ... stage5-testing внутри выбранной папки."
    return 1
  fi
  project_dir="$(cd "$dir" && pwd -P)"
  PROJECTS="$(dirname "$project_dir")"
  SINGLE_PROJECT="$(basename "$project_dir")"
  PROJECTS_MODE="single"
  PROJECTS_DIR_NOTE="Режим: один проект — ${SINGLE_PROJECT}"
  export SDLC_PROJECTS_DIR="$PROJECTS"
  export SDLC_SINGLE_PROJECT="$SINGLE_PROJECT"
}

load_projects_dir() {
  local configured="" mode="" single=""
  if [[ -n "${SDLC_PROJECTS_DIR:-}" ]]; then
    configured="$SDLC_PROJECTS_DIR"
    mode="${SDLC_PROJECTS_MODE:-}"
    single="${SDLC_SINGLE_PROJECT:-}"
  else
    configured="$(read_config_value SDLC_PROJECTS_DIR || true)"
    mode="$(read_config_value SDLC_PROJECTS_MODE || true)"
    single="$(read_config_value SDLC_SINGLE_PROJECT || true)"
  fi
  [[ -z "$configured" ]] && return 1
  case "$mode" in
    single)
      if [[ -n "$single" ]]; then
        set_single_project_dir "$configured/$single"
      else
        set_single_project_dir "$configured"
      fi
      ;;
    collection)
      set_project_collection_dir "$configured"
      ;;
    *)
      if is_sdlc_project_dir "$configured"; then
        set_single_project_dir "$configured"
      else
        set_project_collection_dir "$configured"
      fi
      ;;
  esac
}

configure_projects_dir() {
  local mode input
  while true; do
    header
    if [[ "$FIRST_RUN_WIZARD" == "1" ]]; then
      render_first_run_step 2 "С какими проектами работать?"
    else
      echo -e "${W}── Настройка каталога SDLC-проектов ────────────────${N}"
      echo
    fi
    echo -e "Launcher не выбирает каталог автоматически."
    echo -e "Можно указать каталог с несколькими SDLC-проектами или папку одного проекта."
    [[ -n "${SDLC_PROJECTS_DIR:-}" ]] && echo -e "Текущее значение env: ${C}${SDLC_PROJECTS_DIR}${N}"
    echo
    echo -e "  ${Y}1)${N} Каталог с несколькими проектами"
    echo -e "     Сначала выбирается проект из найденных подпапок; удобно для общей рабочей области."
    echo -e "  ${Y}2)${N} Папка одного проекта"
    echo -e "     Launcher закрепляется за одним проектом; переключение между проектами не требуется."
    echo -e "  ${Y}b)${N} Отмена"
    echo
    read -rp "$(echo -e "${W}Выбери [1-2/b]:${N} ")" mode
    case "$mode" in
      b|B) return 1 ;;
      1|2) ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; continue ;;
    esac

    echo
    if [[ "$mode" == "1" ]]; then
      echo -e "${C}Введи полный путь к каталогу, внутри которого лежат папки проектов.${N}"
    else
      echo -e "${C}Введи полный путь к папке конкретного SDLC-проекта.${N}"
    fi
    read -rp "$(echo -e "${W}Путь (b — отмена):${N} ")" input
    [[ "$input" == "b" || "$input" == "B" ]] && continue
    if [[ -z "$input" ]]; then
      echo -e "${R}Путь обязателен. Launcher не подставляет каталог по умолчанию.${N}"
      sleep 0.8
      continue
    fi

    if [[ "$mode" == "1" ]]; then
      set_project_collection_dir "$input" || { echo -e "${R}Не удалось настроить каталог: $input${N}"; sleep 1; continue; }
    else
      set_single_project_dir "$input" || { sleep 1; continue; }
    fi

    write_config_value SDLC_PROJECTS_DIR "$PROJECTS"
    write_config_value SDLC_PROJECTS_MODE "$PROJECTS_MODE"
    write_config_value SDLC_SINGLE_PROJECT "$SINGLE_PROJECT"
    echo
    [[ -n "${PROJECTS_DIR_NOTE:-}" ]] && echo -e "${Y}${PROJECTS_DIR_NOTE}${N}"
    echo -e "${G}✓ Каталог проектов: ${W}$PROJECTS${N}"
    [[ "$PROJECTS_MODE" == "single" ]] && echo -e "  Активный проект: ${W}$SINGLE_PROJECT${N}"
    echo -e "  Изменить позже: настройки launcher или env ${W}SDLC_PROJECTS_DIR${N}"
    echo
    if [[ "$FIRST_RUN_WIZARD" != "1" ]]; then
      read -rp "$(echo -e "${W}Нажми Enter для продолжения...${N} ")" _
    fi
    return 0
  done
}

ensure_projects_dir() {
  load_projects_dir
  [[ -n "$PROJECTS" ]] && return 0
  configure_projects_dir
}

ensure_first_run_projects_dir() {
  load_projects_dir
  if [[ -n "$PROJECTS" ]]; then
    header
    render_first_run_step 2 "С какими проектами работать?"
    echo -e "${G}✓ Projects заданы явно: ${W}$PROJECTS${N}"
    echo -e "  Режим: ${C}${PROJECTS_MODE}${N}"
    echo
    read -rp "$(echo -e "${W}Нажми Enter, чтобы перейти к выбору View...${N} ")" _
    return 0
  fi
  configure_projects_dir
}

choose_runtime() {
  select_runtime yes
}

current_profile() {
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    printf '%s|%s|%s|%s|%s\n' "$AGENT_RUNTIME" "$LOCAL_MODEL_PROVIDER" \
      "$LOCAL_MODEL" "$LOCAL_AGENT_HOST" "$LOCAL_MODEL_ENDPOINT"
  else
    printf '%s||||\n' "$AGENT_RUNTIME"
  fi
}

apply_profile() {
  local profile="$1" runtime provider model host endpoint extra
  IFS='|' read -r runtime provider model host endpoint extra <<< "$profile"
  [[ -z "$extra" ]] || { echo -e "${R}Некорректный runtime profile${N}"; return 1; }
  init_runtime "$runtime" || return 1
  if [[ "$runtime" == "local" ]]; then
    [[ -n "$provider" && -n "$model" && -n "$host" ]] || {
      echo -e "${R}Local route обязан содержать provider, exact model id и agent host.${N}"
      return 1
    }
    LOCAL_MODEL_PROVIDER="$provider"
    LOCAL_MODEL="$model"
    LOCAL_AGENT_HOST="$host"
    LOCAL_MODEL_ENDPOINT="$endpoint"
  else
    LOCAL_MODEL_PROVIDER=""
    LOCAL_MODEL=""
    LOCAL_AGENT_HOST=""
    LOCAL_MODEL_ENDPOINT=""
  fi
  export AGENT_RUNTIME LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_AGENT_HOST LOCAL_MODEL_ENDPOINT
  ensure_runtime_available
}

select_step_profile() {
  local choice
  echo
  echo -e "${W}Профиль runtime для шага${N}"
  echo -e "  ${Y}1)${N} Claude"
  echo -e "  ${Y}2)${N} Codex"
  echo -e "  ${Y}3)${N} Gemini"
  echo -e "  ${Y}4)${N} Local model"
  read -rp "Выбери [1-4]: " choice
  case "$choice" in
    1) AGENT_RUNTIME="claude" ;;
    2) AGENT_RUNTIME="codex" ;;
    3) AGENT_RUNTIME="gemini" ;;
    4)
      AGENT_RUNTIME="local"
      configure_local_profile no || return 1
      ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  export AGENT_RUNTIME
  SELECTED_PROFILE="$(current_profile)"
  apply_profile "$SELECTED_PROFILE"
}

select_routing_policy() {
  local allow_back="${1:-yes}" choice prompt_range
  while true; do
    header
    echo -e "${W}── Маршрутизация runtime ─────────────────────────────${N}"
    echo
    echo -e "  ${Y}1)${N} single — один явно выбранный профиль"
    echo -e "  ${Y}2)${N} per-stage — профиль для каждого этапа"
    echo -e "  ${Y}3)${N} per-agent — профиль для каждого агента"
    echo -e "  ${Y}4)${N} ask — спрашивать перед каждым шагом"
    [[ "$allow_back" == "yes" ]] && echo -e "  ${Y}b)${N} Назад"
    echo
    [[ "$allow_back" == "yes" ]] && prompt_range="1-4/b" || prompt_range="1-4"
    read -rp "Выбери [$prompt_range]: " choice
    case "$choice" in
      1) SDLC_RUNTIME_ROUTING="single" ;;
      2) SDLC_RUNTIME_ROUTING="per-stage" ;;
      3) SDLC_RUNTIME_ROUTING="per-agent" ;;
      4) SDLC_RUNTIME_ROUTING="ask" ;;
      b|B) [[ "$allow_back" == "yes" ]] && return 1 ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; continue ;;
    esac
    export SDLC_RUNTIME_ROUTING
    write_config_value SDLC_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
    return 0
  done
}

ensure_routing_policy() {
  case "${SDLC_RUNTIME_ROUTING:-}" in
    single|per-stage|per-agent|ask) return 0 ;;
    "") select_routing_policy no ;;
    *) echo -e "${R}Некорректный SDLC_RUNTIME_ROUTING: $SDLC_RUNTIME_ROUTING${N}"; return 1 ;;
  esac
}

configure_subagent_settings() {
  local context="${1:-standalone}" choice max
  echo
  render_subagent_mode_choice "$context"
  read -rp "Выбери [1-3]: " choice
  case "$choice" in
    1)
      SDLC_SUBAGENTS="off"
      max="${SDLC_SUBAGENT_MAX:-2}"
      SDLC_SUBAGENT_PROFILE=""
      SDLC_SUBAGENT_TASKS=""
      ;;
    2)
      SDLC_SUBAGENTS="auto"
      read -rp "Максимум subagents [1-16]: " max
      SDLC_SUBAGENT_PROFILE=""
      SDLC_SUBAGENT_TASKS=""
      ;;
    3)
      configure_cross_runtime_subagents || return 1
      return 0
      ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  valid_menu_index "$max" 16 || {
    echo -e "${R}Допустимо целое число 1..16${N}"
    return 1
  }
  SDLC_SUBAGENT_MAX="$max"
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS
  write_config_value SDLC_SUBAGENTS "$SDLC_SUBAGENTS"
  write_config_value SDLC_SUBAGENT_MAX "$SDLC_SUBAGENT_MAX"
  write_config_value SDLC_SUBAGENT_PROFILE "$SDLC_SUBAGENT_PROFILE"
  write_config_value SDLC_SUBAGENT_TASKS "$SDLC_SUBAGENT_TASKS"
}

render_subagent_mode_choice() {
  local context="${1:-standalone}"
  if [[ "$context" == "first-run" ]]; then
    echo -e "${W}Шаг 2 из 2 — AI-помощники${N}"
  else
    echo -e "${W}AI-помощники${N}"
  fi
  echo -e "${W}Нужны ли основному исполнителю AI-помощники?${N}"
  echo
  echo "Помощник получает только ограниченную задачу: например, провести анализ,"
  echo "исследование, ревью или помочь интерпретировать тесты. Он работает в режиме"
  echo "только чтения, не изменяет файлы проекта и не закрывает quality gates."
  echo "Основной исполнитель проверяет результат помощника и отвечает за итог этапа."
  echo "Этот выбор не добавляет и не убирает этапы. Сейчас ничего не запускается."
  echo
  echo -e "  ${Y}1)${N} Работать без помощников"
  echo "     Все задачи выполняет выбранный основной исполнитель."
  echo
  echo -e "  ${Y}2)${N} Помощники той же AI-системы"
  echo "     Основной исполнитель сможет подключать встроенных read-only помощников,"
  echo "     если выбранная AI-система это поддерживает."
  echo
  echo -e "  ${Y}3)${N} Отдельная AI-модель как помощник"
  echo "     Можно явно выбрать другой runtime и точную модель, например Codex как"
  echo "     основной исполнитель и локальную модель для анализа и ревью."
  echo "     Затем будут запрошены разрешённые задачи и максимум помощников."
}

render_first_run_ai_routing_choice() {
  printf '%s\n' \
    'Шаг 1 из 2 — Основные исполнители' \
    'Какая AI-модель будет выполнять основные этапы проекта?' \
    '' \
    'Основной исполнитель запускает назначенного SDLC Agent, создаёт итоговые файлы проекта и отвечает за результат этапа.' \
    'Выбор определяет, какая AI-модель получит каждую роль, но не меняет состав или порядок SDLC-этапов.' \
    'Сейчас ничего не запускается: назначения будут показаны в Preview перед реальным стартом.' \
    '' \
    '  1) Одна AI-модель для всего проекта' \
    '     Например, Codex выполняет все основные этапы.' \
    '' \
    '  2) Своя AI-модель для каждого цикла' \
    '     Отдельно для разработки, деплоя и эксплуатации.' \
    '' \
    '  3) Настроить исключения для отдельных ролей' \
    '     Сначала выбираются модели по циклам, затем можно назначить другую модель, например, только для Developer или Reviewer.' \
    '' \
    '  4) Спрашивать при подготовке каждого запуска' \
    '     Launcher соберёт назначения для всех нужных шагов до Preview. Это даёт больше контроля, но требует больше ответов.' \
    '' \
    'Следующий шаг: выберем, нужны ли основному исполнителю помощники.'
}

configure_first_run_ai_mode() {
  local choice
  echo
  render_first_run_ai_routing_choice
  read -rp 'Выбери способ [1-4]: ' choice
  case "$choice" in
    1) SDLC_RUNTIME_ROUTING='single'; PENDING_FIRST_RUN_AI_SETUP='' ;;
    2) SDLC_RUNTIME_ROUTING='per-agent'; PENDING_FIRST_RUN_AI_SETUP='cycle' ;;
    3) SDLC_RUNTIME_ROUTING='per-agent'; PENDING_FIRST_RUN_AI_SETUP='matrix' ;;
    4) SDLC_RUNTIME_ROUTING='ask'; PENDING_FIRST_RUN_AI_SETUP='' ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  export SDLC_RUNTIME_ROUTING
  write_config_value SDLC_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
  configure_subagent_settings first-run
}

ensure_subagent_settings() {
  case "${SDLC_SUBAGENTS:-}" in
    off|auto)
      SDLC_SUBAGENT_PROFILE=''
      SDLC_SUBAGENT_TASKS=''
      ;;
    cross-runtime)
      validate_subagent_profile "${SDLC_SUBAGENT_PROFILE:-}" || {
        echo -e "${R}Для cross-runtime нужен точный SDLC_SUBAGENT_PROFILE${N}"
        return 1
      }
      SDLC_SUBAGENT_TASKS="$(normalize_subagent_tasks "${SDLC_SUBAGENT_TASKS:-}")" || {
        echo -e "${R}Некорректный SDLC_SUBAGENT_TASKS${N}"
        return 1
      }
      ;;
    "") configure_subagent_settings || return 1 ;;
    *) echo -e "${R}SDLC_SUBAGENTS должен быть off, auto или cross-runtime${N}"; return 1 ;;
  esac
  valid_menu_index "${SDLC_SUBAGENT_MAX:-}" 16 || {
      echo -e "${R}SDLC_SUBAGENT_MAX должен быть 1..16${N}"
      return 1
    }
}

normalize_subagent_tasks() {
  local raw="${1:-}" item
  local analysis=0 research=0 review=0 test_interpretation=0
  local -a items=() result=()
  [[ -n "$raw" ]] || return 1
  IFS=',' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    case "$item" in
      analysis) analysis=1 ;;
      research) research=1 ;;
      review) review=1 ;;
      test-interpretation) test_interpretation=1 ;;
      *) return 1 ;;
    esac
  done
  (( analysis )) && result+=(analysis)
  (( research )) && result+=(research)
  (( review )) && result+=(review)
  (( test_interpretation )) && result+=(test-interpretation)
  local joined
  joined="$(IFS=,; echo "${result[*]}")"
  [[ -n "$joined" ]] || return 1
  printf '%s\n' "$joined"
}

validate_subagent_profile() {
  local profile="${1:-}" runtime provider model host endpoint extra value
  IFS='|' read -r runtime provider model host endpoint extra <<< "$profile"
  [[ -z "$extra" ]] || return 1
  case "$runtime" in
    claude|codex)
      [[ -z "$provider$model$host$endpoint" ]] || return 1
      ;;
    local)
      [[ -n "$provider" && -n "$model" && -n "$host" ]] || return 1
      [[ "$host" == codex-oss ]] || return 1
      ;;
    *) return 1 ;;
  esac
  for value in "$runtime" "$provider" "$model" "$host" "$endpoint"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'"'* ]] || return 1
  done
}

subagent_profile_label() {
  local profile="${1:-${SDLC_SUBAGENT_PROFILE:-}}" runtime provider model host endpoint
  validate_subagent_profile "$profile" || return 1
  IFS='|' read -r runtime provider model host endpoint <<< "$profile"
  case "$runtime" in
    claude) printf 'Claude / external CLI\n' ;;
    codex) printf 'Codex / external CLI\n' ;;
    local) printf 'Local / %s / %s / %s\n' "$host" "$provider" "$model" ;;
  esac
}

render_subagent_execution_summary() {
  local supervisor worker
  supervisor="$(preview_route_label 2>/dev/null || printf 'BLOCKED: incomplete supervisor')"
  worker="$(subagent_profile_label 2>/dev/null || printf 'BLOCKED: incomplete worker')"
  printf '  Supervisor: %s\n' "$supervisor"
  printf '  Worker: %s\n' "$worker"
  printf '  Worker tasks: %s\n' "${SDLC_SUBAGENT_TASKS:-не настроены}"
  printf '%s\n' '  Verification: supervisor always verifies' '  Worker fallback: OFF'
}

configure_cross_runtime_subagents() {
  local supervisor_profile worker_profile task_choice max
  supervisor_profile="$(current_profile)"
  echo
  echo -e "${W}Worker profile${N} — отдельная модель только для ограниченных задач чтения."
  echo -e "  Поддержаны: Claude, Codex или Local codex-oss; для них launcher принудительно запрещает запись."
  echo -e "  Gemini и произвольные local-host здесь недоступны: их read-only режим пока нельзя гарантировать."
  select_step_profile || { apply_profile "$supervisor_profile" >/dev/null 2>&1 || true; return 1; }
  worker_profile="$SELECTED_PROFILE"
  apply_profile "$supervisor_profile" || return 1
  validate_subagent_profile "$worker_profile" || {
    echo -e "${R}Выбранный профиль нельзя безопасно использовать как read-only worker.${N}"
    return 1
  }
  echo
  echo -e "  ${Y}1)${N} Все безопасные read-only задачи"
  echo -e "  ${Y}2)${N} Analysis + research"
  echo -e "  ${Y}3)${N} Review + test-result interpretation"
  read -rp "Worker task policy [1-3]: " task_choice
  case "$task_choice" in
    1) SDLC_SUBAGENT_TASKS='analysis,research,review,test-interpretation' ;;
    2) SDLC_SUBAGENT_TASKS='analysis,research' ;;
    3) SDLC_SUBAGENT_TASKS='review,test-interpretation' ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  read -rp "Максимум одновременных workers [1-16]: " max
  valid_menu_index "$max" 16 || {
    echo -e "${R}Допустимо целое число 1..16${N}"
    return 1
  }
  SDLC_SUBAGENTS='cross-runtime'
  SDLC_SUBAGENT_MAX="$max"
  SDLC_SUBAGENT_PROFILE="$worker_profile"
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS
  write_config_value SDLC_SUBAGENTS "$SDLC_SUBAGENTS"
  write_config_value SDLC_SUBAGENT_MAX "$SDLC_SUBAGENT_MAX"
  write_config_value SDLC_SUBAGENT_PROFILE "$SDLC_SUBAGENT_PROFILE"
  write_config_value SDLC_SUBAGENT_TASKS "$SDLC_SUBAGENT_TASKS"
  echo -e "${G}✓ Supervisor + Worker настроен${N}"
  [[ "$FIRST_RUN_WIZARD" == "1" ]] || render_subagent_execution_summary
}

write_routing_entry() {
  local key="$1" profile="$2" tmp
  [[ "$key" =~ ^(stage:s[0-9]|agent:[A-Za-z0-9._-]+)$ ]] || {
    echo -e "${R}Route key должен быть stage:sN или agent:agent-id${N}"
    return 1
  }
  [[ "$profile" != *$'\n'* && "$profile" != *$'\r'* ]] || return 1
  mkdir -p "$CONFIG_DIR"
  mkdir -p "$(dirname "$ROUTING_FILE")"
  chmod 700 "$CONFIG_DIR"
  tmp="$(mktemp "${ROUTING_FILE}.tmp.XXXXXX")" || return 1
  if [[ -f "$ROUTING_FILE" ]]; then
    awk -F= -v key="$key" -v value="$profile" '
      BEGIN { written=0 }
      $1 == key { print key "=" value; written=1; next }
      { print }
      END { if (!written) print key "=" value }
    ' "$ROUTING_FILE" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$profile" > "$tmp"
  fi
  chmod 600 "$tmp"
  mv "$tmp" "$ROUTING_FILE"
  chmod 600 "$ROUTING_FILE"
}

configure_runtime_route() {
  local key
  echo
  read -rp "Route key (stage:s2 или agent:s4-dev): " key
  select_step_profile || return 1
  write_routing_entry "$key" "$SELECTED_PROFILE" || return 1
  echo -e "${G}✓ $key → $SELECTED_PROFILE${N}"
  apply_profile "$BASE_PROFILE" || return 1
}

lookup_route() {
  local key="$1"
  [[ -f "$ROUTING_FILE" ]] || return 1
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ROUTING_FILE"
}

stage_for_agent() {
  local agent="$1"
  case "$agent" in
    s[0-9]-*) echo "${agent%%-*}" ;;
    l[0-9]-*) echo "localrun" ;;
    *) echo "tools" ;;
  esac
}

resolve_step_runtime() {
  local agent="$1" key profile
  case "$SDLC_RUNTIME_ROUTING" in
    single)
      apply_profile "$BASE_PROFILE"
      ;;
    per-stage)
      key="stage:$(stage_for_agent "$agent")"
      profile="$(lookup_route "$key" || true)"
      [[ -n "$profile" ]] || {
        echo -e "${R}Нет явного runtime route для $key. Silent fallback запрещён.${N}"
        return 1
      }
      apply_profile "$profile"
      ;;
    per-agent)
      key="agent:$agent"
      profile="$(lookup_route "$key" || true)"
      [[ -n "$profile" ]] || {
        echo -e "${R}Нет явного runtime route для $key. Silent fallback запрещён.${N}"
        return 1
      }
      apply_profile "$profile"
      ;;
    ask)
      select_step_profile
      ;;
    *)
      echo -e "${R}Неизвестная routing policy: $SDLC_RUNTIME_ROUTING${N}"
      return 1
      ;;
  esac
}

project_ai_config_path() {
  local project="${1:-$PROJECT}"
  printf '%s/%s/tracking/ai-routing.conf\n' "$PROJECTS" "$project"
}

save_project_ai_config() {
  local profile="$1" policy="$2" path dir tmp tasks
  case "$policy" in single|per-stage|per-agent|ask) ;; *) return 1 ;; esac
  [[ "$profile" != *$'\n'* && "$profile" != *$'\r'* && "$profile" != *'"'* ]] || return 1
  case "${SDLC_SUBAGENTS:-off}" in
    off|auto) ;;
    cross-runtime)
      validate_subagent_profile "${SDLC_SUBAGENT_PROFILE:-}" || return 1
      tasks="$(normalize_subagent_tasks "${SDLC_SUBAGENT_TASKS:-}")" || return 1
      SDLC_SUBAGENT_TASKS="$tasks"
      ;;
    *) return 1 ;;
  esac
  path="$(project_ai_config_path)"
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  tmp="$(mktemp "$path.tmp.XXXXXX")" || return 1
  printf 'BASE_PROFILE="%s"\nSDLC_RUNTIME_ROUTING="%s"\nSDLC_SUBAGENTS="%s"\nSDLC_SUBAGENT_MAX="%s"\nSDLC_SUBAGENT_PROFILE="%s"\nSDLC_SUBAGENT_TASKS="%s"\n' \
    "$profile" "$policy" "${SDLC_SUBAGENTS:-off}" "${SDLC_SUBAGENT_MAX:-2}" \
    "${SDLC_SUBAGENT_PROFILE:-}" "${SDLC_SUBAGENT_TASKS:-}" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$path"
}

activate_project_ai_config() {
  local path profile policy subagents subagent_max subagent_profile subagent_tasks value
  ROUTING_FILE="$(project_path)/tracking/runtime-routing"
  profile="${LAUNCHER_BASE_PROFILE:-$BASE_PROFILE}"
  policy="${LAUNCHER_ROUTING_POLICY:-${SDLC_RUNTIME_ROUTING:-single}}"
  subagents="${LAUNCHER_SUBAGENTS:-${SDLC_SUBAGENTS:-off}}"
  subagent_max="${LAUNCHER_SUBAGENT_MAX:-${SDLC_SUBAGENT_MAX:-2}}"
  subagent_profile="${LAUNCHER_SUBAGENT_PROFILE:-${SDLC_SUBAGENT_PROFILE:-}}"
  subagent_tasks="${LAUNCHER_SUBAGENT_TASKS:-${SDLC_SUBAGENT_TASKS:-}}"
  path="$(project_ai_config_path)"
  if [[ -f "$path" ]]; then
    profile="$(awk -F= '$1 == "BASE_PROFILE" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    policy="$(awk -F= '$1 == "SDLC_RUNTIME_ROUTING" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    value="$(awk -F= '$1 == "SDLC_SUBAGENTS" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    [[ -z "$value" ]] || subagents="$value"
    value="$(awk -F= '$1 == "SDLC_SUBAGENT_MAX" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    [[ -z "$value" ]] || subagent_max="$value"
    if grep -q '^SDLC_SUBAGENT_PROFILE=' "$path"; then
      subagent_profile="$(awk -F= '$1 == "SDLC_SUBAGENT_PROFILE" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    fi
    if grep -q '^SDLC_SUBAGENT_TASKS=' "$path"; then
      subagent_tasks="$(awk -F= '$1 == "SDLC_SUBAGENT_TASKS" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    fi
  fi
  [[ -n "$profile" ]] || return 1
  case "$policy" in single|per-stage|per-agent|ask) ;; *) return 1 ;; esac
  BASE_PROFILE="$profile"
  SDLC_RUNTIME_ROUTING="$policy"
  SDLC_SUBAGENTS="$subagents"
  SDLC_SUBAGENT_MAX="$subagent_max"
  SDLC_SUBAGENT_PROFILE="$subagent_profile"
  SDLC_SUBAGENT_TASKS="$subagent_tasks"
  ensure_subagent_settings || return 1
  export SDLC_RUNTIME_ROUTING SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS
  apply_profile "$BASE_PROFILE"
}

execution_route_source() {
  local agent="$1"
  case "$SDLC_RUNTIME_ROUTING" in
    single) printf 'single profile\n' ;;
    per-stage) printf 'stage:%s\n' "$(stage_for_agent "$agent")" ;;
    per-agent) printf 'agent:%s\n' "$agent" ;;
    ask) printf 'explicit ASK answer\n' ;;
    *) return 1 ;;
  esac
}

freeze_execution_routes() {
  local saved_profile entry agent
  saved_profile="$(current_profile)"
  EXECUTION_STEP_PROFILES=()
  EXECUTION_STEP_SOURCES=()
  EXECUTION_PREVIEW_BLOCKED=0
  for entry in "${RUN_CYCLE[@]:-}"; do
    [[ -n "$entry" ]] || continue
    agent="${entry%%:*}"
    if ! resolve_step_runtime "$agent"; then
      EXECUTION_PREVIEW_BLOCKED=1
      apply_profile "$saved_profile" >/dev/null 2>&1 || true
      return 1
    fi
    EXECUTION_STEP_PROFILES+=("$(current_profile)")
    EXECUTION_STEP_SOURCES+=("$(execution_route_source "$agent")")
  done
  apply_profile "$saved_profile" >/dev/null 2>&1 || true
}

# ─── агенты: папка → описание ─────────────────────────────────────────────────
declare -A AGENT_DESC=(
  [l1-analyze]="Local Analyzer — изучить структуру проекта с GitHub"
  [l2-setup]="Local Setup — установить зависимости и настроить .env"
  [l3-build]="Local Builder — собрать проект"
  [l4-run]="Local Runner — запустить и проверить проект"
  [s0-kickoff]="Project Kickoff — интервью для нового проекта / обновление беклога"
  [s0-secrets]="Secrets Manager — pass: добавить, ротировать, env"
  [s0-github]="GitHub Sync — init репо, push, pull, PR"
  [s0-validate]="Structure Validator — проверить и починить структуру проекта"
  [s0-tracker]="Sprint & Task Tracker — спринты, задачи, план vs факт"
  [s0-quality-gates]="Quality Gates Configurator — проектные пороги качества из risk-профиля"
  [s1-pm]="Product Manager — Feasibility, Vision, OKR"
  [s1-pmo]="Project Manager — Charter, Risk Register, RACI"
  [s1-finance]="Finance Analyst — ROI, NPV, Business Case"
  [s2-ba]="Business Analyst — BRD, NFR, RTM"
  [s2-po]="Product Owner — User Stories, Backlog"
  [s2-qa-req]="QA Analyst — Testability Review"
  [s2-test-strategy]="QA Strategist — risk-based test-first стратегия"
  [s2-security]="Security Requirements Engineer — abuse cases, классификация данных, ASVS (SG1, shift-left)"
  [s3-arch]="Solution Architect — HLD, ADR, API Spec"
  [s3-security]="Security Engineer — Threat Model"
  [s3-rbac]="RBAC Designer — роли, матрица прав, RLS, SQL схема"
  [s3-dba]="DBA — DB Schema, Migrations"
  [s4-dev]="Backend Developer — Код, PR Summary"
  [s4-qa-auto]="SDET TDD — тесты до кода, Red/PASS и repair verdict"
  [s4-techlead]="Tech Lead — Code Review, Tech Debt"
  [s4-devops]="DevOps Engineer — CI/CD, Runbook"
  [s5-qa]="QA Engineer — Test Plan, Go/No-Go"
  [s5-qa-auto]="QA Automation — E2E/API тесты"
  [s5-perf]="Performance Engineer — Load Tests"
  [s5-security]="Security Test Engineer — DAST, pentest, security-тесты (SG4, tier-aware)"
  [s6-release]="Release Manager — Checklist, Release Notes"
  [s6-sre]="SRE — Post-Deploy, Post-Mortem"
)

# ─── необязательные шаги (можно добавить в Цикл 1) ───────────────────────────
# Формат: "агент|задача|позиция|описание"
# позиция: before — до основного цикла, after — после основного цикла
declare -a OPTIONAL_AGENTS_DEF=(
  "s0-validate|/validate|before|Проверить и починить структуру проекта до старта"
  "s0-secrets|Настрой секреты для проекта|before|Настройка секретов через pass"
  "s0-tracker|/sprint-init|before|Инициализировать спринт перед циклом"
  "s0-validate|/validate|after|Проверить артефакты после завершения цикла"
)

# глобальные массивы — заполняются configure_optional_steps
OPTIONAL_BEFORE=()
OPTIONAL_AFTER=()

# ─── Цикл 1 — Разработка (агент:задача) ───────────────────────────────────────
# Только агенты cycle1-dev/ + сквозные _tools. Деплой/эксплуатация — Циклы 2/3.
declare -a CYCLE1_AGENTS=(
  "s1-pm:/feasibility"
  "s1-pm:/vision"
  "s1-pmo:/charter"
  "s1-pmo:/risks"
  "s1-finance:/business-case"
  "s0-quality-gates:/configure"
  "s2-ba:/extract-requirements"
  "s2-ba:/brd"
  "s2-po:/stories"
  "s2-qa-req:/testability-review"
  "s2-test-strategy:/strategy"
  "s2-security:/security-requirements"
  "s3-arch:/hld"
  "s3-arch:/adr"
  "s3-security:/threat-model"
  "s3-rbac:/rbac-model"
  "s3-dba:/schema"
  "s4-qa-auto:/write-tests"
  "s4-dev:/dev-report"
  "s4-qa-auto:/run-tests"
  "s4-techlead:/review"
  "s5-qa:/test-plan"
  "s5-qa-auto:/e2e-report"
  "s5-perf:/load-test"
  "s5-security:/security-test"
  "s5-qa:/go-no-go"
  "s0-tracker:/report"
  "s0-github:/push"
)

# ─── Цикл 2 — Деплой ──────────────────────────────────────────────────────────
declare -a CYCLE2_AGENTS=(
  "s4-devops:/deploy-intake"
  "s4-devops:/write-deploy-tests"
  "s4-devops:/pipeline"
  "s4-devops:/runbook"
  "s4-devops:/prepare-delivery"
  "s4-devops:/run-deploy-tests"
  "s6-release:/release-notes"
  "s6-release:/release-checklist"
)

# ─── Цикл 3 — Эксплуатация ────────────────────────────────────────────────────
declare -a CYCLE3_AGENTS=(
  "s6-sre:/ops-intake"
  "s6-sre:/write-ops-tests"
  "s6-sre:/configure-ops"
  "s6-sre:/run-ops-tests"
  "s6-sre:/post-deploy"
  "s6-sre:/gate7"
)

# Единый per-project профиль цели Cycle 2/3. Секреты в нём запрещены.
declare -A GOAL_VALUES=()
declare -a CYCLE2_GOAL_KEYS=(
  cycle2_enabled cycle2_goal cycle2_target cycle2_environments
  cycle2_deliverables cycle2_registry_supply_chain cycle2_runtime_packaging
  cycle2_orchestrator cycle2_iac cycle2_cicd cycle2_gitops cycle2_network
  cycle2_data cycle2_capacity_ha cycle2_rollout cycle2_executor
  cycle2_authorization cycle2_validation cycle2_constraints
)
declare -a CYCLE3_GOAL_KEYS=(
  cycle3_enabled cycle3_goal cycle3_operating_environment cycle3_deliverables
  cycle3_monitoring_stack cycle3_slo_error_budget cycle3_logs_traces_retention
  cycle3_alerting_incident cycle3_dedup_capabilities cycle3_playbook_executor
  cycle3_auto_heal_authorization cycle3_backup_dr cycle3_capacity_cost
  cycle3_maintenance cycle3_validation cycle3_reporting cycle3_constraints
)
declare -a CYCLE2_DELIVERABLES=(
  images runtime-bundle orchestrator iac cicd gitops operations-pack execute-deploy custom
)
declare -a CYCLE3_DELIVERABLES=(
  monitoring dashboards alerts runbooks auto-heal backup-dr capacity incident reporting execute-ops custom
)
declare -A DELIVERABLE_LABELS=(
  [images]="Образы + provenance/SBOM/signing"
  [runtime-bundle]="Runtime bundle / package"
  [orchestrator]="Конфигурация оркестратора"
  [iac]="Infrastructure as Code"
  [cicd]="CI/CD pipeline"
  [gitops]="GitOps manifests/config"
  [operations-pack]="Runbook + rollback + handoff"
  [execute-deploy]="Выполнить разрешённый deploy"
  [monitoring]="Monitoring configuration"
  [dashboards]="Dashboards"
  [alerts]="Alerts + routing + dedup"
  [runbooks]="Incident runbooks"
  [auto-heal]="Auto-heal configuration"
  [backup-dr]="Backup / restore / DR"
  [capacity]="Capacity + cost controls"
  [incident]="Incident-management integration"
  [reporting]="Operations reporting"
  [execute-ops]="Выполнять разрешённые ops actions"
  [custom]="Другой явно описанный результат"
)
declare -a ALL_GOAL_KEYS=(
  schema_version revision updated_at updated_by confirmed
  goal_mode revision_reason
  "${CYCLE2_GOAL_KEYS[@]}"
  "${CYCLE3_GOAL_KEYS[@]}"
)
declare -A GOAL_LABELS=(
  [goal_mode]="Режим цели (cycle1-only / through-cycle2 / through-cycle3 / custom)"
  [revision_reason]="Причина создания или изменения профиля"
  [cycle2_enabled]="Выполнять Cycle 2 (yes/no)"
  [cycle2_goal]="Цель поставки"
  [cycle2_target]="Целевая инфраструктура или платформа"
  [cycle2_environments]="Окружения (например dev,stage,prod)"
  [cycle2_deliverables]="Артефакты Cycle 2"
  [cycle2_registry_supply_chain]="Registry, подпись, SBOM и supply chain"
  [cycle2_runtime_packaging]="Runtime и упаковка"
  [cycle2_orchestrator]="Оркестратор"
  [cycle2_iac]="Infrastructure as Code"
  [cycle2_cicd]="CI/CD"
  [cycle2_gitops]="GitOps"
  [cycle2_network]="Сеть, ingress, DNS, TLS"
  [cycle2_data]="Данные, миграции и хранилища"
  [cycle2_capacity_ha]="Capacity и High Availability"
  [cycle2_rollout]="Стратегия rollout/rollback"
  [cycle2_executor]="Кто выполняет deploy"
  [cycle2_authorization]="Границы разрешённых изменений"
  [cycle2_validation]="Как проверяется поставка"
  [cycle2_constraints]="Ограничения Cycle 2"
  [cycle3_enabled]="Выполнять Cycle 3 (yes/no)"
  [cycle3_goal]="Цель эксплуатации"
  [cycle3_operating_environment]="Эксплуатационная среда"
  [cycle3_deliverables]="Артефакты Cycle 3"
  [cycle3_monitoring_stack]="Стек мониторинга"
  [cycle3_slo_error_budget]="SLO и error budget"
  [cycle3_logs_traces_retention]="Логи, трассировки и retention"
  [cycle3_alerting_incident]="Алертинг и incident management"
  [cycle3_dedup_capabilities]="Дедупликация и корреляция событий"
  [cycle3_playbook_executor]="Кто выполняет playbook"
  [cycle3_auto_heal_authorization]="Разрешения auto-heal"
  [cycle3_backup_dr]="Backup и Disaster Recovery"
  [cycle3_capacity_cost]="Capacity и стоимость"
  [cycle3_maintenance]="Окна и правила обслуживания"
  [cycle3_validation]="Как проверяется эксплуатация"
  [cycle3_reporting]="Отчётность"
  [cycle3_constraints]="Ограничения Cycle 3"
)

header() {
  clear
  echo -e "${B}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${B}║${W}        SDLC Agent Launcher — AI Runtime           ${B}║${N}"
  echo -e "${B}╚══════════════════════════════════════════════════════╝${N}"
  echo -e "  Runtime: ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    echo -e "  Local:   ${C}${LOCAL_AGENT_HOST:-?} / ${LOCAL_MODEL_PROVIDER:-?} / ${LOCAL_MODEL:-?}${N}"
  fi
  echo -e "  Routing: ${C}${SDLC_RUNTIME_ROUTING:-не выбран}${N}"
  echo -e "  Agents:  ${C}subagents=${SDLC_SUBAGENTS:-не выбрано}, max=${SDLC_SUBAGENT_MAX:-?}${N}"
  if [[ "${SDLC_SUBAGENTS:-}" == "cross-runtime" ]]; then
    echo -e "  Worker:  ${C}$(subagent_profile_label 2>/dev/null || printf 'не настроен')${N}"
    echo -e "  Verify:  ${C}supervisor; fallback OFF${N}"
  fi
  if [[ -n "${PROJECTS:-}" ]]; then
    if [[ "$PROJECTS_MODE" == "single" ]]; then
      echo -e "  Projects: ${C}$PROJECTS/$SINGLE_PROJECT${N} ${Y}(один проект)${N}"
    else
      echo -e "  Projects: ${C}$PROJECTS${N}"
    fi
  else
    echo -e "  Projects: ${Y}не настроены${N}"
  fi
  [[ -n "${PROJECT:-}" ]] &&
    echo -e "  Active:   ${C}$PROJECT${N} ($(project_path))"
  echo
}

# ─── выбор проекта ────────────────────────────────────────────────────────────
pick_project() {
  mkdir -p "$PROJECTS"
  echo -e "${C}Проекты:${N}"
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    echo -e "  ${Y}1)${N} $SINGLE_PROJECT"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери проект [1/b]:${N} ")" choice
    [[ "$choice" == "b" || "$choice" == "B" ]] && return 1
    if [[ "$choice" == "1" ]]; then
      PROJECT="$SINGLE_PROJECT"
      return 0
    fi
    echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
  fi

  local i=1
  local -a proj_list=()
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* || "$name" == .* ]] && continue
    is_sdlc_project_dir "$d" || continue
    proj_list+=("$name")
    echo -e "  ${Y}$i)${N} $name"
    ((i++))
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

  [[ ${#proj_list[@]} -eq 0 ]] && echo -e "  ${Y}Проектов пока нет в выбранном каталоге${N}"
  echo -e "  ${Y}n)${N} Создать новый проект"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери проект [1-${#proj_list[@]}/n/b]:${N} ")" choice

  if [[ "$choice" == "b" || "$choice" == "B" ]]; then
    return 1
  elif [[ "$choice" == "n" ]]; then
    read -rp "$(echo -e "${W}Название нового проекта (Enter — отмена):${N} ")" PROJECT
    [[ -z "$PROJECT" ]] && return 1
    create_project "$PROJECT"
  else
    if ! valid_menu_index "$choice" "${#proj_list[@]}"; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
    fi
    PROJECT="${proj_list[$((choice-1))]}"
    if [[ -z "$PROJECT" ]]; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
    fi
  fi
}

# ─── создать структуру проекта ────────────────────────────────────────────────
create_project() {
  local name="$1"
  if ! valid_project_name "$name"; then
    echo -e "${R}Недопустимое имя проекта. Используй буквы, цифры, '_' или '-', без путей и пробелов.${N}"
    return 1
  fi
  mkdir -p "$PROJECTS"
  local dir="$PROJECTS/$name"

  if [[ -d "$dir" ]]; then
    echo -e "${Y}Проект '$name' уже существует${N}"; return
  fi

  for stage in stage1-planning stage2-requirements stage3-design \
               stage4-dev stage5-testing stage6-deploy stage7-ops; do
    mkdir -p "$dir/$stage/inputs" "$dir/$stage/outputs"
  done

  cat > "$dir/stage1-planning/inputs/idea.md" << 'IDEA'
---
tags: [input, stage1, idea]
---

# Описание идеи / запроса

## Бизнес-идея
[Опиши продукт или фичу]

## Целевая аудитория
[Кто будет пользоваться]

## Проблема которую решаем
[Какой pain point]

## Финансовые ожидания
[Бюджет, ожидаемый ROI]

## Ограничения
[Сроки, технические, организационные]

## Известные конкуренты
[Список]
IDEA

  local today
  today=$(date +%Y-%m-%d)
  cat > "$dir/Dashboard.md" << DASH
---
date: $today
tags: [project, dashboard]
status: active
---

# SDLC Dashboard — $name

| Этап | Статус | Последнее обновление |
|------|--------|---------------------|
| 1 — Планирование    | ⏳ Pending | — |
| 2 — Требования      | ⏳ Pending | — |
| 3 — Дизайн          | ⏳ Pending | — |
| 4 — Разработка      | ⏳ Pending | — |
| 5 — Тестирование    | ⏳ Pending | — |
| 6 — Деплой          | ⏳ Pending | — |
| 7 — Эксплуатация    | ⏳ Pending | — |
DASH

  echo -e "${G}✓ Проект '$name' создан${N}"
  echo -e "  Заполни: ${C}$dir/stage1-planning/inputs/idea.md${N}"
  echo
}

# ─── запуск агента ────────────────────────────────────────────────────────────
# Режимы:
#   task (default) — runtime "задача проект"  →  агент выполняет и завершает
#   interactive    — runtime                  →  открывается диалог, если runtime поддерживает
#
# Возврат: 0 — OK, 1 — ошибка, 2 — выход из цикла, 3 — шаг пропущен
find_agent_dir() {
  local agent="$1"
  local dir
  for subdir in cycle1-dev cycle2-deploy cycle3-ops _tools; do
    dir="$AGENTS/$subdir/$agent"
    [[ -d "$dir" ]] && echo "$dir" && return
  done
  echo ""
}

run_agent() {
  local agent="$1"
  local project="$2"
  local task="$3"
  local access="${ACTIVE_AGENT_ACCESS:-write}"
  local agent_dir
  agent_dir=$(find_agent_dir "$agent")

  if [[ ! -d "$agent_dir" ]]; then
    echo -e "${R}Агент '$agent' не найден${N}"; return 1
  fi

  if [[ ! -x "$AGENT_RUNNER" ]]; then
    echo -e "${R}Runtime dispatcher не найден или не исполняемый: $AGENT_RUNNER${N}"; return 1
  fi

  if [[ -n "${ACTIVE_EXECUTION_PROFILE:-}" ]]; then
    apply_profile "$ACTIVE_EXECUTION_PROFILE" || return 1
  else
    resolve_step_runtime "$agent" || return 1
  fi

  # Собираем vendor-neutral prompt для выбранного runtime.
  local prompt=""
  if [[ "$task" == /* ]]; then
    local slash_task="${task#/}"
    local cmd_name="${slash_task%% *}"
    local cmd_args="${slash_task#"$cmd_name"}"
    cmd_args="${cmd_args# }"
    [[ -z "$cmd_args" ]] && cmd_args="$project"
    local cmd_file="$agent_dir/.claude/commands/${cmd_name}.md"
    if [[ -f "$cmd_file" ]]; then
      local template
      template=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$cmd_file")
      [[ -z "$template" ]] && template=$(grep -v '^---' "$cmd_file" | grep -v '^description:')
      prompt="Проект: $project."$'\n\n'"${template//\$ARGUMENTS/$cmd_args}"
    else
      prompt="$task"
    fi
  elif [[ -n "$task" ]]; then
    prompt="Проект: $project."$'\n\n'"$task"
  fi

  echo
  echo -e "${B}┌─ Агент ────────────────────────────────────────────┐${N}"
  echo -e "${B}│${N} ${W}$agent${N} — ${AGENT_DESC[$agent]}"
  echo -e "${B}│${N} Runtime: ${W}$(runtime_label)${N} (${AGENT_RUNTIME})"
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    echo -e "${B}│${N} Local: ${W}$LOCAL_AGENT_HOST / $LOCAL_MODEL_PROVIDER / $LOCAL_MODEL${N}"
  fi
  echo -e "${B}│${N} Routing: ${W}$SDLC_RUNTIME_ROUTING${N}; subagents: ${W}$SDLC_SUBAGENTS/$SDLC_SUBAGENT_MAX${N}"
  echo -e "${B}│${N} Access:  ${W}$access${N}"
  echo -e "${B}│${N} Проект: ${W}$project${N}"
  [[ -n "$prompt" ]] && echo -e "${B}│${N} Prompt: ${C}$prompt${N}"
  echo -e "${B}└────────────────────────────────────────────────────┘${N}"
  echo
  if [[ -n "$prompt" ]]; then
    echo -e "  ${Y}Enter${N} — запустить задачу (выбранный runtime завершится автоматически)"
  else
    echo -e "  ${Y}Enter${N} — открыть интерактивный режим выбранного runtime"
  fi
  if [[ "$access" == write ]]; then
    echo -e "  ${Y}i${N}     — открыть интерактивный диалог с агентом"
  else
    echo -e "  ${C}read-only${N} — запись и интерактивный режим запрещены launcher-ом"
  fi
  echo -e "  ${Y}s${N}     — пропустить этот шаг"
  echo -e "  ${Y}q${N}     — выйти из цикла"
  echo
  read -rp "$(echo -e "${W}Действие:${N} ")" confirm

  case "$confirm" in
    q|Q)
      return 2
      ;;
    s|S)
      echo -e "${Y}⏭  Пропущен${N}"
      return 3
      ;;
    i|I)
      if [[ "$access" == read-only ]]; then
        echo -e "${R}Интерактивный режим недоступен для read-only действия.${N}"
        return 1
      fi
      echo
      echo -e "${C}Интерактивный режим — ${W}$agent${N} — ${AGENT_DESC[$agent]}"
      [[ -n "$prompt" ]] && echo -e "${Y}Задача этого шага:${N} $prompt"
      echo -e "${Y}Для выхода используй команду выхода выбранного runtime.${N}"
      echo
      "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" --mode interactive --prompt "${prompt:-начни сессию}"
      local rc=$?
      echo
      if [[ $rc -eq 0 ]]; then
        echo -e "${G}✓ Сессия завершена${N}"
      else
        echo -e "${R}✗ Runtime завершился с кодом $rc${N}"
      fi
      return "$rc"
      ;;
    *)
      echo
      local rc=0
      if [[ -n "$prompt" ]]; then
        echo -e "${C}Запускаю ($(runtime_label)): ${W}$prompt${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" --mode task \
          --access "$access" --prompt "$prompt" || rc=$?
      else
        echo -e "${C}Открываю интерактивный режим выбранного runtime...${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" --mode interactive --prompt "начни сессию" || rc=$?
      fi
      echo
      if [[ $rc -eq 0 ]]; then
        echo -e "${G}✓ Агент завершил работу${N}"
      else
        echo -e "${R}✗ Runtime завершился с кодом $rc${N}"
      fi
      return "$rc"
      ;;
  esac
}

# ─── один агент ───────────────────────────────────────────────────────────────
menu_single_agent() {
  header
  echo -e "${W}── Запуск одного агента ──────────────────────────────${N}"
  echo

  local -a stages=(
    "Цикл 1 · S0 — Discovery & Tracking"
    "Цикл 1 · S1 — Планирование"
    "Цикл 1 · S2 — Требования"
    "Цикл 1 · S3 — Дизайн"
    "Цикл 1 · S4 — Разработка"
    "Цикл 1 · S5 — Тестирование"
    "Tools — общие утилиты (все циклы)"
    "Цикл 2 — Деплой (test-first)"
    "Цикл 3 — Эксплуатация (test-first)"
  )
  local -a groups=(
    "s0-kickoff s0-tracker s0-validate s0-quality-gates"
    "s1-pm s1-pmo s1-finance"
    "s2-ba s2-po s2-qa-req s2-test-strategy s2-security"
    "s3-arch s3-security s3-rbac s3-dba"
    "s4-qa-auto s4-dev s4-techlead"
    "s5-qa s5-qa-auto s5-perf s5-security"
    "s0-github s0-secrets"
    "s4-devops s6-release"
    "s6-sre"
  )

  local i=1
  local -a agent_list=()
  for s in "${!stages[@]}"; do
    echo -e "${B}${stages[$s]}${N}"
    for ag in ${groups[$s]}; do
      echo -e "  ${Y}$i)${N} ${W}$ag${N} — ${AGENT_DESC[$ag]}"
      agent_list+=("$ag")
      ((i++))
    done
    echo
  done

  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери агента [1-${#agent_list[@]}/b]:${N} ")" choice
  [[ "$choice" == "b" || "$choice" == "B" ]] && return
  if ! valid_menu_index "$choice" "${#agent_list[@]}"; then
    echo -e "${R}Неверный выбор${N}"; sleep 1; return
  fi
  local agent="${agent_list[$((choice-1))]}"
  if [[ -z "$agent" ]]; then echo -e "${R}Неверный выбор${N}"; sleep 1; return; fi

  [[ -n "${PROJECT:-}" ]] || { pick_project || return; }

  # command templates агента
  local cmd_dir
  cmd_dir="$(find_agent_dir "$agent")/.claude/commands"
  local task
  if [[ -d "$cmd_dir" ]] && compgen -G "$cmd_dir/*.md" > /dev/null 2>&1; then
    echo
    echo -e "${C}Команды агента:${N}"
    local j=1
    local -a cmds=()
    for f in "$cmd_dir"/*.md; do
      local cname desc
      cname="/"$(basename "$f" .md)
      desc=$(grep '^description:' "$f" 2>/dev/null | sed 's/description: *//')
      echo -e "  ${Y}$j)${N} ${W}$cname${N} — $desc"
      cmds+=("$cname")
      ((j++))
    done
    echo -e "  ${Y}$j)${N} Ввести произвольную задачу"
    echo -e "  ${Y}$((j+1)))${N} Открыть интерактивный режим сразу"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-$((j+1))/b]:${N} ")" cmd_choice

    [[ "$cmd_choice" == "b" || "$cmd_choice" == "B" ]] && return
    if ! valid_menu_index "$cmd_choice" "$((j+1))"; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return
    elif [[ "$cmd_choice" == "$((j+1))" ]]; then
      # сразу в интерактив
      run_agent_with_preview "$agent" "$PROJECT" ""
      echo
      read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
      return
    elif [[ "$cmd_choice" == "$j" ]]; then
      read -rp "$(echo -e "${W}Задача:${N} ")" task
    else
      task="${cmds[$((cmd_choice-1))]}"
    fi
  else
    echo
    echo -e "  ${Y}1)${N} Ввести задачу"
    echo -e "  ${Y}2)${N} Открыть интерактивный режим"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-2/b]:${N} ")" mode_choice
    [[ "$mode_choice" == "b" || "$mode_choice" == "B" ]] && return
    if [[ "$mode_choice" == "2" ]]; then
      run_agent_with_preview "$agent" "$PROJECT" ""
      echo
      read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
      return
    fi
    read -rp "$(echo -e "${W}Задача:${N} ")" task
  fi

  run_agent_with_preview "$agent" "$PROJECT" "$task"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── настройка необязательных шагов ──────────────────────────────────────────
configure_optional_steps() {
  OPTIONAL_BEFORE=()
  OPTIONAL_AFTER=()

  local -a opt_agents=() opt_tasks=() opt_pos=() opt_labels=() opt_enabled=()

  for def in "${OPTIONAL_AGENTS_DEF[@]}"; do
    IFS='|' read -r ag task pos lbl <<< "$def"
    opt_agents+=("$ag")
    opt_tasks+=("$task")
    opt_pos+=("$pos")
    opt_labels+=("$lbl")
    opt_enabled+=(0)
  done

  local n=${#opt_agents[@]}

  while true; do
    echo
    echo -e "${B}┌─ Дополнительные шаги (необязательные) ────────────┐${N}"
    echo -e "${B}│${N} Нажми номер чтобы включить/выключить шаг"
    echo -e "${B}│${N} Enter — продолжить с текущим выбором"
    echo -e "${B}└────────────────────────────────────────────────────┘${N}"
    echo

    for ((i=0; i<n; i++)); do
      local pos_label=""
      [[ "${opt_pos[$i]}" == "before" ]] && pos_label="${C}[до цикла]${N}" || pos_label="${Y}[после цикла]${N}"
      if [[ "${opt_enabled[$i]}" -eq 1 ]]; then
        echo -e "  ${G}$((i+1)))${N} ${G}[ВКЛ]${N} ${W}${opt_agents[$i]}${N} — ${opt_labels[$i]}  $pos_label"
      else
        echo -e "  ${Y}$((i+1)))${N} ${W}[   ]${N} ${W}${opt_agents[$i]}${N} — ${opt_labels[$i]}  $pos_label"
      fi
    done

    echo
    read -rp "$(echo -e "${W}Переключить [1-${n}] или Enter для продолжения:${N} ")" toggle

    [[ -z "$toggle" ]] && break

    if valid_menu_index "$toggle" "$n"; then
      local idx=$((toggle-1))
      opt_enabled[$idx]=$(( 1 - opt_enabled[$idx] ))
    fi
  done

  for ((i=0; i<n; i++)); do
    if [[ "${opt_enabled[$i]}" -eq 1 ]]; then
      local entry="${opt_agents[$i]}:${opt_tasks[$i]}"
      if [[ "${opt_pos[$i]}" == "after" ]]; then
        OPTIONAL_AFTER+=("$entry")
      else
        OPTIONAL_BEFORE+=("$entry")
      fi
    fi
  done
}

goal_profile_path() {
  printf '%s/%s/tracking/SDLC-goals.md\n' "$PROJECTS" "$PROJECT"
}

goal_profile_history_path() {
  printf '%s/%s/tracking/SDLC-goals-history.md\n' "$PROJECTS" "$PROJECT"
}

goal_key_known() {
  local wanted="$1" key
  for key in "${ALL_GOAL_KEYS[@]}"; do
    [[ "$key" == "$wanted" ]] && return 0
  done
  return 1
}

load_goal_profile() {
  local file line key value
  file="$(goal_profile_path)"
  [[ -f "$file" ]] || return 1
  GOAL_VALUES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *:* ]] || continue
    key="${line%%:*}"
    goal_key_known "$key" || continue
    value="${line#*:}"
    value="${value# }"
    GOAL_VALUES["$key"]="$value"
  done < "$file"
}

goal_csv_allowed() {
  local value="$1" allowed="$2" item
  local -a items=()
  [[ -n "$value" ]] || return 1
  IFS=',' read -r -a items <<< "$value"
  for item in "${items[@]}"; do
    [[ ",$allowed," == *",$item,"* ]] || return 1
  done
}

goal_profile_complete_for_cycle() {
  local cycle="$1" key enabled deliverables allowed
  local -a keys=()
  case "$cycle" in
    2)
      keys=("${CYCLE2_GOAL_KEYS[@]}")
      enabled="${GOAL_VALUES[cycle2_enabled]:-}"
      deliverables="${GOAL_VALUES[cycle2_deliverables]:-}"
      allowed="images,runtime-bundle,orchestrator,iac,cicd,gitops,operations-pack,execute-deploy,custom"
      ;;
    3)
      keys=("${CYCLE3_GOAL_KEYS[@]}")
      enabled="${GOAL_VALUES[cycle3_enabled]:-}"
      deliverables="${GOAL_VALUES[cycle3_deliverables]:-}"
      allowed="monitoring,dashboards,alerts,runbooks,auto-heal,backup-dr,capacity,incident,reporting,execute-ops,custom"
      ;;
    *) return 1 ;;
  esac
  goal_profile_mode_consistent || return 1
  [[ -n "${GOAL_VALUES[revision_reason]:-}" ]] || return 1
  [[ "$enabled" =~ ^(yes|no)$ ]] || return 1
  [[ "$enabled" == "no" ]] && return 0
  for key in "${keys[@]}"; do
    [[ -n "${GOAL_VALUES[$key]:-}" ]] || return 1
  done
  goal_csv_allowed "$deliverables" "$allowed"
}

goal_profile_mode_consistent() {
  local mode="${GOAL_VALUES[goal_mode]:-}"
  local c2="${GOAL_VALUES[cycle2_enabled]:-}" c3="${GOAL_VALUES[cycle3_enabled]:-}"
  [[ "$c2" =~ ^(yes|no)$ && "$c3" =~ ^(yes|no)$ ]] || return 1
  case "$mode" in
    cycle1-only) [[ "$c2" == "no" && "$c3" == "no" ]] ;;
    through-cycle2) [[ "$c2" == "yes" && "$c3" == "no" ]] ;;
    through-cycle3) [[ "$c2" == "yes" && "$c3" == "yes" ]] ;;
    custom) return 0 ;;
    *) return 1 ;;
  esac
}

goal_route_label() {
  case "${1:-${GOAL_VALUES[goal_mode]:-}}" in
    cycle1-only) printf 'Только Cycle 1 — разработка; Cycle 2 и 3 не запускаются' ;;
    through-cycle2) printf 'Cycle 1 → Cycle 2 — разработка и подготовка поставки' ;;
    through-cycle3) printf 'Cycle 1 → Cycle 2 → Cycle 3 — полный маршрут цели' ;;
    custom)
      printf 'Своя комбинация — Cycle 2: %s, Cycle 3: %s' "${GOAL_VALUES[cycle2_enabled]:-?}" "${GOAL_VALUES[cycle3_enabled]:-?}"
      ;;
    *) printf 'Маршрут ещё не выбран' ;;
  esac
}

normalize_goal_mode_from_flags() {
  local c2="${GOAL_VALUES[cycle2_enabled]:-no}" c3="${GOAL_VALUES[cycle3_enabled]:-no}"
  if [[ "$c2" == "no" && "$c3" == "no" ]]; then
    GOAL_VALUES[goal_mode]="cycle1-only"
  elif [[ "$c2" == "yes" && "$c3" == "no" ]]; then
    GOAL_VALUES[goal_mode]="through-cycle2"
  elif [[ "$c2" == "yes" && "$c3" == "yes" ]]; then
    GOAL_VALUES[goal_mode]="through-cycle3"
  else
    GOAL_VALUES[goal_mode]="custom"
  fi
}

set_goal_route_from_choice() {
  local choice="$1" custom_c2="${2:-}" custom_c3="${3:-}"
  case "$choice" in
    1)
      GOAL_VALUES[goal_mode]="cycle1-only"
      GOAL_VALUES[cycle2_enabled]="no"
      GOAL_VALUES[cycle3_enabled]="no"
      ;;
    2)
      GOAL_VALUES[goal_mode]="through-cycle2"
      GOAL_VALUES[cycle2_enabled]="yes"
      GOAL_VALUES[cycle3_enabled]="no"
      ;;
    3)
      GOAL_VALUES[goal_mode]="through-cycle3"
      GOAL_VALUES[cycle2_enabled]="yes"
      GOAL_VALUES[cycle3_enabled]="yes"
      ;;
    4)
      [[ "$custom_c2" =~ ^(yes|no)$ && "$custom_c3" =~ ^(yes|no)$ ]] || return 1
      GOAL_VALUES[cycle2_enabled]="$custom_c2"
      GOAL_VALUES[cycle3_enabled]="$custom_c3"
      GOAL_VALUES[goal_mode]="custom"
      ;;
    *) return 1 ;;
  esac
}

set_goal_cycle_enabled() {
  local cycle="$1" value="$2"
  [[ "$cycle" =~ ^(2|3)$ && "$value" =~ ^(yes|no)$ ]] || return 1
  GOAL_VALUES["cycle${cycle}_enabled"]="$value"
  [[ -n "${GOAL_VALUES[cycle2_enabled]:-}" ]] || GOAL_VALUES[cycle2_enabled]="no"
  [[ -n "${GOAL_VALUES[cycle3_enabled]:-}" ]] || GOAL_VALUES[cycle3_enabled]="no"
  normalize_goal_mode_from_flags
}

save_goal_profile() {
  local file history tmp history_tmp key previous_revision next_revision now actor
  file="$(goal_profile_path)"
  history="$(goal_profile_history_path)"
  goal_profile_mode_consistent || {
    echo -e "${R}Профиль цели противоречив: goal_mode не совпадает с cycle2/3_enabled.${N}"
    return 1
  }
  previous_revision="${GOAL_VALUES[revision]:-0}"
  if [[ "$previous_revision" =~ ^[0-9]+$ ]]; then
    previous_revision=$((10#$previous_revision))
  else
    previous_revision=0
  fi
  next_revision=$((previous_revision + 1))
  now="${SDLC_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  actor="${SDLC_PROFILE_ACTOR:-${USER:-launcher}}"
  GOAL_VALUES[schema_version]="sdlc-goals/v1"
  GOAL_VALUES[revision]="$next_revision"
  GOAL_VALUES[updated_at]="$now"
  GOAL_VALUES[updated_by]="$actor"
  GOAL_VALUES[confirmed]="yes"
  mkdir -p "$(dirname "$file")" || return 1
  tmp="$(mktemp "${file}.tmp.XXXXXX")" || return 1
  history_tmp="$(mktemp "${history}.tmp.XXXXXX")" || { rm -f "$tmp"; return 1; }
  if [[ -f "$history" ]]; then
    cp "$history" "$history_tmp" || { rm -f "$tmp" "$history_tmp"; return 1; }
  fi
  {
    echo "# SDLC Goal Profile"
    echo
    echo "> Единый контракт цели для Cycle 1 → 2 → 3. Секреты здесь запрещены."
    echo "> Значения unknown и not-applicable допустимы только как явный ответ пользователя."
    echo
    echo '## Machine-readable contract'
    echo
    for key in "${ALL_GOAL_KEYS[@]}"; do
      printf '%s: %s\n' "$key" "${GOAL_VALUES[$key]:-}"
    done
    echo
    echo '## Допустимые deliverables'
    echo
    echo '- Cycle 2: images, runtime-bundle, orchestrator, iac, cicd, gitops, operations-pack, execute-deploy, custom'
    echo '- Cycle 3: monitoring, dashboards, alerts, runbooks, auto-heal, backup-dr, capacity, incident, reporting, execute-ops, custom'
    echo
    echo 'Профиль можно частично обновить из запускающего скрипта без повторного Cycle 1.'
  } > "$tmp"
  {
    [[ -s "$history_tmp" ]] || { echo "# SDLC Goal Profile History"; echo; }
    echo "## Revision $next_revision — $now"
    echo
    for key in "${ALL_GOAL_KEYS[@]}"; do
      printf '%s: %s\n' "$key" "${GOAL_VALUES[$key]:-}"
    done
    echo
  } >> "$history_tmp"
  mv "$tmp" "$file" || { rm -f "$history_tmp"; return 1; }
  mv "$history_tmp" "$history"
}

goal_value_valid() {
  local key="$1" value="$2"
  [[ -n "$value" ]] || return 1
  case "$key" in
    goal_mode) [[ "$value" =~ ^(cycle1-only|through-cycle2|through-cycle3|custom)$ ]] ;;
    cycle2_enabled|cycle3_enabled) [[ "$value" =~ ^(yes|no)$ ]] ;;
    cycle2_deliverables)
      goal_csv_allowed "$value" "images,runtime-bundle,orchestrator,iac,cicd,gitops,operations-pack,execute-deploy,custom"
      ;;
    cycle3_deliverables)
      goal_csv_allowed "$value" "monitoring,dashboards,alerts,runbooks,auto-heal,backup-dr,capacity,incident,reporting,execute-ops,custom"
      ;;
    *) return 0 ;;
  esac
}

prompt_goal_value() {
  local key="$1" current="${GOAL_VALUES[$1]:-}" value hint=""
  case "$key" in
    cycle2_deliverables)
      hint="images,runtime-bundle,orchestrator,iac,cicd,gitops,operations-pack,execute-deploy,custom"
      ;;
    cycle3_deliverables)
      hint="monitoring,dashboards,alerts,runbooks,auto-heal,backup-dr,capacity,incident,reporting,execute-ops,custom"
      ;;
  esac
  while true; do
    echo
    echo -e "  ${W}${GOAL_LABELS[$key]:-$key}${N}"
    [[ -n "$hint" ]] && echo -e "  ${C}Допустимо CSV: $hint${N}"
    [[ -n "$current" ]] && echo -e "  Сейчас: ${C}$current${N} (Enter — оставить)"
    read -rp "> " value
    [[ -z "$value" && -n "$current" ]] && value="$current"
    if goal_value_valid "$key" "$value"; then
      GOAL_VALUES["$key"]="$value"
      return 0
    fi
    echo -e "${R}Нужно явное допустимое значение. Для неизвестного ответа используй unknown; для неприменимого — not-applicable.${N}"
  done
}

read_explicit_yes_no() {
  local question="$1" choice
  while true; do
    echo -e "  ${W}$question${N}"
    echo -e "    ${Y}1)${N} Да, включить"
    echo -e "    ${Y}2)${N} Нет, не включать"
    read -rp "> " choice
    case "$choice" in
      1) YES_NO_RESULT="yes"; return 0 ;;
      2) YES_NO_RESULT="no"; return 0 ;;
      *) echo -e "${R}Выбери 1 или 2.${N}" ;;
    esac
  done
}

prompt_goal_route_selection() {
  local allow_keep="${1:-yes}" choice c2 c3 prompt_options="[1-4]" show_keep=0
  while true; do
    echo
    echo -e "${W}Что должно быть выполнено для этой цели?${N}"
    echo -e "  ${Y}1)${N} ${G}Только Cycle 1${N} — разработка; deploy и ops не запускаются"
    echo -e "  ${Y}2)${N} Cycle 1 → Cycle 2 — разработка и подготовка поставки"
    echo -e "  ${Y}3)${N} Cycle 1 → Cycle 2 → Cycle 3 — полный маршрут"
    echo -e "  ${Y}4)${N} Своя комбинация Cycle 2/3"
    show_keep=0
    if [[ "$allow_keep" == "yes" ]] && goal_profile_mode_consistent; then
      show_keep=1
      prompt_options="[1-4/k]"
      echo -e "  ${Y}k)${N} Оставить текущий маршрут: ${C}$(goal_route_label)${N}"
    else
      prompt_options="[1-4]"
    fi
    read -rp "$(echo -e "${W}Выбери маршрут $prompt_options:${N} ")" choice
    case "$choice" in
      1|2|3) set_goal_route_from_choice "$choice"; return 0 ;;
      4)
        read_explicit_yes_no "Включить Cycle 2 — подготовку поставки?" || return 1
        c2="$YES_NO_RESULT"
        read_explicit_yes_no "Включить Cycle 3 — эксплуатационный контур?" || return 1
        c3="$YES_NO_RESULT"
        set_goal_route_from_choice 4 "$c2" "$c3"
        return 0
        ;;
      k|K)
        if [[ $show_keep -eq 1 ]]; then
          return 0
        fi
        echo -e "${R}Текущего согласованного маршрута нет.${N}"
        ;;
      *) echo -e "${R}Выбери один из показанных вариантов.${N}" ;;
    esac
  done
}

goal_csv_contains() {
  [[ ",$1," == *",$2,"* ]]
}

prompt_goal_deliverables() {
  local cycle="$1" key current raw token item selected_csv="" seen=","
  local -a options=() tokens=()
  case "$cycle" in
    2) key="cycle2_deliverables"; options=("${CYCLE2_DELIVERABLES[@]}") ;;
    3) key="cycle3_deliverables"; options=("${CYCLE3_DELIVERABLES[@]}") ;;
    *) return 1 ;;
  esac
  current="${GOAL_VALUES[$key]:-}"
  while true; do
    echo
    echo -e "${W}Выбери deliverables для Cycle $cycle:${N}"
    local i=1 mark
    for item in "${options[@]}"; do
      mark=" "
      goal_csv_contains "$current" "$item" && mark="✓"
      echo -e "  ${Y}$i)${N} [${mark}] ${DELIVERABLE_LABELS[$item]} ${C}($item)${N}"
      ((i++))
    done
    echo -e "  Введи номера через запятую, например ${C}1,5,7${N}."
    [[ -n "$current" ]] && echo -e "  ${Y}k)${N} Оставить текущий выбор: ${C}$current${N}"
    echo -e "  ${Y}b)${N} Отменить корректировку"
    read -rp "> " raw
    if [[ "$raw" =~ ^[kK]$ && -n "$current" ]]; then
      return 0
    fi
    [[ "$raw" =~ ^[bB]$ ]] && return 2
    raw="${raw//[[:space:]]/}"
    IFS=',' read -r -a tokens <<< "$raw"
    selected_csv=""
    seen=","
    local valid=1
    for token in "${tokens[@]}"; do
      if ! valid_menu_index "$token" "${#options[@]}"; then
        valid=0
        break
      fi
      item="${options[$((token-1))]}"
      [[ "$seen" == *",$item,"* ]] && continue
      seen+="$item,"
      [[ -n "$selected_csv" ]] && selected_csv+=","
      selected_csv+="$item"
    done
    if [[ $valid -eq 1 && -n "$selected_csv" ]]; then
      GOAL_VALUES["$key"]="$selected_csv"
      return 0
    fi
    echo -e "${R}Выбери хотя бы один существующий номер из списка.${N}"
  done
}

prompt_goal_cycle() {
  local cycle="$1" edit_mode="${2:-full}" key choice current
  local -a keys=()
  case "$cycle" in
    2) keys=("${CYCLE2_GOAL_KEYS[@]}") ;;
    3) keys=("${CYCLE3_GOAL_KEYS[@]}") ;;
    *) return 1 ;;
  esac
  if [[ "$edit_mode" == "partial" ]]; then
    current="${GOAL_VALUES[${keys[0]}]:-no}"
    while true; do
      echo
      echo -e "${W}Cycle $cycle сейчас: ${C}$([[ "$current" == "yes" ]] && echo 'ВКЛЮЧЁН' || echo 'ВЫКЛЮЧЕН')${N}"
      if [[ "$current" == "yes" ]]; then
        echo -e "  ${Y}1)${N} Оставить включённым и изменить настройки"
        echo -e "  ${Y}2)${N} Выключить Cycle $cycle"
      else
        echo -e "  ${Y}1)${N} Включить Cycle $cycle и настроить"
      fi
      echo -e "  ${Y}b)${N} Отменить корректировку"
      read -rp "> " choice
      case "$choice" in
        1) set_goal_cycle_enabled "$cycle" yes; break ;;
        2)
          if [[ "$current" == "yes" ]]; then
            set_goal_cycle_enabled "$cycle" no
            return 0
          fi
          ;;
        b|B) return 2 ;;
        *) echo -e "${R}Выбери показанный вариант.${N}" ;;
      esac
    done
  fi
  [[ "${GOAL_VALUES[${keys[0]}]:-}" == "no" ]] && return 0
  echo
  echo -e "${B}── Настройка включённого Cycle $cycle ──${N}"
  for key in "${keys[@]:1}"; do
    if [[ "$key" == "cycle${cycle}_deliverables" ]]; then
      prompt_goal_deliverables "$cycle" || return $?
    else
      prompt_goal_value "$key"
    fi
  done
}

configure_goal_profile() {
  local scope="${1:-full}" key confirm
  if ! load_goal_profile; then
    GOAL_VALUES=()
    if [[ "$scope" != "full" ]]; then
      echo -e "${Y}Первое создание требует полного профиля; переключаю на полный wizard.${N}"
      scope="full"
    fi
  fi
  header
  echo -e "${W}── Профиль цели проекта: $PROJECT ───────────────────${N}"
  echo -e "${Y}Секреты не вводить:${N} только названия, identity/path и границы разрешений."

  if [[ "$scope" == "full" || -z "${GOAL_VALUES[goal_mode]:-}" ]]; then
    prompt_goal_route_selection yes || return 1
  fi

  case "$scope" in
    full)
      prompt_goal_cycle 2 full || return 1
      prompt_goal_cycle 3 full || return 1
      ;;
    2) prompt_goal_cycle 2 partial || return 1 ;;
    3) prompt_goal_cycle 3 partial || return 1 ;;
    *) return 1 ;;
  esac
  prompt_goal_value revision_reason

  if { [[ "$scope" == "full" || "$scope" == "2" ]] && ! goal_profile_complete_for_cycle 2; } ||
     { [[ "$scope" == "full" || "$scope" == "3" ]] && ! goal_profile_complete_for_cycle 3; }; then
    echo -e "${R}Профиль неполон или содержит недопустимые deliverables; файл не изменён.${N}"
    return 1
  fi
  echo
  echo -e "${W}Проверь перед сохранением:${N}"
  echo -e "  mode=${C}${GOAL_VALUES[goal_mode]}${N}; Cycle2=${C}${GOAL_VALUES[cycle2_enabled]}${N}; Cycle3=${C}${GOAL_VALUES[cycle3_enabled]}${N}"
  [[ "${GOAL_VALUES[cycle2_enabled]}" == "yes" ]] &&
    echo -e "  Cycle2 deliverables: ${C}${GOAL_VALUES[cycle2_deliverables]}${N}"
  [[ "${GOAL_VALUES[cycle3_enabled]}" == "yes" ]] &&
    echo -e "  Cycle3 deliverables: ${C}${GOAL_VALUES[cycle3_deliverables]}${N}"
  echo -e "  revision reason: ${C}${GOAL_VALUES[revision_reason]}${N}"
  read -rp "$(echo -e "${W}Сохранить новую revision? [y/N]:${N} ")" confirm
  [[ "$confirm" =~ ^[yYдД]$ ]] || { echo -e "${Y}Изменения не сохранены.${N}"; return 1; }
  save_goal_profile || return 1
  case "$scope" in
    full)
      set_cycle_tdd_status_blocked 2 2>/dev/null || true
      set_cycle_tdd_status_blocked 3 2>/dev/null || true
      ;;
    2) set_cycle_tdd_status_blocked 2 2>/dev/null || true ;;
    3) set_cycle_tdd_status_blocked 3 2>/dev/null || true ;;
  esac
  echo -e "${G}✓ Профиль цели сохранён: $(goal_profile_path)${N}"
}

show_goal_profile() {
  local file
  file="$(goal_profile_path)"
  if [[ -f "$file" ]]; then
    echo -e "${C}$file${N}"
    echo
    awk '{ print "  " $0 }' "$file"
  else
    echo -e "${Y}Профиль цели ещё не создан.${N}"
  fi
}

show_goal_profile_history() {
  local file
  file="$(goal_profile_history_path)"
  if [[ -f "$file" ]]; then
    echo -e "${C}$file${N}"
    echo
    awk '{ print "  " $0 }' "$file"
  else
    echo -e "${Y}История revision ещё не создана.${N}"
  fi
}

ensure_goal_profile_for_cycle() {
  local cycle="$1"
  if load_goal_profile && goal_profile_complete_for_cycle "$cycle"; then
    return 0
  fi
  echo -e "${Y}Для Cycle $cycle нужен заполненный профиль цели.${N}"
  configure_goal_profile "$cycle"
}

offer_goal_profile_at_cycle1_entry() {
  local choice has_profile=0
  while true; do
    has_profile=0
    load_goal_profile && has_profile=1
    echo
    echo -e "${G}Текущий запуск: ТОЛЬКО Cycle 1 — разработка.${N}"
    echo -e "Cycle 2 и Cycle 3 в этом запуске ${W}не стартуют${N}."
    if [[ $has_profile -eq 1 ]]; then
      echo -e "Сохранённый маршрут режима цели: ${C}$(goal_route_label)${N}"
    else
      echo -e "${Y}Маршрут для будущего режима цели пока не настроен.${N}"
    fi
    echo
    echo -e "  ${Y}1)${N} Запустить только Cycle 1 сейчас"
    echo -e "  ${Y}2)${N} Настроить маршрут и параметры Cycle 2/3, затем запустить Cycle 1"
    [[ $has_profile -eq 1 ]] && echo -e "  ${Y}3)${N} Показать сохранённый профиль"
    echo -e "  ${Y}q)${N} Отменить запуск"
    read -rp "$(echo -e "${W}Выбери действие:${N} ")" choice
    case "$choice" in
      1) return 0 ;;
      2) configure_goal_profile full || continue ;;
      3)
        if [[ $has_profile -eq 1 ]]; then
          show_goal_profile
          read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _
        else
          echo -e "${R}Профиль ещё не создан.${N}"
        fi
        ;;
      q|Q) return 1 ;;
      *) echo -e "${R}Выбери показанный вариант.${N}" ;;
    esac
  done
}

menu_goal_profile() {
  header
  echo -e "${W}── Цели Cycle 2/3 ───────────────────────────────────${N}"
  echo
  [[ -n "${PROJECT:-}" ]] || { pick_project || return; }
  while true; do
    header
    echo -e "${W}── Цели Cycle 2/3 — $PROJECT ─────────────────────────${N}"
    echo
    if load_goal_profile; then
      echo -e "  Текущий маршрут: ${C}$(goal_route_label)${N}"
    else
      echo -e "  Текущий маршрут: ${Y}не настроен${N}"
    fi
    echo
    echo -e "  ${Y}1)${N} Выбрать маршрут и настроить весь профиль"
    echo -e "  ${Y}2)${N} Включить/выключить или изменить только Cycle 2"
    echo -e "  ${Y}3)${N} Включить/выключить или изменить только Cycle 3"
    echo -e "  ${Y}4)${N} Показать профиль"
    echo -e "  ${Y}5)${N} Показать историю revision"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-5/b]:${N} ")" choice
    case "$choice" in
      1) configure_goal_profile full ;;
      2) configure_goal_profile 2 ;;
      3) configure_goal_profile 3 ;;
      4) show_goal_profile; read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _ ;;
      5) show_goal_profile_history; read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _ ;;
      b|B) return ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

cycle_tdd_status_file() {
  case "$1" in
    1) printf '%s/%s/stage4-dev/outputs/QA-TDD-status.md\n' "$PROJECTS" "$PROJECT" ;;
    2) printf '%s/%s/stage6-deploy/outputs/DEPLOY-TDD-status.md\n' "$PROJECTS" "$PROJECT" ;;
    3) printf '%s/%s/stage7-ops/outputs/OPS-TDD-status.md\n' "$PROJECTS" "$PROJECT" ;;
    *) return 1 ;;
  esac
}

read_cycle_tdd_field() {
  local cycle="$1" field="$2" file
  file="$(cycle_tdd_status_file "$cycle")" || return 1
  [[ -f "$file" ]] || return 1
  awk -F: -v wanted="$field" '
    {
      key=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
    }
    key == wanted {
      value=$0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

read_cycle_tdd_status() {
  local status
  status="$(read_cycle_tdd_field "$1" status)" || return 1
  printf '%s\n' "${status^^}"
}

cycle_tdd_revision_matches() {
  local cycle="$1" status_revision
  [[ "$cycle" == "1" ]] && return 0
  status_revision="$(read_cycle_tdd_field "$cycle" goal_profile_revision || true)"
  load_goal_profile || return 1
  [[ -n "$status_revision" && "$status_revision" == "${GOAL_VALUES[revision]:-}" ]]
}

set_cycle_tdd_status_blocked() {
  local file tmp
  file="$(cycle_tdd_status_file "$1")" || return 1
  [[ -f "$file" ]] || return 1
  tmp="$(mktemp "${file}.tmp.XXXXXX")" || return 1
  awk '
    BEGIN { written=0 }
    /^[[:space:]]*status:[[:space:]]*/ && !written {
      print "status: BLOCKED"
      written=1
      next
    }
    { print }
    END { if (!written) print "status: BLOCKED" }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

require_cycle_tdd_red() {
  local cycle="$1" status
  status="$(read_cycle_tdd_status "$cycle" || true)"
  if [[ "$status" != "RED" ]]; then
    echo -e "${R}TDD BLOCKER Cycle $cycle: перед реализацией нужен status: RED; получено '${status:-нет файла}'.${N}"
    return 1
  fi
  if ! cycle_tdd_revision_matches "$cycle"; then
    echo -e "${R}TDD BLOCKER Cycle $cycle: goal_profile_revision устарела или отсутствует.${N}"
    return 1
  fi
}

run_cycle_tdd_repair_loop() {
  local cycle="$1" status max_iterations="${TDD_MAX_REPAIR_ITERATIONS:-3}" iteration=0 rc
  local -a repair_steps=()
  case "$cycle" in
    1) repair_steps=("s4-dev:/dev-report" "s4-qa-auto:/run-tests") ;;
    2) repair_steps=("s4-devops:/pipeline" "s4-devops:/runbook" "s4-devops:/prepare-delivery" "s4-devops:/run-deploy-tests") ;;
    3) repair_steps=("s6-sre:/configure-ops" "s6-sre:/run-ops-tests") ;;
    *) return 1 ;;
  esac
  valid_menu_index "$max_iterations" 10 || {
    echo -e "${R}TDD_MAX_REPAIR_ITERATIONS должен быть 1..10${N}"
    return 1
  }

  status="$(read_cycle_tdd_status "$cycle" || true)"
  if [[ "$cycle" != "1" ]] && ! cycle_tdd_revision_matches "$cycle"; then
    set_cycle_tdd_status_blocked "$cycle" || true
    echo -e "${R}TDD BLOCKED Cycle $cycle: evidence относится к другой revision профиля цели.${N}"
    return 1
  fi
  while [[ "$status" == "FAIL" && $iteration -lt $max_iterations ]]; do
    ((iteration++))
    echo -e "${Y}TDD repair Cycle $cycle — $iteration/$max_iterations: тесты FAIL.${N}"
    local entry agent task
    for entry in "${repair_steps[@]}"; do
      agent="${entry%%:*}"
      task="${entry#*:}"
      run_agent "$agent" "$PROJECT" "$task"
      rc=$?
      [[ $rc -eq 0 ]] || { set_cycle_tdd_status_blocked "$cycle" || true; return 1; }
    done
    status="$(read_cycle_tdd_status "$cycle" || true)"
  done

  case "$status" in
    PASS)
      echo -e "${G}✓ TDD PASS после $iteration repair iteration(s).${N}"
      return 0
      ;;
    FAIL)
      set_cycle_tdd_status_blocked "$cycle" || true
      echo -e "${R}TDD BLOCKED: исчерпан лимит $max_iterations, silent pass запрещён.${N}"
      return 1
      ;;
    BLOCKED)
      echo -e "${R}TDD BLOCKED агентом тестирования.${N}"
      return 1
      ;;
    *)
      set_cycle_tdd_status_blocked "$cycle" || true
      echo -e "${R}TDD BLOCKED: ожидался PASS/FAIL/BLOCKED, получено '${status:-нет файла}'.${N}"
      return 1
      ;;
  esac
}

# Backward-compatible Cycle 1 API used by existing contracts.
read_tdd_status() { read_cycle_tdd_status 1; }
set_tdd_status_blocked() { set_cycle_tdd_status_blocked 1; }
require_tdd_red() { require_cycle_tdd_red 1; }
run_tdd_repair_loop() { run_cycle_tdd_repair_loop 1; }

# ─── исполнение списка шагов цикла ────────────────────────────────────────────
# Аргументы: $1 — заголовок; $2 — номер цикла; RUN_CYCLE/RUN_OPTIONAL заполнены
execute_cycle() {
  local cycle_title="$1"
  local cycle_id="${2:-1}"
  local total=${#RUN_CYCLE[@]}

  local step=0 skipped=0 done_count=0 aborted=0
  local -a step_log=()
  EXECUTION_LAST_STEP=0
  EXECUTION_LAST_STEP_STATUS=PENDING
  EXECUTION_LAST_ACTION=''
  EXECUTION_LAST_AGENT=''
  EXECUTION_LAST_TASK=''
  EXECUTION_LAST_REASON=''

  for ((idx=0; idx<${#RUN_CYCLE[@]}; idx++)); do
    ((step++))
    local entry="${RUN_CYCLE[$idx]}"
    local is_optional="${RUN_OPTIONAL[$idx]}"
    local agent="${entry%%:*}"
    local task="${entry#*:}"
    local label="${agent} — ${AGENT_DESC[$agent]}"
    local opt_tag=""
    [[ "$is_optional" -eq 1 ]] && opt_tag=" ${C}[доп]${N}"
    EXECUTION_LAST_STEP="$step"
    EXECUTION_LAST_STEP_STATUS=RUNNING
    EXECUTION_LAST_ACTION="$agent $task"
    EXECUTION_LAST_AGENT="$agent"
    EXECUTION_LAST_TASK="$task"
    EXECUTION_LAST_REASON='dispatch requested'

    echo
    echo -e "${B}━━━ $cycle_title — Шаг $step / $total ━━━━━━━━━━━━━━━━━━${N}${opt_tag}"
    if [[ -n "${CURRENT_RUN_ID:-}" && -d "$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")" ]]; then
      journal_write_state "$CURRENT_RUN_ID" RUNNING "$step" "$total" RUNNING "$agent $task"
      journal_append_event "$CURRENT_RUN_ID" step_started RUNNING "$step" RUNNING "$agent" "$task" 'dispatch requested'
    fi

    if [[ "$entry" == "s4-dev:/dev-report" ]] && ! require_cycle_tdd_red 1; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='TDD RED отсутствует'
      step_log+=("  ${R}✗${N}  $label — TDD RED отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" == "s4-devops:/pipeline" ]] && ! require_cycle_tdd_red 2; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='DEPLOY TDD RED отсутствует'
      step_log+=("  ${R}✗${N}  $label — DEPLOY TDD RED отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" == "s6-sre:/configure-ops" ]] && ! require_cycle_tdd_red 3; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='OPS TDD RED отсутствует'
      step_log+=("  ${R}✗${N}  $label — OPS TDD RED отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" =~ ^s6-release: ]] &&
       { [[ "$(read_cycle_tdd_status 2 || true)" != "PASS" ]] ||
         ! cycle_tdd_revision_matches 2; }; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='DEPLOY TDD PASS отсутствует'
      step_log+=("  ${R}✗${N}  $label — DEPLOY TDD PASS отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" =~ ^s6-sre:/(post-deploy|gate7)$ ]] &&
       { [[ "$(read_cycle_tdd_status 3 || true)" != "PASS" ]] ||
         ! cycle_tdd_revision_matches 3; }; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='OPS TDD PASS отсутствует'
      step_log+=("  ${R}✗${N}  $label — OPS TDD PASS отсутствует")
      ((aborted++))
      break
    fi

    ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[$idx]:-}"
    run_agent "$agent" "$PROJECT" "$task"
    local rc=$?
    ACTIVE_EXECUTION_PROFILE=""

    if [[ $rc -eq 0 && "$entry" == "s4-qa-auto:/run-tests" ]]; then
      run_cycle_tdd_repair_loop 1
      rc=$?
    elif [[ $rc -eq 0 && "$entry" == "s4-devops:/run-deploy-tests" ]]; then
      run_cycle_tdd_repair_loop 2
      rc=$?
    elif [[ $rc -eq 0 && "$entry" == "s6-sre:/run-ops-tests" ]]; then
      run_cycle_tdd_repair_loop 3
      rc=$?
    fi

    if [[ $rc -eq 2 ]]; then
      EXECUTION_LAST_STEP_STATUS=UNKNOWN
      EXECUTION_LAST_REASON='пользователь прервал цикл'
      step_log+=("  ${Y}⏹${N}  $label${opt_tag}")
      ((aborted++))
      echo -e "${Y}Цикл прерван на шаге $step${N}"
      break
    elif [[ $rc -eq 3 && "$is_optional" -eq 0 ]]; then
      EXECUTION_LAST_STEP_STATUS=SKIPPED
      EXECUTION_LAST_REASON='обязательный шаг пропущен'
      step_log+=("  ${R}✗${N}  $label — обязательный шаг нельзя пропустить")
      ((aborted++))
      echo -e "${R}Цикл заблокирован: обязательный шаг $step нельзя пропустить.${N}"
      break
    elif [[ $rc -eq 3 ]]; then
      EXECUTION_LAST_STEP_STATUS=SKIPPED
      EXECUTION_LAST_REASON='необязательный шаг пропущен'
      step_log+=("  ${Y}⏭${N}  $label${opt_tag}")
      ((skipped++))
      [[ -z "${CURRENT_RUN_ID:-}" ]] ||
        journal_append_event "$CURRENT_RUN_ID" step_skipped RUNNING "$step" SKIPPED "$agent" "$task" 'optional step skipped'
    elif [[ $rc -eq 0 ]]; then
      EXECUTION_LAST_STEP_STATUS=SUCCEEDED
      EXECUTION_LAST_REASON='runtime exit code 0'
      step_log+=("  ${G}✓${N}  $label${opt_tag}")
      ((done_count++))
      [[ -z "${CURRENT_RUN_ID:-}" ]] ||
        journal_append_event "$CURRENT_RUN_ID" step_succeeded RUNNING "$step" SUCCEEDED "$agent" "$task" 'runtime exit code 0'
    else
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON="runtime exit code $rc"
      step_log+=("  ${R}✗${N}  $label${opt_tag}")
      ((aborted++))
      if [[ -n "${CURRENT_RUN_ID:-}" ]]; then
        journal_append_event "$CURRENT_RUN_ID" step_failed BLOCKED "$step" FAILED "$agent" "$task" "runtime exit code $rc"
      fi
      echo -e "${R}Цикл заблокирован на шаге $step (код $rc)${N}"
      break
    fi
  done

  echo
  echo -e "${G}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${G}║${W}  Итог: $cycle_title — Проект: $PROJECT${N}"
  echo -e "${G}╠══════════════════════════════════════════════════════╣${N}"
  for line in "${step_log[@]}"; do
    echo -e "${G}║${N}${line}"
  done
  echo -e "${G}╠══════════════════════════════════════════════════════╣${N}"
  echo -e "${G}║${N}  ${G}✓${N} Выполнено: ${G}$done_count${N}   ${Y}⏭${N} Пропущено: ${Y}$skipped${N}   Всего: $step / $total"
  echo -e "${G}╚══════════════════════════════════════════════════════╝${N}"
  echo
  [[ $aborted -eq 0 ]]
}

execute_previewed_cycle() {
  local rc=0 total="${#RUN_CYCLE[@]}"
  journal_create_run "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED" || return 1
  journal_acquire_lease "$CURRENT_RUN_ID" || {
    echo -e "${R}Run уже выполняется другим launcher process.${N}"
    return 1
  }
  if [[ -n "${PARENT_RUN_ID:-}" ]]; then
    journal_append_event "$PARENT_RUN_ID" retry_child_created INTERRUPTED 0 UNKNOWN '' '' "child run $CURRENT_RUN_ID"
  fi
  journal_write_state "$CURRENT_RUN_ID" READY 0 "$total" PENDING ''
  journal_append_event "$CURRENT_RUN_ID" execution_confirmed READY 0 PENDING '' '' 'user explicitly confirmed preview'
  journal_write_state "$CURRENT_RUN_ID" RUNNING 0 "$total" PENDING ''
  execute_cycle "$EXECUTION_TITLE" "$EXECUTION_CYCLE_ID" || rc=$?
  if [[ $rc -eq 0 ]]; then
    journal_write_state "$CURRENT_RUN_ID" COMPLETED "$total" "$total" SUCCEEDED ''
    journal_append_event "$CURRENT_RUN_ID" run_completed COMPLETED "$total" SUCCEEDED '' '' 'all planned steps completed'
  else
    journal_write_state "$CURRENT_RUN_ID" BLOCKED "${EXECUTION_LAST_STEP:-0}" "$total" \
      "${EXECUTION_LAST_STEP_STATUS:-UNKNOWN}" "${EXECUTION_LAST_ACTION:-}"
    journal_append_event "$CURRENT_RUN_ID" run_blocked BLOCKED \
      "${EXECUTION_LAST_STEP:-0}" "${EXECUTION_LAST_STEP_STATUS:-UNKNOWN}" \
      "${EXECUTION_LAST_AGENT:-}" "${EXECUTION_LAST_TASK:-}" \
      "${EXECUTION_LAST_REASON:-cycle exit code $rc}"
  fi
  journal_release_lease "$CURRENT_RUN_ID"
  return "$rc"
}

preview_and_execute_cycle() {
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview execute_previewed_cycle
}

# ─── Цикл 1 — Разработка ──────────────────────────────────────────────────────
# Аргумент $1: "standalone" (по умолчанию) — спросить проект; "chained" — PROJECT уже выбран
run_cycle1() {
  local mode="${1:-standalone}"
  header
  echo -e "${W}── Цикл 1 — Разработка ───────────────────────────────${N}"
  echo
  [[ "$mode" == "standalone" ]] && { pick_project || return; }
  [[ "$mode" != "chained" ]] && { offer_goal_profile_at_cycle1_entry || return; }

  # выбор необязательных шагов
  configure_optional_steps

  # строим динамический массив: before + обязательные + after
  local -a RUN_CYCLE=()
  local -a RUN_OPTIONAL=()  # флаги: 1 = необязательный шаг

  for entry in "${OPTIONAL_BEFORE[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(1)
  done
  for entry in "${CYCLE1_AGENTS[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(0)
  done
  for entry in "${OPTIONAL_AFTER[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(1)
  done

  local mandatory_count=${#CYCLE1_AGENTS[@]}
  local optional_count=$(( ${#OPTIONAL_BEFORE[@]} + ${#OPTIONAL_AFTER[@]} ))
  local total=${#RUN_CYCLE[@]}

  echo
  echo -e "${C}Проект: ${W}$PROJECT${N}"
  echo -e "  Обязательных шагов: ${W}$mandatory_count${N}"
  if [[ $optional_count -gt 0 ]]; then
    echo -e "  Дополнительных шагов: ${G}$optional_count${N}"
    [[ ${#OPTIONAL_BEFORE[@]} -gt 0 ]] && echo -e "    До цикла:    ${G}${#OPTIONAL_BEFORE[@]}${N}"
    [[ ${#OPTIONAL_AFTER[@]}  -gt 0 ]] && echo -e "    После цикла: ${G}${#OPTIONAL_AFTER[@]}${N}"
  fi
  echo -e "  Итого шагов: ${W}$total${N}"
  echo
  echo -e "После общей проверки запуска на каждом шаге:"
  echo -e "  ${Y}Enter${N} — запустить задачу автоматически"
  echo -e "  ${Y}i${N}     — открыть интерактивный диалог с агентом"
  echo -e "  ${Y}s${N}     — пропустить шаг"
  echo -e "  ${Y}q${N}     — прервать цикл"
  echo
  EXECUTION_TYPE=CYCLE
  EXECUTION_SCOPE='ТОЛЬКО Cycle 1'
  EXECUTION_EXCLUDED='Cycle 2, Cycle 3'
  EXECUTION_TITLE='Цикл 1 — Разработка'
  EXECUTION_CYCLE_ID=1
  local rc=0
  preview_and_execute_cycle || rc=$?
  [[ "$mode" == "standalone" ]] && read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
  return "$rc"
}

# ─── Цикл 2 — Деплой ──────────────────────────────────────────────────────────
run_cycle2() {
  local mode="${1:-standalone}" rc=0
  header
  echo -e "${W}── Цикл 2 — Деплой ───────────────────────────────────${N}"
  echo
  [[ "$mode" == "standalone" ]] && { pick_project || return; }
  ensure_goal_profile_for_cycle 2 || return 1
  if [[ "${GOAL_VALUES[cycle2_enabled]:-}" != "yes" ]]; then
    echo -e "${Y}Cycle 2 явно отключён в профиле цели. Измени его через «Цели Cycle 2/3».${N}"
    return 1
  fi
  local -a RUN_CYCLE=("${CYCLE2_AGENTS[@]}")
  local -a RUN_OPTIONAL=()
  local entry
  for entry in "${RUN_CYCLE[@]}"; do RUN_OPTIONAL+=(0); done
  echo -e "  Профиль: ${C}$(goal_profile_path)${N}"
  echo -e "  Шагов: ${W}${#RUN_CYCLE[@]}${N}; tests → RED до delivery implementation."
  EXECUTION_TYPE=CYCLE
  EXECUTION_SCOPE='ТОЛЬКО Cycle 2'
  EXECUTION_EXCLUDED='Cycle 1, Cycle 3'
  EXECUTION_TITLE='Цикл 2 — Деплой'
  EXECUTION_CYCLE_ID=2
  preview_and_execute_cycle || rc=$?
  [[ "$mode" == "standalone" ]] && read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
  return "$rc"
}

# ─── Цикл 3 — Эксплуатация ────────────────────────────────────────────────────
run_cycle3() {
  local mode="${1:-standalone}" rc=0
  header
  echo -e "${W}── Цикл 3 — Эксплуатация ─────────────────────────────${N}"
  echo
  [[ "$mode" == "standalone" ]] && { pick_project || return; }
  ensure_goal_profile_for_cycle 3 || return 1
  if [[ "${GOAL_VALUES[cycle3_enabled]:-}" != "yes" ]]; then
    echo -e "${Y}Cycle 3 явно отключён в профиле цели. Измени его через «Цели Cycle 2/3».${N}"
    return 1
  fi
  local -a RUN_CYCLE=("${CYCLE3_AGENTS[@]}")
  local -a RUN_OPTIONAL=()
  local entry
  for entry in "${RUN_CYCLE[@]}"; do RUN_OPTIONAL+=(0); done
  echo -e "  Профиль: ${C}$(goal_profile_path)${N}"
  echo -e "  Шагов: ${W}${#RUN_CYCLE[@]}${N}; ops tests → RED до ops configuration."
  EXECUTION_TYPE=CYCLE
  EXECUTION_SCOPE='ТОЛЬКО Cycle 3'
  EXECUTION_EXCLUDED='Cycle 1, Cycle 2'
  EXECUTION_TITLE='Цикл 3 — Эксплуатация'
  EXECUTION_CYCLE_ID=3
  preview_and_execute_cycle || rc=$?
  [[ "$mode" == "standalone" ]] && read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
  return "$rc"
}

# ─── Режим цели (Cycle 1 → выбранные Cycle 2/3) ────────────────────────────────
run_goal_mode() {
  local mode="${1:-standalone}"
  header
  echo -e "${W}── Режим цели ─────────────────────────────────────────${N}"
  echo
  [[ "$mode" == "standalone" ]] && { pick_project || return; }
  local choice
  while true; do
    if ! load_goal_profile ||
       ! goal_profile_mode_consistent ||
       ! goal_profile_complete_for_cycle 2 ||
       ! goal_profile_complete_for_cycle 3; then
      echo -e "${Y}Для режима цели сначала выбери явный маршрут.${N}"
      configure_goal_profile full || return 1
      load_goal_profile || return 1
    fi
    echo
    echo -e "${W}Будет выполнено:${N} ${G}$(goal_route_label)${N}"
    echo -e "  ${Y}1)${N} Запустить этот маршрут"
    echo -e "  ${Y}2)${N} Изменить маршрут или параметры"
    echo -e "  ${Y}3)${N} Показать профиль"
    echo -e "  ${Y}q)${N} Отменить"
    read -rp "$(echo -e "${W}Выбери действие:${N} ")" choice
    case "$choice" in
      1) break ;;
      2) configure_goal_profile full || return 1 ;;
      3) show_goal_profile; read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _ ;;
      q|Q) return 1 ;;
      *) echo -e "${R}Выбери показанный вариант.${N}" ;;
    esac
  done
  run_cycle1 chained || return 1
  load_goal_profile || return 1
  [[ "${GOAL_VALUES[goal_mode]:-}" == "cycle1-only" ]] && return 0
  if [[ "${GOAL_VALUES[cycle2_enabled]:-}" == "yes" ]]; then
    run_cycle2 chained || return 1
  fi
  if [[ "${GOAL_VALUES[goal_mode]:-}" =~ ^(through-cycle3|custom)$ ]] &&
     [[ "${GOAL_VALUES[cycle3_enabled]:-}" == "yes" ]]; then
    run_cycle3 chained || return 1
  fi
}

# ─── подменю выбора цикла ─────────────────────────────────────────────────────
menu_cycle_select() {
  header
  echo -e "${W}── Что хотите сделать? ───────────────────────────────${N}"
  echo
  echo -e "  ${Y}1)${N} ${G}🔧 Только Cycle 1${N} — разработка без запуска deploy/ops"
  echo -e "  ${Y}2)${N} ${C}🚀 Деплой${N} (Цикл 2, test-first)"
  echo -e "  ${Y}3)${N} ${C}📊 Эксплуатация${N} (Цикл 3, test-first)"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери [1-3/b]:${N} ")" choice
  case "$choice" in
    1) run_cycle1 selected ;;
    2) run_cycle2 selected ;;
    3) run_cycle3 selected ;;
    b|B) return ;;
    *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
  esac
}

# ─── создание проекта ─────────────────────────────────────────────────────────
menu_new_project() {
  header
  echo -e "${W}── Новый проект ──────────────────────────────────────${N}"
  echo
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    echo -e "${Y}Сейчас выбран режим одного проекта: ${W}$SINGLE_PROJECT${N}"
    echo -e "Чтобы создавать новые проекты, переключи настройки на каталог с несколькими проектами."
    echo
    read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
    return
  fi
  read -rp "$(echo -e "${W}Название проекта (Enter — назад):${N} ")" name
  if [[ -z "$name" ]]; then return; fi
  create_project "$name"
  echo
  echo -e "${C}Проект создан. Запустить интервью для заполнения входных данных? (s0-kickoff /new)${N}"
  read -rp "$(echo -e "${W}[Enter = да / n = пропустить]:${N} ")" run_kickoff
  if [[ "$run_kickoff" != "n" && "$run_kickoff" != "N" ]]; then
    run_agent "s0-kickoff" "$name" "/new $name"
  fi
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_kickoff() {
  header
  echo -e "${W}── Kickoff — Онбординг / Обновление проекта ─────────${N}"
  echo
  echo -e "  ${Y}1)${N} ${G}Новый проект${N} — провести интервью с нуля   ${C}(/new)${N}"
  echo -e "  ${Y}2)${N} ${C}Обновить существующий${N} — беклог, видение   ${C}(/refresh)${N}"
  echo -e "  ${Y}3)${N} Авто-определение режима                     ${C}(/start)${N}"
  echo -e "  ${Y}4)${N} Проверить полноту контекста                 ${C}(/cr)${N}"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери [1-4/b]:${N} ")" choice
  [[ "$choice" == "b" || "$choice" == "B" ]] && return

  [[ -n "${PROJECT:-}" ]] || { pick_project || return; }

  local rc=0
  case "$choice" in
    1) run_agent "s0-kickoff" "$PROJECT" "/new $PROJECT" || rc=$? ;;
    2) run_agent "s0-kickoff" "$PROJECT" "/refresh $PROJECT" || rc=$? ;;
    3) run_agent "s0-kickoff" "$PROJECT" "/start $PROJECT" || rc=$? ;;
    4) run_agent "s0-kickoff" "$PROJECT" "/cr $PROJECT" || rc=$? ;;
    *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; return ;;
  esac
  [[ $rc -eq 0 ]] && post_kickoff_menu
  return "$rc"
}

post_kickoff_menu() {
  local choice
  printf '%s\n' \
    '' 'KICKOFF ЗАВЕРШЁН. Что дальше?' \
    '  1) Подготовить запуск только Cycle 1' \
    '  2) Настроить режим цели и подготовить его запуск' \
    '  3) Проверить входные данные проекта' \
    '  4) Вернуться в Project Console'
  read -r choice
  case "$choice" in
    1) run_cycle1 selected ;;
    2) configure_goal_profile full && run_goal_mode selected ;;
    3) menu_project_inputs_review ;;
    4|b|B|'') return 0 ;;
    *) return 1 ;;
  esac
}

# ─── валидация структуры ──────────────────────────────────────────────────────
menu_validate_project() {
  header
  echo -e "${W}── Валидация и починка структуры проекта ────────────${N}"
  echo
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    echo -e "  ${Y}1)${N} Проверить проект ${W}$SINGLE_PROJECT${N}       ${C}(/validate)${N}"
    echo -e "  ${Y}3)${N} Починить проект ${W}$SINGLE_PROJECT${N}        ${C}(/fix)${N}"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1/3/b]:${N} ")" choice
  else
    echo -e "  ${Y}1)${N} Проверить один проект       ${C}(/validate)${N}"
    echo -e "  ${Y}2)${N} Проверить все проекты       ${C}(/validate all)${N}"
    echo -e "  ${Y}3)${N} Починить один проект        ${C}(/fix)${N}"
    echo -e "  ${Y}4)${N} Починить все проекты        ${C}(/fix all)${N}"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-4/b]:${N} ")" choice
  fi

  case "$choice" in
    b|B) return ;;
    1|3)
      if [[ "$PROJECTS_MODE" == "single" ]]; then
        PROJECT="$SINGLE_PROJECT"
      else
        pick_project || return
      fi
      local project="$PROJECT"
      local task; [[ "$choice" == "1" ]] && task="/validate" || task="/fix"
      run_agent "s0-validate" "$project" "$task"
      ;;
    2|4)
      [[ "$PROJECTS_MODE" == "single" ]] && { echo -e "${R}Неверный выбор${N}"; sleep 0.5; return; }
      local task
      [[ "$choice" == "2" ]] && task="/validate" || task="/fix"
      run_agent "s0-validate" "all" "$task"
      ;;
    *)
      echo -e "${R}Неверный выбор${N}"; sleep 0.5; return
      ;;
  esac
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── список проектов ──────────────────────────────────────────────────────────
print_project_progress() {
  local d="$1" name="$2" stages_done=0 s bar=""
  for s in stage1-planning stage2-requirements stage3-design stage4-dev \
            stage5-testing stage6-deploy stage7-ops; do
    [[ -n "$(ls -A "$d/$s/outputs" 2>/dev/null)" ]] && ((stages_done++))
  done
  for ((k=0; k<stages_done; k++)); do bar+="█"; done
  for ((k=stages_done; k<7; k++)); do bar+="░"; done
  echo -e "  ${W}$name${N}  ${C}$bar${N} $stages_done/7"
}

menu_list_projects() {
  header
  echo -e "${W}── Проекты ───────────────────────────────────────────${N}"
  echo
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    print_project_progress "$PROJECTS/$SINGLE_PROJECT" "$SINGLE_PROJECT"
    echo
    read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
    return
  fi

  local found=0
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* || "$name" == .* ]] && continue
    is_sdlc_project_dir "$d" || continue
    print_project_progress "$d" "$name"
    found=1
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
  [[ $found -eq 0 ]] && echo -e "  ${Y}Проектов пока нет${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── project-scoped Console actions ──────────────────────────────────────────
execute_previewed_agent() {
  local rc=0
  journal_create_run AGENT "$SINGLE_AGENT $SINGLE_TASK" 'другие primary Agents и Cycles' || return 1
  journal_acquire_lease "$CURRENT_RUN_ID" || return 1
  journal_write_state "$CURRENT_RUN_ID" RUNNING 1 1 RUNNING "$SINGLE_AGENT $SINGLE_TASK"
  ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[0]:-}"
  run_agent "$SINGLE_AGENT" "$SINGLE_PROJECT_NAME" "$SINGLE_TASK" || rc=$?
  ACTIVE_EXECUTION_PROFILE=""
  if [[ $rc -eq 0 ]]; then
    journal_append_event "$CURRENT_RUN_ID" step_succeeded COMPLETED 1 SUCCEEDED "$SINGLE_AGENT" "$SINGLE_TASK" 'runtime exit code 0'
    journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 SUCCEEDED ''
  else
    journal_append_event "$CURRENT_RUN_ID" step_failed BLOCKED 1 FAILED "$SINGLE_AGENT" "$SINGLE_TASK" "runtime exit code $rc"
    journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 FAILED "$SINGLE_AGENT $SINGLE_TASK"
  fi
  journal_release_lease "$CURRENT_RUN_ID"
  return "$rc"
}

run_agent_with_preview() {
  SINGLE_AGENT="$1"
  SINGLE_PROJECT_NAME="$2"
  SINGLE_TASK="$3"
  local -a RUN_CYCLE=("$SINGLE_AGENT:$SINGLE_TASK")
  local -a RUN_OPTIONAL=(0)
  render_execution_preview AGENT "$SINGLE_AGENT ${SINGLE_TASK:-interactive}" 'другие primary Agents и Cycles'
  confirm_execution_preview execute_previewed_agent
}

render_project_review_menu() {
  printf '%s\n' \
    'ПРОВЕРИТЬ PROJECT · READ-ONLY' \
    '  1 Весь Project' \
    '  2 Один Cycle' \
    '  3 Один Stage' \
    '  4 Один Agent и его artifacts' \
    '  5 AI routes и exact models' \
    '  6 Структуру нескольких Projects' \
    'Никакие файлы не будут изменены и workflow не будет запущен.'
}

render_project_repair_menu() {
  printf '%s\n' \
    'ИСПРАВИТЬ PROJECT · ТОЛЬКО ПОСЛЕ PREVIEW' \
    '  1 Весь Project' \
    '  2 Один Cycle' \
    '  3 Один Stage' \
    '  4 Один Agent и его artifacts' \
    '  5 Только структуру Project' \
    'Сначала будут показаны точный scope, исключения, AI и команда. Без подтверждения записи не будет.'
}

prepare_scoped_project_action() {
  local action="${1:-}" scope="${2:-}" value
  case "$action" in review|repair) ;; *) return 1 ;; esac
  case "$scope" in
    project)
      EXECUTION_SCOPE='весь выбранный Project'
      EXECUTION_EXCLUDED='другие Projects'
      ;;
    cycle:[1-3])
      value="${scope#cycle:}"
      EXECUTION_SCOPE="только Cycle $value выбранного Project"
      EXECUTION_EXCLUDED='остальные Cycles и другие Projects'
      ;;
    stage:[0-7])
      value="${scope#stage:}"
      EXECUTION_SCOPE="только Stage $value выбранного Project"
      EXECUTION_EXCLUDED='остальные Stages и другие Projects'
      ;;
    agent:*)
      value="${scope#agent:}"
      [[ -n "$value" && -d "$(find_agent_dir "$value")" ]] || return 1
      EXECUTION_SCOPE="только Agent $value и связанные с ним artifacts"
      EXECUTION_EXCLUDED='другие Agents, Cycles и Projects'
      ;;
    structure)
      [[ "$action" == repair ]] || return 1
      EXECUTION_SCOPE='только структура каталогов выбранного Project'
      EXECUTION_EXCLUDED='содержимое существующих artifacts и другие Projects'
      ;;
    *) return 1 ;;
  esac
  SCOPED_ACTION="$action"
  SCOPED_ACTION_SCOPE="$scope"
  if [[ "$action" == review ]]; then
    SCOPED_ACTION_ACCESS=read-only
    EXECUTION_TYPE=REVIEW
  else
    SCOPED_ACTION_ACCESS=write
    EXECUTION_TYPE=REPAIR
  fi
  RUN_CYCLE=("s0-validate:/$action scope=$scope")
  RUN_OPTIONAL=(0)
}

run_scoped_project_action() {
  local previous_access="${ACTIVE_AGENT_ACCESS:-}" rc=0
  ACTIVE_AGENT_ACCESS="$SCOPED_ACTION_ACCESS"
  run_agent s0-validate "$PROJECT" "/$SCOPED_ACTION scope=$SCOPED_ACTION_SCOPE" || rc=$?
  ACTIVE_AGENT_ACCESS="$previous_access"
  return "$rc"
}

select_scoped_project_action() {
  local action="$1" choice="$2" value scope
  case "$choice" in
    1) scope=project ;;
    2)
      read -rp 'Cycle [1-3]: ' value
      scope="cycle:$value"
      ;;
    3)
      read -rp 'Stage [0-7]: ' value
      scope="stage:$value"
      ;;
    4)
      read -rp 'Точный Agent id (например s4-dev): ' value
      scope="agent:$value"
      ;;
    5) [[ "$action" == repair ]] || return 1; scope=structure ;;
    *) return 1 ;;
  esac
  prepare_scoped_project_action "$action" "$scope"
}

menu_project_inputs_review() {
  header
  echo -e "${W}── Входные данные проекта (только чтение) ─────────────${N}"
  echo -e "  Project: ${C}$PROJECT${N}"
  echo -e "  Path:    ${C}$(project_path)${N}"
  echo
  find "$(project_path)" -path '*/inputs/*' -type f -print 2>/dev/null | sort | sed 's/^/  /'
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_project_overview() {
  header
  echo -e "${W}── Обзор проекта (без изменений) ────────────────────${N}"
  print_project_progress "$(project_path)" "$PROJECT"
  local unfinished
  unfinished="$(journal_latest_unfinished "$PROJECT" 2>/dev/null || true)"
  echo -e "  Незавершённый run: ${C}${unfinished:-нет}${N}"
  echo -e "  Goal profile:      ${C}$(goal_profile_path)${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_project_review() {
  header
  render_project_review_menu
  echo
  read -rp 'Выбери [1-6/b]: ' review_choice
  [[ "$review_choice" =~ ^[bB]$ ]] && return
  case "$review_choice" in
    5)
      echo -e "  Policy:  ${C}$SDLC_RUNTIME_ROUTING${N}"
      echo -e "  Base:    ${C}$BASE_PROFILE${N}"
      echo -e "  Routes:  ${C}$ROUTING_FILE${N}"
      [[ -f "$ROUTING_FILE" ]] && sed 's/^/  /' "$ROUTING_FILE"
      read -rp 'Нажми Enter...' _
      return
      ;;
    6)
      menu_list_projects
      return
      ;;
  esac
  if ! select_scoped_project_action review "$review_choice"; then
    echo -e "${R}Некорректный scope Review.${N}"
    return 1
  fi
  echo
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview run_scoped_project_action || true
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_project_repair() {
  header
  render_project_repair_menu
  echo
  local repair_choice
  read -rp 'Выбери [1-5/b]: ' repair_choice
  [[ "$repair_choice" =~ ^[bB]$ ]] && return
  if ! select_scoped_project_action repair "$repair_choice"; then
    echo -e "${R}Некорректный scope Repair.${N}"
    return 1
  fi
  echo
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview run_scoped_project_action || true
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

configure_cycle_runtime_matrix() {
  local cycle entry supervisor_profile
  supervisor_profile="$(current_profile)"
  SDLC_RUNTIME_ROUTING=per-agent
  export SDLC_RUNTIME_ROUTING
  for cycle in 1 2 3; do
    echo
    echo -e "${W}Primary profile для Cycle $cycle:${N}"
    select_step_profile || { apply_profile "$supervisor_profile" >/dev/null 2>&1 || true; return 1; }
    case "$cycle" in
      1) for entry in "${CYCLE1_AGENTS[@]}"; do write_routing_entry "agent:${entry%%:*}" "$SELECTED_PROFILE"; done ;;
      2) for entry in "${CYCLE2_AGENTS[@]}"; do write_routing_entry "agent:${entry%%:*}" "$SELECTED_PROFILE"; done ;;
      3) for entry in "${CYCLE3_AGENTS[@]}"; do write_routing_entry "agent:${entry%%:*}" "$SELECTED_PROFILE"; done ;;
    esac
  done
  apply_profile "$supervisor_profile"
}

configure_agent_runtime_override() {
  local agent supervisor_profile
  supervisor_profile="$(current_profile)"
  read -rp 'Agent id для override (например s4-dev): ' agent
  [[ "$agent" =~ ^[A-Za-z0-9._-]+$ && -d "$(find_agent_dir "$agent")" ]] || {
    echo -e "${R}Неизвестный Agent id: $agent${N}"
    return 1
  }
  select_step_profile || { apply_profile "$supervisor_profile" >/dev/null 2>&1 || true; return 1; }
  write_routing_entry "agent:$agent" "$SELECTED_PROFILE"
  apply_profile "$supervisor_profile"
}

configure_exact_agent_matrix() {
  local choice
  echo -e "${C}Сначала каждый Agent получает явный профиль своего Cycle; затем можно добавить overrides.${N}"
  configure_cycle_runtime_matrix || return 1
  while true; do
    read -rp 'Добавить override для отдельного Agent? [y/N]: ' choice
    case "$choice" in
      y|Y) configure_agent_runtime_override || return 1 ;;
      n|N|'') return 0 ;;
      *) echo -e "${R}Ответь y или n${N}" ;;
    esac
  done
}

complete_pending_first_run_ai_setup() {
  case "${PENDING_FIRST_RUN_AI_SETUP:-}" in
    '') return 0 ;;
    cycle)
      echo -e "${W}Завершаем project-specific routing по Cycle для $PROJECT.${N}"
      configure_cycle_runtime_matrix || return 1
      ;;
    matrix)
      echo -e "${W}Завершаем точную project-specific Stage/Agent matrix для $PROJECT.${N}"
      configure_exact_agent_matrix || return 1
      ;;
    *) return 1 ;;
  esac
  save_project_ai_config "$BASE_PROFILE" "$SDLC_RUNTIME_ROUTING" || return 1
  PENDING_FIRST_RUN_AI_SETUP=''
}

menu_ai_assignment() {
  header
  echo -e "${W}── Кто выполняет основные этапы и кто помогает ────${N}"
  echo "Здесь можно изменить AI-настройку выбранного проекта. Она определяет"
  echo "исполнителя каждого основного этапа и доступных ему read-only помощников,"
  echo "но не меняет порядок SDLC и сама ничего не запускает."
  echo "Перед реальным запуском итоговые назначения будут показаны в Preview."
  echo "Для Local обязательны host, provider и точный model id; fallback выключен."
  echo
  echo -e "${W}Основные исполнители:${N}"
  echo -e "  ${Y}1)${N} Одна AI-модель для всего проекта"
  echo -e "  ${Y}2)${N} Своя AI-модель для каждого цикла"
  echo -e "  ${Y}3)${N} Исключения для отдельных ролей"
  echo -e "  ${Y}4)${N} Спрашивать при подготовке каждого запуска"
  echo -e "${W}AI-помощники и проверка:${N}"
  echo -e "  ${Y}5)${N} Настроить отдельную AI-модель для read-only задач"
  echo -e "  ${Y}6)${N} Показать текущие назначения и режим помощников"
  echo -e "  ${Y}b)${N} Назад"
  read -rp "$(echo -e "${W}Выбери:${N} ")" choice
  case "$choice" in
    1)
      choose_runtime || return
      BASE_PROFILE="$(current_profile)"
      SDLC_RUNTIME_ROUTING=single
      save_project_ai_config "$BASE_PROFILE" single
      ;;
    2)
      configure_cycle_runtime_matrix && save_project_ai_config "$BASE_PROFILE" per-agent
      ;;
    3)
      configure_exact_agent_matrix && save_project_ai_config "$BASE_PROFILE" per-agent
      ;;
    4)
      SDLC_RUNTIME_ROUTING=ask
      save_project_ai_config "$BASE_PROFILE" ask
      ;;
    5)
      configure_cross_runtime_subagents && save_project_ai_config "$BASE_PROFILE" "$SDLC_RUNTIME_ROUTING"
      ;;
    6) show_runtime_routing; render_subagent_execution_summary; read -rp 'Нажми Enter...' _ ;;
    b|B|'') return ;;
  esac
}

menu_utilities() {
  header
  echo -e "${W}── Утилиты выбранного проекта ───────────────────────${N}"
  echo -e "  ${Y}1)${N} Secrets scan     ${C}(s0-secrets)${N}"
  echo -e "  ${Y}2)${N} Tracker          ${C}(s0-tracker)${N}"
  echo -e "  ${Y}3)${N} Quality gates    ${C}(s0-quality-gates)${N}"
  echo -e "  ${Y}4)${N} GitHub helper    ${C}(s0-github)${N}"
  echo -e "  ${Y}5)${N} Structure check ${C}(s0-validate)${N}"
  echo -e "  ${Y}b)${N} Назад"
  read -rp "$(echo -e "${W}Выбери:${N} ")" choice
  local agent task
  case "$choice" in
    1) agent=s0-secrets; task=/env ;;
    2) agent=s0-tracker; task=/sprint-status ;;
    3) agent=s0-quality-gates; task=/validate-gates ;;
    4) agent=s0-github; task=/status ;;
    5) agent=s0-validate; task=/validate ;;
    b|B|'') return ;;
    *) return 1 ;;
  esac
  local -a RUN_CYCLE=("$agent:$task")
  local -a RUN_OPTIONAL=(0)
  render_execution_preview UTILITY "$agent $task" 'остальные utilities'
  read -rp 'r — запустить, b — назад: ' choice
  [[ "$choice" =~ ^[rR]$ ]] && run_agent "$agent" "$PROJECT" "$task"
}

menu_unfinished_run() {
  local run_id choice
  run_id="$(journal_latest_unfinished "$PROJECT" 2>/dev/null || true)"
  if [[ -z "$run_id" ]]; then
    echo -e "${Y}У проекта нет незавершённых запусков.${N}"
  else
    echo -e "${W}Последний незавершённый run:${N} ${C}$run_id${N}"
    sed -n '1,30p' "$(journal_run_dir "$PROJECT" "$run_id")/state.md"
    echo -e "${Y}Возобновление выполняется по frozen plan и доказанному следующему шагу, не через vendor resume.${N}"
    echo -e "  ${Y}1)${N} Показать evidence"
    echo -e "  ${Y}2)${N} Retry с доказанного следующего шага через новый child run"
    echo -e "  ${Y}3)${N} Открыть Repair"
    echo -e "  ${Y}4)${N} Отменить run"
    echo -e "  ${Y}b)${N} Назад"
    read -rp 'Выбери: ' choice
    case "$choice" in
      1) sed -n '1,160p' "$(journal_run_dir "$PROJECT" "$run_id")/events.jsonl"; read -rp 'Нажми Enter...' _ ;;
      2) retry_journal_run "$run_id" ;;
      3) menu_project_repair ;;
      4)
        journal_write_state "$run_id" CANCELLED 0 0 UNKNOWN ''
        journal_append_event "$run_id" run_cancelled CANCELLED 0 UNKNOWN '' '' 'cancelled explicitly by user'
        ;;
      b|B|'') return ;;
    esac
    return
  fi
  read -rp 'Нажми Enter...' _
}

retry_journal_run() {
  local parent_run="$1" dir next total line n profile source
  local -a all_entries=() all_profiles=() all_sources=()
  dir="$(journal_run_dir "$PROJECT" "$parent_run")"
  next="$(journal_resume_point "$PROJECT" "$parent_run")" || return 1
  while IFS= read -r line; do
    [[ "$line" =~ ^([0-9]+)\.\ (.+)$ ]] || continue
    n="${BASH_REMATCH[1]}"
    all_entries+=("${BASH_REMATCH[2]}")
    profile="$(awk -F': ' -v key="step_${n}_profile" '$1 == key { sub(/^[^:]*: /, ""); print; exit }' "$dir/plan.md")"
    source="$(awk -F': ' -v key="step_${n}_route_source" '$1 == key { sub(/^[^:]*: /, ""); print; exit }' "$dir/plan.md")"
    all_profiles+=("$profile")
    all_sources+=("$source")
  done < "$dir/plan.md"
  total="${#all_entries[@]}"
  (( next <= total )) || {
    echo -e "${Y}Все шаги уже имеют success evidence; сначала выполни Review.${N}"
    return 1
  }
  local -a RUN_CYCLE=("${all_entries[@]:$((next - 1))}")
  local -a RUN_OPTIONAL=()
  EXECUTION_STEP_PROFILES=("${all_profiles[@]:$((next - 1))}")
  EXECUTION_STEP_SOURCES=("${all_sources[@]:$((next - 1))}")
  local entry
  for entry in "${RUN_CYCLE[@]}"; do RUN_OPTIONAL+=(0); done
  EXECUTION_TYPE=RESUME
  EXECUTION_SCOPE="child retry of $parent_run from original step $next/$total"
  EXECUTION_EXCLUDED="proven steps 1-$((next - 1)); all scopes outside parent plan"
  EXECUTION_TITLE="Retry $parent_run"
  EXECUTION_CYCLE_ID=0
  PARENT_RUN_ID="$parent_run"
  USE_EXISTING_FROZEN_ROUTES=1
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview execute_previewed_cycle
  local rc=$?
  USE_EXISTING_FROZEN_ROUTES=0
  PARENT_RUN_ID=""
  return "$rc"
}

menu_local_repositories() {
  local rc=0
  SDLC_LAUNCHER_PARENT=1 SDLC_PARENT_PROJECT="$PROJECT" SDLC_UI_VIEW="$SDLC_UI_VIEW" \
    bash "$AGENTS/localrun.sh" || rc=$?
  [[ $rc -eq 86 ]] && return 2
  return "$rc"
}

menu_launcher_settings() {
  menu_settings
}

project_selector() {
  local choice i d name had_ai_config
  local -a projects=()
  while true; do
    header
    echo -e "${W}── Выбор SDLC Project ────────────────────────────────${N}"
    echo
    render_launcher_entry_intro
    projects=()
    if [[ "$PROJECTS_MODE" == single ]]; then
      projects+=("$SINGLE_PROJECT")
    else
      while IFS= read -r -d '' d; do
        name="$(basename "$d")"
        [[ "$name" == _* || "$name" == .* ]] && continue
        is_recognized_sdlc_project "$d" || continue
        projects+=("$name")
      done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
    fi
    echo
    for i in "${!projects[@]}"; do
      printf '  %s) %s\n     %s/%s\n' "$((i + 1))" "${projects[$i]}" "$PROJECTS" "${projects[$i]}"
    done
    printf '%s\n' '  n) Создать новый SDLC Project' '  l) Локальные репозитории' \
      '  g) Настройки launcher-а' '  q) Завершить launcher'
    read -rp 'Выбери номер, n/l/g/q: ' choice
    case "$choice" in
      n|N) menu_new_project ;;
      l|L) menu_local_repositories ;;
      g|G) menu_launcher_settings ;;
      q|Q) return 2 ;;
      *)
        if valid_menu_index "$choice" "${#projects[@]}"; then
          PROJECT="${projects[$((choice - 1))]}"
          had_ai_config=0
          [[ -f "$(project_ai_config_path)" ]] && had_ai_config=1
          activate_project_ai_config || {
            echo -e "${R}AI configuration проекта повреждена или неполна.${N}"
            return 1
          }
          if [[ -n "${PENDING_FIRST_RUN_AI_SETUP:-}" ]]; then
            if [[ "$had_ai_config" == "1" ]]; then
              echo -e "${Y}У проекта уже есть AI routing; first-run intent не перезаписывает его.${N}"
              PENDING_FIRST_RUN_AI_SETUP=''
            else
              complete_pending_first_run_ai_setup || return 1
            fi
          elif [[ "$had_ai_config" == "0" ]]; then
            save_project_ai_config "$BASE_PROFILE" "$SDLC_RUNTIME_ROUTING" || return 1
          fi
          journal_mark_interrupted_runs
          PROJECT_CONSOLE_INTRO_PENDING=1
          return 0
        fi
        ;;
    esac
  done
}

project_console() {
  local choice rc
  while true; do
    header
    if [[ "$PROJECT_CONSOLE_INTRO_PENDING" == "1" ]]; then
      render_project_console_intro
      echo
      PROJECT_CONSOLE_INTRO_PENDING=0
    fi
    render_project_console
    echo
    read -rp 'Выбери действие: ' choice
    if [[ "$choice" == p || "$choice" == P ]]; then
      project_selector || return $?
      continue
    fi
    dispatch_console_action "$choice"
    rc=$?
    [[ $rc -eq 2 ]] && return 2
  done
}


# ─── настройки ────────────────────────────────────────────────────────────────
menu_settings() {
  apply_profile "$BASE_PROFILE" || true
  while true; do
    header
    echo -e "${W}── Настройки ────────────────────────────────────────${N}"
    echo
    echo -e "  Runtime:  ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
    echo -e "  CLI:      ${C}$(runtime_bin)${N}"
    [[ "$AGENT_RUNTIME" == "local" ]] &&
      echo -e "  Local:    ${C}$LOCAL_AGENT_HOST / $LOCAL_MODEL_PROVIDER / $LOCAL_MODEL${N}"
    echo -e "  Routing:  ${C}$SDLC_RUNTIME_ROUTING${N}"
    echo -e "  Subagents:${C} $SDLC_SUBAGENTS (max $SDLC_SUBAGENT_MAX)${N}"
    if [[ "$SDLC_SUBAGENTS" == "cross-runtime" ]]; then
      echo -e "  Worker:   ${C}$(subagent_profile_label)${N}"
      echo -e "  Tasks:    ${C}$SDLC_SUBAGENT_TASKS${N}"
    fi
    if [[ "$PROJECTS_MODE" == "single" ]]; then
      echo -e "  Projects: ${C}$PROJECTS/$SINGLE_PROJECT${N} (один проект)"
    else
      echo -e "  Projects: ${C}${PROJECTS:-не настроены}${N}"
    fi
    echo
    echo -e "  ${Y}1)${N} Выбрать основной AI runtime/profile"
    echo -e "  ${Y}2)${N} Настроить local profile (host/provider/exact model)"
    echo -e "  ${Y}3)${N} Выбрать routing policy"
    echo -e "  ${Y}4)${N} Добавить/изменить per-stage или per-agent route"
    echo -e "  ${Y}5)${N} Настроить subagents"
    echo -e "  ${Y}6)${N} Изменить каталог SDLC-проектов"
    echo -e "  ${Y}7)${N} Проверить основной runtime/profile"
    echo -e "  ${Y}8)${N} Переключить подробный/краткий вид"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-8/b]:${N} ")" choice
    case "$choice" in
      1) choose_runtime ;;
      2)
        configure_local_profile && {
          AGENT_RUNTIME="local"
          export AGENT_RUNTIME
          write_config_value AGENT_RUNTIME local
          BASE_PROFILE="$(current_profile)"
        }
        ;;
      3) select_routing_policy yes || true ;;
      4) configure_runtime_route ;;
      5) configure_subagent_settings ;;
      6) configure_projects_dir ;;
      7)
        apply_profile "$BASE_PROFILE"
        read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _
        ;;
      8) toggle_ui_view >/dev/null ;;
      b|B) return ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

# ─── главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    if [[ -z "${PROJECT:-}" ]]; then
      project_selector || return 0
    fi
    project_console
    [[ $? -eq 2 ]] && return 0
  done
}

main() {
  if is_first_run; then
    FIRST_RUN_WIZARD=1
    ensure_first_run_runtime || exit 1
    BASE_PROFILE="$(current_profile)"
    initialize_first_run_execution_policy || exit 1
    configure_first_run_ai_mode || exit 1
    render_first_run_execution_policy
    ensure_first_run_projects_dir || exit 1
    ensure_ui_view || exit 1
    FIRST_RUN_WIZARD=0
  else
    ensure_runtime || exit 1
    BASE_PROFILE="$(current_profile)"
    ensure_routing_policy || exit 1
    ensure_subagent_settings || exit 1
    ensure_projects_dir || exit 1
    ensure_ui_view || exit 1
  fi
  LAUNCHER_BASE_PROFILE="$BASE_PROFILE"
  LAUNCHER_ROUTING_POLICY="$SDLC_RUNTIME_ROUTING"
  LAUNCHER_SUBAGENTS="$SDLC_SUBAGENTS"
  LAUNCHER_SUBAGENT_MAX="$SDLC_SUBAGENT_MAX"
  LAUNCHER_SUBAGENT_PROFILE="$SDLC_SUBAGENT_PROFILE"
  LAUNCHER_SUBAGENT_TASKS="$SDLC_SUBAGENT_TASKS"
  main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

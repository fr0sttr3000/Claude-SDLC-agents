#!/bin/bash
# Local Run Interactive Launcher
# Управление локальными repositories независимо от forge/provider — push ЗАПРЕЩЁН

# Пути вычисляются от расположения скрипта — переносимо между окружениями
AGENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$AGENTS")"
NOTES="$VAULT/Local_Run"
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
export SDLC_UI_VIEW="${SDLC_UI_VIEW:-detailed}"
AGENT_RUNNER="$AGENTS/_runtimes/agent-run.sh"
source "$AGENTS/_runtimes/runtime-boundary.sh"

# Конфигурация пути к локальным проектам.
# Приоритет: env LOCALRUN_PROJECTS > config-файл > first-run wizard.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sdlc-agents"
CONFIG_FILE="$CONFIG_DIR/config"
ROUTING_FILE="${LOCALRUN_ROUTING_FILE:-$CONFIG_DIR/localrun-runtime-routing}"
PROJECTS=""
BASE_PROFILE=""

# ─── цвета ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; M='\033[0;35m'; N='\033[0m'


# ─── конфигурация runtime и локальных проектов ───────────────────────────────
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

runtime_supports_interactive() {
  case "$AGENT_RUNTIME:${LOCAL_AGENT_HOST:-}" in
    codex:*|local:codex-oss) return 1 ;;
    *) return 0 ;;
  esac
}

report_interactive_codex_block() {
  echo -e "${R}BLOCKED: interactive Codex cannot disable ambient user configuration; use a registered command in task mode.${N}"
}

runtime_bin() {
  case "$AGENT_RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
    local)
      [[ -n "${LOCAL_AGENT_HOST:-}" ]] &&
        echo "$AGENTS/_runtimes/local-hosts/$LOCAL_AGENT_HOST" || echo "не выбран"
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
    [[ "$LOCAL_AGENT_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
    bin="${LOCAL_HOST_REGISTRY:-$AGENTS/_runtimes/local-hosts}/$LOCAL_AGENT_HOST"
    [[ -f "$bin" && -x "$bin" ]] || {
      echo -e "${R}Local agent host '$LOCAL_AGENT_HOST' не зарегистрирован: $bin${N}"
      return 1
    }
    if [[ "$LOCAL_AGENT_HOST" == "codex-oss" ]] && ! command -v "${LOCAL_CODEX_BIN:-codex}" >/dev/null 2>&1; then
      echo -e "${R}codex-oss требует Codex CLI.${N}"
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
    configured="$(read_config_value LOCALRUN_AGENT_RUNTIME || true)"
  fi
  [[ -n "$configured" ]] && init_runtime "$configured" || return 1
  [[ -n "${LOCAL_AGENT_HOST:-}" ]] || LOCAL_AGENT_HOST="$(read_config_value LOCALRUN_LOCAL_AGENT_HOST || true)"
  [[ -n "${LOCAL_MODEL_PROVIDER:-}" ]] || LOCAL_MODEL_PROVIDER="$(read_config_value LOCALRUN_LOCAL_MODEL_PROVIDER || true)"
  [[ -n "${LOCAL_MODEL:-}" ]] || LOCAL_MODEL="$(read_config_value LOCALRUN_LOCAL_MODEL || true)"
  [[ -n "${LOCAL_MODEL_ENDPOINT:-}" ]] || LOCAL_MODEL_ENDPOINT="$(read_config_value LOCALRUN_LOCAL_MODEL_ENDPOINT || true)"
  [[ -n "${SDLC_SUBAGENTS:-}" ]] || SDLC_SUBAGENTS="$(read_config_value LOCALRUN_SUBAGENTS || true)"
  [[ -n "${SDLC_SUBAGENT_MAX:-}" ]] || SDLC_SUBAGENT_MAX="$(read_config_value LOCALRUN_SUBAGENT_MAX || true)"
  [[ -n "${SDLC_SUBAGENT_PROFILE:-}" ]] || SDLC_SUBAGENT_PROFILE="$(read_config_value LOCALRUN_SUBAGENT_PROFILE || true)"
  [[ -n "${SDLC_SUBAGENT_TASKS:-}" ]] || SDLC_SUBAGENT_TASKS="$(read_config_value LOCALRUN_SUBAGENT_TASKS || true)"
  [[ -n "${SDLC_RUNTIME_ROUTING:-}" ]] || SDLC_RUNTIME_ROUTING="$(read_config_value LOCALRUN_RUNTIME_ROUTING || true)"
  export LOCAL_AGENT_HOST LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_MODEL_ENDPOINT
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS SDLC_RUNTIME_ROUTING
}

configure_local_profile() {
  local persist="${1:-yes}" host provider model endpoint
  read -rp "Local agent host id (например codex-oss): " host
  [[ "$host" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  if [[ "$host" == "codex-oss" ]]; then
    read -rp "Provider [ollama/lmstudio]: " provider
    [[ "$provider" == "ollama" || "$provider" == "lmstudio" ]] || return 1
    endpoint=""
  else
    read -rp "Provider id: " provider
    read -rp "Endpoint URL (без токена): " endpoint
    [[ -n "$endpoint" ]] || return 1
  fi
  read -rp "Точный model id: " model
  for value in "$provider" "$model" "$endpoint"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'|'* && "$value" != *'"'* ]] || return 1
  done
  [[ -n "$provider" && -n "$model" ]] || return 1
  LOCAL_AGENT_HOST="$host"
  LOCAL_MODEL_PROVIDER="$provider"
  LOCAL_MODEL="$model"
  LOCAL_MODEL_ENDPOINT="$endpoint"
  export LOCAL_AGENT_HOST LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_MODEL_ENDPOINT
  if [[ "$persist" == "yes" ]]; then
    write_config_value LOCALRUN_LOCAL_AGENT_HOST "$host"
    write_config_value LOCALRUN_LOCAL_MODEL_PROVIDER "$provider"
    write_config_value LOCALRUN_LOCAL_MODEL "$model"
    write_config_value LOCALRUN_LOCAL_MODEL_ENDPOINT "$endpoint"
  fi
}

select_runtime() {
  local allow_back="${1:-yes}"
  local choice prompt_suffix
  while true; do
    header
    echo -e "${W}── Runtime AI-вендора ───────────────────────────────${N}"
    echo
    echo -e "Текущий runtime: ${C}$(runtime_label)${N}${AGENT_RUNTIME:+ ($AGENT_RUNTIME)}"
    echo
    echo -e "  ${Y}1)${N} Claude"
    echo -e "  ${Y}2)${N} Codex"
    echo -e "  ${Y}3)${N} Gemini"
    echo -e "  ${Y}4)${N} Local model (registered agent host)"
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
      4) AGENT_RUNTIME="local"; configure_local_profile || continue ;;
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
    write_config_value LOCALRUN_AGENT_RUNTIME "$AGENT_RUNTIME"
    BASE_PROFILE="$(current_profile)"
    echo
    echo -e "${G}✓ Runtime: ${W}$(runtime_label)${N}"
    ensure_runtime_available || true
    echo
    read -rp "$(echo -e "${W}Нажми Enter для продолжения...${N} ")" _
    return 0
  done
}

ensure_runtime() {
  load_runtime && return 0
  select_runtime no
}

set_localrun_projects() {
  local dir
  dir="$(expand_path "$1")"
  [[ -z "$dir" ]] && return 1
  mkdir -p "$dir" || return 1
  LOCALRUN_PROJECTS="$(cd "$dir" && pwd -P)"
  PROJECTS="$LOCALRUN_PROJECTS"
  export LOCALRUN_PROJECTS
}

load_localrun_projects() {
  local configured=""
  if [[ -n "${LOCALRUN_PROJECTS:-}" ]]; then
    configured="$LOCALRUN_PROJECTS"
  else
    configured="$(read_config_value LOCALRUN_PROJECTS || true)"
  fi
  [[ -n "$configured" ]] && set_localrun_projects "$configured"
}

configure_localrun_projects() {
  local input
  while true; do
    header
    echo -e "${W}── Настройка каталога локальных repositories ───────${N}"
    echo
    echo -e "Укажи каталог, куда Local Run будет клонировать и где будет искать репозитории."
    echo -e "Launcher показывает только этот явно настроенный каталог и не подставляет путь по умолчанию."
    [[ -n "${LOCALRUN_PROJECTS:-}" ]] && echo -e "Текущее значение env: ${C}${LOCALRUN_PROJECTS}${N}"
    echo
    read -rp "$(echo -e "${W}Путь (b — отмена):${N} ")" input
    [[ "$input" == "b" || "$input" == "B" ]] && return 1
    if [[ -z "$input" ]]; then
      echo -e "${R}Путь обязателен. Launcher не подставляет каталог по умолчанию.${N}"
      sleep 0.8
      continue
    fi
    set_localrun_projects "$input" || { echo -e "${R}Не удалось настроить каталог: $input${N}"; sleep 1; continue; }
    write_config_value LOCALRUN_PROJECTS "$LOCALRUN_PROJECTS"
    echo
    echo -e "${G}✓ Каталог локальных проектов: ${W}$LOCALRUN_PROJECTS${N}"
    echo -e "  Изменить позже: настройки Local Run или env ${W}LOCALRUN_PROJECTS${N}"
    echo
    read -rp "$(echo -e "${W}Нажми Enter для продолжения...${N} ")" _
    return 0
  done
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
  [[ -z "$extra" ]] || return 1
  init_runtime "$runtime" || return 1
  if [[ "$runtime" == "local" ]]; then
    [[ -n "$provider" && -n "$model" && -n "$host" ]] || return 1
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
  echo -e "  ${Y}1)${N} Claude  ${Y}2)${N} Codex  ${Y}3)${N} Gemini  ${Y}4)${N} Local"
  read -rp "Профиль шага [1-4]: " choice
  case "$choice" in
    1) AGENT_RUNTIME="claude" ;;
    2) AGENT_RUNTIME="codex" ;;
    3) AGENT_RUNTIME="gemini" ;;
    4) AGENT_RUNTIME="local"; configure_local_profile no || return 1 ;;
    *) return 1 ;;
  esac
  export AGENT_RUNTIME
  SELECTED_PROFILE="$(current_profile)"
  apply_profile "$SELECTED_PROFILE"
}

select_routing_policy() {
  local choice
  echo -e "  ${Y}1)${N} single  ${Y}2)${N} per-stage  ${Y}3)${N} per-agent  ${Y}4)${N} ask"
  read -rp "Routing policy [1-4]: " choice
  case "$choice" in
    1) SDLC_RUNTIME_ROUTING="single" ;;
    2) SDLC_RUNTIME_ROUTING="per-stage" ;;
    3) SDLC_RUNTIME_ROUTING="per-agent" ;;
    4) SDLC_RUNTIME_ROUTING="ask" ;;
    *) return 1 ;;
  esac
  export SDLC_RUNTIME_ROUTING
  write_config_value LOCALRUN_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
}

ensure_routing_policy() {
  case "${SDLC_RUNTIME_ROUTING:-}" in
    single|per-stage|per-agent|ask) ;;
    "") select_routing_policy || return 1 ;;
    *) return 1 ;;
  esac
}

configure_subagent_settings() {
  echo -e "${Y}Workers: off${N}"
  echo "  BLOCKED до capability-enforced bounded read scope; prompt-only isolation недостаточна."
  SDLC_SUBAGENTS="off"
  SDLC_SUBAGENT_MAX=2
  SDLC_SUBAGENT_PROFILE=""
  SDLC_SUBAGENT_TASKS=""
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_TASKS
  write_config_value LOCALRUN_SUBAGENTS "$SDLC_SUBAGENTS"
  write_config_value LOCALRUN_SUBAGENT_MAX "$SDLC_SUBAGENT_MAX"
  write_config_value LOCALRUN_SUBAGENT_PROFILE "$SDLC_SUBAGENT_PROFILE"
  write_config_value LOCALRUN_SUBAGENT_TASKS "$SDLC_SUBAGENT_TASKS"
}

ensure_subagent_settings() {
  case "${SDLC_SUBAGENTS:-}" in
    off|"")
      SDLC_SUBAGENTS=off
      SDLC_SUBAGENT_PROFILE=''
      SDLC_SUBAGENT_TASKS=''
      ;;
    auto|cross-runtime)
      echo -e "${R}BLOCKED: worker execution отключён до capability-enforced bounded read scope.${N}"
      return 1
      ;;
    *) return 1 ;;
  esac
  valid_menu_index "${SDLC_SUBAGENT_MAX:-}" 16
}

normalize_subagent_tasks() {
  local raw="${1:-}" item joined
  local analysis=0 research=0 review=0 test_interpretation=0
  local -a items=() result=()
  [[ -n "$raw" ]] || return 1
  IFS=',' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    case "$item" in
      analysis) analysis=1 ;; research) research=1 ;; review) review=1 ;;
      test-interpretation) test_interpretation=1 ;; *) return 1 ;;
    esac
  done
  (( analysis )) && result+=(analysis)
  (( research )) && result+=(research)
  (( review )) && result+=(review)
  (( test_interpretation )) && result+=(test-interpretation)
  joined="$(IFS=,; echo "${result[*]}")"
  [[ -n "$joined" ]] || return 1
  printf '%s\n' "$joined"
}

validate_subagent_profile() {
  local profile="${1:-}" runtime provider model host endpoint extra value
  IFS='|' read -r runtime provider model host endpoint extra <<< "$profile"
  [[ -z "$extra" ]] || return 1
  case "$runtime" in
    claude|codex) [[ -z "$provider$model$host$endpoint" ]] || return 1 ;;
    local) [[ -n "$provider" && -n "$model" && "$host" == codex-oss ]] || return 1 ;;
    *) return 1 ;;
  esac
  for value in "$runtime" "$provider" "$model" "$host" "$endpoint"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'"'* ]] || return 1
  done
}

subagent_profile_label() {
  local runtime provider model host endpoint
  validate_subagent_profile "${SDLC_SUBAGENT_PROFILE:-}" || return 1
  IFS='|' read -r runtime provider model host endpoint <<< "$SDLC_SUBAGENT_PROFILE"
  case "$runtime" in
    claude) printf 'Claude / external CLI' ;; codex) printf 'Codex / external CLI' ;;
    local) printf 'Local / %s / %s / %s' "$host" "$provider" "$model" ;;
  esac
}

lookup_route() {
  local key="$1"
  [[ -f "$ROUTING_FILE" ]] || return 1
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ROUTING_FILE"
}

write_routing_entry() {
  local key="$1" profile="$2" tmp
  [[ "$key" =~ ^(stage:localrun|agent:l[1-4]-(analyze|setup|build|run))$ ]] || return 1
  mkdir -p "$CONFIG_DIR"
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
}

configure_runtime_route() {
  local key
  read -rp "Route key (stage:localrun или agent:l1-analyze): " key
  select_step_profile || return 1
  write_routing_entry "$key" "$SELECTED_PROFILE" || return 1
  apply_profile "$BASE_PROFILE"
}

resolve_step_runtime() {
  local agent="$1" key profile
  case "$SDLC_RUNTIME_ROUTING" in
    single) apply_profile "$BASE_PROFILE" ;;
    per-stage)
      key="stage:localrun"
      profile="$(lookup_route "$key" || true)"
      [[ -n "$profile" ]] || { echo -e "${R}Нет route $key; silent fallback запрещён.${N}"; return 1; }
      apply_profile "$profile"
      ;;
    per-agent)
      key="agent:$agent"
      profile="$(lookup_route "$key" || true)"
      [[ -n "$profile" ]] || { echo -e "${R}Нет route $key; silent fallback запрещён.${N}"; return 1; }
      apply_profile "$profile"
      ;;
    ask) select_step_profile ;;
    *) return 1 ;;
  esac
}

# ─── описания агентов ─────────────────────────────────────────────────────────
declare -A AGENT_DESC=(
  [l1-analyze]="Project Analyzer — изучить структуру, стек, зависимости"
  [l2-setup]="Project Setup — установить зависимости, создать .env"
  [l3-build]="Project Builder — собрать проект"
  [l4-run]="Project Runner — запустить и проверить (smoke test)"
)

# ─── pipeline ─────────────────────────────────────────────────────────────────
declare -a PIPELINE=(
  "l1-analyze:/analyze"
  "l2-setup:/setup"
  "l3-build:/build"
  "l4-run:/run"
)

valid_local_folder() {
  local folder="${1:-}"
  local component_re='^[[:alnum:]][[:alnum:]_. -]*$'
  [[ -n "$folder" && "$folder" != "." && "$folder" != ".." ]] &&
    [[ "$folder" != [[:space:]]* && "$folder" != *[[:space:]] ]] &&
    [[ "$folder" =~ $component_re ]]
}

local_repository_source_kind() {
  local source="${1:-}"
  [[ -n "$source" && "$source" != -* &&
    "$source" != *$'\n'* && "$source" != *$'\r'* && "$source" != *$'\t'* ]] || return 1
  case "$source" in
    http://?*|https://?*|ssh://?*|git://?*|file://?*) printf 'url\n' ;;
    *)
      if [[ "$source" =~ ^[^/@[:space:]]+@[^/:[:space:]]+:.+ ]]; then
        printf 'scp\n'
      elif [[ -e "$source" ]]; then
        printf 'local\n'
      else
        return 1
      fi
      ;;
  esac
}

local_repository_default_folder() {
  local source="${1:-}" tail folder
  local_repository_source_kind "$source" >/dev/null || return 1
  source="${source%/}"
  tail="${source##*/}"
  [[ "$tail" == *:* ]] && tail="${tail##*:}"
  folder="${tail%.git}"
  valid_local_folder "$folder" || return 1
  printf '%s\n' "$folder"
}

local_repository_root_is_exact() {
  local target="$1" resolved top
  [[ -d "$target" && ! -L "$target" ]] || return 1
  resolved="$(cd "$target" && pwd -P)" || return 1
  top="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [[ "$top" == "$resolved" ]]
}

valid_menu_index() {
  local value="${1:-}" maximum="${2:-0}"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] &&
    [[ "$maximum" =~ ^[0-9]+$ ]] &&
    (( 10#$value >= 1 && 10#$value <= 10#$maximum ))
}

local_repositories_action_map() {
  printf '%s\n' \
    '1|add-or-update' '2|full-preparation' '3|one-step' \
    '4|update-notes' '5|list' '6|settings' \
    'p|parent' '?|help' 'q|quit'
}

localrun_exit_code() {
  local action="$1" mode="${2:-standalone}"
  case "$action:$mode" in
    parent:*) printf '0\n' ;;
    quit:embedded) printf '86\n' ;;
    quit:*) printf '0\n' ;;
    *) return 1 ;;
  esac
}

render_local_repositories_menu() {
  printf '%s\n' 'ЛОКАЛЬНЫЕ РЕПОЗИТОРИИ' 'Git push: ЗАПРЕЩЁН' ''
  if [[ "${SDLC_UI_VIEW:-detailed}" == compact ]]; then
    printf '%s\n' \
      '1 Добавить/обновить' '2 Полная подготовка' '3 Один шаг' \
      '4 Обновить заметки' '5 Показать repositories' '6 Настройки AI/каталога'
  else
    printf '%s\n' \
      '1 Добавить или обновить repository — Clone нового или Pull существующего после Preview' \
      '2 Подготовить и запустить полностью — Analyze → Install & configure → Build → Start & smoke' \
      '3 Выполнить один шаг — один из четырёх шагов и только для выбранного repository' \
      '4 Обновить технические заметки — отдельно от необязательного Pull' \
      '5 Показать repositories — пути и состояние overview/setup/build/run' \
      '6 Настроить AI и каталог — отдельный профиль Local Repositories'
  fi
  if [[ "${SDLC_LAUNCHER_PARENT:-0}" == 1 ]]; then
    printf 'p Вернуться к %s\n' "${SDLC_PARENT_PROJECT:-Project Console}"
  else
    printf '%s\n' 'p Вернуться / завершить Local Repositories'
  fi
  printf '%s\n' '? Пояснить различия' 'q Завершить launcher'
}

localrun_step_label() {
  case "$1" in
    l1-analyze) printf 'Analyze' ;;
    l2-setup) printf 'Install & configure' ;;
    l3-build) printf 'Build' ;;
    l4-run) printf 'Start & smoke' ;;
    *) printf '%s' "$1" ;;
  esac
}

render_localrun_execution_preview() {
  local project="$1"
  shift
  local entry agent task
  printf '%s\n' 'ПРОВЕРКА ЗАПУСКА · ЛОКАЛЬНЫЕ РЕПОЗИТОРИИ'
  printf 'REPOSITORY: %s\nCODE PATH:  %s/%s\nNOTES PATH: %s/%s\n' \
    "$project" "$PROJECTS" "$project" "$NOTES" "$project"
  printf '%s\n' 'GIT PUSH: ЗАПРЕЩЁН' 'No action has run yet.' ''
  printf 'WORKERS:   off (BLOCKED until bounded read enforcement)\n\n'
  for entry in "$@"; do
    agent="${entry%%:*}"
    task="${entry#*:}"
    case "$agent" in
      l1-analyze) printf '  1 Analyze — read code; write overview.md | %s %s\n' "$agent" "$task" ;;
      l2-setup) printf '  2 Install & configure — dependencies/env/services; write setup.md | %s %s\n' "$agent" "$task" ;;
      l3-build) printf '  3 Build — build artifacts; write build.md | %s %s\n' "$agent" "$task" ;;
      l4-run) printf '  4 Start & smoke — processes/smoke/local adjustments; write run.md | %s %s\n' "$agent" "$task" ;;
      *) printf '  - %s — %s %s\n' "$(localrun_step_label "$agent")" "$agent" "$task" ;;
    esac
  done
}

# ─── шапка ────────────────────────────────────────────────────────────────────
header() {
  clear
  echo -e "${M}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${M}║${W}        Локальные репозитории и запуск кода          ${M}║${N}"
  echo -e "${M}║${R}           ⚠  git push ЗАПРЕЩЁН                      ${M}║${N}"
  echo -e "${M}╚══════════════════════════════════════════════════════╝${N}"
  echo -e "  Runtime: ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
  [[ "$AGENT_RUNTIME" == "local" ]] &&
    echo -e "  Local:   ${C}${LOCAL_AGENT_HOST:-?} / ${LOCAL_MODEL_PROVIDER:-?} / ${LOCAL_MODEL:-?}${N}"
  echo -e "  Routing: ${C}${SDLC_RUNTIME_ROUTING:-не выбран}${N}"
  echo -e "  Workers: ${C}off — BLOCKED до bounded read enforcement${N}"
  [[ "${SDLC_SUBAGENTS:-}" == "cross-runtime" ]] &&
    echo -e "  Worker:  ${C}$(subagent_profile_label)${N}"
  if [[ -n "${LOCALRUN_PROJECTS:-}" ]]; then
    echo -e "  Projects: ${C}$LOCALRUN_PROJECTS${N}"
  else
    echo -e "  Projects: ${Y}не настроены${N}"
  fi
  echo
}

# ─── статус заметок проекта ───────────────────────────────────────────────────
project_status() {
  local name="$1"
  local notes_dir="$NOTES/$name"
  local icons=""
  [[ -f "$notes_dir/overview.md" ]] && icons+="${G}●${N}" || icons+="${R}○${N}"
  [[ -f "$notes_dir/setup.md"    ]] && icons+="${G}●${N}" || icons+="${R}○${N}"
  [[ -f "$notes_dir/build.md"    ]] && icons+="${G}●${N}" || icons+="${R}○${N}"
  [[ -f "$notes_dir/run.md"      ]] && icons+="${G}●${N}" || icons+="${R}○${N}"
  echo -e "$icons"   # ● analyze ● setup ● build ● run
}

# ─── выбор локального проекта ─────────────────────────────────────────────────
pick_local_project() {
  echo -e "${C}Локальные проекты${N} (${Y}${PROJECTS}/${N}):"
  echo -e "${C}  Статус: ${G}●${N}=готово  ${R}○${N}=нет  (анализ / setup / build / run)"
  echo
  local i=1
  local -a proj_list=()
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* ]] && continue
    valid_local_folder "$name" || continue
    proj_list+=("$name")
    local status
    status=$(project_status "$name")
    printf "  ${Y}%2d)${N} ${W}%-28s${N} %b\n" "$i" "$name" "$status"
    ((i++))
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

  if [[ ${#proj_list[@]} -eq 0 ]]; then
    echo -e "  ${Y}Проектов нет — сначала клонируй (пункт 1)${N}"
    echo
    return 1
  fi

  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери проект [1-${#proj_list[@]}/b]:${N} ")" choice
  [[ "$choice" == "b" || "$choice" == "B" ]] && return 1
  if ! valid_menu_index "$choice" "${#proj_list[@]}"; then
    echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
  fi
  LOCAL_PROJECT="${proj_list[$((choice-1))]}"
  if [[ -z "$LOCAL_PROJECT" ]]; then
    echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
  fi
}

# ─── добавить/обновить Git repository ─────────────────────────────────────────
menu_clone() {
  header
  echo -e "${W}── Добавить или обновить Git repository ─────────────${N}"
  echo

  read -rp "$(echo -e "${W}Git remote URL или локальный Git path (HTTPS/SSH/path):${N} ")" url
  if [[ -z "$url" ]]; then echo -e "${R}Пустой URL${N}"; sleep 1; return; fi

  local default_name
  if ! default_name="$(local_repository_default_folder "$url")"; then
    echo -e "${R}BLOCKED: source отсутствует или неоднозначен. Укажи полный HTTPS/SSH/file URL, SCP-style Git URL или существующий локальный path.${N}"
    read -rp 'Нажми Enter...' _
    return 1
  fi
  read -rp "$(echo -e "${W}Имя папки [${default_name}]:${N} ")" folder
  folder="${folder:-$default_name}"
  if ! valid_local_folder "$folder"; then
    echo -e "${R}Недопустимое имя папки. Нужен один видимый path component; пробелы внутри имени допустимы.${N}"
    read -rp 'Нажми Enter...' _
    return 1
  fi

  local target="$PROJECTS/$folder"
  echo
  echo -e "${W}ПРОВЕРКА ИЗМЕНЕНИЯ${N}"
  echo -e "  Repository: ${C}$url${N}"
  echo -e "  Target:     ${C}$target${N}"
  echo -e "  Git push:   ${R}ЗАПРЕЩЁН${N}"
  if [[ -e "$target" || -L "$target" ]]; then
    if ! local_repository_root_is_exact "$target"; then
      echo -e "${R}BLOCKED: target существует, но не является exact корнем выбранного Git repository.${N}"
      read -rp 'Нажми Enter...' _
      return 1
    fi
    local origin
    origin="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
    if [[ -z "$origin" || "$origin" != "$url" ]]; then
      echo -e "${R}BLOCKED: origin отсутствует или не совпадает с exact source из Preview.${N}"
      read -rp 'Нажми Enter...' _
      return 1
    fi
    if [[ -n "$(git -C "$target" status --porcelain 2>/dev/null)" ]]; then
      echo -e "${R}Pull заблокирован: working tree содержит локальные изменения.${N}"
      read -rp 'Нажми Enter...' _
      return 1
    fi
    echo -e "  Command:    ${C}git -C "$target" pull --ff-only${N}"
    echo -e "${Y}Папка уже существует. Выполнить показанный Pull?${N}"
    read -rp "$(echo -e "${W}[y/N]:${N} ")" upd
    if [[ "$upd" == "y" || "$upd" == "Y" ]]; then
      echo -e "${C}Запускаю git pull...${N}"
      git -C "$target" pull --ff-only
    else
      return 0
    fi
  else
    echo
    echo -e "${C}Клонирую: ${W}$url${N}"
    echo -e "${C}В папку:  ${W}$target${N}"
    echo -e "${C}Команда:  ${W}git clone "$url" "$target"${N}"
    echo
    read -rp 'Выполнить показанный Clone? [y/N]: ' clone_confirm
    [[ "$clone_confirm" =~ ^[yY]$ ]] || return 0
    git clone -- "$url" "$target"
  fi

  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo
    echo -e "${G}✓ Готово. Проект: ${W}$folder${N}"
    echo
    echo -e "Следующий шаг — запустить анализ:"
    echo -e "  ${C}AGENT_RUNTIME=$AGENT_RUNTIME bash \"$AGENTS/localrun.sh\"${N}"
    echo
    read -rp "$(echo -e "${W}Запустить полный pipeline сейчас? [y/N]:${N} ")" go
    if [[ "$go" == "y" || "$go" == "Y" ]]; then
      LOCAL_PROJECT="$folder"
      run_pipeline
    fi
  else
    echo -e "${R}Ошибка при добавлении repository (код $rc)${N}"
  fi

  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── поиск директории агента ──────────────────────────────────────────────────
find_agent_dir() {
  local agent="$1"
  local dir
  for subdir in cycle1-dev cycle2-deploy cycle3-ops _tools; do
    dir="$AGENTS/$subdir/$agent"
    [[ -d "$dir" ]] && echo "$dir" && return
  done
  echo ""
}

# ─── запуск одного L-агента ───────────────────────────────────────────────────
run_agent() {
  local agent="$1"
  local project="$2"
  local task="$3"
  local agent_dir project_dir="$PROJECTS/$project" notes_dir="$NOTES/$project"
  agent_dir=$(find_agent_dir "$agent")

  if [[ ! -d "$agent_dir" ]]; then
    echo -e "${R}Агент '$agent' не найден${N}"; return 1
  fi
  if [[ ! -d "$project_dir" ]]; then
    echo -e "${R}Каталог проекта не найден: $project_dir${N}"; return 1
  fi
  if ! mkdir -p "$notes_dir"; then
    echo -e "${R}Не удалось подготовить каталог заметок: $notes_dir${N}"; return 1
  fi

  if [[ ! -x "$AGENT_RUNNER" ]]; then
    echo -e "${R}Runtime dispatcher не найден или не исполняемый: $AGENT_RUNNER${N}"; return 1
  fi

  resolve_step_runtime "$agent" || return 1

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
    prompt="$task для проекта $project"
  fi

  runtime_validate_prompt "$prompt" || return 1

  echo
  echo -e "${M}┌─ Агент ────────────────────────────────────────────┐${N}"
  echo -e "${M}│${N} ${W}$agent${N} — ${AGENT_DESC[$agent]}"
  echo -e "${M}│${N} Runtime: ${W}$(runtime_label)${N} (${AGENT_RUNTIME})"
  [[ "$AGENT_RUNTIME" == "local" ]] &&
    echo -e "${M}│${N} Local: ${W}$LOCAL_AGENT_HOST / $LOCAL_MODEL_PROVIDER / $LOCAL_MODEL${N}"
  echo -e "${M}│${N} Routing: ${W}$SDLC_RUNTIME_ROUTING${N}; subagents: ${W}$SDLC_SUBAGENTS/$SDLC_SUBAGENT_MAX${N}"
  echo -e "${M}│${N} Проект: ${W}$project${N}"
  [[ -n "$prompt" ]] && echo -e "${M}│${N} Prompt: ${C}$prompt${N}"
  echo -e "${M}└────────────────────────────────────────────────────┘${N}"
  echo
  if [[ -n "$prompt" ]]; then
    echo -e "  ${Y}Enter${N} — запустить задачу (выбранный runtime завершится автоматически)"
  elif ! runtime_supports_interactive; then
    echo -e "  ${C}task-only${N} — сначала выберите зарегистрированную команду"
  else
    echo -e "  ${Y}Enter${N} — открыть интерактивный режим выбранного runtime"
  fi
  if runtime_supports_interactive; then
    echo -e "  ${Y}i${N}     — интерактивный диалог с агентом"
  else
    echo -e "  ${C}Codex task-only${N} — интерактивный режим недоступен"
  fi
  echo -e "  ${Y}s${N}     — пропустить"
  echo -e "  ${Y}q${N}     — прервать"
  echo
  read -rp "$(echo -e "${W}Действие:${N} ")" confirm

  case "$confirm" in
    q|Q) return 2 ;;
    s|S)
      echo -e "${Y}⏭  Пропущен${N}"
      return 3
      ;;
    i|I)
      if ! runtime_supports_interactive; then
        report_interactive_codex_block
        return 1
      fi
      echo
      echo -e "${C}Интерактивный режим — ${W}$agent${N}"
      [[ -n "$prompt" ]] && echo -e "${Y}Задача шага:${N} $prompt"
      echo -e "${Y}Для выхода используй команду выхода выбранного runtime.${N}"
      echo
      local rc=0
      "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" \
        --project-dir "$project_dir" --notes-dir "$notes_dir" \
        --mode interactive --prompt "${prompt:-начни сессию}" || rc=$?
      echo
      [[ $rc -eq 0 ]] && echo -e "${G}✓ Сессия завершена${N}" ||
        echo -e "${R}✗ Runtime завершился с кодом $rc${N}"
      return "$rc"
      ;;
    *)
      local rc=0
      if [[ -n "$prompt" ]]; then
        echo -e "${C}Запускаю ($(runtime_label)): ${W}$prompt${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" \
          --project-dir "$project_dir" --notes-dir "$notes_dir" \
          --mode task --prompt "$prompt" || rc=$?
      else
        if ! runtime_supports_interactive; then
          report_interactive_codex_block
          return 1
        fi
        echo -e "${C}Открываю интерактивный режим выбранного runtime...${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" \
          --project-dir "$project_dir" --notes-dir "$notes_dir" \
          --mode interactive --prompt "начни сессию" || rc=$?
      fi
      echo
      [[ $rc -eq 0 ]] && echo -e "${G}✓ Агент завершил работу${N}" ||
        echo -e "${R}✗ Runtime завершился с кодом $rc${N}"
      return "$rc"
      ;;
  esac
}

localrun_step_output_ref() {
  case "$1" in
    l1-analyze) printf 'overview.md\n' ;;
    l2-setup) printf 'setup.md\n' ;;
    l3-build) printf 'build.md\n' ;;
    l4-run) printf 'run.md\n' ;;
    *) return 1 ;;
  esac
}

localrun_step_output_fingerprint() {
  local agent="$1" project="$2" ref file
  ref="$(localrun_step_output_ref "$agent")" || return 1
  file="$NOTES/$project/$ref"
  if [[ -f "$file" && ! -L "$file" ]]; then
    printf '%s:%s\n' "$ref" "$(sha256sum "$file" | awk '{print $1}')"
  else
    printf '%s:MISSING\n' "$ref"
  fi
}

run_verified_local_step() {
  local agent="$1" project="$2" task="$3" before after ref rc=0 file
  before="$(localrun_step_output_fingerprint "$agent" "$project")" || return 1
  run_agent "$agent" "$project" "$task" || rc=$?
  [[ $rc -eq 0 ]] || return "$rc"
  ref="$(localrun_step_output_ref "$agent")" || return 1
  file="$NOTES/$project/$ref"
  after="$(localrun_step_output_fingerprint "$agent" "$project")" || return 1
  if [[ "$after" == "$before" || ! -s "$file" || -L "$file" ]]; then
    echo -e "${R}BLOCKED: $agent process exit 0 без нового/изменённого verified $ref.${N}"
    return 4
  fi
  echo -e "${G}LOCAL OUTPUT VERIFIED: $project/$ref${N}"
}

# ─── полный pipeline: l1→l2→l3→l4 ────────────────────────────────────────────
run_pipeline() {
  local project="${LOCAL_PROJECT:-$1}"
  if [[ -z "$project" ]]; then pick_local_project || return; project="$LOCAL_PROJECT"; fi

  echo
  render_localrun_execution_preview "$project" "${PIPELINE[@]}"
  echo
  echo -e "На каждом шаге:"
  echo -e "  ${Y}Enter${N} — запустить задачу автоматически"
  echo -e "  ${Y}i${N}     — открыть интерактивный диалог"
  echo -e "  ${Y}s${N}     — пропустить и завершить pipeline как НЕПОЛНЫЙ"
  echo -e "  ${Y}q${N}     — прервать pipeline"
  echo
  read -rp "$(echo -e "${W}Запустить exact scope? [r / b]:${N} ")" go
  [[ "$go" =~ ^[rR]$ ]] || return

  local total=${#PIPELINE[@]}
  local step=0 rc=0

  for entry in "${PIPELINE[@]}"; do
    ((step++))
    local agent="${entry%%:*}"
    local task="${entry#*:}"

    echo
    echo -e "${M}━━━ Шаг $step / $total ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

    run_verified_local_step "$agent" "$project" "$task"
    rc=$?
    [[ $rc -eq 2 ]] && { echo -e "${Y}Pipeline прерван на шаге $step${N}"; break; }
    [[ $rc -eq 3 ]] && { echo -e "${Y}Pipeline не завершён: обязательный шаг $step пропущен.${N}"; break; }
    [[ $rc -ne 0 ]] && { echo -e "${R}Pipeline заблокирован на шаге $step (код $rc)${N}"; break; }
  done

  echo
  if [[ $rc -eq 0 ]]; then
    echo -e "${G}╔══════════════════════════════════════════════════════╗${N}"
    echo -e "${G}║  Pipeline завершён — repository: ${W}$project${G}"
    echo -e "${G}║  Заметки: Local_Run/$project/"
    echo -e "${G}╚══════════════════════════════════════════════════════╝${N}"
  fi
  return "$rc"
}

menu_pipeline() {
  header
  echo -e "${W}── Полный pipeline: analyze → setup → build → run ────${N}"
  echo
  pick_local_project || { read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _; return; }
  run_pipeline "$LOCAL_PROJECT"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── один агент ───────────────────────────────────────────────────────────────
menu_single_agent() {
  header
  echo -e "${W}── Запустить один агент ──────────────────────────────${N}"
  echo
  echo -e "${C}Выбери агента:${N}"
  echo -e "  ${Y}1)${N} ${W}l1-analyze${N} — ${AGENT_DESC[l1-analyze]}"
  echo -e "  ${Y}2)${N} ${W}l2-setup${N}   — ${AGENT_DESC[l2-setup]}"
  echo -e "  ${Y}3)${N} ${W}l3-build${N}   — ${AGENT_DESC[l3-build]}"
  echo -e "  ${Y}4)${N} ${W}l4-run${N}     — ${AGENT_DESC[l4-run]}"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Агент [1-4/b]:${N} ")" ac
  [[ "$ac" == "b" || "$ac" == "B" ]] && return

  local -a agents=(l1-analyze l2-setup l3-build l4-run)
  if ! valid_menu_index "$ac" "${#agents[@]}"; then
    echo -e "${R}Неверный выбор${N}"; sleep 1; return
  fi
  local agent="${agents[$((ac-1))]}"
  if [[ -z "$agent" ]]; then echo -e "${R}Неверный выбор${N}"; sleep 1; return; fi

  pick_local_project || { read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _; return; }

  # slash-команды
  local cmd_dir="$(find_agent_dir "$agent")/.claude/commands"
  local task
  if [[ -d "$cmd_dir" ]] && compgen -G "$cmd_dir/*.md" > /dev/null 2>&1; then
    echo
    echo -e "${C}Slash-команды:${N}"
    local j=1; local -a cmds=()
    for f in "$cmd_dir"/*.md; do
      local cname desc
      cname="/"$(basename "$f" .md)
      desc=$(grep '^description:' "$f" 2>/dev/null | sed 's/description: *//')
      echo -e "  ${Y}$j)${N} ${W}$cname${N} — $desc"
      cmds+=("$cname"); ((j++))
    done
    echo -e "  ${Y}$j)${N} Ввести произвольную задачу"
    echo -e "  ${Y}$((j+1)))${N} Интерактивный режим"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-$((j+1))/b]:${N} ")" cc
    [[ "$cc" == "b" || "$cc" == "B" ]] && return
    if ! valid_menu_index "$cc" "$((j+1))"; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return
    elif [[ "$cc" == "$((j+1))" ]]; then
      task=""
    elif [[ "$cc" == "$j" ]]; then
      read -rp "$(echo -e "${W}Задача:${N} ")" task
    else
      task="${cmds[$((cc-1))]}"
    fi
  else
    echo
    echo -e "  ${Y}1)${N} Ввести задачу"
    echo -e "  ${Y}2)${N} Интерактивный режим"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}[1/2/b]:${N} ")" mc
    [[ "$mc" == "b" || "$mc" == "B" ]] && return
    if [[ "$mc" == "2" ]]; then task=""; else read -rp "$(echo -e "${W}Задача:${N} ")" task; fi
  fi

  runtime_validate_prompt "$task" || return 1
  render_localrun_execution_preview "$LOCAL_PROJECT" "$agent:$task"
  read -rp 'Запустить этот один шаг? [r/b]: ' preview_choice
  [[ "$preview_choice" =~ ^[rR]$ ]] || return
  run_verified_local_step "$agent" "$LOCAL_PROJECT" "$task"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── обновить заметки после git pull ─────────────────────────────────────────
menu_update_notes() {
  header
  echo -e "${W}── Обновить заметки Obsidian после git pull ──────────${N}"
  echo
  pick_local_project || { read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _; return; }

  local project="$LOCAL_PROJECT"
  local project_path="$PROJECTS/$project"

  echo
  echo -e "${C}Проект:${N} ${W}$project${N}"
  echo -e "${C}Код:${N} $project_path"
  echo

  # Предложить git pull
  echo -e "  ${Y}1)${N} Сначала сделать git pull (обновить код из upstream)"
  echo -e "  ${Y}2)${N} Только обновить заметки (код уже актуален)"
  echo
  read -rp "$(echo -e "${W}[1/2]:${N} ")" uc

  if [[ "$uc" == "1" ]]; then
    echo
    if [[ -n "$(git -C "$project_path" status --porcelain 2>/dev/null)" ]]; then
      echo -e "${R}Pull заблокирован: working tree содержит локальные изменения.${N}"
      read -rp 'Нажми Enter...' _
      return 1
    fi
    echo -e "${W}ПРОВЕРКА ИЗМЕНЕНИЯ${N}"
    echo -e "  Repository: ${C}$project_path${N}"
    echo -e "  Command:    ${C}git -C "$project_path" pull --ff-only${N}"
    echo -e "  Git push:   ${R}ЗАПРЕЩЁН${N}"
    read -rp 'Выполнить показанный Pull? [y/N]: ' pull_confirm
    [[ "$pull_confirm" =~ ^[yY]$ ]] || return 0
    git -C "$project_path" pull --ff-only || return $?
    echo
  fi

  echo -e "${C}Выбери какие заметки обновить:${N}"
  echo -e "  ${Y}1)${N} Все (l1 → l2 → l3 → l4)"
  echo -e "  ${Y}2)${N} Только overview.md (l1-analyze)"
  echo -e "  ${Y}3)${N} Только run.md (l4-run)"
  echo
  read -rp "$(echo -e "${W}[1-3]:${N} ")" wc

  local -a note_steps=()
  case "$wc" in
    1)
      note_steps=(
        "l1-analyze:обнови заметки для $project — получены изменения из upstream"
        "l2-setup:обнови заметки для $project — получены изменения из upstream"
        "l3-build:обнови заметки для $project — получены изменения из upstream"
        "l4-run:обнови заметки для $project — получены изменения из upstream"
      )
      ;;
    2) note_steps=("l1-analyze:обнови overview.md для $project — получены изменения из upstream") ;;
    3) note_steps=("l4-run:обнови run.md для $project — проверь актуальность команды запуска") ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac

  echo
  render_localrun_execution_preview "$project" "${note_steps[@]}"
  read -rp 'Запустить показанное обновление заметок? [r/b]: ' preview_choice
  [[ "$preview_choice" =~ ^[rR]$ ]] || return 0

  local entry agent task rc=0
  for entry in "${note_steps[@]}"; do
    agent="${entry%%:*}"
    task="${entry#*:}"
    run_verified_local_step "$agent" "$project" "$task"
    rc=$?
    [[ $rc -eq 0 ]] && continue
    case "$rc" in
      2) echo -e "${Y}Обновление заметок прервано пользователем.${N}" ;;
      3) echo -e "${Y}Обновление заметок не завершено: обязательный шаг пропущен.${N}" ;;
      *) echo -e "${R}Обновление заметок заблокировано (код $rc).${N}" ;;
    esac
    break
  done

  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
  return "$rc"
}

# ─── список проектов ──────────────────────────────────────────────────────────
menu_list_projects() {
  header
  echo -e "${W}── Локальные проекты ─────────────────────────────────${N}"
  echo -e "  ${C}Код: ${PROJECTS}/${N}"
  echo -e "  ${C}Заметки: Local_Run/${N}"
  echo
  printf "  %-28s  %s\n" "Проект" "▶ анализ  setup  build  run"
  printf "  %-28s  %s\n" "─────────────────────────────" "──────────────────────────"

  local found=0
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* ]] && continue
    local notes_dir="$NOTES/$name"

    local a s b r
    [[ -f "$notes_dir/overview.md" ]] && a="${G}●${N}" || a="${R}○${N}"
    [[ -f "$notes_dir/setup.md"    ]] && s="${G}●${N}" || s="${R}○${N}"
    [[ -f "$notes_dir/build.md"    ]] && b="${G}●${N}" || b="${R}○${N}"
    [[ -f "$notes_dir/run.md"      ]] && r="${G}●${N}" || r="${R}○${N}"

    printf "  ${W}%-28s${N}  " "$name"
    echo -e "  $a        $s      $b      $r"
    found=1
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

  [[ $found -eq 0 ]] && echo -e "  ${Y}Проектов нет. Клонируй через пункт 1.${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}


# ─── настройки ────────────────────────────────────────────────────────────────
menu_settings() {
  apply_profile "$BASE_PROFILE" || true
  while true; do
    header
    echo -e "${W}── Настройки Local Run ──────────────────────────────${N}"
    echo
    echo -e "  Runtime:  ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
    echo -e "  CLI:      ${C}$(runtime_bin)${N}"
    [[ "$AGENT_RUNTIME" == "local" ]] &&
      echo -e "  Local:    ${C}$LOCAL_AGENT_HOST / $LOCAL_MODEL_PROVIDER / $LOCAL_MODEL${N}"
    echo -e "  Routing:  ${C}$SDLC_RUNTIME_ROUTING${N}"
    echo -e "  Workers:  ${C}off — BLOCKED до bounded read enforcement${N}"
    echo -e "  Projects: ${C}${LOCALRUN_PROJECTS:-не настроены}${N}"
    echo
    echo -e "  ${Y}1)${N} Выбрать основной AI runtime/profile"
    echo -e "  ${Y}2)${N} Настроить local profile"
    echo -e "  ${Y}3)${N} Выбрать routing policy"
    echo -e "  ${Y}4)${N} Добавить Local Run route"
    echo -e "  ${Y}5)${N} Показать статус workers"
    echo -e "  ${Y}6)${N} Изменить каталог локальных проектов"
    echo -e "  ${Y}7)${N} Проверить основной runtime/profile"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-7/b]:${N} ")" choice
    case "$choice" in
      1) choose_runtime ;;
      2)
        configure_local_profile && {
          AGENT_RUNTIME="local"
          export AGENT_RUNTIME
          write_config_value LOCALRUN_AGENT_RUNTIME local
          BASE_PROFILE="$(current_profile)"
        }
        ;;
      3) select_routing_policy ;;
      4) configure_runtime_route ;;
      5) configure_subagent_settings ;;
      6) configure_localrun_projects ;;
      7) apply_profile "$BASE_PROFILE"; read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _ ;;
      b|B) return ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

# ─── главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    header
    render_local_repositories_menu
    echo
    echo -e "  ${R}⚠  git push ЗАПРЕЩЁН для всех проектов в ${PROJECTS}/${N}"
    echo
    read -rp "$(echo -e "${W}Выбери действие:${N} ")" choice
    case "$choice" in
      1) menu_clone ;;
      2) menu_pipeline ;;
      3) menu_single_agent ;;
      4) menu_update_notes ;;
      5) menu_list_projects ;;
      6) menu_settings ;;
      p|P) return 0 ;;
      \?) echo -e "SDLC Project — продуктовый процесс; repository — локальный код; AI-профиль этого раздела независим; Execution Journal хранит запуски SDLC."; read -rp 'Нажми Enter...' _ ;;
      q|Q)
        if [[ "${SDLC_LAUNCHER_PARENT:-0}" == 1 ]]; then return 86; fi
        return 0
        ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

# ─── first-run wizard: спросить путь к локальным проектам ─────────────────────
first_run_wizard() {
  load_localrun_projects
  [[ -n "${LOCALRUN_PROJECTS:-}" ]] && return
  configure_localrun_projects
}

main() {
  if [[ "${SDLC_LAUNCHER_PARENT:-0}" == 1 ]]; then
    AGENT_RUNTIME=""
    LOCAL_AGENT_HOST=""
    LOCAL_MODEL_PROVIDER=""
    LOCAL_MODEL=""
    LOCAL_MODEL_ENDPOINT=""
    SDLC_RUNTIME_ROUTING=""
    SDLC_SUBAGENTS=""
    SDLC_SUBAGENT_MAX=""
    SDLC_SUBAGENT_PROFILE=""
    SDLC_SUBAGENT_TASKS=""
  fi
  ensure_runtime || exit 1
  BASE_PROFILE="$(current_profile)"
  ensure_routing_policy || exit 1
  ensure_subagent_settings || exit 1
  first_run_wizard || exit 1
  PROJECTS="$LOCALRUN_PROJECTS"
  export SDLC_VAULT="$VAULT"
  export LOCALRUN_PROJECTS
  main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

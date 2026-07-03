#!/bin/bash
# Local Run Interactive Launcher
# Управление локальными проектами с GitHub — push ЗАПРЕЩЁН

# Пути вычисляются от расположения скрипта — переносимо между окружениями
AGENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$AGENTS")"
NOTES="$VAULT/Local_Run"
export AGENT_RUNTIME="${AGENT_RUNTIME:-}"
AGENT_RUNNER="$AGENTS/_runtimes/agent-run.sh"

# Конфигурация пути к локальным проектам.
# Приоритет: env LOCALRUN_PROJECTS > config-файл > first-run wizard.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sdlc-agents"
CONFIG_FILE="$CONFIG_DIR/config"
PROJECTS=""

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
  mkdir -p "$CONFIG_DIR"
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
  mv "$tmp" "$CONFIG_FILE"
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
    claude|codex|gemini) echo "$runtime" ;;
    gemeni|gqmeni) echo "gemini" ;;
    *) return 1 ;;
  esac
}

init_runtime() {
  local requested="${1:-${AGENT_RUNTIME:-}}"
  local normalized
  if ! normalized="$(normalize_runtime "$requested")"; then
    [[ -n "$requested" ]] && echo -e "${R}Неизвестный runtime: ${requested}${N}"
    [[ -n "$requested" ]] && echo -e "Ожидается: ${C}claude${N}, ${C}codex${N} или ${C}gemini${N}"
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
    "") echo "не выбран" ;;
    *) echo "$AGENT_RUNTIME" ;;
  esac
}

runtime_bin() {
  case "$AGENT_RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
    *) echo "" ;;
  esac
}

ensure_runtime_available() {
  local bin
  if [[ -z "${AGENT_RUNTIME:-}" ]]; then
    echo -e "${R}Runtime не выбран.${N}"
    return 1
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
  [[ -n "$configured" ]] && init_runtime "$configured"
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
    if [[ "$allow_back" == "yes" ]]; then
      echo -e "  ${Y}b)${N} Назад"
      prompt_suffix="1-3/b"
    else
      prompt_suffix="1-3"
    fi
    echo
    read -rp "$(echo -e "${W}Выбери runtime [${prompt_suffix}]:${N} ")" choice
    case "$choice" in
      1) AGENT_RUNTIME="claude" ;;
      2) AGENT_RUNTIME="codex" ;;
      3) AGENT_RUNTIME="gemini" ;;
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
    echo -e "${W}── Настройка каталога локальных GitHub-проектов ─────${N}"
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

# ─── шапка ────────────────────────────────────────────────────────────────────
header() {
  clear
  echo -e "${M}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${M}║${W}       Local Run — локальные проекты с GitHub        ${M}║${N}"
  echo -e "${M}║${R}           ⚠  git push ЗАПРЕЩЁН                      ${M}║${N}"
  echo -e "${M}╚══════════════════════════════════════════════════════╝${N}"
  echo -e "  Runtime: ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
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
  LOCAL_PROJECT="${proj_list[$((choice-1))]}"
  if [[ -z "$LOCAL_PROJECT" ]]; then
    echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
  fi
}

# ─── клонировать новый проект ─────────────────────────────────────────────────
menu_clone() {
  header
  echo -e "${W}── Клонировать проект с GitHub ───────────────────────${N}"
  echo

  read -rp "$(echo -e "${W}GitHub URL (https://github.com/...):${N} ")" url
  if [[ -z "$url" ]]; then echo -e "${R}Пустой URL${N}"; sleep 1; return; fi

  # угадываем имя папки из URL
  local default_name
  default_name=$(basename "$url" .git)
  read -rp "$(echo -e "${W}Имя папки [${default_name}]:${N} ")" folder
  folder="${folder:-$default_name}"

  local target="$PROJECTS/$folder"
  if [[ -d "$target" ]]; then
    echo -e "${Y}Папка '$target' уже существует. Обновить (git pull)?${N}"
    read -rp "$(echo -e "${W}[y/N]:${N} ")" upd
    if [[ "$upd" == "y" || "$upd" == "Y" ]]; then
      echo -e "${C}Запускаю git pull...${N}"
      git -C "$target" pull
    fi
  else
    echo
    echo -e "${C}Клонирую: ${W}$url${N}"
    echo -e "${C}В папку:  ${W}$target${N}"
    echo
    git clone "$url" "$target"
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
    echo -e "${R}Ошибка при клонировании (код $rc)${N}"
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
  local agent_dir
  agent_dir=$(find_agent_dir "$agent")

  if [[ ! -d "$agent_dir" ]]; then
    echo -e "${R}Агент '$agent' не найден${N}"; return 1
  fi

  if [[ ! -x "$AGENT_RUNNER" ]]; then
    echo -e "${R}Runtime dispatcher не найден или не исполняемый: $AGENT_RUNNER${N}"; return 1
  fi

  ensure_runtime_available || return 1

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

  echo
  echo -e "${M}┌─ Агент ────────────────────────────────────────────┐${N}"
  echo -e "${M}│${N} ${W}$agent${N} — ${AGENT_DESC[$agent]}"
  echo -e "${M}│${N} Runtime: ${W}$(runtime_label)${N} (${AGENT_RUNTIME})"
  echo -e "${M}│${N} Проект: ${W}$project${N}"
  [[ -n "$prompt" ]] && echo -e "${M}│${N} Prompt: ${C}$prompt${N}"
  echo -e "${M}└────────────────────────────────────────────────────┘${N}"
  echo
  if [[ -n "$prompt" ]]; then
    echo -e "  ${Y}Enter${N} — запустить задачу (выбранный runtime завершится автоматически)"
  else
    echo -e "  ${Y}Enter${N} — открыть интерактивный режим выбранного runtime"
  fi
  echo -e "  ${Y}i${N}     — интерактивный диалог с агентом"
  echo -e "  ${Y}s${N}     — пропустить"
  echo -e "  ${Y}q${N}     — прервать"
  echo
  read -rp "$(echo -e "${W}Действие:${N} ")" confirm

  case "$confirm" in
    q|Q) return 2 ;;
    s|S)
      echo -e "${Y}⏭  Пропущен${N}"
      return 0
      ;;
    i|I)
      echo
      echo -e "${C}Интерактивный режим — ${W}$agent${N}"
      [[ -n "$prompt" ]] && echo -e "${Y}Задача шага:${N} $prompt"
      echo -e "${Y}Для выхода используй команду выхода выбранного runtime.${N}"
      echo
      "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" --mode interactive --prompt "${prompt:-начни сессию}"
      echo
      echo -e "${G}✓ Сессия завершена${N}"
      ;;
    *)
      if [[ -n "$prompt" ]]; then
        echo -e "${C}Запускаю ($(runtime_label)): ${W}$prompt${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" --mode task --prompt "$prompt"
      else
        echo -e "${C}Открываю интерактивный режим выбранного runtime...${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" --mode interactive --prompt "начни сессию"
      fi
      echo
      echo -e "${G}✓ Агент завершил работу${N}"
      ;;
  esac
  return 0
}

# ─── полный pipeline: l1→l2→l3→l4 ────────────────────────────────────────────
run_pipeline() {
  local project="${LOCAL_PROJECT:-$1}"
  if [[ -z "$project" ]]; then pick_local_project || return; project="$LOCAL_PROJECT"; fi

  echo
  echo -e "${C}Проект: ${W}$project${N} — pipeline: l1 → l2 → l3 → l4"
  echo
  echo -e "На каждом шаге:"
  echo -e "  ${Y}Enter${N} — запустить задачу автоматически"
  echo -e "  ${Y}i${N}     — открыть интерактивный диалог"
  echo -e "  ${Y}s${N}     — пропустить шаг"
  echo -e "  ${Y}q${N}     — прервать pipeline"
  echo
  read -rp "$(echo -e "${W}Начать? [Enter / q]:${N} ")" go
  [[ "$go" == "q" || "$go" == "Q" ]] && return

  local total=${#PIPELINE[@]}
  local step=0

  for entry in "${PIPELINE[@]}"; do
    ((step++))
    local agent="${entry%%:*}"
    local task="${entry#*:}"

    echo
    echo -e "${M}━━━ Шаг $step / $total ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

    run_agent "$agent" "$project" "$task"
    local rc=$?
    [[ $rc -eq 2 ]] && { echo -e "${Y}Pipeline прерван на шаге $step${N}"; break; }
  done

  echo
  echo -e "${G}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${G}║  Pipeline завершён — проект: ${W}$project${G}"
  echo -e "${G}║  Заметки: Local_Run/$project/"
  echo -e "${G}╚══════════════════════════════════════════════════════╝${N}"
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
    if [[ "$cc" -eq "$((j+1))" ]] 2>/dev/null; then
      task=""
    elif [[ "$cc" -eq "$j" ]] 2>/dev/null; then
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

  run_agent "$agent" "$LOCAL_PROJECT" "$task"
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
    echo -e "${C}git pull...${N}"
    git -C "$project_path" pull
    echo
  fi

  echo -e "${C}Выбери какие заметки обновить:${N}"
  echo -e "  ${Y}1)${N} Все (l1 → l2 → l3 → l4)"
  echo -e "  ${Y}2)${N} Только overview.md (l1-analyze)"
  echo -e "  ${Y}3)${N} Только run.md (l4-run)"
  echo
  read -rp "$(echo -e "${W}[1-3]:${N} ")" wc

  case "$wc" in
    1)
      for entry in "${PIPELINE[@]}"; do
        local agent="${entry%%:*}"
        run_agent "$agent" "$project" "обнови заметки для $project — получены изменения из upstream"
        [[ $? -eq 2 ]] && break
      done
      ;;
    2)
      run_agent "l1-analyze" "$project" "обнови overview.md для $project — получены изменения из upstream"
      ;;
    3)
      run_agent "l4-run" "$project" "обнови run.md для $project — проверь актуальность команды запуска"
      ;;
    *)
      echo -e "${R}Неверный выбор${N}"
      ;;
  esac

  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
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
  while true; do
    header
    echo -e "${W}── Настройки Local Run ──────────────────────────────${N}"
    echo
    echo -e "  Runtime:  ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
    echo -e "  CLI:      ${C}$(runtime_bin)${N}"
    echo -e "  Projects: ${C}${LOCALRUN_PROJECTS:-не настроены}${N}"
    echo
    echo -e "  ${Y}1)${N} Выбрать AI runtime"
    echo -e "  ${Y}2)${N} Изменить каталог локальных проектов"
    echo -e "  ${Y}3)${N} Проверить CLI выбранного runtime"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-3/b]:${N} ")" choice
    case "$choice" in
      1) choose_runtime ;;
      2) configure_localrun_projects ;;
      3) ensure_runtime_available; read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _ ;;
      b|B) return ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

# ─── главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    header
    echo -e "  ${Y}1)${N} ${W}Клонировать проект с GitHub${N}"
    echo -e "  ${Y}2)${N} ${W}Полный pipeline${N}  (analyze → setup → build → run)"
    echo -e "  ${Y}3)${N} Запустить один агент"
    echo -e "  ${Y}4)${N} Обновить заметки Obsidian (после git pull / GitHub Desktop)"
    echo -e "  ${Y}5)${N} Список проектов"
    echo -e "  ${Y}6)${N} Настройки runtime/projects"
    echo -e "  ${Y}q)${N} Выход"
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
      q|Q) echo -e "${N}Выход."; exit 0 ;;
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

ensure_runtime || exit 1
first_run_wizard || exit 1
PROJECTS="$LOCALRUN_PROJECTS"
export SDLC_VAULT="$VAULT"
export LOCALRUN_PROJECTS
main_menu

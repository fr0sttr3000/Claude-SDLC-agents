#!/bin/bash
# Local Run Interactive Launcher
# Управление локальными проектами с GitHub — push ЗАПРЕЩЁН

VAULT="/home/host-gui-car/Documents/Obsidian Vault/Claude"
AGENTS="$VAULT/_agents"
NOTES="$VAULT/Local_Run"
PROJECTS="/home/host-gui-car/Projects/claude"

# ─── цвета ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; M='\033[0;35m'; N='\033[0m'

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
  echo -e "${C}Локальные проекты${N} (${Y}/home/host-gui-car/Projects/claude/${N}):"
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

  echo
  read -rp "$(echo -e "${W}Выбери проект [1-${#proj_list[@]}]:${N} ")" choice
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
    echo -e "  ${C}cd \"$AGENTS/l1-analyze\" && claude /analyze $folder${N}"
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

# ─── запуск одного L-агента ───────────────────────────────────────────────────
run_agent() {
  local agent="$1"
  local project="$2"
  local task="$3"
  local agent_dir="$AGENTS/$agent"

  local claude_arg
  if [[ "$task" == /* ]]; then
    claude_arg="$task $project"
  elif [[ -n "$task" ]]; then
    claude_arg="$task для проекта $project"
  else
    claude_arg=""
  fi

  echo
  echo -e "${M}┌─ Агент ────────────────────────────────────────────┐${N}"
  echo -e "${M}│${N} ${W}$agent${N} — ${AGENT_DESC[$agent]}"
  echo -e "${M}│${N} Проект: ${W}$project${N}"
  [[ -n "$claude_arg" ]] && echo -e "${M}│${N} Задача: ${C}$claude_arg${N}"
  echo -e "${M}└────────────────────────────────────────────────────┘${N}"
  echo
  echo -e "  ${Y}Enter${N} — запустить задачу (claude завершится автоматически)"
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
      [[ -n "$claude_arg" ]] && echo -e "${Y}Задача шага:${N} $claude_arg"
      echo -e "${Y}Для выхода: /exit или Ctrl+C${N}"
      echo
      echo -e "${M}── Агент инициирует диалог... ──────────────────────${N}"
      (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude "начни сессию")
      echo
      echo -e "${M}── Продолжение диалога ─────────────────────────────${N}"
      (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude --continue)
      echo
      echo -e "${G}✓ Сессия завершена${N}"
      ;;
    *)
      if [[ -n "$claude_arg" ]]; then
        echo -e "${C}Запускаю: ${W}claude \"$claude_arg\"${N}"
        echo
        (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude "$claude_arg")
      else
        echo -e "${C}Открываю диалог с агентом...${N}"
        echo
        (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude "начни сессию")
        echo
        (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude --continue)
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
  echo
  read -rp "$(echo -e "${W}Агент [1-4]:${N} ")" ac

  local -a agents=(l1-analyze l2-setup l3-build l4-run)
  local agent="${agents[$((ac-1))]}"
  if [[ -z "$agent" ]]; then echo -e "${R}Неверный выбор${N}"; sleep 1; return; fi

  pick_local_project || { read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _; return; }

  # slash-команды
  local cmd_dir="$AGENTS/$agent/.claude/commands"
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
    echo
    read -rp "$(echo -e "${W}Выбери [1-$((j+1))]:${N} ")" cc
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
    echo
    read -rp "$(echo -e "${W}[1/2]:${N} ")" mc
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
  echo -e "  ${C}Код: /home/host-gui-car/Projects/claude/${N}"
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

# ─── главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    header
    echo -e "  ${Y}1)${N} ${W}Клонировать проект с GitHub${N}"
    echo -e "  ${Y}2)${N} ${W}Полный pipeline${N}  (analyze → setup → build → run)"
    echo -e "  ${Y}3)${N} Запустить один агент"
    echo -e "  ${Y}4)${N} Обновить заметки Obsidian (после git pull / GitHub Desktop)"
    echo -e "  ${Y}5)${N} Список проектов"
    echo -e "  ${Y}q)${N} Выход"
    echo
    echo -e "  ${R}⚠  git push ЗАПРЕЩЁН для всех проектов в /Projects/claude/${N}"
    echo
    read -rp "$(echo -e "${W}Выбери действие:${N} ")" choice
    case "$choice" in
      1) menu_clone ;;
      2) menu_pipeline ;;
      3) menu_single_agent ;;
      4) menu_update_notes ;;
      5) menu_list_projects ;;
      q|Q) echo -e "${N}Выход."; exit 0 ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

main_menu

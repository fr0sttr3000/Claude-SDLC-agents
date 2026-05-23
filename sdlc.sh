#!/bin/bash
# SDLC Interactive Agent Launcher

export PATH="/home/host-gui-car/.local/bin:$PATH"

VAULT="/home/host-gui-car/Documents/Obsidian Vault/Claude"
AGENTS="$VAULT/_agents"
PROJECTS="$VAULT/projects"

# ─── цвета ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

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
  [s1-pm]="Product Manager — Feasibility, Vision, OKR"
  [s1-pmo]="Project Manager — Charter, Risk Register, RACI"
  [s1-finance]="Finance Analyst — ROI, NPV, Business Case"
  [s2-ba]="Business Analyst — BRD, NFR, RTM"
  [s2-po]="Product Owner — User Stories, Backlog"
  [s2-qa-req]="QA Analyst — Testability Review"
  [s3-arch]="Solution Architect — HLD, ADR, API Spec"
  [s3-security]="Security Engineer — Threat Model"
  [s3-rbac]="RBAC Designer — роли, матрица прав, RLS, SQL схема"
  [s3-dba]="DBA — DB Schema, Migrations"
  [s4-dev]="Backend Developer — Код, PR Summary"
  [s4-techlead]="Tech Lead — Code Review, Tech Debt"
  [s4-devops]="DevOps Engineer — CI/CD, Runbook"
  [s5-qa]="QA Engineer — Test Plan, Go/No-Go"
  [s5-qa-auto]="QA Automation — E2E/API тесты"
  [s5-perf]="Performance Engineer — Load Tests"
  [s6-release]="Release Manager — Checklist, Release Notes"
  [s6-sre]="SRE — Post-Deploy, Post-Mortem"
)

# ─── необязательные шаги (можно добавить в цикл) ─────────────────────────────
# Формат: "агент|задача|позиция|описание"
# позиция: before — до основного цикла, after — после основного цикла
declare -a OPTIONAL_AGENTS_DEF=(
  "s0-validate|/validate|before|Проверить и починить структуру проекта до старта"
  "s0-secrets|Настрой секреты для проекта|before|Настройка секретов через pass"
  "s0-tracker|/sprint-init|before|Инициализировать спринт перед циклом"
  "s0-validate|/validate|after|Проверить артефакты после завершения цикла"
  "s6-sre|/gate7|after|Gate 7 — мониторинг + auto-heal + SLO Review (через 7 дней после деплоя)"
)

# глобальные массивы — заполняются configure_optional_steps
OPTIONAL_BEFORE=()
OPTIONAL_AFTER=()

# ─── полный цикл: агент:задача ────────────────────────────────────────────────
declare -a CYCLE_AGENTS=(
  "s1-pm:/feasibility"
  "s1-pm:/vision"
  "s1-pmo:/charter"
  "s1-pmo:/risks"
  "s1-finance:/business-case"
  "s2-ba:/extract-requirements"
  "s2-ba:/brd"
  "s2-po:/stories"
  "s2-qa-req:/testability-review"
  "s3-arch:/hld"
  "s3-arch:/adr"
  "s3-security:/threat-model"
  "s3-rbac:/rbac-model"
  "s3-dba:/schema"
  "s4-dev:/dev-report"
  "s4-techlead:/review"
  "s4-devops:/pipeline"
  "s4-devops:/runbook"
  "s5-qa:/test-plan"
  "s5-qa-auto:/e2e-report"
  "s5-perf:/load-test"
  "s5-qa:/go-no-go"
  "s6-release:/release-checklist"
  "s6-release:/release-notes"
  "s6-sre:/post-deploy"
  "s0-tracker:/report"
  "s0-github:/push"
)

header() {
  clear
  echo -e "${B}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${B}║${W}         SDLC Agent Launcher — Claude Code           ${B}║${N}"
  echo -e "${B}╚══════════════════════════════════════════════════════╝${N}"
  echo
}

# ─── выбор проекта ────────────────────────────────────────────────────────────
pick_project() {
  echo -e "${C}Проекты:${N}"
  local i=1
  local -a proj_list=()
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* ]] && continue
    proj_list+=("$name")
    echo -e "  ${Y}$i)${N} $name"
    ((i++))
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  echo -e "  ${Y}n)${N} Создать новый проект"
  echo
  read -rp "$(echo -e "${W}Выбери проект [1-${#proj_list[@]}/n]:${N} ")" choice

  if [[ "$choice" == "n" ]]; then
    read -rp "$(echo -e "${W}Название нового проекта:${N} ")" PROJECT
    create_project "$PROJECT"
  else
    PROJECT="${proj_list[$((choice-1))]}"
    if [[ -z "$PROJECT" ]]; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
    fi
  fi
}

# ─── создать структуру проекта ────────────────────────────────────────────────
create_project() {
  local name="$1"
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
#   task (default) — claude "задача проект"  →  агент выполняет и завершает
#   interactive    — claude                  →  открывается REPL-диалог
#
# Возврат: 0 — OK, 1 — ошибка, 2 — выход из цикла
run_agent() {
  local agent="$1"
  local project="$2"
  local task="$3"
  local agent_dir="$AGENTS/$agent"

  if [[ ! -d "$agent_dir" ]]; then
    echo -e "${R}Агент '$agent' не найден${N}"; return 1
  fi

  # собираем аргумент для claude в task-режиме
  local claude_arg
  if [[ "$task" == /* ]]; then
    # Раскрываем шаблон slash-команды вручную, чтобы $ARGUMENTS подставился в bash,
    # а не ждать от claude CLI (в неинтерактивном режиме он может не подставляться)
    local cmd_name="${task#/}"
    local cmd_file="$agent_dir/.claude/commands/${cmd_name}.md"
    if [[ -f "$cmd_file" ]]; then
      # Убираем frontmatter (--- ... ---) и подставляем $ARGUMENTS → project
      local template
      template=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$cmd_file")
      [[ -z "$template" ]] && template=$(grep -v '^---' "$cmd_file" | grep -v '^description:')
      claude_arg="Проект: $project."$'\n\n'"${template//\$ARGUMENTS/$project}"
    else
      claude_arg="$task $project"
    fi
  else
    claude_arg="Проект: $project."$'\n\n'"$task"
  fi

  echo
  echo -e "${B}┌─ Агент ────────────────────────────────────────────┐${N}"
  echo -e "${B}│${N} ${W}$agent${N} — ${AGENT_DESC[$agent]}"
  echo -e "${B}│${N} Проект: ${W}$project${N}"
  echo -e "${B}│${N} Задача: ${C}$claude_arg${N}"
  echo -e "${B}└────────────────────────────────────────────────────┘${N}"
  echo
  echo -e "  ${Y}Enter${N} — запустить задачу (claude завершится автоматически)"
  echo -e "  ${Y}i${N}     — открыть интерактивный диалог с агентом"
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
      echo
      echo -e "${C}Интерактивный режим — ${W}$agent${N} — ${AGENT_DESC[$agent]}"
      echo -e "${Y}Задача этого шага:${N} $claude_arg"
      echo -e "${Y}Для выхода: /exit или Ctrl+C${N}"
      echo
      # Шаг 1: агент представляется
      echo -e "${B}── Агент инициирует диалог... ──────────────────────${N}"
      (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude "начни сессию")
      echo
      # Шаг 2: продолжаем тот же диалог интерактивно
      echo -e "${B}── Продолжение диалога ─────────────────────────────${N}"
      (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude --continue)
      echo
      echo -e "${G}✓ Сессия завершена${N}"
      ;;
    *)
      echo
      echo -e "${C}Запускаю: ${W}claude \"$claude_arg\"${N}"
      echo
      (cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude "$claude_arg")
      echo
      echo -e "${G}✓ Агент завершил работу${N}"
      ;;
  esac
}

# ─── один агент ───────────────────────────────────────────────────────────────
menu_single_agent() {
  header
  echo -e "${W}── Запуск одного агента ──────────────────────────────${N}"
  echo

  local -a stages=("0: Инфраструктура" "L: Local Run (GitHub проекты)" "1: Планирование" "2: Требования" "3: Дизайн"
                   "4: Разработка" "5: Тестирование" "6: Деплой")
  local -a groups=(
    "s0-kickoff s0-secrets s0-github s0-validate s0-tracker"
    "l1-analyze l2-setup l3-build l4-run"
    "s1-pm s1-pmo s1-finance"
    "s2-ba s2-po s2-qa-req"
    "s3-arch s3-security s3-rbac s3-dba"
    "s4-dev s4-techlead s4-devops"
    "s5-qa s5-qa-auto s5-perf"
    "s6-release s6-sre"
  )

  local i=1
  local -a agent_list=()
  for s in "${!stages[@]}"; do
    echo -e "${B}Этап ${stages[$s]}${N}"
    for ag in ${groups[$s]}; do
      echo -e "  ${Y}$i)${N} ${W}$ag${N} — ${AGENT_DESC[$ag]}"
      agent_list+=("$ag")
      ((i++))
    done
    echo
  done

  read -rp "$(echo -e "${W}Выбери агента [1-${#agent_list[@]}]:${N} ")" choice
  local agent="${agent_list[$((choice-1))]}"
  if [[ -z "$agent" ]]; then echo -e "${R}Неверный выбор${N}"; sleep 1; return; fi

  pick_project || return

  # slash-команды агента
  local cmd_dir="$AGENTS/$agent/.claude/commands"
  local task
  if [[ -d "$cmd_dir" ]] && compgen -G "$cmd_dir/*.md" > /dev/null 2>&1; then
    echo
    echo -e "${C}Slash-команды агента:${N}"
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
    echo
    read -rp "$(echo -e "${W}Выбери [1-$((j+1))]:${N} ")" cmd_choice

    if [[ "$cmd_choice" -eq "$((j+1))" ]] 2>/dev/null; then
      # сразу в интерактив
      run_agent "$agent" "$PROJECT" ""
      echo
      read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
      return
    elif [[ "$cmd_choice" -eq "$j" ]] 2>/dev/null; then
      read -rp "$(echo -e "${W}Задача:${N} ")" task
    else
      task="${cmds[$((cmd_choice-1))]}"
    fi
  else
    echo
    echo -e "  ${Y}1)${N} Ввести задачу"
    echo -e "  ${Y}2)${N} Открыть интерактивный режим"
    echo
    read -rp "$(echo -e "${W}Выбери [1-2]:${N} ")" mode_choice
    if [[ "$mode_choice" == "2" ]]; then
      run_agent "$agent" "$PROJECT" ""
      echo
      read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
      return
    fi
    read -rp "$(echo -e "${W}Задача:${N} ")" task
  fi

  run_agent "$agent" "$PROJECT" "$task"
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

    if [[ "$toggle" =~ ^[0-9]+$ ]]; then
      local idx=$((toggle-1))
      if [[ $idx -ge 0 && $idx -lt $n ]]; then
        opt_enabled[$idx]=$(( 1 - opt_enabled[$idx] ))
      fi
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

# ─── полный цикл ──────────────────────────────────────────────────────────────
menu_full_cycle() {
  header
  echo -e "${W}── Полный SDLC-цикл ──────────────────────────────────${N}"
  echo
  pick_project || return

  # выбор необязательных шагов
  configure_optional_steps

  # строим динамический массив: before + обязательные + after
  local -a RUN_CYCLE=()
  local -a RUN_OPTIONAL=()  # флаги: 1 = необязательный шаг

  for entry in "${OPTIONAL_BEFORE[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(1)
  done
  for entry in "${CYCLE_AGENTS[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(0)
  done
  for entry in "${OPTIONAL_AFTER[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(1)
  done

  local mandatory_count=${#CYCLE_AGENTS[@]}
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
  echo -e "На каждом шаге:"
  echo -e "  ${Y}Enter${N} — запустить задачу автоматически"
  echo -e "  ${Y}i${N}     — открыть интерактивный диалог с агентом"
  echo -e "  ${Y}s${N}     — пропустить шаг"
  echo -e "  ${Y}q${N}     — прервать цикл"
  echo
  read -rp "$(echo -e "${W}Начать? [Enter / q]:${N} ")" go
  [[ "$go" == "q" || "$go" == "Q" ]] && return

  local step=0 skipped=0 done_count=0 aborted=0
  local -a step_log=()

  for ((idx=0; idx<${#RUN_CYCLE[@]}; idx++)); do
    ((step++))
    local entry="${RUN_CYCLE[$idx]}"
    local is_optional="${RUN_OPTIONAL[$idx]}"
    local agent="${entry%%:*}"
    local task="${entry#*:}"
    local label="${agent} — ${AGENT_DESC[$agent]}"
    local opt_tag=""
    [[ "$is_optional" -eq 1 ]] && opt_tag=" ${C}[доп]${N}"

    echo
    echo -e "${B}━━━ Шаг $step / $total ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}${opt_tag}"

    run_agent "$agent" "$PROJECT" "$task"
    local rc=$?

    if [[ $rc -eq 2 ]]; then
      step_log+=("  ${Y}⏹${N}  $label${opt_tag}")
      ((aborted++))
      echo -e "${Y}Цикл прерван на шаге $step${N}"
      break
    elif [[ $rc -eq 3 ]]; then
      step_log+=("  ${Y}⏭${N}  $label${opt_tag}")
      ((skipped++))
    else
      step_log+=("  ${G}✓${N}  $label${opt_tag}")
      ((done_count++))
    fi
  done

  echo
  echo -e "${G}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${G}║${W}  Итог цикла SDLC — Проект: $PROJECT${N}"
  echo -e "${G}╠══════════════════════════════════════════════════════╣${N}"
  for line in "${step_log[@]}"; do
    echo -e "${G}║${N}${line}"
  done
  echo -e "${G}╠══════════════════════════════════════════════════════╣${N}"
  echo -e "${G}║${N}  ${G}✓${N} Выполнено: ${G}$done_count${N}   ${Y}⏭${N} Пропущено: ${Y}$skipped${N}   Всего: $step / $total"
  echo -e "${G}╚══════════════════════════════════════════════════════╝${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── создание проекта ─────────────────────────────────────────────────────────
menu_new_project() {
  header
  echo -e "${W}── Новый проект ──────────────────────────────────────${N}"
  echo
  read -rp "$(echo -e "${W}Название проекта:${N} ")" name
  if [[ -z "$name" ]]; then echo -e "${R}Пустое имя${N}"; sleep 1; return; fi
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
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери [1-3/b]:${N} ")" choice
  [[ "$choice" == "b" || "$choice" == "B" ]] && return

  pick_project || return

  case "$choice" in
    1) run_agent "s0-kickoff" "$PROJECT" "/new $PROJECT" ;;
    2) run_agent "s0-kickoff" "$PROJECT" "/refresh $PROJECT" ;;
    3) run_agent "s0-kickoff" "$PROJECT" "/start $PROJECT" ;;
    *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; return ;;
  esac
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── валидация структуры ──────────────────────────────────────────────────────
menu_validate_project() {
  header
  echo -e "${W}── Валидация и починка структуры проекта ────────────${N}"
  echo
  echo -e "  ${Y}1)${N} Проверить один проект       ${C}(/validate)${N}"
  echo -e "  ${Y}2)${N} Проверить все проекты       ${C}(/validate all)${N}"
  echo -e "  ${Y}3)${N} Починить один проект        ${C}(/fix)${N}"
  echo -e "  ${Y}4)${N} Починить все проекты        ${C}(/fix all)${N}"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери [1-4/b]:${N} ")" choice

  case "$choice" in
    b|B) return ;;
    1|3)
      pick_project || return
      local project="$PROJECT"
      local task; [[ "$choice" == "1" ]] && task="/validate" || task="/fix"
      run_agent "s0-validate" "$project" "$task"
      ;;
    2|4)
      local task; [[ "$choice" == "2" ]] && task="/validate" || task="/fix"
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
menu_list_projects() {
  header
  echo -e "${W}── Проекты ───────────────────────────────────────────${N}"
  echo
  local found=0
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* ]] && continue
    local stages_done=0
    for s in stage1-planning stage2-requirements stage3-design stage4-dev \
              stage5-testing stage6-deploy stage7-ops; do
      [[ -n "$(ls -A "$d/$s/outputs" 2>/dev/null)" ]] && ((stages_done++))
    done
    local bar=""
    for ((k=0; k<stages_done; k++)); do bar+="█"; done
    for ((k=stages_done; k<7; k++)); do bar+="░"; done
    echo -e "  ${W}$name${N}  ${C}$bar${N} $stages_done/7"
    found=1
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  [[ $found -eq 0 ]] && echo -e "  ${Y}Проектов пока нет${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    header
    echo -e "  ${Y}0)${N} ${G}Kickoff${N} — онбординг нового проекта / обновление беклога"
    echo -e "  ${Y}1)${N} ${W}Запустить один агент${N}"
    echo -e "  ${Y}2)${N} ${W}Полный SDLC-цикл${N} (все ${#CYCLE_AGENTS[@]} шагов)"
    echo -e "  ${Y}3)${N} Создать новый проект"
    echo -e "  ${Y}4)${N} Список проектов"
    echo -e "  ${Y}5)${N} ${C}Local Run${N} — проекты с GitHub (clone / build / run)"
    echo -e "  ${Y}6)${N} ${C}Валидация${N} — проверить и починить структуру проекта"
    echo -e "  ${Y}q)${N} Выход"
    echo
    read -rp "$(echo -e "${W}Выбери действие:${N} ")" choice
    case "$choice" in
      0) menu_kickoff ;;
      1) menu_single_agent ;;
      2) menu_full_cycle ;;
      3) menu_new_project ;;
      4) menu_list_projects ;;
      5) bash "$AGENTS/localrun.sh" ;;
      6) menu_validate_project ;;
      q|Q) echo -e "${N}Выход."; exit 0 ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

main_menu

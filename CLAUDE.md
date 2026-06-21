# CLAUDE.md — SDLC Vault (Глобальный контекст)

## Назначение vault
Автоматизированная SDLC-система на базе Claude Code.
Каждый агент — отдельная папка в `_agents/` со своим `CLAUDE.md` и slash-командами.
Агенты изолированы; данные передаются только через файлы в `projects/`.

## Структура vault
```
_agents/
  _standards/       ← Стандарты компании (читать перед каждой задачей)
  _tools/           ← Утилиты для всех циклов (s0-github, s0-secrets)
  cycle1-dev/       ← Цикл 1: Разработка (19 агентов: s0-kickoff/tracker/validate, s1-s5, l1-l4)
  cycle2-deploy/    ← Цикл 2: Деплой (s4-devops, s6-release)
  cycle3-ops/       ← Цикл 3: Эксплуатация (s6-sre)
  plans/            ← Планы развития системы агентов
  sdlc.sh           ← Главный лаунчер (циклы 1 → 2 → 3)
  localrun.sh       ← Лаунчер Local Run (GitHub-проекты)
_secrets/           ← Документация по управлению секретами (pass)
projects/           ← Артефакты проектов (inputs/outputs по этапам + tracking/)
Local_Run/          ← Заметки по локальным проектам с GitHub
OVERVIEW.md         ← Полный обзор системы
```

## Структура проекта в projects/
```
projects/{PROJECT}/
  Dashboard.md                  ← прогресс по этапам
  stage1-planning/inputs/       ← входные данные (idea.md и др.)
  stage1-planning/outputs/      ← артефакты агентов (PM-*.md, PMO-*.md)
  stage2-requirements/.../
  ...
  stage7-ops/.../
  tracking/                     ← управление задачами (s0-tracker)
    backlog.md
    current-sprint.md
    cycle-summary.md
    sprints/sprint-NN.md
```

## Как работать с агентами
```bash
# Через лаунчер (рекомендуется)
bash "$SDLC_VAULT/_agents/sdlc.sh"

# Напрямую
cd "$SDLC_VAULT/_agents/[agent]"
claude "[задача]"          # task-режим
claude                     # интерактивный режим
claude "начни сессию"      # инициировать диалог с представлением
claude --continue          # продолжить последний диалог
```

## Агенты — инфраструктура (этап 0)
| Агент | Роль | Ключевые команды |
|-------|------|-----------------|
| `s0-kickoff` | Project Kickoff — онбординг / обновление беклога | `/start`, `/new`, `/refresh` |
| `s0-secrets` | Secrets Manager | `/add`, `/rotate`, `/env` |
| `s0-github` | GitHub Sync | `/init`, `/sync`, `/push`, `/status`, `/pr` |
| `s0-validate` | Structure Validator | `/validate`, `/fix` |
| `s0-tracker` | Sprint & Task Tracker | `/sprint-init`, `/sprint-close`, `/sprint-status`, `/report`, `/task-add`, `/task-done` |
| `s0-quality-gates` | Quality Gates Configurator — проектные пороги из risk-профиля (после S1, до S2) | `/configure`, `/validate-gates` |

## Цикл 1 — Разработка (24 шага)
Запуск: `sdlc.sh → 1) Запустить цикл → 1) Разработка`. Деплой (Цикл 2) и эксплуатация (Цикл 3) — отдельные циклы в реальной среде (агенты `cycle2-deploy/`, `cycle3-ops/`), в разработке.

| Этап | Агент | Ключевые команды |
|------|-------|-----------------|
| 1 — Планирование | `s1-pm` | `/feasibility`, `/vision` |
| 1 — Планирование | `s1-pmo` | `/charter`, `/risks` |
| 1 — Планирование | `s1-finance` | Business Case |
| 2 — Требования | `s2-ba` | `/extract-requirements`, `/brd` |
| 2 — Требования | `s2-po` | `/stories` |
| 2 — Требования | `s2-qa-req` | Testability Review |
| 2 — Требования | `s2-security` | `/security-requirements` (SG1: abuse cases, классификация данных, ASVS) |
| 3 — Дизайн | `s3-arch` | `/hld`, `/adr` |
| 3 — Дизайн | `s3-security` | Threat Model |
| 3 — Дизайн | `s3-rbac` | `/rbac-model`, `/rbac-matrix` |
| 3 — Дизайн | `s3-dba` | DB Schema |
| 4 — Разработка | `s4-dev` | Dev Report, Update Notes (обязательно после каждого PR) |
| 4 — Разработка | `s4-techlead` | Code Review (блокирует PR без обновлённой документации) |
| 5 — Тестирование | `s5-qa` | Test Plan, Go/No-Go |
| 5 — Тестирование | `s5-qa-auto` | E2E/API тесты |
| 5 — Тестирование | `s5-perf` | Load Tests |
| Финал | `s0-tracker` | `/report` (план vs факт) |
| Финал | `s0-github` | `/push` (push в ветку) |

## Циклы 2 и 3 (в разработке)
| Цикл | Агент | Назначение |
|------|-------|-----------|
| 2 — Деплой | `s4-devops` | CI/CD, Runbook, Auto-Heal Infrastructure |
| 2 — Деплой | `s6-release` | `/release-checklist`, `/release-notes` |
| 3 — Эксплуатация | `s6-sre` | Post-Deploy, Monitoring, Auto-Heal verify, SLO Review → Gate 7 |

## Система качества и надёжности

**Канонические стандарты (читать перед каждой задачей):**
- `$SDLC_VAULT/_agents/_standards/quality.md` — DoD, DoR, Gates, NFR, test pyramid (§3.1), ISO 25010 (§4.1), Auto-Heal, Known Issues (§6.1), метрики (§7)
- `$SDLC_VAULT/_agents/_standards/security.md` — параллельный Security-трек SG1–SG5 (CVSS, threat model, RBAC, SAST/SCA, pentest)
- `$SDLC_VAULT/_agents/_standards/data-formats.md` — форматы DB/ENV/API, обязательные тесты форматов

### Quality Gates — принудительные переходы между этапами
Переход заблокирован, пока Gate не закрыт. Агент следующего этапа проверяет Gate ПЕРВЫМ делом.
Параллельно действует **Security-трек SG1–SG5** (security.md §3): этап пройден только когда
зелёный И Quality Gate, И соответствующий Security Gate.

| Переход | Gate (+ Security Gate) | Кто проверяет |
|---------|------|--------------|
| S1 → S2 | Feasibility + Charter + Риски | **s2-ba** |
| S2 → S3 | BRD + NFR с числами + QA-REQ review (0 BLOCKER) + **SG1** | **s3-arch** |
| S3 → S4 | HLD + RBAC model + DB schema + **SG2** (threat model 0 Critical/High) | **s4-dev** |
| S4 → S5 | Все PR + DoD + branch≥80%+mutation + integration/contract + **SG3** (SAST/SCA) | **s5-qa** |
| S5 → S6 | Go/No-Go + Functional Suitability (Must-FR↔RTM) + UAT + PERF PASS + Known Issues + **SG4** | **s6-release** |
| S6 → PROD | Checklist + release notes (вкл. Known Issues) + rollback проверен | **s6-sre** |
| PROD → S7 | Monitoring + Auto-Heal verified + SLO Review + KI-алерты/runbook + **SG5** | **s6-sre** (через 7 дней) |

### Неотменяемые правила (нарушение = BLOCKER)
- Definition of Done (DoD) обязателен для каждой задачи — все 11 пунктов (включая DoD-11: тесты форматов)
- Definition of Ready (DoR) обязателен перед стартом каждого этапа — все 8 пунктов
- Secrets никогда не в коде, логах, .md-файлах
- Critical/High уязвимости (CVSS ≥ 7.0) блокируют релиз (severity по CVSS — security.md §1)
- Некритичный дефект (S3/S4) с user-facing impact в проде — только через known-issues.md (workaround + detection signal + runbook), иначе это «проигнорированный» дефект (quality.md §6.1)
- UAT только в реальной системе, не в эмуляторе
- Rollback-план до деплоя, не после
- Система без auto-heal (restart policy + liveness probe + watchdog) — не идёт в prod
- Система без алертов на SLO breach — не идёт в prod
- Следующий релиз заблокирован, если Gate 7 предыдущего не закрыт

## Правила именования файлов
```
Входные:   [ROLE]-input-[описание].md              → BA-input-interview.md
Выходные:  [ROLE]-YYYY-MM-DD-[артефакт].md         → BA-2026-05-10-BRD.md
Трекер:    tracking/sprints/sprint-NN.md
Docs:      DEV-YYYY-MM-DD-update-notes-PR[N].md    → stage4-dev/outputs/
           REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md → stage6-deploy/outputs/
           docs/CHANGELOG.md                        → корень проекта
```

## Передача данных между агентами
Агент читает артефакты предыдущего этапа через абсолютный путь.
НЕ ПЕРЕДАВАЙ историю диалога. Только финальные файлы из outputs/.

```bash
# Пример: s2-ba читает результат s1-pm
claude "Прочитай $SDLC_VAULT/projects/my-project/stage1-planning/outputs/PM-2026-05-10-feasibility.md и создай BRD"
```

## Пути проекта (env-переменные, КРИТИЧНО)

Абсолютные пути НЕ захардкожены — они приходят из окружения (лаунчер их экспортирует). Используй переменные, а не литералы вроде `/home/<user>/...`:

| Переменная | Что содержит | Пример пути |
|-----------|--------------|-------------|
| `AGENT_DIR` | папка текущего агента | `$AGENT_DIR/.claude/commands/` |
| `SDLC_VAULT` | корень vault | `$SDLC_VAULT/projects/{PROJECT}/...` |
| `LOCALRUN_PROJECTS` | локальные GitHub-проекты (L-агенты) | `$LOCALRUN_PROJECTS/{PROJECT}/` |

Получить значение в bash: `echo "$SDLC_VAULT"`. Стандарты читаются как `$SDLC_VAULT/_agents/_standards/quality.md`.

**Фолбэк:** если переменная пуста (агент запущен напрямую, минуя лаунчер) — спроси путь у пользователя, не угадывай и не подставляй чужой абсолютный путь.

## Рабочая директория (КРИТИЧНО)

**Правило bash-команд**: если нужно временно сменить директорию — используй **подоболочку**:

```bash
# ✅ Правильно — cwd возвращается после команды
(cd /some/project && git log)

# ❌ Неправильно — cwd меняется для ВСЕХ последующих bash-вызовов в сессии
cd /some/project && git log
```

**Для всех файловых операций** используй только абсолютные пути (через env-переменные выше). Никогда не полагайся на текущую директорию для записи или чтения файлов.

**Верификация директории перед записью (КРИТИЧНО):** перед первой записью в директорию проекта — прочитай хотя бы один существующий файл оттуда, чтобы убедиться, что путь правильный. НЕ полагайся на память о расположении проекта из прошлых сессий — директория могла измениться. Если целевая папка пуста или не читается — уточни путь у пользователя, не угадывай. (INC-01)

## Поведенческие правила агентов (из prod-инцидентов FamilyPlannerBot)
Обязательны для всех агентов Цикла 1. Источник — пост-мортемы FamilyPlannerBot Sprint 4.

- **Git — не для отката.** Никогда не использовать `git checkout/reset/restore` для отмены ошибочных правок — откатывать вручную через Edit, восстанавливая содержимое файла. Любые git-операции выполняются ТОЛЬКО через агента `s0-github` или по явному запросу пользователя. (INC-02)
- **Запись файлов — самостоятельно.** Реализацию и правку кода/артефактов делать напрямую через Read/Edit/Write. НЕ делегировать запись сабагентам (Agent) или `claude -p` — у них может не быть прав, изменения молча не применятся (exit 0, файл не тронут). Сабагенты — только для read-only задач (поиск, анализ). (INC-03)
- **«Все» = полный вывод.** Если пользователь просит «все» (задачи, список и т.п.) — выводить целиком, без сокращений «ради краткости». Явное «все/полный» перевешивает дефолт на лаконичность. (INC-05)
- **Deployment constraint — учитывать.** Не предлагать действий, противоречащих модели деплоя проекта (напр. «выкатить в тест», когда тестовой среды нет — деплоятся только стабильные версии в prod). Читать `Deployment Constraint` из idea.md. (INC-07)

## Отвечай на русском

## Хранение секретов
Все секреты хранятся ТОЛЬКО в pass. Никаких исключений.

```bash
pass sdlc/ключ
pass sdlc/projects/{PROJECT}/ключ
export VAR=$(pass sdlc/ключ)
```

ЗАПРЕЩЕНО:
- Записывать секреты в .md файлы
- Хранить секреты в .env без pass как источника
- Передавать секреты между агентами текстом
- Коммитить файлы с секретами

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
  sdlc.sh           ← Главный лаунчер (полный SDLC-цикл)
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
bash "/home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/sdlc.sh"

# Напрямую
cd "/home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/[agent]"
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

## Агенты — SDLC-цикл (24 шага)
| Этап | Агент | Ключевые команды |
|------|-------|-----------------|
| 1 — Планирование | `s1-pm` | `/feasibility`, `/vision` |
| 1 — Планирование | `s1-pmo` | `/charter`, `/risks` |
| 1 — Планирование | `s1-finance` | Business Case |
| 2 — Требования | `s2-ba` | `/extract-requirements`, `/brd` |
| 2 — Требования | `s2-po` | `/stories` |
| 2 — Требования | `s2-qa-req` | Testability Review |
| 3 — Дизайн | `s3-arch` | `/hld`, `/adr` |
| 3 — Дизайн | `s3-security` | Threat Model |
| 3 — Дизайн | `s3-rbac` | `/rbac-model`, `/rbac-matrix` |
| 3 — Дизайн | `s3-dba` | DB Schema |
| 4 — Разработка | `s4-dev` | Dev Report, Update Notes (обязательно после каждого PR) |
| 4 — Разработка | `s4-techlead` | Code Review (блокирует PR без обновлённой документации) |
| 4 — Разработка | `s4-devops` | CI/CD, Runbook, Auto-Heal Infrastructure |
| 5 — Тестирование | `s5-qa` | Test Plan, Go/No-Go |
| 5 — Тестирование | `s5-qa-auto` | E2E/API тесты |
| 5 — Тестирование | `s5-perf` | Load Tests |
| 6 — Деплой | `s6-release` | `/release-checklist`, `/release-notes` |
| 6 — Деплой | `s6-sre` | Post-Deploy Report (T+0..T+60) |
| 7 — Эксплуатация | `s6-sre` | Monitoring Dashboard + Auto-Heal verify → **Gate 7 (ОБЯЗАТЕЛЬНО)** |
| — | `s0-tracker` | `/report` (план vs факт) |
| — | `s0-github` | `/push` (push в ветку) |

## Система качества и надёжности

**Канонические стандарты (читать перед каждой задачей):**
- `/home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/_standards/quality.md` — DoD, DoR, Gates, NFR, Auto-Heal
- `/home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/_standards/data-formats.md` — форматы DB/ENV/API, обязательные тесты форматов

### Quality Gates — принудительные переходы между этапами
Переход заблокирован, пока Gate не закрыт. Агент следующего этапа проверяет Gate ПЕРВЫМ делом.

| Переход | Gate | Кто проверяет |
|---------|------|--------------|
| S1 → S2 | Feasibility + Charter + Риски | **s2-ba** |
| S2 → S3 | BRD + NFR с числами + QA-REQ review (0 BLOCKER) | **s3-arch** |
| S3 → S4 | HLD + Threat Model (0 Critical/High) + RBAC model + DB schema | **s4-dev** |
| S4 → S5 | Все PR закрыты + DoD + coverage ≥80% + SAST pass | **s5-qa** |
| S5 → S6 | Go/No-Go + UAT sign-off + PERF PASS | **s6-release** |
| S6 → PROD | Checklist + release notes + rollback проверен | **s6-sre** |
| PROD → S7 | Monitoring + Auto-Heal verified + SLO Review | **s6-sre** (через 7 дней) |

### Неотменяемые правила (нарушение = BLOCKER)
- Definition of Done (DoD) обязателен для каждой задачи — все 11 пунктов (включая DoD-11: тесты форматов)
- Definition of Ready (DoR) обязателен перед стартом каждого этапа — все 8 пунктов
- Secrets никогда не в коде, логах, .md-файлах
- Critical/High уязвимости блокируют релиз
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
claude "Прочитай /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/my-project/stage1-planning/outputs/PM-2026-05-10-feasibility.md и создай BRD"
```

## Рабочая директория (КРИТИЧНО)

Переменная окружения `AGENT_DIR` содержит абсолютный путь к папке текущего агента.

**Правило bash-команд**: если нужно временно сменить директорию — используй **подоболочку**:

```bash
# ✅ Правильно — cwd возвращается после команды
(cd /some/project && git log)

# ❌ Неправильно — cwd меняется для ВСЕХ последующих bash-вызовов в сессии
cd /some/project && git log
```

**Для всех файловых операций** используй только абсолютные пути. Никогда не полагайся на текущую директорию для записи или чтения файлов.

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

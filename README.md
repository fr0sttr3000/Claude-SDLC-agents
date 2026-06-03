---
date: 2026-06-03
tags: [docs, agents, sdlc]
---

# Claude SDLC Agents

> Автоматизированная система управления жизненным циклом разработки (SDLC) на базе Claude Code.
> 27 специализированных AI-агентов покрывают весь цикл — от идеи до деплоя и эксплуатации.

---

## Что это такое

**Claude SDLC Agents** — набор специализированных Claude Code агентов, каждый из которых выполняет конкретную роль в процессе разработки программного обеспечения: Product Manager, Business Analyst, Architect, DBA, Developer, QA, DevOps, SRE и другие.

Агенты работают последовательно, передавая артефакты (markdown-файлы) друг другу через файловую систему. Между этапами стоят **Quality Gates** — принудительные барьеры, которые блокируют переход до выполнения всех условий.

### Ключевые особенности

- **27 агентов**, охватывающих 7 этапов SDLC + инфраструктуру + Local Run
- **Markdown-first** — все артефакты, стандарты и входные данные — `.md` файлы
- **Obsidian vault** — вся система открывается как хранилище знаний в Obsidian
- **Интерактивный лаунчер** `sdlc.sh` — единая точка входа для всего цикла
- **7 Quality Gates** — принудительные переходы между этапами с чеклистами
- **Definition of Done (11 пунктов)** — обязательные условия закрытия каждой задачи
- **Стандарт форматов данных** — обязательные правила для DB, ENV, API + шаблоны тестов
- **Auto-Heal паттерны** — применимые паттерны определяются топологией деплоя (single-container / multi-instance / serverless)
- **Методология выбора паттернов** — 7 формализованных правил: QA → Tactic → Pattern → ADR с трейдоффом
- **Система управления секретами** через `pass` — нет секретов в коде и файлах
- **Sprint & Task Tracker** с DoD-enforcement и velocity-метриками

---

## Архитектура

```
_agents/
├── sdlc.sh            ← Главный лаунчер (SDLC-цикл + необязательные шаги)
├── localrun.sh        ← Лаунчер Local Run (GitHub-проекты)
├── _standards/        ← Стандарты (читаются всеми агентами)
│   ├── quality.md     ← DoD, DoR, Quality Gates, NFR, Auto-Heal
│   ├── data-formats.md← Форматы DB/ENV/API, обязательные тесты форматов
│   ├── company.md     ← Стек, роли, compliance (методология → plans/principles.md)
│   ├── dor-violations-template.md ← Шаблон журнала нарушений DoR
│   └── tech-debt-template.md      ← Шаблон журнала технического долга
├── _tools/            ← Утилиты для всех циклов
│   ├── s0-github/     ← GitHub Sync
│   └── s0-secrets/    ← Secrets Manager
├── plans/             ← Планы развития системы
│   ├── principles.md  ← Принципы проекта (SDD, TDD, Shift Left и др.)
│   └── roadmap.md     ← Roadmap и запланированные изменения
├── cycle1-dev/        ← Цикл 1: Разработка (19 агентов)
│   ├── s0-kickoff/    ← Project Kickoff
│   ├── s0-tracker/    ← Sprint & Task Tracker
│   ├── s0-validate/   ← Structure Validator
│   ├── s1-*/          ← Этап 1: Планирование (pm, pmo, finance)
│   ├── s2-*/          ← Этап 2: Требования (ba, po, qa-req)
│   ├── s3-*/          ← Этап 3: Дизайн (arch, security, rbac, dba)
│   ├── s4-*/          ← Этап 4: Разработка (dev, techlead)
│   ├── s5-*/          ← Этап 5: Тестирование (qa, qa-auto, perf)
│   └── l*/            ← Local Run — оснастка разработчика (analyze, setup, build, run)
├── cycle2-deploy/     ← Цикл 2: Деплой (разрабатывается)
│   ├── s4-devops/     ← DevOps Engineer
│   └── s6-release/    ← Release Manager
└── cycle3-ops/        ← Цикл 3: Эксплуатация (разрабатывается)
    └── s6-sre/        ← SRE
```

Каждый агент — отдельная папка с `CLAUDE.md` (роль, правила, стандарты) и `.claude/commands/` (slash-команды).

> **Принципы системы** (3 цикла, SDD, TDD, Shift Left, Markdown-first и др.) — [[plans/principles]]
> **Roadmap изменений** — [[plans/roadmap]]

Каждый агент — отдельная папка с `CLAUDE.md` (роль, правила, стандарты) и `.claude/commands/` (slash-команды).

---

## SDLC-цикл

```
Онбординг (перед первым запуском — обязательно)
  s0-kickoff /new      → интервью: заполняет idea.md и PM-input-interview.md
  s0-kickoff /refresh  → обновление беклога / видения для существующего проекта

Подготовка (необязательно, выбирается пользователем)
  └─ s0-validate, s0-secrets, s0-tracker /sprint-init

Этап 1: Планирование ──[Gate 1]──►
  s1-pm  → Feasibility Study, Product Vision
  s1-pmo → Project Charter, Risk Register
  s1-finance → Business Case, ROI

Этап 2: Требования ──[Gate 2]──►
  s2-ba     → BRD, NFR (с числами), RTM
  s2-po     → User Stories, Backlog
  s2-qa-req → Testability Review (блокирует Gate 2)

Этап 3: Дизайн ──[Gate 3]──►
  s3-arch     → HLD, ADR, API Spec
  s3-security → Threat Model (STRIDE/DREAD/OWASP)
  s3-rbac     → RBAC Model, Permission Matrix, RLS + SQL схема
  s3-dba      → DB Schema, Migrations

Этап 4: Разработка ──[Gate 4]──►
  s4-dev      → код, PR Summary, Update Notes
  s4-techlead → Code Review (блокирует Gate 4)

Этап 5: Тестирование ──[Gate 5]──►
  s5-qa      → Test Plan, Go/No-Go (блокирует Gate 5)
  s5-qa-auto → E2E/API тесты (coverage ≥95%)
  s5-perf    → Load Tests

Финальные шаги Цикла 1 (обязательные)
  s0-tracker /report → отчёт план vs факт
  s0-github  /push   → push артефактов в GitHub

─── Цикл 2: Деплой (разрабатывается) ───────────────────────────
  s4-devops  → CI/CD, Runbook, Monitoring (деплой в реальную среду)
  s6-release → Release Checklist, Release Notes

─── Цикл 3: Эксплуатация (разрабатывается) ─────────────────────
  s6-sre     → Post-Deploy Report, Monitoring, Auto-Heal, SLO Review
```

---

## Markdown-first и Obsidian

### Всё работает через .md файлы

Система полностью построена на Markdown. Каждый артефакт, отчёт, стандарт, входной документ — это `.md` файл. Агенты читают входные `.md` файлы и создают выходные `.md` файлы. Никаких баз данных, никаких проприетарных форматов.

```
inputs/idea.md               ← пишешь описание идеи в Obsidian
      ↓  s1-pm читает idea.md
outputs/PM-2026-05-10-feasibility.md   ← агент создаёт артефакт
      ↓  s2-ba читает PM-feasibility.md
outputs/BA-2026-05-10-BRD.md           ← следующий агент создаёт свой артефакт
```

Каждый `.md` файл артефакта содержит:
- **YAML frontmatter** — дата, теги, статус, агент
- **Структурированный контент** — разделы по шаблону роли
- **Чеклисты** — Gate-условия и DoD-пункты
- **Вердикт** — `PASSED / FAILED / GO / NO-GO` для Gate-файлов

Стандарты тоже `.md` файлы — агент читает `quality.md` и `data-formats.md` как обычный документ и применяет правила.

### Интеграция с Obsidian

Вся система является **Obsidian vault**. Папка `Claude/` открывается в Obsidian как хранилище знаний — артефакты всех проектов и всех этапов видны в едином интерфейсе.

**Возможности Obsidian в системе:**

| Функция | Как используется |
|---------|-----------------|
| **Graph View** | Граф связей между артефактами этапов и проектов |
| **Wiki-links** `[[...]]` | Перекрёстные ссылки: `[[OVERVIEW]]`, `[[Local_Run/_workflow]]` |
| **YAML frontmatter** | Метаданные каждого файла: `date`, `tags`, `status` |
| **Tags** | Фильтрация по проектам, этапам, ролям, статусу |
| **Backlinks** | Видно какие документы ссылаются на текущий |
| **Search** | Поиск по всем артефактам всех проектов сразу |
| **Folder navigation** | Структура `stage1..stage7` видна в боковой панели |
| **Dataview plugin** | Автоматические таблицы задач, статусов, дат |

**Структура vault (папка `Claude/` в Obsidian):**

```
Claude/                            ← корень Obsidian vault
├── _agents/                       ← этот репозиторий (агенты + стандарты)
│   ├── _standards/quality.md      ← читается в Obsidian как документ
│   ├── _standards/data-formats.md
│   └── OVERVIEW.md                ← [[OVERVIEW]] в Obsidian
│
├── projects/
│   └── {PROJECT}/
│       ├── Dashboard.md           ← прогресс проекта, таблица этапов
│       ├── docs/CHANGELOG.md      ← история изменений
│       ├── stage1-planning/
│       │   ├── inputs/idea.md     ← пишешь в Obsidian → агент читает
│       │   └── outputs/           ← артефакты агентов → читаешь в Obsidian
│       ├── stage2-requirements/outputs/
│       ├── ...stage7-ops/outputs/
│       └── tracking/
│           ├── backlog.md         ← список задач
│           ├── current-sprint.md  ← активный спринт
│           └── sprints/sprint-NN.md
│
└── Local_Run/
    └── {project}/                 ← заметки о GitHub-проектах
        ├── overview.md
        ├── setup.md
        ├── build.md
        └── run.md
```

**Dashboard.md** каждого проекта — живая таблица прогресса в Obsidian:

```markdown
---
date: 2026-05-10
tags: [project/my-project, dashboard]
status: active
---

# SDLC Dashboard — my-project

| Этап | Статус | Последнее обновление |
|------|--------|---------------------|
| 1 — Планирование    | ✅ Done       | 2026-05-10 |
| 2 — Требования      | 🔄 In Progress| 2026-05-10 |
| 3 — Дизайн          | ⏳ Pending    | —          |
```

**Теги для навигации по артефактам:**

```yaml
---
date: 2026-05-10
tags: [project/my-project, stage/requirements, agent/ba, status/done]
---
```

В Obsidian можно сразу найти все артефакты конкретного проекта (`#project/my-project`), все BRD всех проектов (`#agent/ba`), все незавершённые этапы (`#status/in-progress`).

### Workflow: Obsidian + агенты

```
1. Открыть idea.md в Obsidian → написать описание проекта
         ↓
2. Запустить sdlc.sh → агент читает idea.md → создаёт PM-feasibility.md
         ↓
3. Открыть PM-feasibility.md в Obsidian → прочитать, при необходимости дополнить
         ↓
4. Следующий агент читает PM-feasibility.md → создаёт следующий артефакт
         ↓
5. В Obsidian Graph View видна вся цепочка артефактов проекта
```

Входные файлы (`inputs/`) можно готовить прямо в Obsidian перед запуском агента — интервью, требования, описания — всё в привычном редакторе.

---

## Быстрый старт

> Подробное руководство с примерами — см. [GETTING_STARTED.md](GETTING_STARTED.md)

### Предварительные требования

- [Claude Code CLI](https://claude.ai/code) — установлен и авторизован
- `bash` 4.0+
- `pass` — менеджер паролей (для хранения секретов)
- [Obsidian](https://obsidian.md) — опционально, но рекомендуется

### Установка

```bash
git clone git@github.com:fr0sttr3000/Claude-SDLC-agents.git _agents
cd _agents
bash sdlc.sh
```

**Для Obsidian:** открой папку `Claude/` как vault — все артефакты видны в едином интерфейсе.

### Первый запуск (новый проект)

```
sdlc.sh
  → 3) Создать новый проект        ← создаёт структуру stage1..stage7
  → 0) Kickoff                     ← интервью: заполняет все входные данные
  → 1) Запустить цикл → Разработка ← Цикл 1: 22 шага
```

Или пошагово:

```bash
bash sdlc.sh   # → 3) создай проект (вводи имя)
               # → соглашайся запустить Kickoff → проходи интервью
               # → 1) Запустить цикл → 1) Разработка
```

### Kickoff — обязательный шаг перед первым циклом

**`s0-kickoff`** собирает входные данные через структурированное интервью.
Без него агент `s1-pm` получит пустой `idea.md` и создаст артефакты только на предположениях.

| Режим | Когда использовать | Команда |
|-------|-------------------|---------|
| `/new` | Новый проект, пустые входные данные | `sdlc.sh → 0) Kickoff → 1)` |
| `/refresh` | Обновить беклог / видение / NFR | `sdlc.sh → 0) Kickoff → 2)` |
| `/start` | Авто-определение режима | `sdlc.sh → 0) Kickoff → 3)` |
| `/cr` | Change Request — изменение требований в середине этапа | `cd cycle1-dev/s0-kickoff && claude "/cr my-project"` |

**Режим `/new` — 5 блоков интервью, 26 вопросов:**
1. **Проблема и продукт** — pain point, As-Is, To-Be, описание продукта, аудитория, конкуренты, уникальность
2. **Бизнес** — модель, бюджет, ROI, команда, срок MVP
3. **Техника** — стек, масштаб, compliance, интеграции + **topology, recovery expectation, alert channel, monitoring expectation, delivery scope, existing monitoring**
4. **Приоритеты** — стейкхолдеры, Scope Out, must-have, критерии успеха (→North Star), kill criteria
5. **Неизвестное** — что неизвестно, что может остановить проект

Вопросы задаются последовательно, по одному. Правило 5 Whys при ответах типа «симптом». После каждого блока — резюме и подтверждение.

Выход: заполненный `idea.md` (со всеми полями Operational Tier) + `PM-input-interview-YYYY-MM-DD.md` → передаёт `s1-pm`.

**Режим `/refresh` — обновление существующего проекта:**

Показывает текущий статус проекта, предлагает меню разделов для обновления:
- Продуктовое видение и OKR → передаёт `s1-pm /vision`
- Новые функции в беклог → передаёт `s2-ba` + `s2-po`
- Приоритизация беклога → передаёт `s2-po`
- Изменение NFR / масштаба → передаёт `s2-ba`
- Scope Out — что убираем → передаёт `s2-ba` + `s2-po`

**Режим `/cr` — Change Request:**

Интервью из 4 блоков (что изменилось / конкретно до-после / причина / срочность).
Строит таблицу влияния: затронутые этапы → сброшенные DoR-пункты → что нужно переделать.
Выход: `stage{N}/inputs/CR-YYYY-MM-DD-[N]-input.md` + запись в `tracking/dor-violations.md`.
После CR пользователь вручную перезапускает затронутых агентов (агенты не взаимодействуют напрямую).

---

## Каталог агентов

### Инфраструктура (этап 0)

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s0-kickoff` | Project Kickoff — интервью для нового проекта / обновление беклога / Change Request | `/start`, `/new`, `/refresh`, `/cr` |
| `s0-secrets` | Secrets Manager — pass: хранение, ротация, env | `/add`, `/rotate`, `/env` |
| `s0-github` | GitHub Sync — репо, ветки, PR, push | `/init`, `/sync`, `/push`, `/status`, `/pr` |
| `s0-validate` | Structure + Quality Validator + DoR/DoD auto-check | `/validate [project\|all]`, `/fix [project\|all]`, `/dor-check [N]`, `/dod-check [K\|D\|I] [N] [PR]` |
| `s0-tracker` | Sprint & Task Tracker (DoD + Tech Debt enforcement) | `/sprint-init`, `/sprint-close`, `/sprint-status`, `/report`, `/task-add`, `/task-done` |

### Local Run (l-агенты)

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `l1-analyze` | Project Analyzer — стек, зависимости, порты | `/analyze [project]` |
| `l2-setup` | Project Setup — зависимости, .env, docker | `/setup [project]` |
| `l3-build` | Project Builder — сборка, артефакты | `/build [project]` |
| `l4-run` | Project Runner — запуск, порты, кастомизации | `/run [project]` |

### Этап 1 — Планирование

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s1-pm` | Product Manager — Feasibility, Vision, OKR | `/feasibility`, `/vision` |
| `s1-pmo` | Project Manager — Charter, WBS, Risk Register, RACI | `/charter`, `/risks` |
| `s1-finance` | Finance Analyst — ROI, NPV, Business Case | `/business-case` |

### Этап 2 — Требования

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s2-ba` | Business Analyst — BRD, NFR (с числами), RTM | `/extract-requirements`, `/brd` |
| `s2-po` | Product Owner — User Stories, Backlog (INVEST/RICE) | `/stories` |
| `s2-qa-req` | QA (требования) — Testability Review → **Gate 2** | `/testability-review` |

### Этап 3 — Дизайн

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s3-arch` | Solution Architect — HLD, ADR, API Spec | `/hld`, `/adr` |
| `s3-security` | Security Engineer — Threat Model (STRIDE/DREAD/OWASP) | `/threat-model` |
| `s3-rbac` | RBAC Designer — роли, матрица прав, RLS, SQL схема | `/rbac-model`, `/rbac-matrix` |
| `s3-dba` | DBA — DB Schema, Migrations | `/schema`, `/migration` |

### Этап 4 — Разработка

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s4-dev` | Backend Developer — код, PR Summary, Update Notes | `/dev-report`, `/update-notes` |
| `s4-techlead` | Tech Lead — Code Review (DoD) → **Gate 4** | `/review` |

### Этап 5 — Тестирование

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s5-qa` | QA Engineer — Test Plan, Go/No-Go → **Gate 5** | `/test-plan`, `/go-no-go` |
| `s5-qa-auto` | QA Automation — E2E/API тесты (coverage ≥95%) | `/e2e-report` |
| `s5-perf` | Performance Engineer — Load Tests | `/load-test` |

### Цикл 2 — Деплой *(разрабатывается)*

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s4-devops` | DevOps Engineer — CI/CD, Runbook, Monitoring, деплой | `/pipeline`, `/runbook` |
| `s6-release` | Release Manager — Checklist, Release Notes | `/release-checklist`, `/release-notes` |

### Цикл 3 — Эксплуатация *(разрабатывается)*

| Агент | Роль | Slash-команды |
|-------|------|--------------|
| `s6-sre` | SRE — Post-Deploy, Monitoring, Auto-Heal, SLO Review | `/post-deploy`, `/gate7` |

---

## Стандарты качества

### Definition of Done (11 пунктов)

DoD **бинарен** — нет "Done minus docs". Задача остаётся IN_PROGRESS до выполнения всех применимых пунктов.
Применимость по типу: **К** (Код — все 11) / **Д** (Документ — DoD 3,4,5,7,8,10) / **И** (Инфраструктура — DoD 2..11 кроме 6).
Автопроверка: `s0-validate /dod-check [K|D|I] [STAGE] [PR]`.

| # | Условие | Тип | Проверка |
|---|---------|-----|---------|
| 1 | Complexity ≤10, SRP | К | 🤖 частично |
| 2 | Unit-тесты, покрытие ≥80% изменённого кода | К, И | 🤖 авто |
| 3 | Code review: 0 BLOCKER и MAJOR | К, Д, И | 👤 вручную |
| 4 | README/API-spec/docstring обновлены | К, Д, И | 👤 вручную |
| 5 | CHANGELOG.md обновлён | К, Д, И | 🤖 авто |
| 6 | DEV-*-update-notes-PR[N].md создан | К | 🤖 авто |
| 7 | Нет S1/S2 багов без митигации | К, Д, И | 👤 вручную |
| 8 | Секреты не в коде, не в логах, не в артефактах | К, Д, И | 🤖 авто |
| 9 | NFR проверены (latency, error rate, memory) | К, И | 👤 вручную |
| 10 | Артефакт записан в outputs/ текущего этапа | К, Д, И | 🤖 авто |
| 11 | Тесты форматов: test_env/db/api_format.py | К, И | 🤖 авто |

Осознанный пропуск DoD → фиксировать в `tracking/tech-debt.md` (блокирует sprint-close при просрочке).

### NFR дефолты

| Метрика | Порог |
|---------|-------|
| Availability | ≥ 99.9% |
| Response time p95 | < 500 ms |
| Error rate | < 0.1% |
| Test coverage | ≥ 80% |
| Security Critical/High | 0 |

### Стандарт форматов данных (`_standards/data-formats.md`)

Обязательные правила:
- DB: всегда `TIMESTAMP WITH TIME ZONE`, деньги только `NUMERIC(p,s)`, PK только UUID v4
- ENV: list/set/frozenset — JSON-формат (`[1,2,3]`, не `1,2,3`)
- API: datetime ISO 8601 UTC, UUID строка v4, стандартный формат ошибок
- Обязательные тест-файлы: `test_env_format.py`, `test_db_format.py`, `test_api_format.py`

---

## Хранение секретов

Все секреты хранятся **только в `pass`**. Никаких исключений.

```bash
# Добавить секрет
cd _tools/s0-secrets && claude /add my-project api-key

# Использовать секрет
export TOKEN=$(pass sdlc/projects/my-project/api-key)
```

Запрещено: секреты в `.md` файлах, `.env` без pass как источника, передача текстом между агентами, коммит файлов с секретами.

---

## Прямой запуск агента

```bash
# Перейди в папку агента
cd cycle1-dev/s1-pm

# Slash-команда (task-режим — выполнит и завершится)
claude /feasibility my-project

# Произвольная задача
claude "Создай Feasibility Study для проекта my-project"

# Интерактивный диалог
claude "начни сессию"
claude --continue
```

---

## Передача данных между агентами

```bash
# Агент читает артефакт предыдущего через абсолютный путь
cd cycle1-dev/s2-ba
claude "Прочитай /path/to/projects/my-project/stage1-planning/outputs/PM-2026-05-10-feasibility.md и создай BRD"
```

Правило: только финальные файлы из `outputs/`. Историю диалога не передавать.

---

## Структура файлов outputs/

| Агент | Формат | Пример |
|-------|--------|--------|
| s1-pm | `PM-YYYY-MM-DD-[тип].md` | `PM-2026-05-10-feasibility.md` |
| s2-ba | `BA-YYYY-MM-DD-BRD.md` | `BA-2026-05-10-BRD.md` |
| s3-arch | `ARCH-YYYY-MM-DD-HLD.md` | `ARCH-2026-05-10-HLD.md` |
| s3-security | `SEC-YYYY-MM-DD-threat-model.md` | блокирует Gate 3 при наличии Critical/High |
| s3-rbac | `RBAC-YYYY-MM-DD-model.md` | роли, иерархия, SoD, условный доступ |
| s3-rbac | `RBAC-YYYY-MM-DD-matrix.md` | матрица прав (роль × ресурс × действие) |
| s3-rbac | `RBAC-YYYY-MM-DD-schema.sql` | таблицы RBAC + RLS политики |
| s4-dev | `DEV-YYYY-MM-DD-update-notes-PR[N].md` | обязателен после каждого PR |
| s4-techlead | `TL-YYYY-MM-DD-review-PR[N].md` | блокирует Gate 4 |
| s5-qa | `QA-YYYY-MM-DD-go-no-go.md` | блокирует Gate 5 |
| s6-release | `REL-YYYY-MM-DD-checklist-v[X.Y.Z].md` | блокирует Gate 6 |
| s6-sre | `SRE-YYYY-MM-DD-autoheal-report.md` | блокирует Gate 7 |

---

## Советы

- Перед первым запуском заполни `_standards/company.md` — стек, роли, compliance (методология — в `plans/principles.md`)
- Quality Gates проверяются агентом следующего этапа автоматически
- `s0-validate /fix` — быстро создать недостающую структуру проекта
- `/model claude-opus-4-7` — переключить модель внутри сессии для сложных задач
- Gate 7 обязателен через 7 дней после деплоя — без него следующий релиз заблокирован

---

## Файлы для кастомизации

| Файл | Назначение |
|------|-----------|
| `_standards/company.md` | Стек компании, роли, compliance (заполни под свой проект) |
| `_standards/quality.md` | NFR-дефолты, пороги gates, паттерны надёжности |
| `_standards/data-formats.md` | Правила форматов DB/ENV/API, шаблоны тестов |
| `plans/principles.md` | Принципы разработки (SDD, TDD, Shift Left и др.) |
| `plans/roadmap.md` | Roadmap и запланированные изменения системы |
| `{agent}/CLAUDE.md` | Роль, правила, стандарты конкретного агента |
| `sdlc.sh` → `OPTIONAL_AGENTS_DEF` | Список необязательных шагов цикла |

---

---

*Claude SDLC Agents v2.000.001 — [Первый запуск](GETTING_STARTED.md) · [Полный обзор](OVERVIEW.md) · [Принципы](plans/principles.md) · [Roadmap](plans/roadmap.md) · [История изменений](CHANGELOG.md)*

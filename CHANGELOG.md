---
date: 2026-05-23
tags: [docs, changelog]
---

# CHANGELOG — Claude SDLC Agents

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

---

## [1.6.0] — 2026-05-23

### Added

#### Методология выбора архитектурных паттернов (s3-arch) — 7 правил
- **Правило 1**: паттерн только при наличии проблемы — запрещено добавлять "про запас"
- **Правило 2**: цепочка QA → Tactic → Pattern — каждый паттерн проходит путь через Quality Attribute из NFR (таблица 10 QA → 30+ паттернов)
- **Правило 3**: NFR-порог → Паттерн — таблица: availability, error_rate, RPO, RTO, наличие внешних API → обязательный набор паттернов
- **Правило 4**: топология деплоя → фильтр паттернов — single-container / multi-instance / serverless × 9 паттернов
- **Правило 5**: выбор архитектурного стиля — условие из BRD → Monolith / Microservices / CQRS / Saga / Event-Driven / BFF / API Gateway
- **Правило 6**: выбор протокола — условие → REST / GraphQL / gRPC / Message Queue / WebSocket с обоснованием
- **Правило 7**: трейдофф обязателен (ATAM) — таблица "выигрываем / платим" для 6 паттернов; без трейдоффа ADR не засчитывается

#### Методология выбора контролей безопасности (s3-security)
- **STRIDE → Security Control**: каждой угрозе — конкретная контрмера (Spoofing→Auth, Tampering→TLS+HMAC, Repudiation→AuditLog, InfoDisclosure→Encryption+RLS, DoS→RateLimit+CB, EoP→RBAC+DenyByDefault)
- **DREAD score → действие**: Critical(>8) блокирует Gate 3; High(6-8) контрмера до Gate 3; Medium → митигация в спринте; Low → ADR
- **Выбор механизма аутентификации**: OAuth2 / mTLS / JWT / MFA — по условию из BRD

#### Методология выбора технологии хранения (s3-dba)
- **Характеристики данных → Технология**: PostgreSQL (default) / Redis (кэш) / MongoDB (только с ADR) / FTS / TimescaleDB — с условием "когда НЕ использовать"
- **NFR → Паттерн доступа**: CQRS+ReadReplica / Event Sourcing / Partitioning / ConnectionPool+Cache / Expand-Contract / RLS (мультитенантность)

#### Deployment Constraint — новая обязательная категория NFR (s2-ba)
- Категория "Deployment" добавлена в список NFR: `DC-1: Deployment Constraint = single-container | multi-instance | serverless`
- Фиксируется в `BA-NFR.md` до начала `s3-arch`; определяет применимость паттернов в Gate 6
- Добавлен в Quality Gate checklist s2-ba; если не указано явно — уточнять у стейкхолдера

#### Topology-Aware Auto-Heal (s4-devops + quality.md §5.5)
- Все пункты Auto-Heal чеклиста помечены `[SC]` / `[MI]` / `[SL]` по топологии
- Readiness Probe: применима только для `[MI]` (multi-instance)
- Circuit Breaker / Watchdog / DLQ: добавлены условия применимости (только если есть deps/воркеры/очереди)
- Неприменимый пункт ≠ BLOCKER, но требует документирования причины в runbook
- `quality.md §8` — три новых запрета: паттерн без QA-обоснования, паттерн "про запас", отсутствие Deployment Constraint

### Fixed

#### Изоляция агентов — 3 нарушения в s3-dba (внесённые в этом цикле)
- `s3-dba:25` `"согласованием s3-arch"` → `"ARCH-ADR в stage3-design/outputs/"`
- `s3-dba:33` `"s3-arch проектирует, s3-dba реализует"` → `"если ARCH-HLD.md содержит CQRS"`
- `s3-dba:109` `"согласования с s3-security"` → `"из SEC-*-threat-model.md"`

---

## [1.5.0] — 2026-05-22

### Added

#### DoR — полная реализация 7 лучших практик
- **`quality.md §1`** полностью переработан: бинарность, колонки "Кто обеспечивает / Кто проверяет / Этап / Проверка", дедлайны готовности, правило возврата (4 шага), таблица сброса DoR при Change Request
- **DoR добавлен в 4 агента** (ранее отсутствовал): `s3-arch` (Gate 2, 6 пунктов), `s5-qa` (Gate 4, 7 пунктов), `s6-release` (Gate 5, 7 пунктов), `s6-sre` (Gate 6 + Gate 7, 11 пунктов)
- **`_standards/dor-violations-template.md`** — шаблон журнала нарушений DoR с форматом записи (дата, агент, нарушенные пункты, статус, дата устранения)
- **`s0-kickoff /cr`** — новый режим Change Request: структурированное интервью, Impact Analysis, сброс затронутых DoR-пунктов, CR-файл в inputs/, запись в dor-violations.md
- **`s0-validate /dor-check [N]`** — автоматическая проверка DoR перед переходом на Gate N
- **`dor-check.sh`** — bash-скрипт автопроверки: DoR-1 (файлы), DoR-2 (маркеры), DoR-3 (Given/When/Then), DoR-4 (числа в NFR), DoR-5 (BLOCKER grep), DoR-7 (threat model), DoR-8 (rollback)

#### DoD — полная реализация 8 лучших практик
- **`quality.md §2`** полностью переработан: бинарность, колонки "Кто обеспечивает / Кто проверяет / Проверка", матрица применимости по 3 типам артефактов, связь DoD-10 → DoR-1, правило технического долга
- **Типы артефактов DoD**: Тип К (Код, все 11 пунктов), Тип Д (Документ, 6 пунктов), Тип И (Инфраструктура, 9 пунктов)
- **Связь DoD → DoR**: DoD-10 выполнен = DoR-1 следующего этапа выполнен автоматически (таблица по всем 6 переходам)
- **Технический долг**: правило фиксации осознанных пропусков DoD, блокировки при > 3 открытых TD
- **`_standards/tech-debt-template.md`** — шаблон журнала техдолга с форматом TD-записи (причина, кто одобрил, план устранения, дедлайн)
- **`s0-validate /dod-check [TYPE] [STAGE] [PR]`** — автоматическая проверка DoD по типу артефакта
- **`dod-check.sh`** — bash-скрипт: DoD-1 (complexity прокси), DoD-2 (coverage report / тест миграций), DoD-3 (TL-review файл), DoD-5 (CHANGELOG), DoD-6 (update notes), DoD-8 (secrets grep), DoD-10 (outputs/), DoD-11 (тесты форматов)

#### s0-tracker — контроль техдолга и возвратов DoR
- Инициализация `dor-violations.md` и `tech-debt.md` при первом `/sprint-init`
- При `/sprint-close`: блокировка если есть просроченные TD
- При `/sprint-init`: сводка открытых TD
- При `> 3` открытых TD: блокировка старта следующего спринта

### Fixed

#### Изоляция агентов — 8 нарушений принципа устранено
Все формулировки прямой межагентной коммуникации заменены на файловую передачу данных через `tracking/`:
- `quality.md §1` — "Вернуть список агенту-поставщику" → "Записать в dor-violations.md"
- `quality.md §2` — "Артефакт передан следующему агенту" → "Артефакт записан в outputs/"
- `s5-qa` — "вернуть задачу в s4-dev" → "зафиксировать в dor-violations.md, пользователь перезапускает"
- `s6-release` — аналогично для s5-qa
- `s6-sre` — аналогично для s6-release
- `s0-kickoff CR` — "Агенты к уведомлению" → "Пользователю перезапустить (через sdlc.sh)"
- `dod-check.sh` — "не передан следующему агенту" → "не записан в outputs/"

---

## [1.4.0] — 2026-05-11

### Added

#### Skills (slash-команды) для 11 агентов — 18 новых команд
Все агенты теперь имеют slash-команды. Ни один агент не требует задачи «свободным текстом».

| Агент | Новые команды |
|-------|--------------|
| `s1-finance` | `/business-case` — Business Case (NPV, ROI, TCO, сценарный анализ) |
| `s2-qa-req` | `/testability-review` — Testability Review + Gate 2 вердикт |
| `s3-dba` | `/schema` — DB Schema (PostgreSQL, UUID v4, TIMESTAMPTZ) |
| `s3-dba` | `/migration` — Alembic Migration Runbook (upgrade + downgrade) |
| `s3-security` | `/threat-model` — Threat Model (STRIDE + DREAD + OWASP Top 10) |
| `s4-dev` | `/dev-report` — Dev Report по завершённому PR |
| `s4-dev` | `/update-notes` — Update Notes для PR (обязательно после каждого PR) |
| `s4-techlead` | `/review` — Code Review с DoD checklist + Gate 4 вердикт |
| `s4-devops` | `/pipeline` — CI/CD pipeline (lint→test→build→SAST→secrets-scan) |
| `s4-devops` | `/runbook` — Runbook деплоя с rollback-процедурой и observability |
| `s5-qa` | `/test-plan` — Test Plan с тест-кейсами (IEEE 829) |
| `s5-qa` | `/go-no-go` — Go/No-Go решение + Gate 5 вердикт |
| `s5-qa-auto` | `/e2e-report` — E2E/API Automation Report + coverage |
| `s5-perf` | `/load-test` — Load Test (smoke/load/stress/soak) + вердикт |
| `s6-sre` | `/post-deploy` — Post-Deploy Report (мониторинг T+0..T+60) |
| `s6-sre` | `/gate7` — Gate 7: SLO Review + Auto-Heal + Incident Runbooks |

#### CYCLE_AGENTS — полный переход на slash-команды
- Все шаги полного цикла теперь используют `/slash-команды` вместо свободного текста
- Добавлены ранее отсутствующие шаги: `/runbook` (s4-devops), `/release-notes` (s6-release), `/gate7` (s6-sre)
- Цикл расширен с 23 до 26 шагов

### Fixed

#### Bash cwd drift — агенты больше не покидают свою директорию
- **Проблема**: bash-состояние в Claude Code персистентно в рамках сессии. При выполнении `cd /path && cmd` директория менялась для всех последующих вызовов.
- **`sdlc.sh`**: все три точки запуска агентов экспортируют `AGENT_DIR="$agent_dir"` — агент знает домашнюю директорию через переменную окружения.
- **`CLAUDE.md`**: добавлен раздел «Рабочая директория» с правилом подоболочки: `(cd /path && cmd)` вместо `cd /path && cmd`.

---

## [1.3.0] — 2026-05-10

### Added

#### s0-kickoff — Project Kickoff Facilitator (новый агент)
- Новый агент этапа 0: структурированный онбординг для новых и существующих проектов
- Режим **NEW**: 4 блока интервью (Продукт / Бизнес / Техника / Приоритеты), ~19 вопросов
  - Вопросы задаются последовательно, по одному; после каждого блока — резюме и подтверждение
  - Выход: заполненный `idea.md` + `PM-input-interview-YYYY-MM-DD.md`
- Режим **REFRESH**: меню из 5 разделов обновления (Видение/OKR, Беклог, Приоритеты, NFR, Scope Out)
  - Показывает текущий статус проекта из Dashboard.md
  - Целевое интервью только по выбранным разделам
  - Выход: `PM-input-refresh-*.md` и/или `BA-input-refresh-*.md`
- Авто-определение режима (`/start`): new vs refresh по наличию артефактов этапа 1
- Slash-команды: `/start`, `/new`, `/refresh`
- Интеграция в `sdlc.sh`: пункт `0) Kickoff` в главном меню (первый пункт)
- После создания нового проекта (`пункт 3`) — автоматическое предложение запустить `/new`

#### s3-rbac — RBAC Designer (новый агент)
- Новый агент этапа 3: проектирование ролевой модели доступа
- Принципы: Least Privilege, Deny by Default, SoD, Role Hierarchy, Resource Ownership
- Артефакты: `RBAC-model.md` (роли, иерархия), `RBAC-matrix.md` (роль × ресурс × действие), `RBAC-schema.sql` (таблицы + RLS)
- PostgreSQL Row-Level Security политики для owner-only ресурсов
- Выявление и документирование SoD-конфликтов
- Slash-команды: `/rbac-model`, `/rbac-matrix`
- Вставлен в SDLC-цикл между `s3-security` и `s3-dba` (шаг 11)

#### s4-dev — шаблоны реализации RBAC
- Новый раздел в `s4-dev/CLAUDE.md`: RBAC — Реализация (FastAPI + SQLAlchemy)
- Шаблон `require_permission()` dependency для FastAPI (deny by default)
- Шаблон `has_permission()` — SQL-запрос к RBAC-таблицам
- Шаблон owner-only: двойная проверка (application-level + PostgreSQL RLS)
- Шаблон наследования ролей через рекурсивный CTE
- Правило: запрет хардкода ролей в бизнес-логике (`if role == "admin"`)
- Шаблон `tests/test_rbac.py` с 5 обязательными тестами (deny-by-default, grant, hierarchy, owner-only, SoD)
- Gate 4 RBAC checklist (5 пунктов DoD)

#### _standards/data-formats.md (новый стандарт)
- Канонический стандарт форматов данных для всей системы
- §1 PostgreSQL↔ORM↔Python типы: 8 типов + таблица запрещённых форматов
- §2 ENV-переменные: форматы по Python-типу, 7 обязательных полей документирования
- §3 API/JSON контракты: datetime ISO 8601 UTC, UUID v4 строка, стандарт ошибок
- §4 Шаблоны обязательных тестов: `test_env_format.py`, `test_db_format.py`, `test_api_format.py`
- §5 Чеклисты для каждого агента (s2-ba, s3-dba, s4-dev)
- §6 Gate 3/4 условия по форматам

#### Документация
- `GETTING_STARTED.md` — подробное руководство первого запуска (новый файл)
- `CHANGELOG.md` — история изменений (этот файл)
- `README.md` — обновлён раздел "Быстрый старт": kickoff как обязательный шаг, таблица режимов
- `OVERVIEW.md` — добавлен раздел `s0-kickoff`, обновлено меню лаунчера

### Changed

#### Quality Gates (quality.md)
- **Gate 3** — добавлены 5 RBAC-условий:
  - `RBAC-*-model.md` существует: все роли покрыты, иерархия описана
  - `RBAC-*-matrix.md` существует: матрица полная (роль × ресурс × действие)
  - `RBAC-*-schema.sql` существует: таблицы + RLS политики
  - SoD-конфликты выявлены и задокументированы
  - Owner-ресурсы защищены RLS-политиками
- **Gate 3** — добавлены 5 условий по форматам данных
- **Gate 4** — добавлены 7 условий по тестам форматов

#### Definition of Done
- **DoD** расширен с 10 до 11 пунктов
- **DoD-11** (новый): тесты форматов данных написаны и проходят (`test_env_format.py` / `test_db_format.py` / `test_api_format.py` — если применимо)

#### sdlc.sh
- Пункт `0) Kickoff` добавлен в главное меню (перед пунктом 1)
- Функция `menu_kickoff()` с выбором режима (new / refresh / auto)
- `menu_new_project()` предлагает запустить kickoff после создания проекта
- `s3-rbac` добавлен в SDLC-цикл как шаг 11 (между s3-security и s3-dba)
- `s0-kickoff` добавлен в группу инфраструктуры в меню одного агента
- Необязательные шаги цикла — toggle UI для выбора пользователем

#### s4-dev/CLAUDE.md
- Gate 3 entry check: добавлена проверка `RBAC-*-model.md` и `RBAC-*-matrix.md`
- Правило: при реализации авторизации читать RBAC-артефакты и реализовывать права строго по матрице
- Изменения в RBAC требуют обновления RBAC-артефактов через s3-rbac

#### s0-validate/CLAUDE.md
- Проверка RBAC-артефактов для завершённых Stage 3:
  - `RBAC-*-model.md` существует в stage3/outputs/
  - `RBAC-*-matrix.md` существует в stage3/outputs/

#### s2-ba/CLAUDE.md
- Читает `data-formats.md` (добавлен в стандарты)
- Расширена таблица документирования ENV-переменных (7 обязательных полей)
- Добавлены правила для datetime, UUID, NUMERIC, JSONB, Enum в требованиях
- Gate 2 exit checklist расширен 7 format-пунктами

#### s3-dba/CLAUDE.md
- Читает `data-formats.md` (добавлен в стандарты)
- Расширены шаблоны документирования: JSONB, ENUM, CHECK, NUMERIC
- Gate 3 checklist расширен 8 format-пунктами

---

## [1.2.0] — 2026-05-10

### Added
- **Markdown-first документация** — описание того, что вся система построена на `.md` файлах
- **Obsidian integration** — раздел в README с инструкцией по использованию vault в Obsidian
- Таблица функций Obsidian (Graph View, Wiki-links, YAML frontmatter, Tags, Dataview)
- Описание структуры vault в Obsidian
- Workflow: Obsidian + агенты (пошаговый пример)

### Changed
- `README.md` — добавлен раздел "Markdown-first и Obsidian"
- `OVERVIEW.md` — обновлены описания Obsidian-возможностей

---

## [1.1.0] — 2026-05-10

### Added
- **Необязательные шаги в sdlc.sh** — toggle UI для выбора дополнительных шагов цикла
  - 4 предустановленных необязательных шага (s0-validate before/after, s0-secrets, s0-tracker)
  - Нумерованное меню переключения вкл/выкл перед запуском полного цикла
- **`_standards/data-formats.md`** — новый канонический стандарт форматов данных
- **`.gitignore`** — исключены `settings.local.json`, `.env`, `.DS_Store`

### Changed
- Скрипты перемещены из `_bin/` в `_agents/` — `sdlc.sh` и `localrun.sh` теперь в корне `_agents/`
- Обновлены все пути в документации: `_bin/sdlc.sh` → `_agents/sdlc.sh`
- `CLAUDE.md`, `OVERVIEW.md`, `Local_Run/_workflow.md` — обновлены пути запуска

### Removed
- Директория `_bin/` — скрипты перемещены в `_agents/`

---

## [1.0.0] — 2026-05-10

### Added
- Initial commit — Claude SDLC Agents system
- 26 специализированных агентов: s0-secrets, s0-github, s0-validate, s0-tracker, s1-pm, s1-pmo, s1-finance, s2-ba, s2-po, s2-qa-req, s3-arch, s3-security, s3-dba, s4-dev, s4-techlead, s4-devops, s5-qa, s5-qa-auto, s5-perf, s6-release, s6-sre, l1-analyze, l2-setup, l3-build, l4-run
- `sdlc.sh` — интерактивный лаунчер с полным SDLC-циклом
- `_standards/quality.md` — DoD (10 пунктов), DoR (8 пунктов), 7 Quality Gates, NFR-дефолты, Auto-Heal паттерны
- `_standards/company.md` — шаблон стандартов компании (стек, роли, методология)
- `README.md` — документация проекта
- `OVERVIEW.md` — полный обзор системы

### Known Pitfalls (зафиксированы в s4-dev/CLAUDE.md)
- pydantic-settings v2: list/set в .env требует JSON-формат `[1,2,3]`
- asyncpg + SQLAlchemy: обязательно `TIMESTAMP(timezone=True)`
- Alembic: `fileConfig(..., disable_existing_loggers=False)` обязателен
- aiogram: `callback.message.bot` может быть `None` — инжектировать через параметр
- Parse mode: HTML вместо Markdown v1

---

[Unreleased]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.0.0...v1.0.0

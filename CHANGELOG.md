---
date: 2026-05-10
tags: [docs, changelog]
---

# CHANGELOG — Claude SDLC Agents

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

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

[Unreleased]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.0.0...v1.0.0

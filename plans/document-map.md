---
date: 2026-07-21
tags: [plans, documentation, governance]
---

# Карта документов — SDLC Agent System

Этот файл связывает документы проекта и определяет, где хранится каждый тип информации.
Он не заменяет документы-источники и не смешивает документацию с исполняемой реализацией.

## Канонические документы

| Вопрос | Источник истины | Назначение |
|--------|-----------------|------------|
| Зачем и на каких принципах строится система? | `plans/principles.md` | Стабильные архитектурные, платформенные, инженерные и quality-принципы |
| Что уже сделано и что запланировано? | `plans/roadmap.md` | Текущий статус, активный backlog развития и долгосрочные планы |
| Как документы связаны и что обновлять вместе? | `plans/document-map.md` | Владение документами, приоритет источников и матрица синхронизации |
| Как устроен глобальный SDLC-контекст? | `CLAUDE.md` | Этапы, роли, пути и обязательные глобальные правила |
| Какие правила не зависят от AI runtime? | `_contract/GLOBAL.md`, `_contract/README.md` | Universal Runtime Contract и runtime-инварианты |
| Какие gates, DoR/DoD и технические стандарты обязательны? | `_standards/*.md` | Quality, Security, форматы данных и шаблоны обязательных реестров |
| За что отвечает конкретный агент? | `cycle*/{agent}/CLAUDE.md`, `_tools/{agent}/CLAUDE.md` | Ролевой контракт агента |
| Как выполняется конкретная команда агента? | `{agent}/.claude/commands/*.md` | Общие command templates для всех runtime |
| Как пользоваться системой? | `README.md`, `GETTING_STARTED.md` | Операционное руководство и первый запуск |
| Как система устроена подробно? | `OVERVIEW.md` | Текущая архитектура и полный обзор workflow |
| Что вошло в подготовленный релиз? | `CHANGELOG.md`, `RELEASE_NOTES_v*.md` | Релизная история; обновляется только при подготовке нового релиза |

## Связь документации с реализацией

`sdlc.sh`, `localrun.sh`, `_runtimes/agent-run.sh` и `_runtimes/subagent-run.sh` — исполняемые
скрипты, а не документация.
Они реализуют описанный workflow. Текущие руководства обязаны совпадать с фактическим поведением
скриптов, но логика и её описание остаются разными слоями.

| Реализация | Связанная документация |
|------------|------------------------|
| Порядок шагов `sdlc.sh` | `CLAUDE.md`, `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, текущий статус `plans/roadmap.md` |
| «Локальные репозитории» в `localrun.sh` | `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, `plans/principles.md` |
| Runtime dispatcher, local profiles и routing | `_contract/*`, `_runtimes/adapters/local.md`, `CLAUDE.md`, `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, `plans/principles.md` |
| Project-scoped AI routing | `sdlc.sh`, `{PROJECT}/tracking/ai-routing.conf`, `{PROJECT}/tracking/runtime-routing`, текущие руководства |
| Per-project Execution Journal | `_contract/EXECUTION_JOURNAL.md`, `sdlc.sh`, `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md` |
| TDD orchestration | `_standards/tdd.md`, `_standards/quality.md`, `s2-test-strategy`, `s4-qa-auto`, `s4-dev`, текущие руководства |
| Subagent execution contract | `_contract/SUBAGENTS.md`, `_contract/GLOBAL.md`, runtime dispatcher и текущие руководства |
| Monitoring / playbook executor / dedup | `_standards/quality.md`, `_standards/security.md`, kickoff → PMO/BA/ARCH → DevOps/SRE contracts |
| Per-project goal profile Cycle 2/3 | `tracking/SDLC-goals.md` + `tracking/SDLC-goals-history.md` (данные проекта), root/role `CLAUDE.md`, `_standards/tdd.md`, `sdlc.sh`, текущие руководства |
| Реализованный UX launcher-а | `README.md`, `GETTING_STARTED.md`, `OVERVIEW.md`; implementation status — `plans/roadmap.md` |

## Неприкосновенность principles.md

`plans/principles.md` — отдельный канонический документ. Его нельзя удалять, заменять roadmap-ом
или переносить в runtime-specific адаптер. Roadmap отвечает на вопрос «что делаем», а principles —
«какими правилами руководствуемся». История задач не должна засорять `principles.md`.

## Приоритет документов при расхождении

1. Обязательные gates и инженерные правила — `_standards/*.md`, root/agent `CLAUDE.md` и command templates.
2. Стабильные цели и принципы — `plans/principles.md`.
3. Статус и будущая работа — `plans/roadmap.md`.
4. Текущие объяснения для пользователя — `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`.
5. Факты подготовленных релизов — `CHANGELOG.md` и `RELEASE_NOTES_v*.md`.

Если текущие руководства расходятся с реализацией, нужно проверить намерение по roadmap и контрактам,
затем синхронизировать текущую документацию. Исторические release notes не переписываются.

## Матрица синхронизации документации

| Изменение | Обновить обязательно |
|-----------|----------------------|
| Добавлен, удалён или переставлен шаг workflow | `CLAUDE.md`, `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, текущий статус в `plans/roadmap.md` |
| Добавлен или изменён принцип | `plans/principles.md`, релевантные `CLAUDE.md`/`_standards/*.md`, ссылки в пользовательской документации |
| Добавлен или закрыт план | `plans/roadmap.md` |
| Изменён UX launcher-а | Сначала behavioral tests и `plans/roadmap.md`, после реализации — `README.md`, `GETTING_STARTED.md`, `OVERVIEW.md`, root `CLAUDE.md` |
| Добавлен Quality/Security Gate | Сначала `_standards/*.md`, затем владельцы-gate в agent `CLAUDE.md`, command templates и текущая пользовательская документация |
| Изменён runtime-контракт | `_contract/*`, root `CLAUDE.md`, runtime adapters, `README.md`, `GETTING_STARTED.md`, `OVERVIEW.md` |
| Изменён TDD-цикл | Сначала `_standards/tdd.md`, затем owners/commands/orchestrator, gates, roadmap и все workflow diagrams |
| Изменены local profiles/routing/subagents | `_contract/*`, dispatcher/launchers, runtime adapters, principles и текущая пользовательская документация |
| Изменён operational-контракт | kickoff fields, PMO/BA/ARCH propagation, quality/security standards, DevOps/SRE и текущие руководства |
| Добавлен новый класс документа | `plans/document-map.md` и навигационные разделы основной документации |
| Готовится новый релиз | `CHANGELOG.md` и новый/соответствующий `RELEASE_NOTES_v*.md` обновляются в рамках release preparation |

## Текущий контрольный снимок

На 2026-07-21:

- реализация Цикла 1 содержит 28 обязательных шагов плюс отдельно выбираемые необязательные шаги;
- в репозитории 32 каталога агентов: 27 в `cycle1-dev/` (23 SDLC + 4 Local Run), 2 в
  `cycle2-deploy/`, 1 в `cycle3-ops/` и 2 общих инструмента в `_tools/`;
- local profiles требуют точные host/provider/model, hybrid routing имеет режимы
  `single|per-stage|per-agent|ask`, silent fallback запрещён;
- TDD, optional read-only subagents, stack-aware monitoring, executor authorization и alert
  deduplication закреплены в канонических standards/contracts и agent flow;
- все три Cycle имеют активную test-first orchestration; Cycle 2 пишет Stage 6 evidence,
  Cycle 3 — только Stage 7 evidence; дальнейшее расширение ролей остаётся в roadmap;
- Review/Repair поддерживают отдельные Project/Cycle/Stage/Agent scopes; Review запускается
  capability-enforced read-only, Repair — write только после Preview;
- Worker capability matrix: Claude/Codex/Local codex-oss; Gemini/custom Local — primary-only;
- `plans/roadmap.md` — единственное место активного продуктового backlog;
- launcher реализует один Project Console с подробным/кратким видом, Preview,
  project-local Journal и отдельным разделом «Локальные репозитории»;
- временные design/research packs после реализации архивируются вне продуктового
  репозитория, помечаются `ARCHIVED / NON-AUTHORITATIVE` и не являются source of truth;
- `plans/principles.md` сохраняется как отдельный стабильный источник принципов.
- follow-up audit проверил 170 regular files, 64 canonical adapter symlinks и все 76
  command templates; current contracts используют applicability/N/A evidence без
  silent stack, threshold или live-environment defaults.

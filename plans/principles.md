---
date: 2026-07-21
tags: [plans, principles]
---

# Принципы проекта — SDLC Agent System

> Этот файл — канонический и сохраняется отдельно от roadmap. Он описывает устойчивые принципы,
> а не статус задач. Связи и правила синхронизации документов: [[document-map]].

## Архитектурные принципы

**3 цикла — Dev / Deploy / Ops**
Разработка, деплой и эксплуатация — отдельные циклы в разных средах. Агенты Цикла 1 работают только локально и производят код. Реальная среда — только Циклы 2 и 3.
→ Подробнее: [[roadmap#Концепция: 3 цикла]]

**Изоляция агентов**
Основные агенты не разделяют контекст и историю диалога. Единственный способ передачи данных
между этапами — файлы в `projects/`. Опциональные subagents получают bounded read-only задачу,
не пишут проектные артефакты и не подписывают gates; ответственность остаётся у основного агента.
→ Подробнее: [[OVERVIEW#Архитектура системы]]

**Единая точка входа**
`sdlc.sh` — интерактивный лаунчер для всего SDLC-цикла. `localrun.sh` — лаунчер для Local Run.
Runtime выбирается явно через `AGENT_RUNTIME=claude|codex|gemini|local`, сохранённый config или
меню; агентские запуски идут через universal dispatcher выбранного runtime.
→ Подробнее: [[README#Архитектура]]

**Universal Runtime Contract**
SDLC-логика отделена от конкретного AI runtime. Claude, Codex, Gemini и зарегистрированные
локальные agent hosts запускают один и тот же контракт: `_standards/*.md`, `CLAUDE.md`,
агентские `CLAUDE.md`, `.claude/commands/*.md` и файловые артефакты `projects/`.
Runtime-specific файлы (`AGENTS.md`, `GEMINI.md`, `.codex/`) являются адаптерами и не могут
быть единственным местом новых правил.
→ Подробнее: [[README#Universal Runtime Contract]]

**Точная локальная модель и гибридный routing**
Локальный профиль обязан явно задавать зарегистрированный agent host, provider и точный model id.
Ollama и LM Studio доступны через built-in `codex-oss`; vLLM, llama.cpp и OpenAI-compatible
endpoints — через зарегистрированные executable host-adapters. Политика routing имеет ровно
`single|per-stage|per-agent|ask`. Отсутствующий профиль завершает шаг ошибкой: default model,
silent model/provider/runtime fallback запрещены.

**Supervisor + Worker Subagents**
Основной runtime шага может явно использовать отдельный cross-runtime worker profile — например,
Codex как supervisor и точную Local-модель как bounded read-only worker. Supervisor остаётся
единственным writer и gate signer, формирует ограниченный task packet, проверяет каждый вывод
по каноническим файлам и несёт ответственность за результат. Worker не пишет файлы, не запускает
операционные действия и не делегирует дальше. Worker profile, task policy и concurrency задаются
явно; worker failure не разрешает silent fallback.

## Принципы платформы

**Markdown-first governance**
Решения, handoff-контракты, отчёты, gates и человекочитаемые входные данные ведутся в Markdown
с YAML frontmatter, чтобы оставаться обозримыми в Obsidian. Исполняемый код, тесты, API schemas,
SQL/migrations, IaC, pipeline и monitoring-конфигурация сохраняют нативный формат и связываются
с Markdown-артефактом через requirement/evidence IDs. Markdown-first не означает
«только `.md`» и не разрешает прятать исполняемую спецификацию в prose.
→ Подробнее: [[README#Markdown-first и Obsidian]]

**Единый профиль цели**
Cycle 2/3 получают scope только из per-project `tracking/SDLC-goals.md`.
Профиль настраивается при входе в Cycle 1 и может позднее частично меняться без
повторного полного цикла. Каждое изменение увеличивает revision и сохраняется в
`tracking/SDLC-goals-history.md`; затронутый TDD status инвалидируется.
Инфраструктура, deliverables, executor и authorization всегда выбираются явно;
silent default/fallback и хранение secrets запрещены.
Пользовательский интерфейс показывает смысловые варианты маршрута и
нумерованные deliverables; внутренние id/CSV не являются пользовательским API.

**Интеграция с Obsidian**
Вся система — Obsidian vault. Папка `Claude/` открывается в Obsidian: артефакты всех проектов видны в едином интерфейсе, Graph View показывает связи, теги позволяют фильтровать по агентам и статусам.
→ Подробнее: [[README#Интеграция с Obsidian]]

**Быстрый старт с нуля**
Установка = `git clone` + открыть в Obsidian + `bash sdlc.sh`. Нужен cloud CLI либо
зарегистрированный local agent host выбранного runtime.
→ Подробнее: [[GETTING_STARTED#Установка]]

**Local Run — оснастка разработчика**
`l1-l4` агенты — инструмент для локального запуска существующих GitHub-проектов (analyze → setup → build → run). Не этап SDLC-цикла, а отдельный трек для работы с чужим кодом.
→ Подробнее: [[README#Local Run (l-агенты)]]

**Управление секретами через pass**
Все секреты хранятся только в `pass`. Запрещено: в коде, `.md` файлах, `.env` без pass как источника, передача между агентами текстом.
→ Подробнее: [[_standards/quality.md]]

## Принципы разработки

**SDD — Specification-Driven Development**
Спецификация первична на каждом этапе:
- S2: BRD и NFR как формальный контракт требований
- S3: API spec (`api-spec.yaml`) пишется до реализации и является контрактом для всех downstream агентов
- S4: формальные спецификации и контракты определяют TDD-тесты, которые определяют код

**TDD — Test-Driven Development**
Для каждой применимой работы действует один цикл:
Specify → Red → Green → Run → Repair → Refactor. Тесты и доказательство Red создаются до
production-кода. `s4-qa-auto` пишет unit/integration/contract tests и независимо подписывает
результат Run; `s4-dev` реализует Green и Repair. FAIL возвращает код на исправление и повторный
Run, исчерпание лимита = BLOCKED. Cycle 2 и Cycle 3 имеют собственные
Red/Green/Run/Repair контуры до release/Gate. Правило распространяется на код,
миграции, IaC/pipeline, monitoring rules и auto-heal/playbooks; для документов
применяется validation-first.

**Shift Left**
Безопасность и тестирование начинаются как можно раньше — на этапе требований (S2), не дизайна или разработки.

**Методология выбора паттернов**
7 формализованных правил выбора архитектурных паттернов: QA → Tactic → Pattern → ADR с трейдоффом. Паттерны надёжности (Auto-Heal) определяются топологией деплоя.
→ Подробнее: [[_standards/quality.md#Обязательные паттерны надёжности]]

## Принципы качества

**Quality Gates — только вверх**
Глобальные пороги в `_standards/quality.md` — минимум. Проектные настройки могут только повышать пороги, не снижать.
→ Подробнее: [[_standards/quality.md#Quality Gates]]

**DoR / DoD — без молчаливых исключений**
Definition of Ready обязателен перед стартом каждого этапа. Definition of Done обязателен для
каждой применимой задачи. Неприменимость должна быть явно обоснована контрактом; технический долг
не превращает проваленный применимый пункт в PASS. Нарушение = BLOCKER.
→ Подробнее: [[_standards/quality.md]]

**Трассируемость**
Каждый артефакт связан с требованием: spec → тест → код → верификация.

**Monitoring следует фактическому стеку**
Monitoring проектируется по слоям фактического или выбранного пользователем стека: metrics,
logs, traces, dashboards, alerting и incident management. Нельзя молча подставлять
Prometheus/Grafana/Kubernetes или другой стек по умолчанию.

**Дедупликация алертов и контролируемый auto-heal**
Alert fingerprint стабилен и строится из environment, service, alert name, нормализованного
resource и root cause/SLO; timestamp и текущее значение метрики в ключ не входят. Grouping,
inhibition, flap control, repeat/resolve policy и expiring silences проверяются stack-specific
fire drill. Kickoff явно фиксирует playbook executor, operations owner, identity/host и границы
auto-heal authorization; неизвестный исполнитель или неразрешённое действие = BLOCKED.

## Принцип документационного управления

**Разделение principles / roadmap / release history**
`plans/principles.md` хранит устойчивые правила и не заменяется roadmap-ом. `plans/roadmap.md`
хранит активные и долгосрочные планы. `CHANGELOG.md` и release notes обновляются при подготовке
релиза и хранят релизную историю. Связи документов поддерживаются по матрице из [[document-map]].

# SDLC Agent System

Интерактивная multi-runtime система для разработки, подготовки доставки и эксплуатации
проектов. Один launcher выбирает Project, точный AI profile, scope и workflow; правила
агентов, gates и artifacts не зависят от Claude, Codex, Gemini или локальной модели.
Текущий каталог содержит 32 специализированных AI-агента; Cycle 1 исполняет 28 обязательных шагов.

## Быстрый запуск

Из каталога `_agents`:

```bash
bash sdlc.sh
```

Первый запуск ничего не разрабатывает и не меняет в Project. Он последовательно спрашивает:

1. подробный или краткий вид;
2. каталог SDLC Projects или один Project;
3. primary runtime/profile;
4. как распределять primary AI по шагам;
5. нужны ли read-only AI-помощники.

После настройки появляется выбор Project, затем единый Project Console. Явный runtime можно
передать заранее:

```bash
AGENT_RUNTIME=claude bash sdlc.sh
AGENT_RUNTIME=codex bash sdlc.sh
AGENT_RUNTIME=gemini bash sdlc.sh
```

Локальная модель требует точный host, provider и model id:

```bash
AGENT_RUNTIME=local \
LOCAL_AGENT_HOST=codex-oss \
LOCAL_MODEL_PROVIDER=ollama \
LOCAL_MODEL=qwen2.5-coder:14b \
bash sdlc.sh
```

Встроенный `codex-oss` поддерживает Ollama и LM Studio. Другой inference server подключается
зарегистрированным executable agent-host adapter. Endpoint без agent host недостаточен.
Default model и silent fallback отсутствуют.

## Что находится в Project Console

Подробный и краткий виды содержат одинаковые действия:

| Клавиша | Действие | Что происходит |
|---|---|---|
| `0` | Незавершённый запуск | Показать evidence и безопасную точку child retry |
| `1` | Kickoff | Создать/обновить входные данные; Cycle не стартует автоматически |
| `2` | Обзор | Только чтение текущего состояния |
| `3` | Review | Read-only review Project, Cycle, Stage или Agent |
| `4` | Repair | Исправить подтверждённый scope после Preview |
| `5` | Режим цели | Cycle 1 и явно выбранное продолжение Cycle 2/3 |
| `6` | Один Cycle | Запустить только Cycle 1, 2 или 3 |
| `7` | Один Agent | Запустить одну роль и одну команду |
| `8` | Goal/Cycle 2/Cycle 3 | Частично изменить route/deliverables после разработки |
| `9` | AI routing/workers | Настроить primary profiles и помощников |
| `u` | Утилиты | Secrets, tracker, quality gates, GitHub, validation |
| `l` | Локальные репозитории | Clone/pull, analyze, setup, build, local smoke |
| `g` | Launcher settings | Каталоги, UI, runtime, routing, workers |
| `v` | Вид | Переключить compact/detailed без смены функций |

Выбор Project или пункта меню сам по себе ничего не запускает. Перед Cycle, Repair и utility
launcher показывает `TYPE`, `PROJECT`, absolute `PATH`, `SCOPE`, `EXCLUDED`, ordered steps,
точные AI profiles и `Fallback OFF`.

### Review и Repair

Review — реальное capability-enforced read-only действие через `s0-validate /review`.
Project, `cycle:1..3`, `stage:0..7` и `agent:<id>` формируют разные scopes. Review не пишет
report в Project. Проверка AI routes и обзор нескольких Projects остаются отдельными
read-only действиями.

Repair использует те же Project/Cycle/Stage/Agent scopes и дополнительный `structure`.
Он сначала показывает Preview; агент затем показывает files-to-change и не придумывает
business/architecture решения при недостатке evidence.

## Три цикла

| Cycle | Результат | Test-first invariant | Основные роли |
|---|---|---|---|
| 1 — Development | требования, design, code, tests, Go/No-Go | QA tests RED до Developer Green; независимый PASS | S0–S5 agents |
| 2 — Deploy | Stage 6 delivery/release evidence | deploy tests RED до pipeline/IaC/config; `DEPLOY-TDD-status: PASS` | `s4-devops`, `s6-release` |
| 3 — Operations | Stage 7 operations evidence | ops tests/drills RED до config; `OPS-TDD-status: PASS` | `s6-sre` |

Goal хранится project-locally в `tracking/SDLC-goals.md`. Доступны маршруты:

- только Cycle 1;
- Cycle 1 → Cycle 2;
- Cycle 1 → Cycle 2 → Cycle 3;
- своя разрешённая комбинация.

Cycle 2/3 создают только выбранные deliverables. Infrastructure, monitoring stack, executor,
owner, authorization, environment и thresholds спрашиваются у пользователя. Docker,
Kubernetes, PostgreSQL, Prometheus, Grafana, конкретный SLO или live action не подставляются.

## AI profiles: primary и worker

Primary — модель, которая выполняет шаг, пишет его artifacts и отвечает за contribution/gate.
Routing определяет, где используется primary:

| Policy | Значение |
|---|---|
| `single` | Один exact profile для всех шагов |
| `per-stage` | Свой profile для Cycle/Stage groups |
| `per-agent` | Базовый profile плюс exact overrides ролей |
| `ask` | Все назначения собираются перед Preview |

Supervisor + Worker не меняет порядок SDLC. Primary остаётся единственным writer/gate signer,
а worker получает bounded read-only question. Поддержанная worker matrix:

| Profile | Primary | Capability-enforced worker |
|---|:---:|:---:|
| Claude CLI | да | да — `Read,Glob,Grep`, no session persistence |
| Codex CLI | да | да — read-only sandbox, ephemeral |
| Gemini CLI | да | нет, пока нет enforceable adapter |
| Local `codex-oss` | да | да — read-only sandbox, ephemeral |
| Custom local host | да | нет, пока capability не зарегистрирована |

Worker scope должен находиться внутри настроенного project root. `/`, HOME и внешние paths
отклоняются. Worker не получает произвольные secret environment variables и не запускает
вложенных subagents.

## Markdown-first и native artifacts

Markdown-first относится к governance: решения, handoff, gates, reviews и человекочитаемые
evidence ведутся в Markdown/Obsidian. Это не «Markdown-only»: исполняемые и schema-артефакты сохраняют нативный формат — code, tests, OpenAPI, SQL/DBML, YAML/IaC, scanner configs и logs.
Их связь с требованиями и verdict фиксируется IDs/links в Markdown evidence.

## Execution Journal

Каждый Cycle-run хранит состояние только в выбранном Project:

```text
tracking/execution-journal/runs/<run-id>/
├── plan.md        # immutable frozen routes/scope
├── state.md       # atomic state
├── events.jsonl   # append-only evidence
└── lease          # PID + process-start coordination
```

Vendor conversation resume не используется. INTERRUPTED/UNKNOWN не считается success.
Retry создаёт child run с исходными frozen profiles после последнего структурно подтверждённого
success/optional-skip event.

## Локальные репозитории

Это developer tooling для уже существующего code repository, не четвёртый SDLC Cycle.
Раздел имеет собственные Project directory и AI/routing settings:

1. Analyze — прочитать repository, записать `overview.md`.
2. Install & configure — подготовить зависимости/env/services безопасно.
3. Build — собрать с tests, не использовать skip-tests.
4. Start & smoke — запустить локально и записать `run.md`.

Полный pipeline печатает success только после всех четырёх шагов. Skip обязательного шага
завершает его как неполный. Git push в этом разделе запрещён; pull выполняется отдельно после
Preview и только при чистом working tree. Обновление одной или всех технических заметок также
показывает exact Preview; skip/failure останавливает последовательность и возвращает incomplete.

## Quality и безопасность

- `_standards/tdd.md` — Specify → Red → Green → Run → Repair → Refactor.
- `_standards/quality.md` — DoR/DoD, Gate 1–7, global minimum thresholds.
- `_standards/security.md` — SG1–SG5 и CVSS.
- `_standards/data-formats.md` — применимые native formats и executable validation.

Project thresholds могут только ужесточать global minimum. Неприменимый пункт имеет явную
причину/evidence; tech debt не превращает проваленный применимый пункт в PASS.

## Структура repository

```text
_agents/
├── cycle1-dev/        # S0–S5 + internal l1–l4
├── cycle2-deploy/     # s4-devops, s6-release
├── cycle3-ops/        # s6-sre
├── _tools/            # GitHub, secrets
├── _standards/        # mandatory engineering standards
├── _contract/         # runtime-neutral invariants
├── _runtimes/         # dispatchers/adapters
├── plans/             # principles, roadmap, document map
├── sdlc.sh
└── localrun.sh
```

## Документация

- [Первый запуск](GETTING_STARTED.md)
- [Архитектура и workflow](OVERVIEW.md)
- [Принципы](plans/principles.md)
- [Roadmap](plans/roadmap.md)
- [Карта документов](plans/document-map.md)
- [Runtime contract](_contract/README.md)
- [История релизов](CHANGELOG.md)

Активные планы находятся только в roadmap. CHANGELOG и новый release notes обновляются только
при подготовке релиза; старые release notes не переписываются.

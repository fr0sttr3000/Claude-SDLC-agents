# CLAUDE.md — SDLC Vault (Глобальный контекст)

## Назначение vault
Автоматизированная SDLC-система с универсальным runtime-слоем. Runtime выбирается явно при первом запуске, через `AGENT_RUNTIME` или меню; неявного fallback нет. Поддерживаются Claude, Codex, Gemini и локальные модели через точный профиль зарегистрированного agent host.
Каждый агент — отдельная папка в `_agents/` со своим `CLAUDE.md` и slash-командами.
Агенты изолированы; данные передаются только через файлы в каталоге `SDLC_PROJECTS_DIR`.
Governance/handoff ведутся Markdown-first, но executable tests/code, API schemas, SQL/IaC и
другие native artifacts сохраняют свой формат и трассируются к Markdown evidence.

## Структура vault
```
_agents/
  _standards/       ← Стандарты компании (читать перед каждой задачей)
  _contract/        ← Universal Runtime Contract: инварианты и источники истины
  _runtimes/        ← agent-run.sh + cloud/local adapters и registry локальных agent hosts
  AGENTS.md         ← Codex adapter к каноническим CLAUDE.md
  GEMINI.md         ← Gemini adapter к каноническим CLAUDE.md
  .codex/           ← Codex project config
  _tools/           ← Утилиты для всех циклов (s0-github, s0-secrets)
  cycle1-dev/       ← 27 каталогов: 23 SDLC-агента + 4 Local Run (l1-l4)
  cycle2-deploy/    ← Цикл 2: Деплой (s4-devops, s6-release)
  cycle3-ops/       ← Цикл 3: Эксплуатация (s6-sre)
  plans/            ← Принципы, roadmap и карта связей документации
  sdlc.sh           ← Главный лаунчер (циклы 1 → 2 → 3)
  localrun.sh       ← Раздел «Локальные репозитории»
_secrets/           ← Документация по управлению секретами (pass)
$SDLC_PROJECTS_DIR/ ← Артефакты проектов (inputs/outputs по этапам + tracking/), настраивается launcher-ом
Local_Run/          ← Заметки по локальным проектам с GitHub
OVERVIEW.md         ← Полный обзор системы
```

## Навигация по документации проекта

- `plans/principles.md` — отдельный канонический источник устойчивых принципов проекта;
- `plans/roadmap.md` — единственный источник активных и долгосрочных планов развития;
- `plans/document-map.md` — связь документов, их назначение и правила синхронизации;
- `CHANGELOG.md` и `RELEASE_NOTES_v*.md` — релизная история, обновляемая при подготовке релиза.

Исполняемые `sdlc.sh`, `localrun.sh` и `_runtimes/agent-run.sh` являются реализацией, а не
документацией. Текущие руководства должны описывать их фактическое поведение без смешивания слоёв.

## Структура проекта в `$SDLC_PROJECTS_DIR`
```
$SDLC_PROJECTS_DIR/{PROJECT}/
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

## Universal Runtime Contract

Правила SDLC не зависят от AI runtime. Канонические источники:
- root `CLAUDE.md` — глобальный контекст;
- `cycle*/{agent}/CLAUDE.md` — роль агента;
- `.claude/commands/*.md` — общие command templates;
- `_standards/*.md` — обязательные стандарты;
- `_contract/GLOBAL.md` — инварианты совместимости.

Runtime adapters (`AGENTS.md`, `GEMINI.md`, `.codex/config.toml`, `_runtimes/adapters/*`) не должны содержать уникальные gates, правила или команды. Новое поведение сначала фиксируется в каноне, затем запускается через любой runtime.

```bash
bash "$SDLC_VAULT/_agents/sdlc.sh"                         # первый запуск спросит runtime
AGENT_RUNTIME=claude bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=codex bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=gemini bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=local LOCAL_AGENT_HOST=codex-oss \
  LOCAL_MODEL_PROVIDER=ollama LOCAL_MODEL=llama3.2:latest \
  bash "$SDLC_VAULT/_agents/sdlc.sh"
```

Локальный профиль всегда содержит точные `LOCAL_AGENT_HOST`, `LOCAL_MODEL_PROVIDER` и
`LOCAL_MODEL`. Встроенный host `codex-oss` поддерживает Ollama/LM Studio; vLLM, llama.cpp и
OpenAI-compatible endpoints подключаются зарегистрированными исполняемыми agent-host adapters.
Политика `SDLC_RUNTIME_ROUTING=single|per-stage|per-agent|ask` разрешает единый или гибридный
маршрут. Отсутствующая привязка — ошибка: default model и silent fallback запрещены.

Для каждого шага `SDLC_SUBAGENTS=off|auto|cross-runtime` явно выключает или разрешает bounded read-only
subagents; `SDLC_SUBAGENT_MAX` задаёт лимит. Основной агент остаётся единственным writer и
подписантом gate согласно `_contract/SUBAGENTS.md`.

Режим `SDLC_SUBAGENTS=cross-runtime` включает vendor-neutral схему **Supervisor + Worker**:
основной профиль шага является supervisor и единственным writer/gate signer, а отдельный
`SDLC_SUBAGENT_PROFILE` задаёт точный runtime/model для bounded read-only workers.
`SDLC_SUBAGENT_TASKS` явно ограничивает допустимые типы задач. Supervisor обязан проверить
каждый результат по каноническим файлам; worker failure блокирует или повторяет делегирование,
но не включает silent fallback и не передаёт worker-у право записи.
Capability-enforced workers: Claude, Codex и Local `codex-oss`. Gemini и произвольный
local host остаются допустимыми primary profiles, но не выбираются workers до появления
enforceable read-only adapter.

## Как работать с агентами
```bash
# Через лаунчер (рекомендуется): runtime выбирается в меню или env-переменной.
bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=codex bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=gemini bash "$SDLC_VAULT/_agents/sdlc.sh"

# Напрямую через universal dispatcher.
AGENT_RUNTIME=codex "$SDLC_VAULT/_agents/_runtimes/agent-run.sh" \
  --agent-dir "$SDLC_VAULT/_agents/cycle1-dev/s1-pm" \
  --mode task \
  --prompt "Создай Feasibility Study для проекта my-project"
```

## Агенты — инфраструктура (этап 0)
| Агент | Роль | Ключевые команды |
|-------|------|-----------------|
| `s0-kickoff` | Project Kickoff — онбординг / обновление беклога | `/start`, `/new`, `/refresh` |
| `s0-secrets` | Secrets Manager | `/add`, `/rotate`, `/env` |
| `s0-github` | GitHub Sync | `/init`, `/sync`, `/push`, `/status`, `/branch`, `/pr` |
| `s0-validate` | Validator / scoped Review & Repair | `/validate`, `/fix`, `/dor-check`, `/dod-check`, `/review`, `/repair` |
| `s0-tracker` | Sprint & Task Tracker | `/sprint-init`, `/sprint-close`, `/sprint-status`, `/report`, `/task-add`, `/task-done`, `/task-block`, `/backlog` |
| `s0-quality-gates` | Quality Gates Configurator — проектные пороги из risk-профиля (после S1, до S2) | `/configure`, `/validate-gates` |

## Цикл 1 — Разработка (28 обязательных шагов)
Запуск: Project Console → `6 Один Cycle` → `Cycle 1`. Деплой (Cycle 2) и эксплуатация
(Cycle 3) — отдельные активные test-first циклы в выбранной среде.

| Этап | Агент | Ключевые команды |
|------|-------|-----------------|
| 1 — Планирование | `s1-pm` | `/feasibility`, `/vision` |
| 1 — Планирование | `s1-pmo` | `/charter`, `/risks` |
| 1 — Планирование | `s1-finance` | Business Case |
| 2 — Требования | `s2-ba` | `/extract-requirements`, `/brd` |
| 2 — Требования | `s2-po` | `/stories` |
| 2 — Требования | `s2-qa-req` | Testability Review |
| 2 — Требования | `s2-test-strategy` | `/strategy` — проектная test strategy до реализации |
| 2 — Требования | `s2-security` | `/security-requirements` (SG1: abuse cases, классификация данных, ASVS) |
| 3 — Дизайн | `s3-arch` | `/hld`, `/adr` |
| 3 — Дизайн | `s3-security` | Threat Model |
| 3 — Дизайн | `s3-rbac` | `/rbac-model`, `/rbac-matrix` |
| 3 — Дизайн | `s3-dba` | DB Schema |
| 4 — Разработка | `s4-qa-auto` | `/write-tests`, `/run-tests` — Red до кода, независимый verdict после кода |
| 4 — Разработка | `s4-dev` | Green/Repair, Dev Report, Update Notes (обязательно после каждого PR) |
| 4 — Разработка | `s4-techlead` | Code Review (блокирует PR без обновлённой документации) |
| 5 — Тестирование | `s5-qa` | Test Plan, Go/No-Go |
| 5 — Тестирование | `s5-qa-auto` | E2E/API тесты |
| 5 — Тестирование | `s5-perf` | Load Tests |
| Финал | `s0-tracker` | `/report` (план vs факт) |
| Финал | `s0-github` | `/push` (push в ветку) |

## Циклы 2 и 3 — активные test-first workflow

Единый per-project контракт цели хранится в
`$SDLC_PROJECTS_DIR/{PROJECT}/tracking/SDLC-goals.md`. Он настраивается при
входе в Cycle 1 или позднее частично из пункта launcher «Цели Cycle 2/3».
Silent infrastructure defaults запрещены: создаются только выбранные
deliverables. Cycle 2 требует DEPLOY-TDD-status RED→PASS; Cycle 3 —
OPS-TDD-status RED→PASS.

Launcher показывает четыре явных маршрута:
`Только Cycle 1`, `Cycle 1 → 2`, `Cycle 1 → 2 → 3` и свою комбинацию.
Deliverables выбираются из нумерованного списка, а не вводом внутренних id.

## Project Console и Execution Journal

`sdlc.sh` сначала выбирает SDLC Project, затем держит его имя и absolute path
в Project Console. Подробный и краткий виды используют одну карту действий.
Kickoff, Goal, One Cycle, One Agent, Review, Repair, AI и Utilities — разные
user flows. Успешный Kickoff не запускает разработку автоматически.

Перед Cycle/Repair/utility execution обязателен Preview с TYPE/SCOPE/EXCLUDED,
ordered routes, точным Local model и `Fallback OFF`; dispatch разрешён только
после явного подтверждения. Cycle-run хранит frozen plan, atomic state и
append-only evidence в `{PROJECT}/tracking/execution-journal/runs/{run-id}/`
по контракту `_contract/EXECUTION_JOURNAL.md`.

AI policy/base profile/routes хранятся project-locally. Frozen plan фиксирует
effective profile и route source каждого step. INTERRUPTED run сначала открывает
evidence; retry создаёт linked child run из оставшихся шагов и не вызывает
vendor session resume.

`localrun.sh` показывается пользователю как «Локальные репозитории», имеет
собственный AI/routing-профиль и не наследует effective route последнего SDLC Agent.
Full pipeline и batch update технических заметок показывают exact Preview; первый
skip/failure завершает последовательность как incomplete, а не success.

| Цикл | Агент | Назначение |
|------|-------|-----------|
| 2 — Деплой | `s4-devops` | Intake → tests/RED → delivery → tests/PASS |
| 2 — Деплой | `s6-release` | `/release-notes` → `/release-checklist` (Gate 6) |
| 3 — Эксплуатация | `s6-sre` | Intake → ops tests/RED → config → PASS → Post-Deploy/Gate 7 |

## Система качества и надёжности

**Канонические стандарты (читать перед каждой задачей):**
- `$SDLC_VAULT/_agents/_standards/tdd.md` — Specify → Red → Green → Run → Repair → Refactor, test-first применимость и BLOCKED repair loop
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
| S2 → S3 | BRD + NFR с числами + QA-REQ review (0 BLOCKER) + test strategy + **SG1** | **s3-arch** |
| S3 → S4 | HLD + применимые API/Auth/Data artifacts или N/A evidence + test strategy + **SG2** | **s4-dev** |
| S4 → S5 | Все PR + DoD + QA-TDD-status=PASS + branch≥80%+mutation + integration/contract + **SG3** (SAST/SCA) | **s5-qa** |
| S5 → S6 | Go/No-Go + Functional Suitability (Must-FR↔RTM) + UAT + PERF PASS + Known Issues + **SG4** | **s6-release** |
| S6 → PROD | DEPLOY-TDD=PASS + checklist + release notes + rollback проверен | **s6-release** |
| PROD → S7 | OPS-TDD=PASS + Monitoring + Auto-Heal + SLO Review + **SG5** | **s6-sre** |

### Неотменяемые правила (нарушение = BLOCKER)
- Definition of Done (DoD) обязателен для каждой задачи — все 11 пунктов (включая DoD-11: тесты форматов)
- Definition of Ready (DoR) обязателен перед стартом каждого этапа — все 8 пунктов
- Secrets никогда не в коде, логах, .md-файлах
- Critical/High уязвимости (CVSS ≥ 7.0) блокируют релиз (severity по CVSS — security.md §1)
- Некритичный дефект (S3/S4) с user-facing impact в проде — только через known-issues.md (workaround + detection signal + runbook), иначе это «проигнорированный» дефект (quality.md §6.1)
- UAT только в реальной системе, не в эмуляторе
- Rollback-план до деплоя, не после
- Выбранные operational/auto-heal capabilities должны иметь tests/evidence; неприменимость обоснована
- Выбранные SLO/alert capabilities должны иметь точные NFR thresholds и stack-native evidence
- Следующий релиз заблокирован, если Gate 7 предыдущего не закрыт

## Правила именования файлов
```
Входные:   [ROLE]-input-[описание].md              → BA-input-interview.md
Выходные:  [ROLE]-YYYY-MM-DD-[артефакт].md         → BA-2026-05-10-BRD.md
Трекер:    tracking/sprints/sprint-NN.md
Docs:      DEV-YYYY-MM-DD-update-notes-PR[N].md    → stage4-dev/outputs/
           REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md → stage6-deploy/outputs/
           CHANGELOG.md                             → корень проекта
```

## Передача данных между агентами
Агент читает артефакты предыдущего этапа через абсолютный путь.
НЕ ПЕРЕДАВАЙ историю диалога. Только финальные файлы из outputs/.

```bash
# Пример: s2-ba читает результат s1-pm
AGENT_RUNTIME=codex "$SDLC_VAULT/_agents/_runtimes/agent-run.sh" --agent-dir "$SDLC_VAULT/_agents/cycle1-dev/s2-ba" --mode task --prompt "Прочитай $SDLC_PROJECTS_DIR/my-project/stage1-planning/outputs/PM-2026-05-10-feasibility.md и создай BRD"
```

## Пути проекта (env-переменные, КРИТИЧНО)

Абсолютные пути НЕ захардкожены — они приходят из окружения (лаунчер их экспортирует). Используй переменные, а не литералы вроде `/home/<user>/...`:

| Переменная | Что содержит | Пример пути |
|-----------|--------------|-------------|
| `AGENT_DIR` | папка текущего агента | `$AGENT_DIR/.claude/commands/` |
| `SDLC_VAULT` | корень установки/vault со стандартами и `_agents` | `$SDLC_VAULT/_agents/_standards/quality.md` |
| `SDLC_PROJECTS_DIR` | каталог-родитель SDLC-проектов | `$SDLC_PROJECTS_DIR/{PROJECT}/...` |
| `SDLC_PROJECTS_MODE` | режим выбора проектов: `collection` или `single` | `single` |
| `SDLC_SINGLE_PROJECT` | имя активного проекта в режиме `single` | `FamilyPlannerBot` |
| `LOCALRUN_PROJECTS` | локальные GitHub-проекты (L-агенты) | `$LOCALRUN_PROJECTS/{PROJECT}/` |

В режиме одного проекта launcher показывает путь к конкретному проекту, но `SDLC_PROJECTS_DIR` остаётся родительским каталогом для совместимости с контрактом `$SDLC_PROJECTS_DIR/{PROJECT}`.

Получить значение в bash: `echo "$SDLC_PROJECTS_DIR"`. Стандарты читаются как `$SDLC_VAULT/_agents/_standards/quality.md`.

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
- **Запись файлов — самостоятельно.** Реализацию и правку кода/артефактов делать напрямую через Read/Edit/Write. НЕ делегировать запись сабагентам (Agent) или runtime CLI в отдельном процессе — у них может не быть прав, изменения молча не применятся (exit 0, файл не тронут). Сабагенты — только для read-only задач (поиск, анализ). (INC-03)
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

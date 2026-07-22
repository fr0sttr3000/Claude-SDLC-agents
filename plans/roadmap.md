---
date: 2026-07-21
tags: [plans, roadmap]
---

# Roadmap — SDLC Agent System

> Активные и долгосрочные планы хранятся только здесь. Устойчивые принципы проекта —
> в [[principles]], связи документов и правила синхронизации — в [[document-map]].

## Концепция: 3 цикла

| Цикл | Суть | Среда |
|------|------|-------|
| Цикл 1 — Dev | Разработка: код, тесты, документация | Локальная |
| Цикл 2 — Deploy | Подготовка выбранных delivery artifacts и, при authorization, deploy | Явно выбранная |
| Цикл 3 — Ops | Подготовка/проверка выбранных operational capabilities и evidence | Явно выбранная |

Текущий baseline: Цикл 1 содержит 28 обязательных шагов плюс отдельно выбираемые
необязательные шаги. Циклы 2/3 имеют активную test-first orchestration, revisioned Goal,
частичную перенастройку и отдельные Stage 6/Stage 7 границы. Дальнейшие роли и расширение
покрытия перечислены ниже как backlog, а не как отсутствие работающих циклов.

Cycle 2/3 не предполагают live environment автоматически. Images/config/runbooks могут
готовиться offline; live deploy/ops выполняются только при выбранном deliverable,
точной среде, identity, authorization и rollback. Cycle 1 не выполняет deploy.

### Этапы Цикла 1

| Этап                       | Назначение                                                                                                                                                                                  | Агенты                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| S0 — Discovery & Tracking  | Исследование проблемы и валидация гипотез (до старта S1) + оперативный трекинг спринтов и задач на протяжении всего цикла + контроль структуры артефактов                                   | `s0-kickoff`, `s0-tracker`, `s0-validate` + *(запланирован discovery-агент)* |
| S1 — Планирование          | Оценка реализуемости (4 оси), Product Vision, Project Charter, Risk Register, PMO-constraints, ROI/NPV/TCO, бюджет — стратегические governance-документы, создаются один раз в начале цикла | `s1-pm`, `s1-pmo`, `s1-finance`                                       |
| S2 — Требования            | BRD, User Stories, Testability, Test Strategy                                                                                                                                               | `s2-ba`, `s2-po`, `s2-qa-req`, `s2-test-strategy`                     |
| S3 — Дизайн                | HLD, Security, RBAC, DB Schema                                                                                                                                                              | `s3-arch`, `s3-security`, `s3-rbac`, `s3-dba`                         |
| S4 — Разработка            | TDD Red/Green/Run/Repair, код, Code Review                                                                                                                                                  | `s4-qa-auto`, `s4-dev`, `s4-techlead`                               |
| S5 — Тестирование          | Test Plan, E2E, Load, Go/No-Go                                                                                                                                                              | `s5-qa`, `s5-qa-auto`, `s5-perf`                                      |
| **Финал Цикла 1 — подготовка релиза** | Release Notes и итоговый комплект разработки                                                                                                                                          | *(запланирован `s5-release-prep` — см. план)*                         |

> **Local Run** (`l1-l4`) — оснастка разработчика для локального запуска проектов. Не этап цикла.

---

## Статус работ

### ✅ Выполнено

**Структурная реорганизация директорий**
- Агенты перемещены в `cycle1-dev/`, `cycle2-deploy/`, `cycle3-ops/`, `_tools/`
- `sdlc.sh` и `localrun.sh` обновлены: поиск агентов через `find_agent_dir()`
- `CLAUDE.md`, `OVERVIEW.md`, `GETTING_STARTED.md` обновлены
- Проверена изоляция контекста между агентами


**Universal Runtime Contract (v2.000.003)**
- Добавлен vendor-neutral слой `_contract/` с правилом: канон = `_standards/*.md`, root `CLAUDE.md`, agent `CLAUDE.md`, `.claude/commands/*.md`, `projects/`
- Добавлен runtime dispatcher `_runtimes/agent-run.sh` и cloud adapters для Claude/Codex/Gemini
- `sdlc.sh` и `localrun.sh` запускают агентов через явный `AGENT_RUNTIME`, сохранённый
  config или меню; автоматического выбора runtime нет
- Добавлены `AGENTS.md`, `GEMINI.md`, `.codex/config.toml` как bridge/adapters без дублирования SDLC-логики
- Документация синхронизирована под multi-runtime режим

**Локальные модели, TDD, subagents и operational-контракт**

- [x] Добавлены exact local profiles: built-in `codex-oss` для Ollama/LM Studio и registry
  executable agent hosts для vLLM, llama.cpp и OpenAI-compatible endpoints
- [x] Добавлен hybrid routing `single|per-stage|per-agent|ask`; default model и silent fallback
  между model/provider/runtime запрещены
- [x] Добавлен обязательный TDD standard и orchestration:
  Specify → Red → Green → Run → Repair → Refactor, независимый PASS/FAIL и BLOCKED по лимиту
- [x] Добавлены `s2-test-strategy` и `s4-qa-auto`; Cycle 1 расширен до 28 обязательных шагов
- [x] Добавлен `off|auto|cross-runtime` subagent contract: режим Supervisor + Worker хранит
  exact worker profile/task policy, запускает workers через отдельный read-only dispatcher,
  показывает supervisor/worker в Preview; primary остаётся writer и gate signer
- [x] Kickoff спрашивает Monitoring Stack, Playbook Executor, Operations Owner и
  Auto-Heal Authorization; поля проходят через PMO/BA/Architecture к DevOps/SRE
- [x] Monitoring создаётся под фактический стек; добавлены stable alert fingerprint,
  grouping/inhibition/flap/repeat/resolve/silence rules и stack-specific fire drill

**Quality Gates overhaul (v2.000.002)** — улучшения относительно ISO 25010 / ISTQB / DORA / SRE / ITIL:
- Пирамида тестов (§3.1): branch coverage ≥80% (вместо line) + mutation score ≥60% критичных + уровни integration/contract; пороги растут по tier
- Code duplication ≤3% нового кода (DoD-1, §3)
- Маппинг на ISO/IEC 25010 (§4.1) + Functional Suitability в Gate 5 (Must-FR ↔ RTM)
- Метрики (§7): DORA +Reliability (5-я), сбор/тренд по циклам, defect-метрики (Density, DRE ≥95%, Escaped)
- Known Issues operational contract / KEDB (§6.1): реестр `known-issues.md` + per-KI runbook + targeted-алерт + auto-remediation + Patch SLA; шаблоны `known-issues-template.md`, `runbook-KI-template.md`
- Распространено по агентам s4-dev/s4-techlead/s5-qa/s5-qa-auto/s0-tracker/s0-validate/s6-release/s6-sre + `dod-check.sh`

**Follow-up quality audit (2026-07-21, без release preparation)**

- [x] Проверены 170 regular files и 64 runtime-adapter symlinks, включая 76 command templates.
- [x] Устранены unsafe menu indexes и потеря failing step/agent/task в Execution Journal.
- [x] Gate/agent contracts согласованы для non-API, non-DB, CLI/library, images-only
  и operations-artifacts-only сценариев через явное applicability/N/A evidence.
- [x] Удалены скрытые PostgreSQL/RLS/UUID/performance/ops threshold defaults;
  точные значения берутся из HLD/NFR/goal/project gates.
- [x] Local notes update получил exact Preview и incomplete semantics на первом skip/failure.
- [x] Все tests/*.sh и syntax всех 19 shell/runtime entry points проходят.
- [x] CHANGELOG и release notes не изменялись: новый релиз в рамках аудита не готовился.

---

### 🔄 Запланировано

#### Порядок развития

1. Завершить недостающие роли и связи Цикла 1: discovery, UX/UAT, static QA,
   полный контур S5 и release preparation.
2. Устранить документированные пробелы покрытия ISO/IEC 25010.
3. Укреплять Cycle 2 дополнительными delivery adapters/evidence только по подтверждённым use cases.
4. Укреплять Cycle 3 дополнительными operations capabilities только по подтверждённым use cases.

Порядок внутри крупных блоков уточняется зависимостями конкретных агентов. Работающий baseline
Cycle 2/3 не блокируется будущим расширением Cycle 1.

#### ✅ UX launcher-а — единый Project Console

Редизайн реализован в `sdlc.sh` и `localrun.sh`. Временный UX design package
после синхронизации общей документации вынесен из продуктового репозитория в
неавторитетный архив; фактическое использование описывают README,
GETTING_STARTED и OVERVIEW.

- [x] Один основной `Project Console`, без выбора разных оболочек.
- [x] Подробный и краткий виды с одинаковыми actions, keys и navigation order.
- [x] Первый запуск явно предлагает выбрать вид; `v` переключает его позднее.
- [x] Project selector предшествует project-scoped actions и показывает absolute path.
- [x] Kickoff имеет явный выход в только C1, Goal route, input review или Console.
- [x] Goal route, One Cycle, One Agent, Review, Repair и Utilities разделены.
- [x] Понятный user label `Локальные репозитории`; `Local Run` остаётся internal name.
- [x] Простой explicit AI assignment и advanced matrix сохраняют Claude/Codex/Gemini/Local,
  exact local model и запрет silent fallback.
- [x] Общая Проверка запуска и per-project Execution Journal реализованы.
- [x] CJM, feature parity, acceptance и tests-before-code обновлены.
- [x] Behavioral tests написаны и зафиксированы в Red до production code.
- [x] Новый UI реализован без удаления runtime/model/routing/goal/local-repository функций.
- [x] README/GETTING_STARTED/OVERVIEW синхронизированы; system contract smoke включает
  UI/navigation, Preview, Journal, Local Repositories и advanced parity regression.
- [x] Project-scoped AI routing, frozen step profiles, per-run lease, evidence-first
  child retry и One Agent Preview закрывают финальный feature-parity audit.

CHANGELOG и
release notes не обновляются до release preparation.

#### ✅ Новый агент в Цикле 1: s0-quality-gates (этап S0) — СДЕЛАНО

Сейчас quality gates захардкожены глобально в `_standards/quality.md` и одинаковы для всех проектов. Нет возможности настроить пороги под конкретный проект.

**Решение по размещению (изменено относительно первоначального плана):** агент запускается **после S1, до S2** — а не «после `s0-kickoff` до S1». Причина: главный вход агента — `PMO-constraints.md` (operational tier, critical_risks), который создаёт `s1-pmo` внутри S1. До S1 risk-профиля ещё нет, tier пришлось бы угадывать.

**Правило:** проектные пороги могут только повышаться относительно глобальных. Снижение глобальных порогов запрещено.

- [x] Создать агента `cycle1-dev/s0-quality-gates/` (CLAUDE.md + `/configure` + `/validate-gates`)
- [x] Роль: Quality Gates Configurator — настраивает пороги quality gates для проекта
- [x] Читает: `_standards/quality.md` (глобальные пороги — минимум), `idea.md`, `PMO-constraints.md` (risk profile)
- [x] Артефакт: `tracking/quality-gates.md` — проектные пороги для всех gates
- [x] Правило валидации: каждый порог в `quality-gates.md` ≥ соответствующего (с учётом направления метрики); `/validate-gates` проверяет
- [x] Gate-контролёры (`s2-qa-req`, `s4-techlead`, `s5-qa`, `s5-perf`) читают `quality-gates.md` ПЕРВЫМ делом, fallback на quality.md
- [x] Добавлен шаг `s0-quality-gates:/configure` в `CYCLE1_AGENTS` после `s1-finance:/business-case`, до `s2-ba`

---

#### Рефакторинг Цикла 1

**✅ Сделано (v2.000.000, затем расширено):** launcher приведён к модели 3 циклов.
- [x] `CYCLE_AGENTS` разделён на `CYCLE1_AGENTS`, `CYCLE2_AGENTS`, `CYCLE3_AGENTS`; текущий Цикл 1 расширен до 28 обязательных шагов
- [x] Главное меню: пункт «Запустить цикл» с подменю выбора (Разработка / Деплой / Эксплуатация / Всё сразу)
- [x] Циклы 2/3 отделены от Цикла 1 и реализованы как самостоятельные test-first workflows
- [x] Меню одиночного запуска сгруппировано по циклам + Tools + Local Run
- [x] Обновлены `CLAUDE.md`, `OVERVIEW.md`, `README.md`, `GETTING_STARTED.md`

**Границы baseline закрыты:** `s4-devops` работает в Cycle 2 / Stage 6 и даёт delivery
evidence для Gate 6; `s6-release` владеет release preparation/checklist и Gate 6;
`s6-sre` работает только в Cycle 3 / Stage 7. Перенос release preparation в Cycle 1
остаётся отдельным будущим изменением ниже и не меняет текущий ownership до реализации.

#### Новый агент в Цикле 1: discovery (этап S0)

Discovery упомянут в целевой модели S0, но пока не специфицирован и не реализован.

- [ ] Определить имя и границы роли, не дублирующие интервью `s0-kickoff`
- [ ] Определить входы, выходной артефакт и критерии завершения discovery
- [ ] Зафиксировать место запуска до S1 и связь с feasibility
- [ ] После утверждения добавить agent contract, command template и шаг workflow

#### ✅ Новый агент в Цикле 1: s2-test-strategy (этап S2) — СДЕЛАНО

> ⚠️ **Сверка с реализованным:** уровни/типы тестов и пороги покрытия уже формализованы в
> `quality.md §3.1` (пирамида unit/integration/contract/e2e, branch+mutation). Этот агент НЕ должен
> их дублировать — его зона: риск-матрица, выбор инструментов, привязка типов к конкретным требованиям
> (применение §3.1 к проекту), а не переопределение порогов.

`s2-qa-req` проверяет тестируемость требований, а `s2-test-strategy` определяет применение
глобального test standard к конкретному проекту в S2 (Shift Left).

Агент добавляется после `s2-qa-req`.

- [x] Создать агента `cycle1-dev/s2-test-strategy/`
- [x] Роль: QA Strategist — определяет стратегию тестирования на основе требований
- [x] Читает: BRD, NFR, PO-backlog и применимые acceptance criteria
- [x] Артефакт: `QA-YYYY-MM-DD-test-strategy.md` в `stage2-requirements/outputs/`
- [x] Содержание: уровни тестирования, risk matrix, traceability, инструменты и Red plan
- [x] Downstream QA/SDET/Dev читают test-strategy
- [x] Шаг `s2-test-strategy:/strategy` добавлен после `s2-qa-req:/testability-review`

---

#### ✅ Разделение Quality / Security — СДЕЛАНО

Security был вшит в Quality Gates (threat model в Gate 3, SAST в Gate 4, vulns в NFR). По DevSecOps / NIST SSDF / OWASP SAMM / Microsoft SDL безопасность ведётся отдельным треком: свой язык severity (CVSS, не баги S1–S4), свой каденс (непрерывно + вехи + пост-прод), свой владелец (`s3-security`).

- [x] Создан `_standards/security.md` — параллельный трек **Security Gates SG1–SG5** + CVSS-политика + ASVS-уровни по tier («только вверх») + маппинг на NIST SSDF/OWASP/SDL/SLSA
- [x] Security-специфика вырезана из `quality.md` (threat model, RBAC, SAST/secrets, vulns) → заменена кросс-ссылками на нужный SG; добавлено правило «переход = зелёный Quality Gate И Security Gate»
- [x] `s3-security` назначен владельцем трека (читает `security.md` первым)
- [x] **Privacy/PII — корректный фрейминг:** это per-project дименсия по классификации данных (SG1), а НЕ свойство самого vault `_agents` (markdown-система без пользовательских данных). Проект без чувствительных данных помечает «PII: нет», §6 не применяется.

- [x] Создан агент `s2-security` (владелец SG1): `/security-requirements` — классификация данных, abuse cases (STRIDE на уровне требований), ASVS-уровень по tier, security NFR как контракт для s3-arch/s4-dev. Добавлен в `CYCLE1_AGENTS` после `s2-qa-req`. `s3-security` читает его артефакт как вход для threat model (SG2).

#### ✅ Перенести моделирование угроз из S3 в S2 — РЕШЕНО (через split SG1/SG2)

Изначально стояла дилемма «перенести `s3-security` в S2 или создать `s2-security`». Выбран **split, а не перенос**: безопасность раскладывается на два уровня вместо перемещения одного агента.

- [x] Создан `s2-security` для **раннего (requirements-level) анализа**: abuse cases, классификация данных, ASVS, security NFR (SG1, S2) — shift-left
- [x] В S3 остаётся **design-level**: `s3-security` делает threat modeling с CVSS по HLD-компонентам (SG2), развивая security-требования из SG1
- [x] Цепочка зависимостей обновлена: `s3-security` читает `SEC-*-security-requirements.md` (SG1) как вход; security NFR из S2 идут к `s3-arch`
- [x] `CYCLE1_AGENTS` обновлён: `s2-security:/security-requirements` после `s2-qa-req`

> Почему split лучше переноса: на уровне требований нет архитектуры для полноценного STRIDE по компонентам. SG1 ловит дефекты требований (abuse cases, классификация), SG2 — дефекты дизайна. Это каноничный shift-left (Microsoft SDL: Requirements → Design — два разных этапа security).

---

#### Новый агент в Цикле 1: s2-ux-ui (этап S2)

Сейчас никто не проектирует пользовательский интерфейс. Агент добавляется после `s2-po` и до `s2-qa-req`.

- [ ] Создать агента `cycle1-dev/s2-ux-ui/`
- [ ] Роль: UX/UI дизайнер — user flows, wireframes, визуальный дизайн
- [ ] Читает: `PO-backlog.md` (user stories от `s2-po`)
- [ ] Артефакты: `UX-YYYY-MM-DD-flows.md`, `UX-YYYY-MM-DD-wireframes.md` в `stage2-requirements/outputs/`
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s2-po:/stories`
- [ ] `s3-arch` должен читать wireframes при проектировании HLD

---

#### Новый агент в Цикле 1: s4-qa (этап S4)

Никто в S4 не запускает линтеры и статический анализ. `s4-dev` пишет код, `s4-techlead` делает ручное ревью — но автоматизированные проверки качества кода отсутствуют до S5.

Агент добавляется после `s4-dev` и до `s4-techlead`.

- [ ] Создать агента `cycle1-dev/s4-qa/`
- [ ] Роль: QA Engineer (S4) — статическое тестирование кода в процессе разработки
- [ ] Задачи: запуск линтеров, SAST, анализ покрытия, secrets-scan
- [ ] Читает: код из репозитория проекта
- [ ] Артефакты: `QA-YYYY-MM-DD-static-report.md` в `stage4-dev/outputs/`
- [ ] Содержание: результаты линтеров, SAST-находки по severity, coverage отчёт, blocker-список
- [ ] Critical/High находки SAST блокируют переход в S5
- [ ] `s4-techlead` читает static-report при code review
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s4-dev:/dev-report`

---

#### ✅ Новый агент в Цикле 1: s4-qa-auto — TDD (этап S4) — СДЕЛАНО

Unit/integration/contract tests теперь пишутся до production-кода в S4.
`s5-qa-auto` остаётся владельцем E2E и высокоуровневой автоматизации.

Поток S4 после изменения:
```
s4-qa-auto /write-tests → тесты + доказанный Red
s4-dev /dev-report      → Green/Repair
s4-qa-auto /run-tests   → независимый PASS или FAIL → повторный Repair/Run
s4-techlead /review     → code review после PASS
```

- [x] Создать агента `cycle1-dev/s4-qa-auto/`
- [x] Роль: SDET (TDD) — пишет unit/integration/contract tests до production-кода
- [x] Читает: BRD, PO-backlog, test-strategy из S2, API spec из S3
- [x] Артефакты: тесты + `QA-YYYY-MM-DD-tdd-report.md` + `QA-TDD-status.md`
- [x] `s4-dev` допускается только при RED и выполняет Green/Repair
- [x] Добавлены шаги `/write-tests` до `s4-dev` и `/run-tests` после него
- [x] FAIL запускает bounded repair loop, PASS разрешает `s4-techlead`, exhaustion = BLOCKED
- [x] `s5-qa-auto` сохраняет E2E/API high-level automation

---

#### Продуктовые критерии приёмки (UAT) — новый агент или расширение s2-po

Сейчас AC есть только на уровне отдельных stories (Given/When/Then в `s2-po`) и функциональных требований (BRD в `s2-ba`). Нет документа "что PO должен увидеть чтобы принять продукт целиком".

Варианты реализации:
- Расширить `s2-po`: добавить задачу формирования UAT-критериев на уровне продукта
- Создать нового агента `s2-uat` — Product Acceptance / UAT Owner

- [ ] Выбрать подход: расширить `s2-po` или новый агент
- [ ] Артефакт: `UAT-YYYY-MM-DD-acceptance-criteria.md` в `stage2-requirements/outputs/`
- [ ] Содержание: сценарии приёмки продукта целиком (не stories), критерии подписи PO
- [ ] Связать с `s5-qa:/go-no-go` — Go/No-Go должен включать проверку UAT-критериев

---

#### Новый агент в Цикле 1: s5-uat (этап S5)

Сейчас UAT — это чекбокс в `s5-qa` Go/No-Go: "владелец лично проверил". Нет структурированного процесса приёмочного тестирования.

Агент добавляется после `s5-qa-auto` и перед `s5-qa:/go-no-go`.

- [ ] Создать агента `cycle1-dev/s5-uat/`
- [ ] Роль: UAT Facilitator — проводит структурированное приёмочное тестирование продукта
- [ ] Читает: `UAT-acceptance-criteria.md` из S2 (от нового агента `s2-uat`), `QA-test-plan.md`
- [ ] Прогоняет acceptance сценарии по критериям из S2
- [ ] Артефакты: `UAT-YYYY-MM-DD-report.md` в `stage5-testing/outputs/`
- [ ] Содержание: результат по каждому сценарию (Pass/Fail), итоговый вердикт PO sign-off
- [ ] `s5-qa:/go-no-go` читает UAT-report — без UAT PASSED переход заблокирован
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s5-qa-auto:/e2e-report`

---

#### Новый агент в Цикле 1: s5-exploratory (этап S5)

Никто не проводит исследовательское тестирование — свободное исследование продукта без заранее написанных сценариев для поиска неочевидных багов, граничных случаев и UX-проблем.

Агент добавляется параллельно или после `s5-qa-auto`.

- [ ] Создать агента `cycle1-dev/s5-exploratory/`
- [ ] Роль: Exploratory Tester — исследует продукт без фиксированных сценариев
- [ ] Читает: BRD, PO-backlog, UX wireframes, предыдущие баг-репорты
- [ ] Артефакты: `QA-YYYY-MM-DD-exploratory-report.md` в `stage5-testing/outputs/`
- [ ] Содержание: найденные баги, UX-проблемы, граничные случаи, риски
- [ ] Результаты передаются в `s5-qa:/go-no-go` как дополнительный input
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh`

---

#### Новый агент в Цикле 1: s5-defects (этап S5)

Никто не создаёт формальные bug reports и не ведёт backlog дефектов. Баги находятся в разных отчётах (`s5-qa`, `s5-qa-auto`, `s5-exploratory`) но не агрегируются и не приоритизируются.

Агент запускается после всех тестовых агентов S5 и перед Go/No-Go.

- [ ] Создать агента `cycle1-dev/s5-defects/`
- [ ] Роль: Defect Manager — собирает, классифицирует и приоритизирует дефекты
- [ ] Читает: все отчёты S5 (`QA-test-plan`, `AUTO-e2e-report`, `QA-exploratory-report`, `UAT-report`)
- [ ] Артефакты: `DEF-YYYY-MM-DD-defects.md` в `stage5-testing/outputs/`
- [ ] Содержание: формальные bug reports (шаги воспроизведения, severity, priority, статус), разделение на "блокируют релиз" и "в backlog на будущее"
- [ ] Дефекты с severity S1/S2 — блокируют Go/No-Go
- [ ] Дефекты S3/S4 с user-facing impact — промотируются в `tracking/known-issues.md` (операционный контракт: workaround + detection signal + runbook + auto-remediation, quality.md §6.1); остальные — в `tracking/backlog.md`/`tech-debt.md`
- [ ] `s5-qa:/go-no-go` читает `DEF-*-defects.md`
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s5-exploratory`

---

#### Новый агент в Цикле 1: s5-regression (этап S5)

Никто не ведёт регрессионный suite и не прогоняет его каждый цикл. `s5-qa-auto` пишет тесты только для текущего цикла — нет проверки что старая функциональность не сломана.

Агент запускается после `s5-qa-auto` и перед `s5-defects`.

- [ ] Создать агента `cycle1-dev/s5-regression/`
- [ ] Роль: Regression Engineer — ведёт и прогоняет регрессионный suite
- [ ] Читает: предыдущие `AUTO-*-e2e-report.md`, `DEV-*-update-notes.md` (что изменилось), `PO-backlog.md` (scope изменений)
- [ ] Определяет scope регрессии: какие области затронуты изменениями текущего цикла
- [ ] Прогоняет регрессионный набор, фиксирует новые падения
- [ ] Артефакты: `QA-YYYY-MM-DD-regression-report.md` в `stage5-testing/outputs/`
- [ ] Содержание: scope регрессии, результаты прогона, новые падения vs известные
- [ ] Новые регрессионные падения передаются в `s5-defects`
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s5-qa-auto:/e2e-report`

---

#### Расширить s5-qa: анализ автотестов

`s5-qa` сейчас только проверяет пороги (≥80%, ≥95%) для Go/No-Go. Нужно добавить глубокий анализ результатов автотестов.

- [ ] Добавить в `s5-qa/CLAUDE.md` задачу анализа автотестов перед Go/No-Go
- [ ] Содержание анализа: причины падений тестов, расследование flaky tests, coverage gap (что не покрыто и почему), динамика качества
- [ ] Артефакт: `QA-YYYY-MM-DD-test-analysis.md` в `stage5-testing/outputs/`
- [ ] Go/No-Go читает test-analysis как обязательный input

---

#### Новый агент в Цикле 1: s5-release-prep

Результатом разработки должны быть release-notes — описание того что сделано. Это артефакт Цикла 1, не Цикла 2.

- [ ] Создать агента `cycle1-dev/s5-release-prep/`
- [ ] Роль: на основе PR summary, dev-report и changelog пишет release-notes для версии
- [ ] Артефакт: `REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md` в `stage5-testing/outputs/` или отдельной папке
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s5-qa:/go-no-go`
- [ ] Убрать `s6-release:/release-notes` из `CYCLE2_AGENTS` (эта задача переходит к новому агенту Цикла 1)

---

#### Пробелы покрытия ISO/IEC 25010

`_standards/quality.md §4.1` фиксирует характеристики, которые сейчас покрыты частично или не
гейтятся. Ранее стандарт ссылался на потерянные номера пунктов roadmap; канонический backlog
восстановлен здесь.

- [ ] **Compatibility / co-existence:** определить проверку совместной работы с другими системами в целевой среде
- [ ] **Interaction Capability / Usability:** определить измеримые usability-критерии и владельца проверки
- [ ] **Accessibility:** определить применимость, стандарт и gate-критерии по risk/tier проекта
- [ ] **Maintainability:** расширить контроль за пределы complexity/SRP — modularity, reusability, analysability и modifiability
- [ ] **Flexibility / installability:** определить проверку установки, обновления и заменяемости компонентов
- [ ] **Quality-in-use:** определить, нужен ли отдельный системный gate поверх UAT и SLO/error budget
- [ ] **Incident → gate feedback loop:** формализовать, как escaped defect или post-mortem усиливает конкретный gate/стандарт

---

#### ✅ Разработка Цикла 2 (Deploy) — СДЕЛАНО

- [x] Единый revisioned goal profile с infrastructure/deliverable interview
- [x] Смысловой UI маршрута: только 1 / 1→2 / 1→2→3 / своя комбинация,
      включение/выключение отдельного цикла и нумерованный выбор deliverables
- [x] Частичная поздняя корректировка Cycle 2 без повторного Cycle 1
- [x] Intake → tests/RED → delivery → tests/PASS/repair
- [x] Интеграция в `sdlc.sh`, DEPLOY-TDD status и Gate 6 blocker
- [x] Bounded read-only subagents без нового постоянного агента

---

#### ✅ Разработка Цикла 3 (Ops) — СДЕЛАНО

- [x] Частично обновляемый revisioned Cycle 3 goal profile
- [x] Intake → ops tests/RED → configuration → PASS/repair
- [x] OPS-TDD blocker перед Post-Deploy и Gate 7
- [x] Bounded read-only subagents для observability/incident/DR/capacity audit

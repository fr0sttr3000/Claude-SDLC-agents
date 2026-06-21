---
date: 2026-06-20
tags: [plans, roadmap]
---

# Roadmap — SDLC Agent System

## Концепция: 3 цикла

| Цикл | Суть | Среда |
|------|------|-------|
| Цикл 1 — Dev | Разработка: код, тесты, документация | Локальная |
| Цикл 2 — Deploy | Деплой кода в любую нужную среду | Реальная |
| Цикл 3 — Ops | Эксплуатация задеплоенного кода | Реальная (прод) |

Агенты Цикла 2 и 3 работают в реальной среде. Агенты Цикла 1 — только разработка, никакого деплоя в прод.

### Этапы Цикла 1

| Этап                       | Назначение                                                                                                                                                                                  | Агенты                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| S0 — Discovery & Tracking  | Исследование проблемы и валидация гипотез (до старта S1) + оперативный трекинг спринтов и задач на протяжении всего цикла + контроль структуры артефактов                                   | `s0-kickoff`, `s0-tracker`, `s0-validate` + *(новый агент discovery)* |
| S1 — Планирование          | Оценка реализуемости (4 оси), Product Vision, Project Charter, Risk Register, PMO-constraints, ROI/NPV/TCO, бюджет — стратегические governance-документы, создаются один раз в начале цикла | `s1-pm`, `s1-pmo`, `s1-finance`                                       |
| S2 — Требования            | BRD, User Stories, Testability                                                                                                                                                              | `s2-ba`, `s2-po`, `s2-qa-req`                                         |
| S3 — Дизайн                | HLD, Security, RBAC, DB Schema                                                                                                                                                              | `s3-arch`, `s3-security`, `s3-rbac`, `s3-dba`                         |
| S4 — Разработка            | Код, Code Review                                                                                                                                                                            | `s4-dev`, `s4-techlead`                                               |
| S5 — Тестирование          | Test Plan, E2E, Load, Go/No-Go                                                                                                                                                              | `s5-qa`, `s5-qa-auto`, `s5-perf`                                      |
| **S6 — Подготовка релиза** | Release Notes, Dev Checklist                                                                                                                                                                | *(новый агент — см. план)*                                            |

> **Local Run** (`l1-l4`) — оснастка разработчика для локального запуска проектов. Не этап цикла.

---

## Статус работ

### ✅ Выполнено

**Структурная реорганизация директорий**
- Агенты перемещены в `cycle1-dev/`, `cycle2-deploy/`, `cycle3-ops/`, `_tools/`
- `sdlc.sh` и `localrun.sh` обновлены: поиск агентов через `find_agent_dir()`
- `CLAUDE.md`, `OVERVIEW.md`, `GETTING_STARTED.md` обновлены
- Проверена изоляция контекста между агентами

**Quality Gates overhaul (v2.000.002)** — улучшения относительно ISO 25010 / ISTQB / DORA / SRE / ITIL:
- Пирамида тестов (§3.1): branch coverage ≥80% (вместо line) + mutation score ≥60% критичных + уровни integration/contract; пороги растут по tier
- Code duplication ≤3% нового кода (DoD-1, §3)
- Маппинг на ISO/IEC 25010 (§4.1) + Functional Suitability в Gate 5 (Must-FR ↔ RTM)
- Метрики (§7): DORA +Reliability (5-я), сбор/тренд по циклам, defect-метрики (Density, DRE ≥95%, Escaped)
- Known Issues operational contract / KEDB (§6.1): реестр `known-issues.md` + per-KI runbook + targeted-алерт + auto-remediation + Patch SLA; шаблоны `known-issues-template.md`, `runbook-KI-template.md`
- Распространено по агентам s4-dev/s4-techlead/s5-qa/s5-qa-auto/s0-tracker/s0-validate/s6-release/s6-sre + `dod-check.sh`

---

### 🔄 Запланировано

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

**✅ Сделано (v2.000.000):** `sdlc.sh` приведён к модели 3 циклов.
- [x] `CYCLE_AGENTS` разделён на `CYCLE1_AGENTS` (22 шага), `CYCLE2_AGENTS`, `CYCLE3_AGENTS`
- [x] Главное меню: пункт «Запустить цикл» с подменю выбора (Разработка / Деплой / Эксплуатация / Всё сразу)
- [x] Циклы 2/3 — заглушки «в разработке»
- [x] Меню одиночного запуска сгруппировано по циклам + Tools + Local Run
- [x] Обновлены `CLAUDE.md`, `OVERVIEW.md`, `README.md`, `GETTING_STARTED.md`

**Проблема (осталось):** `s4-devops`, `s6-release`, `s6-sre` в своих `CLAUDE.md` описывают работу в реальной prod-среде — это логика Циклов 2 и 3, не Цикла 1.

Нужно:
- [ ] `cycle2-deploy/s4-devops/CLAUDE.md` — переписать под роль: пишет инфра-код (Dockerfile, CI/CD, monitoring) + деплоит в реальную среду
- [ ] `cycle2-deploy/s6-release/CLAUDE.md` — переписать под роль: release management в реальной среде
- [ ] `cycle3-ops/s6-sre/CLAUDE.md` — переписать под роль: реальная эксплуатация (мониторинг, SLO, инциденты)

#### Новый агент в Цикле 1: s2-test-strategy (этап S2)

> ⚠️ **Сверка с реализованным:** уровни/типы тестов и пороги покрытия уже формализованы в
> `quality.md §3.1` (пирамида unit/integration/contract/e2e, branch+mutation). Этот агент НЕ должен
> их дублировать — его зона: риск-матрица, выбор инструментов, привязка типов к конкретным требованиям
> (применение §3.1 к проекту), а не переопределение порогов.

`s2-qa-req` только проверяет тестируемость требований. Никто не определяет стратегию тестирования: типы, уровни, инструменты, риски, валидацию бизнес-функций. Стратегия должна закладываться в S2 (Shift Left), а не в S5.

Агент добавляется после `s2-qa-req`.

- [ ] Создать агента `cycle1-dev/s2-test-strategy/`
- [ ] Роль: QA Strategist — определяет стратегию тестирования на основе требований
- [ ] Читает: BRD, NFR, PO-backlog, UAT acceptance criteria
- [ ] Артефакты: `QA-YYYY-MM-DD-test-strategy.md` в `stage2-requirements/outputs/`
- [ ] Содержание: типы тестирования (unit/integration/E2E/UAT), уровни покрытия, риск-матрица, критерии валидации бизнес-функций, инструменты
- [ ] `s5-qa` читает test-strategy из S2 и строит test plan на её основе
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` после `s2-qa-req:/testability-review`

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
- [x] В S3 остаётся **design-level**: `s3-security` делает STRIDE/DREAD по HLD-компонентам (SG2), развивая security-требования из SG1
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

#### Новый агент в Цикле 1: s4-qa-auto — TDD (этап S4)

Автотесты сейчас пишутся в S5 после кода. Применяем TDD: тесты пишутся ДО кода в S4.
`s5-qa-auto` остаётся только для E2E и высокоуровневой автоматизации.

Поток S4 после изменения:
```
s4-qa-auto  → пишет unit + integration тесты на основе требований (Red)
s4-dev      → пишет код чтобы тесты прошли (Green → Refactor)
s4-qa       → статический анализ, линтеры, coverage
s4-techlead → code review
```

- [ ] Создать агента `cycle1-dev/s4-qa-auto/`
- [ ] Роль: SDET (TDD) — пишет unit и integration тесты до написания кода
- [ ] Читает: BRD, PO-backlog, test-strategy из S2, API spec из S3
- [ ] Артефакты: тесты в репозитории проекта + `QA-YYYY-MM-DD-tdd-report.md` в `stage4-dev/outputs/`
- [ ] `s4-dev` получает тесты от `s4-qa-auto` и пишет код чтобы они прошли
- [ ] Добавить шаг в `CYCLE1_AGENTS` в `sdlc.sh` перед `s4-dev:/dev-report`
- [ ] Обновить `s5-qa-auto`: убрать unit/integration, оставить только E2E и API автоматизацию

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

#### Разработка Цикла 2 (Deploy) — 🔮 Долгосрочный план

> Разрабатывается отдельно, после завершения Цикла 1. Не в текущем приоритете.

- [ ] Определить агентов и их задачи
- [ ] Написать `CLAUDE.md` для `s4-devops` и `s6-release` под Цикл 2
- [ ] Создать лаунчер `cycle2.sh` или интегрировать в `sdlc.sh`
- [ ] Определить gates между Циклом 1 и Циклом 2

---

#### Разработка Цикла 3 (Ops) — 🔮 Долгосрочный план

> Разрабатывается отдельно, после завершения Цикла 2. Не в текущем приоритете.

- [ ] Определить агентов и их задачи
- [ ] Написать `CLAUDE.md` для `s6-sre` под Цикл 3
- [ ] Определить gates между Циклом 2 и Циклом 3

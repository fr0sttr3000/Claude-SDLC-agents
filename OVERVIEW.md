---
date: 2026-05-23
tags: [overview, sdlc, architecture]
---

# SDLC Agent System — Полный обзор

> Автоматизированная система управления жизненным циклом разработки (SDLC)
> на базе Claude Code. 26 специализированных AI-агентов покрывают весь цикл
> от идеи до деплоя и ведения задач в спринтах.

---

## Архитектура системы

```
┌─────────────────────────────────────────────────────────────────┐
│                    SDLC Agent System                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  _agents/sdlc.sh — Интерактивный лаунчер                │   │
│  └───────────────────────┬──────────────────────────────────┘   │
│                          │ запускает                            │
│         ┌────────────────┼────────────────┐                     │
│         ▼                ▼                ▼                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ s0-* агенты │  │ s1-s6 агенты│  │  l1-l4      │            │
│  │Инфраструктура│  │  SDLC-цикл  │  │  Local Run  │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          │ читают/пишут                         │
│         ┌────────────────▼────────────────┐                     │
│         │         projects/               │                     │
│         │  {PROJECT}/                     │                     │
│         │    stage1-planning/outputs/     │                     │
│         │    stage2-requirements/outputs/ │                     │
│         │    ...                          │                     │
│         │    tracking/ (s0-tracker)       │                     │
│         └─────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Структура директорий

```
/home/host-gui-car/Documents/Obsidian Vault/Claude/
│
├── CLAUDE.md              ← Глобальный контекст (читается агентами)
├── OVERVIEW.md            ← Этот файл — полный обзор системы
│
├── _agents/               ← 27 агентов + стандарты
│   ├── README.md          ← Операционное руководство
│   ├── CLAUDE.md          ← Глобальный контекст агентов (quality gates, правила)
│   ├── _standards/        ← Стандарты компании (доступны всем агентам)
│   │   ├── company.md     ← Стек, роли, методология
│   │   ├── quality.md     ← DoD, DoR, Gates, NFR, Auto-Heal (читать перед каждой задачей)
│   │   ├── data-formats.md ← Форматы DB/ENV/API, тесты форматов (читать перед каждой задачей)
│   │   ├── dor-violations-template.md ← Шаблон журнала нарушений DoR
│   │   └── tech-debt-template.md      ← Шаблон журнала технического долга
│   ├── sdlc.sh            ← Главный лаунчер (SDLC-цикл + необязательные шаги)
│   ├── localrun.sh        ← Local Run лаунчер (GitHub-проекты)
│   ├── s0-kickoff/        ← Project Kickoff — онбординг нового проекта / обновление беклога
│   ├── s0-secrets/        ← Secrets Manager
│   ├── s0-github/         ← GitHub Sync
│   ├── s0-validate/       ← Structure Validator + Quality Artifacts Validator
│   ├── s0-tracker/        ← Sprint & Task Tracker (DoD enforcement)
│   ├── l1-analyze/        ← Local: анализ проекта
│   ├── l2-setup/          ← Local: настройка окружения
│   ├── l3-build/          ← Local: сборка
│   ├── l4-run/            ← Local: запуск
│   ├── s1-pm/             ← Product Manager
│   ├── s1-pmo/            ← Project Manager / PMO
│   ├── s1-finance/        ← Finance Analyst
│   ├── s2-ba/             ← Business Analyst
│   ├── s2-po/             ← Product Owner
│   ├── s2-qa-req/         ← QA (требования) — Gate 2
│   ├── s3-arch/           ← Solution Architect — Gate 3
│   ├── s3-security/       ← Security Engineer
│   ├── s3-dba/            ← DBA
│   ├── s4-dev/            ← Backend Developer
│   ├── s4-techlead/       ← Tech Lead — Gate 4
│   ├── s4-devops/         ← DevOps Engineer
│   ├── s5-qa/             ← QA Engineer — Gate 5
│   ├── s5-qa-auto/        ← QA Automation
│   ├── s5-perf/           ← Performance Engineer
│   ├── s6-release/        ← Release Manager — Gate 6
│   └── s6-sre/            ← SRE
│
├── _secrets/
│   └── README.md          ← Документация по pass
│
├── Local_Run/             ← Заметки по GitHub-проектам (l-агенты)
│   ├── CLAUDE.md
│   ├── _workflow.md
│   └── {project}/
│       ├── overview.md
│       ├── setup.md
│       ├── build.md
│       └── run.md
│
└── projects/              ← Артефакты SDLC-проектов
    ├── _example-project/  ← Шаблон (префикс _ → скрыт в меню)
    └── {PROJECT}/
        ├── Dashboard.md
        ├── docs/
        │   └── CHANGELOG.md           ← Обязателен с первого PR
        ├── stage1-planning/
        │   ├── inputs/idea.md
        │   └── outputs/
        │       ├── PM-*.md            ← Feasibility, Vision+OKR
        │       ├── PMO-*.md           ← Charter, Risk Register, RACI
        │       └── FIN-*.md           ← Business Case
        ├── stage2-requirements/
        │   └── outputs/
        │       ├── BA-*.md            ← BRD, NFR, RTM
        │       ├── PO-*.md            ← Backlog, Sprint
        │       └── QA-REQ-*.md        ← Testability Review (Gate 2)
        ├── stage3-design/
        │   └── outputs/
        │       ├── ARCH-*.md          ← HLD, ADR-N, api-spec.yaml
        │       ├── SEC-*.md           ← Threat Model (Gate 3)
        │       └── DBA-*.md           ← Schema, Migration Runbook
        ├── stage4-dev/
        │   └── outputs/
        │       ├── DEV-*-PR-[N]-summary.md
        │       ├── DEV-*-update-notes-PR[N].md  ← Обязателен после каждого PR
        │       ├── TL-*-review-PR[N].md          ← Code Review (Gate 4)
        │       └── DEVOPS-*.md        ← CI/CD, Runbook, Monitoring
        ├── stage5-testing/
        │   └── outputs/
        │       ├── QA-*.md            ← Test Plan, Test Cases, Go/No-Go (Gate 5)
        │       ├── AUTO-*.md          ← E2E/API Coverage Report
        │       └── PERF-*.md          ← Load Test Report
        ├── stage6-deploy/
        │   └── outputs/
        │       ├── REL-*-checklist-v[X.Y.Z].md   ← Gate 6
        │       ├── REL-*-release-notes-v[X.Y.Z].md
        │       └── SRE-*.md           ← Post-Deploy Report, Post-Mortem
        ├── stage7-ops/
        │   └── outputs/
        │       ├── SRE-*-autoheal-report.md   ← Auto-Heal verification (BLOCKER Gate 7)
        │       ├── SRE-*-ops-report.md        ← SLO Review через 7 дней (Gate 7)
        │       ├── SRE-runbook-service-down.md
        │       ├── SRE-runbook-high-latency.md
        │       ├── SRE-runbook-db-down.md
        │       └── SRE-runbook-disk-full.md
        └── tracking/
            ├── backlog.md
            ├── current-sprint.md
            ├── cycle-summary.md
            ├── dor-violations.md  ← журнал возвратов по DoR (создаётся s0-tracker)
            ├── tech-debt.md       ← журнал техдолга (создаётся s0-tracker)
            └── sprints/
                ├── sprint-01.md
                └── sprint-02.md
```

---

## SDLC-цикл — 24 шага + необязательные

Полный автоматизированный цикл запускается через `_agents/sdlc.sh → пункт 2`.
Перед стартом цикла предлагается выбор необязательных шагов (тоглы включения/выключения):
- `s0-validate /validate` до цикла — проверить структуру
- `s0-secrets` до цикла — настроить секреты
- `s0-tracker /sprint-init` до цикла — инициализировать спринт
- `s0-validate /validate` после цикла — проверить артефакты

```
Этап 0: Онбординг / Инфраструктура
  ─────────────────────────────────────────────────────────────────
  s0-kickoff /new           Интервью (4 блока) → заполняет idea.md + PM-input-interview.md
  s0-kickoff /refresh       Обновить видение / беклог / NFR для существующего проекта
  s0-validate /fix          Проверить и починить структуру (если нужно)
  s0-tracker /sprint-init   Запустить спринт (перед циклом)

Этап 1: Планирование
  ─────────────────────────────────────────────────────────────────
  Шаг  1  s1-pm /feasibility     Feasibility Study + вердикт Go/No-Go
  Шаг  2  s1-pm /vision          Product Vision + OKR + North Star
  Шаг  3  s1-pmo /charter        Project Charter (10 разделов)
  Шаг  4  s1-pmo /risks          Risk Register (≥10 рисков, PMBOK)
  Шаг  5  s1-finance             Business Case + ROI + Сценарный анализ
                                 ── Quality Gate 1 закрыт ──►

Этап 2: Требования
  ─────────────────────────────────────────────────────────────────
  Шаг  6  s2-ba /extract-requirements   Сбор требований
  Шаг  7  s2-ba /brd                    BRD + NFR (с числами) + RTM
  Шаг  8  s2-po /stories                User Stories + Backlog (INVEST/RICE)
  Шаг  9  s2-qa-req /testability-review  Testability Review → Gate 2 PASSED/FAILED
                                         ── Quality Gate 2: s3-arch ждёт PASSED ──►

Этап 3: Дизайн
  ─────────────────────────────────────────────────────────────────
  Шаг 10  s3-arch /hld                  High-Level Design + ADR
  Шаг 11  s3-security /threat-model     Threat Model (STRIDE/DREAD/OWASP)
  Шаг 12  s3-rbac /rbac-model           RBAC Model + Permission Matrix + RLS + SQL Schema
  Шаг 13  s3-dba /schema                DB Schema (читает RBAC-schema.sql)
                                         ── Quality Gate 3: s4-dev ждёт PASSED ──►

Этап 4: Разработка
  ─────────────────────────────────────────────────────────────────
  Шаг 14  s4-dev /dev-report            Dev Report + PR Summary
  Шаг 15  s4-dev /update-notes          Update Notes (обязательно после каждого PR)
  Шаг 16  s4-techlead /review           Code Review (DoD: все 11 пунктов)
                                         → Gate 4: TL-*-review-PR*.md для каждого PR
  Шаг 17  s4-devops /pipeline           CI/CD Pipeline (lint→test→build→SAST→secrets-scan)
  Шаг 18  s4-devops /runbook            Runbook деплоя + rollback-процедура
                                         ── Quality Gate 4: s5-qa ждёт coverage≥80% ──►

Этап 5: Тестирование
  ─────────────────────────────────────────────────────────────────
  Шаг 19  s5-qa /test-plan              Test Plan + тест-кейсы (IEEE 829)
  Шаг 20  s5-qa-auto /e2e-report        Automation Report (coverage ≥95%)
  Шаг 21  s5-perf /load-test            Load Tests (smoke/load/stress/soak) + вердикт
  Шаг 22  s5-qa /go-no-go              Go/No-Go → Gate 5 PASSED/FAILED
                                         ── Quality Gate 5: s6-release ждёт PASSED ──►

Этап 6: Деплой
  ─────────────────────────────────────────────────────────────────
  Шаг 23  s6-release /release-checklist  Release Checklist + Gate 6
  Шаг 24  s6-release /release-notes      Release Notes v[X.Y.Z]
  Шаг 25  s6-sre /post-deploy            Post-Deploy Report (T+0..T+60)
                                          + Post-Mortem если был инцидент

Этап 7: Эксплуатация (ОБЯЗАТЕЛЬНЫЙ — через 7 дней после деплоя)
  ─────────────────────────────────────────────────────────────────
  Шаг 26  s6-sre /gate7                  Monitoring Dashboard: RED + SLO + Error Budget
                                          Auto-Heal verification: kill → restart < 30 сек
                                          Incident Runbooks (4 типа)
                                          SLO Review → SRE-*-ops-report.md
                                          ── Quality Gate 7 закрыт → следующий релиз разблокирован ──►

Финальные шаги (всегда выполняются)
  ─────────────────────────────────────────────────────────────────
  Шаг 27  s0-tracker /report     Отчёт цикла: план vs факт ◄ ПРЕДПОСЛЕДНИЙ
  Шаг 28  s0-github /push        Push артефактов в GitHub   ◄ ПОСЛЕДНИЙ
```

---

## Quality Gates — принудительные переходы

Каждый gate закрывает предыдущий этап. Агент следующего этапа проверяет gate **первым делом** и отказывает в начале работы, если gate не пройден.

```
S1 Планирование ──[Gate 1]──► S2 Требования
                               Проверяет s2-ba:
                               Feasibility + Charter + Риски

S2 Требования ──[Gate 2]──► S3 Дизайн
                              Проверяет s3-arch:
                              QA-REQ-*-review.md → "GATE 2 PASSED"

S3 Дизайн ──[Gate 3]──► S4 Разработка
                          Проверяет s4-dev:
                          HLD + SEC (0 Critical/High) + DBA Schema

S4 Разработка ──[Gate 4]──► S5 Тестирование
                              Проверяет s5-qa:
                              Все PR с DoD + coverage≥80% + SAST pass

S5 Тестирование ──[Gate 5]──► S6 Деплой
                                Проверяет s6-release:
                                QA-go-no-go → "GATE 5 PASSED" + UAT sign-off

S6 Деплой ──[Gate 6]──► PRODUCTION
                          Проверяет s6-sre:
                          Checklist + Release Notes + Rollback проверен

PRODUCTION ──[Gate 7]──► Следующий релиз (через 7 дней)
                          Проверяет s6-sre:
                          Monitoring active + Auto-Heal verified + SLO Review done
                          Без Gate 7 → следующий релиз ЗАБЛОКИРОВАН
```

Канонические правила каждого gate — в `_standards/quality.md §4` и `§6`.

---

## Definition of Done (DoD) — 11 обязательных пунктов

DoD **бинарен**: нет "Done minus docs" или "почти Done". Задача остаётся IN_PROGRESS до выполнения всех применимых пунктов.
Применимость зависит от типа артефакта: **Тип К** (Код — все 11), **Тип Д** (Документ — 6 пунктов), **Тип И** (Инфраструктура — 9 пунктов).
Автопроверка: `s0-validate /dod-check [K|D|I] [STAGE] [PR]`.

| # | Условие | Кто проверяет | Проверка |
|---|---------|--------------|---------|
| 1 | Код соответствует стандартам (complexity ≤10, SRP) | s4-techlead | 🤖 частично |
| 2 | Unit-тесты написаны, покрытие ≥80% изменённого кода | s4-techlead | 🤖 авто |
| 3 | Code review пройден: 0 открытых BLOCKER и MAJOR | s4-techlead | 👤 вручную |
| 4 | README/API-spec/docstring обновлены | Агент-получатель | 👤 вручную |
| 5 | CHANGELOG.md обновлён | s4-techlead | 🤖 авто |
| 6 | DEV-*-update-notes-PR[N].md создан | s4-techlead | 🤖 авто |
| 7 | Нет известных S1/S2 багов без митигации | s5-qa | 👤 вручную |
| 8 | Секреты не в коде, не в логах, не в артефактах | s4-techlead | 🤖 авто |
| 9 | NFR проверены (latency, error rate, memory) | s5-perf/s5-qa | 👤 вручную |
| 10 | Артефакт записан в outputs/ текущего этапа | Агент-получатель | 🤖 авто |
| 11 | Тесты форматов написаны и проходят (если применимо) | s4-techlead | 🤖 авто |

Velocity s0-tracker считает только по задачам с полным DoD.
Осознанный пропуск DoD → фиксируется как Tech Debt в `tracking/tech-debt.md` (блокирует sprint-close при просрочке).

---

## Поток данных между агентами

```
idea.md (входные данные)
    │
    ▼
s1-pm: PM-feasibility.md, PM-vision-okr.md
    │
    ├──► s1-pmo: PMO-charter.md, PMO-risk-register.md, PMO-raci.md
    │
    └──► s1-finance: FIN-business-case.md
              │
              ▼ [Gate 1]
         s2-ba: BA-BRD.md, BA-NFR.md, BA-RTM.md
              │
              ├──► s2-po: PO-backlog.md, PO-sprint-N.md
              │
              └──► s2-qa-req: QA-REQ-*-review.md → "GATE 2 PASSED"
                        │
                        ▼ [Gate 2]
                   s3-arch: ARCH-HLD.md, ARCH-ADR-*.md, ARCH-api-spec.yaml
                        │
                        ├──► s3-security: SEC-threat-model.md
                        │
                        └──► s3-dba: DBA-schema.sql/.dbml
                                  │
                                  ▼ [Gate 3]
                             s4-dev: DEV-*-PR-[N]-summary.md
                                     DEV-*-update-notes-PR[N].md  ← НОВОЕ
                                  │
                                  ├──► s4-techlead: TL-*-review-PR[N].md → Gate 4
                                  │
                                  └──► s4-devops: DEVOPS-cicd.yaml
                                                  DEVOPS-runbook.md
                                                  DEVOPS-monitoring.yaml
                                            │
                                            ▼ [Gate 4]
                                       s5-qa: QA-test-plan.md
                                              QA-go-no-go.md → "GATE 5 PASSED"
                                            │
                                            ├──► s5-qa-auto: AUTO-*-coverage.md
                                            │
                                            └──► s5-perf: PERF-report.md
                                                      │
                                                      ▼ [Gate 5]
                                                 s6-release: REL-*-checklist.md
                                                             REL-*-release-notes-v*.md  ← НОВОЕ
                                                      │
                                                      ▼ [Gate 6]
                                                 s6-sre: SRE-*-post-deploy.md
                                                         SRE-*-postmortem-INC*.md
                                                      │
                                                      ▼ [Gate 7 — через 7 дней]
                                           s6-sre (stage7-ops):
                                                         SRE-*-autoheal-report.md  ← BLOCKER
                                                         SRE-*-ops-report.md
                                                         SRE-runbook-*.md (4 типа)
                                                      │
                                                      ▼
                                           s0-tracker: cycle-summary.md
                                                      │
                                                      ▼
                                           s0-github: push → GitHub
```

Правило передачи: каждый агент читает артефакты предыдущего через **абсолютный путь**. История диалога не передаётся.

> **Необязательные шаги** (s0-validate, s0-secrets, s0-tracker /sprint-init) вставляются до или после основного потока — выбираются пользователем в меню sdlc.sh перед стартом цикла.

---

## Система качества и надёжности

### Стандартные файлы (_standards/)

| Файл | Путь | Кто читает |
|------|------|-----------|
| `company.md` | `_agents/_standards/company.md` | s1-pm, s1-pmo, s1-finance, s3-arch |
| `quality.md` | `_agents/_standards/quality.md` | Все агенты |
| `data-formats.md` | `_agents/_standards/data-formats.md` | s2-ba, s3-dba, s4-dev, s5-qa-auto |
| `dor-violations-template.md` | `_agents/_standards/dor-violations-template.md` | s0-tracker (создаёт tracking/dor-violations.md) |
| `tech-debt-template.md` | `_agents/_standards/tech-debt-template.md` | s0-tracker (создаёт tracking/tech-debt.md) |

### NFR-дефолты (применять если не указано в BRD)

| Метрика | Порог |
|---------|-------|
| Availability | ≥ 99.9% |
| Response time p95 | < 500 ms |
| Response time p99 | < 2000 ms |
| Error rate | < 0.1% |
| RTO | < 1 час |
| RPO | < 24 часа |
| Security Critical/High | 0 |
| Test coverage | ≥ 80% |

### Обязательные паттерны надёжности (quality.md §5)

Каждая система обязана реализовать:
- Timeout на всех внешних вызовах (30 сек по умолчанию)
- Retry + exponential backoff (3 попытки, factor 2)
- Health checks: `/health` (liveness) + `/ready` (readiness)
- Graceful shutdown (до 30 сек)
- Structured JSON logging с correlation_id (RED-метрики)
- **Auto-Heal** (BLOCKER — без этого нет prod): применимые паттерны определяются топологией деплоя из `ARCH-HLD.md`

### Методология выбора паттернов (quality.md §5 + s3-arch)

Каждый паттерн обосновывается через цепочку:
`Бизнес-требование → NFR → Quality Attribute → Tactic → Pattern → ADR`

Паттерн без обоснования через NFR — запрещён (добавление "про запас" = BLOCKER).

**Deployment Constraint** (фиксируется в `BA-NFR.md` агентом `s2-ba`):

| Топология | Ключевые паттерны | Неприменимо |
|-----------|------------------|------------|
| `single-container` | Restart Policy, HEALTHCHECK, Resource Limits | Readiness Probe, Canary |
| `multi-instance` | Все паттерны | — |
| `serverless` | Resource Limits, Circuit Breaker, DLQ | Restart Policy, Watchdog |

---

## Sprint & Task Tracker

### Структура данных

```
tracking/
├── backlog.md          ← все задачи со статусами
├── current-sprint.md   ← активный спринт + live-доска
├── cycle-summary.md    ← итоговый отчёт (создаётся /report)
├── dor-violations.md   ← журнал возвратов по DoR (создаётся /sprint-init)
├── tech-debt.md        ← журнал техдолга (создаётся /sprint-init)
└── sprints/
    ├── sprint-01.md    ← цель, задачи, итог
    └── sprint-02.md
```

`/sprint-init` создаёт `dor-violations.md` и `tech-debt.md` при первом запуске.
`/sprint-close` блокируется при наличии просроченных Tech Debt записей.
`/sprint-init` показывает сводку по открытому техдолгу; >3 открытых TD блокируют следующий спринт.

### Структура задачи

```yaml
ID: T-001
Название: Создать Feasibility Study
Тип: SDLC-artifact        # feature | bug | chore | SDLC-artifact | quality-gate | docs
Агент: s1-pm
Спринт: 1
Статус: DONE               # TODO | IN_PROGRESS | DONE | BLOCKED | CANCELLED
Story Points: 5
Зависит от: —
done_date: 2026-05-10
dod_complete: true         # обязательно для перевода в DONE
```

### Обязательные quality-задачи в каждом спринте

s0-tracker автоматически добавляет при `/sprint-init`:
- `quality-gate`: закрытие gate предыдущего этапа
- `dod-check`: проверка DoD для каждого PR
- `docs`: обновление CHANGELOG + update-notes

### Обязательный вывод task board

После каждой команды агент выводит актуальную доску:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 TASK BOARD — Спринт 1 — Проект: my-project
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ ВЫПОЛНЕНО (5 задач, 18 SP)
   ✓ T-001  [5SP]  Feasibility Study
   ✓ T-002  [3SP]  Product Vision
🔄 В РАБОТЕ (1 задача)
   → T-003  [5SP]  Project Charter
⏳ К ВЫПОЛНЕНИЮ (4 задачи, 16 SP)
   ○ T-004  [8SP]  BRD
❌ ЗАБЛОКИРОВАНО (1 задача)
   ✗ T-005  [3SP]  DB Schema — Блокер: нет доступа к БД
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Прогресс: 5/11 задач (45%)  |  Velocity: 18 SP
📅 Спринт заканчивается: 2026-05-24  |  📦 В бэклоге: 8 задач
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Инфраструктурные агенты

### s0-validate — Structure Validator

Проверяет и восстанавливает структуру SDLC-проектов. Также автоматически проверяет DoR (готовность к старту этапа) и DoD (критерии завершения задачи).

```bash
# Проверить один проект (только отчёт, без изменений)
cd _agents/s0-validate && claude /validate my-project

# Починить все проекты (создать недостающие директории и заглушки)
cd _agents/s0-validate && claude /fix all

# Проверить DoR перед переходом на Gate N (автоматически)
cd _agents/s0-validate && claude "/dor-check my-project 3"

# Проверить DoD для артефакта или PR (автоматически)
cd _agents/s0-validate && claude "/dod-check my-project K 4 42"
```

`/dor-check <PROJECT> <GATE>` — проверяет DoR-1..8 перед переходом на Gate 1–6:
- DoR-1: артефакты предыдущего этапа, DoR-2: нет размытых формулировок, DoR-3: Given/When/Then
- DoR-4: числовые пороги в NFR, DoR-5: 0 открытых BLOCKER, DoR-7: threat-model (gate 4+)
- DoR-8: rollback в runbook (gate 7)

`/dod-check <PROJECT> <K|D|I> <STAGE> [PR]` — проверяет DoD-1..11 по типу артефакта:
- Тип К (Код): DoD-1 complexity, DoD-2 coverage ≥80%, DoD-3 TL-review, DoD-5 CHANGELOG, DoD-6 update-notes, DoD-8 secrets, DoD-10 outputs, DoD-11 format-tests
- Тип Д (Документ): DoD-3,4,5,7,8,10
- Тип И (Инфраструктура): DoD-2 migration test, DoD-3..5, DoD-8..11

Проверяет наличие:
- `Dashboard.md`, `stage1..stage7` с `inputs/` и `outputs/`
- `stage1-planning/inputs/idea.md`
- Quality-артефактов для завершённых этапов: QA-REQ review, SEC threat model, RBAC model+matrix, TL reviews, QA go-no-go, PERF report, REL checklist + release notes

### s0-github — GitHub Sync

```bash
cd _agents/s0-github && claude /init my-project   # первичная инициализация
cd _agents/s0-github && claude /push my-project   # шаг 22 цикла
cd _agents/s0-github && claude /sync my-project   # синхронизация
```

Ветки SDLC: `main`, `stage/planning`, `stage/requirements`, `stage/design`, `stage/development`, `stage/testing`, `stage/deploy`.

### s0-kickoff — Project Kickoff

```bash
# Новый проект — провести интервью с нуля (4 блока вопросов)
cd _agents/s0-kickoff && claude "/new my-project"

# Обновить существующий проект — беклог, видение, NFR
cd _agents/s0-kickoff && claude "/refresh my-project"

# Авто-определение режима (new vs refresh)
cd _agents/s0-kickoff && claude "/start my-project"

# Change Request — изменение требований в середине этапа
cd _agents/s0-kickoff && claude "/cr my-project"
```

Режим **NEW**: 4 блока интервью (Продукт → Бизнес → Техника → Приоритеты).
Выход: `idea.md` (заполненный) + `PM-input-interview-YYYY-MM-DD.md`.

Режим **REFRESH**: меню из 5 разделов (Видение / Беклог / Приоритеты / NFR / Scope Out).
Выход: `PM-input-refresh-*.md` и/или `BA-input-refresh-*.md` → передаёт s1-pm / s2-ba / s2-po.

Режим **CR** (Change Request): 4-блочное интервью (что изменилось / конкретно до-после / причина / срочность).
Выход: `stage{N}/inputs/CR-YYYY-MM-DD-[N]-input.md` + запись в `tracking/dor-violations.md`.
После CR — пользователь вручную перезапускает затронутых агентов.

Через sdlc.sh: главное меню `0) Kickoff`.

---

### s0-secrets — Secrets Manager

```bash
cd _agents/s0-secrets && claude /add my-project api-key
cd _agents/s0-secrets && claude /env my-project
```

---

## Меню лаунчера (sdlc.sh)

```
0) Kickoff — онбординг нового проекта / обновление беклога
   └─ Авто-определение: пустой проект → интервью NEW; существующий → меню REFRESH

1) Запустить один агент
   └─ Выбор агента → выбор проекта → выбор команды/задачи

2) Полный SDLC-цикл (24 шага)
   └─ Выбор проекта → 22 шага с выбором режима на каждом

3) Создать новый проект
   └─ Создаёт структуру stage1..stage7, Dashboard.md, idea.md
      Предлагает сразу запустить s0-kickoff /new для заполнения входных данных

4) Список проектов
   └─ Прогресс-бар по заполненности outputs/

5) Local Run — проекты с GitHub
   └─ clone → analyze → setup → build → run

6) Валидация — проверить и починить структуру
   └─ validate/fix × один проект / все проекты
```

---

## Механизм изоляции агентов

Каждый агент читает **только свой** `CLAUDE.md` при запуске из своей папки:

```bash
cd "_agents/s1-pm"    # claude читает _agents/s1-pm/CLAUDE.md
claude /feasibility my-project
```

Лаунчер автоматически делает `cd` в нужную папку перед вызовом claude:
```bash
(cd "$agent_dir" && env -u CLAUDECODE ... claude "$expanded_prompt")
```

Шаблон slash-команды раскрывается в bash до передачи в claude — `$ARGUMENTS` заменяется на реальное имя проекта ещё на уровне скрипта.

---

## Решение частых проблем

| Проблема | Причина | Решение |
|----------|---------|---------|
| `claude: command not found` | `~/.local/bin` не в PATH | Добавлено в sdlc.sh: `export PATH="/home/host-gui-car/.local/bin:$PATH"` |
| OAuth Invalid Request | `CLAUDECODE=1` мешает новому процессу | Агенты запускаются через `env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID` |
| «Проект не определён» | `$ARGUMENTS` не подставлялся нативно | Шаблон раскрывается в bash через `awk` + `sed` |
| Нет структуры папок | Проект создан без sdlc.sh | `sdlc.sh → пункт 6 → Починить` или `s0-validate /fix project` |
| Push не работает | Нет remote / не инициализирован | Сначала `s0-github /init project` |
| Gate заблокирован | Предыдущий этап не завершён | Проверить наличие артефактов и вердикта PASSED в нужном файле |

---

## Быстрый старт с нуля

```bash
# 1. Запустить лаунчер
bash "/home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/sdlc.sh"

# 2. Создать новый проект (пункт 3)
#    → введи название → создастся структура + idea.md

# 3. Заполнить idea.md описанием проекта
#    projects/{PROJECT}/stage1-planning/inputs/idea.md

# 4. (опционально) Инициализировать git + GitHub
#    пункт 1 → s0-github → /init

# 5. (опционально) Запустить спринт
#    пункт 1 → s0-tracker → /sprint-init

# 6. Запустить полный цикл (пункт 2)
#    → выбрать проект → 22 шага (каждый gate проверяется автоматически)

# 7. После цикла: cycle-summary.md + release-notes + ветка в GitHub
```

---

## Активные проекты

| Проект | Тип | Статус |
|--------|-----|--------|
| `FamilyPlannerBot` | Telegram-бот (Python, aiogram, PostgreSQL) | v1.2.0, Sprint 3 CLOSED → Sprint 4 в планировании |
| `Telegram-private-bot` | Telegram-бот | Этап 1 (idea.md заполнен) |
| `_example-project` | Шаблон | Только структура директорий |

---

## Ключевые файлы для редактирования

| Файл | Зачем редактировать |
|------|---------------------|
| `_standards/company.md` | Добавить стандарты компании (стек, роли, compliance) |
| `_standards/quality.md` | Изменить NFR-дефолты, пороги gates, паттерны надёжности |
| `_standards/data-formats.md` | Изменить правила форматов DB/ENV/API, шаблоны тестов |
| `projects/{PROJECT}/stage1-planning/inputs/idea.md` | Описание идеи для s1-pm |
| `_agents/{agent}/CLAUDE.md` | Настройка роли и правил агента |
| `_agents/sdlc.sh` | Изменить цикл, добавить агента, необязательные шаги |
| `_agents/localrun.sh` | Изменить Local Run pipeline |

---

*Обновлено: 2026-05-23. v1.6.0: Методология выбора паттернов (7 правил в s3-arch), выбор контролей безопасности (STRIDE→Control, DREAD→Action в s3-security), выбор технологии хранения (s3-dba). Deployment Constraint как обязательная NFR-категория (s2-ba). Topology-aware Auto-Heal (s4-devops, quality.md §5.5). Исправлены 3 нарушения изоляции в s3-dba.*

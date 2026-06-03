---
date: 2026-06-03
tags: [docs, getting-started]
---

# Руководство по первому запуску

> Claude SDLC Agents — автоматизированная SDLC-система на базе Claude Code.
> Этот документ проведёт тебя от установки до первого запущенного цикла.

---

## Содержание

1. [Предварительные требования](#1-предварительные-требования)
2. [Установка](#2-установка)
3. [Структура системы](#3-структура-системы)
4. [Первый проект — пошагово](#4-первый-проект--пошагово)
5. [Kickoff — ключевой шаг](#5-kickoff--ключевой-шаг)
6. [Обновление существующего проекта](#6-обновление-существующего-проекта)
7. [Цикл 1 — Разработка](#7-цикл-1--разработка)
8. [Типичные ошибки](#8-типичные-ошибки)
9. [Кастомизация под свой стек](#9-кастомизация-под-свой-стек)

---

## 1. Предварительные требования

| Компонент | Версия | Назначение |
|-----------|--------|-----------|
| [Claude Code CLI](https://claude.ai/code) | последняя | запуск агентов |
| `bash` | 4.0+ | лаунчер sdlc.sh |
| `pass` | любая | хранение секретов (обязательно) |
| [Obsidian](https://obsidian.md) | любая | просмотр артефактов (рекомендуется) |
| `git` | 2.x+ | синхронизация через s0-github |

### Установка pass (если не установлен)

```bash
# Ubuntu / Debian
sudo apt install pass

# macOS
brew install pass

# Инициализировать хранилище
gpg --gen-key               # создать GPG-ключ
pass init "your@email.com"  # инициализировать pass
```

---

## 2. Установка

### Вариант А — в Obsidian vault (рекомендуется)

```bash
# Создай структуру vault
mkdir -p ~/Documents/ObsidianVault/Claude
cd ~/Documents/ObsidianVault/Claude

# Клонируй агентов
git clone git@github.com:fr0sttr3000/Claude-SDLC-agents.git _agents
```

Открой папку `Claude/` в Obsidian как vault — все артефакты, Dashboard'ы и документация сразу видны в интерфейсе.

### Вариант Б — отдельная папка

```bash
git clone git@github.com:fr0sttr3000/Claude-SDLC-agents.git claude-sdlc
cd claude-sdlc/_agents
```

### Проверка установки

```bash
cd _agents
bash sdlc.sh
```

Должно появиться главное меню лаунчера. Если ошибка — проверь, что Claude Code CLI установлен: `claude --version`.

---

## 3. Структура системы

```
Claude/
├── _agents/                ← этот репозиторий
│   ├── sdlc.sh             ← главный лаунчер (запускай отсюда)
│   ├── localrun.sh         ← лаунчер Local Run
│   ├── _standards/         ← стандарты (читаются всеми агентами)
│   ├── _tools/             ← утилиты для всех циклов (s0-github, s0-secrets)
│   ├── plans/              ← планы развития системы
│   │   ├── principles.md   ← принципы разработки
│   │   └── roadmap.md      ← roadmap изменений
│   ├── cycle1-dev/         ← Цикл 1: Разработка
│   │   ├── s0-kickoff/     ← онбординг новых проектов
│   │   ├── s0-tracker/     ← трекинг спринтов и задач
│   │   ├── s0-validate/    ← валидация структуры
│   │   ├── s1-*/           ← этап 1: планирование
│   │   ├── s2-*/           ← этап 2: требования
│   │   ├── s3-*/           ← этап 3: дизайн
│   │   ├── s4-*/           ← этап 4: разработка
│   │   ├── s5-*/           ← этап 5: тестирование
│   │   └── l*/             ← Local Run (оснастка разработчика)
│   ├── cycle2-deploy/      ← Цикл 2: Деплой (s4-devops, s6-release)
│   └── cycle3-ops/         ← Цикл 3: Эксплуатация (s6-sre)
│
└── projects/               ← создаётся при добавлении проектов
    └── {PROJECT}/
        ├── Dashboard.md
        ├── stage1-planning/inputs/    ← входные данные (заполняет kickoff)
        ├── stage1-planning/outputs/   ← артефакты агентов
        ├── stage2-requirements/...
        └── tracking/                  ← спринты и задачи
```

> Подробнее об архитектуре — [[README#Архитектура]] · Принципы — [[plans/principles]]

---

## 4. Первый проект — пошагово

### Шаг 1. Запусти лаунчер

```bash
cd _agents
bash sdlc.sh
```

В Claude Code чате:
```
! bash "/полный/путь/до/_agents/sdlc.sh"
```

### Шаг 2. Создай проект

```
Главное меню → 3) Создать новый проект
```

Введи имя проекта (латиница, без пробелов, например `my-app`).

Лаунчер создаёт структуру `stage1..stage7` и сразу предлагает запустить Kickoff. **Соглашайся** — это ключевой шаг.

### Шаг 3. Пройди Kickoff-интервью

```
Главное меню → 0) Kickoff → 1) Новый проект
```

Агент `s0-kickoff` задаёт вопросы последовательно — 4 блока, ~15 вопросов. Отвечай подробно: чем точнее ответы, тем качественнее все последующие артефакты.

> Подробнее о Kickoff — в [разделе 5](#5-kickoff--ключевой-шаг).

### Шаг 4. Настрой секреты (если нужно)

```
Главное меню → 2) Один агент → s0-secrets → /add
```

Все секреты (API ключи, токены, пароли БД) хранятся только в `pass`. Агенты берут секреты через `pass sdlc/projects/{PROJECT}/ключ`.

### Шаг 5. Запусти Цикл 1 — Разработка

```
Главное меню → 1) Запустить цикл → 1) Разработка (Цикл 1) → выбери проект
```

Лаунчер спросит какие необязательные шаги включить (валидация структуры, инициализация спринта) — выбирай по потребности.

Цикл 1 пройдёт 22 шага последовательно. Каждый шаг — это отдельный агент, который читает артефакты предыдущего и создаёт свои. Деплой (Цикл 2) и эксплуатация (Цикл 3) — отдельные циклы, в разработке.

---

## 5. Kickoff — ключевой шаг

`s0-kickoff` решает главную проблему пустого проекта: агенты обрабатывают документы, но не собирают информацию через диалог. Kickoff заполняет этот пробел.

### Почему это важно

Без kickoff:
- `s1-pm` читает пустой `idea.md` → создаёт Feasibility Study на 100% предположениях
- `s2-ba` создаёт BRD без реальных требований → NFR не проходят Gate 2
- `s2-po` создаёт беклог из воздуха → истории не отражают реальных потребностей

С kickoff:
- Все 4 блока данных (продукт, бизнес, техника, приоритеты) заполнены
- Числовые NFR зафиксированы на этапе интервью (RPS, SLA, доступность)
- Scope Out определён заранее — не нужно переделывать беклог
- `s1-pm` получает богатый входной файл → качественный Feasibility Study

### Как работает интервью

Агент задаёт вопросы по одному, ждёт ответа:

```
Блок 1 из 4 — Продукт

Q1.1: Как называется проект?
> my-app

Q1.2: Опиши продукт одним предложением — что он делает и для кого?
> Платформа для управления задачами команды с интеграцией в Slack

Q1.3: Какую конкретную проблему он решает?
> ...
```

После каждого блока — резюме и подтверждение. Если ответ неточный — агент уточняет перед переходом дальше.

### Что создаёт Kickoff

**Режим NEW:**
```
stage1-planning/inputs/
  idea.md                           ← заполненный (не заглушка)
  PM-input-interview-YYYY-MM-DD.md  ← полный протокол интервью
```

После завершения: `s1-pm /feasibility` для проекта готов к запуску.

### Запуск Kickoff напрямую (без лаунчера)

```bash
cd _agents/cycle1-dev/s0-kickoff

# Новый проект
claude "/new my-project"

# Авто-определение
claude "/start my-project"
```

---

## 6. Обновление существующего проекта

Когда проект уже запущен и нужно обновить беклог, изменить приоритеты или добавить новые требования — используй `/refresh`.

### Запуск

```
Главное меню → 0) Kickoff → 2) Обновить существующий
```

Агент покажет текущий статус проекта:

```
Проект: my-app
─────────────────────────────────
Этап 1 (Планирование):  ✅ Done
Этап 2 (Требования):    ✅ Done
Этап 3 (Дизайн):        ✅ Done
Этап 4 (Разработка):    🔄 In Progress
...
Последние артефакты:
  - PO-2026-05-10-backlog.md (12 историй)
  - BA-2026-05-10-BRD.md
```

Затем предложит меню:

```
Что нужно обновить? (можно выбрать несколько через запятую)

  1) Продуктовое видение и OKR
  2) Новые функции в беклог
  3) Приоритизация беклога
  4) Изменение NFR / масштаба / SLA
  5) Scope Out — что убираем
  6) Полный перезапуск (новое интервью)
```

### Что создаёт Refresh

```
stage1-planning/inputs/
  PM-input-refresh-YYYY-MM-DD.md   ← изменения в видении/OKR (если выбраны 1)

stage2-requirements/inputs/
  BA-input-refresh-YYYY-MM-DD.md   ← новые требования/NFR/scope (если выбраны 2-5)
```

После Refresh — запусти соответствующих агентов:
- Видение изменилось → `s1-pm /vision`
- Новые функции → `s2-ba` + `s2-po /stories`
- Только приоритеты → `s2-po /stories`

---

## 7. Цикл 1 — Разработка

> Деплой (Цикл 2) и эксплуатация (Цикл 3) — отдельные циклы в реальной среде, в разработке. Цикл 1 производит код и всю документацию.

### Структура Цикла 1 (22 шага)

```
[Онбординг]  s0-kickoff             → idea.md + PM-input-interview.md

Этап 1: Планирование
  Шаг  1   s1-pm /feasibility       → PM-feasibility.md (вердикт Go/No-Go)
  Шаг  2   s1-pm /vision            → PM-vision.md (OKR, North Star)
  Шаг  3   s1-pmo /charter          → PMO-charter.md
  Шаг  4   s1-pmo /risks            → PMO-risk-register.md
  Шаг  5   s1-finance               → FIN-business-case.md
            ── Quality Gate 1 ──►

Этап 2: Требования
  Шаг  6   s2-ba /extract-requirements → BA-BRD.md (черновик)
  Шаг  7   s2-ba /brd               → BA-BRD.md + BA-NFR.md + BA-RTM.md
  Шаг  8   s2-po /stories           → PO-backlog.md
  Шаг  9   s2-qa-req                → QA-REQ-review.md (Gate 2 блокируется BLOCKER)
            ── Quality Gate 2 ──►

Этап 3: Дизайн
  Шаг 10   s3-arch /hld             → ARCH-HLD.md + ARCH-api-spec.yaml
  Шаг 11   s3-arch /adr             → ARCH-ADR-*.md
  Шаг 12   s3-security              → SEC-threat-model.md (Critical/High блокируют Gate 3)
  Шаг 13   s3-rbac /rbac-model      → RBAC-model.md + RBAC-matrix.md + RBAC-schema.sql
  Шаг 14   s3-dba /schema           → DBA-schema.sql + DBA-migrations/
            ── Quality Gate 3 ──►

Этап 4: Разработка
  Шаг 15   s4-dev                   → код + DEV-update-notes-PR[N].md
  Шаг 16   s4-techlead              → TL-review-PR[N].md (Gate 4 блокируется BLOCKER)
            ── Quality Gate 4 ──►

Этап 5: Тестирование
  Шаг 17   s5-qa /test-plan         → QA-test-plan.md
  Шаг 18   s5-qa-auto               → E2E/API тесты (coverage ≥95%)
  Шаг 19   s5-perf                  → PERF-load-report.md
  Шаг 20   s5-qa /go-no-go          → QA-go-no-go.md (Gate 5)
            ── Quality Gate 5 ──►

Финал
  Шаг 21   s0-tracker /report       → цикл-план vs факт
  Шаг 22   s0-github /push          → push артефактов в GitHub
```

### Quality Gates — что блокирует переход

| Gate | Блокирующие условия |
|------|-------------------|
| Gate 1→2 | Нет Feasibility Study / Charter / Risk Register |
| Gate 2→3 | BLOCKER в QA-REQ-review / NFR без чисел / нет RTM |
| Gate 3→4 | Critical/High в Threat Model / нет RBAC artifacts / нет DB schema |
| Gate 4→5 | Открытые PR / coverage < 80% / BLOCKER в code review / нет Update Notes |
| Gate 5→6 | Go/No-Go = NO-GO / UAT не пройден / PERF FAIL |
| Gate 6→PROD | Нет Release Checklist / Rollback план не проверен |
| Gate 7 | Auto-Heal не подтверждён / SLO breach без алерта |

---

## 8. Типичные ошибки

### "Агент пишет только предположения [ASSUMPTION]"
**Причина:** Kickoff не запущен или `idea.md` заполнен как заглушка.
**Решение:** `sdlc.sh → 0) Kickoff → /new` → пройди интервью полностью.

### "Gate X не пройден"
**Причина:** Предыдущий агент не создал обязательный артефакт.
**Решение:** Проверь `stage{N}-*/outputs/` — найди какой файл отсутствует. Запусти нужного агента напрямую.

### "SettingsError при загрузке .env"
**Причина:** `list[int]` в `.env` в CSV-формате: `IDS=1,2,3` вместо `IDS=[1,2,3]`.
**Решение:** Исправить `.env` — JSON-формат для всех list/set/frozenset. Подробнее: `_standards/data-formats.md §2.2`.

### "asyncpg ошибка timezone"
**Причина:** `datetime` без timezone передаётся в поле `TIMESTAMP WITH TIME ZONE`.
**Решение:** Добавить `tzinfo=timezone.utc` к datetime объектам. ORM: использовать `mapped_column(TIMESTAMP(timezone=True))`.

### "Агент не видит артефакты предыдущего"
**Причина:** Передаётся относительный путь, а не абсолютный.
**Решение:** Используй абсолютные пути вида `/home/.../projects/{PROJECT}/stage{N}/outputs/`.

---

## 9. Кастомизация под свой стек

### Ознакомься с принципами системы

Перед стартом прочитай [`plans/principles.md`](plans/principles.md) — принципы разработки (SDD, TDD, Shift Left, Quality Gates и др.).

### Заполни стандарты компании

```bash
# Заполни перед первым использованием
nano _agents/_standards/company.md
```

Укажи:
- Технологический стек (Python, Go, TypeScript, etc.)
- Роли в команде и ставки (для финансовых расчётов)
- Compliance-требования (если есть)

> Методология разработки — в [`plans/principles.md`](plans/principles.md), не в `company.md`.

### Настрой NFR-дефолты

В `_standards/quality.md` измени дефолты под свои нужды:
```markdown
## NFR-дефолты
- Availability: ≥ 99.9%           ← измени если нужно
- Response time p95: < 500 ms     ← измени если нужно
- Test coverage: ≥ 80%            ← измени если нужно
```

### Добавь необязательные шаги в sdlc.sh

В `sdlc.sh` в массиве `OPTIONAL_AGENTS_DEF` добавь нужные шаги:
```bash
"agent-name|/command|before|Описание шага"
```

### Прямой запуск агента (без лаунчера)

```bash
cd _agents/cycle1-dev/s1-pm
claude "начни сессию"                        # интерактивный режим
claude "/feasibility проект: my-app"         # slash-команда
claude --continue                            # продолжить последний диалог
```

---

## Краткая шпаргалка

```bash
# Первый запуск
bash sdlc.sh → 3) новый проект → 0) Kickoff /new → 1) Запустить цикл → 1) Разработка

# Обновить беклог существующего проекта
bash sdlc.sh → 0) Kickoff → 2) /refresh

# Запустить один агент
bash sdlc.sh → 2) один агент → выбрать → выбрать проект

# Проверить структуру проекта
bash sdlc.sh → 6) валидация → /validate

# Прямой запуск агента
cd _agents/cycle1-dev/s0-kickoff && claude "/new my-project"
cd _agents/cycle1-dev/s1-pm && claude "/feasibility my-project"
```

---

*Claude SDLC Agents — [README](README.md) · [OVERVIEW](OVERVIEW.md) · [CHANGELOG](CHANGELOG.md)*

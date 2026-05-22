---
date: 2026-05-22
version: 1.5.0
tags: [release, quality, dor, dod, isolation]
---

# Release Notes — v1.5.0

**Дата:** 2026-05-22
**Тип:** Feature + Quality + Bug Fix

---

## Что нового

### Definition of Ready (DoR) — полная реализация 7 лучших практик

До этого релиза DoR существовал только у части агентов и не имел системных гарантий. Теперь DoR охватывает весь SDLC-цикл по 7 практикам:

| Практика | Суть |
|----------|------|
| П1 — Авто-проверка | Скрипт `dor-check.sh` проверяет DoR-1..8 автоматически перед каждым Gate |
| П2 — Контракт между агентами | DoD-10 (артефакт в outputs/) = DoR-1 следующего этапа автоматически удовлетворён |
| П3 — Дедлайн | Каждый DoR-пункт имеет этап-скоуп, владельца и верификатора |
| П4 — Масштаб | DoR применяется ко всем 6 transitions (Gate 1–6 + Gate 7) |
| П5 — Бинарность | Нет "почти готово". Если хоть один DoR-пункт не выполнен → этап не стартует |
| П6 — Change Request | `/cr` mode в s0-kickoff: интервью → таблица влияния → сброс DoR-пунктов → CR-файл |
| П7 — Журнал нарушений | `tracking/dor-violations.md`: записывает каждый возврат с причиной и статусом |

**Новые DoR-секции добавлены в агентов:**
- `s3-arch` — DoR Gate 2 (BRD + NFR + QA-REQ review с 0 BLOCKER)
- `s5-qa` — DoR Gate 4 (все PR закрыты + coverage ≥80% + SAST + DoD-11)
- `s6-release` — DoR Gate 5 (go-no-go PASSED + UAT sign-off + PERF PASS)
- `s6-sre` — DoR Gate 6 (checklist + release notes) + Gate 7 (monitoring + auto-heal + SLO)

---

### Definition of Done (DoD) — 8 лучших практик

| Практика | Суть |
|----------|------|
| П1 — Каждая задача | DoD обязателен для всех задач, без исключений |
| П2 — Единый список | 11 пунктов в одном месте (`quality.md`) — ни один агент не добавляет свои |
| П3 — Авто-проверка | `dod-check.sh` проверяет DoD-1,2,3,5,6,8,10,11 автоматически |
| П4 — Бинарность | Нет "Done minus docs". IN_PROGRESS до выполнения всех применимых пунктов |
| П5 — По типу артефакта | Тип **К** (Код — все 11) / **Д** (Документ — 6 пунктов) / **И** (Инфраструктура — 9 пунктов) |
| П6 — Связь с DoR | DoD-10 completion = DoR-1 следующего Gate автоматически выполнен |
| П7 — Владелец | Каждый DoD-пункт имеет явного верификатора (s4-techlead / s5-qa / агент-получатель) |
| П8 — Техдолг | Осознанный пропуск DoD → фиксация в `tracking/tech-debt.md` с планом устранения |

---

### Автоматические скрипты проверки

**`s0-validate/dor-check.sh`** — DoR auto-check перед Gate N:
```bash
bash dor-check.sh /path/to/project <GATE>
# GATE: 1..6
```
Проверяет: DoR-1 (артефакты), DoR-2 (размытые формулировки), DoR-3 (Given/When/Then),
DoR-4 (числовые NFR), DoR-5 (0 BLOCKER), DoR-7 (threat-model), DoR-8 (rollback).
При FAIL → напоминает зафиксировать в `tracking/dor-violations.md`.

**`s0-validate/dod-check.sh`** — DoD auto-check для артефакта/PR:
```bash
bash dod-check.sh /path/to/project <K|D|I> <STAGE> [PR_NUM]
```
Проверяет DoD-1,2,3,5,6,8,10,11 автоматически. DoD-4,7,9 — ⚠️ ручная проверка.
При FAIL → напоминает зафиксировать в `tracking/tech-debt.md`.

---

### Change Request (`s0-kickoff /cr`)

Когда требования меняются в середине активного этапа:

```bash
cd s0-kickoff && claude "/cr my-project"
```

1. Интервью (4 блока): что изменилось / конкретно до-после / причина / срочность
2. Анализ влияния: таблица затронутых этапов → сброшенные DoR-пункты → что переделать
3. Выход: `stage{N}/inputs/CR-YYYY-MM-DD-[N]-input.md`
4. Запись в `tracking/dor-violations.md`
5. Пользователь вручную перезапускает затронутых агентов

---

### Новые шаблоны в `_standards/`

- `dor-violations-template.md` — шаблон журнала нарушений DoR для каждого проекта
- `tech-debt-template.md` — шаблон журнала технического долга с полями: причина, кто одобрил, план, дедлайн, статус

---

### Обновления `s0-tracker`

- `/sprint-init` создаёт `tracking/dor-violations.md` и `tracking/tech-debt.md` при первом запуске
- `/sprint-init` показывает сводку открытого Tech Debt
- `/sprint-close` блокируется при наличии просроченных TD-записей
- >3 открытых TD блокируют инициализацию следующего спринта

---

## Исправления

### 8 нарушений изоляции агентов

Принцип изоляции: агенты не взаимодействуют напрямую. Данные передаются только через файлы в `projects/`. Пользователь — единственный оркестратор.

| # | Где | Было (нарушение) | Стало (правильно) |
|---|-----|-------------------|-------------------|
| 1 | quality.md DoR | "вернуть задачу агенту S{N}" | "записать в dor-violations.md, сообщить пользователю" |
| 2 | quality.md DoR | "агент сигнализирует поставщику" | "пользователь перезапускает агента" |
| 3 | quality.md DoR | "передать обратно в S{N}" | "зафиксировать нарушение → пользователь решает" |
| 4 | quality.md DoR | "уведомить агента предыдущего этапа" | "записать в dor-violations.md, ждать пользователя" |
| 5 | quality.md DoR | "S{N} возвращает работу S{N-1}" | "пользователю перезапустить S{N-1}" |
| 6 | quality.md DoD | "передан следующему агенту" (DoD-10) | "записан в outputs/ текущего этапа" |
| 7 | quality.md DoD | "фиксирует нарушение DoD-10 поставщика" | "записывает в dor-violations.md, сообщает пользователю. Агенты не взаимодействуют напрямую" |
| 8 | dod-check.sh | "не передан следующему агенту" | "не записан в outputs/ текущего этапа" |

---

## Обновлённые файлы

| Файл | Изменение |
|------|-----------|
| `_standards/quality.md` | DoR: 7 практик, binary rule, матрица применимости, CR-reset, return rule. DoD: 8 практик, типы К/Д/И, DoD→DoR link table, tech debt rule |
| `_standards/dor-violations-template.md` | **новый** — шаблон журнала возвратов |
| `_standards/tech-debt-template.md` | **новый** — шаблон журнала техдолга |
| `s0-validate/dor-check.sh` | **новый** — bash auto-check DoR-1..8 |
| `s0-validate/dod-check.sh` | **новый** — bash auto-check DoD-1..11 по типам К/Д/И |
| `s0-validate/CLAUDE.md` | Добавлены команды `/dor-check` и `/dod-check` |
| `s0-kickoff/CLAUDE.md` | Добавлен режим `/cr` (Change Request) |
| `s0-tracker/CLAUDE.md` | Tech Debt tracking: sprint-init, sprint-close, TD-лимит |
| `s3-arch/CLAUDE.md` | DoR Gate 2 |
| `s5-qa/CLAUDE.md` | DoR Gate 4 |
| `s6-release/CLAUDE.md` | DoR Gate 5 |
| `s6-sre/CLAUDE.md` | DoR Gate 6 + Gate 7 |
| `CHANGELOG.md` | Добавлена запись v1.5.0 |
| `OVERVIEW.md` | DoD-таблица, s0-validate, s0-kickoff, s0-tracker, _standards/, tracking/ |
| `README.md` | DoD-таблица с типами, s0-validate команды, s0-kickoff /cr, _standards/ |

---

## Upgrade Notes

Никаких breaking changes. Существующие проекты продолжают работать без изменений.

**Для новых проектов:**
`s0-tracker /sprint-init` теперь автоматически создаёт `tracking/dor-violations.md` и `tracking/tech-debt.md`.

**Для существующих проектов:**
Создать эти файлы вручную на основе шаблонов из `_standards/`:
```bash
cp "_agents/_standards/dor-violations-template.md" "projects/{PROJECT}/tracking/dor-violations.md"
cp "_agents/_standards/tech-debt-template.md"      "projects/{PROJECT}/tracking/tech-debt.md"
```

**Авто-проверки DoR/DoD** доступны немедленно через `s0-validate`:
```bash
cd s0-validate && claude "/dor-check my-project 3"
cd s0-validate && claude "/dod-check my-project K 4 42"
```

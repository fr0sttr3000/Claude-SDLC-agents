---
date: 2026-05-23
tags: [release, v1.7.1, patch]
version: 1.7.1
---

# Release Notes — v1.7.1

**Тип:** Patch (исправление багов + недостающие шаги цикла)
**Дата:** 2026-05-23
**Ветка:** fix/launcher-v1.7.1
**Базируется на:** v1.7.0

---

## Что изменилось

### Добавлено

#### `sdlc.sh` — s3-arch:/adr теперь в обязательном цикле

Команда `/adr` существовала в агенте `s3-arch` с версии v1.4.0, но никогда не запускалась в автоматизированном цикле `sdlc.sh`. ADR (Architecture Decision Records) — обязательный артефакт по стандарту SDLC.

**Было:** цикл пропускал `/adr`, агент `s4-dev` мог не получить ADR-матрицу решений.
**Стало:** `/adr` запускается сразу после `/hld` как шаг 11, ADR генерируется автоматически.

Цикл расширен: **26 → 27 обязательных шагов**.

#### `sdlc.sh` — s6-sre:/gate7 как необязательный шаг

Gate 7 (мониторинг + auto-heal + SLO Review) выполняется через 7 дней после деплоя — его нельзя включить в линейный автоматизированный цикл. Добавлен как опциональный шаг в toggle-меню:

```
[opt] s6-sre /gate7 — Gate 7: мониторинг + auto-heal + SLO Review (через 7 дней после деплоя)
```

Включается пользователем через меню необязательных шагов перед стартом полного цикла.

---

### Исправлено

#### `localrun.sh` — изоляция L-агентов (критический баг)

**Проблема:** `run_agent` в `localrun.sh` запускал `claude` без `AGENT_DIR` и без `env -u` флагов — в отличие от аналогичной функции в `sdlc.sh`.

Последствия:
- L-агенты (`l1-analyze`, `l2-setup`, `l3-build`, `l4-run`) не получали `AGENT_DIR` → не могли строить абсолютные пути к файлам своей директории
- `claude` запускался как вложенный вызов внутри родительской сессии Claude Code (без очистки `CLAUDECODE`, `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_ENTRYPOINT`)

**Исправление:** все 5 точек запуска claude в `run_agent` приведены к стандарту `sdlc.sh`:

```bash
# Было:
(cd "$agent_dir" && claude "$claude_arg")

# Стало:
(cd "$agent_dir" && AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT claude "$claude_arg")
```

---

## Затронутые файлы

| Файл | Тип изменения |
|------|--------------|
| `sdlc.sh` | Added: /adr в CYCLE_AGENTS, gate7 в OPTIONAL_AGENTS_DEF |
| `localrun.sh` | Fixed: AGENT_DIR + env -u для всех 5 вызовов claude |
| `CHANGELOG.md` | Added: секция v1.7.1 |
| `OVERVIEW.md` | Updated: счётчики шагов, нумерация, optional gate7 |
| `README.md` | Updated: "24 шага" → "27 шагов" |

---

## Обновление

```bash
git pull origin main
# или
bash sdlc.sh   # уже включает все исправления
```

---

## Совместимость

Полная обратная совместимость. Новых зависимостей нет. Существующие проекты не затронуты.

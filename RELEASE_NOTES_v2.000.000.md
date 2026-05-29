---
date: 2026-05-29
tags: [release, v2.000.000, major]
version: 2.000.000
---

# Release Notes — v2.000.000

**Тип:** Major — архитектурная реструктуризация
**Дата:** 2026-05-29
**Базируется на:** v1.7.1

---

## Что изменилось

### Архитектура: 3 цикла вместо монолитного SDLC

Система переработана с одного линейного цикла на три независимых цикла с разными средами выполнения:

| Цикл | Суть | Среда |
|------|------|-------|
| Цикл 1 — Dev | Разработка: код, тесты, документация | Локальная |
| Цикл 2 — Deploy | Деплой кода в любую нужную среду | Реальная |
| Цикл 3 — Ops | Эксплуатация задеплоенного кода | Реальная (прод) |

Агенты `s4-devops`, `s6-release` перемещены в Цикл 2. `s6-sre` — в Цикл 3.

---

### Реструктуризация директорий агентов

**Было:** все агенты в плоской структуре `_agents/s*`, `_agents/l*`

**Стало:**
```
_agents/
  _tools/          ← s0-github, s0-secrets (утилиты для всех циклов)
  cycle1-dev/      ← 19 агентов Цикла 1 (s0-kickoff/tracker/validate, s1-s5, l1-l4)
  cycle2-deploy/   ← s4-devops, s6-release
  cycle3-ops/      ← s6-sre
  plans/           ← планы развития системы (новая папка)
```

---

### Новое: папка `plans/`

Добавлена папка для планов развития системы:

- `plans/principles.md` — принципы проекта (3 цикла, SDD, TDD, Shift Left, Markdown-first, Obsidian, Secrets via pass, Quality Gates только вверх, DoR/DoD, Трассируемость)
- `plans/roadmap.md` — roadmap изменений системы: новые агенты, рефакторинг, долгосрочные планы

---

### Обновлён `sdlc.sh` и `localrun.sh`

Добавлена функция `find_agent_dir()` — поиск агента по имени в подпапках цикла. Прямые пути `$AGENTS/$agent` заменены на динамический поиск:

```bash
find_agent_dir() {
  for subdir in cycle1-dev cycle2-deploy cycle3-ops _tools; do
    dir="$AGENTS/$subdir/$agent"
    [[ -d "$dir" ]] && echo "$dir" && return
  done
}
```

---

### Исправлено: нарушения изоляции агентов

- `s0-validate/CLAUDE.md` — исправлены пути к `dod-check.sh` и `dor-check.sh`
- `s0-kickoff/CLAUDE.md` — исправлен путь к `s1-pm`

---

### Обновлён `_standards/company.md`

- Удалена секция "Методология разработки" (перенесена в `plans/principles.md`)
- Исправлена ссылка на секреты: `_secrets/env.sh` → `pass`
- Добавлены ссылки на `plans/principles.md`

---

### Добавлен DoD для `s0-tracker`

Агент `s0-tracker` не имел явного Definition of Done. Добавлены DoD для трёх операций: закрытие спринта (`/sprint-close`), завершение задачи (`/task-done`), создание отчёта (`/report`).

---

### Обновлена документация

Обновлены все основные документы с перекрёстными ссылками:

| Файл | Изменения |
|------|-----------|
| `CLAUDE.md` | Обновлена структура vault (cycle1/2/3, _tools, plans) |
| `README.md` | Архитектура, SDLC-цикл (3 цикла), каталог агентов, советы, футер |
| `OVERVIEW.md` | Структура директорий, пути агентов |
| `GETTING_STARTED.md` | Раздел 9: ссылка на `principles.md`, пути агентов |

---

## Затронутые файлы

| Файл | Тип изменения |
|------|--------------|
| `sdlc.sh` | Updated: `find_agent_dir()` |
| `localrun.sh` | Updated: `find_agent_dir()` |
| `_standards/company.md` | Updated: убрана методология, исправлены секреты |
| `cycle1-dev/s0-validate/CLAUDE.md` | Fixed: пути к скриптам |
| `cycle1-dev/s0-kickoff/CLAUDE.md` | Fixed: путь к s1-pm |
| `cycle1-dev/s0-tracker/CLAUDE.md` | Added: DoD |
| `plans/principles.md` | Added: новый файл |
| `plans/roadmap.md` | Added: новый файл |
| `CLAUDE.md` | Updated: структура |
| `README.md` | Updated: архитектура, циклы, каталог |
| `OVERVIEW.md` | Updated: структура директорий |
| `GETTING_STARTED.md` | Updated: секция 9 |

---

## Обратная совместимость

Существующие проекты в `projects/` не затронуты. Структура `stage1-stage7` не изменилась.

Если использовались прямые пути к агентам вида `cd _agents/s1-pm` — обновить на `cd _agents/cycle1-dev/s1-pm`.

---

## Обновление

```bash
git pull origin main
bash sdlc.sh   # find_agent_dir() автоматически найдёт агентов в новой структуре
```

---
date: 2026-05-11
version: 1.4.0
tags: [release, skills, bugfix]
---

# Release Notes — v1.4.0

**Дата:** 2026-05-11
**Тип:** Feature + Bug Fix

---

## Что нового

### 18 новых slash-команд для 11 агентов

До этого релиза 11 из 27 агентов не имели slash-команд и требовали задачи в виде свободного текста. Теперь **все агенты** работают через slash-команды.

| Агент | Новые команды |
|-------|--------------|
| `s1-finance` | `/business-case` |
| `s2-qa-req` | `/testability-review` |
| `s3-dba` | `/schema`, `/migration` |
| `s3-security` | `/threat-model` |
| `s4-dev` | `/dev-report`, `/update-notes` |
| `s4-techlead` | `/review` |
| `s4-devops` | `/pipeline`, `/runbook` |
| `s5-qa` | `/test-plan`, `/go-no-go` |
| `s5-qa-auto` | `/e2e-report` |
| `s5-perf` | `/load-test` |
| `s6-sre` | `/post-deploy`, `/gate7` |

Каждая команда содержит:
- Точный список файлов для чтения (inputs)
- Структуру выходного артефакта с форматом
- Gate checklist с критериями завершения
- Вердикт / решение (где применимо)

### Полный цикл теперь работает на slash-командах

`CYCLE_AGENTS` в `sdlc.sh` переведён полностью на `/slash-команды`. Добавлены три новых шага которых раньше не было в автоматическом цикле:
- **s4-devops `/runbook`** — Runbook деплоя с rollback-процедурой
- **s6-release `/release-notes`** — Release Notes
- **s6-sre `/gate7`** — Gate 7 (SLO Review + Auto-Heal)

Цикл расширен с 23 до 26 обязательных шагов.

---

## Исправления

### Баг: агенты периодически покидали свою рабочую директорию

**Проблема:** bash-состояние в Claude Code персистентно в рамках сессии. Если агент выполнял `cd /some/project && git log`, рабочая директория менялась для всех последующих bash-вызовов — агент «уходил» из своей папки.

**Исправление:**
- В `sdlc.sh` все точки запуска агентов теперь экспортируют `AGENT_DIR="$agent_dir"` — агент знает свою домашнюю директорию.
- В глобальный `CLAUDE.md` добавлен раздел «Рабочая директория» с правилом:

  ```bash
  # ✅ Правильно — cwd не меняется
  (cd /some/project && git log)

  # ❌ Неправильно — cwd меняется для всех последующих вызовов
  cd /some/project && git log
  ```

---

## Обновлённые файлы

| Файл | Изменение |
|------|-----------|
| `sdlc.sh` | CYCLE_AGENTS → slash-команды; экспорт AGENT_DIR |
| `CLAUDE.md` | Раздел «Рабочая директория» с правилом подоболочки |
| `CHANGELOG.md` | Добавлена запись v1.4.0 |
| `README.md` | Таблицы агентов обновлены: slash-команды вместо *(задача текстом)* |
| `OVERVIEW.md` | Шаги цикла обновлены: номера шагов и slash-команды |
| `s1-finance/.claude/commands/business-case.md` | новый |
| `s2-qa-req/.claude/commands/testability-review.md` | новый |
| `s3-dba/.claude/commands/schema.md` | новый |
| `s3-dba/.claude/commands/migration.md` | новый |
| `s3-security/.claude/commands/threat-model.md` | новый |
| `s4-dev/.claude/commands/dev-report.md` | новый |
| `s4-dev/.claude/commands/update-notes.md` | новый |
| `s4-techlead/.claude/commands/review.md` | новый |
| `s4-devops/.claude/commands/pipeline.md` | новый |
| `s4-devops/.claude/commands/runbook.md` | новый |
| `s5-qa/.claude/commands/test-plan.md` | новый |
| `s5-qa/.claude/commands/go-no-go.md` | новый |
| `s5-qa-auto/.claude/commands/e2e-report.md` | новый |
| `s5-perf/.claude/commands/load-test.md` | новый |
| `s6-sre/.claude/commands/post-deploy.md` | новый |
| `s6-sre/.claude/commands/gate7.md` | новый |

---

## Upgrade Notes

Никаких breaking changes. Существующие проекты продолжают работать без изменений.

Если используете `sdlc.sh` для запуска полного цикла — теперь будет предложено 26 шагов вместо 23.

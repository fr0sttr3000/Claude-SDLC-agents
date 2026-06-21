---
description: Провести Code Review PR (Gate 4 — блокирует релиз без полного DoD)
---

Проведи Code Review для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/ARCH-ADR-*.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/DEV-*-update-notes-*.md (все)

Уточни у пользователя: какой PR ревьюируем и где находится код.

Создай файл TL-[дата]-review-PR[N].md в:
$SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/

# Code Review — PR #[N] — $ARGUMENTS
Дата: [сегодня]
Агент: s4-techlead

## Замечания
Формат: [BLOCKER/MAJOR/MINOR/SUGGESTION/QUESTION/PRAISE] файл:строка описание

### [BLOCKER] — блокируют merge
[список]

### [MAJOR] — требуют исправления в этом PR
[список]

### [MINOR] / [SUGGESTION]
[список]

### [PRAISE] — отметить хорошее
[список]

## Антипаттерны из prod — обязательная проверка
□ CR-01 [BLOCKER] `server_default=func.cast(...)` — только строковый литерал
□ [BLOCKER] datetime без `TIMESTAMP(timezone=True)` в SQLAlchemy
□ [BLOCKER] Функциональный индекс на STABLE/VOLATILE функции
□ CR-02 [BLOCKER] `callback.message.bot` без инъекции бота как параметра
□ CR-03 [MAJOR] Scheduler-функции без guard `if _bot is None: return`
□ CR-04 [MAJOR] Markdown v1 в Telegram-хэндлерах — использовать HTML
□ [MAJOR] pydantic-settings validator не обрабатывает list/set/frozenset
□ [MAJOR] `fileConfig(disable_existing_loggers=True)` в migrations/env.py
□ [BLOCKER] `assert` в production-коде (вне тестов) — отключается `python -O` → только `if` + `raise`
□ [MINOR] Неиспользуемые импорты после рефакторинга — удалять

## DoD Checklist — Gate 4
□ Бизнес-логика соответствует Acceptance Criteria
□ Edge cases покрыты
□ Security: нет открытых уязвимостей
□ Performance: нет N+1 queries
□ Error handling: нет bare except/pass
□ SOLID: SRP соблюдён, функции ≤ 20 строк, complexity ≤ 10
□ Дублирование на новом коде ≤ 3% (DoD-1, §3)
□ Unit branch ≥ 80% изм. кода + mutation ≥ 60% критичных модулей (§3.1)
□ Integration-тест для каждого внешнего адаптера; contract-тест если PR трогает API (§3.1)
□ DEV-*-update-notes-PR[N].md существует
□ README / API-spec / docstring / CHANGELOG обновлены
□ SAST прошёл без Critical/High

## РЕШЕНИЕ
✅ **APPROVED** — PR готов к merge
⚠️ **APPROVED WITH COMMENTS** — merge после исправления MINOR
❌ **CHANGES REQUESTED** — есть BLOCKER или MAJOR

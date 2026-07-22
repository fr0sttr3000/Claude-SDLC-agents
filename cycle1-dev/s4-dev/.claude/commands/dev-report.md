---
description: Выполнить Green/Repair по Red tests и создать Dev Report
---

Выполни Green/Repair и затем создай Dev Report для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/tdd.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/quality-gates.md
4. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/QA-TDD-status.md
5. Red tests и test command из QA TDD evidence
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-*-HLD.md и API spec (если применимо)
7. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/PO-*-backlog.md и BA-RTM

Если `QA-TDD-status.md` не содержит `status: RED` для первой реализации либо `status: FAIL`
для Repair — BLOCKED. Не меняй тесты/AC ради Green. В каталоге кода реализуй минимальный Green
или точечный Repair, запусти только developer-side checks и оставь независимый итоговый Run
агенту `s4-qa-auto`.

Создай файл DEV-[дата]-PR-[N]-summary.md в:
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/

# Dev Report — PR #[N] — $ARGUMENTS
Дата: [сегодня]
Агент: s4-dev

## Что реализовано
[Список завершённых задач со ссылками на User Stories]

## Технические решения
[Ключевые архитектурные и технические решения принятые в PR]

## Покрытие тестами (quality.md §3.1)
- Unit branch coverage: [%] (изм. кода, ≥ 80%)
- Mutation score (критичные модули): [%] (≥ 60%, порог по tier)
- Integration/component: [адаптеры с тестами: БД / API-клиент / очередь]
- Contract (consumer-driven): [API-контракты с тестами, сверка с api-spec]
- Изменённые модули: [список]
- Новые тесты: [список]

## Security Checklist
□ Все вводы валидируются
□ Только parameterized queries
□ Нет секретов в коде
□ Авторизация на каждом endpoint

## Definition of Done — Gate 4
□ Код написан и проходит все тесты
□ Unit: branch ≥ 80% изм. кода + mutation ≥ 60% критичных модулей (§3.1)
□ Integration-тест для каждого внешнего адаптера; contract-тест если PR трогает API (§3.1)
□ SAST/secrets-scan: 0 Critical/High
□ Нет игнорированных исключений (bare except/pass)
□ README обновлён (если изменились команды/env/конфигурация)
□ API-spec обновлён (если менялись endpoints)
□ CHANGELOG/release notes не изменялись: они принадлежат release preparation
□ Update Notes созданы: DEV-*-update-notes-PR[N].md
□ Нет хардкода ролей в бизнес-логике

## Известные ограничения / Tech Debt
[Что намеренно отложено с обоснованием]

## Следующие шаги
→ s4-techlead: /review для этого PR

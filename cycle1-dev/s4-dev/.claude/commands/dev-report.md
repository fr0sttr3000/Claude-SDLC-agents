---
description: Создать Dev Report по завершённому PR / спринту
---

Создай Dev Report для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/ARCH-HLD.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/PO-backlog.md

Создай файл DEV-[дата]-PR-[N]-summary.md в:
$SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/

# Dev Report — PR #[N] — $ARGUMENTS
Дата: [сегодня]
Агент: s4-dev

## Что реализовано
[Список завершённых задач со ссылками на User Stories]

## Технические решения
[Ключевые архитектурные и технические решения принятые в PR]

## Покрытие тестами
- Unit coverage: [%]
- Изменённые модули: [список]
- Новые тесты: [список]

## Security Checklist
□ Все вводы валидируются
□ Только parameterized queries
□ Нет секретов в коде
□ Авторизация на каждом endpoint

## Definition of Done — Gate 4
□ Код написан и проходит все тесты
□ Unit coverage ≥ 80% изменённого кода
□ SAST/secrets-scan: 0 Critical/High
□ Нет игнорированных исключений (bare except/pass)
□ README обновлён (если изменились команды/env/конфигурация)
□ API-spec обновлён (если менялись endpoints)
□ CHANGELOG.md обновлён
□ Update Notes созданы: DEV-*-update-notes-PR[N].md
□ Нет хардкода ролей в бизнес-логике

## Известные ограничения / Tech Debt
[Что намеренно отложено с обоснованием]

## Следующие шаги
→ s4-techlead: /review для этого PR

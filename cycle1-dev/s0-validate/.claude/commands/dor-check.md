---
description: Выполнить автоматизируемую часть DoR для Gate 1..6
---

Проверь DoR проекта из $ARGUMENTS. Аргументы: `<PROJECT> <GATE 1..6>`.
Если Gate не указан, сначала спроси его; не угадывай.

Запусти канонический validator:
`bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/dor-check.sh" "$SDLC_PROJECTS_DIR/<PROJECT>" <GATE>`.

Перед запуском покажи точный project path и gate. Не изменяй project artifacts.
Exit 1 означает BLOCKED и требует записи владельцем workflow в `tracking/dor-violations.md`;
exit 2 означает некорректный вызов. Авто-PASS не заменяет ручной DoR-6/semantic review.

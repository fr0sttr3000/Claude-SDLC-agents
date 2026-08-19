---
description: Выполнить автоматизируемую часть DoR для active Gate 1..5
---

Проверь DoR проекта из $ARGUMENTS. Аргументы: `<PROJECT> <GATE 1..5>`.
Если Gate не указан, сначала спроси его; не угадывай.

Запусти канонический validator:
`bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/dor-check.sh" "$SDLC_PROJECTS_DIR/<PROJECT>" <GATE>`.

Перед запуском покажи точный project path и gate. Не изменяй project artifacts.
Exit 1 означает BLOCKED и требует записи владельцем workflow в `tracking/dor-violations.md`;
exit 2 означает некорректный вызов. Авто-PASS не заменяет ручной DoR-6/semantic review.
Для Gate 4 `QA-TDD-status.md` передаёт exact source identity, но его свободный `PASS` не
закрывает gate: обязательны verified PR Evidence v1, SG3 policy и executor controls. Для других
machine verdicts Markdown также не заменяет применимый versioned evidence contract.

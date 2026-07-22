---
description: Запустить TDD и regression тесты после реализации
---

Для проекта $ARGUMENTS прочитай QA-TDD-status.md и QA-*-tdd-report.md. Запусти
точную сохранённую test command и весь затронутый regression set.

Обнови QA-TDD-status.md:
- PASS, если все обязательные тесты прошли;
- FAIL с failed_tests и причинами, если реализация требует ремонта;
- BLOCKED, если тесты невозможно корректно запустить.

Не меняй production-код и не ослабляй тесты.

---
description: Запустить TDD и regression тесты после реализации
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Для проекта $ARGUMENTS прочитай QA-TDD-status.md и QA-*-tdd-report.md. Запусти
точную сохранённую test command и весь затронутый regression set.

Прочитай current approved Change Scope по `_contract/CHANGE_SCOPE_V1.md`. Для
`s4-qa-auto /run-tests` разрешены только launcher-registered governance outputs. Production и
native test code не меняй даже если тесты падают; FAIL передай в repair loop. Не расширяй scope.

До запуска составь полный scope и `stage4-dev/outputs/QA-affected-tests-v1.tsv` по
`_contract/TDD_STATUS_V1.md`. Каждому scope id нужен хотя бы один существующий native test
file. Запиши exact source revision, manifest digest и expected/executed counts; skip/xfail и
selective/partial run не дают PASS.

Обнови QA-TDD-status.md:
- PASS, если все обязательные тесты прошли;
- FAIL с failed_tests и причинами, если реализация требует ремонта;
- BLOCKED, если тесты невозможно корректно запустить.

Не меняй production-код и не ослабляй тесты.

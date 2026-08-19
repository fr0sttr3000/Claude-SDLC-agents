---
description: Написать unit/integration/contract тесты до кода и доказать Red
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Для проекта $ARGUMENTS прочитай tdd.md, test strategy, требования и дизайн.
Напиши применимые unit, integration, contract, migration и format tests до
production-реализации. Запусти их и докажи ожидаемый Red: падение должно быть
вызвано отсутствующей/неверной функциональностью, а не окружением.

Создай QA-[дата]-tdd-report.md и QA-TDD-status.md в stage4-dev/outputs/.
Установи status: RED только при валидном доказательстве. Иначе status: BLOCKED.
Используй exact schema `_contract/TDD_STATUS_V1.md`: для Red укажи
`regression_scope: not-yet-run`, concrete functional `red_evidence` и zero post-Green counts.
Тестовый код сохрани в native test structure репозитория проекта, не в governance outputs.

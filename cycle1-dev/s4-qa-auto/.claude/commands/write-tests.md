---
description: Написать unit/integration/contract тесты до кода и доказать Red
---

Для проекта $ARGUMENTS прочитай tdd.md, test strategy, требования и дизайн.
Напиши применимые unit, integration, contract, migration и format tests до
production-реализации. Запусти их и докажи ожидаемый Red: падение должно быть
вызвано отсутствующей/неверной функциональностью, а не окружением.

Создай QA-[дата]-tdd-report.md и QA-TDD-status.md в stage4-dev/outputs/.
Установи status: RED только при валидном доказательстве. Иначе status: BLOCKED.

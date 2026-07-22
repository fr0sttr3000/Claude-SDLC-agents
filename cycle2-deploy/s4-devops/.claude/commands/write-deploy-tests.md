---
description: Написать deploy tests и получить RED до pipeline и конфигурации
---

# /write-deploy-tests

Создай исполняемые тесты поставки до изменения pipeline/IaC/runtime-конфигурации.

1. Прочитай deploy intake, tracking/SDLC-goals.md, _standards/tdd.md и
   acceptance/NFR/security constraints.
2. Для каждого заказанного cycle2_deliverables создай применимые
   lint/schema/policy/supply-chain/sandbox/smoke/rollback проверки.
3. Зафиксируй manifest тестов и точные команды. Тесты не должны обращаться к
   prod без явной cycle2_authorization.
4. Запусти тесты до реализации. Ожидаемое функциональное падение подтверждает
   Red; ошибка окружения, синтаксиса или зависимости даёт BLOCKED.
5. Запиши план и evidence в
   stage6-deploy/outputs/DEVOPS-YYYY-MM-DD-deploy-test-plan.md.
6. Создай stage6-deploy/outputs/DEPLOY-TDD-status.md с полями:
   status: RED|BLOCKED; project; goal_profile_revision; scope; test_command; red_evidence;
   failed_tests; repair_iteration: 0.

После Red нельзя ослаблять или подменять тестовый контракт ради Green.

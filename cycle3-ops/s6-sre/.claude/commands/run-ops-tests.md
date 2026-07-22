---
description: Запустить неизменённый ops test manifest и записать verdict
---

# /run-ops-tests

Запусти неизменённый ops test manifest после конфигурации.

1. Выполни полный затронутый набор rule/fixture/drill/permission/recovery tests.
2. Сформируй stage7-ops/outputs/SRE-YYYY-MM-DD-ops-test-report.md с командами,
   exit codes, измеренными сигналами и evidence.
3. Обнови stage7-ops/outputs/OPS-TDD-status.md:
   PASS — все обязательные tests прошли; FAIL — требуется repair конфигурации;
   BLOCKED — безопасный проверяемый запуск невозможен.
   Несовпадение goal_profile_revision с текущим профилем означает BLOCKED.
4. Не ослабляй сценарии и не выдавай отсутствие live permission за PASS.
5. Post-deploy и Gate 7 запрещены до PASS.

Вердикт определяется исполняемым harness и измерениями; subagent может только
независимо проверить evidence.

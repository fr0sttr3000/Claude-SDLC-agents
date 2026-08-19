---
description: Запустить неизменённый deploy test manifest и записать verdict
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /run-deploy-tests

Запусти неизменённый test manifest Cycle 2 после реализации.

1. Выполни полный затронутый набор из deploy test plan.
2. Не меняй tests/AC/manifest для получения Green.
3. Сформируй stage6-deploy/outputs/DEVOPS-YYYY-MM-DD-deploy-test-report.md
   с командами, exit codes, evidence и failed checks.
4. Обнови единственную строку status: в
   stage6-deploy/outputs/DEPLOY-TDD-status.md:
   PASS — все обязательные проверки прошли;
   FAIL — реализация не прошла, укажи конкретный repair target;
   BLOCKED — окружение/разрешение не позволяет получить вердикт.
   Сохрани goal_profile_revision; несовпадение с текущим профилем даёт BLOCKED.
5. При execute-deploy отдельно докажи smoke и rollback readiness. Не повторяй
   неудачный prod deploy автоматически.

Вердикт следует из исполняемых проверок, не из мнения агента или subagent.

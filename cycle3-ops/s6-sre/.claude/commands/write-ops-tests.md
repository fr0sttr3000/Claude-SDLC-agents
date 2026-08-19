---
description: Написать ops tests и получить RED до изменения конфигурации
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /write-ops-tests

Создай ops tests до изменения monitoring/alerts/runbooks/auto-heal.

1. Прочитай ops intake, профиль цели и _standards/tdd.md.
2. Создай применимые rule fixtures, alert/dedup scenarios, permissions и
   idempotency tests, backup/restore checks, capacity/SLO assertions и
   безопасные fire-drill сценарии.
3. Зафиксируй точные команды и ожидаемые наблюдаемые сигналы.
4. Докажи Red до конфигурации. Ошибка harness/окружения — BLOCKED, не Red.
5. Запиши stage7-ops/outputs/SRE-YYYY-MM-DD-ops-test-plan.md.
6. Создай stage7-ops/outputs/OPS-TDD-status.md с полями:
   status, project, goal_profile_revision, scope, test_command, red_evidence,
   failed_tests, repair_iteration.

Начальный допустимый status: RED или BLOCKED.

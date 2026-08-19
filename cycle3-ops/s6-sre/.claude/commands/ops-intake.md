---
description: Сверить goal, evidence, authorization и точный scope Cycle 3
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /ops-intake

Подготовь проверяемый intake Cycle 3 до ops tests и конфигурации.

1. Прочитай tracking/SDLC-goals.md, PMO constraints, HLD, SLO/NFR,
   deploy evidence и DEPLOY-TDD-status.md.
2. Используй только явно заданные cycle3_*; стек мониторинга и executor по
   умолчанию запрещены.
3. Свяжи каждый cycle3_deliverables с наблюдаемым результатом, тестом,
   evidence, owner и границей authorization.
4. Live drill/auto-heal допустим только при явной authorization, безопасной
   среде, maintenance window и rollback. Иначе используй offline fixture либо
   BLOCKED — в зависимости от цели.
5. Bounded read-only subagents могут анализировать observability, incident
   dedup, DR/capacity и test scenarios. Они не меняют конфигурацию и не
   выполняют operational actions.
6. Запиши stage7-ops/outputs/SRE-YYYY-MM-DD-ops-intake.md.

---
description: Реализовать выбранную ops-конфигурацию после подтверждённого RED
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /configure-ops

Реализуй минимальную ops-конфигурацию для прохождения заранее написанных тестов.

- Читай актуальные cycle3_* из tracking/SDLC-goals.md непосредственно перед
  изменениями.
- Создавай только выбранные deliverables: monitoring, dashboards, alerts,
  runbooks, auto-heal, backup-dr, capacity, incident, reporting, execute-ops.
- Не подставляй Prometheus/Grafana/Kubernetes/cloud service или model по
  умолчанию.
- Не меняй tests/AC ради Green.
- Operational action execute-ops выполняй только в разрешённой среде с точной
  identity, allowlist, retry limit, escalation и rollback.
- Subagents — только bounded read-only analysis; основной агент остаётся
  единственным writer.

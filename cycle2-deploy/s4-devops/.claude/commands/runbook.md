---
description: Создать stack-native runbook и operations package после RED
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /runbook

Создай только выбранные профилем runbook/operations-pack результаты для
проекта $ARGUMENTS.

Если operations-pack/execute-deploy/runtime handoff неприменимы (например,
images-only), не создавай фиктивный runbook: запиши N/A и version fallback в
deploy intake/test evidence и заверши шаг без лишнего deliverable.

Прочитай tracking/SDLC-goals.md, DEPLOY-TDD-status.md: RED, deploy test plan,
HLD, NFR/SLO и созданные delivery artifacts.

Runbook должен отражать фактический stack и содержать применимые:

- prerequisites, exact identities и границы authorization;
- versioned deployment steps без secrets;
- migration/backup/restore и проверяемый rollback;
- rollout thresholds и stop conditions;
- validation/smoke команды и ожидаемый evidence;
- monitoring/alert handoff только для выбранного stack;
- escalation, owner и явно обоснованные N/A.

Docker, Kubernetes, Prometheus, Grafana и любой cloud service не являются
defaults. Не выполняй live deploy/rollback. Запиши goal_profile_revision.

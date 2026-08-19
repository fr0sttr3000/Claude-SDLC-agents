---
description: Проверить post-deploy только после PASS ops tests
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /post-deploy

Выполни разрешённую post-deploy проверку проекта $ARGUMENTS.

До действий прочитай tracking/SDLC-goals.md,
stage7-ops/outputs/OPS-TDD-status.md: PASS, ops test report, Gate 6 evidence,
deploy report и актуальный runbook.

Сначала проверь применимость observation к cycle3_deliverables. Если post-deploy
observation не требуется выбранным monitoring/alerts/reporting/execute-ops scope,
создай stage7-ops/outputs/SRE-YYYY-MM-DD-post-deploy-not-applicable.md с
`applicability: not-applicable`, goal revision и причиной; live action не выполняй.
Если observation требуется, но нет безопасного read access/authorization, верни BLOCKED.

- Scope ограничен cycle3_deliverables и точной goal_profile_revision.
- Live actions требуют execute-ops, точной identity/authorization, maintenance
  window, stop conditions и rollback; иначе только read-only observation.
- Собери измерения в интервалы из актуального goal/NFR/quality-gates. Если
  cadence не задан, верни BLOCKED — не подставляй локальные интервалы.
- При нарушении утверждённого rollback threshold следуй runbook; не придумывай
  пороги и не повторяй действие автоматически.
- Запиши команды/queries, измерения, incident/rollback decision и revision в
  stage7-ops/outputs/SRE-YYYY-MM-DD-post-deploy-report.md.

Subagents допустимы только для bounded read-only анализа evidence.

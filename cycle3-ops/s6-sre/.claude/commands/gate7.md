---
description: Подписать Gate 7 по готовому проверяемому evidence
---

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.


# /gate7

Проверь Gate 7 проекта $ARGUMENTS без создания новой ops-конфигурации.

Обязательные входы:

1. tracking/SDLC-goals.md и его актуальная revision;
2. stage7-ops/outputs/OPS-TDD-status.md: PASS;
3. ops test plan/report той же revision;
4. post-deploy report либо явное post-deploy-not-applicable goal evidence,
   а также применимые SLO/error-budget и incident/known-issue evidence;
5. все артефакты Gate 7 из _standards/quality.md.

Проверь соответствие только выбранным cycle3_deliverables: monitoring,
dashboards, alerts/dedup, runbooks, auto-heal authorization, backup/DR,
capacity/cost, incident и reporting. Не подставляй stack или executor.

Если revision/evidence устарели, status не PASS или обязательное измерение
отсутствует — Gate 7 BLOCKED. Здесь запрещено менять tests/configuration,
выполнять live drill/auto-heal/deploy/rollback или принимать подпись subagent.
Основной s6-sre записывает итоговый SRE-YYYY-MM-DD-ops-report.md.

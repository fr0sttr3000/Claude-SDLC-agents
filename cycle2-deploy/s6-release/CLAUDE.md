# CLAUDE.md — Агент: Release Manager (Cycle 2 / Stage 6)

> ⛔ **FROZEN / NOT READY / NOT SUPPORTED.** Historical reference only. Do not execute
> this role or command; the supported launcher exposes Cycle 1 only.

## Роль

Эта historical роль владела release preparation и подписанием Gate 6 в замороженном
baseline. Она не является current owner: поддерживаемые release notes теперь принадлежат
Cycle 1 utility `s0-tracker /release-notes`.

## Входы

Читай `_standards/quality.md`, `_standards/tdd.md`, `tracking/SDLC-goals.md`,
`tracking/quality-gates.md`, Stage 5 Go/No-Go/performance/security evidence,
`stage6-deploy/outputs/DEPLOY-TDD-status.md`, deploy test report, применимый runbook/rollback evidence,
known issues и корневой `CHANGELOG.md` Project.

Если project threshold задан, применяй его; иначе global minimum. Не подставляй environment,
version, monitoring stack, SLO или approval owner.

## Workflow и outputs

1. Убедись, что Gate 5 PASS и Cycle 2 deliverables соответствуют текущей goal revision.
2. Убедись, что `DEPLOY-TDD-status.md: PASS`; FAIL/BLOCKED нельзя переписать verdict-ом.
3. `/release-notes` создаёт `REL-YYYY-MM-DD-release-notes-vX.Y.Z.md` в Stage 6.
4. В рамках явной release preparation обнови корневой `CHANGELOG.md` Project.
5. `/release-checklist` проверяет evidence и создаёт `REL-YYYY-MM-DD-checklist-vX.Y.Z.md`.
6. Подпиши Gate 6 PASS/FAIL с paths и blockers. Deploy выполняет authorised executor, не ты.

## Gate 6

□ Gate 5 PASS, required QA/UAT/performance/security thresholds выполнены.
□ DEPLOY-TDD PASS и Stage 6 deploy test evidence соответствуют goal revision.
□ Release notes и root `CHANGELOG.md` описывают exact version/scope/known issues.
□ Rollback/version fallback задокументирован и протестирован применимо к delivery scope.
□ Runbook/monitoring/on-call/owner существуют, только если выбраны; N/A обоснован goal evidence.
□ Ни один secret/live credential не попал в artifacts.
□ Все blockers видимы; никаких исключений или silent risk acceptance.

Авто-проверка: `s0-validate /dod-check [PROJECT] D 6`.

## Subagents и старт

Read-only subagent может сверять evidence, но не пишет release artifacts и не подписывает Gate.
При старте назови Cycle 2 / Stage 6, Project, version и нужную команду.

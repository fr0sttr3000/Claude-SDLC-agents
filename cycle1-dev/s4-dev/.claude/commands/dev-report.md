---
description: Выполнить Green/Repair по Red tests и создать Dev Report
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Выполни Green/Repair и затем создай Dev Report для проекта $ARGUMENTS.

До любой записи прочитай `tracking/current-change-scope-v1.yaml` и связанные approved
metadata/path table по `_contract/CHANGE_SCOPE_V1.md`. Найди строки только для
`s4-dev /dev-report`. Меняй production/native documentation исключительно по этим exact
`MODIFY|EXTEND` paths; `USE|LOCKED` и все неуказанные пути read-only. Не добавляй себе paths,
не исправляй тесты и не считай доступность каталога разрешением. Если нужного пути нет —
верни `BLOCKED` с предложением подготовить новый Change Scope.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/tdd.md
3. Current `quality-policy` и `tdd-status` по root Current Artifacts rule
4. Red tests и test command из QA TDD evidence
5. Current `high-level-design` и `api-contract` (если применимо)
6. Current `product-backlog` и `requirements-traceability`

Если `QA-TDD-status.md` не содержит `status: RED` для первой реализации либо `status: FAIL`
для Repair — BLOCKED. Не меняй тесты/AC ради Green. В каталоге кода реализуй минимальный Green
или точечный Repair, запусти только developer-side checks и оставь независимый итоговый Run
агенту `s4-qa-auto`.

Применяй KISS из `plans/principles.md`: используй existing conventions/public interfaces и
smallest coherent diff. Не добавляй speculative abstraction/layer/dependency/framework/
extension point. Если новый элемент необходим, свяжи его с exact requirement или current
HLD/ADR. Не упрощай validation, error handling, authorization, observability, reliability,
compatibility, tests или protected intentional complexity.

Для каждой quality metric вызови `quality-policy-read.sh PROJECT METRIC_ID` и используй
возвращённые metric id, operator, threshold, unit, policy revision и Product Profile revision.
Observed result хуже effective threshold делает отчёт и Gate 4 BLOCKED; локальные числа и
Markdown-самооценка не заменяют verified Evidence v1.

Создай файл DEV-[дата]-PR-[N]-summary.md в:
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/

# Dev Report — PR #[N] — $ARGUMENTS
Дата: [сегодня]
Агент: s4-dev

## Что реализовано
[Список завершённых задач со ссылками на User Stories]

## Change Scope
- Scope digest: [SDLC_CHANGE_SCOPE_SHA256]
- Approved implementation paths: [exact list]
- Out-of-scope changes: none

## Технические решения
[Ключевые архитектурные и технические решения принятые в PR]

## KISS
- Simplest sufficient implementation: [почему выбранный diff минимален и достаточен]
- New layers/dependencies/abstractions: none | [exact requirement/HLD/ADR rationale]
- Preserved controls and intentional complexity: [validation/security/reliability/tests]

## Покрытие тестами (quality.md §3.1)
| Metric ID | Operator | Effective threshold | Unit | Observed | Verdict | Evidence v1 ref | Policy revision | Product Profile revision |
|---|---|---:|---|---:|---|---|---|---:|
| branch_coverage_percent | [>=] | [effective value] | percent | [observed] | [PASS/BLOCKED] | [exact ref] | [revision] | [revision] |
| mutation_score_percent | [>=] | [effective value] | percent | [observed] | [PASS/BLOCKED] | [exact ref] | [revision] | [revision] |
- Integration/component: [адаптеры с тестами: БД / API-клиент / очередь]
- Contract (consumer-driven): [API-контракты с тестами, сверка с api-spec]
- Изменённые модули: [список]
- Новые тесты: [список]

## Security Checklist
□ Все вводы валидируются
□ Только parameterized queries
□ Нет секретов в коде
□ Endpoint protection соответствует current API/auth applicability и authorization matrix;
  public/unprotected endpoints явно определены current contract

## Definition of Done — Gate 4
□ Код написан и проходит все тесты
□ Unit branch и mutation прошли exact effective thresholds из `quality-policy-read.sh`
□ Integration-тест для каждого внешнего адаптера; contract-тест если PR трогает API (§3.1)
□ SAST/secrets-scan прошли exact effective thresholds/evidence contract
□ Нет игнорированных исключений (bare except/pass)
□ KISS: нет speculative layers/dependencies/abstractions; каждый новый элемент имеет exact rationale
□ README обновлён (если изменились команды/env/конфигурация)
□ Реализация сверена с current `api-contract`; Stage 3 artifact этой командой не изменяется
□ Требуемое изменение endpoint contract/ADR возвращает `BLOCKED` для s3-arch handoff,
  fresh Change Scope и отдельного Human Approval
□ CHANGELOG/release notes не изменялись: они принадлежат release preparation
□ Update Notes созданы: DEV-*-update-notes-PR[N].md
□ Нет хардкода ролей в бизнес-логике

## Известные ограничения / Tech Debt
[Что намеренно отложено с обоснованием]

## Следующие шаги
→ s4-techlead: /review для этого PR

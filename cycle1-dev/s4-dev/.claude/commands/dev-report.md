---
description: Выполнить Green/Repair по Red tests и создать Dev Report
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Выполни Green/Repair и затем создай Dev Report для проекта $ARGUMENTS.

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

## Технические решения
[Ключевые архитектурные и технические решения принятые в PR]

## Покрытие тестами (quality.md §3.1)
| Metric ID | Operator | Effective threshold | Unit | Observed | Verdict | Evidence v1 ref | Policy revision | Product Profile revision |
|---|---|---:|---|---:|---|---|---|---:|
| unit_branch_coverage_percent | [>=] | [effective value] | percent | [observed] | [PASS/BLOCKED] | [exact ref] | [revision] | [revision] |
| mutation_score_percent | [>=] | [effective value] | percent | [observed] | [PASS/BLOCKED] | [exact ref] | [revision] | [revision] |
- Integration/component: [адаптеры с тестами: БД / API-клиент / очередь]
- Contract (consumer-driven): [API-контракты с тестами, сверка с api-spec]
- Изменённые модули: [список]
- Новые тесты: [список]

## Security Checklist
□ Все вводы валидируются
□ Только parameterized queries
□ Нет секретов в коде
□ Авторизация на каждом endpoint

## Definition of Done — Gate 4
□ Код написан и проходит все тесты
□ Unit branch и mutation прошли exact effective thresholds из `quality-policy-read.sh`
□ Integration-тест для каждого внешнего адаптера; contract-тест если PR трогает API (§3.1)
□ SAST/secrets-scan прошли exact effective thresholds/evidence contract
□ Нет игнорированных исключений (bare except/pass)
□ README обновлён (если изменились команды/env/конфигурация)
□ API-spec обновлён (если менялись endpoints)
□ CHANGELOG/release notes не изменялись: они принадлежат release preparation
□ Update Notes созданы: DEV-*-update-notes-PR[N].md
□ Нет хардкода ролей в бизнес-логике

## Известные ограничения / Tech Debt
[Что намеренно отложено с обоснованием]

## Следующие шаги
→ s4-techlead: /review для этого PR

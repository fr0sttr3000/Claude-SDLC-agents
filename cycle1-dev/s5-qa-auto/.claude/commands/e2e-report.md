---
description: Исполнить full-affected automation и создать exact-build отчёт для Gate 5
---

Создай Automation Report для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/artifact-metadata.md
3. $SDLC_VAULT/_agents/_standards/data-formats.md
4. $SDLC_VAULT/_agents/_contract/S5_VALIDATION_V1.md
5. Current `product-ci-profile`, `quality-policy`, `s5-validation-index`, `s5-test-cases` и
   `api-contract` по root Current Artifacts rule
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/evidence/v1/ (build record exact source)

Создай файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/:
- AUTO-[дата]-e2e-report.md
- AUTO-[дата]-coverage.md

Оба Markdown-файла получают общий Artifact Metadata v1 с Obsidian links. Дополнительно укажи
`owner: s5-qa-auto`, `subject_digest`, `build_identity`, `environment_id`; artifact_type —
`automation-report` и `automation-coverage` соответственно.

Исполни существующие применимые suites как полный affected regression на exact build; в S5
не создавай и не исправляй test code. Отсутствующий/сломанный применимый suite возвращается
в S4 и даёт BLOCKED. Затем создай
`tracking/validation/raw/automation.json` по S5 Validation v1. Обязательны
`regression_scope: full-affected`, exact `test_results`, `critical_path_results` по полному
S2 UAT catalog, required `criterion_results` для UXC/A11Y и две effective-policy
`quality_metrics`; counters и coverage вычисляются из этих rows. Зафиксируй SHA-256 и добавь/замени только
строку `automation\ts5-qa-auto` в общем индексе. Сохрани остальные строки byte-for-byte.
Без отдельного environment APPROVE, при selective/partial scope, skipped/failed test или
неполном count верни BLOCKED; PASS не записывай.

# Automation Report — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa-auto

## Automation Pyramid — статус

| Уровень | Цель | Факт | Статус |
|---------|------|------|--------|
| E2E/API/UI critical paths | effective quality policy; UI только если применим | | |
| Contract (consumer-driven) | для каждого внешнего API, сверено с api-spec | | |
| Integration / component | для каждого внешнего адаптера (БД/API/очередь) | | |
| Unit (branch/mutation) | effective Quality Policy | | |

## E2E — Critical Paths
| TC ID | Описание | Время (сек) | Статус |
|-------|---------|------------|--------|

## API Tests — Coverage
| Endpoint | Method | Тест | Статус |
|----------|--------|------|--------|

## Покрытие — branch + mutation (quality.md §3.1)
| Модуль | Branch % | Mutation % (критичные) | Статус |
|--------|---------|------------------------|--------|
| **Итого** | | | |

## Integration / Contract — наличие
| Внешний адаптер / API | Тип теста | Есть | Проходит |
|-----------------------|-----------|------|----------|

## Anti-patterns — проверка
□ Для применимого UI нет `waitForTimeout(N)` — только event-driven ожидания
□ Для применимого UI нет fragile CSS; locator/POM policy соответствует выбранному harness
□ Нет shared test data — тесты изолированы
□ Нет order-dependent тестов — каждый тест атомарен
□ Нет assertions в Page Objects

## Gate 5 Checklist
□ Применимые critical paths покрыты по effective quality policy
□ API endpoints покрыты, только если API применим; UI/POM — только если UI применим
□ Unit branch/mutation соответствуют effective quality policy (§3.1)
□ Integration- и contract-тесты присутствуют и проходят (§3.1)
□ Все тесты проходят независимо от порядка
□ Тест-данные изолированы (нет shared state)
□ AUTO-*-coverage.md передан в stage5-testing/outputs/
□ Raw automation JSON и owner-bound index row привязаны к exact source/build/environment

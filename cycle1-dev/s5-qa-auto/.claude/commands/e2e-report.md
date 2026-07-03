---
description: Создать E2E/API automation отчёт с coverage (Gate 4/5)
---

Создай Automation Report для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/QA-test-cases-*.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-api-spec.yaml (если существует)

Создай файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/:
- AUTO-[дата]-e2e-report.md
- AUTO-[дата]-coverage.md

# Automation Report — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa-auto

## Automation Pyramid — статус

| Уровень | Цель | Факт | Статус |
|---------|------|------|--------|
| E2E (critical paths) | ≤ 20 тестов, < 30 сек каждый, ≥ 95% автоматизация | | |
| Contract (consumer-driven) | для каждого внешнего API, сверено с api-spec | | |
| Integration / component | для каждого внешнего адаптера (БД/API/очередь) | | |
| Unit (branch) | ≥ 80% изм. кода + mutation ≥ 60% критичных | | |

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
□ Нет `waitForTimeout(N)` — только event-driven ожидания
□ Нет fragile CSS-локаторов — только data-testid / aria-role / visible text
□ Нет shared test data — тесты изолированы
□ Нет order-dependent тестов — каждый тест атомарен
□ Нет assertions в Page Objects

## Gate 4/5 Checklist
□ E2E: покрыты все critical paths (≥ 95% автоматизировано)
□ API: все endpoints из api-spec.yaml покрыты
□ Unit: branch ≥ 80% изм. кода + mutation ≥ 60% критичных модулей (§3.1)
□ Integration- и contract-тесты присутствуют и проходят (§3.1)
□ Все тесты проходят независимо от порядка
□ Тест-данные изолированы (нет shared state)
□ AUTO-*-coverage.md передан в stage5-testing/outputs/

---
description: Создать E2E/API automation отчёт с coverage (Gate 4/5)
---

Создай Automation Report для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage5-testing/outputs/QA-test-cases-*.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/ARCH-api-spec.yaml (если существует)

Создай файлы в $SDLC_VAULT/projects/$ARGUMENTS/stage5-testing/outputs/:
- AUTO-[дата]-e2e-report.md
- AUTO-[дата]-coverage.md

# Automation Report — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa-auto

## Automation Pyramid — статус

| Уровень | Цель | Факт | Статус |
|---------|------|------|--------|
| E2E (critical paths) | ≤ 20 тестов, < 30 сек каждый | | |
| API (все endpoints) | 80%+ coverage | | |
| Unit | 80%+ line coverage | | |

## E2E — Critical Paths
| TC ID | Описание | Время (сек) | Статус |
|-------|---------|------------|--------|

## API Tests — Coverage
| Endpoint | Method | Тест | Статус |
|----------|--------|------|--------|

## Unit Coverage
| Модуль | Coverage | Строк | Статус |
|--------|---------|-------|--------|
| **Итого** | | | |

## Anti-patterns — проверка
□ Нет `waitForTimeout(N)` — только event-driven ожидания
□ Нет fragile CSS-локаторов — только data-testid / aria-role / visible text
□ Нет shared test data — тесты изолированы
□ Нет order-dependent тестов — каждый тест атомарен
□ Нет assertions в Page Objects

## Gate 4/5 Checklist
□ E2E: покрыты все critical paths (≥ 95% автоматизировано)
□ API: все endpoints из api-spec.yaml покрыты
□ Unit coverage ≥ 80%
□ Все тесты проходят независимо от порядка
□ Тест-данные изолированы (нет shared state)
□ AUTO-*-coverage.md передан в stage5-testing/outputs/

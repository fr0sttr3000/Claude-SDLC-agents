---
description: Создать Test Plan с тест-кейсами по всем типам (IEEE 829)
---

Создай Test Plan для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/PO-backlog.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/BA-NFR.md

Создай файлы в $SDLC_VAULT/projects/$ARGUMENTS/stage5-testing/outputs/:
- QA-[дата]-test-plan.md
- QA-[дата]-test-cases-[epic].md (по одному на epic)

# Test Plan — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa

## Scope тестирования
**In Scope:** [что тестируем]
**Out of Scope:** [что не тестируем и почему]

## Тест-кейсы

Формат каждого:
```
TC-[EPIC_ID]-[N]: [название]
Priority: Critical | High | Medium | Low
Type: Functional | API | UI | Security | Performance
Preconditions: [состояние системы до теста]
Test Data: [данные для теста]
Steps:
  1. ...
Expected Result: [точный ожидаемый результат]
```

## Обязательные типы тест-кейсов (из prod-багов)

### Конфигурация и старт
- TC: запуск с некорректным env-форматом → понятная ошибка, не crash
- TC: запуск с некорректным токеном → ошибка в логах < 10 сек
- TC: restart loop → причина видна в `docker compose logs`

### Datetime / Timezone
- TC: CREATE с timezone-aware datetime → INSERT успешен
- TC: READ timestamps → возвращаются timezone-aware значения

### Parse mode (если Telegram)
- TC: спецсимволы `_`, `*`, `` ` `` в тексте → отображаются корректно

### Race condition
- TC: параллельные запросы на один объект → нет дублей, нет data corruption

## UAT Requirements
- UAT проводится в живой системе (не эмулятор)
- Владелец лично выполняет acceptance scenarios
- Без UAT sign-off — релиз не разрешён

## Severity классификация
S1 Critical → fix 4ч / S2 High → 1 день / S3 Medium → sprint / S4 Low → backlog

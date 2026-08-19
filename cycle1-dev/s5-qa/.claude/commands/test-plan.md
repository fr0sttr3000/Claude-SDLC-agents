---
description: Создать Test Plan с тест-кейсами по всем типам (IEEE 829)
---

Создай Test Plan для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/artifact-metadata.md
3. $SDLC_VAULT/_agents/_standards/data-formats.md
4. $SDLC_VAULT/_agents/_contract/S5_VALIDATION_V1.md
5. Current `product-ci-profile`, `product-backlog`, `nonfunctional-requirements`,
   `uat-criteria` и `product-acceptance-index` по root Current Artifacts rule
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/evidence/v1/ (ровно один build record exact source)

Создай файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/:
- QA-[дата]-test-plan.md
- QA-[дата]-test-cases-[epic].md (по одному на epic)

Каждый новый Markdown-файл использует общий Artifact Metadata v1 и Obsidian links.

Также создай каталог `tracking/validation/raw/` и, только если индекс ещё отсутствует,
инициализируй `tracking/validation/S5-validation-v1.tsv` точным header из
`S5_VALIDATION_V1.md`. Не добавляй результаты и не создавай approvals за другие роли.
Если индекс уже существует, не стирай и не заменяй его строки.

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

## Условный lessons-learned каталог

Добавляй сценарии ниже только если соответствующий stack/capability подтверждён Product
Profile/HLD/test strategy. Для другого стека используй его эквивалентные инварианты.

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
- Каждый `UAT-*` scenario из проверенных product acceptance criteria получает отдельный
  test case/result с сохранёнными Must-FR, risk и UX flow/NOT_APPLICABLE links
- UAT проводится в согласованной репрезентативной безопасной среде; production требует
  отдельной явной authorization
- Владелец лично выполняет acceptance scenarios
- Без отдельного UAT Human Approval v1 Cycle 1 validation остаётся BLOCKED; QA не создаёт
  approval от имени владельца.
- Зафиксируй validation environment из current Product Profile schema v5 (legacy v4 readable). Если environment `not-available`
  или нет отдельного APPROVE на `environment:<id>`, верни BLOCKED до исполнения S5.

## Severity классификация
S1 Critical → fix 4ч / S2 High → 1 день / S3 Medium → sprint / S4 Low → backlog

---
description: Провести нагрузочное тестирование (smoke/load/stress/soak) и вынести вердикт
---

Проведи нагрузочное тестирование для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/artifact-metadata.md
3. $SDLC_VAULT/_agents/_standards/data-formats.md
4. $SDLC_VAULT/_agents/_contract/S5_VALIDATION_V1.md
5. $SDLC_VAULT/_agents/_contract/RISK_EXCEPTION_V3.md
6. Current `product-ci-profile`, `s5-validation-index`, `nonfunctional-requirements` и
   `api-contract` по root Current Artifacts rule
7. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/evidence/v1/ (build record exact source)

Исполни существующий project-selected performance harness на exact build и создай
`PERF-[дата]-report.md` в `$SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/`.
В S5 не создавай и не исправляй executable load-test code: missing/broken required harness
означает BLOCKED и возврат в S4.

`PERF-*-report.md` получает общий Artifact Metadata v1 с Obsidian links и дополнительно
`owner: s5-perf`, exact `subject_digest/build_identity/environment_id`.

Создай `tracking/validation/raw/performance.json` по S5 Validation v1 и добавь/замени только
строку `performance\ts5-perf` в общем индексе, сохранив чужие строки byte-for-byte. Required
stream содержит exact `quality_metrics` rows; operator/threshold/unit/policy revision берутся
из `quality-policy-read.sh`, observed value — из raw execution, counters выводятся из rows.
Нужен environment APPROVE. Structured N/A
допустим только по Product Profile schema v5 (legacy v4 readable): `environment_id: not-applicable`, profile revision,
exact resolver owner/reason, нулевые counters, без фиктивного теста. CONDITIONAL_PASS требует
Risk Exception v3 с `exception_type: performance`, `finding_severity: PERFORMANCE_THRESHOLD`,
exact findings и matching typed Tech Debt до конца следующего sprint; иначе BLOCKED.

# Performance Report — $ARGUMENTS
Дата: [сегодня]
Агент: s5-perf

## NFR Thresholds

Перенеси точные метрики, пороги и единицы из BA-NFR.md и
tracking/quality-gates.md. Project gates могут только ужесточать global minimum.
Если обязательный порог отсутствует — верни BLOCKED; не подставляй локальные defaults.

| Метрика | Порог |
|---------|-------|
| {метрика из NFR} | {точный порог + единица + source} |

## Типы тестов — результаты

Выполняй типы, выбранные project test strategy. Для каждого неприменимого типа
укажи N/A с BA/HLD evidence. Если performance testing целиком неприменим,
создай PERF-report с verdict NOT_APPLICABLE и не генерируй фиктивный test script.

### 1. Smoke Test
Цель: система запускается без ошибок
Результат: PASS / FAIL

### 2. Load Test (ожидаемая нагрузка)
| Метрика | Результат | Порог | Статус |
|---------|---------|-------|--------|
| {метрика} | {измерение} | {порог из NFR/gates} | |

### 3. Stress Test (предельная нагрузка)
Деградация начинается при: [N] VU / [M] RPS
Точка отказа: [N] VU / [M] RPS

### 4. Soak Test
Длительность и нагрузка: {точные значения из test strategy/NFR}
Утечки памяти: PASS / FAIL
Деградация производительности: PASS / FAIL

## Красные флаги — анализ
□ Sawtooth pattern → memory leak? [описание]
□ Long tail p99 >> p95 → lock contention? [описание]
□ Error rate растёт со временем → pool exhausted? [описание]

## Gate 5 Checklist
□ Все применимые типы из project test strategy выполнены; N/A обоснованы
□ Все применимые NFR/project thresholds проверены; источник каждого числа указан
□ Красные флаги проверены и задокументированы
□ Baseline зафиксирован для сравнения в следующем спринте
□ PERF-report.md передан в stage5-testing/outputs/

## ВЕРДИКТ
**PASS** / **CONDITIONAL PASS** / **FAIL** / **NOT_APPLICABLE**
Обоснование: ...

FAIL → Gate 5 заблокирован. CONDITIONAL PASS допустим только с verified Risk Exception v3.
NOT_APPLICABLE допустим только с profile-bound structured evidence; локальный вывод BA/HLD не
может переопределить Product Profile.

---
description: Провести нагрузочное тестирование (smoke/load/stress/soak) и вынести вердикт
---

Проведи нагрузочное тестирование для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-NFR.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-api-spec.yaml (если существует)

Создай применимые файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/:
- PERF-[дата]-report.md
- PERF-[дата]-k6-load.js, только если k6 соответствует выбранному workload/tooling

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
создай PERF-report с verdict NOT_APPLICABLE и не генерируй фиктивный k6 script.

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

## k6 скрипт (PERF-[дата]-k6-load.js)
[Полный k6 скрипт для воспроизведения тестов]

## Gate 5 Checklist
□ Все применимые типы из project test strategy выполнены; N/A обоснованы
□ Все применимые NFR/project thresholds проверены; источник каждого числа указан
□ Красные флаги проверены и задокументированы
□ Baseline зафиксирован для сравнения в следующем спринте
□ PERF-report.md передан в stage5-testing/outputs/

## ВЕРДИКТ
**PASS** / **CONDITIONAL PASS** / **FAIL** / **NOT_APPLICABLE**
Обоснование: ...

FAIL → Gate 5 заблокирован. CONDITIONAL PASS допустим с явным планом устранения.
NOT_APPLICABLE допустим только с BA/HLD evidence отсутствия performance/load target.

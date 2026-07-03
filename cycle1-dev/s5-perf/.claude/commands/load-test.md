---
description: Провести нагрузочное тестирование (smoke/load/stress/soak) и вынести вердикт
---

Проведи нагрузочное тестирование для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-NFR.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-api-spec.yaml (если существует)

Создай файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/:
- PERF-[дата]-report.md
- PERF-[дата]-k6-load.js

# Performance Report — $ARGUMENTS
Дата: [сегодня]
Агент: s5-perf

## NFR Thresholds (из BA-NFR.md или дефолты)
| Метрика | Порог |
|---------|-------|
| p50 | < 100ms |
| p95 | < 300ms |
| p99 | < 1000ms |
| error_rate | < 0.1% |

## Типы тестов — результаты

### 1. Smoke Test (1 VU, 1 мин)
Цель: система запускается без ошибок
Результат: PASS / FAIL

### 2. Load Test (ожидаемая нагрузка)
| Метрика | Результат | Порог | Статус |
|---------|---------|-------|--------|
| p50 | | < 100ms | |
| p95 | | < 300ms | |
| p99 | | < 1000ms | |
| error_rate | | < 0.1% | |
| RPS | | | |

### 3. Stress Test (предельная нагрузка)
Деградация начинается при: [N] VU / [M] RPS
Точка отказа: [N] VU / [M] RPS

### 4. Soak Test (нормальная нагрузка, 1+ час)
Утечки памяти: PASS / FAIL
Деградация производительности: PASS / FAIL

## Красные флаги — анализ
□ Sawtooth pattern → memory leak? [описание]
□ Long tail p99 >> p95 → lock contention? [описание]
□ Error rate растёт со временем → pool exhausted? [описание]

## k6 скрипт (PERF-[дата]-k6-load.js)
[Полный k6 скрипт для воспроизведения тестов]

## Gate 5 Checklist
□ Все 4 типа тестов выполнены: smoke, load, stress, soak
□ NFR пороги проверены: p95 < 300ms, p99 < 1000ms, error < 0.1%
□ Красные флаги проверены и задокументированы
□ Baseline зафиксирован для сравнения в следующем спринте
□ PERF-report.md передан в stage5-testing/outputs/

## ВЕРДИКТ
**PASS** / **CONDITIONAL PASS** / **FAIL**
Обоснование: ...

FAIL → Gate 5 заблокирован. CONDITIONAL PASS допустим с явным планом устранения.

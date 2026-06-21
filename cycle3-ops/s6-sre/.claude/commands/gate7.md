---
description: Gate 7 — SLO Review, Auto-Heal проверка, Incident Runbooks (через 7 дней после деплоя)
---

Выполни Gate 7 для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage6-deploy/outputs/SRE-*-post-deploy-report.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/DEVOPS-monitoring.yaml (если существует)

Создай файлы в $SDLC_VAULT/projects/$ARGUMENTS/stage7-ops/outputs/:
- SRE-[дата]-autoheal-report.md
- SRE-[дата]-ops-report.md
- SRE-runbook-service-down.md
- SRE-runbook-high-latency.md
- SRE-runbook-db-down.md
- SRE-runbook-disk-full.md

# Gate 7 — Ops Report — $ARGUMENTS
Дата: [через 7 дней после деплоя]
Агент: s6-sre

## 7.1 Monitoring Dashboard — проверка
□ Dashboard содержит RED-метрики: Rate / Error Rate / Duration
□ SLO-виджет: фактический availability за 30 дней vs порог 99.9%
□ Error budget: остаток в минутах на текущий месяц
□ Топ-5 ошибок за последние 24 часа
□ Алерты протестированы (fire drill): намеренно вызвать → алерт сработал
□ Алерты на SLO breach (не "CPU > 80%", а "error_rate > 0.1%")

## 7.2 Auto-Heal — проверка (BLOCKER)
□ Liveness → auto-restart: убить процесс → контейнер перезапустился < 30 сек
□ Watchdog heartbeat: проверить лог за 24 часа, интервал ≤ настроенному
□ Circuit breaker: при отключении зависимости → fallback, не 500
□ DLQ: упавшие задачи попали в DLQ, не потерялись

Результат каждой проверки: [PASS / FAIL + детали]

## 7.3 Incident Runbooks
Шаблон каждого runbook:
```
## Symptoms / Detect / Isolate / Recover / Verify / Escalate
```

Обязательные runbooks:
- SRE-runbook-service-down.md (error_rate > 50%)
- SRE-runbook-high-latency.md (p95 > 2× baseline)
- SRE-runbook-db-down.md (нет соединений с БД)
- SRE-runbook-disk-full.md (диск > 85%)

## 7.4 SLO Review
| Метрика | Значение | SLO | Статус |
|---------|---------|-----|--------|
| Availability (7 дней) | | 99.9% | |
| Error Budget остаток | мин | 43.8 мин/мес | |
| Инцидентов S1 | | 0 | |

SLO = 99.9% = 43.8 мин/месяц downtime допустимо.
- Error budget < 20% → заморозить деплои до конца месяца
- Error budget < 0% → красный алерт, немедленная заморозка

## 7.5 Операционные метрики доставки (DORA + escaped defects, quality.md §7)
| Метрика | Значение | Цель | Примечание |
|---------|---------|------|-----------|
| MTTR | | < 1 дня | время detect→recover |
| Change Failure Rate | | < 10% | релизы с откатом/хотфиксом ÷ всего |
| Reliability (SLO) | | выполняется | 5-я DORA-метрика |
| Escaped Defects | | → 0 | S1/S2 → обязательный post-mortem |

Эти значения s0-tracker читает из SRE-*-ops-report.md для блока §6 в cycle-summary.md.

## Gate 7 Checklist
□ Monitoring Dashboard активен с RED-метриками
□ SLO-виджет настроен, Error Budget рассчитан
□ Алерты протестированы (fire drill)
□ Auto-Heal проверен: liveness, watchdog, circuit breaker, DLQ
□ Все 4 Incident Runbooks созданы
□ Known Issues: для каждой OPEN-записи с impact — targeted-алерт (KI-id) протестирован + SRE-runbook-KI-*.md существует (§6.1)
□ SLO Review за 7 дней выполнен
□ Операционные метрики (MTTR / CFR / Reliability / Escaped Defects) зафиксированы (§7.5)
□ SRE-*-autoheal-report.md создан
□ SRE-*-ops-report.md создан

## ВЕРДИКТ
✅ **GATE 7 CLOSED** — следующий релиз разрешён
❌ **GATE 7 OPEN** — [список блокеров, следующий релиз заблокирован]

Без закрытого Gate 7 — следующий релиз проекта заблокирован. Никаких исключений.

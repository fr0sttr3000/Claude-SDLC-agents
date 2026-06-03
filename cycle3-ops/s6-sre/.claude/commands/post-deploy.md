---
description: Создать Post-Deploy отчёт (мониторинг T+0..T+60, rollback-критерии)
---

Создай Post-Deploy Report для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/DEVOPS-runbook.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage6-deploy/outputs/REL-checklist.md

Создай файл SRE-[дата]-post-deploy-report.md в:
$SDLC_VAULT/projects/$ARGUMENTS/stage6-deploy/outputs/

# Post-Deploy Report — $ARGUMENTS
Дата деплоя: [дата]
Версия: v[X.Y.Z]
Агент: s6-sre

## Pre-Deploy Checklist
□ REL-*-checklist.md получен и Gate 6 PASSED
□ Rollback-процедура задокументирована и протестирована
□ SLO определён, Error Budget рассчитан
□ Мониторинг активен: алерты на SLO breach настроены
□ Backup БД сделан

## Мониторинг по времени

### T+0 (деплой завершён)
□ Dashboard открыт, метрики текут
□ error_rate: [%] | p95 latency: [ms] | pod status: [OK/FAIL]

### T+5
□ error_rate: [%] | p95: [ms] | DB connections: [N]
□ Аномалии: [описание или "нет"]

### T+15
□ throughput: [RPS] | memory: [MB] | DB connections: [N]
□ Сравнение с baseline: [лучше/хуже/норма]

### T+30
□ Сравнение с предыдущим деплоем: [описание]
□ Аномалии: [описание или "нет"]

### T+60 — Final Assessment
□ Итоговое состояние: [стабильно / деградация / откат]
□ error_rate за 60 мин: [%]
□ SLO за период: [%]

## Критерии Rollback — статус
| Критерий | Порог | Факт | Сработал? |
|---------|-------|------|----------|
| error_rate | > 5% за 2 мин | | |
| Pod restarts | > 3 за 10 мин | | |
| p95 latency | > 3× baseline за 5 мин | | |

## Вывод
**Деплой:** УСПЕШЕН / ОТКАТ ВЫПОЛНЕН
**Следующие шаги:** [описание]

→ s6-sre: /gate7 через 7 дней для SLO Review и Gate 7.

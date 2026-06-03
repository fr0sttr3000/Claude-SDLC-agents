---
description: Создать Runbook деплоя с rollback-процедурой и observability
---

Создай Runbook деплоя для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/DEVOPS-cicd.yaml (если существует)
3. $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/ARCH-HLD.md

Создай файлы в $SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/:
- DEVOPS-[дата]-runbook.md
- DEVOPS-[дата]-monitoring.yaml

# Runbook — $ARGUMENTS
Дата: [сегодня]
Агент: s4-devops

## Pre-Deployment Checklist
□ Backup БД сделан и restore протестирован
□ Rollback-команды подготовлены и проверены
□ SLO определён, Error Budget рассчитан
□ Мониторинг настроен (алерты на SLO breach)
□ Release Checklist от s6-release получен

## Deployment Steps
```bash
# 1. Pull новой версии
docker pull image:vX.Y.Z

# 2. Миграции БД
docker compose run --rm app alembic upgrade head

# 3. Canary deploy (10%)
# ...

# 4. Full rollout
docker compose up -d --scale app=N
```

## Rollback Procedure (конкретные команды)
```bash
# Trigger: error_rate > 5% за 2 мин | pod restarts > 3 за 10 мин | p95 > 3× baseline
docker compose stop app
docker compose run --rm app alembic downgrade -1
docker pull image:vPREV
docker compose up -d
```

## Observability Baseline
| Endpoint | Назначение | SLO |
|----------|-----------|-----|
| /health | Liveness probe | всегда 200 |
| /ready | Readiness probe | 200 когда ready |
| /metrics | Prometheus | — |

Logging: структурированный JSON с trace_id, пишем в stdout.

## Алерты (настроить на SLO breach, не на симптомы)
| Условие | Действие | Эскалация |
|---------|---------|-----------|
| error_rate > 5% за 2 мин | Rollback | немедленно |
| p95 > 3× baseline за 5 мин | Rollback | немедленно |
| pod restarts > 3 за 10 мин | Rollback | немедленно |
| error_budget < 20% | Заморозить деплои | жёлтый алерт |

## Runbook Checklist — Gate 6
□ Runbook написан ДО деплоя
□ Rollback-процедура с конкретными командами
□ Backup и restore протестированы
□ Алерты на SLO breach (не на CPU/RAM симптомы)
□ Auto-Heal: restart policy + liveness probe + resource limits
□ DEVOPS-*-runbook.md передан s6-sre

---
description: Создать CI/CD pipeline (GitHub Actions / GitLab CI) с SAST и secrets-scan
---

Создай CI/CD pipeline для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-HLD.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/SEC-security-requirements.md (если существует)

Создай файл DEVOPS-[дата]-cicd.yaml в:
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/

# CI/CD Pipeline — $ARGUMENTS
Дата: [сегодня]
Агент: s4-devops

## Стадии pipeline

### On PR (каждый Pull Request)
```
lint → unit-tests → build → SAST → secrets-scan
```

### On Merge (в main/develop)
```
[PR стадии] → integration-tests → docker-build → deploy-dev → smoke-tests
```

### On Release (тег vX.Y.Z)
```
→ staging → full-tests → manual-approval → canary(10%) → full-rollout
```

## Конфигурация pipeline (yaml)
[Полный файл CI/CD конфигурации под используемую платформу]

## SAST настройка
- Critical/High находки блокируют merge
- Инструмент: [bandit для Python / semgrep / trivy]

## Secrets scan
- Ни один секрет не должен пройти в git
- Инструмент: [gitleaks / trufflehog]

## Docker образы
- Тегируются версией: `image:v1.2.3` — никогда `:latest` в prod
- Multi-stage build для минимального образа

## Observability в pipeline
- Структурированные логи с trace_id
- /health → liveness, /ready → readiness

## Auto-Heal — BLOCKER (Gate 6)
```yaml
# docker-compose.yml
services:
  app:
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:PORT/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## CI/CD Checklist — Gate 3
□ Pipeline покрывает все стадии: lint → unit-tests → build → SAST → secrets-scan
□ SAST: Critical/High блокируют merge
□ Secrets-scan: ни один секрет не пройдёт в git
□ Docker-образы тегированы версией, не :latest
□ Auto-Heal: restart policy + healthcheck + resource limits заданы
□ DEVOPS-*-cicd.yaml передан в stage4-dev/outputs/

---
description: Реализовать выбранные pipeline, IaC и supply-chain deliverables после RED
---

# /pipeline

Реализуй минимальную delivery automation для проекта $ARGUMENTS.

Обязательные входы:

1. tracking/SDLC-goals.md — актуальная revision и поля cycle2_*;
2. stage6-deploy/outputs/DEPLOY-TDD-status.md со status: RED;
3. deploy intake и deploy test plan;
4. HLD, security requirements и готовый test/build evidence Cycle 1.

Правила:

- создавай только явно выбранные cycle2_deliverables;
- конкретные CI, registry, runtime, orchestrator, IaC/GitOps и cloud platform
  берутся из профиля, не из defaults;
- для images соблюдай точные tag/signing/SBOM/provenance constraints;
- tests, manifest и acceptance criteria ради Green не меняй;
- секреты не записывай; используй только одобренные identity/path references;
- execute-deploy здесь не выполняется.

Пиши выбранные delivery artifacts и evidence в stage6-deploy/outputs/. Каждый
артефакт указывает goal_profile_revision и связь с тестами.

---
description: Проверить only-up policy и profile-bound quality characteristics
---

Не изменяй Project. Запусти:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-quality-gates/quality-gates-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS"
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-quality-gates/quality-characteristics-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS"
```

`QUALITY POLICY VERIFIED` возвращает exact `policy_revision`; `QUALITY CHARACTERISTICS
VERIFIED` — exact profile revision и 11 characteristics. Любой сниженный threshold,
неподтверждённый N/A, missing owner/evidence/gate/rationale, stale Product Profile binding,
нарушенная revision chain или snapshot mismatch — `BLOCKED`.

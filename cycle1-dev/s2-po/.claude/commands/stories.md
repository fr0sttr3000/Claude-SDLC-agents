---
description: Backlog, UX applicability и product acceptance из подтверждённых требований
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай User Stories и Product Acceptance artifacts для проекта $ARGUMENTS.

Прочитай:
- current `business-requirements`, `requirements-traceability`, `risk-register` и
  `product-ci-profile` schema v5 по root Current Artifacts rule
- `$SDLC_VAULT/_agents/_contract/PRODUCT_ACCEPTANCE_V1.md`

Создай в `stage2-requirements/outputs/`:

1. `PO-YYYY-MM-DD-backlog.md`: для каждого FR напиши Story, проверь INVEST, если >8SP —
   декомпозируй; минимум 3 Gherkin-сценария. В конце добавь Backlog Summary по MoSCoW и
   оценку спринтов.
2. Если `ux_brief_requirement: required`, создай `PO-YYYY-MM-DD-ux-brief.md` с минимальными
   `UXF-*` flows и `UXC-*` constraints. Иначе создай `PO-YYYY-MM-DD-ux-not-applicable.md`
   с точным interface и основанием из profile. Wireframes не обязательны.
   Для `accessibility_validation: required` добавь confirmed `accessibility_standard`,
   `## Accessibility Criteria` и измеримые `A11Y-*`; для profile N/A запиши structured
   accessibility applicability, `not-applicable` standard и concrete reason.
3. `UAT-YYYY-MM-DD-acceptance-criteria.md`: отдельные end-to-end `UAT-*` product scenarios,
   Must-FR, риски, UX flow/`NOT_APPLICABLE` и явные PO sign-off criteria. Не копируй
   story-level AC.
4. `UAT-product-acceptance-v1.tsv`: точная trace-таблица из Product Acceptance Contract v1.

Свяжи артефакты с текущей `product_profile_revision`, затем обязательно запусти:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/product-acceptance-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS"
```

Не завершай задачу при `BLOCKED`.

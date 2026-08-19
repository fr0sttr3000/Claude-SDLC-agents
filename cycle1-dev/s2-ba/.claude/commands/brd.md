---
description: Написать Business Requirements Document
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Напиши BRD для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/company.md
2. $SDLC_VAULT/_agents/_standards/quality.md
3. $SDLC_VAULT/_agents/_standards/data-formats.md
4. Current `project-constraints`, `feasibility-study`, `product-vision`, `project-charter`,
   `risk-register`, `business-case` по root Current Artifacts rule
5. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/inputs/
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-requirements-raw.md (если есть)

Создай три согласованных артефакта:
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-YYYY-MM-DD-BRD.md
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-YYYY-MM-DD-NFR.md
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-YYYY-MM-DD-RTM.md

BRD: Executive Summary / AS-IS / TO-BE / Scope / FR / BR / Assumptions / Dependencies / Open Issues / Glossary.
NFR: девять current ISO/IEC 25010:2023 characteristics с exact Product Profile applicability,
только измеримые outcomes/пороги с единицами, open-set runtime/data capabilities и явные
`unknown`/`not-applicable` без скрытого выбора endpoint, container, data stack или native type.
RTM: каждый FR/NFR ID → acceptance criteria → planned test level/evidence. Не объявляй Gate 2
PASSED: QA review, test strategy и SG1 создаются следующими независимыми ролями.

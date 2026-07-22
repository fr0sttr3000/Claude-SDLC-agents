---
description: Написать Business Requirements Document
---

Напиши BRD для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/company.md
2. $SDLC_VAULT/_agents/_standards/quality.md
3. $SDLC_VAULT/_agents/_standards/data-formats.md
4. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/PMO-constraints.md
5. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/outputs/
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/inputs/
7. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-requirements-raw.md (если есть)

Создай три согласованных артефакта:
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-YYYY-MM-DD-BRD.md
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-YYYY-MM-DD-NFR.md
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-YYYY-MM-DD-RTM.md

BRD: Executive Summary / AS-IS / TO-BE / Scope / FR / BR / Assumptions / Dependencies / Open Issues / Glossary.
NFR: только измеримые пороги с единицами, topology/data-store/monitoring capabilities и явные
`unknown`/`not-applicable` без скрытого выбора стека.
RTM: каждый FR/NFR ID → acceptance criteria → planned test level/evidence. Не объявляй Gate 2
PASSED: QA review, test strategy и SG1 создаются следующими независимыми ролями.

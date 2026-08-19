---
description: Создать Project Charter
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай Project Charter для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/company.md
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/inputs/
3. Current logical ids `feasibility-study` и `product-vision` по root Current Artifacts rule

Создай ровно два declared outputs:

1. `$SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/outputs/PMO-charter.md`;
2. `$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/PMO-constraints.md` по exact формату role.

В Charter включи все 10 разделов; WBS, RACI, Communication Plan, milestone schedule и
Stakeholder Register являются его секциями, не отдельными файлами. Все пустые поля помечай
[УТОЧНИТЬ]. Оба outputs получают Artifact Metadata v1 с producer `s1-pmo` и своими
registered artifact types/paths.
Обязательные Gate 1 поля: `Charter status: SIGNED`,
`charter_approval_ref: tracking/approvals/APPROVAL-CHARTER-{ID}.yaml` и раздел
`## Objectives`. Агент сначала пишет DRAFT с exact source revision и approval ref, вычисляет
digest и показывает preview со scope `charter-signature`. Только отдельное интерактивное
human action создаёт approval/receipt; агент не пишет подпись. До валидного Human Approval
charter и Gate 1 остаются BLOCKED.
В конце — список Open Items.

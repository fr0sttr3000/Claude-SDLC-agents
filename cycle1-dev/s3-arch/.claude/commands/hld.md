---
description: Создать High-Level Design документ
---

Создай HLD для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/company.md
2. $SDLC_VAULT/_agents/_standards/quality.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/PMO-constraints.md
4. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-*-BRD.md
5. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-*-NFR.md
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-*-RTM.md
7. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/QA-REQ-*-review.md
8. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/QA-*-test-strategy.md
9. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/SEC-*-security-requirements.md

До начала проверь Gate 2 + SG1. Создай:
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-YYYY-MM-DD-HLD.md
- если проект имеет API: machine-readable
  $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-YYYY-MM-DD-api-spec.yaml;
- если API действительно неприменим: ARCH-YYYY-MM-DD-api-not-applicable.md с обоснованием и
  `applicability: not-applicable`.

Структура HLD: ASRs / Architecture pattern + trade-off matrix / C4 / Components / Data strategy /
Integration / NFR Traceability / authorization enforcement / monitoring capabilities / ADR candidates.
API schema должна трассировать operation/schema IDs к BA-RTM и создаваться до tests/code.

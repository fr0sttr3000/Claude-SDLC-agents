---
description: Создать High-Level Design документ
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай HLD для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/company.md
2. $SDLC_VAULT/_agents/_standards/quality.md
3. Current `project-constraints`, `business-requirements`, `nonfunctional-requirements`,
   `requirements-traceability`, `qa-requirements-review`, `test-strategy`,
   `security-requirements`, `ux-requirements`, `uat-criteria`, `product-acceptance-index`,
   `product-ci-profile`, `quality-characteristics-index`, `quality-characteristics-view` по
   root Current Artifacts rule

До начала проверь Gate 2 + SG1. Создай:
- $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-YYYY-MM-DD-HLD.md
- если проект имеет API: machine-readable
  $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-YYYY-MM-DD-api-spec.yaml;
- если API действительно неприменим: ARCH-YYYY-MM-DD-api-not-applicable.md с обоснованием и
  `applicability: not-applicable`.

Структура HLD: ASRs / Architecture pattern + trade-off matrix / C4 / Components / Data strategy /
Integration / NFR Traceability / authorization enforcement / monitoring capabilities / ADR candidates.
API schema должна трассировать operation/schema IDs к BA-RTM и создаваться до tests/code.

HLD оформи по `_contract/ARCHITECTURE_DECISION_TRACE_V1.md`: свяжи его с точной Product
Profile revision, укажи `assumption_policy: no-unconfirmed-stack-or-topology`, добавь
`## Architecture Decision Trace` и стабильные DEC/NFR/QA/TACTIC/PATTERN/ADR ids. Не выбирай
stack или topology, которых нет в подтверждённых входах. Подготовь
`ARCH-decision-trace-v1.tsv`; команда `/adr` завершит его exact ADR URI.

Для schema v5 добавь `## Quality Characteristic Scope` по exact contract: Reliability и
Maintainability всегда REQUIRED с полными dimensions и stable evidence ids; Performance,
Compatibility, Flexibility и Safety строго повторяют profile applicability. Required получает
stable evidence id; Compatibility фиксирует co-existence/interoperability, Flexibility —
install/update/replaceability/configuration portability. N/A получает concrete reason. Не подменяй application reliability frozen
deployment/operations и не создавай ADR без реального decision candidate.

---
description: Создать или обновить machine-readable API contract до реализации
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter. Нативный YAML сохраняет свой schema contract.

Для проекта $ARGUMENTS сначала прочитай `_contract/APPLICABILITY_V1.md`, ARCH-HLD,
BA-BRD/NFR/RTM, QA test strategy и SG1. Получи scope только командой
`applicability-resolve.sh resolve ... api-contract`.

Если API применим, создай или обнови
`$SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-YYYY-MM-DD-api-spec.yaml`.
Спецификация должна быть machine-readable, валидной для выбранного protocol/schema format,
с operation/schema IDs, error contract, auth requirements и трассировкой к FR/NFR IDs.

При `NOT_APPLICABLE` не создавай фиктивную schema: создай
`ARCH-YYYY-MM-DD-api-not-applicable.md` типа `applicability-decision` с exact
capability/field/value/profile revision/owner/reason из resolver и проверь через его
`validate` mode. Production code и contract tests на этом шаге не писать.

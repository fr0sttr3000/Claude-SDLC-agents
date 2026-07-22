---
description: Создать или обновить machine-readable API contract до реализации
---

Для проекта $ARGUMENTS сначала прочитай ARCH-HLD, BA-BRD/NFR/RTM, QA test strategy и SG1.

Если API применим, создай или обнови
`$SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-YYYY-MM-DD-api-spec.yaml`.
Спецификация должна быть machine-readable, валидной для выбранного protocol/schema format,
с operation/schema IDs, error contract, auth requirements и трассировкой к FR/NFR IDs.

Если API неприменим, не создавай фиктивную schema: создай
`ARCH-YYYY-MM-DD-api-not-applicable.md` с `applicability: not-applicable` и проверяемым
обоснованием. Production code и contract tests на этом шаге не писать.

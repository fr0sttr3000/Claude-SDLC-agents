---
description: Спроектировать migration strategy и test requirements до executable migration
---

Перед записью Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Для проекта $ARGUMENTS прочитай data-formats, TDD standard, BRD/NFR, HLD/ADR и
существующий data design. Если data store/technology не выбраны — верни BLOCKED.

Сначала разреши capability `data-store` через canonical applicability resolver. При
`NOT_APPLICABLE` создай только `DBA-YYYY-MM-DD-migration-not-applicable.md` типа
`applicability-decision` с exact capability/field/value/profile revision/owner/reason.
Не создавай runbook, migration code или фиктивный migration test. При `REQUIRED` продолжай.

Создай `DBA-YYYY-MM-DD-migration-runbook.md` в `stage3-design/outputs/`:

1. Goal и traceability IDs.
2. Применимый engine/tooling без silent default.
3. Preconditions, compatibility window и dependency order.
4. Design шагов forward/rollback; irreversible step пометь BLOCKED до подтверждения.
5. Backup/restore требования, если есть изменяемые данные.
6. Verification queries/checks и наблюдаемые success/failure criteria.
7. Migration tests, которые QA-TDD напишет и запустит до реализации.
8. Ownership и handoff в Stage 4.

На Stage 3 не создавай executable migration, не применяй schema и не утверждай,
что upgrade/downgrade протестированы. Реализация начинается только после настоящего
RED от migration tests в Stage 4.

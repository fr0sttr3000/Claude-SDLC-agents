---
description: Спроектировать data-store schema в нативном формате выбранного stack
---

Спроектируй data-store schema для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/data-formats.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-HLD.md
4. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-BRD.md

Сначала определи из HLD/ADR:
- нужен ли persistent data store;
- точный engine/версию и schema/migration format;
- identifier, datetime, money, deletion и consistency contracts.

Если persistent data store не нужен, создай DBA-[дата]-not-applicable.md с причиной
и HLD evidence. Иначе создай DBA-[дата]-schema в нативном формате выбранного
engine; SQL/DBML создавай только если они применимы.

# Обязательные гарантии

- Типы, nullability, identifiers и constraints трассируются к BRD/HLD.
- Временные значения сохраняют согласованную timezone semantics.
- Деньги/точные величины не используют тип с потерей точности.
- Migration strategy содержит проверяемые forward/rollback действия.
- Retention/deletion выбираются из requirements; soft delete не является default.
- Stack-specific правила data-formats.md применяются только к соответствующему stack.

В Gate 3 checklist укажи выбранный engine/format, identifier strategy,
применимые format checks, migration evidence и обоснованные N/A. Не подставляй
PostgreSQL, SQLAlchemy, UUID, TIMESTAMPTZ или soft delete без выбора проекта.

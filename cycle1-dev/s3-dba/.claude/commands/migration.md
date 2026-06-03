---
description: Создать Alembic миграцию с runbook (upgrade + downgrade)
---

Создай план миграции базы данных для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/data-formats.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/DBA-schema.sql (если существует)

Создай файл DBA-[дата]-migration-runbook.md в:
$SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/

# Migration Runbook — $ARGUMENTS
Дата: [сегодня]
Агент: s3-dba

## Миграции (список)
Для каждой миграции:

### [N]. [Название]
**Цель:** [что и зачем меняем]
**Риск:** Low / Medium / High
**Downtime:** None / Brief / Required

```python
# alembic upgrade
def upgrade() -> None:
    ...

# alembic downgrade — ОБЯЗАТЕЛЕН для каждой миграции
def downgrade() -> None:
    ...
```

**Проверка после upgrade:**
```sql
-- запрос для подтверждения
```

## Expand-Contract Pattern (zero-downtime)
Используй для breaking changes:
1. **Expand** — добавить новый столбец/таблицу (nullable)
2. **Migrate** — перенести данные
3. **Contract** — удалить старый столбец/таблицу

## Обязательные правила Alembic
- `alembic.ini`: `args = (sys.stdout,)` — не stderr
- `migrations/env.py`: `fileConfig(..., disable_existing_loggers=False)` — иначе трейсбеки из app исчезают
- `server_default`: только строковые литералы — не `func.cast(...)` (некорректный DDL)

## Checklist перед применением
□ Каждая миграция имеет `upgrade()` и `downgrade()`
□ Протестировано: `alembic upgrade head` + `downgrade -1` + `upgrade head` на чистой БД
□ Rollback-команды задокументированы
□ Backup БД сделан перед применением в prod

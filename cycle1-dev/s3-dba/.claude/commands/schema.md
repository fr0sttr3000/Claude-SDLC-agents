---
description: Спроектировать схему базы данных (PostgreSQL, TIMESTAMPTZ, UUID v4)
---

Спроектируй схему базы данных для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/data-formats.md
3. $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/ARCH-HLD.md
4. $SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/BA-BRD.md

Создай файлы в $SDLC_VAULT/projects/$ARGUMENTS/stage3-design/outputs/:
- DBA-[дата]-schema.sql
- DBA-[дата]-schema.dbml

# Требования к схеме (строго обязательны)

## Стандарты полей
- PK: `UUID DEFAULT gen_random_uuid()` — никогда SERIAL/INTEGER
- Timestamps: `created_at TIMESTAMPTZ DEFAULT NOW()`, `updated_at TIMESTAMPTZ`, `deleted_at TIMESTAMPTZ` (soft delete)
- Naming: snake_case, таблицы во мн. числе
- NOT NULL по умолчанию, NULL только с явным обоснованием

## Критические правила (баги из prod)
- Все datetime: `TIMESTAMP WITH TIME ZONE` (TIMESTAMPTZ) — никогда WITHOUT TIME ZONE
- Деньги/финансы: `NUMERIC(12,2)` — никогда FLOAT/REAL/DOUBLE
- VARCHAR: всегда с явным лимитом `VARCHAR(N)`, не голый VARCHAR
- Функциональные индексы: только IMMUTABLE функции

## Обязательная документация в схеме
- Каждое JSONB-поле: комментарий с примером структуры `-- {"key": "value"}`
- Каждый ENUM-тип: перечислены все значения + способ добавления нового
- Каждый CHECK constraint: задокументирован с причиной ограничения

## Gate 3 — DBA Checklist
□ Все таблицы: PK UUID, created_at, updated_at, deleted_at
□ Все datetime: TIMESTAMPTZ — grep "WITHOUT TIME ZONE" = 0
□ Деньги/финансы: NUMERIC — grep "FLOAT\|REAL\|DOUBLE" = 0
□ Функциональные индексы: только IMMUTABLE функции
□ Каждое JSONB-поле: комментарий с примером JSON
□ Каждый VARCHAR: явный лимит
□ DBA-schema.sql/.dbml переданы в stage3-design/outputs/

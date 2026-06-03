# CLAUDE.md — Агент: Backend Developer (Этап 4)

## Идентичность агента
Ты — Senior Backend Developer. Пишешь чистый, тестируемый, безопасный код.
Этап SDLC: 4 — Разработка.

## Стандарты (читать перед каждой задачей)
$SDLC_VAULT/_agents/_standards/quality.md
$SDLC_VAULT/_agents/_standards/data-formats.md

## Пути файлов
Читай:
  $SDLC_VAULT/projects/{PROJECT}/stage3-design/outputs/ARCH-HLD.md
  $SDLC_VAULT/projects/{PROJECT}/stage3-design/outputs/ARCH-api-spec.yaml
  $SDLC_VAULT/projects/{PROJECT}/stage2-requirements/outputs/PO-backlog.md
Пиши отчёты в: $SDLC_VAULT/projects/{PROJECT}/stage4-dev/outputs/

## TDD Workflow
Red → Green → Refactor

## Code Quality Rules
- Функции: максимум 20 строк, SRP
- Cyclomatic complexity: ≤ 10
- Нет магических чисел → константы
- DRY / YAGNI

## Security Checklist
□ Все вводы валидируются
□ Только parameterized queries
□ Нет секретов в коде
□ Авторизация на каждом endpoint

## Python-стек — Known Pitfalls (из prod-багов)

### pydantic-settings v2 (Баг 1)
- Сложные типы (`frozenset[int]`, `list[str]`, `set[int]`) в `.env` должны быть в JSON-формате:
  - ❌ `ALLOWED_USERS=123,456` — невалидный JSON, SettingsError до запуска validator
  - ✅ `ALLOWED_USERS=[123,456]` — json.loads() успешен, validator получает list
- Validator с `mode="before"` должен обрабатывать все входные типы: `str`, `list`, `set`, `frozenset`
- Добавлять `extra="ignore"` чтобы избежать ValidationError на неизвестные env-переменные
- Полная таблица форматов по типам — см. data-formats.md §2.2

### Обязательные файлы тестов форматов (data-formats.md §4)
При наличии .env / pydantic Settings — создать `tests/test_env_format.py`:
- Тест: корректный env загружается без ошибок
- Тест: list/set в JSON-формате парсится; CSV-формат вызывает ошибку
- Тест: невалидный URL вызывает ValidationError
- Тест: out-of-range числа вызывают ValidationError
- Тест: недопустимое enum-значение вызывает ValidationError

При наличии SQLAlchemy/asyncpg — создать `tests/test_db_format.py`:
- Тест: timezone-aware datetime вставляется без ошибок asyncpg
- Тест: timezone-naive datetime не проходит молча
- Тест: PK — UUID v4
- Тест: NUMERIC-поля не теряют точность
- Тест: migration upgrade→downgrade→upgrade на чистой БД

При наличии HTTP API — создать `tests/test_api_format.py`:
- Тест: datetime в ответах — ISO 8601 UTC
- Тест: UUID в ответах — строка UUID v4
- Тест: ошибки — стандартный формат {error, detail}

Шаблоны тестов — в data-formats.md §4.1, §4.2, §4.3

### Alembic setup (Баги 2, 3)
- `alembic.ini`: `args = (sys.stdout,)` — не stderr; Docker капчурит оба потока, но stdout единообразен
- `migrations/env.py`: `fileConfig(config.config_file_name, disable_existing_loggers=False)`
  - Без этого fileConfig выставляет `disabled=True` у всех логгеров вне alembic.ini
  - Следствие: `logger.exception()` из main.py становится no-op, трейсбек исчезает

### ORM + asyncpg datetime (Баг 5)
- Все datetime-поля: `mapped_column(TIMESTAMP(timezone=True), ...)` — явно, не `Mapped[datetime]` без типа
- `Mapped[datetime]` без SQLAlchemy-типа → `TIMESTAMP WITHOUT TIME ZONE` → asyncpg падает на timezone-aware значениях

### SQLAlchemy server_default + миграции (CR-01, Баг 4)
- `server_default` — **только строковый литерал**: `server_default="none"`
  - ❌ `server_default=func.cast(VALUE, String)` — генерирует некорректный DDL, миграция падает
- Функциональные индексы — **только на IMMUTABLE-выражениях**
  - ❌ `date_trunc('month', event_date)` на колонке `date` — `date_trunc` STABLE → миграция упадёт
  - ✅ явный каст к immutable-типу: `date_trunc('month', event_date::timestamp)`

### Корректность production-кода (INC-08)
- **`assert` запрещён в production-коде** (вне тестов) — отключается флагом `python -O`, проверка молча исчезнет
  - ❌ `assert result.reminder is not None`
  - ✅ `if result.reminder is None: raise ...`
- **Неиспользуемые импорты** удалять сразу — особенно "хвосты" после рефакторинга/удаления метода
  - При удалении метода проверять, не осиротели ли его импорты

### Telegram / aiogram (CR-02, CR-03, CR-04)
- `callback.message.bot` может быть `None` — инъецировать `bot: Bot` как параметр handler'а, не брать из message
- Scheduler-функции: всегда guard `if _bot is None: return` перед использованием bot-объекта
- Parse mode: использовать **HTML** (`parse_mode=ParseMode.HTML`), не Markdown v1
  - Markdown v1 ломается на `_`, `*`, `` ` `` в пользовательском контенте без экранирования

## RBAC — Реализация (FastAPI + SQLAlchemy)

Читать перед реализацией авторизации:
- `stage3-design/outputs/RBAC-*-model.md` — роли, иерархия, ресурсы
- `stage3-design/outputs/RBAC-*-matrix.md` — матрица прав (роль × ресурс × действие)
- `stage3-design/outputs/RBAC-*-schema.sql` — SQL-схема таблиц RBAC

### Шаблон: dependency для FastAPI

```python
# app/auth/dependencies.py
from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_session
from app.auth.models import User
from app.rbac.service import has_permission

def require_permission(resource: str, action: str):
    async def _check(
        current_user: User = Depends(get_current_user),
        session: AsyncSession = Depends(get_session),
    ) -> User:
        allowed = await has_permission(session, current_user.id, resource, action)
        if not allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        return current_user
    return _check
```

```python
# app/rbac/service.py
from uuid import UUID
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

async def has_permission(
    session: AsyncSession, user_id: UUID, resource: str, action: str
) -> bool:
    result = await session.execute(
        text("""
            SELECT 1
            FROM user_roles ur
            JOIN role_permissions rp ON rp.role_id = ur.role_id
            JOIN permissions p ON p.id = rp.permission_id
            WHERE ur.user_id = :user_id
              AND p.resource = :resource
              AND p.action = :action
            LIMIT 1
        """),
        {"user_id": user_id, "resource": resource, "action": action},
    )
    return result.scalar() is not None
```

### Шаблон: использование на endpoint

```python
# app/api/v1/documents.py
@router.delete("/{doc_id}", dependencies=[Depends(require_permission("document", "delete"))])
async def delete_document(doc_id: UUID, session: AsyncSession = Depends(get_session)):
    ...
```

### Шаблон: owner-only (RLS + application check)

```python
# app/rbac/service.py
async def is_owner(session: AsyncSession, user_id: UUID, resource_id: UUID, table: str) -> bool:
    result = await session.execute(
        text(f"SELECT 1 FROM {table} WHERE id = :rid AND owner_id = :uid LIMIT 1"),
        {"rid": resource_id, "uid": user_id},
    )
    return result.scalar() is not None
```

RLS в PostgreSQL (дополнительный слой, не замена application check):
```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY owner_isolation ON documents
    USING (owner_id = current_setting('app.current_user_id')::uuid);
```

Установка контекста перед запросом:
```python
await session.execute(text("SET LOCAL app.current_user_id = :uid"), {"uid": str(user_id)})
```

### Шаблон: наследование ролей

```python
# app/rbac/service.py — рекурсивный CTE для иерархии ролей
async def get_effective_roles(session: AsyncSession, user_id: UUID) -> list[UUID]:
    result = await session.execute(
        text("""
            WITH RECURSIVE role_tree AS (
                SELECT role_id FROM user_roles WHERE user_id = :uid
                UNION
                SELECT rh.parent_role_id
                FROM role_hierarchy rh
                JOIN role_tree rt ON rt.role_id = rh.child_role_id
            )
            SELECT role_id FROM role_tree
        """),
        {"uid": user_id},
    )
    return [row[0] for row in result.fetchall()]
```

### Правила реализации RBAC

- **Deny by Default**: если право не найдено → 403, никогда не 200
- **Не дублировать матрицу в коде** — строки `resource`/`action` берутся из constans, совпадающих с RBAC-*-matrix.md
- **Нет хардкода ролей** в бизнес-логике (`if user.role == "admin"`) — только через `has_permission()`
- **Owner-check** — двойной: application-level + RLS (оба обязательны для owner_only ресурсов)
- **SoD-конфликты** из матрицы → проверять при назначении роли:
  ```python
  async def assign_role(session, user_id, role_id):
      conflicts = await get_sod_conflicts(session, user_id, role_id)
      if conflicts:
          raise ValueError(f"SoD violation: {conflicts}")
  ```

### Обязательные тесты RBAC (`tests/test_rbac.py`)

```python
# Шаблон — адаптировать под матрицу проекта
async def test_deny_by_default(session, user_without_roles):
    assert not await has_permission(session, user_without_roles.id, "document", "delete")

async def test_role_grants_permission(session, user_with_editor_role):
    assert await has_permission(session, user_with_editor_role.id, "document", "edit")

async def test_role_hierarchy_inherited(session, user_with_admin_role):
    # admin наследует editor → должен иметь editor-права
    assert await has_permission(session, user_with_admin_role.id, "document", "edit")

async def test_owner_only_blocks_other_user(session, user_a, user_b, document_owned_by_a):
    assert not await is_owner(session, user_b.id, document_owned_by_a.id, "documents")

async def test_sod_conflict_raises(session, user, conflicting_role_id):
    with pytest.raises(ValueError, match="SoD violation"):
        await assign_role(session, user.id, conflicting_role_id)
```

### Gate 4 — RBAC checklist (добавить к DoD)

□ `tests/test_rbac.py` создан: deny-by-default, role grants, hierarchy, owner-only, SoD
□ Нет хардкода ролей в бизнес-логике (`if role == "..."`)
□ Все endpoints с доступом к данным используют `require_permission()`
□ Owner-only ресурсы: двойная проверка (app + RLS)
□ Константы resource/action совпадают с RBAC-*-matrix.md

## Conventional Commits
feat / fix / refactor / test / docs

## Обязательное обновление документации (после каждого PR)
После завершения PR ты ОБЯЗАН обновить документацию — это блокирующее условие:

□ **README** — отразить новые/изменённые команды, переменные окружения, конфигурацию
□ **API-доки** — обновить ARCH-api-spec.yaml или аналогичный контракт, если менялись эндпоинты
□ **Inline-комментарии** — публичные функции/классы должны иметь актуальные docstring
□ **CHANGELOG** — добавить запись в `docs/CHANGELOG.md` проекта в формате:
  ```
  ## [Unreleased]
  ### Added / Changed / Fixed / Removed
  - краткое описание изменения (PR #N)
  ```
□ **ADR** — если решение изменяет архитектуру, создай/обнови ADR в stage3-design/outputs/

Файл с update notes пиши в:
`$SDLC_VAULT/projects/{PROJECT}/stage4-dev/outputs/DEV-YYYY-MM-DD-update-notes-PR[N].md`

Формат update notes:
```
# Update Notes — PR #N — YYYY-MM-DD
## Что изменилось
## Влияние на API / схему БД / конфигурацию
## Требуемые действия при деплое (миграции, env-переменные)
## Ссылки на обновлённую документацию
```

## Именование файлов
DEV-YYYY-MM-DD-PR-[N]-summary.md
DEV-YYYY-MM-DD-update-notes-PR[N].md

## Интерактивный старт
Когда получаешь сообщение "начни сессию" — немедленно инициируй диалог:
1. Представься: назови роль, этап SDLC и что ты делаешь (1-2 строки)
2. Перечисли доступные задачи / slash-команды кратким списком
3. Спроси: какой проект и что нужно сделать?
Не жди дополнительных инструкций — начинай сразу.

## Quality Gate — вход и выход этапа 4 (Dev)

### ВХОД (Gate 3): проверить перед началом каждого спринта
□ ARCH-HLD.md существует в stage3-design/outputs/
□ SEC-*-threat-model.md существует с вердиктом PASS или CONDITIONAL PASS
□ RBAC-*-model.md и RBAC-*-matrix.md существуют в stage3-design/outputs/
□ DBA-schema.sql или DBA-schema.dbml существует
□ Нет открытых Critical/High угроз из Threat Model
Если Gate 3 не пройден → сообщить об этом, не начинать разработку.

При реализации аутентификации/авторизации — читать RBAC-*-model.md и реализовывать
права строго по матрице. Изменения в RBAC требуют обновления RBAC артефактов (через s3-rbac).

### ВЫХОД (вклад в Gate 4): проверять после каждого PR
□ Definition of Done (DoD) из quality.md §2 выполнен — все 11 пунктов (включая DoD-11)
□ Unit coverage ≥ 80% изменённого кода
□ Документация обновлена (README/API-spec/docstring/CHANGELOG)
□ DEV-*-update-notes-PR[N].md создан
□ SAST/secrets-scan прошёл без Critical/High
□ Нет игнорированных исключений (pass/except без logging)
□ grep "assert " в production-коде (вне tests/) = 0 результатов
□ Нет неиспользуемых импортов (linter/ruff F401 чист)
□ server_default — строковый литерал, не func.cast (grep "server_default=func" = 0)

# Валидация форматов (data-formats.md §5 s4-dev / §6 Gate 4)
□ tests/test_env_format.py создан и все тесты проходят (если есть .env)
□ tests/test_db_format.py создан и все тесты проходят (если есть SQLAlchemy/asyncpg)
□ tests/test_api_format.py создан и все тесты проходят (если есть HTTP API)
□ grep "WITHOUT TIME ZONE" в ORM-моделях = 0 результатов
□ grep "Mapped\[datetime\]" без TIMESTAMP(timezone=True) = 0 результатов
□ README содержит таблицу ENV-переменных: имя, тип, формат, дефолт, обязательность

## Хранение секретов
Все секреты хранятся ТОЛЬКО в pass. Никаких исключений.

Получить секрет:
  pass sdlc/ключ
  pass sdlc/projects/{PROJECT}/ключ
  export VAR=$(pass sdlc/ключ)

ЗАПРЕЩЕНО:
- Записывать секреты в .md файлы (заметки, артефакты)
- Хранить секреты в .env без pass как источника
- Передавать секреты между агентами текстом
- Коммитить файлы с секретами

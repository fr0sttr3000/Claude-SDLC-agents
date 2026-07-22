# Стандарт валидации форматов данных — SDLC Vault

> Единственный источник истины по форматам данных в системе.
> Читается агентами: **s2-ba, s3-dba, s4-dev, s5-qa-auto**.
> Применимые правила не опциональны — нарушение = BLOCKER. Конкретный data stack,
> ORM и стратегия идентификаторов берутся из HLD/ADR проекта, без silent defaults.

---

## 1. Типы данных: БД ↔ ORM ↔ язык — обязательное соответствие

Таблица ниже применяется только если выбран PostgreSQL + SQLAlchemy + Python.
Для другого stack используй его нативные типы с теми же гарантиями контракта
(timezone, точность денег, ограничения строк и проверяемая schema). UUID v4
проверяется только если эта стратегия идентификаторов явно выбрана в HLD/ADR.

| PostgreSQL | SQLAlchemy ORM | Python | Правило |
|-----------|----------------|--------|---------|
| `TIMESTAMPTZ` | `TIMESTAMP(timezone=True)` | `datetime` (aware, UTC) | **ВСЕГДА WITH TIME ZONE** |
| `UUID` | `UUID` / `String(36)` | `uuid.UUID` | UUID v4 только при выбранном UUID-v4 contract |
| `VARCHAR(N)` | `String(N)` | `str` | Лимит N — обязателен |
| `TEXT` | `Text()` | `str` | Только для неограниченного текста |
| `INTEGER` | `Integer()` | `int` | Счётчики, малые числа |
| `BIGINT` | `BigInteger()` | `int` | Большие числовые ID |
| `BOOLEAN` | `Boolean()` | `bool` | Не `int(0/1)` |
| `NUMERIC(p,s)` | `Numeric(p, s)` | `Decimal` | Деньги/финансы — **только NUMERIC** |
| `JSONB` | `JSONB()` | `dict` / `list` | Схема JSON обязана быть задокументирована |
| `ENUM('a','b')` | `Enum(MyEnum)` | `enum.Enum` | Изменение ENUM требует миграции |
| `ARRAY(type)` | `ARRAY(type)` | `list[type]` | Тип элементов обязателен |

### Запрещено (нарушение = BLOCKER)
```
✗ TIMESTAMP WITHOUT TIME ZONE — asyncpg падает на timezone-aware значениях
✗ FLOAT / DOUBLE для денег — потеря точности, использовать NUMERIC
✗ Хранение списков в VARCHAR через запятую — использовать ARRAY или JSONB
✗ ORM-маппинг без явного типа: Mapped[datetime] без TIMESTAMP(timezone=True)
✗ VARCHAR без лимита N — использовать TEXT если нет ограничения
✗ Хардкод строк вместо ENUM, когда значения фиксированы
```

---

## 2. Env-переменные — формат и валидация (pydantic-settings v2)

### 2.1 Обязательная спецификация каждой переменной

Каждая env-переменная задокументируется в README / BRD / NFR по схеме:

| Поле | Описание | Пример |
|------|----------|--------|
| `Имя` | Название переменной | `ALLOWED_USERS` |
| `Тип Python` | Тип в Settings-модели | `list[int]` |
| `Формат в .env` | Как записывать значение | JSON: `[123, 456]` |
| `По умолчанию` | Значение или «обязательная» | — (обязательная) |
| `Источник` | pass-путь или описание | `pass sdlc/project/allowed-users` |
| `Правило валидации` | Ограничения значений | все элементы > 0 |

### 2.2 Таблица форматов .env по типам

| Python тип | Формат в .env | Пример | Частая ошибка |
|-----------|--------------|--------|---------------|
| `str` | строка | `APP_NAME=myapp` | — |
| `int` | число | `PORT=8080` | `PORT=8080.0` |
| `float` | число | `RATE=0.95` | — |
| `bool` | `true` / `false` | `DEBUG=false` | `DEBUG=1`, `DEBUG=yes` |
| `list[T]` | JSON-массив | `IDS=[1,2,3]` | `IDS=1,2,3` ← BLOCKER |
| `set[T]` | JSON-массив | `IDS=[1,2,3]` | `IDS=1,2,3` ← BLOCKER |
| `frozenset[T]` | JSON-массив | `IDS=[1,2,3]` | `IDS=1,2,3` ← BLOCKER |
| `dict[K,V]` | JSON-объект | `MAP={"a":1}` | `MAP=a:1` ← BLOCKER |
| `Enum` | строка-значение | `MODE=production` | `MODE=PRODUCTION` (case-sensitive) |
| `AnyUrl` / `DSN` | полный URL | `DB_URL=postgresql+asyncpg://...` | без схемы |
| `SecretStr` | строка (из pass) | `TOKEN=xxx` | не хардкодить |

### 2.3 Правила validator-методов (pydantic-settings v2)

```python
@field_validator("allowed_users", mode="before")
@classmethod
def parse_list(cls, v):
    # Обрабатывать все входные типы: str, list, set, frozenset
    if isinstance(v, str):
        import json
        return json.loads(v)
    return list(v)
```

- `extra="ignore"` — добавлять в Settings, чтобы неизвестные env не вызывали ValidationError
- Validator должен обрабатывать: `str`, `list`, `set`, `frozenset` — не только строку

---

## 3. API / JSON-контракт — форматы полей

| Тип данных | Формат в JSON | Пример |
|-----------|--------------|--------|
| Дата/время | ISO 8601 UTC | `"2026-05-10T12:00:00Z"` |
| Identifier | формат из API contract; например UUID v4 | `"550e8400-e29b-41d4-a716-446655440000"` |
| Деньги | строка с 2 знаками | `"12.50"` (не `12.5`, не `float`) |
| Булево | `true` / `false` | не `1`/`0`, не `"yes"`/`"no"` |
| Enum | строка-значение | документировать в OpenAPI `enum: [...]` |
| Nullable | поле может быть `null` | явно `nullable: true` в OpenAPI |

### Стандартный формат ошибки API (обязательный)
```json
{
  "error": "VALIDATION_ERROR",
  "detail": "field 'email' must be a valid email address",
  "field": "email",
  "code": "INVALID_FORMAT"
}
```

---

## 4. Обязательные тесты форматов данных

### 4.1 `tests/test_env_format.py` — обязателен при наличии .env

```python
# tests/test_env_format.py
import pytest
from pydantic import ValidationError
from app.config import Settings

class TestEnvFormat:
    def test_settings_load_without_error(self, valid_env):
        """Settings создаётся без исключений при корректных env"""
        settings = Settings()
        assert settings is not None

    def test_list_var_accepts_json_array(self, monkeypatch):
        """list-переменные: JSON-массив [1,2,3] парсится успешно"""
        monkeypatch.setenv("ALLOWED_USERS", "[123, 456]")
        settings = Settings()
        assert settings.allowed_users == [123, 456]

    def test_list_var_rejects_csv(self, monkeypatch):
        """list-переменные: CSV-формат 1,2,3 вызывает ошибку"""
        monkeypatch.setenv("ALLOWED_USERS", "123,456")
        with pytest.raises((ValidationError, Exception)):
            Settings()

    def test_bool_var_accepts_true_false(self, monkeypatch):
        """bool-переменные: 'true'/'false' — корректный формат"""
        monkeypatch.setenv("DEBUG", "false")
        settings = Settings()
        assert settings.debug is False

    def test_bool_var_rejects_numeric(self, monkeypatch):
        """bool-переменные: '1'/'0' недопустимы (если не сконфигурировано)"""
        monkeypatch.setenv("DEBUG", "1")
        with pytest.raises(ValidationError):
            Settings()

    def test_url_var_valid_format(self, monkeypatch):
        """URL-переменные валидируются как корректный URL"""
        monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")
        settings = Settings()
        assert settings.database_url is not None

    def test_url_var_rejects_invalid(self, monkeypatch):
        """Невалидный URL вызывает ValidationError"""
        monkeypatch.setenv("DATABASE_URL", "not-a-url")
        with pytest.raises(ValidationError):
            Settings()

    def test_numeric_var_in_range(self, monkeypatch):
        """Числовые переменные в допустимом диапазоне"""
        monkeypatch.setenv("PORT", "8080")
        settings = Settings()
        assert 1 <= settings.port <= 65535

    def test_enum_var_valid_value(self, monkeypatch):
        """Enum-переменные: только документированные значения"""
        monkeypatch.setenv("LOG_LEVEL", "INFO")
        settings = Settings()
        assert settings.log_level == "INFO"

    def test_enum_var_rejects_invalid(self, monkeypatch):
        """Enum-переменные: недопустимое значение вызывает ошибку"""
        monkeypatch.setenv("LOG_LEVEL", "VERBOSE")
        with pytest.raises(ValidationError):
            Settings()
```

### 4.2 `tests/test_db_format.py` — обязателен при наличии SQLAlchemy/asyncpg

```python
# tests/test_db_format.py
import uuid
import pytest
from datetime import datetime, timezone

class TestDBFormat:
    async def test_datetime_timezone_aware_insert(self, db_session):
        """timezone-aware datetime вставляется без ошибок asyncpg"""
        record = MyModel(created_at=datetime.now(timezone.utc))
        db_session.add(record)
        await db_session.commit()
        await db_session.refresh(record)
        assert record.created_at.tzinfo is not None

    async def test_datetime_naive_rejected_or_converted(self, db_session):
        """timezone-naive datetime НЕ проходит молча (теряет TZ-информацию)"""
        # Поведение должно быть явным: либо ошибка, либо конвертация с логированием
        naive_dt = datetime.now()  # без timezone
        with pytest.raises(Exception):
            record = MyModel(created_at=naive_dt)
            db_session.add(record)
            await db_session.commit()

    async def test_pk_uuid_v4_format(self, db_session):
        """PK соответствует явно выбранному UUID-v4 contract"""
        record = await create_test_record(db_session)
        pk = record.id
        parsed = uuid.UUID(str(pk))
        assert parsed.version == 4

    async def test_decimal_field_no_float_precision_loss(self, db_session):
        """NUMERIC-поля: нет потери точности (деньги/финансы)"""
        from decimal import Decimal
        record = MyFinancialModel(amount=Decimal("12.99"))
        db_session.add(record)
        await db_session.commit()
        await db_session.refresh(record)
        assert record.amount == Decimal("12.99")  # не 12.990000001

    async def test_jsonb_field_schema_valid(self, db_session):
        """JSONB-поля соответствуют задокументированной схеме"""
        valid_data = {"key": "value", "count": 1}
        record = MyModel(metadata=valid_data)
        db_session.add(record)
        await db_session.commit()
        await db_session.refresh(record)
        assert record.metadata["key"] == "value"

    async def test_enum_field_rejects_invalid_value(self, db_session):
        """Enum-поля: недопустимое значение отвергается"""
        with pytest.raises(Exception):
            record = MyModel(status="INVALID_STATUS")
            db_session.add(record)
            await db_session.commit()

    def test_migration_upgrade_downgrade_upgrade(self, empty_db_url):
        """Alembic: upgrade → downgrade → upgrade на чистой БД"""
        from alembic.config import Config
        from alembic import command
        cfg = Config("alembic.ini")
        cfg.set_main_option("sqlalchemy.url", empty_db_url)
        command.upgrade(cfg, "head")
        command.downgrade(cfg, "-1")
        command.upgrade(cfg, "head")
        # Нет исключений = PASS

    async def test_soft_delete_not_hard_delete(self, db_session):
        """Soft delete: запись помечается deleted_at, не удаляется физически"""
        record = await create_test_record(db_session)
        await soft_delete(db_session, record)
        # Физически запись существует
        result = await db_session.execute(
            select(MyModel).where(MyModel.id == record.id)
        )
        assert result.scalar_one_or_none() is not None
        assert record.deleted_at is not None
```

### 4.3 `tests/test_api_format.py` — обязателен при наличии HTTP API

```python
# tests/test_api_format.py
import uuid
from datetime import datetime

class TestAPIFormat:
    async def test_datetime_response_iso8601_utc(self, client):
        """datetime в ответах API: ISO 8601 с UTC ('Z' или '+00:00')"""
        response = await client.get("/items/1")
        assert response.status_code == 200
        created_at = response.json()["created_at"]
        # Парсинг не должен кидать ValueError
        dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        assert dt.tzinfo is not None

    async def test_identifier_matches_api_contract(self, client):
        """Identifier соответствует выбранному API contract; ниже пример UUID v4"""
        response = await client.get("/items/1")
        item_id = response.json()["id"]
        parsed = uuid.UUID(item_id)
        assert parsed.version == 4

    async def test_error_response_standard_format(self, client):
        """Ошибки API: стандартный формат {error, detail, field, code}"""
        response = await client.get("/items/invalid-uuid")
        assert response.status_code in (400, 404, 422)
        body = response.json()
        assert "error" in body or "detail" in body  # хотя бы одно обязательно

    async def test_validation_error_includes_field_name(self, client):
        """Ошибки валидации: указывают конкретное поле"""
        response = await client.post("/items", json={"invalid_field": "x"})
        assert response.status_code == 422
        body = response.json()
        # Ответ содержит информацию о поле
        assert any(
            "field" in str(body).lower() or
            "loc" in str(body).lower()  # pydantic default
        )

    async def test_request_accepts_iso8601_datetime(self, client):
        """Запросы API принимают ISO 8601 datetime"""
        response = await client.post("/items", json={
            "scheduled_at": "2026-05-10T12:00:00Z"
        })
        assert response.status_code != 400

    async def test_request_rejects_non_iso_datetime(self, client):
        """Запросы API отвергают нестандартный формат даты"""
        response = await client.post("/items", json={
            "scheduled_at": "10.05.2026 12:00"  # не ISO 8601
        })
        assert response.status_code == 422
```

---

## 5. Чеклист форматов для каждого агента

### s2-ba — при написании BRD/NFR
```
□ Каждая env-переменная задокументирована: имя, тип, формат, дефолт, обязательность
□ list/set-переменные: явно указан формат JSON-массива (не CSV)
□ URL-переменные: указана схема (postgresql+asyncpg://, redis://, etc.)
□ JSONB-поля в требованиях: задокументирована ожидаемая структура (пример JSON)
□ Enum-поля: перечислены допустимые значения
□ Форматы datetime: явно "ISO 8601 UTC" — не "дата"
```

### s3-dba — при проектировании схемы
```
□ Сначала зафиксированы выбранный data store и применимость SQL/PostgreSQL-правил
□ Для PostgreSQL: datetime = TIMESTAMPTZ, деньги = NUMERIC(p,s), JSONB schema документирована
□ Для другого store: зафиксированы stack-native эквиваленты timezone, decimal precision,
  identifier, enum/schema validation и migration rollback; молчаливый PostgreSQL default запрещён
□ PK/identifier strategy обоснована требованиями и совместимостью, а не выбрана скрытым default
```

### s4-dev — при реализации
Проверяй только применимые к выбранному stack пункты; неприменимые фиксируй N/A
со ссылкой на HLD/ADR.
```
□ tests/test_env_format.py создан при наличии pydantic-settings и содержит тесты из §4.1
□ tests/test_db_format.py создан при наличии SQLAlchemy/asyncpg и содержит тесты из §4.2
□ tests/test_api_format.py создан при наличии HTTP API и содержит тесты из §4.3
□ Для SQLAlchemy/PostgreSQL ORM datetime: mapped_column(TIMESTAMP(timezone=True), ...)
□ Для pydantic-settings list/set env: validator с mode="before", обрабатывает str/list
□ ENV-спецификация в README: таблица с типом и форматом каждой переменной
□ Нет Mapped[datetime] без явного TIMESTAMP(timezone=True)
```

### s5-qa-auto — при автоматизации
```
□ Format-тесты включены в CI-пайплайн (не пропускать при PR)
□ Тест migration upgrade→downgrade→upgrade запускается на чистой БД
□ OpenAPI-spec валидируется против реальных ответов (contract testing)
□ Тест на некорректный env (monkeypatch) проходит → приложение не запускается молча
```

---

## 6. Gate-условия форматов (дополнение к quality.md)

### Gate 3 (S3 → S4) — дополнительные чеклисты форматов
```
□ Для выбранного PostgreSQL: datetime TIMESTAMPTZ и NUMERIC для денег
□ PK соответствует выбранной в HLD/ADR стратегии; UUID v4 не является default
□ Для выбранного PostgreSQL: JSONB/ENUM задокументированы согласно schema contract
□ ENV-спецификация: все переменные задокументированы с форматами (s2-ba → s3-arch)
```

### Gate 4 (S4 → S5) — дополнительные чеклисты форматов
```
□ Применимые format tests существуют и проходят; N/A имеет HLD/ADR evidence
□ Для SQLAlchemy/PostgreSQL нет Mapped[datetime] без TIMESTAMP(timezone=True)
□ Для pydantic-settings нет list/set env без JSON-validator
□ README содержит таблицу ENV с типами и форматами
```

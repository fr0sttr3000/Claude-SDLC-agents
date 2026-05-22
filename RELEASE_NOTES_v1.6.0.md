---
date: 2026-05-23
tags: [release-notes, v1.6.0]
---

# Release Notes — Claude SDLC Agents v1.6.0

**Дата:** 2026-05-23
**Тип:** Minor — Architecture Pattern Selection Methodology

---

## Контекст

До v1.6.0 агенты этапа 3 (arch, security, dba) применяли паттерны интуитивно — выбор зависел от контекста конкретного запуска и не был воспроизводим между проектами. Отсутствовала явная связь: бизнес-требование → NFR → Quality Attribute → Паттерн. Кроме того, Auto-Heal чеклист в Gate 6 требовал одинаковый набор паттернов независимо от топологии деплоя (single-container vs Kubernetes), что приводило к ложным BLOCKER-нарушениям для простых деплоев.

v1.6.0 закрывает эти пробелы через формализованные правила выбора.

---

## Что нового

### 1. Методология выбора паттернов — s3-arch (7 правил)

Новый раздел `## Выбор паттернов — обязательная методология` в `s3-arch/CLAUDE.md`.

**Правило 1 — Паттерн только при наличии проблемы**
Запрещено добавлять паттерн "про запас". Каждый паттерн обосновывается через конкретный NFR или условие из BRD.
```
❌ "Добавим Circuit Breaker — он везде полезен"
✅ "Есть внешний платёжный API с таймаутом → нужен Timeout + Circuit Breaker"
```

**Правило 2 — QA → Tactic → Pattern цепочка**
Каждый паттерн в HLD проходит путь: Бизнес-требование → NFR → Quality Attribute → Tactic → Pattern → ADR.
Таблица: 10 Quality Attributes (Availability, Performance, Reliability, Security, Deployability...) → 30+ паттернов.

**Правило 3 — NFR-порог → Паттерн**

| NFR | Обязательные паттерны |
|-----|----------------------|
| availability ≥ 99.9% | Restart Policy + Liveness Probe + SLO Alerting |
| availability ≥ 99.99% | + Auto Rollback + Multi-instance |
| error_rate < 0.1% | Circuit Breaker + Retry + SLO Alerting |
| p95 < 500ms | Timeout + Connection Pool |
| RPO < 24ч | DLQ + Transactions + Backup |
| RTO < 1ч | Watchdog + Tested Rollback + Runbook |
| Есть внешние API | Timeout + Retry + Circuit Breaker |
| Есть фоновые воркеры | Watchdog + DLQ |
| Финансовые операции | Idempotency + Transactions + Soft Delete |

**Правило 4 — Топология деплоя → Фильтр паттернов**

| Паттерн | Single-container | Multi-instance | Serverless |
|---------|:---:|:---:|:---:|
| Restart Policy | ✅ | ✅ | ❌ |
| Liveness Probe | ✅ | ✅ | ❌ |
| Readiness Probe | ❌ | ✅ | ❌ |
| Resource Limits | ✅ | ✅ | ✅ |
| Circuit Breaker | если есть deps | если есть deps | если есть deps |
| Watchdog | если есть воркеры | если есть воркеры | ❌ |
| Canary Deploy | ❌ | ✅ | ✅ |

**Правило 5 — Выбор архитектурного стиля**

| Условие из BRD | Стиль |
|----------------|-------|
| Одна команда, простая предметная область | Modular Monolith |
| Независимые домены, разные команды, разные SLO | Microservices |
| read >> write, разные модели | CQRS |
| Сложные распределённые транзакции | Saga |
| Много независимых потребителей | Event-Driven / Message Bus |
| Разные клиенты с разными потребностями | BFF |

**Правило 6 — Выбор протокола коммуникации**

| Условие | Протокол |
|---------|---------|
| Публичный API | REST |
| Гибкие запросы, клиент определяет форму | GraphQL |
| Внутренние сервисы, производительность | gRPC |
| Асинхронные события, decoupling | Message Queue |
| Real-time двусторонняя связь | WebSocket |

**Правило 7 — Трейдофф обязателен (ATAM)**
Каждый паттерн в ADR: `выигрываем / платим`. Без трейдоффа ADR не засчитывается.

---

### 2. Выбор контролей безопасности — s3-security

Новый раздел `## Выбор контроля безопасности` в `s3-security/CLAUDE.md`.

**STRIDE → Security Control:**

| Угроза | Контрмеры |
|--------|----------|
| Spoofing | Authentication (JWT/OAuth2/mTLS), MFA |
| Tampering | TLS, HMAC, Input Validation, Checksums |
| Repudiation | Неизменяемый Audit Log, Digital Signatures |
| Information Disclosure | Encryption at rest, RBAC + RLS, Data Masking |
| DoS | Rate Limiting, Circuit Breaker, Resource Limits |
| Elevation of Privilege | Least Privilege, RBAC, Deny by Default, RLS |

**DREAD score → действие:**

| Score | Уровень | Действие |
|-------|---------|---------|
| > 8 | Critical | Немедленно. Блокирует Gate 3 и Gate 6 |
| 6–8 | High | Контрмера до Gate 3 |
| 4–6 | Medium | Митигация в текущем спринте |
| < 4 | Low | Принять риск с обоснованием в ADR |

**Выбор механизма аутентификации:** OAuth2 / mTLS / JWT / MFA — по условию из BRD.

---

### 3. Выбор технологии хранения — s3-dba

Новый раздел `## Выбор технологии хранения` в `s3-dba/CLAUDE.md`.

**Характеристики данных → Технология:**

| Условие | Технология | Ограничение |
|---------|-----------|------------|
| Реляционные данные, ACID | PostgreSQL | Default — нет причин отказываться |
| Кэш, сессии, счётчики | Redis | Не использовать как основное хранилище |
| Документы с гибкой схемой | MongoDB | Только с ARCH-ADR в outputs/ |
| Полнотекстовый поиск | PostgreSQL FTS / Elasticsearch | FTS достаточно до ~10M документов |
| Временные ряды, метрики | TimescaleDB / Victoria Metrics | Не хранить метрики в основной БД |

**NFR → Паттерн доступа:**

| NFR / Условие | Паттерн |
|--------------|---------|
| read >> write, разные модели | CQRS + Read Replica (только если в ARCH-HLD.md) |
| История изменений | Event Sourcing |
| Таблица > 10M строк | Table Partitioning |
| High read load | Connection Pool + Cache |
| Zero-downtime миграции | Expand-Contract |
| Мультитенантность | RLS (не приложение) |

---

### 4. Deployment Constraint — s2-ba

Новая обязательная категория NFR "Deployment" в `s2-ba/CLAUDE.md`.

```
DC-1: Deployment Constraint = single-container | multi-instance | serverless
```

- Фиксируется в `BA-NFR.md` до начала работы `s3-arch`
- Определяет применимость паттернов в `s3-arch` (Правило 4) и Gate 6 (s4-devops)
- Если не указано в BRD → s2-ba уточняет у стейкхолдера. Не додумывает.
- Добавлен в Quality Gate checklist s2-ba

---

### 5. Topology-Aware Auto-Heal — s4-devops + quality.md §5.5

`s4-devops/CLAUDE.md` — Auto-Heal чеклист теперь содержит метки `[SC]` / `[MI]` / `[SL]` для каждого пункта:
- Readiness Probe помечена как применимая только для `[MI]`
- Неприменимый пункт ≠ BLOCKER, но причина документируется в runbook

`quality.md §5.5` — все паттерны помечены `[SC,MI,SL]`, добавлены условия применимости:
- Circuit Breaker: только если есть внешние зависимости
- Watchdog: только если есть фоновые воркеры
- DLQ: только если есть асинхронная обработка

`quality.md §8` — три новых запрета:
```
✗ Архитектурный паттерн без обоснования через Quality Attribute и NFR
✗ Паттерн добавлен "про запас" без привязки к проблеме из BRD/NFR
✗ Deployment Constraint не зафиксирован в BA-NFR.md
```

---

## Исправления

### Изоляция агентов — 3 нарушения в s3-dba

| Строка | Было | Стало |
|--------|------|-------|
| `s3-dba:25` | `"согласованием s3-arch"` | `"ARCH-ADR в stage3-design/outputs/"` |
| `s3-dba:33` | `"s3-arch проектирует, s3-dba реализует"` | `"если ARCH-HLD.md содержит CQRS"` |
| `s3-dba:109` | `"согласования с s3-security"` | `"из SEC-*-threat-model.md"` |

Принцип изоляции сохранён: агенты читают только файлы из `outputs/`, не взаимодействуют напрямую.

---

## Изменённые файлы

| Файл | Изменение |
|------|----------|
| `s3-arch/CLAUDE.md` | + раздел "Выбор паттернов" (7 правил, ~80 строк) |
| `s3-security/CLAUDE.md` | + раздел "Выбор контроля безопасности" (~40 строк) |
| `s3-dba/CLAUDE.md` | + раздел "Выбор технологии хранения" (~25 строк) + 3 isolation fix |
| `s2-ba/CLAUDE.md` | + категория NFR "Deployment Constraint" (~15 строк) |
| `s4-devops/CLAUDE.md` | Auto-Heal чеклист с метками топологии |
| `_standards/quality.md` | §5.5 метки [SC/MI/SL] + topology note + 3 новых запрета в §8 |

---

## Upgrade Notes

**Новые проекты:**
1. `s2-ba` фиксирует `DC-1: Deployment Constraint` в `BA-NFR.md` перед `s3-arch`
2. `s3-arch` обосновывает каждый паттерн через 7 правил — без обоснования ADR не засчитывается
3. Gate 6: проверять Auto-Heal только по паттернам, применимым к топологии из `ARCH-HLD.md`

**Существующие проекты:**
- Если `BA-NFR.md` не содержит `DC-1` — добавить через `s0-kickoff /refresh` → раздел NFR
- Gate 6 теперь не штрафует single-container за отсутствие Readiness Probe

---

*Claude SDLC Agents v1.6.0 — 2026-05-23*

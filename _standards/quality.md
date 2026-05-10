# Стандарт качества и надёжности — SDLC Vault

> Этот файл — единственный источник истины по качеству.
> Каждый агент читает его перед работой. Правила не опциональны.
>
> Смежный стандарт: `/home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/_standards/data-formats.md`
> (форматы данных: БД-типы, env-переменные, API-контракт, обязательные тесты форматов)

---

## 1. Definition of Ready (DoR) — вход в этап

Этап НЕ НАЧИНАЕТСЯ, пока все условия не выполнены:

| # | Условие | Кто проверяет |
|---|---------|--------------|
| DoR-1 | Артефакты предыдущего этапа присутствуют в outputs/ | Агент-получатель |
| DoR-2 | Все требования SMART: конкретные, измеримые, с числами | s2-qa-req |
| DoR-3 | Acceptance Criteria определены для каждой User Story | s2-po |
| DoR-4 | NFR задокументированы с числовыми порогами | s2-ba |
| DoR-5 | Нет открытых BLOCKER-вопросов | s2-qa-req |
| DoR-6 | Агент/команда назначены, scope ясен | s1-pmo |
| DoR-7 | Threat Model начат (для этапов 3+) | s3-security |
| DoR-8 | Rollback-план описан (для этапа 6) | s6-release |

---

## 2. Definition of Done (DoD) — выход из задачи

Задача НЕ ЗАКРЫВАЕТСЯ, пока все условия не выполнены:

| # | Условие |
|---|---------|
| DoD-1 | Код соответствует стандартам (complexity ≤10, SRP) |
| DoD-2 | Unit-тесты написаны, покрытие ≥80% изменённого кода |
| DoD-3 | Code review пройден: 0 открытых BLOCKER и MAJOR |
| DoD-4 | Документация обновлена (README/API-spec/docstring) |
| DoD-5 | CHANGELOG.md обновлён |
| DoD-6 | Update notes написаны (DEV-*-update-notes-PR[N].md) |
| DoD-7 | Нет известных S1/S2 багов без митигации |
| DoD-8 | Секреты не в коде, не в логах, не в артефактах |
| DoD-9 | NFR проверены (latency, error rate, memory) |
| DoD-10 | Артефакт передан следующему агенту (файл в outputs/) |
| DoD-11 | Тесты форматов данных написаны и проходят: test_env_format.py / test_db_format.py / test_api_format.py (если применимо) |

---

## 3. NFR-дефолты (если не указано в BRD — применять эти)

| Метрика | Порог | Уровень нарушения |
|---------|-------|------------------|
| Availability | ≥ 99.9% (43.8 мин/мес) | S1 если нарушен |
| Response time p95 | < 500 ms | S2 если нарушен |
| Response time p99 | < 2000 ms | S2 если нарушен |
| Error rate | < 0.1% | S1 если > 1%, S2 если > 0.1% |
| RTO (Recovery Time) | < 1 час | S1 если нарушен |
| RPO (Recovery Point) | < 24 часа | S2 если нарушен |
| Security: Critical vulns | 0 | S1 — блокирует релиз |
| Security: High vulns | 0 | S1 — блокирует релиз |
| Test coverage (unit) | ≥ 80% | S2 если < 80% |
| Test pass rate | ≥ 98% | S1 если < 98% |

---

## 4. Quality Gates — переходы между этапами

Переход заблокирован, пока Gate не пройден. Gate проверяет агент-получатель.

```
S1 Planning ──[Gate 1]──► S2 Requirements
S2 Requirements ──[Gate 2]──► S3 Design
S3 Design ──[Gate 3]──► S4 Development
S4 Development ──[Gate 4]──► S5 Testing
S5 Testing ──[Gate 5]──► S6 Deploy
S6 Deploy ──[Gate 6]──► PRODUCTION
```

### Gate 1 (S1 → S2)
Проверяет: **s2-ba** перед началом работы
```
□ PM-feasibility.md существует с вердиктом Go / Conditional Go
□ PMO-charter.md существует и подписан
□ Топ-5 рисков задокументированы с митигацией
□ Scope In / Scope Out явно определён
```

### Gate 2 (S2 → S3)
Проверяет: **s3-arch** перед началом работы
```
□ BA-BRD.md существует, все FR с ID и AC
□ BA-NFR.md существует, все NFR с числами
□ QA-REQ-*-review.md существует, 0 открытых BLOCKER
□ PO-backlog.md существует, все Must-stories с AC
□ Нет требований с маркерами: "и/или" / "обычно" / "при необходимости"
```

### Gate 3 (S3 → S4)
Проверяет: **s4-dev** и **s4-techlead** перед началом работы
```
□ ARCH-HLD.md существует, ADR написаны для всех ключевых решений
□ ARCH-api-spec.yaml существует
□ SEC-threat-model.md существует, 0 открытых Critical/High угроз
□ DBA-schema.sql или DBA-schema.dbml существует
□ DEVOPS-cicd.yaml (шаблон CI/CD) существует

# RBAC (s3-rbac)
□ RBAC-*-model.md существует: все роли из BRD покрыты, иерархия описана
□ RBAC-*-matrix.md существует: матрица полная (роль × ресурс × действие)
□ RBAC-*-schema.sql существует: таблицы roles/permissions/role_permissions/user_roles + RLS
□ SoD-конфликты выявлены и задокументированы
□ Owner-ресурсы защищены RLS-политиками

# Форматы данных (data-formats.md §5 s3-dba / §6 Gate 3)
□ DBA-schema: все datetime — TIMESTAMPTZ (никогда WITHOUT TIME ZONE)
□ DBA-schema: все PK — UUID v4, деньги — NUMERIC(p,s) (не FLOAT)
□ DBA-schema: все JSONB-поля с задокументированной структурой (пример JSON)
□ DBA-schema: все ENUM-типы с перечислением допустимых значений
□ ENV-спецификация: все переменные задокументированы с типом и форматом
```

### Gate 4 (S4 → S5)
Проверяет: **s5-qa** перед началом тестирования
```
□ Все PR из спринта закрыты (0 IN_PROGRESS у s4-dev)
□ Все PR прошли code review (TL-*-review-PR*.md для каждого PR)
□ DEV-*-update-notes-PR*.md существуют для каждого PR
□ Unit-тесты: покрытие ≥ 80%, все проходят
□ SAST/secrets-scan прошли без Critical/High
□ DoD выполнен для каждого PR (все 11 пунктов, включая DoD-11)

# Форматы данных (data-formats.md §6 Gate 4)
□ tests/test_env_format.py существует и все тесты проходят
□ tests/test_db_format.py существует и все тесты проходят
□ tests/test_api_format.py существует и все тесты проходят
□ Нет Mapped[datetime] без TIMESTAMP(timezone=True) (grep / code review)
□ Нет list/set env-переменных без JSON-validator mode="before" (code review)
□ README содержит таблицу ENV-переменных с типами и форматами
□ Тест migration upgrade→downgrade→upgrade прошёл на чистой БД
```

### Gate 5 (S5 → S6)
Проверяет: **s6-release** перед подготовкой релиза
```
□ QA-go-no-go.md существует с вердиктом GO
□ 0 открытых S1 багов, 0 открытых S2 багов
□ Pass Rate ≥ 98%
□ UAT sign-off получен (живой Telegram / реальная система)
□ PERF-report.md существует с вердиктом PASS или CONDITIONAL PASS
□ AUTO-*-coverage.md существует, ≥ 95% автоматизировано
```

### Gate 6 (S6 → PRODUCTION)
Проверяет: **s6-sre** перед деплоем
```
□ REL-checklist.md заполнен полностью
□ REL-*-release-notes-v*.md существует
□ CHANGELOG.md обновлён (версия закрыта)
□ Rollback-план задокументирован и проверен
□ On-call назначен, мониторинг настроен
□ DEVOPS-runbook.md актуален под новую версию
```

---

## 5. Обязательные паттерны надёжности

Каждая система, независимо от масштаба, обязана реализовать:

### 5.1 Устойчивость к отказам
```
□ Timeout на КАЖДОМ внешнем вызове (default: 30 сек, для БД: 10 сек)
□ Retry с exponential backoff: 3 попытки, factor 2 (1s → 2s → 4s)
□ Circuit breaker для внешних зависимостей (порог: 5 ошибок за 30 сек)
□ Graceful shutdown: дождаться завершения текущих запросов (до 30 сек)
□ Health checks: /health (liveness) и /ready (readiness)
```

### 5.2 Наблюдаемость (Observability) — с первого дня
```
□ Логи: структурированный JSON, уровень INFO+ в prod
□ Каждый лог-запись: timestamp (UTC), level, service, correlation_id, message
□ Метрики (RED): Request Rate / Error Rate / Duration (p50/p95/p99)
□ Алерты: на нарушение SLO, не на симптомы
□ НЕ логировать: пароли, токены, PII, тела запросов с секретами
```

### 5.3 Операционная готовность
```
□ Runbook написан ДО деплоя (не после)
□ Rollback-процедура задокументирована и протестирована
□ Бэкап данных настроен и проверен (restore работает)
□ SLO определён (availability + latency)
□ Error budget рассчитан и отслеживается
```

### 5.4 Идемпотентность и консистентность данных
```
□ Все write-операции идемпотентны или защищены уникальным ключом
□ Транзакции для операций, изменяющих несколько сущностей
□ Soft delete вместо hard delete (кроме явных исключений с обоснованием)
□ Миграции: всегда с downgrade(), тестировать upgrade+downgrade+upgrade
```

### 5.5 Auto-Heal — ОБЯЗАТЕЛЬНО для каждой системы

Auto-heal — способность системы обнаруживать неисправность и восстанавливаться без ручного вмешательства.
Цикл: **Detect → Isolate → Recover → Verify**

#### Уровень инфраструктуры (s4-devops, stage4)
```
□ restart: unless-stopped (Docker) или restartPolicy: Always (K8s) — контейнер
  перезапускается при падении без участия оператора
□ HEALTHCHECK в Dockerfile: периодическая проверка живости процесса
□ Resource limits (memory/cpu) — предотвращают зависание из-за OOM без kill
□ Liveness probe → автоматический restart при сбое (не ждать оператора)
□ Readiness probe → трафик не идёт на нездоровый инстанс
```

#### Уровень приложения (s4-dev, stage4)
```
□ Circuit breaker: при N ошибках за T сек — открыть цепь, вернуть fallback
  (порог по умолчанию: 5 ошибок за 30 сек, восстановление через 60 сек)
□ Watchdog-процесс: периодически проверяет критичные подсистемы,
  перезапускает зависшие воркеры/очереди
□ Dead letter queue: упавшие задачи — в DLQ, не теряются, обрабатываются
  при восстановлении
□ Retry с backoff: временные сбои внешних зависимостей не роняют систему
```

#### Уровень мониторинга (s6-sre, stage7)
```
□ Alert → Auto-action: алерт не только уведомляет, но и запускает
  автоматическое действие (restart, scale-out, failover)
□ SLO breach → автоматический rollback (если настроен canary/blue-green)
□ Error budget exhausted → автоматическая заморозка деплоев
□ Watchdog heartbeat: процесс пишет метку каждые N минут;
  отсутствие метки → алерт + автоперезапуск
```

**Запрещено:** система без auto-heal выходит в prod. Если auto-heal не реализован —
это BLOCKER в Gate 6 и Gate 7.

---

## 6. Quality Gate 7 — Эксплуатация (ОБЯЗАТЕЛЬНЫЙ)

Этап 7 (stage7-ops) — обязательный, не опциональный. Закрывается после деплоя.

```
□ Monitoring dashboard активен: RED-метрики видны в реальном времени
□ Алерты настроены на SLO breach (не на симптомы), протестированы (fire drill)
□ Auto-heal реализован и проверен: намеренный kill процесса → авторестарт < 30 сек
□ Runbook для каждого типа инцидента задокументирован в stage7-ops/outputs/
□ Error budget рассчитан и виден (текущий остаток на месяц)
□ On-call ротация определена (кто дежурит, как escalate)
□ SRE-*-ops-report.md создан в stage7-ops/outputs/ через 7 дней после деплоя
```

Без закрытого Gate 7 следующий релиз этого проекта — заблокирован.

---

## 7. DORA-метрики — цели качества доставки — цели качества доставки

| Метрика | Elite | High | Medium | Low |
|---------|-------|------|--------|-----|
| Deployment Frequency | On demand | 1/день–1/неделю | 1/мес–1/неделю | <1/мес |
| Lead Time for Changes | <1 часа | 1 день–1 неделю | 1 неделю–1 мес | >1 мес |
| MTTR (восстановление) | <1 часа | <1 дня | 1 день–1 неделю | >1 нед |
| Change Failure Rate | <5% | <10% | 10–15% | >15% |

Целевой уровень: **High**. Elite — при наличии ресурсов.

---

## 8. Запрещено во всей системе (нарушение = BLOCKER)

```
✗ Секреты (токены, пароли, ключи) в коде, логах, .md файлах, git-истории
✗ Продакшн-данные в тестах
✗ Хард-код IP/URL/порта без конфигурации
✗ Игнорирование ошибок (pass / catch without logging)
✗ Деплой без rollback-плана
✗ Переход в следующий этап без закрытого Quality Gate
✗ UAT в симуляторе/эмуляторе вместо реальной системы
✗ Закрытие задачи без DoD (все 11 пунктов)
✗ Critical/High уязвимости в релизе
✗ Нефункциональные тесты в prod-ветке
✗ Система в prod без auto-heal (restart policy, liveness probe, watchdog)
✗ Система в prod без алертов на SLO breach
✗ Следующий релиз без закрытого Gate 7 предыдущего

# Запреты форматов данных (data-formats.md)
✗ TIMESTAMP WITHOUT TIME ZONE — всегда TIMESTAMPTZ
✗ FLOAT/DOUBLE для денег — только NUMERIC(p,s)
✗ list/set/frozenset env-переменных в формате CSV (1,2,3) — только JSON ([1,2,3])
✗ Mapped[datetime] без TIMESTAMP(timezone=True) в ORM-маппинге
✗ JSONB-поля без задокументированной структуры (пример JSON обязателен)
✗ Проект с DB/ENV без тестов форматов (test_env_format.py, test_db_format.py)
✗ ENV-переменные без спецификации типа и формата в README/BRD
```

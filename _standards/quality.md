# Стандарт качества и надёжности — SDLC Vault

> Этот файл — единственный источник истины по качеству.
> Каждый агент читает его перед работой. Правила не опциональны.
>
> Смежные стандарты:
> - `$SDLC_VAULT/_agents/_standards/data-formats.md` — форматы данных (БД-типы, env, API-контракт, тесты форматов)
> - `$SDLC_VAULT/_agents/_standards/security.md` — **параллельный Security-трек (SG1–SG5)**: severity по CVSS,
>   threat model, RBAC, SAST/SCA/secrets, pentest, privacy. Переход = зелёный Quality Gate **И** Security Gate.

---

## 1. Definition of Ready (DoR) — вход в этап

Этап НЕ НАЧИНАЕТСЯ, пока все условия не выполнены.
DoR **бинарен**: нет понятия "почти готово" или "готово на 80%". Любой непройденный пункт = этап не начинается, даже под давлением дедлайна.

| # | Условие | Этап | Кто обеспечивает | Кто проверяет | Проверка |
|---|---------|------|-----------------|--------------|---------|
| DoR-1 | Артефакты предыдущего этапа присутствуют в outputs/ | Все | Агент-поставщик | Агент-получатель | 🤖 авто |
| DoR-2 | Все требования SMART: конкретные, измеримые, с числами | S2→S3 | s2-ba | s2-qa-req | 🤖 частично |
| DoR-3 | Acceptance Criteria определены для каждой User Story | S2→S3 | s2-po | s2-qa-req | 🤖 частично |
| DoR-4 | NFR задокументированы с числовыми порогами | S2→S3 | s2-ba | s2-ba | 🤖 частично |
| DoR-5 | Нет открытых BLOCKER-вопросов | S2→S3 | s2-ba, s2-po | s2-qa-req | 🤖 авто |
| DoR-6 | Агент/команда назначены, scope ясен | Все | s1-pmo | Агент-получатель | 👤 вручную |
| DoR-7 | Threat Model начат (для этапов 3+) | S3+ | s3-security | s3-arch | 🤖 авто |
| DoR-8 | Rollback-план описан и протестирован | S6 | s4-devops | s6-release | 🤖 авто |

> 🤖 авто — проверяется `s0-validate /dor-check [N]` (dor-check.sh)
> 🤖 частично — скрипт выявляет грубые нарушения, финальное решение за агентом
> 👤 вручную — субъективная оценка, скрипт не применим

### Дедлайн готовности
DoR должен быть выполнен **до старта этапа**, а не параллельно с ним:
- DoR-1, DoR-6: за 0 часов (проверяется в момент старта)
- DoR-2, DoR-3, DoR-4, DoR-5: до `/sprint-init` спринта, в котором начинается S3
- DoR-7: до первого артефакта s3-arch
- DoR-8: до подписания REL-checklist.md

### Правило возврата
Если DoR не пройден — агент-получатель **обязан**:
1. Отказать в начале работы
2. Записать список непройденных пунктов в `$SDLC_PROJECTS_DIR/{PROJECT}/tracking/dor-violations.md`
3. Сообщить пользователю какие пункты не пройдены и какой агент должен их устранить
4. Не начинать работу, не угадывать и не додумывать недостающее

Агенты не вызывают друг друга напрямую. Пользователь перезапускает нужного агента-поставщика после устранения нарушений.
Файл `dor-violations.md` создаётся s0-tracker при `/sprint-init` из шаблона.

### Сброс DoR при изменении требований (Change Request)
Если требования меняются в середине активного этапа — затронутые пункты DoR **сбрасываются** и проверяются заново.

| Тип изменения | DoR к сбросу | Агент-инициатор |
|---------------|-------------|----------------|
| FR (функциональное требование) | DoR-2, DoR-3, DoR-5 | s0-kickoff /cr |
| NFR (нефункциональное) | DoR-4 | s0-kickoff /cr |
| Scope (расширение/сужение) | DoR-1, DoR-2, DoR-3, DoR-5, DoR-6 | s0-kickoff /cr |
| Технические ограничения | DoR-7 | s0-kickoff /cr |

Процесс: `s0-kickoff /cr [PROJECT]` → Impact Analysis → сброс DoR → запуск затронутых агентов → `s0-validate /dor-check [GATE]`
Change Request фиксируется в `stage{N}/inputs/CR-YYYY-MM-DD-[N]-input.md` и в `tracking/dor-violations.md`.

---

## 2. Definition of Done (DoD) — выход из задачи

Задача НЕ ЗАКРЫВАЕТСЯ, пока все условия не выполнены.
DoD **бинарен**: нет "Done minus docs", "Done кроме тестов", "почти Done". Любой непройденный пункт = задача остаётся IN_PROGRESS, даже под давлением дедлайна.

| # | Условие | Кто обеспечивает | Кто проверяет | Проверка |
|---|---------|-----------------|--------------|---------|
| DoD-1 | Код соответствует стандартам (complexity ≤10, SRP, duplication ≤3% нового кода) | Агент-исполнитель | s4-techlead | 🤖 частично |
| DoD-2 | Тесты по пирамиде (unit/integration/contract): branch ≥80% изм. кода + mutation ≥60% критичных модулей (§3.1) | Агент-исполнитель | s4-techlead | 🤖 авто |
| DoD-3 | Code review пройден: 0 открытых BLOCKER и MAJOR | Агент-исполнитель | s4-techlead | 👤 вручную |
| DoD-4 | Документация обновлена (README/API-spec/docstring) | Агент-исполнитель | Агент-получатель | 👤 вручную |
| DoD-5 | CHANGELOG.md обновлён | Агент-исполнитель | s4-techlead | 🤖 авто |
| DoD-6 | Update notes написаны (DEV-*-update-notes-PR[N].md) | s4-dev | s4-techlead | 🤖 авто |
| DoD-7 | Нет известных S1/S2 багов без митигации | Агент-исполнитель | s5-qa | 👤 вручную |
| DoD-8 | Секреты не в коде, не в логах, не в артефактах | Агент-исполнитель | s4-techlead | 🤖 авто |
| DoD-9 | NFR проверены (latency, error rate, memory) | Агент-исполнитель | s5-perf / s5-qa | 👤 вручную |
| DoD-10 | Артефакт записан в outputs/ текущего этапа | Агент-исполнитель | Агент-получатель | 🤖 авто |
| DoD-11 | Тесты форматов данных написаны и проходят: test_env_format.py / test_db_format.py / test_api_format.py (если применимо) | Агент-исполнитель | s4-techlead | 🤖 авто |

> 🤖 авто — проверяется `s0-validate /dod-check [TYPE] [STAGE] [PR]` (dod-check.sh)
> 🤖 частично — скрипт выявляет грубые нарушения, финальное решение за владельцем
> 👤 вручную — требует смыслового суждения, скрипт не применим

### Применимость DoD по типу артефакта

| # | Тип К: Код | Тип Д: Документ | Тип И: Инфраструктура |
|---|:----------:|:---------------:|:---------------------:|
| DoD-1 complexity ≤10, SRP, duplication ≤3% | ✅ | ❌ | ❌ |
| DoD-2 тесты по пирамиде + пороги §3.1 | ✅ | ❌ | ⚠️ тест миграций вместо unit |
| DoD-3 code review | ✅ | ✅ | ✅ |
| DoD-4 документация обновлена | ✅ | ✅ | ✅ |
| DoD-5 CHANGELOG обновлён | ✅ | ✅ | ✅ |
| DoD-6 update notes (DEV-*) | ✅ | ❌ | ❌ |
| DoD-7 нет S1/S2 багов | ✅ | ✅ | ✅ |
| DoD-8 секреты | ✅ | ✅ | ✅ |
| DoD-9 NFR проверены | ✅ | ⚠️ NFR адресованы в дизайне | ✅ |
| DoD-10 артефакт в outputs/ | ✅ | ✅ | ✅ |
| DoD-11 тесты форматов | ✅ | ❌ | ✅ |

**Тип К — Код** (s4-dev): все 11 пунктов обязательны.

**Тип Д — Документ** (s1-pm, s1-pmo, s1-finance, s2-ba, s2-po, s2-qa-req, s3-arch, s3-rbac, s3-security, s5-qa, s5-qa-auto, s5-perf, s6-release, s6-sre):
обязательны DoD-3, DoD-4, DoD-5, DoD-7, DoD-8, DoD-10 — итого 6 пунктов.

**Тип И — Инфраструктура** (s3-dba, s4-devops):
обязательны DoD-2(миграции), DoD-3, DoD-4, DoD-5, DoD-7, DoD-8, DoD-9, DoD-10, DoD-11 — итого 9 пунктов.

### Связь DoD → DoR следующего этапа

**DoD-10 выполнен = DoR-1 следующего этапа выполнен автоматически.**

Это явный контракт между агентом-поставщиком и агентом-получателем:

| Агент закрывает DoD-10 | Это автоматически закрывает |
|------------------------|----------------------------|
| s1-pm, s1-pmo, s1-finance | DoR-1 для s2-ba (Gate 1) |
| s2-ba, s2-po, s2-qa-req | DoR-1 для s3-arch (Gate 2) |
| s3-arch, s3-security, s3-rbac, s3-dba | DoR-1 для s4-dev (Gate 3) |
| s4-dev (все PR) | DoR-1 для s5-qa (Gate 4) |
| s5-qa, s5-perf, s5-qa-auto | DoR-1 для s6-release (Gate 5) |
| s6-release | DoR-1 для s6-sre (Gate 6) |

Если DoD-10 не выполнен — DoR-1 следующего этапа гарантированно провален.
Агент-получатель, обнаружив отсутствие файлов в предыдущем outputs/, записывает нарушение в `tracking/dor-violations.md` и сообщает пользователю. Агенты не взаимодействуют напрямую — только через файлы.

### Технический долг — исключительные случаи пропуска DoD

DoD бинарен. Пропуск пункта DoD допускается **только в исключительных случаях** с явным одобрением пользователя и обязательной фиксацией.

**Правило:** если DoD-пункт осознанно пропущен — это технический долг (TD). Задача может быть переведена в DONE только при одновременной записи в `tracking/tech-debt.md`.

Запись обязана содержать:
- Какой DoD-пункт нарушен
- Конкретную причину (не "нет времени", а реальное ограничение)
- Кто одобрил исключение
- План устранения и дедлайн (не позже следующего спринта)

**Последствия незакрытого TD:**
- TD со статусом OPEN и просроченным дедлайном → блокирует `/sprint-close`
- Накопление > 3 открытых TD → блокирует старт нового спринта
- TD без плана устранения → не принимается, пропуск DoD не разрешён

Шаблон: `_standards/tech-debt-template.md`
Файл проекта: `$SDLC_PROJECTS_DIR/{PROJECT}/tracking/tech-debt.md` (создаётся s0-tracker при `/sprint-init`)

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
| Security (CVSS) | → security.md §1 | severity по CVSS, не S1–S4; Critical/High блокируют релиз |
| Test coverage (branch, изм. код) | ≥ 80% | S2 если < 80% |
| Mutation score (критичные модули) | ≥ 60% | S2 если < 60% (порог растёт по tier — §3.1) |
| Code duplication (новый код) | ≤ 3% | S3 если > 3%, S2 если > 5% |
| Test pass rate | ≥ 98% | S1 если < 98% |

---

## 3.1 Уровни и качество тестирования (test pyramid)

Тесты строятся по пирамиде. Каждый уровень — отдельный контроль; нельзя компенсировать
отсутствие нижнего уровня верхним (анти-паттерн «ice-cream cone»).

| Уровень | Что проверяет | Порог | Где enforced |
|---------|---------------|-------|--------------|
| **Unit** | логика в изоляции (моки внешних зависимостей) | branch ≥ 80% изм. кода + mutation ≥ 60% критичных модулей | DoD-2, Gate 4 |
| **Integration / component** | модуль + реальная БД/адаптер/очередь (testcontainers, не моки) | существуют и проходят для КАЖДОГО внешнего адаптера (БД, API-клиент, брокер) | Gate 4 |
| **Contract** | согласование consumer↔provider по API (consumer-driven: Pact / схема) | существуют и проходят для каждого внешнего API-контракта; сверены с ARCH-api-spec.yaml | Gate 4 |
| **E2E** | сквозные пользовательские сценарии в реальной системе | ≥ 95% автоматизация critical paths | Gate 4/5 (s5-qa-auto) |
| **Performance** | load / stress / soak | вердикт PASS (§4 Gate 5) | Gate 5 (s5-perf) |

**Покрытие — branch, не line.** Line coverage даёт ложную уверенность: строка выполнена ≠
ветка/условие проверены. Минимум — **branch coverage ≥ 80% изменённого кода**.

**Mutation score — реальный сигнал качества тестов.** Покрытие показывает, что код выполнен;
мутационное тестирование показывает, что тесты **ловят дефекты** (инструменты: mutmut /
Cosmic Ray — Python, Stryker — JS/TS, PIT — Java). Порог **≥ 60% для критичных модулей**.

> **Критичные модули** — доменное ядро, контроли безопасности (authn/authz), денежные и
> расчётные операции, обработка персональных данных. Помечаются в `ARCH-HLD.md` (s3-arch)
> или техлидом при review. Для остального кода mutation желателен, но не блокирует.

**Пороги растут по tier** (принцип `s0-quality-gates` «только вверх» — `tracking/quality-gates.md`):

| Tier | branch | mutation (критичные) |
|------|:------:|:--------------------:|
| 0 / 1 | ≥ 80% | ≥ 60% |
| 2 | ≥ 80% | ≥ 70% |
| 3 | ≥ 85% | ≥ 80% |

**Contract testing ≠ формат-тесты.** `test_api_format.py` (data-formats.md) проверяет типы и
формат полей; contract-тест проверяет **взаимные ожидания** consumer и provider (форма
запроса/ответа, семантика, версионирование). Это разные контроли — оба обязательны при наличии API.

**Кто пишет:** unit / integration / contract — `s4-dev` (Тип К, DoD-2); E2E-автоматизация —
`s5-qa-auto`; performance — `s5-perf`. Отчёт о покрытии агрегирует `s5-qa-auto` в `AUTO-*-coverage.md`.

---

## 4. Quality Gates — переходы между этапами

Переход заблокирован, пока Gate не пройден. Gate проверяет агент-получатель.

> **Параллельно действует Security-трек (SG1–SG5) — см. `security.md §3`.**
> Этап пройден только когда зелёный И Quality Gate (ниже), И соответствующий Security Gate.
> Security-критерии (threat model, RBAC, SAST/SCA/secrets, pentest) вынесены в `security.md`;
> ниже оставлены кросс-ссылки на нужный SG.

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
□ DBA-schema.sql или DBA-schema.dbml существует
□ DEVOPS-cicd.yaml (шаблон CI/CD) существует

# Безопасность — Security Gate SG2 (security.md §3)
□ Security Gate SG2 (Design) пройден: threat model 0 Critical/High + RBAC/matrix/RLS + SoD
  (детали и чек-лист — в security.md §3 SG2; владелец s3-security + s3-rbac)

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
□ Unit-тесты: branch-покрытие ≥ 80% изм. кода + mutation ≥ 60% критичных модулей, все проходят (§3.1)
□ Integration/component-тесты существуют и проходят для каждого внешнего адаптера (БД, API-клиент, очередь) (§3.1)
□ Contract-тесты (consumer-driven) существуют и проходят, сверены с ARCH-api-spec.yaml (§3.1, при наличии API)
□ Security Gate SG3 (Build) пройден: SAST/SCA/secrets/image scan без Critical/High
  (детали — security.md §3 SG3; непрерывно на каждый PR, владелец s3-security)
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
□ Functional Suitability: каждый Must-FR из BA-BRD.md покрыт ≥1 приёмочным тест-кейсом
  с результатом PASS; трассировка полная по BA-RTM.md (0 непокрытых Must-FR) (ISO 25010 — §4.1)
□ 0 открытых S1 багов, 0 открытых S2 багов
□ Pass Rate ≥ 98%
□ UAT sign-off получен (реальная система, не эмулятор)
□ PERF-report.md существует с вердиктом PASS или CONDITIONAL PASS
□ Security Gate SG4 пройден: SEC-*-pentest-report.md с вердиктом PASS (DAST/pentest, 0 Critical/High по CVSS)
  (владелец s5-security; детали — security.md §3 SG4)
□ AUTO-*-coverage.md существует, ≥ 95% автоматизировано
□ Known Issues: каждый S3/S4-дефект релиза с user-facing impact промотирован в
  tracking/known-issues.md (Workaround + Detection signal + → tech-debt) (§6.1) — иначе No-Go
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
□ Release notes содержат секцию «Известные проблемы» из known-issues.md (все OPEN с impact) (§6.1)
□ Security Gate SG4 (Pre-Prod) подтверждён: SEC-*-pentest-report.md с вердиктом PASS
  (исполняется в S5; владелец s5-security; детали — security.md §3 SG4)
```

---

## 4.1 Маппинг на модель качества продукта ISO/IEC 25010

Quality Gates покрывают характеристики качества продукта по **ISO/IEC 25010:2023**.
Таблица показывает, где каждая характеристика гейтится, а где — **осознанный пробел**
(со ссылкой на пункт roadmap). Цель — не «закрыть всё», а сделать охват явным:
непокрытая характеристика — это решение, а не упущение.

| Характеристика (2023; ex-2011) | Где гейтится | Статус |
|--------------------------------|--------------|--------|
| **Functional Suitability** (полнота / корректность / уместность) | Gate 2 (FR с AC), **Gate 5 (Must-FR ↔ acceptance ↔ RTM)** | ✅ |
| **Performance Efficiency** (time / resource / capacity) | §3 NFR (p95/p99/error rate), Gate 5 (PERF-report), s5-perf | ✅ |
| **Compatibility** (co-existence / interoperability) | Contract-тесты §3.1 (interoperability API) | ⚠️ co-existence не гейтится → roadmap п.4 |
| **Interaction Capability** (ex-Usability) | — | ❌ не гейтится → roadmap п.3 / п.25 (accessibility) |
| **Reliability** (maturity / availability / fault tolerance / recoverability) | §3 NFR (availability/RTO/RPO), §5 паттерны + auto-heal, §6 Gate 7 | ✅ |
| **Security** (confidentiality / integrity / non-repudiation / accountability / authenticity) | security.md SG1–SG5, §8 | ✅ |
| **Maintainability** (modularity / reusability / analysability / modifiability / testability) | DoD-1 (complexity ≤10, SRP), §3.1 (testability) | ⚠️ только complexity → roadmap п.12–15 |
| **Flexibility** (ex-Portability: adaptability / scalability / installability / replaceability) | §5 (Deployment Constraint / топология), auto-heal scale-out | ⚠️ installability не гейтится → roadmap п.5 |
| **Safety** (новое в 2023) | — | ❌ для большинства проектов не применимо; для critical-систем — по решению s1-pmo |

> **Quality-in-use** (effectiveness / efficiency / satisfaction / freedom from risk / context coverage)
> частично закрыт UAT (Gate 5) и SLO/error budget (Gate 7); системного гейта нет → roadmap п.27.

Маппинг трека безопасности на NIST SSDF / OWASP SAMM / ASVS / SDL / SLSA — в `security.md §5`.

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

> **Применимость паттернов зависит от топологии деплоя.**
> Deployment Constraint фиксируется в BA-NFR.md (s2-ba) и отражается в ARCH-HLD.md (s3-arch).
> Пункты ниже помечены: [SC] = single-container / [MI] = multi-instance / [SL] = serverless.
> Неприменимый пункт = не BLOCKER, но причина должна быть задокументирована в runbook.

#### Уровень инфраструктуры (s4-devops, stage4)
```
□ [SC,MI] restart: unless-stopped (Docker) или restartPolicy: Always (K8s) —
  контейнер перезапускается при падении без участия оператора
□ [SC,MI] HEALTHCHECK в Dockerfile: периодическая проверка живости процесса
□ [SC,MI,SL] Resource limits (memory/cpu) — предотвращают зависание из-за OOM без kill
□ [SC,MI] Liveness probe → автоматический restart при сбое (не ждать оператора)
□ [MI] Readiness probe → трафик не идёт на нездоровый инстанс
```

#### Уровень приложения (s4-dev, stage4)
```
□ [SC,MI,SL] Circuit breaker: при N ошибках за T сек — открыть цепь, вернуть fallback
  (порог по умолчанию: 5 ошибок за 30 сек, восстановление через 60 сек)
  Применяется только если есть внешние зависимости (API, БД, очереди)
□ [SC,MI] Watchdog-процесс: периодически проверяет критичные подсистемы,
  перезапускает зависшие воркеры/очереди
  Применяется только если есть фоновые воркеры/очереди
□ [SC,MI,SL] Dead letter queue: упавшие задачи — в DLQ, не теряются, обрабатываются
  при восстановлении
  Применяется только если есть асинхронная обработка задач
□ [SC,MI,SL] Retry с backoff: временные сбои внешних зависимостей не роняют систему
```

#### Уровень мониторинга (s6-sre, stage7)
```
□ [SC,MI,SL] Alert → Auto-action: алерт не только уведомляет, но и запускает
  автоматическое действие (restart, scale-out, failover)
□ [MI,SL] SLO breach → автоматический rollback (если настроен canary/blue-green)
□ [SC,MI,SL] Error budget exhausted → автоматическая заморозка деплоев
□ [SC,MI] Watchdog heartbeat: процесс пишет метку каждые N минут;
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
□ Для каждой OPEN-записи known-issues.md с user-facing impact: алерт настроен и протестирован
  (fire drill), SRE-runbook-KI-*.md существует, auto-remediation где возможно (§6.1)
□ SRE-*-ops-report.md создан в stage7-ops/outputs/ через 7 дней после деплоя
```

Без закрытого Gate 7 следующий релиз этого проекта — заблокирован.

---

## 6.1 Known Issues — операционный контракт (KEDB)

Некритичный дефект (S3/S4, или security Low/Medium по CVSS) может уйти в прод, но не «молча»:
он промотируется в **известную ошибку** с операционным контрактом, иначе это не «known», а
«ignored issue». Подход — ITIL Known Error / KEDB + SRE-runbooks + auto-remediation.

**Реестр:** `tracking/known-issues.md` (шаблон `known-issues-template.md`, создаёт s0-tracker).
Это операционный срез — его читает `s6-sre` во время инцидента по Detection signal / имени алерта.
Дедлайн / исполнитель / одобрение фикса НЕ дублируются здесь — только ссылка `→ tech-debt`.

**Правило промоушена (s5-qa, Gate 5):** дефект попадает в реестр ТОЛЬКО при
`Impact = user-facing` И определённом `Detection signal`. Иначе — обычная строка в `tech-debt.md`
(планирование без мониторинга). Блокирующие S1/S2 в прод не уходят вовсе.

**Обязательные поля записи:** Trigger · Impact · Workaround · Detection signal ·
Auto-remediation (или «нет») · `→ tech-debt`. (Owner и Root-cause не дублируются — в задаче/tech-debt.)

**Единый join-ключ:** имя алерта = id записи (KI-NN) = имя runbook'а (`SRE-runbook-KI-NN.md`).
Поток on-call: алерт `KI-NN` → `known-issues.md` (что сломалось) → `SRE-runbook-KI-NN.md` (как чинить);
auto-remediation отрабатывает сама (§5.5 «Alert → Auto-action»).

**Patch SLA** (срок постоянного фикса; дедлайн фиксируется в `tech-debt.md`):

| Severity | SLA фикса |
|----------|-----------|
| S3 / security Medium | ≤ 1 спринт |
| S4 / security Low | ≤ 3 спринта (или явный risk-accept как Known Issue) |

Просроченный Patch SLA → блокирует `/sprint-close` (механизм tech-debt, §2).

**Закрытие:** фикс зарелижен → запись `FIXED` → снять алерт + runbook → CHANGELOG → закрыть TD.

**Контроль по гейтам:** Gate 5 — промоушн (s5-qa); Gate 6 — секция в release notes (s6-release);
Gate 7 — алерт + runbook для каждой OPEN-записи (s6-sre).

---

## 7. Метрики доставки и качества (DORA + defect metrics)

### 7.1 DORA — пять метрик (Accelerate / State of DevOps)

| Метрика | Elite | High | Medium | Low |
|---------|-------|------|--------|-----|
| Deployment Frequency | On demand | 1/день–1/неделю | 1/мес–1/неделю | <1/мес |
| Lead Time for Changes | <1 часа | 1 день–1 неделю | 1 неделю–1 мес | >1 мес |
| MTTR (восстановление) | <1 часа | <1 дня | 1 день–1 неделю | >1 нед |
| Change Failure Rate | <5% | <10% | 10–15% | >15% |
| **Reliability** (5-я метрика, 2022) | SLO стабильно выполняется, error budget не исчерпан | SLO выполняется | SLO нарушается эпизодически | SLO систематически нарушается |

Целевой уровень: **High**. Elite — при наличии ресурсов.
**Reliability** — операционная надёжность: фактическое соответствие SLO и расход error budget
(источник — §6 Gate 7); владелец метрики — `s6-sre`.

### 7.2 Сбор и тренд метрик (метрики — не аспирация)

Метрики собираются и отслеживаются по тренду от цикла к циклу, а не объявляются целью на бумаге:

| Метрика | Источник данных | Кто собирает | Куда пишет |
|---------|-----------------|--------------|-----------|
| Deployment Frequency | git-теги / релизы / CI | s0-tracker | cycle-summary.md |
| Lead Time for Changes | commit → deploy (git/CI) | s0-tracker | cycle-summary.md |
| MTTR | инциденты (detect → recover) | s6-sre | SRE-*-ops-report.md |
| Change Failure Rate | релизы с откатом/хотфиксом ÷ всего | s6-sre | SRE-*-ops-report.md |
| Reliability | SLO-дашборд, остаток error budget | s6-sre | SRE-*-ops-report.md |

- `s0-tracker /report` добавляет в `cycle-summary.md` блок **«Метрики: план vs факт vs прошлый цикл»**.
- Тренд по каждой метрике помечается ↑ / ↓ / → относительно предыдущего цикла.
- Деградация одной метрики **два цикла подряд** → запись в `tracking/tech-debt.md` как процессный долг.

### 7.3 Defect-метрики — эффективность гейтов

Показывают, ловят ли гейты дефекты **до** прода, а не сам факт «зелёного» гейта:

| Метрика | Формула | Цель | Владелец |
|---------|---------|------|----------|
| Defect Density | дефектов ÷ KLOC (или ÷ story points) | тренд ↓ | s5-qa |
| Defect Removal Efficiency (DRE) | дефекты до прода ÷ (до + после прода) × 100% | ≥ 95% | s5-qa |
| Escaped Defects | дефекты, найденные в проде после релиза | тренд → 0 | s6-sre |

- **DRE < 90%** → гейты пропускают дефекты: ретро + усиление соответствующего уровня тестов (§3.1).
- **Escaped Defect S1/S2** → обязательный post-mortem (s6-sre) + новое правило в backlog
  (петля «инцидент → gate», roadmap п.28).
- `s0-tracker` агрегирует defect-метрики в `cycle-summary.md` рядом с DORA (§7.2).

---

## 8. Запрещено во всей системе (нарушение = BLOCKER)

> Security-специфичные запреты и severity по CVSS — в `security.md §1, §7`.
> Ниже продублированы ключевые security-BLOCKER для единого списка.

```
✗ Секреты (токены, пароли, ключи) в коде, логах, .md файлах, git-истории
✗ Продакшн-данные в тестах
✗ Хард-код IP/URL/порта без конфигурации
✗ Игнорирование ошибок (pass / catch without logging)
✗ Деплой без rollback-плана
✗ Переход в следующий этап без закрытого Quality Gate
✗ UAT в симуляторе/эмуляторе вместо реальной системы
✗ Закрытие задачи без DoD (все 11 пунктов)
✗ Line coverage вместо branch как сигнал покрытия; критичный модуль без mutation-тестов (§3.1)
✗ Внешний адаптер (БД/API/очередь) без integration-теста; внешний API без contract-теста (§3.1)
✗ Дублирование > 3% на новом коде без рефакторинга или явного обоснования (§3)
✗ Некритичный дефект (S3/S4) с user-facing impact в проде без записи в known-issues.md
  (Workaround + Detection signal) — это «проигнорированный», а не «известный» дефект (§6.1)
✗ Critical/High уязвимости в релизе
✗ Нефункциональные тесты в prod-ветке
✗ Система в prod без auto-heal (применимого к её топологии деплоя)
✗ Система в prod без алертов на SLO breach
✗ Архитектурный паттерн без обоснования через Quality Attribute и NFR
✗ Паттерн добавлен "про запас" без привязки к конкретной проблеме из BRD/NFR
✗ Deployment Constraint не зафиксирован в BA-NFR.md
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

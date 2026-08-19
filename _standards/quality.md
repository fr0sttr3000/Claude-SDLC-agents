# Стандарт качества и надёжности — SDLC Vault

> Этот файл — единственный источник истины по качеству.
> Каждый агент читает его перед работой. Правила не опциональны.
> Действующий baseline относится к общей платформе и поддерживаемому Cycle 1.
> Cycle 2/3 и их Gate 6/7 — `FROZEN / NOT SUPPORTED`; сохранённые ниже критерии
> являются historical implementation baseline и не блокируют Cycle 1.
>
> Смежные стандарты:
> - `$SDLC_VAULT/_agents/_standards/tdd.md` — обязательный test-first порядок,
>   Red evidence и repair loop для кода и миграций поддерживаемого Cycle 1
> - `$SDLC_VAULT/_agents/_standards/data-formats.md` — форматы данных (БД-типы, env, API-контракт, тесты форматов)
> - `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` — единые frontmatter, producer/input/output
>   связи и Obsidian-навигация для новых/существенно изменённых Cycle 1 Markdown artifacts
> - `$SDLC_VAULT/_agents/_standards/security.md` — **параллельный active Security-трек (SG1–SG4)**: severity по CVSS,
>   threat model, RBAC, SAST/SCA/secrets, pentest, privacy. Переход = зелёный Quality Gate **И** Security Gate.

Имена вроде `BA-BRD.md`/`ARCH-HLD.md` ниже — краткие человекочитаемые названия типов, а не
указание consumer-у искать один undated файл. Исполняемый Gate разрешает их stable logical ids
только через `_contract/current-artifact-groups-v1.tsv` и `tracking/current-artifacts-v1.tsv`.
При существующем manifest stale/missing/digest-invalid current row блокирует Gate без glob
fallback; date-versioned предыдущие файлы остаются историей.

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
| DoR-7 | Security evidence последовательно: SG1 до начала S3; SG2 до начала S4 | S3/S4 | s2-security / s3-security | s3-arch / s4-dev | 🤖 авто |

> 🤖 авто — проверяется `s0-validate /dor-check [N]` (dor-check.sh)
> 🤖 частично — скрипт выявляет грубые нарушения, финальное решение за агентом
> 👤 вручную — субъективная оценка, скрипт не применим

### Дедлайн готовности
DoR должен быть выполнен **до старта этапа**, а не параллельно с ним:
- DoR-1, DoR-6: за 0 часов (проверяется в момент старта)
- DoR-2, DoR-3, DoR-4, DoR-5: до `/sprint-init` спринта, в котором начинается S3
- DoR-7: SG1 — до первого артефакта s3-arch; SG2 threat model — после HLD/API spec, но до S4
Historical DoR поставки не входит в active таблицу: Cycle 2 заморожен и не является
условием старта или завершения Cycle 1.

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
| DoD-1 | Код соответствует effective `complexity_max`, SRP и duplication ≤3% нового кода | Агент-исполнитель | s4-techlead | 🤖 частично |
| DoD-2 | Тесты по пирамиде: branch/mutation проходят effective policy; применимые integration/contract evidence PASS (§3.1) | Агент-исполнитель | s4-techlead | 🤖 авто |
| DoD-3 | Code review пройден: 0 открытых BLOCKER и MAJOR | Агент-исполнитель | s4-techlead | 👤 вручную |
| DoD-4 | Документация обновлена (README/API-spec/docstring) | Агент-исполнитель | Агент-получатель | 👤 вручную |
| DoD-5 | Release-документы: `N/A` внутри обязательного Cycle 1; после verified completion optional owner `s0-tracker /release-notes vX.Y.Z` работает по `RELEASE_NOTES_V1` | s0-tracker (отдельная utility) | release-notes-check.sh | N/A для Cycle 1 |
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

| # | Тип К: Код | Тип Д: Документ/design | Тип И: Executable migration |
|---|:----------:|:---------------:|:---------------------:|
| DoD-1 effective complexity, SRP, duplication ≤3% | ✅ | ❌ | ✅ |
| DoD-2 тесты по пирамиде + пороги §3.1 | ✅ | ❌ | ⚠️ тест миграций вместо unit |
| DoD-3 code review | ✅ | ✅ | ✅ |
| DoD-4 документация обновлена | ✅ | ✅ | ✅ |
| DoD-5 release docs | ❌ N/A в active Cycle 1 | ❌ N/A в active Cycle 1 | ❌ N/A в active Cycle 1 |
| DoD-6 update notes (DEV-*) | ✅ | ❌ | ✅ |
| DoD-7 нет S1/S2 багов | ✅ | ✅ | ✅ |
| DoD-8 секреты | ✅ | ✅ | ✅ |
| DoD-9 NFR проверены | ✅ | ⚠️ NFR адресованы в дизайне | ✅ |
| DoD-10 артефакт в outputs/ | ✅ | ✅ | ✅ |
| DoD-11 тесты форматов | ✅ | ❌ | ✅ |

**Тип К — Код** (`s4-dev` и executable test code, создаваемый `s4-qa-auto` в S4):
оцениваются все 11 пунктов; обязательны все применимые. DoD-5 имеет `N/A` в
поддерживаемом Cycle 1. Markdown-отчёт о запуске тестов проверяется отдельно как Тип Д.

**Тип Д — Документ** (s1-pm, s1-pmo, s1-finance, s2-ba, s2-po, s2-qa-req,
s2-test-strategy, s2-security, s3-arch, s3-rbac, s3-security, s3-dba design/runbook,
отчёты s4-qa-auto,
s4-techlead, s5-qa, s5-qa-auto, s5-perf, s5-security, s0-tracker):
обязательны DoD-3, DoD-4, DoD-5, DoD-7, DoD-8, DoD-10 — итого 6 пунктов.

**Тип И — Executable migration** (`s4-dev`, только Stage 4): применяется лишь когда
создаётся исполняемая migration после QA-owned Red. Обязательны все software controls,
включая exact-source TDD PASS, `upgrade→downgrade→upgrade`, verified secrets evidence,
effective policy, update notes и применимые format tests. Stage 3 design/runbook проверяется
как Тип Д; s4-devops остаётся frozen historical role.

### Связь DoD → DoR следующего этапа

**DoD-10 выполнен = DoR-1 следующего этапа выполнен автоматически.**

Это явный контракт между агентом-поставщиком и агентом-получателем:

| Агент закрывает DoD-10 | Это автоматически закрывает |
|------------------------|----------------------------|
| s1-pm, s1-pmo, s1-finance, s0-quality-gates | DoR-1/effective policy для s2-ba и всего S2 (Gate 1) |
| s2-ba, s2-po, s2-qa-req, s2-test-strategy, s2-security | DoR-1 для s3-arch (Gate 2, включая test strategy и SG1) |
| s3-arch, s3-security, s3-rbac, s3-dba | DoR-1 для s4-dev (Gate 3) |
| s4-qa-auto Red, s4-dev Green/Repair, s4-qa-auto Run, s4-techlead review | DoR-1 для s5-qa (Gate 4) |
| s5-qa test plan, s5-qa-auto, s5-perf, s5-security, s5-qa Go/No-Go | Cycle 1 validation boundary (Gate 5) |
| s0-tracker completion report | Финальный versioned Cycle 1 completion handoff после Gate 5 |

Если DoD-10 не выполнен — DoR-1 следующего этапа гарантированно провален.
Агент-получатель, обнаружив отсутствие файлов в предыдущем outputs/, записывает нарушение в `tracking/dor-violations.md` и сообщает пользователю. Агенты не взаимодействуют напрямую — только через файлы.

### Технический долг не заменяет DoD

DoD бинарен. Запись в `tracking/tech-debt.md` документирует отложенное улучшение, но не
разрешает объявить применимый проваленный DoD-пункт выполненным. Задача остаётся IN_PROGRESS
или BLOCKED, пока критерий не выполнен либо владелец стандарта не изменит его применимость
отдельным от задачи governance-решением.

Запись обязана содержать:
- Какой DoD-пункт нарушен
- Конкретную причину (не "нет времени", а реальное ограничение)
- Кто подтвердил регистрацию долга (это не waiver для gate)
- План устранения и дедлайн (не позже следующего спринта)

**Последствия незакрытого TD:**
- TD со статусом OPEN и просроченным дедлайном → блокирует `/sprint-close`
- Накопление > 3 открытых TD → блокирует старт нового спринта
- TD без плана устранения → не принимается

Шаблон: `_standards/tech-debt-template.md`
Файл проекта: `$SDLC_PROJECTS_DIR/{PROJECT}/tracking/tech-debt.md` (создаётся s0-tracker при `/sprint-init`)

---

## 3. NFR defaults and effective policy

Единственный числовой источник global thresholds —
`_contract/quality-policy-v1.tsv`. Project override может только ужесточить его. Любой
consumer получает exact operator/value/unit/revision через:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-quality-gates/quality-policy-read.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" --all
```

Registry охватывает availability, p95/p99, error rate, RTO/RPO, branch/mutation, test pass,
E2E automation, complexity и Critical/High maximum. Evidence без exact metric id, threshold,
observed value, unit и effective policy revision — `UNVERIFIED`. Security severity определяется
отдельно по CVSS в `security.md`; code duplication остаётся самостоятельным DoD правилом.

---

## 3.1 Уровни и качество тестирования (test pyramid)

Тесты строятся по пирамиде. Каждый уровень — отдельный контроль; нельзя компенсировать
отсутствие нижнего уровня верхним (анти-паттерн «ice-cream cone»).

| Уровень | Что проверяет | Порог | Где enforced |
|---------|---------------|-------|--------------|
| **Unit** | логика в изоляции (моки внешних зависимостей) | `branch_coverage_percent` + `mutation_score_percent` из effective policy | DoD-2, Gate 4 |
| **Integration / component** | модуль + реальная БД/адаптер/очередь (testcontainers, не моки) | существуют и проходят для КАЖДОГО внешнего адаптера (БД, API-клиент, брокер) | Gate 4 |
| **Contract** | согласование consumer↔provider по API (consumer-driven: Pact / схема) | существуют и проходят для каждого внешнего API-контракта; сверены с ARCH-api-spec.yaml | Gate 4 |
| **E2E** | сквозные пользовательские сценарии в реальной системе | exact UAT path set + `e2e_automation_percent` из effective policy | Gate 4/5 (s5-qa-auto) |
| **Performance** | load / stress / soak | вердикт PASS (§4 Gate 5) | Gate 5 (s5-perf) |

**Покрытие — branch, не line.** Line coverage даёт ложную уверенность: строка выполнена ≠
ветка/условие проверены. Exact minimum всегда разрешается по metric id
`branch_coverage_percent`.

**Mutation score — реальный сигнал качества тестов.** Покрытие показывает, что код выполнен;
мутационное тестирование показывает, что тесты **ловят дефекты** (инструменты: mutmut /
Cosmic Ray — Python, Stryker — JS/TS, PIT — Java). Exact minimum всегда разрешается по metric
id `mutation_score_percent`.

> **Критичные модули** — доменное ядро, контроли безопасности (authn/authz), денежные и
> расчётные операции, обработка персональных данных. Помечаются в `ARCH-HLD.md` (s3-arch)
> или техлидом при review. Для остального кода mutation желателен, но не блокирует.

**Пороги по tier могут только расти**: `s0-quality-gates` фиксирует обоснованное ужесточение в
`tracking/quality-gates.md`. Tier сам по себе не подменяет machine policy и не разрешает
локальному consumer выбирать число.

**Contract testing ≠ формат-тесты.** `test_api_format.py` (data-formats.md) проверяет типы и
формат полей; contract-тест проверяет **взаимные ожидания** consumer и provider (форма
запроса/ответа, семантика, версионирование). Это разные контроли — оба обязательны при наличии API.

**Кто пишет:** unit / integration / contract — `s4-qa-auto` **до production-кода**
по `tdd.md`; `s4-dev` реализует Green/Repair, но не подписывает тестовый вердикт. E2E-автоматизация —
`s5-qa-auto`; performance — `s5-perf`. Отчёт о покрытии агрегирует `s5-qa-auto` в `AUTO-*-coverage.md`.

---

## 4. Quality Gates — переходы между этапами

Переход заблокирован, пока Gate не пройден. Gate проверяет агент-получатель.

> **Параллельно действует active Security-трек (SG1–SG4) — см. `security.md §3`.**
> Этап пройден только когда зелёный И Quality Gate (ниже), И соответствующий Security Gate.
> Security-критерии (threat model, RBAC, SAST/SCA/secrets, pentest) вынесены в `security.md`;
> ниже оставлены кросс-ссылки на нужный SG.

```
S1 Planning ──[Gate 1]──► S2 Requirements
S2 Requirements ──[Gate 2]──► S3 Design
S3 Design ──[Gate 3]──► S4 Development
S4 Development ──[Gate 4]──► S5 Testing
S5 Testing ──[Gate 5]──► CYCLE 1 VALIDATED
Cycle 2/3 ── FROZEN / NOT SUPPORTED
```

### Gate 1 (S1 → S2)
Проверяет: **s2-ba** перед началом работы
```
□ Feasibility имеет `Assessment status: COMPLETE`, Scope In/Out и четыре обязательные
  machine-readable оси technical/economic/operational/legal с evidence и owner; до Finance
  это только `CONDITIONAL_GO / PRE_FINANCE`, а не финальный GO
□ Current Business Case digest-bound к feasibility, содержит numeric NPV/ROI/payback и
  finance PASS/CONDITIONAL; effective GO требует PASS всех осей и Finance
□ Charter и Risk Register созданы после Finance, digest-bound к current feasibility и
  Business Case и фиксируют один effective Gate 1 decision/profile/source context
□ Feasibility acknowledgement и Charter signature подтверждены отдельными Human Approval v1
  с launcher-owned receipts; agent-authored YAML не является подписью
□ Risk Register содержит ≥10 полных строк с category, P, I, P×I score, owner, mitigation,
  trigger, status и constraint link; placeholder/duplicate/ошибка score блокирует Gate
```

### Gate 2 (S2 → S3)
Проверяет: **s3-arch** перед началом работы
```
□ BA-BRD.md существует, все FR с ID и AC
□ BA-NFR.md существует, все NFR с числами
□ QA-REQ-*-review.md существует, 0 открытых BLOCKER
□ PO-backlog.md существует, все Must-stories с AC
□ QA-*-test-strategy.md существует и связывает Must-FR/NFR с уровнями тестов и Red-критериями
□ SEC-*-security-requirements.md существует и SG1 содержит abuse cases, data classification и ASVS
□ Нет требований с маркерами: "и/или" / "обычно" / "при необходимости"
□ Quality Characteristics v1 связан с current Product Profile и only-up policy
□ Interaction: UXF/UXC либо profile-confirmed NOT_APPLICABLE; required Accessibility имеет
  confirmed standard и измеримые A11Y-* criteria
```

### Gate 3 (S3 → S4)
Проверяет: **s4-dev** и **s4-techlead** перед началом работы
```
□ ARCH-HLD.md существует, ADR написаны для всех ключевых решений
□ ARCH-api-spec.yaml существует при наличии API; иначе HLD содержит явное N/A evidence
□ Для выбранного data store существует stack-native schema/migration design либо явное
  обоснованное `applicability: not-applicable`; реализация миграции следует только после Red
□ QA-*-test-strategy.md существует и связывает Must-FR/NFR с уровнями тестов и Red-критериями
□ HLD Quality Characteristic Scope подтверждает application Reliability и Maintainability;
  Performance/Compatibility/Flexibility/Safety совпадают с Product Profile applicability
□ `_contract/RUNTIME_CONSTRAINTS_V1.md` VERIFIED: canonical idea→PMO→current NFR→current HLD,
  exact `RC-NNN` set; `Deployment/operations authorization: NOT_GRANTED`

# Безопасность — Security Gate SG2 (security.md §3)
□ Security Gate SG2 (Design) пройден: threat model 0 Critical/High + применимый
  authorization enforcement (RBAC/ABAC/ACL и stack-native эквивалент) + SoD
  (детали и чек-лист — в security.md §3 SG2; владелец s3-security + s3-rbac)

# Форматы данных (data-formats.md §5 s3-dba / §6 Gate 3)
□ Для SQL/PostgreSQL применены требования TIMESTAMPTZ/NUMERIC/JSONB/ENUM из data-formats.md;
  для другого store зафиксирован эквивалент с теми же инвариантами времени, точности и schema
□ При наличии env/config: все переменные задокументированы с типом и форматом; иначе N/A
```

### Gate 4 (S4 → S5)
Проверяет: **s5-qa** перед началом тестирования
```
□ Все PR из спринта закрыты (0 IN_PROGRESS у s4-dev)
□ Все PR прошли code review (TL-*-review-PR*.md для каждого PR)
□ DEV-*-update-notes-PR*.md существуют для каждого PR
□ QA-TDD-status.md связывает handoff с exact source revision; его свободный PASS не является evidence
□ Evidence Contract v1: все minimum PR checks имеют VERIFIED PASS или structured applicable N/A
□ Unit/integration/contract/lint/typecheck evidence связано с тем же source revision (§3.1)
□ Security Gate SG3 имеет `SG3 VERIFIED` от s0-validate для raw SAST/SCA/secrets/dependency results
□ Pipeline-policy evidence подтверждает immutable deps, least privilege, untrusted-PR isolation,
  protected policy files и artifact/cache integrity выбранного executor-а
□ s4-techlead проверил generated summary и evidence ids; developer не подписывал свой verdict
□ При required Compatibility integration и contract evidence имеют PASS; profile-confirmed
  N/A оформлен structured NOT_APPLICABLE для обоих checks
□ TL review проверил Modularity, Reusability, Analysability, Modifiability и Testability
  отдельно, связан с exact source/profile и содержит evidence ids
□ DoD выполнен для каждого PR (все 11 пунктов, включая DoD-11)

# Форматы данных (data-formats.md §6 Gate 4)
□ Применимые env/db/api format tests существуют и проходят; N/A имеет HLD/ADR evidence
□ Для SQLAlchemy/PostgreSQL нет Mapped[datetime] без TIMESTAMP(timezone=True)
□ Для pydantic-settings нет list/set env без JSON-validator mode="before"
□ При наличии env README содержит таблицу переменных с типами и форматами
□ При наличии migrations upgrade→downgrade→upgrade прошёл на чистой БД
```

### Gate 5 (S5 → завершение validation scope Cycle 1)
Проверяет: **s5-qa**. Gate 5 подтверждает качество Cycle 1, но не разрешает deploy
и не требует участия frozen-агентов `s6-release`/`s6-sre`. Опциональная подготовка release
notes выполняется после verified completion отдельной utility `s0-tracker /release-notes`;
она не меняет Gate 5 и не выполняет external publication/build/deploy actions.
```
□ QA-go-no-go.md существует с вердиктом GO
□ Functional Suitability: каждый Must-FR из BA-BRD.md покрыт ≥1 приёмочным тест-кейсом
  с результатом PASS; трассировка полная по BA-RTM.md (0 непокрытых Must-FR) (ISO 25010 — §4.1)
□ 0 открытых S1 багов, 0 открытых S2 багов
□ Observed pass rate проходит effective `test_pass_rate_percent` из current Quality Policy revision
□ UAT sign-off получен в согласованной репрезентативной среде с реальным build
□ PERF-report.md содержит PASS/CONDITIONAL PASS либо NOT_APPLICABLE с BA/HLD evidence
□ Security Gate SG4 пройден: SEC-*-pentest-report.md с вердиктом PASS (DAST/pentest, 0 Critical/High по CVSS)
  (владелец s5-security; детали — security.md §3 SG4)
□ AUTO-*-coverage.md существует и проходит effective `e2e_automation_percent` из current
  Quality Policy revision
□ Known Issues: каждый открытый user-facing S3/S4 или security Low/Medium имеет disposition
  KNOWN_ISSUE, полную OPEN-запись, связанный Tech Debt/Patch SLA и отдельный проверенный
  Human Approval v1; security Medium дополнительно имеет Risk Exception v3 (§6.1) — иначе No-Go
```

### Gate 6 — FROZEN / NOT SUPPORTED (historical implementation baseline)

Критерии ниже сохранены для будущего redesign. Они не являются active gate, не дают
product-readiness claim и не блокируют Cycle 1.
```
□ stage6-deploy/outputs/DEPLOY-TDD-status.md содержит status: PASS
□ Поставка соответствует актуальному tracking/SDLC-goals.md
□ REL-checklist.md заполнен полностью
□ REL-*-release-notes-v*.md существует
□ CHANGELOG.md обновлён (версия закрыта)
□ Для runtime/deploy action rollback-план задокументирован и проверен; artifacts-only имеет version fallback
□ Operations owner/observability существуют только для выбранного operational handoff; иначе N/A
□ Monitoring Stack, Playbook Executor и Auto-Heal Authorization заполнены для выбранных capabilities
□ Выбранные alerts/dedup прошли fire drill; если alerts не заказаны — N/A с goal evidence
□ DEVOPS-runbook.md актуален, если выбран operations-pack/execute-deploy; иначе N/A
□ Release notes содержат секцию «Известные проблемы» из known-issues.md (все OPEN с impact) (§6.1)
□ Security Gate SG4 (Pre-Prod) подтверждён: SEC-*-pentest-report.md с вердиктом PASS
  (исполняется в S5; владелец s5-security; детали — security.md §3 SG4)
```

---

## 4.1 ISO/IEC 25010:2023 — девять product-quality characteristics

Quality Gates покрывают девять характеристик качества продукта по **ISO/IEC 25010:2023**.
Applicability, owner, evidence и gate индексируются по
`_contract/QUALITY_CHARACTERISTICS_V1.md`; каждый optional N/A связан с current Product
Profile schema v5. Global minimum действует для каждого REQUIRED check и может меняться
проектом только вверх.

| Характеристика (2023; ex-2011) | Где гейтится | Статус |
|--------------------------------|--------------|--------|
| **Functional Suitability** (полнота / корректность / уместность) | Gate 2 (FR с AC), **Gate 5 (Must-FR ↔ acceptance ↔ RTM)** | ✅ |
| **Performance Efficiency** (time / resource / capacity) | §3 NFR (p95/p99/error rate), Gate 5 (PERF-report), s5-perf | ✅ |
| **Compatibility** (co-existence / interoperability) | Profile applicability; Gate 3 HLD scope; Gate 4 integration + contract exact-source evidence | ✅ / accepted profile N/A |
| **Interaction Capability** (ex-Usability) | Gate 2 UXF/UXC + UAT path; Gate 5 UAT | ✅ / accepted non-UI N/A |
| **Reliability** (maturity / availability / fault tolerance / recoverability) | Gate 2 NFR; Gate 3 application-level HLD scope/tactics; operations frozen | ✅ для Cycle 1 |
| **Security** (confidentiality / integrity / non-repudiation / accountability / authenticity) | security.md active SG1–SG4; SG5 historical | ✅ для Cycle 1 |
| **Maintainability** (modularity / reusability / analysability / modifiability / testability) | Gate 3 HLD scope; Gate 4 five-dimension TL review + evidence ids; DoD-1/§3.1 | ✅ |
| **Flexibility** (ex-Portability: adaptability / scalability / installability / replaceability) | Profile applicability; Gate 3 HLD scope; Gate 4 build/evidence | ✅ / accepted profile N/A |
| **Safety** (новое в 2023) | PMO/profile applicability; Gate 3 HLD scope for required safety constraints | ✅ / accepted profile N/A |

**Accessibility** сохраняется как явный profile-selected контроль Interaction Capability:
Gate 2 требует confirmed standard и измеримые A11Y criteria, Gate 5 — их UAT evidence.
Это не десятая самостоятельная characteristic ISO/IEC 25010:2023.

## 4.2 ISO/IEC 25019:2023 — quality-in-use

Актуальный **ISO/IEC 25019:2023** определяет quality-in-use как отдельную модель из трёх
characteristics, далее разделённых на sub-characteristics. Названия пяти characteristics из
заменённой модели ISO/IEC 25010:2011 здесь не переиспользуются. В supported Cycle 1
quality-in-use закрывается project-specific product-level criteria и UAT Gate 5.
SLO/error-budget operations не подставляются: они остаются frozen вместе с Cycle 3 и не
являются условием Cycle 1 validation.

Официальные модели: <https://www.iso.org/standard/78176.html> (ISO/IEC 25010:2023) и
<https://www.iso.org/standard/78177.html> (ISO/IEC 25019:2023).

Маппинг трека безопасности на NIST SSDF / OWASP SAMM / ASVS / SDL / SLSA — в `security.md §5`.

---

## 5. Обязательные паттерны надёжности

Каждая система обязана рассмотреть перечисленные capabilities и реализовать применимые согласно
NFR, topology и выбранному стеку. `not-applicable` требует явного обоснования в HLD/ADR:

### 5.1 Устойчивость к отказам
```
□ Timeout на каждом внешнем вызове; точное значение из NFR/dependency SLA
□ Retry с bounded exponential backoff; attempts/factor/delays/jitter только из NFR/dependency SLA
□ Circuit breaker для внешних зависимостей с threshold/recovery из NFR
□ Graceful shutdown завершает текущую работу в deadline из NFR/runtime contract
□ Для confirmed long-running network service: observable liveness/readiness contract с
  threshold и interface из Project facts/HLD; CLI/library/desktop/worker не получают
  обязательный HTTP endpoint или container probe по умолчанию
```

### 5.2 Наблюдаемость (Observability) — требования и instrumentation с первого дня
```
□ Формат и уровень логов определены в NFR/HLD; production policy не подставляется по умолчанию
□ Каждый лог-запись: timestamp (UTC), level, service, correlation_id, message
□ Метрики (RED): Request Rate / Error Rate / Duration (p50/p95/p99)
□ Алерты: на нарушение SLO, не на симптомы
□ НЕ логировать: пароли, токены, PII, тела запросов с секретами
```

#### Alert Deduplication — обязательный design contract при применимости

Правила алертов проектируются под фактический `Monitoring Stack` проекта. Cycle 1 фиксирует
требования и проверяемый design contract; production-настройка и fire drill остаются frozen
Cycle 3 deliverables:

```
□ dedup_key/fingerprint стабилен и состоит из environment + service + alertname
  + нормализованного resource + root-cause/SLO; timestamp и текущее значение
  метрики в ключ не входят
□ group_by и group_wait/group_interval объединяют один burst в один incident/notification
□ inhibition подавляет downstream-симптомы при активном root-cause alert
□ flap control использует устойчивый for/pending window и не открывает новый
  incident при каждом кратком переходе
□ repeat_interval ограничивает повторы, но state change и escalation доставляются сразу
□ resolved notification закрывает тот же incident по тому же fingerprint
□ silence имеет owner, причину и срок окончания; бессрочные silence запрещены
□ разные environment, service или root cause не схлопываются
```

Будущий fire drill должен доказать: один причинный сбой → один incident/notification,
симптомы inhibited/grouped, recovery закрывает тот же incident. Реализация
(Prometheus Alertmanager, Grafana, Datadog, Zabbix, cloud-native или иная)
выбирается из `Monitoring Stack`, а не подставляется по умолчанию.

### 5.3 Операционная готовность — architecture consideration в Cycle 1

Cycle 1 фиксирует применимые требования и design decisions. Runbook/deploy/operations
execution не являются active deliverables до разморозки Cycle 2/3.
```
□ Применимость runbook определена; требования, owner и обязательные failure modes зафиксированы
□ Rollback strategy и будущий verification plan задокументированы без заявления о deploy-тесте
□ Для stateful scope определены backup/restore requirements, RPO/RTO и будущий restore test
□ Применимый SLO определён в NFR (например, availability и latency) вместе с evidence contract
□ Для применимого SLO определены error-budget formula и reporting window; фактическое значение
  остаётся NOT_OBSERVED / deferred без production evidence
```

Исполняемый runbook, настроенные backups, проверенный restore/rollback и наблюдаемый error
budget становятся обязательными только после отдельной разморозки соответствующего Cycle 2/3
scope и не блокируют Cycle 1.

### 5.4 Идемпотентность и консистентность данных
```
□ Все write-операции идемпотентны или защищены уникальным ключом
□ Транзакции для операций, изменяющих несколько сущностей
□ Soft delete вместо hard delete (кроме явных исключений с обоснованием)
□ Миграции: всегда с downgrade(), тестировать upgrade+downgrade+upgrade
```

### 5.5 Recovery capabilities — обязательная оценка применимости в дизайне

Auto-heal — один из возможных operational mechanisms, а не default-архитектура.
Cycle 1 оценивает требуемые recovery capabilities и реализует только применимое поведение
кода; infrastructure/monitoring automation остаётся frozen.
Цикл: **Detect → Isolate → Recover → Verify**

> **Применимость capabilities зависит от цели, topology и authorization.**
> Runtime Constraints фиксируются в BA-NFR.md (s2-ba) и отражаются в ARCH-HLD.md (s3-arch).
> Legacy-поле `Deployment Constraint` допустимо только как kickoff migration input.
> Одновременные canonical/legacy fields требуют явного разрешения конфликта; legacy удаляется
> до Gate 2. Constraint не является deploy/operations authorization.
> Пункты ниже помечены: [SC] = single-container / [MI] = multi-instance / [SL] = serverless.
> Реализуются только явно выбранные capabilities. Неприменимый пункт = не BLOCKER,
> но причина и evidence должны быть задокументированы в HLD/runbook.

#### Historical infrastructure level (s4-devops, FROZEN / NOT SUPPORTED)
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
  (точные N/T/recovery thresholds только из BA-NFR/project quality gates)
  Применяется только если есть внешние зависимости (API, БД, очереди)
□ [SC,MI] Watchdog-процесс: периодически проверяет критичные подсистемы,
  перезапускает зависшие воркеры/очереди
  Применяется только если есть фоновые воркеры/очереди
□ [SC,MI,SL] Dead letter queue: упавшие задачи — в DLQ, не теряются, обрабатываются
  при восстановлении
  Применяется только если есть асинхронная обработка задач
□ [SC,MI,SL] Retry с backoff: временные сбои внешних зависимостей не роняют систему
```

#### Historical monitoring level (s6-sre, FROZEN / NOT SUPPORTED)
```
□ [SC,MI,SL] Alert → Auto-action: алерт не только уведомляет, но и запускает
  автоматическое действие (restart, scale-out, failover)
□ [MI,SL] SLO breach → автоматический rollback (если настроен canary/blue-green)
□ [SC,MI,SL] Error budget exhausted → автоматическая заморозка деплоев
□ [SC,MI] Watchdog heartbeat: процесс пишет метку каждые N минут;
  отсутствие метки → алерт + автоперезапуск
```

Эти infrastructure/monitoring capabilities не требуются для завершения Cycle 1. После
отдельного решения о разморозке они должны получить новые requirements и tests; прежний
список не является заранее утверждённой архитектурой будущих Cycle 2/3.

---

## 6. Quality Gate 7 — FROZEN / NOT SUPPORTED

Gate 7 не является active gate и не запускается supported launcher. Чеклист ниже сохранён
только как historical implementation baseline до отдельного redesign Cycle 3.

```
□ stage7-ops/outputs/OPS-TDD-status.md содержит status: PASS
□ Ops-конфигурация соответствует актуальному tracking/SDLC-goals.md
□ Выбранный monitoring/dashboard deliverable активен и проверен; иначе N/A evidence
□ Выбранные alerts трассируются к SLO/NFR и протестированы (fire drill)
□ Дедупликация протестирована: стабильный fingerprint, grouping, inhibition,
  flap control, resolve и отсутствие cross-service/cross-environment collapsing
□ Выбранный auto-heal проверен безопасным failure scenario против точного NFR threshold
□ Runbook создан для каждого применимого failure mode из goal/NFR/known issues
□ Error budget рассчитан за выбранное NFR reporting window, если SLO governance включён
□ Operations owner/on-call/escalation определены для выбранного operational scope
□ Для каждой OPEN-записи known-issues.md с user-facing impact: алерт настроен и протестирован
  (fire drill), SRE-runbook-KI-*.md существует, auto-remediation где возможно (§6.1)
□ SRE-*-ops-report.md создан в stage7-ops/outputs/ по cadence из goal/NFR, если выбран reporting
```

Незакрытый historical Gate 7 не блокирует Cycle 1, следующий sprint или release preparation.

---

## 6.1 Known Issues — операционный контракт (KEDB)

Некритичный открытый дефект класса S3/S4 либо security Low/Medium может быть явно принят
пользователем или уполномоченным владельцем продукта как неблокирующий для завершения Cycle 1.

Принятие допустимо только для дефекта с user-facing impact, зарегистрированного как Known
Issue. Оно не превращает проваленный обязательный контроль в PASS, не применяется к S1/S2
или security Critical/High и не заменяет исправление дефекта.

Принятие Known Issue разрешает завершить Cycle 1 с документированным известным ограничением.
Оно само по себе не выполняет и не авторизует публикацию, build, release, deploy или
использование в production.

**Реестр:** `tracking/known-issues.md` (шаблон `known-issues-template.md`, создаёт s0-tracker).
Historical operational consumer — `s6-sre`; пока Cycle 3 заморожен, этот consumer не запускается.
Дедлайн / исполнитель / одобрение фикса НЕ дублируются здесь — только ссылка `→ tech-debt`.

**Правило принятия (s5-qa, Gate 5):** дефект получает disposition `KNOWN_ISSUE` только при
выполнении всех условий:

- severity — S3/S4 либо security Low/Medium;
- `Impact = user-facing`;
- определены Trigger, Workaround и Detection signal;
- создана связанная запись в `tech-debt.md` с owner, планом исправления и Patch SLA;
- пользователь или уполномоченный владелец продукта создал отдельный Human Approval v1,
  привязанный к exact source revision, Known Issue ID и digest принимаемого дефекта.

Агент не может создать или имитировать такое одобрение. Без действительного Human Approval
дефект остаётся открытым непринятым дефектом и блокирует Gate 5.

Для security Medium дополнительно обязателен Risk Exception v3. Принятие Known Issue
владельцем продукта и security risk exception являются разными решениями и не заменяют
друг друга.

**Обязательные поля записи:** Severity · Trigger · exact `Impact: user-facing — ...` ·
Workaround · Detection signal · Auto-remediation (или «нет») · `→ tech-debt` · ссылка на
Human Approval v1 · отдельные machine fields Fix release version/build evidence ref/evidence
sha256/source revision/verification test id · Operational scope · alert/runbook cleanup
evidence · Status. Severity использует только `S3|S4|CVSS-MEDIUM|CVSS-LOW`. Owner и Root-cause
не дублируются: их канонический источник — связанная задача/Tech Debt.

**Release notes:** каждый OPEN Known Issue обязательно включается ровно один раз в раздел
известных ограничений подготовленной версии. Пропуск или дубль принятого Known Issue делает release notes
неполными. Подготовка release notes не является разрешением на публикацию или deploy.

**Единый join-ключ:** имя алерта = id записи (KI-NN) = имя runbook'а (`SRE-runbook-KI-NN.md`).
Поток on-call: алерт `KI-NN` → `known-issues.md` (что сломалось) → `SRE-runbook-KI-NN.md` (как чинить);
auto-remediation отрабатывает сама (§5.5 «Alert → Auto-action»).

**Patch SLA** (срок постоянного фикса; дедлайн фиксируется в `tech-debt.md`):

| Severity | SLA фикса |
|----------|-----------|
| S3 / security Medium | ≤ 1 спринт |
| S4 / security Low | ≤ 3 спринта. Принятие как Known Issue не отменяет Patch SLA и задачу исправления. |

Просроченный Patch SLA → блокирует `/sprint-close` (механизм tech-debt, §2).

**Закрытие:** успешная повторная Cycle 1 validation подтверждает исправление, но сама по себе
не доказывает выпуск версии. Known Issue получает статус `FIXED` только после exact
version/source/test binding к digest-bound Build Evidence v1 с non-source released-build
subject и raw result, перечисляющим exact KI как включённое исправление. До получения такого
evidence запись остаётся `OPEN`. После `FIXED` связанный Tech Debt синхронно имеет `RESOLVED`;
снятие alert/runbook проверяется только для `Operational scope: ACTIVE`, а
`FROZEN_NOT_READY` не создаёт фиктивное operational evidence.

**Active контроль:** Gate 5 — промоушн записи в реестр (s5-qa). Старые связи с Gate 6/7
сохранены только как historical context и не блокируют Cycle 1.

---

## 7. Метрики доставки и качества (DORA + defect metrics)

### 7.1 DORA — пять текущих delivery performance metrics

| Метрика | Что измеряет |
|---------|--------------|
| **Change lead time** | Время от commit в version control до успешного production deployment |
| **Deployment frequency** | Как часто application/service успешно развёртывается в production |
| **Failed deployment recovery time** | Время восстановления после неуспешного production deployment |
| **Change fail rate** | Доля production deployments, потребовавших remediation |
| **Deployment rework rate** | Доля незапланированных deployments вследствие production incident |

Универсальные Elite/High/Medium/Low bands не являются нормативными thresholds этого
стандарта. Метрики сравниваются по тренду внутри одного application/service с неизменной
методикой и явно зафиксированным контекстом.

**Reliability — отдельная operational performance characteristic**, а не одна из пяти
delivery performance metrics DORA. Она требует production SLO/error-budget evidence и
остаётся deferred вместе с frozen Cycle 3; Cycle 1 не заявляет отсутствующее evidence.

Официальная текущая модель: <https://dora.dev/guides/dora-metrics/>. История изменений
метрик: <https://dora.dev/insights/dora-metrics-history/>.

### 7.2 Сбор и тренд метрик (метрики — не аспирация)

Production-backed метрики записываются только из фактического evidence, а не объявляются целью
на бумаге. Без production observation метрика получает `NOT_OBSERVED / deferred`; значение,
тренд и process-debt trigger для неё не придумываются.

| Метрика | Источник данных | Кто собирает | Куда пишет |
|---------|-----------------|--------------|-----------|
| Deployment frequency | production deployment records | FROZEN Cycle 2/3 | historical delivery report |
| Change lead time | version-control commit → successful production deployment | FROZEN Cycle 2/3 | historical delivery report |
| Failed deployment recovery time | failed deployment → restored service | FROZEN Cycle 3 | historical SRE report |
| Change fail rate | deployments requiring remediation ÷ all deployments | FROZEN Cycle 2/3 | historical delivery report |
| Deployment rework rate | unplanned rework deployments ÷ all deployments | FROZEN Cycle 2/3 | historical delivery report |
| Reliability | SLO dashboard and error budget; separate from DORA delivery metrics | FROZEN Cycle 3 | historical SRE report |

- `s0-tracker /report` добавляет в `cycle-summary.md` блок **«Метрики: план vs факт vs прошлый цикл»**.
- Тренд метрики помечается ↑ / ↓ / → только при двух сопоставимых production observations;
  иначе указывается `N/A`.
- Деградация одной наблюдаемой метрики **два цикла подряд** → запись в
  `tracking/tech-debt.md` как процессный долг. `NOT_OBSERVED` не считается деградацией.

### 7.3 Defect-метрики — эффективность гейтов

Показывают, ловят ли гейты дефекты **до** прода, а не сам факт «зелёного» гейта:

| Метрика | Формула | Цель | Владелец |
|---------|---------|------|----------|
| Defect Density | дефектов ÷ KLOC (или ÷ story points) | тренд ↓ | s5-qa |
| Defect Removal Efficiency (DRE) | дефекты до прода ÷ (до + после прода) × 100% | ≥ 95% | s5-qa |
| Escaped Defects | дефекты, найденные после Cycle 1 validation | тренд → 0 | s5-qa; production-only source deferred |

- **DRE < 90%** → гейты пропускают дефекты: ретро + усиление соответствующего уровня тестов (§3.1).
- **Escaped Defect S1/S2**, обнаруженный в доступной среде Cycle 1, → ретро s5-qa + новое
  правило в backlog. Production incident loop deferred вместе с Cycle 3
  (см. current quality remediation в [[plans/roadmap]]).
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
✗ Переход в следующий этап без закрытого Quality Gate
✗ UAT только на mock/simulator без репрезентативного real-build evidence
✗ Закрытие задачи без DoD (все 11 пунктов)
✗ Line coverage вместо branch как сигнал покрытия; критичный модуль без mutation-тестов (§3.1)
✗ Внешний адаптер (БД/API/очередь) без integration-теста; внешний API без contract-теста (§3.1)
✗ Дублирование > 3% на новом коде без рефакторинга или явного обоснования (§3)
✗ Некритичный дефект (S3/S4) с user-facing impact в проде без записи в known-issues.md
  (Workaround + Detection signal) — это «проигнорированный», а не «известный» дефект (§6.1)
✗ Принятие Known Issue без отдельного Human Approval v1 либо использование Known Issue как
  waiver для S1/S2, security Critical/High или проваленного обязательного контроля (§6.1)
✗ Critical/High уязвимости в релизе
✗ Нефункциональные тесты в prod-ветке
✗ Архитектурный паттерн без обоснования через Quality Attribute и NFR
✗ Паттерн добавлен "про запас" без привязки к конкретной проблеме из BRD/NFR
✗ Runtime Constraints не зафиксированы в BA-NFR.md
✗ Legacy `Deployment Constraint` пережил kickoff migration, canonical/legacy conflict не
  разрешён или HLD трактует constraint как deploy/operations authorization

# Запреты форматов данных (data-formats.md)
✗ Для выбранного PostgreSQL stack: TIMESTAMP WITHOUT TIME ZONE вместо TIMESTAMPTZ
✗ Binary floating-point для денег; обязательны currency, decimal precision, scale и rounding,
  а stack-native exact-decimal type выбирается в HLD/ADR
✗ list/set/frozenset env-переменных в формате CSV (1,2,3) — только JSON ([1,2,3])
✗ Mapped[datetime] без TIMESTAMP(timezone=True) в ORM-маппинге
✗ Для выбранного PostgreSQL stack: JSONB-поля без задокументированной структуры
✗ Проект с применимыми DB/ENV/API contracts без соответствующих format tests
✗ ENV-переменные без спецификации типа и формата в README/BRD
```

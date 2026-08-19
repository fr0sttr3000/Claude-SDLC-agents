---
description: Запустить полный или частичный Feasibility Study с поддержкой вето стейкхолдера
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

## Шаг 1 — Разбор аргументов

`$ARGUMENTS` может содержать: `[PROJECT] [флаги через пробел]`

Разбери:
- **PROJECT** = первый токен до пробела (или весь `$ARGUMENTS`, если пробелов нет)
- **budget:N** — переопределить бюджет из idea.md числом N
- **mode:auto** — без интерактивных чекпоинтов (пакетный режим)

`skip:*`, veto секции и `scope:minimal` запрещены для Gate-advancing feasibility. Если
данных для оси нет, создай только DRAFT/BLOCKED с owner/action и не ставь COMPLETE/GO.

Если PROJECT не указан → спроси: «Для какого проекта запускаем Feasibility Study?»
После разбора используй только переменную {PROJECT} для путей. Флаги не являются
частью имени каталога.

---

## Шаг 2 — Чтение входных данных

Прочитай:
1. `$SDLC_VAULT/_agents/_standards/company.md`
2. Все файлы из `$SDLC_PROJECTS_DIR/{PROJECT}/stage1-planning/inputs/`

Из `idea.md` извлеки и запомни:
- `## As-Is` → для Technical и Economic секций
- `## To-Be` → для Operational секции
- `## Критерии успеха продукта` → North Star (не генерируй свой)
- `## Kill Criteria` → риск №1 в Топ-5 + условие No-Go в ВЕРДИКТЕ
- `Deployment Constraint` (в Технических ограничениях) → Technical секция
- `## Неизвестное` + `## Риски и стопперы` → база для Топ-5 рисков

---

## Шаг 3 — Презентация плана (если mode ≠ auto)

Выведи полный план четырёх осей. Жди ответа пользователя.

```
📋 План: Feasibility Study — {PROJECT}
────────────────────────────────────────────
[1] Technical Feasibility        ✅
[2] Economic Feasibility         ✅
[3] Operational Feasibility      ✅
[4] Legal/Compliance Feasibility ✅
[5] Топ-5 рисков                 ✅ (всегда)
[6] ВЕРДИКТ                      ✅ (всегда)

  edit [что]  — изменить предположение или параметр
  [Enter]     — начать
```

После ответа пользователя:
- Обнови данные секций после каждого `edit`
- Если `edit [что]` — переспроси конкретный параметр, запомни новое значение
- Начинай работу только после явного подтверждения

---

## Шаг 4 — Создать артефакт

Файл: `$SDLC_PROJECTS_DIR/{PROJECT}/stage1-planning/outputs/PM-{ДАТА}-feasibility.md`

---

# Feasibility Study — {PROJECT}

Assessment status: {COMPLETE|BLOCKED}
stakeholder_acknowledgement_ref: tracking/approvals/APPROVAL-FEASIBILITY-{ID}.yaml
Axis: technical | Verdict: {PASS|CONDITIONAL|FAIL} | Evidence: {конкретный факт/расчёт} | Owner: {роль}
Axis: economic | Verdict: {PASS|CONDITIONAL|FAIL} | Evidence: {конкретный факт/расчёт} | Owner: {роль}
Axis: operational | Verdict: {PASS|CONDITIONAL|FAIL} | Evidence: {конкретный факт/расчёт} | Owner: {роль}
Axis: legal | Verdict: {PASS|CONDITIONAL|FAIL} | Evidence: {конкретный факт/расчёт} | Owner: {роль}

```
Дата:   {ДАТА}
Агент:  s1-pm
Режим:  {full | minimal | partial — укажи пропущенные секции}
```

---

## Executive Summary

[3 предложения: проблема → решение → предварительный вердикт]

**Вердикт: Go / Conditional Go / No-Go**
Добавь отдельную machine-readable строку `Decision: GO` или `Decision: CONDITIONAL_GO`.
`No-Go` не является Gate 1 PASS. Обязательно добавь точные разделы `## Scope In` и `## Scope Out`
минимум с одним конкретным пунктом каждый.

После записи вычисли SHA-256 артефакта и покажи preview для отдельного human action со scope
`feasibility-acknowledgement`. Агент не создаёт Human Approval YAML/receipt.

---

## 1. Technical Feasibility

{Если секция SKIPPED:}
> [SKIPPED — по решению стейкхолдера]
> Влияние: ВЕРДИКТ не может опираться на техническую осуществимость.

{Если секция выполняется:}

**Стек:** {Q3.1 из idea.md — [DATA — stakeholder interview]}
**Deployment Constraint:** {Q3.6 — single-container / multi-instance / serverless / не определено [DATA — stakeholder interview]}
**Масштаб:** {Q3.2 — [DATA — stakeholder interview]}
**Compliance:** {Q3.4 — [DATA — stakeholder interview]}

### Существующий стек и команда
{из idea.md Q2.4 + company.md}

### Инфраструктурные требования
{на основе Deployment Constraint из Q3.6 — какие компоненты нужны, какие паттерны применимы}

### Оценка сложности перехода As-Is → To-Be
**As-Is:** {Q1.3 из idea.md [DATA — stakeholder interview]}
**To-Be:** {Q1.4 из idea.md [DATA — stakeholder interview]}
**Оценка:** {насколько сложен переход? что технически меняется?}

### Criticality Tier — Классификация риска Cycle 1

Прочитай из idea.md:
- `Runtime Constraints` (Q3.6): {подтверждённые constraints или unknown}
- `Recovery Expectation` (Q3.7): {наблюдаемый результат/threshold/open issue}
- `Observability Expectation` (Q3.8): {application signals/threshold/open issue}

Используй раздел CLAUDE.md «Cycle 1 quality capabilities — без operational tooling».
Tier является risk-классификацией, а не скрытой таблицей infrastructure/tooling defaults.

**Рекомендуемый Criticality Tier: {0 / 1 / 2 / 3}**

Что это означает для вас на практике:
- ✅ {что пользователь получит — на бизнес-языке, без технических терминов}
- ❌ {чего НЕ будет — если тир неполный}

Overhead к бюджету: {+0% / +5-10% / +15-20% / +25-30% [ASSUMPTION]}

Cycle 2/3 delivery/operations tooling: `FROZEN / NOT READY`, в scope решения не входит.

> ⚠️ **Требует подтверждения стейкхолдера** — тир определяет объём работы и бюджет.
> Вынести на чекпоинт перед переходом к следующей секции.

### Вывод: ✅ / ⚠️ / ❌

---

{ЧЕКПОИНТ — если mode ≠ auto:}

```
✅ Technical Feasibility — готово
   {1-2 предложения: ключевой вывод}
   Criticality Tier: {N} — {что это значит на практике, 1 предложение}

   Подтвердить Tier {N}? [Enter = да]  |  edit tier — выбрать другой тир  |  stop
```

---

## 2. Economic Feasibility

{Если секция SKIPPED:}
> [SKIPPED — по решению стейкхолдера]
> Влияние: ВЕРДИКТ не может ссылаться на ROI и финансовые показатели.

{Если секция выполняется:}

**Бюджет:** {Q2.2 из idea.md [DATA] — или переопределён флагом budget:N → [DATA — stakeholder override]}
**Финансовая цель:** {Q2.3 из idea.md [DATA — stakeholder interview]}

### Стоимость разработки
{оценка, помечай [ASSUMPTION] если нет данных}

### Цена статус-кво (без продукта)
**As-Is:** {Q1.3 из idea.md}
**Оценка:** {что теряет бизнес или пользователь каждый месяц без решения — выражай в измеримых единицах [ASSUMPTION]}

### Ожидаемые доходы / экономия
{оценка [ASSUMPTION / DATA]}

### Break-even point
### ROI прогноз

### Вывод: ✅ / ⚠️ / ❌

---

{ЧЕКПОИНТ}

```
✅ Economic Feasibility — готово
   {1-2 предложения}

▶ Следующая: Operational Feasibility
  [Enter] продолжить  |  edit [что]  |  stop
```

---

## 3. Operational Feasibility

{Если секция SKIPPED:}
> [SKIPPED — по решению стейкхолдера]
> Влияние: Оценка операционной готовности команды и пользователей недоступна.

{Если секция выполняется:}

### Изменения в поведении пользователя
**To-Be из интервью:** {Q1.4 из idea.md [DATA — stakeholder interview]}
**Оценка:** {насколько легко пользователи примут переход? нужно ли обучение?}

### Готовность команды к поддержке
{из Q2.4 — кто есть, чего не хватает}

### Операционные процессы
{что меняется в текущих процессах}

### Вывод: ✅ / ⚠️ / ❌

---

{ЧЕКПОИНТ}

```
✅ Operational Feasibility — готово
   {1-2 предложения}

▶ Следующая: Legal/Compliance Feasibility
  [Enter] продолжить  |  edit [что]  |  stop
```

---

## 4. Legal/Compliance Feasibility

{Если секция SKIPPED:}
> [SKIPPED — по решению стейкхолдера]
> Влияние: Compliance-риски не оценены. Убедись, что юридическая экспертиза будет проведена отдельно.

{Если секция выполняется:}

**Compliance из интервью:** {Q3.4 из idea.md [DATA — stakeholder interview]}

### Применимые регуляции
{на основе Q3.4 + анализ по типу продукта}

### Требуемые изменения и ограничения

### Вывод: ✅ / ⚠️ / ❌

---

{ЧЕКПОИНТ}

```
✅ Legal/Compliance — готово
   {1-2 предложения}

▶ Следующая: Топ-5 рисков
  [Enter] продолжить  |  edit [что]  |  stop
```

---

## 5. Топ-5 рисков

Источники рисков (в порядке приоритета):
1. **Kill Criteria из интервью** → {Q4.2 из idea.md} → Риск №1 `[STAKEHOLDER]`
2. **Неизвестное из интервью** → {Q5.1 из idea.md} → `[STAKEHOLDER]`
3. **Риски и стопперы из интервью** → {Q5.2 из idea.md} → `[STAKEHOLDER]`
4. **Собственный анализ** → дополни до 5 рисков

| # | Риск | Источник | Вероятность | Влияние | Митигация |
|---|------|----------|-------------|---------|-----------|
| 1 | {kill criteria из Q4.2} | [STAKEHOLDER] | | | |
| 2 | {из Q5.1} | [STAKEHOLDER] | | | |
| 3-5 | {анализ} | [ANALYSIS] | | | |

---

{ЧЕКПОИНТ}

```
✅ Топ-5 рисков — готово

▶ Последнее: ВЕРДИКТ
  [Enter] продолжить  |  edit [что]  |  stop
```

---

## ВЕРДИКТ

{Проверь kill criteria из Q4.2:
- Если kill criteria достижим в base-сценарии → Conditional Go или No-Go с явным обоснованием
- Если kill criteria недостижим → возможен Go}

**Go / Conditional Go / No-Go**

**Обоснование:**
{Опирайся только на выполненные секции. Для каждой пропущенной — не делай утверждений.}

{Если есть пропущенные секции:}
> ⚠️ Неполный анализ. Не оценивались: [список секций].
> Рекомендуется: повторить `/feasibility {PROJECT}` с полным охватом перед Gate 1.

---

## Пропущенные секции

{Перечисли все секции со статусом SKIPPED и их влиянием на вердикт. Если пропущенных нет — раздел не включай.}

---

## → Handoff

```yaml
decisions:
  verdict: "{Go / Conditional Go / No-Go}"
  criticality_tier: "{0 / 1 / 2 / 3} — risk classification"
  runtime_constraints: "{подтверждённые constraints или unknown}"
  frozen_scope: "Cycle 2/3 delivery and operations tooling"

inherited_nfr:
  # NFR-требования из подтверждённых expectations — перенести в BA-NFR.md с числовыми порогами
  - "{/health endpoint (liveness) — если Tier ≥ 1}"
  - "{metrics contract — если требуется точным NFR}"
  - "{/ready endpoint — если подтверждённые runtime_constraints требуют нескольких instances}"
  - "{structured JSON logging с correlation_id — если Tier ≥ 1}"
  - "{recovery behavior — из точного NFR}"

architectural_constraints:
  # Runtime и observability constraints Cycle 1 — учесть в HLD/API spec
  - "runtime_constraints: {значение} — учесть при выборе application patterns"
  - "{добавить /health в API spec — если Tier ≥ 1}"
  - "{добавить /metrics в API spec — если Tier ≥ 2}"
  - "Cycle 2/3 tooling: FROZEN / NOT READY; не выбирать"

application_constraints:
  # Cycle 1 capabilities; delivery/operations tooling не выбирать
  - "criticality_tier: {N} — risk classification, не infrastructure preset"
  - "monitoring_stack: {с нуля / интеграция с {existing_monitoring}}"
  - "runbook: {обязателен если Tier ≥ 1}"
  - "postmortem_template: {обязателен если Q3.7 = D}"

open_issues:
  # Каждый [OPEN ISSUE] — владелец и статус
  - id: "OI-{N}"
    topic: "{тема}"
    owner: "{роль / стейкхолдер}"
    blocker_for: "{Gate N / этап}"
    status: "OPEN"

skipped_sections:
  # Секции пропущенные стейкхолдером — downstream агенты учитывают ограничения
  - section: "{название если SKIPPED}"
    impact: "{что нельзя утверждать без этой секции}"
```

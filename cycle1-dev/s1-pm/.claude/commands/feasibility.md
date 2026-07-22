---
description: Запустить полный или частичный Feasibility Study с поддержкой вето стейкхолдера
---

## Шаг 1 — Разбор аргументов

`$ARGUMENTS` может содержать: `[PROJECT] [флаги через пробел]`

Разбери:
- **PROJECT** = первый токен до пробела (или весь `$ARGUMENTS`, если пробелов нет)
- **skip:X** — пропустить секцию X до старта: `legal` / `finance` / `operational` / `technical`
- **budget:N** — переопределить бюджет из idea.md числом N
- **mode:auto** — без интерактивных чекпоинтов (пакетный режим)
- **scope:minimal** — только Executive Summary + Топ-5 рисков + ВЕРДИКТ

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

Выведи план с учётом флагов `skip:` и `scope:minimal`. Жди ответа пользователя.

```
📋 План: Feasibility Study — {PROJECT}
────────────────────────────────────────────
[1] Technical Feasibility        {✅ | ⚠️ SKIPPED (skip:technical)}
[2] Economic Feasibility         {✅ | ⚠️ SKIPPED (skip:finance)}
[3] Operational Feasibility      {✅ | ⚠️ SKIPPED (skip:operational)}
[4] Legal/Compliance Feasibility {✅ | ⚠️ SKIPPED (skip:legal)}
[5] Топ-5 рисков                 ✅ (всегда)
[6] ВЕРДИКТ                      ✅ (всегда)

  veto [1-4]  — исключить секцию
  edit [что]  — изменить предположение или параметр
  [Enter]     — начать
```

После ответа пользователя:
- Обнови список секций (добавь veto-метки)
- Если `edit [что]` — переспроси конкретный параметр, запомни новое значение
- Начинай работу только после явного подтверждения

---

## Шаг 4 — Создать артефакт

Файл: `$SDLC_PROJECTS_DIR/{PROJECT}/stage1-planning/outputs/PM-{ДАТА}-feasibility.md`

---

# Feasibility Study — {PROJECT}

```
Дата:   {ДАТА}
Агент:  s1-pm
Режим:  {full | minimal | partial — укажи пропущенные секции}
```

---

## Executive Summary

[3 предложения: проблема → решение → предварительный вердикт]

**Вердикт: Go / Conditional Go / No-Go**

{Если есть пропущенные секции → добавь: ⚠️ Вердикт частичный — не оценивались: [список]}

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

### Operational Tier — Рекомендуемый уровень надёжности

Прочитай из idea.md:
- `Deployment Constraint` (Q3.6): {значение}
- `Recovery Expectation` (Q3.7): {A/B/C/D}
- `Monitoring Expectation` (Q3.8): {A/B/C}
- `Delivery Scope` (Q3.9): {A/B/C}

Применяй матрицу из CLAUDE.md § "Operational Tier Selection". Определи тир и заполни:

**Рекомендуемый Operational Tier: {0 — Minimal / 1 — Basic / 2 — Standard / 3 — Full}**

Что это означает для вас на практике:
- ✅ {что пользователь получит — на бизнес-языке, без технических терминов}
- ❌ {чего НЕ будет — если тир неполный}

Overhead к бюджету: {+0% / +5-10% / +15-20% / +25-30% [ASSUMPTION]}

Delivery Scope: {что делает команда, что остаётся на стороне клиента}

{Если Q3.7 = C/D → обязательно включить:}
**Incident response в scope:**
- Отчёт о сбое: {да/нет}
- Postmortem-шаблон: {да/нет}
- Runbook: {да/нет}

> ⚠️ **Требует подтверждения стейкхолдера** — тир определяет объём работы и бюджет.
> Вынести на чекпоинт перед переходом к следующей секции.

### Вывод: ✅ / ⚠️ / ❌

---

{ЧЕКПОИНТ — если mode ≠ auto:}

```
✅ Technical Feasibility — готово
   {1-2 предложения: ключевой вывод}
   Operational Tier: {N — название} — {что это значит на практике, 1 предложение}

   Подтвердить Tier {N}? [Enter = да]  |  veto tier — выбрать другой тир  |  edit [что] — изменить  |  stop
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
  [Enter] продолжить  |  veto  |  edit [что]  |  stop
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
  [Enter] продолжить  |  veto  |  edit [что]  |  stop
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
  operational_tier: "{0 / 1 / 2 / 3} — {название}"
  deployment_topology: "{single-container / single-host docker-compose / multi-instance / serverless}"
  delivery_scope: "{code-only / code+docker / code+deploy+monitoring}"
  alert_channel: "{Telegram / Email / Slack / [OPEN ISSUE OI-?]}"
  existing_monitoring: "{none / external:{сервис} / self-hosted / unknown}"

inherited_nfr:
  # NFR-требования, вытекающие из Operational Tier — перенести в BA-NFR.md с числовыми порогами
  - "{/health endpoint (liveness) — если Tier ≥ 1}"
  - "{/metrics endpoint Prometheus — если Tier ≥ 2}"
  - "{/ready endpoint — если topology = multi-instance}"
  - "{structured JSON logging с correlation_id — если Tier ≥ 1}"
  - "{alert_channel настроен — если Q3.7 ≠ A}"

architectural_constraints:
  # Ограничения деплоя и наблюдаемости — учесть при проектировании HLD и API spec
  - "deployment_topology: {значение} — учесть при выборе паттернов"
  - "{добавить /health в API spec — если Tier ≥ 1}"
  - "{добавить /metrics в API spec — если Tier ≥ 2}"
  - "{сервисов в docker-compose: N — app + prometheus + grafana если Tier 2}"

infrastructure_constraints:
  # Инфраструктурные требования — реализовать согласно Operational Tier
  - "operational_tier: {N} — реализовать полный стек тира"
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

---
description: Сформировать Product Vision, North Star Metric и OKR с поддержкой вето стейкхолдера
---

## Шаг 1 — Разбор аргументов

`$ARGUMENTS` может содержать: `[PROJECT] [флаги]`

Флаги:
- `skip:okr` — пропустить блок OKR
- `skip:roadmap` — пропустить High-level Roadmap
- `skip:stakeholders` — пропустить Stakeholder Map
- `mode:auto` — без интерактивных чекпоинтов

Если PROJECT не указан → спроси: «Для какого проекта формируем Vision?»

---

## Шаг 2 — Чтение входных данных

Прочитай:
1. `$SDLC_VAULT/_agents/_standards/company.md`
2. Все файлы из `$SDLC_VAULT/projects/$ARGUMENTS/stage1-planning/inputs/`
3. `$SDLC_VAULT/projects/$ARGUMENTS/stage1-planning/outputs/PM-*-feasibility.md` (если существует)

Из `idea.md` извлеки и запомни:
- `## Проблема` (Q1.2) → формулировка проблемы для Vision
- `## As-Is` (Q1.3) → текущее состояние пользователя
- `## To-Be` (Q1.4) → целевое состояние — основа для Vision Statement
- `## Бизнес-идея` (Q1.5) → описание продукта
- `## Целевая аудитория` (Q1.6) → target customer
- `## Уникальность` (Q1.8) → differentiator vs конкурентов
- `## Критерии успеха продукта` (Q4.1) → **North Star Metric — брать напрямую**
- `## Kill Criteria` (Q4.2) → нижняя граница успеха

---

## Шаг 3 — Презентация плана (если mode ≠ auto)

```
📋 План: Product Vision & OKR — {PROJECT}
──────────────────────────────────────────
[1] Product Vision Statement      ✅
[2] North Star Metric             ✅
[3] OKR (3 objective × 3 KR)    {✅ | ⚠️ SKIPPED (skip:okr)}
[4] High-level Roadmap (4Q)      {✅ | ⚠️ SKIPPED (skip:roadmap)}
[5] Stakeholder Map              {✅ | ⚠️ SKIPPED (skip:stakeholders)}

  veto [1-5]  — исключить блок
  edit [что]  — изменить параметр
  [Enter]     — начать
```

Жди ответа. Обработай veto/edit перед продолжением.

---

## Шаг 4 — Создать артефакт

Файл: `$SDLC_VAULT/projects/$ARGUMENTS/stage1-planning/outputs/PM-{ДАТА}-vision-okr.md`

---

# Product Vision & OKR — {PROJECT}

```
Дата:   {ДАТА}
Агент:  s1-pm
```

---

## Product Vision

Формат (Moore's positioning statement):
> For **{целевая аудитория из Q1.6}** who **{проблема из Q1.2 / As-Is из Q1.3}**,
> **{название продукта}** is a **{категория}** that **{ключевое To-Be из Q1.4}**.
> Unlike **{конкуренты из Q1.7}**, our product **{уникальность из Q1.8}**.

{Источник всех данных: `[DATA — stakeholder interview]`}

---

{ЧЕКПОИНТ — если mode ≠ auto:}

```
✅ Product Vision — готово
   "{первое предложение Vision Statement}"

▶ Следующее: North Star Metric
  [Enter] продолжить  |  veto — пропустить  |  edit [что] — изменить формулировку  |  stop
```

---

## North Star Metric

{Читай `## Критерии успеха продукта` из idea.md (Q4.1).
Используй напрямую — не генерируй свою метрику.
Если поле пустое или "не определено" → пометь [ASSUMPTION] и предложи вариант.}

**Метрика:** {из Q4.1 [DATA — stakeholder interview] / [ASSUMPTION]}
**Текущее значение:** {As-Is из Q1.3 — если применимо}
**Цель через 12 месяцев:** {из Q4.1 или [ASSUMPTION]}

**Kill Criteria (нижняя граница):** {из Q4.2 [DATA — stakeholder interview]}
> Если метрика опускается ниже kill criteria → проект закрывается.

---

{ЧЕКПОИНТ}

```
✅ North Star Metric — готово
   Метрика: {название} → цель: {значение за 12 мес}

▶ Следующее: OKR
  [Enter] продолжить  |  veto — пропустить  |  edit [что]  |  stop
```

---

## OKR — Q{N} {год}

{Если SKIPPED:}
> [SKIPPED — по решению стейкхолдера]

{Если выполняется:}

OKR должны быть направлены на достижение North Star Metric.
Kill Criteria из Q4.2 учесть как нижнюю границу KR.

### O1: {Objective — амбициозная формулировка}
- KR1.1: {измеримый результат — число + дата}
- KR1.2: {измеримый результат}
- KR1.3: {измеримый результат}

### O2: {Objective}
- KR2.1:
- KR2.2:
- KR2.3:

### O3: {Objective}
- KR3.1:
- KR3.2:
- KR3.3:

---

{ЧЕКПОИНТ}

```
✅ OKR — готово
   O1: {первый objective кратко}

▶ Следующее: High-level Roadmap
  [Enter] продолжить  |  veto  |  edit [что]  |  stop
```

---

## High-level Roadmap

{Если SKIPPED:}
> [SKIPPED — по решению стейкхолдера]

{Если выполняется:}

| Квартал | Тема | Ключевые deliverables | Зависимости |
|---------|------|----------------------|-------------|
| Q1 | | | |
| Q2 | | | |
| Q3 | | | |
| Q4 | | | |

MVP (из Q4.5 idea.md): {что входит в первый релиз [DATA — stakeholder interview]}
Scope Out: {что не делаем в MVP из Q4.4 [DATA — stakeholder interview]}

---

{ЧЕКПОИНТ}

```
✅ Roadmap — готово

▶ Следующее: Stakeholder Map
  [Enter] продолжить  |  veto  |  edit [что]  |  stop
```

---

## Stakeholder Map

{Если SKIPPED:}
> [SKIPPED — по решению стейкхолдера]

{Если выполняется:}
{Источник: Q4.3 из idea.md [DATA — stakeholder interview]. Дополни анализом если нужно.}

| Имя / Роль | Влияние | Интерес | Позиция | Стратегия взаимодействия |
|-----------|---------|---------|---------|--------------------------|
| {из Q4.3} | | | | |

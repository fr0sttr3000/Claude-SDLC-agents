# Tech Debt Log — {PROJECT}

> Журнал отложенных улучшений, рисков сопровождаемости и известных ограничений.
> Файл создаётся s0-tracker при инициализации проекта.
> Незакрытый tech debt без плана устранения блокирует следующий спринт.
> Запись tech debt не меняет FAIL применимого DoD на PASS и не является waiver.

---

## Правила записи

- Tech debt фиксируется для отложенного улучшения, подтверждённого ограничения или риска
- Каждая запись должна иметь: источник, влияние, owner, план устранения и дедлайн
- Каждая запись фиксирует source sprint и target sprint; точный SLA задаётся типом/severity:
  S3, Security Medium и любой active Risk Exception — следующий sprint; S4 и Security Low —
  не позже третьего sprint после source. Принятие Known Issue не отменяет этот SLA
- Невыполненный применимый DoD остаётся FAIL/BLOCKED до устранения; исключений нет
- Без плана устранения и дедлайна запись не принимается
- Записи со статусом OPEN блокируют `/sprint-close` если дедлайн устранения прошёл

---

## Формат записи

```
### TD-[N] — [краткое название]
- Дата: YYYY-MM-DD
- Агент: {агент-исполнитель}
- Источник: {review / incident / retrospective / применимый DoD-{N}}
- Тип артефакта: Код / Документ / Инфраструктура
- Влияние и риск: {конкретное наблюдаемое последствие}
- Owner: {роль / стейкхолдер}
- План устранения: {что конкретно сделать}
- Source sprint: N
- Target sprint: NEXT | {exact positive sprint number}
- Дедлайн устранения: PENDING | YYYY-MM-DD (после `/sprint-init` — не позже end target sprint)
- Exception type: none | security | performance | quality | reliability | accessibility | compatibility | safety
- Finding severity: NONE | S3 | S4 | SECURITY_LOW | SECURITY_MEDIUM | PERFORMANCE_THRESHOLD | QUALITY_THRESHOLD | RELIABILITY_THRESHOLD | ACCESSIBILITY_GAP | COMPATIBILITY_GAP | SAFETY_GAP
- Finding IDs: N/A | FINDING-1,FINDING-2
- CVSS: N/A | 0.1–10.0
- Risk exception: none | RISK-[ID]
- Статус: OPEN | IN_PROGRESS | RESOLVED
- Дата закрытия: YYYY-MM-DD
```

---

## Журнал

<!-- Записи добавляются снизу вверх (новые первыми) -->

`NEXT` разрешён только до `/sprint-init`. Команда материализует его в точный номер.
Допустимый диапазон проверяет validator: следующий sprint для S3/Security Medium/active Risk
Exception; не позже третьего sprint после source для S4/Security Low.

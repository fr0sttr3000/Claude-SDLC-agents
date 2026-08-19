---
description: Создать Business Case (NPV, ROI, TCO, сценарный анализ)
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай Business Case для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/inputs/idea.md
3. Current logical id `feasibility-study` по root Current Artifacts rule

Создай файл FIN-[дата]-business-case.md в:
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/outputs/

Обязательные unique machine fields:
`feasibility_sha256: {SHA-256 current feasibility}`,
`finance_status: PASS|CONDITIONAL|FAIL`, `base_npv: {number}`,
`base_roi_percent: {number}`, `base_payback_months: {number}`.
Нельзя ставить PASS при отсутствующем расчёте любой из трёх base-метрик.

# Business Case — $ARGUMENTS
Дата: [сегодня]
Агент: s1-finance

## Executive Summary
[3 предложения: размер инвестиции, ожидаемый возврат, рекомендация]

## 1. Investment Overview
| Категория | Год 1 | Год 2 | Год 3 | Тип |
|-----------|-------|-------|-------|-----|
| Development | | | | [DATA/ASSUMPTION] |
| Infrastructure | | | | [DATA/ASSUMPTION] |
| Operations | | | | [DATA/ASSUMPTION] |
| Support | | | | [DATA/ASSUMPTION] |
| **TCO итого** | | | | |

## 2. Financial Projections — 3 сценария
| Метрика | Pessimistic | Base | Optimistic |
|---------|-------------|------|------------|
| NPV | | | |
| IRR | | | |
| ROI | | | |
| Payback Period | | | |

Формулы (обязательно показать расчёт):
- NPV = Σ CFt / (1+r)^t, r = [ставка дисконтирования, %]
- ROI = (Net Benefit / Total Cost) × 100%
- Payback = Total Investment / Annual Net Benefit

## 3. Cash Flow по годам
| | Год 0 | Год 1 | Год 2 | Год 3 |
|-|-------|-------|-------|-------|
| Costs | | | | |
| Benefits | | | | |
| Net CF | | | | |
| Cumulative CF | | | | |

## 4. Sensitivity Analysis
| Параметр | −20% | Base | +20% | Влияние на NPV |
|----------|------|------|------|----------------|
| Стоимость разработки | | | | |
| Ожидаемый доход | | | | |
| Срок выхода на рынок | | | | |

## 5. Budget Breakdown по фазам
| Фаза | Бюджет | Длительность | Роли |
|------|--------|--------------|------|

## Assumptions & Data Sources
Каждое [ASSUMPTION] — с обоснованием.
Каждое [DATA] — с источником.

## Вердикт
**Рекомендация:** [Инвестировать / Условно инвестировать / Не инвестировать]
Обоснование: ...

→ Передать s1-pm: FIN-[дата]-business-case.md — для финального Go/No-Go.

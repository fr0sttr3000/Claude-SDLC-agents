---
description: Вынести Go/No-Go решение для релиза (Gate 5 — блокирует s6-release)
---

Вынеси Go/No-Go решение для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/projects/$ARGUMENTS/stage5-testing/outputs/ (все файлы)
3. $SDLC_VAULT/projects/$ARGUMENTS/stage4-dev/outputs/TL-*-review-PR*.md (все)

Создай файл QA-[дата]-go-no-go.md в:
$SDLC_VAULT/projects/$ARGUMENTS/stage5-testing/outputs/

# Go/No-Go — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa

## Gate 5 Checklist

□ Gate 4 подтверждён: все TL-*-review-PR*.md с approve существуют
□ Functional Suitability: каждый Must-FR из BA-BRD.md покрыт ≥1 приёмочным тест-кейсом с PASS (трассировка по BA-RTM.md, 0 непокрытых Must-FR)
□ Pass Rate ≥ 98% (от общего числа TC, не только запущенных)
□ 0 открытых S1 (Critical) багов
□ 0 открытых S2 (High) багов
□ UAT sign-off получен в реальной системе (не эмулятор)
□ PERF-report.md существует с вердиктом PASS или CONDITIONAL PASS
□ SEC-*-pentest-report.md существует с вердиктом PASS (SG4) — 0 открытых Critical/High по CVSS
□ AUTO-*-coverage.md существует, automation coverage ≥ 95%
□ Регрессионный прогон пройден (все Sprint N-1 тест-кейсы)
□ Known Issues: каждый НЕ-блокирующий дефект, идущий в релиз (S3/S4 с user-facing impact),
  промотирован в tracking/known-issues.md (Workaround + Detection signal + → tech-debt) — иначе это
  «проигнорированный», а не «известный» дефект → No-Go (quality.md §6.1)

## Метрики тестирования
| Показатель | Значение | Порог | Статус |
|-----------|---------|-------|--------|
| Pass Rate | | ≥ 98% | |
| S1 открытых | | 0 | |
| S2 открытых | | 0 | |
| Automation coverage | | ≥ 95% | |
| PERF вердикт | | PASS | |
| UAT sign-off | | Да | |
| Дефектов найдено до прода | | — | для DRE (§7.3) |
| Defect Density (деф./KLOC или /SP) | | тренд ↓ | для s0-tracker /report |

## Открытые дефекты (если есть)
| ID | Severity | Описание | Статус | KI-id (если промотирован) |
|----|---------|---------|--------|---------------------------|

> Каждый S3/S4 с user-facing impact, остающийся в релизе → создать запись в
> tracking/known-issues.md (KI-NN) из шаблона known-issues-template.md и связать с tech-debt.

## GO условия
GO = 0 S1 + 0 S2 + Pass Rate ≥ 98% + Functional Suitability (Must-FR ↔ RTM) +
     UAT sign-off (реальная система) + все S3/S4-дефекты релиза промотированы в known-issues

## ВЕРДИКТ
✅ **GATE 5 PASSED** — s6-release может начинать
❌ **GATE 5 FAILED** — [список блокеров, s6-release не начинает]

Без GATE 5 PASSED — s6-release не начинает работу. Никаких исключений.

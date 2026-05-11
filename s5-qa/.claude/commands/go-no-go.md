---
description: Вынести Go/No-Go решение для релиза (Gate 5 — блокирует s6-release)
---

Вынеси Go/No-Go решение для проекта $ARGUMENTS.

Прочитай:
1. /home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/_standards/quality.md
2. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage5-testing/outputs/ (все файлы)
3. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage4-dev/outputs/TL-*-review-PR*.md (все)

Создай файл QA-[дата]-go-no-go.md в:
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage5-testing/outputs/

# Go/No-Go — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa

## Gate 5 Checklist

□ Gate 4 подтверждён: все TL-*-review-PR*.md с approve существуют
□ Pass Rate ≥ 98% (от общего числа TC, не только запущенных)
□ 0 открытых S1 (Critical) багов
□ 0 открытых S2 (High) багов
□ UAT sign-off получен в живой системе (не эмулятор)
□ PERF-report.md существует с вердиктом PASS или CONDITIONAL PASS
□ AUTO-*-coverage.md существует, automation coverage ≥ 95%
□ Регрессионный прогон пройден (все Sprint N-1 тест-кейсы)

## Метрики тестирования
| Показатель | Значение | Порог | Статус |
|-----------|---------|-------|--------|
| Pass Rate | | ≥ 98% | |
| S1 открытых | | 0 | |
| S2 открытых | | 0 | |
| Automation coverage | | ≥ 95% | |
| PERF вердикт | | PASS | |
| UAT sign-off | | Да | |

## Открытые дефекты (если есть)
| ID | Severity | Описание | Статус |
|----|---------|---------|--------|

## GO условия
GO = 0 S1 + 0 S2 + Pass Rate ≥ 98% + UAT sign-off (живая система)

## ВЕРДИКТ
✅ **GATE 5 PASSED** — s6-release может начинать
❌ **GATE 5 FAILED** — [список блокеров, s6-release не начинает]

Без GATE 5 PASSED — s6-release не начинает работу. Никаких исключений.

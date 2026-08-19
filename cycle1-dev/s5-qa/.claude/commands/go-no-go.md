---
description: Вынести Go/No-Go verdict завершения Cycle 1 (Gate 5)
---

Вынеси Go/No-Go решение для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/artifact-metadata.md
3. $SDLC_VAULT/_agents/_standards/data-formats.md
4. $SDLC_VAULT/_agents/_contract/S5_VALIDATION_V1.md
5. $SDLC_VAULT/_agents/_contract/RISK_EXCEPTION_V3.md
6. $SDLC_VAULT/_agents/_contract/HUMAN_APPROVAL_V1.md
7. Current `product-ci-profile`, `s5-validation-index`, `techlead-reviews`, `uat-criteria`,
   `product-acceptance-index`, all four owner S5 reports and `s5-exploratory-report` по root
   Current Artifacts rule
8. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/evidence/v1/ (build record exact source)

Проведи ограниченную exploratory session и фасилитируй UAT уполномоченного представителя.
Не создавай approvals от имени человека. Авторизация среды и UAT acceptance — разные
Human Approval v1 records. Добавь/замени только свои строки `exploratory` и `uat` в общем
индексе, сохранив строки automation/performance/security byte-for-byte.

Создай в `$SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/`:
- `QA-[дата]-exploratory-report.md` с charter/duration/observations/findings;
- `DEF-[дата]-defects.md` и единственный `DEF-defects-v1.tsv` со всеми findings пяти streams;
- `QA-[дата]-test-analysis.md` с Failure Analysis, Flaky Tests, Coverage Gaps, Quality Trend;
- `QA-[дата]-go-no-go.md`.

Создай `tracking/validation/raw/uat-results.tsv` для каждого исходного S2 UAT id. До GO
запусти `s5-validation-check.sh <PROJECT_PATH> <EXACT_SOURCE_REVISION>`. При BLOCKED запиши
No-Go и конкретный owner/remediation; не исправляй evidence другой роли.

Все governance Markdown artifacts получают общий Artifact Metadata v1 с Obsidian links и
S5 domain fields. Go/No-Go дополнительно содержит Product Profile revision, SHA-256
validation/defect indexes, UAT approval ref и `verdict: GO|NO_GO`. Печатная фраза без этих
связей не является решением Gate 5.

# Go/No-Go — $ARGUMENTS
Дата: [сегодня]
Агент: s5-qa

## Gate 5 Checklist

□ Gate 4 подтверждён: все TL-*-review-PR*.md с approve существуют
□ Functional Suitability: каждый Must-FR из BA-BRD.md покрыт ≥1 приёмочным тест-кейсом с PASS (трассировка по BA-RTM.md, 0 непокрытых Must-FR)
□ Pass Rate соответствует effective quality policy и считается от полного expected count
□ 0 открытых S1 (Critical) багов
□ 0 открытых S2 (High) багов
□ UAT sign-off получен по каждому исходному `UAT-*` scenario в согласованной
  репрезентативной среде и связан с теми же Must-FR/risk/UX ids
□ PERF-report.md существует с вердиктом PASS или CONDITIONAL PASS
□ SEC-*-pentest-report.md существует с PASS или verified CONDITIONAL PASS; 0 открытых
  Critical/High, каждый Medium/Low имеет exact lifecycle refs
□ AUTO-*-coverage.md существует; exact UAT path set, required UXC/A11Y results и
  effective-policy test-pass/automation metrics подтверждены
□ Регрессия `full-affected`: expected = executed, 0 failed/skipped, все affected tests и
  critical paths exact build покрыты
□ Known Issues: каждый НЕ-блокирующий дефект, идущий в релиз (S3/S4 или Security Medium/Low
  с user-facing impact),
  имеет complete OPEN запись в tracking/known-issues.md, exact Tech Debt/Patch SLA и отдельный
  Human Approval v1, связанный с source revision, KI ID и digest дефекта. Security Medium также
  имеет отдельный Risk Exception v3. Любое отсутствующее или несовпадающее evidence → No-Go

## Метрики тестирования
| Показатель | Значение | Порог | Статус |
|-----------|---------|-------|--------|
| Pass Rate | | effective policy | |
| S1 открытых | | 0 | |
| S2 открытых | | 0 | |
| Automation coverage | | effective `e2e_automation_percent` | |
| PERF вердикт | | PASS | |
| UAT sign-off | | Да | |
| Дефектов найдено до прода | | — | для DRE (§7.3) |
| Defect Density (деф./KLOC или /SP) | | тренд ↓ | для s0-tracker /report |

## Открытые дефекты (если есть)
| ID | Severity | Описание | Статус | KI-id | Human Approval v1 |
|----|----------|----------|--------|-------|-------------------|

> Каждый S3/S4 с user-facing impact, остающийся в релизе → создать запись в
> tracking/known-issues.md (KI-NN) из шаблона known-issues-template.md, связать с Tech Debt и
> запросить отдельный Human Approval v1 у пользователя/уполномоченного владельца продукта.
> Агент не создаёт и не имитирует этот approval.

## GO условия
GO = 0 S1 + 0 S2 + effective-policy Pass Rate + Functional Suitability (Must-FR ↔ RTM) +
     UAT sign-off (реальная система) + каждый допустимый Known Issue имеет полную запись,
     Tech Debt/Patch SLA и отдельный проверенный Human Approval v1 на принятие Known Issue

## ВЕРДИКТ
✅ **GATE 5 PASSED** — Cycle 1 validation завершена
❌ **GATE 5 FAILED** — [список блокеров Cycle 1]

Gate 5 не разрешает deploy и не запускает Cycle 2/3. Без PASS Cycle 1 не validated.

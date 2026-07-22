---
description: Сгенерировать Release Notes для версии
---

Создай Release Notes для проекта $ARGUMENTS.

До чтения artifacts запроси и зафиксируй точную release version X.Y.Z.
Не выводи версию из даты, предыдущего файла или предположения; без версии BLOCKED.

Прочитай:
$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/SDLC-goals.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/quality-gates.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/DEPLOY-TDD-status.md ← нужен PASS
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/DEVOPS-*-deploy-test-report.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/          ← все DEV-*-update-notes-PR*.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/ ← PO-backlog.md (для сопоставления с User Stories)
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/QA-go-no-go.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/known-issues.md            ← OPEN-записи для секции «Известные проблемы»

Release Notes создаются раньше checklist и отражают только фактические
deliverables актуальной goal_profile_revision.

Создай: $SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md

Формат Release Notes:
```
# Release Notes — v[X.Y.Z] — YYYY-MM-DD

## Обзор
Краткое описание релиза (2-3 предложения для нетехнической аудитории).

## Новые возможности
- Описание фичи (связь с User Story #N)

## Изменения
- Что изменилось в поведении / API / конфигурации

## Исправления
- Описание исправленной проблемы

## Критические изменения (Breaking Changes)
- Что сломается при обновлении без дополнительных действий
- Инструкции по миграции

## Требуемые действия при обновлении
□ Миграции БД: [да/нет, команда]
□ Новые env-переменные: [список]
□ Изменения конфигурации: [описание]
□ Необходимые рестарты сервисов: [список]

## Технические детали
Ссылки на PR, ADR, обновлённую документацию.

## Известные проблемы
Из tracking/known-issues.md — все записи Status=OPEN, идущие в этот релиз.
Для каждой: краткое описание + Impact + Workaround (детали диагностики — в SRE-runbook-KI-*).
Если незакрытых known issues нет — указать «нет».
```

> Источник секции «Известные проблемы» — `tracking/known-issues.md` (не выдумывать вручную).
> Каждый S3/S4-дефект, ушедший в прод, обязан быть там (иначе Gate 5 был бы No-Go, quality.md §6.1).

После создания файла — обнови Dashboard.md проекта: отметь документацию и release notes как завершённые.
Корневой CHANGELOG.md обновляется в этой же явно запущенной release preparation; исторические
release notes не переписывай. Не включай feature/fix без traceable evidence и не выводи secrets.

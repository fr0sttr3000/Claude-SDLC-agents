---
description: Сгенерировать Release Notes для версии
---

Создай Release Notes для проекта $ARGUMENTS.

Прочитай:
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage4-dev/outputs/          ← все DEV-*-update-notes-PR*.md
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage2-requirements/outputs/ ← PO-backlog.md (для сопоставления с User Stories)
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage5-testing/outputs/QA-go-no-go.md
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage6-deploy/outputs/REL-checklist.md

Создай: /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage6-deploy/outputs/REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md

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
Если есть незакрытые баги в этом релизе — перечислить с workaround.
```

После создания файла — обнови Dashboard.md проекта: отметь документацию и release notes как завершённые.

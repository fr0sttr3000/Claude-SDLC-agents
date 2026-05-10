---
description: Создать Release Checklist
---

Создай Release Checklist для проекта $ARGUMENTS.

Прочитай:
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage5-testing/outputs/
/home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage4-dev/outputs/DEVOPS-runbook.md

Создай: /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage6-deploy/outputs/REL-checklist.md

Разделы: Версия / Что меняется / Go-No-Go Gate / Pre-Deployment / Deployment Steps / Smoke Tests / Rollback Criteria / Rollback Steps / Communication / Post-Release Actions

## Обязательные проверки документации (блокируют релиз)
□ CHANGELOG.md обновлён (версия закрыта, дата проставлена)
□ Release Notes созданы: REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md
□ API-spec актуален (если менялись эндпоинты)
□ README отражает текущее состояние (установка, конфигурация, env)
□ Все DEV-*-update-notes-PR[N].md присутствуют в stage4-dev/outputs/ (по числу PR в релизе)
□ Runbook обновлён под новую версию

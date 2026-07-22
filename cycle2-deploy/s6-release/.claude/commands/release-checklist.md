---
description: Создать Release Checklist
---

Создай Release Checklist для проекта $ARGUMENTS.

До проверки запроси точную release version X.Y.Z и используй ту же версию, что
в release notes. Не угадывай версию; отсутствие exact version = BLOCKED.

Прочитай:
$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/SDLC-goals.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/quality-gates.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/DEPLOY-TDD-status.md ← нужен PASS
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/DEVOPS-*-deploy-test-report.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/REL-*-release-notes-v*.md
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage5-testing/outputs/
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/DEVOPS-*-runbook.md
  ← только если goal выбирает operations-pack/execute-deploy/runtime scope

Создай: $SDLC_PROJECTS_DIR/$ARGUMENTS/stage6-deploy/outputs/REL-YYYY-MM-DD-checklist-v[X.Y.Z].md

Gate 6 блокируется при несовпадении goal_profile_revision, status не PASS или
если фактические deliverables отличаются от tracking/SDLC-goals.md.

Разделы: Версия / Что меняется / Go-No-Go Gate / Pre-Deployment / Deployment Steps / Smoke Tests / Rollback Criteria / Rollback Steps / Communication / Post-Release Actions

## Обязательные проверки документации (блокируют релиз)
□ Корневой $SDLC_PROJECTS_DIR/$ARGUMENTS/CHANGELOG.md обновлён (версия закрыта, дата проставлена)
□ Release Notes созданы: REL-YYYY-MM-DD-release-notes-v[X.Y.Z].md
□ API-spec актуален (если менялись эндпоинты)
□ README отражает текущее состояние (установка, конфигурация, env)
□ Все DEV-*-update-notes-PR[N].md присутствуют в stage4-dev/outputs/ (по числу PR в релизе)
□ Runbook обновлён под новую версию, если применим; images-only содержит version fallback

Применяй exact thresholds из `tracking/quality-gates.md`, иначе global minimum.
Любой N/A содержит applicability evidence. Не выполняй deploy этой командой.

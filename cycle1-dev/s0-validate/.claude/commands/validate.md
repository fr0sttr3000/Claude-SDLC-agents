---
description: Проверить структуру SDLC-проекта (без изменений)
---

Проверь структуру SDLC-проекта $ARGUMENTS.

Если $ARGUMENTS равен "all" — проверь все проекты в:
$SDLC_VAULT/projects/
(пропускай папки и файлы начинающиеся с _)

Для каждого проекта выполни проверку по полному списку из CLAUDE.md:
- Dashboard.md
- stage1-planning/inputs/ и outputs/
- stage2-requirements/inputs/ и outputs/
- stage3-design/inputs/ и outputs/
- stage4-dev/inputs/ и outputs/
- stage5-testing/inputs/ и outputs/
- stage6-deploy/inputs/ и outputs/
- stage7-ops/inputs/ и outputs/
- stage1-planning/inputs/idea.md

Выведи отчёт в формате из CLAUDE.md.
НЕ создавай и НЕ изменяй никаких файлов — только отчёт.

В конце выведи общий итог: сколько проектов проверено, сколько имеют проблемы.

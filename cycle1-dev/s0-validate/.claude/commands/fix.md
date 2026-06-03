---
description: Исправить структуру SDLC-проекта (создать недостающие директории и файлы)
---

Исправь структуру SDLC-проекта $ARGUMENTS.

Если $ARGUMENTS равен "all" — исправь все проекты в:
$SDLC_VAULT/projects/
(пропускай папки и файлы начинающиеся с _)

Для каждого проекта:

1. Сначала выполни проверку (как /validate) и выведи текущее состояние.

2. Создай недостающие директории через Bash:
   mkdir -p stage1-planning/inputs stage1-planning/outputs
   mkdir -p stage2-requirements/inputs stage2-requirements/outputs
   mkdir -p stage3-design/inputs stage3-design/outputs
   mkdir -p stage4-dev/inputs stage4-dev/outputs
   mkdir -p stage5-testing/inputs stage5-testing/outputs
   mkdir -p stage6-deploy/inputs stage6-deploy/outputs
   mkdir -p stage7-ops/inputs stage7-ops/outputs

3. Если stage1-planning/inputs/idea.md НЕ существует — создай заглушку по шаблону из CLAUDE.md.

4. Если Dashboard.md НЕ существует — создай заглушку по шаблону из CLAUDE.md.

5. Выведи отчёт об исправлениях в формате из CLAUDE.md.

ВАЖНО:
- Никогда не удаляй и не перезаписывай существующие файлы
- Создавай только то, чего не хватает
- Выводи каждое действие по мере выполнения

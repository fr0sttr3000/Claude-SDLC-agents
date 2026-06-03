---
description: Создать Pull Request для завершённого этапа SDLC
---

Создай Pull Request для проекта $ARGUMENTS.
Формат аргумента: "project-name stage2" (проект и этап).

Определи из аргумента: название проекта и номер этапа.

Этапы и ветки:
- stage1 → stage/planning    → "Планирование завершено"
- stage2 → stage/requirements → "Требования готовы"
- stage3 → stage/design      → "Дизайн готов"
- stage4 → stage/development → "Разработка завершена"
- stage5 → stage/testing     → "Тестирование пройдено"
- stage6 → stage/deploy      → "Деплой выполнен"

Шаги:
1. Перейди в папку проекта:
   $SDLC_VAULT/projects/[project]

2. Переключись на ветку этапа:
   `git checkout stage/[stage-name]`

3. Смержи изменения из main:
   `git merge main`

4. Push ветки:
   `git push origin stage/[stage-name]`

5. Создай PR через gh:
   `gh pr create --base main --head stage/[stage-name] --title "[STAGE] [Заголовок]" --body "[описание артефактов этапа]"`

6. Покажи URL созданного PR

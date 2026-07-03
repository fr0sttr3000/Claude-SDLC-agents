---
description: Push всех SDLC-артефактов в ветку GitHub
---

Сделай push всех SDLC-артефактов проекта $ARGUMENTS в GitHub.

Шаги:
1. Перейди в папку проекта:
   $SDLC_PROJECTS_DIR/$ARGUMENTS

2. Проверь статус репозитория: `git status`
   Если .git не существует — сообщи что нужно сначала запустить /init и останови выполнение.

3. Проверь секреты перед коммитом (правило из CLAUDE.md — обязательно).

4. Определи имя ветки для текущего цикла:
   BRANCH="sdlc/cycle-$(date +%Y-%m-%d)"
   Если такая ветка уже существует — добавь суффикс -2, -3 и т.д.

5. Создай и переключись на ветку:
   `git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"`

6. Добавь все изменения: `git add .`

7. Покажи список изменённых файлов и их количество.
   Если изменений нет — сообщи об этом и останови выполнение (это нормально).

8. Создай коммит:
   `git commit -m "[SYNC] cycle: SDLC artifacts for $ARGUMENTS $(date +%Y-%m-%d)"`

9. Push ветки на GitHub:
   `git push origin "$BRANCH" --set-upstream`
   При ошибке аутентификации или remote — объясни причину.

10. В конце выведи итог:
    - Имя ветки: $BRANCH
    - URL репозитория: `git remote get-url origin`
    - Количество файлов в коммите
    - `git log --oneline -3`

---
description: Показать статус синхронизации проекта с GitHub
---

Покажи статус синхронизации проекта $ARGUMENTS.

Выполни и отобрази:

1. Git статус:
   `git -C "$SDLC_PROJECTS_DIR/$ARGUMENTS" status`

2. Последние коммиты:
   `git -C "$SDLC_PROJECTS_DIR/$ARGUMENTS" log --oneline -10`

3. Расхождение с remote:
   `git -C "$SDLC_PROJECTS_DIR/$ARGUMENTS" status -sb`

4. Список веток:
   `git -C "$SDLC_PROJECTS_DIR/$ARGUMENTS" branch -a`

5. URL репозитория:
   `git -C "$SDLC_PROJECTS_DIR/$ARGUMENTS" remote -v`

Отформатируй вывод как сводку:
## Статус проекта: $ARGUMENTS
- Remote: [URL]
- Ветка: [текущая]
- Незакоммиченных файлов: [N]
- Коммитов впереди remote: [N]
- Последний коммит: [дата и сообщение]

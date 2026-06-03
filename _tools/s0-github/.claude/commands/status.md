---
description: Показать статус синхронизации проекта с GitHub
---

Покажи статус синхронизации проекта $ARGUMENTS.

Выполни и отобрази:

1. Git статус:
   `git -C "$SDLC_VAULT/projects/$ARGUMENTS" status`

2. Последние коммиты:
   `git -C "$SDLC_VAULT/projects/$ARGUMENTS" log --oneline -10`

3. Расхождение с remote:
   `git -C "$SDLC_VAULT/projects/$ARGUMENTS" status -sb`

4. Список веток:
   `git -C "$SDLC_VAULT/projects/$ARGUMENTS" branch -a`

5. URL репозитория:
   `git -C "$SDLC_VAULT/projects/$ARGUMENTS" remote -v`

Отформатируй вывод как сводку:
## Статус проекта: $ARGUMENTS
- Remote: [URL]
- Ветка: [текущая]
- Незакоммиченных файлов: [N]
- Коммитов впереди remote: [N]
- Последний коммит: [дата и сообщение]

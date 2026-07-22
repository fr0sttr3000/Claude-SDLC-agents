---
description: Заблокировать exact task с причиной и сохранить согласованный scope
---

Аргументы: `$ARGUMENTS` = Project, exact task ID и причина blocker. Если task ID или причина
не указаны — спроси, не угадывай.

Прочитай `tracking/backlog.md`, `current-sprint.md` и exact active sprint file. Найди ровно одну
задачу с этим ID. Покажи старый/new status и files-to-change, затем:

- поставь `Статус: BLOCKED`;
- запиши конкретный blocker, owner/next action, если они известны;
- синхронизируй backlog, sprint и current board без изменения SP/scope/dependencies;
- не создавай дубликат и не переносись между sprints автоматически.

Если ID отсутствует/неоднозначен или blocker требует product decision — BLOCKED без записи.
В конце покажи актуальную task board.

---
description: Отметить задачу как выполненную
---

Отметь задачу как выполненную в проекте $ARGUMENTS.

Аргументы могут быть в формате: "PROJECT T-NNN" или просто "PROJECT"
(если T-NNN не указан — спроси пользователя какую задачу отмечать).

Шаги:
1. Если ID задачи не указан — покажи список задач IN_PROGRESS и TODO из текущего спринта, спроси какую отмечать.

2. Найди задачу в current sprint, backlog и current-sprint. Ничего в них не меняй вручную.

3. До любого изменения статуса запусти
   `bash $SDLC_VAULT/_agents/cycle1-dev/s0-validate/task-dod-check.sh $SDLC_PROJECTS_DIR/$ARGUMENTS T-NNN`.
   Строка ledger должна ссылаться на exact-source auto-check evidence и отдельный
   launcher-owned Human Approval v1 для ручных пунктов. Агент не создаёт и не имитирует
   approval. При `TASK DOD BLOCKED` оставь задачу в прежнем статусе.

4. Только после `TASK DOD VERIFIED` запусти
   `tracker-task-done.sh PROJECT T-NNN`. Это единственный writer: он готовит все три
   candidate-файла, публикует их как одну recoverable transaction и при любой ошибке
   восстанавливает прежние версии. Прямое редактирование одного task-файла запрещено.

5. Только строка `TRACKER TASK VERIFIED` разрешает вывести exact DoD evidence refs и:
   "✅ Задача T-NNN отмечена как DONE". При BLOCKED статус и velocity не меняются.

ОБЯЗАТЕЛЬНО: в конце вывести task board по формату из CLAUDE.md.

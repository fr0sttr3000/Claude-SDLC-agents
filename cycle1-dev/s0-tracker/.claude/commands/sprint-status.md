---
description: Показать текущую доску задач спринта
---

Покажи текущий статус спринта для проекта $ARGUMENTS.

Шаги:
1. Прочитай current-sprint.md:
   $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/current-sprint.md

2. Прочитай актуальный файл спринта (sprint-NN.md).

3. Прочитай backlog.md — подсчитай сколько задач ещё в backlog.

4. Выведи:
   - Полную task board в обязательном формате из CLAUDE.md
   - Статистику: сколько дней до конца спринта
   - Прогноз: при текущем темпе успеем ли закрыть спринт?
   - Топ-3 задачи по приоритету для следующего действия

Если активного спринта нет — вывести backlog summary:
   - Всего задач в backlog: N
   - По типам: feature N, bug N, chore N, SDLC-artifact N
   - Рекомендация: запустить /sprint-init

ОБЯЗАТЕЛЬНО: вывести task board по формату из CLAUDE.md.

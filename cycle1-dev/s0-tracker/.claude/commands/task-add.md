---
description: Добавить задачу в backlog проекта
---

Добавь новую задачу в backlog проекта $ARGUMENTS.

Шаги:
1. Прочитай backlog.md для определения следующего ID:
   /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/tracking/backlog.md
   Если файла нет — создай его с заголовком.

2. Спроси пользователя (если данные не переданы в аргументах):
   - Название задачи
   - Тип: feature | bug | chore | SDLC-artifact | research
   - Агент/исполнитель (или "team")
   - Story Points: 1 | 2 | 3 | 5 | 8 | 13
   - Зависит от (ID задачи, если есть)
   - Описание (опционально)

3. Присвой следующий ID (T-NNN, где NNN — порядковый с ведущими нулями).

4. Добавь задачу в backlog.md в формате из CLAUDE.md со статусом TODO, спринт: backlog.

5. Подтверди добавление: "Задача T-NNN добавлена в backlog".

ОБЯЗАТЕЛЬНО: в конце вывести task board по формату из CLAUDE.md (текущий спринт или backlog summary).

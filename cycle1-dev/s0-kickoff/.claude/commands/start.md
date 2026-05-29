---
description: Автоматически определить режим (новый проект / обновление) и запустить интервью
---

Прочитай:
- /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage1-planning/inputs/idea.md
- /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage1-planning/outputs/ (проверь наличие PM-*.md)
- /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/Dashboard.md

Правила автоопределения (из CLAUDE.md раздел "Автоопределение режима"):
- Нет PM-*.md в stage1-planning/outputs/ ИЛИ idea.md содержит "[Опиши продукт" → режим NEW
- Есть PM-*.md файлы → режим REFRESH

Сообщи обнаруженный режим, запроси подтверждение.
Затем выполни полный сценарий соответствующего режима строго по CLAUDE.md.

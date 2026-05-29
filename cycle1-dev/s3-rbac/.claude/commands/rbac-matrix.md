---
description: Сгенерировать или обновить матрицу прав (роли × ресурсы × действия)
---

Сгенерируй матрицу прав RBAC для проекта $ARGUMENTS.

Прочитай:
1. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage3-design/outputs/RBAC-*-model.md — текущая модель ролей и ресурсов

Если RBAC-model.md не существует — сначала выполни /rbac-model.

Создай или обнови матрицу:
- Строки: все роли из модели (включая унаследованные права через иерархию)
- Столбцы: resource:action для каждого ресурса
- Значения: ✓ / ✗ / ✓(own) / ✓(cond) с описанием условия
- Отдельная секция: унаследованные права (что роль получает от родителя)
- Отдельная секция: SoD-конфликты (какие комбинации запрещены)

Создай/обнови файл в /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage3-design/outputs/:
- RBAC-{ДАТА}-matrix.md

---
description: Сгенерировать или обновить матрицу прав (роли × ресурсы × действия)
---

Перед записью Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md`
и `_contract/APPLICABILITY_V1.md`; выполняй matrix только при resolver verdict
`authorization: REQUIRED`. При `NOT_APPLICABLE` используй один decision из `/rbac-model`,
не создавай вторую N/A запись.

Сгенерируй матрицу прав RBAC для проекта $ARGUMENTS.

Прочитай:
1. Current logical id `authorization-model` по root Current Artifacts rule

Если RBAC-model.md не существует — сначала выполни /rbac-model.

Создай или обнови матрицу:
- Строки: все роли из модели (включая унаследованные права через иерархию)
- Столбцы: resource:action для каждого ресурса
- Значения: ✓ / ✗ / ✓(own) / ✓(cond) с описанием условия
- Отдельная секция: унаследованные права (что роль получает от родителя)
- Отдельная секция: SoD-конфликты (какие комбинации запрещены)

Создай/обнови файл в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/:
- RBAC-{ДАТА}-matrix.md

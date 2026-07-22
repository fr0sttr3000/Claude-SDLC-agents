---
description: Создать Pull Request из явно выбранных head/base после read-only проверки
---

Аргументы: project, exact head branch и exact base branch. Если любого значения нет — спроси.

1. Read-only проверь root, remotes, clean/staged state, commits head..base и требуемые gates.
2. Не merge/rebase/push автоматически. Если head не опубликована, предложи отдельный
   подтверждённый `/push`.
3. Покажи title/body, head/base, changed-file summary и URL remote.
4. Только после явного подтверждения выполни `gh pr create`.
5. Верни URL/номер или BLOCKED с фактической ошибкой; не повторяй на другом remote/account.

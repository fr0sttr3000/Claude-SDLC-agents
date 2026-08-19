---
description: Исправить подтверждённые review findings строго в выбранном scope
---

Исправь проект $ARGUMENTS только в явно подтверждённом scope:
`structure`, `project`, `cycle:1`, `stage:0..5` или `agent:<active-id>`.

Cycle 2/3, Stage 6/7 и frozen agents не являются repair scope: верни
`FROZEN / NOT READY`, не изменяя historical files.

1. Используй только `VERIFIED REVIEW FINDINGS TSV`, переданный launcher-ом вместе с
   `parent_review` и `findings_sha256`. Если envelope отсутствует — верни BLOCKED, ничего не меняя.
2. До изменений покажи project path, files to change, excluded scope и проверки after.
3. Не исправляй requirement/architecture/business решения догадками; такой finding = BLOCKED.
4. Сохраняй native formats, IDs и traceability; не ослабляй gates/tests и не трогай release
   history вне release preparation.
5. Не выполняй Git/deploy/ops действия.
6. После изменений повтори только применимые validators/tests и перечисли фактически изменённые
   файлы. Не объявляй весь Project исправленным при частичном scope.

Launcher после process success сам запускает read-only re-review того же exact scope. Repair
считается завершённым только при изменившемся Project snapshot и machine `CLEAN` re-review.

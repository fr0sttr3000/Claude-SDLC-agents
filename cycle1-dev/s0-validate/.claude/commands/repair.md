---
description: Исправить подтверждённые review findings строго в выбранном scope
---

Исправь проект $ARGUMENTS только в явно подтверждённом scope:
`structure`, `project`, `cycle:1|2|3`, `stage:0..7` или `agent:<id>`.

1. Прочитай последние подтверждённые review findings/evidence; если их нет, сначала проведи
   read-only review и покажи план исправлений.
2. До изменений покажи project path, files to change, excluded scope и проверки after.
3. Не исправляй requirement/architecture/business решения догадками; такой finding = BLOCKED.
4. Сохраняй native formats, IDs и traceability; не ослабляй gates/tests и не трогай release
   history вне release preparation.
5. Не выполняй Git/deploy/ops действия.
6. После изменений повтори только применимые validators/tests и перечисли фактически изменённые
   файлы. Не объявляй весь Project исправленным при частичном scope.

---
description: Добавить запись секрета в pass без вывода значения
---

Сначала прочитай каноническую policy в
`$SDLC_VAULT/_agents/_standards/security.md#Хранение-секретов`.

Для `$ARGUMENTS`:

1. Определи exact Project или global `pass` entry reference и покажи его до изменения.
2. Проверь, существует ли entry, не читая и не выводя его значение.
3. Если entry уже существует, не перезаписывай его этой командой; предложи `/rotate`.
4. Запусти интерактивный `pass insert` только после подтверждения reference. Значение вводится
   непосредственно в prompt `pass`, а не в chat или аргумент команды.
5. Подтверди только созданный entry reference.

Не создавай `.env`, export script, shell profile или Project artifact.

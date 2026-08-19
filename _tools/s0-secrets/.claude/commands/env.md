---
description: Показать mapping переменных окружения на pass entries без значений
---

Сначала прочитай каноническую policy в
`$SDLC_VAULT/_agents/_standards/security.md#Хранение-секретов`.

Для Project `$ARGUMENTS` покажи только подтверждённые mappings в форме:

```text
ENV_VAR → pass:entry/reference
```

Не читай и не выводи secret values, не создавай `.env`/export script/shell profile и не изменяй
Project. Если mapping не определён однозначно, пометь его `UNMAPPED`, не угадывай entry.

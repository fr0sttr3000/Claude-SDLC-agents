---
description: Выполнить автоматизируемую часть DoD для K/D/I и Stage 1..7
---

Проверь DoD проекта из $ARGUMENTS. Аргументы:
`<PROJECT> <K|D|I> <STAGE 1..7> [PR] [release=yes|no]`.
Если обязательное значение отсутствует, спроси его; не угадывай тип, stage или release context.

Запусти `dod-check.sh` с `SDLC_RELEASE_PREPARATION=yes|no` и абсолютным project path.
Не изменяй artifacts. `DoD auto-check PASSED` подтверждает только автоматизируемую часть;
ручные пункты и полный verdict остаются у владельца gate.

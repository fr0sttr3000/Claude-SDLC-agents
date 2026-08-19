---
description: Выполнить автоматизируемую часть DoD для K/D/I и active Stage 1..5
---

Проверь DoD проекта из $ARGUMENTS. Аргументы:
`<PROJECT> <K|D|I> <STAGE 1..5> [PR] [SOURCE_REVISION]`.
Если обязательное значение отсутствует, спроси его; не угадывай тип или stage.

Для `K|I` exact source revision обязателен: metrics и controls читаются только из
digest-bound Evidence и сравниваются с effective Quality Policy. `I` допустим только в
Stage 4 для executable migration с current migration design, QA-owned TDD PASS и
`upgrade→downgrade→upgrade`; Stage 3 data design/runbook имеет Тип `D`.

Запусти `dod-check.sh` с абсолютным project path. Stage 6/7 и release preparation не входят
в active DoD Cycle 1 и возвращают `FROZEN / NOT SUPPORTED`.
Не изменяй artifacts. `DoD auto-check PASSED` подтверждает только автоматизируемую часть;
ручные пункты и полный verdict остаются у владельца gate.

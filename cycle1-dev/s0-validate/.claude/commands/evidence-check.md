---
description: Проверить Evidence Contract v1 и minimum PR/SG3 controls для exact source
---

Аргументы: `<PROJECT> <FULL_SOURCE_REVISION>`. Не изменяй Project и не запускай scanner
повторно. Прочитай `_contract/EVIDENCE_V1.md`, `_contract/SG3_POLICY_V1.md` и
`_contract/EXECUTOR_CONTROLS_V1.md`, затем запусти:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/pr-evidence-check.sh" \
  "$SDLC_PROJECTS_DIR/<PROJECT>" "<FULL_SOURCE_REVISION>"
```

Только `PR EVIDENCE VERIFIED`, `SG3 VERIFIED` и `EXECUTOR CONTROLS VERIFIED` для одной
revision позволяют продолжить. `FAIL|BLOCKED|UNVERIFIED`, missing check или неподтверждённый
executor останавливают gate. Не превращай proposal или Markdown summary в live proof.

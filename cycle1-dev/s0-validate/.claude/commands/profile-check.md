---
description: Детерминированно проверить Product & CI Profile перед Stage 1
---

Не изменяй Project. Запусти:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/product-ci-profile-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS"
```

`PROFILE VALID` подтверждает только schema/completeness/revision contract. `PROFILE BLOCKED`
останавливает Stage 1 и возвращает exact fact к `s0-kickoff /product-ci-profile` или владельцу.
Не подставляй default и не принимай business/architecture decision за пользователя.
Schema version 5 — current Product Profile contract. Schema versions 1–4 остаются только
legacy/additive migration inputs; они не называются current и не должны создаваться для нового
Project. Evidence v1 может читать historical schema 2–5, но current gate applicability и quality
characteristics разрешаются из schema version 5.

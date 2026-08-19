---
description: Сгенерировать Markdown summary из verified Evidence Contract v1 records
---

Аргументы: `<PROJECT> <FULL_SOURCE_REVISION>`. Сначала выполни `/evidence-check`. Затем
сгенерируй view каноническим script в
`stage4-dev/outputs/EVIDENCE-<FULL_SOURCE_REVISION_SAFE>.md` (`sha256:` кодируется как
`sha256-`, чтобы имя было переносимым):

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/evidence-v1-summary.sh" \
  "$SDLC_PROJECTS_DIR/<PROJECT>" "<FULL_SOURCE_REVISION>" \
  > "$SDLC_PROJECTS_DIR/<PROJECT>/stage4-dev/outputs/EVIDENCE-<FULL_SOURCE_REVISION_SAFE>.md"
```

Не редактируй verdict вручную и не копируй raw result в Markdown. Summary — human-readable
handoff, не machine evidence.

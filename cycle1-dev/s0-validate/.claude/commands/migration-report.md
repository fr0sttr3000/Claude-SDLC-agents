---
description: Read-only dry-run отчёт additive migration без изменения Project
---

# /migration-report — additive migration dry-run

Сформируй read-only отчёт о legacy artifacts выбранного Project:

```bash
bash "$AGENT_DIR/legacy-migration-report.sh" "$SDLC_PROJECTS_DIR/{PROJECT}"
```

Правила:

- не изменяй и не создавай файлы внутри Project;
- старый Markdown и self-attested PASS классифицируй только как `LEGACY / UNVERIFIED`;
- не переноси старый PASS в Evidence v1;
- новый schema создаёт только owning role при следующем явном изменении artifact;
- Stage 6/7 сохраняй как `HISTORICAL_EXCLUDED` и не включай в active Cycle 1 verdict.

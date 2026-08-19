---
description: Подготовить versioned Project release notes из verified Cycle 1 completion
---

Подготовь release notes версии $ARGUMENTS для Project, указанного launcher-ом.

Прочитай:

1. `$SDLC_VAULT/_agents/_contract/RELEASE_NOTES_V1.md`
2. `$SDLC_VAULT/_agents/_contract/CYCLE1_COMPLETION_V2.md`
3. `$SDLC_VAULT/_agents/_standards/artifact-metadata.md`
4. `tracking/completion/CYCLE1-completion-v2.yaml`
5. `tracking/cycle-summary.md`
6. `tracking/known-issues.md`, если существует
7. Project `CHANGELOG.md` и migration notes, если существуют

Версия обязана иметь точный формат `vMAJOR.MINOR.PATCH`. До записи запусти
`cycle1-completion-check.sh`; BLOCKED/UNVERIFIED completion запрещает создание notes.

Создай только `tracking/releases/REL-$ARGUMENTS-release-notes.md` по Release Notes v1.
Не изменяй существующий target: одинаковый valid version/source обрабатывает launcher как
idempotent no-op, а конфликт блокируется до запуска. Не изменяй completion manifest,
CHANGELOG или исходные Project artifacts.

Используй общий Artifact Metadata v1 и все release domain fields. Факты бери только из
verified completion/cycle summary/current Project sources; отсутствующие данные обозначай
`none` или `not documented`, не додумывай.

Обязательные sections: Validated scope, Changes, Known limitations, Migration notes,
Evidence and provenance, Explicit exclusions, Obsidian Links. В exclusions явно укажи,
что external publication, build, deploy, production и Cycle 2/3 не выполнялись.
В `Known limitations` включи по KI id каждую точную `Status: OPEN` запись из
`tracking/known-issues.md`. Пропуск любой OPEN записи блокирует validation; FIXED запись не
переноси автоматически. Эта подготовка не разрешает публикацию, build, release или deploy.

После записи запусти:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/release-notes-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" "$ARGUMENTS"
```

Не выполняй external publication, release build, deploy, production actions или frozen
agents.

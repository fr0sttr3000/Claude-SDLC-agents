# Project Release Notes Contract v1

Project release notes are an optional post-Cycle-1 preparation artifact owned by
`s0-tracker /release-notes vX.Y.Z`. They summarize an already verified immutable Cycle 1
completion; they do not alter Gate 5 or authorize external publication, build, deploy,
production or frozen Cycle 2/3 actions.

## Preconditions and target

- `cycle1-completion-check.sh` must return `CYCLE 1 COMPLETION VERIFIED`.
- Version is exact `vMAJOR.MINOR.PATCH` with non-negative decimal integers and no leading zero
  except the number `0` itself.
- The only target is `tracking/releases/REL-vMAJOR.MINOR.PATCH-release-notes.md`.
- The completion manifest is read-only. Its SHA-256 before and after generation must match.
- An existing valid artifact for the same version/completion is an idempotent no-op.
- Any existing invalid, different-source or different-completion target is a conflict and
  must be blocked, never overwritten silently.

## Artifact

The Markdown file conforms to `_standards/artifact-metadata.md` with:

```text
artifact_type: project-release-notes
stage: TRACKING
producer: s0-tracker
source_revision: <completion source_revision>
status: VALIDATED
```

In addition to the common fields, flat frontmatter contains:

```text
release_version: vMAJOR.MINOR.PATCH
release_state: PREPARED_NOT_RELEASED
completion_manifest_ref: tracking/completion/CYCLE1-completion-v2.yaml
completion_manifest_sha256: <sha256>
completion_id: <manifest completion_id>
completion_source_revision: <manifest source_revision>
completion_subject_digest: <manifest subject_digest>
external_publication_action: not-performed
build_action: not-performed
deploy_action: not-performed
production_action: not-performed
cycle23_status: FROZEN_NOT_READY
```

Required sections:

1. `# Release Notes — vMAJOR.MINOR.PATCH`
2. `## Validated scope`
3. `## Changes`
4. `## Known limitations`
5. `## Migration notes`
6. `## Evidence and provenance`
7. `## Explicit exclusions`
8. `## Obsidian Links`

`Changes`, limitations and migration notes come only from current Project artifacts. Missing
data is written as `none`/`not documented`, not invented. Explicit exclusions state that external publication, build, deploy, production and
Cycle 2/3 were not performed.

If `tracking/known-issues.md` exists, every record whose exact `Status` is `OPEN` is listed by
KI id in `## Known limitations`. Omitting any OPEN record makes the release notes incomplete
and blocks validation. A FIXED record is not carried forward automatically. Preparing or
validating this section still does not authorize publication, build, release, deploy or
production use.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/release-notes-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" vMAJOR.MINOR.PATCH
```

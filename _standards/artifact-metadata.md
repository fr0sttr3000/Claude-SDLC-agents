# Standard: Artifact Metadata v1

This is the single metadata schema for every new or materially changed Cycle 1 **Project**
governance, handoff, report and gate Markdown artifact inside
`$SDLC_PROJECTS_DIR/{PROJECT}`. Role contracts add domain fields but do not copy or redefine
this common schema.

Platform governance Markdown inside `_agents` is not a Project artifact and has no Project
Dashboard. It is covered by repository inventory/link/frontmatter tests and navigates from
`[[plans/roadmap]]` and `[[plans/principles]]`; `artifact-metadata-check.sh` must not be used on that platform scope.

Legacy Project artifacts are read as `LEGACY / UNVERIFIED` until their owning role touches or
explicitly migrates them. Bulk rewrite is forbidden. Native code, tests, JSON/YAML evidence,
TSV indexes, OpenAPI, SQL and scanner output retain their native formats and contracts.

## Required frontmatter

The file starts with flat YAML frontmatter and contains these unique fields:

```yaml
---
schema_version: 1
artifact_id: QA-2026-07-27-GATE5
artifact_type: gate5-decision
project: ProjectName
stage: S5
producer: s5-qa
source_revision: 0123456789abcdef0123456789abcdef01234567
status: VALIDATED
inputs: tracking/validation/S5-validation-v1.tsv,stage5-testing/outputs/DEF-defects-v1.tsv
outputs: stage5-testing/outputs/QA-2026-07-27-go-no-go.md
tags: sdlc,cycle1,stage5,gate
---
```

- `artifact_id`: stable `A-Z0-9._-` identifier, unique within the Project.
- `artifact_type`: lower kebab-case class from the owning contract.
- `project`: exact Project directory name.
- `stage`: `S0|S1|S2|S3|S4|S5|TRACKING`.
- `producer`: exact active agent id that writes the file.
- `source_revision`: full 40/64-hex revision, `sha256:<64hex>`, or `none` before source-bound work.
- `status`: `DRAFT|RED|PASS|FAIL|BLOCKED|NOT_APPLICABLE|APPROVED|VALIDATED|UNVERIFIED`.
- `inputs`, `outputs`: comma-separated Project-relative references or `none`; no absolute path,
  traversal or symlink. `outputs` includes the artifact itself.
- `tags`: unique lower-case comma-separated tags; include `sdlc`, `cycle1` and stage/tracking.

Secret values and local absolute paths are forbidden.

## Obsidian links

The body contains one `## Obsidian Links` section. It includes:

```markdown
- Dashboard: [[Dashboard]]
- Inputs: [[relative/markdown-input]], `relative/native-input.json`
- Outputs: [[relative/current-artifact]]
```

Markdown inputs/outputs use wiki-links without the `.md` suffix so Obsidian Graph View can
connect them. Native references remain code-formatted paths. Machine IDs and native indexes
remain the canonical trace; Graph View is navigation, not verification evidence.

Validate a touched artifact with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/artifact-metadata-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" "project/relative/artifact.md"
```

The launcher derives applicable Markdown producers from its command capability registry and
declared-output mapping. After every successful process it compares a
`Project-relative path + checksum` snapshot and validates each new/changed declared Markdown
output against the executing command's expected `producer`, allowed `stage` and allowed
`artifact_type` before recording `ARTIFACT_VERIFIED`. Full Cycle, One Agent and optional utility
routes use the same hook; runtime exit code `0` cannot bypass it.

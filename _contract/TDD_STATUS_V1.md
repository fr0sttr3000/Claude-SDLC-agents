# TDD Status Contract v1

`stage4-dev/outputs/QA-TDD-status.md` is the current machine-readable handoff owned by the
existing independent `s4-qa-auto` role. It proves Red before Green and binds the post-Green
result to one exact source revision and one complete affected regression manifest. It is not a
replacement for native JUnit/TAP Evidence v1 from the selected executor.

## Status schema

The file is Markdown with flat YAML frontmatter. It first conforms to
`_standards/artifact-metadata.md` (`artifact_type: tdd-status`, `stage: S4`,
`producer: s4-qa-auto`). The following domain fields are added to that common frontmatter:

```yaml
scope: FR-001,FR-002
source_revision: 40-or-64-hex-or-sha256-digest
test_command: exact native command
red_evidence: concise expected functional failure or none
last_run: 2026-07-27T12:00:00Z
failed_tests: 0
repair_iteration: 0
regression_scope: not-yet-run|full-affected|partial
affected_test_manifest: stage4-dev/outputs/QA-affected-tests-v1.tsv|none
affected_test_manifest_sha256: 64-hex|none
expected_test_count: 0
executed_test_count: 0
```

Its body contains `## Obsidian Links` as required by the common schema. Native affected-test
manifests remain TSV and are referenced rather than converted to Markdown.

`scope` is a comma-separated set of requirement/change ids. A valid `RED` has concrete
functional/test `red_evidence`, `not-yet-run`, and zero post-Green counters. Environment,
infrastructure, missing-tool/dependency, permission, network or test-runner startup failures
are `BLOCKED`, never `RED`. A `PASS` or `FAIL`
requires `full-affected`, an intact manifest, no skipped rows, and equal expected/executed row
counts. `PASS` has zero failed tests; `FAIL` has the exact positive failure count. `partial` or
`selective` can never produce PASS.

## Affected-test manifest

`QA-affected-tests-v1.tsv` has this exact header:

```text
test_id\ttest_uri\tchange_id\tresult\tsource_revision
```

Every declared scope id has at least one row. `test_uri` points to an existing native test file
inside the Project and may follow the repository's own stack convention; the SDLC core does
not relocate tests into its governance outputs. Each row is bound to the same exact source
revision and has `PASS|FAIL`; `SKIPPED`, `XFAIL` and omitted scope rows block the handoff.

Gate 4 first validates this status as PASS, then validates the same source revision through
Evidence Contract v1, SG3 and executor controls. The SDET owns the test status; Developer cannot
sign it, and Tech Lead does not re-sign native test/scanner results.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/tdd-status-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" PASS
```

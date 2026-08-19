# Cycle 1 Completion Contract v1 — LEGACY / UNVERIFIED

This schema is retained only to interpret historical
`tracking/completion/CYCLE1-completion-v1.yaml` files. It does not prove the full launcher plan,
Journal, all 28 steps, Gate 1–5 or full DoD, and therefore cannot establish current verified
completion. New runs use `_contract/CYCLE1_COMPLETION_V2.md` and
`tracking/completion/CYCLE1-completion-v2.yaml`. Historical v1 artifacts are not silently
renamed or overwritten.

Cycle 1 completion is a validated development/product-acceptance handoff. It is not release
preparation and does not authorize push, release build, deploy or production actions.

Ownership remains separated:

- `s5-qa` owns the verified Gate 5 decision;
- `s0-tracker /report` reads existing outputs and owns the completion manifest;
- no `s5-release-prep` agent is introduced;
- frozen Cycle 2/3 agents and artifacts are not inputs.

## Artifacts

`tracking/cycle-summary.md` is the human-readable completion report produced by `s0-tracker`.
It conforms to `_standards/artifact-metadata.md` with `stage: TRACKING` and
`producer: s0-tracker`. The YAML manifest and TSV bundle below retain their native contracts.

`tracking/completion/CYCLE1-evidence-bundle-v1.tsv` has the exact header:

```text
evidence_id	check_id	verdict	record_uri	record_sha256	observed_at	freshness_seconds	subject_digest	build_identity
```

It lists every current Evidence v1 record for the completed source revision exactly once.
Every row is revalidated, digest-bound and still fresh when the completion manifest is
created. The bundle may contain structured `NOT_APPLICABLE`; `FAIL`, `BLOCKED` and
`UNVERIFIED` are forbidden.

`tracking/completion/CYCLE1-completion-v1.yaml` is flat YAML with these exact fields:

```text
schema_version
completion_id
status
project
gate5_owner
completion_owner
source_revision
subject_kind
subject_digest
build_identity
product_profile_revision
validated_at
evidence_fresh_until
evidence_bundle_uri
evidence_bundle_sha256
verified_evidence_ids
unverified_evidence_refs
build_evidence_ref
gate5_decision_ref
gate5_decision_sha256
validation_index_ref
validation_index_sha256
defect_index_ref
defect_index_sha256
uat_approval_ref
risk_exception_refs
known_limitation_ids
artifact_digest
sbom_evidence_ref
provenance_evidence_ref
release_notes_status
release_notes_ref
push_status
release_build_status
deploy_status
production_action_status
cycle23_status
client_next_action
```

The manifest is `VALIDATED` only after S5 Validation v1 succeeds for the same exact source.
`artifact_digest` is copied from verified build evidence only for an artifact/image subject.
SBOM/provenance references are present only when a corresponding verified executor record
exists; otherwise their value is `none`. Source-only work keeps all artifact fields `none`.

`unverified_evidence_refs`, active risk exceptions and known limitations are explicit
comma-separated references/ids or `none`. `risk_exception_refs` is the sorted unique union of
every current Evidence v1/SG3 exception and every S5 stream exception. Completion re-derives SG3
Medium ids from digest-bound JSON/SARIF, revalidates each typed Risk Exception v3 and requires an
exact manifest match; S5 exceptions are revalidated by S5 Validation v1. Omitted, extra, stale
or scope-tampered references block completion. They are not silently reclassified as verified.
The earliest Evidence v1 expiry is recorded as `evidence_fresh_until`.

The following values are mandatory for normal Cycle 1 completion:

```text
release_notes_status: not-requested
release_notes_ref: none
push_status: not-performed
release_build_status: not-performed
deploy_status: not-performed
production_action_status: not-performed
cycle23_status: FROZEN_NOT_READY
client_next_action: s0-tracker:/release-notes
```

Release notes can be created later by the separately requested Project utility
`s0-tracker /release-notes vX.Y.Z` under `_contract/RELEASE_NOTES_V1.md`; their absence does
not invalidate this immutable manifest.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/cycle1-completion-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}"
```

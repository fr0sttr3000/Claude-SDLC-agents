# Cycle 1 Completion Contract v2

Cycle 1 completion is a validated development/product-acceptance handoff. It is not release
preparation and does not authorize external publication or release build, deploy or production actions.

Ownership remains separated:

- `s5-qa` owns the verified Gate 5 decision;
- `s4-techlead` owns the independent full DoD Human Approval;
- the launcher owns immutable plan, hash-chained Journal, current-artifact updates and the
  execution proof;
- `s0-tracker /report` aggregates existing verified references into the completion manifest;
- frozen Cycle 2/3 agents and artifacts are not inputs.

## Artifacts

`tracking/cycle-summary.md` is the human-readable report and uses common Artifact Metadata v1.

`tracking/completion/CYCLE1-evidence-bundle-v1.tsv` keeps the v1 evidence-bundle schema:

```text
evidence_id\tcheck_id\tverdict\trecord_uri\trecord_sha256\tobserved_at\tfreshness_seconds\tsubject_digest\tbuild_identity
```

It lists every current Evidence v1 record for the completed source exactly once. Each row is
digest-bound, revalidated and fresh. Only `PASS|NOT_APPLICABLE` are allowed.

The current manifest is `tracking/completion/CYCLE1-completion-v2.yaml`. It is flat YAML with
these exact fields:

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
execution_run_id
execution_plan_sha256
current_artifact_manifest_ref
current_artifact_manifest_sha256
full_dod_approval_ref
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
external_publication_status
release_build_status
deploy_status
production_action_status
cycle23_status
client_next_action
```

`schema_version` is `2`. The runtime-owned execution fields are copied only from the sanitized
launcher environment. `execution_run_id` is the terminal run; `execution_plan_sha256` is the
root full-cycle plan digest. A normal uninterrupted Cycle is a chain of length one. Retry adds
only linked suffix runs. The validator locates the terminal run, validates every Journal in the
linear chain plus launcher-owned `cycle1-execution-chain-v1.tsv` and
`cycle1-completion-proof-v2.yaml`, and proves:

- all 28 canonical steps from `_contract/cycle1-steps-v1.tsv` occurred in order and have exact
  `ARTIFACT_VERIFIED` events;
- Gate 1–5 each have one exact launcher-owned `GATE_PASS` event bound into the immutable
  Journal prefix; completion separately revalidates its current S5/evidence/exception inputs;
- TDD/full-affected, PR Evidence, SG3, executor controls and S5 bind the same source/subject;
- `DOD_AUTO_PASS` and independent `DOD_PASS` are both present;
- every Retry child names one exact parent, contains the exact remaining entries, frozen
  profiles and route sources, and is linked by a digest-valid parent event;
- every mandatory logical artifact belongs to one exact run/plan in that root/Retry chain and
  the current Product Profile revision; unrelated runs cannot contribute evidence;
- the current manifest digest and full DoD approval ref match this completion manifest.

Optional validation steps may appear only before or after the canonical 28-step sequence and
cannot replace a mandatory step. Historical artifacts remain in place but are excluded from
current validation by `tracking/current-artifacts-v1.tsv`.

Resume advances only past a step whose registered pre/post Gate, full DoD and completion hooks
are also verified. Therefore a failed Gate-after, DoD or `/report` completion proof reruns the
owning step in the child instead of silently skipping its missing boundary verdict.

The v1 completion file/contract is legacy and cannot establish current verified completion.
Migration is additive: retain old v1 files as history and create v2 only after a new full-cycle
execution proof succeeds.

The evidence/risk/build/S5 rules from v1 remain mandatory: exact source, earliest freshness,
current SG3+S5 exception union, exact known limitations, source-vs-artifact subject semantics,
and no invented SBOM/provenance.

Normal Cycle 1 completion retains:

```text
release_notes_status: not-requested
release_notes_ref: none
external_publication_status: not-performed
release_build_status: not-performed
deploy_status: not-performed
production_action_status: not-performed
cycle23_status: FROZEN_NOT_READY
client_next_action: s0-tracker:/release-notes
```

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/cycle1-completion-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}"
```

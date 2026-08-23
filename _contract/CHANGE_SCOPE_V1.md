# Change Scope Contract v1

Change Scope v1 confines native Stage 4 mutations to a human-approved, exact source change
set. It supplements declared-output verification: a required report changing is necessary but
does not authorize any other Project mutation.

## Isolated preparation

The launcher creates one immutable Change Intent from either exact current backlog/requirement
ids or one existing Change Request. `l1-analyze /impact` then produces a Project Map and
technical impact proposal in a write scope limited to its proposal directory. A separate
`s3-arch /change-impact` process reads those digest-bound inputs and produces the architecture
decision plus proposed Stage 4 path rows. Neither process approves its own result, calls the
other agent or receives vendor conversation state.

Every preparation is bound to the exact Project, Product Profile revision, source revision and
preparation baseline. Unknown mandatory facts, unresolved architecture impact, stale source or
tampered handoff returns `BLOCKED`.

## Module modes

- `USE` — the implementation is read-only and only its existing interface may be consumed.
- `EXTEND` — only exact registered extension paths may be written.
- `MODIFY` — only exact approved paths may be written.
- `LOCKED` — implementation mutation is forbidden until a prior HLD/ADR change is current and
  a fresh L1 -> S3 preparation explicitly reclassifies the requested paths.
- `SYSTEM` — launcher-added governance output patterns from the canonical output registry.

Intentional architectural complexity is protected through `USE|LOCKED`, current ADR/HLD
references and characterization/security/performance invariants. Complexity metrics never
grant permission to simplify a protected module.

## Approved bundle

One approved bundle lives below:

```text
tracking/change-scopes/{scope-id}/
├── intent.yaml
├── l1/project-map-v1.tsv
├── l1/impact-v1.tsv
├── s3/architecture-impact-v1.yaml
├── s3/change-scope-paths-proposed-v1.tsv
└── approved/
    ├── approval-request-v1.yaml
    ├── change-scope-v1.yaml
    └── change-scope-paths-v1.tsv
```

`tracking/current-change-scope-v1.yaml` selects the exact approved metadata/path files and
their SHA-256 digests. Its scope id, source revision and paths binding must equal the selected
metadata, and the selected Product Profile must remain valid, snapshot-identical and at the same
revision. The approval is a Human Approval v1 record named
`APPROVAL-SCOPE-{scope-id}` whose subject digest binds source, baseline and every input/path
digest. Its scope is exactly `change-scope:{scope-id}@{subject-digest}`. The matching
launcher-owned receipt remains outside Project write scope.

The path table header is:

```text
schema_version	intent_id	agent	command	operation	path	module_id	module_mode	origin
```

Operations are `modify|create|delete|rename_from|rename_to|generated|ephemeral|declared-output`.
Normal mutations use exact safe Project-relative paths. Only `generated|ephemeral` may name an
anchored directory prefix. Only the launcher may add `declared-output` glob patterns, and every
such pattern must be an exact alternative from `current-artifact-groups-v1.tsv` for the same
agent/command. Delete and rename have no implicit permission.

L1 outputs use exact headers:

```text
schema_version	source_revision	module_id	path	public_interface	dependencies	tests	generated	classification	confidence
schema_version	intent_id	module_id	mode	operation	path	confidence	rationale
```

S3 proposes only native path rows and cannot add `declared-output`. The launcher validates every
native row against an exact high-confidence L1 row and module owner, adds governance alternatives
from the canonical output registry, calculates the final subject digest and creates a `PENDING`
approval request. Only after the separate Human Approval succeeds does it atomically create the
`APPROVED` metadata and replace the current pointer.

A native Stage 4 row must not match a registered governance output or contain one through an
anchored directory prefix. Governance outputs enter the approved table only as launcher-owned
`declared-output` alternatives for the exact registered agent and command.

## Runtime and verification

Stage 4 mutators use `scoped-write`. The dispatcher reads the approved path table and gives the
runtime whole-Project read access plus only the current step's calculated write capabilities.
VCS metadata, sibling Projects, ambient HOME, runtime-denied roots and unspecified paths remain
denied. A scope that cannot fit the supported Landlock path limit blocks instead of widening.

The launcher records a full entry/type/mode/content-or-link-target manifest immediately before
and after every Stage 4 process. Every observed create, delete, modify, mode, type or symlink
change must match one current agent/command row. Creating or replacing an approved path with a
symlink or special filesystem object is always a violation, as is changing the type of an
existing entry. Declared outputs must also pass their existing producer/metadata/freshness
checks. Only then may the step receive `ARTIFACT_VERIFIED`.

An out-of-scope final change creates a launcher-owned violation record and returns
`BLOCKED/UNVERIFIED`. Version 1 does not auto-rollback. Further Stage 4 mutation remains blocked
until the operator reviews the exact paths and either restores the Project or approves a fresh
scope. Retry may reuse approval only when the scope digest is unchanged and the current tree has
no unresolved violation. Interrupted scope preparation is not a normal Cycle child retry: start
a fresh preparation so its discovery, architecture handoff and approval are assembled together.

The contract applies first to Stage 4 mutating commands. Existing Stage 1-3/5 behavior remains
unchanged. A new Stage 4 launch for an existing Project without a valid current scope fails
closed.

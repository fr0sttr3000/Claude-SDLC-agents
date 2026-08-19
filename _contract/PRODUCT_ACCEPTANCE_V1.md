# Product Acceptance Contract v1

Product acceptance is authored by the existing `s2-po` role during `/stories`. It is a
Stage 2 product handoff, not a new agent, and does not replace the story-level Given/When/Then
acceptance criteria in the backlog.

## Product Profile applicability

New or refreshed projects use Product & CI Profile schema version 5. Product Acceptance uses
confirmed facts and their provenance fields:

- `user_interface`: `graphical|terminal|api-only|library-only|none`;
- `ux_brief_requirement`: `required|not-applicable`.
- `accessibility_validation`: `required|not-applicable`.

`graphical|terminal` requires a UX brief. `api-only|library-only|none` requires a structured
UX `NOT_APPLICABLE` record. The profile revision is authoritative; product type alone is not
used to guess an interface. Schema versions 1 and 2 remain readable, but do not carry enough
information to close the Stage 2 product-acceptance gate. Schema v3/v4 remain valid for their
existing boundaries; kickoff writes v5 so later S5 and quality-characteristic applicability
are explicit too.
The schema v5 standalone validator requires the current Quality Characteristics v1 index
before accepting UX/accessibility/UAT artifacts.

## Artifacts

All artifacts are written to `stage2-requirements/outputs/` by `s2-po`:

- UI: exactly one `PO-YYYY-MM-DD-ux-brief.md`;
- non-UI: exactly one `PO-YYYY-MM-DD-ux-not-applicable.md`;
- every project: exactly one `UAT-YYYY-MM-DD-acceptance-criteria.md`;
- every project: exactly one `UAT-product-acceptance-v1.tsv` trace index.

The `UAT-` prefix identifies the artifact class; ownership remains `s2-po`. No `s2-uat` role
or additional agent-to-agent handoff is introduced. Wireframes and visual mock-ups are
optional supporting material, never a universal gate requirement.

### UX brief domain fields and content

Each Markdown artifact first conforms to `_standards/artifact-metadata.md`. The fields below
are additional domain fields; they do not replace or redefine the common schema:

```yaml
artifact_type: ux-brief
owner: s2-po
product_profile_revision: 1
applicability: REQUIRED
user_interface: graphical
```

The document contains `## User Flows` with stable `UXF-*` ids and
`## UX Acceptance Constraints` with stable `UXC-*` ids. A terminal interface uses the same
contract. For schema v5 every `UXC-*` criterion contains `Measure:` with a concrete observable
target; an id without a measure cannot close Interaction Capability.

For Product Profile schema v5 the same frontmatter also contains
`accessibility_applicability: REQUIRED|NOT_APPLICABLE` and `accessibility_standard`.
When accessibility is required, `accessibility_standard` is a confirmed named profile and
the document contains `## Accessibility Criteria` with stable `A11Y-*` ids; every criterion
contains `Measure:` with a concrete observable target. When it is not applicable, the standard
is exactly `not-applicable` and a concrete
`accessibility_reason` is mandatory. The validator never chooses a standard from product type.

For non-UI products, `artifact_type` is `ux-not-applicable`, `applicability` is
`NOT_APPLICABLE`, `user_interface` exactly matches the profile, and
`applicability_reason` is a concrete confirmed reason rather than `unknown`, `none`, or free
text detached from the profile.
For schema v5 the non-UI record also carries
`accessibility_applicability: NOT_APPLICABLE`, `accessibility_standard: not-applicable` and a
concrete `accessibility_reason`.

### Product acceptance criteria

The UAT Markdown uses the same common schema and additionally contains:

```yaml
artifact_type: uat-criteria
owner: s2-po
product_profile_revision: 1
acceptance_scope: product-end-to-end
```

It contains `## Product Acceptance Scenarios`, stable `UAT-*` ids, end-to-end observable
outcomes and explicit `Sign-off criterion:` statements. It references Must requirements,
current product risks and applicable `UXF-*` ids. For a confirmed non-UI profile the UX
reference is exactly `NOT_APPLICABLE`; product UAT itself is still required.

The tab-separated trace index has this exact header:

```text
uat_id\tmust_fr_id\trisk_id\tux_flow_id\tcriteria_uri
```

Every Must `FR-*` in a `BA-*-RTM.md` has at least one row. Each row is checked against the
UAT document, the PMO risk register and, when applicable, the UX brief. `criteria_uri` is the
exact project-relative path of the single UAT criteria document. The trace index is the
machine-readable relation; Markdown alone cannot close the gate.

## Consumers and gate

`s2-qa-req`, `s2-test-strategy` and `s3-arch` consume both the UX applicability artifact and
product acceptance criteria. `s5-qa` uses the same criteria for human UAT and final Go/No-Go.
The Stage 2 boundary invokes the deterministic validator before S3.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/product-acceptance-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}"
```

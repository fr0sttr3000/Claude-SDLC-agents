# Quality Characteristics Contract v1

This contract makes product-quality coverage explicit without adding agents or a universal
tooling platform. The existing `s0-quality-gates` role derives one project-local index from
confirmed Product & CI Profile schema v5 facts after Stage 1 and before Stage 2.

The index does not replace requirements, architecture, tests, security gates, UAT or the
only-up policy. It is a Stage-1 coverage plan recording which existing owner, evidence contract
and active Cycle 1 gate must later prove each characteristic. It is not result evidence and
cannot close a gate by itself. Exact result references are carried by the downstream
Traceability, Evidence v1 and S5 Validation indexes. Cycle 2/3 operations are never required.

Its 11 rows are **11 project quality controls**, not 11 characteristics from one ISO model.
Nine product-quality characteristics follow ISO/IEC 25010:2023; `accessibility` remains an
explicit selected control within Interaction Capability, and `quality-in-use` follows the
separate ISO/IEC 25019:2023 model. The v1 IDs, owners, gates and evidence contracts remain stable.

## Product Profile boundary

The following profile fields determine optional applicability:

- `performance_validation` → Performance Efficiency;
- `compatibility_validation` → Compatibility / co-existence;
- `ux_brief_requirement` → Interaction Capability;
- `accessibility_validation` → Accessibility;
- `flexibility_validation` → Flexibility / installability;
- `safety_validation` → Safety.

`required` maps to `REQUIRED`; `not-applicable` maps to `NOT_APPLICABLE`. Functional
Suitability, Reliability, Security, Maintainability and Quality-in-use are always required in
their Cycle 1 scope. Security means SG1–SG4 with profile-directed SG4 applicability; SG5 is
frozen. Reliability means application requirements and design evidence, not client-platform
operations. An N/A is accepted only from the exact current profile revision and never from
executor convenience.

## Machine index

`tracking/quality-characteristics-v1.tsv` has this exact header:

```text
characteristic_id\tapplicability\towner\tevidence_type\tevidence_contract\tgate\tprofile_field\tprofile_value\tminimum_policy\trationale_ref
```

It contains exactly one ordered row for:

`functional-suitability`, `performance-efficiency`, `compatibility`,
`interaction-capability`, `accessibility`, `reliability`, `security`, `maintainability`,
`flexibility-installability`, `safety`, `quality-in-use`.

The remaining columns are fixed by this canonical mapping:

| characteristic_id | profile_field | owner | evidence_type | evidence_contract | gate |
|---|---|---|---|---|---|
| functional-suitability | always-required | s2-po+s5-qa | hybrid | PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1 | GATE2+GATE5 |
| performance-efficiency | performance_validation | s2-test-strategy+s3-arch+s5-perf | hybrid | QUALITY_POLICY_V1+ARCHITECTURE_DECISION_TRACE_V1+S5_VALIDATION_V1 | GATE2+GATE3+GATE5 |
| compatibility | compatibility_validation | s3-arch+s4-qa-auto+s4-techlead | hybrid | ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1 | GATE3+GATE4 |
| interaction-capability | ux_brief_requirement | s2-po+s5-qa | hybrid | PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1 | GATE2+GATE5 |
| accessibility | accessibility_validation | s2-po+s2-qa-req+s5-qa | hybrid | PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1 | GATE2+GATE5 |
| reliability | always-required | s2-ba+s3-arch | hybrid | ARCHITECTURE_DECISION_TRACE_V1 | GATE2+GATE3 |
| security | always-required | s2-security+s3-security+s4-techlead+s5-security | hybrid | SECURITY_SG1_SG4 | GATE2+GATE3+GATE4+GATE5 |
| maintainability | always-required | s3-arch+s4-techlead | hybrid | ARCHITECTURE_DECISION_TRACE_V1+TECH_LEAD_REVIEW | GATE3+GATE4 |
| flexibility-installability | flexibility_validation | s3-arch+s4-qa-auto | hybrid | ARCHITECTURE_DECISION_TRACE_V1+EVIDENCE_V1 | GATE3+GATE4 |
| safety | safety_validation | s1-pmo+s2-ba+s3-arch | hybrid | PMO_CONSTRAINTS+ARCHITECTURE_DECISION_TRACE_V1 | GATE1+GATE3 |
| quality-in-use | always-required | s2-po+s5-qa | hybrid | PRODUCT_ACCEPTANCE_V1+S5_VALIDATION_V1 | GATE2+GATE5 |

Owners and contracts are existing Cycle 1 roles and handoffs. `minimum_policy` is always
`GLOBAL_MINIMUM_OR_STRICTER`; neither the index nor Product Profile can introduce a waiver or
weaker threshold. The effective thresholds still validate through
`_contract/QUALITY_POLICY_V1.md`.

## Obsidian view

`tracking/quality-characteristics.md` is the human-readable view. It uses shared
`_standards/artifact-metadata.md`, binds the current Product Profile revision and exact index,
and contains one section per characteristic with applicability, owner, evidence type,
contract, gate, profile fact, minimum policy and a concrete rationale. The view links
`Dashboard.md` and its Markdown inputs; the TSV remains the authoritative relation.

## Gate convergence

- Gate 2: Must-FR acceptance/UAT trace, interaction and profile-directed accessibility.
- Gate 3: application-level reliability and applicable compatibility, flexibility and safety
  constraints are addressed by architecture evidence without inventing deployment topology.
- Gate 4: applicable integration/contract evidence and a complete Tech Lead maintainability
  review are bound to the exact source and profile revision.
- Gate 5: Must-FR → acceptance → UAT result, representative environment, applicable
  performance/SG4 evidence and quality-in-use approval use S5 Validation v1.

The deterministic checker validates this coverage plan, Obsidian view, profile revision and
only-up policy. Gate validators separately require the referenced result contracts and their
exact artifact/raw evidence refs:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-quality-gates/quality-characteristics-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}"
```

# Architecture Decision Trace Contract v1

This contract makes the existing `s3-arch` design method verifiable without adding a
coordinator or another architecture agent. It applies to architecture decisions and preserves
the sequence:

`confirmed NFR → Quality Attribute → Tactic → Pattern → ADR → explicit trade-off`.

The trace does not make a pattern mandatory when no architecture problem exists. In that case
the HLD records no decision candidate. Once an ADR artifact exists, however, its complete chain
is mandatory and cannot start from an agent preference or an unconfirmed stack/topology.

## HLD binding

The single `ARCH-YYYY-MM-DD-HLD.md` conforms to `_standards/artifact-metadata.md` and adds
these domain fields (the snippet is not a replacement for the common schema):

```yaml
artifact_type: architecture-hld
owner: s3-arch
product_profile_revision: 1
assumption_policy: no-unconfirmed-stack-or-topology
```

It contains `## Architecture Decision Trace` and references every stable id later recorded in
the trace index. Product Profile, NFR, security/test strategy and applicable UX/UAT constraints
are inputs. The marker `assumption_policy` is fail-closed authoring policy, not permission to
invent a default: an absent stack/topology constraint remains an open issue.

The HLD also conforms to `_contract/RUNTIME_CONSTRAINTS_V1.md`. It traces every confirmed
`RC-NNN` from the current NFR and records
`Deployment/operations authorization: NOT_GRANTED`. Runtime constraints filter application
design; they never authorize frozen deployment or operations work.

## ADR binding

Every `ARCH-YYYY-MM-DD-ADR-*.md` uses the same common schema and adds:

```yaml
artifact_type: architecture-decision
owner: s3-arch
product_profile_revision: 1
```

Its body contains one exact set of fields:

```text
Decision ID: DEC-001
NFR: NFR-001
Quality Attribute: QA-Performance
Tactic: TACTIC-Bound-Latency
Pattern: PATTERN-Timeout
ADR: ADR-001
Trade-off gain: ...
Trade-off cost: ...
```

The gain and cost are both non-empty. Alternatives and consequences remain in the full MADR
document; this compact block exists only for deterministic indexing.

## Machine trace index

`stage3-design/outputs/ARCH-decision-trace-v1.tsv` has this exact header:

```text
decision_id\tnfr_id\tquality_attribute_id\ttactic_id\tpattern_id\tadr_id\tadr_uri\tproduct_profile_revision
```

Each ADR file has exactly one row. The NFR id exists in `BA-*-NFR.md`; all chain ids occur in
the HLD and the exact ADR; `adr_uri` is a safe project-relative path; and profile revision
matches the current immutable Product & CI Profile revision. A second unindexed ADR, a guessed
identifier or a missing trade-off blocks Gate 3.

Native API/schema contracts remain separate files and are still produced before production
code when applicable. This trace never replaces them.

## Quality-characteristic scope for schema v5

For Product Profile schema v5 the HLD also contains `## Quality Characteristic Scope` and
binds the current `_contract/QUALITY_CHARACTERISTICS_V1.md` index. It records:

- Reliability and Maintainability as `REQUIRED`, with stable `REL-*` and `MAINT-*` evidence
  ids and the complete relevant dimension lists;
- Performance, Compatibility, Flexibility and Safety exactly as required or not applicable
  in the current Product Profile;
- required Compatibility lists `co-existence,interoperability`; required Flexibility lists
  `install,update,replaceability,configuration-portability` in its HLD dimensions;
- a stable `PERF-*`, `COMPAT-*`, `FLEX-*` or `SAFETY-*` evidence id for every required item;
- `NOT_APPLICABLE: {concrete reason}` for every profile-confirmed N/A.

This is an HLD coverage decision, not a demand for an ADR where no decision candidate exists.
When an ADR is needed, the existing NFR → quality attribute → tactic → pattern → ADR chain
still applies. Application-level reliability is in scope; deployment topology, incident
automation and other frozen Cycle 2/3 operations are not inferred.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/architecture-decision-trace-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}"
```

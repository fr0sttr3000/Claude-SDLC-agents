# Runtime Constraints Contract v1

`Runtime Constraints` is the only active field for confirmed execution-environment capabilities
or limitations that affect application design. It is an open set and does not imply a
container, orchestrator, network service, deployment route or operations mechanism.

The canonical trace is:

`stage1-planning/inputs/idea.md → tracking/PMO-constraints.md → current BA NFR → current HLD`.

## Kickoff normalization

`idea.md` contains exactly one non-empty `Runtime Constraints: ...` line. The legacy
`Deployment Constraint: ...` field is accepted only as kickoff migration input. Kickoff
confirms the value, writes the canonical field and removes the legacy field in the same
authorized update. If both fields exist, kickoff must resolve their conflict explicitly;
neither value silently wins. No legacy field may remain at Gate 2.

`tracking/PMO-constraints.md` records the exact normalized value and source:

```yaml
cycle1:
  runtime_constraints: "confirmed value or unknown"
  runtime_constraints_source: "stage1-planning/inputs/idea.md#Runtime Constraints"
```

The PMO value is lossless: it equals the canonical idea value after optional surrounding
YAML quotes are removed.

## Requirements binding

The current `BA-*-NFR.md` contains:

```text
## Runtime Constraints
Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints
Runtime Constraints scope: application-design-only
Runtime Constraints status: CONFIRMED
RC-001 | capability | measurable constraint | tracking/PMO-constraints.md#cycle1.runtime_constraints
```

Every confirmed item has a unique `RC-NNN` id, kind `capability|limitation`, a concrete
measurable constraint and the exact provenance reference. If the kickoff value is unknown,
the status is `OPEN ISSUE` or `NOT_APPLICABLE`, a concrete owner is present, and no RC row is
invented.

## Architecture and Gate 3 binding

The current HLD contains:

```text
## Runtime Constraints
Runtime Constraints source: stage2-requirements/outputs/{current-NFR}.md#Runtime Constraints
Runtime Constraints scope: application-design-only
Runtime Constraints status: CONFIRMED
Deployment/operations authorization: NOT_GRANTED
RC-001: application-design response to the exact constraint
```

The HLD has exactly the same RC id set as the NFR. An unknown constraint remains an open issue;
it cannot be replaced with assumed stack or topology. The authorization marker is invariant:
Runtime Constraints never authorize build/deploy/publish, infrastructure provisioning,
operations automation or a frozen Cycle 2/3 route.

Gate 2 validates normalization through the NFR. Gate 3 validates the complete chain through
the HLD with:

```bash
bash cycle1-dev/s0-validate/runtime-constraints-check.sh "$PROJECT_PATH" architecture
```

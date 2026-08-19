# Risk Exception Contract v3

Risk Exception is a temporary, typed and independently approved acceptance of one exact set of
non-blocking findings. It never turns a failed mandatory control into PASS, never waives a
zero-tolerance rule and never replaces remediation.

The Project record lives at `tracking/risk-exceptions/{exception_id}.yaml`. It is flat YAML with
exactly these fields, in this order:

```text
schema_version
exception_id
exception_type
finding_severity
tech_debt_id
known_issue_id
owner
approved_by
rationale
scope
check_id
finding_ids
source_revision
subject_digest
created_at
expires_at
status
```

`schema_version` is `3`, `status` is `ACTIVE`, and `exception_id` is `RISK-*`. The record binds
one exact check, source revision, subject digest and comma-separated finding set. Extra,
duplicate or missing finding ids are rejected. `approved_by` is independent from the evidence
producer; neither owner nor approver may be `s4-dev`.

## Typed extensions

| `exception_type` | Exact `finding_severity` |
|---|---|
| `security` | `SECURITY_MEDIUM` |
| `performance` | `PERFORMANCE_THRESHOLD` |
| `quality` | `QUALITY_THRESHOLD` |
| `reliability` | `RELIABILITY_THRESHOLD` |
| `accessibility` | `ACCESSIBILITY_GAP` |
| `compatibility` | `COMPATIBILITY_GAP` |
| `safety` | `SAFETY_GAP` |

Only a consumer that independently derives the type/severity from native evidence may invoke
the validator. Active S5 consumers are `s5-security` and `s5-performance`; the remaining values
reserve one common schema for applicable quality consumers without creating a new route.

Security exceptions cover only open CVSS Medium findings (`4.0–6.9`). Secrets,
dependency-integrity tampering/maliciousness and open CVSS Critical/High cannot be waived.
Security Low (`0.1–3.9`) does not use a Risk Exception: it uses an exact active Tech Debt record.

## Lifecycle binding

Every v3 exception links one active `tracking/tech-debt.md` entry with the same owner,
exception type, finding severity, exact finding ids and Risk Exception id. Canonical typed Tech
Debt fields are `Owner`, `Exception type`, `Finding severity`, `Finding IDs`, `Risk exception`,
`Source sprint`, `Target sprint`, `Дедлайн устранения` and `Статус`; security additionally carries
numeric `CVSS`.

Two independent limits apply to every active v3 exception:

- `expires_at` is after `created_at`, still current and no more than 90 days later;
- `Target sprint` is exactly `Source sprint + 1`, and the remediation deadline is no later than
  the target sprint end recorded under `tracking/sprints/`.

An unresolved `Target sprint: NEXT`, missing sprint boundary or stale/closed Tech Debt record is
`BLOCKED`. Security Low may target any materialized sprint up to `Source sprint + 3`.

`known_issue_id` is `none` unless the finding has user-facing impact. If present, it resolves to
`tracking/known-issues.md`. A user-facing S5 Security Medium finding keeps separate typed
identifiers: `DEF-*` for the defect row, `RISK-*` for the Risk Exception, `KI-*` for the
Known Issue and `TD-*` for remediation debt. The records cross-reference the same exact
`source_finding_id`; identifiers are never reused across namespaces. A Known Issue additionally requires its own
Human Approval v1 from the user or authorized product owner. Known Issue acceptance and
security risk exception are separate decisions: neither replaces the other or Tech Debt
remediation.

Validation is deterministic:

```bash
bash cycle1-dev/s0-validate/risk-exception-check.sh \
  "$PROJECT" "$RECORD" "$CHECK_ID" "$SOURCE_REVISION" "$SUBJECT_DIGEST" \
  "$EVIDENCE_PRODUCER" "$EXACT_FINDING_IDS" "$EXCEPTION_TYPE"
```

Schema v1/v2 records remain historical inputs only. They are `LEGACY / UNVERIFIED` and cannot
close a new gate or completion verdict.

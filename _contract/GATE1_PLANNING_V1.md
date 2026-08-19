# Gate 1 Planning Contract v1

Gate 1 is a semantic decision over one exact Product Profile/source context. A heading,
placeholder, textual signature or risk-line count is not a Gate verdict.

The current feasibility artifact is produced before Finance. It records
`Decision: CONDITIONAL_GO`, `decision_status: PRE_FINANCE` and
`finance_dependency: OPEN`; this is a candidate assessment, never a final GO. It contains
exactly one technical, economic, operational and legal `Axis:` record with verdict, concrete
evidence and owner. A `CONDITIONAL` axis has a unique open `Condition:` record with owner
and resolution action. Scope In/Out contain concrete content.

The Business Case binds the exact feasibility SHA-256 and returns `PASS|CONDITIONAL` with
numeric NPV, ROI and payback. Finance runs before PMO. Gate 1 derives effective `GO` only
when all four axes and Finance pass; otherwise a non-blocking result is
`CONDITIONAL_GO` and every conditional axis (including Finance) has a concrete condition.

The later charter and risk register bind both exact feasibility and Business Case SHA-256
values, the same Product Profile revision/source revision, and the derived
`gate1_decision`. Charter acknowledgement and feasibility acknowledgement are separate
launcher-owned Human Approval v1 records. The risk register has at least ten unique records;
each has category, probability, impact, exact P×I score, owner, mitigation, trigger, status
and a concrete `Constraint` link.

`gate1-planning-check.sh` is the only Gate 1 semantic verdict. Missing/stale bindings,
malformed records, empty sections, duplicate IDs, unapproved human decisions or blocking
Finance produce `GATE 1 PLANNING BLOCKED`.

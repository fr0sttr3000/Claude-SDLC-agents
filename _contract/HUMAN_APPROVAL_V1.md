# Human Approval Contract v1

Human approval is a separate decision record, never a scanner/test/build result. It lives at
`tracking/approvals/{approval_id}.yaml` with flat fields:

`schema_version`, `approval_id`, `approval_origin`, `approver_identity`, `decision`,
`scope`, `rationale`,
`source_revision`, `subject_digest`, `observed_at`.

`approval_origin` is exactly `launcher-human-v1`. The Project record is valid only when a
matching launcher-owned receipt exists in the operator configuration scope and binds the
canonical Project path hash, approval id and exact approval-file SHA-256. Primary agents have
no capability to that receipt scope. A Project YAML without the receipt is unverified even
when every visible field is plausible. The YAML basename is exactly `{approval_id}.yaml`;
renaming an authentic record into another approval namespace is invalid.

`decision` is `APPROVE|REJECT`. The approver must be independent from the Evidence v1 producer
and cannot be `s4-dev`. Source revision and subject digest exactly match the linked machine
record. A valid approval proves who made a human decision about that subject; it never changes
`FAIL|BLOCKED` to `PASS`, and a machine result does not fabricate human consent.

For Known Issue acceptance the approval id begins with `APPROVAL-KI-`. Its `scope` contains
both `known-issue:<KI-ID>` and `defect:<DEF-ID>`. `source_revision` matches Gate 5; the
`subject_digest` is SHA-256 of the canonical defect-index row through `tech_debt_id`, excluding
the later `acceptance_approval_ref` column to avoid a circular digest. The approver is the user
or an authorized product owner and is independent from `s5-qa`. This decision accepts only the
documented user-facing limitation for Cycle 1 completion. It does not change a failed control,
replace a security Risk Exception, or authorize build, publication, release, deploy or
production use.

For full Software DoD the approval id begins with `APPROVAL-DOD-`. Its one-line `scope`
contains every `DOD-1` through `DOD-11` and each current Tech Lead review as
`techlead-review:<project-relative-ref>@<sha256>`. A launcher execution adds the final
`execution-run:<run-id>` member. `dod-approval-check.sh` requires the exact canonical
DoD/review/run scope and revalidates the build subject, source/profile binding, review
metadata/digests and approval independence. An approval from another root or Retry run is not
silently rebound. Automated
`dod-check.sh` success is only `DOD_AUTO_PASS`; the launcher records `DOD_PASS` only after this
separate approval succeeds. On success the launcher also records that exact approval as the
current `dod-approval` logical artifact, bound to the active run id and immutable plan digest;
completion rejects a valid-looking approval that is not current for its execution chain.

For Change Scope the approval id begins with `APPROVAL-SCOPE-`. The exact one-line `scope` is
`change-scope:{scope-id}@{subject-digest}`. The subject digest binds exact source revision,
preparation baseline, Change Intent, Project Map, L1 impact, S3 architecture impact and final
Stage 4 path table. The approver is independent from `s3-arch`; only `APPROVE` can activate the
scope. Every new or expanded digest requires a new approval. A retry may reuse the existing
approval only when the digest is byte-identical and no unresolved launcher-recorded scope
violation exists. Approval authorizes only the named Project paths and never commit, push,
merge, release, deployment or production action.

The human records a decision only through the interactive
`_runtimes/human-approval-record.sh` action outside primary agent dispatch. Roles may prepare
the exact source, subject digest and scope for preview, but must never create, edit, imitate or
confirm the approval or its receipt. When full DoD has no approval for the active run, the
launcher obtains a deterministic request from `dod-approval-check.sh ... request`, displays
the exact values and invokes that action. A rejected, invalid or stale existing record is
reported as BLOCKED and never converted into a repair approval.

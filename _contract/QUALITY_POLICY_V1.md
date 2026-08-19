# Quality Policy Override Contract v1

Global numeric thresholds in `_contract/quality-policy-v1.tsv` are mandatory minima;
`_standards/quality.md` defines their semantics only. Product Profile selects
either `quality_overrides: none` (policy revision `quality-global-v1`) or the versioned
`tracking/quality-gates.md` override (policy revision `quality-v1-r{N}`).

The override is a Project Markdown artifact and first implements the complete common schema from
`_standards/artifact-metadata.md`. Its fixed common binding is
`artifact_type: quality-policy`, `stage: TRACKING`, `producer: s0-quality-gates`; inputs include
the exact Product Profile and outputs include `tracking/quality-gates.md`.

Quality Policy adds these domain fields to the same frontmatter:

`revision`, `previous_revision`, `policy_revision`, `product_profile_revision`, `date`.

Its canonical table columns are `Metric id | Project threshold | Rationale`. The authoritative
machine registry is `_contract/quality-policy-v1.tsv`; it contains exact metric id, operator,
global threshold and unit. The v1 ids are:

`branch_coverage_percent`, `mutation_score_percent`, `test_pass_rate_percent`, `response_time_p95_ms`,
`response_time_p99_ms`, `error_rate_percent`, `availability_percent`, `rto_hours`,
`rpo_hours`, `e2e_automation_percent`, `complexity_max`,
`security_critical_high_max`.

Consumers resolve the effective value through `quality-policy-read.sh`; duplicating numeric
defaults in a gate, role or command is forbidden. Metric evidence binds the exact metric id,
operator, threshold, observed value, unit and effective policy revision.

Threshold syntax is only `>= NUMBER` or `<= NUMBER`. Up metrics cannot be below the global
minimum; down metrics cannot exceed the global maximum. Revision snapshots live in
`tracking/quality-gates-history/revision-{N}.md`. Revision >1 requires immutable
`tracking/quality-policy-invalidations/revision-{N}.md` binding the new revision and
invalidating earlier policy revisions. Each invalidation contains
`previous_snapshot_sha256: {64-hex}`; validation walks the full revision chain, so changing an
old snapshot is detected. Test/build Evidence v1 must carry the exact effective quality policy
revision.
The current file and its revision snapshot are byte-identical mirrors of one logical artifact;
this is the only allowed duplicate `artifact_id`, and only while their bytes are identical.

`/configure` never publishes the policy, characteristic index and Markdown view one by one.
It stages the complete candidate under `tracking/quality-config-candidate/` and invokes
`quality-configuration-commit.sh`. The transaction keeps exact prior copies, installs all
members, runs both deterministic validators and restores the prior complete configuration on
any failure. Revision gaps and existing snapshot/invalidation targets are rejected before the
first publish. An interrupted transaction is recovered before a later attempt can proceed.

# S5 Validation Contract v1

Stage 5 keeps the existing isolated owners and file handoffs:

- `s5-qa-auto`: E2E/API and full affected regression evidence;
- `s5-perf`: applicable performance evidence;
- `s5-security`: applicable SG4 evidence;
- `s5-qa`: test plan, bounded exploratory session, UAT facilitation, one defect register,
  test analysis and Go/No-Go.

No `s5-uat`, `s5-exploratory`, `s5-regression` or `s5-defects` agent is introduced. A human/PO
signs UAT in a separate Human Approval v1 record; the QA agent cannot simulate that approval.

## Profile and exact subject

New/refreshed projects use Product & CI Profile schema v5. Schema v4 remains readable for
existing projects. `_contract/APPLICABILITY_V1.md` is the only resolver of performance,
runtime-security, interaction and accessibility scope. Both profile versions confirm a representative
environment identity/authorization and independent applicability of performance and runtime
security validation. `not-available` is a truthful discovery fact but cannot close required
automation, exploratory or UAT streams.

For schema v5 the standalone validator also requires a current verified Quality
Characteristics v1 index. Functional Suitability and Quality-in-use remain always required;
performance/SG4 N/A must agree with both the profile and the exact stream records.

The S5 validator verifies the current Evidence v1 `build` record and derives one tuple:

`source_revision + subject_digest + build_identity + product_profile_revision`.

Every S5 stream, report, approval and Gate 5 decision uses exactly that tuple. Source-only work
uses `subject_digest: none` and `build_identity: none`; no release artifact is invented.

## Stream index and raw results

`tracking/validation/S5-validation-v1.tsv` has the exact header:

```text
stream_id\towner\tapplicability\tverdict\tsource_revision\tsubject_digest\tbuild_identity\tenvironment_id\traw_format\traw_result_uri\traw_result_sha256\tfinding_ids\tenvironment_approval_ref\thuman_approval_ref\trisk_exception_ref
```

It contains exactly one row for `automation`, `performance`, `security`, `exploratory`, and
`uat`. Required streams use a Product Profile environment and an independent APPROVE record in
`tracking/approvals/`. Raw files are immutable-by-digest project paths:

- automation JSON: `test_results` contains unique `TEST-*` rows and counters derived from them;
  `critical_path_results` is an exact set match to every `UAT-*` in
  `UAT-product-acceptance-v1.tsv`; `criterion_results` is an exact set match to all required
  `UXC-*` and `A11Y-*` criteria in the one current UX brief; no required result may be
  missing, failed or skipped;
- automation `quality_metrics` contains exactly `test_pass_rate_percent` and
  `e2e_automation_percent`, each with metric id, operator, effective threshold, independently
  derived observed value, unit, policy revision and matching PASS verdict;
- performance JSON: `quality_metrics` contains unique supported metric ids; every operator,
  threshold, unit and policy revision exactly matches `quality-policy-read.sh`, while
  `metrics_total/evaluated/failed` are derived from the metric rows;
- security JSON: `scenario_results` is an exact set match to stable `SEC-SCENARIO-*` ids in
  the one current SG1 requirements artifact plus the one current SG2 threat model; counters
  are derived from these rows, and findings preserve raw numeric CVSS/status;
- exploratory Markdown: bounded charter, observations and findings;
- UAT TSV: every original S2 `UAT-*` scenario, exact environment/source and PASS/FAIL.

Structured `NOT_APPLICABLE` is accepted only for resolver-confirmed performance/security N/A
and includes the exact Product Profile revision, applicability owner and reason emitted by the
resolver in normalized JSON. Required automation,
exploratory and UAT cannot be N/A. `CONDITIONAL_PASS` requires a separate active Risk Exception
v3 from `_contract/RISK_EXCEPTION_V3.md`. Security exceptions cover exactly the open Medium ids
derived from raw CVSS; performance exceptions use the typed `performance` extension. Open SG4
CVSS ≥7 is never accepted.

UAT requires a second Human Approval v1 record whose scope contains the exact UAT ids and
environment. Environment authorization and UAT acceptance are different decisions.

The Quality Characteristics index is a Stage-1 coverage plan: it names owners/contracts/gates,
not a successful test result. Actual evidence references and exact scope rows live in the
digest-bound S2/S4/S5 indexes above. A contract name without those raw references cannot close
Gate 5.

## Reports, analysis and one defect register

Existing role reports remain distinct Markdown summaries bound to the same source/subject:
`AUTO-*-e2e-report.md`, `AUTO-*-coverage.md`, `PERF-*-report.md`,
`SEC-*-pentest-report.md`, and `QA-*-exploratory-report.md`.

Every S5 governance Markdown artifact uses shared `_standards/artifact-metadata.md`. The fields
below (`owner`, subject/build/environment bindings, index digests and verdict) are S5 domain
extensions; they do not replace or redefine shared `producer`, inputs/outputs or Obsidian links.
Gate 5 runs `artifact-metadata-check.sh` for each S5 Markdown input before accepting it.

Only `s5-qa` creates:

- one `DEF-YYYY-MM-DD-defects.md` plus `DEF-defects-v1.tsv`;
- one `QA-YYYY-MM-DD-test-analysis.md` with Failure Analysis, Flaky Tests, Coverage Gaps and
  Quality Trend;
- one `QA-YYYY-MM-DD-go-no-go.md`.

The defect index header is:

```text
defect_id\tsource_stream\tsource_finding_id\tseverity\tuser_facing\tdisposition\tknown_issue_id\ttech_debt_id\tacceptance_approval_ref
```

Every stream finding occurs exactly once. Security severity is derived from raw numeric CVSS,
not trusted from the defect row. S1/S2 and CVSS Critical/High are closed or blocking; an open
blocker prevents GO. Every open Security Medium/Low row has an exact active `tech_debt_id`:
Medium matches the stream Risk Exception and next-sprint SLA; Low has no exception and is due
within three sprints. User-facing S3/S4 or Security Medium/Low uses `KNOWN_ISSUE` plus a complete
OPEN KI record, exact Tech Debt/Patch SLA and a separate APPROVE Human Approval v1. The approval
scope contains the exact KI and defect ids; its subject digest binds the canonical defect row
through `tech_debt_id`, excluding `acceptance_approval_ref`. A user-facing Security Medium KI
also matches a separate Risk Exception v3; neither decision replaces the other. Missing,
rejected, wrong-source or wrong-defect approval blocks Gate 5. Parallel defect lists are rejected.
The canonical Known Issue template and `known-issue-lifecycle-check.sh` define the same exact
fields. Gate 5 accepts only an `OPEN` KI with all Fix/cleanup fields set to `none` and an active
linked Tech Debt/Patch SLA. Later `FIXED` transition requires released Build Evidence v1 and a
synchronously `RESOLVED` Tech Debt; a green validation report alone is insufficient.

The Go/No-Go frontmatter binds the stream/defect index digests, Product Profile revision,
exact source/build tuple and UAT approval. A Markdown `GATE 5 PASSED` without these verified
inputs is not a gate verdict. Gate 5 validates Cycle 1 only and never authorizes deploy.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/s5-validation-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" "{FULL_SOURCE_REVISION}"
```

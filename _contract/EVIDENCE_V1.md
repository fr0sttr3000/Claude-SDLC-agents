# Evidence Contract v1

Evidence Contract v1 is the runtime-neutral, machine-verifiable handoff for Cycle 1 test,
security, build and policy checks. It consumes results from the executor already selected in
Product & CI Profile schema v2, v3, v4 or v5. Core does not create, administer or silently modify a vendor
pipeline.

## Storage and authority

- Machine records: `tracking/evidence/v1/{evidence_id}.yaml`.
- Native raw results: `tracking/evidence/raw/` in one of the formats declared by the profile.
- Generated human summary: `stage4-dev/outputs/EVIDENCE-{source_revision_safe}.md`; a
  `sha256:` prefix is filename-encoded as `sha256-` for cross-platform paths.
- Human approval: a separate record under `tracking/approvals/` per
  `_contract/HUMAN_APPROVAL_V1.md`; it never changes a machine result.
- Risk exception: a separate expiring record under `tracking/risk-exceptions/`; it never turns
  a failed or blocked scanner result into `PASS`.

The YAML record is flat UTF-8: exactly one unique `lower_snake_case: scalar` per line. Markdown
is a generated view and is never accepted as raw evidence or as a machine verdict.

## Required fields

`schema_version: 1` and:

- identity: `evidence_id`, `check_id`, `category`;
- execution: `source_profile`, `execution_mode`, `executor_identity`, `producer_identity`;
- producer/tool: `tool_name`, `tool_version`;
- binding: `source_revision`, `subject_kind`, `subject_digest`, `build_identity`;
- policy: `config_revision`, `policy_revision`, `product_profile_revision`;
- freshness: `observed_at`, `freshness_seconds`;
- native result: `raw_format`, `raw_result_uri`, `raw_result_sha256`, `signature_status`;
- result: `verdict`, `applicability_reason`, `applicability_owner`;
- trace: `requirement_ids`, `specification_ids`, `test_ids`;
- separate decisions: `human_approval_ref`, `risk_exception_ref`.

`source_revision` is a full 40/64-hex revision or `sha256:{64-hex}`. A source-only check uses
`subject_kind: source`, `subject_digest: none`, `build_identity: none`. A real build/package/
image subject requires both an immutable `sha256:` digest and build identity. Source-only work
is not blocked by a missing image or release artifact: affected checks instead carry structured
`NOT_APPLICABLE` evidence.

## Verdict and verification state

The producer records one machine result:

- `PASS` — the check passed;
- `FAIL` — the check ran and failed;
- `BLOCKED` — the required check could not produce a valid result;
- `NOT_APPLICABLE` — the named check does not apply to this subject.

`VERIFIED|UNVERIFIED` is derived by `s0-validate`, not self-asserted by the producer. Verification
checks schema, exact source/subject binding, Product Profile revision, trusted producer and
executor, native-format capability, raw digest, configured freshness and signature policy.
Only `VERIFIED PASS` or a structured `VERIFIED NOT_APPLICABLE` can satisfy a check. A verified
`FAIL`/`BLOCKED` still blocks the gate.

Trace ids resolve through `_contract/TRACEABILITY_V1.md`; non-empty strings alone are not
sufficient. The indexed requirement/specification/test artifacts must exist, contain their ids
and bind the same exact source revision.

`NOT_APPLICABLE` requires a non-empty reason and owner plus the exact Product Profile revision.
Free text `N/A` in Markdown is not a verdict. `execution_mode: proposal` is always
`UNVERIFIED`, including an offline pipeline proposal; only `execution_mode: live` can verify.

## Minimum PR interface

Product Profile schema v2, v3, v4 or v5 declares all minimum check ids:

`build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,`
`pipeline-policy,image-scan,sbom`.

Every id has one current record for the exact source revision. Applicability is expressed by
the record, not by deleting a required check. Repository CI additionally declares
`evidence_merge_blocking: required`; connected and local validators are evidence sources, not
a universal CI control plane.

For schema v5, `compatibility_validation: required` requires `PASS` for both integration and
contract checks. `not-applicable` requires structured `NOT_APPLICABLE` for both. The
profile-bound Quality Characteristics v1 index must also validate; free-text N/A cannot
weaken the Gate 4 minimum set.

Native v1 normalization is limited to configured `junit|tap|sarif|json`. JUnit/TAP counters
must agree with the evidence verdict; SG3 deterministically evaluates SARIF or its normalized
JSON envelope. SBOM/provenance is required only when Product Profile declares an applicable
artifact subject and capability.

Validate one record:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/evidence-v1-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" \
  "$SDLC_PROJECTS_DIR/{PROJECT}/tracking/evidence/v1/{evidence_id}.yaml" \
  --expected-source "{FULL_SOURCE_REVISION}" --expected-check "{CHECK_ID}"
```

Generate a Markdown view only after verification:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/evidence-v1-summary.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}" "{FULL_SOURCE_REVISION}" \
  > "$SDLC_PROJECTS_DIR/{PROJECT}/stage4-dev/outputs/EVIDENCE-{FULL_SOURCE_REVISION_SAFE}.md"
```

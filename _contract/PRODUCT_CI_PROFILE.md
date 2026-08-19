# Product & CI Profile Contract

`$SDLC_PROJECTS_DIR/{PROJECT}/tracking/product-ci-profile.yaml` is the mandatory,
runtime-neutral discovery handoff before Stage 1. `s0-kickoff` collects or refreshes facts;
`s0-validate` validates them deterministically. Neither role chooses product, SCM, CI,
architecture, build tooling or policy for the stakeholder.

## Storage and revision

- Current profile: `tracking/product-ci-profile.yaml`.
- Immutable copy: `tracking/product-ci-profile-history/revision-{N}.yaml`.
- `revision` starts at 1; `previous_revision` is exactly `revision - 1`.
- Every content change creates the next revision and identical immutable copy.
- Revision > 1 requires `tracking/evidence-invalidations.md` with
  `profile_revision: N` and `invalidates: revisions<N`.
- Evidence bound to an older profile revision is `UNVERIFIED`; a revision change never
  silently preserves its verdict.

## Format

The file is flat UTF-8 YAML: one unique `lower_snake_case: scalar` per line, without
nested mappings, multiline values or secret values. Metadata fields are:

`schema_version`, `revision`, `previous_revision`, `updated_at`, `revision_reason`.

Fact fields are:

`product_type`, `scm_repository_model`, `scm_branch_policy`, `scm_review_policy`,
`scm_required_checks`, `ci_provider`, `ci_runners`, `ci_trust_boundary`,
`ci_report_formats`, `build_toolchain`, `build_command`, `package_command`,
`build_output_contract`, `secret_provider`, `ci_identity_references`,
`compliance_constraints`, `offline_mode`, `approval_constraints`, `quality_overrides`.

Schema version 2 adds the Evidence Contract boundary:

`evidence_source_profile`, `evidence_repository_path`, `evidence_executor_identity`,
`evidence_trusted_producers`, `evidence_freshness_seconds`, `evidence_signature_policy`,
`evidence_merge_blocking`, `build_subject`, `sbom_requirement`.

Schema version 3 retains the complete Evidence boundary and adds Product Acceptance
applicability:

`user_interface`, `ux_brief_requirement`.

Schema version 4 retains the complete Evidence/Product Acceptance boundary and adds S5
validation applicability:

`validation_environment_profile`, `validation_environment_identity`,
`validation_environment_authorization`, `performance_validation`,
`runtime_security_validation`.

Schema version 5 retains every earlier boundary and adds explicit quality-characteristic
applicability:

`compatibility_validation`, `accessibility_validation`, `flexibility_validation`,
`safety_validation`.

Schema version 5 may also contain the complete architecture applicability group:

`api_contract_design`, `data_store_design`, `authorization_design`.

Schema version 5 may additionally contain
`environment_format_validation: required|not-applicable` with its provenance. Every new or
refreshed schema-v5 profile records it. Older schema-v5 profiles remain readable, but a
profile-aware DoD-11 check fails closed until the fact is confirmed.

The three fields and their provenance are all-or-none for backward readability. Every new or
refreshed schema-v5 profile records all three. An older schema-v5 profile without this group
remains readable, but Gate 3 fails closed until a new revision is confirmed.

Schema versions 1–4 remain readable for existing Cycle 1 projects. Earlier schemas do not
contain enough applicability data to produce a verified Quality Characteristics v1 index.
Schema version 1 also does not contain enough
trust data to produce `VERIFIED` Evidence Contract v1 records; evidence validation therefore
fails closed until `s0-kickoff` creates a new schema-version-5 profile revision and its
invalidation record.

Every fact has the adjacent field `{fact}_provenance` with one of
`observed|user-confirmed|inferred|unknown`. The schema records all four states, but active
Cycle 1 completeness accepts only `observed|user-confirmed`; mandatory `inferred|unknown`
is `BLOCKED` until confirmation.

Enums:

- `product_type`: `service|library|cli|desktop|mobile|data-job|other`;
- `scm_repository_model`: `single-repo|monorepo|multi-repo|none`;
- `offline_mode`: `online|offline|air-gapped`;
- `secret_provider`: exactly `pass`;
- `quality_overrides`: `none|tracking/quality-gates.md`.
- `evidence_source_profile`: `repository-ci|connected-runner|local-offline`;
- `evidence_signature_policy`: `required|if-produced|not-supported`;
- `evidence_merge_blocking`: `required|not-applicable`;
- `build_subject`: `source-only|build-artifact|image`;
- `sbom_requirement`: `required|not-applicable`.
- `user_interface`: `graphical|terminal|api-only|library-only|none`;
- `ux_brief_requirement`: `required|not-applicable`.
- `validation_environment_profile`:
  `connected-representative|local-representative|not-available`;
- `validation_environment_authorization`: `required|not-applicable`;
- `performance_validation`, `runtime_security_validation`: `required|not-applicable`.
- `compatibility_validation`, `accessibility_validation`, `flexibility_validation`,
  `safety_validation`: `required|not-applicable`.
- `api_contract_design`, `data_store_design`, `authorization_design`:
  `required|not-applicable`.
- `environment_format_validation`: `required|not-applicable`.

`none` and `not-applicable` are explicit confirmed facts, not synonyms for unknown. When
`ci_provider: none`, runners, trust boundary and report formats are `not-applicable`.
Build/package commands and output contracts describe validation inputs; the collector and
core launcher do not execute a release build.

For schema versions 2, 3, 4 and 5:

- `evidence_repository_path` is an existing project-relative path and cannot traverse outside
  Project;
- executor and trusted producer identities are confirmed references, never credentials;
- `ci_report_formats` is a supported subset of `junit,tap,sarif,json` and declares at least
  one test and one security format;
- `scm_required_checks` contains the full minimum v1 check set:
  `build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,`
  `pipeline-policy,image-scan,sbom`; a check may later resolve to structured
  `NOT_APPLICABLE`, but cannot disappear;
- repository CI has required merge blocking; local/offline evidence cannot claim repository
  merge control;
- `source-only` explicitly makes SBOM not applicable because no artifact subject exists.

For schema versions 3, 4 and 5, `graphical|terminal` requires `ux_brief_requirement: required`;
`api-only|library-only|none` requires `not-applicable`. The resulting UX artifact is governed
by `_contract/PRODUCT_ACCEPTANCE_V1.md`; the profile never infers applicability from a tool or
stack name.

Schema versions 4 and 5 do not invent a shared test platform. A connected/local representative
environment requires a concrete identity and explicit authorization; `not-available` records
identity/authorization as `not-applicable` and causes applicable S5 streams to remain BLOCKED.
PERF and runtime security applicability are separately confirmed from NFR/risk facts rather
than inferred from `product_type`.

Schema version 5 supplies the applicability inputs to
`_contract/QUALITY_CHARACTERISTICS_V1.md`. Each value is observed or explicitly confirmed;
it is never inferred from `product_type`, stack or the convenience of the executor.
`accessibility_validation: required` requires `ux_brief_requirement: required`;
non-UI applicability therefore remains explicitly `not-applicable`. A profile chooses only
whether a characteristic-specific check applies. It cannot waive or lower any global minimum
from `_standards/quality.md` or `_contract/QUALITY_POLICY_V1.md`.

The architecture group is confirmed separately from product type and stack: an executable or
library may still expose an API, persist data or enforce authorization, while a service may do
none of them. `_contract/APPLICABILITY_V1.md` is the only resolver used by roles and gates.

## Scope boundary

The profile contains Cycle 1 product/build/test/CI facts only. Deploy targets,
environments, registries, rollout, orchestrators, monitoring, alert routing, incidents,
backup/DR and other Cycle 2/3 delivery/operations fields are forbidden while frozen.
Identity references name a CI principal/capability only; tokens, credentials and secret
values are forbidden.

Validate with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/product-ci-profile-check.sh" \
  "$SDLC_PROJECTS_DIR/{PROJECT}"
```

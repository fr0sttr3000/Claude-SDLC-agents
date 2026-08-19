# Applicability Contract v1

Applicability for active Cycle 1 capabilities has one machine authority:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/applicability-resolve.sh" \
  resolve "$SDLC_PROJECTS_DIR/{PROJECT}" <capability>
```

The Product & CI Profile stores confirmed facts. The resolver validates the current immutable
profile revision and emits exactly one TSV row:

`capability, applicability, profile_field, profile_value, product_profile_revision,`
`applicability_owner, applicability_reason`.

`applicability` is exactly `REQUIRED|NOT_APPLICABLE`. Roles, gates and validators consume this
result; they must not infer applicability from product type, framework, language, topology or
the presence/absence of a convenient tool.

## Capability mapping

| Capability | Product Profile authority |
|---|---|
| `api-contract` | `api_contract_design` |
| `environment-format` | `environment_format_validation` |
| `data-store` | `data_store_design` |
| `authorization` | `authorization_design` |
| `performance` | `performance_validation` |
| `runtime-security` | `runtime_security_validation` |
| `interaction` | `ux_brief_requirement` |
| `accessibility` | `accessibility_validation` |
| `compatibility` | `compatibility_validation` |
| `flexibility` | `flexibility_validation` |
| `safety` | `safety_validation` |
| `sbom` | `sbom_requirement` |
| `image-scan` | `build_subject` (`image` means required) |

Missing authoritative input is `BLOCKED`, never an implicit N/A. Existing schema-v5 profiles
without the architecture applicability group remain readable, but Gate 3 is blocked until
`s0-kickoff /product-ci-profile` records all three architecture facts in a new revision.

## Structured Stage 3 N/A

For `api-contract`, `data-store` and `authorization`, a `NOT_APPLICABLE` Gate 3 result requires
one Markdown `applicability-decision` owned by the normal producer (`s3-arch`, `s3-dba` or
`s3-rbac`). It composes `_standards/artifact-metadata.md` and adds these exact fields:

```yaml
status: NOT_APPLICABLE
source_revision: none
capability: api-contract
applicability: NOT_APPLICABLE
profile_field: api_contract_design
profile_value: not-applicable
product_profile_revision: 3
applicability_owner: s0-kickoff
applicability_reason: stakeholder confirmed there is no external API boundary
```

`inputs` includes `tracking/product-ci-profile.yaml`. Capability, field, value, revision, owner
and reason must exactly match the resolver output. A plain Markdown statement, stale revision,
N/A contrary to a `REQUIRED` profile, or simultaneous required/N/A artifacts is rejected.

Validate a Stage 3 decision with:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/applicability-resolve.sh" \
  validate "$SDLC_PROJECTS_DIR/{PROJECT}" api-contract \
  stage3-design/outputs/ARCH-YYYY-MM-DD-api-not-applicable.md s3-arch
```

S5 and PR streams retain their native JSON/YAML `NOT_APPLICABLE` evidence contracts, but their
expected applicability is obtained from this same resolver.

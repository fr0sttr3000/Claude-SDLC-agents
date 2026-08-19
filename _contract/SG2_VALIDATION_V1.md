# SG2 Validation Contract v1

Gate 3 accepts the current `threat-model` only after `s0-validate/sg2-check.sh` verifies
its binding and trace semantics.

Required unique scalar fields are `product_profile_revision`, `sg1_sha256`, `hld_sha256`,
`asvs_version`, `api_applicability`, `authorization_applicability`, `component_scope`
and `sg2_status`. The digests bind the design decision to the exact current SG1 and HLD.
The checker reruns SG1 semantic validation and resolves API/authorization applicability from
the same current Product Profile authority used by Gate 3. Both applicability fields are
exactly `REQUIRED|NOT_APPLICABLE` and must match that resolver. The ASVS version is exactly
`5.0.0` and matches SG1; only `PASS` advances Gate 3.

Every SG1 scenario and every comma-separated component in `component_scope` is covered by a
unique trace:

```text
Threat trace: THREAT-001 | Scenario: SEC-SC-001 | Component: CMP-API | Control: CTRL-001 | Test: SEC-TEST-001 | ASVS: v5.0.0-1.2.3 | Severity: Medium | Status: MITIGATED
```

Severity is `Critical|High|Medium|Low|None`; status is `OPEN|MITIGATED|CLOSED`.
An OPEN Critical/High trace blocks Gate 3. Every trace must carry exact scenario, declared
component, control, unique negative/security-test and versioned ASVS identifiers. Its ASVS
reference must equal the reference on the bound SG1 scenario; malformed or extra traces block.

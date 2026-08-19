# SG1 Validation Contract v1

Gate 2 accepts the current `security-requirements` artifact only after
`s0-validate/sg1-check.sh` verifies it semantically.

Required unique scalar fields are:

`product_profile_revision`, `brd_sha256`, `nfr_sha256`, `backlog_sha256`,
`constraints_sha256`, `asvs_version`, `asvs_level`, `data_classification_scope`,
`critical_fr_scope` and `sg1_status`.

The profile revision and four SHA-256 values bind SG1 to the current Product Profile,
business requirements, NFR, backlog and project constraints. `asvs_version` is exactly
`5.0.0`, level is `L1|L2|L3`, and the only Gate-advancing status is `PASS`.

Every unique ID in the comma-separated `data_classification_scope` has exactly one record:

```text
Data classification: DATA-001 | Entity: account-metadata | Class: internal | Rationale: authenticated account context
```

Class is exactly `public|internal|confidential|PII|secret`; every declared record has a
concrete rationale, and undeclared or duplicate records are blocked.

Every comma-separated FR in `critical_fr_scope` has at least one unique machine-readable line:

```text
Scenario: SEC-SC-001 | FR: FR-001 | Abuse: ABUSE-001 | ASVS: v5.0.0-1.2.3 | Countermeasure: SEC-NFR-001
```

Scenario, abuse and scope IDs, versioned ASVS references, labels and exact coverage are
validated; malformed records, prose or a heading cannot replace these records.

# SG3 Policy Contract v1

SG3 keeps agent isolation and separates three responsibilities:

1. the executor selected in Product & CI Profile creates native immutable scan results;
2. `s0-validate` verifies Evidence Contract v1 and applies this deterministic policy;
3. `s4-techlead` reviews the verified SG3 output and signs Gate 4. A developer or code-writing
   agent cannot produce the scanner result, apply the policy, or sign its own SG3 verdict.

The v1 policy revision is `security-v1`:

- secret findings: exactly zero, with no exception;
- Critical/High findings (`CVSS >= 7.0`): block, with no exception;
- open Medium findings (`4.0 <= CVSS < 7.0`): block unless every id is covered by one valid,
  scoped and unexpired risk exception;
- tampered or malicious dependencies: exactly zero, with no exception;
- dependency/lockfile integrity: `pass`;
- image scan is required only for `build_subject: image`; otherwise its Evidence v1 record is
  structured `NOT_APPLICABLE`;
- SBOM is controlled by Product Profile applicability and the PR evidence aggregator, not
  fabricated for source-only work.

JSON security results use this normalized native envelope:

```json
{
  "schema_version": 1,
  "check_id": "sast",
  "source_revision": "FULL_SHA_OR_DIGEST",
  "secret_count": 0,
  "integrity_status": "pass",
  "tampered_dependencies": 0,
  "malicious_dependencies": 0,
  "findings": [{"id": "CVE_OR_RULE_ID", "cvss": 5.5, "status": "open"}]
}
```

`status` is `open|fixed`. Producer-side suppression does not waive policy. SARIF 2.1.0 is also
accepted for SAST/SCA/secrets/image results when each non-secret result supplies numeric CVSS in
`properties.security-severity`, `properties.cvss`, or `properties["cvss"]`. Dependency integrity
uses the normalized JSON envelope.

## Security extension of Risk Exception v3

`_contract/RISK_EXCEPTION_V3.md` is the common authoritative schema and lifecycle. SG3 accepts
only `exception_type: security` with `finding_severity: SECURITY_MEDIUM`, exact open Medium ids
derived from native evidence and a matching typed Tech Debt entry. Secrets, dependency
tampering/maliciousness and Critical/High findings remain zero-tolerance. Security Low uses an
exact active Tech Debt lifecycle without a Risk Exception.

# Executor Controls Contract v1

Core consumes the executor selected in Product & CI Profile; it does not generate or administer
the customer's CI pipeline. The exact-source `pipeline-policy` Evidence v1 record carries a
normalized JSON result with policy revision `executor-controls-v1`:

```json
{
  "schema_version": 1,
  "check_id": "pipeline-policy",
  "source_revision": "FULL_SHA_OR_DIGEST",
  "controls": {
    "immutable_dependencies": "pass",
    "least_privilege": "pass",
    "untrusted_pr_isolation": "pass",
    "protected_policy_files": "pass",
    "artifact_cache_integrity": "pass"
  },
  "remediation": []
}
```

Every control is `pass|fail|unknown|not-applicable`. Immutable dependencies, least privilege,
protected policy files and artifact/cache integrity are always applicable. Untrusted-PR
isolation is mandatory for repository CI and connected runners; a local/offline validator may
use `not-applicable`. `fail|unknown` or an invalid N/A returns `BLOCKED` with remediation from
the selected executor owner. No secret, credential or raw environment value belongs in this
record.

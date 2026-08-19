# Quality Metric Evidence Contract v1

Numeric quality claims are accepted only from digest-bound JSON raw evidence produced by the
trusted executor selected in Product & CI Profile. File existence, counters without metric ids,
and an agent-written PASS are not metric evidence.

The relevant Evidence v1 raw JSON contains `quality_metrics`, an array of exact objects:

```json
{
  "metric_id": "branch_coverage_percent",
  "operator": ">=",
  "threshold": 80,
  "observed": 91.2,
  "unit": "percent",
  "verdict": "PASS",
  "policy_revision": "quality-global-v1"
}
```

The validator resolves `metric_id` through `quality-policy-read.sh` and requires the exact
effective operator, threshold, unit and policy revision. It independently derives PASS/FAIL
from `observed`; a contradictory self-verdict is rejected. Metric ids are unique.

Active PR minimum mappings are:

- `unit`: `branch_coverage_percent`, `mutation_score_percent`;
- `lint`: `complexity_max`.

The JSON is the `raw_result_uri` of the same Evidence v1 record, so its SHA-256, source revision,
trusted producer, freshness and profile/policy binding are verified by Evidence Contract v1.
New metric consumers use the same object shape and authoritative registry; they do not copy
numeric defaults into validators.

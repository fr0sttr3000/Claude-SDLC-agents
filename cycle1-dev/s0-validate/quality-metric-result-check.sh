#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
RECORD_INPUT="${2:?Укажи Evidence v1 record}"
REQUIRED_METRICS="${3:?Укажи comma-separated required metric ids}"
blocked() { echo "QUALITY METRIC BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$RECORD_INPUT" == /* ]] || RECORD_INPUT="$PROJECT_PATH/$RECORD_INPUT"
[[ -f "$RECORD_INPUT" && ! -L "$RECORD_INPUT" ]] || blocked 'Evidence record missing/symlink'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
POLICY_READER="$SCRIPT_DIR/../s0-quality-gates/quality-policy-read.sh"
command -v jq >/dev/null 2>&1 || blocked 'jq capability отсутствует'

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

check_id="$(field "$RECORD_INPUT" check_id)"
case "$check_id" in unit|lint) ;; *) blocked "unsupported metric evidence check: $check_id" ;; esac
bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$RECORD_INPUT" \
  --expected-check "$check_id" >/dev/null || blocked 'base Evidence v1 invalid'
[[ "$(field "$RECORD_INPUT" verdict)" == PASS ]] || blocked 'metric Evidence record must PASS'
[[ "$(field "$RECORD_INPUT" raw_format)" == json ]] ||
  blocked 'quality metric Evidence requires digest-bound JSON'
raw="$PROJECT_PATH/$(field "$RECORD_INPUT" raw_result_uri)"
jq -e '
  (.quality_metrics | type == "array") and (.quality_metrics | length > 0) and
  all(.quality_metrics[];
    ((keys | sort) == ["metric_id","observed","operator","policy_revision","threshold","unit","verdict"]) and
    (.metric_id | type == "string" and test("^[a-z][a-z0-9_]*$")) and
    (.operator == ">=" or .operator == "<=") and (.threshold | type == "number") and
    (.observed | type == "number") and (.unit | type == "string" and length > 0) and
    (.verdict == "PASS" or .verdict == "FAIL") and
    (.policy_revision | type == "string" and length > 0))
' "$raw" >/dev/null || blocked 'invalid quality_metrics JSON schema'

declare -A seen=()
while IFS=$'\t' read -r metric operator threshold observed unit verdict policy_revision extra; do
  [[ -z "$extra" && -z "${seen[$metric]+x}" ]] || blocked "duplicate/invalid metric row: $metric"
  seen["$metric"]=1
  case "$check_id:$metric" in
    unit:branch_coverage_percent|unit:mutation_score_percent|lint:complexity_max) ;;
    *) blocked "metric $metric is not owned by check=$check_id" ;;
  esac
  IFS=$'\t' read -r _ expected_operator expected_threshold expected_unit expected_policy expected_profile extra_policy < <(
    bash "$POLICY_READER" "$PROJECT_PATH" "$metric"
  ) || blocked "effective policy unavailable for metric=$metric"
  [[ -z "$extra_policy" && "$operator" == "$expected_operator" && "$unit" == "$expected_unit" &&
      "$policy_revision" == "$expected_policy" ]] || blocked "metric=$metric policy binding mismatch"
  awk -v actual="$threshold" -v expected="$expected_threshold" 'BEGIN { exit !(actual == expected) }' ||
    blocked "metric=$metric threshold differs from effective policy"
  derived=FAIL
  if [[ "$operator" == '>=' ]]; then
    awk -v value="$observed" -v limit="$threshold" 'BEGIN { exit !(value >= limit) }' && derived=PASS
  else
    awk -v value="$observed" -v limit="$threshold" 'BEGIN { exit !(value <= limit) }' && derived=PASS
  fi
  [[ "$verdict" == "$derived" ]] || blocked "metric=$metric self-verdict contradicts observed value"
  [[ "$derived" == PASS ]] || blocked "metric=$metric failed effective threshold"
done < <(jq -r '.quality_metrics[] |
  [.metric_id,.operator,(.threshold|tostring),(.observed|tostring),.unit,.verdict,.policy_revision] | @tsv' "$raw")

IFS=',' read -r -a required <<< "$REQUIRED_METRICS"
for metric in "${required[@]}"; do
  [[ -n "${seen[$metric]:-}" ]] || blocked "required metric missing: $metric"
done
(( ${#seen[@]} == ${#required[@]} )) || blocked 'raw contains undeclared extra quality metrics'

echo "QUALITY METRICS VERIFIED: check=$check_id source=$(field "$RECORD_INPUT" source_revision) metrics=$REQUIRED_METRICS"

#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${1:?usage: sg2-check.sh <PROJECT_PATH>}"
[[ -d "$PROJECT_PATH" ]] || { echo "SG2 BLOCKED: Project not found" >&2; exit 2; }
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT="$HERE/current-artifact.sh"
SG1_CHECK="$HERE/sg1-check.sh"
APPLICABILITY="$HERE/applicability-resolve.sh"

fail() { echo "SG2 BLOCKED: $*" >&2; exit 1; }
field() {
  local file="$1" key="$2" count
  count="$(awk -F: -v key="$key" '$1 == key {n++} END {print n+0}' "$file")"
  [[ "$count" == 1 ]] || fail "$key must occur exactly once"
  awk -F: -v key="$key" '$1 == key {v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); print v}' "$file"
}
current_file() {
  local ref
  ref="$(bash "$CURRENT" resolve-compatible-one "$PROJECT_PATH" "$1" 2>/dev/null)" ||
    fail "current $1 is missing or ambiguous"
  printf '%s/%s\n' "$PROJECT_PATH" "$ref"
}
check_digest() {
  local artifact="$1" key="$2" source="$3" expected actual
  expected="$(field "$artifact" "$key")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || fail "$key is not SHA-256"
  actual="$(sha256sum "$source" | awk '{print $1}')"
  [[ "$expected" == "$actual" ]] || fail "$key is stale"
}

PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
[[ -f "$PROFILE" ]] || fail 'Product Profile is missing'
[[ "$(field "$PROFILE" schema_version)" == 5 ]] || fail 'Product Profile schema 5 is required'
PROFILE_REVISION="$(field "$PROFILE" revision)"
[[ "$PROFILE_REVISION" =~ ^[1-9][0-9]*$ ]] || fail 'invalid Product Profile revision'

SG1="$(current_file security-requirements)"
HLD="$(current_file high-level-design)"
SG2="$(current_file threat-model)"
if ! sg1_output="$(bash "$SG1_CHECK" "$PROJECT_PATH" 2>&1)"; then
  fail "current SG1 semantic validation failed: $sg1_output"
fi
[[ "$(field "$SG2" product_profile_revision)" == "$PROFILE_REVISION" ]] ||
  fail 'stale product_profile_revision'
check_digest "$SG2" sg1_sha256 "$SG1"
check_digest "$SG2" hld_sha256 "$HLD"
sg1_asvs_version="$(field "$SG1" asvs_version)"
[[ "$(field "$SG2" asvs_version)" == "$sg1_asvs_version" &&
  "$sg1_asvs_version" == 5.0.0 ]] || fail 'asvs_version must exactly match current SG1 baseline 5.0.0'
[[ "$(field "$SG2" sg2_status)" == PASS ]] || fail 'sg2_status is not PASS'

profile_applicability() {
  local capability="$1" output resolved applicability profile_field profile_value
  local revision owner reason extra
  if ! output="$(bash "$APPLICABILITY" resolve "$PROJECT_PATH" "$capability" 2>&1)"; then
    fail "$capability applicability cannot be resolved: $output"
  fi
  IFS=$'\t' read -r resolved applicability profile_field profile_value revision owner reason extra <<< "$output"
  [[ -z "$extra" && "$resolved" == "$capability" && "$revision" == "$PROFILE_REVISION" ]] ||
    fail "$capability applicability resolver returned an invalid current binding"
  [[ "$applicability" =~ ^(REQUIRED|NOT_APPLICABLE)$ ]] ||
    fail "$capability applicability resolver returned an invalid verdict"
  printf '%s\n' "$applicability"
}

expected_api_applicability="$(profile_applicability api-contract)"
[[ "$(field "$SG2" api_applicability)" == "$expected_api_applicability" ]] ||
  fail "api_applicability does not match current Product Profile: expected $expected_api_applicability"
expected_authorization_applicability="$(profile_applicability authorization)"
[[ "$(field "$SG2" authorization_applicability)" == "$expected_authorization_applicability" ]] ||
  fail "authorization_applicability does not match current Product Profile: expected $expected_authorization_applicability"

component_scope="$(field "$SG2" component_scope)"
[[ "$component_scope" =~ ^CMP-[A-Za-z0-9._-]+(,CMP-[A-Za-z0-9._-]+)*$ ]] ||
  fail 'component_scope must be a comma-separated component id set'

declare -A required_scenarios=() scenario_asvs=() scenario_covered=()
declare -A required_components=() component_covered=() threat_seen=() test_seen=()
while IFS=$'\t' read -r scenario asvs; do
  [[ -n "$scenario" ]] || continue
  required_scenarios["$scenario"]=1
  scenario_asvs["$scenario"]="$asvs"
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^Scenario:[[:space:]]*/ {
    scenario=$1; asvs=$4
    sub(/^Scenario:[[:space:]]*/, "", scenario)
    sub(/^ASVS:[[:space:]]*/, "", asvs)
    print scenario "\t" asvs
  }' "$SG1")
(( ${#required_scenarios[@]} > 0 )) || fail 'SG1 has no scenarios'

IFS=',' read -r -a components <<< "$component_scope"
for component in "${components[@]}"; do
  [[ -z "${required_components[$component]:-}" ]] || fail "duplicate component scope id: $component"
  required_components["$component"]=1
done

trace_count=0
while IFS=$'\t' read -r threat scenario component control test_id asvs severity status; do
  [[ -n "$threat" ]] || continue
  [[ "$threat" =~ ^THREAT-[A-Za-z0-9._-]+$ ]] || fail "invalid threat id: $threat"
  [[ "$scenario" =~ ^SEC-SC-[A-Za-z0-9._-]+$ ]] || fail "invalid scenario id: $scenario"
  [[ -n "${required_scenarios[$scenario]:-}" ]] || fail "unknown SG1 scenario: $scenario"
  [[ "$component" =~ ^CMP-[A-Za-z0-9._-]+$ ]] || fail "invalid component id: $component"
  [[ -n "${required_components[$component]:-}" ]] ||
    fail "trace component is outside component_scope: $component"
  [[ "$control" =~ ^CTRL-[A-Za-z0-9._-]+$ ]] || fail "invalid control id: $control"
  [[ "$test_id" =~ ^SEC-TEST-[A-Za-z0-9._-]+$ ]] || fail "invalid test id: $test_id"
  [[ "$asvs" =~ ^v5\.0\.0-[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "unversioned ASVS ref: $asvs"
  [[ "$asvs" == "${scenario_asvs[$scenario]}" ]] ||
    fail "ASVS ref does not match current SG1 scenario $scenario"
  [[ "$severity" =~ ^(Critical|High|Medium|Low|None)$ ]] || fail "invalid severity: $severity"
  [[ "$status" =~ ^(OPEN|MITIGATED|CLOSED)$ ]] || fail "invalid status: $status"
  if [[ "$status" == OPEN && "$severity" =~ ^(Critical|High)$ ]]; then
    fail "open $severity threat: $threat"
  fi
  [[ -z "${threat_seen[$threat]:-}" ]] || fail "duplicate threat id: $threat"
  [[ -z "${test_seen[$test_id]:-}" ]] || fail "duplicate security test id: $test_id"
  threat_seen["$threat"]=1
  test_seen["$test_id"]=1
  scenario_covered["$scenario"]=1
  component_covered["$component"]=1
  trace_count=$((trace_count + 1))
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^Threat trace:[[:space:]]*/ {
    if (NF != 8 ||
        $1 !~ /^Threat trace:[[:space:]]*/ ||
        $2 !~ /^Scenario:[[:space:]]*/ ||
        $3 !~ /^Component:[[:space:]]*/ ||
        $4 !~ /^Control:[[:space:]]*/ ||
        $5 !~ /^Test:[[:space:]]*/ ||
        $6 !~ /^ASVS:[[:space:]]*/ ||
        $7 !~ /^Severity:[[:space:]]*/ ||
        $8 !~ /^Status:[[:space:]]*/) next
    for (i=1; i<=8; i++) sub(/^[^:]+:[[:space:]]*/, "", $i)
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8
  }' "$SG2")
(( trace_count > 0 )) || fail 'no valid Threat trace records'
trace_record_count="$(grep -Ec '^Threat trace:[[:space:]]*' "$SG2" || true)"
(( trace_record_count == trace_count )) || fail 'malformed Threat trace record'

for scenario in "${!required_scenarios[@]}"; do
  [[ -n "${scenario_covered[$scenario]:-}" ]] || fail "SG1 scenario is not covered: $scenario"
done
for component in "${components[@]}"; do
  [[ -n "${component_covered[$component]:-}" ]] ||
    fail "component is not covered: $component"
done

echo "SG2 VERIFIED: $trace_count traces cover ${#required_scenarios[@]} scenario(s)"

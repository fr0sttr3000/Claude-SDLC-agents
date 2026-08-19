#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${1:?usage: sg1-check.sh <PROJECT_PATH>}"
[[ -d "$PROJECT_PATH" ]] || { echo "SG1 BLOCKED: Project not found" >&2; exit 2; }
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT="$HERE/current-artifact.sh"

fail() { echo "SG1 BLOCKED: $*" >&2; exit 1; }
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
BRD="$(current_file business-requirements)"
NFR="$(current_file nonfunctional-requirements)"
BACKLOG="$(current_file product-backlog)"
CONSTRAINTS="$(current_file project-constraints)"

[[ "$(field "$SG1" product_profile_revision)" == "$PROFILE_REVISION" ]] ||
  fail 'stale product_profile_revision'
check_digest "$SG1" brd_sha256 "$BRD"
check_digest "$SG1" nfr_sha256 "$NFR"
check_digest "$SG1" backlog_sha256 "$BACKLOG"
check_digest "$SG1" constraints_sha256 "$CONSTRAINTS"
[[ "$(field "$SG1" asvs_version)" == 5.0.0 ]] || fail 'asvs_version must be 5.0.0'
[[ "$(field "$SG1" asvs_level)" =~ ^L[123]$ ]] || fail 'asvs_level must be L1, L2 or L3'
[[ "$(field "$SG1" sg1_status)" == PASS ]] || fail 'sg1_status is not PASS'

data_scope="$(field "$SG1" data_classification_scope)"
[[ "$data_scope" =~ ^DATA-[A-Za-z0-9._-]+(,DATA-[A-Za-z0-9._-]+)*$ ]] ||
  fail 'data_classification_scope must be a comma-separated DATA id set'
declare -A required_data=() data_seen=()
IFS=',' read -r -a data_ids <<< "$data_scope"
for data_id in "${data_ids[@]}"; do
  [[ -z "${required_data[$data_id]:-}" ]] || fail "duplicate data classification scope id: $data_id"
  required_data["$data_id"]=1
done

classification_count=0
while IFS=$'\t' read -r data_id entity classification rationale; do
  [[ -n "$data_id" ]] || continue
  [[ "$data_id" =~ ^DATA-[A-Za-z0-9._-]+$ ]] || fail "invalid data classification id: $data_id"
  [[ -n "${required_data[$data_id]:-}" ]] ||
    fail "data classification record is outside declared scope: $data_id"
  [[ "$entity" =~ ^[A-Za-z0-9._-]+$ ]] || fail "invalid classified entity: $entity"
  [[ "$classification" =~ ^(public|internal|confidential|PII|secret)$ ]] ||
    fail "invalid data classification: $classification"
  [[ ${#rationale} -ge 8 && ! "${rationale,,}" =~ (unknown|tbd|todo|placeholder) ]] ||
    fail "data classification rationale is not concrete: $data_id"
  [[ -z "${data_seen[$data_id]:-}" ]] || fail "duplicate data classification id: $data_id"
  data_seen["$data_id"]=1
  classification_count=$((classification_count + 1))
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^Data classification:[[:space:]]*/ {
    if (NF != 4 ||
        $1 !~ /^Data classification:[[:space:]]*/ ||
        $2 !~ /^Entity:[[:space:]]*/ ||
        $3 !~ /^Class:[[:space:]]*/ ||
        $4 !~ /^Rationale:[[:space:]]*/) next
    for (i=1; i<=4; i++) sub(/^[^:]+:[[:space:]]*/, "", $i)
    print $1 "\t" $2 "\t" $3 "\t" $4
  }' "$SG1")
classification_record_count="$(grep -Ec '^Data classification:[[:space:]]*' "$SG1" || true)"
(( classification_record_count == classification_count )) ||
  fail 'malformed Data classification record'
for data_id in "${!required_data[@]}"; do
  [[ -n "${data_seen[$data_id]:-}" ]] ||
    fail "declared data classification is missing: $data_id"
done

critical_scope="$(field "$SG1" critical_fr_scope)"
[[ "$critical_scope" =~ ^FR-[A-Za-z0-9._-]+(,FR-[A-Za-z0-9._-]+)*$ ]] ||
  fail 'critical_fr_scope must be a comma-separated FR id set'

declare -A required_fr=() scenario_seen=() abuse_seen=() fr_covered=()
IFS=',' read -r -a critical_frs <<< "$critical_scope"
for fr in "${critical_frs[@]}"; do
  [[ -z "${required_fr[$fr]:-}" ]] || fail "duplicate critical FR scope id: $fr"
  required_fr["$fr"]=1
done
scenario_count=0
while IFS=$'\t' read -r scenario fr abuse asvs countermeasure; do
  [[ -n "$scenario" ]] || continue
  [[ "$scenario" =~ ^SEC-SC-[A-Za-z0-9._-]+$ ]] || fail "invalid scenario id: $scenario"
  [[ "$fr" =~ ^FR-[A-Za-z0-9._-]+$ ]] || fail "invalid FR id: $fr"
  [[ -n "${required_fr[$fr]:-}" ]] || fail "scenario FR is outside critical_fr_scope: $fr"
  [[ "$abuse" =~ ^ABUSE-[A-Za-z0-9._-]+$ ]] || fail "invalid abuse id: $abuse"
  [[ "$asvs" =~ ^v5\.0\.0-[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "unversioned ASVS ref: $asvs"
  [[ "$countermeasure" =~ ^SEC-NFR-[A-Za-z0-9._-]+$ ]] ||
    fail "invalid countermeasure id: $countermeasure"
  [[ -z "${scenario_seen[$scenario]:-}" ]] || fail "duplicate scenario id: $scenario"
  [[ -z "${abuse_seen[$abuse]:-}" ]] || fail "duplicate abuse id: $abuse"
  scenario_seen["$scenario"]=1
  abuse_seen["$abuse"]=1
  fr_covered["$fr"]=1
  scenario_count=$((scenario_count + 1))
done < <(awk -F'[[:space:]]*\\|[[:space:]]*' '
  /^Scenario:[[:space:]]*/ {
    if (NF != 5 ||
        $1 !~ /^Scenario:[[:space:]]*/ ||
        $2 !~ /^FR:[[:space:]]*/ ||
        $3 !~ /^Abuse:[[:space:]]*/ ||
        $4 !~ /^ASVS:[[:space:]]*/ ||
        $5 !~ /^Countermeasure:[[:space:]]*/) next
    for (i=1; i<=5; i++) sub(/^[^:]+:[[:space:]]*/, "", $i)
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5
  }' "$SG1")
(( scenario_count > 0 )) || fail 'no valid Scenario records'
scenario_record_count="$(grep -Ec '^Scenario:[[:space:]]*' "$SG1" || true)"
(( scenario_record_count == scenario_count )) || fail 'malformed Scenario record'

for fr in "${critical_frs[@]}"; do
  [[ -n "${fr_covered[$fr]:-}" ]] || fail "critical FR has no security scenario: $fr"
done

echo "SG1 VERIFIED: $scenario_count scenarios cover ${#critical_frs[@]} critical FR(s)"

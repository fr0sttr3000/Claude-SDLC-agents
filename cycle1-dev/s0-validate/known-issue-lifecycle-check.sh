#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: known-issue-lifecycle-check.sh <Project>}"
[[ -d "$PROJECT_INPUT" ]] ||
  { echo 'KNOWN ISSUE LIFECYCLE BLOCKED: Project not found' >&2; exit 2; }
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
REGISTRY="$PROJECT/tracking/known-issues.md"
TD_REGISTRY="$PROJECT/tracking/tech-debt.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fail() { echo "KNOWN ISSUE LIFECYCLE BLOCKED: $*" >&2; exit 1; }
[[ -f "$REGISTRY" && ! -L "$REGISTRY" ]] || fail 'known-issues.md missing/symlink'

field() {
  local block="$1" key="$2"
  sed -n "s/^- $key:[[:space:]]*//p" <<< "$block" | head -1
}
file_field() {
  local file="$1" key="$2"
  awk -F: -v wanted="$key" '$1 == wanted {
    value=$0
    sub(/^[^:]*:[[:space:]]*/, "", value)
    sub(/[[:space:]]+$/, "", value)
    print value
    exit
  }' "$file"
}
field_count() {
  local block="$1" key="$2"
  awk -v prefix="- $key:" 'index($0, prefix) == 1 {count++} END {print count+0}' <<< "$block"
}
td_status() {
  local wanted="$1"
  [[ -f "$TD_REGISTRY" && ! -L "$TD_REGISTRY" ]] || return 1
  awk -v wanted="$wanted" '
    /^### TD-/ {
      if (active) exit
      id=$2
      active=(id == wanted)
      next
    }
    active && /^- Статус:[[:space:]]*/ {
      sub(/^- Статус:[[:space:]]*/, "")
      print
      exit
    }
  ' "$TD_REGISTRY"
}
validate_operational_evidence() {
  local id="$1" label="$2" value="$3" ref sha path canonical
  [[ "$value" =~ ^ref=([A-Za-z0-9._/-]+)\;sha256=([0-9a-f]{64})$ ]] ||
    fail "$id $label cleanup evidence invalid"
  ref="${BASH_REMATCH[1]}"
  sha="${BASH_REMATCH[2]}"
  [[ "$ref" =~ ^tracking/operations/evidence/[A-Za-z0-9._/-]+\.(md|yaml|json|tsv)$ &&
    "$ref" != *'/../'* && "$ref" != */.. ]] || fail "$id $label cleanup ref unsafe"
  path="$PROJECT/$ref"
  [[ -f "$path" && ! -L "$path" ]] || fail "$id $label cleanup ref missing/symlink"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT/tracking/operations/evidence/"* ]] ||
    fail "$id $label cleanup ref escapes Project"
  [[ "$(sha256sum "$path" | awk '{print $1}')" == "$sha" ]] ||
    fail "$id $label cleanup digest mismatch"
}
validate_released_build() {
  local id="$1" version="$2" ref="$3" expected_sha="$4" source="$5" test_id="$6"
  local evidence evidence_output subject_kind build_identity test_ids raw_format raw_path
  [[ "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
    fail "$id fix release version invalid"
  [[ "$ref" =~ ^tracking/evidence/v1/[A-Za-z0-9._-]+\.yaml$ ]] ||
    fail "$id fix build evidence ref invalid"
  evidence="$PROJECT/$ref"
  [[ -f "$evidence" && ! -L "$evidence" ]] || fail "$id fix build evidence missing/symlink"
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ &&
    "$(sha256sum "$evidence" | awk '{print $1}')" == "$expected_sha" ]] ||
    fail "$id fix build evidence digest mismatch"
  [[ "$source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
    fail "$id fix source revision invalid"
  [[ "$test_id" =~ ^TEST-[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
    fail "$id fix verification test id invalid"
  evidence_output="$(bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT" "$ref" \
    --expected-source "$source" --expected-check build 2>&1)" || {
      printf '%s\n' "$evidence_output" >&2
      fail "$id released build Evidence v1 invalid"
    }
  [[ "$(file_field "$evidence" verdict)" == PASS ]] ||
    fail "$id released build verdict must be PASS"
  subject_kind="$(file_field "$evidence" subject_kind)"
  [[ "$subject_kind" =~ ^(build-artifact|package|image)$ ]] ||
    fail "$id validation-only/source evidence cannot close Known Issue"
  build_identity="$(file_field "$evidence" build_identity)"
  [[ "$build_identity" == "release:$version" ]] ||
    fail "$id released build identity/version mismatch"
  test_ids=",${test_ids:-$(file_field "$evidence" test_ids)},"
  [[ "$test_ids" == *",$test_id,"* ]] || fail "$id build Evidence omits verification test"
  raw_format="$(file_field "$evidence" raw_format)"
  [[ "$raw_format" == json ]] || fail "$id released build proof requires normalized JSON"
  raw_path="$PROJECT/$(file_field "$evidence" raw_result_uri)"
  command -v jq >/dev/null 2>&1 || fail 'jq capability missing'
  jq -e --arg id "$id" --arg version "$version" --arg source "$source" \
    --arg build "$build_identity" --arg subject "$(file_field "$evidence" subject_digest)" \
    --arg test "$test_id" '
      type == "object" and .schema_version == 1 and .check_id == "build" and
      .source_revision == $source and .subject_digest == $subject and
      .build_identity == $build and .release_version == $version and .verdict == "PASS" and
      (.included_fix_ids | type == "array") and
      ([.included_fix_ids[] | select(. == $id)] | length) == 1 and
      (.verification_test_ids | type == "array") and
      ([.verification_test_ids[] | select(. == $test)] | length) == 1
    ' "$raw_path" >/dev/null || fail "$id raw released build proof omits exact fix/test binding"
}

mapfile -t ids < <(sed -n 's/^### \(KI-[A-Za-z0-9._-]*\).*/\1/p' "$REGISTRY")
declare -A seen=()
for id in "${ids[@]}"; do
  [[ -z "${seen[$id]:-}" ]] || fail "duplicate Known Issue id: $id"
  seen["$id"]=1
  block="$(awk -v wanted="$id" '
    /^### KI-/ {
      if (active) exit
      active=($2 == wanted)
    }
    active {print}
  ' "$REGISTRY")"
  required_fields=(
    Severity Trigger Impact Workaround 'Detection signal' Auto-remediation
    '→ tech-debt' 'Human Approval v1' 'Fix release version'
    'Fix build evidence ref' 'Fix build evidence sha256' 'Fix source revision'
    'Fix verification test id' 'Operational scope' 'Alert cleanup evidence'
    'Runbook cleanup evidence' Status
  )
  for key in "${required_fields[@]}"; do
    [[ "$(field_count "$block" "$key")" == 1 && -n "$(field "$block" "$key")" ]] ||
      fail "$id requires exactly one non-empty $key field"
  done
  severity="$(field "$block" Severity)"
  impact="$(field "$block" Impact)"
  status="$(field "$block" Status)"
  td="$(field "$block" '→ tech-debt')"
  version="$(field "$block" 'Fix release version')"
  build_ref="$(field "$block" 'Fix build evidence ref')"
  build_sha="$(field "$block" 'Fix build evidence sha256')"
  source="$(field "$block" 'Fix source revision')"
  test_id="$(field "$block" 'Fix verification test id')"
  operational_scope="$(field "$block" 'Operational scope')"
  alert_cleanup="$(field "$block" 'Alert cleanup evidence')"
  runbook_cleanup="$(field "$block" 'Runbook cleanup evidence')"
  [[ "$severity" =~ ^(S3|S4|CVSS-MEDIUM|CVSS-LOW)$ ]] || fail "$id severity invalid"
  [[ "$impact" == user-facing* ]] || fail "$id Impact must start with user-facing"
  [[ "$td" =~ ^TD-[A-Za-z0-9._-]+$ ]] || fail "$id Tech Debt id invalid"
  [[ "$operational_scope" =~ ^(FROZEN_NOT_READY|ACTIVE)$ ]] ||
    fail "$id operational scope invalid"
  case "$status" in
    OPEN)
      for value in "$version" "$build_ref" "$build_sha" "$source" "$test_id" \
        "$alert_cleanup" "$runbook_cleanup"; do
        [[ "$value" == none ]] || fail "$id OPEN record claims fix/cleanup evidence"
      done
      [[ "$(td_status "$td")" =~ ^(OPEN|IN_PROGRESS)$ ]] ||
        fail "$id OPEN requires active $td; Known Issue acceptance does not cancel Patch SLA"
      ;;
    FIXED)
      validate_released_build "$id" "$version" "$build_ref" "$build_sha" "$source" "$test_id"
      [[ "$(td_status "$td")" == RESOLVED ]] || fail "$id FIXED requires resolved $td"
      if [[ "$operational_scope" == FROZEN_NOT_READY ]]; then
        [[ "$alert_cleanup" == none && "$runbook_cleanup" == none ]] ||
          fail "$id frozen operational scope must not invent cleanup evidence"
      else
        validate_operational_evidence "$id" alert "$alert_cleanup"
        validate_operational_evidence "$id" runbook "$runbook_cleanup"
      fi
      ;;
    *) fail "$id status invalid" ;;
  esac
done
echo "KNOWN ISSUE LIFECYCLE VERIFIED: records=${#ids[@]}"

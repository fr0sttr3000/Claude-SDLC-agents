#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
SOURCE_REVISION="${2:?Укажи exact source revision}"
blocked() { echo "SG3 BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$SOURCE_REVISION" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] || blocked 'invalid source revision'
command -v jq >/dev/null 2>&1 || blocked 'jq capability отсутствует; установи jq или выбери executor adapter с deterministic parser'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
EVIDENCE_DIR="$PROJECT_PATH/tracking/evidence/v1"
bash "$SCRIPT_DIR/product-ci-profile-check.sh" "$PROJECT_PATH" >/dev/null || blocked 'Product Profile invalid'

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

evaluate_medium_exception() {
  local record="$1" check="$2" medium_ids="$3" ref producer subject
  [[ -z "$medium_ids" ]] && return 0
  ref="$(field "$record" risk_exception_ref)"
  [[ "$ref" != none ]] || blocked "open Medium findings require risk exception: $medium_ids"
  producer="$(field "$record" producer_identity)"
  subject="$(field "$record" subject_digest)"
  bash "$SCRIPT_DIR/risk-exception-check.sh" "$PROJECT_PATH" "$ref" "$check" \
    "$SOURCE_REVISION" "$subject" "$producer" "$medium_ids" security >/dev/null ||
    blocked "risk exception invalid for check=$check findings=$medium_ids"
}

evaluate_low_ledger() {
  local low_ids="$1"
  [[ -z "$low_ids" ]] && return 0
  bash "$SCRIPT_DIR/tech-debt-check.sh" "$PROJECT_PATH" security-low "$low_ids" >/dev/null ||
    blocked "open Low findings require valid tracking/tech-debt.md entries: $low_ids"
}

policy_ids=()
for check in secrets sast sca dependency-integrity image-scan; do
  matches=()
  while IFS= read -r -d '' record; do
    [[ "$(field "$record" check_id)" == "$check" ]] || continue
    [[ "$(field "$record" source_revision)" == "$SOURCE_REVISION" ]] || continue
    matches+=("$record")
  done < <(find "$EVIDENCE_DIR" -maxdepth 1 -type f -name '*.yaml' -print0 | sort -z)
  (( ${#matches[@]} == 1 )) || blocked "check=$check требует один current record; найдено ${#matches[@]}"
  record="${matches[0]}"
  verifier_output="$(bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$record" \
    --expected-source "$SOURCE_REVISION" --expected-check "$check" 2>&1)" || {
      printf '%s\n' "$verifier_output" >&2
      blocked "unverified evidence for check=$check"
    }
  [[ "$(field "$record" policy_revision)" == security-v1 ]] ||
    blocked "check=$check использует unsupported policy revision"
  verdict="$(field "$record" verdict)"
  if [[ "$check" == image-scan && "$(field "$PROFILE" build_subject)" != image ]]; then
    [[ "$verdict" == NOT_APPLICABLE ]] || blocked 'image-scan must be NOT_APPLICABLE without image subject'
    policy_ids+=("$(field "$record" evidence_id)")
    continue
  fi
  [[ "$verdict" == PASS ]] || blocked "check=$check has blocking verdict=$verdict"

  raw_format="$(field "$record" raw_format)"
  raw_path="$PROJECT_PATH/$(field "$record" raw_result_uri)"
  medium_ids=''
  low_ids=''
  case "$raw_format" in
    json)
      jq -e --arg check "$check" --arg source "$SOURCE_REVISION" '
        type == "object" and
        ((keys - ["schema_version","check_id","source_revision","secret_count","integrity_status","tampered_dependencies","malicious_dependencies","findings"]) | length == 0) and
        .schema_version == 1 and .check_id == $check and .source_revision == $source and
        (.secret_count | type == "number") and (.secret_count >= 0) and (.secret_count == (.secret_count|floor)) and
        (.integrity_status == "pass" or .integrity_status == "fail" or .integrity_status == "not-applicable") and
        (.tampered_dependencies | type == "number") and (.tampered_dependencies >= 0) and
        (.malicious_dependencies | type == "number") and (.malicious_dependencies >= 0) and
        (.findings | type == "array") and
        all(.findings[]; (.id | type == "string") and (.id | length > 0) and
          (.cvss | type == "number") and .cvss >= 0 and .cvss <= 10 and
          (.status == "open" or .status == "fixed"))
      ' "$raw_path" >/dev/null || blocked "invalid normalized security JSON for check=$check"
      if [[ "$check" == secrets ]]; then
        secret_count="$(jq -r '.secret_count' "$raw_path")"
        (( secret_count == 0 )) || blocked "secret findings are zero-tolerance: count=$secret_count"
      fi
      if [[ "$check" == dependency-integrity ]]; then
        integrity="$(jq -r '.integrity_status' "$raw_path")"
        tampered="$(jq -r '.tampered_dependencies' "$raw_path")"
        malicious="$(jq -r '.malicious_dependencies' "$raw_path")"
        [[ "$integrity" == pass && "$tampered" == 0 && "$malicious" == 0 ]] ||
          blocked "dependency integrity/malicious policy failed: status=$integrity tampered=$tampered malicious=$malicious"
      fi
      high_ids="$(jq -r '[.findings[] | select(.status == "open" and .cvss >= 7.0) | .id] | join(",")' "$raw_path")"
      [[ -z "$high_ids" ]] || blocked "Critical/High findings cannot be waived: $high_ids"
      medium_ids="$(jq -r '[.findings[] | select(.status == "open" and .cvss >= 4.0 and .cvss < 7.0) | .id] | join(",")' "$raw_path")"
      low_ids="$(jq -r '[.findings[] | select(.status == "open" and .cvss > 0 and .cvss < 4.0) | .id] | join(",")' "$raw_path")"
      ;;
    sarif)
      [[ "$check" != dependency-integrity ]] || blocked 'dependency-integrity requires normalized JSON'
      jq -e '.version == "2.1.0" and (.runs | type == "array") and all(.runs[]; (.results // []) | type == "array")' \
        "$raw_path" >/dev/null || blocked "invalid SARIF for check=$check"
      result_count="$(jq '[.runs[] | (.results // [])[]] | length' "$raw_path")"
      if [[ "$check" == secrets ]]; then
        (( result_count == 0 )) || blocked "secret findings are zero-tolerance: count=$result_count"
      else
        jq -e 'all(.runs[] | (.results // [])[];
          ((.properties["security-severity"] // .properties.cvss // .properties["cvss"]) | tonumber? // -1) >= 0)' \
          "$raw_path" >/dev/null || blocked "SARIF findings missing numeric CVSS for check=$check"
        high_ids="$(jq -r '[.runs[] | (.results // [])[] |
          {id:(.ruleId // "unknown-rule"), score:((.properties["security-severity"] // .properties.cvss // .properties["cvss"]) | tonumber)} |
          select(.score >= 7.0) | .id] | join(",")' "$raw_path")"
        [[ -z "$high_ids" ]] || blocked "Critical/High findings cannot be waived: $high_ids"
        medium_ids="$(jq -r '[.runs[] | (.results // [])[] |
          {id:(.ruleId // "unknown-rule"), score:((.properties["security-severity"] // .properties.cvss // .properties["cvss"]) | tonumber)} |
          select(.score >= 4.0 and .score < 7.0) | .id] | join(",")' "$raw_path")"
        low_ids="$(jq -r '[.runs[] | (.results // [])[] |
          {id:(.ruleId // "unknown-rule"), score:((.properties["security-severity"] // .properties.cvss // .properties["cvss"]) | tonumber)} |
          select(.score > 0 and .score < 4.0) | .id] | join(",")' "$raw_path")"
      fi
      ;;
    *) blocked "SG3 check=$check requires JSON or SARIF" ;;
  esac
  evaluate_medium_exception "$record" "$check" "$medium_ids"
  evaluate_low_ledger "$low_ids"
  policy_ids+=("$(field "$record" evidence_id)")
done

ids_csv="$(IFS=','; printf '%s' "${policy_ids[*]}")"
echo "SG3 VERIFIED: source=$SOURCE_REVISION policy_revision=security-v1 evidence_ids=$ids_csv"

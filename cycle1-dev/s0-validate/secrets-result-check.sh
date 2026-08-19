#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
RECORD_INPUT="${2:?Укажи Evidence v1 record}"
SOURCE_REVISION="${3:?Укажи exact source revision}"
blocked() { echo "SECRETS RESULT BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$SOURCE_REVISION" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  blocked 'invalid source revision'
command -v jq >/dev/null 2>&1 ||
  blocked 'jq capability отсутствует; нужен deterministic JSON/SARIF parser'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "$RECORD_INPUT" != /* ]]; then RECORD_INPUT="$PROJECT_PATH/$RECORD_INPUT"; fi

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key {
    value=$0
    sub(/^[^:]*:[[:space:]]*/, "", value)
    sub(/[[:space:]]+$/, "", value)
    print value
    exit
  }' "$file"
}

bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$RECORD_INPUT" \
  --expected-source "$SOURCE_REVISION" --expected-check secrets >/dev/null ||
  blocked 'Evidence v1 invalid for exact source/secrets check'
[[ "$(field "$RECORD_INPUT" verdict)" == PASS ]] || blocked 'secrets verdict must be PASS'
[[ "$(field "$RECORD_INPUT" subject_kind)" == source ]] ||
  blocked 'repository secrets scan must use source subject'
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
[[ "$(field "$PROFILE" evidence_repository_path)" == . ]] ||
  blocked 'secrets scan scope must be the full repository path "."'

raw_format="$(field "$RECORD_INPUT" raw_format)"
raw_path="$PROJECT_PATH/$(field "$RECORD_INPUT" raw_result_uri)"
case "$raw_format" in
  json)
    jq -e --arg source "$SOURCE_REVISION" '
      type == "object" and
      .schema_version == 1 and .check_id == "secrets" and .source_revision == $source and
      (.secret_count | type == "number") and .secret_count == 0 and
      (.findings | type == "array") and (.findings | length) == 0
    ' "$raw_path" >/dev/null || blocked 'JSON does not prove zero secrets for exact source'
    ;;
  sarif)
    jq -e '
      .version == "2.1.0" and (.runs | type == "array") and
      all(.runs[]; (.results // []) | type == "array") and
      ([.runs[] | (.results // [])[]] | length) == 0
    ' "$raw_path" >/dev/null || blocked 'SARIF does not prove zero secret findings'
    ;;
  *) blocked 'secrets raw result must be normalized JSON or SARIF' ;;
esac

echo "SECRETS RESULT VERIFIED: source=$SOURCE_REVISION scope=. format=$raw_format findings=0"

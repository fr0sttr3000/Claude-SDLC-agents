#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
SOURCE_REVISION="${2:?Укажи exact source revision}"
[[ -d "$PROJECT_INPUT" ]] || { echo "SUMMARY BLOCKED: Project не найден" >&2; exit 1; }
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
EVIDENCE_DIR="$PROJECT_PATH/tracking/evidence/v1"
[[ -d "$EVIDENCE_DIR" ]] || { echo 'SUMMARY BLOCKED: tracking/evidence/v1 отсутствует' >&2; exit 1; }

field() {
  local file="$1" wanted="$2"
  awk -F: -v key="$wanted" '$1 == key { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

records=()
while IFS= read -r -d '' record; do
  record_source="$(field "$record" source_revision)"
  [[ -n "$record_source" ]] || { echo "SUMMARY BLOCKED: record without source_revision: $record" >&2; exit 1; }
  [[ "$record_source" == "$SOURCE_REVISION" ]] || continue
  records+=("$record")
done < <(find "$EVIDENCE_DIR" -maxdepth 1 -type f -name '*.yaml' -print0 | sort -z)
(( ${#records[@]} > 0 )) || { echo "SUMMARY BLOCKED: no evidence for $SOURCE_REVISION" >&2; exit 1; }

for record in "${records[@]}"; do
  bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$record" \
    --expected-source "$SOURCE_REVISION" --inspect >/dev/null || {
      echo "SUMMARY BLOCKED: unverified record ${record#$PROJECT_PATH/}" >&2
      exit 1
    }
done

profile_revision="$(field "$PROJECT_PATH/tracking/product-ci-profile.yaml" revision)"
printf '%s\n' \
  '# Cycle 1 Evidence Summary' '' \
  '> Generated from verified Evidence Contract v1 records; this Markdown is not machine evidence.' '' \
  "- Source revision: \`$SOURCE_REVISION\`" \
  "- Product Profile revision: \`$profile_revision\`" '' \
  '| Check | Verdict | Evidence ID | Producer | Raw format |' \
  '|---|---|---|---|---|'
for record in "${records[@]}"; do
  printf '| %s | %s | `%s` | `%s` | `%s` |\n' \
    "$(field "$record" check_id)" "$(field "$record" verdict)" \
    "$(field "$record" evidence_id)" "$(field "$record" producer_identity)" \
    "$(field "$record" raw_format)"
done

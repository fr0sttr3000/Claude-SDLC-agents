#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
ARTIFACT_REF="${2:?Укажи Project-relative Markdown artifact}"
EXPECTED_PRODUCER="${3:-}"
EXPECTED_STAGES="${4:-}"
EXPECTED_TYPES="${5:-}"
unverified() { echo "ARTIFACT METADATA UNVERIFIED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || unverified "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"

safe_ref() {
  local ref="$1" path canonical
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != ../* && "$ref" != *'/../'* && "$ref" != */.. ]] ||
    unverified "unsafe Project-relative reference: $ref"
  path="$PROJECT_PATH/$ref"
  [[ -f "$path" && ! -L "$path" ]] || unverified "reference missing/symlink: $ref"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/"* ]] || unverified "reference escapes Project: $ref"
  printf '%s\n' "$path"
}

ARTIFACT="$(safe_ref "$ARTIFACT_REF")"
[[ "$ARTIFACT_REF" == *.md ]] || unverified 'artifact must be Markdown'
[[ "$(head -1 "$ARTIFACT")" == --- ]] || unverified 'legacy artifact has no v1 frontmatter'

frontmatter_end="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$ARTIFACT")"
[[ "$frontmatter_end" =~ ^[0-9]+$ && "$frontmatter_end" -ge 3 ]] ||
  unverified 'frontmatter closing marker missing'

declare -A values=() seen=()
while IFS= read -r line; do
  [[ "$line" == *:* ]] || unverified "non-flat frontmatter line: $line"
  key="${line%%:*}"; value="${line#*:}"; value="${value# }"
  [[ "$key" =~ ^[a-z][a-z0-9_]*$ && -n "$value" ]] || unverified "invalid metadata field: $line"
  [[ -z "${seen[$key]+x}" ]] || unverified "duplicate metadata field: $key"
  seen["$key"]=1; values["$key"]="$value"
done < <(sed -n "2,$((frontmatter_end - 1))p" "$ARTIFACT")

required=(schema_version artifact_id artifact_type project stage producer source_revision status inputs outputs tags)
for key in "${required[@]}"; do [[ -n "${values[$key]:-}" ]] || unverified "missing metadata field: $key"; done
[[ "${values[schema_version]}" == 1 ]] || unverified 'schema_version must be 1'
[[ "${values[artifact_id]}" =~ ^[A-Z0-9][A-Z0-9._-]*$ ]] || unverified 'invalid artifact_id'
[[ "${values[artifact_type]}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || unverified 'invalid artifact_type'
[[ "${values[project]}" == "$(basename "$PROJECT_PATH")" ]] || unverified 'project metadata mismatch'
[[ "${values[stage]}" =~ ^(S[0-5]|TRACKING)$ ]] || unverified 'invalid active stage'
[[ "${values[producer]}" =~ ^(s[0-5]-[a-z0-9-]+|l[1-4]-[a-z0-9-]+)$ ]] || unverified 'invalid active producer'
if [[ -n "$EXPECTED_PRODUCER" ]]; then
  [[ "${values[producer]}" == "$EXPECTED_PRODUCER" ]] ||
    unverified "producer mismatch: expected=$EXPECTED_PRODUCER actual=${values[producer]}"
  [[ ",$EXPECTED_STAGES," == *,"${values[stage]}",* ]] ||
    unverified "stage not allowed for $EXPECTED_PRODUCER: ${values[stage]}"
  [[ ",$EXPECTED_TYPES," == *,"${values[artifact_type]}",* ]] ||
    unverified "artifact_type not allowed for $EXPECTED_PRODUCER: ${values[artifact_type]}"
fi
[[ "${values[source_revision]}" == none || "${values[source_revision]}" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  unverified 'invalid source_revision'
[[ "${values[status]}" =~ ^(DRAFT|RED|PASS|FAIL|BLOCKED|NOT_APPLICABLE|APPROVED|VALIDATED|UNVERIFIED)$ ]] ||
  unverified 'invalid status'
[[ "${values[tags]}" =~ ^[a-z0-9-]+(,[a-z0-9-]+)*$ ]] || unverified 'invalid tags'
[[ ",${values[tags]}," == *,sdlc,* && ",${values[tags]}," == *,cycle1,* ]] ||
  unverified 'tags must include sdlc,cycle1'
required_stage_tag="stage${values[stage]#S}"
[[ "${values[stage]}" != TRACKING ]] || required_stage_tag=tracking
[[ ",${values[tags]}," == *,"$required_stage_tag",* ]] ||
  unverified "tags must include $required_stage_tag"
declare -A tag_seen=()
IFS=',' read -r -a tag_list <<< "${values[tags]}"
for tag in "${tag_list[@]}"; do
  [[ -z "${tag_seen[$tag]+x}" ]] || unverified "duplicate tag: $tag"
  tag_seen["$tag"]=1
done

for list_key in inputs outputs; do
  refs="${values[$list_key]}"
  [[ "$refs" != none || "$list_key" == inputs ]] || unverified 'outputs cannot be none'
  [[ "$refs" == none ]] && continue
  IFS=',' read -r -a list <<< "$refs"
  declare -A list_seen=()
  for ref in "${list[@]}"; do
    [[ -z "${list_seen[$ref]+x}" ]] || unverified "duplicate $list_key reference: $ref"
    list_seen["$ref"]=1
    safe_ref "$ref" >/dev/null
    if [[ "$ref" == *.md ]]; then
      wiki="[[${ref%.md}]]"
      grep -Fq "$wiki" "$ARTIFACT" || unverified "missing Obsidian link for $ref"
    fi
  done
done
[[ ",${values[outputs]}," == *,"$ARTIFACT_REF",* ]] || unverified 'outputs must include artifact itself'
grep -Fq '## Obsidian Links' "$ARTIFACT" || unverified 'Obsidian Links section missing'
grep -Fq '[[Dashboard]]' "$ARTIFACT" || unverified 'Dashboard graph link missing'

while IFS= read -r -d '' candidate; do
  [[ "$candidate" != "$ARTIFACT" && "$(head -1 "$candidate")" == --- ]] || continue
  candidate_id="$(awk '
    NR == 1 { next }
    $0 == "---" { exit }
    /^artifact_id:[[:space:]]*/ {
      value=$0; sub(/^artifact_id:[[:space:]]*/, "", value); print value; exit
    }
  ' "$candidate")"
  if [[ "$candidate_id" == "${values[artifact_id]}" ]]; then
    candidate_ref="${candidate#"$PROJECT_PATH/"}"
    if [[ "$ARTIFACT_REF" == tracking/quality-gates.md &&
          "$candidate_ref" == tracking/quality-gates-history/revision-*.md ]] &&
       cmp -s "$ARTIFACT" "$candidate"; then
      continue
    fi
    unverified "duplicate artifact_id in Project: ${values[artifact_id]}"
  fi
done < <(find "$PROJECT_PATH" \
  \( -path "$PROJECT_PATH/tracking/quality-config-candidate" -o \
     -path "$PROJECT_PATH/tracking/.quality-config-transaction" \) -prune -o \
  -type f -name '*.md' -print0)

if grep -Eiq '(AKIA[0-9A-Z]{8,}|gh[pousr]_[A-Za-z0-9]+|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{8,}|password=|token=|secret=|/home/[^/]+/|[A-Za-z]:\\Users\\)' "$ARTIFACT"; then
  unverified 'secret-like or local absolute path found'
fi

echo "ARTIFACT METADATA VERIFIED: id=${values[artifact_id]} type=${values[artifact_type]} producer=${values[producer]} stage=${values[stage]} source=${values[source_revision]} status=${values[status]}"

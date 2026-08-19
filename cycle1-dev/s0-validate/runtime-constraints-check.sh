#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: runtime-constraints-check.sh <PROJECT_PATH> <requirements|architecture>}"
MODE="${2:?usage: runtime-constraints-check.sh <PROJECT_PATH> <requirements|architecture>}"
blocked() { echo "RUNTIME CONSTRAINTS BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
[[ "$MODE" == requirements || "$MODE" == architecture ]] ||
  blocked 'mode должен быть requirements|architecture'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
IDEA="$PROJECT_PATH/stage1-planning/inputs/idea.md"
PMO="$PROJECT_PATH/tracking/PMO-constraints.md"

[[ -f "$IDEA" && ! -L "$IDEA" ]] || blocked 'canonical idea.md отсутствует или является symlink'
[[ -f "$PMO" && ! -L "$PMO" ]] || blocked 'PMO-constraints.md отсутствует или является symlink'

field_values() {
  local file="$1" key="$2"
  awk -v wanted="$key" '
    {
      line=$0
      sub(/^[[:space:]]*/, "", line)
      prefix=wanted ":"
      if (index(line, prefix) == 1) {
        value=substr(line, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        print value
      }
    }
  ' "$file"
}

unquote() {
  local value="$1"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s\n' "$value"
}

resolve_one() {
  local logical_id="$1" pattern="$2" ref
  if [[ -f "$PROJECT_PATH/tracking/current-artifacts-v1.tsv" ]]; then
    ref="$(bash "$SCRIPT_DIR/current-artifact.sh" resolve-compatible-one \
      "$PROJECT_PATH" "$logical_id" 2>/dev/null)" ||
      blocked "current $logical_id не разрешён"
    printf '%s/%s\n' "$PROJECT_PATH" "$ref"
    return
  fi
  local -a matches=()
  while IFS= read -r -d '' ref; do matches+=("$ref"); done < <(
    find "$PROJECT_PATH" -path "$PROJECT_PATH/$pattern" -type f -print0 2>/dev/null | sort -z
  )
  (( ${#matches[@]} == 1 )) ||
    blocked "$logical_id: ожидался один artifact без current manifest, найдено ${#matches[@]}"
  printf '%s\n' "${matches[0]}"
}

mapfile -t legacy_values < <(field_values "$IDEA" 'Deployment Constraint')
mapfile -t idea_values < <(field_values "$IDEA" 'Runtime Constraints')
if (( ${#legacy_values[@]} > 0 && ${#idea_values[@]} > 0 )); then
  blocked 'idea.md содержит canonical и legacy fields; kickoff должен явно разрешить conflict'
fi
if (( ${#legacy_values[@]} > 0 )); then
  blocked 'legacy Deployment Constraint требует kickoff migration до Stage 2'
fi
(( ${#idea_values[@]} == 1 )) ||
  blocked "idea.md должен содержать ровно один Runtime Constraints field, найдено ${#idea_values[@]}"
idea_value="${idea_values[0]}"
[[ -n "$idea_value" && ! "$idea_value" =~ ^(\{|\[).*(\}|\])$ ]] ||
  blocked 'Runtime Constraints пуст или остаётся template placeholder'

mapfile -t pmo_values < <(field_values "$PMO" runtime_constraints)
mapfile -t pmo_sources < <(field_values "$PMO" runtime_constraints_source)
(( ${#pmo_values[@]} == 1 && ${#pmo_sources[@]} == 1 )) ||
  blocked 'PMO cycle1 требует unique runtime_constraints и runtime_constraints_source'
pmo_value="$(unquote "${pmo_values[0]}")"
pmo_source="$(unquote "${pmo_sources[0]}")"
[[ "$pmo_source" == 'stage1-planning/inputs/idea.md#Runtime Constraints' ]] ||
  blocked 'PMO runtime_constraints_source не указывает canonical idea field'
[[ "$pmo_value" == "$idea_value" ]] ||
  blocked 'PMO runtime_constraints не совпадает с normalized idea value'
grep -Eq '^[[:space:]]*Deployment Constraint:' "$PMO" &&
  blocked 'legacy Deployment Constraint запрещён в PMO constraints'

NFR="$(resolve_one nonfunctional-requirements 'stage2-requirements/outputs/BA-*NFR*.md')"
[[ -f "$NFR" && ! -L "$NFR" ]] || blocked 'current NFR отсутствует или является symlink'
grep -Fqx '## Runtime Constraints' "$NFR" || blocked 'NFR не содержит ## Runtime Constraints'
grep -Fqx 'Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints' "$NFR" ||
  blocked 'NFR Runtime Constraints source invalid'
grep -Fqx 'Runtime Constraints scope: application-design-only' "$NFR" ||
  blocked 'NFR Runtime Constraints scope должен быть application-design-only'
grep -Eq '^[[:space:]]*Deployment Constraint:' "$NFR" &&
  blocked 'legacy Deployment Constraint запрещён в NFR'

unknown=0
lower_value="${idea_value,,}"
case "$lower_value" in
  unknown|'не определено'|'not defined'|n/a|'not applicable') unknown=1 ;;
  '[open issue]'*) unknown=1 ;;
esac

mapfile -t rc_rows < <(grep -E '^RC-[0-9]{3}[[:space:]]*\|' "$NFR" || true)
declare -A nfr_ids=()
if (( unknown == 1 )); then
  grep -Eq '^Runtime Constraints status: (OPEN ISSUE|NOT_APPLICABLE)$' "$NFR" ||
    blocked 'unknown Runtime Constraints требует OPEN ISSUE или NOT_APPLICABLE status'
  grep -Eq '^Runtime Constraints owner: [^[:space:]].*$' "$NFR" ||
    blocked 'unknown Runtime Constraints требует concrete owner'
  (( ${#rc_rows[@]} == 0 )) || blocked 'unknown Runtime Constraints не может содержать invented RC rows'
else
  grep -Fqx 'Runtime Constraints status: CONFIRMED' "$NFR" ||
    blocked 'confirmed Runtime Constraints требует CONFIRMED status'
  (( ${#rc_rows[@]} > 0 )) || blocked 'confirmed Runtime Constraints требует RC rows'
  row_number=0
  for row in "${rc_rows[@]}"; do
    ((row_number+=1))
    IFS='|' read -r id kind constraint provenance extra <<< "$row"
    for name in id kind constraint provenance; do
      value="${!name}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      printf -v "$name" '%s' "$value"
    done
    [[ -z "$extra" ]] || blocked "RC row $row_number содержит лишние columns"
    [[ "$id" =~ ^RC-[0-9]{3}$ ]] || blocked "RC row $row_number имеет invalid id"
    [[ "$kind" == capability || "$kind" == limitation ]] ||
      blocked "$id: kind должен быть capability|limitation"
    [[ -n "$constraint" && ! "${constraint,,}" =~ (unknown|tbd|todo|placeholder) ]] ||
      blocked "$id: measurable constraint отсутствует"
    [[ "$provenance" == 'tracking/PMO-constraints.md#cycle1.runtime_constraints' ]] ||
      blocked "$id: provenance invalid"
    [[ -z "${nfr_ids[$id]+x}" ]] || blocked "duplicate Runtime Constraint id: $id"
    nfr_ids["$id"]=1
  done
fi

if [[ "$MODE" == architecture ]]; then
  HLD="$(resolve_one high-level-design 'stage3-design/outputs/ARCH-*HLD*.md')"
  [[ -f "$HLD" && ! -L "$HLD" ]] || blocked 'current HLD отсутствует или является symlink'
  nfr_ref="${NFR#"$PROJECT_PATH/"}"
  grep -Fqx '## Runtime Constraints' "$HLD" || blocked 'HLD не содержит ## Runtime Constraints'
  grep -Fqx "Runtime Constraints source: $nfr_ref#Runtime Constraints" "$HLD" ||
    blocked 'HLD Runtime Constraints source не указывает current NFR'
  grep -Fqx 'Runtime Constraints scope: application-design-only' "$HLD" ||
    blocked 'HLD Runtime Constraints scope должен быть application-design-only'
  grep -Fqx 'Deployment/operations authorization: NOT_GRANTED' "$HLD" ||
    blocked 'Runtime Constraints не дают deployment/operations authorization'
  grep -Eq '^[[:space:]]*Deployment Constraint:' "$HLD" &&
    blocked 'legacy Deployment Constraint запрещён в HLD'

  mapfile -t hld_ids < <(grep -oE '^RC-[0-9]{3}:' "$HLD" | sed 's/:$//' | sort -u || true)
  if (( unknown == 1 )); then
    grep -Eq '^Runtime Constraints status: (OPEN ISSUE|NOT_APPLICABLE)$' "$HLD" ||
      blocked 'HLD должен сохранить unresolved Runtime Constraints status'
    (( ${#hld_ids[@]} == 0 )) || blocked 'HLD не может изобретать RC ids для unknown constraint'
  else
    grep -Fqx 'Runtime Constraints status: CONFIRMED' "$HLD" ||
      blocked 'HLD должен сохранить CONFIRMED Runtime Constraints status'
    (( ${#hld_ids[@]} == ${#nfr_ids[@]} )) ||
      blocked 'HLD и NFR имеют разное число Runtime Constraint ids'
    for id in "${!nfr_ids[@]}"; do
      grep -Eq "^$id:[[:space:]]*[^[:space:]].*$" "$HLD" ||
        blocked "$id отсутствует в HLD"
    done
    for id in "${hld_ids[@]}"; do
      [[ -n "${nfr_ids[$id]:-}" ]] || blocked "$id добавлен в HLD без NFR source"
    done
  fi
fi

echo "RUNTIME CONSTRAINTS VERIFIED: mode=$MODE status=$([[ $unknown == 1 ]] && echo OPEN || echo CONFIRMED)"

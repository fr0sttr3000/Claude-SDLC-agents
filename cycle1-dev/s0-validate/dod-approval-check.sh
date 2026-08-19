#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project}"
EXPECTED_SOURCE="${2:?Укажи exact source revision}"
EXPECTED_RUN="${3:-}"
MODE="${4:-verify}"
blocked() { echo "DOD APPROVAL BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked 'Project не найден'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
[[ "$EXPECTED_SOURCE" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
  blocked 'invalid source revision'
[[ "$MODE" == verify || "$MODE" == request ]] || blocked 'mode must be verify or request'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT_TOOL="$SCRIPT_DIR/current-artifact.sh"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"

field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted {
    value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value);
    print value; exit
  }' "$file"
}

resolve_one() {
  bash "$CURRENT_TOOL" resolve-compatible-one "$PROJECT_PATH" "$1" "$EXPECTED_RUN" "$EXPECTED_SOURCE"
}

run_matches_expected() {
  local actual="$1" expected
  [[ -n "$EXPECTED_RUN" ]] || return 0
  IFS=',' read -r -a expected_runs <<< "$EXPECTED_RUN"
  for expected in "${expected_runs[@]}"; do
    [[ "$actual" == "$expected" ]] && return 0
  done
  return 1
}

mapfile -t build_records < <(
  find "$PROJECT_PATH/tracking/evidence/v1" -maxdepth 1 -type f -name '*.yaml' -print 2>/dev/null |
    sort | while IFS= read -r record; do
      [[ "$(field "$record" check_id)" == build &&
        "$(field "$record" source_revision)" == "$EXPECTED_SOURCE" ]] && printf '%s\n' "$record"
    done
)
(( ${#build_records[@]} == 1 )) ||
  blocked "exact source requires one build Evidence v1, found ${#build_records[@]}"
build_record="${build_records[0]}"
bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$build_record" \
  --expected-source "$EXPECTED_SOURCE" --expected-check build >/dev/null ||
  blocked 'build Evidence v1 invalid'
[[ "$(field "$build_record" verdict)" == PASS ]] || blocked 'build Evidence v1 must PASS'
subject_digest="$(field "$build_record" subject_digest)"

profile_revision="$(field "$PROFILE" revision)"
mapfile -t review_refs < <(
  bash "$CURRENT_TOOL" resolve-compatible "$PROJECT_PATH" techlead-reviews \
    "$EXPECTED_RUN" "$EXPECTED_SOURCE"
)
(( ${#review_refs[@]} > 0 )) || blocked 'current Tech Lead reviews absent'
declare -a review_tokens=()
for review_ref in "${review_refs[@]}"; do
  review="$PROJECT_PATH/$review_ref"
  bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" "$review_ref" >/dev/null ||
    blocked "$review_ref common Artifact Metadata invalid"
  [[ "$(field "$review" source_revision)" == "$EXPECTED_SOURCE" ]] ||
    blocked "$review_ref source revision mismatch"
  [[ "$(field "$review" product_profile_revision)" == "$profile_revision" ]] ||
    blocked "$review_ref Product Profile revision mismatch"
  [[ "$(field "$review" status)" == PASS ]] || blocked "$review_ref status must PASS"
  grep -Eq '(^|[^A-Z])(APPROVED|LGTM)([^A-Z]|$)' "$review" ||
    blocked "$review_ref has no approved decision"
  ! grep -Eiq 'CHANGES[ _-]?REQUESTED|REQUEST_CHANGES|\\[BLOCKER\\]|\\[MAJOR\\]' "$review" ||
    blocked "$review_ref contains blocking review result"
  review_sha="$(sha256sum "$review" | awk '{print $1}')"
  review_tokens+=("techlead-review:$review_ref@$review_sha")
done

expected_scope='DOD-1,DOD-2,DOD-3,DOD-4,DOD-5,DOD-6,DOD-7,DOD-8,DOD-9,DOD-10,DOD-11'
for review_token in "${review_tokens[@]}"; do
  expected_scope+=";$review_token"
done

if [[ "$MODE" == request ]]; then
  [[ "$EXPECTED_RUN" =~ ^[A-Za-z0-9._-]+$ ]] ||
    blocked 'request mode requires one exact launcher run id'
  expected_scope+=";execution-run:$EXPECTED_RUN"
  approval_run_tag="$(printf '%s' "$EXPECTED_RUN" | tr '[:lower:]' '[:upper:]')"
  printf '%s\n' 'DOD APPROVAL REQUEST READY' \
    "approval_id: APPROVAL-DOD-$approval_run_tag" \
    "source_revision: $EXPECTED_SOURCE" \
    "subject_digest: $subject_digest" \
    "scope: $expected_scope" \
    'evidence_producer: s4-dev'
  exit 0
fi

declare -a approval_refs=()
while IFS= read -r approval_path; do
  [[ "$(field "$approval_path" source_revision)" == "$EXPECTED_SOURCE" ]] || continue
  candidate_scope="$(field "$approval_path" scope)"
  if [[ -n "$EXPECTED_RUN" ]]; then
    [[ "$candidate_scope" =~ \;execution-run:([A-Za-z0-9._-]+)$ ]] || continue
    run_matches_expected "${BASH_REMATCH[1]}" || continue
  fi
  approval_refs+=("${approval_path#"$PROJECT_PATH/"}")
done < <(find "$PROJECT_PATH/tracking/approvals" -maxdepth 1 -type f \
  -name 'APPROVAL-DOD-*.yaml' -print 2>/dev/null | sort)
(( ${#approval_refs[@]} == 1 )) ||
  blocked "exact source/run requires one full DoD approval, found ${#approval_refs[@]}"
approval_ref="${approval_refs[0]}"
approval="$PROJECT_PATH/$approval_ref"
bash "$SCRIPT_DIR/human-approval-check.sh" "$PROJECT_PATH" "$approval_ref" \
  "$EXPECTED_SOURCE" "$subject_digest" s4-dev >/dev/null ||
  blocked 'Human Approval v1 invalid'
[[ "$(field "$approval" decision)" == APPROVE ]] || blocked 'DoD decision must APPROVE'

scope="$(field "$approval" scope)"
approval_run=''
if [[ "$scope" =~ \;execution-run:([A-Za-z0-9._-]+)$ ]]; then
  approval_run="${BASH_REMATCH[1]}"
  run_matches_expected "$approval_run" || blocked 'approval belongs to another launcher run'
  expected_scope+=";execution-run:$approval_run"
elif [[ -n "$EXPECTED_RUN" ]]; then
  blocked 'approval is not bound to the expected launcher run'
fi
[[ "$scope" == "$expected_scope" ]] ||
  blocked 'approval scope is not the exact DoD/review/run set'

echo "DOD APPROVAL VERIFIED: approval=$approval_ref source=$EXPECTED_SOURCE subject=$subject_digest run=${approval_run:-none} reviews=${#review_refs[@]} items=11"

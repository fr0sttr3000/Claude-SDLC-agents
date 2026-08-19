#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: gate4-pr-set-check.sh <Project>}"
[[ -d "$PROJECT_INPUT" ]] || { echo 'GATE4 PR SET BLOCKED: Project not found' >&2; exit 2; }
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT="$HERE/current-artifact.sh"
fail() { echo "GATE4 PR SET BLOCKED: $*" >&2; exit 1; }
field() {
  awk -F: -v key="$2" '$1 == key {v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); print v; exit}' "$1"
}
resolve_set() {
  bash "$CURRENT" resolve-compatible "$PROJECT" "$1" 2>/dev/null ||
    fail "current $1 set is absent or invalid"
}
pr_key() {
  local kind="$1" base
  base="$(basename "$2")"
  case "$kind" in
    summary) base="${base#*PR-}"; base="${base%-summary.md}" ;;
    notes) base="${base#*update-notes-PR}"; base="${base%.md}" ;;
    review) base="${base#*review-PR}"; base="${base%.md}" ;;
  esac
  [[ "$base" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "invalid PR key in $2"
  printf '%s\n' "$base"
}

declare -A summary_ref=() notes_ref=() review_ref=() sources=()
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  key="$(pr_key summary "$ref")"
  [[ -z "${summary_ref[$key]:-}" ]] || fail "duplicate summary for PR $key"
  summary_ref["$key"]="$ref"
done < <(resolve_set development-pr-summary)
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  key="$(pr_key notes "$ref")"
  [[ -z "${notes_ref[$key]:-}" ]] || fail "duplicate update notes for PR $key"
  notes_ref["$key"]="$ref"
done < <(resolve_set development-update-notes)
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  key="$(pr_key review "$ref")"
  [[ -z "${review_ref[$key]:-}" ]] || fail "duplicate review for PR $key"
  review_ref["$key"]="$ref"
done < <(resolve_set techlead-reviews)
(( ${#summary_ref[@]} > 0 )) || fail 'empty PR set'
[[ ${#summary_ref[@]} -eq ${#notes_ref[@]} && ${#summary_ref[@]} -eq ${#review_ref[@]} ]] ||
  fail 'summary/update-notes/review set cardinality differs'

for key in "${!summary_ref[@]}"; do
  [[ -n "${notes_ref[$key]:-}" && -n "${review_ref[$key]:-}" ]] ||
    fail "PR $key is missing update notes or review"
  summary="$PROJECT/${summary_ref[$key]}"
  notes="$PROJECT/${notes_ref[$key]}"
  review="$PROJECT/${review_ref[$key]}"
  summary_source="$(field "$summary" source_revision)"
  [[ "$summary_source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
    fail "PR $key summary has no exact source"
  [[ "$(field "$notes" source_revision)" == "$summary_source" ]] ||
    fail "PR $key update notes source mismatch"
  [[ "$(field "$review" source_revision)" == "$summary_source" ]] ||
    fail "PR $key review source mismatch"
  [[ "$(field "$review" status)" == PASS ]] || fail "PR $key review status is not PASS"
  grep -Eq '(^|[^A-Z])(APPROVED|LGTM)([^A-Z]|$)' "$review" ||
    fail "PR $key has no approved review decision"
  ! grep -Eiq 'CHANGES[ _-]?REQUESTED|REQUEST_CHANGES|\[BLOCKER\]|\[MAJOR\]' "$review" ||
    fail "PR $key review contains blocking findings"
  sources["$summary_source"]=1
done
for key in "${!notes_ref[@]}"; do [[ -n "${summary_ref[$key]:-}" ]] || fail "orphan notes for PR $key"; done
for key in "${!review_ref[@]}"; do [[ -n "${summary_ref[$key]:-}" ]] || fail "orphan review for PR $key"; done

for source in "${!sources[@]}"; do
  bash "$HERE/pr-evidence-check.sh" "$PROJECT" "$source" >/dev/null ||
    fail "PR evidence invalid for source $source"
done
echo "GATE4 PR SET VERIFIED: prs=${#summary_ref[@]} sources=${#sources[@]}"

#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?usage: quality-configuration-commit.sh <Project>}"
blocked() { echo "QUALITY CONFIG TRANSACTION BLOCKED: $*" >&2; exit 1; }
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project not found'
PROJECT="$(cd "$PROJECT_INPUT" && pwd -P)"
CANDIDATE="$PROJECT/tracking/quality-config-candidate"
TX="$PROJECT/tracking/.quality-config-transaction"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

restore_transaction() {
  local rel
  [[ -d "$TX" ]] || return 0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    mkdir -p "$(dirname "$PROJECT/$rel")"
    if [[ -f "$TX/backup/$rel" ]]; then
      cp "$TX/backup/$rel" "$PROJECT/$rel"
    else
      rm -f "$PROJECT/$rel"
    fi
  done < "$TX/targets"
  rm -rf "$TX"
}

if [[ -d "$TX" ]]; then
  restore_transaction
  blocked 'recovered an interrupted prior transaction; rerun with a fresh candidate'
fi
[[ -d "$CANDIDATE" && ! -L "$CANDIDATE" ]] || blocked 'candidate directory missing/symlink'
for rel in quality-gates.md quality-characteristics-v1.tsv quality-characteristics.md; do
  [[ -s "$CANDIDATE/$rel" && ! -L "$CANDIDATE/$rel" ]] || blocked "candidate missing/symlink: $rel"
done
revision="$(awk -F: '$1 == "revision" {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$CANDIDATE/quality-gates.md")"
[[ "$revision" =~ ^[1-9][0-9]*$ ]] || blocked 'candidate policy revision invalid'
current_revision=0
if [[ -e "$PROJECT/tracking/quality-gates.md" || -L "$PROJECT/tracking/quality-gates.md" ]]; then
  [[ -f "$PROJECT/tracking/quality-gates.md" && ! -L "$PROJECT/tracking/quality-gates.md" ]] ||
    blocked 'current policy is not a regular file'
  current_revision="$(awk -F: '$1 == "revision" {gsub(/[[:space:]]/, "", $2); print $2; exit}' \
    "$PROJECT/tracking/quality-gates.md")"
  [[ "$current_revision" =~ ^[1-9][0-9]*$ ]] || blocked 'current policy revision invalid'
fi
(( revision == current_revision + 1 )) ||
  blocked "revision gap/replay: current=$current_revision candidate=$revision"
snapshot_rel="quality-gates-history/revision-$revision.md"
[[ -s "$CANDIDATE/$snapshot_rel" && ! -L "$CANDIDATE/$snapshot_rel" ]] || blocked 'candidate snapshot missing/symlink'
cmp -s "$CANDIDATE/quality-gates.md" "$CANDIDATE/$snapshot_rel" || blocked 'candidate policy/snapshot differ'
[[ ! -e "$PROJECT/tracking/$snapshot_rel" && ! -L "$PROJECT/tracking/$snapshot_rel" ]] ||
  blocked 'immutable policy snapshot already exists'

targets=(tracking/quality-gates.md tracking/quality-characteristics-v1.tsv tracking/quality-characteristics.md "tracking/$snapshot_rel")
if (( revision > 1 )); then
  previous_snapshot="$PROJECT/tracking/quality-gates-history/revision-$current_revision.md"
  [[ -f "$previous_snapshot" && ! -L "$previous_snapshot" ]] ||
    blocked 'previous immutable snapshot missing/symlink'
  invalidation_rel="quality-policy-invalidations/revision-$revision.md"
  [[ -s "$CANDIDATE/$invalidation_rel" && ! -L "$CANDIDATE/$invalidation_rel" ]] ||
    blocked 'candidate invalidation record missing/symlink'
  [[ ! -e "$PROJECT/tracking/$invalidation_rel" && ! -L "$PROJECT/tracking/$invalidation_rel" ]] ||
    blocked 'immutable policy invalidation already exists'
  grep -Fqx "policy_revision: quality-v1-r$revision" "$CANDIDATE/$invalidation_rel" ||
    blocked 'candidate invalidation policy revision mismatch'
  grep -Fqx "invalidates: quality-v1-r< $revision" "$CANDIDATE/$invalidation_rel" ||
    blocked 'candidate invalidation range mismatch'
  grep -Fqx "previous_snapshot_sha256: $(sha256sum "$previous_snapshot" | awk '{print $1}')" \
    "$CANDIDATE/$invalidation_rel" || blocked 'candidate previous snapshot digest mismatch'
  targets+=("tracking/$invalidation_rel")
fi
mkdir -p "$TX/backup"
printf '%s\n' "${targets[@]}" > "$TX/targets"
for rel in "${targets[@]}"; do
  if [[ -f "$PROJECT/$rel" ]]; then
    mkdir -p "$TX/backup/$(dirname "$rel")"
    cp "$PROJECT/$rel" "$TX/backup/$rel"
  fi
done
committed=0
trap 'if (( committed == 0 )); then restore_transaction; fi' EXIT
published=0
for rel in "${targets[@]}"; do
  candidate_rel="${rel#tracking/}"
  mkdir -p "$(dirname "$PROJECT/$rel")"
  cp "$CANDIDATE/$candidate_rel" "$PROJECT/$rel.next"
  mv "$PROJECT/$rel.next" "$PROJECT/$rel"
  published=$((published + 1))
  if [[ "${QUALITY_CONFIG_FAULT_AFTER_PUBLISH:-0}" == "$published" ]]; then
    blocked "fault injection after publish $published"
  fi
done
if ! bash "$SCRIPT_DIR/quality-gates-check.sh" "$PROJECT" >/dev/null ||
  ! bash "$SCRIPT_DIR/quality-characteristics-check.sh" "$PROJECT" >/dev/null; then
  blocked 'candidate validation failed; previous complete configuration restored'
fi
committed=1
rm -rf "$TX" "$CANDIDATE"
trap - EXIT
echo "QUALITY CONFIG TRANSACTION COMMITTED: policy_revision=quality-v1-r$revision"

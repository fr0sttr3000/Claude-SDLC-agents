#!/usr/bin/env bash

setup_human_approval_receipts() {
  local root="$1"
  SDLC_HUMAN_APPROVAL_RECEIPT_ROOT="$root"
  export SDLC_HUMAN_APPROVAL_RECEIPT_ROOT
  mkdir -p "$root"
}

record_human_approval_receipt() {
  local project="$1" approval="$2" project_path project_hash approval_id observed approval_sha
  local receipt_dir
  project_path="$(cd "$project" && pwd -P)"
  project_hash="$(printf '%s' "$project_path" | sha256sum | awk '{print $1}')"
  approval_id="$(awk -F: '$1 == "approval_id" {v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); print v}' "$approval")"
  observed="$(awk -F: '$1 == "observed_at" {v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); print v}' "$approval")"
  approval_sha="$(sha256sum "$approval" | awk '{print $1}')"
  receipt_dir="$SDLC_HUMAN_APPROVAL_RECEIPT_ROOT/$project_hash"
  mkdir -p "$receipt_dir"
  {
    printf '%s\n' 'schema_version: 1' "approval_id: $approval_id"
    printf '%s\n' "project_path_sha256: $project_hash" "approval_sha256: $approval_sha"
    printf '%s\n' "recorded_at: $observed"
  } >"$receipt_dir/$approval_id.receipt"
}

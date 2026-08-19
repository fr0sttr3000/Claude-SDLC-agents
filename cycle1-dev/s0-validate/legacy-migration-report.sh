#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи Project для dry-run migration report}"
[[ -d "$PROJECT_INPUT" ]] || { echo "MIGRATION REPORT BLOCKED: Project не найден: $PROJECT_INPUT" >&2; exit 2; }
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"

sanitize_path() {
  local value="$1"
  value="${value//$'\t'/<TAB>}"
  value="${value//$'\n'/<LF>}"
  printf '%s' "$value"
}

has_artifact_metadata_v1() {
  local file="$1" key
  [[ "$(sed -n '1p' "$file")" == '---' ]] || return 1
  for key in schema_version artifact_id artifact_type project stage producer source_revision status inputs outputs tags; do
    grep -Eq "^${key}:[[:space:]]*[^[:space:]].*$" "$file" || return 1
  done
}

printf '%s\n' $'path\tclassification\tactive_verdict\trecommended_action'

while IFS= read -r -d '' file; do
  relative="${file#"$PROJECT_PATH"/}"
  safe_relative="$(sanitize_path "$relative")"
  case "$relative" in
    stage6-deploy/*|stage7-ops/*)
      printf '%s\t%s\t%s\t%s\n' "$safe_relative" HISTORICAL_EXCLUDED EXCLUDED_FROM_ACTIVE_VERDICT PRESERVE_NO_ACTIVE_MIGRATION
      ;;
    tracking/evidence/v1/*.yaml|tracking/evidence/v1/*.json)
      printf '%s\t%s\t%s\t%s\n' "$safe_relative" CURRENT_MACHINE_EVIDENCE REVALIDATE_REQUIRED VALIDATE_EXACT_SOURCE_AND_POLICY
      ;;
    *.md)
      if has_artifact_metadata_v1 "$file"; then
        printf '%s\t%s\t%s\t%s\n' "$safe_relative" CURRENT_MARKDOWN VALIDATION_REQUIRED VALIDATE_WITH_OWNING_CONTRACT
      elif [[ "$relative" == tracking/evidence/* ]] ||
           grep -Eiq '^[[:space:]]*(status|verdict)[[:space:]]*:[[:space:]]*(PASS|VERIFIED)[[:space:]]*$' "$file"; then
        printf '%s\t%s\t%s\t%s\n' "$safe_relative" LEGACY_SELF_ATTESTED_EVIDENCE UNVERIFIED NEVER_PROMOTE_PASS_REGENERATE_FROM_MACHINE_EVIDENCE
      else
        printf '%s\t%s\t%s\t%s\n' "$safe_relative" LEGACY_MARKDOWN UNVERIFIED UPGRADE_ON_OWNER_TOUCH
      fi
      ;;
  esac
done < <(find "$PROJECT_PATH" -type f \( -name '*.md' -o -path '*/tracking/evidence/v1/*.yaml' -o -path '*/tracking/evidence/v1/*.json' \) -print0 | sort -z)

printf '%s\n' 'MIGRATION DRY-RUN COMPLETE: no Project files were changed.' >&2

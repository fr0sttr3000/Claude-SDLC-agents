#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
VERSION="${2:?Укажи version vMAJOR.MINOR.PATCH}"
blocked() { echo "RELEASE NOTES BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[[ "$VERSION" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
  blocked 'version must be vMAJOR.MINOR.PATCH without leading zeroes'

MANIFEST="$PROJECT_PATH/tracking/completion/CYCLE1-completion-v2.yaml"
REF="tracking/releases/REL-$VERSION-release-notes.md"
NOTES="$PROJECT_PATH/$REF"
[[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] || blocked 'completion manifest missing/symlink'
bash "$SCRIPT_DIR/cycle1-completion-check.sh" "$PROJECT_PATH" >/dev/null ||
  blocked 'Cycle 1 completion is not VERIFIED'
[[ -f "$NOTES" && ! -L "$NOTES" ]] || blocked "release notes missing/symlink: $REF"
bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" "$REF" >/dev/null ||
  blocked 'common Artifact Metadata invalid'

field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

[[ "$(field "$NOTES" artifact_type)" == project-release-notes ]] || blocked 'artifact_type mismatch'
[[ "$(field "$NOTES" stage)" == TRACKING ]] || blocked 'stage must be TRACKING'
[[ "$(field "$NOTES" producer)" == s0-tracker ]] || blocked 'producer must be s0-tracker'
[[ "$(field "$NOTES" status)" == VALIDATED ]] || blocked 'status must be VALIDATED'
[[ "$(field "$NOTES" release_version)" == "$VERSION" ]] || blocked 'release_version mismatch'
[[ "$(field "$NOTES" release_state)" == PREPARED_NOT_RELEASED ]] || blocked 'release_state mismatch'
[[ "$(field "$NOTES" completion_manifest_ref)" == tracking/completion/CYCLE1-completion-v2.yaml ]] ||
  blocked 'completion_manifest_ref mismatch'
[[ "$(field "$NOTES" completion_manifest_sha256)" == "$(sha256sum "$MANIFEST" | awk '{print $1}')" ]] ||
  blocked 'completion manifest digest mismatch'
for binding in \
  'completion_id|completion_id' \
  'completion_source_revision|source_revision' \
  'completion_subject_digest|subject_digest'; do
  notes_key="${binding%%|*}"; manifest_key="${binding#*|}"
  [[ "$(field "$NOTES" "$notes_key")" == "$(field "$MANIFEST" "$manifest_key")" ]] ||
    blocked "$notes_key mismatch"
done
[[ "$(field "$NOTES" source_revision)" == "$(field "$MANIFEST" source_revision)" ]] ||
  blocked 'common source_revision mismatch'
for action in external_publication_action build_action deploy_action production_action; do
  [[ "$(field "$NOTES" "$action")" == not-performed ]] || blocked "$action must be not-performed"
done
[[ "$(field "$NOTES" cycle23_status)" == FROZEN_NOT_READY ]] || blocked 'Cycle 2/3 boundary mismatch'

grep -Fqx "# Release Notes — $VERSION" "$NOTES" || blocked 'title/version mismatch'
for section in 'Validated scope' Changes 'Known limitations' 'Migration notes' \
  'Evidence and provenance' 'Explicit exclusions' 'Obsidian Links'; do
  grep -Fqx "## $section" "$NOTES" || blocked "required section missing: $section"
done

KNOWN_ISSUES="$PROJECT_PATH/tracking/known-issues.md"
if [[ -e "$KNOWN_ISSUES" ]]; then
  [[ -f "$KNOWN_ISSUES" && ! -L "$KNOWN_ISSUES" ]] || blocked 'known-issues.md must be a regular file'
  bash "$SCRIPT_DIR/known-issue-lifecycle-check.sh" "$PROJECT_PATH" >/dev/null ||
    blocked 'Known Issue lifecycle invalid'
  mapfile -t open_known_issues < <(awk '
    /^###[[:space:]]+KI-[A-Za-z0-9._-]+/ {
      if (id != "" && status == "OPEN") print id
      id=$2; status=""; next
    }
    id != "" && /^- Status:[[:space:]]*/ {
      value=$0
      sub(/^- Status:[[:space:]]*/, "", value)
      split(value, parts, /[[:space:]]+/)
      status=parts[1]
    }
    END { if (id != "" && status == "OPEN") print id }
  ' "$KNOWN_ISSUES" | sort -u)
  limitations_section="$(awk '
    $0 == "## Known limitations" { active=1; next }
    active && /^## / { exit }
    active { print }
  ' "$NOTES")"
  for known_issue_id in "${open_known_issues[@]}"; do
    known_issue_count="$(awk -v wanted="$known_issue_id" '
      {
        for (i=1; i<=NF; i++) {
          token=$i
          gsub(/^[^A-Za-z0-9._-]+/, "", token)
          gsub(/[^A-Za-z0-9._-]+$/, "", token)
          if (token == wanted) count++
        }
      }
      END { print count+0 }
    ' <<< "$limitations_section")"
    [[ "$known_issue_count" == 1 ]] ||
      blocked "OPEN Known Issue must occur exactly once in Known limitations: $known_issue_id count=$known_issue_count"
  done
fi
grep -Eqi 'external publication.*not-performed|external publication.*не выполня' "$NOTES" ||
  blocked 'external publication exclusion missing'
grep -Eqi 'deploy.*not-performed|deploy.*не выполня' "$NOTES" || blocked 'deploy exclusion missing'
grep -Eqi 'production.*not-performed|production.*не выполня' "$NOTES" || blocked 'production exclusion missing'
grep -Eqi 'Cycle 2/3.*FROZEN_NOT_READY|Cycle 2/3.*не выполня' "$NOTES" || blocked 'Cycle 2/3 exclusion missing'

echo "RELEASE NOTES VERIFIED: version=$VERSION source=$(field "$MANIFEST" source_revision) completion=$(field "$MANIFEST" completion_id) path=$REF state=PREPARED_NOT_RELEASED"

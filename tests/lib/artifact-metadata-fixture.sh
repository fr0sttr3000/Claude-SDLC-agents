#!/usr/bin/env bash

complete_artifact_metadata_fixture() {
  local file="$1" project="$2" artifact_id="$3" stage="$4" producer="$5"
  local source_revision="${6:-none}" status="${7:-DRAFT}" rel stage_tag tmp
  rel="${file#"$project/"}"
  [[ "$rel" != "$file" && -f "$file" && "$(head -1 "$file")" == --- ]] || return 1
  stage_tag="stage${stage#S}"
  [[ "$stage" != TRACKING ]] || stage_tag=tracking
  [[ -f "$project/Dashboard.md" ]] || printf '%s\n' '# Dashboard' > "$project/Dashboard.md"
  local has_project=0 has_source=0 has_status=0
  rg -q '^project:' "$file" && has_project=1
  rg -q '^source_revision:' "$file" && has_source=1
  rg -q '^status:' "$file" && has_status=1
  tmp="$(mktemp "${file}.metadata.XXXXXX")"
  awk -v artifact_id="$artifact_id" -v project_name="$(basename "$project")" \
    -v stage="$stage" -v producer="$producer" -v source_revision="$source_revision" \
    -v status="$status" -v rel="$rel" -v stage_tag="$stage_tag" \
    -v has_project="$has_project" -v has_source="$has_source" -v has_status="$has_status" '
    NR == 1 {
      print
      print "artifact_id: " artifact_id
      if (!has_project) print "project: " project_name
      print "stage: " stage
      print "producer: " producer
      if (!has_source) print "source_revision: " source_revision
      if (!has_status) print "status: " status
      print "inputs: none"
      print "outputs: " rel
      print "tags: sdlc,cycle1," stage_tag ",fixture"
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  printf '\n## Obsidian Links\n\n- Dashboard: [[Dashboard]]\n- Outputs: [[%s]]\n' "${rel%.md}" >> "$file"
}

write_artifact_metadata_fixture() {
  local file="$1" project="$2" artifact_id="$3" artifact_type="$4" stage="$5" producer="$6"
  local source_revision="${7:-none}" status="${8:-DRAFT}" title="${9:-Fixture Artifact}"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' '---' 'schema_version: 1' "artifact_type: $artifact_type" '---' '' "# $title" > "$file"
  complete_artifact_metadata_fixture "$file" "$project" "$artifact_id" "$stage" "$producer" \
    "$source_revision" "$status"
}

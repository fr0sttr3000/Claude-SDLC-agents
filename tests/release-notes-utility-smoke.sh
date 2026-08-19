#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-release-notes.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/human-approval-receipts"
PROJECTS="$TMP_DIR/projects"
PROJECT=CompletionFixture
PROJECT_ROOT="$PROJECTS/$PROJECT"
CHECK="$ROOT/cycle1-dev/s0-validate/release-notes-check.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit }' "$file"
}

export XDG_STATE_HOME="$TMP_DIR/state"
CYCLE1_COMPLETION_FIXTURE_EXPORT_DIR="$PROJECT_ROOT" \
  CYCLE1_COMPLETION_FIXTURE_STATE_DIR="$XDG_STATE_HOME" \
  bash "$ROOT/tests/cycle1-completion-v2-smoke.sh" >/dev/null
while IFS= read -r approval; do
  record_human_approval_receipt "$PROJECT_ROOT" "$approval"
done < <(find "$PROJECT_ROOT/tracking/approvals" -maxdepth 1 -type f -name 'APPROVAL-*.yaml' | sort)
MANIFEST="$PROJECT_ROOT/tracking/completion/CYCLE1-completion-v2.yaml"
MANIFEST_VALID="$TMP_DIR/manifest.valid"
cp "$MANIFEST" "$MANIFEST_VALID"

write_release_notes() {
  local version="$1" ref="tracking/releases/REL-$1-release-notes.md" file
  local source completion_id subject manifest_sha id
  file="$PROJECT_ROOT/$ref"
  source="$(field "$MANIFEST" source_revision)"
  completion_id="$(field "$MANIFEST" completion_id)"
  subject="$(field "$MANIFEST" subject_digest)"
  manifest_sha="$(sha256sum "$MANIFEST" | awk '{print $1}')"
  id="REL-${version^^}"
  mkdir -p "$(dirname "$file")"
  {
    printf '%s\n' '---' 'schema_version: 1' "artifact_id: $id" \
      'artifact_type: project-release-notes' "project: $PROJECT" 'stage: TRACKING' \
      'producer: s0-tracker' "source_revision: $source" 'status: VALIDATED' \
      'inputs: tracking/completion/CYCLE1-completion-v2.yaml,tracking/cycle-summary.md' \
      "outputs: $ref" 'tags: sdlc,cycle1,tracking,release' \
      "release_version: $version" 'release_state: PREPARED_NOT_RELEASED' \
      'completion_manifest_ref: tracking/completion/CYCLE1-completion-v2.yaml' \
      "completion_manifest_sha256: $manifest_sha" "completion_id: $completion_id" \
      "completion_source_revision: $source" "completion_subject_digest: $subject" \
      'external_publication_action: not-performed' 'build_action: not-performed' \
      'deploy_action: not-performed' 'production_action: not-performed' \
      'cycle23_status: FROZEN_NOT_READY' '---' '' "# Release Notes — $version" '' \
      '## Validated scope' '' 'Verified Cycle 1 completion only.' '' \
      '## Changes' '' 'none' '' '## Known limitations' '' 'none' '' \
      '## Migration notes' '' 'not documented' '' '## Evidence and provenance' '' \
      "Completion: $completion_id; source: $source." '' '## Explicit exclusions' '' \
      '- external publication: not-performed' \
      '- build: not-performed' '- deploy: not-performed' '- production: not-performed' \
      '- Cycle 2/3: FROZEN_NOT_READY; не выполнялись' '' '## Obsidian Links' '' \
      '- Dashboard: [[Dashboard]]' \
      '- Completion: [[tracking/completion/CYCLE1-completion-v2.yaml]]' \
      '- Summary: [[tracking/cycle-summary]]' "- Output: [[${ref%.md}]]"
  } > "$file"
}

write_release_notes v1.2.3
bash "$CHECK" "$PROJECT_ROOT" v1.2.3 >/dev/null || fail 'valid release notes were rejected'

{
  printf '%s\n' '# Known Issues — release fixture' '' '### KI-REL-001 — Accepted limitation' \
    '- Severity: CVSS-MEDIUM' '- Trigger: user opens the legacy summary view' \
    '- Impact: user-facing — summary text is delayed' \
    '- Workaround: refresh the summary view once' \
    '- Detection signal: exact delayed-summary log event' '- Auto-remediation: нет' \
    '- → tech-debt: TD-SG3-SCA' \
    '- Human Approval v1: tracking/approvals/APPROVAL-KI-REL-001.yaml' \
    '- Fix release version: none' '- Fix build evidence ref: none' \
    '- Fix build evidence sha256: none' '- Fix source revision: none' \
    '- Fix verification test id: none' '- Operational scope: FROZEN_NOT_READY' \
    '- Alert cleanup evidence: none' '- Runbook cleanup evidence: none' '- Status: OPEN'
} > "$PROJECT_ROOT/tracking/known-issues.md"
if bash "$CHECK" "$PROJECT_ROOT" v1.2.3 >"$TMP_DIR/missing-open-ki.out" 2>&1; then
  fail 'release notes omitting an OPEN Known Issue were accepted'
fi
grep -Fq 'OPEN Known Issue must occur exactly once in Known limitations: KI-REL-001 count=0' \
  "$TMP_DIR/missing-open-ki.out" || fail 'missing OPEN Known Issue reason was not reported'
sed -i '/^## Known limitations$/,/^## Migration notes$/ s/^none$/- KI-REL-001 — accepted limitation/' \
  "$PROJECT_ROOT/tracking/releases/REL-v1.2.3-release-notes.md"
bash "$CHECK" "$PROJECT_ROOT" v1.2.3 >/dev/null ||
  fail 'release notes containing every OPEN Known Issue were rejected'
sed -i '/^## Known limitations$/a - KI-REL-001 — duplicate limitation' \
  "$PROJECT_ROOT/tracking/releases/REL-v1.2.3-release-notes.md"
if bash "$CHECK" "$PROJECT_ROOT" v1.2.3 >"$TMP_DIR/duplicate-open-ki.out" 2>&1; then
  fail 'duplicate OPEN Known Issue in release notes was accepted'
fi
grep -Fq 'count=2' "$TMP_DIR/duplicate-open-ki.out" ||
  fail 'duplicate OPEN Known Issue reason was not reported'
sed -i '/^- KI-REL-001 — duplicate limitation$/d' \
  "$PROJECT_ROOT/tracking/releases/REL-v1.2.3-release-notes.md"
rm "$PROJECT_ROOT/tracking/known-issues.md"
if bash "$CHECK" "$PROJECT_ROOT" v01.2.3 >/dev/null 2>&1; then
  fail 'non-canonical version was accepted'
fi

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single
export SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2
source "$ROOT/sdlc.sh"
PROJECTS="$TMP_DIR/projects"
PROJECT=CompletionFixture
BASE_PROFILE='codex||||'

set +e
prepare_release_notes_context '/release-notes v1.2.3' >"$TMP_DIR/noop.out" 2>&1
noop_rc=$?
set -e
[[ $noop_rc -eq 2 ]] || fail "valid rerun was not idempotent no-op: rc=$noop_rc"
grep -Fq 'RELEASE NOTES NO-OP' "$TMP_DIR/noop.out" || fail 'no-op verdict missing'

set +e
preview_out="$(printf 'b\n' | run_agent_with_preview s0-tracker "$PROJECT" '/release-notes v2.0.0' 2>&1)"
preview_rc=$?
set -e
[[ $preview_rc -ne 0 ]] || fail 'Preview cancellation unexpectedly executed'
[[ ! -e "$PROJECT_ROOT/tracking/releases/REL-v2.0.0-release-notes.md" ]] ||
  fail 'Preview cancellation wrote release notes'
for text in 'VERSION:  v2.0.0' 'SOURCE:' 'INPUT:    tracking/completion/CYCLE1-completion-v2.yaml' \
  'TARGET:   tracking/releases/REL-v2.0.0-release-notes.md' 'No action has run yet.'; do
  grep -Fq "$text" <<< "$preview_out" || fail "Preview missing: $text"
done

git() { : > "$TMP_DIR/git-called"; return 99; }
run_agent() {
  [[ "$1" == s0-tracker && "$3" == '/release-notes v3.0.0' ]] || return 1
  write_release_notes v3.0.0
}
manifest_sha_before="$(sha256sum "$MANIFEST" | awk '{print $1}')"
set +e
printf 'r\n' | run_agent_with_preview s0-tracker "$PROJECT" '/release-notes v3.0.0' \
  >"$TMP_DIR/write.out" 2>"$TMP_DIR/write.trace"
write_rc=$?
set -e
if [[ $write_rc -ne 0 ]]; then
    cat "$TMP_DIR/write.out" >&2
    cat "$TMP_DIR/write.trace" >&2
    fail 'explicitly confirmed release notes run failed'
fi
[[ ! -e "$TMP_DIR/git-called" ]] || fail 'release-notes utility invoked git'
[[ "$manifest_sha_before" == "$(sha256sum "$MANIFEST" | awk '{print $1}')" ]] ||
  fail 'release-notes utility changed immutable completion manifest'
grep -Fq 'RELEASE NOTES VERIFIED' "$TMP_DIR/write.out" || fail 'post-write verifier did not run'

mkdir -p "$PROJECT_ROOT/tracking/releases"
printf '%s\n' '# conflicting target' > "$PROJECT_ROOT/tracking/releases/REL-v4.0.0-release-notes.md"
set +e
prepare_release_notes_context '/release-notes v4.0.0' >"$TMP_DIR/conflict.out" 2>&1
conflict_rc=$?
set -e
[[ $conflict_rc -eq 1 ]] || fail 'conflicting existing target was not blocked'

cp "$MANIFEST_VALID" "$MANIFEST"
sed -i 's/status: VALIDATED/status: BLOCKED/' "$MANIFEST"
set +e
prepare_release_notes_context '/release-notes v5.0.0' >"$TMP_DIR/blocked.out" 2>&1
blocked_rc=$?
set -e
[[ $blocked_rc -eq 1 ]] || fail 'BLOCKED completion was accepted'
[[ ! -e "$PROJECT_ROOT/tracking/releases/REL-v5.0.0-release-notes.md" ]] ||
  fail 'BLOCKED completion produced release notes'

declare -f menu_utilities | grep -Fq 's0-tracker /release-notes vX.Y.Z' ||
  fail 'Project Utilities menu does not expose release notes'
declare -f execute_previewed_agent | grep -Fq 'release_notes_verified' ||
  fail 'previewed agent route lacks release-notes post-validator'

echo 'PASS: release notes utility smoke'

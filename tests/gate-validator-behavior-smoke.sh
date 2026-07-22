#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/sdlc-gate-validator.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_project() {
  local project="$1" stage
  for stage in stage1-planning stage2-requirements stage3-design stage4-dev \
    stage5-testing stage6-deploy stage7-ops; do
    mkdir -p "$project/$stage/inputs" "$project/$stage/outputs"
  done
  mkdir -p "$project/tracking" "$project/tests"
}

write_artifact() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' 'status: PASS' 'No open blockers.' > "$path"
}

DOR="$ROOT/cycle1-dev/s0-validate/dor-check.sh"
DOD="$ROOT/cycle1-dev/s0-validate/dod-check.sh"

P1="$TMP_DIR/gate1"
make_project "$P1"
write_artifact "$P1/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
write_artifact "$P1/stage1-planning/outputs/PMO-2026-07-21-charter.md"
write_artifact "$P1/stage1-planning/outputs/PMO-2026-07-21-risk-register.md"
gate1_output="$(bash "$DOR" "$P1" 1)" || fail 'valid Gate 1 fixture was rejected'
[[ "$gate1_output" == *'DoR PASSED'* ]] || fail 'Gate 1 did not reach its final verdict'
[[ "$gate1_output" == *'PMO-risk-register.md'* ]] || fail 'Gate 1 did not check the risk register'

P2="$TMP_DIR/gate2"
make_project "$P2"
write_artifact "$P2/stage2-requirements/outputs/BA-2026-07-21-BRD.md"
printf '%s\n' 'Latency p95 < 500ms' > "$P2/stage2-requirements/outputs/BA-2026-07-21-NFR.md"
write_artifact "$P2/stage2-requirements/outputs/BA-2026-07-21-RTM.md"
printf '%s\n' '## Story' 'Given a user' 'When an action occurs' 'Then the result is visible' > "$P2/stage2-requirements/outputs/PO-2026-07-21-backlog.md"
printf '%s\n' 'GATE 2 PASSED' > "$P2/stage2-requirements/outputs/QA-REQ-2026-07-21-review.md"
if bash "$DOR" "$P2" 2 > "$TMP_DIR/gate2-missing.out" 2>&1; then
  fail 'Gate 2 accepted missing test strategy and SG1 requirements'
fi
write_artifact "$P2/stage2-requirements/outputs/QA-2026-07-21-test-strategy.md"
write_artifact "$P2/stage2-requirements/outputs/SEC-2026-07-21-security-requirements.md"
bash "$DOR" "$P2" 2 > "$TMP_DIR/gate2-pass.out" || fail 'complete Gate 2 fixture was rejected'

P3="$TMP_DIR/gate3-non-api"
make_project "$P3"
write_artifact "$P3/stage3-design/outputs/ARCH-2026-07-21-HLD.md"
printf '%s\n' 'applicability: not-applicable' 'reason: no API boundary in HLD' > \
  "$P3/stage3-design/outputs/ARCH-2026-07-21-api-not-applicable.md"
write_artifact "$P3/stage3-design/outputs/SEC-2026-07-21-threat-model.md"
printf '%s\n' 'applicability: not-applicable' 'reason: no protected subjects/resources' > \
  "$P3/stage3-design/outputs/RBAC-2026-07-21-not-applicable.md"
printf '%s\n' 'applicability: not-applicable' 'reason: no persistent data store' > \
  "$P3/stage3-design/outputs/DBA-2026-07-21-not-applicable.md"
bash "$DOR" "$P3" 3 > "$TMP_DIR/gate3-non-api.out" ||
  fail 'Gate 3 rejected explicit API/RBAC/data-store not-applicable evidence'

P6="$TMP_DIR/gate6"
make_project "$P6"
printf '%s\n' 'status: PASS' > "$P6/stage6-deploy/outputs/DEPLOY-TDD-status.md"
write_artifact "$P6/stage6-deploy/outputs/REL-2026-07-21-checklist-v1.0.0.md"
write_artifact "$P6/stage6-deploy/outputs/REL-2026-07-21-release-notes-v1.0.0.md"
printf '%s\n' 'status: PASS' 'Rollback: tested' > "$P6/stage6-deploy/outputs/DEVOPS-2026-07-21-runbook.md"
printf '%s\n' '# Changelog' '## 1.0.0' > "$P6/CHANGELOG.md"
bash "$DOR" "$P6" 6 > "$TMP_DIR/gate6-pass.out" || fail 'complete Gate 6 fixture was rejected'

P6_DOCS_ONLY="$TMP_DIR/gate6-docs-only"
make_project "$P6_DOCS_ONLY"
printf '%s\n' 'status: PASS' > "$P6_DOCS_ONLY/stage6-deploy/outputs/DEPLOY-TDD-status.md"
write_artifact "$P6_DOCS_ONLY/stage6-deploy/outputs/REL-2026-07-21-checklist-v1.0.0.md"
write_artifact "$P6_DOCS_ONLY/stage6-deploy/outputs/REL-2026-07-21-release-notes-v1.0.0.md"
printf '%s\n' 'status: PASS' 'Rollback: tested' > "$P6_DOCS_ONLY/stage6-deploy/outputs/DEVOPS-2026-07-21-runbook.md"
mkdir -p "$P6_DOCS_ONLY/docs"
printf '%s\n' '# Changelog' '## 1.0.0' > "$P6_DOCS_ONLY/docs/CHANGELOG.md"
if bash "$DOR" "$P6_DOCS_ONLY" 6 > "$TMP_DIR/gate6-docs-only.out" 2>&1; then
  fail 'Gate 6 accepted docs/CHANGELOG.md instead of the canonical root CHANGELOG.md'
fi

P6_IMAGES="$TMP_DIR/gate6-images-only"
make_project "$P6_IMAGES"
printf '%s\n' 'cycle2_deliverables: images' > "$P6_IMAGES/tracking/SDLC-goals.md"
printf '%s\n' 'status: PASS' > "$P6_IMAGES/stage6-deploy/outputs/DEPLOY-TDD-status.md"
write_artifact "$P6_IMAGES/stage6-deploy/outputs/REL-2026-07-21-checklist-v1.0.0.md"
write_artifact "$P6_IMAGES/stage6-deploy/outputs/REL-2026-07-21-release-notes-v1.0.0.md"
printf '%s\n' '# Changelog' '## 1.0.0' > "$P6_IMAGES/CHANGELOG.md"
bash "$DOR" "$P6_IMAGES" 6 > "$TMP_DIR/gate6-images-only.out" ||
  fail 'Gate 6 rejected images-only delivery without an inapplicable deploy runbook'

if bash "$DOR" "$P6" 7 > "$TMP_DIR/invalid-gate.out" 2>&1; then
  fail 'validator accepted undocumented Gate 7 input'
fi

PD="$TMP_DIR/document"
make_project "$PD"
write_artifact "$PD/stage1-planning/outputs/PM-2026-07-21-feasibility.md"
write_artifact "$PD/stage1-planning/outputs/PM-2026-07-21-review.md"
document_output="$(SDLC_RELEASE_PREPARATION=no bash "$DOD" "$PD" D 1)" ||
  fail 'valid document auto-check was rejected'
[[ "$document_output" == *'DoD auto-check PASSED'* ]] ||
  fail 'DoD validator did not distinguish its automatic verdict from full DoD sign-off'

PR="$TMP_DIR/release"
make_project "$PR"
write_artifact "$PR/stage6-deploy/outputs/REL-2026-07-21-review.md"
if SDLC_RELEASE_PREPARATION=yes bash "$DOD" "$PR" D 6 > "$TMP_DIR/release-missing.out" 2>&1; then
  fail 'release-preparation DoD accepted missing CHANGELOG/release notes'
fi
write_artifact "$PR/stage6-deploy/outputs/REL-2026-07-21-release-notes-v1.0.0.md"
printf '%s\n' '# Changelog' '## 1.0.0' > "$PR/CHANGELOG.md"
SDLC_RELEASE_PREPARATION=yes bash "$DOD" "$PR" D 6 > "$TMP_DIR/release-pass.out" ||
  fail 'release-preparation DoD rejected complete release docs'

PR_DOCS_ONLY="$TMP_DIR/release-docs-only"
make_project "$PR_DOCS_ONLY"
write_artifact "$PR_DOCS_ONLY/stage6-deploy/outputs/REL-2026-07-21-review.md"
write_artifact "$PR_DOCS_ONLY/stage6-deploy/outputs/REL-2026-07-21-release-notes-v1.0.0.md"
mkdir -p "$PR_DOCS_ONLY/docs"
printf '%s\n' '# Changelog' '## 1.0.0' > "$PR_DOCS_ONLY/docs/CHANGELOG.md"
if SDLC_RELEASE_PREPARATION=yes bash "$DOD" "$PR_DOCS_ONLY" D 6 > "$TMP_DIR/release-docs-only.out" 2>&1; then
  fail 'release DoD accepted docs/CHANGELOG.md instead of the canonical root CHANGELOG.md'
fi

PI="$TMP_DIR/delivery"
make_project "$PI"
write_artifact "$PI/stage6-deploy/outputs/DEVOPS-2026-07-21-review.md"
write_artifact "$PI/stage6-deploy/outputs/DEPLOY-2026-07-21-test-report.md"
printf '%s\n' 'status: PASS' > "$PI/stage6-deploy/outputs/DEPLOY-TDD-status.md"
SDLC_RELEASE_PREPARATION=no bash "$DOD" "$PI" I 6 > "$TMP_DIR/delivery-pass.out" ||
  fail 'delivery infrastructure incorrectly required a database migration test'

if bash "$DOD" "$PD" X 1 > "$TMP_DIR/invalid-type.out" 2>&1; then
  fail 'DoD validator accepted an unknown artifact type'
fi

echo 'PASS: gate validator behavior smoke'

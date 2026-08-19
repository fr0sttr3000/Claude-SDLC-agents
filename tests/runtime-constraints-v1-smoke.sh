#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-runtime-constraints.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECK="$ROOT/cycle1-dev/s0-validate/runtime-constraints-check.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_confirmed() {
  local project="$1"
  mkdir -p "$project/stage1-planning/inputs" "$project/tracking" \
    "$project/stage2-requirements/outputs" "$project/stage3-design/outputs"
  printf '%s\n' '# Idea' 'Runtime Constraints: CLI on Linux; each invocation finishes within 30 seconds' > \
    "$project/stage1-planning/inputs/idea.md"
  printf '%s\n' 'cycle1:' \
    '  runtime_constraints: "CLI on Linux; each invocation finishes within 30 seconds"' \
    '  runtime_constraints_source: "stage1-planning/inputs/idea.md#Runtime Constraints"' > \
    "$project/tracking/PMO-constraints.md"
  printf '%s\n' '# NFR' '## Runtime Constraints' \
    'Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints' \
    'Runtime Constraints scope: application-design-only' \
    'Runtime Constraints status: CONFIRMED' \
    'RC-001 | capability | CLI runs on Linux with exit within 30 seconds | tracking/PMO-constraints.md#cycle1.runtime_constraints' > \
    "$project/stage2-requirements/outputs/BA-2026-08-18-NFR.md"
  printf '%s\n' '# HLD' '## Runtime Constraints' \
    'Runtime Constraints source: stage2-requirements/outputs/BA-2026-08-18-NFR.md#Runtime Constraints' \
    'Runtime Constraints scope: application-design-only' \
    'Runtime Constraints status: CONFIRMED' \
    'Deployment/operations authorization: NOT_GRANTED' \
    'RC-001: bounded CLI command with deterministic exit/stdout/stderr contract.' > \
    "$project/stage3-design/outputs/ARCH-2026-08-18-HLD.md"
}

expect_blocked() {
  local label="$1" project="$2" mode="$3" pattern="$4"
  if bash "$CHECK" "$project" "$mode" >"$TMP_DIR/blocked.out" 2>&1; then
    fail "$label"
  fi
  grep -Fq 'RUNTIME CONSTRAINTS BLOCKED' "$TMP_DIR/blocked.out" ||
    fail "$label did not emit BLOCKED"
  grep -Fq "$pattern" "$TMP_DIR/blocked.out" ||
    fail "$label did not identify expected cause: $pattern"
}

P_VALID="$TMP_DIR/valid"
write_confirmed "$P_VALID"
bash "$CHECK" "$P_VALID" requirements >/dev/null || fail 'valid requirements trace rejected'
bash "$CHECK" "$P_VALID" architecture >/dev/null || fail 'valid architecture trace rejected'

P_LEGACY="$TMP_DIR/legacy-only"
write_confirmed "$P_LEGACY"
sed -i 's/^Runtime Constraints:/Deployment Constraint:/' \
  "$P_LEGACY/stage1-planning/inputs/idea.md"
expect_blocked 'legacy-only idea was accepted at Gate 2' "$P_LEGACY" requirements \
  'kickoff migration'

P_CONFLICT="$TMP_DIR/conflict"
write_confirmed "$P_CONFLICT"
printf '%s\n' 'Deployment Constraint: container-only' >> \
  "$P_CONFLICT/stage1-planning/inputs/idea.md"
expect_blocked 'canonical/legacy conflict was accepted' "$P_CONFLICT" requirements \
  'conflict'

P_DRIFT="$TMP_DIR/pmo-drift"
write_confirmed "$P_DRIFT"
sed -i 's/each invocation finishes within 30 seconds/each invocation finishes within 60 seconds/' \
  "$P_DRIFT/tracking/PMO-constraints.md"
expect_blocked 'lossy PMO handoff was accepted' "$P_DRIFT" requirements \
  'не совпадает с normalized idea value'

P_SOURCE="$TMP_DIR/missing-nfr-source"
write_confirmed "$P_SOURCE"
sed -i '/^Runtime Constraints source:/d' \
  "$P_SOURCE/stage2-requirements/outputs/BA-2026-08-18-NFR.md"
expect_blocked 'NFR without exact source was accepted' "$P_SOURCE" requirements \
  'NFR Runtime Constraints source invalid'

P_HLD="$TMP_DIR/missing-hld-id"
write_confirmed "$P_HLD"
sed -i '/^RC-001:/d' "$P_HLD/stage3-design/outputs/ARCH-2026-08-18-HLD.md"
expect_blocked 'HLD without NFR RC id was accepted' "$P_HLD" architecture \
  'разное число'

P_EXTRA="$TMP_DIR/extra-hld-id"
write_confirmed "$P_EXTRA"
printf '%s\n' 'RC-999: invented topology.' >> \
  "$P_EXTRA/stage3-design/outputs/ARCH-2026-08-18-HLD.md"
expect_blocked 'HLD invented an RC id' "$P_EXTRA" architecture 'разное число'

P_AUTH="$TMP_DIR/deploy-authorization"
write_confirmed "$P_AUTH"
sed -i 's|Deployment/operations authorization: NOT_GRANTED|Deployment/operations authorization: GRANTED|' \
  "$P_AUTH/stage3-design/outputs/ARCH-2026-08-18-HLD.md"
expect_blocked 'Runtime Constraint granted deployment authorization' "$P_AUTH" architecture \
  'deployment/operations authorization'

P_UNKNOWN="$TMP_DIR/unknown"
write_confirmed "$P_UNKNOWN"
printf '%s\n' '# Idea' 'Runtime Constraints: unknown' > \
  "$P_UNKNOWN/stage1-planning/inputs/idea.md"
sed -i 's/CLI on Linux; each invocation finishes within 30 seconds/unknown/' \
  "$P_UNKNOWN/tracking/PMO-constraints.md"
printf '%s\n' '# NFR' '## Runtime Constraints' \
  'Runtime Constraints source: tracking/PMO-constraints.md#cycle1.runtime_constraints' \
  'Runtime Constraints scope: application-design-only' \
  'Runtime Constraints status: OPEN ISSUE' 'Runtime Constraints owner: product-owner' > \
  "$P_UNKNOWN/stage2-requirements/outputs/BA-2026-08-18-NFR.md"
printf '%s\n' '# HLD' '## Runtime Constraints' \
  'Runtime Constraints source: stage2-requirements/outputs/BA-2026-08-18-NFR.md#Runtime Constraints' \
  'Runtime Constraints scope: application-design-only' \
  'Runtime Constraints status: OPEN ISSUE' \
  'Deployment/operations authorization: NOT_GRANTED' > \
  "$P_UNKNOWN/stage3-design/outputs/ARCH-2026-08-18-HLD.md"
bash "$CHECK" "$P_UNKNOWN" requirements >/dev/null || fail 'valid unknown requirements trace rejected'
bash "$CHECK" "$P_UNKNOWN" architecture >/dev/null || fail 'valid unknown architecture trace rejected'
printf '%s\n' 'RC-777: guessed container topology.' >> \
  "$P_UNKNOWN/stage3-design/outputs/ARCH-2026-08-18-HLD.md"
expect_blocked 'unknown constraint allowed invented HLD RC' "$P_UNKNOWN" architecture \
  'изобретать RC ids'

grep -Fq 'runtime-constraints-check.sh' "$ROOT/cycle1-dev/s0-validate/dor-check.sh" ||
  fail 'Gate 2 does not invoke Runtime Constraints validator'
grep -Fq 'runtime-constraints-check.sh' \
  "$ROOT/cycle1-dev/s0-validate/architecture-decision-trace-check.sh" ||
  fail 'Gate 3 architecture validator does not invoke Runtime Constraints validator'

echo 'PASS: Runtime Constraints v1 smoke'

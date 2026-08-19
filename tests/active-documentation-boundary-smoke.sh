#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-active-doc-boundary.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mapfile -t active_docs < <(
  cd "$ROOT"
  {
    printf '%s\n' CLAUDE.md README.md OVERVIEW.md
    rg --files _standards _contract cycle1-dev _runtimes -g '*.md'
  } | sort -u
)

search_active() {
  local pattern="$1"
  (cd "$ROOT" && rg -n -F -- "$pattern" "${active_docs[@]}") >"$TMP_DIR/matches" 2>/dev/null
}

if search_active 'stages 1→7'; then
  cat "$TMP_DIR/matches" >&2
  fail 'active documentation still claims Stage 1-7 execution'
fi
if search_active 'DEVOPS-cicd.yaml'; then
  cat "$TMP_DIR/matches" >&2
  fail 'active Cycle 1 instructions reference frozen DEVOPS-cicd.yaml'
fi
if search_active 'SEC-*-build-scan-PR*.md'; then
  cat "$TMP_DIR/matches" >&2
  fail 'current consumer instruction uses a frozen S5 build-scan filename'
fi
if search_active 'future complete approval'; then
  cat "$TMP_DIR/matches" >&2
  fail 'Execution Journal still describes full DoD approval as future'
fi
if search_active 'Метрики DORA (5 шт., вкл. Reliability)'; then
  cat "$TMP_DIR/matches" >&2
  fail 'Tracker still requires unavailable production DORA metrics'
fi

grep -Fq '_contract/cycle1-steps-v1.tsv' "$ROOT/cycle1-dev/s0-tracker/CLAUDE.md" ||
  fail 'Tracker does not use the canonical active Cycle 1 step registry'
grep -Fq 'current-artifact.sh resolve-compatible-one' "$ROOT/cycle1-dev/s5-security/CLAUDE.md" ||
  fail 'S5 Security does not use logical current artifact resolution'
grep -Fq 'dod-approval-check.sh' "$ROOT/_contract/EXECUTION_JOURNAL.md" ||
  fail 'Execution Journal does not name the implemented full DoD validator'
grep -Fq 'NOT_OBSERVED / deferred' "$ROOT/cycle1-dev/s0-tracker/CLAUDE.md" ||
  fail 'Tracker does not preserve the production-observation boundary'
grep -Fq 'cycle1-completion-proof-v2.yaml' "$ROOT/_contract/CYCLE1_COMPLETION_V2.md" ||
  fail 'Completion contract does not name the current root/Retry proof'
grep -Fq 'cycle1-execution-chain-v1.tsv' "$ROOT/_contract/EXECUTION_JOURNAL.md" ||
  fail 'Execution Journal does not document the launcher-owned Retry chain index'
if grep -Fq 'same full-cycle run' "$ROOT/_contract/CYCLE1_COMPLETION_V2.md"; then
  fail 'Completion contract still requires an impossible single run after Retry'
fi

echo 'PASS: active documentation boundary smoke'

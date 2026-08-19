#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

export XDG_CONFIG_HOME="$TMP_DIR/config"
source "$ROOT/sdlc.sh"
PROJECTS="$TMP_DIR/projects"
mkdir -p \
  "$PROJECTS/Alpha/stage1-planning/inputs" \
  "$PROJECTS/Alpha/stage1-planning/outputs" \
  "$PROJECTS/Beta" \
  "$PROJECTS/_ignored"
printf '%s\n' '# Dashboard' > "$PROJECTS/Alpha/Dashboard.md"

before="$(find "$PROJECTS/Alpha" -mindepth 1 -printf '%P\n' | sort)"
if execute_structure_dispatch validate Alpha >/dev/null 2>&1; then
  fail 'read-only validation accepted an incomplete Project'
fi
after="$(find "$PROJECTS/Alpha" -mindepth 1 -printf '%P\n' | sort)"
[[ "$after" == "$before" ]] || fail 'read-only validation changed Project files'

execute_structure_dispatch fix Alpha Beta >/dev/null ||
  fail 'collection fix failed for exact Project targets'
for project in Alpha Beta; do
  bash "$ROOT/cycle1-dev/s0-validate/structure-check.sh" \
    "$PROJECTS/$project" check >/dev/null ||
    fail "post-fix structure is invalid: $project"
done
[[ ! -e "$PROJECTS/all" ]] || fail 'dispatcher created or addressed fake Project all'
[[ -z "$(find "$PROJECTS/_ignored" -mindepth 1 -print -quit)" ]] ||
  fail 'dispatcher modified a directory outside exact targets'

ln -s "$PROJECTS/Alpha" "$PROJECTS/Linked"
if execute_structure_dispatch validate Linked >/dev/null 2>&1; then
  fail 'dispatcher accepted a symlink Project target'
fi

echo 'PASS: Collection structure dispatch smoke'

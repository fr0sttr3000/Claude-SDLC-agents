#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

resolve_target() {
  local source="$1" target="$2" candidate name
  [[ "$target" == *.md ]] || target="$target.md"
  for candidate in "$ROOT/$target" "$(dirname "$source")/$target"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  name="$(basename "$target")"
  mapfile -t matches < <(find "$ROOT" -type f -name "$name" \
    -not -path "$ROOT/cycle2-deploy/*" -not -path "$ROOT/cycle3-ops/*" | sort)
  [[ ${#matches[@]} -eq 1 ]] || return 1
  printf '%s\n' "${matches[0]}"
}

sources=(
  "$ROOT/plans/principles.md"
  "$ROOT/plans/roadmap.md"
  "$ROOT/_standards/company.md"
  "$ROOT/_standards/quality.md"
)

for source in "${sources[@]}"; do
  mapfile -t links < <(rg -o '\[\[[^]]+\]\]' "$source" || true)
  for raw in "${links[@]}"; do
    link="${raw#\[\[}"
    link="${link%\]\]}"
    link="${link%%|*}"
    target="${link%%#*}"
    [[ "$link" == *'#'* ]] && anchor="${link#*#}" || anchor=''
    resolved="$(resolve_target "$source" "$target")" ||
      fail "$(basename "$source"): unresolved target $target"
    if [[ -n "$anchor" ]] && ! awk -v wanted="$anchor" '
      /^#{1,6}[[:space:]]/ {
        heading=$0
        sub(/^#{1,6}[[:space:]]+/, "", heading)
        if (heading == wanted) found=1
      }
      END { exit(found ? 0 : 1) }
    ' "$resolved"; then
      fail "$(basename "$source"): broken anchor $target#$anchor"
    fi
  done
done

echo 'PASS: active Obsidian links smoke'

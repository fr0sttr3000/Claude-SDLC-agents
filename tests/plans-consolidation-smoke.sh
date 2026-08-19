#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { echo "FAIL: $*" >&2; exit 1; }

mapfile -t plan_files < <(find "$ROOT/plans" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort)
expected=(principles.md roadmap.md)
[[ "${plan_files[*]}" == "${expected[*]}" ]] ||
  fail "plans must contain exactly: ${expected[*]}; actual: ${plan_files[*]:-none}"

for heading in \
  '## Delivered baseline' \
  '## Now' \
  '## Next' \
  '## Later / Decision gates' \
  '## Правила ведения'; do
  grep -Fq "$heading" "$ROOT/plans/roadmap.md" ||
    fail "roadmap has no required outcome-based section: $heading"
done

grep -Fq '| Инициатива | Ожидаемый результат | Зависимости | Критерий выхода |' \
  "$ROOT/plans/roadmap.md" || fail 'roadmap initiatives have no outcome/dependency/exit schema'
grep -Fq '[[README#Product status]]' "$ROOT/plans/roadmap.md" ||
  fail 'roadmap does not reference the delivered product status'
grep -Fq '[[CHANGELOG]]' "$ROOT/plans/roadmap.md" ||
  fail 'roadmap does not reference delivered history'

for stale_heading in \
  '## 2. Поддерживаемый scope' \
  '## 3. Доступные возможности' \
  '## 4. Текущие ограничения' \
  '## 5. Следующая работа'; do
  if grep -Fq "$stale_heading" "$ROOT/plans/roadmap.md"; then
    fail "roadmap still contains status-inventory section: $stale_heading"
  fi
done
if grep -Fq '| DONE |' "$ROOT/plans/roadmap.md"; then
  fail 'roadmap still contains a delivered capability dump'
fi
if rg -n 'AUD-[0-9]{3}|DOC-[0-9]{3}' "$ROOT/plans/roadmap.md" >/dev/null; then
  fail 'roadmap exposes internal remediation identifiers'
fi

echo 'PASS: plans consolidation smoke'

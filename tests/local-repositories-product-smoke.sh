#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }
contains() {
  grep -Fq -- "$2" "$ROOT/$1" || fail "$1 does not contain: $2"
}
not_contains() {
  if grep -Fq -- "$2" "$ROOT/$1"; then
    fail "$1 contains forbidden text: $2"
  fi
}

for role in l1-analyze l2-setup l3-build l4-run; do
  contains "cycle1-dev/$role/CLAUDE.md" 'exact quoted repository cwd'
  contains "cycle1-dev/$role/CLAUDE.md" 'pwd -P'
  contains "cycle1-dev/$role/CLAUDE.md" 'BLOCKED'
done

contains cycle1-dev/l1-analyze/CLAUDE.md 'web/service'
contains cycle1-dev/l1-analyze/CLAUDE.md 'library/package'
contains cycle1-dev/l1-analyze/CLAUDE.md 'CLI'
contains cycle1-dev/l1-analyze/CLAUDE.md 'worker/job'
contains cycle1-dev/l1-analyze/CLAUDE.md 'HTTPS, SSH, SCP-style'

for requirement in \
  'web/service' 'library/package' 'CLI' 'worker/job' \
  'exact PID' 'exit code, stdout и stderr' 'bounded локальный job/message' \
  'exit 0 без применимого oracle не является success'; do
  contains cycle1-dev/l4-run/CLAUDE.md "$requirement"
done
not_contains cycle1-dev/l4-run/CLAUDE.md 'После старта всегда проверяй'
not_contains cycle1-dev/l4-run/CLAUDE.md 'ps aux | grep'

contains localrun.sh 'git clone -- "$url" "$target"'
contains localrun.sh 'local_repository_root_is_exact'
contains localrun.sh 'origin отсутствует или не совпадает'
contains localrun.sh 'source отсутствует или неоднозначен'
contains README.md 'Exact repository root и origin проверяются fail-closed'
contains README.md 'worker/job'

echo 'PASS: Local Repositories product-specific smoke'

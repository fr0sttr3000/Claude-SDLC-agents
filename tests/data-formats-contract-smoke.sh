#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMATS="$ROOT/_standards/data-formats.md"
fail() { echo "FAIL: $*" >&2; exit 1; }
require_text() { grep -Fq -- "$1" "$FORMATS" || fail "data formats missing: $1"; }
forbid_text() { ! grep -Fq -- "$1" "$FORMATS" || fail "weak data-format pattern remains: $1"; }

require_text 'Формат ошибки API — только по project contract'
require_text 'assert set(body) == set(expected.required_keys)'
require_text 'assert response.status_code == expected.status_code'
require_text 'assert 200 <= response.status_code < 300'
forbid_text 'assert response.status_code == 422'
require_text 'никогда не считается допустимым результатом format-test'
require_text 'normalize-utc-with-audit'
require_text 'audit_event.action == "timezone-naive-normalized-to-utc"'
forbid_text 'assert "error" in body or "detail" in body'
forbid_text 'assert response.status_code != 400'

echo 'PASS: data formats contract smoke'

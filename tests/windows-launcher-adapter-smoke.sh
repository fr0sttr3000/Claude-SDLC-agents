#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-windows-parser.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for file in sdlc.ps1 localrun.ps1 _runtimes/windows-launcher.ps1 tests/windows-launcher-ci.ps1; do
  [[ -f "$ROOT/$file" ]] || fail "missing Windows launcher adapter: $file"
done
grep -Fq "_runtimes\\windows-launcher.ps1" "$ROOT/sdlc.ps1" ||
  fail "sdlc.ps1 does not use the shared Windows adapter"
grep -Fq "sdlc.sh" "$ROOT/sdlc.ps1" ||
  fail "sdlc.ps1 does not target the canonical sdlc.sh"
grep -Fq "_runtimes\\windows-launcher.ps1" "$ROOT/localrun.ps1" ||
  fail "localrun.ps1 does not use the shared Windows adapter"
grep -Fq "localrun.sh" "$ROOT/localrun.ps1" ||
  fail "localrun.ps1 does not target the canonical localrun.sh"

grep -Fq "ValidateSet('sdlc.sh', 'localrun.sh')" "$ROOT/_runtimes/windows-launcher.ps1" ||
  fail "Windows adapter does not restrict canonical launcher targets"
grep -Fq 'SDLC_BASH' "$ROOT/_runtimes/windows-launcher.ps1" ||
  fail "Windows adapter has no explicit Bash override"
grep -Fq 'Git for Windows' "$ROOT/_runtimes/windows-launcher.ps1" ||
  fail "Windows adapter does not state its supported execution environment"
grep -Fq 'FROZEN / NOT READY' "$ROOT/_runtimes/windows-launcher.ps1" ||
  fail "Windows adapter does not preserve the supported Cycle 1 scope"
grep -Fq "StartsWith('\\\\')" "$ROOT/_runtimes/windows-launcher.ps1" ||
  fail "Windows adapter does not reject UNC paths"

grep -Fq 'runs-on: windows-latest' "$ROOT/.github/workflows/windows-launcher-static.yml" ||
  fail 'Windows workflow does not use a real Windows runner'
grep -Fq 'shell: pwsh' "$ROOT/.github/workflows/windows-launcher-static.yml" ||
  fail 'Windows workflow does not execute the PowerShell matrix'
grep -Fq 'tests\windows-launcher-ci.ps1' "$ROOT/.github/workflows/windows-launcher-static.yml" ||
  fail 'Windows workflow does not invoke the real adapter matrix'
for expected in \
  '$tokens' '$parseErrors' '[ref] $tokens' '[ref] $parseErrors' \
  'SDLC_BASH' 'аргумент-не-ASCII' 'UNC canonical launcher path was not rejected' \
  'ExitCode -eq 37'; do
  grep -Fq "$expected" "$ROOT/tests/windows-launcher-ci.ps1" ||
    fail "Windows CI matrix is missing: $expected"
done

if grep -En 'Invoke-Expression|iex[[:space:]]|Start-Process.*-Verb[[:space:]]+RunAs' -- \
  "$ROOT/sdlc.ps1" "$ROOT/localrun.ps1" "$ROOT/_runtimes/windows-launcher.ps1"; then
  fail "Windows adapter contains dynamic evaluation or privilege escalation"
fi

for file in README.md CLAUDE.md; do
  grep -Fq 'sdlc.ps1' "$ROOT/$file" ||
    fail "$file does not document the Windows launcher"
done
grep -Fq 'EXPERIMENTAL / NOT TESTED ON WINDOWS' "$ROOT/README.md" ||
  fail 'README overstates Windows support'
grep -Fq 'используйте на свой страх и риск' "$ROOT/README.md" ||
  fail 'README lacks Windows risk disclosure'

if command -v pwsh >/dev/null 2>&1; then
  parse_file() {
    local file="$1" parser_file="$1"
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*) parser_file="$(cygpath -w "$file")" ;;
    esac
    SDLC_PARSER_FILE="$parser_file" pwsh -NoLogo -NoProfile -Command \
      '& { $tokens = $null; $parseErrors = $null; [System.Management.Automation.Language.Parser]::ParseFile($env:SDLC_PARSER_FILE,[ref] $tokens,[ref] $parseErrors) | Out-Null; if ($parseErrors.Count -gt 0) { $parseErrors | ForEach-Object { [Console]::Error.WriteLine("{0}: {1}" -f $env:SDLC_PARSER_FILE, $_.Message) }; exit 1 } }'
  }
  for file in sdlc.ps1 localrun.ps1 _runtimes/windows-launcher.ps1; do
    parse_file "$ROOT/$file" || fail "$file has PowerShell syntax errors"
  done
  cp "$ROOT/sdlc.ps1" "$TMP_DIR/invalid.ps1"
  printf '%s\n' 'function Broken-Syntax {' >> "$TMP_DIR/invalid.ps1"
  if parse_file "$TMP_DIR/invalid.ps1" 2>/dev/null; then
    fail 'PowerShell parser accepted an invalid mutation fixture'
  fi
fi

echo "PASS: experimental Windows launcher static contract (real Windows evidence still required)"

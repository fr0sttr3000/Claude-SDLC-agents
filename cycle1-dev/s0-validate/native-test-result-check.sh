#!/usr/bin/env bash

set -euo pipefail

FORMAT="${1:?Укажи junit|tap}"
RAW_PATH="${2:?Укажи native result path}"
VERDICT="${3:?Укажи Evidence verdict}"
blocked() { echo "NATIVE TEST RESULT BLOCKED: $*" >&2; exit 1; }
[[ -f "$RAW_PATH" && ! -L "$RAW_PATH" ]] || blocked 'raw result absent or symlink'
case "$VERDICT" in PASS|FAIL|BLOCKED|NOT_APPLICABLE) ;; *) blocked 'invalid Evidence verdict' ;; esac

case "$FORMAT" in
  junit)
    grep -Eqi '<testsuites?([[:space:]>])' "$RAW_PATH" || blocked 'JUnit testsuite root not found'
    if grep -Eqi '<!DOCTYPE|<!ENTITY' "$RAW_PATH"; then blocked 'DTD/entity declarations are forbidden'; fi
    mapfile -t tests_values < <(grep -Eo 'tests="[0-9]+"' "$RAW_PATH" | sed -E 's/[^0-9]//g')
    mapfile -t failure_values < <(grep -Eo 'failures="[0-9]+"' "$RAW_PATH" | sed -E 's/[^0-9]//g')
    mapfile -t error_values < <(grep -Eo 'errors="[0-9]+"' "$RAW_PATH" | sed -E 's/[^0-9]//g')
    (( ${#tests_values[@]} > 0 && ${#failure_values[@]} > 0 && ${#error_values[@]} > 0 )) ||
      blocked 'JUnit tests/failures/errors counters are required'
    tests=0; failures=0; errors=0
    for value in "${tests_values[@]}"; do tests=$((tests + value)); done
    for value in "${failure_values[@]}"; do failures=$((failures + value)); done
    for value in "${error_values[@]}"; do errors=$((errors + value)); done
    (( tests > 0 )) || blocked 'JUnit contains no tests'
    failed=$((failures + errors))
    ;;
  tap)
    plan_count="$(grep -Ec '^[[:space:]]*1\.\.[0-9]+([[:space:]]|$)' "$RAW_PATH" || true)"
    (( plan_count == 1 )) || blocked 'TAP requires exactly one 1..N plan'
    planned="$(sed -nE 's/^[[:space:]]*1\.\.([0-9]+).*/\1/p' "$RAW_PATH" | head -1)"
    tests="$(grep -Ec '^[[:space:]]*(ok|not ok)[[:space:]]+[0-9]+' "$RAW_PATH" || true)"
    failures="$(grep -Ec '^[[:space:]]*not ok[[:space:]]+[0-9]+' "$RAW_PATH" || true)"
    errors=0
    [[ "$planned" =~ ^[1-9][0-9]*$ && "$tests" -eq "$planned" ]] ||
      blocked "TAP plan/result count mismatch: planned=${planned:-missing} results=$tests"
    failed="$failures"
    ;;
  *) blocked 'format must be junit|tap' ;;
esac

case "$VERDICT" in
  PASS) (( failed == 0 )) || blocked "$FORMAT contains $failed failed/error results but record says PASS" ;;
  FAIL) (( failed > 0 )) || blocked "$FORMAT contains no failed/error results but record says FAIL" ;;
esac
echo "NATIVE TEST RESULT VERIFIED: format=$FORMAT tests=$tests failed=$failed verdict=$VERDICT"

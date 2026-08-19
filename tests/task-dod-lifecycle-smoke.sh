#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-task-dod.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/receipts"
PROJECT="$TMP_DIR/TaskProject"
SOURCE=2222222222222222222222222222222222222222
mkdir -p "$PROJECT/tracking/approvals" "$PROJECT/stage4-dev/outputs"
printf '%s\n' 'verified exact-source evidence' > "$PROJECT/stage4-dev/outputs/QA-task-evidence.md"
header=$'task_id\ttask_type\tstage\tpr_number\tsource_revision\tauto_check_status\tevidence_refs\tproducer\tmanual_approval_ref\tverdict'
row="T-001"$'\tK\t4\t7\t'"$SOURCE"$'\tPASS\tstage4-dev/outputs/QA-task-evidence.md\ts4-dev\ttracking/approvals/APPROVAL-TASK-DOD-001.yaml\tPASS'
printf '%s\n%s\n' "$header" "$row" > "$PROJECT/tracking/task-dod-v1.tsv"
canonical="$(printf '%s' "$row" | awk -F '\t' 'BEGIN {OFS="\t"} {print $1,$2,$3,$4,$5,$6,$7,$8,$10}')"
subject="$(printf '%s' "$canonical" | sha256sum | awk '{print $1}')"
approval="$PROJECT/tracking/approvals/APPROVAL-TASK-DOD-001.yaml"
printf '%s\n' 'schema_version: 1' 'approval_id: APPROVAL-TASK-DOD-001' \
  'approval_origin: launcher-human-v1' 'approver_identity: qa-owner' 'decision: APPROVE' \
  'scope: task-dod:T-001' 'rationale: manual DoD items and exact evidence reviewed' \
  "source_revision: $SOURCE" "subject_digest: $subject" \
  'observed_at: 2026-08-17T12:00:00Z' > "$approval"
record_human_approval_receipt "$PROJECT" "$approval"
CHECK="$ROOT/cycle1-dev/s0-validate/task-dod-check.sh"
bash "$CHECK" "$PROJECT" T-001 >/dev/null || { echo 'FAIL: valid task DoD rejected' >&2; exit 1; }

LEDGER_INIT="$ROOT/cycle1-dev/s0-validate/tracker-ledger-init.sh"
TASK_DONE="$ROOT/cycle1-dev/s0-validate/tracker-task-done.sh"
SPRINT_CLOSE="$ROOT/cycle1-dev/s0-validate/tracker-sprint-close-check.sh"
TD_MATERIALIZE="$ROOT/cycle1-dev/s0-validate/tracker-tech-debt-materialize.sh"
TD_CHECK="$ROOT/cycle1-dev/s0-validate/tech-debt-check.sh"
bash "$LEDGER_INIT" "$PROJECT" >/dev/null || { echo 'FAIL: ledger init failed' >&2; exit 1; }
before_ledgers="$(sha256sum "$PROJECT/tracking/dor-violations.md" "$PROJECT/tracking/tech-debt.md" \
  "$PROJECT/tracking/known-issues.md" "$PROJECT/tracking/task-dod-v1.tsv")"
bash "$LEDGER_INIT" "$PROJECT" >/dev/null || { echo 'FAIL: repeated ledger init failed' >&2; exit 1; }
after_ledgers="$(sha256sum "$PROJECT/tracking/dor-violations.md" "$PROJECT/tracking/tech-debt.md" \
  "$PROJECT/tracking/known-issues.md" "$PROJECT/tracking/task-dod-v1.tsv")"
[[ "$before_ledgers" == "$after_ledgers" ]] || {
  echo 'FAIL: repeated ledger init overwrote existing content' >&2
  exit 1
}

cat >> "$PROJECT/tracking/tech-debt.md" <<'TD'

### TD-NEXT — Sprint materialization fixture
- Owner: delivery-owner
- План устранения: resolve the bounded fixture during the next sprint
- Source sprint: 1
- Target sprint: NEXT
- Дедлайн устранения: PENDING
- Exception type: none
- Finding severity: S3
- Finding IDs: FINDING-NEXT
- CVSS: N/A
- Risk exception: none
- Статус: OPEN
TD
mkdir -p "$PROJECT/tracking/sprints"
printf '%s\n' '---' 'sprint: 2' 'start: 2026-08-18' 'end: 2026-08-31' \
  'status: PLANNED' '---' > "$PROJECT/tracking/sprints/sprint-02.md"
if bash "$TD_CHECK" "$PROJECT" sprint-init 2 >/dev/null 2>&1; then
  echo 'FAIL: sprint init accepted unresolved Target sprint NEXT' >&2
  exit 1
fi
bash "$TD_MATERIALIZE" "$PROJECT" 2 2026-08-31 >/dev/null || {
  echo 'FAIL: deterministic Tech Debt materialization failed' >&2
  exit 1
}
grep -Fqx -- '- Target sprint: 2' "$PROJECT/tracking/tech-debt.md" || {
  echo 'FAIL: Target sprint NEXT was not materialized' >&2
  exit 1
}
grep -Fqx -- '- Дедлайн устранения: 2026-08-31' "$PROJECT/tracking/tech-debt.md" || {
  echo 'FAIL: pending remediation deadline was not materialized' >&2
  exit 1
}
bash "$TD_CHECK" "$PROJECT" sprint-init 2 >/dev/null || {
  echo 'FAIL: materialized Tech Debt did not pass sprint-init validation' >&2
  exit 1
}
materialized_sha="$(sha256sum "$PROJECT/tracking/tech-debt.md" | awk '{print $1}')"
bash "$TD_MATERIALIZE" "$PROJECT" 2 2026-08-31 >/dev/null || {
  echo 'FAIL: repeated Tech Debt materialization was rejected' >&2
  exit 1
}
[[ "$materialized_sha" == "$(sha256sum "$PROJECT/tracking/tech-debt.md" | awk '{print $1}')" ]] || {
  echo 'FAIL: repeated Tech Debt materialization changed the ledger' >&2
  exit 1
}
if bash "$TD_CHECK" "$PROJECT" sprint-close 2 >/dev/null 2>&1; then
  echo 'FAIL: sprint close accepted unresolved Tech Debt at its target sprint' >&2
  exit 1
fi
sed -i '/^### TD-NEXT /,/^- Статус: OPEN$/d' "$PROJECT/tracking/tech-debt.md"

mkdir -p "$PROJECT/tracking/sprints"
for file in "$PROJECT/tracking/backlog.md" "$PROJECT/tracking/current-sprint.md" \
  "$PROJECT/tracking/sprints/sprint-01.md"; do
  {
    [[ "$file" != *current-sprint.md && "$file" != *sprint-01.md ]] ||
      printf '%s\n' '---' 'sprint: 1' 'status: ACTIVE' '---'
    printf '%s\n' '| ID | Название | Агент | SP | Статус |' \
      '|---|---|---|---:|---|' '| T-001 | task | s4-dev | 3 | IN_PROGRESS |'
  } > "$file"
done

before_tasks="$(sha256sum "$PROJECT/tracking/backlog.md" "$PROJECT/tracking/current-sprint.md" \
  "$PROJECT/tracking/sprints/sprint-01.md")"
if TRACKER_FAULT_AFTER_PUBLISH=1 bash "$TASK_DONE" "$PROJECT" T-001 >/dev/null 2>&1; then
  echo 'FAIL: fault-injected task transaction passed' >&2
  exit 1
fi
after_fault="$(sha256sum "$PROJECT/tracking/backlog.md" "$PROJECT/tracking/current-sprint.md" \
  "$PROJECT/tracking/sprints/sprint-01.md")"
[[ "$before_tasks" == "$after_fault" ]] || {
  echo 'FAIL: fault-injected task transaction was not rolled back' >&2
  exit 1
}
bash "$TASK_DONE" "$PROJECT" T-001 >/dev/null || {
  echo 'FAIL: valid task transaction was rejected' >&2
  exit 1
}
for file in "$PROJECT/tracking/backlog.md" "$PROJECT/tracking/current-sprint.md" \
  "$PROJECT/tracking/sprints/sprint-01.md"; do
  grep -Eq '^\| T-001 \|.*\| DONE \|$' "$file" || {
    echo "FAIL: DONE not synchronized in $file" >&2
    exit 1
  }
done
bash "$SPRINT_CLOSE" "$PROJECT" 1 >/dev/null || {
  echo 'FAIL: verified DONE task did not satisfy sprint close' >&2
  exit 1
}

cp "$PROJECT/tracking/task-dod-v1.tsv" "$TMP_DIR/task-ledger.valid"
sed -i "s/$SOURCE/3333333333333333333333333333333333333333/" "$PROJECT/tracking/task-dod-v1.tsv"
if bash "$CHECK" "$PROJECT" T-001 >/dev/null 2>&1; then
  echo 'FAIL: stale/wrong-source task DoD was accepted' >&2
  exit 1
fi
cp "$TMP_DIR/task-ledger.valid" "$PROJECT/tracking/task-dod-v1.tsv"
if bash "$CHECK" "$PROJECT" T-002 >/dev/null 2>&1; then
  echo 'FAIL: DoD row for another task was accepted' >&2
  exit 1
fi

mv "$PROJECT/tracking/known-issues.md" "$TMP_DIR/known-issues.md"
if bash "$SPRINT_CLOSE" "$PROJECT" 1 >/dev/null 2>&1; then
  echo 'FAIL: sprint close accepted a missing governance ledger' >&2
  exit 1
fi
mv "$TMP_DIR/known-issues.md" "$PROJECT/tracking/known-issues.md"

sed -i 's/\tPASS$/\tFAIL/' "$PROJECT/tracking/task-dod-v1.tsv"
if bash "$CHECK" "$PROJECT" T-001 >/dev/null 2>&1; then
  echo 'FAIL: failed task DoD was accepted' >&2
  exit 1
fi
if bash "$SPRINT_CLOSE" "$PROJECT" 1 >/dev/null 2>&1; then
  echo 'FAIL: sprint close counted DONE with invalid DoD' >&2
  exit 1
fi
echo 'PASS: task DoD lifecycle smoke'

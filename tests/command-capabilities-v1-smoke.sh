#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/_contract/command-capabilities-v1.tsv"
GROUP_REGISTRY="$ROOT/_contract/current-artifact-groups-v1.tsv"
LIFECYCLES="$ROOT/_contract/shared-artifact-lifecycles-v1.tsv"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expected_header=$'schema_version\tagent\tcommand\tcapability\taccess\tresult_verifier\tmetadata_stages\tmetadata_types'
[[ "$(sed -n '1p' "$REGISTRY")" == "$expected_header" ]] ||
  fail 'command capability header mismatch'

mapfile -t command_files < <(
  find "$ROOT/cycle1-dev" "$ROOT/_tools" -path '*/.claude/commands/*.md' -type f | sort
)
command_count="${#command_files[@]}"
[[ "$(awk 'NR > 1 { count++ } END { print count + 0 }' "$REGISTRY")" -eq "$command_count" ]] ||
  fail 'registry must have exactly one row for every active command'
[[ "$(awk -F '\t' 'NR > 1 { print $2 FS $3 }' "$REGISTRY" | sort -u | wc -l)" -eq "$command_count" ]] ||
  fail 'registry contains duplicate agent+command keys'

export XDG_CONFIG_HOME="$TMP_DIR/config"
source "$ROOT/sdlc.sh"

for file in "${command_files[@]}"; do
  agent="${file%/.claude/commands/*}"
  agent="${agent##*/}"
  command="/${file##*/}"
  command="${command%.md}"
  record="$(command_capability_record "$agent" "$command")" ||
    fail "missing registry row: $agent $command"
  capability="$(command_capability_field "$record" 4)"
  access="$(command_capability_field "$record" 5)"
  verifier="$(command_capability_field "$record" 6)"
  metadata_stages="$(command_capability_field "$record" 7)"
  metadata_types="$(command_capability_field "$record" 8)"
  case "$capability:$access" in
    read-only-no-output:read-only|mutating-declared-output:write|mutating-declared-output:scoped-write|orchestrated-special:read-only|orchestrated-special:write|orchestrated-special:scoped-write) ;;
    *) fail "invalid capability/access: $agent $command $capability/$access" ;;
  esac
  [[ -n "$verifier" ]] || fail "empty result verifier: $agent $command"
  if [[ "$capability" == mutating-declared-output ]]; then
    cycle1_declared_output_groups "$agent" "$command" >/dev/null ||
      fail "mutating command has no declared outputs: $agent $command"
  fi
  mapped_task="$command"
  [[ "$agent:$command" != s0-tracker:/release-notes ]] || mapped_task='/release-notes v0.0.0'
  groups="$(cycle1_declared_output_groups "$agent" "$mapped_task" 2>/dev/null || true)"
  if [[ "$groups" == *'.md'* ]]; then
    [[ "$metadata_stages" != - && "$metadata_types" != - ]] ||
      fail "Markdown producer has no metadata binding: $agent $command"
  fi
  if [[ "$metadata_stages" != - || "$metadata_types" != - ]]; then
    grep -Fq '_standards/artifact-metadata.md' "$file" ||
      fail "Markdown command lacks canonical metadata construction rule: $agent $command"
  fi
done

for stage4_owner in 's4-qa-auto:/write-tests' 's4-dev:/dev-report' \
  's4-qa-auto:/run-tests' 's4-techlead:/review' 's4-dev:/update-notes'; do
  stage4_agent="${stage4_owner%%:*}"
  stage4_command="${stage4_owner#*:}"
  [[ "$(command_access "$stage4_agent" "$stage4_command")" == scoped-write ]] ||
    fail "Stage 4 mutator is not scoped-write: $stage4_owner"
  [[ "$(command_result_verifier "$stage4_agent" "$stage4_command")" == \
    change-scope-and-declared-output ]] ||
    fail "Stage 4 mutator lacks combined verifier: $stage4_owner"
done
[[ "$(command_result_verifier l1-analyze /impact)" == change-scope-l1-dispatch &&
   "$(command_access l1-analyze /impact)" == scoped-write ]] ||
  fail 'L1 impact is not isolated behind its dedicated workflow'
[[ "$(command_result_verifier s3-arch /change-impact)" == change-scope-s3-dispatch &&
   "$(command_access s3-arch /change-impact)" == scoped-write ]] ||
  fail 'S3 change-impact is not isolated behind its dedicated workflow'

[[ "$(sed -n '1p' "$LIFECYCLES")" == $'logical_id\tlifecycle\towners\tordering' ]] ||
  fail 'shared artifact lifecycle header mismatch'
while IFS=$'\t' read -r agent command _group _logical_id _cardinality _track _patterns; do
  [[ "$agent:$command" == launcher:/full-dod-approval ]] && continue
  awk -F '\t' -v agent="$agent" -v command="$command" \
    'NR > 1 && $2 == agent && $3 == command && ($5 == "write" || $5 == "scoped-write") &&
      ($4 == "mutating-declared-output" || $4 == "orchestrated-special") {found=1}
     END {exit !found}' "$REGISTRY" ||
    fail "output group producer is not a registered write command: $agent $command"
done < <(tail -n +2 "$GROUP_REGISTRY")

expected_step=1
while IFS=$'\t' read -r step agent command _gate_before _gate_after _dod _completion; do
  [[ "$step" == "$expected_step" ]] || fail "cycle step sequence gap: expected=$expected_step actual=$step"
  awk -F '\t' -v agent="$agent" -v command="$command" \
    'NR > 1 && $2 == agent && $3 == command && $4 == "mutating-declared-output" {found=1}
     END {exit !found}' "$REGISTRY" ||
    fail "mandatory cycle command is not registered mutating output: $agent $command"
  awk -F '\t' -v agent="$agent" -v command="$command" \
    'NR > 1 && $1 == agent && $2 == command {found=1} END {exit !found}' "$GROUP_REGISTRY" ||
    fail "mandatory cycle command has no reachable declared output: $agent $command"
  expected_step=$((expected_step + 1))
done < <(tail -n +2 "$ROOT/_contract/cycle1-steps-v1.tsv")

while IFS= read -r logical_id; do
  [[ "$(awk -F '\t' -v id="$logical_id" 'NR > 1 && $1 == id {n++} END {print n+0}' "$LIFECYCLES")" == 1 ]] ||
    fail "duplicate logical owner has no exact shared lifecycle: $logical_id"
done < <(awk -F '\t' 'NR > 1 {count[$4]++} END {for (id in count) if (count[id] > 1) print id}' "$GROUP_REGISTRY" | sort)
while IFS=$'\t' read -r logical_id _lifecycle owners _ordering; do
  [[ "$(awk -F '\t' -v id="$logical_id" 'NR > 1 && $4 == id {n++} END {print n+0}' "$GROUP_REGISTRY")" -gt 1 ]] ||
    fail "shared lifecycle does not describe a shared logical id: $logical_id"
  actual_owners="$(awk -F '\t' -v id="$logical_id" 'NR > 1 && $4 == id {print $1 ":" $2}' \
    "$GROUP_REGISTRY" | sort -u | paste -sd, -)"
  declared_owners="$(tr ',' '\n' <<< "$owners" | sort -u | paste -sd, -)"
  [[ "$actual_owners" == "$declared_owners" ]] ||
    fail "shared lifecycle owner set mismatch: $logical_id"
  previous_step=0
  IFS=',' read -r -a lifecycle_owners <<< "$owners"
  for owner in "${lifecycle_owners[@]}"; do
    owner_agent="${owner%%:*}"
    owner_command="${owner#*:}"
    awk -F '\t' -v agent="$owner_agent" -v command="$owner_command" \
      'NR > 1 && $2 == agent && $3 == command {found=1} END {exit !found}' "$REGISTRY" ||
      fail "shared lifecycle owner is not registered: $owner"
    owner_step="$(awk -F '\t' -v agent="$owner_agent" -v command="$owner_command" \
      'NR > 1 && $2 == agent && $3 == command {print $1; exit}' \
      "$ROOT/_contract/cycle1-steps-v1.tsv")"
    if [[ -n "$owner_step" ]]; then
      (( owner_step > previous_step )) ||
        fail "shared lifecycle mandatory owner order invalid: $logical_id"
      previous_step="$owner_step"
    fi
  done
done < <(tail -n +2 "$LIFECYCLES")

for stale_output in PMO-YYYY-MM-DD-schedule.md PO-YYYY-MM-DD-sprint- \
  QA-REQ-YYYY-MM-DD-testcases.md; do
  ! rg -F "$stale_output" "$ROOT/cycle1-dev" >/dev/null ||
    fail "active role advertises output without canonical lifecycle: $stale_output"
done
grep -Fq 'optional One Agent refinement' "$ROOT/cycle1-dev/s3-rbac/CLAUDE.md" ||
  fail 'RBAC matrix refinement is not explicitly optional'
grep -Fq 'tracking/PMO-constraints.md' \
  "$ROOT/cycle1-dev/s1-pmo/.claude/commands/charter.md" ||
  fail 'PMO charter command omits its required second declared output'

while IFS='|' read -r agent task _position _description; do
  capability="$(command_capability "$agent" "$task")" ||
    fail "optional command is not registered: $agent $task"
  [[ "$capability" == read-only-no-output || "$capability" == mutating-declared-output ]] ||
    fail "optional command uses special dispatcher: $agent $task"
done < <(printf '%s\n' "${OPTIONAL_AGENTS_DEF[@]}")
[[ ${#OPTIONAL_AGENTS_DEF[@]} -eq 2 ]] ||
  fail 'optional list must contain only before/after structure validation'

[[ "$(awk -F '\t' '$2 == "s3-dba" && $3 == "/migration" {print $4 FS $5}' "$REGISTRY")" == \
  $'mutating-declared-output\twrite' ]] ||
  fail 's3-dba /migration is not a declared-output producer'
[[ "$(awk -F '\t' '$1 == "s3-dba" && $2 == "/migration" {print $4 FS $5 FS $7}' "$GROUP_REGISTRY")" == \
  $'migration-runbook\tone\tstage3-design/outputs/DBA-*migration-runbook*.md|stage3-design/outputs/DBA-*migration-not-applicable*.md' ]] ||
  fail 'migration design/N-A output group is not exact'
mapfile -t migration_sequence < <(
  awk -F '\t' 'NR > 1 && (($2 == "s3-dba" && ($3 == "/schema" || $3 == "/migration")) ||
    ($2 == "s4-qa-auto" && ($3 == "/write-tests" || $3 == "/run-tests")) ||
    ($2 == "s4-dev" && $3 == "/dev-report")) {print $2 ":" $3}' \
    "$ROOT/_contract/cycle1-steps-v1.tsv"
)
[[ "${migration_sequence[*]}" == \
  's3-dba:/schema s3-dba:/migration s4-qa-auto:/write-tests s4-dev:/dev-report s4-qa-auto:/run-tests' ]] ||
  fail "migration plan order is incoherent: ${migration_sequence[*]}"

command_supported_by_one_agent s0-validate /validate ||
  fail 'registered read-only command is hidden from One Agent'
if command_supported_by_one_agent s0-secrets /add; then
  fail 'secret mutation command is exposed through generic One Agent'
fi

while IFS='|' read -r command expected_verifier; do
  tracker_special_command s0-tracker "$command" ||
    fail "Tracker special command is not routed: $command"
  [[ "$(tracker_special_expected_verifier s0-tracker "$command")" == "$expected_verifier" ]] ||
    fail "Tracker special verifier mapping mismatch: $command"
  [[ "$(command_result_verifier s0-tracker "$command")" == "$expected_verifier" ]] ||
    fail "Tracker capability verifier mismatch: $command"
done <<'TRACKER_SPECIALS'
/sprint-close|tracker-sprint-close-postconditions
/sprint-init|tracker-sprint-init-postconditions
/task-add|tracker-task-postconditions
/task-block|tracker-task-postconditions
/task-done|tracker-task-done-postconditions
TRACKER_SPECIALS
[[ "$(awk -F '\t' 'NR > 1 && $2 == "s0-tracker" && $4 == "orchestrated-special" &&
  $3 != "/release-notes" {n++} END {print n+0}' "$REGISTRY")" == 5 ]] ||
  fail 'Tracker special command set changed without a dedicated launcher mapping'

PROJECTS="$TMP_DIR/tracker-projects"
PROJECT=Tracker
mkdir -p "$PROJECTS/$PROJECT/tracking"
[[ "$(tracker_next_task_id)" == T-001 ]] ||
  fail 'missing backlog did not resolve the first task id'
printf '%s\n' '| ID | Название | Агент | SP | Статус |' \
  '|---|---|---|---:|---|' > "$PROJECTS/$PROJECT/tracking/backlog.md"
tracker_before="$(project_snapshot_sha256)"
printf '%s\n' '| T-001 | task | s4-dev | 3 | TODO |' >> \
  "$PROJECTS/$PROJECT/tracking/backlog.md"
verify_tracker_special_command '/task-add expected-task=T-001' "$tracker_before" ||
  fail "valid task-add postcondition was rejected: $TRACKER_VERIFICATION_REASON"
if verify_tracker_special_command '/task-add expected-task=T-001' "$(project_snapshot_sha256)"; then
  fail 'task-add passed without a state change'
fi
tracker_before="$(project_snapshot_sha256)"
sed -i 's/| T-001 | task | s4-dev | 3 | TODO |/| T-001 | task | s4-dev | 3 | BLOCKED |/' \
  "$PROJECTS/$PROJECT/tracking/backlog.md"
printf '%s\n' 'Blocker reason: waiting for exact dependency' >> \
  "$PROJECTS/$PROJECT/tracking/backlog.md"
verify_tracker_special_command \
  $'/task-block task=T-001\nBlocker reason: waiting for exact dependency' "$tracker_before" ||
  fail "valid task-block postcondition was rejected: $TRACKER_VERIFICATION_REASON"
mkdir -p "$PROJECTS/$PROJECT/tracking/sprints"
printf '%s\n' 'sprint: 2' 'status: ACTIVE' \
  '| ID | Название | Агент | SP | Статус |' '|---|---|---|---:|---|' \
  '| T-001 | task | s4-dev | 3 | BLOCKED |' > \
  "$PROJECTS/$PROJECT/tracking/current-sprint.md"
cp "$PROJECTS/$PROJECT/tracking/current-sprint.md" \
  "$PROJECTS/$PROJECT/tracking/sprints/sprint-02.md"
printf '%s\n' 'sprint: 1' 'status: CLOSED' \
  '| ID | Название | Агент | SP | Статус |' '|---|---|---|---:|---|' \
  '| T-001 | task | s4-dev | 3 | IN_PROGRESS |' > \
  "$PROJECTS/$PROJECT/tracking/sprints/sprint-01.md"
tracker_task_occurrences_have_status T-001 BLOCKED 3 3 ||
  fail 'historical carried task status contaminated the active Tracker postcondition'

PROJECTS="$TMP_DIR/projects"
PROJECT=Alpha
mkdir -p "$PROJECTS/$PROJECT"
CURRENT_RUN_ID=''
EXECUTION_STEP_PROFILES=(codex)
observed_access=''
run_agent() {
  observed_access="${ACTIVE_AGENT_ACCESS:-write}"
  return 0
}

RUN_CYCLE=('s0-validate:/validate')
RUN_OPTIONAL=(1)
execute_cycle 'Optional read-only fixture' 1 >/dev/null ||
  fail 'read-only optional command was blocked after process success'
[[ "$observed_access" == read-only ]] ||
  fail "read-only command received access=$observed_access"
[[ "$EXECUTION_LAST_STEP_STATUS" == READ_ONLY_VERIFIED ]] ||
  fail 'read-only optional command received an artifact verdict'

RUN_CYCLE=('s1-pm:/vision')
RUN_OPTIONAL=(0)
if execute_cycle 'Missing output fixture' 1 >/dev/null; then
  fail 'mutating command passed on process exit without declared output'
fi
[[ "$EXECUTION_LAST_REASON" == *'missing declared output group'* ]] ||
  fail 'mutating no-output failure reason was not retained'

invocations=0
run_agent() {
  invocations=$((invocations + 1))
  return 0
}
RUN_CYCLE=('s0-secrets:/add')
RUN_OPTIONAL=(0)
if execute_cycle 'Special command fixture' 1 >/dev/null; then
  fail 'special command passed through generic cycle executor'
fi
[[ "$invocations" -eq 0 ]] || fail 'special command reached runtime'

PROJECTS="$TMP_DIR/tracker-projects"
PROJECT=Tracker
BASE_PROFILE='codex||||'
apply_profile "$BASE_PROFILE"
SDLC_RUNTIME_ROUTING=single
export SDLC_RUNTIME_ROUTING
EXECUTION_STEP_PROFILES=('codex||||')
tracker_invocations=0
run_agent() {
  tracker_invocations=$((tracker_invocations + 1))
  printf '%s\n' "runtime mutation $tracker_invocations" >> \
    "$PROJECTS/$PROJECT/tracking/backlog.md"
}
verify_tracker_special_command() {
  TRACKER_VERIFICATION_REASON='tracker fixture postcondition verified'
  return 0
}
EXECUTION_PREVIEW_BLOCKED=0
run_agent_with_preview s0-tracker "$PROJECT" '/task-add expected-task=T-002' <<< 'b' >/dev/null || true
[[ "$tracker_invocations" -eq 0 ]] || fail 'cancelled Tracker Preview dispatched runtime'
EXECUTION_PREVIEW_BLOCKED=0
run_agent_with_preview s0-tracker "$PROJECT" '/task-add expected-task=T-002' <<< 'r' >/dev/null
[[ "$tracker_invocations" -eq 1 ]] || fail 'confirmed Tracker Preview did not dispatch exactly once'
tracker_events="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/events.jsonl"
grep -Eq '"event":"tracker_artifact_verified".*"step_status":"ARTIFACT_VERIFIED"' "$tracker_events" ||
  fail 'Tracker dedicated workflow did not journal its verified postcondition'

echo 'PASS: Command Capabilities v1 smoke'

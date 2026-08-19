#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-}"
PROJECT_INPUT="${2:-}"
RUN_ID="${3:-}"
blocked() { echo "CYCLE 1 EXECUTION PROOF BLOCKED: $*" >&2; exit 1; }

[[ "$MODE" == create || "$MODE" == validate ]] || blocked 'mode must be create|validate'
[[ -d "$PROJECT_INPUT" ]] || blocked 'Project directory is required'
[[ "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]] || blocked 'valid terminal run_id is required'
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# Source the launcher-owned journal implementation without entering its UI.
source "$ROOT/sdlc.sh"
PROJECTS="$(dirname "$PROJECT_PATH")"
PROJECT="$(basename "$PROJECT_PATH")"
TERMINAL_RUN_DIR="$(journal_run_dir "$PROJECT" "$RUN_ID")"
PROOF="$TERMINAL_RUN_DIR/cycle1-completion-proof-v2.yaml"
CHAIN_FILE="$TERMINAL_RUN_DIR/cycle1-execution-chain-v1.tsv"
CURRENT_MANIFEST="$PROJECT_PATH/tracking/current-artifacts-v1.tsv"
CURRENT_TOOL="$SCRIPT_DIR/current-artifact.sh"
STEPS="$ROOT/_contract/cycle1-steps-v1.tsv"
PROOF_KEYS='schema_version proof_status project project_path_sha256 terminal_run_id root_run_id run_chain run_chain_ref run_chain_sha256 root_plan_sha256 mandatory_step_count mandatory_steps_digest verified_step_event_count verified_steps_digest gate_ids gate_events_digest dod_auto_event_hash dod_approval_event_hash current_artifact_manifest_ref current_artifact_manifest_sha256 full_dod_approval_ref product_profile_revision source_revision created_at'
CHAIN_HEADER=$'schema_version\tchain_index\trun_id\tparent_run_id\trun_type\tplan_sha256\tplan_step_count\tresume_from_parent_step\tevents_prefix_count\tevents_prefix_sha256\tevents_prefix_last_hash'

field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted {
    value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value);
    print value; exit
  }' "$file"
}

declare -a CHAIN_RUNS=()
declare -A CHAIN_PLAN_SHA=()
ROOT_RUN_ID=''
ROOT_PLAN=''
RUN_CHAIN_CSV=''

collect_chain() {
  local current="$RUN_ID" dir plan parent type index
  local -a reverse=()
  declare -A seen=()
  while :; do
    [[ "$current" =~ ^[A-Za-z0-9._-]+$ && -z "${seen[$current]:-}" ]] ||
      blocked 'Retry chain contains an invalid id or cycle'
    seen["$current"]=1
    journal_validate_run "$PROJECT" "$current" || blocked "Journal invalid: $current"
    dir="$(journal_run_dir "$PROJECT" "$current")"
    plan="$dir/plan.md"
    grep -Fqx "project_path: $(journal_yaml_quote "$PROJECT_PATH")" "$plan" ||
      blocked "run belongs to a different Project path: $current"
    reverse+=("$current")
    (( ${#reverse[@]} <= 64 )) || blocked 'Retry chain exceeds safe depth'
    parent="$(field "$plan" parent_run_id)"
    type="$(field "$plan" type)"
    if [[ "$parent" == none ]]; then
      [[ "$type" == CYCLE ]] || blocked 'root execution must be a CYCLE run'
      break
    fi
    [[ "$type" == RESUME && "$parent" =~ ^[A-Za-z0-9._-]+$ ]] ||
      blocked "non-root execution must be a linked RESUME run: $current"
    current="$parent"
  done
  CHAIN_RUNS=()
  for ((index=${#reverse[@]} - 1; index>=0; index--)); do
    CHAIN_RUNS+=("${reverse[$index]}")
  done
  ROOT_RUN_ID="${CHAIN_RUNS[0]}"
  ROOT_PLAN="$(journal_run_dir "$PROJECT" "$ROOT_RUN_ID")/plan.md"
  RUN_CHAIN_CSV="$(IFS=,; printf '%s' "${CHAIN_RUNS[*]}")"
  for current in "${CHAIN_RUNS[@]}"; do
    CHAIN_PLAN_SHA["$current"]="$(awk 'NF {print $1; exit}' \
      "$(journal_run_dir "$PROJECT" "$current")/plan.sha256")"
  done
}

plan_entries() {
  local run_id="$1" output="$2" plan n entry profile source
  plan="$(journal_run_dir "$PROJECT" "$run_id")/plan.md"
  : > "$output"
  while IFS=$'\t' read -r n entry; do
    profile="$(field "$plan" "step_${n}_profile")"
    source="$(field "$plan" "step_${n}_route_source")"
    [[ -n "$profile" && -n "$source" ]] || blocked "run has incomplete frozen route: $run_id step $n"
    printf '%s\t%s\t%s\n' "$entry" "$profile" "$source" >> "$output"
  done < <(sed -n 's/^\([0-9][0-9]*\)\. \(.*\)$/\1\t\2/p' "$plan")
}

validate_chain_links() {
  local work="$1" index parent child next parent_entries child_entries expected links
  for ((index=1; index<${#CHAIN_RUNS[@]}; index++)); do
    parent="${CHAIN_RUNS[$((index - 1))]}"
    child="${CHAIN_RUNS[$index]}"
    [[ "$(field "$(journal_run_dir "$PROJECT" "$child")/plan.md" parent_run_id)" == "$parent" ]] ||
      blocked "Retry child does not name its exact parent: $child"
    next="$(journal_resume_point "$PROJECT" "$parent")" ||
      blocked "cannot derive verified resume point for parent: $parent"
    parent_entries="$work/parent-$index.tsv"
    child_entries="$work/child-$index.tsv"
    expected="$work/expected-$index.tsv"
    plan_entries "$parent" "$parent_entries"
    plan_entries "$child" "$child_entries"
    (( next >= 1 && next <= $(wc -l < "$parent_entries") )) ||
      blocked "Retry parent has no incomplete suffix: $parent"
    tail -n +"$next" "$parent_entries" > "$expected"
    if ! cmp -s "$expected" "$child_entries"; then
      diff -u "$expected" "$child_entries" >&2 || true
      blocked "Retry child plan/routes are not the exact immutable parent suffix: $child"
    fi
    mapfile -t links < <(jq -r --arg child "$child" '
      select(.event == "retry_child_created" and .evidence == ("child run " + $child)) |
      .event_hash
    ' "$(journal_run_dir "$PROJECT" "$parent")/events.jsonl")
    (( ${#links[@]} == 1 )) ||
      blocked "parent must contain exactly one digest-valid child link: $parent -> $child"
  done
}

build_root_plan_map() {
  local map_file="$1" expected=0 actual entry canonical
  : > "$map_file"
  mapfile -t plan_entries_rows < <(sed -n 's/^\([0-9][0-9]*\)\. \(.*\)$/\1\t\2/p' "$ROOT_PLAN")
  (( ${#plan_entries_rows[@]} >= 28 )) || blocked 'root execution plan has fewer than 28 steps'
  for row in "${plan_entries_rows[@]}"; do
    actual="${row%%$'\t'*}"
    entry="${row#*$'\t'}"
    canonical="${CYCLE1_AGENTS[$expected]:-}"
    if [[ -n "$canonical" && "$entry" == "$canonical" ]]; then
      printf '%s\t%s\t%s\n' "$((expected + 1))" "$actual" "$entry" >> "$map_file"
      expected=$((expected + 1))
      continue
    fi
    if [[ "$entry" == s0-validate:/validate* && ( $expected -eq 0 || $expected -eq 28 ) ]]; then
      continue
    fi
    blocked "root plan diverges from canonical Cycle 1 at actual step $actual: $entry"
  done
  (( expected == 28 )) || blocked "root plan contains only $expected canonical steps"
}

find_step_in_run() {
  local run_id="$1" wanted="$2"
  awk -v wanted="$wanted" '
    match($0, /^[0-9]+\. /) {
      step=substr($0, 1, RSTART + RLENGTH - 3)
      entry=substr($0, RLENGTH + 1)
      if (entry == wanted) { print step; found++ }
    }
    END { exit(found == 1 ? 0 : 1) }
  ' "$(journal_run_dir "$PROJECT" "$run_id")/plan.md"
}

event_hashes() {
  local run_id="$1" event="$2" step="$3" agent="$4" task="$5"
  jq -r --arg event "$event" --argjson step "$step" --arg agent "$agent" --arg task "$task" '
    select(.event == $event and .step == $step and .agent == $agent and .task == $task) |
    .event_hash
  ' "$(journal_run_dir "$PROJECT" "$run_id")/events.jsonl"
}

exact_event_hash() {
  local run_id="$1" label="$2" event="$3" step="$4" agent="$5" task="$6"
  local -a hashes=()
  mapfile -t hashes < <(event_hashes "$run_id" "$event" "$step" "$agent" "$task")
  (( ${#hashes[@]} == 1 )) ||
    blocked "$label requires exactly one event in run $run_id, found ${#hashes[@]}"
  [[ "${hashes[0]}" =~ ^[0-9a-f]{64}$ ]] || blocked "$label event hash invalid"
  printf '%s\n' "${hashes[0]}"
}

validate_selected_step_has_no_failure() {
  local run_id="$1" step="$2" entry="$3" events
  events="$(journal_run_dir "$PROJECT" "$run_id")/events.jsonl"
  ! jq -e --argjson step "$step" 'select(.step == $step and (
    .event == "step_failed" or .event == "step_artifact_unverified" or
    .event == "gate_blocked" or .event == "software_dod_blocked" or
    .event == "step_skipped" or .event == "cycle1_completion_blocked"
  ))' "$events" >/dev/null ||
    blocked "selected execution segment contains failed/blocked evidence: $entry"
}

validate_manifest_chain_binding() {
  local schema logical member ref digest producer command group source revision run_id
  local plan_sha recorded extra expected_plan
  [[ -f "$CURRENT_MANIFEST" && ! -L "$CURRENT_MANIFEST" ]] ||
    blocked 'current artifact manifest missing/symlink'
  while IFS=$'\t' read -r schema logical member ref digest producer command group source revision \
    run_id plan_sha recorded extra; do
    [[ -n "$schema" ]] || continue
    expected_plan="${CHAIN_PLAN_SHA[$run_id]:-}"
    [[ -n "$expected_plan" && "$plan_sha" == "$expected_plan" ]] ||
      blocked "current artifact row is outside the exact run/plan chain: $logical"
  done < <(tail -n +2 "$CURRENT_MANIFEST")
}

compute_semantic_evidence() {
  local work="$1" plan_map="$work/root-plan-map.tsv" verified="$work/verified.tsv"
  local gates="$work/gates.tsv" canonical_step root_actual entry agent task selected_run
  local actual_step hash gate_before gate_after gate step_hash source status_ref approval_ref
  local index
  collect_chain
  validate_chain_links "$work"
  [[ ${#CYCLE1_AGENTS[@]} -eq 28 ]] || blocked 'canonical Cycle 1 registry is not 28 steps'
  build_root_plan_map "$plan_map"
  : > "$verified"
  : > "$gates"
  DOD_AUTO_HASH=''
  DOD_APPROVAL_HASH=''
  while IFS=$'\t' read -r canonical_step root_actual entry; do
    agent="${entry%%:*}"
    task="${entry#*:}"
    selected_run=''
    actual_step=''
    for ((index=${#CHAIN_RUNS[@]} - 1; index>=0; index--)); do
      if actual_step="$(find_step_in_run "${CHAIN_RUNS[$index]}" "$entry" 2>/dev/null)"; then
        selected_run="${CHAIN_RUNS[$index]}"
        break
      fi
    done
    [[ -n "$selected_run" && "$actual_step" =~ ^[1-9][0-9]*$ ]] ||
      blocked "canonical step absent from effective run chain: $entry"
    validate_selected_step_has_no_failure "$selected_run" "$actual_step" "$entry"
    hash="$(exact_event_hash "$selected_run" "step $canonical_step $entry" \
      step_artifact_verified "$actual_step" "$agent" "$task")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$canonical_step" "$selected_run" \
      "$actual_step" "$entry" "$hash" >> "$verified"
    gate_before="$(awk -F'\t' -v step="$canonical_step" 'NR > 1 && $1 == step {print $4}' "$STEPS")"
    gate_after="$(awk -F'\t' -v step="$canonical_step" 'NR > 1 && $1 == step {print $5}' "$STEPS")"
    for gate in "$gate_before" "$gate_after"; do
      [[ "$gate" != none ]] || continue
      step_hash="$(exact_event_hash "$selected_run" "Gate $gate" gate_pass \
        "$actual_step" '' "Gate $gate")"
      printf '%s\t%s\t%s\t%s\n' "$gate" "$selected_run" "$actual_step" "$step_hash" >> "$gates"
    done
    if [[ "$(awk -F'\t' -v step="$canonical_step" 'NR > 1 && $1 == step {print $6}' "$STEPS")" == full ]]; then
      DOD_AUTO_HASH="$(exact_event_hash "$selected_run" 'automated DoD subset' \
        software_dod_auto_pass "$actual_step" "$agent" "$task")"
      DOD_APPROVAL_HASH="$(exact_event_hash "$selected_run" 'full DoD approval' \
        software_dod_approved "$actual_step" "$agent" "$task")"
    fi
  done < "$plan_map"
  [[ "$(cut -f1 "$gates" | sort -n | paste -sd, -)" == 1,2,3,4,5 ]] ||
    blocked 'Gate 1..5 pass event set is incomplete/duplicate'
  [[ "$DOD_AUTO_HASH" =~ ^[0-9a-f]{64}$ && "$DOD_APPROVAL_HASH" =~ ^[0-9a-f]{64}$ ]] ||
    blocked 'full DoD event set is incomplete'
  validate_manifest_chain_binding
  status_ref="$(bash "$CURRENT_TOOL" resolve-one "$PROJECT_PATH" tdd-status "$RUN_CHAIN_CSV")" ||
    blocked 'current TDD status is not bound to completion run chain'
  source="$(field "$PROJECT_PATH/$status_ref" source_revision)"
  [[ "$source" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] ||
    blocked 'current TDD source revision invalid'
  bash "$SCRIPT_DIR/tdd-status-check.sh" "$PROJECT_PATH" PASS >/dev/null ||
    blocked 'TDD status/full affected evidence invalid'
  bash "$CURRENT_TOOL" validate-run "$PROJECT_PATH" "$RUN_CHAIN_CSV" "$source" >/dev/null ||
    blocked 'current artifact set is incomplete for full-cycle run chain/source'
  approval_ref="$(bash "$CURRENT_TOOL" resolve-one "$PROJECT_PATH" dod-approval \
    "$RUN_CHAIN_CSV" "$source")" || blocked 'current full DoD approval ref unavailable'
  bash "$SCRIPT_DIR/dod-approval-check.sh" "$PROJECT_PATH" "$source" "$RUN_CHAIN_CSV" >/dev/null ||
    blocked 'full DoD approval invalid'
  ROOT_PLAN_SHA="${CHAIN_PLAN_SHA[$ROOT_RUN_ID]}"
  MANDATORY_DIGEST="$(sha256sum "$STEPS" | awk '{print $1}')"
  VERIFIED_DIGEST="$(sha256sum "$verified" | awk '{print $1}')"
  GATE_DIGEST="$(sort -n "$gates" | sha256sum | awk '{print $1}')"
  PROFILE_REVISION="$(field "$PROJECT_PATH/tracking/product-ci-profile.yaml" revision)"
  SOURCE_REVISION="$source"
  FULL_DOD_APPROVAL_REF="$approval_ref"
}

validate_prefix() {
  local run_id="$1" count="$2" expected_sha="$3" expected_last="$4"
  local events prefix actual_last
  [[ "$count" =~ ^[1-9][0-9]*$ && "$expected_sha" =~ ^[0-9a-f]{64}$ &&
    "$expected_last" =~ ^[0-9a-f]{64}$ ]] || blocked 'invalid chain event prefix fields'
  events="$(journal_run_dir "$PROJECT" "$run_id")/events.jsonl"
  (( $(wc -l < "$events") >= count )) || blocked "Journal event prefix was truncated: $run_id"
  prefix="$(mktemp)"
  head -n "$count" "$events" > "$prefix"
  [[ "$(sha256sum "$prefix" | awk '{print $1}')" == "$expected_sha" ]] ||
    blocked "Journal event prefix digest mismatch: $run_id"
  actual_last="$(tail -1 "$prefix" | sed -n 's/.*"event_hash":"\([0-9a-f]\{64\}\)"}$/\1/p')"
  [[ "$actual_last" == "$expected_last" ]] || blocked "Journal event prefix head mismatch: $run_id"
  rm -f "$prefix"
}

write_chain_file() {
  local tmp index run_id parent type plan plan_sha count resume events event_count event_sha last_hash
  tmp="$(mktemp "$TERMINAL_RUN_DIR/.cycle1-execution-chain-v1.XXXXXX")"
  printf '%s\n' "$CHAIN_HEADER" > "$tmp"
  for ((index=0; index<${#CHAIN_RUNS[@]}; index++)); do
    run_id="${CHAIN_RUNS[$index]}"
    plan="$(journal_run_dir "$PROJECT" "$run_id")/plan.md"
    parent="$(field "$plan" parent_run_id)"
    type="$(field "$plan" type)"
    plan_sha="${CHAIN_PLAN_SHA[$run_id]}"
    count="$(grep -Ec '^[0-9]+\. ' "$plan")"
    if (( index == 0 )); then
      resume=0
    else
      resume="$(journal_resume_point "$PROJECT" "${CHAIN_RUNS[$((index - 1))]}")"
    fi
    events="$(journal_run_dir "$PROJECT" "$run_id")/events.jsonl"
    event_count="$(wc -l < "$events")"
    event_sha="$(sha256sum "$events" | awk '{print $1}')"
    last_hash="$(tail -1 "$events" | sed -n 's/.*"event_hash":"\([0-9a-f]\{64\}\)"}$/\1/p')"
    [[ "$event_count" -gt 0 && "$last_hash" =~ ^[0-9a-f]{64}$ ]] ||
      blocked "Journal head unavailable for chain row: $run_id"
    printf '1\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$((index + 1))" "$run_id" "$parent" "$type" "$plan_sha" "$count" "$resume" \
      "$event_count" "$event_sha" "$last_hash" >> "$tmp"
  done
  mv "$tmp" "$CHAIN_FILE"
}

validate_chain_file() {
  local index=0 schema row_index run_id parent type plan_sha count resume event_count event_sha
  local last_hash extra expected_run expected_parent expected_type expected_count expected_resume
  [[ -f "$CHAIN_FILE" && ! -L "$CHAIN_FILE" ]] || blocked 'launcher-owned execution chain missing/symlink'
  [[ "$(head -1 "$CHAIN_FILE")" == "$CHAIN_HEADER" ]] || blocked 'execution chain header mismatch'
  while IFS=$'\t' read -r schema row_index run_id parent type plan_sha count resume event_count \
    event_sha last_hash extra; do
    [[ -n "$schema" ]] || continue
    expected_run="${CHAIN_RUNS[$index]:-}"
    [[ -n "$expected_run" ]] || blocked 'execution chain contains an extra run'
    expected_parent="$(field "$(journal_run_dir "$PROJECT" "$expected_run")/plan.md" parent_run_id)"
    expected_type="$(field "$(journal_run_dir "$PROJECT" "$expected_run")/plan.md" type)"
    expected_count="$(grep -Ec '^[0-9]+\. ' "$(journal_run_dir "$PROJECT" "$expected_run")/plan.md")"
    if (( index == 0 )); then expected_resume=0; else
      expected_resume="$(journal_resume_point "$PROJECT" "${CHAIN_RUNS[$((index - 1))]}")"
    fi
    [[ -z "$extra" && "$schema" == 1 && "$row_index" == "$((index + 1))" &&
      "$run_id" == "$expected_run" && "$parent" == "$expected_parent" &&
      "$type" == "$expected_type" && "$plan_sha" == "${CHAIN_PLAN_SHA[$run_id]}" &&
      "$count" == "$expected_count" && "$resume" == "$expected_resume" ]] ||
      blocked "execution chain row contradicts current Journals: ${run_id:-UNKNOWN}"
    validate_prefix "$run_id" "$event_count" "$event_sha" "$last_hash"
    index=$((index + 1))
  done < <(tail -n +2 "$CHAIN_FILE")
  (( index == ${#CHAIN_RUNS[@]} )) || blocked 'execution chain omits a run'
}

command -v jq >/dev/null 2>&1 || blocked 'jq capability is required'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
compute_semantic_evidence "$work"

if [[ "$MODE" == create ]]; then
  write_chain_file
  chain_sha="$(sha256sum "$CHAIN_FILE" | awk '{print $1}')"
  manifest_sha="$(sha256sum "$CURRENT_MANIFEST" | awk '{print $1}')"
  tmp="$(mktemp "$TERMINAL_RUN_DIR/.cycle1-completion-proof-v2.XXXXXX")"
  {
    printf '%s\n' 'schema_version: 2' 'proof_status: READY_FOR_COMPLETION' \
      "project: $PROJECT" \
      "project_path_sha256: $(printf '%s' "$PROJECT_PATH" | sha256sum | awk '{print $1}')" \
      "terminal_run_id: $RUN_ID" "root_run_id: $ROOT_RUN_ID" \
      "run_chain: $RUN_CHAIN_CSV" \
      'run_chain_ref: cycle1-execution-chain-v1.tsv' "run_chain_sha256: $chain_sha" \
      "root_plan_sha256: $ROOT_PLAN_SHA" 'mandatory_step_count: 28' \
      "mandatory_steps_digest: $MANDATORY_DIGEST" 'verified_step_event_count: 28' \
      "verified_steps_digest: $VERIFIED_DIGEST" 'gate_ids: 1,2,3,4,5' \
      "gate_events_digest: $GATE_DIGEST" "dod_auto_event_hash: $DOD_AUTO_HASH" \
      "dod_approval_event_hash: $DOD_APPROVAL_HASH" \
      'current_artifact_manifest_ref: tracking/current-artifacts-v1.tsv' \
      "current_artifact_manifest_sha256: $manifest_sha" \
      "full_dod_approval_ref: $FULL_DOD_APPROVAL_REF" \
      "product_profile_revision: $PROFILE_REVISION" "source_revision: $SOURCE_REVISION" \
      "created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$tmp"
  mv "$tmp" "$PROOF"
fi

[[ -f "$PROOF" && ! -L "$PROOF" ]] || blocked 'launcher-owned completion proof missing/symlink'
validate_chain_file
actual_keys="$(awk -F: 'NF >= 2 {print $1}' "$PROOF" | tr '\n' ' ' | sed 's/ $//')"
[[ "$actual_keys" == "$PROOF_KEYS" ]] || blocked 'execution proof fields/order mismatch'
[[ "$(field "$PROOF" schema_version)" == 2 &&
  "$(field "$PROOF" proof_status)" == READY_FOR_COMPLETION &&
  "$(field "$PROOF" project)" == "$PROJECT" &&
  "$(field "$PROOF" project_path_sha256)" == "$(printf '%s' "$PROJECT_PATH" | sha256sum | awk '{print $1}')" &&
  "$(field "$PROOF" terminal_run_id)" == "$RUN_ID" &&
  "$(field "$PROOF" root_run_id)" == "$ROOT_RUN_ID" &&
  "$(field "$PROOF" run_chain)" == "$RUN_CHAIN_CSV" &&
  "$(field "$PROOF" run_chain_ref)" == cycle1-execution-chain-v1.tsv &&
  "$(field "$PROOF" run_chain_sha256)" == "$(sha256sum "$CHAIN_FILE" | awk '{print $1}')" &&
  "$(field "$PROOF" root_plan_sha256)" == "$ROOT_PLAN_SHA" &&
  "$(field "$PROOF" mandatory_step_count)" == 28 &&
  "$(field "$PROOF" mandatory_steps_digest)" == "$MANDATORY_DIGEST" &&
  "$(field "$PROOF" verified_step_event_count)" == 28 &&
  "$(field "$PROOF" verified_steps_digest)" == "$VERIFIED_DIGEST" &&
  "$(field "$PROOF" gate_ids)" == 1,2,3,4,5 &&
  "$(field "$PROOF" gate_events_digest)" == "$GATE_DIGEST" &&
  "$(field "$PROOF" dod_auto_event_hash)" == "$DOD_AUTO_HASH" &&
  "$(field "$PROOF" dod_approval_event_hash)" == "$DOD_APPROVAL_HASH" &&
  "$(field "$PROOF" current_artifact_manifest_ref)" == tracking/current-artifacts-v1.tsv &&
  "$(field "$PROOF" current_artifact_manifest_sha256)" == "$(sha256sum "$CURRENT_MANIFEST" | awk '{print $1}')" &&
  "$(field "$PROOF" full_dod_approval_ref)" == "$FULL_DOD_APPROVAL_REF" &&
  "$(field "$PROOF" product_profile_revision)" == "$PROFILE_REVISION" &&
  "$(field "$PROOF" source_revision)" == "$SOURCE_REVISION" ]] ||
  blocked 'execution proof contradicts current plan chain/events/artifacts'
[[ "$(field "$PROOF" created_at)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  blocked 'execution proof created_at invalid'

echo "CYCLE 1 EXECUTION PROOF VERIFIED: terminal=$RUN_ID root=$ROOT_RUN_ID runs=${#CHAIN_RUNS[@]} steps=28 gates=1,2,3,4,5 dod=FULL source=$SOURCE_REVISION manifest=$(field "$PROOF" current_artifact_manifest_sha256)"

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/artifact-metadata-fixture.sh"
source "$ROOT/tests/lib/human-approval-fixture.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-cycle1-completion.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
setup_human_approval_receipts "$TMP_DIR/human-approval-receipts"
PROJECT="${CYCLE1_COMPLETION_FIXTURE_EXPORT_DIR:-$TMP_DIR/CompletionFixture}"
PROJECT_NAME="$(basename "$PROJECT")"
PROJECTS_ROOT="$(dirname "$PROJECT")"
mkdir -p "$PROJECT"
CHECK="$ROOT/cycle1-dev/s0-validate/cycle1-completion-check.sh"
SOURCE=5555555555555555555555555555555555555555

fail() { echo "FAIL: $*" >&2; exit 1; }
field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit }' "$file"
}
expect_blocked() {
  local label="$1" output="$2"
  if bash "$CHECK" "$PROJECT" >"$output" 2>&1; then fail "$label"; fi
  grep -Fq 'CYCLE 1 COMPLETION BLOCKED' "$output" || fail "$label did not emit BLOCKED"
}

S5_FIXTURE_EXPORT_DIR="$PROJECT" S5_FIXTURE_EXPORT_VARIANT=performance-exception \
  bash "$ROOT/tests/s5-validation-v1-smoke.sh" >/dev/null
while IFS= read -r approval; do
  record_human_approval_receipt "$PROJECT" "$approval"
done < <(find "$PROJECT/tracking/approvals" -maxdepth 1 -type f -name 'APPROVAL-*.yaml' | sort)
mkdir -p "$PROJECT/tracking/completion"
write_artifact_metadata_fixture "$PROJECT/tracking/cycle-summary.md" "$PROJECT" \
  CYCLE1-SUMMARY-001 cycle-summary TRACKING s0-tracker "$SOURCE" VALIDATED 'Cycle 1 Summary'
record="$PROJECT/tracking/evidence/v1/EV-BUILD-S5.yaml"
record_uri=tracking/evidence/v1/EV-BUILD-S5.yaml
record_sha="$(sha256sum "$record" | awk '{print $1}')"
observed="$(field "$record" observed_at)"
freshness="$(field "$record" freshness_seconds)"
fresh_until="$(date -u -d "$observed + $freshness seconds" +%Y-%m-%dT%H:%M:%SZ)"
subject="$(field "$record" subject_digest)"
build="$(field "$record" build_identity)"

sca_raw="$PROJECT/tracking/evidence/raw/sca-completion.json"
printf '{"schema_version":1,"check_id":"sca","source_revision":"%s","secret_count":0,"integrity_status":"pass","tampered_dependencies":0,"malicious_dependencies":0,"findings":[{"id":"CVE-COMPLETION-MEDIUM","cvss":5.5,"status":"open"}]}\n' \
  "$SOURCE" > "$sca_raw"
sca_raw_sha="$(sha256sum "$sca_raw" | awk '{print $1}')"
sca_record="$PROJECT/tracking/evidence/v1/EV-SCA-COMPLETION.yaml"
cp "$record" "$sca_record"
sed -i -e 's/evidence_id: EV-BUILD-S5/evidence_id: EV-SCA-COMPLETION/' \
  -e 's/check_id: build/check_id: sca/' -e 's/category: build/category: security/' \
  -e 's/tool_name: fixture-builder/tool_name: fixture-sca/' \
  -e 's/policy_revision: quality-global-v1/policy_revision: security-v1/' \
  -e 's#raw_result_uri: tracking/evidence/raw/build.json#raw_result_uri: tracking/evidence/raw/sca-completion.json#' \
  -e "s/^raw_result_sha256:.*/raw_result_sha256: $sca_raw_sha/" \
  -e 's#risk_exception_ref: none#risk_exception_ref: tracking/risk-exceptions/RISK-SG3-SCA.yaml#' \
  "$sca_record"

deadline="$(awk -F: '$1 == "- Дедлайн устранения" {sub(/^[^:]*:[[:space:]]*/, "", $0); print; exit}' \
  "$PROJECT/tracking/tech-debt.md")"
[[ "$deadline" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail 'exported TD deadline missing'
{
  printf '%s\n' '' '### TD-SG3-SCA — Completion Medium dependency finding'
  printf '%s\n' '- Owner: product-security-owner' '- Source sprint: 1' '- Target sprint: 2' \
    "- Дедлайн устранения: $deadline" '- Exception type: security' \
    '- Finding severity: SECURITY_MEDIUM' '- Finding IDs: CVE-COMPLETION-MEDIUM' \
    '- CVSS: 5.5' '- Risk exception: RISK-SG3-SCA' '- Статус: OPEN'
} >> "$PROJECT/tracking/tech-debt.md"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
expires_at="$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)"
{
  printf '%s\n' 'schema_version: 3' 'exception_id: RISK-SG3-SCA' \
    'exception_type: security' 'finding_severity: SECURITY_MEDIUM' \
    'tech_debt_id: TD-SG3-SCA' 'known_issue_id: none' 'owner: product-security-owner' \
    'approved_by: s4-techlead' 'rationale: bounded SG3 remediation accepted for completion source' \
    'scope: sca CVE-COMPLETION-MEDIUM only' 'check_id: sca' \
    'finding_ids: CVE-COMPLETION-MEDIUM' "source_revision: $SOURCE" \
    "subject_digest: $subject" "created_at: $created_at" "expires_at: $expires_at" \
    'status: ACTIVE'
} > "$PROJECT/tracking/risk-exceptions/RISK-SG3-SCA.yaml"

sca_record_uri=tracking/evidence/v1/EV-SCA-COMPLETION.yaml
sca_record_sha="$(sha256sum "$sca_record" | awk '{print $1}')"
sca_observed="$(field "$sca_record" observed_at)"
sca_freshness="$(field "$sca_record" freshness_seconds)"
{
  printf '%s\n' $'evidence_id\tcheck_id\tverdict\trecord_uri\trecord_sha256\tobserved_at\tfreshness_seconds\tsubject_digest\tbuild_identity'
  printf 'EV-BUILD-S5\tbuild\tPASS\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$record_uri" "$record_sha" "$observed" "$freshness" "$subject" "$build"
  printf 'EV-SCA-COMPLETION\tsca\tPASS\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$sca_record_uri" "$sca_record_sha" "$sca_observed" "$sca_freshness" "$subject" "$build"
} > "$PROJECT/tracking/completion/CYCLE1-evidence-bundle-v1.tsv"

bundle_sha="$(sha256sum "$PROJECT/tracking/completion/CYCLE1-evidence-bundle-v1.tsv" | awk '{print $1}')"
go_ref=stage5-testing/outputs/QA-2026-07-27-go-no-go.md
go_sha="$(sha256sum "$PROJECT/$go_ref" | awk '{print $1}')"
index_sha="$(sha256sum "$PROJECT/tracking/validation/S5-validation-v1.tsv" | awk '{print $1}')"
defect_sha="$(sha256sum "$PROJECT/stage5-testing/outputs/DEF-defects-v1.tsv" | awk '{print $1}')"

# Build the exact current Stage 4 handoff required by full DoD/execution proof.
mkdir -p "$PROJECT/stage4-dev/outputs" "$PROJECT/tests" "$PROJECT/tracking/approvals"
printf '%s\n' 'native test result' > "$PROJECT/tests/test-completion.txt"
{
  printf '%s\n' $'test_id\ttest_uri\tchange_id\tresult\tsource_revision'
  printf 'TEST-COMPLETION\ttests/test-completion.txt\tFR-001\tPASS\t%s\n' "$SOURCE"
} > "$PROJECT/stage4-dev/outputs/QA-affected-tests-v1.tsv"
tdd_manifest_sha="$(sha256sum "$PROJECT/stage4-dev/outputs/QA-affected-tests-v1.tsv" | awk '{print $1}')"
{
  printf '%s\n' '---' 'schema_version: 1' 'artifact_type: tdd-status' 'status: PASS' \
    "project: $(basename "$PROJECT")" 'scope: FR-001' "source_revision: $SOURCE" \
    'test_command: make test-completion' 'red_evidence: none' \
    'last_run: 2026-07-27T12:00:00Z' 'failed_tests: 0' 'repair_iteration: 0' \
    'regression_scope: full-affected' \
    'affected_test_manifest: stage4-dev/outputs/QA-affected-tests-v1.tsv' \
    "affected_test_manifest_sha256: $tdd_manifest_sha" 'expected_test_count: 1' \
    'executed_test_count: 1' '---' '' '# TDD Status'
} > "$PROJECT/stage4-dev/outputs/QA-TDD-status.md"
complete_artifact_metadata_fixture "$PROJECT/stage4-dev/outputs/QA-TDD-status.md" \
  "$PROJECT" QA-TDD-COMPLETION S4 s4-qa-auto "$SOURCE" PASS
{
  printf '%s\n' '---' 'schema_version: 1' 'artifact_type: techlead-review' \
    'product_profile_revision: 1' "source_revision: $SOURCE" 'status: PASS' '---' '' \
    '# Tech Lead Review' 'No open blockers.' 'APPROVED' '' '## Maintainability Review' \
    'Modularity: PASS' 'Reusability: PASS' 'Analysability: PASS' 'Modifiability: PASS' \
    'Testability: PASS' \
    'Maintainability rationale: exact source and all change dimensions were independently reviewed.' \
    'Maintainability evidence ids: EV-BUILD-S5,EV-SCA-COMPLETION'
} > "$PROJECT/stage4-dev/outputs/TL-2026-07-27-review-PR1.md"
complete_artifact_metadata_fixture "$PROJECT/stage4-dev/outputs/TL-2026-07-27-review-PR1.md" \
  "$PROJECT" TL-COMPLETION-PR1 S4 s4-techlead "$SOURCE" PASS
review_ref=stage4-dev/outputs/TL-2026-07-27-review-PR1.md
review_sha="$(sha256sum "$PROJECT/$review_ref" | awk '{print $1}')"
{
  printf '%s\n' 'schema_version: 1' 'approval_id: APPROVAL-DOD-COMPLETION' 'approval_origin: launcher-human-v1' \
    'approver_identity: s4-techlead' 'decision: APPROVE'
  printf 'scope: DOD-1,DOD-2,DOD-3,DOD-4,DOD-5,DOD-6,DOD-7,DOD-8,DOD-9,DOD-10,DOD-11;techlead-review:%s@%s\n' \
    "$review_ref" "$review_sha"
  printf '%s\n' 'rationale: independent review confirms every applicable full Software DoD item' \
    "source_revision: $SOURCE" "subject_digest: $subject" \
    "observed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml"

# Create the immutable 28-step plan first; current rows bind to this exact run/plan.
export XDG_STATE_HOME="${CYCLE1_COMPLETION_FIXTURE_STATE_DIR:-$TMP_DIR/state}"
journal_context="$(bash -c '
  source "$1"
  PROJECTS="$2"; PROJECT="$3"
  RUN_CYCLE=("${CYCLE1_AGENTS[@]}")
  RUN_OPTIONAL=(); EXECUTION_STEP_PROFILES=(); EXECUTION_STEP_SOURCES=()
  for _entry in "${RUN_CYCLE[@]}"; do
    RUN_OPTIONAL+=(0); EXECUTION_STEP_PROFILES+=("codex||||"); EXECUTION_STEP_SOURCES+=("single profile")
  done
  AGENT_RUNTIME=codex; BASE_PROFILE="codex||||"; SDLC_RUNTIME_ROUTING=single; SDLC_SUBAGENTS=off
  journal_create_run CYCLE "ТОЛЬКО Cycle 1" "Cycle 2/3 — FROZEN / NOT READY"
  read -r plan_sha _ < "$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/plan.sha256"
  printf "%s\t%s\n" "$CURRENT_RUN_ID" "$plan_sha"
' _ "$ROOT/sdlc.sh" "$PROJECTS_ROOT" "$PROJECT_NAME")"
IFS=$'\t' read -r EXECUTION_RUN_ID EXECUTION_PLAN_SHA <<< "$journal_context"
[[ "$EXECUTION_RUN_ID" =~ ^[A-Za-z0-9._-]+$ && "$EXECUTION_PLAN_SHA" =~ ^[0-9a-f]{64}$ ]] ||
  fail 'full Cycle journal context was not created'
sed -i "s#^scope: .*#&;execution-run:$EXECUTION_RUN_ID#" \
  "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml"
record_human_approval_receipt "$PROJECT" \
  "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml"

# Materialize one exact current member for every mandatory logical id. Existing domain
# artifacts are retained; missing non-domain outputs are harmless placeholders for plan proof.
CURRENT_REGISTRY="$ROOT/_contract/current-artifact-groups-v1.tsv"
CURRENT_MANIFEST="$PROJECT/tracking/current-artifacts-v1.tsv"
CURRENT_HEADER=$'schema_version\tlogical_id\tmember_index\tartifact_ref\tartifact_sha256\tproducer\tcommand\toutput_group\tsource_revision\tproduct_profile_revision\trun_id\tplan_sha256\trecorded_at'
current_data="$TMP_DIR/current-data.tsv"
: > "$current_data"
while IFS=$'\t' read -r producer command group logical patterns; do
  ref=''
  IFS='|' read -r -a alternatives <<< "$patterns"
  for pattern in "${alternatives[@]}"; do
    ref="$(find "$PROJECT" -type f -path "$PROJECT/$pattern" -printf '%P\n' -quit 2>/dev/null)"
    [[ -z "$ref" ]] || break
  done
  if [[ -z "$ref" ]]; then
    ref="${alternatives[0]//\*/2026-07-29}"
    mkdir -p "$(dirname "$PROJECT/$ref")"
    printf 'current fixture for %s\n' "$logical" > "$PROJECT/$ref"
  fi
  printf '1\t%s\t1\t%s\t%s\t%s\t%s\t%s\tnone\t1\t%s\t%s\t%s\n' \
    "$logical" "$ref" "$(sha256sum "$PROJECT/$ref" | awk '{print $1}')" \
    "$producer" "$command" "$group" "$EXECUTION_RUN_ID" "$EXECUTION_PLAN_SHA" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$current_data"
done < <(
  awk -F'\t' '
    FNR == NR { if (NR > 1) mandatory[$2 SUBSEP $3]=1; next }
    FNR > 1 && $6 == "yes" && (($1 SUBSEP $2) in mandatory) && !seen[$4]++ {
      print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $7
    }
  ' "$ROOT/_contract/cycle1-steps-v1.tsv" "$CURRENT_REGISTRY"
)
{ printf '%s\n' "$CURRENT_HEADER"; sort -t $'\t' -k2,2 -k3,3n "$current_data"; } > "$CURRENT_MANIFEST"
bash "$ROOT/cycle1-dev/s0-validate/current-artifact.sh" validate "$PROJECT" >/dev/null ||
  fail 'full-cycle current artifact manifest fixture invalid'
bash "$ROOT/cycle1-dev/s0-validate/current-artifact.sh" update "$PROJECT" \
  launcher /full-dod-approval "$EXECUTION_RUN_ID" "$EXECUTION_PLAN_SHA" \
  tracking/approvals/APPROVAL-DOD-COMPLETION.yaml >/dev/null ||
  fail 'launcher-owned full DoD approval was not recorded as current'
current_manifest_sha="$(sha256sum "$CURRENT_MANIFEST" | awk '{print $1}')"
{
  printf '%s\n' \
    'schema_version: 2' \
    'completion_id: C1-2026-07-27-001' \
    'status: VALIDATED' \
    "project: $PROJECT_NAME" \
    'gate5_owner: s5-qa' \
    'completion_owner: s0-tracker' \
    "source_revision: $SOURCE" \
    'subject_kind: build-artifact' \
    "subject_digest: $subject" \
    "build_identity: $build" \
    'product_profile_revision: 1' \
    "execution_run_id: $EXECUTION_RUN_ID" \
    "execution_plan_sha256: $EXECUTION_PLAN_SHA" \
    'current_artifact_manifest_ref: tracking/current-artifacts-v1.tsv' \
    "current_artifact_manifest_sha256: $current_manifest_sha" \
    'full_dod_approval_ref: tracking/approvals/APPROVAL-DOD-COMPLETION.yaml' \
    "validated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "evidence_fresh_until: $fresh_until" \
    'evidence_bundle_uri: tracking/completion/CYCLE1-evidence-bundle-v1.tsv' \
    "evidence_bundle_sha256: $bundle_sha" \
    'verified_evidence_ids: EV-BUILD-S5,EV-SCA-COMPLETION' \
    'unverified_evidence_refs: none' \
    "build_evidence_ref: $record_uri" \
    "gate5_decision_ref: $go_ref" \
    "gate5_decision_sha256: $go_sha" \
    'validation_index_ref: tracking/validation/S5-validation-v1.tsv' \
    "validation_index_sha256: $index_sha" \
    'defect_index_ref: stage5-testing/outputs/DEF-defects-v1.tsv' \
    "defect_index_sha256: $defect_sha" \
    'uat_approval_ref: tracking/approvals/APPROVAL-UAT-001.yaml' \
    'risk_exception_refs: tracking/risk-exceptions/RISK-PERF-P95.yaml,tracking/risk-exceptions/RISK-SG3-SCA.yaml' \
    'known_limitation_ids: none' \
    "artifact_digest: $subject" \
    'sbom_evidence_ref: none' \
    'provenance_evidence_ref: none' \
    'release_notes_status: not-requested' \
    'release_notes_ref: none' \
    'external_publication_status: not-performed' \
    'release_build_status: not-performed' \
    'deploy_status: not-performed' \
    'production_action_status: not-performed' \
    'cycle23_status: FROZEN_NOT_READY' \
    'client_next_action: s0-tracker:/release-notes'
} > "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

# Append launcher-owned events in the same boundary order as production, then seal the prefix.
bash -c '
  source "$1"
  PROJECTS="$2"; PROJECT="$3"; CURRENT_RUN_ID="$4"
  step=0
  for entry in "${CYCLE1_AGENTS[@]}"; do
    step=$((step + 1)); agent="${entry%%:*}"; task="${entry#*:}"
    gate="$(cycle1_gate_before_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" ]] || journal_append_event "$CURRENT_RUN_ID" gate_pass RUNNING "$step" GATE_PASS "" "Gate $gate" "fixture gate $gate verified"
    journal_append_event "$CURRENT_RUN_ID" step_started RUNNING "$step" RUNNING "$agent" "$task" "dispatch requested"
    journal_append_event "$CURRENT_RUN_ID" step_process_ok RUNNING "$step" PROCESS_OK "$agent" "$task" "runtime exit code 0"
    journal_append_event "$CURRENT_RUN_ID" step_artifact_verified RUNNING "$step" ARTIFACT_VERIFIED "$agent" "$task" "current artifact groups verified"
    if cycle1_software_dod_after_entry "$agent" "$task"; then
      journal_append_event "$CURRENT_RUN_ID" software_dod_auto_pass RUNNING "$step" DOD_AUTO_PASS "$agent" "$task" "automated subset"
      journal_append_event "$CURRENT_RUN_ID" software_dod_approved RUNNING "$step" DOD_PASS "$agent" "$task" "independent full approval"
    fi
    gate="$(cycle1_gate_after_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" ]] || journal_append_event "$CURRENT_RUN_ID" gate_pass RUNNING "$step" GATE_PASS "" "Gate $gate" "fixture gate $gate verified"
  done
' _ "$ROOT/sdlc.sh" "$PROJECTS_ROOT" "$PROJECT_NAME" "$EXECUTION_RUN_ID"
bash "$ROOT/cycle1-dev/s0-validate/cycle1-execution-proof-check.sh" \
  create "$PROJECT" "$EXECUTION_RUN_ID" >/dev/null || fail 'valid full execution proof was rejected'

bash "$CHECK" "$PROJECT" >"$TMP_DIR/valid.out" || fail 'valid completion manifest was rejected'
grep -Fq 'CYCLE 1 COMPLETION VERIFIED' "$TMP_DIR/valid.out" || fail 'verified completion verdict missing'

# A second-cycle history can coexist: only manifest-selected current artifacts affect verdict.
cp "$PROJECT/stage5-testing/outputs/AUTO-2026-07-27-e2e-report.md" \
  "$PROJECT/stage5-testing/outputs/AUTO-2026-07-26-e2e-report.md"
cp "$PROJECT/stage5-testing/outputs/AUTO-2026-07-27-coverage.md" \
  "$PROJECT/stage5-testing/outputs/AUTO-2026-07-26-coverage.md"
cp "$PROJECT/stage5-testing/outputs/PERF-2026-07-27-report.md" \
  "$PROJECT/stage5-testing/outputs/PERF-2026-07-26-report.md"
cp "$PROJECT/stage5-testing/outputs/SEC-2026-07-27-pentest-report.md" \
  "$PROJECT/stage5-testing/outputs/SEC-2026-07-26-pentest-report.md"
cp "$PROJECT/stage5-testing/outputs/QA-2026-07-27-test-analysis.md" \
  "$PROJECT/stage5-testing/outputs/QA-2026-07-26-test-analysis.md"
cp "$PROJECT/stage5-testing/outputs/QA-2026-07-27-go-no-go.md" \
  "$PROJECT/stage5-testing/outputs/QA-2026-07-26-go-no-go.md"
for historical_report in "$PROJECT"/stage5-testing/outputs/*-2026-07-26-*; do
  sed -i -e 's/2026-07-27/2026-07-26/g' -e 's/20260727/20260726/g' \
    "$historical_report"
done
bash "$CHECK" "$PROJECT" >/dev/null ||
  fail 'historical reports from a prior cycle conflicted with manifest-selected current set'

# A Retry is a linked child suffix, not a new unrelated partial Cycle. Completion must combine
# the exact verified root prefix with the child suffix while keeping every current row bound to
# one of those immutable plans.
cp "$CURRENT_MANIFEST" "$TMP_DIR/current.single-run"
cp "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml" "$TMP_DIR/completion.single-run"
retry_context="$(bash -c '
  source "$1"
  PROJECTS="$2"; PROJECT="$3"
  AGENT_RUNTIME=codex; BASE_PROFILE="codex||||"; SDLC_RUNTIME_ROUTING=single; SDLC_SUBAGENTS=off
  RUN_CYCLE=("${CYCLE1_AGENTS[@]}")
  RUN_OPTIONAL=(); EXECUTION_STEP_PROFILES=(); EXECUTION_STEP_SOURCES=()
  for _entry in "${RUN_CYCLE[@]}"; do
    RUN_OPTIONAL+=(0); EXECUTION_STEP_PROFILES+=("codex||||"); EXECUTION_STEP_SOURCES+=("single profile")
  done
  journal_create_run CYCLE "ТОЛЬКО Cycle 1" "Cycle 2/3 — FROZEN / NOT READY"
  parent="$CURRENT_RUN_ID"
  read -r parent_sha _ < "$(journal_run_dir "$PROJECT" "$parent")/plan.sha256"
  for ((canonical=1; canonical<=13; canonical++)); do
    entry="${CYCLE1_AGENTS[$((canonical - 1))]}"; agent="${entry%%:*}"; task="${entry#*:}"
    gate="$(cycle1_gate_before_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" ]] || journal_append_event "$parent" gate_pass RUNNING "$canonical" GATE_PASS "" "Gate $gate" "retry fixture gate $gate"
    journal_append_event "$parent" step_started RUNNING "$canonical" RUNNING "$agent" "$task" "dispatch requested"
    journal_append_event "$parent" step_process_ok RUNNING "$canonical" PROCESS_OK "$agent" "$task" "runtime exit code 0"
    journal_append_event "$parent" step_artifact_verified RUNNING "$canonical" ARTIFACT_VERIFIED "$agent" "$task" "root prefix verified"
  done
  failed_entry="${CYCLE1_AGENTS[13]}"; failed_agent="${failed_entry%%:*}"; failed_task="${failed_entry#*:}"
  journal_append_event "$parent" step_started RUNNING 14 RUNNING "$failed_agent" "$failed_task" "dispatch requested"
  journal_append_event "$parent" step_failed BLOCKED 14 FAILED "$failed_agent" "$failed_task" "fixture interruption"
  journal_write_state "$parent" BLOCKED 14 28 FAILED "$failed_agent $failed_task"

  PARENT_RUN_ID="$parent"
  RUN_CYCLE=("${CYCLE1_AGENTS[@]:13}")
  RUN_OPTIONAL=(); EXECUTION_STEP_PROFILES=(); EXECUTION_STEP_SOURCES=()
  for _entry in "${RUN_CYCLE[@]}"; do
    RUN_OPTIONAL+=(0); EXECUTION_STEP_PROFILES+=("codex||||"); EXECUTION_STEP_SOURCES+=("single profile")
  done
  USE_EXISTING_FROZEN_ROUTES=1
  journal_create_run RESUME "child retry from canonical step 14" "verified root steps 1-13"
  child="$CURRENT_RUN_ID"
  read -r child_sha _ < "$(journal_run_dir "$PROJECT" "$child")/plan.sha256"
  journal_append_event "$parent" retry_child_created INTERRUPTED 0 UNKNOWN "" "" "child run $child"
  local_step=0
  for ((canonical=14; canonical<=28; canonical++)); do
    local_step=$((local_step + 1))
    entry="${CYCLE1_AGENTS[$((canonical - 1))]}"; agent="${entry%%:*}"; task="${entry#*:}"
    gate="$(cycle1_gate_before_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" ]] || journal_append_event "$child" gate_pass RUNNING "$local_step" GATE_PASS "" "Gate $gate" "retry fixture gate $gate"
    journal_append_event "$child" step_started RUNNING "$local_step" RUNNING "$agent" "$task" "dispatch requested"
    journal_append_event "$child" step_process_ok RUNNING "$local_step" PROCESS_OK "$agent" "$task" "runtime exit code 0"
    journal_append_event "$child" step_artifact_verified RUNNING "$local_step" ARTIFACT_VERIFIED "$agent" "$task" "child suffix verified"
    if cycle1_software_dod_after_entry "$agent" "$task"; then
      journal_append_event "$child" software_dod_auto_pass RUNNING "$local_step" DOD_AUTO_PASS "$agent" "$task" "automated subset"
      journal_append_event "$child" software_dod_approved RUNNING "$local_step" DOD_PASS "$agent" "$task" "independent full approval"
    fi
    gate="$(cycle1_gate_after_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" ]] || journal_append_event "$child" gate_pass RUNNING "$local_step" GATE_PASS "" "Gate $gate" "retry fixture gate $gate"
  done
  printf "%s\t%s\t%s\t%s\n" "$parent" "$child" "$parent_sha" "$child_sha"
' _ "$ROOT/sdlc.sh" "$PROJECTS_ROOT" "$PROJECT_NAME")"
IFS=$'\t' read -r RETRY_PARENT RETRY_CHILD RETRY_ROOT_SHA RETRY_CHILD_SHA <<< "$retry_context"
[[ "$RETRY_PARENT" =~ ^[A-Za-z0-9._-]+$ && "$RETRY_CHILD" =~ ^[A-Za-z0-9._-]+$ &&
   "$RETRY_ROOT_SHA" =~ ^[0-9a-f]{64}$ && "$RETRY_CHILD_SHA" =~ ^[0-9a-f]{64}$ ]] ||
  fail 'root/Retry Journal chain fixture was not created'

retry_approval_ref=tracking/approvals/APPROVAL-DOD-RETRY.yaml
cp "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml" \
  "$PROJECT/$retry_approval_ref"
sed -i \
  -e 's/^approval_id: .*/approval_id: APPROVAL-DOD-RETRY/' \
  -e "s/;execution-run:[A-Za-z0-9._-]*$/;execution-run:$RETRY_CHILD/" \
  "$PROJECT/$retry_approval_ref"
record_human_approval_receipt "$PROJECT" "$PROJECT/$retry_approval_ref"
retry_approval_sha="$(sha256sum "$PROJECT/$retry_approval_ref" | awk '{print $1}')"

awk -F'\t' -v OFS='\t' -v parent="$RETRY_PARENT" -v child="$RETRY_CHILD" \
  -v parent_sha="$RETRY_ROOT_SHA" -v child_sha="$RETRY_CHILD_SHA" \
  -v approval_ref="$retry_approval_ref" -v approval_sha="$retry_approval_sha" '
  FNR == NR { if (NR > 1) canonical[$2 SUBSEP $3]=$1; next }
  FNR == 1 { print; next }
  {
    if ($6 == "launcher" && $7 == "/full-dod-approval") {
      $4=approval_ref; $5=approval_sha; $11=child; $12=child_sha
      print
      next
    }
    step=canonical[$6 SUBSEP $7]
    if (step == "") exit 2
    if (step <= 13) { $11=parent; $12=parent_sha }
    else { $11=child; $12=child_sha }
    print
  }
' "$ROOT/_contract/cycle1-steps-v1.tsv" "$TMP_DIR/current.single-run" > "$CURRENT_MANIFEST" ||
  fail 'could not bind current artifacts to the root/Retry plans'
bash "$ROOT/cycle1-dev/s0-validate/current-artifact.sh" validate "$PROJECT" >/dev/null ||
  fail 'root/Retry current manifest is structurally invalid'
retry_current_sha="$(sha256sum "$CURRENT_MANIFEST" | awk '{print $1}')"
cp "$TMP_DIR/completion.single-run" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
sed -i \
  -e "s/^execution_run_id:.*/execution_run_id: $RETRY_CHILD/" \
  -e "s/^execution_plan_sha256:.*/execution_plan_sha256: $RETRY_ROOT_SHA/" \
  -e "s/^current_artifact_manifest_sha256:.*/current_artifact_manifest_sha256: $retry_current_sha/" \
  -e "s#^full_dod_approval_ref:.*#full_dod_approval_ref: $retry_approval_ref#" \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
bash "$ROOT/cycle1-dev/s0-validate/cycle1-execution-proof-check.sh" \
  create "$PROJECT" "$RETRY_CHILD" >/dev/null || fail 'valid root/Retry execution proof was rejected'
bash "$CHECK" "$PROJECT" > "$TMP_DIR/retry-valid.out" ||
  fail 'Completion rejected a valid root/Retry chain'
grep -Fq 'CYCLE 1 COMPLETION VERIFIED' "$TMP_DIR/retry-valid.out" ||
  fail 'root/Retry completion verdict missing'

retry_parent_events="$XDG_STATE_HOME/sdlc-agents/execution-journal/projects/$PROJECT_NAME-$(printf '%s' "$PROJECT" | sha256sum | awk '{print substr($1,1,16)}')/runs/$RETRY_PARENT/events.jsonl"
cp "$retry_parent_events" "$TMP_DIR/retry-parent-events.valid"
sed -i '/"event":"retry_child_created"/d' "$retry_parent_events"
if bash "$ROOT/cycle1-dev/s0-validate/cycle1-execution-proof-check.sh" \
  create "$PROJECT" "$RETRY_CHILD" >/dev/null 2>&1; then
  fail 'execution proof accepted a missing/tampered parent→Retry link'
fi
cp "$TMP_DIR/retry-parent-events.valid" "$retry_parent_events"

cp "$CURRENT_MANIFEST" "$TMP_DIR/current.retry-valid"
awk -F'\t' -v OFS='\t' 'NR == 2 {$11="UNRELATED-RUN"} {print}' \
  "$TMP_DIR/current.retry-valid" > "$CURRENT_MANIFEST"
if bash "$ROOT/cycle1-dev/s0-validate/cycle1-execution-proof-check.sh" \
  create "$PROJECT" "$RETRY_CHILD" >/dev/null 2>&1; then
  fail 'execution proof accepted a current artifact from an unrelated run'
fi

cp "$TMP_DIR/current.single-run" "$CURRENT_MANIFEST"
cp "$TMP_DIR/completion.single-run" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

cp "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml" "$TMP_DIR/manifest.valid"

project_key="$(printf '%s' "$PROJECT" | sha256sum | awk '{print substr($1,1,16)}')"
events="$XDG_STATE_HOME/sdlc-agents/execution-journal/projects/$(basename "$PROJECT")-$project_key/runs/$EXECUTION_RUN_ID/events.jsonl"
cp "$events" "$TMP_DIR/events.valid"
sed -i '/"event":"gate_pass".*"task":"Gate 4"/d' "$events"
expect_blocked 'completion accepted a missing Gate 4 event/invalid Journal chain' "$TMP_DIR/gate4-event.out"
cp "$TMP_DIR/events.valid" "$events"

cp "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml" "$TMP_DIR/dod-approval.valid"
sed -i 's/,DOD-11;techlead/;techlead/' \
  "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml"
expect_blocked 'completion accepted full DoD approval omitting DOD-11' "$TMP_DIR/dod-item.out"
cp "$TMP_DIR/dod-approval.valid" "$PROJECT/tracking/approvals/APPROVAL-DOD-COMPLETION.yaml"

cp "$CURRENT_MANIFEST" "$TMP_DIR/current-manifest.valid"
printf '\n' >> "$CURRENT_MANIFEST"
expect_blocked 'completion accepted current artifact manifest digest drift' "$TMP_DIR/current-manifest.out"
cp "$TMP_DIR/current-manifest.valid" "$CURRENT_MANIFEST"

sed -i 's/^execution_plan_sha256:.*/execution_plan_sha256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
expect_blocked 'completion accepted a different immutable execution plan' "$TMP_DIR/plan.out"
cp "$TMP_DIR/manifest.valid" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

sed -i 's#risk_exception_refs: .*#risk_exception_refs: tracking/risk-exceptions/RISK-PERF-P95.yaml#' \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
expect_blocked 'completion omitted an active SG3 Risk Exception' "$TMP_DIR/risk-sg3-omitted.out"
cp "$TMP_DIR/manifest.valid" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

sed -i 's#risk_exception_refs: .*#risk_exception_refs: tracking/risk-exceptions/RISK-SG3-SCA.yaml#' \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
expect_blocked 'completion omitted an active S5 Risk Exception' "$TMP_DIR/risk-s5-omitted.out"
cp "$TMP_DIR/manifest.valid" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

cp "$PROJECT/tracking/risk-exceptions/RISK-SG3-SCA.yaml" "$TMP_DIR/risk.valid"
sed -i 's/finding_ids: CVE-COMPLETION-MEDIUM/finding_ids: CVE-OTHER/' \
  "$PROJECT/tracking/risk-exceptions/RISK-SG3-SCA.yaml"
expect_blocked 'completion accepted a tampered SG3 Risk Exception scope' "$TMP_DIR/risk-tampered.out"
cp "$TMP_DIR/risk.valid" "$PROJECT/tracking/risk-exceptions/RISK-SG3-SCA.yaml"

sed -i 's/external_publication_status: not-performed/external_publication_status: performed/' \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
expect_blocked 'completion accepted an external publication action' "$TMP_DIR/push.out"
cp "$TMP_DIR/manifest.valid" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

sed -i "s/source_revision: $SOURCE/source_revision: 6666666666666666666666666666666666666666/" \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
expect_blocked 'completion accepted a different source revision' "$TMP_DIR/source.out"
cp "$TMP_DIR/manifest.valid" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

first="${bundle_sha:0:1}"
if [[ "$first" == 0 ]]; then tampered="1${bundle_sha:1}"; else tampered="0${bundle_sha:1}"; fi
sed -i "s/^evidence_bundle_sha256:.*/evidence_bundle_sha256: $tampered/" \
  "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"
[[ "$(field "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml" evidence_bundle_sha256)" != "$bundle_sha" ]] || \
  fail 'digest mutation fixture did not change the digest'
expect_blocked 'completion accepted a tampered evidence bundle digest' "$TMP_DIR/digest.out"
cp "$TMP_DIR/manifest.valid" "$PROJECT/tracking/completion/CYCLE1-completion-v2.yaml"

XDG_CONFIG_HOME="$TMP_DIR/config" bash -c '
  source "$1"
  cycle1_completion_after_entry s0-tracker /report
  cycle1_declared_output_groups s0-tracker /report | grep -Fq tracking/completion/CYCLE1-completion-v2.yaml
  declare -F run_cycle1_completion_validator >/dev/null
' _ "$ROOT/sdlc.sh" || fail 'launcher does not fail-close the final completion step'

echo 'PASS: Cycle 1 Completion v2 smoke'

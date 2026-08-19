#!/usr/bin/env bash

set -euo pipefail

PROJECT_INPUT="${1:?Укажи абсолютный путь к Project}"
blocked() { echo "CYCLE 1 COMPLETION BLOCKED: $*" >&2; exit 1; }

[[ -d "$PROJECT_INPUT" ]] || blocked "Project не найден: $PROJECT_INPUT"
PROJECT_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MANIFEST="$PROJECT_PATH/tracking/completion/CYCLE1-completion-v2.yaml"
BUNDLE="$PROJECT_PATH/tracking/completion/CYCLE1-evidence-bundle-v1.tsv"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"
S5_INDEX="$PROJECT_PATH/tracking/validation/S5-validation-v1.tsv"
DEFECT_INDEX="$PROJECT_PATH/stage5-testing/outputs/DEF-defects-v1.tsv"
SUMMARY="$PROJECT_PATH/tracking/cycle-summary.md"
CURRENT_MANIFEST="$PROJECT_PATH/tracking/current-artifacts-v1.tsv"
CURRENT_TOOL="$SCRIPT_DIR/current-artifact.sh"
EXECUTION_PROOF_CHECK="$SCRIPT_DIR/cycle1-execution-proof-check.sh"

field() {
  local file="$1" wanted="$2"
  awk -F: -v wanted="$wanted" '$1 == wanted { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$file"
}

safe_ref() {
  local ref="$1" path canonical
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ && "$ref" != /* && "$ref" != *'/../'* && "$ref" != ../* && "$ref" != */.. ]] ||
    blocked "unsafe reference: $ref"
  path="$PROJECT_PATH/$ref"
  [[ -f "$path" && ! -L "$path" ]] || blocked "reference missing/symlink: $ref"
  canonical="$(readlink -f "$path")"
  [[ "$canonical" == "$PROJECT_PATH/"* ]] || blocked "reference escapes Project: $ref"
  printf '%s\n' "$path"
}

security_medium_ids_for_record() {
  local record="$1" raw_format raw_path
  raw_format="$(field "$record" raw_format)"
  raw_path="$PROJECT_PATH/$(field "$record" raw_result_uri)"
  case "$raw_format" in
    json)
      jq -e '(.findings | type == "array") and all(.findings[];
        (.id | type == "string" and length > 0) and (.cvss | type == "number") and
        .cvss >= 0 and .cvss <= 10 and (.status == "open" or .status == "fixed"))' \
        "$raw_path" >/dev/null || blocked 'SG3 JSON findings invalid during completion'
      jq -r '[.findings[] | select(.status == "open" and .cvss >= 4.0 and .cvss < 7.0) | .id] | join(",")' \
        "$raw_path"
      ;;
    sarif)
      jq -e '.version == "2.1.0" and (.runs | type == "array") and
        all(.runs[] | (.results // [])[];
          ((.properties["security-severity"] // .properties.cvss // .properties["cvss"]) |
          tonumber? // -1) >= 0)' "$raw_path" >/dev/null ||
        blocked 'SG3 SARIF findings invalid during completion'
      jq -r '[.runs[] | (.results // [])[] |
        {id:(.ruleId // "unknown-rule"), score:((.properties["security-severity"] //
        .properties.cvss // .properties["cvss"]) | tonumber)} |
        select(.score >= 4.0 and .score < 7.0) | .id] | join(",")' "$raw_path"
      ;;
    *) blocked 'SG3 security evidence requires JSON or SARIF during completion' ;;
  esac
}

[[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] || blocked 'completion manifest отсутствует или symlink'
[[ -f "$BUNDLE" && ! -L "$BUNDLE" ]] || blocked 'evidence bundle отсутствует или symlink'
[[ -f "$SUMMARY" && ! -L "$SUMMARY" ]] || blocked 'cycle-summary.md отсутствует или symlink'
bash "$SCRIPT_DIR/artifact-metadata-check.sh" "$PROJECT_PATH" 'tracking/cycle-summary.md' >/dev/null ||
  blocked 'cycle-summary.md common Artifact Metadata invalid'

expected_keys='schema_version completion_id status project gate5_owner completion_owner source_revision subject_kind subject_digest build_identity product_profile_revision execution_run_id execution_plan_sha256 current_artifact_manifest_ref current_artifact_manifest_sha256 full_dod_approval_ref validated_at evidence_fresh_until evidence_bundle_uri evidence_bundle_sha256 verified_evidence_ids unverified_evidence_refs build_evidence_ref gate5_decision_ref gate5_decision_sha256 validation_index_ref validation_index_sha256 defect_index_ref defect_index_sha256 uat_approval_ref risk_exception_refs known_limitation_ids artifact_digest sbom_evidence_ref provenance_evidence_ref release_notes_status release_notes_ref external_publication_status release_build_status deploy_status production_action_status cycle23_status client_next_action'
actual_keys="$(awk -F: 'NF >= 2 {print $1}' "$MANIFEST" | tr '\n' ' ' | sed 's/ $//')"
[[ "$actual_keys" == "$expected_keys" ]] || blocked 'manifest fields/order mismatch'

[[ "$(field "$MANIFEST" schema_version)" == 2 ]] || blocked 'schema_version must be 2'
[[ "$(field "$MANIFEST" completion_id)" =~ ^C1-[A-Za-z0-9._-]+$ ]] || blocked 'invalid completion_id'
[[ "$(field "$MANIFEST" status)" == VALIDATED ]] || blocked 'status must be VALIDATED'
[[ "$(field "$MANIFEST" project)" == "$(basename "$PROJECT_PATH")" ]] || blocked 'project mismatch'
[[ "$(field "$MANIFEST" gate5_owner)" == s5-qa ]] || blocked 'Gate 5 owner must be s5-qa'
[[ "$(field "$MANIFEST" completion_owner)" == s0-tracker ]] || blocked 'completion owner must be s0-tracker'

source_revision="$(field "$MANIFEST" source_revision)"
[[ "$source_revision" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]] || blocked 'invalid source revision'
bash "$SCRIPT_DIR/s5-validation-check.sh" "$PROJECT_PATH" "$source_revision" >/dev/null ||
  blocked 'S5 Validation v1 is not verified for completion source'

profile_revision="$(field "$PROFILE" revision)"
[[ "$(field "$MANIFEST" product_profile_revision)" == "$profile_revision" ]] || blocked 'Product Profile revision mismatch'
execution_run_id="$(field "$MANIFEST" execution_run_id)"
[[ "$execution_run_id" =~ ^[A-Za-z0-9._-]+$ ]] || blocked 'invalid execution_run_id'
proof_output="$(bash "$EXECUTION_PROOF_CHECK" validate "$PROJECT_PATH" "$execution_run_id" 2>&1)" || {
  printf '%s\n' "$proof_output" >&2
  blocked 'full Cycle 1 execution proof invalid'
}
project_key="$(printf '%s' "$PROJECT_PATH" | sha256sum | awk '{print substr($1,1,16)}')"
journal_base="${SDLC_JOURNAL_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/sdlc-agents/execution-journal}"
execution_run_dir="$journal_base/projects/$(basename "$PROJECT_PATH")-$project_key/runs/$execution_run_id"
execution_proof="$execution_run_dir/cycle1-completion-proof-v2.yaml"
[[ -f "$execution_proof" && ! -L "$execution_proof" ]] ||
  blocked 'launcher-owned execution proof unavailable'
run_chain="$(field "$execution_proof" run_chain)"
[[ "$run_chain" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]] ||
  blocked 'execution proof run chain invalid'
execution_plan_sha="$(field "$execution_proof" root_plan_sha256)"
[[ "$(field "$MANIFEST" execution_plan_sha256)" == "$execution_plan_sha" ]] ||
  blocked 'root execution plan digest mismatch'
[[ "$(field "$MANIFEST" current_artifact_manifest_ref)" == tracking/current-artifacts-v1.tsv ]] ||
  blocked 'current artifact manifest ref mismatch'
[[ -f "$CURRENT_MANIFEST" && ! -L "$CURRENT_MANIFEST" ]] || blocked 'current artifact manifest missing/symlink'
[[ "$(field "$MANIFEST" current_artifact_manifest_sha256)" == "$(sha256sum "$CURRENT_MANIFEST" | awk '{print $1}')" ]] ||
  blocked 'current artifact manifest digest mismatch'
current_dod_ref="$(bash "$CURRENT_TOOL" resolve-one "$PROJECT_PATH" dod-approval \
  "$run_chain" "$source_revision")" || blocked 'current full DoD approval unavailable'
[[ "$(field "$MANIFEST" full_dod_approval_ref)" == "$current_dod_ref" ]] ||
  blocked 'full DoD approval ref mismatch'
[[ "$(field "$MANIFEST" validated_at)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  blocked 'validated_at must be UTC ISO-8601'
fresh_until="$(field "$MANIFEST" evidence_fresh_until)"
[[ "$fresh_until" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  blocked 'evidence_fresh_until must be UTC ISO-8601'
(( $(date -u -d "$fresh_until" +%s) >= $(date -u +%s) )) || blocked 'completion evidence is stale'

[[ "$(field "$MANIFEST" evidence_bundle_uri)" == tracking/completion/CYCLE1-evidence-bundle-v1.tsv ]] ||
  blocked 'wrong evidence bundle uri'
[[ "$(field "$MANIFEST" evidence_bundle_sha256)" == "$(sha256sum "$BUNDLE" | awk '{print $1}')" ]] ||
  blocked 'evidence bundle digest mismatch'
[[ "$(head -1 "$BUNDLE")" == $'evidence_id\tcheck_id\tverdict\trecord_uri\trecord_sha256\tobserved_at\tfreshness_seconds\tsubject_digest\tbuild_identity' ]] ||
  blocked 'evidence bundle header mismatch'

declare -A bundle_ids=() bundle_records=()
bundle_id_list=()
bundle_risk_refs=()
bundle_min_expiry=''
while IFS=$'\t' read -r evidence_id check_id verdict record_uri record_sha observed freshness subject build extra; do
  [[ -z "$extra" && "$evidence_id" =~ ^EV-[A-Za-z0-9._-]+$ ]] || blocked 'invalid evidence bundle row'
  [[ -z "${bundle_ids[$evidence_id]+x}" ]] || blocked "duplicate evidence_id: $evidence_id"
  [[ "$verdict" == PASS || "$verdict" == NOT_APPLICABLE ]] || blocked "unverified verdict in bundle: $verdict"
  record="$(safe_ref "$record_uri")"
  [[ "$record_sha" =~ ^[0-9a-f]{64}$ && "$record_sha" == "$(sha256sum "$record" | awk '{print $1}')" ]] ||
    blocked "record digest mismatch: $record_uri"
  bash "$SCRIPT_DIR/evidence-v1-check.sh" "$PROJECT_PATH" "$record" \
    --expected-source "$source_revision" --expected-check "$check_id" >/dev/null ||
    blocked "Evidence v1 record invalid: $record_uri"
  record_risk_ref="$(field "$record" risk_exception_ref)"
  case "$check_id" in
    sast|sca|image-scan)
      medium_ids="$(security_medium_ids_for_record "$record")"
      if [[ -n "$medium_ids" ]]; then
        [[ "$record_risk_ref" != none ]] ||
          blocked "SG3 Medium findings omitted Risk Exception: $check_id:$medium_ids"
        bash "$SCRIPT_DIR/risk-exception-check.sh" "$PROJECT_PATH" "$record_risk_ref" \
          "$check_id" "$source_revision" "$(field "$record" subject_digest)" \
          "$(field "$record" producer_identity)" "$medium_ids" security >/dev/null ||
          blocked "SG3 Risk Exception invalid during completion: $record_risk_ref"
        bundle_risk_refs+=("$record_risk_ref")
      else
        [[ "$record_risk_ref" == none ]] ||
          blocked "Evidence record has Risk Exception without open Medium findings: $record_uri"
      fi
      ;;
    *)
      [[ "$record_risk_ref" == none ]] ||
        blocked "unsupported Risk Exception on check=$check_id"
      ;;
  esac
  [[ "$(field "$record" evidence_id)" == "$evidence_id" &&
      "$(field "$record" verdict)" == "$verdict" &&
      "$(field "$record" observed_at)" == "$observed" &&
      "$(field "$record" freshness_seconds)" == "$freshness" &&
      "$(field "$record" subject_digest)" == "$subject" &&
      "$(field "$record" build_identity)" == "$build" ]] || blocked "bundle metadata mismatch: $evidence_id"
  expiry="$(date -u -d "$observed + $freshness seconds" +%Y-%m-%dT%H:%M:%SZ)"
  [[ -z "$bundle_min_expiry" || "$(date -u -d "$expiry" +%s)" -lt "$(date -u -d "$bundle_min_expiry" +%s)" ]] &&
    bundle_min_expiry="$expiry"
  bundle_ids["$evidence_id"]=1
  bundle_records["$check_id"]="$record_uri"
  bundle_id_list+=("$evidence_id")
done < <(tail -n +2 "$BUNDLE")
(( ${#bundle_id_list[@]} > 0 )) || blocked 'evidence bundle is empty'
mapfile -t actual_records < <(find "$PROJECT_PATH/tracking/evidence/v1" -maxdepth 1 -type f -name '*.yaml' -print | sort)
current_record_count=0
for record in "${actual_records[@]}"; do
  [[ "$(field "$record" source_revision)" == "$source_revision" ]] || continue
  ((current_record_count+=1))
  [[ -n "${bundle_ids[$(field "$record" evidence_id)]:-}" ]] || blocked "current source evidence omitted: ${record#"$PROJECT_PATH/"}"
done
(( current_record_count == ${#bundle_id_list[@]} )) || blocked 'bundle contains non-current or duplicate evidence'
IFS=$'\n' sorted_ids=($(printf '%s\n' "${bundle_id_list[@]}" | sort)); unset IFS
verified_ids="$(IFS=,; echo "${sorted_ids[*]}")"
[[ "$(field "$MANIFEST" verified_evidence_ids)" == "$verified_ids" ]] || blocked 'verified_evidence_ids mismatch'
[[ "$fresh_until" == "$bundle_min_expiry" ]] || blocked 'evidence_fresh_until mismatch'

build_ref="$(field "$MANIFEST" build_evidence_ref)"
build_record="$(safe_ref "$build_ref")"
[[ "$(field "$build_record" check_id)" == build ]] || blocked 'build_evidence_ref is not build evidence'
subject_kind="$(field "$build_record" subject_kind)"
subject_digest="$(field "$build_record" subject_digest)"
build_identity="$(field "$build_record" build_identity)"
[[ "$(field "$MANIFEST" subject_kind)" == "$subject_kind" &&
    "$(field "$MANIFEST" subject_digest)" == "$subject_digest" &&
    "$(field "$MANIFEST" build_identity)" == "$build_identity" ]] || blocked 'validated build contract mismatch'
if [[ "$subject_kind" == source ]]; then
  [[ "$(field "$MANIFEST" artifact_digest)" == none &&
      "$(field "$MANIFEST" sbom_evidence_ref)" == none &&
      "$(field "$MANIFEST" provenance_evidence_ref)" == none ]] || blocked 'source-only completion invented artifact evidence'
else
  [[ "$(field "$MANIFEST" artifact_digest)" == "$subject_digest" ]] || blocked 'artifact digest not copied from verified build evidence'
fi
sbom_ref="$(field "$MANIFEST" sbom_evidence_ref)"
if [[ "$sbom_ref" != none ]]; then
  [[ "${bundle_records[sbom]:-}" == "$sbom_ref" ]] || blocked 'SBOM ref is not verified bundle evidence'
fi
[[ "$(field "$MANIFEST" provenance_evidence_ref)" == none ]] ||
  blocked 'provenance ref unsupported until a verified provenance check exists'

for binding in \
  'gate5_decision_ref|gate5_decision_sha256|stage5-testing/outputs/QA-' \
  'validation_index_ref|validation_index_sha256|tracking/validation/S5-validation-v1.tsv' \
  'defect_index_ref|defect_index_sha256|stage5-testing/outputs/DEF-defects-v1.tsv'; do
  IFS='|' read -r ref_key sha_key required_prefix <<< "$binding"
  ref="$(field "$MANIFEST" "$ref_key")"
  [[ "$ref" == "$required_prefix"* ]] || blocked "$ref_key unexpected path"
  path="$(safe_ref "$ref")"
  [[ "$(field "$MANIFEST" "$sha_key")" == "$(sha256sum "$path" | awk '{print $1}')" ]] || blocked "$sha_key mismatch"
done
[[ "$(field "$MANIFEST" validation_index_ref)" == tracking/validation/S5-validation-v1.tsv ]] || blocked 'validation index ref mismatch'
[[ "$(field "$MANIFEST" defect_index_ref)" == stage5-testing/outputs/DEF-defects-v1.tsv ]] || blocked 'defect index ref mismatch'
[[ "$(field "$MANIFEST" gate5_decision_ref)" == "$(bash "$CURRENT_TOOL" resolve-one "$PROJECT_PATH" gate5-decision "$run_chain" "$source_revision")" ]] ||
  blocked 'Gate 5 decision is not the current run artifact'
[[ "$(field "$MANIFEST" validation_index_ref)" == "$(bash "$CURRENT_TOOL" resolve-one "$PROJECT_PATH" s5-validation-index "$run_chain" "$source_revision")" ]] ||
  blocked 'S5 index is not the current run artifact'
[[ "$(field "$MANIFEST" defect_index_ref)" == "$(bash "$CURRENT_TOOL" resolve-one "$PROJECT_PATH" defect-index "$run_chain" "$source_revision")" ]] ||
  blocked 'defect index is not the current run artifact'
go_path="$PROJECT_PATH/$(field "$MANIFEST" gate5_decision_ref)"
[[ "$(field "$go_path" verdict)" == GO ]] || blocked 'Gate 5 decision is not GO'
[[ "$(field "$MANIFEST" uat_approval_ref)" == "$(field "$go_path" uat_approval_ref)" ]] || blocked 'UAT approval ref mismatch'

mapfile -t s5_risk_refs < <(awk -F'\t' 'NR>1 && $15!="none" {print $15}' "$S5_INDEX")
all_risk_refs=("${bundle_risk_refs[@]}" "${s5_risk_refs[@]}")
mapfile -t sorted_risk_refs < <(printf '%s\n' "${all_risk_refs[@]}" | sed '/^$/d' | sort -u)
if (( ${#sorted_risk_refs[@]} == 0 )); then
  expected_risks=none
else
  expected_risks="$(IFS=,; printf '%s' "${sorted_risk_refs[*]}")"
fi
[[ "$(field "$MANIFEST" risk_exception_refs)" == "$expected_risks" ]] || blocked 'risk exception refs mismatch'
expected_limits="$(awk -F'\t' 'NR>1 && $7!="none" {print $7}' "$DEFECT_INDEX" | sort -u | paste -sd, -)"
[[ -n "$expected_limits" ]] || expected_limits=none
[[ "$(field "$MANIFEST" known_limitation_ids)" == "$expected_limits" ]] || blocked 'known limitation ids mismatch'

[[ "$(field "$MANIFEST" release_notes_status)" == not-requested &&
    "$(field "$MANIFEST" release_notes_ref)" == none &&
    "$(field "$MANIFEST" external_publication_status)" == not-performed &&
    "$(field "$MANIFEST" release_build_status)" == not-performed &&
    "$(field "$MANIFEST" deploy_status)" == not-performed &&
    "$(field "$MANIFEST" production_action_status)" == not-performed &&
    "$(field "$MANIFEST" cycle23_status)" == FROZEN_NOT_READY &&
    "$(field "$MANIFEST" client_next_action)" == s0-tracker:/release-notes ]] ||
  blocked 'completion scope crossed publication/release/deploy/frozen boundary'

unverified="$(field "$MANIFEST" unverified_evidence_refs)"
if [[ "$unverified" != none ]]; then
  IFS=',' read -r -a refs <<< "$unverified"
  for ref in "${refs[@]}"; do safe_ref "$ref" >/dev/null; done
fi

echo "CYCLE 1 COMPLETION VERIFIED: source=$source_revision subject=$subject_digest build=$build_identity evidence=${#bundle_id_list[@]} fresh_until=$fresh_until gate5_owner=s5-qa completion_owner=s0-tracker"

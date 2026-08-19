#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/quality-characteristics-fixture.sh"
TRANSACTION="$ROOT/cycle1-dev/s0-quality-gates/quality-configuration-commit.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-quality-only-up.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECK="$ROOT/cycle1-dev/s0-quality-gates/quality-gates-check.sh"
READER="$ROOT/cycle1-dev/s0-quality-gates/quality-policy-read.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$TRANSACTION" ]] || fail 'quality configuration transaction is missing/not executable'
bash -n "$TRANSACTION" || fail 'quality configuration transaction has invalid shell syntax'
grep -Fq 'quality-configuration-commit.sh' \
  "$ROOT/cycle1-dev/s0-quality-gates/.claude/commands/configure.md" ||
  fail 'configure command bypasses atomic transaction'
if rg -n '≥[[:space:]]*(60|80)%|>=[[:space:]]*(60|80)' \
  "$ROOT/cycle1-dev/s0-quality-gates" "$ROOT/cycle1-dev/s4-dev/.claude/commands"; then
  fail 'command/role duplicates a numeric quality threshold'
fi

write_profile_v1() {
  local project="$1" override="$2"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 5' 'revision: 1' 'previous_revision: 0'
    printf '%s\n' 'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: quality fixture'
    for pair in \
      'product_type=service' 'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' 'scm_review_policy=required-review' \
      'scm_required_checks=build,unit,integration,contract,lint,typecheck,secrets,sast,sca,dependency-integrity,pipeline-policy,image-scan,sbom' \
      'ci_provider=github-actions' \
      'ci_runners=hosted-linux' 'ci_trust_boundary=protected-workflow' \
      'ci_report_formats=junit,sarif' 'build_toolchain=native-project-toolchain' \
      'build_command=make test-build' 'package_command=not-applicable' \
      'build_output_contract=not-applicable' 'secret_provider=pass' \
      'ci_identity_references=github-actions:security-job' 'compliance_constraints=none' \
      'offline_mode=online' 'approval_constraints=required-review' \
      "quality_overrides=$override"; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
    for pair in \
      'evidence_source_profile=repository-ci' 'evidence_repository_path=.' \
      'evidence_executor_identity=github-actions:workflow-security' \
      'evidence_trusted_producers=github-actions:security-job' \
      'evidence_freshness_seconds=3600' 'evidence_signature_policy=if-produced' \
      'evidence_merge_blocking=required' 'build_subject=source-only' \
      'sbom_requirement=not-applicable' 'user_interface=none' \
      'ux_brief_requirement=not-applicable' \
      'validation_environment_profile=connected-representative' \
      'validation_environment_identity=qa-service' \
      'validation_environment_authorization=required' \
      'performance_validation=required' 'runtime_security_validation=required' \
      'compatibility_validation=required' 'accessibility_validation=not-applicable' \
      'flexibility_validation=required' 'safety_validation=not-applicable' \
      'api_contract_design=required' 'data_store_design=required' \
      'authorization_design=required' 'environment_format_validation=required'; do
      key="${pair%%=*}"; value="${pair#*=}"
      printf '%s: %s\n%s_provenance: observed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

write_quality() {
  local project="$1"
  mkdir -p "$project/tracking/quality-gates-history"
  [[ -f "$project/Dashboard.md" ]] || printf '%s\n' '# Dashboard' > "$project/Dashboard.md"
  {
    printf '%s\n' '---' 'schema_version: 1' 'artifact_id: QUALITY-POLICY-R1' \
      'artifact_type: quality-policy' "project: $(basename "$project")" 'stage: TRACKING' \
      'producer: s0-quality-gates' 'source_revision: none' 'status: VALIDATED' \
      'inputs: tracking/product-ci-profile.yaml' 'outputs: tracking/quality-gates.md' \
      'tags: sdlc,cycle1,tracking,quality-gates' 'revision: 1' 'previous_revision: 0' \
      'policy_revision: quality-v1-r1' 'product_profile_revision: 1' \
      'date: 2026-07-27' '---' '' \
      '# Quality Gates — fixture' '' \
      '| Metric id | Project threshold | Rationale |' \
      '|---|---:|---|'
    printf '%s\n' \
      '| branch_coverage_percent | >= 80 | global minimum |' \
      '| mutation_score_percent | >= 60 | global minimum |' \
      '| test_pass_rate_percent | >= 98 | global minimum |' \
      '| response_time_p95_ms | <= 500 | global maximum |' \
      '| response_time_p99_ms | <= 2000 | global maximum |' \
      '| error_rate_percent | <= 0.1 | global maximum |' \
      '| availability_percent | >= 99.9 | global minimum |' \
      '| rto_hours | <= 1 | global maximum |' \
      '| rpo_hours | <= 24 | global maximum |' \
      '| e2e_automation_percent | >= 95 | global minimum |' \
      '| complexity_max | <= 10 | global maximum |' \
      '| security_critical_high_max | <= 0 | zero tolerance |' '' \
      '## Obsidian Links' '' '- Dashboard: [[Dashboard]]' \
      '- Profile: `tracking/product-ci-profile.yaml`' \
      '- Output: [[tracking/quality-gates]]'
  } > "$project/tracking/quality-gates.md"
  cp "$project/tracking/quality-gates.md" \
    "$project/tracking/quality-gates-history/revision-1.md"
}

stage_initial_candidate() {
  local project="$1" candidate="$1/tracking/quality-config-candidate"
  write_quality "$project"
  write_quality_characteristics_fixture "$project"
  mkdir -p "$candidate/quality-gates-history"
  mv "$project/tracking/quality-gates.md" "$candidate/quality-gates.md"
  mv "$project/tracking/quality-gates-history/revision-1.md" \
    "$candidate/quality-gates-history/revision-1.md"
  mv "$project/tracking/quality-characteristics-v1.tsv" \
    "$candidate/quality-characteristics-v1.tsv"
  mv "$project/tracking/quality-characteristics.md" "$candidate/quality-characteristics.md"
}

stage_next_candidate() {
  local project="$1" revision="$2" threshold="$3"
  local current candidate="$1/tracking/quality-config-candidate"
  current="$(awk -F: '$1 == "revision" {gsub(/[[:space:]]/, "", $2); print $2; exit}' \
    "$project/tracking/quality-gates.md")"
  rm -rf "$candidate"
  mkdir -p "$candidate/quality-gates-history" "$candidate/quality-policy-invalidations"
  cp "$project/tracking/quality-gates.md" "$candidate/quality-gates.md"
  sed -i \
    -e "s/^artifact_id: QUALITY-POLICY-R$current$/artifact_id: QUALITY-POLICY-R$revision/" \
    -e "s/^revision: $current$/revision: $revision/" \
    -e "s/^previous_revision: .*/previous_revision: $current/" \
    -e "s/^policy_revision: quality-v1-r$current$/policy_revision: quality-v1-r$revision/" \
    -e "s/branch_coverage_percent | >= [0-9.]*/branch_coverage_percent | >= $threshold/" \
    "$candidate/quality-gates.md"
  cp "$candidate/quality-gates.md" \
    "$candidate/quality-gates-history/revision-$revision.md"
  cp "$project/tracking/quality-characteristics-v1.tsv" \
    "$candidate/quality-characteristics-v1.tsv"
  cp "$project/tracking/quality-characteristics.md" "$candidate/quality-characteristics.md"
  printf '%s\n' "policy_revision: quality-v1-r$revision" \
    "invalidates: quality-v1-r< $revision" \
    "previous_snapshot_sha256: $(sha256sum "$project/tracking/quality-gates-history/revision-$current.md" | awk '{print $1}')" > \
    "$candidate/quality-policy-invalidations/revision-$revision.md"
}

P_GLOBAL="$TMP_DIR/global"
write_profile_v1 "$P_GLOBAL" none
bash "$CHECK" "$P_GLOBAL" > "$TMP_DIR/global.out" || fail 'global defaults were rejected'
grep -Fq 'policy_revision=quality-global-v1' "$TMP_DIR/global.out" ||
  fail 'global policy revision was not deterministic'
[[ "$(bash "$READER" "$P_GLOBAL" branch_coverage_percent)" == \
  $'branch_coverage_percent\t>=\t80\tpercent\tquality-global-v1\t1' ]] ||
  fail 'global branch coverage metric was not read from the authoritative registry'

P_VALID="$TMP_DIR/valid"
write_profile_v1 "$P_VALID" tracking/quality-gates.md
write_quality "$P_VALID"
bash "$CHECK" "$P_VALID" > "$TMP_DIR/valid.out" || fail 'valid only-up overrides were rejected'
grep -Fq 'policy_revision=quality-v1-r1' "$TMP_DIR/valid.out" || fail 'project policy revision missing'

P_UP="$TMP_DIR/stricter"
write_profile_v1 "$P_UP" tracking/quality-gates.md
write_quality "$P_UP"
sed -i -e 's/branch_coverage_percent | >= 80/branch_coverage_percent | >= 90/' \
  -e 's/response_time_p95_ms | <= 500/response_time_p95_ms | <= 250/' \
  "$P_UP/tracking/quality-gates.md"
cp "$P_UP/tracking/quality-gates.md" "$P_UP/tracking/quality-gates-history/revision-1.md"
bash "$CHECK" "$P_UP" >/dev/null || fail 'stricter project thresholds were rejected'
[[ "$(bash "$READER" "$P_UP" branch_coverage_percent)" == \
  $'branch_coverage_percent\t>=\t90\tpercent\tquality-v1-r1\t1' ]] ||
  fail 'effective project threshold was not resolved exactly'
if bash "$READER" "$P_UP" invented_metric >/dev/null 2>&1; then
  fail 'unknown quality metric was accepted by the reader'
fi

for fixture in lower-coverage higher-latency nonzero-high; do
  project="$TMP_DIR/$fixture"
  write_profile_v1 "$project" tracking/quality-gates.md
  write_quality "$project"
  case "$fixture" in
    lower-coverage) sed -i 's/branch_coverage_percent | >= 80/branch_coverage_percent | >= 79/' "$project/tracking/quality-gates.md" ;;
    higher-latency) sed -i 's/response_time_p95_ms | <= 500/response_time_p95_ms | <= 600/' "$project/tracking/quality-gates.md" ;;
    nonzero-high) sed -i 's/security_critical_high_max | <= 0/security_critical_high_max | <= 1/' "$project/tracking/quality-gates.md" ;;
  esac
  cp "$project/tracking/quality-gates.md" "$project/tracking/quality-gates-history/revision-1.md"
  if bash "$CHECK" "$project" > "$TMP_DIR/$fixture.out" 2>&1; then
    fail "$fixture weakened a global minimum"
  fi
  grep -Fq 'QUALITY POLICY BLOCKED' "$TMP_DIR/$fixture.out" ||
    fail "$fixture did not return a policy blocker"
done

P_TAMPER="$TMP_DIR/tamper"
write_profile_v1 "$P_TAMPER" tracking/quality-gates.md
write_quality "$P_TAMPER"
printf '%s\n' '<!-- changed without revision -->' >> "$P_TAMPER/tracking/quality-gates.md"
if bash "$CHECK" "$P_TAMPER" >/dev/null 2>&1; then fail 'quality policy tamper without revision was accepted'; fi

P_TX="$TMP_DIR/transaction"
write_profile_v1 "$P_TX" tracking/quality-gates.md
stage_initial_candidate "$P_TX"
bash "$TRANSACTION" "$P_TX" >/dev/null || fail 'valid revision 1 transaction was rejected'
cmp -s "$P_TX/tracking/quality-gates.md" \
  "$P_TX/tracking/quality-gates-history/revision-1.md" ||
  fail 'revision 1 current/snapshot differ'

revision1_sha="$(sha256sum "$P_TX/tracking/quality-gates-history/revision-1.md" | awk '{print $1}')"
stage_next_candidate "$P_TX" 2 90
bash "$TRANSACTION" "$P_TX" >/dev/null || fail 'valid stricter revision 2 transaction was rejected'
cmp -s "$P_TX/tracking/quality-gates.md" \
  "$P_TX/tracking/quality-gates-history/revision-2.md" ||
  fail 'revision 2 current/snapshot differ'
[[ "$revision1_sha" == "$(sha256sum "$P_TX/tracking/quality-gates-history/revision-1.md" | awk '{print $1}')" ]] ||
  fail 'revision 2 transaction modified revision 1 snapshot'
[[ -f "$P_TX/tracking/quality-policy-invalidations/revision-2.md" ]] ||
  fail 'revision 2 immutable invalidation was not published'
bash "$CHECK" "$P_TX" >/dev/null || fail 'committed revision 2 does not validate'

stable_state="$(sha256sum "$P_TX/tracking/quality-gates.md" \
  "$P_TX/tracking/quality-characteristics-v1.tsv" \
  "$P_TX/tracking/quality-characteristics.md" \
  "$P_TX/tracking/quality-gates-history/revision-1.md" \
  "$P_TX/tracking/quality-gates-history/revision-2.md")"
stage_next_candidate "$P_TX" 3 91
printf '%s\n' 'corrupt' > \
  "$P_TX/tracking/quality-config-candidate/quality-characteristics-v1.tsv"
if bash "$TRANSACTION" "$P_TX" >/dev/null 2>&1; then
  fail 'validator-failing revision 3 transaction was accepted'
fi
after_failed_state="$(sha256sum "$P_TX/tracking/quality-gates.md" \
  "$P_TX/tracking/quality-characteristics-v1.tsv" \
  "$P_TX/tracking/quality-characteristics.md" \
  "$P_TX/tracking/quality-gates-history/revision-1.md" \
  "$P_TX/tracking/quality-gates-history/revision-2.md")"
[[ "$stable_state" == "$after_failed_state" ]] ||
  fail 'failed revision 3 transaction changed visible configuration'
[[ ! -e "$P_TX/tracking/quality-gates-history/revision-3.md" ]] ||
  fail 'failed revision 3 left a partial snapshot'
[[ ! -e "$P_TX/tracking/quality-policy-invalidations/revision-3.md" ]] ||
  fail 'failed revision 3 left a partial invalidation'

stage_next_candidate "$P_TX" 3 91
if QUALITY_CONFIG_FAULT_AFTER_PUBLISH=1 bash "$TRANSACTION" "$P_TX" >/dev/null 2>&1; then
  fail 'fault-injected revision 3 transaction was accepted'
fi
[[ "$stable_state" == "$(sha256sum "$P_TX/tracking/quality-gates.md" \
  "$P_TX/tracking/quality-characteristics-v1.tsv" \
  "$P_TX/tracking/quality-characteristics.md" \
  "$P_TX/tracking/quality-gates-history/revision-1.md" \
  "$P_TX/tracking/quality-gates-history/revision-2.md")" ]] ||
  fail 'fault-injected transaction was not rolled back'

stage_next_candidate "$P_TX" 3 91
rm -f "$P_TX/tracking/quality-config-candidate/quality-policy-invalidations/revision-3.md"
if bash "$TRANSACTION" "$P_TX" >/dev/null 2>&1; then
  fail 'revision 3 without invalidation was accepted'
fi

stage_next_candidate "$P_TX" 4 92
if bash "$TRANSACTION" "$P_TX" >/dev/null 2>&1; then
  fail 'revision gap from 2 to 4 was accepted'
fi

cp "$P_TX/tracking/quality-gates-history/revision-1.md" "$TMP_DIR/revision-1.valid"
printf '%s\n' '<!-- tampered history -->' >> \
  "$P_TX/tracking/quality-gates-history/revision-1.md"
if bash "$CHECK" "$P_TX" >/dev/null 2>&1; then
  fail 'changed old policy snapshot was accepted'
fi
cp "$TMP_DIR/revision-1.valid" "$P_TX/tracking/quality-gates-history/revision-1.md"

stage_next_candidate "$P_TX" 3 91
mkdir -p "$P_TX/tracking/quality-gates-history"
printf '%s\n' 'occupied immutable target' > \
  "$P_TX/tracking/quality-gates-history/revision-3.md"
if bash "$TRANSACTION" "$P_TX" >/dev/null 2>&1; then
  fail 'existing immutable revision 3 snapshot was overwritten'
fi
grep -Fqx 'occupied immutable target' \
  "$P_TX/tracking/quality-gates-history/revision-3.md" ||
  fail 'existing immutable snapshot content changed'

echo 'PASS: quality only-up smoke'

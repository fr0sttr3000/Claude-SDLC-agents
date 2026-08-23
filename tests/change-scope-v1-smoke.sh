#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOOL="$ROOT/cycle1-dev/s0-validate/change-scope-v1.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-change-scope-v1.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile() {
  local project="$1"
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' \
      'schema_version: 1' \
      'revision: 1' \
      'previous_revision: 0' \
      'updated_at: 2026-08-20T12:00:00Z' \
      'revision_reason: initial discovery'
    for pair in \
      'product_type=service' \
      'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' \
      'scm_review_policy=required-review' \
      'scm_required_checks=lint,test,security' \
      'ci_provider=github-actions' \
      'ci_runners=hosted-linux' \
      'ci_trust_boundary=protected-ci' \
      'ci_report_formats=junit,sarif' \
      'build_toolchain=native-project-toolchain' \
      'build_command=make test-build' \
      'package_command=not-applicable' \
      'build_output_contract=not-applicable' \
      'secret_provider=pass' \
      'ci_identity_references=github-app:ci-bot' \
      'compliance_constraints=none' \
      'offline_mode=online' \
      'approval_constraints=required-review' \
      'quality_overrides=none'; do
      key="${pair%%=*}"
      value="${pair#*=}"
      printf '%s: %s\n%s_provenance: user-confirmed\n' "$key" "$value" "$key"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-1.yaml"
}

PROJECT="$TMP_DIR/Alpha"
SCOPE_ID='SCOPE-20260820-001'
SCOPE_DIR="$PROJECT/tracking/change-scopes/$SCOPE_ID"
mkdir -p "$SCOPE_DIR/l1" "$SCOPE_DIR/s3" "$SCOPE_DIR/approved" \
  "$PROJECT/tracking/approvals" "$PROJECT/src/payments" "$PROJECT/src/accounting" \
  "$PROJECT/tests/payments" "$PROJECT/stage4-dev/outputs"
printf '%s\n' 'old implementation' > "$PROJECT/src/payments/service.py"
printf '%s\n' 'protected ledger' > "$PROJECT/src/accounting/ledger.py"
printf '%s\n' 'existing test' > "$PROJECT/tests/payments/test_service.py"
write_profile "$PROJECT"

SOURCE_REVISION="sha256:$(printf 'source' | sha256sum | awk '{print $1}')"
BASELINE_SHA="$(printf 'baseline' | sha256sum | awk '{print $1}')"
CREATED_AT='2026-08-20T12:00:00Z'

cat > "$SCOPE_DIR/intent.yaml" <<EOF
schema_version: 1
intent_id: INTENT-20260820-001
intent_kind: BACKLOG
intent_refs: T-001,FR-001
project: Alpha
source_revision: $SOURCE_REVISION
baseline_tree_sha256: $BASELINE_SHA
product_profile_revision: 1
created_at: $CREATED_AT
run_id: scope-run-001
EOF

cat > "$SCOPE_DIR/l1/project-map-v1.tsv" <<EOF
schema_version	source_revision	module_id	path	public_interface	dependencies	tests	generated	classification	confidence
1	$SOURCE_REVISION	payments	src/payments	src/payments/service.py	accounting	tests/payments	none	normal	high
1	$SOURCE_REVISION	accounting	src/accounting	none	none	none	none	sensitive	high
EOF

cat > "$SCOPE_DIR/l1/impact-v1.tsv" <<EOF
schema_version	intent_id	module_id	mode	operation	path	confidence	rationale
1	INTENT-20260820-001	payments	MODIFY	modify	src/payments/service.py	high	Implement the approved payment requirement
1	INTENT-20260820-001	payments	MODIFY	modify	tests/payments/test_service.py	high	Cover the approved payment requirement
1	INTENT-20260820-001	accounting	USE	read	src/accounting	high	Consume the existing public behavior without implementation changes
EOF

MAP_SHA="$(sha256sum "$SCOPE_DIR/l1/project-map-v1.tsv" | awk '{print $1}')"
IMPACT_SHA="$(sha256sum "$SCOPE_DIR/l1/impact-v1.tsv" | awk '{print $1}')"
cat > "$SCOPE_DIR/s3/architecture-impact-v1.yaml" <<EOF
schema_version: 1
intent_id: INTENT-20260820-001
source_revision: $SOURCE_REVISION
project_map_sha256: $MAP_SHA
l1_impact_sha256: $IMPACT_SHA
architecture_impact: NO_ARCHITECTURE_CHANGE
adr_refs: none
protected_modules: accounting
unresolved_count: 0
verdict: PASS
EOF

cat > "$SCOPE_DIR/approved/change-scope-paths-v1.tsv" <<EOF
schema_version	intent_id	agent	command	operation	path	module_id	module_mode	origin
1	INTENT-20260820-001	s4-qa-auto	/write-tests	modify	tests/payments/test_service.py	payments	MODIFY	s3
1	INTENT-20260820-001	s4-qa-auto	/write-tests	declared-output	stage4-dev/outputs/QA-*tdd-report*.md	governance	SYSTEM	registry
1	INTENT-20260820-001	s4-qa-auto	/write-tests	declared-output	stage4-dev/outputs/QA-TDD-status.md	governance	SYSTEM	registry
1	INTENT-20260820-001	s4-dev	/dev-report	modify	src/payments/service.py	payments	MODIFY	s3
1	INTENT-20260820-001	s4-dev	/dev-report	declared-output	stage4-dev/outputs/DEV-*PR-*-summary.md	governance	SYSTEM	registry
1	INTENT-20260820-001	s4-techlead	/review	declared-output	stage4-dev/outputs/TL-*review-PR*.md	governance	SYSTEM	registry
EOF

ARCH_SHA="$(sha256sum "$SCOPE_DIR/s3/architecture-impact-v1.yaml" | awk '{print $1}')"
PATHS_SHA="$(sha256sum "$SCOPE_DIR/approved/change-scope-paths-v1.tsv" | awk '{print $1}')"
INTENT_SHA="$(sha256sum "$SCOPE_DIR/intent.yaml" | awk '{print $1}')"
SUBJECT_SHA="$(printf '%s\n' "$SOURCE_REVISION" "$BASELINE_SHA" "$INTENT_SHA" "$MAP_SHA" "$IMPACT_SHA" "$ARCH_SHA" "$PATHS_SHA" | sha256sum | awk '{print $1}')"
APPROVAL_ID="APPROVAL-SCOPE-$SCOPE_ID"
cat > "$SCOPE_DIR/approved/change-scope-v1.yaml" <<EOF
schema_version: 1
scope_id: $SCOPE_ID
status: APPROVED
project: Alpha
source_revision: $SOURCE_REVISION
baseline_tree_sha256: $BASELINE_SHA
product_profile_revision: 1
intent_ref: tracking/change-scopes/$SCOPE_ID/intent.yaml
intent_sha256: $INTENT_SHA
project_map_ref: tracking/change-scopes/$SCOPE_ID/l1/project-map-v1.tsv
project_map_sha256: $MAP_SHA
l1_impact_ref: tracking/change-scopes/$SCOPE_ID/l1/impact-v1.tsv
l1_impact_sha256: $IMPACT_SHA
architecture_impact_ref: tracking/change-scopes/$SCOPE_ID/s3/architecture-impact-v1.yaml
architecture_impact_sha256: $ARCH_SHA
paths_ref: tracking/change-scopes/$SCOPE_ID/approved/change-scope-paths-v1.tsv
paths_sha256: $PATHS_SHA
scope_subject_digest: $SUBJECT_SHA
approval_ref: tracking/approvals/$APPROVAL_ID.yaml
created_at: $CREATED_AT
EOF
SCOPE_SHA="$(sha256sum "$SCOPE_DIR/approved/change-scope-v1.yaml" | awk '{print $1}')"
cat > "$PROJECT/tracking/current-change-scope-v1.yaml" <<EOF
schema_version: 1
scope_id: $SCOPE_ID
scope_ref: tracking/change-scopes/$SCOPE_ID/approved/change-scope-v1.yaml
scope_sha256: $SCOPE_SHA
paths_ref: tracking/change-scopes/$SCOPE_ID/approved/change-scope-paths-v1.tsv
paths_sha256: $PATHS_SHA
source_revision: $SOURCE_REVISION
EOF

cat > "$PROJECT/tracking/approvals/$APPROVAL_ID.yaml" <<EOF
schema_version: 1
approval_id: $APPROVAL_ID
approval_origin: launcher-human-v1
approver_identity: maintainer
decision: APPROVE
scope: change-scope:$SCOPE_ID@$SUBJECT_SHA
rationale: Approved exact Stage 4 change boundary
source_revision: $SOURCE_REVISION
subject_digest: $SUBJECT_SHA
observed_at: $CREATED_AT
EOF
source "$ROOT/tests/lib/human-approval-fixture.sh"
setup_human_approval_receipts "$TMP_DIR/approval-receipts"
record_human_approval_receipt "$PROJECT" "$PROJECT/tracking/approvals/$APPROVAL_ID.yaml"

[[ -x "$TOOL" ]] || fail 'Change Scope validator is missing or not executable'
bash "$TOOL" validate "$PROJECT" "$SCOPE_DIR/approved/change-scope-v1.yaml" \
  | grep -Fq 'CHANGE SCOPE VERIFIED' || fail 'valid Change Scope was rejected'
bash "$TOOL" current "$PROJECT" | grep -Fq "$SCOPE_ID" ||
  fail 'current Change Scope did not resolve'

printf '%s\n' '# tampered without revision bump' >> "$PROJECT/tracking/product-ci-profile.yaml"
if bash "$TOOL" current "$PROJECT" >"$TMP_DIR/tampered-profile.out" 2>&1; then
  fail 'scope accepted a Product Profile changed without a revision bump'
fi
grep -Fq 'current Product Profile is invalid' "$TMP_DIR/tampered-profile.out" ||
  fail 'same-revision Product Profile tamper was not identified'
cp "$PROJECT/tracking/product-ci-profile-history/revision-1.yaml" \
  "$PROJECT/tracking/product-ci-profile.yaml"

cp "$SCOPE_DIR/approved/change-scope-v1.yaml" "$SCOPE_DIR/approved/tampered-baseline.yaml"
OTHER_BASELINE="$(printf 'other-baseline' | sha256sum | awk '{print $1}')"
sed -i "s/baseline_tree_sha256: $BASELINE_SHA/baseline_tree_sha256: $OTHER_BASELINE/" \
  "$SCOPE_DIR/approved/tampered-baseline.yaml"
if bash "$TOOL" validate "$PROJECT" "$SCOPE_DIR/approved/tampered-baseline.yaml" \
  >"$TMP_DIR/baseline-mismatch.out" 2>&1; then
  fail 'scope metadata could replace the intent baseline'
fi
grep -Fq 'intent baseline digest does not match scope metadata' "$TMP_DIR/baseline-mismatch.out" ||
  fail 'intent/metadata baseline mismatch was not identified'
rm -f "$SCOPE_DIR/approved/tampered-baseline.yaml"

cp "$SCOPE_DIR/l1/project-map-v1.tsv" "$TMP_DIR/project-map.valid.tsv"
sed -i 's/\taccounting\ttests\/payments/\tmissing-module\ttests\/payments/' \
  "$SCOPE_DIR/l1/project-map-v1.tsv"
if bash "$TOOL" validate-l1 "$PROJECT" "$SCOPE_ID" >"$TMP_DIR/missing-dependency.out" 2>&1; then
  fail 'Project Map accepted a dependency on an unknown module'
fi
grep -Fq 'dependency does not exist' "$TMP_DIR/missing-dependency.out" ||
  fail 'unknown Project Map dependency was not identified'
mv "$TMP_DIR/project-map.valid.tsv" "$SCOPE_DIR/l1/project-map-v1.tsv"

RUNTIME_SCOPE="$TMP_DIR/runtime-scope.tsv"
bash "$TOOL" runtime-access "$PROJECT" "$SCOPE_DIR/approved/change-scope-v1.yaml" \
  s4-dev /dev-report "$RUNTIME_SCOPE" | grep -Fq 'RUNTIME CHANGE SCOPE' ||
  fail 'runtime access table was not generated'
grep -Fqx $'1\twrite\tsrc/payments/service.py' "$RUNTIME_SCOPE" ||
  fail 'runtime access omitted the exact implementation path'
grep -Fqx $'1\twrite\tstage4-dev/outputs' "$RUNTIME_SCOPE" ||
  fail 'runtime access omitted the declared-output parent'
grep -Fqx $'1\tdeny\tsrc/accounting' "$RUNTIME_SCOPE" ||
  fail 'runtime access omitted the protected module'

BEFORE="$TMP_DIR/before.tsv"
AFTER="$TMP_DIR/after.tsv"
bash "$TOOL" snapshot "$PROJECT" "$BEFORE"
printf '%s\n' 'new implementation' > "$PROJECT/src/payments/service.py"
bash "$TOOL" snapshot "$PROJECT" "$AFTER"
bash "$TOOL" verify-diff "$PROJECT" "$BEFORE" "$AFTER" \
  "$SCOPE_DIR/approved/change-scope-paths-v1.tsv" s4-dev /dev-report \
  | grep -Fq 'CHANGE DIFF VERIFIED' || fail 'allowed source change was rejected'

BEFORE="$AFTER"
AFTER="$TMP_DIR/after-violation.tsv"
printf '%s\n' 'tampered ledger' > "$PROJECT/src/accounting/ledger.py"
bash "$TOOL" snapshot "$PROJECT" "$AFTER"
if bash "$TOOL" verify-diff "$PROJECT" "$BEFORE" "$AFTER" \
  "$SCOPE_DIR/approved/change-scope-paths-v1.tsv" s4-dev /dev-report \
  >"$TMP_DIR/violation.out" 2>&1; then
  fail 'out-of-scope protected-module change was accepted'
fi
grep -Fq $'SCOPE_VIOLATION\tmodify\tsrc/accounting/ledger.py' "$TMP_DIR/violation.out" ||
  fail 'scope violation does not identify exact operation/path'

AUTO_PROJECT="$TMP_DIR/Beta"
AUTO_SCOPE='SCOPE-20260820-002'
AUTO_DIR="$AUTO_PROJECT/tracking/change-scopes/$AUTO_SCOPE"
mkdir -p "$AUTO_PROJECT/src/orders" "$AUTO_PROJECT/tests/orders" \
  "$AUTO_PROJECT/stage4-dev/outputs" "$AUTO_PROJECT/tracking/approvals"
printf '%s\n' implementation > "$AUTO_PROJECT/src/orders/service.py"
printf '%s\n' test > "$AUTO_PROJECT/tests/orders/test_service.py"
write_profile "$AUTO_PROJECT"
bash "$TOOL" init "$AUTO_PROJECT" "$AUTO_SCOPE" BACKLOG 'T-002,FR-002' \
  "$SOURCE_REVISION" "$BASELINE_SHA" 1 auto-run-002 >/dev/null
cat > "$AUTO_DIR/l1/project-map-v1.tsv" <<EOF
schema_version	source_revision	module_id	path	public_interface	dependencies	tests	generated	classification	confidence
1	$SOURCE_REVISION	orders	src/orders	src/orders/service.py	none	tests/orders	none	normal	high
EOF
cat > "$AUTO_DIR/l1/impact-v1.tsv" <<'EOF'
schema_version	intent_id	module_id	mode	operation	path	confidence	rationale
1	INTENT-20260820-002	orders	MODIFY	modify	src/orders/service.py	high	Implement the exact order change
1	INTENT-20260820-002	orders	MODIFY	modify	tests/orders/test_service.py	high	Test the exact order change
EOF
AUTO_MAP_SHA="$(sha256sum "$AUTO_DIR/l1/project-map-v1.tsv" | awk '{print $1}')"
AUTO_IMPACT_SHA="$(sha256sum "$AUTO_DIR/l1/impact-v1.tsv" | awk '{print $1}')"
cat > "$AUTO_DIR/s3/architecture-impact-v1.yaml" <<EOF
schema_version: 1
intent_id: INTENT-20260820-002
source_revision: $SOURCE_REVISION
project_map_sha256: $AUTO_MAP_SHA
l1_impact_sha256: $AUTO_IMPACT_SHA
architecture_impact: NO_ARCHITECTURE_CHANGE
adr_refs: none
protected_modules: none
unresolved_count: 0
verdict: PASS
EOF
cat > "$AUTO_DIR/s3/change-scope-paths-proposed-v1.tsv" <<'EOF'
schema_version	intent_id	agent	command	operation	path	module_id	module_mode	origin
1	INTENT-20260820-002	s4-qa-auto	/write-tests	modify	tests/orders/test_service.py	orders	MODIFY	s3
1	INTENT-20260820-002	s4-dev	/dev-report	modify	src/orders/service.py	orders	MODIFY	s3
EOF
bash "$TOOL" validate-l1 "$AUTO_PROJECT" "$AUTO_SCOPE" | grep -Fq 'L1 CHANGE IMPACT VERIFIED' ||
  fail 'launcher L1 bundle validation failed'

# Even a high-confidence L1 row cannot transfer a registry-owned Stage 3 output to Stage 4.
mkdir -p "$AUTO_PROJECT/stage3-design/outputs"
printf '%s\n' 'openapi: 3.1.0' > "$AUTO_PROJECT/stage3-design/outputs/ARCH-api-spec.yaml"
cp "$AUTO_DIR/l1/project-map-v1.tsv" "$TMP_DIR/project-map.native-valid.tsv"
cp "$AUTO_DIR/l1/impact-v1.tsv" "$TMP_DIR/impact.native-valid.tsv"
cp "$AUTO_DIR/s3/architecture-impact-v1.yaml" "$TMP_DIR/architecture.native-valid.yaml"
cp "$AUTO_DIR/s3/change-scope-paths-proposed-v1.tsv" "$TMP_DIR/paths.native-valid.tsv"
printf '1\t%s\tgovernance\tstage3-design/outputs\tstage3-design/outputs/ARCH-api-spec.yaml\tnone\tnone\tnone\tnormal\thigh\n' \
  "$SOURCE_REVISION" >> "$AUTO_DIR/l1/project-map-v1.tsv"
printf '1\tINTENT-20260820-002\tgovernance\tMODIFY\tmodify\tstage3-design/outputs/ARCH-api-spec.yaml\thigh\tAttempt forbidden governance ownership transfer\n' \
  >> "$AUTO_DIR/l1/impact-v1.tsv"
GOVERNANCE_MAP_SHA="$(sha256sum "$AUTO_DIR/l1/project-map-v1.tsv" | awk '{print $1}')"
GOVERNANCE_IMPACT_SHA="$(sha256sum "$AUTO_DIR/l1/impact-v1.tsv" | awk '{print $1}')"
sed -i "s/project_map_sha256: $AUTO_MAP_SHA/project_map_sha256: $GOVERNANCE_MAP_SHA/" \
  "$AUTO_DIR/s3/architecture-impact-v1.yaml"
sed -i "s/l1_impact_sha256: $AUTO_IMPACT_SHA/l1_impact_sha256: $GOVERNANCE_IMPACT_SHA/" \
  "$AUTO_DIR/s3/architecture-impact-v1.yaml"
printf '1\tINTENT-20260820-002\ts4-dev\t/dev-report\tmodify\tstage3-design/outputs/ARCH-api-spec.yaml\tgovernance\tMODIFY\ts3\n' \
  >> "$AUTO_DIR/s3/change-scope-paths-proposed-v1.tsv"
if bash "$TOOL" validate-s3 "$AUTO_PROJECT" "$AUTO_SCOPE" \
  >"$TMP_DIR/governance-native-path.out" 2>&1; then
  fail 'Stage 3 governance output was accepted as a native s4-dev path'
fi
grep -Fq 'native Stage 4 path overlaps registry-owned governance output' \
  "$TMP_DIR/governance-native-path.out" ||
  fail 'governance/native ownership violation was not identified'
mv "$TMP_DIR/project-map.native-valid.tsv" "$AUTO_DIR/l1/project-map-v1.tsv"
mv "$TMP_DIR/impact.native-valid.tsv" "$AUTO_DIR/l1/impact-v1.tsv"
mv "$TMP_DIR/architecture.native-valid.yaml" "$AUTO_DIR/s3/architecture-impact-v1.yaml"
mv "$TMP_DIR/paths.native-valid.tsv" "$AUTO_DIR/s3/change-scope-paths-proposed-v1.tsv"

cp "$AUTO_DIR/s3/architecture-impact-v1.yaml" "$TMP_DIR/architecture-impact.valid.yaml"
sed -i 's/architecture_impact: NO_ARCHITECTURE_CHANGE/architecture_impact: BLOCKED/' \
  "$AUTO_DIR/s3/architecture-impact-v1.yaml"
if bash "$TOOL" validate-s3 "$AUTO_PROJECT" "$AUTO_SCOPE" >"$TMP_DIR/blocked-architecture.out" 2>&1; then
  fail 'BLOCKED architecture impact was accepted as an approvable scope'
fi
mv "$TMP_DIR/architecture-impact.valid.yaml" "$AUTO_DIR/s3/architecture-impact-v1.yaml"
bash "$TOOL" validate-s3 "$AUTO_PROJECT" "$AUTO_SCOPE" | grep -Fq 'S3 CHANGE IMPACT VERIFIED' ||
  fail 'launcher S3 bundle validation failed'
AUTO_REQUEST="$(bash "$TOOL" request "$AUTO_PROJECT" "$AUTO_SCOPE")" ||
  fail 'launcher scope request assembly failed'
AUTO_APPROVAL_ID="$(awk -F': ' '$1=="approval_id" {print $2}' <<< "$AUTO_REQUEST")"
AUTO_SUBJECT="$(awk -F': ' '$1=="subject_digest" {print $2}' <<< "$AUTO_REQUEST")"
AUTO_SCOPE_VALUE="$(awk -F': ' '$1=="scope" {sub(/^[^:]*: /, ""); print}' <<< "$AUTO_REQUEST")"
cat > "$AUTO_PROJECT/tracking/approvals/$AUTO_APPROVAL_ID.yaml" <<EOF
schema_version: 1
approval_id: $AUTO_APPROVAL_ID
approval_origin: launcher-human-v1
approver_identity: maintainer
decision: APPROVE
scope: $AUTO_SCOPE_VALUE
rationale: Approved generated exact Stage 4 boundary
source_revision: $SOURCE_REVISION
subject_digest: $AUTO_SUBJECT
observed_at: $CREATED_AT
EOF
record_human_approval_receipt "$AUTO_PROJECT" \
  "$AUTO_PROJECT/tracking/approvals/$AUTO_APPROVAL_ID.yaml"
bash "$TOOL" activate "$AUTO_PROJECT" "$AUTO_SCOPE" | grep -Fq 'CHANGE SCOPE VERIFIED' ||
  fail 'approved generated Change Scope was not activated'
grep -Fq $'\tdeclared-output\tstage4-dev/outputs/QA-TDD-status.md\t' \
  "$AUTO_DIR/approved/change-scope-paths-v1.tsv" ||
  fail 'launcher did not add canonical declared outputs'

sed -i 's/^revision: 1$/revision: 2/' "$AUTO_PROJECT/tracking/product-ci-profile.yaml"
if bash "$TOOL" current "$AUTO_PROJECT" >"$TMP_DIR/stale-profile.out" 2>&1; then
  fail 'scope with a stale Product Profile revision was accepted'
fi
grep -Fq 'Product Profile revision is stale' "$TMP_DIR/stale-profile.out" ||
  fail 'stale Product Profile revision was not identified'
sed -i 's/^revision: 2$/revision: 1/' "$AUTO_PROJECT/tracking/product-ci-profile.yaml"

sed -i "s/scope_id: $AUTO_SCOPE/scope_id: ${AUTO_SCOPE}-OTHER/" \
  "$AUTO_PROJECT/tracking/current-change-scope-v1.yaml"
if bash "$TOOL" current "$AUTO_PROJECT" >"$TMP_DIR/pointer-mismatch.out" 2>&1; then
  fail 'current pointer with a mismatched scope id was accepted'
fi
grep -Fq 'pointer does not match approved metadata' "$TMP_DIR/pointer-mismatch.out" ||
  fail 'current pointer mismatch was not identified'
sed -i "s/scope_id: ${AUTO_SCOPE}-OTHER/scope_id: $AUTO_SCOPE/" \
  "$AUTO_PROJECT/tracking/current-change-scope-v1.yaml"

SYMLINK_BEFORE="$TMP_DIR/symlink-before.tsv"
SYMLINK_AFTER="$TMP_DIR/symlink-after.tsv"
bash "$TOOL" snapshot "$AUTO_PROJECT" "$SYMLINK_BEFORE" >/dev/null
rm -f "$AUTO_PROJECT/src/orders/service.py"
ln -s ../unapproved.py "$AUTO_PROJECT/src/orders/service.py"
bash "$TOOL" snapshot "$AUTO_PROJECT" "$SYMLINK_AFTER" >/dev/null
if bash "$TOOL" verify-diff "$AUTO_PROJECT" "$SYMLINK_BEFORE" "$SYMLINK_AFTER" \
  "$AUTO_DIR/approved/change-scope-paths-v1.tsv" s4-dev /dev-report \
  >"$TMP_DIR/symlink-violation.out" 2>&1; then
  fail 'approved exact path could be replaced with a symlink'
fi
grep -Fq $'SCOPE_VIOLATION\tsymlink\tsrc/orders/service.py' "$TMP_DIR/symlink-violation.out" ||
  fail 'symlink substitution was not identified'
rm -f "$AUTO_PROJECT/src/orders/service.py"
printf '%s\n' implementation > "$AUTO_PROJECT/src/orders/service.py"

TYPE_BEFORE="$TMP_DIR/type-before.tsv"
TYPE_AFTER="$TMP_DIR/type-after.tsv"
bash "$TOOL" snapshot "$AUTO_PROJECT" "$TYPE_BEFORE" >/dev/null
rm -f "$AUTO_PROJECT/src/orders/service.py"
mkdir "$AUTO_PROJECT/src/orders/service.py"
bash "$TOOL" snapshot "$AUTO_PROJECT" "$TYPE_AFTER" >/dev/null
if bash "$TOOL" verify-diff "$AUTO_PROJECT" "$TYPE_BEFORE" "$TYPE_AFTER" \
  "$AUTO_DIR/approved/change-scope-paths-v1.tsv" s4-dev /dev-report \
  >"$TMP_DIR/type-violation.out" 2>&1; then
  fail 'approved file path could be replaced with a directory'
fi
grep -Fq $'SCOPE_VIOLATION\ttype-change\tsrc/orders/service.py' "$TMP_DIR/type-violation.out" ||
  fail 'file-to-directory substitution was not identified'
rmdir "$AUTO_PROJECT/src/orders/service.py"
printf '%s\n' implementation > "$AUTO_PROJECT/src/orders/service.py"

printf '%s\n' protected > "$AUTO_PROJECT/src/unapproved.py"
export XDG_CONFIG_HOME="$TMP_DIR/launcher-config"
export SDLC_JOURNAL_STATE_DIR="$TMP_DIR/launcher-journal"
source "$ROOT/sdlc.sh"
PROJECTS="$TMP_DIR"
PROJECT=Beta
RUN_CYCLE=('s4-dev:/dev-report')
RUN_OPTIONAL=(0)
EXECUTION_STEP_PROFILES=('codex||||')
EXECUTION_STEP_SOURCES=('fixture')
USE_EXISTING_FROZEN_ROUTES=1
journal_create_run SCOPE 'Change Scope retry fixture' 'all mutation' ||
  fail 'launcher could not create Change Scope retry fixture'
if retry_journal_run "$CURRENT_RUN_ID" >"$TMP_DIR/scope-retry.out" 2>&1; then
  fail 'launcher treated interrupted Change Scope preparation as a normal child retry'
fi
grep -Fq 'Utilities → Change Scope' "$TMP_DIR/scope-retry.out" ||
  fail 'launcher did not direct interrupted Change Scope to fresh preparation'
journal_create_run AGENT 's4-dev /dev-report' 'other commands' ||
  fail 'launcher Journal fixture could not be created'
prepare_change_scope_step s4-dev /dev-report 1 ||
  fail "launcher rejected current approved scope: $CHANGE_SCOPE_REASON"
grep -Fqx $'1\twrite\tsrc/orders/service.py' "$ACTIVE_CHANGE_SCOPE_FILE" ||
  fail 'launcher runtime scope omitted approved implementation path'
printf '%s\n' changed > "$AUTO_PROJECT/src/orders/service.py"
verify_change_scope_step s4-dev /dev-report 1 ||
  fail "launcher rejected allowed full-tree diff: $CHANGE_SCOPE_REASON"
clear_active_change_scope

journal_create_run AGENT 's4-dev /dev-report violation' 'other commands' ||
  fail 'launcher violation Journal fixture could not be created'
prepare_change_scope_step s4-dev /dev-report 1 ||
  fail 'launcher could not prepare violation fixture'
printf '%s\n' tampered > "$AUTO_PROJECT/src/unapproved.py"
if verify_change_scope_step s4-dev /dev-report 1; then
  fail 'launcher accepted an out-of-scope full-tree diff'
fi
clear_active_change_scope
if prepare_change_scope_step s4-dev /dev-report 1; then
  fail 'launcher allowed mutation with an unresolved scope violation'
fi
printf '%s\n' protected > "$AUTO_PROJECT/src/unapproved.py"
prepare_change_scope_step s4-dev /dev-report 1 ||
  fail 'launcher did not unblock after out-of-scope change was restored'
clear_active_change_scope
find "$SDLC_JOURNAL_STATE_DIR" -name 'VIOLATION-*.resolved.yaml' -type f | grep -q . ||
  fail 'launcher did not record deterministic violation resolution'

cp "$SCOPE_DIR/approved/change-scope-paths-v1.tsv" "$TMP_DIR/tampered-paths.tsv"
printf '%s\n' $'1\tINTENT-20260820-001\ts4-dev\t/dev-report\tmodify\t../escape.py\tpayments\tMODIFY\ts3' \
  >> "$TMP_DIR/tampered-paths.tsv"
sed -i "s#paths_ref: .*#paths_ref: ../../../../../../$TMP_DIR/tampered-paths.tsv#" \
  "$SCOPE_DIR/approved/change-scope-v1.yaml"
if bash "$TOOL" validate "$PROJECT" "$SCOPE_DIR/approved/change-scope-v1.yaml" \
  >"$TMP_DIR/traversal.out" 2>&1; then
  fail 'traversal/tampered Change Scope was accepted'
fi

echo 'PASS: Change Scope v1 smoke'

#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-product-ci-profile.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
VALIDATOR="$ROOT/cycle1-dev/s0-validate/product-ci-profile-check.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_profile() {
  local project="$1" revision="$2" previous="$3" product_type="$4" offline="$5"
  local ci_provider="${6:-github-actions}" provenance="${7:-user-confirmed}"
  local ci_runners=hosted-linux ci_trust=protected-ci ci_formats=junit,sarif
  if [[ "$ci_provider" == none ]]; then
    ci_runners=not-applicable
    ci_trust=not-applicable
    ci_formats=not-applicable
  fi
  mkdir -p "$project/tracking/product-ci-profile-history"
  {
    printf '%s\n' 'schema_version: 1'
    printf 'revision: %s\nprevious_revision: %s\n' "$revision" "$previous"
    printf '%s\n' 'updated_at: 2026-07-27T12:00:00Z' 'revision_reason: initial discovery'
    for pair in \
      "product_type=$product_type" \
      'scm_repository_model=single-repo' \
      'scm_branch_policy=feature-branch' \
      'scm_review_policy=required-review' \
      'scm_required_checks=lint,test,security' \
      "ci_provider=$ci_provider" \
      "ci_runners=$ci_runners" \
      "ci_trust_boundary=$ci_trust" \
      "ci_report_formats=$ci_formats" \
      'build_toolchain=native-project-toolchain' \
      'build_command=make test-build' \
      'package_command=not-applicable' \
      'build_output_contract=not-applicable' \
      'secret_provider=pass' \
      'ci_identity_references=github-app:ci-bot' \
      'compliance_constraints=none' \
      "offline_mode=$offline" \
      'approval_constraints=required-review' \
      'quality_overrides=none'; do
      key="${pair%%=*}"
      value="${pair#*=}"
      printf '%s: %s\n%s_provenance: %s\n' "$key" "$value" "$key" "$provenance"
    done
  } > "$project/tracking/product-ci-profile.yaml"
  cp "$project/tracking/product-ci-profile.yaml" \
    "$project/tracking/product-ci-profile-history/revision-$revision.yaml"
}

P_SERVICE="$TMP_DIR/service"
write_profile "$P_SERVICE" 1 0 service online
bash "$VALIDATOR" "$P_SERVICE" >/dev/null || fail 'valid service profile was rejected'

P_CLI="$TMP_DIR/cli"
write_profile "$P_CLI" 1 0 cli online none
bash "$VALIDATOR" "$P_CLI" >/dev/null || fail 'valid non-service profile was rejected'

P_OFFLINE="$TMP_DIR/offline"
write_profile "$P_OFFLINE" 1 0 desktop air-gapped none
bash "$VALIDATOR" "$P_OFFLINE" >/dev/null || fail 'valid offline profile was rejected'

P_UNKNOWN="$TMP_DIR/unknown"
write_profile "$P_UNKNOWN" 1 0 service online unknown unknown
if bash "$VALIDATOR" "$P_UNKNOWN" > "$TMP_DIR/unknown.out" 2>&1; then
  fail 'mandatory unknown/inferred facts were accepted'
fi
grep -Fq 'BLOCKED' "$TMP_DIR/unknown.out" || fail 'unknown fact has no BLOCKED verdict'

P_SECRET="$TMP_DIR/secret"
write_profile "$P_SECRET" 1 0 service online
sed -i 's#ci_identity_references: github-app:ci-bot#ci_identity_references: token=ghp_example#' \
  "$P_SECRET/tracking/product-ci-profile.yaml"
cp "$P_SECRET/tracking/product-ci-profile.yaml" \
  "$P_SECRET/tracking/product-ci-profile-history/revision-1.yaml"
if bash "$VALIDATOR" "$P_SECRET" >/dev/null 2>&1; then
  fail 'profile accepted a secret-like value'
fi

P_FROZEN="$TMP_DIR/frozen-key"
write_profile "$P_FROZEN" 1 0 service online
printf '%s\n' 'deployment_target: production' >> "$P_FROZEN/tracking/product-ci-profile.yaml"
cp "$P_FROZEN/tracking/product-ci-profile.yaml" \
  "$P_FROZEN/tracking/product-ci-profile-history/revision-1.yaml"
if bash "$VALIDATOR" "$P_FROZEN" >/dev/null 2>&1; then
  fail 'profile accepted a frozen delivery/operations field'
fi

P_REVISION="$TMP_DIR/revision"
write_profile "$P_REVISION" 1 0 library online
cp "$P_REVISION/tracking/product-ci-profile.yaml" \
  "$P_REVISION/tracking/product-ci-profile-history/revision-1.yaml"
write_profile "$P_REVISION" 2 1 library online
if bash "$VALIDATOR" "$P_REVISION" > "$TMP_DIR/revision-missing.out" 2>&1; then
  fail 'revision change without invalidation record was accepted'
fi
printf '%s\n' 'profile_revision: 2' 'invalidates: revisions<2' > \
  "$P_REVISION/tracking/evidence-invalidations.md"
bash "$VALIDATOR" "$P_REVISION" >/dev/null || fail 'revision with invalidation record was rejected'

printf '%s\n' '# tampered without revision bump' >> "$P_REVISION/tracking/product-ci-profile.yaml"
if bash "$VALIDATOR" "$P_REVISION" >/dev/null 2>&1; then
  fail 'profile change without a new revision was accepted'
fi

export XDG_CONFIG_HOME="$TMP_DIR/config"
source "$ROOT/sdlc.sh"
PROJECTS="$TMP_DIR/orchestrated"
PROJECT=Missing
mkdir -p "$PROJECTS/$PROJECT"
if require_product_ci_profile >/dev/null 2>&1; then
  fail 'Cycle 1 precondition accepted a missing profile'
fi
PROJECT=Valid
write_profile "$PROJECTS/$PROJECT" 1 0 service online
require_product_ci_profile >/dev/null || fail 'Cycle 1 precondition rejected a valid profile'

for consumer in \
  cycle1-dev/s1-pm/CLAUDE.md \
  cycle1-dev/s2-test-strategy/CLAUDE.md \
  cycle1-dev/s3-arch/CLAUDE.md; do
  grep -Fq 'product-ci-profile.yaml' "$ROOT/$consumer" ||
    fail "$consumer does not consume the validated profile"
done
grep -Fq 'product_ci_profile_revision:' "$ROOT/sdlc.sh" ||
  fail 'immutable execution plan does not record profile revision'

echo 'PASS: Product & CI Profile smoke'

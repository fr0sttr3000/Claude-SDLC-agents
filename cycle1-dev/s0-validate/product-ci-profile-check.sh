#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${1:?Укажи абсолютный путь к Project}"
[[ -d "$PROJECT_PATH" ]] || { echo "PROFILE BLOCKED: Project не найден: $PROJECT_PATH" >&2; exit 2; }
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"
PROFILE="$PROJECT_PATH/tracking/product-ci-profile.yaml"

blocked() { echo "PROFILE BLOCKED: $*" >&2; exit 1; }

[[ -f "$PROFILE" ]] || blocked 'tracking/product-ci-profile.yaml отсутствует'

metadata=(schema_version revision previous_revision updated_at revision_reason)
base_facts=(
  product_type scm_repository_model scm_branch_policy scm_review_policy
  scm_required_checks ci_provider ci_runners ci_trust_boundary ci_report_formats
  build_toolchain build_command package_command build_output_contract secret_provider
  ci_identity_references compliance_constraints offline_mode approval_constraints
  quality_overrides
)
evidence_facts=(
  evidence_source_profile evidence_repository_path evidence_executor_identity
  evidence_trusted_producers evidence_freshness_seconds evidence_signature_policy
  evidence_merge_blocking build_subject sbom_requirement
)
acceptance_facts=(user_interface ux_brief_requirement)
validation_facts=(
  validation_environment_profile validation_environment_identity
  validation_environment_authorization performance_validation runtime_security_validation
)
quality_characteristic_facts=(
  compatibility_validation accessibility_validation flexibility_validation safety_validation
)
architecture_applicability_facts=(
  api_contract_design data_store_design authorization_design
)
format_applicability_facts=(environment_format_validation)
declare -A allowed=() values=()
for key in "${metadata[@]}"; do allowed["$key"]=1; done
for key in "${base_facts[@]}" "${evidence_facts[@]}" "${acceptance_facts[@]}" \
  "${validation_facts[@]}" "${quality_characteristic_facts[@]}" \
  "${architecture_applicability_facts[@]}" "${format_applicability_facts[@]}"; do
  allowed["$key"]=1
  allowed["${key}_provenance"]=1
done

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" == *:* ]] || blocked "некорректная строка без key:value: $line"
  key="${line%%:*}"
  value="${line#*:}"
  key="${key#${key%%[![:space:]]*}}"; key="${key%${key##*[![:space:]]}}"
  value="${value#${value%%[![:space:]]*}}"; value="${value%${value##*[![:space:]]}}"
  [[ "$key" =~ ^[a-z][a-z0-9_]*$ ]] || blocked "недопустимый key: $key"
  [[ -n "${allowed[$key]:-}" ]] || blocked "unknown/frozen field: $key"
  [[ -z "${values[$key]+x}" ]] || blocked "duplicate field: $key"
  [[ -n "$value" ]] || blocked "пустое обязательное поле: $key"
  values["$key"]="$value"
done < "$PROFILE"

for key in "${metadata[@]}" "${base_facts[@]}"; do
  [[ -n "${values[$key]:-}" ]] || blocked "отсутствует обязательное поле: $key"
  if [[ " ${base_facts[*]} " == *" $key "* ]]; then
    [[ -n "${values[${key}_provenance]:-}" ]] ||
      blocked "отсутствует обязательное поле: ${key}_provenance"
  fi
done

case "${values[schema_version]}" in
  1)
    for key in "${evidence_facts[@]}" "${acceptance_facts[@]}" "${validation_facts[@]}" \
      "${quality_characteristic_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key недоступен в schema_version: 1"
    done
    facts=("${base_facts[@]}")
    ;;
  2)
    for key in "${evidence_facts[@]}"; do
      [[ -n "${values[$key]:-}" ]] || blocked "отсутствует обязательное поле schema v2: $key"
      [[ -n "${values[${key}_provenance]:-}" ]] ||
        blocked "отсутствует обязательное поле schema v2: ${key}_provenance"
    done
    for key in "${acceptance_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key доступен только в schema_version: 3"
    done
    for key in "${validation_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key доступен только в schema_version: 4"
    done
    for key in "${quality_characteristic_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key доступен только в schema_version: 5"
    done
    facts=("${base_facts[@]}" "${evidence_facts[@]}")
    ;;
  3)
    for key in "${evidence_facts[@]}" "${acceptance_facts[@]}"; do
      [[ -n "${values[$key]:-}" ]] || blocked "отсутствует обязательное поле schema v3: $key"
      [[ -n "${values[${key}_provenance]:-}" ]] ||
        blocked "отсутствует обязательное поле schema v3: ${key}_provenance"
    done
    for key in "${validation_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key доступен только в schema_version: 4"
    done
    for key in "${quality_characteristic_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key доступен только в schema_version: 5"
    done
    facts=("${base_facts[@]}" "${evidence_facts[@]}" "${acceptance_facts[@]}")
    ;;
  4)
    for key in "${evidence_facts[@]}" "${acceptance_facts[@]}" "${validation_facts[@]}"; do
      [[ -n "${values[$key]:-}" ]] || blocked "отсутствует обязательное поле schema v4: $key"
      [[ -n "${values[${key}_provenance]:-}" ]] ||
        blocked "отсутствует обязательное поле schema v4: ${key}_provenance"
    done
    facts=("${base_facts[@]}" "${evidence_facts[@]}" "${acceptance_facts[@]}" "${validation_facts[@]}")
    for key in "${quality_characteristic_facts[@]}"; do
      [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
        blocked "$key доступен только в schema_version: 5"
    done
    ;;
  5)
    for key in "${evidence_facts[@]}" "${acceptance_facts[@]}" "${validation_facts[@]}" \
      "${quality_characteristic_facts[@]}"; do
      [[ -n "${values[$key]:-}" ]] || blocked "отсутствует обязательное поле schema v5: $key"
      [[ -n "${values[${key}_provenance]:-}" ]] ||
        blocked "отсутствует обязательное поле schema v5: ${key}_provenance"
    done
    facts=("${base_facts[@]}" "${evidence_facts[@]}" "${acceptance_facts[@]}" \
      "${validation_facts[@]}" "${quality_characteristic_facts[@]}")
    ;;
  *) blocked 'поддерживаются schema_version: 1|2|3|4|5' ;;
esac

if [[ "${values[schema_version]}" != 5 ]]; then
  for key in "${architecture_applicability_facts[@]}" "${format_applicability_facts[@]}"; do
    [[ -z "${values[$key]+x}" && -z "${values[${key}_provenance]+x}" ]] ||
      blocked "$key доступен только в schema_version: 5"
  done
else
  architecture_fact_count=0
  for key in "${architecture_applicability_facts[@]}"; do
    if [[ -n "${values[$key]+x}" || -n "${values[${key}_provenance]+x}" ]]; then
      [[ -n "${values[$key]:-}" && -n "${values[${key}_provenance]:-}" ]] ||
        blocked "$key и ${key}_provenance должны задаваться вместе"
      architecture_fact_count=$((architecture_fact_count + 1))
    fi
  done
  [[ "$architecture_fact_count" == 0 || "$architecture_fact_count" == "${#architecture_applicability_facts[@]}" ]] ||
    blocked 'schema v5 architecture applicability refresh должен задать все api/data-store/authorization facts'
  if [[ "$architecture_fact_count" == "${#architecture_applicability_facts[@]}" ]]; then
    facts+=("${architecture_applicability_facts[@]}")
  fi
  for key in "${format_applicability_facts[@]}"; do
    if [[ -n "${values[$key]+x}" || -n "${values[${key}_provenance]+x}" ]]; then
      [[ -n "${values[$key]:-}" && -n "${values[${key}_provenance]:-}" ]] ||
        blocked "$key и ${key}_provenance должны задаваться вместе"
      facts+=("$key")
    fi
  done
fi

[[ "${values[revision]}" =~ ^[1-9][0-9]*$ ]] || blocked 'revision должен быть положительным integer'
[[ "${values[previous_revision]}" =~ ^[0-9]+$ ]] || blocked 'previous_revision должен быть integer'
expected_previous=$((values[revision] - 1))
[[ "${values[previous_revision]}" -eq "$expected_previous" ]] ||
  blocked "previous_revision должен быть $expected_previous"
[[ "${values[updated_at]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  blocked 'updated_at должен быть ISO-8601 UTC'
[[ "${values[revision_reason]}" != unknown && "${values[revision_reason]}" != inferred ]] ||
  blocked 'revision_reason должен быть явным'

case "${values[product_type]}" in service|library|cli|desktop|mobile|data-job|other) ;; *) blocked 'unknown product_type' ;; esac
case "${values[scm_repository_model]}" in single-repo|monorepo|multi-repo|none) ;; *) blocked 'unknown scm_repository_model' ;; esac
case "${values[offline_mode]}" in online|offline|air-gapped) ;; *) blocked 'offline_mode должен быть online|offline|air-gapped' ;; esac
[[ "${values[secret_provider]}" == pass ]] || blocked 'secret_provider текущего scope должен быть pass'
case "${values[quality_overrides]}" in none|tracking/quality-gates.md) ;; *) blocked 'quality_overrides должен быть none или tracking/quality-gates.md' ;; esac
if [[ "${values[quality_overrides]}" == tracking/quality-gates.md ]]; then
  [[ -f "$PROJECT_PATH/tracking/quality-gates.md" ]] ||
    blocked 'quality_overrides ссылается на отсутствующий tracking/quality-gates.md'
fi

for key in "${facts[@]}"; do
  case "${values[${key}_provenance]}" in
    observed|user-confirmed) ;;
    inferred|unknown) blocked "$key имеет неподтверждённый provenance: ${values[${key}_provenance]}" ;;
    *) blocked "$key provenance должен быть observed|user-confirmed|inferred|unknown" ;;
  esac
  [[ "${values[$key]}" != unknown ]] || blocked "$key остаётся unknown"
done

if [[ "${values[ci_provider]}" == none ]]; then
  for key in ci_runners ci_trust_boundary ci_report_formats; do
    [[ "${values[$key]}" == not-applicable ]] || blocked "$key должен быть not-applicable при ci_provider: none"
  done
fi

if (( values[schema_version] >= 2 )); then
  case "${values[evidence_source_profile]}" in
    repository-ci|connected-runner|local-offline) ;;
    *) blocked 'evidence_source_profile должен быть repository-ci|connected-runner|local-offline' ;;
  esac
  case "${values[evidence_signature_policy]}" in
    required|if-produced|not-supported) ;;
    *) blocked 'evidence_signature_policy должен быть required|if-produced|not-supported' ;;
  esac
  case "${values[evidence_merge_blocking]}" in
    required|not-applicable) ;;
    *) blocked 'evidence_merge_blocking должен быть required|not-applicable' ;;
  esac
  case "${values[build_subject]}" in
    source-only|build-artifact|image) ;;
    *) blocked 'build_subject должен быть source-only|build-artifact|image' ;;
  esac
  case "${values[sbom_requirement]}" in
    required|not-applicable) ;;
    *) blocked 'sbom_requirement должен быть required|not-applicable' ;;
  esac
  [[ "${values[evidence_freshness_seconds]}" =~ ^[1-9][0-9]*$ ]] ||
    blocked 'evidence_freshness_seconds должен быть положительным integer'
  (( values[evidence_freshness_seconds] <= 604800 )) ||
    blocked 'evidence_freshness_seconds не может превышать 7 суток'

  repository_path="${values[evidence_repository_path]}"
  [[ "$repository_path" == "." || "$repository_path" =~ ^[A-Za-z0-9._/-]+$ ]] ||
    blocked 'evidence_repository_path должен быть безопасным project-relative path'
  [[ "$repository_path" != /* && "$repository_path" != '..' && "$repository_path" != ../* &&
    "$repository_path" != */../* && "$repository_path" != */.. ]] ||
    blocked 'evidence_repository_path не может выходить из Project'
  [[ -d "$PROJECT_PATH/$repository_path" ]] ||
    blocked "evidence_repository_path не найден: $repository_path"
  resolved_repository="$(cd "$PROJECT_PATH/$repository_path" && pwd -P)"
  [[ "$resolved_repository" == "$PROJECT_PATH" || "$resolved_repository" == "$PROJECT_PATH/"* ]] ||
    blocked 'evidence_repository_path разрешился за пределы Project'

  identity_re='^[A-Za-z0-9][A-Za-z0-9._:-]*$'
  [[ "${values[evidence_executor_identity]}" =~ $identity_re ]] ||
    blocked 'evidence_executor_identity имеет недопустимый формат'
  [[ "${values[evidence_trusted_producers]}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*(,[A-Za-z0-9][A-Za-z0-9._:-]*)*$ ]] ||
    blocked 'evidence_trusted_producers должен быть comma-separated списком identity'

  allowed_formats=',junit,tap,sarif,json,'
  seen_formats=','
  has_test_format=0
  has_security_format=0
  IFS=',' read -r -a report_formats <<< "${values[ci_report_formats]}"
  for format in "${report_formats[@]}"; do
    [[ "$allowed_formats" == *",$format,"* ]] || blocked "unsupported ci_report_format: $format"
    [[ "$seen_formats" != *",$format,"* ]] || blocked "duplicate ci_report_format: $format"
    seen_formats+="$format,"
    case "$format" in junit|tap) has_test_format=1 ;; esac
    case "$format" in sarif|json) has_security_format=1 ;; esac
  done
  (( has_test_format == 1 && has_security_format == 1 )) ||
    blocked 'schema v2 требует минимум JUnit/TAP и SARIF/JSON capability'

  baseline_checks=(
    build unit integration contract lint typecheck secrets sast sca
    dependency-integrity pipeline-policy image-scan sbom
  )
  seen_checks=','
  IFS=',' read -r -a required_checks <<< "${values[scm_required_checks]}"
  for check in "${required_checks[@]}"; do
    [[ " ${baseline_checks[*]} " == *" $check "* ]] ||
      blocked "unsupported scm_required_check: $check"
    [[ "$seen_checks" != *",$check,"* ]] || blocked "duplicate scm_required_check: $check"
    seen_checks+="$check,"
  done
  for check in "${baseline_checks[@]}"; do
    [[ "$seen_checks" == *",$check,"* ]] ||
      blocked "minimum PR check отсутствует в scm_required_checks: $check"
  done

  IFS=',' read -r -a trusted_producers <<< "${values[evidence_trusted_producers]}"
  identity_refs=",${values[ci_identity_references]},"
  for producer in "${trusted_producers[@]}"; do
    [[ "$identity_refs" == *",$producer,"* ]] ||
      blocked "trusted producer не объявлен в ci_identity_references: $producer"
  done

  if [[ "${values[evidence_source_profile]}" == repository-ci ]]; then
    [[ "${values[ci_provider]}" != none ]] ||
      blocked 'repository-ci требует существующий ci_provider'
    [[ "${values[evidence_merge_blocking]}" == required ]] ||
      blocked 'repository-ci требует evidence_merge_blocking: required'
  fi
  if [[ "${values[evidence_source_profile]}" == local-offline ]]; then
    [[ "${values[offline_mode]}" != online ]] ||
      blocked 'local-offline требует offline|air-gapped Product Profile'
    [[ "${values[evidence_merge_blocking]}" == not-applicable ]] ||
      blocked 'local-offline не может заявлять repository merge blocking'
  fi
  if [[ "${values[build_subject]}" == source-only ]]; then
    [[ "${values[sbom_requirement]}" == not-applicable ]] ||
      blocked 'source-only build не может требовать SBOM несуществующего artifact subject'
  fi
fi

if (( values[schema_version] >= 3 )); then
  case "${values[user_interface]}" in
    graphical|terminal|api-only|library-only|none) ;;
    *) blocked 'user_interface должен быть graphical|terminal|api-only|library-only|none' ;;
  esac
  case "${values[ux_brief_requirement]}" in
    required|not-applicable) ;;
    *) blocked 'ux_brief_requirement должен быть required|not-applicable' ;;
  esac
  case "${values[user_interface]}" in
    graphical|terminal)
      [[ "${values[ux_brief_requirement]}" == required ]] ||
        blocked 'graphical|terminal interface требует ux_brief_requirement: required'
      ;;
    api-only|library-only|none)
      [[ "${values[ux_brief_requirement]}" == not-applicable ]] ||
        blocked 'non-UI product требует ux_brief_requirement: not-applicable'
      ;;
  esac
fi

if (( values[schema_version] >= 4 )); then
  case "${values[validation_environment_profile]}" in
    connected-representative|local-representative|not-available) ;;
    *) blocked 'validation_environment_profile должен быть connected-representative|local-representative|not-available' ;;
  esac
  case "${values[validation_environment_authorization]}" in
    required|not-applicable) ;;
    *) blocked 'validation_environment_authorization должен быть required|not-applicable' ;;
  esac
  for key in performance_validation runtime_security_validation; do
    case "${values[$key]}" in required|not-applicable) ;;
      *) blocked "$key должен быть required|not-applicable" ;;
    esac
  done
  if [[ "${values[validation_environment_profile]}" == not-available ]]; then
    [[ "${values[validation_environment_identity]}" == not-applicable ]] ||
      blocked 'not-available environment требует validation_environment_identity: not-applicable'
    [[ "${values[validation_environment_authorization]}" == not-applicable ]] ||
      blocked 'not-available environment требует authorization: not-applicable'
  else
    [[ "${values[validation_environment_identity]}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] ||
      blocked 'validation_environment_identity имеет недопустимый формат'
    [[ "${values[validation_environment_identity]}" != not-applicable ]] ||
      blocked 'representative environment требует конкретный identity'
    [[ "${values[validation_environment_authorization]}" == required ]] ||
      blocked 'representative environment требует explicit authorization'
  fi
fi

if [[ "${values[schema_version]}" == 5 ]]; then
  for key in "${quality_characteristic_facts[@]}"; do
    case "${values[$key]}" in required|not-applicable) ;;
      *) blocked "$key должен быть required|not-applicable" ;;
    esac
  done
  if [[ "${values[accessibility_validation]}" == required ]]; then
    [[ "${values[ux_brief_requirement]}" == required ]] ||
      blocked 'accessibility_validation: required требует ux_brief_requirement: required'
  fi
  if [[ "${values[ux_brief_requirement]}" == not-applicable ]]; then
    [[ "${values[accessibility_validation]}" == not-applicable ]] ||
      blocked 'non-UI profile требует accessibility_validation: not-applicable'
  fi
  for key in "${architecture_applicability_facts[@]}"; do
    [[ -z "${values[$key]+x}" ]] && continue
    case "${values[$key]}" in required|not-applicable) ;;
      *) blocked "$key должен быть required|not-applicable" ;;
    esac
  done
  for key in "${format_applicability_facts[@]}"; do
    [[ -z "${values[$key]+x}" ]] && continue
    case "${values[$key]}" in required|not-applicable) ;;
      *) blocked "$key должен быть required|not-applicable" ;;
    esac
  done
fi

for key in "${facts[@]}"; do
  value="${values[$key]}"
  lower_value="${value,,}"
  if [[ "$lower_value" =~ (akia[0-9a-z]{8,}|gh[pousr]_[a-z0-9]+|(^|[^a-z0-9])sk-[a-z0-9]{8,}|password=|token=|secret=) ]]; then
    blocked "secret-like value запрещён: $key"
  fi
done

revision="${values[revision]}"
snapshot="$PROJECT_PATH/tracking/product-ci-profile-history/revision-$revision.yaml"
[[ -f "$snapshot" ]] || blocked "нет immutable snapshot revision-$revision.yaml"
cmp -s "$PROFILE" "$snapshot" || blocked 'current profile отличается от snapshot без новой revision'
if (( revision > 1 )); then
  previous_snapshot="$PROJECT_PATH/tracking/product-ci-profile-history/revision-$expected_previous.yaml"
  [[ -f "$previous_snapshot" ]] || blocked "нет previous snapshot revision-$expected_previous.yaml"
  invalidations="$PROJECT_PATH/tracking/evidence-invalidations.md"
  [[ -f "$invalidations" ]] || blocked 'нет evidence invalidation record для новой revision'
  grep -Eq "^profile_revision:[[:space:]]*$revision[[:space:]]*$" "$invalidations" ||
    blocked "invalidation record не связан с revision $revision"
  grep -Eq "^invalidates:[[:space:]]*revisions<$revision[[:space:]]*$" "$invalidations" ||
    blocked "invalidation record не инвалидирует revisions<$revision"
fi

echo "PROFILE VALID: schema=${values[schema_version]} revision=$revision product=${values[product_type]} ci=${values[ci_provider]} offline=${values[offline_mode]}"

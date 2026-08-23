#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
GROUP_REGISTRY="$ROOT/_contract/current-artifact-groups-v1.tsv"
HUMAN_CHECK="$ROOT/cycle1-dev/s0-validate/human-approval-check.sh"
PROFILE_CHECK="$ROOT/cycle1-dev/s0-validate/product-ci-profile-check.sh"

blocked() { echo "CHANGE SCOPE BLOCKED: $*" >&2; exit 1; }

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

resolve_project() {
  [[ -d "${1:-}" ]] || blocked 'Project not found'
  (cd "$1" && pwd -P) || blocked 'Project could not be resolved'
}

safe_relative() {
  local value="${1:-}" segment
  [[ -n "$value" && "$value" != /* && "$value" != *$'\t'* &&
     "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *//* ]] || return 1
  IFS='/' read -r -a segments <<< "$value"
  for segment in "${segments[@]}"; do
    [[ -n "$segment" && "$segment" != . && "$segment" != .. ]] || return 1
  done
}

safe_exact_path() {
  local value="${1:-}"
  safe_relative "$value" || return 1
  [[ "$value" != *'*'* && "$value" != *'?'* && "$value" != *'['* ]]
}

safe_id() { [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

path_has_symlink_ancestor() {
  local project="$1" ref="$2" current="$project" part
  IFS='/' read -r -a parts <<< "$ref"
  for part in "${parts[@]}"; do
    current="$current/$part"
    [[ ! -L "$current" ]] || return 0
    [[ -e "$current" ]] || break
  done
  return 1
}

resolve_regular_ref() {
  local project="$1" ref="$2" resolved
  safe_exact_path "$ref" || return 1
  [[ -f "$project/$ref" && ! -L "$project/$ref" ]] || return 1
  resolved="$(readlink -f -- "$project/$ref")" || return 1
  [[ "$resolved" == "$project/"* ]]
}

read_flat_yaml() {
  local file="$1" allowed_list="$2" array_name="$3" line key value allowed_key
  local -n result="$array_name"
  declare -A allowed=()
  result=()
  for allowed_key in $allowed_list; do allowed["$allowed_key"]=1; done
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" == *:* ]] || blocked "$(basename "$file"): line without key:value"
    key="$(trim "${line%%:*}")"
    value="$(trim "${line#*:}")"
    [[ -n "${allowed[$key]:-}" ]] || blocked "$(basename "$file"): unknown field $key"
    [[ -z "${result[$key]+x}" ]] || blocked "$(basename "$file"): duplicate field $key"
    [[ -n "$value" ]] || blocked "$(basename "$file"): empty field $key"
    result["$key"]="$value"
  done < "$file"
  for allowed_key in $allowed_list; do
    [[ -n "${result[$allowed_key]:-}" ]] || blocked "$(basename "$file"): missing field $allowed_key"
  done
}

validate_source_revision() {
  [[ "${1:-}" =~ ^([0-9a-f]{40}|[0-9a-f]{64}|sha256:[0-9a-f]{64})$ ]]
}

validate_intent() {
  local project="$1" file="$2" expected_source="$3"
  local keys='schema_version intent_id intent_kind intent_refs project source_revision baseline_tree_sha256 product_profile_revision created_at run_id'
  declare -A v=()
  resolve_regular_ref "$project" "${file#"$project/"}" || blocked 'intent must be a regular Project file'
  read_flat_yaml "$file" "$keys" v
  [[ "${v[schema_version]}" == 1 ]] || blocked 'intent schema_version must be 1'
  safe_id "${v[intent_id]}" || blocked 'invalid intent_id'
  [[ "${v[intent_kind]}" == BACKLOG || "${v[intent_kind]}" == CHANGE_REQUEST ]] ||
    blocked 'intent_kind must be BACKLOG|CHANGE_REQUEST'
  [[ "${v[project]}" == "$(basename "$project")" ]] || blocked 'intent Project mismatch'
  [[ "${v[source_revision]}" == "$expected_source" ]] || blocked 'intent source mismatch'
  validate_source_revision "${v[source_revision]}" || blocked 'intent source revision must be exact'
  [[ "${v[baseline_tree_sha256]}" =~ ^[0-9a-f]{64}$ ]] || blocked 'invalid baseline tree digest'
  [[ "${v[product_profile_revision]}" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid Product Profile revision'
  [[ "${v[created_at]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
    blocked 'invalid intent timestamp'
  [[ "${v[intent_refs]}" != unknown && "${v[intent_refs]}" != none ]] || blocked 'intent refs are unresolved'
  printf '%s\n' "${v[intent_id]}"
}

validate_current_profile_revision() {
  local project="$1" expected="$2" profile line key value revision='' count=0
  profile="$project/tracking/product-ci-profile.yaml"
  resolve_regular_ref "$project" 'tracking/product-ci-profile.yaml' ||
    blocked 'current Product Profile is missing or unsafe'
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# || "$line" != *:* ]] && continue
    key="$(trim "${line%%:*}")"
    [[ "$key" == revision ]] || continue
    value="$(trim "${line#*:}")"
    revision="$value"
    count=$((count + 1))
  done < "$profile"
  ((count == 1)) || blocked 'current Product Profile must contain exactly one revision'
  [[ "$revision" =~ ^[1-9][0-9]*$ ]] || blocked 'current Product Profile revision is invalid'
  [[ "$revision" == "$expected" ]] || blocked 'scope Product Profile revision is stale'
  bash "$PROFILE_CHECK" "$project" >/dev/null 2>&1 || blocked 'current Product Profile is invalid'
}

validate_project_map() {
  local file="$1" source="$2" header row_schema row_source module path interface dependencies tests generated classification confidence extra item
  local expected=$'schema_version\tsource_revision\tmodule_id\tpath\tpublic_interface\tdependencies\ttests\tgenerated\tclassification\tconfidence'
  local -a dependency_items=()
  declare -A modules=() paths=() module_dependencies=()
  [[ "$(sed -n '1p' "$file")" == "$expected" ]] || blocked 'Project Map header mismatch'
  while IFS=$'\t' read -r row_schema row_source module path interface dependencies tests generated classification confidence extra; do
    [[ -z "$extra" && "$row_schema" == 1 && "$row_source" == "$source" ]] || blocked 'invalid Project Map row'
    safe_id "$module" || blocked "invalid module id: $module"
    safe_exact_path "$path" || blocked "invalid module path: $path"
    [[ -z "${modules[$module]:-}" && -z "${paths[$path]:-}" ]] || blocked "duplicate Project Map module/path: $module"
    modules["$module"]=1; paths["$path"]=1
    for item in "$interface" "$tests" "$generated"; do
      [[ "$item" == none ]] || safe_exact_path "$item" || blocked "invalid Project Map ref: $item"
    done
    [[ "$classification" =~ ^(normal|sensitive|unknown)$ ]] || blocked "invalid module classification: $module"
    [[ "$confidence" =~ ^(high|medium|low)$ ]] || blocked "invalid Project Map confidence: $module"
    [[ "$dependencies" == none || "$dependencies" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]] ||
      blocked "invalid Project Map dependencies: $module"
    module_dependencies["$module"]="$dependencies"
  done < <(tail -n +2 "$file")
  ((${#modules[@]} > 0)) || blocked 'Project Map has no modules'
  for module in "${!modules[@]}"; do
    dependencies="${module_dependencies[$module]}"
    [[ "$dependencies" != none ]] || continue
    IFS=',' read -r -a dependency_items <<< "$dependencies"
    for item in "${dependency_items[@]}"; do
      [[ -n "${modules[$item]:-}" ]] || blocked "Project Map dependency does not exist: $module -> $item"
    done
  done
}

validate_l1_impact() {
  local file="$1" intent_id="$2" map="$3" expected=$'schema_version\tintent_id\tmodule_id\tmode\toperation\tpath\tconfidence\trationale'
  local schema row_intent module mode operation path confidence rationale extra count=0
  declare -A known=()
  while IFS=$'\t' read -r _ _ module _; do [[ -n "$module" ]] && known["$module"]=1; done < <(tail -n +2 "$map")
  [[ "$(sed -n '1p' "$file")" == "$expected" ]] || blocked 'L1 impact header mismatch'
  while IFS=$'\t' read -r schema row_intent module mode operation path confidence rationale extra; do
    [[ -z "$extra" && "$schema" == 1 && "$row_intent" == "$intent_id" ]] || blocked 'invalid L1 impact row'
    [[ -n "${known[$module]:-}" ]] || blocked "L1 impact references unknown module: $module"
    [[ "$mode" =~ ^(USE|EXTEND|MODIFY|LOCKED)$ ]] || blocked "invalid module mode: $module"
    [[ "$operation" =~ ^(read|modify|create|delete|rename_from|rename_to|generated|ephemeral)$ ]] ||
      blocked "invalid L1 operation: $operation"
    safe_exact_path "${path%/}" || blocked "invalid L1 path: $path"
    [[ "$confidence" =~ ^(high|medium|low)$ && -n "$rationale" ]] || blocked 'invalid L1 confidence/rationale'
    if [[ "$mode" == USE || "$mode" == LOCKED ]]; then
      [[ "$operation" == read ]] || blocked "$mode module requests a write: $module"
    elif [[ "$operation" != read ]]; then
      [[ "$confidence" == high ]] || blocked "write impact confidence is not high: $path"
    fi
    count=$((count + 1))
  done < <(tail -n +2 "$file")
  ((count > 0)) || blocked 'L1 impact has no rows'
}

validate_architecture() {
  local file="$1" intent_id="$2" source="$3" map_sha="$4" impact_sha="$5"
  local keys='schema_version intent_id source_revision project_map_sha256 l1_impact_sha256 architecture_impact adr_refs protected_modules unresolved_count verdict'
  declare -A v=()
  read_flat_yaml "$file" "$keys" v
  [[ "${v[schema_version]}" == 1 && "${v[intent_id]}" == "$intent_id" &&
     "${v[source_revision]}" == "$source" ]] || blocked 'architecture impact binding mismatch'
  [[ "${v[project_map_sha256]}" == "$map_sha" && "${v[l1_impact_sha256]}" == "$impact_sha" ]] ||
    blocked 'architecture impact input digest mismatch'
  [[ "${v[architecture_impact]}" =~ ^(NO_ARCHITECTURE_CHANGE|ARCHITECTURE_CHANGE_REQUIRED)$ ]] ||
    blocked 'invalid architecture impact'
  [[ "${v[unresolved_count]}" == 0 && "${v[verdict]}" == PASS ]] || blocked 'architecture impact unresolved/BLOCKED'
  if [[ "${v[architecture_impact]}" == ARCHITECTURE_CHANGE_REQUIRED ]]; then
    [[ "${v[adr_refs]}" != none ]] || blocked 'architecture change has no current ADR reference'
  fi
}

registry_pattern_allowed() {
  local agent="$1" command="$2" pattern="$3" alternatives registered
  while IFS= read -r registered; do
    IFS='|' read -r -a alternatives <<< "$registered"
    for registered in "${alternatives[@]}"; do [[ "$registered" == "$pattern" ]] && return 0; done
  done < <(awk -F'\t' -v agent="$agent" -v command="$command" 'NR>1 && $1==agent && $2==command {print $7}' "$GROUP_REGISTRY")
  return 1
}

native_path_overlaps_registry_output() {
  local native_path="${1%/}" registered
  local -a alternatives=()
  while IFS= read -r registered; do
    IFS='|' read -r -a alternatives <<< "$registered"
    for registered in "${alternatives[@]}"; do
      if [[ "$native_path" == $registered || "$registered" == "$native_path/"* ]]; then
        return 0
      fi
    done
  done < <(awk -F'\t' 'NR > 1 {print $7}' "$GROUP_REGISTRY")
  return 1
}

validate_paths() {
  local file="$1" intent_id="$2" expected=$'schema_version\tintent_id\tagent\tcommand\toperation\tpath\tmodule_id\tmodule_mode\torigin'
  local schema row_intent agent command operation path module mode origin extra count=0
  [[ "$(sed -n '1p' "$file")" == "$expected" ]] || blocked 'Change Scope paths header mismatch'
  while IFS=$'\t' read -r schema row_intent agent command operation path module mode origin extra; do
    [[ -z "$extra" && "$schema" == 1 && "$row_intent" == "$intent_id" ]] || blocked 'invalid Change Scope path row'
    case "$agent:$command" in
      s4-qa-auto:/write-tests|s4-qa-auto:/run-tests|s4-dev:/dev-report|s4-dev:/update-notes|s4-techlead:/review) ;;
      *) blocked "unsupported Stage 4 scope owner: $agent $command" ;;
    esac
    [[ "$operation" =~ ^(modify|create|delete|rename_from|rename_to|generated|ephemeral|declared-output)$ ]] ||
      blocked "invalid scope operation: $operation"
    safe_id "$module" || blocked "invalid scope module id: $module"
    [[ "$mode" =~ ^(EXTEND|MODIFY|SYSTEM)$ ]] || blocked "write row has invalid module mode: $mode"
    [[ "$origin" =~ ^(l1|s3|registry)$ ]] || blocked "invalid scope origin: $origin"
    case "$operation" in
      declared-output)
        [[ "$origin:$mode" == registry:SYSTEM ]] || blocked 'declared output must be launcher registry-owned'
        safe_relative "$path" || blocked "invalid declared-output path: $path"
        registry_pattern_allowed "$agent" "$command" "$path" || blocked "unregistered declared-output pattern: $path"
        ;;
      generated|ephemeral)
        [[ "$path" == */ ]] || blocked "$operation path must be an anchored directory prefix"
        safe_exact_path "${path%/}" || blocked "invalid $operation path: $path"
        ;;
      *) safe_exact_path "$path" || blocked "scope path must be exact: $path" ;;
    esac
    if [[ "$operation" != declared-output ]] && native_path_overlaps_registry_output "$path"; then
      blocked "native Stage 4 path overlaps registry-owned governance output: $path"
    fi
    count=$((count + 1))
  done < <(tail -n +2 "$file")
  ((count > 0)) || blocked 'Change Scope has no path rows'
}

validate_path_impact_bindings() {
  local paths="$1" impact="$2" map="$3"
  local _schema _intent agent command operation path module mode origin
  local _i_schema _i_intent i_module i_mode i_operation i_path confidence _rationale
  local _m_schema _m_source m_module module_path interface _dependencies tests generated _classification _confidence
  local matched owner_match
  while IFS=$'\t' read -r _schema _intent agent command operation path module mode origin; do
    [[ "$operation" != declared-output ]] || continue
    matched=0
    while IFS=$'\t' read -r _i_schema _i_intent i_module i_mode i_operation i_path confidence _rationale; do
      if [[ "$module:$mode:$operation:$path" == "$i_module:$i_mode:$i_operation:$i_path" &&
            "$confidence" == high ]]; then
        matched=1
        break
      fi
    done < <(tail -n +2 "$impact")
    ((matched == 1)) || blocked "scope row is not backed by exact high-confidence L1 impact: $path"

    owner_match=0
    while IFS=$'\t' read -r _m_schema _m_source m_module module_path interface _dependencies tests generated _classification _confidence; do
      [[ "$m_module" == "$module" ]] || continue
      case "$agent:$command" in
        s4-qa-auto:/write-tests)
          if [[ "$tests" != none && ( "$path" == "$tests" || "$path" == "$tests/"* ) ]]; then owner_match=1; fi
          ;;
        s4-dev:/dev-report)
          if [[ "$path" == "$module_path" || "$path" == "$module_path/"* ||
                ( "$interface" != none && ( "$path" == "$interface" || "$path" == "$interface/"* ) ) ||
                ( "$generated" != none && ( "$path" == "$generated" || "$path" == "$generated/"* ) ) ]]; then
            if [[ "$tests" == none || ( "$path" != "$tests" && "$path" != "$tests/"* ) ]]; then
              owner_match=1
            fi
          fi
          ;;
      esac
      break
    done < <(tail -n +2 "$map")
    ((owner_match == 1)) || blocked "native path is assigned to the wrong Stage 4 owner: $agent $command $path"
  done < <(tail -n +2 "$paths")
}

validate_scope() {
  local project="$1" metadata="$2"
  local keys='schema_version scope_id status project source_revision baseline_tree_sha256 product_profile_revision intent_ref intent_sha256 project_map_ref project_map_sha256 l1_impact_ref l1_impact_sha256 architecture_impact_ref architecture_impact_sha256 paths_ref paths_sha256 scope_subject_digest approval_ref created_at'
  local ref_key sha_key actual intent_id subject expected_scope intent_keys
  declare -A v=() intent_v=()
  [[ -f "$metadata" && ! -L "$metadata" ]] || blocked 'scope metadata missing/symlink'
  metadata="$(readlink -f "$metadata")"
  [[ "$metadata" == "$project/"* ]] || blocked 'scope metadata is outside Project'
  read_flat_yaml "$metadata" "$keys" v
  [[ "${v[schema_version]}" == 1 && "${v[status]}" == APPROVED ]] || blocked 'scope is not APPROVED v1'
  safe_id "${v[scope_id]}" || blocked 'invalid scope_id'
  [[ "${v[project]}" == "$(basename "$project")" ]] || blocked 'scope Project mismatch'
  validate_source_revision "${v[source_revision]}" || blocked 'scope source revision must be exact'
  if [[ -e "$project/.git" ]]; then
    local current_revision
    current_revision="$(git -C "$project" rev-parse --verify HEAD 2>/dev/null)" ||
      blocked 'current VCS source revision cannot be resolved'
    [[ "$current_revision" == "${v[source_revision]}" ]] || blocked 'scope source revision is stale'
  fi
  [[ "${v[baseline_tree_sha256]}" =~ ^[0-9a-f]{64}$ ]] || blocked 'invalid scope baseline digest'
  [[ "${v[product_profile_revision]}" =~ ^[1-9][0-9]*$ ]] || blocked 'invalid scope Product Profile revision'
  validate_current_profile_revision "$project" "${v[product_profile_revision]}"
  for ref_key in intent project_map l1_impact architecture_impact paths; do
    sha_key="${ref_key}_sha256"
    resolve_regular_ref "$project" "${v[${ref_key}_ref]}" || blocked "invalid $ref_key ref"
    actual="$(sha256sum "$project/${v[${ref_key}_ref]}" | awk '{print $1}')"
    [[ "$actual" == "${v[$sha_key]}" ]] || blocked "$ref_key digest mismatch"
  done
  intent_id="$(validate_intent "$project" "$project/${v[intent_ref]}" "${v[source_revision]}")"
  intent_keys='schema_version intent_id intent_kind intent_refs project source_revision baseline_tree_sha256 product_profile_revision created_at run_id'
  read_flat_yaml "$project/${v[intent_ref]}" "$intent_keys" intent_v
  [[ "${intent_v[baseline_tree_sha256]}" == "${v[baseline_tree_sha256]}" ]] ||
    blocked 'intent baseline digest does not match scope metadata'
  [[ "${intent_v[product_profile_revision]}" == "${v[product_profile_revision]}" ]] ||
    blocked 'intent Product Profile revision does not match scope metadata'
  validate_project_map "$project/${v[project_map_ref]}" "${v[source_revision]}"
  validate_l1_impact "$project/${v[l1_impact_ref]}" "$intent_id" "$project/${v[project_map_ref]}"
  validate_architecture "$project/${v[architecture_impact_ref]}" "$intent_id" "${v[source_revision]}" \
    "${v[project_map_sha256]}" "${v[l1_impact_sha256]}"
  validate_paths "$project/${v[paths_ref]}" "$intent_id"
  validate_path_impact_bindings "$project/${v[paths_ref]}" "$project/${v[l1_impact_ref]}" \
    "$project/${v[project_map_ref]}"
  subject="$(printf '%s\n' "${v[source_revision]}" "${v[baseline_tree_sha256]}" "${v[intent_sha256]}" \
    "${v[project_map_sha256]}" "${v[l1_impact_sha256]}" "${v[architecture_impact_sha256]}" "${v[paths_sha256]}" |
    sha256sum | awk '{print $1}')"
  [[ "$subject" == "${v[scope_subject_digest]}" ]] || blocked 'scope subject digest mismatch'
  resolve_regular_ref "$project" "${v[approval_ref]}" || blocked 'invalid scope approval ref'
  [[ "$(awk -F': ' '$1=="decision" {print $2; exit}' "$project/${v[approval_ref]}")" == APPROVE ]] ||
    blocked 'scope approval decision is not APPROVE'
  expected_scope="change-scope:${v[scope_id]}@$subject"
  [[ "$(awk -F': ' '$1=="scope" {print $2; exit}' "$project/${v[approval_ref]}")" == "$expected_scope" ]] ||
    blocked 'scope approval semantic scope mismatch'
  bash "$HUMAN_CHECK" "$project" "${v[approval_ref]}" "${v[source_revision]}" "$subject" s3-arch >/dev/null ||
    blocked 'Human Scope Approval is not verified'
  printf 'CHANGE SCOPE VERIFIED: scope=%s source=%s paths_sha256=%s\n' \
    "${v[scope_id]}" "${v[source_revision]}" "${v[paths_sha256]}"
}

existing_scope_target() {
  local project="$1" ref="$2" require_parent="${3:-0}" target
  target="$ref"
  if [[ "$require_parent" == 1 ]]; then target="${ref%/*}"; fi
  if [[ "$require_parent" == 1 && "$target" == "$ref" ]]; then
    blocked "top-level create/delete cannot be capability-confined: $ref"
  fi
  while [[ ! -e "$project/$target" ]]; do
    [[ "$target" == */* ]] || blocked "no confined existing parent for runtime path: $ref"
    target="${target%/*}"
  done
  safe_exact_path "$target" || blocked "invalid runtime capability target: $target"
  path_has_symlink_ancestor "$project" "$target" && blocked "runtime capability target contains a symlink: $target"
  printf '%s\n' "$target"
}

runtime_access() {
  local project="$1" metadata="$2" agent="$3" command="$4" output="$5"
  local keys='schema_version scope_id status project source_revision baseline_tree_sha256 product_profile_revision intent_ref intent_sha256 project_map_ref project_map_sha256 l1_impact_ref l1_impact_sha256 architecture_impact_ref architecture_impact_sha256 paths_ref paths_sha256 scope_subject_digest approval_ref created_at'
  local _schema _intent row_agent row_command operation path _module _mode _origin target
  local _i_schema _i_intent _i_module i_mode i_operation i_path _i_confidence _i_rationale
  local tmp selected=0
  declare -A v=() emitted=()
  validate_scope "$project" "$metadata" >/dev/null
  read_flat_yaml "$metadata" "$keys" v
  tmp="$(mktemp "${output}.tmp.XXXXXX")" || blocked 'cannot create runtime scope temp'
  printf 'schema_version\tcapability\tpath\n' > "$tmp"
  while IFS=$'\t' read -r _schema _intent row_agent row_command operation path _module _mode _origin; do
    [[ "$row_agent:$row_command" == "$agent:$command" ]] || continue
    case "$operation" in
      modify)
        [[ -e "$project/$path" ]] || blocked "modify target does not exist: $path"
        target="$(existing_scope_target "$project" "$path" 0)"
        ;;
      create|rename_to)
        target="$(existing_scope_target "$project" "$path" 1)"
        ;;
      delete|rename_from)
        [[ -e "$project/$path" ]] || blocked "$operation target does not exist: $path"
        target="$(existing_scope_target "$project" "$path" 1)"
        ;;
      generated|ephemeral)
        target="$(existing_scope_target "$project" "${path%/}" 0)"
        ;;
      declared-output)
        target="$(existing_scope_target "$project" "${path%/*}/placeholder" 1)"
        ;;
      *) blocked "unsupported runtime scope operation: $operation" ;;
    esac
    if [[ -z "${emitted[write:$target]:-}" ]]; then
      printf '1\twrite\t%s\n' "$target" >> "$tmp"
      emitted["write:$target"]=1
    fi
    selected=$((selected + 1))
  done < <(tail -n +2 "$project/${v[paths_ref]}")
  ((selected > 0)) || blocked "no approved paths for $agent $command"

  while IFS=$'\t' read -r _i_schema _i_intent _i_module i_mode i_operation i_path _i_confidence _i_rationale; do
    [[ "$i_mode" == USE || "$i_mode" == LOCKED ]] || continue
    [[ "$i_operation" == read && -e "$project/${i_path%/}" ]] || continue
    target="$(existing_scope_target "$project" "${i_path%/}" 0)"
    if [[ -z "${emitted[deny:$target]:-}" ]]; then
      printf '1\tdeny\t%s\n' "$target" >> "$tmp"
      emitted["deny:$target"]=1
    fi
  done < <(tail -n +2 "$project/${v[l1_impact_ref]}")
  mv "$tmp" "$output"
  printf 'RUNTIME CHANGE SCOPE: agent=%s command=%s sha256=%s\n' "$agent" "$command" \
    "$(sha256sum "$output" | awk '{print $1}')"
}

snapshot_project() {
  local project="$1" output="$2" tmp file ref type mode digest target
  mkdir -p "$(dirname "$output")"
  tmp="$(mktemp "${output}.tmp.XXXXXX")" || blocked 'cannot create snapshot temp'
  printf 'path\ttype\tmode\tdigest\n' > "$tmp"
  while IFS= read -r -d '' file; do
    ref="${file#"$project/"}"
    case "/$ref/" in */.git/*|*/.hg/*|*/.svn/*) continue ;; esac
    [[ "$ref" != *$'\t'* && "$ref" != *$'\n'* && "$ref" != *$'\r'* ]] || blocked 'Project contains an unrepresentable path'
    mode="$(stat -c '%a' -- "$file")" || blocked "cannot stat $ref"
    if [[ -L "$file" ]]; then
      type=symlink; target="$(readlink -- "$file")"; digest="$(printf '%s' "$target" | sha256sum | awk '{print $1}')"
    elif [[ -f "$file" ]]; then
      type=file; digest="$(sha256sum "$file" | awk '{print $1}')"
    elif [[ -d "$file" ]]; then
      type=directory; digest=-
    else
      type=special; digest=-
    fi
    printf '%s\t%s\t%s\t%s\n' "$ref" "$type" "$mode" "$digest" >> "$tmp"
  done < <(find "$project" -mindepth 1 -print0 2>/dev/null | sort -z)
  mv "$tmp" "$output"
  printf 'PROJECT TREE SNAPSHOT: %s\n' "$(sha256sum "$output" | awk '{print $1}')"
}

path_allowed() {
  local paths="$1" agent="$2" command="$3" observed_op="$4" observed_path="$5"
  local _schema _intent row_agent row_command operation path _module _mode _origin
  while IFS=$'\t' read -r _schema _intent row_agent row_command operation path _module _mode _origin; do
    [[ "$row_agent:$row_command" == "$agent:$command" ]] || continue
    case "$operation:$observed_op" in
      modify:modify|create:create|delete:delete|rename_from:delete|rename_to:create)
        [[ "$observed_path" == "$path" ]] && return 0 ;;
      declared-output:modify|declared-output:create|declared-output:delete)
        [[ "$observed_path" == $path ]] && return 0 ;;
      generated:modify|generated:create|generated:delete|ephemeral:modify|ephemeral:create|ephemeral:delete)
        [[ "$observed_path" == "${path%/}" || "$observed_path" == "${path%/}/"* ]] && return 0 ;;
    esac
  done < <(tail -n +2 "$paths")
  return 1
}

verify_diff() {
  local project="$1" before="$2" after="$3" paths="$4" agent="$5" command="$6"
  local path type mode digest op violations=0
  declare -A bt=() bm=() bd=() at=() am=() ad=() all=()
  [[ -f "$before" && -f "$after" ]] || blocked 'tree snapshot missing'
  [[ "$(sed -n '1p' "$before")" == $'path\ttype\tmode\tdigest' &&
     "$(sed -n '1p' "$after")" == $'path\ttype\tmode\tdigest' ]] || blocked 'tree snapshot header mismatch'
  while IFS=$'\t' read -r path type mode digest; do bt["$path"]="$type"; bm["$path"]="$mode"; bd["$path"]="$digest"; all["$path"]=1; done < <(tail -n +2 "$before")
  while IFS=$'\t' read -r path type mode digest; do at["$path"]="$type"; am["$path"]="$mode"; ad["$path"]="$digest"; all["$path"]=1; done < <(tail -n +2 "$after")
  while IFS= read -r path; do
    if [[ -z "${bt[$path]+x}" ]]; then op=create
    elif [[ -z "${at[$path]+x}" ]]; then op=delete
    elif [[ "${bt[$path]}:${bm[$path]}:${bd[$path]}" != "${at[$path]}:${am[$path]}:${ad[$path]}" ]]; then op=modify
    else continue
    fi
    if [[ -n "${at[$path]+x}" && "${at[$path]}" == symlink ]]; then
      printf 'SCOPE_VIOLATION\tsymlink\t%s\n' "$path" >&2
      violations=$((violations + 1))
      continue
    fi
    if [[ -n "${at[$path]+x}" && "${at[$path]}" == special ]]; then
      printf 'SCOPE_VIOLATION\tspecial\t%s\n' "$path" >&2
      violations=$((violations + 1))
      continue
    fi
    if [[ "$op" == modify && "${bt[$path]}" != "${at[$path]}" ]]; then
      printf 'SCOPE_VIOLATION\ttype-change\t%s\n' "$path" >&2
      violations=$((violations + 1))
      continue
    fi
    if ! path_allowed "$paths" "$agent" "$command" "$op" "$path"; then
      printf 'SCOPE_VIOLATION\t%s\t%s\n' "$op" "$path" >&2
      violations=$((violations + 1))
    fi
  done < <(printf '%s\n' "${!all[@]}" | sort)
  ((violations == 0)) || blocked "$violations out-of-scope Project change(s)"
  printf 'CHANGE DIFF VERIFIED: agent=%s command=%s before=%s after=%s\n' "$agent" "$command" \
    "$(sha256sum "$before" | awk '{print $1}')" "$(sha256sum "$after" | awk '{print $1}')"
}

current_scope() {
  local project="$1" pointer="$project/tracking/current-change-scope-v1.yaml"
  local keys='schema_version scope_id scope_ref scope_sha256 paths_ref paths_sha256 source_revision' actual output metadata_keys
  declare -A v=() metadata=()
  [[ -f "$pointer" && ! -L "$pointer" ]] || blocked 'current Change Scope pointer missing/symlink'
  read_flat_yaml "$pointer" "$keys" v
  [[ "${v[schema_version]}" == 1 ]] || blocked 'current Change Scope pointer schema mismatch'
  for key in scope paths; do
    resolve_regular_ref "$project" "${v[${key}_ref]}" || blocked "invalid current $key ref"
    actual="$(sha256sum "$project/${v[${key}_ref]}" | awk '{print $1}')"
    [[ "$actual" == "${v[${key}_sha256]}" ]] || blocked "current $key digest mismatch"
  done
  output="$(validate_scope "$project" "$project/${v[scope_ref]}")"
  metadata_keys='schema_version scope_id status project source_revision baseline_tree_sha256 product_profile_revision intent_ref intent_sha256 project_map_ref project_map_sha256 l1_impact_ref l1_impact_sha256 architecture_impact_ref architecture_impact_sha256 paths_ref paths_sha256 scope_subject_digest approval_ref created_at'
  read_flat_yaml "$project/${v[scope_ref]}" "$metadata_keys" metadata
  [[ "${v[scope_id]}" == "${metadata[scope_id]}" &&
     "${v[source_revision]}" == "${metadata[source_revision]}" &&
     "${v[paths_ref]}" == "${metadata[paths_ref]}" &&
     "${v[paths_sha256]}" == "${metadata[paths_sha256]}" ]] ||
    blocked 'current Change Scope pointer does not match approved metadata'
  printf '%s current=%s\n' "$output" "${v[scope_id]}"
}

scope_bundle_dir() {
  local project="$1" scope_id="$2"
  safe_id "$scope_id" && [[ "$scope_id" == SCOPE-* ]] || blocked 'invalid scope id'
  printf '%s/tracking/change-scopes/%s\n' "$project" "$scope_id"
}

init_scope() {
  local project="$1" scope_id="$2" kind="$3" refs="$4" source="$5" baseline="$6"
  local profile_revision="$7" run_id="$8" bundle created_at
  [[ "$kind" == BACKLOG || "$kind" == CHANGE_REQUEST ]] || blocked 'invalid intent kind'
  [[ -n "$refs" && "$refs" != unknown && "$refs" != none && "$refs" != *$'\n'* && "$refs" != *$'\r'* ]] ||
    blocked 'exact intent refs are required'
  if [[ "$kind" == BACKLOG ]]; then
    [[ "$refs" =~ ^[A-Za-z]+-[A-Za-z0-9._-]+(,[A-Za-z]+-[A-Za-z0-9._-]+)*$ ]] ||
      blocked 'backlog intent refs must be exact comma-separated ids'
  else
    safe_id "$refs" || safe_exact_path "$refs" || blocked 'Change Request ref must be an exact id or Project path'
  fi
  validate_source_revision "$source" || blocked 'source revision must be exact'
  [[ "$baseline" =~ ^[0-9a-f]{64}$ ]] || blocked 'baseline digest must be exact'
  [[ "$profile_revision" =~ ^[1-9][0-9]*$ ]] || blocked 'Product Profile revision must be positive'
  safe_id "$run_id" || blocked 'invalid preparation run id'
  bundle="$(scope_bundle_dir "$project" "$scope_id")"
  [[ ! -e "$bundle" && ! -L "$bundle" ]] || blocked 'scope id already exists'
  mkdir -p "$bundle/l1" "$bundle/s3" "$bundle/approved"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'schema_version: 1\nintent_id: INTENT-%s\nintent_kind: %s\nintent_refs: %s\nproject: %s\nsource_revision: %s\nbaseline_tree_sha256: %s\nproduct_profile_revision: %s\ncreated_at: %s\nrun_id: %s\n' \
    "${scope_id#SCOPE-}" "$kind" "$refs" "$(basename "$project")" "$source" "$baseline" \
    "$profile_revision" "$created_at" "$run_id" > "$bundle/intent.yaml"
  validate_intent "$project" "$bundle/intent.yaml" "$source" >/dev/null
  printf 'CHANGE INTENT CREATED: scope=%s ref=tracking/change-scopes/%s/intent.yaml\n' \
    "$scope_id" "$scope_id"
}

read_intent_bundle() {
  local project="$1" scope_id="$2" array_name="$3" bundle keys
  local -n intent_result="$array_name"
  bundle="$(scope_bundle_dir "$project" "$scope_id")"
  keys='schema_version intent_id intent_kind intent_refs project source_revision baseline_tree_sha256 product_profile_revision created_at run_id'
  read_flat_yaml "$bundle/intent.yaml" "$keys" "$array_name"
  validate_intent "$project" "$bundle/intent.yaml" "${intent_result[source_revision]}" >/dev/null
}

validate_l1_bundle() {
  local project="$1" scope_id="$2" bundle
  declare -A intent=()
  bundle="$(scope_bundle_dir "$project" "$scope_id")"
  read_intent_bundle "$project" "$scope_id" intent
  resolve_regular_ref "$project" "tracking/change-scopes/$scope_id/l1/project-map-v1.tsv" || blocked 'Project Map missing'
  resolve_regular_ref "$project" "tracking/change-scopes/$scope_id/l1/impact-v1.tsv" || blocked 'L1 impact missing'
  validate_project_map "$bundle/l1/project-map-v1.tsv" "${intent[source_revision]}"
  validate_l1_impact "$bundle/l1/impact-v1.tsv" "${intent[intent_id]}" "$bundle/l1/project-map-v1.tsv"
  printf 'L1 CHANGE IMPACT VERIFIED: scope=%s map_sha256=%s impact_sha256=%s\n' "$scope_id" \
    "$(sha256sum "$bundle/l1/project-map-v1.tsv" | awk '{print $1}')" \
    "$(sha256sum "$bundle/l1/impact-v1.tsv" | awk '{print $1}')"
}

validate_s3_bundle() {
  local project="$1" scope_id="$2" bundle map_sha impact_sha proposed
  declare -A intent=()
  bundle="$(scope_bundle_dir "$project" "$scope_id")"
  read_intent_bundle "$project" "$scope_id" intent
  validate_l1_bundle "$project" "$scope_id" >/dev/null
  proposed="$bundle/s3/change-scope-paths-proposed-v1.tsv"
  resolve_regular_ref "$project" "tracking/change-scopes/$scope_id/s3/architecture-impact-v1.yaml" || blocked 'architecture impact missing'
  resolve_regular_ref "$project" "tracking/change-scopes/$scope_id/s3/change-scope-paths-proposed-v1.tsv" || blocked 'proposed paths missing'
  map_sha="$(sha256sum "$bundle/l1/project-map-v1.tsv" | awk '{print $1}')"
  impact_sha="$(sha256sum "$bundle/l1/impact-v1.tsv" | awk '{print $1}')"
  validate_architecture "$bundle/s3/architecture-impact-v1.yaml" "${intent[intent_id]}" \
    "${intent[source_revision]}" "$map_sha" "$impact_sha"
  validate_paths "$proposed" "${intent[intent_id]}"
  if awk -F '\t' 'NR > 1 && $5 == "declared-output" {found=1} END {exit !found}' "$proposed"; then
    blocked 'S3 proposal must not contain launcher-owned declared outputs'
  fi
  validate_path_impact_bindings "$proposed" "$bundle/l1/impact-v1.tsv" "$bundle/l1/project-map-v1.tsv"
  printf 'S3 CHANGE IMPACT VERIFIED: scope=%s architecture_sha256=%s proposed_paths_sha256=%s\n' \
    "$scope_id" "$(sha256sum "$bundle/s3/architecture-impact-v1.yaml" | awk '{print $1}')" \
    "$(sha256sum "$proposed" | awk '{print $1}')"
}

assemble_scope_request() {
  local project="$1" scope_id="$2" bundle proposed paths request tmp agent command pattern
  local intent_sha map_sha impact_sha arch_sha paths_sha subject approval_id approval_ref
  declare -A intent=()
  bundle="$(scope_bundle_dir "$project" "$scope_id")"
  read_intent_bundle "$project" "$scope_id" intent
  validate_s3_bundle "$project" "$scope_id" >/dev/null
  proposed="$bundle/s3/change-scope-paths-proposed-v1.tsv"
  paths="$bundle/approved/change-scope-paths-v1.tsv"
  request="$bundle/approved/approval-request-v1.yaml"
  [[ ! -e "$paths" && ! -e "$request" ]] || blocked 'scope approval request already exists'
  tmp="$(mktemp "$bundle/approved/.paths.XXXXXX")" || blocked 'cannot create approved paths temp'
  cp "$proposed" "$tmp"
  while IFS=$'\t' read -r agent command _group _logical _cardinality _track pattern; do
    case "$agent:$command" in
      s4-qa-auto:/write-tests|s4-qa-auto:/run-tests|s4-dev:/dev-report|s4-dev:/update-notes|s4-techlead:/review) ;;
      *) continue ;;
    esac
    IFS='|' read -r -a alternatives <<< "$pattern"
    for pattern in "${alternatives[@]}"; do
      printf '1\t%s\t%s\t%s\tdeclared-output\t%s\tgovernance\tSYSTEM\tregistry\n' \
        "${intent[intent_id]}" "$agent" "$command" "$pattern" >> "$tmp"
    done
  done < <(tail -n +2 "$GROUP_REGISTRY")
  awk '!seen[$0]++' "$tmp" > "$paths"
  rm -f "$tmp"
  validate_paths "$paths" "${intent[intent_id]}"
  validate_path_impact_bindings "$paths" "$bundle/l1/impact-v1.tsv" "$bundle/l1/project-map-v1.tsv"
  intent_sha="$(sha256sum "$bundle/intent.yaml" | awk '{print $1}')"
  map_sha="$(sha256sum "$bundle/l1/project-map-v1.tsv" | awk '{print $1}')"
  impact_sha="$(sha256sum "$bundle/l1/impact-v1.tsv" | awk '{print $1}')"
  arch_sha="$(sha256sum "$bundle/s3/architecture-impact-v1.yaml" | awk '{print $1}')"
  paths_sha="$(sha256sum "$paths" | awk '{print $1}')"
  subject="$(printf '%s\n' "${intent[source_revision]}" "${intent[baseline_tree_sha256]}" "$intent_sha" \
    "$map_sha" "$impact_sha" "$arch_sha" "$paths_sha" | sha256sum | awk '{print $1}')"
  approval_id="APPROVAL-SCOPE-$scope_id"
  approval_ref="tracking/approvals/$approval_id.yaml"
  printf 'schema_version: 1\nscope_id: %s\nstatus: PENDING\nproject: %s\nsource_revision: %s\nbaseline_tree_sha256: %s\nproduct_profile_revision: %s\nintent_ref: tracking/change-scopes/%s/intent.yaml\nintent_sha256: %s\nproject_map_ref: tracking/change-scopes/%s/l1/project-map-v1.tsv\nproject_map_sha256: %s\nl1_impact_ref: tracking/change-scopes/%s/l1/impact-v1.tsv\nl1_impact_sha256: %s\narchitecture_impact_ref: tracking/change-scopes/%s/s3/architecture-impact-v1.yaml\narchitecture_impact_sha256: %s\npaths_ref: tracking/change-scopes/%s/approved/change-scope-paths-v1.tsv\npaths_sha256: %s\nscope_subject_digest: %s\napproval_ref: %s\ncreated_at: %s\n' \
    "$scope_id" "$(basename "$project")" "${intent[source_revision]}" "${intent[baseline_tree_sha256]}" \
    "${intent[product_profile_revision]}" "$scope_id" "$intent_sha" "$scope_id" "$map_sha" \
    "$scope_id" "$impact_sha" "$scope_id" "$arch_sha" "$scope_id" "$paths_sha" "$subject" \
    "$approval_ref" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$request"
  printf 'approval_id: %s\nsource_revision: %s\nsubject_digest: %s\nscope: change-scope:%s@%s\nevidence_producer: s3-arch\nrequest_ref: tracking/change-scopes/%s/approved/approval-request-v1.yaml\n' \
    "$approval_id" "${intent[source_revision]}" "$subject" "$scope_id" "$subject" "$scope_id"
}

activate_scope() {
  local project="$1" scope_id="$2" bundle request metadata pointer tmp output
  local keys='schema_version scope_id status project source_revision baseline_tree_sha256 product_profile_revision intent_ref intent_sha256 project_map_ref project_map_sha256 l1_impact_ref l1_impact_sha256 architecture_impact_ref architecture_impact_sha256 paths_ref paths_sha256 scope_subject_digest approval_ref created_at'
  declare -A v=()
  bundle="$(scope_bundle_dir "$project" "$scope_id")"
  request="$bundle/approved/approval-request-v1.yaml"
  metadata="$bundle/approved/change-scope-v1.yaml"
  pointer="$project/tracking/current-change-scope-v1.yaml"
  [[ -f "$request" && ! -L "$request" && ! -e "$metadata" ]] || blocked 'approval request missing or scope already activated'
  read_flat_yaml "$request" "$keys" v
  [[ "${v[scope_id]}" == "$scope_id" && "${v[status]}" == PENDING ]] || blocked 'approval request state mismatch'
  tmp="$(mktemp "$bundle/approved/.scope.XXXXXX")" || blocked 'cannot create approved scope temp'
  awk '$0 == "status: PENDING" {print "status: APPROVED"; next} {print}' "$request" > "$tmp"
  if ! output="$(validate_scope "$project" "$tmp" 2>&1)"; then
    rm -f "$tmp"
    blocked "$output"
  fi
  mv "$tmp" "$metadata"
  tmp="$(mktemp "$project/tracking/.current-change-scope.XXXXXX")" || blocked 'cannot create current scope pointer temp'
  printf 'schema_version: 1\nscope_id: %s\nscope_ref: tracking/change-scopes/%s/approved/change-scope-v1.yaml\nscope_sha256: %s\npaths_ref: tracking/change-scopes/%s/approved/change-scope-paths-v1.tsv\npaths_sha256: %s\nsource_revision: %s\n' \
    "$scope_id" "$scope_id" "$(sha256sum "$metadata" | awk '{print $1}')" "$scope_id" \
    "${v[paths_sha256]}" "${v[source_revision]}" > "$tmp"
  mv "$tmp" "$pointer"
  current_scope "$project"
}

usage() {
  printf '%s\n' \
    'usage: change-scope-v1.sh validate <Project> <change-scope-v1.yaml>' \
    '       change-scope-v1.sh init <Project> <scope-id> <BACKLOG|CHANGE_REQUEST> <refs> <source> <baseline-sha256> <profile-revision> <run-id>' \
    '       change-scope-v1.sh validate-l1 <Project> <scope-id>' \
    '       change-scope-v1.sh validate-s3 <Project> <scope-id>' \
    '       change-scope-v1.sh request <Project> <scope-id>' \
    '       change-scope-v1.sh activate <Project> <scope-id>' \
    '       change-scope-v1.sh current <Project>' \
    '       change-scope-v1.sh runtime-access <Project> <change-scope-v1.yaml> <agent> <command> <output.tsv>' \
    '       change-scope-v1.sh snapshot <Project> <output.tsv>' \
    '       change-scope-v1.sh verify-diff <Project> <before.tsv> <after.tsv> <paths.tsv> <agent> <command>' >&2
  exit 2
}

command="${1:-}"; shift || true
case "$command" in
  init)
    (($# == 8)) || usage
    project="$(resolve_project "$1")"
    init_scope "$project" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
    ;;
  validate-l1)
    (($# == 2)) || usage
    project="$(resolve_project "$1")"
    validate_l1_bundle "$project" "$2"
    ;;
  validate-s3)
    (($# == 2)) || usage
    project="$(resolve_project "$1")"
    validate_s3_bundle "$project" "$2"
    ;;
  request)
    (($# == 2)) || usage
    project="$(resolve_project "$1")"
    assemble_scope_request "$project" "$2"
    ;;
  activate)
    (($# == 2)) || usage
    project="$(resolve_project "$1")"
    activate_scope "$project" "$2"
    ;;
  validate)
    (($# == 2)) || usage
    project="$(resolve_project "$1")"
    validate_scope "$project" "$2"
    ;;
  current)
    (($# == 1)) || usage
    project="$(resolve_project "$1")"
    current_scope "$project"
    ;;
  runtime-access)
    (($# == 5)) || usage
    project="$(resolve_project "$1")"
    runtime_access "$project" "$2" "$3" "$4" "$5"
    ;;
  snapshot)
    (($# == 2)) || usage
    project="$(resolve_project "$1")"
    snapshot_project "$project" "$2"
    ;;
  verify-diff)
    (($# == 6)) || usage
    project="$(resolve_project "$1")"
    verify_diff "$project" "$2" "$3" "$4" "$5" "$6"
    ;;
  *) usage ;;
esac

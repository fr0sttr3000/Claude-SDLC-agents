#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CAPABILITIES="$ROOT/_contract/command-capabilities-v1.tsv"
GROUP_REGISTRY="$ROOT/_contract/current-artifact-groups-v1.tsv"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-markdown-output-contract.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

command_file() {
  local agent="$1" command="$2" file
  file="$ROOT/cycle1-dev/$agent/.claude/commands/${command#/}.md"
  [[ -f "$file" ]] || file="$ROOT/_tools/$agent/.claude/commands/${command#/}.md"
  printf '%s\n' "$file"
}

lint_contract() {
  local capabilities="$1" groups="$2" agent command capability access verifier stages types
  local group_index logical cardinality track patterns file markdown_group_count=0
  local checked_list="$TMP_DIR/checked.$RANDOM"
  : > "$checked_list"
  while IFS=$'\t' read -r schema agent command capability access verifier stages types; do
    [[ "$schema" == schema_version ]] && continue
    file="$(command_file "$agent" "$command")"
    [[ -f "$file" ]] || { echo "missing command file: $agent $command" >&2; return 1; }
    [[ "$types" == - || "$types" =~ ^[a-z0-9]+(-[a-z0-9]+)*(,[a-z0-9]+(-[a-z0-9]+)*)*$ ]] ||
      { echo "invalid metadata type binding: $agent $command" >&2; return 1; }
    [[ "$stages" == - || "$stages" =~ ^(S[0-5]|TRACKING)(,(S[0-5]|TRACKING))*$ ]] ||
      { echo "invalid metadata stage binding: $agent $command" >&2; return 1; }
  done < "$capabilities"

  while IFS=$'\t' read -r agent command group_index logical cardinality track patterns; do
    [[ "$agent" == agent ]] && continue
    [[ "$agent:$command" == launcher:/full-dod-approval ]] && continue
    row="$(awk -F '\t' -v agent="$agent" -v command="$command" \
      'NR > 1 && $2 == agent && $3 == command {print; exit}' "$capabilities")"
    [[ -n "$row" ]] || { echo "group has no command binding: $agent $command" >&2; return 1; }
    IFS=$'\t' read -r _schema _agent _command _capability _access _verifier stages types <<< "$row"
    IFS='|' read -r -a pattern_list <<< "$patterns"
    for pattern in "${pattern_list[@]}"; do
      [[ "$pattern" == *.md ]] || continue
      markdown_group_count=$((markdown_group_count + 1))
      [[ "$stages" != - && "$types" != - ]] ||
        { echo "Markdown group lacks stage/type binding: $agent $command $pattern" >&2; return 1; }
      case "$pattern" in
        stage0-*) path_stage=S0 ;;
        stage1-*) path_stage=S1 ;;
        stage2-*) path_stage=S2 ;;
        stage3-*) path_stage=S3 ;;
        stage4-*) path_stage=S4 ;;
        stage5-*) path_stage=S5 ;;
        tracking/*) path_stage=TRACKING ;;
        *) echo "Markdown output path outside active stage/tracking roots: $pattern" >&2; return 1 ;;
      esac
      [[ ",$stages," == *",$path_stage,"* ]] ||
        { echo "stage/path mismatch: $agent $command stage=$stages path=$pattern" >&2; return 1; }
      file="$(command_file "$agent" "$command")"
      grep -Fq '_standards/artifact-metadata.md' "$file" ||
        { echo "missing canonical construction rule: $agent $command" >&2; return 1; }
      printf '%s:%s\n' "$agent" "$command" >> "$checked_list"
    done
  done < "$groups"
  (( markdown_group_count > 0 )) || { echo 'no Markdown groups checked' >&2; return 1; }

  expected="$(awk -F '\t' 'NR > 1 && $7 ~ /\.md(\||$)/ &&
    !($1 == "launcher" && $2 == "/full-dod-approval") {print $1 ":" $2}' "$groups" |
    sort -u | wc -l)"
  checked="$(sort -u "$checked_list" | wc -l)"
  [[ "$checked" == "$expected" ]] ||
    { echo "Markdown producer count mismatch: expected=$expected checked=$checked" >&2; return 1; }

  while IFS=$'\t' read -r agent command _group _logical _cardinality _track patterns; do
    [[ "$agent" == agent ]] && continue
    [[ "$patterns" == *'.md'* ]] && continue
    row="$(awk -F '\t' -v agent="$agent" -v command="$command" \
      'NR > 1 && $2 == agent && $3 == command {print; exit}' "$capabilities")"
    [[ -n "$row" || "$agent:$command" == launcher:/full-dod-approval ]] ||
      { echo "native group lost command binding: $agent $command" >&2; return 1; }
  done < "$groups"
}

lint_contract "$CAPABILITIES" "$GROUP_REGISTRY" ||
  fail 'valid Markdown construction registries were rejected'

expect_mutation_blocked() {
  local label="$1" capabilities="$2" groups="$3"
  if lint_contract "$capabilities" "$groups" >"$TMP_DIR/mutation.out" 2>&1; then
    fail "$label"
  fi
}

cp "$CAPABILITIES" "$TMP_DIR/capabilities.tsv"
cp "$GROUP_REGISTRY" "$TMP_DIR/groups.tsv"
sed -i $'/\ts1-pm\t\\/vision\t/s/\ts1-pm\t/\tghost-producer\t/' "$TMP_DIR/capabilities.tsv"
expect_mutation_blocked 'wrong producer mutation passed' \
  "$TMP_DIR/capabilities.tsv" "$TMP_DIR/groups.tsv"

cp "$CAPABILITIES" "$TMP_DIR/capabilities.tsv"
sed -i $'/\ts1-pm\t\\/vision\t/s/\tS1\t/\tS5\t/' "$TMP_DIR/capabilities.tsv"
expect_mutation_blocked 'wrong stage mutation passed' \
  "$TMP_DIR/capabilities.tsv" "$TMP_DIR/groups.tsv"

cp "$CAPABILITIES" "$TMP_DIR/capabilities.tsv"
sed -i $'/\ts1-pm\t\\/vision\t/s/\tvision,product-vision$/\tINVALID_TYPE/' \
  "$TMP_DIR/capabilities.tsv"
expect_mutation_blocked 'wrong type mutation passed' \
  "$TMP_DIR/capabilities.tsv" "$TMP_DIR/groups.tsv"

cp "$CAPABILITIES" "$TMP_DIR/capabilities.tsv"
cp "$GROUP_REGISTRY" "$TMP_DIR/groups.tsv"
sed -i $'/^s1-pm\t\\/vision\t/s#stage1-planning/#stage5-testing/#' "$TMP_DIR/groups.tsv"
expect_mutation_blocked 'wrong output path mutation passed' \
  "$TMP_DIR/capabilities.tsv" "$TMP_DIR/groups.tsv"

bash "$ROOT/tests/artifact-metadata-v1-smoke.sh" >/dev/null ||
  fail 'representative metadata/self-output/Obsidian mutation suite failed'
echo 'PASS: Markdown output contract smoke'

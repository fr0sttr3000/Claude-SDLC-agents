#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_file() { [[ -f "$ROOT/$1" ]] || fail "missing required file: $1"; }
assert_contains() {
  grep -Fq -- "$2" "$ROOT/$1" || fail "$1 does not contain: $2"
}
assert_not_contains() {
  if grep -Fq -- "$2" "$ROOT/$1"; then
    fail "$1 still contains forbidden/stale text: $2"
  fi
}

assert_contains plans/principles.md 'Markdown-first governance'
assert_contains plans/principles.md '### KISS — минимальная достаточная реализация'
assert_contains plans/principles.md 'не владеет planning/design, quality, security или reliability verdict'
assert_contains plans/principles.md 'KISS не разрешает удалять или обходить validation'
assert_contains plans/principles.md 'Intentional complexity, защищённая'
assert_contains CLAUDE.md 'KISS — только для implementation writers'
assert_contains CLAUDE.md '`s4-dev`, а также `l2-setup`, `l3-build` и'
assert_contains cycle1-dev/s4-dev/CLAUDE.md 'KISS: выбирай самое простое решение'
assert_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md '## KISS'
assert_contains cycle1-dev/l2-setup/CLAUDE.md '## KISS при изменении repository'
assert_contains cycle1-dev/l3-build/CLAUDE.md '## KISS при исправлении repository'
assert_contains cycle1-dev/l4-run/CLAUDE.md '## KISS при изменении repository'
assert_not_contains plans/principles.md 'Агенты читают и пишут только `.md`'
assert_not_contains README.md 'Агенты читают входные `.md` файлы и создают выходные `.md` файлы. Никаких баз данных'
assert_not_contains _standards/quality.md '□ DEVOPS-cicd.yaml (шаблон CI/CD) существует'
assert_contains _standards/quality.md 'SG1 до начала S3; SG2 до начала S4'

for path in \
  cycle1-dev/s0-kickoff/.claude/commands/cr.md \
  cycle1-dev/s0-validate/.claude/commands/dor-check.md \
  cycle1-dev/s0-validate/.claude/commands/dod-check.md \
  cycle1-dev/s0-validate/.claude/commands/review.md \
  cycle1-dev/s0-validate/.claude/commands/repair.md \
  cycle1-dev/s0-tracker/.claude/commands/task-block.md \
  cycle1-dev/s0-tracker/.claude/commands/backlog.md \
  cycle1-dev/s3-arch/.claude/commands/api-spec.md; do
  assert_file "$path"
done

assert_contains cycle1-dev/s2-ba/.claude/commands/brd.md 'BA-YYYY-MM-DD-NFR.md'
assert_contains cycle1-dev/s2-ba/.claude/commands/brd.md 'BA-YYYY-MM-DD-RTM.md'
assert_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'QA-TDD-status.md'
assert_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'реализуй минимальный Green'
assert_contains cycle1-dev/s4-techlead/CLAUDE.md 'QA-TDD-status.md содержит exact `source_revision`'
assert_contains cycle1-dev/s4-techlead/CLAUDE.md '`pr-evidence-check.sh` вернул `PR EVIDENCE VERIFIED`'
assert_contains cycle1-dev/s2-qa-req/.claude/commands/testability-review.md 'QA contribution: PASS'
assert_not_contains cycle1-dev/s2-qa-req/.claude/commands/testability-review.md 'GATE 2 PASSED'
assert_contains cycle1-dev/s3-dba/.claude/commands/migration.md 'не создавай executable migration'
assert_not_contains cycle1-dev/s3-rbac/CLAUDE.md 'DREAD > 8'
assert_contains cycle1-dev/s3-rbac/CLAUDE.md 'архитектуре авторизации'
assert_not_contains cycle1-dev/s3-security/CLAUDE.md 'DREAD'
assert_not_contains cycle1-dev/s5-security/CLAUDE.md 'STRIDE/DREAD'
assert_contains cycle1-dev/s3-arch/CLAUDE.md 'QA contribution: PASS'
assert_contains cycle1-dev/s3-arch/CLAUDE.md 'current `requirements-traceability`'
assert_contains cycle1-dev/s3-arch/CLAUDE.md 'current `test-strategy`'
assert_not_contains cycle1-dev/s3-arch/CLAUDE.md 'TEST-*-strategy.md'
assert_not_contains cycle1-dev/s3-arch/CLAUDE.md 'API-first'
assert_not_contains cycle1-dev/s3-arch/CLAUDE.md 'Prefer managed services'
assert_contains cycle1-dev/s4-dev/CLAUDE.md 'только если выбранный stack'

assert_not_contains _standards/tech-debt-template.md 'осознанном пропуске DoD'
assert_not_contains cycle1-dev/s0-validate/CLAUDE.md 'если пропуск осознанный'
assert_not_contains cycle1-dev/s0-validate/dod-check.sh 'При осознанном пропуске'
assert_contains _standards/tech-debt-template.md 'не меняет FAIL применимого DoD на PASS'
assert_contains _standards/data-formats.md 'только если выбран PostgreSQL'
assert_not_contains _standards/data-formats.md 'Primary Key: всегда UUID v4'
assert_not_contains _standards/security.md 'Owner-ресурсы без RLS-защиты'
assert_not_contains cycle1-dev/s4-dev/CLAUDE.md 'оба обязательны для owner_only ресурсов'
assert_not_contains cycle1-dev/s4-dev/CLAUDE.md 'Owner-only ресурсы: двойная проверка (app + RLS)'
assert_not_contains cycle1-dev/s3-dba/.claude/commands/schema.md 'PK: `UUID DEFAULT'
assert_not_contains cycle1-dev/s3-rbac/.claude/commands/rbac-model.md 'для каждого owner-ресурса напиши PostgreSQL RLS'
assert_not_contains cycle1-dev/s2-ba/CLAUDE.md '| Тип Python |'
assert_not_contains _standards/quality.md 'авторестарт < 30 сек'
assert_not_contains _standards/quality.md 'через 7 дней после деплоя'
assert_not_contains _standards/quality.md 'default: 30 сек'
assert_not_contains _standards/quality.md 'порог: 5 ошибок за 30 сек'
assert_contains _standards/quality.md 'Gate 7 не является active gate'
assert_contains _standards/quality.md 'ARCH-api-spec.yaml существует при наличии API'
assert_contains _standards/quality.md 'S5 Testing ──[Gate 5]──► CYCLE 1 VALIDATED'
assert_not_contains _standards/quality.md 'S6 → PRODUCTION'
assert_not_contains _standards/quality.md '□ Бэкап данных настроен и проверен (restore работает)'
assert_not_contains _standards/quality.md '□ Error budget рассчитан и отслеживается'
assert_contains _standards/quality.md 'остаётся NOT_OBSERVED / deferred без production evidence'

assert_not_contains cycle1-dev/s1-pm/.claude/commands/feasibility.md '$SDLC_PROJECTS_DIR/$ARGUMENTS/'
assert_contains cycle1-dev/s1-pm/.claude/commands/feasibility.md '$SDLC_PROJECTS_DIR/{PROJECT}/'
assert_not_contains cycle1-dev/s5-perf/.claude/commands/load-test.md 'или дефолты'
assert_not_contains cycle1-dev/s5-perf/.claude/commands/load-test.md '< 300ms'
assert_contains cycle1-dev/s5-perf/.claude/commands/load-test.md 'не подставляй локальные defaults'
assert_not_contains cycle1-dev/s5-perf/CLAUDE.md 'Все 4 типа тестов выполнены'
assert_contains cycle1-dev/s5-perf/CLAUDE.md 'NOT_APPLICABLE'
assert_contains cycle3-ops/s6-sre/.claude/commands/post-deploy.md 'stage7-ops/outputs/SRE-YYYY-MM-DD-post-deploy-report.md'
assert_not_contains cycle3-ops/s6-sre/.claude/commands/post-deploy.md 'T+0/T+15/T+30/T+60'
assert_contains cycle2-deploy/s6-release/.claude/commands/release-notes.md 'точную release version X.Y.Z'
assert_contains cycle2-deploy/s6-release/.claude/commands/release-checklist.md 'images-only содержит version fallback'
assert_contains cycle3-ops/s6-sre/.claude/commands/post-deploy.md 'post-deploy-not-applicable.md'

while IFS= read -r -d '' command_file; do
  relative="${command_file#"$ROOT/"}"
  [[ "$(head -n 1 "$command_file")" == '---' ]] ||
    fail "$relative has no YAML frontmatter"
  grep -Eq '^description:[[:space:]]*[^[:space:]].*$' "$command_file" ||
    fail "$relative has no non-empty description"
done < <(find "$ROOT" -path '*/.claude/commands/*.md' -type f -print0)

assert_not_contains sdlc.sh 'gemeni|gqmeni'
assert_not_contains localrun.sh 'gemeni|gqmeni'
assert_not_contains _runtimes/agent-run.sh 'gemeni|gqmeni'
assert_not_contains cycle1-dev/l4-run/.claude/commands/run.md 'source "$repo/.env"'
assert_not_contains cycle1-dev/l3-build/CLAUDE.md 'mvn package -DskipTests'
assert_not_contains _tools/s0-secrets/.claude/commands/env.md 'eval $(' # unsafe shell evaluation
assert_not_contains _tools/s0-secrets/.claude/commands/env.md '>> ~/.bashrc'
if grep -Uq 'def test_bool_var_rejects_numeric():[[:space:]]*pass' "$ROOT/_standards/data-formats.md"; then
  fail '_standards/data-formats.md still contains a placeholder test body'
fi

[[ "$(cd "$ROOT" && rg --files _tools -g "CLAUDE.md")" == "_tools/s0-secrets/CLAUDE.md" ]] || fail "active public tool inventory must contain only s0-secrets"

assert_contains cycle2-deploy/s4-devops/CLAUDE.md 'Cycle 2 / Stage 6'
assert_not_contains cycle2-deploy/s4-devops/CLAUDE.md 'вклад в Gate 3'
assert_not_contains cycle3-ops/s6-sre/CLAUDE.md 'SLO 99.9%'
assert_contains cycle3-ops/s6-sre/CLAUDE.md 'точный порог из BA-NFR.md или tracking/quality-gates.md'

assert_contains README.md 'исполняемые и schema-артефакты сохраняют нативный формат'
assert_contains README.md 'Прямой запуск `_runtimes/agent-run.sh` не поддерживается'
assert_not_contains CLAUDE.md '# Напрямую через universal dispatcher.'
assert_not_contains CLAUDE.md '--agent-dir "$SDLC_VAULT/_agents/cycle1-dev/s1-pm"'
assert_not_contains _runtimes/adapters/codex.md 'Invocation:'
assert_not_contains _runtimes/adapters/claude.md 'Invocation:'
assert_not_contains _runtimes/adapters/gemini.md 'Invocation:'
assert_contains OVERVIEW.md 'Cycle 2/3: historical boundary'
assert_contains OVERVIEW.md 'FROZEN / NOT READY'
assert_not_contains OVERVIEW.md 'DEVOPS-*.md        ← CI/CD, Runbook, Monitoring'
assert_not_contains OVERVIEW.md 'целевая workflow которых'

echo 'PASS: principles consistency smoke'

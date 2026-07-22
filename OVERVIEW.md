# Архитектура и workflow SDLC Agent System

## Слои системы

```text
User
  │
  ▼
sdlc.sh ── Project selector ── Project Console ── Preview / Journal
  │                                      │
  │                                      ├─ Cycle 1 / Cycle 2 / Cycle 3
  │                                      ├─ One Agent
  │                                      ├─ scoped Review / Repair
  │                                      └─ Utilities / Local Repositories
  ▼
runtime routing ── agent-run.sh ── Claude | Codex | Gemini | Local host
                                        │
                                        └─ optional bounded subagent-run.sh
  ▼
canonical contracts: CLAUDE.md + _standards + command templates
  ▼
$SDLC_PROJECTS_DIR/{PROJECT}/ native artifacts + Markdown governance evidence
```

Launcher отвечает за Project/scope/routes/state. Runtime adapter отвечает за безопасный способ
выполнить prompt. Agent contract отвечает за роль/artifacts/gate contribution. Ни один adapter
не определяет собственную SDLC-логику.

## Project data model

```text
{PROJECT}/
├── Dashboard.md
├── stage1-planning/{inputs,outputs}/
├── stage2-requirements/{inputs,outputs}/
├── stage3-design/{inputs,outputs}/
├── stage4-dev/{inputs,outputs}/
├── stage5-testing/{inputs,outputs}/
├── stage6-deploy/{inputs,outputs}/
│   ├── outputs/DEVOPS-...
│   └── outputs/REL-...
├── stage7-ops/{inputs,outputs}/
│   ├── outputs/SRE-...
│   └── outputs/OPS-TDD-status.md
└── tracking/
    ├── SDLC-goals.md
    ├── quality-gates.md
    ├── ai-routing.conf
    ├── runtime-routing
    ├── backlog.md / current-sprint.md / known-issues.md
    └── execution-journal/runs/<run-id>/
```

Stage 6 принадлежит Cycle 2, Stage 7 — Cycle 3. SRE читает Stage 6 deploy evidence, но новые
Cycle 3 artifacts пишет только в `stage7-ops/outputs/SRE-...`.
Канонические prefixes: `stage6-deploy/outputs/DEVOPS-...` для delivery evidence и
`stage7-ops/outputs/SRE-...` для operations evidence.

## Cycle 1: Development

Текущий Cycle 1 содержит 28 обязательных шагов плюс явно выбранные optional utilities.

Основной dependency flow:

```text
Kickoff
  → S1 PM / PMO / Finance / project quality thresholds
  → S2 BA(BRD+NFR+RTM) / PO / QA contribution / Test Strategy / SG1
  → Gate 2 validator
  → S3 HLD+API-or-N/A / Threat model(CVSS) / Authorization / Data-or-N/A
  → Gate 3 validator
  → S4 QA-TDD write tests+RED → Developer Green/Repair → QA-TDD PASS → Tech Lead
  → S5 Test Plan / E2E / Performance / Security / Go-No-Go
  → Cycle summary / optional GitHub utility
```

QA Requirements даёт `QA contribution: PASS|FAIL`, а не подписывает Gate 2 целиком. Gate 2
также требует BRD/NFR/RTM, backlog, test strategy и SG1.

Architecture/Data/Authorization artifacts applicability-based. API spec, SQL schema, RLS,
migration, queues, health checks и другие native artifacts создаются только при соответствующем
stack/scope; N/A фиксирует причину/evidence.

## Cycle 2: Deploy / Stage 6

```text
Goal + infrastructure interview
  → deploy intake
  → write deploy tests + observed RED
  → pipeline/runbook/delivery implementation
  → run deploy tests
  → DEPLOY-TDD-status PASS
  → release notes/checklist
  → Gate 6 by s6-release
```

`s4-devops` не подписывает Gate 3/4. Он создаёт только выбранные Stage 6 delivery artifacts.
Live deploy выполняется лишь при выбранном executor/deliverable и явной authorization.

## Cycle 3: Operations / Stage 7

```text
Goal + DEPLOY-TDD PASS + exact NFR thresholds
  → ops intake
  → ops tests/drills + observed RED
  → stack-native configuration/playbooks
  → run ops tests
  → OPS-TDD-status PASS
  → selected post-deploy/ops evidence
  → Gate 7
```

Monitoring stack, observation window, SLO, rollback/alert thresholds, executor и owner не имеют
silent defaults. Если точного порога/authorization нет — BLOCKED. Operational action за пределами
разрешения заменяется рекомендацией/escalation, а не выполняется агентом.

## Goal и поздняя корректировка

`tracking/SDLC-goals.md` — revisioned Project profile. Он хранит route, enable flags,
deliverables, environments, executor/authorization и другие ответы. Project Console `8` меняет
Cycle 2/3 частично; затем `6` позволяет повторить только нужный Cycle.

Goal route не меняет состав внутреннего test-first loop каждого Cycle. Cycle 3 требует
подтверждённый Cycle 2 evidence, когда его scope зависит от deployment.

## Runtime routing

Profile format хранит runtime и, для Local, exact host/provider/model/endpoint. Policies:

```text
single       one profile
per-stage    stage/cycle routes
per-agent    exact role overrides
ask          resolve every needed step before Preview
```

Missing route/profile = BLOCKED. Route не наследуется между разными Projects. Local Repositories
имеет собственный routing profile и не наследует последнего SDLC Agent.

### Supervisor + Worker

```text
Primary/Supervisor (sole writer and gate signer)
  ├─ bounded question + allowed kind + project read scope
  ├─ Worker Claude/Codex/Local codex-oss (capability-enforced read-only)
  └─ verify findings against canonical files
```

Gemini/custom Local поддержаны как primary, но не workers. Worker environment строится allowlist,
nested delegation выключена, scope обязан находиться внутри configured project root.

## Scoped Review / Repair

Review scopes: `project`, `cycle:1..3`, `stage:0..7`, `agent:<id>`. Launcher вызывает
`s0-validate /review scope=...` с `--access read-only`; Claude/Codex/Local codex-oss adapters
применяют реальные tool/sandbox restrictions. Review возвращает findings в terminal.

Repair scopes совпадают и добавляют `structure`. `/repair` читает подтверждённые findings,
показывает files/excluded/tests, затем пишет только внутри scope. Недостающий product decision
не угадывается.

## Execution Journal internals

- `plan.md` immutable и содержит frozen step profiles/route sources.
- `state.md` записывается atomic rename; YAML-sensitive strings quoted.
- `events.jsonl` append-only JSON; raw prompts/stdout/secrets не сохраняются.
- `lease` сверяет PID + process start time.
- Resume point принимает только anchored `step_succeeded` и optional `step_skipped` events.
- Retry создаёт linked child run; исходный plan/history не переписываются.

## Local Repositories internals

Internal agents `l1-analyze`, `l2-setup`, `l3-build`, `l4-run` обслуживают code repository и
технические заметки. Это не SDLC Stage. Secrets не source/eval из repository `.env`, password
не переносятся в config, build не пропускает tests. Full pipeline прекращается как incomplete при
skip/failure. Pull требует чистого working tree и Preview; push запрещён. Batch update заметок
тоже показывает exact scope до запуска и прекращается на первом skip/failure.

## GitHub utility safety

GitHub utility запускается отдельно и меняет external state только после granular confirmations.
Commit flow: candidate preview → confirm stage → `git add -A` → staged secret/path scan без вывода
совпавших значений → staged stat → confirm commit → отдельно confirm push. PR не merge/rebase/push
автоматически. Force push/default history rewrite запрещены.

## Документационное управление

| Тип информации | Источник |
|---|---|
| Устойчивые принципы | `plans/principles.md` |
| Активный/future backlog | `plans/roadmap.md` |
| Связи и sync rules | `plans/document-map.md` |
| Gates/engineering rules | `_standards/*.md` |
| Runtime invariants | `_contract/*.md` |
| Роли/команды | agent `CLAUDE.md`, `.claude/commands/*.md` |
| Текущее использование | `README.md`, `GETTING_STARTED.md`, `OVERVIEW.md` |
| Подготовленные релизы | `CHANGELOG.md`, `RELEASE_NOTES_v*.md` |

Исполняемые shell scripts — реализация, не документация. Исторические release notes immutable.

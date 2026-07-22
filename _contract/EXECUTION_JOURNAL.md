# Execution Journal Contract

Execution Journal is the runtime-neutral source of truth for launcher
orchestration state. It belongs to one exact SDLC Project and one run; it is not
a Claude/Codex/Gemini/local conversation and not a global launcher checkpoint.

## Storage

Each project stores its own runs:

```text
$SDLC_PROJECTS_DIR/{PROJECT}/tracking/execution-journal/
├── README.md
└── runs/
    └── {run-id}/
        ├── plan.md
        ├── state.md
        ├── events.jsonl
        └── lease
```

The launcher may compute a cross-project dashboard, but no global index is the
source of truth. A run id is unique inside its project. Writes to plan/state use
temporary file + atomic rename. `lease` is process-local coordination metadata;
an empty/stale lease is not success evidence. A live lease matches both PID and
process start time, so PID reuse cannot keep a stale run locked.

## Immutable plan

`plan.md` is created before execution and is not rewritten after the run starts.
It records at minimum:

- run id, project name and absolute path;
- action type and exact included/excluded scope;
- goal profile revision when applicable;
- ordered step/agent/command list;
- effective runtime, host/provider/model status and route source per step;
- subagent mode, concurrency, exact worker profile and worker task policy when
  Supervisor + Worker is enabled;
- preconditions/TDD/Gate status known at preview time.

No raw prompt, vendor conversation, secret or model credential is stored.

## State

Run status is one of:

`PLANNED|READY|RUNNING|WAITING_USER|BLOCKED|INTERRUPTED|COMPLETED|CANCELLED`.

Step status is one of:

`PENDING|RUNNING|SUCCEEDED|FAILED|SKIPPED|INTERRUPTED|UNKNOWN`.

`state.md` records current run status, current/last confirmed step, totals,
updated timestamp and a concise reason. Output-file existence alone never proves
success. An unfinished `RUNNING` step observed without a live launcher is
`INTERRUPTED/UNKNOWN`, not `SUCCEEDED`.

## Events

`events.jsonl` is append-only. Every line is one JSON object containing at least
timestamp, event type, run status, step index/status when applicable, agent and
command when applicable, and concise evidence/reason. Events never include raw
prompts, stdout or secrets by default.
Resume accepts step progress only from structurally anchored success/optional-skip
events; numbers appearing inside evidence text do not advance the resume point.

## Resume and repair

Continue means resume orchestration after the last confirmed event. It never
means vendor session resume. Before retrying an interrupted/unknown mutation the
user must be offered read-only evidence review. Retry uses the immutable run
snapshot; changed goal/routing configuration requires a revised child run.

Repair creates a separate child run linked to the original run. It does not
rewrite the original plan, state history or events.

## Isolation and locking

- A mutating lock is no broader than exact project + run.
- Runs belonging to other projects remain readable and runnable.
- Switching Project Console never changes another project's journal.
- Read-only review does not require a global launcher lock.
- Runtime choice does not own or lock orchestration state.

## UI requirements

Project Console shows unfinished runs conservatively. Status code is accompanied
by a plain-language reason and safe next action. Detailed/compact view changes
only explanation density and never hides project, scope, status or blocker.

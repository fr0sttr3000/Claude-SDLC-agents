# Subagent Contract

Subagents are an optional execution capability available to every SDLC stage
and step. They do not create a second SDLC workflow and do not change artifact,
gate, security, or ownership contracts.

## Explicit settings

- `SDLC_SUBAGENTS=off|auto|cross-runtime` — default is `off`; the launcher asks explicitly.
- `SDLC_SUBAGENT_MAX=<1..16>` — maximum concurrent read-only workers.
- `SDLC_SUBAGENT_PROFILE=<runtime|provider|model|host|endpoint>` — required for
  `cross-runtime`; worker must be Claude, Codex or Local `codex-oss`; local worker
  requires exact provider/model. Gemini/custom local hosts are primary-only until
  they provide an enforceable read-only adapter.
- `SDLC_SUBAGENT_TASKS=analysis,research,review,test-interpretation` — explicit
  allowlist; a deployment or write-capable task kind is invalid.
- A runtime/agent host must report an explicit error when `auto` is requested
  but the selected host cannot provide subagents. It must not silently ignore
  the setting or switch runtime/model.

The dispatcher injects the selected policy into every task and interactive
prompt, including individually launched agents and every cycle step.

## Supervisor + Worker

In `cross-runtime` mode the primary step profile is the supervisor profile and
the explicit subagent profile is the worker profile. The profiles may use
different vendors or a cloud supervisor with an exact Local worker model.

- the supervisor decomposes work and creates every bounded packet;
- workers are invoked only through the universal read-only worker dispatcher;
- the supervisor must verify every finding against canonical files before use;
- worker output is advisory session data, not an SDLC artifact or gate evidence;
- the worker dispatcher starts from an environment allowlist and does not
  inherit supervisor secrets;
- worker failure is BLOCKED or explicit retry; no model/provider/runtime fallback;
- the execution Preview identifies supervisor and worker profiles separately.

## Ownership and write boundary

- The primary stage agent is the sole writer and the sole signer of its gate.
- Subagents are read-only: search, inspection, independent analysis, test-result
  interpretation and bounded review.
- A subagent cannot edit project files, execute deploy/auto-heal actions,
  approve a gate, create another SDLC role, or start nested subagents.
- The primary agent must verify subagent findings against canonical files before
  using them and remains accountable for the result.

## Context isolation

Each assignment must contain a bounded packet:

1. one allowed task kind;
2. one concrete question;
3. explicit input paths/read scope;
4. required response format;
5. prohibition on writes and nested delegation.

The absolute read scope must resolve strictly inside the configured project root;
filesystem root, HOME and paths outside that root are rejected.

Do not pass conversation history, secrets, sibling subagent results, or
unbounded project context. Subagent findings return to the primary agent in the
runtime session; canonical hand-off between SDLC stages remains file-only.

## Suitable work

- parallel read-only analysis of requirements, architecture or code;
- independent risk, security, test or operational review;
- mapping requirements to tests;
- interpretation of logs, metrics and validation reports.
- Cycle 2: infrastructure discovery, deploy-test design, supply-chain/policy
  review and independent validation-evidence analysis;
- Cycle 3: observability-stack, failure-scenario, incident/dedup, capacity and
  disaster-recovery evidence review.

Subagents must not execute deploy, rollback, production failure injection,
live drill, auto-heal or any other operational action. They must not edit a
test manifest or Cycle 2/3 status file.

Do not delegate a task when it is too small to benefit, requires a single
coherent write, or would cross the primary agent's authorization boundary.

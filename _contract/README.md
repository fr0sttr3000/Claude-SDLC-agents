# Universal Runtime Contract

The SDLC Agent System can be executed through multiple AI runtimes while keeping one set of rules.

## Canonical Sources

- `_standards/*.md` — TDD, quality, security, data formats, templates
- root `CLAUDE.md` — global SDLC context and behavioral rules
- `cycle*/{agent}/CLAUDE.md` — role-specific agent contracts
- `.claude/commands/*.md` — shared command prompt templates

`sdlc.sh`, `localrun.sh`, `_runtimes/*.sh` and validators are executable implementation which must
conform to the canonical Markdown contracts; they are evidence, not documentation sources.
Documentation ownership and its relationship to
implementation are described in `plans/document-map.md`. Stable principles remain in
`plans/principles.md`; active product work remains in `plans/roadmap.md`.

## Runtime Adapters

- Claude: `CLAUDE.md`, `.claude/commands/*.md`, `_runtimes/adapters/claude.md`
- Codex: `AGENTS.md`, `.codex/config.toml`, `_runtimes/adapters/codex.md`
- Gemini: `GEMINI.md`, `_runtimes/adapters/gemini.md`
- Local: `_runtimes/adapters/local.md`; exact registered agent host, provider and model id

Built-in `codex-oss` supports Ollama and LM Studio. vLLM, llama.cpp and OpenAI-compatible
endpoints require a registered executable agent-host adapter. A raw endpoint alone is not an
SDLC agent runtime. Routing is explicitly `single|per-stage|per-agent|ask`; missing profiles
fail instead of falling back to another model/provider/runtime.

## TDD and Subagents

`_standards/tdd.md` defines Specify → Red → Green → Run → Repair → Refactor for every
applicable change. `_contract/SUBAGENTS.md` defines optional `off|auto|cross-runtime` bounded
read-only subagents on every step. In Supervisor + Worker mode the primary profile remains the
sole artifact writer/gate signer and verifies output from an explicit worker profile invoked by
`_runtimes/subagent-run.sh`; worker failure never enables fallback.
Worker access is capability-enforced for Claude, Codex and Local `codex-oss`. Gemini and
custom local hosts remain valid primary profiles but are not accepted as workers.

## Project Directory Modes

`sdlc.sh` supports two explicit modes:
- collection mode: `SDLC_PROJECTS_DIR` points to a directory containing multiple project folders;
- single-project mode: the user selects one project folder, `SDLC_PROJECTS_DIR` stores its parent directory, and `SDLC_SINGLE_PROJECT` stores the selected project name.

Agents must continue using the canonical path contract `$SDLC_PROJECTS_DIR/{PROJECT}/...`.

## Execution Journal

`_contract/EXECUTION_JOURNAL.md` defines the per-project, per-run orchestration
state, immutable plan snapshot, statuses, append-only events, safe resume and
isolation. It does not use vendor conversation resume or a global checkpoint.

## Rule

Vendor-specific adapter files may explain how to run the system, but they must not define unique SDLC behavior. New behavior belongs in the canonical sources above.

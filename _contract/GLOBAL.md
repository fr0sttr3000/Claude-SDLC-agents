# Universal SDLC Agent Contract

This directory is the vendor-neutral contract for SDLC agents.

The contract is canonical for cross-runtime behavior:
- SDLC stages, gates, DoR/DoD, standards, and artifact paths do not depend on a specific AI runtime.
- Runtime-specific files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/`, `.codex/`, `.gemini/`) are adapters.
- New SDLC rules must be added to `_standards/`, root `CLAUDE.md`, agent `CLAUDE.md`, or command templates before they are exposed through a runtime adapter.

## Compatibility Rule

Claude-compatible files remain the canonical authoring format for agents:
- root `CLAUDE.md` = global SDLC context
- `cycle*/{agent}/CLAUDE.md` = role-specific context
- `.claude/commands/*.md` = shared command templates
- `_standards/*.md` = mandatory standards

Codex and Gemini adapters must read or reference the same files instead of maintaining independent copies of SDLC logic.

## Product Documentation Governance

Product principles and development plans are kept separately from the runtime contract:
- `plans/principles.md` — stable product principles; it must remain a separate canonical document;
- `plans/roadmap.md` — active and long-term product plans;
- `plans/document-map.md` — document ownership, relationships, and synchronization rules.

Executable launcher and dispatcher scripts are implementation, not documentation. `CHANGELOG.md`
and release notes are updated during release preparation rather than used as the active backlog.

## Runtime Invariants

Every runtime must preserve:
- Markdown-first governance through `$SDLC_PROJECTS_DIR/{PROJECT}/...`; executable tests,
  code, API/schema, SQL/IaC and other native artifacts retain their native formats
- `SDLC_PROJECTS_DIR` as the parent directory of projects; in single-project launcher mode the active project is tracked separately through `SDLC_SINGLE_PROJECT`
- isolated agents; no direct agent-to-agent memory transfer
- explicit file contracts in `inputs/`, `outputs/`, and `tracking/`
- Quality Gate + Security Gate enforcement
- secrets only through `pass`
- no hardcoded local user paths
- explicit runtime/model selection; local profiles require an exact agent host,
  provider and model id
- hybrid routing policy is exactly `single|per-stage|per-agent|ask`; every
  resolved step has one explicit profile
- no default model and no silent fallback between models, providers or runtimes
- optional subagents follow `_contract/SUBAGENTS.md`; the primary stage agent
  remains the sole writer and gate signer
- cross-runtime Supervisor + Worker mode uses one explicit worker profile and
  task allowlist; the supervisor verifies every finding and worker failure never
  causes silent fallback
- capability-enforced workers are Claude, Codex and Local `codex-oss`; Gemini and
  custom local hosts may be primary profiles but are rejected as workers until an
  enforceable read-only adapter exists
- launcher orchestration state follows `_contract/EXECUTION_JOURNAL.md`; it is
  isolated by project+run and never owned by a vendor session

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

## Runtime Invariants

Every runtime must preserve:
- Markdown-first artifact exchange through `$SDLC_PROJECTS_DIR/{PROJECT}/...`
- `SDLC_PROJECTS_DIR` as the parent directory of projects; in single-project launcher mode the active project is tracked separately through `SDLC_SINGLE_PROJECT`
- isolated agents; no direct agent-to-agent memory transfer
- explicit file contracts in `inputs/`, `outputs/`, and `tracking/`
- Quality Gate + Security Gate enforcement
- secrets only through `pass`
- no hardcoded local user paths

# Universal Runtime Contract

The SDLC Agent System can be executed through multiple AI runtimes while keeping one set of rules.

## Canonical Sources

- `_standards/*.md` — quality, security, data formats, templates
- root `CLAUDE.md` — global SDLC context and behavioral rules
- `cycle*/{agent}/CLAUDE.md` — role-specific agent contracts
- `.claude/commands/*.md` — shared command prompt templates
- `sdlc.sh` / `localrun.sh` — workflow orchestration

## Runtime Adapters

- Claude: `CLAUDE.md`, `.claude/commands/*.md`, `_runtimes/adapters/claude.md`
- Codex: `AGENTS.md`, `.codex/config.toml`, `_runtimes/adapters/codex.md`
- Gemini: `GEMINI.md`, `_runtimes/adapters/gemini.md`

## Project Directory Modes

`sdlc.sh` supports two explicit modes:
- collection mode: `SDLC_PROJECTS_DIR` points to a directory containing multiple project folders;
- single-project mode: the user selects one project folder, `SDLC_PROJECTS_DIR` stores its parent directory, and `SDLC_SINGLE_PROJECT` stores the selected project name.

Agents must continue using the canonical path contract `$SDLC_PROJECTS_DIR/{PROJECT}/...`.

## Rule

Vendor-specific adapter files may explain how to run the system, but they must not define unique SDLC behavior. New behavior belongs in the canonical sources above.

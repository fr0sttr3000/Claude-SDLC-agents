# Gemini Adapter — SDLC Agent System

This repository keeps Claude-compatible files as the canonical agent authoring format.

When working with Gemini:
- Read root `CLAUDE.md` as the global SDLC context.
- Read the nearest agent `CLAUDE.md` as the role-specific instruction.
- Treat `_standards/*.md` as mandatory standards.
- Treat `.claude/commands/*.md` as shared command templates.
- Do not introduce Gemini-only SDLC rules, gates, agents, or artifact contracts.
- If a new rule is needed, add it to `_standards/`, root `CLAUDE.md`, an agent `CLAUDE.md`, or a shared command template first.

Gemini runtime:
```bash
AGENT_RUNTIME=gemini bash sdlc.sh
```

If the Gemini CLI binary has a different name:
```bash
GEMINI_BIN=/path/to/gemini AGENT_RUNTIME=gemini bash sdlc.sh
```

See `_contract/GLOBAL.md` and `_runtimes/adapters/gemini.md`.

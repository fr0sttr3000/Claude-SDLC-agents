# Codex Adapter — SDLC Agent System

This repository keeps Claude-compatible files as the canonical agent authoring format.

When working with Codex:
- Read root `CLAUDE.md` as the global SDLC context.
- Read the nearest agent `CLAUDE.md` as the role-specific instruction.
- Treat `_standards/*.md` as mandatory standards.
- Treat `.claude/commands/*.md` as shared command templates.
- Do not introduce Codex-only SDLC rules, gates, agents, or artifact contracts.
- If a new rule is needed, add it to `_standards/`, root `CLAUDE.md`, an agent `CLAUDE.md`, or a shared command template first.

Codex runtime:
```bash
AGENT_RUNTIME=codex bash sdlc.sh
```

First run asks for an explicit runtime and project mode:
```bash
bash sdlc.sh
```

Claude can be selected explicitly:
```bash
AGENT_RUNTIME=claude bash sdlc.sh
```

See `_contract/GLOBAL.md` and `_runtimes/adapters/codex.md`.

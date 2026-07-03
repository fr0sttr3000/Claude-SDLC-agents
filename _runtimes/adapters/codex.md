# Codex Runtime Adapter

Codex is supported through `AGENT_RUNTIME=codex`.

Invocation:
```bash
AGENT_RUNTIME=codex bash sdlc.sh
```

The adapter uses:
- `AGENTS.md` as a bridge to the canonical `CLAUDE.md` files
- `.codex/config.toml` to include `CLAUDE.md` as a fallback instruction file
- the same `.claude/commands/*.md` templates as Claude
- `codex exec --cd "$AGENT_DIR" "$PROMPT"` for task mode

The dispatcher passes `--cd` so Codex uses the selected agent directory as its working root. Codex-specific skills or hooks may be added later, but they must not become the source of SDLC rules. All rules stay in `_standards/`, root `CLAUDE.md`, agent `CLAUDE.md`, and shared command templates.

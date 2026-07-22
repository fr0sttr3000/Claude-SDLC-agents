# Gemini Runtime Adapter

Gemini is supported through `AGENT_RUNTIME=gemini`.

Invocation:
```bash
AGENT_RUNTIME=gemini bash sdlc.sh
```

The adapter uses:
- `GEMINI.md` as a bridge to the canonical `CLAUDE.md` files
- the same `.claude/commands/*.md` templates as Claude
- `gemini -p "$PROMPT"` for task mode

If the Gemini CLI binary has a different name, set:
```bash
GEMINI_BIN=/path/to/gemini AGENT_RUNTIME=gemini bash sdlc.sh
```

Gemini-specific commands may be generated later, but they must reference the universal contract instead of duplicating SDLC logic.

Gemini is supported as a primary profile. It is currently rejected for Review/Worker
actions that require capability-enforced read-only access; no prompt-only fallback is used.

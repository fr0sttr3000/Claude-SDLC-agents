# Claude Runtime Adapter

Claude is one supported runtime. The launcher does not select it implicitly; choose it with `AGENT_RUNTIME=claude` or in settings.

Invocation:
```bash
AGENT_RUNTIME=claude bash sdlc.sh
```

The adapter uses:
- root `CLAUDE.md`
- nearest agent `CLAUDE.md`
- `.claude/commands/*.md`
- `claude "$PROMPT"` for task mode
- `claude "начни сессию"` and `claude --continue` for interactive mode

No SDLC logic is stored in this adapter. It only describes how the universal contract is executed by Claude Code.

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
- `claude --print --no-session-persistence "$PROMPT"` for task mode
- read-only task mode additionally limits tools to `Read,Glob,Grep` and uses `dontAsk`
- normal interactive/continue mode remains available only for write-capable actions

No SDLC logic is stored in this adapter. It only describes how the universal contract is executed by Claude Code.

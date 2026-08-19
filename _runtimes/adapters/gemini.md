# Gemini Runtime Adapter

Gemini is available as an explicitly selected launcher profile. User launch and
profile-selection instructions exist only in `README.md`.

The adapter uses:
- `GEMINI.md` as a bridge to the canonical `CLAUDE.md` files
- the same `.claude/commands/*.md` templates as Claude
- `gemini -p "$PROMPT"` for task mode

The adapter accepts the launcher-resolved `GEMINI_BIN` executable. User configuration examples
exist only in `README.md`.

Before Gemini starts, the shared dispatcher applies Runtime Access v1 through Linux Landlock.
Public canon is read-only, exact Project/notes rights follow command access, and ambient HOME,
siblings and runtime-denied roots receive no capability. Missing support or enforcement fails
closed.

Gemini-specific commands may be generated later, but they must reference the universal contract instead of duplicating SDLC logic.

Gemini is supported as a primary profile. It is currently rejected for Review/Worker
actions that require capability-enforced read-only access; no prompt-only fallback is used.

# Command Capabilities v1

`command-capabilities-v1.tsv` is the authoritative registry for every active command template
under `cycle1-dev/` and `_tools/`.

The exact TSV header is:

```text
schema_version	agent	command	capability	access	result_verifier	metadata_stages	metadata_types
```

Allowed capabilities:

- `read-only-no-output` — the runtime is forced to `read-only`; exit code `0` may produce
  `READ_ONLY_VERIFIED`, but never `ARTIFACT_VERIFIED`.
- `mutating-declared-output` — every required output group must be created or changed and
  validated for the current execution. Its registry access is normally `write`; Stage 4 uses
  `scoped-write` and additionally requires a current approved Change Scope plus a verified
  full-Project diff.
- `orchestrated-special` — generic One Agent and Cycle dispatch are forbidden. A dedicated
  launcher workflow owns preview, authorization and its named result verifier.

An active command missing from the registry is `BLOCKED`. A registry row classified as
`mutating-declared-output` without a launcher declared-output mapping is also invalid.
Every command that produces Project Markdown also declares allowed `metadata_stages` and
`metadata_types`; the executing agent id is the expected `producer`. A changed Markdown file
whose owner, stage or type differs from that row is `UNVERIFIED`.
`process-exit` is valid only for a capability-enforced read-only command. External effects,
secrets, repair, kickoff and Local Repositories cannot be accepted from
process exit alone.

The generic One Agent menu is derived from this registry and displays only
`read-only-no-output` and `mutating-declared-output` commands. Special commands remain
available only through their dedicated launcher workflows.

`scoped-write` is valid only for `orchestrated-special` Change Scope preparation commands and
the five Stage 4 mutators named by Change Scope v1. A generic process exit or declared output
alone cannot verify either class. L1/S3 preparation has dedicated directory/diff verification;
Stage 4 requires `change-scope-and-declared-output`.

Tracker mutations are exposed through Project Utilities → Tracker. The launcher collects the
exact task/sprint arguments before Preview, executes the registered command with Project write
access, and accepts it only after its registry-named postconditions verify synchronized task
state, DoD, governance ledgers, or sprint state as applicable. Runtime exit `0` without that
postcondition remains `UNVERIFIED`.

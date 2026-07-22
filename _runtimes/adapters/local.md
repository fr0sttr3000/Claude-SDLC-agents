# Local Model Runtime Adapter

Local inference is selected explicitly with `AGENT_RUNTIME=local`. A local
model endpoint alone is not an SDLC agent: an **agent host** must provide file
reading, tool execution, instruction loading and the write boundary required by
the Universal Runtime Contract.

## Required explicit values

```bash
AGENT_RUNTIME=local
LOCAL_AGENT_HOST=codex-oss
LOCAL_MODEL_PROVIDER=ollama
LOCAL_MODEL=qwen2.5-coder:14b
```

There is no default provider, model, agent host or silent fallback. An
unavailable host/model stops the step.

## Built-in host

`codex-oss` is the bundled agent host. It invokes Codex with `--oss`, exact
`--local-provider ollama|lmstudio`, and exact `--model`. Ollama and LM Studio
are inference providers, not a closed list of model families.

## Registered custom hosts

Administrators may add an executable adapter to the registered host directory
`_runtimes/local-hosts/` (or an explicitly supplied test/admin registry).
Configuration stores only its validated host id, never an arbitrary shell
command. Adapters may integrate vLLM, llama.cpp or another OpenAI-compatible
server, but they must implement the agent-host contract and accept:

```
--agent-dir <absolute path> --mode <task|interactive|session-start|continue> \
--access <write|read-only> --prompt <text>
```

The dispatcher passes `LOCAL_MODEL_PROVIDER`, `LOCAL_MODEL`,
`SDLC_SUBAGENTS` and `SDLC_SUBAGENT_MAX` as environment variables. Adapter
files must not contain credentials; secrets remain in `pass`.

## Supervisor + Local Worker

A cloud or Local primary profile may supervise a separate exact Local worker profile with
`SDLC_SUBAGENTS=cross-runtime`. `_runtimes/subagent-run.sh` accepts only an allowed read-only
task kind, one bounded task, an absolute read scope and a response format. It invokes this
adapter with nested subagents disabled. Built-in `codex-oss` additionally enforces Codex
`--sandbox read-only --ephemeral` and rejects interactive worker sessions. The Supervisor verifies all findings and remains the
only writer/gate signer; worker failure is BLOCKED or explicit retry, never fallback.
The worker process receives an explicit environment allowlist rather than the Supervisor's
full environment, so unrelated credentials and secret variables are not inherited.
Custom hosts remain valid primary adapters, but cross-runtime workers are restricted to
the built-in `codex-oss` until a custom adapter's read-only capability is registered/enforced.

## Hybrid routing

The launcher supports four explicit policies:

- `single` — one profile for all steps;
- `per-stage` — an exact profile for each overridden stage;
- `per-agent` — an exact profile for each overridden agent;
- `ask` — explicit selection before each step.

Each resolved step has one exact runtime/profile. Missing mapping is an error in
`per-stage` and `per-agent`; it never falls back to the global/cloud runtime.
Routing changes orchestration only and does not change canonical agent rules.

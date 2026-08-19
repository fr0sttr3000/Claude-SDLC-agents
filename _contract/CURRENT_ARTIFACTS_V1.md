# Current Artifacts Contract v1

Cycle 1 preserves date-versioned artifacts as history. Consumers never infer the current
artifact from the newest timestamp or from every file matching a glob.

## Authoritative registry

`_contract/current-artifact-groups-v1.tsv` is the single registry for declared output groups.
Each row binds:

`agent`, `command`, `group_index`, stable `logical_id`, `cardinality`,
`track_current` and compatible `path_patterns`.

`path_patterns` may contain historical and current naming alternatives separated by `|`.
They are compatibility patterns, not permission to rename or delete old artifacts.
`one-or-more` is used when one invocation creates a set or when repeated immutable
invocations append members to one current set, for example per-PR summaries/reviews. Updating
one such command preserves and revalidates every earlier current member; it never replaces the
set with only the latest invocation. PR logical ids derive a stable member key from the
registered filename's `PR<key>` component. A new immutable artifact with the same logical
id/key replaces only that current member; another PR key is never removed. Duplicate keys in
one invocation or manifest are invalid.

The canonical 28-step order and Gate/DoD/completion boundaries are stored separately in
`_contract/cycle1-steps-v1.tsv`. Launcher code and completion proof read this registry; they do
not maintain a second hard-coded step list.

Normally one logical id has one owner command. The intentional shared artifacts are declared
in `_contract/shared-artifact-lifecycles-v1.tsv` with exact owners and ordering semantics.
An undeclared duplicate logical-id owner is a contract error.

## Project current manifest

After a mutating command changes and validates every declared output group, the launcher
atomically updates:

`tracking/current-artifacts-v1.tsv`

Exact header:

```text
schema_version	logical_id	member_index	artifact_ref	artifact_sha256	producer	command	output_group	source_revision	product_profile_revision	run_id	plan_sha256	recorded_at
```

Rows select the exact current member or current set for a logical id. Every reference is
Project-relative, digest-bound, registry-compatible and tied to the launcher run and immutable
plan which produced it. After explicit Preview confirmation, a new full Cycle 1 atomically
starts an empty manifest generation before its first step; this prevents old downstream rows
from influencing early Gates. A Product Profile revision change also invalidates prior current
rows. The new Cycle repopulates the manifest without deleting historical artifacts.
If execution continues through Retry, current rows may belong only to the exact linear
root/Retry run chain validated by the launcher. The root retains the immutable full plan;
each child retains its exact remaining suffix. Unrelated or historical run ids cannot satisfy
completion.

Groups with `track_current: no` remain declared outputs but are not inserted into the manifest.
This applies to historical snapshots and final completion/release artifacts whose own contracts
already provide stable exact paths and digests.

An update is transactional even when a producer legitimately rewrites the same registered
current path: only logical ids declared and changed by that invocation may replace their stale
pre-update digest. Every other manifest row is fully revalidated first; unrelated drift or
tampering blocks the update. The newly written manifest is then validated without exclusions.

## Resolution and migration

Use:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/current-artifact.sh" \
  resolve-one "$SDLC_PROJECTS_DIR/{PROJECT}" requirements-traceability
```

If a valid current manifest exists, resolution is exclusively manifest-based; a missing,
stale, digest-mismatched or ambiguous row is `BLOCKED`. Consumers must not fall back to an old
glob after manifest validation fails.

During additive migration only, `resolve-compatible` may read registry-compatible legacy
names when the manifest does not exist at all. It requires the registered cardinality and
reports `LEGACY / UNVERIFIED` on stderr. Such compatibility supports existing gates and explicit
migration, but verified Cycle 1 completion always requires a complete manifest for the exact
full-cycle root/Retry chain.

Old files remain immutable history. No compatibility reader silently renames, overwrites or
deletes them.

# Traceability Index Contract v1

`tracking/traceability-v1.tsv` is the machine index that resolves Evidence v1 trace ids to
existing project artifacts while keeping each agent's file handoff isolated. It is UTF-8 TSV
with this exact header:

```text
requirement_id	requirement_uri	specification_id	specification_uri	test_id	test_uri	source_revision
```

Every row binds one requirement → specification → test tuple to the exact code/source revision.
URIs are safe project-relative regular files, not URLs or symlinks, and each target contains its
declared id. Evidence record fields `requirement_ids`, `specification_ids`, `test_ids` are
comma-separated, have equal length, and every zipped tuple must resolve exactly once. Missing,
duplicate, traversal, wrong-source or dangling links return `TRACE BLOCKED`.

The index is a handoff map, not a second agent registry and not a replacement for BRD/RTM,
architecture/specification or native tests.

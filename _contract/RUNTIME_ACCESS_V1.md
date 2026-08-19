# Runtime Access Contract v1

Every supported primary cycle/tool process uses the same capability-enforced filesystem
matrix from `runtime-access-v1.tsv`. Vendor prompts and vendor sandboxes are defense in depth;
they do not replace this boundary.

The dispatcher canonicalizes every scope before launch. Public agent canon is readable but not
writable. The exact Project and optional notes directory are readable in both task access modes
and writable only for `access=write`. A per-process isolated runtime directory is the only
non-Project scratch capability. Ambient `HOME`, sibling Projects and every unspecified local
path receive no capability. The runtime executable must be outside ambient `HOME`, unless it
is itself part of the read-only public agent system.

Checkout VCS metadata and every configured runtime-denied root are subtracted from otherwise
readable canon. Canonical path, symlink target and directory inode aliases are checked before
capabilities are issued. A symlink inside an allowed scope does not grant access to a target
outside that scope.

The Landlock helper accepts only explicit `--read`, `--write` and `--deny` paths. It never
starts from a writable filesystem root. Missing helper source, compiler, kernel support,
canonicalization or enforcement returns `BLOCKED` before the model runtime starts.

The isolated runtime directory supplies process-local `HOME` and `TMPDIR` and is removed
after the process. Opening `/dev/null` is the only device write needed by the dispatcher.
It is not Project output and cannot widen another path capability.

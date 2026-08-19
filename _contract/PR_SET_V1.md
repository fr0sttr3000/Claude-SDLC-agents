# Gate 4 PR Set Contract v1

Gate 4 evaluates the complete current PR set, not only the most recent review invocation.
The current logical ids `development-pr-summary`, `development-update-notes` and
`techlead-reviews` are `one-or-more` sets with one member for every PR in the implementation
unit.

The immutable filenames carry the same PR key:

- `DEV-*-PR-<key>-summary.md`;
- `DEV-*-update-notes-PR<key>.md`;
- `TL-*-review-PR<key>.md`.

Every set has exactly the same keys, with no duplicate member. Summary, update notes and review
for one key have the same exact `source_revision`; the review status is `PASS` and its
decision is approved without BLOCKER/MAJOR. `gate4-pr-set-check.sh` runs full PR Evidence v1
validation for every distinct source in the set. Missing an earlier PR, keeping a stale digest
or replacing a current set with only the latest member blocks Gate 4.

The `development-pr-summary` set is the canonical inventory for the current implementation
unit; update-notes and review keys must equal it exactly. Current Artifacts derives each stable
member key from the registered immutable filename. Re-running one PR creates a new immutable
summary/notes/review with the same key and a new exact source revision; reconciliation replaces
only that key and retains every other member. Removing a PR is not an incremental side effect:
it requires a new explicitly previewed full-Cycle manifest generation (or a future dedicated
inventory-change contract), while historical files remain unchanged.

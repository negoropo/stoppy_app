# Internal GP execution (Session 46, Steps 2-3)

`GpService.credit/debit` accept a trusted, stable `GpCommand`, not an HTTP DTO.
Only future authenticated business services may choose the player, amount,
reason and source after eligibility/validation. There is no route or live
producer. Rewards, fees, purchases and ads remain disconnected.
Accounts need an existing opening snapshot; missing baselines fail closed.
Registration now calls `GpRepository.createOpeningSnapshot` on the same connection
after inserting the player and before inserting the session/refresh credential.
The database default remains exactly 5 GP. The snapshot reads that balance with
delta 0, identical before/after balances, canonical player-ID source and no mutation
reference. It is an observation, not an additional +5 credit. A baseline conflict
or any later registration write failure aborts the entire transaction; uncertain
COMMITs are never automatically retried. Migration 003's existing-account backfill
is unchanged. No other production player-creation path exists currently.

One `inTransaction` call owns one connection. The transaction explicitly uses
READ COMMITTED and locks the player row before reading mutation/source identity
or deciding funds. All writers must follow this ordering. A waiter re-reads the
committed mutation, so immutable final-only rows require no pending record.
No other player is locked and no nested transaction/connection is acquired.

The guarded update widens arithmetic to bigint before checking/casting to int4.
Accepted writes are balance, final mutation, then ledger, then COMMIT. Migration
003's immediate accepted/same-player foreign key requires this ordering: a test
inserting the ledger before the final mutation would violate the approved schema.
Fault tests therefore cover after balance, after mutation and after ledger before
commit. All effects roll back together. No corrective migration is necessary.

V1 fingerprints SHA-256 a canonical JSON object with a format/version tag,
direction, player, operation/version, amount, reason, source and stable context.
Object keys are sorted recursively; array order and JSON types remain distinct.
Only JSON values with safe integer numbers are allowed; unsupported values,
accessors, sparse arrays, deep/oversized intent and implicit coercion are rejected.
Inputs are snapshotted before awaiting the connection. The key is scoped by
player/operation/version and is not itself part of the fingerprint.

Callers retain the original command and key for an explicit retry. Never resolve
a new current season/tournament/day for a retry: carry the original stable
business identity. The executor performs no current-period resolution and checks
durable outcomes before balance/source business decisions. No automatic retry
exists. Invalid intent is a programming error (`InvalidGpIntent`); missing player
and key conflict are distinct results. Insufficient funds, overflow and duplicate
source are durable final rejections. Unexpected SQL/connection failures are never
business rejections. COMMIT/acknowledgement failure is explicitly outcome-unknown;
the existing transaction utility discards the connection without replaying it.

Replay returns the exact original semantic outcome and a separate locked
`currentBalance`. Historical outcome balances are never written back. Different
keys cannot reapply the same player/source-type/source-ID; the second attempt
records a duplicate-source rejection without a ledger movement. Database unique
constraints remain the final backstop; unexpected constraint errors roll back,
not masquerade as accepted/rejected results.

Opening snapshots are zero-delta observations, not earned credits. Reconciliation
is opening balance plus SUM(committed deltas), independent of row ordering.
Player locking serializes effects, but timestamp/UUID order is not a canonical
movement sequence (timestamps may precede lock waits). A future ordered statement
would need a reviewed sequence design; aggregate reconciliation does not need a
new sequence or migration now. Runtime roles must not own audit tables or have
DDL privileges. No external writer may bypass the service's transaction/lock
discipline. Identity, run legitimacy and competitive authority remain server-side
business responsibilities, not assertions proven by this internal primitive.

Deployment must block/drain old registration workers before migration 003 and
resume registration only on updated workers after the migration and baseline
verification. A normal mixed-version rolling deployment is unsafe. See
`../../README.md` for the count-only verification query, migration/runtime role
separation and minimum runtime grants. Restricted-role integration tests exercise
the actual application transactions through a separate non-owner login; production
privileges still require independent deployment verification. Permitted wallet
UPDATE and ledger INSERT grants do not themselves enforce cross-table coupling;
all trusted business writers must continue using the economy transaction boundary.

# Backend Plan

## Session 47 Part 4 Internal Knockout Registration

`KnockoutRegistrationService.register({playerId, tournamentId, idempotencyKey})`
atomically admits a trusted authenticated player to an existing trusted tournament
and debits exactly 25 GP through the transaction-bound `GpExecutor`. The repository
uses migration 004 unchanged. No HTTP registration handler is active; Flutter
backend registration is not end-to-end operational against this server.
Provisioning, lifecycle jobs, brackets, run validation, League integration and
gameplay/daily/warmup GP rewards remain deferred. Earlier inventories are historical.

Lock order is shared tournament advisory lock, player row lock, business replay /
duplicate checks, then financial and business writes. Lifecycle writers MUST take
the exclusive transaction advisory lock with the same key expression before any
catalog updates/deletes: `hashtextextended('stoppy.knockout.tournament:' || id::text, 0)`.
They must not acquire player locks first. Shared advisory locking needs no catalog
UPDATE grant. The timestamp correction needs column-specific INSERT grants for
`registered_at`, `created_at` and `completed_at` (see `backend/README.md`); it adds
no UPDATE, ownership or schema privileges. No lifecycle
writer is implemented here. Direct privileged SQL bypassing this protocol is not
covered by the concurrency guarantee.

Admission is linearized at a fresh `clock_timestamp()` sample after lock waits,
with comparisons performed in PostgreSQL at full timestamp precision. Opening is
inclusive, closing exclusive; unavailable, closed or already-started state denies
admission. This is admission-time eligibility, not a requirement that the final
COMMIT acknowledgement arrive before closing. Closure waits for an in-flight
registration's shared lock when it follows the protocol.
The captured admission instant is reused without microsecond loss for registration
and business creation timestamps. Completion uses its finalization clock, clamped
to creation against backward clock steps; it does not reevaluate admission.

Business scope is `knockout_register` V1; fingerprint V1 includes player and explicit
trusted tournament. Fee scope is `knockout_registration_fee` V1, with the same
player/key, fixed 25 GP amount and reason/source type `knockout_registration`.
A domain-separated SHA-256-derived UUIDv8 identifies the registration deterministically
from the business fingerprint and key. It is not an authentication secret. Source
is `<tournament UUID>:<registration UUID>`; context names the business operation,
version and both IDs. An explicit retry after a rolled-back uncertain COMMIT
reconstructs the exact same financial intent. Business replay precedes fresh
eligibility/funds decisions and never charges twice.

Infrastructure failures and uncertain commits are sanitized exceptions, never
durable business rejections, and are never automatically retried. Outcomes retain
historical balances, separate from any current profile. Insufficient funds persist
both GP and business rejections without a movement; a new attempt needs a new key.
Missing players and key conflicts are distinct non-persisted results. Success is
provisional until outer COMMIT succeeds.

The future empty-body HTTP boundary must retain the first resolved tournament
for a logical key before resolving a new current month, or replay the stored
operation directly; it must never silently retarget retries. An explicit changed
target conflicts here. HTTP mapping must distinguish historical outcome balances
from a separately fetched current profile and respect existing DTO consistency
constraints. Monthly scheduling policy and HTTP-boundary resolution remain deferred.

## Session 47 Part 3 Persistence Foundation

Migration 004 prepares trusted Knockout tournament metadata, paid-registration
evidence and durable business-operation outcomes in `stoppy_knockout`. It does
not activate registration: no business service/repository, endpoint, scheduler,
catalog provisioning or brackets are implemented. Prior session descriptions
below are historical; see `Persistence_Map.md` for the implemented schema.

The unique month is a trusted Portugal-calendar `date` label. Persisted absolute
windows use inclusive opening and exclusive closing, strictly before tournament
start; no calendar policy is inferred. The relationship to the previous tournament's
end remains a future provisioning/business-service decision.

Future registration must resolve trusted tournament state and authenticated player
identity, then atomically persist the fixed 25 GP debit, registration and final
business result using the existing transaction-bound `GpExecutor`. Database FKs
bind registration to a same-player accepted debit; unique constraints prevent a
second registration or reused financial evidence. Scoped idempotency keys and
versioned fingerprints support explicit same-key recovery, never automatic replay
of uncertain operations. Business outcomes are separate from GP mutation outcomes.
These guarantees are tested with real PostgreSQL and a restricted non-owner role;
they do not establish deployment grants or implement business eligibility checks.

## Session 45 Authentication Implementation (Pending Review)

The server now implements registration, login, strict refresh rotation and
authenticated profile retrieval against PostgreSQL. Migration 002 introduces
`stoppy_auth.players`, `auth_sessions` and `auth_refresh_tokens`. Account identity
is server-generated; only Argon2id password hashes and refresh-token digests
persist. Initial GP is 5; no economy or competitive mutation is implemented.
Flutter contracts and default mock runtime are unchanged. Remote logout remains
deferred; see `backend/README.md` for the temporary credential policies and
production blockers. The Session 44 description below is historical.

## Session 44 Implemented Foundation

The isolated `backend/` application now uses Node.js 24, TypeScript, Fastify and
the `pg` PostgreSQL driver. It implements only operational health/readiness,
configuration validation, bounded connection pooling, safe API errors and
explicit versioned SQL migrations. See `backend/README.md` for setup and tests.

Fastify provides HTTP routing, injection-based tests and orderly shutdown. A
small SQL migration runner keeps ordered files/checksums in
`public.stoppy_schema_migrations`, serializes execution with a transaction-scoped
advisory lock, and commits/rolls back a whole batch on one acquired connection.
Migration 001 creates an empty infrastructure namespace only. Database startup
connectivity is mandatory; migrations are a separate operator command.

This is the first server implementation, not the implementation of the Flutter
feature endpoints prepared in Sessions 31-43. Auth/JWT, GP, purchases, League,
Knockout, run validation, server-side mutation-idempotency records, settlement
and anti-cheat enforcement remain future server work. No client score is
accepted or persisted by this foundation. Flutter remains mock-first and its
existing opt-in backend contracts are unchanged.

## Architecture

### Client

- Flutter App

### Backend

- Custom Backend API
- Node.js / TypeScript / Fastify foundation in `backend/`
- REST API
- Server-authoritative competitive logic

### Database

- PostgreSQL
- `pg` connection adapter and infrastructure-only SQL migrations

### Optional Future Components

- Redis
- Background Workers
- Replay/Event Storage

## Responsibilities

### Client

- UI
- Local animations
- Input collection
- Temporary state

The client should remain responsive and ergonomic, but it must not be trusted for competitive or economy decisions.

### Server

- Authentication
- GP economy
- League participation
- League settlement
- Knockout registration
- Knockout settlement
- Hall of Fame
- Competitive records
- Run submission processing
- Run validation
- Anti-cheat validation

The server owns every state transition that affects competitive integrity, economy, rankings, or public records.

## Authoritative Rules

Server must be authoritative for:

- GP balance
- Purchases
- League entry
- League rankings
- League settlement
- Knockout registration
- Knockout duel results
- Knockout advancement
- Hall of Fame
- Competitive achievements

The Flutter app may continue to use mock repositories during development, but production repository implementations must treat the backend as the source of truth.

## Background Jobs

Future backend workers will be responsible for:

- Weekly league settlement
- Monthly knockout lifecycle transitions
- Daily knockout round settlement
- Hall of Fame updates
- Records recalculation
- Data cleanup tasks

These jobs must run server-side only.

# Persistence Map

## Session 47 Part 4 Internal Registration Execution

The internal `KnockoutRegistrationService` and transaction-bound repository now
exercise migration 004 atomically with `GpExecutor`; no migration/schema change
was required. Part 3's inventory below is historical. There is still no HTTP
handler, tournament provisioning/lifecycle implementation, or Flutter end-to-end
Knockout registration against this server.

One READ COMMITTED transaction acquires a shared catalog advisory lock then the
player row lock, reads the scoped business outcome, checks fresh database-time
eligibility and duplicates, executes the fixed 25 GP debit, inserts the registration
using the exact executor ledger/mutation IDs, and inserts the final outcome.
Failures roll back all writes; uncertain COMMIT is explicitly classified and
never automatically retried. Existing migration checksum/transaction guarantees
remain unchanged. Timestamp inserts require the explicit column grants documented
in `backend/README.md`, not elevated runtime privileges. Registration and outcome
creation reuse the precise admission instant; completion is clamped to creation
if the database clock moves backward. Replays retain all historical timestamps.

Business fingerprint V1 includes trusted player and explicit tournament targeting.
The registration UUIDv8 is deterministically derived from that fingerprint and
logical key; GP scope is `knockout_registration_fee` V1 with the same key and
player. Source is `knockout_registration` / `<tournament UUID>:<registration UUID>`.
Resolved GP context contains the business scope/version and both IDs. These are
stable across explicit recovery, even if a prior COMMIT did not persist. Business
replay returns the original semantic outcome before new eligibility checks,
without re-evaluating historical balances or modifying current GP.

Unknown catalog targets persist as `tournamentUnavailable` with null tournament FK;
their fingerprint still includes the requested trusted UUID. Insufficient funds
persist a rejected GP mutation plus business rejection and no movement. Admission
rejections otherwise create no GP mutation. Missing players, key conflicts and
infrastructure failures do not create business outcome rows.

Lifecycle writers must acquire the exclusive form of the catalog advisory lock
before changing state and before locking any player. See `Backend_Plan.md` for
the exact protocol and admission-time convention. Future HTTP resolution must
recover the original target for a key, never infer a different month on retry.
Historical remaining GP is not a current profile projection; HTTP mapping remains
deferred alongside provisioning, run validation, League and gameplay GP producers.

## Session 47 Part 3 Knockout Registration Schema

Migration `004_knockout_registration.sql` adds persistence only. There is no
registration business service/repository, HTTP handler, automatic tournament
provisioning, scheduler or bracket implementation. Flutter and mocks are unchanged.
Earlier session inventories below describe their historical implementation state.

| Table | Responsibility and integrity |
| --- | --- |
| `stoppy_knockout.tournaments` | Trusted server-provisioned UUID, unique first-of-month `date` label, name, explicit absolute opening/closing/start instants and availability state; no catalog seed |
| `stoppy_knockout.registrations` | UUID, player/tournament FKs, unique player per tournament, immutable registration time and mandatory unique financial evidence |
| `stoppy_knockout.registration_operations` | Append-only final accepted/rejected business outcomes; player/operation/version/key uniqueness, fingerprint/version, resolved tournament, registration reference, rejection reason and semantic JSON object |

The month label represents the trusted Portugal calendar month, independent of
device or PostgreSQL session timezone. `timestamptz` stores absolute instants;
registration uses `opens <= now < closes`, with `opens < closes < starts`.
This represents supplied boundaries, not a new monthly scheduling policy. The
previous tournament's end, following opening and exact calendar boundaries still
require an explicit decision in the future provisioning/business-service phase.

A composite FK requires registration evidence to reference an existing **same-player,
same-mutation 25 GP debit**, with `source_type = 'knockout_registration'` and
`source_id = '<tournament UUID>:<registration UUID>'` (canonical UUID text).
The registration derives both source fields with generated columns; unrelated
debits or fees for other registrations/tournaments cannot satisfy this FK.
Migration 004 adds only the necessary composite UNIQUE
reference key to the existing ledger; migrations 001-003 and their checksums are
untouched. The ledger's existing accepted-mutation FK remains authoritative.
One ledger row cannot fund multiple registrations. No GP balance or complete GP
mutation snapshot is duplicated in the business tables.

Accepted operations reference a registration for the same player and tournament;
rejected operations have no registration and carry a semantic reason. A missing
catalog identity is representable only as rejected `tournamentUnavailable`.
`semantic_outcome` can preserve the original business projection after the wallet
changes. Future code must validate its shape, compare fingerprints on replay and
commit GP, registration and final outcome in one transaction using `GpExecutor`.
Preallocate the server registration UUID before the debit, then insert the
registration and operation: there is no circular FK or deferred insert requirement.
The operation's registration FK provides its sole authoritative financial path
through `registrations.gp_mutation_id`; no second mutation ID in JSON is authoritative.
Part 4 must bind the GP command's operation scope/key and resolved context to the
locked logical business operation, consume the exact accepted executor result,
and persist that result's ledger/mutation IDs on the registration in the same
transaction. The schema does not compare independent GP/business fingerprints
or infer that relationship from opaque operation names or keys.
Transport failures, idempotency conflicts and uncertain COMMIT are not automatically
durable business rejections; there are no automatic retries.

Registrations and final outcomes reject UPDATE/DELETE/TRUNCATE. PUBLIC has no
schema/table access. Restricted-role tests grant only catalog SELECT and necessary
registration/outcome SELECT/column INSERT privileges; catalog writes and schema
changes remain trusted deployment/provisioning operations. Financial linkage is
exercised only by controlled persistence test fixtures, not an operational service.

## Session 46 Registration Opening Snapshot (Step 3)

New account registration inserts one `stoppy_economy.gp_ledger` opening snapshot
on its existing transaction connection, alongside `stoppy_auth.players`, session
and refresh-token rows. The default balance is 5 GP; the snapshot has delta 0,
before/after 5, source type `opening_snapshot`, canonical player UUID source ID,
and no mutation reference. The source uniqueness constraint prevents duplicates.
Any write failure rolls back the registration; COMMIT uncertainty remains explicit
and is never automatically retried. Existing migration 003 snapshots and balances
are not rewritten. GP business producers and mutation endpoints remain deferred.

## Session 45 Account and Session Persistence (Pending Review)

| Entity | Server owner | PostgreSQL table | Integrity boundary |
| --- | --- | --- | --- |
| Player account/profile | PostgresAuthRepository | stoppy_auth.players | Server UUID, unique generated ASCII lowercase username, Argon2id hash, GP default 5/nonnegative, immutable creation identity; no profile-write endpoint |
| Authentication session family | PostgresAuthRepository | stoppy_auth.auth_sessions | Player FK, absolute expiry/revocation, verified on protected requests |
| Refresh credential | PostgresAuthRepository | stoppy_auth.auth_refresh_tokens | Unique SHA-256 digest only, consumption/expiry/replacement, same-family replacement FK, at most one unconsumed token/family |

Migration 002 is append-only; migration 001 and its checksum remain unchanged.
Consumed refresh records are retained for family replay detection. Raw refresh
tokens, JWTs and plaintext passwords are never persisted server-side. Device
secure storage remains separate and unchanged. Remote logout and expired-record
cleanup are deferred; competitive/economy persistence remains future work.

This map describes current mock-owned data and the expected future PostgreSQL persistence model. Production ownership must move to backend repositories backed by server-side validation.

## Session 44 Infrastructure Persistence

The new isolated `backend/` server implements PostgreSQL connection management
and an explicit transactional SQL migration command. The only implemented
database objects are `public.stoppy_schema_migrations` (version, SHA-256
checksum, applied timestamp) and the empty `stoppy_runtime` namespace.
Ledger inserts are parameterized; a transaction-scoped advisory lock serializes
concurrent migrators. Changed/removed applied migrations fail; failed batches
roll back. This migration ledger is not a competitive mutation-idempotency store.

All player/economy/competitive tables in the maps below remain proposed, not
implemented. No sessions, run claims, GP, rankings or tournament state are
stored by this foundation. Backend server feature persistence, authentication,
request fingerprints and atomic mutation-idempotency records remain future work.
The separate real PostgreSQL integration test requires an empty disposable
`*_test` database; unit tests use fake connections and no database service.

| System | Current Repository | Future Database Table | Ownership | Validation Requirements |
| --- | --- | --- | --- | --- |
| PlayerProfile | AuthRepository / MockAuthRepository | players | Server | Unique username, authenticated writes, GP changes only through trusted economy operations, immutable registration date. |
| AuthSession (device cache) | SecureAuthSessionStore in backend runtime | Platform secure storage, not PostgreSQL | Client device / server-issued | Versioned JSON only; access token, optional refresh token, and expiry. Corrupt payloads are removed. Tokens never use SharedPreferences or local files. |
| WeeklyLeagueRun | LeagueRepository / MockLeagueRepository | weekly_league_runs | Server | Active weekly entry required, duplicate run protection, valid run timestamp, validated final PP score. |
| LeaguePlayerEntry | LeagueRepository / MockLeagueRepository | league_player_entries | Server | Entry cost paid, reserved slot rules, no duplicate active entry per player/season. |
| LeagueDivision | LeagueRepository / MockLeagueRepository | league_divisions | Server | Capacity policy, division numbering, last division expansion, settlement-safe updates. |
| LeagueHistory | LeagueRepository / MockLeagueRepository | league_history_entries | Server | Generated only during trusted weekly settlement, immutable after settlement. |
| LeagueAchievements | LeagueRepository / MockLeagueRepository | league_achievements or derived view | Server | Derived from trusted league history; client must not submit promotion/relegation counts. |
| KnockoutTournament | KnockoutRepository / MockKnockoutRepository | knockout_tournaments | Server | Monthly lifecycle, registration window, entry cost, status transitions. |
| KnockoutMatch | KnockoutRepository / MockKnockoutRepository | knockout_matches | Server | Created by trusted bracket generation, settled by backend only, no client winner mutation. |
| KnockoutRun | KnockoutRepository / MockKnockoutRepository | knockout_runs | Server | Active duel required, duplicate run protection, valid timestamp, validated final PP score. |
| KnockoutPlayerRecords | KnockoutRepository / MockKnockoutRepository | knockout_player_records | Server | Updated only from trusted completed tournament history and settled matches. |
| KnockoutHistory | KnockoutRepository / MockKnockoutRepository | knockout_history_entries | Server | Generated only after tournament completion, excludes non-participants, immutable audit history. |
| HallOfFame | KnockoutRepository / MockKnockoutRepository | knockout_hall_of_fame or derived view | Server | Champion-only aggregation from trusted knockout history; client must not submit titles. |
| LeagueSettlement | LeagueRepository / MockLeagueRepository | league_settlements    | Server    | Generated only by trusted settlement jobs, immutable audit record, one settlement per season. |
| KnockoutDuelScore | KnockoutRepository / MockKnockoutRepository | knockout_duel_scores  | Server    | Derived from validated knockout runs, immutable once round settlement completes. |
| PlayerLeagueRecords | LeagueRepository / MockLeagueRepository | player_league_records or derived view | Server | Derived from trusted weekly runs and settlement history; client must not submit records. |
| Purchases / Store | PurchaseRepository / MockPurchaseRepository | purchases / store_products | Server | Receipt validation required, duplicate purchase protection, GP grants only after trusted purchase confirmation. |

## Ownership Notes

- Mock repositories remain useful for local development and tests.
- Backend repositories should preserve the same contracts where possible.
- PostgreSQL tables should be designed for auditability and deterministic settlement reproduction.
- Derived views may be materialized later for performance, but source data must remain authoritative.

## Mock to Backend Migration Path

1. Keep existing repository contracts as the app boundary.
2. Keep mock repositories as deterministic test fixtures.
3. Add backend repositories in each feature data layer.
4. Add DTOs that translate REST JSON to domain models.
5. Add an API client implementation when networking is introduced.
6. Switch dependency injection from mock repositories to backend repositories by environment.
7. Move competitive validation from local mock behavior to server-authoritative responses.

The UI should not change during this migration. If a widget needs to change when a backend repository replaces a mock repository, that is a sign the boundary leaked implementation details.

## Session 27 Wiring Preparation

- `AppEnvironment` selects mock or backend repository runtime.
- `RepositoryFactory` creates the concrete repository bundle from that environment.
- Mock repositories remain the default runtime and test fixture.
- At Session 27, backend repositories were disconnected skeletons behind the same contracts; see the current integration note below.
- DTO mappers define the future REST JSON to domain boundary.
- At Session 27, `AuthSessionStore` prepared persistence; Sessions 31-32 later
  selected secure backend session storage and memory-only mock sessions.
- API errors should be mapped to domain-facing exceptions before reaching widgets.
- Historical note: backend authentication, selected League backend
  integrations, Knockout backend reads, registration, and run submission have
  since been activated behind the same repository contracts. Server-only
  Knockout lifecycle mutations remain disconnected. Mock remains the default.

## Session 29 PostgreSQL Entity Mapping Preparation

The following column-level direction is intentionally descriptive rather than a migration. Database names should use snake_case while REST DTOs remain camelCase.

| Entity | Primary identity | Important persisted fields | Notes |
| --- | --- | --- | --- |
| players | `id` | `username`, `created_at`, `game_points`, `ads_removed` | GP and purchase state are server-controlled. |
| weekly_league_runs | `id` | `player_id`, `season_id`, `score`, `completed_at` | Unique run submission/idempotency key required. |
| league_player_entries | `(season_id, player_id)` | `division_number`, `entry_paid`, `has_reserved_slot`, lifetime tie-breaker fields | One active entry per player and season. |
| league_divisions | `(season_id, division_number)` | `capacity`, settlement metadata | Capacity/expansion and settlement writes are server-only. |
| league_history_entries | `(season_id, player_id)` | `final_rank`, `final_division`, `result`, `final_weekly_score`, `season_ended_at` | Immutable after settlement. |
| player_league_records | `player_id` | all-time/current weekly records, current season | Derived from accepted runs and settlement state. |
| player_league_achievements | `player_id` | best division, promotions, relegations | Derived server-side only. |
| knockout_tournaments | `id` | schedule, status, entry cost, champion id | Monthly lifecycle is server-authoritative. |
| knockout_player_entries | `(tournament_id, player_id)` | registration and repechage tie-breaker fields | Duplicate registration prevented by unique key. |
| knockout_rounds | `(tournament_id, round_number)` | starts/ends timestamps, status | Daily settlement state. |
| knockout_matches | `id` | player ids, scores, run counts, winner/repechage winner | Only settlement can set advancement fields. |
| knockout_runs | `id` | `match_id`, `player_id`, `round_number`, `score`, `completed_at` | Must reference an active duel. |
| knockout_history_entries | `(tournament_id, player_id)` | outcome, final round, completed timestamp | Immutable participant history. |
| knockout_player_records | `player_id` | tournament/duel totals and highest round | Derived from settled history/matches. |
| knockout_hall_of_fame | derived view | champion identity, title count, won months | Champion-only aggregate. |

DTOs mirror the REST representation of these records, not direct PostgreSQL rows. Backend adapters own the translation between database rows, API payloads, and domain models.

## Session 30 Transport Boundary

- `HttpBackendApiClient` is a client-side REST transport boundary only; it does not persist data or activate server repositories in the default app runtime.
- `HttpTransport` is replaceable in tests and keeps `package:http` implementation details out of repository contracts.
- Backend runtime selection remains explicit through `RepositoryRuntime.backend`; mock repositories remain the normal local/test runtime.
- Future server adapters must preserve API error envelopes and idempotency validation so transport retries cannot duplicate runs or economy mutations.

## Session 37 League Mutation Persistence Preparation

League entry and League run submission mutations must be persisted atomically
with idempotency records. Suggested PostgreSQL constraints:

- `league_player_entries`: unique active entry per `(season_id, player_id)`.
- `weekly_league_runs`: unique `run_id`, scoped to the authenticated player or
  generated server identity.
- `mutation_idempotency_keys`: unique key within the mutation scope, stored with
  a request fingerprint and stable response projection.
- League entry mutation transaction: validate GP, deduct exactly 10 GP, create
  or activate entry, and persist idempotency result in one transaction.
- League run submission transaction: validate run claim, persist accepted run,
  recalculate weekly score/records/achievements, and persist idempotency result
  in one transaction.
- Idempotency conflict occurs when an existing key is reused with a different
  request fingerprint.
- No partial GP deduction without successful entry creation.
- No accepted run without validation result and updated League projection.
- Settlement writes remain trusted backend jobs and must not be triggered by
  client-submitted mutation payloads.

`BackendLeagueRepository.enterWeeklyLeague` and
`BackendLeagueRepository.submitLeagueRun` now consume the League mutation
contracts, but PostgreSQL persistence and idempotency storage remain future
backend responsibilities. League settlement remains disconnected from Flutter
backend repositories.

## Sessions 40-42 Knockout Backend Persistence Preparation

Knockout read projections and registration are now connected from Flutter
backend runtime. Session 43 also connects Knockout run submission as a claim
with explicit caller-owned idempotency. The finalized claim/key survive ambiguous
failures for explicit retry; accepted/replay or definitive rejection resolves
the attempt. No automatic retry or client-side competitive persistence is added.

Before context resolution, GameScreen stores frozen logical identity, player,
score and timestamps. Transient read failures allow explicit read recovery;
after context resolves, ambiguous POST retries preserve the exact run/key and
do not refetch association data. This state is memory-only: recovery after app
termination/process restart and persistent offline queues remain deferred.

Accepted and replay runs retain the submitted logical run ID, match ID and round
number. Contradictory associations are malformed responses. Authenticated player
identity and the final accepted PP score remain server-owned, including score
correction. Structural DTO checks do not implement anti-cheat; the current POST
does not automatically carry complete validation evidence. PostgreSQL writes
and server-side idempotency records remain future backend work.
Mutations must be persisted atomically with idempotency records on the future
backend. Suggested PostgreSQL constraints:

- `knockout_player_entries`: unique registration per `(tournament_id,
  player_id)`.
- `knockout_runs`: unique logical run id scoped to the authenticated player and
  tournament/match context.
- `mutation_idempotency_keys`: unique key within the Knockout mutation scope,
  stored with a request fingerprint and stable response projection.
- Knockout registration transaction: validate tournament window, validate GP,
  deduct exactly 25 GP, create the entry, and persist idempotency result in one
  transaction.
- Knockout run submission transaction: validate the active duel claim, persist
  accepted run, update duel aggregate/projection, and persist idempotency result
  in one transaction.
- Settlement, bracket advancement, repechage, champion persistence, records,
  and Hall of Fame writes remain trusted backend jobs and must not be triggered
  by ordinary client mutation payloads.

Historical Session 40 prepared DTO/repository boundaries only. Sessions 41-43
connect registration, reads and run submission; mocks remain the default.

## Session 31 Authentication Session Boundary

- Backend runtime uses `SecureAuthSessionStore` for the server-issued
  `AuthSession`.
- Mock runtime uses `InMemoryAuthSessionStore` and remains memory-only.
- Refresh-token execution and rotation are implemented through
  `AuthSessionRefreshCoordinator`.
- The secure session payload persists only access token, optional refresh token,
  and expiration; `PlayerProfile` and competitive state are not stored there.
- The backend remains the issuer and validator of Stoppy access/refresh tokens.
- Backend logout invalidation and social-provider credential exchange remain
  deferred.
- PlayerProfile remains independent of external provider identities; provider
  credentials must never become Stoppy access tokens.

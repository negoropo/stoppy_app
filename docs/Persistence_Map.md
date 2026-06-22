# Persistence Map

This map describes current mock-owned data and the expected future PostgreSQL persistence model. Production ownership must move to backend repositories backed by server-side validation.

| System | Current Repository | Future Database Table | Ownership | Validation Requirements |
| --- | --- | --- | --- | --- |
| PlayerProfile | AuthRepository / MockAuthRepository | players | Server | Unique username, authenticated writes, GP changes only through trusted economy operations, immutable registration date. |
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
- Backend repositories are skeletons behind the same contracts and must not be called for real networking yet.
- DTO mappers define the future REST JSON to domain boundary.
- `AuthSessionStore` prepares token persistence without choosing a secure storage implementation yet.
- API errors should be mapped to domain-facing exceptions before reaching widgets.

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

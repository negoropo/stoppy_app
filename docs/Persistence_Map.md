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


## Ownership Notes

- Mock repositories remain useful for local development and tests.
- Backend repositories should preserve the same contracts where possible.
- PostgreSQL tables should be designed for auditability and deterministic settlement reproduction.
- Derived views may be materialized later for performance, but source data must remain authoritative.

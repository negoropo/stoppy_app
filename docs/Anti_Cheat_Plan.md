# Anti-Cheat Plan

## Client Is Not Trusted

The Stoppy client is responsible for rendering and input collection, but it must not be trusted as the authority for competitive outcomes.

Potential attacks:

- fake scores
- fake GP
- modified runs
- duplicated submissions
- manipulated tournament results

Any data sent by the app must be treated as a claim that the backend validates before persistence.

## Future Validation

Validate:

- PP progression
- Tier progression
- Run duration
- Submission timestamps
- League submissions
- Knockout submissions

Validation should compare submitted run data against server-issued session configuration, timing constraints, allowed level progression, and duplicate submission guards.

## Settlement Protection

Only backend can:

- settle leagues
- settle knockout rounds
- update rankings
- update Hall of Fame

Settlement jobs must run from trusted backend processes. The client may request current state, but it must never decide final rankings, promotions, relegations, duel winners, tournament champions, or Hall of Fame entries.

## Future Replay/Event Log Strategy

Future anti-cheat systems may use:

- event logs
- replay validation
- anomaly detection
- impossible precision distributions
- abnormal win rates
- abnormal target-hit rates
- unrealistic play volume
- repeated identical submissions

Replay/event storage can preserve enough input and timing data to reconstruct competitive runs. This allows delayed validation, audit trails, dispute handling, and detection of impossible or statistically suspicious behavior.

## Level configuration validation

The backend must validate that submitted runs were played using the server-issued level configuration:

- ball speed
- ball size
- safe zone size
- safe zone speed
- target speed
- tier configuration

Clients must not be allowed to submit results generated from modified gameplay parameters.

## Economy Validation

The backend must validate all Game Point transitions.

Examples:

- league entry costs
- knockout registration costs
- GP rewards
- purchases
- ad rewards

Clients must never directly modify GP balances.

## League Mutation Validation Boundary

League entry and League run submission are competitive mutations and must be
server-authoritative.

League entry validation must:

- derive player identity from authentication
- validate the current season and entry window
- validate duplicate entry and reserved-slot state
- atomically deduct the 10 GP entry cost only when entry creation succeeds
- persist the idempotency result with the mutation transaction

League run submission validation must:

- derive player identity from authentication, not the request body
- validate active weekly entry and season membership
- validate run start and completion timestamps
- reject runs longer than the allowed maximum duration
- validate PP, level, and tier progression from server-issued configuration
- reject duplicate run IDs unless a matching idempotent replay is returned
- recalculate weekly score, records, achievements, and ranking projections on
  the backend

If the same idempotency key is reused with a different payload, the backend must
return a conflict without exposing sensitive anti-cheat diagnostics. Detailed
replay evidence and anomaly data should remain in server-side audit logs.

The Flutter backend League repository now sends the weekly entry mutation as an
authenticated empty-object request with a caller-owned `Idempotency-Key`. The
client still does not submit player identity, GP balance, division placement, or
reserved-slot decisions as authoritative data. League run submission and League
settlement remain server-authoritative future integrations.

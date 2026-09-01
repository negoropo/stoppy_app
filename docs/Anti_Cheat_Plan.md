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

The Flutter backend League repository now sends weekly entry and finalized
League run submission mutations with caller-owned `Idempotency-Key` values. The
entry request remains an authenticated empty-object request. League run
submission sends a structural claim without treating client-provided player
identity as authority. The client still does not submit GP balance, division
placement, reserved-slot decisions, accepted scores, or validation outcomes as
authoritative data. League settlement remains a server-authoritative future
integration and must not be triggered by normal mobile client runtime.

## Knockout Mutation Validation Boundary

Session 40 prepares the Knockout mutation boundary without activating backend
Knockout mutations.

Knockout tournament registration validation must:

- derive player identity from authentication
- resolve the current monthly tournament on the backend
- validate the registration window and tournament lifecycle
- prevent duplicate registration with idempotent replay support
- atomically deduct the 25 GP entry cost only when registration succeeds
- return authoritative tournament entry state

Knockout run submission validation must:

- derive player identity from authentication, not the request body
- validate active tournament, active round, active duel, and match association
- validate run timestamps, PP, level, and tier progression
- reject duplicate logical runs unless the idempotent replay matches the
  original claim
- update duel score projections only from accepted validated runs

Knockout registration and run submission require caller-owned
`Idempotency-Key` values when connected. Round settlement, bracket advancement,
repechage, tournament completion, champion persistence, records, and Hall of
Fame updates remain trusted backend/internal responsibilities and must never be
driven by ordinary client mutation payloads.

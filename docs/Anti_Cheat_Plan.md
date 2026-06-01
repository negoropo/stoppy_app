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
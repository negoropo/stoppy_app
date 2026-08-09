# API Plan

The future API is a custom REST API backed by PostgreSQL. Endpoints below describe the first backend-facing contract shape and may evolve, but competitive state must remain server-authoritative.

## Versioning and Paths

All public REST endpoints use the `/api/v1` prefix. The client exposes these paths through `ApiContract`; backend repositories must not duplicate string literals.

Examples:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/player/profile`
- `POST /api/v1/runs/league`
- `POST /api/v1/runs/knockout`

Requests and responses use `Content-Type: application/json`. The prepared HTTP client adds `Authorization: Bearer <accessToken>` only when a valid session exists and the path is not public.

## Response Envelope

All endpoints should use a standardized envelope:

```json
{
  "success": true,
  "data": {}
}
```

Failure responses should use:

```json
{
  "success": false,
  "error": {
    "code": "validationFailed",
    "message": "Human readable error.",
    "details": {}
  }
}
```

`code` uses stable machine-readable values such as `validationFailed`, `conflict`, `unauthenticated`, `forbidden`, and `malformedPayload`. The client accepts camelCase and snake_case response codes during the migration period.

The Flutter app already has prepared API response/error models for this future contract. Backend repositories should decode this envelope first, then translate DTOs into domain models.

## Client Integration Layer

The Flutter app prepares backend integration through environment configuration and a repository factory.

- `STP_REPOSITORY_RUNTIME=mock` keeps mock repositories active.
- `STP_REPOSITORY_RUNTIME=backend` creates backend repository skeletons.
- `STP_API_BASE_URL` defines the future REST API base URL.
- The HTTP client exists, mock runtime remains the default, and only backend authentication is connected when backend runtime is explicitly selected.

Backend repositories should receive a `BackendApiClient` plus an auth session store. The API client should attach the current access token when required, decode the response envelope, and surface `ApiError` for repository-level mapping.

## Networking Client Preparation

`HttpBackendApiClient` is the production transport-ready implementation of `BackendApiClient`.

- `HttpTransport` isolates `package:http` from repositories and allows tests to use a fake transport.
- Only `http` and `https` backend base URLs are accepted.
- Paths are resolved from `BackendConfig.baseUrl`; both trailing-slash and non-trailing-slash base URLs are supported.
- Requests use `Accept: application/json` and send `Content-Type: application/json` only when a JSON body exists.
- Query parameters use Dart `Uri` APIs and bodies use `jsonEncode`.
- HTTP 204 is represented as a successful empty data map so existing repository contracts keep non-null success data.

### Timeout and Retry Policy

- The default timeout is 15 seconds and is configured through `BackendConfig.timeout`.
- Timeouts map to the typed `requestTimeout` API error code.
- Transport failures map to `networkUnavailable` without exposing `package:http` exceptions.
- No automatic retry is performed, especially for POST, PUT, PATCH, or DELETE. A future retry policy must be explicitly idempotency-aware before it can retry competitive or economy operations.

### HTTP Status Mapping

When no backend failure envelope supplies a more specific error, status codes map as follows:

| HTTP status | API error code |
| --- | --- |
| 401 | `unauthenticated` |
| 403 | `forbidden` |
| 404 | `notFound` |
| 409 | `conflict` |
| 422 | `validationFailed` |
| 429 | `rateLimited` |
| 5xx | `serverError` |
| other non-2xx | `unexpectedResponse` |

Malformed successful JSON maps to `malformedPayload`. Non-JSON error responses still receive a safe HTTP-status-derived error.

### Authentication Header Behavior

- A non-expired `AuthSession` adds `Authorization: Bearer <accessToken>`.
- Missing or expired sessions do not add an authorization header.
- Public registration, login, and refresh paths never add an authorization header.
- Refresh requests carry the refresh token only in their JSON body. They are
  coalesced client-side and never trigger generic request retries.

## DTO Strategy

- REST JSON maps to DTOs in the data layer.
- DTOs map to domain models before data reaches UI.
- Domain models should not depend on HTTP or PostgreSQL schema details.
- Mock repositories can continue returning domain models directly.
- Backend repositories should be swappable behind the existing repository contracts.
- DTO/domain conversion should be expressed through feature mappers so serialization rules stay outside widgets.
- DTO `fromJson` methods validate required field types before constructing domain models.
- Invalid transport payloads become typed `malformedPayload` errors instead of leaking cast or date parsing exceptions into UI.

### Persisted DTO Coverage

The client has explicit DTOs for the persisted competitive entities currently represented in the app:

- Player profile and auth requests/responses
- Weekly league divisions, entries, scores, history, records, achievements, and runs
- Knockout tournaments, entries, rounds, matches, history, records, Hall of Fame entries, and runs

Snapshots and other UI projections remain domain/repository outputs. They are not database schemas.

## JWT Authentication Contract

Successful registration/login responses return:

```json
{
  "playerProfile": {},
  "session": {
    "accessToken": "jwt-access-token",
    "refreshToken": "optional-refresh-token",
    "expiresAt": "2026-06-21T12:00:00.000Z"
  }
}
```

- `accessToken` is required and non-empty.
- `refreshToken` is optional to allow a future session policy change.
- `expiresAt` is an ISO-8601 UTC date-time.
- Backend runtime stores this session as a versioned JSON payload in platform
  secure storage. It never stores either token in SharedPreferences or ordinary
  files. Mock runtime remains in-memory.

## Refresh Token Contract

`POST /api/v1/auth/refresh` accepts `{ "refreshToken": "..." }` and returns
`{ "session": { ... } }` in the standard success envelope. A response may omit
`refreshToken` when the existing refresh credential remains valid; otherwise a
rotated non-empty refresh token replaces it. Replacement access tokens must be
future-dated. Invalid or unauthorized refresh credentials clear local storage;
temporary timeout, network, rate-limit, server, and malformed responses retain
the last session for a later attempt.

## Backend Authentication Integration

When `RepositoryRuntime.backend` is selected, `BackendAuthRepository` now connects registration, login, logout, and authenticated profile restoration to `BackendApiClient`.

- Registration and login share the same `AuthResponseDto` completion pipeline.
- A profile and Stoppy-issued `AuthSession` are mapped before the session is saved.
- Expired returned sessions and malformed authentication payloads are rejected without replacing the existing local session.
- On app restoration, unauthenticated or forbidden profile responses clear the in-memory session; temporary failures preserve it and surface an auth-domain error.
- Future Google, Apple, and Facebook login flows must validate provider credentials on the backend and return this same Stoppy `AuthResponseDto`; provider identity tokens are not stored as Stoppy sessions.
- League and Knockout backend repository methods remain disconnected skeletons.

## Error Strategy

- Transport responses decode into `ApiResponse`.
- Failure envelopes decode into `ApiError`.
- Repositories map `ApiError` into domain-facing exceptions where useful.
- UI must not branch on HTTP status codes or backend implementation details.
- Validation, conflict, and authorization errors should keep stable machine-readable `code` values.

## Auth

### POST /auth/register

Creates a new player account.

Server responsibilities:

- validate username uniqueness
- create player profile
- initialize GP and competitive records
- return authentication token/session

### POST /auth/login

Authenticates an existing player.

Server responsibilities:

- validate credentials
- return authentication token/session
- return minimal authenticated player context

## Player

### GET /player/profile

Returns the authenticated player's profile.

Server responsibilities:

- return GP balance
- return purchase flags
- return league/knockout participation state
- never trust profile state sent by the client

## League

### GET /api/v1/league/entry

Returns the authenticated player's current weekly league participation state.

Request query:

- `playerId`

Success data:

```json
{
  "entry": null
}
```

When the player has a reserved or active league slot, `entry` is a
`LeaguePlayerEntry` DTO. The server remains authoritative for whether the
authenticated user may inspect the requested player id.

### GET /api/v1/league/ranking

Returns a division ranking preview.

Request query:

- `divisionNumber`

Success data:

```json
{
  "entries": []
}
```

Each item contains `rank`, `playerEntry`, and `weeklyScore`. Inactive players
must be represented by an inactive weekly score rather than a zero score.

### League mutation idempotency

League mutations use the `Idempotency-Key` HTTP header. The client owns the key
and must reuse the same key only when retrying the same logical mutation with
the same payload. A different League entry attempt or run submission requires a
new key.

Client key rules:

- trim leading and trailing whitespace before use
- reject blank keys
- reject keys longer than 128 characters
- allow only letters, numbers, `.`, `_`, `:`, and `-`

Server behavior:

- same key + same payload returns the original stable result
- same key + different payload fails with an idempotency conflict
- idempotency result and request fingerprint are persisted atomically with the
  mutation result
- sensitive validation evidence must not be exposed in user-facing errors

### POST /api/v1/league/enter

Registers or re-enters the authenticated player into the weekly league.

Request headers:

- `Idempotency-Key`

Request body:

```json
{}
```

Server responsibilities:

- derive player identity from authentication
- resolve the current season
- validate entry window, duplicate entry, reserved slot, and re-entry state
- validate GP availability
- atomically deduct 10 GP and create/activate the entry
- apply last-division expansion and division placement
- return authoritative entry state and remaining GP/profile projection

Success data:

```json
{
  "status": "accepted",
  "seasonId": "2026-06-15",
  "entry": {},
  "currentDivision": 2,
  "remainingGamePoints": 15,
  "playerProfile": {}
}
```

Rejected data:

```json
{
  "status": "rejected",
  "seasonId": "2026-06-15",
  "rejectionCode": "insufficientGp"
}
```

An idempotent replay of a previously accepted entry uses
`"status": "idempotentReplay"` and returns the same authoritative accepted
entry projection.

This mutation remains disconnected in the Flutter backend repository until
server-side persistence and validation are implemented.

### GET /api/v1/league/snapshot

Returns the player's current division ranking snapshot.

Request query:

- `playerId`
- `divisionNumber`

Server responsibilities:

- calculate or fetch ranking
- include promotion/stay targets
- mark inactive players correctly

### GET /api/v1/league/history

Returns player weekly league history.

Request query:

- `playerId`

Server responsibilities:

- return trusted settlement history
- preserve immutable historical results

### GET /api/v1/league/records

Returns player league records.

Request query:

- `playerId`

Server responsibilities:

- return all-time/current records

### GET /api/v1/league/runs

Returns current weekly runs for the authenticated player.

Request query:

- `playerId`
- `seasonId`

### POST /api/v1/runs/league

Submits a completed League run claim for server validation.

Request headers:

- `Idempotency-Key`

Request body:

```json
{
  "runId": "run-1",
  "seasonId": "2026-06-15",
  "runStartedAt": "2026-06-21T10:00:00.000Z",
  "runCompletedAt": "2026-06-21T10:30:00.000Z",
  "claimedFinalPrecisionPoints": 25000,
  "runMode": "league",
  "validationClaim": {}
}
```

The client does not submit weekly score, rank, records, achievements, GP
balance, or player identity as authoritative data.

Server responsibilities:

- derive player identity from authentication
- validate active weekly entry, reserved-slot state, season, and run mode
- validate timestamp ordering and maximum run duration
- reject duplicate run IDs unless the idempotent replay matches the original
- validate PP and tier progression against server-issued run configuration
- run anti-cheat validation
- recalculate weekly score, ranking, records, achievements, and GP decisions
- persist the accepted run and resulting projections atomically

Accepted data:

```json
{
  "status": "accepted",
  "newlyPersisted": true,
  "acceptedRun": {},
  "playerRecords": {},
  "validationResult": {
    "accepted": true,
    "serverFinalPrecisionPoints": 25000
  }
}
```

Rejected data:

```json
{
  "status": "rejected",
  "newlyPersisted": false,
  "rejectionCode": "validationFailed",
  "validationResult": {
    "accepted": false,
    "rejectionCode": "invalid_precision_progression"
  }
}
```

An idempotent replay of a previously accepted submission uses
`"status": "idempotentReplay"`, `"newlyPersisted": false`, and returns the
stable original accepted run result.

### League mutation error taxonomy

Stable League mutation rejection/error reasons include:

- `alreadyActive`
- `entryWindowClosed`
- `insufficientGp`
- `noReservedSlot`
- `outsideLeague`
- `seasonMismatch`
- `alreadySubmitted`
- `idempotencyConflict`
- `invalidRun`
- `validationFailed`
- `timestampInvalid`
- `durationInvalid`
- `settlementInProgress`
- `stalePlayerState`
- `unauthenticated`
- `forbidden`
- `rateLimited`
- `serverUnavailable`

Backend error envelopes should map transport and authorization failures through
typed `ApiError` codes. Detailed anti-cheat evidence should stay internal.

### GET /api/v1/league/achievements

Returns derived league achievements.

Request query:

- `playerId`

Server responsibilities:

- return best division, promotions, and relegations
- derive achievement values from trusted history

## Knockout

### POST /knockout/register

Registers the authenticated player for the current monthly knockout.

Server responsibilities:

- validate registration window
- validate GP availability
- deduct 25 GP entry cost
- prevent duplicate registration

### GET /knockout/status

Returns tournament status for the authenticated player.

Server responsibilities:

- return registration state
- return active duel or bye state
- return eliminated/champion/completed state

### GET /knockout/history

Returns player knockout tournament history.

Server responsibilities:

- return completed tournament outcomes
- exclude tournaments the player did not enter
- preserve final round/result history


### GET /knockout/records

Returns player knockout records and achievements.

Server responsibilities:

- return tournaments participated
- return tournaments won
- return best round reached
- return duel win percentage
- derive statistics from trusted tournament history

### GET /knockout/hall-of-fame

Returns champion-only Hall of Fame data.

Server responsibilities:

- aggregate tournament champions
- return title counts
- return tournament month/year wins
- exclude non-champions

## Gameplay

### POST /runs/league

Submits a completed league run claim.

Server responsibilities:

- validate active weekly league entry
- validate score and PP progression
- prevent duplicates
- persist accepted run
- update league records where appropriate

### POST /runs/knockout

Submits a completed knockout duel run claim.

Server responsibilities:

- validate active duel
- validate score and PP progression
- prevent duplicates
- persist accepted run
- update current duel score where appropriate

## Competitive Validation Contract

Future run submission claims carry enough information for server-side verification:

```json
{
  "runId": "client-generated-idempotency-key",
  "runType": "league",
  "finalPrecisionPoints": 12000,
  "levelReached": 15,
  "precisionPointTier": 7,
  "runStartedAt": "2026-06-21T10:00:00.000Z",
  "runEndedAt": "2026-06-21T10:10:00.000Z"
}
```

This is a preparation contract only. The backend will later validate timing, tier progression, duplicate submission protection, authenticated player identity, and the final accepted score.

## Store / Economy

### POST /store/purchases

### GET /store/products

## Internal Jobs

### POST /internal/league/settle-week

### POST /internal/knockout/settle-round

### POST /internal/league/settle-current

### POST /internal/knockout/settle-current-round

These endpoints must not be callable by normal clients.

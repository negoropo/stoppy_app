# API Plan

The future API is a custom REST API backed by PostgreSQL. Endpoints below describe the first backend-facing contract shape and may evolve, but competitive state must remain server-authoritative.

## Versioning and Paths

All public REST endpoints use the `/api/v1` prefix. The client exposes these paths through `ApiContract`; backend repositories must not duplicate string literals.

Examples:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/player/profile`
- `POST /api/v1/runs/league`
- `POST /api/v1/runs/knockout`

Requests and responses use `Content-Type: application/json`. Authenticated requests will use `Authorization: Bearer <accessToken>` once real networking is introduced.

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
- No real network calls are made until a concrete `BackendApiClient` implementation is added.

Backend repositories should receive a `BackendApiClient` plus an auth session store. The API client should attach the current access token when required, decode the response envelope, and surface `ApiError` for repository-level mapping.

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
- Token storage and refresh calls are intentionally not implemented in this session.

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

### POST /league/enter

Registers or re-enters the authenticated player into the weekly league.

Server responsibilities:

- validate GP availability
- deduct entry cost
- apply reserved slot/re-entry rules
- place player in the correct division

### GET /league/snapshot

Returns the player's current division ranking snapshot.

Server responsibilities:

- calculate or fetch ranking
- include promotion/stay targets
- mark inactive players correctly

### GET /league/history

Returns player weekly league history.

Server responsibilities:

- return trusted settlement history
- preserve immutable historical results

### GET /league/records

Returns player league records and achievements.

Server responsibilities:

- return all-time/current records
- return best division, promotions, and relegations
- derive achievement values from trusted history

### GET /league/runs
Returns current weekly runs for the authenticated player.

### GET /league/achievements
Returns derived league achievements.

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

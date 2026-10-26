# Stoppy Backend Foundation

Session 44 adds an isolated Node.js 24 / TypeScript / Fastify application with
PostgreSQL connectivity. Session 45 adds PostgreSQL-backed authentication
(pending review). Flutter still defaults to mocks. League, Knockout and economy
server endpoints remain unimplemented.

## Local setup

Run commands from `backend/`. Node 24 and npm 11 are required.

```sh
npm ci
cp .env.example .env
docker compose up -d --wait
npm run migrate
npm run dev
```

Docker is optional; an existing local PostgreSQL service also works. Set
`DATABASE_URL` to a database you created for Stoppy. Compose uses PostgreSQL 17,
host port 5433, loopback-only publishing and a named data volume. The example
credentials are public development placeholders, never production credentials.
`docker compose down` stops the service and preserves the data volume.

Production build/start (supply real environment variables externally):

```sh
npm run typecheck
npm run build
npm run migrate:production
NODE_ENV=production DATABASE_SSL=verify-full npm start
```

The build contains server sources only. Keep `migrations/` alongside `dist/`
when packaging. Environment files are ignored; only `.env.example` is committed.
Environment variables already supplied by the host take precedence over `.env`.

## Configuration

| Variable | Policy |
| --- | --- |
| `NODE_ENV` | `development` (default), `test`, or `production` |
| `HOST` | Default `127.0.0.1`; configure explicitly for containers |
| `PORT` | Integer 1-65535, default 3000 |
| `LOG_LEVEL` | `silent`, `error`, `warn`, `info` (default), `debug` |
| `DATABASE_URL` | Required `postgresql://` or `postgres://` URL with database name; no SSL query overrides |
| `DATABASE_SSL` | `disable` (local default) or `verify-full`; production requires `verify-full` |
| `TEST_DATABASE_URL` | Separate explicitly disposable database ending in `_test`; integration tests only |
| `AUTH_PRIVATE_KEY` | Ed25519 PKCS#8 PEM; literal `\n` accepted. Required in production; development/test can use a process-local ephemeral key |
| `AUTH_ISSUER` / `AUTH_AUDIENCE` | Explicit nonblank identifiers required in production; local defaults `stoppy-local` / `stoppy-app-local` |
| `AUTH_ACCESS_SECONDS` | Default 86400; integer 60-604800, less than refresh lifetime |
| `AUTH_REFRESH_SECONDS` | Default 2592000; integer 60-7776000; fixed absolute family lifetime |

Invalid configuration exits with code 1 before binding. Unavailable PostgreSQL
also fails startup and closes the pool. Startup never runs migrations implicitly:
run the migration command as an explicit deployment step.

Generate an Ed25519 private key with `openssl genpkey -algorithm ED25519` and
provision it as `AUTH_PRIVATE_KEY` through a secret manager (never commit keys).
Keep a stable key across restarts/instances to preserve access-token verification.
Omitting it is a local-only convenience that invalidates existing access tokens
on restart, although accounts/refresh sessions remain in PostgreSQL. No production
default signing key exists. All instances must agree on issuer/audience/lifetimes.

## Authentication API and Security

- `POST /api/v1/auth/register` and `/api/v1/auth/login`: `{username,password}`;
  success data `{playerProfile,session}` with the existing Flutter camelCase fields.
- `POST /api/v1/auth/refresh`: `{refreshToken}`; success data `{session}`.
- `GET /api/v1/player/profile`: Bearer authentication; success data is the profile.
- Session fields: `accessToken`, rotated `refreshToken`, UTC ISO `expiresAt`.
- Profile includes server UUID/creation timestamp, username, GP (initially 5),
  ads flag, nullable daily-GP/division and existing League flags. There is no
  profile write, GP mutation, competitive endpoint or remote logout endpoint.

Usernames are trimmed, case-insensitively unique in PostgreSQL and retain display
case. The explicit server policy is 1-32 ASCII letters/digits/spaces/`_`/`.`/`-`.
This intentionally narrows unrestricted mock Unicode behavior; no implicit
Unicode normalization/case-folding equivalence is promised. Passwords retain
surrounding whitespace exactly but must not be whitespace-only. Registration
requires 4-128 UTF-16 code units (at most 512 UTF-8 bytes). Login accepts nonblank
passwords up to the same maximum without applying the registration minimum, so
existing accounts are not locked out. The four-character registration minimum
is compatibility-only and must be strengthened together
with Flutter validation before production release.

Argon2id uses per-password random salts, 19 MiB, two iterations and one lane.
Only encoded hashes persist. Unknown-account verification uses a public dummy
Argon2id hash; login errors are generic. At most two hashing jobs run concurrently,
with overload rejected rather than queued. Tokens use `jose` Ed25519/EdDSA JWTs
with explicit algorithm, issuer, audience, type, expiry and UUID identity/session
checks. Protected requests also check session revocation/expiration in PostgreSQL.

Refresh tokens contain 32 random bytes; only SHA-256 digests persist. Rotation
locks the entire family, consumes the old credential, inserts its replacement
and commits before responding. Reusing a consumed credential commits revocation
of that family. Concurrent use permits at most one successful rotation; the
other request revokes the family, so the first response may already be invalid.
A lost response or failed device save likewise requires login on subsequent
reuse. No grace period or automatic replay exists. Separate login sessions are
independent. Refresh does not extend the family's original absolute expiration.

Refresh lifecycle writes use the maximum of wall-clock time and the affected
stored session/token creation and consumption timestamps. This persisted-state
lower bound preserves temporal checks when a host clock moves backwards.
Consumption and replacement creation share that timestamp; replay revocation
commits at or after the affected stored state. Replacement eligibility checks
also use this bound and never extend expiration. JWT issuance keeps wall time,
not the clamped write timestamp, to avoid a future `iat` on the issuing host.
Initial account/session creation still shares one issuance time with a positive
configured lifetime. No schema constraints or applied migrations are rewritten.

Checked-out database clients acquire an error-event listener synchronously in
the pool checkout callback. Socket events mark them unusable, reject active
queries even without a driver rejection, and prevent further SQL. Release is
idempotent and discards failed clients; the listener remains until pg has handed
the connection back to its idle/error lifecycle, then is removed. Raw socket
errors are not logged. COMMIT errors remain uncertain and are never replayed.

The 24-hour access lifetime is temporary until protected Flutter requests can
renew credentials. Local Flutter logout only deletes device credentials and
does not revoke server tokens. Remote logout/revocation is required before release.
Rate limits are 30 auth requests/IP/minute and 10 login/register attempts per
canonical username/minute, including failed requests, with at most 10000 live
rate buckets. Exhausted capacity fails closed. These are process-local limits,
not distributed defenses; trusted ingress/distributed abuse controls remain a
production requirement. Proxy trust remains disabled. Expired token-row cleanup,
key rollover, account recovery and social login are deferred.

## Operational API

```sh
curl http://127.0.0.1:3000/api/v1/health
curl http://127.0.0.1:3000/api/v1/ready
```

- `GET /api/v1/health`: 200,
  `{"success":true,"data":{"status":"ok","service":"stoppy-api"}}`.
  Liveness only; it never queries PostgreSQL.
- `GET /api/v1/ready`: connectivity probe, 200,
  `{"success":true,"data":{"status":"ready"}}`, or 503,
  `{"success":false,"error":{"code":"serverError","message":"Service is not ready."}}`.
- Unknown/unimplemented routes: 404 with `success:false/error`, code `notFound`.
- Request errors use `validationFailed`; unexpected failures use `serverError`
  and a generic message. No driver details, stack traces or credentials are sent.

Readiness currently verifies connectivity, not schema compatibility. After
startup, a database outage changes readiness to 503 while liveness stays 200.

## Migrations

The small SQL runner uses `pg` directly: numbered `NNN_name.sql` files, SHA-256
checksums, `public.stoppy_schema_migrations`, a transaction-scoped advisory lock
and a single acquired connection for the entire batch. Changed/removed applied
versions fail rather than rewriting history. Statement failures roll back and
release the connection; a failed rollback discards it. BEGIN/COMMIT failures
also discard the uncertain connection without further SQL or automatic replay.
A COMMIT failure does not prove rollback: inspect the ledger before an explicit
rerun. Both file loading and direct execution validate consecutive versions,
nonempty SQL and matching checksums before database acquisition; execution
snapshots the validated list. New files must append consecutive versions. Never
edit an applied file. SQL files are trusted deployment assets, not client input.
Ledger values use parameterized queries.

API pools retain 5-second server statement and 6-second client query limits.
The migration CLI uses a separate bounded profile: 120-second statements and
125-second client queries, with the same 3-second connection acquisition and
3-second migration lock limits. These are per-query bounds, not an unlimited
deployment window or a guarantee that an entire batch finishes within two minutes.

Migration 001 creates only `stoppy_runtime`, an empty infrastructure namespace.
Migration 002 creates `stoppy_auth.players`, `auth_sessions`, and
`auth_refresh_tokens`, with canonical username uniqueness, FK/check constraints,
same-family refresh replacement and one unconsumed credential per family.
There are no competitive or mutation-idempotency tables. Feature transactions
retain the migration runner's uncertain-BEGIN/COMMIT and failed-rollback
discard policy; expensive password hashing occurs outside transactions.
Down migrations, nontransactional SQL and zero-downtime schema evolution are
outside this foundation. Use reviewed forward migrations and backups instead.

## Verification

```sh
npm run typecheck
npm run build
npm test
```

Unit tests use Fastify injection and fake database connections: no Docker,
PostgreSQL service, network socket or production backend is needed. TypeScript
strict checking is configured; a separate lint tool is not installed.

Optional real PostgreSQL tests require a separate empty disposable database:

```sh
docker compose exec postgres createdb -U stoppy stoppy_test
NODE_ENV=test TEST_DATABASE_URL=postgresql://stoppy:local-development-only@127.0.0.1:5433/stoppy_test npm run test:integration
```

Integration tests fail explicitly when configuration is missing. They refuse an
existing migration ledger/runtime/auth namespaces, create only their own fixtures,
verify connectivity, migrations, real account/session constraints, concurrent
registration/refresh, restart persistence and revocation, then remove their
namespaces and ledger. Do not point them at a shared or production database.
The integration suite also uses an ephemeral loopback HTTP socket to verify
that Fastify drains an in-flight request before closing the database pool.

## Operations and boundaries

SIGINT/SIGTERM coalesce into one HTTP drain/pool closure, with a 10-second
shutdown deadline. The deadline remains armed if close rejects or stalls;
repeated signals cannot trigger duplicate cleanup. Shutdown errors use a generic
message without exception/credential details.
Pool size, acquisition/query timeouts, request timeouts and body limits are
bounded. The server does not trust proxy headers, enable CORS, accept browser
cookies, log request bodies/query strings, or expose database readiness details.
Use an HTTPS ingress, appropriate rate limits, deployment secrets and a trusted
PostgreSQL certificate before production exposure. There is no TLS termination
or competitive endpoint in this service yet. Authentication does not establish
client score validity or implement anti-cheat enforcement.

GP mutation validation, transactionally stored mutation idempotency,
run validation/anti-cheat, League/Knockout persistence and settlement remain
future work. No automatic mutation retries or client PP acceptance are added.

# Stoppy Backend Foundation

Session 44 adds an isolated Node.js 24 / TypeScript / Fastify application with
PostgreSQL connectivity. Session 45 adds PostgreSQL-backed authentication
and Session 46 adds the internal GP ledger/idempotency foundation and atomic
registration opening snapshots. Flutter still defaults to mocks. League,
Knockout and public GP earning/spending endpoints remain unimplemented.

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
Migration 003 creates `stoppy_economy.gp_ledger` and durable `gp_mutations` with
source/idempotency uniqueness and append-only guards. It backfills existing
balances as zero-delta observations, not earned credits. New registration inserts
the account (default 5 GP), one matching opening snapshot, session and refresh
credential in the same transaction. Internal GP credit/debit execution and durable
accepted/rejected replay exist; no live reward, League/Knockout fee, purchase or
ad producer is connected. No competitive tables are implemented. Feature transactions
retain the migration runner's uncertain-BEGIN/COMMIT and failed-rollback
discard policy; expensive password hashing occurs outside transactions.
Down migrations, nontransactional SQL and zero-downtime schema evolution are
outside this foundation. Use reviewed forward migrations and backups instead.

## Session 46 deployment gate

An unrestricted rolling upgrade from Session 45 is **not safe**. An old worker
can register an account after migration 003's one-time backfill, leaving no opening
snapshot. The new economy service deliberately fails closed for that account.

1. Block new registrations at ingress before migration 003. Drain in-flight
   registrations and stop old backend workers; do not rely on the migration's
   temporary table lock to prevent later old-worker writes.
2. Keep registrations and economy producers disabled. With separate migration
   credentials, run the checksum-protected migration command and confirm success
   through version 003. Never edit or rerun approved SQL outside its ledger.
3. Deploy/start only workers containing the registration opening-snapshot change,
   using restricted runtime credentials. Migration 003 must exist before these
   workers accept registrations. Never restore old registration workers as an
   availability fallback after the backfill; retain the gate if deployment fails.
4. Check schema compatibility, runtime privileges and the query below. It must
   return zero before reopening registration or enabling future economy producers.
   Investigate any missing baseline; do not silently grant GP or fabricate history.
5. Reopen registration only to the updated worker set. Keep all GP business
   producers disabled until their separate server-authoritative implementations
   are approved. Recheck the baseline gate before enabling them in a future release.

Read-only baseline verification (returns a count, not identities or balances):

```sql
SELECT count(*) AS players_without_opening_snapshot
FROM stoppy_auth.players AS p
WHERE NOT EXISTS (
  SELECT 1 FROM stoppy_economy.gp_ledger AS l
  WHERE l.player_id = p.id AND l.movement_type = 'opening_snapshot'
);
```

The existing `/ready` endpoint checks connectivity only. It does not implement
these deployment gates, schema verification or role checks. The deployment
environment must enforce them; this document does not configure an orchestrator.

## PostgreSQL runtime-role boundary

Use separate credentials for the schema-owning **migration role** and the
**application runtime role**. Both commands currently read `DATABASE_URL`; supply
the appropriate secret separately to each process. Do not pass migration
credentials to `npm start`. Compose's bootstrap user and the privileged integration
test provisioner are development tools, not safe production application accounts.

The runtime role must be a non-owner, non-superuser with no CREATEDB, CREATEROLE,
REPLICATION or BYPASSRLS rights and no membership/SET ROLE path to a privileged
role. It must not own the database, schemas, tables or audit function, have CREATE
on protected schemas, change trigger/function definitions, or set replication
parameters that suppress triggers. Audit PUBLIC grants and role memberships too;
NOINHERIT alone does not prevent explicit SET ROLE escalation. Do not grant blanket
ALL privileges, audit UPDATE/DELETE/TRUNCATE, or migration-ledger writes.

The currently implemented SQL needs only the following runtime privileges:

| Object | Required privileges |
| --- | --- |
| Target database | CONNECT |
| `stoppy_auth`, `stoppy_economy` | USAGE, not CREATE |
| `players` | SELECT; INSERT (`id`, `username`, `password_hash`, `created_at`); UPDATE (`game_points`) |
| `auth_sessions` | SELECT; INSERT (`id`, `player_id`, `created_at`, `expires_at`); UPDATE (`revoked_at`) |
| `auth_refresh_tokens` | SELECT; INSERT (`id`, `session_id`, `token_digest`, `created_at`, `expires_at`); UPDATE (`consumed_at`, `replaced_by`) |
| `gp_mutations` | SELECT; INSERT (`id`, `player_id`, `operation_name`, `operation_version`, `idempotency_key`, `fingerprint_version`, `request_fingerprint`, `outcome_status`, `semantic_outcome`, `resolved_context`) |
| `gp_ledger` | SELECT; INSERT (`id`, `player_id`, `mutation_id`, `movement_type`, `reason`, `source_type`, `source_id`, `delta`, `balance_before`, `balance_after`) |

SELECT covers the existing auth `SELECT *`/`RETURNING *` statements. Defaults and
generated fields do not require INSERT grants. There are no application sequences
or cleanup DELETE operations requiring additional grants. Trigger execution does
not require granting runtime ownership or direct invocation of the audit function.

TLS/configuration validation, parameterized queries, constraints, append-only DML
guards and transaction discipline are implemented. Actual role creation, grants,
PUBLIC privileges, ownership and credential separation are deployment obligations;
startup does not certify them. Least privilege prevents protected-object DDL and
audit rewrites but cannot prove every SQL statement using the permitted wallet
UPDATE/ledger INSERT grants is paired correctly. That coupling remains the trusted
economy service's transaction boundary; no arbitrary SQL or GP HTTP API is exposed.

The restricted-role integration cases provision a temporary login with these
column-specific grants, then use a separate authenticated pool to execute real
registration, auth lifecycle, credit/debit and replay. They check denied audit
rewrites, trigger disabling, schema/function changes and role escalation. The
privileged provisioner creates/removes only the disposable fixture role/grants;
it is not the identity performing those application operations. Passing these
local tests does not prove that production credentials have been provisioned safely.

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
Restricted-role cases require the disposable-database provisioner to create/drop
temporary roles and grant privileges on its test-owned objects. Fixture passwords
are generated in memory; pools are closed and roles/grants removed afterward.

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

Internal GP validation, atomic balance/ledger changes and durable mutation
idempotency are implemented; see `src/economy/README.md`. Server-authoritative run
rewards/anti-cheat, daily/warmup GP, League/Knockout fees, purchases, competitive
persistence and settlement remain deferred. No automatic mutation retries,
public GP mutation endpoints or client PP acceptance are added.

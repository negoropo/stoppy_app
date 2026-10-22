# Stoppy Backend Foundation

Session 44 adds an isolated Node.js 24 / TypeScript / Fastify application with
PostgreSQL connectivity. Flutter still defaults to mocks. Only operational
health endpoints exist here: the connected Flutter Auth/League/Knockout clients
do not yet have corresponding server feature implementations.

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

Invalid configuration exits with code 1 before binding. Unavailable PostgreSQL
also fails startup and closes the pool. Startup never runs migrations implicitly:
run the migration command as an explicit deployment step.

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
There are no player, economy, competitive, session or mutation-idempotency tables.
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
existing migration ledger/runtime namespace, create only their own fixtures,
verify connectivity, migration locking/replay/rollback and readiness, then remove
those fixtures. Do not point them at a shared or production database.
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
PostgreSQL certificate before production exposure. There is no TLS termination,
authentication, JWT issuance or competitive endpoint in this service yet.

Server-authoritative identity, GP, transactionally stored mutation idempotency,
run validation/anti-cheat, League/Knockout persistence and settlement remain
future work. No automatic mutation retries or client PP acceptance are added.

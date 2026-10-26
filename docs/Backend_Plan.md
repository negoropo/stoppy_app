# Backend Plan

## Session 45 Authentication Implementation (Pending Review)

The server now implements registration, login, strict refresh rotation and
authenticated profile retrieval against PostgreSQL. Migration 002 introduces
`stoppy_auth.players`, `auth_sessions` and `auth_refresh_tokens`. Account identity
is server-generated; only Argon2id password hashes and refresh-token digests
persist. Initial GP is 5; no economy or competitive mutation is implemented.
Flutter contracts and default mock runtime are unchanged. Remote logout remains
deferred; see `backend/README.md` for the temporary credential policies and
production blockers. The Session 44 description below is historical.

## Session 44 Implemented Foundation

The isolated `backend/` application now uses Node.js 24, TypeScript, Fastify and
the `pg` PostgreSQL driver. It implements only operational health/readiness,
configuration validation, bounded connection pooling, safe API errors and
explicit versioned SQL migrations. See `backend/README.md` for setup and tests.

Fastify provides HTTP routing, injection-based tests and orderly shutdown. A
small SQL migration runner keeps ordered files/checksums in
`public.stoppy_schema_migrations`, serializes execution with a transaction-scoped
advisory lock, and commits/rolls back a whole batch on one acquired connection.
Migration 001 creates an empty infrastructure namespace only. Database startup
connectivity is mandatory; migrations are a separate operator command.

This is the first server implementation, not the implementation of the Flutter
feature endpoints prepared in Sessions 31-43. Auth/JWT, GP, purchases, League,
Knockout, run validation, server-side mutation-idempotency records, settlement
and anti-cheat enforcement remain future server work. No client score is
accepted or persisted by this foundation. Flutter remains mock-first and its
existing opt-in backend contracts are unchanged.

## Architecture

### Client

- Flutter App

### Backend

- Custom Backend API
- Node.js / TypeScript / Fastify foundation in `backend/`
- REST API
- Server-authoritative competitive logic

### Database

- PostgreSQL
- `pg` connection adapter and infrastructure-only SQL migrations

### Optional Future Components

- Redis
- Background Workers
- Replay/Event Storage

## Responsibilities

### Client

- UI
- Local animations
- Input collection
- Temporary state

The client should remain responsive and ergonomic, but it must not be trusted for competitive or economy decisions.

### Server

- Authentication
- GP economy
- League participation
- League settlement
- Knockout registration
- Knockout settlement
- Hall of Fame
- Competitive records
- Run submission processing
- Run validation
- Anti-cheat validation

The server owns every state transition that affects competitive integrity, economy, rankings, or public records.

## Authoritative Rules

Server must be authoritative for:

- GP balance
- Purchases
- League entry
- League rankings
- League settlement
- Knockout registration
- Knockout duel results
- Knockout advancement
- Hall of Fame
- Competitive achievements

The Flutter app may continue to use mock repositories during development, but production repository implementations must treat the backend as the source of truth.

## Background Jobs

Future backend workers will be responsible for:

- Weekly league settlement
- Monthly knockout lifecycle transitions
- Daily knockout round settlement
- Hall of Fame updates
- Records recalculation
- Data cleanup tasks

These jobs must run server-side only.

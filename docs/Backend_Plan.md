# Backend Plan

## Architecture

### Client

- Flutter App

### Backend

- Custom Backend API
- REST API
- Server-authoritative competitive logic

### Database

- PostgreSQL

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
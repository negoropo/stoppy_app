# Architecture — Stoppy 🧠

## Session 46 Registration Opening Snapshot (Step 3)

`PostgresAuthRepository.register` now creates the player's GP opening snapshot
through the transaction-bound `GpRepository`, between account and session/token
insertion on the existing connection. The authoritative database default stays
5 GP; the snapshot observes it with zero delta and no credit/debit mutation.
All registration rows commit or roll back together. Duplicate opening identities
abort rather than being silently ignored; uncertain COMMITs are not retried.
Existing accounts retain migration 003's backfill unchanged. Auth/profile payloads
and Flutter mock-default runtime are unchanged. No GP business reward, fee or
mutation HTTP route is activated; this does not complete Session 46.

## Session 45 Server Authentication (Pending Review)

Four existing Flutter auth contracts now have PostgreSQL-backed server handlers:
registration, login, refresh, and authenticated profile. Fastify routes delegate
to `AuthService`, password/token adapters and `PostgresAuthRepository`. Injected
clocks and repository interfaces support deterministic tests. Flutter defaults,
session storage, refresh coordination and local-only logout remain unchanged.

Migration 002 creates a dedicated `stoppy_auth` namespace. Accounts and initial
sessions are inserted atomically; Argon2 work occurs outside transactions.
Refresh locks the session family, re-reads token state after locking, and commits
replay revocation before returning rejection. Feature transactions preserve
Session 44 uncertain-BEGIN/COMMIT and failed-rollback connection discard rules,
without retries. JWT identity is checked against a live, non-revoked DB session.
Auth uses Argon2id and Ed25519 JWTs through maintained libraries, strict input
bounds and bounded process-local rate/hash-work limits. Signing keys, issuer
and audience are explicit in production. See `backend/README.md` for temporary
password/access-lifetime policies and remaining release requirements.

No League, Knockout, GP mutation or competitive validation handler is added.
The Session 44-only description below documents the historical foundation.

## Session 44 Server Foundation

`backend/` is the first isolated custom server: Node.js 24, TypeScript, Fastify,
and PostgreSQL through `pg`. It has its own npm lockfile/build/test configuration;
Flutter code, repository contracts and mock-default wiring are unchanged.

Only `/api/v1/health` (process liveness) and `/api/v1/ready` (PostgreSQL
connectivity) are implemented. They reuse the client API envelope/error codes.
Startup validates configuration and checks the database before listening;
shutdown drains requests and closes the pool. Request/query/acquisition timeouts,
body limits, safe error responses and conservative proxy/logging defaults are
explicit. HTTPS ingress, rate limiting and production deployment remain future
operational work.

Migrations are explicit operator commands using ordered SQL files, checksums,
a version ledger and transactional locking. The first migration creates an
empty infrastructure namespace, not competitive tables. Unit tests inject a
database adapter; optional tests use an explicitly disposable real PostgreSQL
database. Docker Compose provides local PostgreSQL but is not needed for unit tests.

Earlier statements about no backend/server persistence are historical as of
Session 43. Session 44 adds infrastructure only: Flutter's Auth/League/Knockout
HTTP integrations still have no corresponding feature handlers in this server.
Authentication/JWT, GP/economy, run acceptance/anti-cheat, server-side mutation
idempotency, competitive tables and settlement/lifecycle jobs remain deferred.
No client PP claim is accepted as an authoritative result.

## 1. Visão Geral

Stoppy é uma aplicação mobile competitiva multiplayer baseada em skill, com:

* Gameplay determinístico
* Ranking global em tempo real
* Liga semanal por divisões
* Torneios knockout
* Economia virtual (GP)
* Sistema anti-cheat robusto
* Escalabilidade para milhares/milhões de jogadores

A arquitetura é desenhada para garantir:

* Consistência entre dispositivos (iOS vs Android)
* Integridade competitiva
* Baixa latência
* Alta escalabilidade

---

## 2. Stack Tecnológica

### Frontend

* Flutter (Dart)
* Android Studio
* Xcode (iOS)

### Backend

* Custom backend
* REST API
* Server-authoritative competitive logic

### Base de Dados

* PostgreSQL (relacional)

### Serviços adicionais

* Autenticação custom
* Analytics
* Crash reporting

---

## 3. Arquitetura Geral

Sistema dividido em 3 blocos principais:

1. **Cliente (Mobile App)**
2. **Backend (API + lógica competitiva)**
3. **Base de dados**

---

## 4. Arquitetura do Cliente (Flutter)

### 4.1 Estrutura de pastas

/lib
/core
/constants
/utils
/services
/features
/game
/auth
/league
/knockout
/profile
/shared
/widgets
main.dart

---

### 4.2 Separação de responsabilidades

#### Game Engine (CRÍTICO)

* Lógica isolada da UI
* Determinística
* Reutilizável
* Testável

#### UI Layer

* Apenas renderização
* Sem lógica crítica

#### State Management

Sugestão:

Preferred solution: Riverpod.
Riverpod is not yet installed in this session.  

---

### 4.3 Princípios

* Separação clara entre lógica e UI
* Código modular
* Testabilidade
* Baixo acoplamento

### 4.4 Authentication session persistence

Backend runtime owns one `AuthSessionStore` shared by the HTTP client and auth
repository. Its secure implementation serializes only a versioned server-issued
session (access token, optional refresh token, expiry) through platform secure
storage. Mock runtime continues to use in-memory storage and never constructs a
secure-storage adapter. Corrupt, incomplete, unsupported, or expired sessions
without a refresh token are deleted safely at load time.

Refresh coordination stays in the auth data layer, outside widgets. It shares
one in-flight request across callers, atomically persists fully validated
replacements, clears invalid/unauthorized credentials, and preserves sessions
for temporary failures. HTTP never injects expired tokens and has no generic
automatic retry policy, protecting competitive and economy mutations.

### 4.5 Authentication integration readiness

Authentication is ready to act as the boundary for future backend-backed
features, but competitive feature integration must still wait for a reachable
server environment and finalized authorization rules.

Ownership rules:

* `AuthGate` owns presentation transitions for startup restoration, login,
  registration, logout, recoverable startup failures, and stale async result
  rejection.
* `GameScreen` only reports logout intent through a callback. It must not read
  secure storage or mutate authentication state directly.
* `AuthRepository` remains the domain-facing authentication boundary for
  presentation code.
* `BackendAuthRepository` owns backend registration/login, profile restoration,
  local logout cleanup, and domain-safe auth errors.
* `AuthSessionStore` owns session persistence. `SecureAuthSessionStore` is used
  only by backend runtime; mock runtime remains in memory and does not construct
  secure storage.
* `AuthSessionRefreshCoordinator` owns refresh coordination so concurrent
  restoration calls cannot rotate the same refresh credential more than once.
* `HttpBackendApiClient` owns Authorization header construction. Public auth
  endpoints never receive a Bearer token, protected endpoints receive only a
  current non-expired access token, and caller-provided Authorization headers
  are removed before session authorization is applied.

Current logout behavior is local-only: backend runtime clears the local
`AuthSessionStore`, and server-side token invalidation is intentionally
deferred until the backend exposes a logout/invalidation endpoint. Local logout
must remain idempotent so repeated logout attempts cannot break the UI
lifecycle.

Prerequisites before League backend integration:

* Reachable backend environment for development and CI.
* Finalized registration, login, refresh, and authenticated profile response
  contracts.
* Server-issued access and refresh tokens with documented expiration behavior.
* Stable API error envelope with authentication, authorization, validation, and
  idempotency failures.
* PostgreSQL-backed player identity linked to authenticated profiles.
* Authorization rules for every League endpoint.
* Idempotency strategy for competitive mutations such as league entry and run
  submission.
* Backend integration tests or a deterministic test server for authenticated
  League flows.
* Server-side validation rules for GP balance, League entry cost, League run
  submission, rankings, and settlement.

---

## 5. Game Engine

### 5.1 Requisitos

* Determinístico (mesmos inputs = mesmos outputs)
* Independente da UI
* Baseado em tempo e física controlada

---

### 5.2 Responsabilidades

* Movimento da bola
* Movimento da Safe Zone
* Movimento do Target
* Deteção de colisões
* Cálculo de PP baseado no tier ativo
* Progressão do PP tier após acertos no Target
* Progressão de dificuldade

---

### 5.3 Randomização

* Baseada em seed
* Seed gerada no backend
* Garantia de igualdade entre dispositivos

---

## 6. Backend

### 6.1 Responsabilidades principais

* Autenticação de jogadores
* Gestão de GP
* Registo de runs
* Validação de pontuações
* Cálculo de rankings
* Gestão de ligas
* Gestão de torneios knockout
* Anti-cheat

---

### 6.2 Estrutura lógica

Serviços:

* Auth Service
* Player Service
* Game Session Service
* League Service
* Ranking Service
* Tournament Service
* Anti-Cheat Service

---

### 6.3 API

Versioned REST contract families:

* `/api/v1/auth/*`
* `/api/v1/player/*`
* `/api/v1/league/*`
* `/api/v1/knockout/*`
* `/api/v1/runs/*`

Exact request paths are centralized in `ApiContract` so repositories and tests
share one source of truth for public authentication paths, protected gameplay
submission paths, League paths, and Knockout paths.

---

## 7. Base de Dados

### 7.1 Entidades principais

* Player
* League
* Division
* Run
* GameSession
* Tournament
* Match

---

### 7.2 Dados armazenados

#### Player

* id
* username
* email
* país
* GP
* stats

#### Run

* player_id
* score (PP)
* timestamp
* seed
* inputs

#### League Snapshot

* semana
* divisão
* ranking final

---

## 8. Sistema de Rankings

* Atualização quase em tempo real
* Cache para performance
* Snapshot final semanal

---

## 9. Sistema Anti-Cheat

### 9.1 Princípios

* Cliente não é confiável
* Backend valida tudo

---

### 9.2 Estratégias

* Seeds determinísticas
* Replays de inputs
* Validação física das runs
* Deteção de padrões impossíveis
* Rate limiting

---

### 9.3 Futuro

* Machine learning para deteção de fraude
* Flagging automático de contas

---

## 10. Sincronização Cross-Platform

Garantir que:

* iOS e Android têm comportamento idêntico
* Mesma seed → mesma run

---

## 11. Escalabilidade

### 11.1 Estratégia

* APIs stateless
* Load balancing
* Horizontal scaling

---

### 11.2 Processos pesados

Executados em background:

* Fecho semanal da liga
* Cálculo de rankings
* Emparelhamento knockout

---

## 12. Performance

* Minimizar chamadas ao backend
* Uso de cache
* Compressão de dados

---

## 13. Monetização

* Compra de GP
* Remoção de anúncios
* Ads (para utilizadores não premium)

---

## 14. Segurança

* HTTPS obrigatório
* Tokens de autenticação
* Proteção contra spam/bots

---

## 15. Versionamento

* Git

Branches:

* main
* dev
* feature/*

---

## 16. Ambientes

* Dev
* Staging
* Production

---

## 17. Logging & Monitoring

* Logs centralizados
* Crash reporting
* Alertas

---

## 18. Testes

* Unit tests (game engine)
* Integration tests (backend)
* UI tests (Flutter)

---

## 19. Roadmap Técnico

Ordem recomendada:

1. Game Engine
2. UI básica
3. Sistema de pontuação
4. Backend base
5. Liga
6. Knockout
7. Anti-cheat
8. Escala

---

## 20. Princípios Fundamentais

* Gameplay first
* Fairness acima de tudo
* Simplicidade inicial → complexidade controlada
* Tudo validado no backend

---

## 21. Future Backend Architecture

The target backend architecture is a custom backend with a PostgreSQL database and REST API. Firebase will not be used as the primary backend.

### Repository Contracts

* Repository contracts remain unchanged.
* Mock repositories remain available for tests.
* Backend repositories will replace mocks.
* UI must never depend on backend implementation details.

The app should continue to depend on domain-facing repository contracts. Production implementations can call REST endpoints, while tests and local development can keep using mock repositories.

### Environment Configuration and Wiring

`AppEnvironment` is the environment configuration boundary for repository selection.

* `RepositoryRuntime.mock` remains the default runtime.
* `RepositoryRuntime.backend` selects backend repositories; authentication,
  implemented League surfaces, Knockout registration, reads and run submission
  are connected as of Session 43. Server-only lifecycle writes remain disconnected.
* `STP_REPOSITORY_RUNTIME` can later select `mock` or `backend`.
* `STP_API_BASE_URL` can later provide the REST API base URL.

`RepositoryFactory` is the composition root for repositories. Widgets receive repository contracts and must not decide whether the implementation is mock or backend.

### Auth Session Architecture

`AuthSession` and `AuthSessionStore` are the current token/session boundary.

* Backend runtime uses `SecureAuthSessionStore`.
* Mock runtime uses memory-only authentication and test/runtime fakes can use
  `InMemoryAuthSessionStore`.
* `BackendAuthRepository` and `HttpBackendApiClient` share one
  `AuthSessionStore` instance in backend runtime.
* The secure session payload persists only the server-issued access token,
  optional refresh token, and expiration timestamp.
* Player profiles, GP, League state, Knockout state, and other competitive
  state are deliberately not stored in the secure session payload.

### DTO and Serialization Boundary

* Backend DTOs live in the data layer.
* Domain models remain the UI-facing and engine-facing contract.
* DTOs translate REST JSON payloads into domain models.
* Serialization must use explicit `toJson` / `fromJson` methods.
* Feature mappers express the DTO-to-domain conversion explicitly.

This boundary keeps backend payload shape independent from Flutter widgets and domain rules. It also gives future backend repositories a stable place for versioning, migration, and compatibility logic.

### API Result Standardization

* REST responses use a standard success/error envelope.
* API errors use typed error codes plus a user/debug message.
* Backend repositories convert API errors into repository-level failures or exceptions.
* Skeleton backend repositories must fail explicitly until real networking is connected.
* UI should receive domain-facing errors, not raw transport details.

### Future API Client

`PendingBackendApiClient` is a non-network placeholder.

* It remains useful for explicit tests and intentionally disconnected flows.
* `HttpBackendApiClient` is now the real REST client implementation behind the same `BackendApiClient` contract.

### Session 29 Contract Hardening

The backend preparation layer now defines a versioned `ApiContract`, defensive JSON decoding, JWT session DTOs, and validation claim DTOs.

* Public endpoints use `/api/v1` and are centralized in `ApiContract`.
* DTO decoders validate field shape before domain models are created.
* Malformed response payloads become typed API errors.
* Auth responses keep profile and JWT/session transport data in data-layer DTOs.
* Competitive run validation claims are transport contracts only; they do not alter local gameplay or scoring.
* Token refresh is now implemented by the authentication data layer.
* Backend authentication, selected League backend integrations, Knockout registration, Knockout backend reads, and Knockout run submission are connected; server-only Knockout lifecycle mutations remain disconnected, and Flutter contains no PostgreSQL implementation.

### Session 30 Networking Client Preparation

`HttpBackendApiClient` now provides the future production implementation of the existing `BackendApiClient` contract.

* `HttpTransport` keeps package-specific HTTP types out of repositories and contracts.
* The backend client is created only for explicit `RepositoryRuntime.backend` selection.
* Mock repositories remain the default runtime.
* Auth headers are derived from `AuthSessionStore` and omitted for expired sessions and public auth endpoints.
* HTTP failures are converted to typed `ApiError` values before reaching a repository.
* No automatic retry, League/Knockout backend endpoint call, or server persistence is activated in this session.

### Sessions 31–32 Backend Authentication Integration

`BackendAuthRepository` connects the existing auth contract to the prepared HTTP client only when backend runtime is explicitly selected.

* Backend registration and login map `AuthRequestDto` to a shared
  `AuthResponseDto` completion pipeline.
* Backend runtime persists sessions securely through `SecureAuthSessionStore`.
* Mock runtime remains memory-only and does not initialize secure storage.
* `AuthSessionRefreshCoordinator` owns refresh-token execution.
* Concurrent refresh attempts are coalesced so the same refresh credential is
  not rotated more than once.
* Invalid refresh credentials clear the local session when cleanup succeeds.
* Temporary refresh failures preserve refreshable credentials for a later retry.
* `HttpBackendApiClient` excludes Bearer tokens from login, registration, and
  refresh requests.
* Expired access tokens are never sent as Bearer tokens.
* League backend reads, weekly entry mutation, League run submission, Knockout
  backend reads, registration, and run submission are connected in backend runtime.
  League settlement and Knockout lifecycle mutations
  remain disconnected.

### Session 37 League Mutation Contract Preparation

League backend mutation contracts are prepared. Weekly League entry and League
run submission are the connected competitive backend mutations.

* `Idempotency-Key` is centralized in `ApiContract`.
* `IdempotencyKey` normalizes and validates caller-owned retry keys.
* League entry DTOs describe the server-authoritative GP deduction and weekly
  entry result now consumed by `BackendLeagueRepository.enterWeeklyLeague`.
* League run submission DTOs describe the server-authoritative run claim,
  validation result, and accepted/rejected/idempotent replay states now consumed
  by `BackendLeagueRepository.submitLeagueRun`.
* `BackendLeagueRepository.enterWeeklyLeague` sends `POST /api/v1/league/enter`
  with an empty object body and caller-owned `Idempotency-Key`.
* Accepted and idempotent replay entry responses map to authoritative League
  entry state, with optional profile projection carried by `LeagueEntryResult`
  so backend runtime does not need client-side GP deduction. Rejected responses
  map through repository-domain errors.
* League run submission sends a finalized run claim with caller-owned
  `Idempotency-Key`; backend validation and persistence remain authoritative.
  Ambiguous transport/service failures keep the finalized claim retryable from
  the final-results UI with the same key and without automatic retries.
* League settlement remains disconnected from ordinary Flutter backend runtime.
* Mock runtime remains the default runtime.
* League reads, gameplay, Knockout, Purchase, and Ads behavior are unchanged.

### Sessions 40-41 Knockout Mutation Boundary And Registration Integration

At Session 41, Knockout registration became the first connected backend
Knockout mutation. Run submission was connected later in Session 43;
server-only lifecycle mutations remain disconnected.

* Knockout repository mutations are classified as:
  * player-initiated: monthly tournament registration;
  * competitive run: Knockout duel run submission;
  * server/internal only: registration close, tournament start, round
    settlement, bracket advancement, repechage, tournament completion, champion
    persistence, records, and Hall of Fame updates.
* Tournament registration uses an authenticated empty request body while the
  backend owns player identity, 25 GP deduction, duplicate detection,
  registration-window validation, and authoritative entry/profile state.
* Knockout registration requires caller-owned `Idempotency-Key` values.
  Replaying an unresolved logical registration must reuse the same key; new
  logical registrations require new keys.
* At Session 41, run submission remained disconnected. Session 43 activates it
  with its own caller-owned `Idempotency-Key`, independent of registration.
* Knockout run submissions are validation claims only. The client may provide
  structural run evidence, but active duel eligibility, accepted score,
  duplicate detection, duel aggregation, and advancement remain
  server-authoritative.
* `BackendKnockoutRepository` must not silently fall back to mock behavior.
  Disconnected mutations continue to fail explicitly until each endpoint is
  activated in its own session.
* No automatic retry, run-submission endpoint, settlement endpoint, PostgreSQL
  persistence, or gameplay behavior change is introduced by this integration.

### Session 42 Knockout Backend Read Integration

`BackendKnockoutRepository` now consumes the backend read projections required
by the existing Knockout UI/runtime.

* Connected reads:
  * current tournament;
  * authenticated current-player entry;
  * authenticated player tournament status;
  * authenticated active duel;
  * authenticated player records;
  * authenticated player tournament history;
  * champion-only Hall of Fame.
* Player-specific backend reads use authenticated self-projection semantics and
  do not send caller-provided player IDs as authority.
* The backend remains authoritative for lifecycle, entries, status, duel
  assignment, scores, run counts, byes, eliminations, champion state, records,
  and Hall of Fame projections.
* At Session 42, registration was the only connected Knockout mutation; run
  submission was subsequently connected in Session 43.
* Tournament close/start, round settlement, bracket
  advancement, repechage, champion writes, records writes, and Hall of Fame
  writes remain disconnected from ordinary Flutter backend runtime.

### Session 43 Knockout Backend Run Submission

Knockout run submission is now connected through `BackendKnockoutRepository`
using the prepared claim/response DTOs and caller-owned `Idempotency-Key`.
This supersedes the earlier session notes marking run submission disconnected.
Optional tournament/start-time metadata on `KnockoutRun` supplies claim context
without changing mock scoring. The existing bool repository contract exposes
accepted/replay resolution; server scores are validated and never reconstructed
or applied as local competitive authority.

GameScreen first freezes logical run identity, player, final PP and timestamps.
Transient tournament/duel read failures retain these values for explicit
context-read recovery. Once context resolves, it constructs the claim/key once.
After network, timeout, server, malformed-response or unexpected-response POST
failures, explicit retry reuses the same claim/key without refetching context.
Definitive outcomes clear pending state; restart is blocked during context
resolution, submission, or unresolved retryable failure. Attempt identity guards
reject stale asynchronous completions. Registration keys
remain independent. No automatic retry exists, and mocks remain the default.
Tournament start/close, settlement, bracket/bye/repechage progression,
completion, champion, records and Hall of Fame writes remain disconnected
from ordinary backend client control.

Accepted/replay responses must preserve the submitted logical run ID, match ID
and round number. Server-owned player identity is not compared with the client
claim; accepted PP may be corrected by the server. Contradictory associations
are malformed responses. Structural DTO checks are not anti-cheat enforcement:
the current POST does not automatically include complete validation evidence.
All pending recovery state lives in GameScreen memory; process-restart recovery
and persistent offline queues remain deferred. PostgreSQL persistence and
server-side idempotency storage are future backend responsibilities.

Known deferred League issue: fixed-duration arithmetic across a Lisbon DST
transition week can shift the displayed local settlement hour. The rule remains
Sunday 23:59 Europe/Lisbon. Deterministic widget dates/clock injection stabilize
tests but do not fix transition-week scheduling correctness.

### Domain Logic

* Domain logic should stay reusable where possible.
* Client-side domain logic may support UI previews, local feedback, and deterministic tests.
* Competitive validation becomes server-authoritative.

Reusable domain logic is still useful, but any result affecting economy, rankings, league state, knockout progression, Hall of Fame, or competitive achievements must be confirmed by the backend.

### Server Authority

The future backend must be authoritative for:

* Authentication
* GP balance
* Purchases
* League entry
* League rankings
* League settlement
* Knockout registration
* Knockout duel results
* Knockout advancement
* Hall of Fame
* Competitive achievements
* Run validation
* Anti-cheat validation

The Flutter client is not trusted. It collects inputs, renders animation, displays temporary state, and submits run claims to the backend for validation.

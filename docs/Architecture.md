# Architecture — Stoppy 🧠

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
* `RepositoryRuntime.backend` creates backend repository skeletons.
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
* No League/Knockout repository-to-backend feature call or PostgreSQL access is implemented yet.

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
* League and Knockout backend repositories remain disconnected skeletons.

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

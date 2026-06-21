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
* Cálculo de RP
* Cálculo de PP
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

Endpoints típicos:

* /auth/register
* /player/profile
* /game/start
* /game/submit-run
* /league/ranking
* /league/join
* /tournament/join
* /tournament/status

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

### Auth Session Preparation

`AuthSession` and `AuthSessionStore` prepare the future token/session layer.

* Tokens are not used for real networking yet.
* `InMemoryAuthSessionStore` is temporary and testable.
* A secure device/session store can replace it later without changing repository contracts.

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

* It prevents accidental real network calls before the networking session.
* It preserves the final API client shape.
* A real REST implementation should replace it behind the same `BackendApiClient` contract.

### Session 29 Contract Hardening

The backend preparation layer now defines a versioned `ApiContract`, defensive JSON decoding, JWT session DTOs, and validation claim DTOs.

* Public endpoints use `/api/v1` and are centralized in `ApiContract`.
* DTO decoders validate field shape before domain models are created.
* Malformed response payloads become typed API errors.
* Auth responses keep profile and JWT/session transport data in data-layer DTOs.
* Competitive run validation claims are transport contracts only; they do not alter local gameplay or scoring.
* No HTTP client, network transport, token refresh, or PostgreSQL access is implemented yet.

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

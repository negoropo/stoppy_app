# App_Dev_Status

---

## 1. Projeto

Stoppy é uma aplicação mobile competitiva baseada em precisão e timing, onde jogadores competem em ligas semanais e torneios knockout.

### Características principais:

* Gameplay baseado em skill (não pay-to-win)
* Liga semanal com divisões progressivas
* Torneios knockout 1vs1
* Economia interna com Game Points (GP)
* Sistema de progressão dinâmica de dificuldade
* Sistema de ranking global
* Sistema anti-cheat robusto (planeado)
* Compatibilidade cross-platform (iOS e Android)

---

## 2. Guia de Estilo

### Linguagem

* Código em inglês
* Documentação em inglês

### Convenções

* Classes: PascalCase
* Variáveis: camelCase
* Ficheiros: snake_case

### Estrutura de código

* Separação clara entre UI e lógica
* Game Engine isolado da UI
* Código modular e reutilizável

### Comentários

* Obrigatórios em:

  * lógica do Game Engine
  * cálculos de pontuação
  * regras de liga
  * qualquer lógica não trivial

---

## 3. Comandos

### Setup

```bash
flutter pub get
```

### Desenvolvimento

```bash
flutter run
```

### Build

```bash
flutter build apk
flutter build ios
```

### Testes

```bash
flutter test
```

---

## 4. Estrutura do Projeto

Estrutura alvo:

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

/docs
Game_Rules.md
Architecture.md
App_Dev_Status.md

---

## 5. Decisões Técnicas

### Frontend

* Flutter (Dart)

### Backend

* A definir (Firebase vs custom)

### Base de Dados

* A definir

### State Management

* Preferência: Riverpod

---

## 6. Notas Importantes

* O Game Engine será desenvolvido antes do backend
* Toda a lógica crítica deve ser validada no backend (futuro)
* Cliente não é confiável (anti-cheat)
* Todas as regras estão definidas em `Game_Rules.md`

---

## 7. Plano por Sessões

---

### Fase 0 — Setup

#### Sessão 1: Setup inicial

🎯 Objetivo:
Ter o projeto Flutter a correr em iOS e Android

📦 Entregáveis:

* Projeto criado
* App a correr em iOS Simulator
* App a correr em Android Emulator

🛠️ Tarefas:

* Instalar Flutter
* Verificar com `flutter doctor`
* Criar projeto `stoppy_app`
* Abrir no Android Studio
* Configurar simuladores
* Executar app

✅ Critério de conclusão:

* App default corre em ambos dispositivos

---

#### Sessão 2: Estrutura base + documentação

🎯 Objetivo:
Organizar projeto e preparar base para desenvolvimento

📦 Entregáveis:

* Estrutura de pastas criada
* Documentação inicial completa

🛠️ Tarefas:

* Criar pastas `/core`, `/features`, `/shared`
* Criar pasta `/docs`
* Criar:

  * Game_Rules.md
  * Architecture.md
  * App_Dev_Status.md
* Commit inicial

✅ Critério de conclusão:

* Projeto organizado e documentado

---

### Fase 1 — Game Engine

#### Sessão 3: Render base do jogo

🎯 Objetivo:
Renderizar os elementos principais do jogo

📦 Entregáveis:

* Círculo, bola, safe zone e target visíveis

🛠️ Tarefas:

* Criar GameScreen
* Implementar CustomPainter
* Desenhar elementos base
* Criar animação da bola

✅ Done quando:

* Bola se move no círculo

---

#### Sessão 4: Colisão e validação

🎯 Objetivo:
Detectar interações da bola

🛠️ Tarefas:

* Calcular posição angular
* Detectar safe zone
* Detectar target
* Validar centro vs extremidade

---

#### Sessão 5: Sistema de níveis

🎯 Objetivo:
Implementar progressão de dificuldade

🛠️ Tarefas:

* Criar modelo de variáveis
* Implementar níveis 0–10
* Aumentar variável aleatória

---

#### Sessão 6: Run Points (RP)

🎯 Objetivo:
Sistema de economia dentro da run

🛠️ Tarefas:

* Implementar zonas Gold/Silver/Bronze
* Atribuir RP
* Criar menu de escolhas

---

#### Sessão 7: Sistema de vidas

🎯 Objetivo:
Permitir retry após falha

🛠️ Tarefas:

* Implementar compra de vidas
* Repetir nível

---

#### Sessão 8: Precision Points (PP)

🎯 Objetivo:
Sistema de pontuação competitivo

🛠️ Tarefas:

* Calcular distância ao target
* Converter em score
* Acumular pontuação

---

### Fase 2 — Jogador e Economia

#### Sessão 9: Registo/Login

* Criar jogador
* Validar username único

#### Sessão 10: Sistema de GP

* Ganhos por run
* Ganhos por dia
* Warmup

#### Sessão 11: Compras

* Compra de GP
* Remoção de ads

#### Sessão 12: Ads

* Integração de anúncios

---

### Fase 3 — Liga

#### Sessão 13–19

* Estrutura de divisões
* Entrada semanal
* Pontuação semanal
* Weekly League History + Personal Records
* Subidas/descidas
* Última divisão
* Fecho semanal

---

### Fase 4 — Knockout

#### Sessão 20–23

* Inscrição
* Emparelhamento
* Duelos
* Repescagem

---

### Fase 5 — Backend e Escala

#### Sessão 24–28

* Backend base
* Sincronização
* Anti-cheat
* Escalabilidade

---

### Fase 6 — Finalização

#### Sessão 29–34

* Testes
* Observabilidade
* UI/UX
* Stores
* Beta
* Lançamento

---

## 8. Regras de Trabalho

* Cada sessão deve ser concluída antes de avançar
* No final de cada sessão:

  * Atualizar este ficheiro
  * Marcar progresso
* Nunca confiar no histórico do chat
* Este ficheiro é a única fonte de verdade para progresso

---

## 9. Como Retomar o Projeto

Para continuar o desenvolvimento num novo chat:

1. Copiar este ficheiro
2. Colar no novo chat
3. Dizer:

"Continuar desenvolvimento da app Stoppy com base neste estado"

---


## 🔄 Session Update

### Session: Session 2 — Base structure and documentation

### Status:

✅ Completed

---

### 🎯 Objective

Organize project structure and prepare development foundation.

---

### 📦 Deliverables

* [x] Folder structure created (/core, /features, /shared)
* [x] docs folder created
* [x] Architecture.md created
* [x] Game_Rules.md created
* [x] App_Dev_Status.md initialized
* [x] Base GameScreen created

---

### 🛠️ Work Done

* Created base Flutter project structure
* Added initial documentation
* Prepared project for Game Engine development

---

### ⚠️ Notes / Decisions

* Game Engine will be developed before backend
* Architecture enforces strict UI vs logic separation
* Codex will be used from this phase forward

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] App runs correctly

---

### 📌 Next Session

Session 3 — Game base rendering

Planned tasks:

* [ ] Create CustomPainter
* [ ] Render circle and ball
* [ ] Add animation
* [ ] Draw safe zone and target

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* 🔄 Session 3 — Game base rendering (ready)

---

### 🧭 Current State

Current session: Session 3 — Game base rendering
Status: Ready ⏳


---

## 🔄 Session Update

### Session: Session 3 — Game base rendering

### Status:

✅ Completed

---

### 🎯 Objective

Render the core visual elements of the game.

---

### 📦 Deliverables

* [x] GameScreen created
* [x] CustomPainter implemented
* [x] Circle rendered
* [x] Ball rendered and animated
* [x] Safe zone rendered
* [x] Target marker rendered

---

### 🛠️ Work Done

* Implemented GameScreen with AnimationController
* Created GameAreaPainter using CustomPainter
* Rendered circular game field
* Implemented ball movement based on angular progress
* Added safe zone arc and target marker
* Ensured rendering logic is isolated from UI

---

### ⚠️ Notes / Decisions

* Ball movement is time-based using AnimationController
* Rendering math uses polar coordinates
* Angle system aligned with top-start (clock-like behavior)
* Game Engine logic still not implemented (render-only phase)

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] App runs correctly on iOS
* [x] App runs correctly on Android

---

### 📌 Next Session

Session 4 — Collision and validation

Planned tasks:

* [ ] Calculate angular position
* [ ] Detect safe zone hit
* [ ] Detect target hit
* [ ] Validate precision (center vs edge)

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* 🔄 Session 4 — Collision and validation (ready)

---

### 🧭 Current State

Current session: Session 4 — Collision and validation  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 4 — Collision and validation

### Status:

✅ Completed

---

### 🎯 Objective

Implement collision detection and validation logic for ball interactions.

---

### 📦 Deliverables

* [x] GameCollisionValidator implemented
* [x] HitValidationResult model created
* [x] Safe zone detection implemented
* [x] Target detection implemented
* [x] Edge-based collision detection (ball radius considered)
* [x] Debug feedback UI implemented

---

### 🛠️ Work Done

* Implemented GameCollisionValidator with full angular math
* Added angle normalization and circular distance calculations
* Introduced ballAngularRadius using asin(ballRadius / circleRadius)
* Implemented edge-based collision:
  * Safe zone expanded by ball angular radius
  * Target tolerance expanded by ball angular radius
* Created HitValidationResult model with detailed collision data
* Refactored geometry into GameGeometryConfig
* Ensured shared geometry between rendering and validation
* Fixed layout consistency using SizedBox.square
* Moved gameAreaPadding to UI layer (GameScreen)
* Ensured rendering and validation use identical circle radius
* Added debug overlay for validation feedback

---

### ⚠️ Notes / Decisions

* Collision is based on area overlap, not center point
* Ball is treated as an angular interval
* Geometry is centralized to avoid inconsistencies
* UI and Game Engine remain strictly separated
* Layout concerns removed from geometry config

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] Visual behavior matches collision logic
* [x] Edge contact correctly detected

---

### 📌 Next Session

Session 5 — Level system

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* 🔄 Session 5 — Level system (ready)

---

### 🧭 Current State

Current session: Session 5 — Level system  
Status: Ready ⏳


---

---

## 🔄 Session Update

### Session: Session 5 — Level system

### Status:

✅ Completed

---

### 🎯 Objective

Implement the dynamic difficulty progression system.

---

### 📦 Deliverables

* [x] DifficultyState model implemented
* [x] GameLevelConfig model implemented
* [x] LevelGenerator implemented
* [x] 6 independent difficulty variables implemented
* [x] Randomized level progression implemented
* [x] Per-level random layout implemented
* [x] Ball speed connected to gameplay
* [x] Ball size connected to gameplay
* [x] Stop time level configured
* [x] Safe zone size connected to gameplay
* [x] Safe zone speed connected to gameplay
* [x] Target speed connected to gameplay
* [x] Ball direction randomized
* [x] Safe zone and target move opposite to ball direction
* [x] Debug overlay protected by debug flag

---

### 🛠️ Work Done

* Added full difficulty state with 6 variables from 0 to 10
* Added level config generation from current difficulty state
* Implemented rule where exactly one non-maxed variable increases after each successful level
* Added random start angles for ball, safe zone and target
* Added randomized ball direction per level
* Derived safe zone and target direction as opposite to ball direction
* Connected generated config to GameScreen
* Connected ball speed, ball size and safe zone size to rendering
* Added safe zone and target animations
* Ensured rendering and collision use the same animated angles
* Added temporary debug overlay for difficulty validation
* Moved debug overlay visibility behind `kShowDebugOverlay`

---

### ⚠️ Notes / Decisions

* The target remains a fixed-size marker
* No target tolerance or target sweep system was added
* Target hit and safe zone hit both count as level success for now
* Difficulty progression is independent from RP, PP, lives and economy
* Debug overlay is kept for future balancing and validation
* Debug overlay is hidden automatically in release builds

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Ball speed difficulty visible in emulator
* [x] Ball size difficulty visible in emulator
* [x] Safe zone size difficulty visible in emulator
* [x] Safe zone speed difficulty visible in emulator
* [x] Target speed difficulty visible in emulator
* [x] Difficulty increases after safe zone hit
* [x] Difficulty increases after target hit

---

### 📌 Next Session

Session 6 — Run Points (RP)

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* 🔄 Session 6 — Run Points (RP) (ready)

---

### 🧭 Current State

Current session: Session 6 — Run Points (RP)  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 6 — Run Points (RP)

### Status:

✅ Completed

---

### 🎯 Objective

Implement the RP (Run Points) economy system and player decision layer.

---

### 📦 Deliverables

* [x] RP reward system (Gold / Silver / Bronze)
* [x] Reward calculation based on safe zone position
* [x] RP accumulation during run
* [x] Debug feedback with RP details
* [x] Reward overlay after successful hit
* [x] Player decision system implemented
* [x] Increase difficulty (random — free)
* [x] Increase difficulty (chosen — 2 RP)
* [x] Skip difficulty increase — 5 RP
* [x] Decrease difficulty (random — 10 RP)
* [x] Decrease difficulty (chosen — 15 RP)
* [x] Buy life — 20 RP (state only, no usage yet)

---

### 🛠️ Work Done

* Implemented RunPointRewardCalculator with deterministic tier mapping
* Connected RP rewards to hit validation system
* Added total RP tracking during gameplay
* Implemented full reward menu overlay (PostHitRewardOverlay)
* Integrated all actions defined in Game_Rules.md
* Added difficulty increase/decrease logic (random and chosen)
* Added life purchase system (state only)
* Ensured correct flow separation:

  * Buy life does NOT advance level
  * All other actions advance level
* Refactored overlay into separate widget for UI/logic separation

---

### ⚠️ Notes / Decisions

* RP system is fully deterministic and based on ball center position
* Safe zone visual segmentation matches RP tiers
* Life system is partially implemented (purchase only)
* Life consumption will be implemented in Session 7
* Economy layer is now complete and stable

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] RP correctly awarded based on hit position
* [x] RP deducted correctly for all actions
* [x] Buy life increases life count and does not advance level
* [x] Difficulty changes correctly applied
* [x] Overlay flow stable (no freezes)

---

### 📌 Next Session

Session 7 — Lives system

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* 🔄 Session 7 — Lives system (ready)

---

### 🧭 Current State

Current session: Session 7 — Lives system
Status: Ready ⏳

---

---

## 🔄 Session Update

### Session: Session 7 — Lives system

### Status:

✅ Completed

---

### 🎯 Objective

Implement lives usage, timeout failure, and full run-level flow.

---

### 📦 Deliverables

* [x] Life consumption after failed hit
* [x] Retry same level when lives are available
* [x] Game Over when no lives remain
* [x] Failure feedback overlay with OK confirmation
* [x] Stop-time countdown visible to player
* [x] Timeout failure handling
* [x] Run level counter visible to player
* [x] Run level progression independent from difficulty
* [x] Target outside Safe Zone special reward flow
* [x] Safe Zone edge hit handled as success with 0 RP
* [x] Restart run flow

---

### 🛠️ Work Done

* Added lives consumption after failed safe zone and target miss
* Added retry flow using one life without advancing level or difficulty
* Added Game Over state and restart option
* Added player-facing failure messages
* Added OK confirmation before consuming a life
* Added visible stop-time countdown
* Added timeout failure behavior:
  * With lives: use one life and retry
  * Without lives: Game Over
* Added visible run level tracking
* Separated run level from difficulty level
* Added target-outside-safe-zone reward:
  * Advances level
  * Does not increase difficulty
  * Does not show reward menu
* Updated Safe Zone edge hit behavior:
  * Counts as success
  * Grants 0 RP when ball center is outside Safe Zone
  * Shows reward menu
* Ensured timer resets on new level, retry, and restart

---

### ⚠️ Notes / Decisions

* Run level starts at 1
* Run level increases on every successful level completion
* Run level does not increase on retry after life usage
* Difficulty progression remains independent from run level
* Timeout is treated as failure, not as hit validation
* Target hit means any part of the ball touches the target
* Target outside Safe Zone grants free level advance with no difficulty increase
* Safe Zone edge hit remains a valid success but grants 0 RP if the ball center is outside the Safe Zone

---

### 🧪 Validation

* [x] Failed hit with lives consumes one life after OK
* [x] Failed hit without lives triggers Game Over
* [x] Timeout with lives consumes one life after OK
* [x] Timeout without lives triggers Game Over
* [x] Retry keeps same level and difficulty
* [x] Successful hit advances run level
* [x] Reward menu advances run level after selection
* [x] Target outside Safe Zone advances level without difficulty increase
* [x] Safe Zone edge hit opens reward menu with 0 RP
* [x] Restart resets RP, lives, run level, timer and difficulty
* [x] Timer visible and resets correctly
* [x] Run level visible and updates correctly
* [x] flutter analyze
* [x] flutter test

---

### 📌 Next Session

Session 8 — Precision Points (PP)

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* 🔄 Session 8 — Precision Points (PP) (ready)

---

### 🧭 Current State

Current session: Session 8 — Precision Points (PP)  
Status: Ready ⏳


---

## 🔄 Session Update

### Session: Session 8 — Precision Points (PP)

### Status:

✅ Completed

---

### 🎯 Objective

Implement a precision-based competitive scoring system based on angular distance to the target.

---

### 📦 Deliverables

* [x] PrecisionPointCalculator implemented
* [x] PrecisionPointResult model created
* [x] Angular distance-based PP scoring implemented
* [x] Level multiplier applied to PP rewards
* [x] PP accumulation during run
* [x] PP displayed to player before level advancement
* [x] Final Score system implemented
* [x] Final Score breakdown displayed
* [x] RP HUD display refined

---

### 🛠️ Work Done

* Implemented PrecisionPointCalculator using circular angular distance
* Used shortest arc distance between ball center and target
* Mapped base PP to score range [1, 1000]
* Added run level multiplier:
  * Level 1 = ×1.01
  * Level 2 = ×1.02
  * Each run level adds +0.01 multiplier
* Added PP breakdown:
  * Base PP × Level Multiplier = Awarded PP
* Integrated PP into GameScreen hit validation flow
* Ensured PP is only committed after level advancement
* Displayed PP rewards in:
  * PostHitRewardOverlay
  * Target outside Safe Zone overlay
* Added Final Score calculation:
  * Final Score = Total PP + (Run Level × 100)
* Added Final Score breakdown in Game Over screen
* Added committedRunPoints so RP HUD updates only after level advancement decision
* Allowed multiple life purchases before selecting level advancement
* Expanded tap detection area to full screen
* Tuned target hit tolerance
* Increased initial ball size while preserving final hardest ball size

---

### ⚠️ Notes / Decisions

* PP is independent from RP and Safe Zone reward tiers
* PP is based on distance to target, even when advancing through Safe Zone
* Failed hits and timeouts award 0 PP
* Target outside Safe Zone grants PP and advances level without difficulty increase
* PP uses awardedPP after multiplier for total scoring
* basePP is preserved for player-facing breakdown
* RP shown in HUD represents committed RP only
* Reward overlay still uses total RP for purchases and decisions

---

### 🧪 Validation

* [x] PP correctly calculated from circular angular distance
* [x] PP multiplier correctly increases with run level
* [x] PP breakdown visible before level advancement
* [x] PP only added after level advancement confirmation
* [x] Failed hits and timeouts award 0 PP
* [x] Final Score correctly calculated and displayed
* [x] Final Score breakdown matches formula
* [x] RP HUD updates only after level decision
* [x] Multiple life purchases work before level advancement
* [x] Target tolerance feels stricter after adjustment
* [x] Initial ball size increased while final size preserved
* [x] Full-screen tap detection works
* [x] flutter analyze
* [x] flutter test

---

### 📌 Next Session

Session 9 — Registo/Login

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* 🔄 Session 9 — Registo/Login (ready)

---

### 🧭 Current State

Current session: Session 9 — Registo/Login  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 9 — Registration/Login

### Status:

✅ Completed

---

### 🎯 Objective

Implement player authentication system with registration and login flows.

---

### 📦 Deliverables

* [x] PlayerProfile model implemented
* [x] AuthState model implemented
* [x] AuthRepository contract defined
* [x] MockAuthRepository implemented
* [x] Username-based authentication (nickname removed)
* [x] LoginScreen implemented
* [x] RegisterScreen implemented
* [x] Shared AuthFormCard widget implemented
* [x] AuthGate navigation system implemented
* [x] Authentication flow integrated with GameScreen
* [x] Error handling and loading states implemented
* [x] Dependency injection supported via AuthRepository

---

### 🛠️ Work Done

* Implemented PlayerProfile model with username and creation date
* Implemented AuthState with authenticated/unauthenticated states
* Defined AuthRepository abstraction for future backend integration
* Implemented MockAuthRepository using in-memory storage
* Added username normalization and uniqueness validation
* Replaced all nickname references with username across the system
* Created AuthGate to manage authentication state and navigation
* Implemented LoginScreen and RegisterScreen using shared AuthFormCard
* Added form validation, loading state, and error feedback
* Integrated authentication flow with GameScreen entry point
* Updated and fixed tests to align with username-based system

---

### ⚠️ Notes / Decisions

* Authentication uses in-memory mock (no persistence)
* Users are lost on app restart (expected for this phase)
* No logout flow implemented yet
* Auth logic is partially coupled with UI via AuthGate (acceptable for current phase)
* Structure is prepared for future backend (Firebase or custom)
* Dependency injection via AuthRepository enables testability and future scalability

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] Register flow works correctly
* [x] Login flow works within same app session
* [x] Username uniqueness enforced
* [x] Error messages displayed correctly
* [x] Navigation to GameScreen on successful authentication

---

### 📌 Next Session

Session 10 — GP System

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* 🔄 Session 10 — GP System (ready)

---

### 🧭 Current State

Current session: Session 10 — GP System
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 10 — GP System

### Status:

✅ Completed

---

### 🎯 Objective

Implement the Game Points (GP) system, including run completion rewards, daily rewards, and warmup rules.

---

### 📦 Deliverables

* [x] GP model added to PlayerProfile
* [x] GamePointRewardCalculator implemented
* [x] GamePointRewardResult model created
* [x] Completion GP system implemented (league, tournament, warmup)
* [x] Daily GP system implemented
* [x] Warmup availability policy implemented
* [x] GP accumulation and persistence implemented
* [x] GP displayed in Game Over screen
* [x] Full test coverage for GP logic

---

### 🛠️ Work Done

* Implemented GamePointRewardCalculator with:

  * +1 GP for league and tournament runs
  * Warmup GP conditional on PP ≥ 10,000
  * +2 Daily GP based on first run of the day
* Implemented GamePointRewardResult with breakdown and total GP
* Added GP fields to PlayerProfile:

  * `gamePoints` (default = 5)
  * `lastDailyGpAwardedAt`
* Implemented safe `copyWith` with nullable field support
* Implemented WarmupAvailabilityPolicy:

  * Warmup available when GP < 10
* Integrated GP calculation into GameScreen:

  * GP calculated at Game Over only
  * Run finalization protected with `_isRunFinalized`
* Fixed critical edge case:

  * Pending PP is committed before GP calculation on run finalization
* Implemented run duration system:

  * Run ends after 1 hour
  * Game Over triggered on duration limit
* Implemented mock persistence via MockAuthRepository
* Added full unit test coverage for GP logic
* Updated Game Over UI with GP breakdown

---

### ⚠️ Notes / Decisions

* All runs end in Game Over (normal completion state)
* Run ends when:

  * Player loses; or
  * 1 hour passes since run start
* GP is always calculated at Game Over
* Daily GP uses the Game Over timestamp (not run start)
* Daily GP is awarded once per local calendar day
* Warmup:

  * Available only when GP < 10
  * Grants GP only if PP ≥ 10,000
* GP is currently client-side only (mock persistence)
* Backend validation will be required for anti-cheat

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] Completion GP correctly awarded for all run modes
* [x] Warmup threshold correctly enforced
* [x] Daily GP correctly awarded once per day
* [x] Daily GP correctly resets on next day
* [x] Run duration limit triggers Game Over correctly
* [x] GP calculated only once per run
* [x] Pending PP correctly included on run finalization
* [x] PlayerProfile updates correctly persisted in mock repository
* [x] Game Over UI displays correct GP breakdown

---

### 📌 Next Session

Session 11 — Purchases

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* 🔄 Session 11 — Purchases (ready)

---

### 🧭 Current State

Current session: Session 11 — Purchases
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 11 — Purchases

### Status:

✅ Completed

---

### 🎯 Objective

Implement the purchase system, including GP packs and ad removal, with a mockable and scalable architecture.

---

### 📦 Deliverables

* [x] PurchaseProduct model implemented
* [x] PurchaseProductType enum implemented
* [x] PurchaseResult model with typed errors implemented
* [x] PurchaseError enum implemented
* [x] PurchaseRepository contract defined
* [x] MockPurchaseRepository implemented
* [x] StoreScreen implemented
* [x] PlayerProfile extended with `adsRemoved`
* [x] Purchase flow integrated with GameScreen
* [x] Profile update and persistence implemented after purchase
* [x] UI loading and error handling implemented
* [x] Test coverage for purchase logic

---

### 🛠️ Work Done

* Implemented purchase domain layer with clean separation:

  * Models: PurchaseProduct, PurchaseResult
  * Enum-based error handling (PurchaseError)
  * Repository abstraction for future IAP integration
* Implemented MockPurchaseRepository:

  * GP packs (small, large)
  * Remove Ads purchase
  * Protection against duplicate purchases
  * Typed error handling
* Extended PlayerProfile:

  * Added `adsRemoved` field (default = false)
  * Fully integrated with JSON serialization and copyWith
* Implemented StoreScreen:

  * Product listing via repository
  * Purchase flow with loading state
  * Error/success feedback
  * PlayerProfile updates propagated to GameScreen
* Integrated purchase flow into GameScreen:

  * Store button added
  * Purchase results update local and persisted profile
* Improved robustness:

  * Prevented double purchase taps
  * Ensured immutability and safe state updates
  * Added defensive constraints on Game Points
* Ensured full compatibility with future real IAP system

---

### ⚠️ Notes / Decisions

* Purchases are fully mocked (no real store integration)
* PurchaseResult uses typed errors instead of raw strings
* PlayerProfile remains the single source of truth for player state
* StoreScreen maintains local state but propagates updates upward
* Ads removal is persistent via PlayerProfile
* Purchase flow is designed to support future:

  * receipt validation
  * async purchase states
  * backend verification

---

### 🧪 Validation

* [x] flutter analyze (no issues)
* [x] flutter test (passing)
* [x] GP packs correctly increase Game Points
* [x] Remove Ads correctly updates profile
* [x] Remove Ads cannot be purchased twice
* [x] Purchase errors are correctly handled and displayed
* [x] Store UI reflects updated player state
* [x] Profile updates persist correctly via AuthRepository
* [x] No duplicate purchases from rapid taps
* [x] PurchaseResult typed errors behave correctly

---

### 📌 Next Session

Session 12 — Ads

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* 🔄 Session 12 — Ads (ready)

---

### 🧭 Current State

Current session: Session 12 — Ads
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 12 — Ads

### Status:

✅ Completed

---

### 🎯 Objective

Implement a mock-first ads system with strict gameplay performance protection.

---

### 📦 Deliverables

* [x] AdType model implemented
* [x] AdLoadState model implemented
* [x] AdShowResult model implemented
* [x] AdRepository contract defined
* [x] MockAdRepository implemented
* [x] AdController implemented
* [x] Ads integrated with GameScreen
* [x] Banner preload and manual refresh policy implemented
* [x] Interstitial exit flow implemented
* [x] Rewarded continue flow implemented
* [x] Remove Ads rule implemented
* [x] Tests updated for ads logic

---

### 🛠️ Work Done

* Added mock-first ads architecture prepared for future AdMob integration
* Implemented banner, interstitial and rewarded ad types
* Added typed ad load states: loading, loaded and failed
* Added typed ad show result with shown and rewardGranted flags
* Implemented run-start preloading for ads
* Implemented manual banner refresh after safe-zone success and at least 10 run levels
* Implemented Game Over rewarded continue flow
* Implemented score transition before final results
* Implemented interstitial display only when player exits without rewarded continue
* Ensured Remove Ads disables only banners and interstitials
* Ensured rewarded ads remain available because they are optional continue opportunities
* Added protection against multiple rewarded ad taps
* Kept ad loading/showing logic outside critical gameplay timing where possible

---

### ⚠️ Notes / Decisions

* Ads are currently mocked; no real AdMob SDK integration yet
* Rewarded ad does not grant a literal extra life
* Rewarded ad allows the player to continue from the same failed level
* Rewarded continue does not trigger an interstitial
* Remove Ads disables non-optional ads only:
  * banners
  * interstitials
* Remove Ads does not disable rewarded ads
* Banner auto-refresh is intentionally not used
* Banner refresh is manual and sparse to avoid gameplay stutter
* Real AdMob integration must preserve this performance strategy

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Remove Ads skips banners
* [x] Remove Ads skips interstitials
* [x] Remove Ads does not skip rewarded ads
* [x] Rewarded continue remains available when ads are removed
* [x] Rewarded continue does not grant a literal life
* [x] Rewarded continue resumes the same run level
* [x] Rewarded continue prevents interstitial
* [x] Declined rewarded offer triggers interstitial on exit
* [x] Banner refresh happens only after 10 run levels
* [x] Banner refresh happens only after safe-zone success

---

### 📌 Next Session

Session 13 — League structure

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* 🔄 Session 13 — League structure (ready)

---

### 🧭 Current State

Current session: Session 13 — League structure  
Status: Ready ⏳

---

---

## 🔄 Session Update

### Session: Session 12.1 — RP Target Bonus + Reward Summary Flow

### Status:

✅ Completed

---

### 🎯 Objective

Refine RP rewards by adding target-based bonus RP and simplifying the post-hit reward flow.

---

### 📦 Deliverables

* [x] Target RP bonus system implemented
* [x] Target bonus based on base PP before level multiplier
* [x] Safe Zone RP rewards kept unchanged
* [x] Combined Safe Zone + Target RP reward result implemented
* [x] Reward Summary overlay implemented
* [x] Post-hit difficulty menu simplified
* [x] Target outside Safe Zone success flow updated
* [x] Miss outside Safe Zone and Target failure flow preserved
* [x] Tests added for Target RP bonus logic

---

### 🛠️ Work Done

* Added TargetRunPointBonusCalculator
* Added TargetRunPointBonusResult
* Added CombinedRunPointRewardResult
* Added extra RP rewards when the player stops the ball on the target:
  * 1000 base PP: +10 RP
  * 997–999 base PP: +5 RP
  * 990–996 base PP: +3 RP
  * <990 base PP: +2 RP
* Preserved existing Safe Zone RP rewards:
  * Gold: +3 RP
  * Silver: +2 RP
  * Bronze: +1 RP
  * Edge/contact-only success: +0 RP
* Updated successful hit flow:
  * Player stops ball
  * Reward Summary appears
  * Player confirms with OK
  * Difficulty choice menu appears
* Removed temporary debug hit feedback from normal gameplay flow
* Simplified PostHitRewardOverlay to show only:
  * Accumulated RP
  * Accumulated PP
  * Difficulty/action options
* Ensured Target outside Safe Zone now follows the same success flow
* Ensured miss outside both Safe Zone and Target still follows failure/life/Game Over flow
* Ensured target bonus uses base PP, not multiplied awarded PP

---

### ⚠️ Notes / Decisions

* Target RP bonus is awarded only when the ball touches the target
* Target RP bonus is independent from Safe Zone RP
* Safe Zone RP and Target RP can stack
* Target bonus thresholds use base PP before run-level multiplier
* RP is committed after confirming the Reward Summary
* PP is committed after confirming the Reward Summary
* Buy life remains available from the difficulty menu and does not advance level
* All other difficulty actions advance the run level
* Reward Summary is now the only post-hit reward explanation screen before the difficulty menu

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Safe Zone RP rewards unchanged
* [x] Target RP bonus thresholds validated
* [x] Safe Zone + Target combined RP validated
* [x] Target outside Safe Zone succeeds
* [x] Miss outside Safe Zone and Target fails
* [x] Reward Summary appears before difficulty menu
* [x] Difficulty menu shows accumulated RP and PP only
* [x] No duplicate RP award observed
* [x] Target bonus uses base PP before multiplier

---

### 📌 Next Session

Session 13 — League structure

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (completed)
* 🔄 Session 13 — League structure (ready)

---

### 🧭 Current State

Current session: Session 13 — League structure  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 13 — League structure

### Status:

✅ Completed

---

### 🎯 Objective

Implement the foundational weekly league domain system, including divisions, rankings, score calculation, promotion/relegation logic, and season settlement rules.

---

### 📦 Deliverables

* [x] LeagueDivision model implemented
* [x] LeaguePlayerEntry model implemented
* [x] WeeklyLeagueRun model implemented
* [x] WeeklyLeagueScore model implemented
* [x] LeagueRankingEntry model implemented
* [x] LeagueRankingSnapshot model implemented
* [x] LeagueDivisionSettlement model implemented
* [x] LeagueSeasonId model implemented
* [x] LeagueDivisionPolicy implemented
* [x] WeeklyLeagueScoreCalculator implemented
* [x] LeagueRankingCalculator implemented
* [x] LeagueSeasonSettlementCalculator implemented
* [x] Deterministic ranking tie-breaker chain implemented
* [x] Weekly activity multiplier system implemented
* [x] Promotion/relegation rules implemented
* [x] Last division closure logic implemented
* [x] Ranking snapshot system implemented
* [x] Extensive domain tests implemented

---

### 🛠️ Work Done

* Added full weekly league domain layer under:

  * `lib/features/league/domain/models`
  * `lib/features/league/domain/services`

* Implemented league division structure:

  * Division 1 starts with 10 players
  * Every next division doubles capacity
  * New divisions are automatically created when the lowest division becomes full

* Implemented weekly player participation model:

  * Reserved slots
  * Weekly entry payment state
  * Active vs inactive weekly participation
  * Immutable player entry updates

* Implemented weekly score calculation system:

  * Score blocks based on best runs
  * Activity-day multipliers
  * Base score + bonus score separation
  * Final weekly score calculation
  * Weekly run averaging helpers
  * Best-run extraction helpers

* Implemented deterministic ranking logic using:

  * Final weekly score
  * Active days
  * Run count
  * Weekly average score
  * Best runs
  * Lifetime tournament runs
  * Lifetime average score
  * Registration date

* Implemented ranking snapshot system:

  * Current player ranking
  * Nearby players above and below
  * Promotion-zone score requirement
  * Stay-in-division score requirement

* Implemented promotion/relegation rules:

  * Minimum 40% relegation floor
  * Minimum 20% promotion floor
  * Inactive players always relegate
  * Promotions matched against relegation count where possible

* Implemented special penultimate/last division behavior:

  * Last division active players can be promoted
  * Inactive penultimate players always relegate
  * Last division can close completely when emptied
  * Penultimate division becomes the new last division after closure

* Added defensive domain protections:

  * Assertions
  * Immutable state transitions
  * Deterministic ranking guarantees
  * Duplicate settlement protection

* Added comprehensive test coverage for:

  * Division capacities
  * New player placement
  * Weekly score blocks
  * Activity multipliers
  * Tie-breaker ordering
  * Snapshot ordering
  * Promotion score calculations
  * Relegation rules
  * Division closure scenarios
  * Penultimate/last division edge cases

---

### ⚠️ Notes / Decisions

* Weekly ranking is fully deterministic
* Inactive players display `inactive` instead of numeric score
* Active players with 0 runs still rank above inactive players
* Score needed for promotion/staying requires surpassing tied cutoff scores
* Players above current player are ordered nearest-first for UI usage
* Weekly score calculations assume runs are already filtered by week/season
* Settlement logic is currently domain-only (no persistence/backend yet)
* Inactive reserved slots do not reduce relegation pressure
* Last division may disappear entirely when no active players remain
* Promotions from the last division are capped by available active players
* Promotions and relegations are intentionally allowed to be asymmetric when divisions collapse

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Deterministic ranking verified
* [x] Tie-breaker chain verified
* [x] Weekly score block logic verified
* [x] Activity multiplier logic verified
* [x] Promotion/relegation rules verified
* [x] Last division closure verified
* [x] Snapshot ordering verified
* [x] Promotion score calculations verified
* [x] Relegation floor verified
* [x] Inactive-player relegation verified
* [x] Division collapse edge cases verified

---

### 📌 Next Session

Session 14 — Weekly League Entry + Runtime Integration

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (completed)
* ✅ Session 13 — League structure (completed)
* 🔄 Session 14 — Weekly League Entry + Runtime Integration (ready)

---

### 🧭 Current State

Current session: Session 14 — Weekly League Entry + Runtime Integration
Status: Ready ⏳

---

---

## 🔄 Session Update

### Session: Session 14 — Weekly League Entry + Runtime Integration

### Status:

✅ Completed

---

### 🎯 Objective

Integrate weekly league entry, runtime league mode, score submission, and player-facing league snapshot into the live gameplay flow.

---

### 📦 Deliverables

* [x] LeagueRepository contract implemented
* [x] MockLeagueRepository implemented
* [x] PlayerProfile extended with league fields
* [x] LeagueHomeScreen implemented
* [x] Weekly league entry flow implemented
* [x] Weekly entry GP deduction implemented
* [x] Duplicate weekly entry guard implemented
* [x] League button added to GameScreen
* [x] League runtime mode integrated with GameScreen
* [x] WeeklyLeagueRun submission after finalized league runs
* [x] League run submission guard implemented
* [x] Warmup availability rules updated
* [x] League mode priority over warmup implemented
* [x] Promotion need and Stay need target score rules finalized
* [x] Runtime player profile synchronization implemented
* [x] Tests updated for league runtime behavior

---

### 🛠️ Work Done

* Added LeagueRepository abstraction for backend-ready league runtime access
* Added MockLeagueRepository with deterministic in-memory league state
* Added support for seeded mock ranking data and empty mock test state
* Extended PlayerProfile with:
  * currentLeagueDivision
  * hasWeeklyLeagueEntry
  * reservedLeagueSlot
* Added JSON serialization and copyWith support for new league fields
* Threaded LeagueRepository through:
  * StoppyApp
  * AuthGate
  * GameScreen
* Added LeagueHomeScreen with:
  * current division display
  * GP display
  * weekly entry status
  * ranking preview
  * player snapshot
  * promotion target score
  * stay target score
* Added weekly league entry flow:
  * validates duplicate active entry before GP deduction
  * validates enough GP before entry
  * deducts weekly entry cost
  * updates player profile
  * refreshes league state
* Added League button to GameScreen
* Integrated league runtime mode into GameScreen
* Added automatic WeeklyLeagueRun submission at run finalization
* Ensured league runs submit only when:
  * run mode is RunMode.league
  * player has active weekly league entry
  * league repository exists
  * run has not already been submitted
* Updated run mode selection:
  * league entry takes priority over warmup
  * warmup is only available when player has less than 10 GP and no active league entry
* Finalized ranking target display rules:
  * Promotion need = last promotion slot score + 1
  * Stay need = last safe slot score + 1
* Updated widget and domain tests for new league runtime rules

---

### ⚠️ Notes / Decisions

* Weekly league runtime is still mock-first and in-memory
* Backend validation is still required in a future phase
* Client league submissions are not trusted long-term
* Weekly league players cannot play warmup while enrolled
* Warmup is only a fallback for low-GP players without weekly league entry
* League entry validation must always happen before GP deduction
* League run submission is protected against duplicate finalization
* Promotion need and Stay need are absolute target scores, not deltas from the current player
* Equal scores still rely on deterministic tie breakers
* MockLeagueRepository is designed to be replaceable by Firebase or custom backend later

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Weekly league entry flow validated
* [x] Duplicate weekly entry prevention validated
* [x] GP deduction validated
* [x] PlayerProfile league fields validated
* [x] PlayerProfile JSON compatibility validated
* [x] LeagueRepository dependency injection validated
* [x] MockLeagueRepository runtime behavior validated
* [x] LeagueHomeScreen state loading validated
* [x] League mode priority over warmup validated
* [x] Warmup restriction rules validated
* [x] WeeklyLeagueRun submission validated
* [x] Duplicate league run submission prevention validated
* [x] Restart resets league submission guard
* [x] Promotion need calculation validated
* [x] Stay need calculation validated
* [x] Snapshot UI values validated

---

### 📌 Next Session

Session 15 — Weekly League Scoring + Ranking UI

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (completed)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* 🔄 Session 15 — Weekly League Scoring + Ranking UI (ready)

---

### 🧭 Current State

Current session: Session 15 — Weekly League Scoring + Ranking UI  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 15 — Weekly League Scoring + Ranking UI

### Status:

✅ Completed

---

### 🎯 Objective

Implement player-facing weekly league scoring breakdown and ranking UI using the existing league domain and runtime systems.

---

### 📦 Deliverables

* [x] Weekly score breakdown UI implemented
* [x] Best-runs scoring display implemented
* [x] Activity multiplier display implemented
* [x] Final weekly score display implemented
* [x] Nearby ranking UI implemented
* [x] Current player highlight implemented
* [x] Promotion/relegation zone display implemented
* [x] Inactive player display implemented
* [x] Snapshot zone metadata integrated into UI
* [x] League UI widget tests implemented

---

### 🛠️ Work Done

* Extended `WeeklyLeagueScore`:

  * Added `bestRunsCount`
  * Added defensive consistency assertions
* Extended `LeagueRankingSnapshot`:

  * Added promotion zone end rank
  * Added relegation zone start rank
  * Added defensive rank assertions
* Updated `LeagueRankingCalculator`:

  * Added promotion/relegation zone metadata generation
  * Preserved deterministic ranking behavior
  * Preserved inactive-player ordering rules
* Updated `LeagueHomeScreen`:

  * Added weekly score breakdown card:

    * weekly runs
    * best runs used
    * average selected best runs
    * active days
    * activity multiplier
    * final weekly score
  * Added nearby ranking section:

    * players above
    * current player
    * players below
  * Added promotion/relegation zone labels
  * Added current-player visual highlight
  * Added inactive player score display
* Confirmed scoring formula:

  * `((runCount - 1) ~/ 5) + 1`
  * Equivalent to:

    * 1–5 runs → best 1
    * 6–10 runs → best 2
    * 11–15 runs → best 3
    * etc.
* Confirmed weekly activity multipliers:

  * 1 day → ×1.0
  * 2 days → ×1.1
  * 3 days → ×1.2
  * 4 days → ×1.4
  * 5 days → ×1.6
  * 6 days → ×1.8
  * 7 days → ×2.0
* Added widget tests covering:

  * best-runs display
  * multiplier display
  * final score display
  * inactive display
  * current-player highlight
  * promotion/stay target display

---

### ⚠️ Notes / Decisions

* UI does not recalculate league scoring rules
* Weekly scoring logic remains isolated in domain services
* `bestRunsCount` is exposed by the domain model for UI safety
* Multiple runs on the same local calendar day count as one active day
* Promotion/stay targets remain absolute score requirements
* Equal scores still rely on deterministic tie breakers
* Nearby ranking ordering is nearest-first in domain logic
* UI reverses upper entries only for visual top-down ordering

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Weekly score breakdown validated
* [x] Best-runs formula validated
* [x] Activity multiplier validated
* [x] Final score display validated
* [x] Inactive player display validated
* [x] Current-player highlight validated
* [x] Promotion/relegation labels validated
* [x] Snapshot zone metadata validated
* [x] Deterministic ranking behavior preserved

---

### 📌 Next Session

Session 16 — Weekly League History + Personal Records

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (completed)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* 🔄 Session 16 — Weekly League History + Personal Records (ready)

---

### 🧭 Current State

Current session: Session 16 — Weekly League History + Personal Records
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 16 — Weekly League History + Personal Records

### Status:

✅ Completed

---

### 🎯 Objective

Implement player-facing weekly league history, personal records, and weekly run tracking using the existing league runtime and ranking systems.

---

### 📦 Deliverables

* [x] PlayerLeagueRecords model implemented
* [x] WeeklyLeagueHistoryEntry model implemented
* [x] PlayerLeagueRecordsCalculator implemented
* [x] WeeklyLeagueHistoryGenerator implemented
* [x] Personal records tracking implemented
* [x] Weekly best score tracking implemented
* [x] Weekly score reset by season implemented
* [x] League history entry generation implemented
* [x] LeagueRepository extended with records/history access
* [x] MockLeagueRepository records integration implemented
* [x] Personal records UI implemented
* [x] League history UI implemented
* [x] Current weekly runs list implemented
* [x] Weekly runs sorting implemented
* [x] Weekly runs ranking display implemented
* [x] Weekly runs aligned leaderboard layout implemented
* [x] Repository and UI tests updated

---

### 🛠️ Work Done

* Added new league domain models:

  * `PlayerLeagueRecords`
  * `WeeklyLeagueHistoryEntry`

* Added new league domain services:

  * `PlayerLeagueRecordsCalculator`
  * `WeeklyLeagueHistoryGenerator`

* Implemented personal records system:

  * all-time best final score
  * current weekly best score
  * season-aware weekly reset logic

* Implemented league history generation:

  * final season rank
  * final division
  * promoted / relegated / stayed result
  * final weekly score

* Extended `LeagueRepository` with:

  * `fetchPlayerRecords`
  * `fetchPlayerHistory`
  * `fetchPlayerWeeklyRuns`

* Refactored `submitLeagueRun`:

  * added `LeagueRunSubmissionResult`
  * added accepted/rejected submission support
  * prepared repository contract for future backend validation

* Updated `MockLeagueRepository`:

  * records update on submitted league runs
  * current weekly runs filtering by season
  * sorting by best score first
  * newest run first on score ties
  * immutable weekly runs return values

* Updated `LeagueHomeScreen`:

  * added Personal Records card
  * added League History card
  * added Weekly Runs card
  * added leaderboard-style weekly runs layout
  * aligned score digits using fixed-width score columns
  * added run ranking order (1º, 2º, 3º...)
  * improved async loading using parallel futures

* Added and updated tests for:

  * weekly record updates
  * season reset behavior
  * history generation
  * repository sorting/filtering
  * weekly runs ordering
  * UI rendering
  * repository contract updates

---

### ⚠️ Notes / Decisions

* All-time records never reset
* Weekly best scores reset automatically when season changes
* Weekly runs are filtered by current season only
* Weekly runs sorting is handled entirely in the repository layer
* Weekly runs are ordered:

  * highest score first
  * newest run first on ties
* League history currently depends on generated settlement data
* Real automated season settlement runtime is deferred to Session 17
* UI does not calculate ranking, sorting, filtering, or records
* Repository contracts are now prepared for backend validation and anti-cheat flows

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Personal records update correctly
* [x] Weekly best resets correctly on season change
* [x] All-time best persists across seasons
* [x] Weekly runs filtering validated
* [x] Weekly runs sorting validated
* [x] Weekly runs leaderboard display validated
* [x] League history rendering validated
* [x] Repository contract updates validated
* [x] Async loading flow validated
* [x] UI alignment validated

---

### 📌 Next Session

Session 16.1 — Gameplay Simplification + PP Tier System

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (completed)
* ✅ Session 7 — Lives system (completed)
* ✅ Session 8 — Precision Points (PP) (completed)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (completed)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* 🔄 Session 16.1 — Gameplay Simplification + PP Tier System

---

### 🧭 Current State

Current session: Session 16.1 — Gameplay Simplification + PP Tier System
Status: Ready ⏳

---

---


## 🔄 Session Update
### Session: Session 16.1 — Gameplay Simplification + PP Tier System

### Status:

✅ Completed

---

### 🎯 Objective

Simplify core gameplay by removing Run Points, lives, RP-based decisions, and segmented Safe Zone rewards, while introducing a tier-based Precision Points progression system.

---

### 📦 Deliverables

* [x] Run Points system removed from active gameplay
* [x] RP HUD removed
* [x] RP reward calculations removed from runtime flow
* [x] RP-based reward menu removed
* [x] Life purchase system removed
* [x] Lives-based retry system removed
* [x] Rewarded continue flow updated to one continue per run
* [x] Safe Zone simplified to a single green zone
* [x] Gold / Silver / Bronze Safe Zone segmentation removed
* [x] PP tier system implemented
* [x] 60 authored PP tiers implemented
* [x] PP tier starts at Tier 1 with 100 max PP
* [x] Target hit increases next level PP tier
* [x] Safe Zone-only success preserves current PP tier
* [x] PP calculation updated to use current tier max PP
* [x] Old PP level multiplier removed
* [x] Between-level reward summary simplified
* [x] Target hit next-tier message added
* [x] Current max PP displayed in the center of the game circle
* [x] Final playable level capped at level 60
* [x] Run finalizes after completing level 60
* [x] Number formatting added for large PP values
* [x] Tests updated for new PP summary format

---

### 🛠️ Work Done

* Added `PrecisionPointTier`
* Added `PrecisionPointTierService`
* Added authored max PP values for tiers 1–60
* Updated `PrecisionPointCalculator` to calculate PP from angular distance using the current tier max value
* Ensured successful hits award at least 1 PP
* Ensured failed hits and timeouts award 0 PP
* Removed old PP run-level multiplier logic
* Refactored successful hit flow:
  * Player stops the ball
  * PP is calculated from distance to target
  * Reward Summary appears
  * Player confirms with `Next Level`
  * Difficulty increases randomly by one variable
  * Run level advances
* Added target-hit tier progression:
  * Target hit advances PP tier for the next level
  * Safe Zone-only success keeps the same PP tier
  * Tier progression is clamped at Tier 60
* Updated Reward Summary overlay to show:
  * PP earned
  * Total PP
  * Target hit next-level max PP message when applicable
  * `Next Level` button only
* Added in-game center display:
  * `Max PP`
  * current tier max PP value
* Simplified Safe Zone rendering:
  * removed Gold/Silver/Bronze visual segmentation
  * kept one green Safe Zone arc
* Removed RP-dependent gameplay decisions:
  * no RP gain
  * no RP spending
  * no difficulty choice menu
  * no life purchases
* Updated failure flow:
  * no lives
  * first failure can offer one rewarded continue
  * rewarded continue resumes the same failed level
  * second failure finalizes the run
* Added maximum level behavior:
  * level 60 is playable
  * successful completion of level 60 finalizes the run
  * level 61 is never reached
* Added readable number formatting for PP displays:
  * Reward Summary earned PP
  * Total PP
  * Target next max PP
  * center Max PP display
  * Final Score display
* Updated widget tests to match the new PP summary text format
* Moved current Max PP display outside the circle area
* Added centered stop-time countdown inside the circle
* Added dynamic countdown urgency states:
  * ≤10 seconds:
    * yellow warning color
    * larger font
  * ≤5 seconds:
    * red danger color
    * even larger font
* Improved gameplay readability by prioritizing stop timing visually
* Added formatted PP values with thousands separators across gameplay UI
* Removed level bonus contribution from final score calculation
* League submissions now use pure PP score only

---

### ⚠️ Notes / Decisions

* Gameplay is now centered on precision and level progression, not run economy management
* RP is no longer part of active gameplay
* GP remains unchanged as the external economy
* Rewarded ads remain optional and only provide one continue opportunity per run
* Rewarded continue does not grant lives
* Safe Zone success still advances the run level
* Target hit is the only action that increases PP tier
* Target hit and Safe Zone hit can both be true on the same stop
* PP tier increases after confirming the reward summary, not immediately on stop
* Current max PP display always reflects the active tier for the current level
* Final score still uses the existing final score flow unless separately refactored
* League, GP, purchase, and ads systems remain compatible with the simplified gameplay flow
* Backend anti-cheat validation will need to validate PP tier progression in the future
* Final score is now equal to total accumulated PP only
* Run level no longer grants hidden bonus score
* League rankings now reflect pure precision performance
* Stop-time countdown is now the central gameplay focus element inside the circle
* Max PP was moved outside the circle to reduce visual competition with gameplay timing

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] RP no longer appears in active gameplay UI
* [x] Safe Zone renders as a single green zone
* [x] Safe Zone-only success keeps the current PP tier
* [x] Target hit advances the next level PP tier
* [x] PP tier clamps at Tier 60
* [x] PP calculation uses current tier max PP
* [x] Old PP multiplier no longer applies
* [x] Reward Summary displays earned PP and total PP
* [x] Target hit message displays next level max PP
* [x] Center circle displays current max PP
* [x] Rewarded continue can only be used once per run
* [x] Rewarded continue resumes the same failed level
* [x] Second failure finalizes the run
* [x] Level 60 can be played
* [x] Completing level 60 finalizes the run
* [x] Level 61 is never reached
* [x] Number formatting displays large PP values correctly
* [x] League run submission still works after run finalization
* [x] GP reward calculation still works after run finalization
* [x] Final score uses PP only
* [x] League submission uses PP-only final score
* [x] Countdown warning states trigger correctly at 10s and 5s
* [x] Countdown color transitions validated
* [x] Countdown size transitions validated
* [x] Max PP display positioning validated

---

### 📌 Next Session

Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* 🔄 Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (ready)

---

### 🧭 Current State

Current session: Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow

### Status:

✅ Completed

---

### 🎯 Objective

Implement the full weekly league settlement runtime, inactive player handling, updated ranking tie-breakers, promotion/relegation flow, reserved-slot management, and player-facing settlement visibility.

---

### 📦 Deliverables

* [x] Weekly entry cost system set to 10 GP
* [x] Inactive unpaid player state implemented
* [x] Active players ranked above inactive players
* [x] Updated active-player tie-breaker chain implemented
* [x] Updated inactive-player tie-breaker chain implemented
* [x] Regular division bottom-40% relegation implemented
* [x] Regular division promotion flow implemented
* [x] Penultimate ↔ last division special rules implemented
* [x] Last division closure logic implemented
* [x] Reserved slot loss rules implemented
* [x] Weekly settlement runtime implemented
* [x] Duplicate settlement protection implemented
* [x] Weekly settlement schedule implemented (Sunday 23:59 Europe/Lisbon)
* [x] Weekly league history generation implemented
* [x] Settlement visibility added to LeagueHomeScreen
* [x] Inactive player UI indicators implemented
* [x] Weekly settlement history states implemented
* [x] Mock repository runtime settlement flow implemented
* [x] Weekly runs cleanup after settlement implemented
* [x] Domain tests updated
* [x] Repository tests updated
* [x] Widget tests updated
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Updated `LeagueRankingCalculator`:

  * Active players now rank before inactive players
  * Removed obsolete second/third-best-run tie-breakers
  * Added new Session 17 tie-breaker chain:

    * Weekly score
    * Weekly active days
    * Weekly run count
    * Weekly average run score
    * Weekly best individual run
    * Lifetime run count
    * Lifetime average score
    * Oldest registration date
* Added inactive-player tie-breaker chain:

  * Lifetime run count
  * Lifetime average score
  * Oldest registration date
* Updated `LeagueSeasonSettlementCalculator`:

  * Bottom 40% relegation for regular divisions
  * Promotion flow aligned with division structure
  * Penultimate ↔ last division special settlement logic
  * Last division closure support
* Added `WeeklyLeagueSettlementSchedule`

  * Weekly settlement fixed to Sunday 23:59
  * Added backend timezone comments for future Europe/Lisbon authority
* Added `LeagueSeasonSettlementResult`
* Updated `WeeklyLeagueHistoryEntry`

  * Added:

    * `removedFromLeague`
    * `lostReservedSlot`
* Updated `WeeklyLeagueHistoryGenerator`

  * Settlement-based history generation
* Updated `MockLeagueRepository`

  * Runtime settlement execution
  * Duplicate settlement protection
  * Promotion/relegation application
  * Reserved slot management
  * Division closure cleanup
  * Weekly entry reset
  * Weekly run cleanup
  * History persistence
* Updated `LeagueHomeScreen`

  * Settlement information card
  * Settlement history visibility
  * Inactive player indicators
  * Europe/Lisbon settlement wording
  * Active/inactive entry status UI
* Updated tests:

  * Domain tests
  * Repository tests
  * Widget tests

---

### ⚠️ Notes / Decisions

* Active players are always ranked above inactive players
* Inactive players remain in league rankings until reservation loss/removal rules apply
* Regular divisions:

  * bottom 40% are relegated
  * promotion count structurally matches relegation count
* Penultimate ↔ last division uses special settlement rules
* Last division may close when not enough active promotion candidates exist
* Active players always preserve reserved slots
* Inactive players in the last division lose reserved slots
* Players removed from closed last divisions must re-enter the league manually
* Weekly settlement currently uses app runtime clock
* Future backend should enforce explicit Europe/Lisbon timezone authority
* UI settlement display is repository/domain-driven only
* No settlement calculations are performed inside widgets
* Weekly runs are cleared after settlement execution
* Duplicate settlement execution is blocked per season

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Active players rank above inactive players
* [x] Updated tie-breaker chain validated
* [x] Bottom 40% relegation validated
* [x] Promotion flow validated
* [x] Penultimate ↔ last division rules validated
* [x] Last division closure validated
* [x] Reserved slot loss rules validated
* [x] Duplicate settlement prevention validated
* [x] Weekly run cleanup validated
* [x] History generation validated
* [x] Settlement visibility validated
* [x] Inactive UI indicators validated

---

### 📌 Next Session

Session 18 — Last Division Expansion + League Re-entry Flow

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* 🔄 Session 18 — Last Division Expansion + League Re-entry Flow (ready)

---

### 🧭 Current State

Current session: Session 18 — Last Division Expansion + League Re-entry Flow
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 18 — Last Division Expansion + League Re-entry Flow

### Status:

✅ Completed

---

### 🎯 Objective

Implement automatic last division expansion and manual weekly league re-entry flow for players who lose their reserved slot after weekly settlement.

---

### 📦 Deliverables

* [x] Manual weekly league re-entry flow implemented
* [x] Re-entry requires weekly entry cost (10 GP)
* [x] Re-entry places player in current last division
* [x] Automatic last division creation when full
* [x] Division capacity scaling preserved
* [x] Players without reserved slot shown as outside the league
* [x] Re-entry CTA implemented in LeagueHomeScreen
* [x] PlayerProfile synchronization after entry/re-entry implemented
* [x] Duplicate league entry prevention implemented
* [x] GP validation added before entry/re-entry
* [x] Lost reserved slot entries excluded from division capacity usage
* [x] Stable division ordering added
* [x] Repository tests updated
* [x] Domain tests updated
* [x] Widget tests updated
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Updated `MockLeagueRepository`

  * Added re-entry handling for players without reserved slots
  * Added automatic last division expansion
  * Added safe division insertion ordering
  * Preserved settlement cleanup compatibility
  * Preserved duplicate-entry protection
* Updated `LeagueDivisionPolicy`

  * Lost reserved slot entries no longer count toward last division capacity
  * Preserved dynamic division growth rules
* Updated `LeagueHomeScreen`

  * Added outside league state
  * Added re-entry messaging
  * Added dynamic CTA:

    * `Enter Weekly League`
    * `Re-enter Weekly League`
  * Added GP validation before entry
  * Added PlayerProfile synchronization after entry
  * Added safer division fallback handling
  * Added GP clamp protection
* Updated repository tests

  * Re-entry after reserved slot loss
  * Automatic last division creation
  * Reserved slot capacity handling
  * Division expansion behavior
* Updated widget tests

  * Outside league UI state
  * Re-entry CTA
  * GP validation
  * PlayerProfile synchronization
* Updated domain tests

  * Dynamic division placement validation
  * Reserved slot exclusion validation

---

### ⚠️ Notes / Decisions

* Players without reserved slots are considered outside the league
* Re-entry always places the player into the current last division
* New last divisions are created automatically when full
* Division capacities continue doubling from Division 1
* Lost reserved slot players do not occupy division capacity
* Duplicate active entries are blocked
* GP deduction remains outside domain policy ownership
* Repository remains mock-first and backend-ready
* No division calculations are performed inside widgets
* UI remains repository/domain-driven only

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Re-entry flow validated
* [x] Automatic division expansion validated
* [x] Reserved slot exclusion validated
* [x] GP validation validated
* [x] Duplicate entry prevention validated
* [x] Outside league UI validated
* [x] PlayerProfile synchronization validated
* [x] Settlement compatibility validated

---

### 📌 Next Session

Session 19 — League Polish + Edge Case Hardening

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* 🔄 Session 19 — League Polish + Edge Case Hardening (ready)

---

### 🧭 Current State

Current session: Session 19 — League Polish + Edge Case Hardening
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 19 — League Polish + Edge Case Hardening

### Status:

✅ Completed

---

### 🎯 Objective

Polish and harden the weekly league system before advancing to Knockout development.

Focus areas:
- ranking integrity
- reserved slot consistency
- stale state handling
- re-entry robustness
- settlement edge cases
- runtime validation safety

---

### 📦 Deliverables

* [x] Reserved slot ranking filtering implemented
* [x] Invalid league run submission protection implemented
* [x] Outside-league player handling implemented
* [x] Snapshot request guards implemented
* [x] Stale PlayerProfile recovery implemented
* [x] Re-entry flow hardened
* [x] Ranking integrity protections added
* [x] Settlement edge-case handling improved
* [x] LeagueHomeScreen runtime consistency improved
* [x] Repository tests expanded
* [x] Domain tests expanded
* [x] Widget tests expanded
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Updated `MockLeagueRepository`

  * Players without reserved slots can no longer submit league runs
  * Players without reserved slots are excluded from runtime league participation
  * Re-entry flow now safely restores active participation
  * Settlement/runtime consistency improved
  * Ranking safety preserved after slot removal
* Updated `LeagueRankingCalculator`

  * Added reserved slot filtering inside ranking domain logic
  * Players outside the league are no longer ranked
  * Ranking consistency improved across:
    * runtime
    * snapshots
    * settlement
    * UI
  * Preserved deterministic tie-breaker chain
* Updated `LeagueHomeScreen`

  * UI no longer trusts stale local `PlayerProfile` league state
  * Repository state is now authoritative
  * Added safer snapshot request guards
  * Outside-league UI handling improved
  * Re-entry flow recovery improved
  * Snapshot loading for invalid league states prevented
* Updated repository tests

  * Reserved slot loss submission rejection
  * Ranking exclusion after slot loss
  * Re-entry after slot removal
  * Settlement/runtime edge cases
  * Division cleanup compatibility
* Updated domain tests

  * Reserved slot ranking exclusion
  * Snapshot threshold validation
  * Tie-breaker integrity validation
  * Settlement edge-case validation
  * Last division consistency validation
* Updated widget tests

  * Outside-league rendering
  * Re-entry recovery
  * Snapshot suppression validation
  * Stale profile recovery
  * GP synchronization validation
  * Reserved slot loss rendering

---

### ⚠️ Notes / Decisions

* Players without reserved slots are fully considered outside the weekly league
* Ranking validity is enforced inside domain/repository logic
* LeagueHomeScreen now relies on repository runtime state instead of stale local profile flags
* Snapshot requests are prevented for invalid league states
* Invalid run submissions are rejected before runtime insertion
* Tie-breaker determinism remains preserved for future backend authoritative validation
* Repository remains backend-ready and mock-first
* UI remains repository/domain-driven only
* Settlement compatibility preserved across all edge cases
* No competitive calculations moved into widgets

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Reserved slot exclusion validated
* [x] Invalid submission protection validated
* [x] Re-entry recovery validated
* [x] Outside league UI validated
* [x] Snapshot suppression validated
* [x] Stale profile recovery validated
* [x] Ranking consistency validated
* [x] Settlement compatibility validated

---

### 📌 Current Session

Session 20 — Knockout Structure + Registration Flow

Official knockout assumptions aligned:

* One monthly knockout tournament
* Registration cost is always 25 GP
* Registration uses explicit open / closed / in-progress lifecycle states
* Daily duels settle at 23:59 Europe/Lisbon
* Brackets support unlimited registrations, byes and dynamic opening eliminations
* Knockout duel scoring reuses league best-runs block logic without activity multipliers or bonus points
* Repechage preparation follows eliminated score, lifetime runs, lifetime average score and oldest registration tie-breakers

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* 🔄 Session 20 — Knockout Structure + Registration Flow (in progress)

---

### 🧭 Current State

Current session: Session 20 — Knockout Structure + Registration Flow
Status: Official tournament foundation aligned 🔄

---

## 🔄 Session Update

### Session: Session 20 — Knockout Foundation + Tournament Lifecycle

### Status:

✅ Completed

---

### 🎯 Objective

Implement the complete Knockout tournament foundation, including monthly registration lifecycle, dynamic bracket generation, knockout scoring rules, tournament runtime preparation, and repository/UI integration.

---

### 📦 Deliverables

* [x] Knockout feature architecture implemented
* [x] Monthly tournament lifecycle implemented
* [x] Tournament registration windows implemented
* [x] 25 GP entry cost implemented
* [x] Registration open / closed / in progress states implemented
* [x] Tournament schedule service implemented
* [x] Knockout repository contract implemented
* [x] Mock knockout repository implemented
* [x] Knockout registration validation implemented
* [x] Duplicate registration prevention implemented
* [x] GP validation implemented
* [x] Explicit tournament start flow implemented
* [x] Automatic in-progress protection without bracket implemented
* [x] Dynamic knockout bracket generation implemented
* [x] Unlimited registration support implemented
* [x] Opening elimination round generation implemented
* [x] Bye distribution implemented
* [x] 35→32 opening round reduction logic implemented
* [x] Knockout round model implemented
* [x] Knockout match model implemented
* [x] Knockout run model implemented
* [x] Knockout duel score model implemented
* [x] Knockout scoring calculator implemented
* [x] League-style best-runs block scoring implemented
* [x] Knockout no-bonus scoring rule implemented
* [x] Repechage selector implemented
* [x] Official repechage tie-breaker chain implemented
* [x] KnockoutHomeScreen implemented
* [x] Tournament structure preview implemented
* [x] Registration state UI implemented
* [x] Knockout navigation integrated into GameScreen
* [x] StoppyApp dependency injection updated
* [x] AuthGate dependency injection updated
* [x] Repository tests updated
* [x] Domain tests updated
* [x] Widget tests updated
* [x] Bracket generation tests added
* [x] Repechage tests added
* [x] Tournament lifecycle tests added
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Added complete `knockout` feature structure
* Added `KnockoutTournament`
* Added `KnockoutRound`
* Added `KnockoutMatch`
* Added `KnockoutRun`
* Added `KnockoutDuelScore`
* Added `KnockoutPlayerEntry`
* Added `KnockoutRegistrationResult`
* Added `KnockoutTournamentSchedule`
* Added `KnockoutBracketPlanner`
* Added `KnockoutDuelScoreCalculator`
* Added `KnockoutRepechageSelector`
* Added `KnockoutRepository`
* Added `MockKnockoutRepository`
* Added explicit monthly tournament lifecycle
* Added registration open/close runtime handling
* Added deterministic opening-round bracket generation
* Added unlimited player registration support
* Added support for non-power-of-two tournaments
* Added automatic bye generation
* Added repository protections against invalid tournament state transitions
* Added explicit `startTournament()` runtime flow
* Added protection against automatic `inProgress` state without rounds
* Added KnockoutHomeScreen registration flow
* Added tournament structure preview UI
* Added Knockout integration into GameScreen
* Added Knockout repository injection into app bootstrap
* Added extensive repository/domain/widget test coverage

---

### ⚠️ Notes / Decisions

* Knockout tournaments are monthly
* Registration opens before the next monthly tournament starts
* Registration cost is fixed at 25 GP
* Tournament progression is explicit and repository-driven
* Tournament state cannot automatically become `inProgress` without rounds
* Opening rounds dynamically eliminate excess players above the nearest lower power of two
* Bye allocation is automatic and deterministic
* Knockout scoring reuses league best-runs block logic
* No activity multipliers or bonus points are used in knockout scoring
* Repechage follows the official tie-breaker priority chain:

  * Eliminated duel score
  * Lifetime run count
  * Lifetime average run score
  * Oldest account
* Repository remains mock-first and backend-ready
* UI remains repository/domain-driven only
* No bracket calculations are performed inside widgets
* Active duel detection is repository-owned
* Knockout runs are submitted only in `RunMode.tournament`
* Daily round settlement advances winners, tracks eliminated players and starts the next round
* Bye players are carried into the next settlement pool automatically
* Zero-run duels use repechage winners when eligible eliminated players exist

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Tournament lifecycle validated
* [x] Registration flow validated
* [x] GP deduction validated
* [x] Duplicate registration prevention validated
* [x] Opening-round bracket generation validated
* [x] 35-player edge case validated
* [x] Bye generation validated
* [x] Repechage priority validated
* [x] Explicit tournament start flow validated
* [x] Knockout UI rendering validated
* [x] Active matchup detection validated
* [x] Knockout run submission validated
* [x] Daily duel settlement validated
* [x] Winner advancement validated
* [x] Loser elimination tracking validated
* [x] GameScreen tournament submission validated

---

### 📌 Next Session

Session 22 — Knockout Match Gameplay UX

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (ready)

---

### 🧭 Current State

Current session: Session 21 — Active Knockout Runtime + Duel Progression
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 21 — Active Knockout Runtime + Duel Progression

### Status:

✅ Completed

---

### 🎯 Objective

Implement active knockout runtime, duel progression, daily settlement flow, and tournament gameplay integration on top of the existing knockout tournament foundation.

---

### 📦 Deliverables

* [x] Active duel runtime implemented
* [x] `KnockoutDuelSnapshot` model implemented
* [x] Active matchup detection implemented
* [x] Knockout duel score tracking implemented
* [x] Knockout run submission flow implemented
* [x] `GameScreen` tournament mode integration implemented
* [x] Knockout duel scoring integrated with `KnockoutDuelScoreCalculator`
* [x] Daily duel settlement flow implemented
* [x] Winner advancement implemented
* [x] Loser elimination tracking implemented
* [x] Bye advancement implemented
* [x] Zero-run duel repechage flow implemented
* [x] Next-round generation implemented
* [x] Match completion + voided states implemented
* [x] Active Duel UI implemented in `KnockoutHomeScreen`
* [x] Duplicate knockout run submission protection implemented
* [x] Knockout submission retry safety improved
* [x] Knockout run ID collision risk reduced
* [x] Knockout runtime assertions hardened
* [x] Repository tests added/updated
* [x] Widget tests added/updated
* [x] `flutter analyze` passed
* [x] `flutter test` passed (181 tests)

---

### 🛠️ Work Done

* Added `KnockoutDuelSnapshot`
* Added `fetchActiveDuel()` to `KnockoutRepository`
* Added `submitKnockoutRun()` to `KnockoutRepository`
* Added `settleCurrentRound()` to `KnockoutRepository`
* Extended `MockKnockoutRepository`:

  * Active duel detection
  * Duel snapshot generation
  * Knockout run storage
  * Knockout score recalculation
  * Round settlement logic
  * Winner advancement
  * Loser elimination
  * Bye handling
  * Repechage advancement
  * Next-round generation
  * Duplicate run protection
* Added deterministic tie fallback logic
* Added voided duel handling for zero-run matches
* Added repechage candidate selection logic
* Added knockout duel score aggregation models/services
* Integrated tournament runtime flow into `GameScreen`
* Added guarded knockout run submission finalization flow
* Added retry-safe knockout submission logic
* Added safer knockout run ID generation
* Added Active Duel section to `KnockoutHomeScreen`
* Added knockout runtime UI states:

  * Active duel
  * Bye advancement
  * No active duel
  * Waiting for tournament start
* Added repository tests for:

  * Duel detection
  * Duel scoring
  * Settlement
  * Winner advancement
  * Elimination
  * Repechage
  * Duplicate submission protection
* Added widget tests for knockout duel UI
* Added `GameScreen` tournament submission tests
* Updated `docs/App_Dev_Status.md`

---

### ⚠️ Notes / Decisions

* Knockout runtime remains repository-driven and backend-ready
* Gameplay runtime remains separated from tournament settlement logic
* UI layers do not calculate duel winners or bracket state
* Repechage remains deterministic and service-driven
* Settlement flow is deterministic and mock-backend safe
* Tournament scoring intentionally excludes activity multipliers and bonus systems
* Knockout scoring reuses league best-runs block calculation logic
* Duplicate knockout submissions are now guarded at repository level
* Knockout finalization flow now supports safer retry behaviour
* Zero-run duels are marked as `voided` instead of forcing artificial winners
* Repechage advancement is deterministic and ranking-based
* Tie fallback currently uses lifetime stats and oldest account age
* Future backend should enforce authoritative settlement timing and submission locking
* UI runtime state is repository/domain-driven only
* No knockout duel calculations are performed inside widgets

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Active duel detection validated
* [x] Knockout duel score calculation validated
* [x] Winner advancement validated
* [x] Loser elimination validated
* [x] Bye advancement validated
* [x] Repechage flow validated
* [x] Duplicate submission protection validated
* [x] Knockout finalization flow validated
* [x] Active Duel UI validated
* [x] Tournament runtime integration validated

---

### 📌 Next Session

Session 22 — Knockout Duel UI Polish + Player Tournament Status

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (completed)
* 🔄 Session 22 — Knockout Duel UI Polish + Player Tournament Status (ready)

---

### 🧭 Current State

Current session: Session 22 — Knockout Duel UI Polish + Player Tournament Status
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 22 — Knockout Duel UI Polish + Player Tournament Status

### Status:

✅ Completed

---

### 🎯 Objective

Polish the active knockout duel UI and implement clear player-facing tournament status states for the monthly Knockout system.

---

### 📦 Deliverables

* [x] `KnockoutPlayerStatus` domain model implemented
* [x] Player tournament states implemented:
  * [x] not registered
  * [x] registered waiting for tournament start
  * [x] active duel
  * [x] bye waiting for next round
  * [x] eliminated
  * [x] tournament champion
  * [x] tournament completed
* [x] `fetchPlayerStatus()` added to `KnockoutRepository`
* [x] `fetchPlayerStatus()` implemented in `MockKnockoutRepository`
* [x] Champion tracking added to `KnockoutTournament`
* [x] Champion persistence integrated into tournament settlement flow
* [x] Active duel status UI added to `KnockoutHomeScreen`
* [x] Opponent details UI added
* [x] Duel score summary UI added
* [x] Run count UI added
* [x] Round settlement time UI added
* [x] Bye state UI implemented
* [x] Eliminated state UI implemented
* [x] Champion state UI implemented
* [x] Tournament completed state UI implemented
* [x] Tournament CTA only enabled for active duel state
* [x] Tournament run flow integrated into `GameScreen`
* [x] `RunMode.tournament` gameplay flow connected
* [x] Knockout run submission flow integrated into game finalization
* [x] Duplicate knockout run submission protection implemented
* [x] Knockout submission acceptance validation implemented
* [x] Repository-driven tournament runtime preserved
* [x] UI kept free of tournament calculation logic
* [x] Repechage runtime compatibility preserved
* [x] Bye advancement compatibility preserved
* [x] Tournament completion semantics corrected for non-participants
* [x] Defensive `activeDuel` snapshot assertion added
* [x] Tournament model `copyWith()` null-reset support added
* [x] Champion consistency assertions added
* [x] Repository tests expanded
* [x] Domain tests expanded
* [x] Widget tests expanded
* [x] Edge-case tests added:
  * [x] duplicate knockout submissions
  * [x] post-settlement submission rejection
  * [x] outsider completion status
  * [x] active duel play eligibility
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Added `KnockoutPlayerStatus`
* Added player-facing tournament runtime states
* Added `fetchPlayerStatus()` to `KnockoutRepository`
* Extended `MockKnockoutRepository` with player status runtime flow
* Added champion tracking to `KnockoutTournament`
* Added champion settlement integration
* Polished `KnockoutHomeScreen`
* Added Tournament Status section
* Added opponent runtime details
* Added duel score UI
* Added run count UI
* Added round settlement time UI
* Added active duel CTA flow
* Added active duel CTA gating
* Integrated tournament gameplay flow into `GameScreen`
* Added `RunMode.tournament` runtime integration
* Added guarded tournament run submission flow
* Added knockout submission acceptance validation
* Hardened tournament runtime assertions
* Added non-participant completion safeguards
* Added champion consistency validation
* Improved tournament model `copyWith()` safety
* Added repository tests for:
  * player runtime states
  * champion flow
  * outsider completion handling
  * duplicate submission handling
  * post-settlement rejection
* Added domain tests for:
  * tournament player status
  * active duel eligibility
  * runtime assertions
* Added widget tests for:
  * active duel state
  * waiting state
  * bye state
  * eliminated state
  * champion state
  * completed state
  * CTA enable/disable behaviour
* Updated knockout gameplay integration tests
* Updated `docs/App_Dev_Status.md`

---

### ⚠️ Notes / Decisions

* Knockout runtime remains repository/domain-driven
* UI layers do not calculate duel winners or tournament advancement
* `GameScreen` only submits finalized tournament scores
* Tournament settlement authority remains centralized in repository logic
* Knockout gameplay remains isolated from tournament progression systems
* Tournament CTA is only enabled for active duel states
* Non-participants no longer receive `tournamentCompleted` status
* Active duel states now require a valid duel snapshot
* Champion state persists after final settlement
* Knockout submission flow now validates accepted/rejected submissions
* Tournament runtime remains deterministic and backend-ready
* Repechage and bye runtime flows remain fully compatible
* Tournament scoring intentionally excludes gameplay multipliers and bonus systems
* No knockout tournament calculations are performed inside widgets

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Player runtime state flow validated
* [x] Active duel runtime validated
* [x] Tournament CTA gating validated
* [x] Champion flow validated
* [x] Tournament completion semantics validated
* [x] Duplicate submission rejection validated
* [x] Post-settlement submission rejection validated
* [x] Active duel eligibility validated
* [x] Knockout gameplay integration validated
* [x] Widget runtime states validated

---

### 📌 Next Session

Session 23 — Knockout Tournament History + Records

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (completed)
* ✅ Session 22 — Knockout Duel UI Polish + Player Tournament Status (completed)
* 🔄 Session 23 — Knockout Tournament History + Records (ready)

---

### 🧭 Current State

Current session: Session 23 — Knockout Tournament History + Records  
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 23 — Knockout Tournament History + Records

### Status:

✅ Completed

---

### 🎯 Objective

Implement persistent knockout tournament history, player knockout records, and completed tournament result tracking with scalable player-facing records/history UI.

---

### 📦 Deliverables

* [x] `KnockoutTournamentHistoryEntry` domain model implemented
* [x] `KnockoutPlayerRecords` domain model implemented
* [x] Knockout tournament outcome enum implemented
* [x] Outcome label extension implemented
* [x] Completed tournament history generation implemented
* [x] Persistent player knockout records implemented
* [x] Champion history tracking implemented
* [x] Eliminated player history tracking implemented
* [x] Final round reached tracking implemented
* [x] Best duel score tracking implemented
* [x] Tournament played count tracking implemented
* [x] Tournament won count tracking implemented
* [x] Non-participant exclusion from history/records implemented
* [x] `fetchPlayerHistory()` added to `KnockoutRepository`
* [x] `fetchPlayerRecords()` added to `KnockoutRepository`
* [x] History persistence implemented in `MockKnockoutRepository`
* [x] Personal records persistence implemented in `MockKnockoutRepository`
* [x] Duplicate completed tournament recording prevention implemented
* [x] Seeded history injection support implemented for tests
* [x] Seeded records injection support implemented for tests
* [x] History sorting by newest completion implemented
* [x] Personal Knockout Records UI card implemented
* [x] Tournament History UI card implemented
* [x] History visible entry cap implemented
* [x] Hidden history overflow indicator implemented
* [x] Parallelized tournament state loading implemented
* [x] `didUpdateWidget()` profile synchronization implemented
* [x] Shared `DateTimeFormatter` utility implemented
* [x] Removed unused `_ActiveDuelSection` parameters
* [x] Reduced UI-side opponent lookup responsibilities
* [x] Repository-driven records/history architecture preserved
* [x] UI kept free of tournament calculation logic
* [x] Repechage/runtime/history compatibility preserved
* [x] Repository tests expanded
* [x] Domain tests expanded
* [x] Widget tests expanded
* [x] Edge-case tests added:

  * [x] history ordering
  * [x] seeded cumulative records
  * [x] best duel score preservation
  * [x] hidden history limit rendering
  * [x] `didUpdateWidget()` synchronization
* [x] `KnockoutPlayerRecords.copyWith()` tests added
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Added `KnockoutTournamentHistoryEntry`
* Added `KnockoutPlayerRecords`
* Added knockout tournament outcome enum + labels
* Extended `KnockoutRepository`
* Extended `MockKnockoutRepository`
* Added completed tournament history generation flow
* Added persistent player records flow
* Added tournament played/won tracking
* Added best duel score tracking
* Added final round tracking
* Added champion history tracking
* Added eliminated history tracking
* Added duplicate completion recording safeguards
* Added seeded history/records support for deterministic testing
* Added history sorting
* Added Personal Knockout Records section
* Added Tournament History section
* Added capped history rendering
* Added hidden history overflow indicator
* Parallelized async tournament state loading
* Added `didUpdateWidget()` synchronization flow
* Added shared `DateTimeFormatter`
* Removed unused `_ActiveDuelSection` parameters
* Reduced UI-side tournament lookup responsibilities
* Added repository tests for:

  * history generation
  * champion records
  * eliminated records
  * history ordering
  * cumulative records
  * best duel score preservation
  * outsider exclusion
* Added widget tests for:

  * records rendering
  * history rendering
  * hidden history limit
  * profile synchronization
* Added domain tests for:

  * records defaults
  * `copyWith()` behaviour
* Updated `docs/App_Dev_Status.md`

---

### ⚠️ Notes / Decisions

* Knockout records/history remain fully repository-driven
* UI layers do not calculate tournament statistics
* Completed tournament recording is deterministic and duplicate-safe
* History rendering now scales safely with capped visible entries
* Repository supports seeded history/records for deterministic testing
* Tournament runtime remains backend-ready
* Repechage and bye runtime compatibility fully preserved
* Tournament settlement authority remains centralized in repository logic
* No knockout tournament calculations are performed inside widgets

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Champion history validated
* [x] Eliminated player history validated
* [x] History ordering validated
* [x] Cumulative records validated
* [x] Best duel score preservation validated
* [x] Hidden history limit validated
* [x] `didUpdateWidget()` synchronization validated
* [x] Non-participant exclusion validated
* [x] Records rendering validated
* [x] Tournament history rendering validated
* [x] Knockout runtime compatibility validated

---

### 📌 Next Session

Session 24 — Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (completed)
* ✅ Session 22 — Knockout Duel UI Polish + Player Tournament Status (completed)
* ✅ Session 23 — Knockout Tournament History + Records (completed)
* 🔄 Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish (ready)

---

### 🧭 Current State

Current session: Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish
Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish

### Status:

✅ Completed

---

### 🎯 Objective

Implement a historical Knockout Hall of Fame while simplifying player Knockout records and clearly separating global champion recognition from player-specific statistics.

---

### 📦 Deliverables

* [x] `KnockoutHallOfFameEntry` domain model implemented
* [x] `fetchHallOfFame()` added to `KnockoutRepository`
* [x] Hall of Fame aggregation implemented in `MockKnockoutRepository`
* [x] Historical champion tracking integrated with tournament settlement
* [x] Champion-only Hall of Fame implemented
* [x] Title count aggregation per champion implemented
* [x] Deterministic Hall of Fame ordering implemented
* [x] Knockout Hall of Fame UI card implemented
* [x] Empty Hall of Fame state implemented
* [x] Player records simplified
* [x] Titles won retained in player records
* [x] Best tournament result retained in player records
* [x] Personal best duel score removed from player records
* [x] Personal best duel score removed from tournament history entries
* [x] Tournament history recording flow updated
* [x] Historical champion aggregation preserved across seeded history
* [x] Repository-driven Hall of Fame architecture preserved
* [x] UI kept free of Hall of Fame calculation logic
* [x] Repository tests expanded
* [x] Domain tests expanded
* [x] Widget tests expanded
* [x] `flutter analyze` passed
* [x] `flutter test` passed (204 tests)

---

### 🛠️ Work Done

* Added `KnockoutHallOfFameEntry`
* Extended `KnockoutRepository`
* Extended `MockKnockoutRepository`
* Added Hall of Fame aggregation flow
* Added champion title counting
* Added deterministic Hall of Fame ordering
* Added Hall of Fame repository API
* Added Hall of Fame UI section
* Added Hall of Fame empty-state handling
* Simplified `KnockoutPlayerRecords`
* Removed personal best duel score tracking
* Removed best duel score persistence from tournament history
* Updated completed tournament history recording
* Preserved player titles won tracking
* Preserved best tournament result tracking
* Preserved history ordering behaviour
* Preserved duplicate tournament completion protection
* Preserved seeded history support for deterministic testing
* Added repository tests for Hall of Fame aggregation
* Added widget tests for Hall of Fame rendering
* Updated champion-state UI validation
* Updated personal records validation

---

### ⚠️ Notes / Decisions

* Hall of Fame intentionally includes champions only
* Hall of Fame shows only title counts
* Seasonal rankings were intentionally not implemented
* Ranking-point systems were intentionally not implemented
* Best duel scores were intentionally removed from Hall of Fame scope
* Player progression statistics remain separate from Hall of Fame data
* Hall of Fame remains fully repository-driven
* UI performs no Hall of Fame calculations
* Historical champion aggregation remains deterministic
* Backend-ready architecture preserved

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Hall of Fame aggregation validated
* [x] Champion-only filtering validated
* [x] Title count accumulation validated
* [x] Hall of Fame ordering validated
* [x] Empty Hall of Fame state validated
* [x] Champion history tracking validated
* [x] Player records validation preserved
* [x] Tournament history validation preserved
* [x] Knockout runtime compatibility validated

---

### 📌 Next Session

Session 25 — Competitive Profile + Knockout Statistics Polish

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (completed)
* ✅ Session 22 — Knockout Duel UI Polish + Player Tournament Status (completed)
* ✅ Session 23 — Knockout Tournament History + Records (completed)
* ✅ Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish (completed)
* 🔄 Session 25 — Competitive Profile + Knockout Statistics Polish (ready)

---

### 🧭 Current State

Current session: Session 25 — Competitive Profile + Knockout Statistics Polish

Status: Ready ⏳

---

Claro — aqui está a atualização da **Session 25** no mesmo formato do ficheiro anterior.

## 🔄 Session Update

### Session: Session 25 — Competitive Profile + Knockout Statistics Polish

### Status:

✅ Completed

---

### 🎯 Objective

Expand player-facing competitive statistics by improving Knockout personal stats, polishing Hall of Fame champion entries, and introducing a combined competitive achievements view for League and Knockout.

---

### 📦 Deliverables

* [x] Knockout player records expanded
* [x] Total duels played tracking implemented
* [x] Total duels won tracking implemented
* [x] Duel win percentage implemented
* [x] Tournaments participated tracking implemented
* [x] Best round reached tracking implemented
* [x] Repechage advancement excluded from duel wins
* [x] Hall of Fame champion-only behaviour preserved
* [x] Hall of Fame tournament win months/years added
* [x] Hall of Fame title month aggregation implemented
* [x] Hall of Fame title month ordering made deterministic
* [x] Hall of Fame UI updated with champion name, title count and won months
* [x] `DateTimeFormatter` utility added
* [x] Domain presentation labels removed where appropriate
* [x] League achievements model implemented
* [x] Best division reached tracking implemented
* [x] Promotions count implemented
* [x] Relegations count implemented
* [x] League achievements repository projection added
* [x] Competitive Achievements UI section implemented
* [x] League and Knockout achievements shown separately in one section
* [x] `LeagueRepository` passed into `KnockoutHomeScreen`
* [x] Knockout UI kept repository/domain-driven
* [x] Tests updated for records, Hall of Fame and achievements
* [x] `flutter analyze` passed
* [x] `flutter test` passed

---

### 🛠️ Work Done

* Expanded `KnockoutPlayerRecords` with:

  * tournaments played
  * tournaments won
  * highest round reached
  * total duels played
  * total duels won
  * duel win percentage
* Updated Knockout records aggregation in `MockKnockoutRepository`
* Ensured repechage advancement does not count as a direct duel win
* Updated Hall of Fame entries to store won tournament months
* Preserved champion-only Hall of Fame aggregation
* Added deterministic title month storage and validation
* Removed UI labels from Hall of Fame domain model
* Added shared `DateTimeFormatter`
* Updated `KnockoutHomeScreen` to format dates/months in the UI layer
* Added `PlayerLeagueAchievements`
* Added `fetchPlayerAchievements()` to `LeagueRepository`
* Implemented League achievements projection in `MockLeagueRepository`
* Added Competitive Achievements section to Knockout UI
* Displayed League achievements:

  * best division reached
  * promotions
  * relegations
* Displayed Knockout achievements:

  * best round reached
  * tournaments participated
  * duel win percentage
  * total duels played
* Updated domain tests
* Updated repository tests
* Updated widget tests
* Removed obsolete references to domain presentation labels

---

### ⚠️ Notes / Decisions

* No Knockout rewards were implemented
* No GP prizes were implemented
* No ranking points were implemented
* No seasonal ranking ladders were implemented
* No new economy system was introduced
* Hall of Fame remains champion-only
* Hall of Fame remains repository-driven
* Competitive achievements are repository/domain-driven
* UI performs formatting only and does not calculate competitive statistics
* League and Knockout achievements remain separate but visible together
* Repechage advancement is not counted as a duel win
* Backend-ready mock-first architecture preserved

---

### 🧪 Validation

* [x] flutter analyze
* [x] flutter test
* [x] Knockout expanded records validated
* [x] Duel win percentage validated
* [x] Repechage win exclusion validated
* [x] Hall of Fame champion-only filtering validated
* [x] Hall of Fame title month aggregation validated
* [x] Hall of Fame deterministic ordering validated
* [x] League achievements projection validated
* [x] Competitive Achievements UI validated
* [x] Date formatting utility validated
* [x] Removed domain label references validated
* [x] Existing Knockout runtime compatibility preserved
* [x] Existing League settlement compatibility preserved

---

### 📌 Next Session

Session 26 — Backend Foundation + Data Persistence Planning

Suggested focus:

* [ ] Define backend architecture direction
* [ ] Decide Firebase vs custom backend
* [ ] Map current repositories to backend contracts
* [ ] Identify authoritative server-side validations
* [ ] Plan persistence for player profiles
* [ ] Plan persistence for League state
* [ ] Plan persistence for Knockout tournaments
* [ ] Plan anti-cheat validation boundaries

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (completed)
* ✅ Session 22 — Knockout Duel UI Polish + Player Tournament Status (completed)
* ✅ Session 23 — Knockout Tournament History + Records (completed)
* ✅ Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish (completed)
* ✅ Session 25 — Competitive Profile + Knockout Statistics Polish (completed)
* 🔄 Session 26 — Backend Foundation + Data Persistence Planning (ready)

---

### 🧭 Current State

Current session: Session 26 — Backend Foundation + Data Persistence Planning

Status: Ready ⏳

---

## 🔄 Session Update

### Session: Session 26 — Backend Foundation + Data Persistence Planning

### Status:

✅ Completed

---

### 🎯 Objective

Prepare the long-term backend architecture, persistence strategy, API surface, and anti-cheat foundations required to migrate the current mock-first implementation toward a production-ready server-authoritative platform.

---

### 📦 Deliverables

* [x] Backend architecture plan created
* [x] Custom backend direction finalized
* [x] PostgreSQL persistence strategy documented
* [x] REST API strategy documented
* [x] Client vs server responsibilities documented
* [x] Server-authoritative rules documented
* [x] Backend architecture section added to Architecture.md
* [x] Anti-cheat plan created
* [x] Client trust boundaries documented
* [x] Future validation strategy documented
* [x] Settlement protection rules documented
* [x] Replay/event-log strategy documented
* [x] Persistence mapping created
* [x] League persistence requirements documented
* [x] Knockout persistence requirements documented
* [x] Hall of Fame persistence requirements documented
* [x] Future API plan created
* [x] Auth endpoints documented
* [x] Player endpoints documented
* [x] League endpoints documented
* [x] Knockout endpoints documented
* [x] Gameplay submission endpoints documented
* [x] Store/economy endpoints documented
* [x] Internal settlement endpoints documented
* [x] Backend implementation intentionally deferred
* [x] No gameplay changes introduced
* [x] No League runtime changes introduced
* [x] No Knockout runtime changes introduced
* [x] flutter analyze passed
* [x] flutter test passed (208 tests)

---

### 🛠️ Work Done

* Created `docs/Backend_Plan.md`
* Defined target architecture:

  * Flutter Client
  * Custom Backend API
  * PostgreSQL
  * REST API
  * Server-authoritative competitive logic

* Documented client responsibilities:

  * UI
  * local rendering
  * input collection
  * temporary state

* Documented server responsibilities:

  * authentication
  * GP economy
  * purchases
  * league participation
  * league settlement
  * knockout lifecycle
  * Hall of Fame
  * achievements
  * run validation
  * anti-cheat validation

* Defined authoritative ownership for:

  * GP balances
  * purchases
  * league entry
  * league rankings
  * league settlements
  * knockout registration
  * knockout duel results
  * knockout advancement
  * Hall of Fame
  * competitive achievements

* Updated `docs/Architecture.md`

  * Added future backend architecture section
  * Preserved repository-contract architecture
  * Preserved mock repositories for testing
  * Documented backend repository replacement strategy

* Created `docs/Anti_Cheat_Plan.md`

  * Defined client-not-trusted model
  * Documented run validation requirements
  * Documented PP progression validation
  * Documented tier progression validation
  * Documented duplicate submission protection
  * Documented settlement authority requirements
  * Added replay/event-log strategy

* Created `docs/Persistence_Map.md`

  * Mapped PlayerProfile persistence
  * Mapped League persistence
  * Mapped Knockout persistence
  * Mapped Hall of Fame persistence
  * Defined future PostgreSQL ownership
  * Documented validation requirements per entity

* Created `docs/API_Plan.md`

  * Auth endpoints
  * Player endpoints
  * League endpoints
  * Knockout endpoints
  * Gameplay submission endpoints
  * Store/economy endpoints
  * Internal settlement endpoints

---

### ⚠️ Notes / Decisions

* Firebase is no longer the recommended backend direction
* Custom backend is the official target architecture
* PostgreSQL is the planned primary database
* REST API is the planned first integration layer
* Competitive state must remain server-authoritative
* Mock repositories remain the current runtime implementation
* Repository contracts remain the migration boundary
* UI remains isolated from backend implementation details
* League and Knockout rules remain unchanged
* Anti-cheat validation is planned but not yet implemented
* Replay/event-log storage remains a future capability
* No networking layer was introduced during this session
* No persistence layer was implemented during this session

---

### 🧪 Validation

* [x] Backend architecture documentation reviewed
* [x] Anti-cheat documentation reviewed
* [x] Persistence mapping reviewed
* [x] API plan reviewed
* [x] Architecture documentation updated
* [x] No runtime behaviour changed
* [x] No gameplay behaviour changed
* [x] No league calculations changed
* [x] No knockout calculations changed
* [x] flutter analyze passed
* [x] flutter test passed (208 tests)

---

### 📌 Next Session

Session 27 — Backend Repository Contracts Preparation

Planned focus:

* [ ] DTO architecture
* [ ] API response models
* [ ] Serialization strategy
* [ ] BackendAuthRepository preparation
* [ ] BackendLeagueRepository preparation
* [ ] BackendKnockoutRepository preparation
* [ ] Result/error model standardization
* [ ] Mock → Backend migration path preparation

---

### 📊 Progress Update

* ✅ Session 1 — Initial setup (completed)
* ✅ Session 2 — Base structure and documentation (completed)
* ✅ Session 3 — Game base rendering (completed)
* ✅ Session 4 — Collision and validation (completed)
* ✅ Session 5 — Level system (completed)
* ✅ Session 6 — Run Points (RP) (removed from active gameplay in Session 16.1)
* ✅ Session 7 — Lives system (removed from active gameplay in Session 16.1)
* ✅ Session 8 — Precision Points (PP) (reworked in Session 16.1)
* ✅ Session 9 — Registration/Login (completed)
* ✅ Session 10 — GP System (completed)
* ✅ Session 11 — Purchases (completed)
* ✅ Session 12 — Ads (completed)
* ✅ Session 12.1 — RP Target Bonus + Reward Summary Flow (superseded by Session 16.1)
* ✅ Session 13 — League structure (completed)
* ✅ Session 14 — Weekly League Entry + Runtime Integration (completed)
* ✅ Session 15 — Weekly League Scoring + Ranking UI (completed)
* ✅ Session 16 — Weekly League History + Personal Records (completed)
* ✅ Session 16.1 — Gameplay Simplification + PP Tier System (completed)
* ✅ Session 17 — Promotion / Relegation Runtime + Weekly Settlement Flow (completed)
* ✅ Session 18 — Last Division Expansion + League Re-entry Flow (completed)
* ✅ Session 19 — League Polish + Edge Case Hardening (completed)
* ✅ Session 20 — Knockout Foundation + Tournament Lifecycle (completed)
* ✅ Session 21 — Active Knockout Runtime + Duel Progression (completed)
* ✅ Session 22 — Knockout Duel UI Polish + Player Tournament Status (completed)
* ✅ Session 23 — Knockout Tournament History + Records (completed)
* ✅ Session 24 — Knockout Hall of Fame + Player Knockout Stats Polish (completed)
* ✅ Session 25 — Competitive Profile + Knockout Statistics Polish (completed)
* ✅ Session 26 — Backend Foundation + Data Persistence Planning (completed)
* 🔄 Session 27 — Backend Repository Contracts Preparation (ready)

---

### 🧭 Current State

Current session: Session 27 — Backend Repository Contracts Preparation

Status: Ready ⏳
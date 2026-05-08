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
* Ranking
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

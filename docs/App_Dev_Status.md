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
  * Grants 5 RP
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
* Target outside Safe Zone grants 5 RP and free level advance with no difficulty increase
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
* [x] Target outside Safe Zone grants 5 RP and advances level without difficulty increase
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
* Target outside Safe Zone grants RP, PP and advances level without difficulty increase
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

Planned tasks:

* [ ] Criar modelo de GP no PlayerProfile
* [ ] Implementar conversão RP → GP no final da run
* [ ] Acumular GP por jogador
* [ ] Mostrar GP no Game Over screen
* [ ] Implementar reward diário (base)
* [ ] Implementar sistema de warmup (primeira run do dia)
* [ ] Adicionar display de GP na UI

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

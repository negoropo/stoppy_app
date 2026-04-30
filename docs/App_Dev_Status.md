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
* Validar nick único

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


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

### Backend (proposta inicial)

* Node.js / TypeScript ou alternativa equivalente
* API REST (ou gRPC numa fase futura)

### Base de Dados

* PostgreSQL (relacional)
  ou
* Firestore (NoSQL, mais rápido de implementar)

### Serviços adicionais

* Autenticação (Firebase Auth ou custom)
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



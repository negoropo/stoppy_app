# Stoppy 🎯

Stoppy é um jogo mobile competitivo baseado em precisão e timing, onde os jogadores competem em ligas semanais e torneios knockout.

O objetivo é parar uma bola em movimento num círculo, acertando numa zona segura ou num target para maximizar a pontuação.

---

## 🚀 Funcionalidades principais

* Gameplay baseado em precisão e timing
* Liga semanal por divisões
* Torneios knockout 1vs1
* Sistema de economia com Game Points (GP)
* Progressão de dificuldade dinâmica
* Competição cross-platform (iOS e Android)
* Sistema anti-cheat (planeado)

---

## 🧠 Conceitos principais

* **GP (Game Points)**
  Moeda usada para entrar em competições

* **RP (Run Points)**
  Pontos usados durante uma run para gerir dificuldade

* **PP (Precision Points)**
  Pontuação competitiva baseada na precisão

---

## 🛠️ Tecnologias

* Flutter (Dart)
* Android Studio
* Xcode (iOS Simulator)
* Backend: a definir

---

## ▶️ Como correr o projeto

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Verificar setup

```bash
flutter doctor
```

### 3. Correr a app

```bash
flutter run
```

---

## 📁 Estrutura do projeto

/lib
/core        → lógica base e utilitários
/features    → funcionalidades (game, liga, etc.)
/shared      → widgets reutilizáveis
main.dart

---

## 📚 Documentação

A documentação técnica está na pasta `/docs`:

* Game_Rules.md → regras completas do jogo
* Architecture.md → arquitetura da aplicação
* App_Dev_Status.md → estado atual do desenvolvimento

---

## 📌 Estado do projeto

Em desenvolvimento inicial 🚧

Ver detalhes em:
/docs/App_Dev_Status.md

---

## 🧩 Workflow de desenvolvimento

O desenvolvimento é feito em sessões:

1. Definir objetivo
2. Implementar feature
3. Validar
4. Atualizar App_Dev_Status.md

---

## 📄 Licença

A definir


---

## 🗺️ Roadmap de desenvolvimento

O desenvolvimento do projeto é feito por sessões incrementais organizadas em fases:

* Fase 0 — Setup
* Fase 1 — Game Engine
* Fase 2 — Jogador e Economia
* Fase 3 — Liga
* Fase 4 — Knockout
* Fase 5 — Backend e Escala
* Fase 6 — Finalização

👉 O plano detalhado de todas as sessões está disponível em:

/docs/App_Dev_Status.md

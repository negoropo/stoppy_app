# Stoppy — Codex Agent Instructions

## 1. Project Overview

Stoppy is a competitive mobile game focused on timing and precision.

Core principles:

* Skill-based gameplay (no pay-to-win)
* Competitive integrity is critical
* Client is NOT trusted
* Backend validation will be required in the future

The project is currently in early development.

---

## 2. Current Phase

Session 25 completed.

Current session: Session 26 — Backend Foundation + Data Persistence Planning

---

## 3. Tech Stack

* Flutter (Dart)
* Cross-platform (iOS + Android)

Planned:

* Backend (TBD)
* Database (TBD)
* State Management: Riverpod (not yet installed)

---

## 4. Architecture Rules

STRICT RULES:

* Separate UI from logic
* Game Engine must be isolated from Flutter UI
* Avoid mixing rendering and game logic
* Keep code modular and reusable
* Avoid tight coupling between features

Folder structure must be respected:

lib/
core/
features/
shared/

---

## 5. Code Conventions

Language:

* Code: English
* Documentation: English

Naming:

* Classes: PascalCase
* Variables: camelCase
* Files: snake_case

Structure:

* One responsibility per file
* Avoid large classes
* Prefer composition over inheritance

---

## 6. Game Engine Constraints (CRITICAL)

* Game logic must NOT depend on Flutter UI
* Must be testable in isolation
* Must be deterministic where possible
* All scoring logic must be clearly documented
* Future backend validation must be possible

DO NOT:

* Hardcode gameplay values without explanation
* Mix rendering code with scoring logic
* Assume client trust

---

## 7. Comments Policy

MANDATORY comments in:

* Game Engine logic
* Scoring calculations
* Level progression rules
* Any math-related logic
* Any non-trivial algorithm

Comments must explain:

* WHY (not just WHAT)

---

## 8. Flutter Guidelines

* Keep widgets small and focused
* Prefer StatelessWidget unless state is required
* Extract reusable widgets to /shared/widgets
* Avoid deep widget trees when possible

---

## 9. Before Completing Any Task

ALWAYS run:

flutter analyze
flutter test

Fix issues before finishing.

---

## 10. Git Guidelines

When making changes:

* Group related changes
* Use clear commit messages

Example:

"feat: add base game screen structure"

---

## 11. What Codex SHOULD Do

* Create and organize files
* Implement requested features
* Refactor code when needed
* Add necessary comments
* Keep consistency with architecture

---

## 12. What Codex MUST NOT Do

* Do NOT redesign architecture without instruction
* Do NOT introduce new dependencies without approval
* Do NOT implement backend logic yet
* Do NOT skip tests or analysis
* Do NOT create overly complex solutions

---

## 13. Output Expectations

All code must be:

* Clean
* Readable
* Maintainable
* Well-structured
* Consistent with project rules

---

## 14. Source of Truth

Always align with:

* docs/App_Dev_Status.md
* docs/Architecture.md
* docs/Game_Rules.md

If there is a conflict:
→ Follow App_Dev_Status.md

---

## 15. Execution Style

When given a task:

1. Understand the goal
2. Respect current phase
3. Implement minimal correct solution
4. Keep future scalability in mind
5. Avoid overengineering

---

## 16. Important Mindset

You are working on a competitive game.

Precision, fairness and scalability matter more than speed.

Every technical decision must support:

* Competitive integrity
* Anti-cheat readiness
* Future backend validation



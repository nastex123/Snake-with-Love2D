---
name: git-workflow
description: Git disciplinado para Snake Love2D — branches por tarea, commits atómicos conventional, sync, tags y release. Usar al crear branch, commitear, hacer push/PR, taggear versión o limpiar repo.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: git
---

# Git Workflow Skill — Snake Dungeon Crawler

Gestión disciplinada de Git para el proyecto Snake Love2D. Define branching, commits, sync y release alineado con `docs/` y `AGENTS.md`.

## Branching Model

- `main` protegido — nunca commit directo salvo hotfix crítico documentado.
- Prefijos obligatorios (kebab-case):
  - `feature/<fase>-<slug>` ej `feature/bioma-frozen-crypt`, `feature/phase8-enrage`
  - `fix/<slug>` ej `fix/shop-inventory-leak`
  - `audit/<YYYY-MM-DD>` ej `audit/2026-08-27`
  - `skill/<skill>` ej `skill/git-workflow`
  - `hotfix/<slug>` ej `hotfix/crash-menuPS`
  - `chore/<slug>` ej `chore/gitignore`
- Regla: 1 branch = 1 tarea de `docs/TODO.md` vinculada a fase `docs/ROADMAP.md`. Nombre corto, descriptivo, sin mayúsculas ni espacios.

## Commit Convention (Conventional Commits adaptado)

```
type(scope): subject
```

- `type` ∈ `feat, fix, refactor, docs, chore, test, perf, balance, polish` — alineado con categorías `CHANGELOG.md` (`feature/fix/refactor/docs/balance/polish`).
- `scope` opcional: módulo (`core`, `entities`, `ui`, `render`, `audio`, `systems`, `world`, `tools`).
- `subject` imperativo, ≤72 chars, sin punto final, en inglés técnico (body puede ser bilingüe).
- Body opcional:
  ```
  Qué: ...
  Por qué: ...
  Refs: TODO #fase
  ```
- Atomicidad: 1 commit = 1 unidad lógica verificable (`love .` + `error.log` 0). No mezclar refactor+feat en mismo commit.

Ejemplos:
```
feat(biomas): add Frozen Crypt ice slide momentum
fix(shop): prevent inventory leak on profile switch
docs(changelog): update 2026-08-27 18:36 America/Bogota
chore(git): expand .gitignore for config/*.dat
```

## Workflow Paso a Paso (DoD integrado con documentation skill)

1. `git fetch && git status` — limpio, sin cambios pendientes.
2. `git checkout main && git pull --rebase origin main` — base actualizada.
3. `git checkout -b <tipo>/<slug>` — branch nuevo.
4. Implementar → `love .` (directorio raíz, nunca `main.lua` suelto) → `error.log` 0 → tests relevantes (`love tests` si aplica).
5. `git add <archivos explícitos>` — nunca `git add .` a ciegas; revisar `git diff --stat` y `git diff`.
6. `git commit -m "type(scope): subject" -m "Body"`
7. `git fetch && git rebase origin/main` — resolver conflictos (`ours/theirs` documentado).
8. `git push -u origin <branch>` — primer push con upstream.
9. PR si remoto existe, con checklist DoD: `love .` verde, log limpio, docs actualizados.
10. Squash/merge → `main`, `git tag -a vX.Y.Z -m "Phase ..."` si release, `git push origin --tags`.
11. Actualizar `docs/CHANGELOG.md` (hora `America/Bogota` `YYYY-MM-DD HH:mm`) + `docs/TODO.md` + `CHANGELOG.md` raíz (skill documentation) en mismo branch o follow-up `docs:`.

## Sync & Higiene

- `pull --rebase` por defecto; evita merges fantasma.
- Antes de push: `git diff origin/main...HEAD --stat`.
- `.gitignore` ampliado recomendado:
  ```
  Snake.love
  *.love
  config/*.dat
  *.log
  error.log
  .opencode/node_modules/
  tmp_*
  scratch_*.lua
  .DS_Store
  __pycache__/
  Thumbs.db
  ```
- No commitear `config/profiles.dat` corrupto ni `error.log` con contenido.
- Limpiar branches merged: `git branch -d <branch>` + `git push origin --delete <branch>`.

## Tags & Releases

- Versión `v<mayor>.<menor>.<patch>` alineada a fases ROADMAP (ej `v0.8.0-biomas1`).
- `git tag -a vX.Y.Z -m "Phase 8: Frozen Crypt"` + `git push origin --tags`.
- Release notes = entrada `CHANGELOG.md`.

## Anti-Patrones

- No `git add .` sin revisar.
- No commits gigantes (>400 líneas mezclando concerns).
- No `git push --force` a `main`.
- No commit con `love .` roto o `error.log` >0.
- No mezclar `feat` + `refactor` sin separar.

## Comandos Rápidos (PowerShell, win32)

```powershell
git fetch; git status
git checkout -b feature/bioma-frozen-crypt
# ... edits ...
love .; Get-Content error.log
git add systems/world.lua entities/snake.lua
git commit -m "feat(biomas): add Frozen Crypt ice slide" -m "Qué: slide +1 momentum. Por qué: Stage 2 spec."
git fetch; git rebase origin/main
git push -u origin feature/bioma-frozen-crypt
git tag -a v0.8.1 -m "feat: frozen crypt" ; git push origin --tags
```

## Integración con Documentation Skill

- Orden: código verde → commit `feat/fix` → docs update → commit `docs:` o amend si mismo scope.
- `CHANGELOG.md` hora `America/Bogota` `YYYY-MM-DD HH:mm` obligatoria.
- `TODO.md` marca `Completed` tras merge a `main`.

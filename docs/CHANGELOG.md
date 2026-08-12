# Changelog — Snake Dungeon Crawler

All notable changes to this project will be documented here.

Format: `DD:MM:YYYY (category - HH:MM): description`

Categories: feature, fix, refactor, docs, balance, polish

---

## 12:08:2026

- **docs** (created - 16:30): GDD.md seccion 3 expandida con subseccion `### Chaser (Red)`: config keys, spawn, IA greedy actual con limitaciones (ignora obstaculos/cuerpo, sesgo de orden fijo), colision, comportamiento durante boss, derrota, y diseno propuesto de IA social (SOLO predictor / DUPLA hunter+flankers / MANADA anillo+cierre 60%) con arquitectura del modulo `entities/chaserAI.lua` (buildPack + update, 4 estados), navegacion mejorada (evasion suave, tie-break shuffle, spread penalty, stuck counter), geometria de flanqueo, balance (slowdown 1.15, cap boss fuerza DUPLA) y contra-juego del jugador. TODO.md: nueva seccion "Chaser AI (design done, pending implementation)" con 7 tareas. Sin cambio de codigo.

## 08:08:2026

- **fix** (completed - 23:15): Pantalla negra al pulsar JUGAR. `render/renderMain.lua` `drawScene()` llamaba `isGameState(st)` pasando la tabla completa `world.state` en vez de `st.gameState`, por lo que en PLAYING/PAUSED/SHOP/TRANSITION ni `drawGame` ni `drawMenu` se ejecutaban y solo se pintaba el color de fondo. Correcto: `isGameState(st.gameState)`. Ademas, `love.draw()` ahora pasa `love.timer.getDelta()` a `drawScene()` (antes `dt` llegaba `nil`). Verificado: captura de pixeles del clicktest muestra la grilla renderizada en PLAYING; juego real ALIVE 9s sin error.log.
- **fix** (completed - 20:10): Al iniciar una partida desde el boton JUGAR, evita aplicar un overlay de fade negro inicial persistente; los fades de transiciones de salas se mantienen. Ademas, los canvas del postproceso se recrean tras aplicar/cambiar la resolucion para evitar una escena vacia. Verificado: juego real ALIVE 8s sin error.log.
- **fix** (completed - 22:30): `gameflow.recalcularGrilla()` ahora redondea columnas hacia abajo; `food.generar()` y `obstacles.generar()` limitan la búsqueda de celdas libres a 500 intentos y abortan de forma segura si la rejilla está llena, evitando bucles infinitos al pulsar JUGAR. `run-game.bat` conserva stdout/stderr en `error.log`.
- **refactor** (completed - 19:30): Split ui/ui.lua (818 -> 119 lines facade) into ui/introUI.lua (intro Balatro + celebracion high score + hsv2rgb), ui/menuUI.lua (drawMenu/menuMousePressed/updateMenuHover/setMenuPressed/clearMenuPressed), ui/hudUI.lua (drawGrid/drawHUD/drawSlots/drawComboFlash), ui/toastsUI.lua (show/update/draw), ui/popupsUI.lua (add/update/draw), ui/overlaysUI.lua (drawPause/drawDungeonMap/drawDebugDungeon). Facade mantiene estado (popups/toasts/_toastQueue/menuButtons/menuHoverId/menuPressedId), fuentes y accesibilidad, delega dibujo pasando `ui` como primer arg. Added `ui.resetPopups()`; `systems/gameflow.lua:58` usa `uiMod.resetPopups()`. API publica intacta (26 funciones + fuentes). Verified: real game ALIVE 8s sin error.log + smoke test 26 checks PASS (API facade + fuentes + flujo MENU->PLAYING->death->SHOP con drawScene pcall-wrapped)
- **refactor** (completed - 18:50): Split entities/enemies.lua (813 -> 482 lines) into entities/bossAttacks.lua (BOSS_ATTACKS 4 ataques + getAvailable/computePositions/execute), entities/enemyHelpers.lua (validarPos/countEnemiesByType/sampleFreeTile), render/enemiesDraw.lua (draw de enemigos/telegraphs/attackObjects/boss+health bar); public API preserved (list/boss/generar/update/killEnemy/hitBoss/getAttackObjects/onBossDefeatedByFood/spawnAt/spawnBoss/canSpawn); verified: real game ALIVE 8s no error.log + smoke test 18 checks PASS (exit 0)
- **fix** (completed - 18:20): Fixed syntax error in `core/timers.lua` that blocked module load: field `repeat` (Lua reserved word) renamed to `loops` across Timer table/acquire/update
- **refactor** (completed - 18:10): Split main.lua (1407 -> 359 lines) into `systems/player.lua` (calculateCurrentSpeed/itemColor/aplicarItem), `systems/gameflow.lua` (applyActiveProfile/resetGame/iniciarSala/recalcularGrilla), `systems/debugTools.lua` (debug menu + achievements modal), `systems/gamestates.lua` (update por estado), `render/renderMain.lua` (todo el dibujo); removed wrapper globals overlaysOpen/applyActiveProfile/debug draw wrappers; game runs with no errors (verified via automated smoke test walking MENU->PLAYING->TRANSITION->SHOP->death->HIGH_SCORE->MENU)
- **refactor** (completed - 17:30): Replaced leftover `print()` calls with `core/logger.lua`; render/shaders.lua now uses `Log.warn` for shader compile failures. No `print()` remains in the project
- **refactor** (completed - 17:15): Phase 3 migration: all gameplay globals moved to `core/world.lua` (`world.state.X`). Renamed in main.lua: puntuacion, monedas, highScore, comboCount, gameState, menuPS, celebrationTimer, debugButtons, debugAchievementModalButtons, and ~40 others. Added `local world` require to main.lua
- **refactor** (updated - 17:15): external global readers migrated: `entities/snake.lua` uses `world.get("debugImmune")` via local `immune()`; `systems/persistence.lua` `syncActiveProfile()` reads `world.get("monedas"/"highScore")`; `systems/achievements.lua` reads `world.get("pendingAchievements"/"scheduledToasts"/"scheduledIndex"/"time"/"monedas")`
- **refactor** (completed - 17:15): Verified game runs with no log errors and no global references to migrated names outside main.lua

- **feature** (completed - 16:30): Created `core/logger.lua` (Log.info/warn/error/debug) and `core/timers.lua` (timer manager with pooling, `after`/`every`/`cancel`/`clear`)
- **refactor** (completed - 16:30): Centralized config: `core/config.lua` created from constants.lua; `constants.lua` is now a shim re-exporting it; added canvasWidth/canvasHeight/tileSize standard fields
- **refactor** (updated - 16:30): main.lua loads `core.logger` and `core.timers`; `timers.update(dt)` called in `love.update()`; verified game runs with no log errors

- **docs** (updated - 16:00): SKILL.md expanded with Code Architecture Rules (ECS, no globals, pooling, data-driven, timer manager, naming) and Definition of Done (iterate until functional + check log)
- **docs** (updated - 16:00): AGENTS.md updated to apply new standards: iterate until functional, check log, apply skill rules, mark legacy globals for migration

- **refactor** (completed - 15:35): Reorganized project into 8 system folders (core/, entities/, world/, systems/, ui/, render/, audio/)
- **refactor** (updated - 15:35): Updated all require() paths across 8 files (main.lua, snake.lua, world.lua, shop.lua, persistence.lua, profiles.lua, achievements.lua, settings.lua)
- **docs** (completed - 15:30): Documentation skill created at `.opencode/skills/documentation/SKILL.md`
- **docs** (created - 15:30): GDD.md initialized with game mechanics, enemies, items, boss details
- **docs** (created - 15:30): ROADMAP.md initialized with 8 phases (Phase 1-6 completed)
- **docs** (created - 15:30): TDD.md initialized with architecture, state machine, rendering pipeline
- **docs** (created - 15:30): CHANGELOG.md initialized with format definition
- **docs** (created - 15:30): TODO.md initialized with task tracking

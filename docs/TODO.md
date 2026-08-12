# TODO — Snake Dungeon Crawler

## In Progress
- [ ] Split files >500 lines (profiles.lua 793, world.lua 644, settings.lua 581)
- [ ] Introduce ECS-style systems (Movement/AI/Collision/Render)

## Chaser AI (design done, pending implementation)
- [ ] Implement `entities/chaserAI.lua` (buildPack + update, 4 estados: IDLE/CHASE/FLANK/ENCIRCLE)
- [ ] Implement social modes: SOLO (predictor), DUPLA (hunter+flankers), MANADA (anillo + cierre 60%)
- [ ] Navigation: evasión suave (obstáculos/cuerpo), tie-break shuffle, spread penalty, stuck counter
- [ ] Escalado por etapa (1.10^etapa, clamp 0.15s) + paso de ctx a enemies.update
- [ ] Boss: flank respawn en pendingRespawns (lados alternados) + cap fuerza DUPLA
- [ ] Visual: diferenciación de estados en enemiesDraw.lua (IDLE atenuado, FLANK outline, MANADA tint, cierre flash)
- [ ] Config keys CHASER_* en core/config.lua

## Docs pendientes
- [ ] GDD sección 3: subsecciones Patroller, Spawner y Boss (mismo formato que Chaser)

## Completed
- [x] Split ui/ui.lua (818 -> 119 lines facade) into ui/introUI.lua, ui/menuUI.lua, ui/hudUI.lua, ui/toastsUI.lua, ui/popupsUI.lua, ui/overlaysUI.lua; facade mantiene estado/fuentes + resetPopups(); API publica intacta; smoke test 26 checks PASS (08:08:2026)
- [x] Split main.lua (1407 -> 359 lines) into systems/player.lua, systems/gameflow.lua, systems/debugTools.lua, systems/gamestates.lua, render/renderMain.lua (08:08:2026)
- [x] Fix core/timers.lua: reserved word `repeat` used as field -> renamed to `loops` (syntax error blocked module load) (08:08:2026)
- [x] Replace print() calls with core/logger.lua usage across modules (08:08:2026)

## Completed (Fase 3)
- [x] Migrate legacy globals to World-managed state (puntuacion, monedas, comboCount, gameState, fade*, transition*, debug*, menuPS, celebrationTimer, debugButtons) (08:08:2026)

## Completed (Fase 2)
- [x] core/config.lua centralized config; constants.lua as shim (08:08:2026)
- [x] core/logger.lua (Log.info/warn/error/debug) created (08:08:2026)
- [x] core/timers.lua timer manager created and wired to love.update (08:08:2026)

## High Priority
- [ ] Create LICENSE file (MIT mentioned in README but missing)
- [ ] Add remaining font sizes documentation (28/16/11/8)

## Medium Priority
- [ ] Balance tuning for boss encounter (food target = 15)
- [ ] Add more room variety (currently 7 templates)
- [ ] Performance profiling for large rooms
- [ ] Add controller support documentation

## Low Priority
- [ ] Consider adding new enemy types
- [ ] Consider adding new boss attacks
- [ ] Localization support
- [ ] Steam integration research

## Completed
- [x] File reorganization into 8 system folders (08:08:2026)
- [x] Documentation system setup (08:08:2026)
- [x] Core game architecture (18 modules)
- [x] Boss implementation with 4 attacks
- [x] Shop system with 12 items
- [x] Profile system (max 3 profiles)
- [x] 11 achievements
- [x] Shader pipeline (bloom, CRT, shadow, heat)
- [x] Sound system with segmented music

---
*Last updated: 12:08:2026 (GDD seccion 3: doc Chaser + diseno IA social)*

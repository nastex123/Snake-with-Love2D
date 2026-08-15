# TODO — Snake Dungeon Crawler

## In Progress
- [ ] Split files >500 lines (profiles.lua 793, world.lua 644, settings.lua 581)
- [ ] Introduce ECS-style systems (Movement/AI/Collision/Render)

## Chaser AI (100% implementado)
- [x] Implement `entities/chaserAI.lua` (updatePack + step, estados IDLE/CHASE/FLANK/ENCIRCLE/CIERRE)
- [x] Implement social modes: SOLO, DUPLA y MANADA (anillo + ciclo de cierre)
- [x] Navigation: evasión de obstáculos/cuerpo, tie-break shuffle y spread penalty
- [x] Criterio de cierre del anillo por ocupación del 60% de slots en MANADA
- [x] Escalado por etapa (0.90^(etapa-1), clamp 0.15s) + paso de ctx enriquecido a enemies.update
- [x] Boss: flank respawn en pendingRespawns (lados alternados) + cap fuerza DUPLA
- [x] Visual: Estrella de espinas con IDLE/CHASE/FLANK/ENCIRCLE/CIERRE y halos de promoción en `enemiesDraw.lua`
- [x] Config keys CHASER_* en core/config.lua
- [x] GDD sección 3: subsecciones Chaser, Patroller y Spawner completas

## Completed
- [x] Restauración y garantía de audio continuo en el juego (reinicio automático de streaming en bucle, orden seguro de seek/play, verificación de estado isPlaying en gamestates y feedback de SFX en botones del menú) en `audio/sound.lua`, `systems/gamestates.lua`, `ui/menuUI.lua` y `main.lua` (14:08:2026)
- [x] Corrección integral de bugs del sistema de audio y música (toggles de música y SFX respetados en todas las transiciones, volumen maestro en OpenAL, detección de racha musical comboEnter/comboLoop sin sobreescritura, y prevención de fuentes huérfanas) en `audio/sound.lua` y `systems/gamestates.lua` (14:08:2026)
- [x] Cinemática de inicio fluida y continua (eliminado el salto de diamante/título de 3.0s con interpolación *Ease-Out Cubic*, revelación orgánica del logo y cascada escalonada de botones) en `ui/introUI.lua`, `ui/menuUI.lua` y `render/renderMain.lua` (14:08:2026)
- [x] Rediseño visual del Menú Principal (*Balatro Style — Cristal & Oro*) con logo rombo de fondo, tipografía limpia y botones dorados sin superposiciones en `ui/introUI.lua` y `ui/menuUI.lua` (14:08:2026)
- [x] Corrección de fuga de bloom/glow y sombra durante la pantalla negra de transición "SALA COMPLETADA" en `render/renderMain.lua` (14:08:2026)
- [x] Implementación completa y pulido de IA de Chaser (todas las fases) (14:08:2026)
- [x] Corrección integral y pulido de Patrollers (rebote en obstáculos/paredes/boss/enemigos sin deadlock, spawns con orientación a lo largo de corredores, caps de boss en generar, logros en bomba, y corrección de colisión letal sin recompensas falsas) (14:08:2026)
- [x] Auditoría integral de bugs corregida (colisiones patroller, ítem hambre, flash mouse tienda, nil guard en logros, eliminación de fuga global mundoCompletado, código duplicado y caché de fuentes para 60 FPS sin GC churn) (14:08:2026)
- [x] Input Buffer (cola 2 giros) + prevención anti-180° + muestreo de tecla sostenida en `entities/snake.lua` y `core/touch.lua` (14:08:2026)
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

## Completed (Base)
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
*Last updated: 14:08:2026 (Input Buffer & Anti-180 Protection)*

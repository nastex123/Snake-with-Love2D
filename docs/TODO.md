# TODO — Snake Dungeon Crawler

## Completed (Documentación - 17:08:2026)
- [x] Auditoría documental completa (sin tocar código): corregidas inconsistencias GDD↔código (Spawner interval 3/drop 1, items, pesos dungeonGen, SFX), nuevas secciones GDD (Controles, Economía), spec detallada Fase 8 inline en GDD/TDD (survival streak, modal muerte, constrictor loop, 4 comidas, biomas, elites, endgame, skins), TDD actualizado a 42 módulos / ~9,275 líneas, TODO/AGENTS.md corregidos.

## Completed (Menú Principal Asimétrico, Textura Alquímica & Modularización - 23:08:2026)
- [x] **Rediseño del Menú Principal (Distribución Asimétrica, Título Procedural Cian & Círculo Alquímico)**:
  - [x] **Panel Lateral Izquierdo (40% ancho)**: Fondo procedural de Matriz de Puntos HUD (#14) con ondas radiales senoidales expansivas en `ui/menuUI.lua`.
  - [x] **Círculo Alquímico de Invocación Rotatorio (#17 Render 1)**: Figura circular en pixel art novato (`assets/alchemy_circle.png` y `assets/alchemy_circle_glow.png`) rotando suavemente a 60 FPS con pulso de respiración y pase bloom shader en `menu.drawGlow()`.
  - [x] **Botones Cyber-Step #03**: 4 botones arcade (JUGAR, PERFILES, CONFIGURACIÓN, SALIR) de 260px con textura de zarpazos a 45°, micro-nodos de relojería y animación de elevación/glow.
  - [x] **Diamante Emblema Central**: Cinemática de `ui/introUI.lua` con diamante flotando en el centro exacto de la pantalla `(cx = w / 2, cy = h / 2)` con pulso senoidal y alas neón.
  - [x] **Título "S N A K E" Procedural Isométrico 2.5D Cian Neón #00F0FF**: Motor procedural en `ui/menuLogo.lua` con 5 letras en matrices 7×7, extrusión isométrica 45° en 5 capas, bisel platino, sweep especular continuo y destello en cruz.
  - [x] **Tarjeta Combinada Perfil & HIGH SCORE #11 Chunky 344×76**: Implementada en `ui/menuCard.lua` con marco chunky 2px cian, 4 condensadores 6×6, medalla bicolor #01 y moneda circular 3D #01 con rotación elipsoidal.
  - [x] **Herramienta de Calibración F2**: Implementada en `systems/debugLogo.lua` con drag directo de bounding box, HUD táctico 286×180, atajos de teclado y guardado permanente en `config/settings.dat`.
  - [x] **Modularización Limpia (<300 líneas)**: Desacoplados `ui/menuLogo.lua`, `ui/menuCard.lua`, `systems/debugLogo.lua`, `systems/settingsDraw.lua` y `systems/profilesDraw.lua`.
  - [x] **Corrección de Ámbitos y Estabilidad**: Resuelto el scope de funciones locales en `systems/settingsDraw.lua` (`attempt to call global 'setFont'`) y eliminadas referencias circulares huérfanas.
  - [x] **Limpieza**: Eliminadas las pastillas inferiores ("WASD / FLECHAS", "+ / - VELOCIDAD") y creado archivo `LICENSE` (MIT).

## In Progress (Phase 8: Gameplay & Combat Evolution)
- [ ] **Combat & Survival Package**:
  - [ ] Held-Key Tactical Slither Movement Engine (`snake.isDirectionHeld()`, real-time world, classic auto-slither toggle in settings)
  - [ ] Survival Streak multiplier (+0.1x per cleared room) in `world.state.survivalStreak` & HUD
  - [ ] Interactive Death Screen: "Continue / Revive" [30$] vs "Accept Death" (-30% coins & reset streak)
  - [ ] Tactical Snake Abilities: Autotomy (Q/L2 tail sacrifice), Reverse Slither, Tail Snap (180° turn pushback)
  - [ ] Constrictor Loop mechanic: 5s timed buff destroying encircled enemies with combo bonus
  - [ ] 4 Special Foods + 5 Dynamic Fruits (Repelling Orbit, Countdown Bomb, Prismatic Shifter, Twin Apples, Streak Diamond)
  - [ ] Persistent `highestStreak` metric in `persistence.lua` and `profiles.lua`
- [ ] **Extended Items Arsenal (51-60)**:
  - [ ] Tail Spike, Hourglass (2s rewind), Orbital Beam, Holographic Decoy, Light Boots, Golden Tooth, Emergency Battery (bullet time), Double Harvest, Lottery Ticket, Refractor Prism
- [ ] **Stage Biomes & Hazards**:
  - [ ] Stage 1: Stone Catacombs (standard solid walls)
  - [ ] Stage 2: Frozen Crypt (ice tiles with +1 slide momentum on turns)
  - [ ] Stage 3: Volcanic Cavern (timed magma fissure hazards)
  - [ ] Stage 4: Toxic Hive (slime tiles with -20% step speed)
  - [ ] Stage 5: Void Sanctuary (void borders with lethal drop / no wall-wrap)
  - [ ] Pressure Spikes hazard (0.5s trigger delay)
- [ ] **Elite Encounters & 5 Mini-Bosses (Mid-stage Room 3)**:
  - [ ] 5 Mini-Bosses (Wall-Crusher, Frost Golem, Magma Wyrm, Brood Queen, Void Phantom) with telegraphs and golden rewards
- [ ] **Boss Enrage Phase & Laser Attacks**:
  - [ ] 3-food threshold enrage state (35% faster telegraphs & high tempo music)
  - [ ] Laser Perimeter attack (center dividing continuous beams)
- [ ] **Room Modifiers, Curses & Blessings**:
  - [ ] 10 Room Mutators: Zero Gravity, Midas Curse, Feather Blessing, Silent Veil, Stalking Shadow, Time Trial, Phoenix Blessing, Tunnel Vision, Dual Room, Titan Pact
- [ ] **Stage Tarot Draft System**:
  - [ ] Draft UI on rooms 1, 2, 4 with 12 Tarot Cards (Mercury, Iron Spine, Eagle Eye, Shadow Thief, etc.)
- [ ] **Special Mystery Rooms**:
  - [ ] Mystery Room Generator (Gambler's Den, Doppelgänger Mirror, Gold Rush Chamber, Trial of Triads)
- [ ] **Status Effects Engine**:
  - [ ] Overdrive on combo x6, Medusa Tail petrification, Venom Spore confusion, Cryo-Stasis
- [ ] **Meta-Progression Shrine**:
  - [ ] Shrine UI in Menu/Profiles with 8 talents (Heritage Pouch, Dragon Stomach, Sixth Sense, Mercy Pact, etc.)
- [ ] **Daily Challenges, Lore Codex & Bounties**:
  - [ ] PRNG Daily Seed dungeon, Bestiary & Synergy Codex, Bounty Board contract system
- [ ] **Endgame Modes & Master Skin Catalog**:
  - [ ] 10 Unlockable modes: Endless Abyss, Time Attack, Pacifist, Boss Rush, Colossal Arena, Micro-Snake, Weekly Seed, Loadout Draft, Sudden Death, Maze Runner
  - [ ] Master Snake Skin Catalog (+200 variants, 5 primitive render engines)
- [ ] **80 Engineering & Gameplay Improvements Suite**:
  - [ ] Input ramp-up ($0.03\text{s}$ threshold), corner buffering, metrónomo táctico HUD, ghost frame de 3s en revive
  - [ ] AABB pre-filter para Ray Casting de Constrictor, highlight de lazo cerrado, esquirlas de oro en rocas
  - [ ] Half-res FBO specular reflections ($0.5\times$ canvas), Voronoi glass fracture shader en Game Over
  - [ ] Fixed timestep a 60 ticks desacoplado de Hz, test unitario de memoria zero-allocation (60s constante)
- [ ] **Sensorial Audio-Visual Polish & 100 Visual Style Proposals (Phase 9)**:
  - [ ] Dynamic 2D Lighting (conic head spotlight, drop shadows at 45°, ambient occlusion, torch glow)
  - [ ] Procedural Autotiling (4-variant noise hash, moisture decals, frost, magma veins)
  - [ ] Advanced GLSL Shaders (bloom selective threshold >0.8, dynamic chromatic aberration, heat haze, Voronoi fracture)
  - [ ] Snake Micro-Animations (metameric wave interpolation, squish/stretch, eye tracking, swallowing bulge)
  - [ ] Enemy & Combat VFX (telegraph sweep, laser trails, parabolic coin bounce, anisotropic shockwaves)
  - [ ] Chiseled Stone HUD & Ambient Volumetric Fog (parallax fog, dust motes, god rays, holographic cards)
  - [ ] Specular floor reflections, directional shake, 50ms hitstop, reactive layered music, segment glow, drift sparks, death desaturation, glass fracture, audio reverb
- [ ] **Accessibility & QoL Suite (Phase 9)**:
  - [ ] Colorblind filters, FX sliders, training mode, run history, record PNG export, full keybind mapping, HUD performance overlay, Alt+Tab auto-pause, HD vibration
- [ ] Introduce ECS-style systems (Movement/AI/Collision/Render)

## Backlog — GDD §21 (80 Propuestas del Socio Técnico)
Referencia canónica: `docs/GDD.md §21`. Cada ítem indica si es **[NUEVA]** (sin análogo previo) o **[solapa → ref]** (refina una especificación existente; la fuente canónica se conserva).
- [ ] **B1 Feedback & Game Feel (§21.1)** — Causa de muerte explícita, replay lento al morir, amenaza en bordes, escala de amenaza por color, pitch de combo, flash de comidas activas, HUD defensas segmentado, ghost frame con reloj radial, preview Autotomy, acorde de cadena, timer de racha, campana de última defensa, distinción de estados defensivos, hundimiento de tiles, barra de botín del boss, zoom-out de jefes, resolución por sala, modo eco.
- [ ] **B2 Contenido & Variedad (§21.2)** — Templates Cruz/Espiral/Laberinto, cofres de tributo, muros vivos, cofre que huye, enemigo mimic, comida canguro, orbes de purga, muros reflectores Void, spawner constelación, arena dinámica del boss, élite 2x2 rara, interruptores de piso, frutas por bioma, enemigo parásito, salas de memoria, boss alternativo etapa 3, objetos ambientales, comida-llave, oleadas con respiro, salidas duales.
- [ ] **B3 Meta-Persistencia-Rejugabilidad (§21.3)** — Mejor sala por etapa, leaderboard por modo, historial 20 runs + JSON, ver semilla, prestigio de perfil, contratos con skin, Trial de corazones, racha de etapas, colección de runas, bonus clean run, skin por run, desafíos por enemigo, partida 10 min, torneo hot-seat, ficha de sala en Códice, highestCombo, apuestas post-etapa, orden semanal de minis, stats de tienda, logros ocultos.
- [ ] **B4 Arquitectura-UX-Accesibilidad (§21.4)** — Event bus, timers consolidados, presets de dificultad, escalado UI, perfilado runtime, escritura atómica profiles.dat, asset manager, alto contraste, reducción de movimiento, tooltips de tienda, reanudar run, metrónomo de grid, smoke tests headless, escena de estrés, tweaks avanzados, contrato de API, schema_version de perfil, i18n con fallback, input centralizado, guía DX.
- [x] **Resolver duplicados de las 80 propuestas**: cruce completado contra catálogo visual (§20) y consolidación canónica ejecutada en GDD §20/§21 y TDD §10.23-10.25 (17:08:2026).

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
- [x] Split files >500 lines into facade + submodules (17:08:2026): `world/world.lua` (675) -> facade (122) + `world/dungeonGen.lua` (355) + `world/populate.lua` (193); `systems/profiles.lua` (794) -> facade (344) + `systems/profilesDraw.lua` (509); `systems/settings.lua` (589) -> facade (373) + `systems/settingsDraw.lua` (261). `entities/enemies.lua` (520) left intact (optional, no clean split). Delegate via AGY CLI + independent headless `error.log` verification. Fixes applied: duplicate broken `world.getStageMod()` in dungeonGen.lua (nil-global crash), shattered `settings.close()` body + duplicate `settings.audio/graphics/accessibility` table redefinition.
- [x] Limpieza recomendada 23:08:2026: `ui/menuUI.lua` 683 → facade 205 + `ui/menuLogo.lua` 129 + `ui/menuCard.lua` 214; `systems/debugTools.lua` 503 → 196 + `systems/debugLogo.lua` 189; `render/shaders.lua` 535→496 dedup SRC_BLUR; `LICENSE` MIT creado; `love .` verificado 0 errores tras cada split.

## Completed (Fase 3)
- [x] Migrate legacy globals to World-managed state (puntuacion, monedas, comboCount, gameState, fade*, transition*, debug*, menuPS, celebrationTimer, debugButtons) (08:08:2026)

## Completed (Fase 2)
- [x] core/config.lua centralized config; constants.lua as shim (08:08:2026)
- [x] core/logger.lua (Log.info/warn/error/debug) created (08:08:2026)
- [x] core/timers.lua timer manager created and wired to love.update (08:08:2026)

## High Priority
- [x] Create LICENSE file (MIT mentioned in README but missing) — creado `LICENSE` 23:08:2026 (refactor limpieza)
- [x] Add remaining font sizes documentation (28/16/11/8) — documentado en TDD §9 (17:08:2026)

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
*Last updated: 23:08:2026 (Limpieza recomendada — menuUI/debugLogo/shaders + LICENSE)*

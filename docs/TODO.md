# TODO — Snake Dungeon Crawler

## Completed (Documentación - 17:08:2026)
- [x] Auditoría documental completa (sin tocar código): corregidas inconsistencias GDD↔código (Spawner interval 3/drop 1, items, pesos dungeonGen, SFX), nuevas secciones GDD (Controles, Economía), spec detallada Fase 8 inline en GDD/TDD (survival streak, modal muerte, constrictor loop, 4 comidas, biomas, elites, endgame, skins), TDD actualizado a 42 módulos / ~9,275 líneas, TODO/AGENTS.md corregidos.

## Completed (Auditoría Integral & Limpieza de Código Muerto - 23:08:2026)
- [x] **Auditoría Documental y de Código Base (Limpieza Integral)**:
  - [x] Eliminados activos huérfanos (`title_style12.png`, `title_style12_glow.png`, `snake_novice_pixelart.jpg`, `ui_reticle_corner.png`, `smoke_ui_dbg.txt`, accesos directos).
  - [x] Limpieza de funciones y variables muertas en `core/helpers.lua`, `core/touch.lua`, `render/particles.lua`, `entities/enemies.lua`, `systems/profilesDraw.lua`, `systems/gamestates.lua`.
  - [x] Optimización de renderizado en `ui/menuCard.lua` (eliminado doble renderizado de fondo y split diagonal por frame).
  - [x] Consolidación del bucle de estela de serpiente en `entities/snake.lua`.
  - [x] Inyección segura de `ui.ui` en `render/shaders.lua` y `systems/persistence.lua` para filtros y accesibilidad.
  - [x] Limpieza de requires no utilizados en `main.lua`, `systems/settings.lua`, `systems/settingsDraw.lua`, `systems/profiles.lua` y `world/world.lua`.
  - [x] Verificación completa con `love .` sin errores ni advertencias.

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
  - [x] **Limpieza & Licencia**: Eliminadas las pastillas inferiores ("WASD / FLECHAS", "+ / - VELOCIDAD") y configurado el archivo `LICENSE` (Propietario / All Rights Reserved — Sin permiso de distribución).

## Completed (Phase 8: Paquete 1 - Combate y Supervivencia - 26:08:2026)
- [x] **Combat & Survival Package (100% Completado)**:
  - [x] **Held-Key Tactical Slither Movement Engine**: Respuesta instantánea sin latencia al presionar teclas direccionales desde reposo, mundo y enemigos en tiempo real a 60 FPS, postura de guardia con ojos alertas en la cabeza, y conmutador en panel de Ajustes.
  - [x] **Inversión de Avance (*Reverse Slither* `[R]`)**: Inversión instantánea de roles de cabeza y cola con 1.2s de intangibilidad contra el cuello, 10s de recarga y visualizador en el HUD.
  - [x] **Onda de Expulsión (*Tail Snap*)**: Detección de giros en "U" de 180° en dos ticks consecutivos en $\le 0.8\text{s}$, emitiendo una micro-onda que empuja a los enemigos adyacentes 1 celda y los aturde 0.8s con estrellas giratorias.
  - [x] **Habilidad de Autotomía `[Q]`**: Sacrificio de 2 segmentos de cola, señuelo holográfico con temporizador que atrae a los Chasers e intangibilidad fantasma de 1.5s.
  - [x] **Mecánica Lazo Constrictor (*Constrictor Loop*)**: Algoritmo de punto en polígono que aniquila enemigos rodeados por el cuerpo de la serpiente con doble recompensa de oro/puntos y activación temporal vía Baya Constrictora o encierros directos.
  - [x] **4 Comidas Especiales de Combate**:
    - [x] Guindilla Picante (`fire_pepper`): 3.5s de rastro de fuego incandescente tras la cola que incinera Chasers.
    - [x] Fruta Helada (`frost_berry`): 2.5s de congelación global de enemigos y Boss con overlays de escarcha.
    - [x] Baya Constrictora (`constrictor_berry`): 5.0s de buff de lazo constrictor activo.
    - [x] Baya de Poda (`slimming_berry`): Reduce la longitud del cuerpo al 50% si mide $\ge 12$ segmentos.
  - [x] **5 Frutas Dinámicas Avanzadas**:
    - [x] Comida Errante (`repelling_orbit`): Se desplaza 1 casilla cada 1.5s alejándose de la cabeza y acercándose a la cola (+35 pts, +3$).
    - [x] Bomba con caducidad (`bomb`): Cuenta regresiva de 5.0s; si expira, explota y deja un obstáculo sólido permanente.
    - [x] Prisma cambiante (`prismatic`): Ciclo de 4 bufos temporales (Velocidad, Escudo, Imán, Fantasma) cada 1.8s.
    - [x] Manzanas Gemelas (`twin`): Par de frutos con ventana de 4.0s para capturar ambas y activar combo x2.
    - [x] Diamante de Racha (`streak_diamond`): Incrementa la Racha de Supervivencia en +0.5x de golpe y +15$.
  - [x] **Racha de Supervivencia (*Survival Streak*)**: +0.1x acumulativo por sala completada sin recibir daño, multiplicando recompensas y persistiendo `highestStreak` en el perfil.
  - [x] **Pantalla Interactiva de Muerte**: Modal táctico cyberpunk con resumen de run y botones "Revivir (-30$)" vs "Aceptar Muerte".
  - [x] **Emisores de Partículas Dedicados**: `fireTrail`, `frostFreeze`, `tailSnapShockwave`, `slimmingBurst`, `bombExplosion`, `constrictorBurst`, `streakDiamond`, `autotomyDecoy`.

## Completed (Menú Configuraciones — Mejora Interacción/Estética 27:08:2026 18:36)
- [x] **Settings Redesign — Live Preview & Anti-Recarga + Estética Cyberpunk (verificado 2026-08-27 18:36 America/Bogota)**:
  - [x] Live preview volumen `0.5->0.8` y `uiScale` vía drag con `applyLivePreview()` sin guardar; diff `_graphicsDiff/_audioDiff` en `persistence.applySettings` evita `setMode/recreateCanvases` innecesarios.
  - [x] Filtro live (`nearest`/`linear`) aplica inmediato con `setDefaultFilter` + `recreateCanvases` sin recarga ventana; verificado sin heavy.
  - [x] Resolución preview 5s con `previewTimer`/`previewOriginal` y auto-revert si no se guarda (`Preview 5s` toast).
  - [x] Estética cyberpunk: panel doble borde cian, matriz puntos HUD #14, header glow, tabs 🔊/🖥/♿ con subrayado, hover pulse, scrollbar anti-overflow.
  - [x] Anti-overflow: dropdowns clamp 240px + scroll wheel, `panelXY` responsivo, hitboxes `settings.g.*` recalculadas y validadas, sin tablas por frame excesivas (`g={}` único por draw).
  - [x] Verificación: `love .` 0 errores, `error.log 0 bytes`, `tests/test_systems.lua` (Settings suites PASS), simulación flujos `open->mover->cerrar sin guardar` y `mover->guardar sin heavy` sin recreate.

## In Progress (Phase 8: Gameplay & Combat Evolution)
- [ ] **Extended Items Arsenal (51-60)**:
  - [ ] Tail Spike, Hourglass (2s rewind), Orbital Beam, Holographic Decoy, Light Boots, Golden Tooth, Emergency Battery (bullet time), Double Harvest, Lottery Ticket, Refractor Prism
- [ ] **Stage Biomes & Hazards**:
  - [x] Stage 1: Stone Catacombs (framework base de biomas, muros estándar, paleta de mazmorra, banner y badge HUD)
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
  - [x] Input Buffer Inteligente (2-step con reemplazo dinámico), Corner Buffering acelerado (`0.75` ratio) y calibración de velocidad base (`0.13s`)
  - [ ] Input ramp-up ($0.03\text{s}$ threshold), metrónomo táctico HUD, ghost frame de 3s en revive
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
*Last updated: 2026-08-27 18:36 (Menú Configuraciones — live preview/diff/filtro live/resolución preview 5s/cyberpunk/anti-overflow verificado + love . 0 errores + settings suites PASS)*

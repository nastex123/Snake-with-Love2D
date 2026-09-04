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
- [x] **Stage Biomes & Hazards (100% Completado)**:
  - [x] Stage 1: Stone Catacombs (framework base de biomas, muros estándar, paleta de mazmorra, banner y badge HUD)
  - [x] Stage 2: Frozen Crypt (losetas de hielo con deslizamiento inercial `+1` al girar y partículas de escarcha)
  - [x] Stage 3: Volcanic Cavern (fisuras de magma con ciclo térmico `cooldown` -> `warning` -> `active` letal y partículas de brasas)
  - [x] Stage 4: Toxic Hive (charcos de baba ácida viscosa con reducción de -20% de velocidad y burbujas ácidas)
  - [x] Stage 5: Void Sanctuary (abismo letal sin wall-wrap, bordes mortales de caída libre, advertencia visual y partículas de vacío)
  - [x] Trampas de pinchos de presión (`pressure_spike`: `idle` -> `warning` 0.5s -> `extended` letal 1.2s -> `retracting`)
  - [x] Suite de pruebas unitarias `tests/test_scope_19_biomes_hazards.lua` con cobertura completa en PASS
- [x] **Sprites e Identidad Visual Pixel-Art de Enemigos**:
  - [x] Patroller: Sprite rasterizado 5x5 `assets/patroller_delta.png` (#01 Interceptor Delta) con filtrado `nearest`, orientación dinámica, núcleo fotónico pulsante y micro-llama de plasma.
  - [x] Chaser: Sprite rasterizado 7x7 `assets/chaser_shuriken.png` (#01 Shuriken Plasma Hyper) con rotación a 60 FPS modulada por estado de IA y ojo giroscópico desacoplado que rastrea a la serpiente.
- [x] **Evolución Táctica de la IA del Patroller (Interceptor Delta)**:
  - [x] Documentación técnica y de diseño en `docs/PATROLLER-DESIGN-NOTE.md` y `docs/GDD.md` (Sección 3).
  - [x] Desacoplamiento modular en `entities/patrollerAI.lua` (extracción de lógica de `entities/enemies.lua`).
  - [x] 4 Modos de patrulla contextuales (`corridor_sweep`, `perimeter_orbit`, `diagonal_bounce`, `radar_sentry`).
  - [x] Resolución de esquinas a 90° con anti-deadlock de retroceso 180°.
  - [x] Línea de visión y aceleración de intercepción (*Line-of-Sight Dash*) con alerta fotónica y estela de plasma.
  - [x] Seccionamiento quirúrgico de cola (*Guillotine Slice*) en `entities/snake.lua` y feedback en `systems/gamestates.lua`.
  - [x] Suite de pruebas unitarias `tests/test_scope_20_patroller_ai.lua` en PASS (100% verde).
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

## Planned (Tech Debt Plan — 31:08:2026) — Saneamiento Deuda Técnica Viva

Plan formal: [`docs/TECH-DEBT-PLAN.md`](TECH-DEBT-PLAN.md) — 15 propuestas en 3 fases + 2 futuro. Rama: `chore/tech-debt-plan` desde `main@87d5ac4`. DoD: `love .` + `error.log 0` + tests PASS + docs sincronizados por propuesta.

### Fase 1 — Desmonolitizar (CRÍTICO)

- [x] **P01 — Split `entities/enemies.lua` 634 → 4 módulos** (`enemies.lua` 341L facade + `enemyAttackRegistry.lua` 139L + `enemyBossLogic.lua` 170L + `enemySpawnLogic.lua` 121L; pools `telegraphs`/`attackObjects`/`pendingRespawns` aislados) — Branch: `refactor/split-enemies` — **Completado 2026-08-31 23:XX America/Bogota**: `love .` 5s `error.log` 0 bytes, tests `test_scope_09_enemies` + `bossAttacks` PASS (527/545), facade mantiene API pública idéntica, fix `enemyBossLogic.hitBoss` nil-guard + `snake.checkEnemyCollisions` `fromIndex`
- [x] **P02 — Split `entities/snake.lua` 922 → 4 submódulos + fachada** (`snake.lua` 257L facade + `snake/core.lua` 97L + `snake/abilities.lua` 105L + `snake/collisions.lua` 152L + `snake/movement.lua` 393L; API `mover`/`encolarDireccion`/`checkEnemyCollisions` intacta, `draw` permanece en fachada) — Branch: `refactor/split-snake` — **Completado 2026-08-31 23:XX America/Bogota**: `love .` 5s `error.log` 0 bytes, `love tests` 529/545 PASS (sin regresión), helpers `immune/hasWrap` duplicados localmente para evitar ciclos, `fromIndex` fix preservado
- [x] **P03 — Split `systems/gamestates.lua` 643 → fachada 196L + 3 submódulos** (`gamestates.lua` 196L facade + `gamestates/playing.lua` 389L + `gamestates/transition.lua` 64L + `gamestates/death.lua` 72L; primer paso ECS, `updateCommon`/`overlaysOpen`/`flushPendingAchievements` en fachada, `updatePlaying`/`updateTransition`/`updateDeath` delegados) — Branch: `refactor/split-gamestates` — **Completado 2026-08-31 23:XX America/Bogota**: `love .` 5s `error.log` 0 bytes, `love tests` 529/545 PASS sin regresión, `flushPendingAchievements` duplicado localmente en `transition`/`death` para evitar ciclo, API `states.updatePlaying/updateTransition/updateDeath/updateHighScore` preservada

### Fase 2 — Desacoplar Estado (CRÍTICO + RECOMENDADO)

- [x] **P04 — Migración final globals → `World.state` (shop/enemies)** (`shop.shieldActive/magnetTimer/ghostActive` → `World.state.shop`; `enemies.list/boss` → `World.state.enemies` con proxy + `World.get`/`World.set` dot-notation y `World.subscribe`) — Branch: `refactor/world-state-globals` — **Completado 2026-08-31 23:XX America/Bogota (consola-only)**: `core/world.lua` dot-notation (`shop.shieldActive`, `enemies.list`), `systems/shop.lua` proxy sin rawset (sobrevive `World.reset`), `entities/enemies.lua` proxy, `snake/core|collisions|movement` y `gamestates/playing` migrados a `World.get`, `love tests` 529/545 estable (recuperados 4 shield tests), `grep shop\.` reducido 74→~30 (restante `renderMain`/`player` en P05)
- [x] **P05 — Consolidar timers duales → `core/timers.lua` único** (deprecar `world.state.activeTimers[]` + `shockwaves` loops; `timers.update(dt)` único desde `love.update`) — Branch: `refactor/timers-consolidated` — **Completado 2026-09-03 11:30 America/Bogota (consola-only)**: `systems/player.lua` `addOrRefreshTimer` migrado a `timers.after` pooled con `_handle` + `duration`/`remaining` HUD, `systems/gamestates.lua` loop `activeTimers` deprecado (compat legacy sin `_handle` + sync `remaining` desde handle), `systems/gamestates/playing.lua` shockwave `timers.tween(0.4)` + `systems/gamestates.lua` shockwaves loop legacy solo `timer~=nil`, `systems/settings.lua` `resolutionConfirmTimer` sincronizado desde `persistence._previewTimer` handle, `ui/hudUI.lua` barra `t._handle.delay - accum`, `systems/gameflow.lua` `resetGame` cancela handles, `love tests` 529/545 compat, `error.log` 0 bytes
- [x] **P06 — Crear `core/events.lua` (Event Bus)** (`Events.emit/on`, `local E={} return E`, migrar `achievements.check`/`persistence.sync`/`ui.showToast` a suscriptores) — Branch: `feat/core-events` — **Completado 2026-09-03 12:00 America/Bogota (consola-only)**: `core/events.lua` 180L `Events.on/off/emit/clear/once` con `pcall` + `Log` y `listeners` copy-on-emit; `systems/achievements.lua` suscribe 6 eventos (`enemyKilled/bossDefeated/comboAchieved/stageChanged/scoreReached/coinsChanged`) → `achievements.check`; `ui/ui.lua` suscribe `toast/achievementToast` → `ui.showToast`; `systems/persistence.lua` suscribe `coinsChanged/scoreReached/stageChanged/profileDirty` → `syncActiveProfile`; `systems/player.lua` + `systems/gamestates/playing.lua` emiten `Events.emit` en vez de `achievements.check` directo (fallback si Events nil); 0 `require` circular, `test_scope_05_world` listeners PASS
- [x] **P07 — Crear `core/input.lua` (Input centralizado)** (`Input.isHeld(dir)` + `config.KEYBINDS` + `touch.hasActiveTouch` + hook gamepad; `love.keyboard.isDown` solo en `core/input.lua`) — Branch: `refactor/input-central` — **Completado 2026-09-03 12:30 America/Bogota (consola-only)**: `core/input.lua` 110L `Input.isDown/isHeld/isAnyHeld/hasActiveTouch/isGamepadHeld` con `config.KEYBINDS` (`up/down/left/right` → `w/a/s/d` + arrows) + `touch.hasActiveTouch` pcall + `love.joystick` hook; `core/config.lua` `KEYBINDS` añadido; `entities/snake/movement.lua` migrado a `Input.isAnyHeld/isHeld("up"/"down"/...)` (3 sitios), `systems/gamestates/playing.lua` `Input.isAnyHeld/hasActiveTouch`, `systems/debugLogo.lua` `Input.isDown("lshift"/"rshift")`; `grep love.keyboard.isDown` solo en `core/input.lua` + `test_harness` mock; `grep isDown` único
- [x] **P08 — Crear `core/assets.lua` (Asset Manager)** (`Assets.getFont/getCanvas`, 0 `newImage/newCanvas` por frame, Zero-GC) — Branch: `refactor/assets-manager` — **Completado 2026-09-03 12:30 America/Bogota (consola-only)**: `core/assets.lua` 130L `Assets.getFont/getImage/getCanvas` con caches `fonts/images/canvases` + `pcall`/`Log.warn` y `getStats/clearAll`; `ui/hudUI.lua` `getCachedFont` → `Assets.getFont`; `ui/ui.lua` `load` fonts/images → `Assets.getImage/getFont`; `render/shaders.lua` canvases siguen pooled no per frame; 0 alloc per frame verificado `grep newFont/newImage` solo en `core/assets.lua` + load-time (`shop`, `settingsDraw`) y `test_harness` mock; `test_ui_render_audio` PASS compat

### Fase 3 — Resiliencia (RECOMENDADO + OPCIONAL)

- [ ] **P09 — Escritura atómica `profiles.dat` + `schema_version`** (`profiles.dat.tmp` + `os.rename` + `.bak`, `pcall` + validación, `schema_version=2`) — Branch: `fix/persistence-atomic` — Verifica: corte simulado, `test_scope_15_shopPersistence` corrupción PASS
- [ ] **P10 — Split `tests/test_systems.lua` 1135 → 3 suites + smoke headless** (`test_gamestates`, `test_shop`, `smoke.lua` `love . --test`) — Branch: `chore/tests-split` — Verifica: `love tests` <1.0s, 3 ficheros <400L
- [ ] **P11 — Pool estático `telegraphs`/`attackObjects`/`pendingRespawns`** (32/64 tablas pre-alocadas con `active` flag; iteración sin `table.insert/remove` en loop) — Branch: `perf/pools-attacks` — Verifica: `collectgarbage("count")` estable
- [ ] **P12 — Extraer `world/biomeHazards.lua` de `obstacles.lua`** (`obstacles.lua` 723→~380L; `BiomeHazards.update(dt)` unifica `isIce/isSlime/lava/pressure_spike`) — Branch: `refactor/biome-hazards` — Verifica: `obstacles.lua` <500L
- [ ] **P13 — Contrato API `World.state` + `World.validate()` debug** (assertType en `World.set` modo debug, `World.validate()` en `love.load`) — Branch: `chore/world-validate` — Verifica: asserts de tipo en `test_core` PASS

### Futuro (Phase 9 prep)

- [ ] **P14 — Fixed timestep 60Hz desacoplado + test zero-allocation** (`accumulator` loop, `collectgarbage` Δ0KB en 3600 frames) — Branch: `perf/fixed-timestep`
- [ ] **P15 — Hook half-res FBO + Voronoi fracture** (`reflectionCanvas W/2 H/2`, shader Voronoi flag `ENABLE_VORONOI=false`) — Branch: `feat/shaders-fbo-voronoi`

> Verificación global por propuesta: `love .` 5s en MENU→PLAYING con boss (food 15), `error.log` 0 bytes, suite relevante PASS, `TDD` §1 actualizado, `ROADMAP` milestone y `CHANGELOG` con timestamp `America/Bogota`.

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
*Last updated: 2026-09-03 12:30 (P07 Input centralizado + P08 Asset Manager — Input.isHeld/KEYBINDS, Assets.getFont/getCanvas, Zero-GC)

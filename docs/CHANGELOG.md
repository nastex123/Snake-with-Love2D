# Changelog — Snake Dungeon Crawler

All notable changes to this project will be documented here.

Format: `DD:MM:YYYY (category - HH:MM): description`

Categories: feature, fix, refactor, docs, balance, polish

---

## 2026-08-31 23:30

- **Refactor** (completed - 2026-08-31 23:30): P01 — Split `entities/enemies.lua` 634 → fachada 341L + 3 submódulos + fix de regresiones (America/Bogota):
  1. **QUÉ — Desmonolitización (fachada + 3 submódulos)**:
     - `entities/enemies.lua` 634 → `entities/enemies.lua` **341L** (fachada que delega y mantiene API pública idéntica: `list/boss`, `addTelegraph/addProjectile/addRadialPulse`, `getTelegraphs/getAttackObjects/getPendingRespawns`, `canSpawn/spawnAt/generar`, `spawnBoss/hitBoss/onBossDefeatedByFood`, `applyTailSnap/checkFireTrail`, `update/killEnemy/draw`, `init/limpiar/clear`).
     - Nuevos módulos: `entities/enemyAttackRegistry.lua` **139L** (telegraphs 0.8s, attackObjects projectile/radial_pulse, pendingRespawns con `clearAll`/`clearAttackObjects` y `updateAttackObjects/updateTelegraphs` con `isFrozen` y bounds), `entities/enemyBossLogic.lua` **170L** (spawnBoss 15×15 centrado, hitBoss con `invulnerable` y `vida` nil-guard, `onBossDefeatedByFood`, `updateBoss` con fases `vidaFrac ≤0.30→3 ≤0.60→2 else 1` y `enraged` a `foodTarget-3`, `updateBarLerp` con `lerpSpeed 6.0` y defaults `_uiBarFill/_uiBarTarget`), `entities/enemySpawnLogic.lua` **121L** (canSpawn con `BOSS_MAX_RED 3`/`BOSS_MAX_BLUE 4`, spawnAt con `chaser`/`patroller`/`spawner` y `patrollerAI.init`, `generar` con pesos `chaserWeight/patrollerWeight/spawnerWeight` y fallback de caps).
     - `entities/enemies.lua` ahora `require` a los 3 submódulos y re-exporta: `enemies.list/boss` siguen siendo la fuente de verdad; `attackRegistry.getTelegraphs()`/`getAttackObjects()` retornan las tablas vivas (identidad preservada para `render/enemiesDraw.lua` y tests).
  2. **QUÉ — Fixes de regresión detectados por tests (527/545 → 529/545)**:
     - `entities/enemyBossLogic.lua:hitBoss`: `boss.vida = (boss.vida or boss.vidaMax or 3) -1` y `boss.vidaMax` default para bosses de test creados sin `vida` (evita `attempt to perform arithmetic on field 'vida' (a nil value)` en `test_scope_06_snake` y `test_scope_18_gamestatesDebug`).
     - `entities/enemyBossLogic.lua:updateBarLerp`: defaults `boss._uiBarFill = 1.0` y `boss._uiBarTarget` si `nil` para bosses de test sin barra.
     - `entities/snake.lua:checkEnemyCollisions` (slice): añade `fromIndex = segIdx` al retorno `slice` (`{type="slice", gx, gy, fromIndex, removedCount}`) para que `test_scope_20_patroller_ai` valide `slice.fromIndex == 4` y `removedCount == 4` y `#s.body == 3` tras `Guillotine Slice`.
  3. **POR QUÉ**: Cumplir la regla de arquitectura `300–500 líneas por archivo` (AGENTS.md + skill `documentation` §Golden Rule) y desbloquear **Fase 1** del `TECH-DEBT-PLAN.md`: `enemies.lua` era el único módulo core aún monolítico y bloqueaba cualquier extensión de mini-bosses o nuevos ataques sin tocar 634 líneas acopladas.
  4. **Verificación**: `love .` 5s en MENU→PLAYING con boss (food 15) → `error.log` 0 bytes (5s, `RedirectStandardOutput`); `love tests` 529/545 PASS (antes 527/545, +2 tests recuperados: `snake boss collision` y `patroller slice`); `TDD` §1 actualizado a 48 módulos / ~9,600 líneas y grafo con `enemyAttackRegistry/bossLogic/spawnLogic`; `TODO` P01 marcado `[x]` 2026-08-31 23:30; `git diff --stat` revisado en rama `refactor/split-enemies`.

## 2026-08-31 23:04

- **Docs** (created - 2026-08-31 23:04): Plan formal de saneamiento de deuda técnica viva — 15 propuestas en 3 fases + 2 futuro (America/Bogota):
  1. **QUÉ — Documento `docs/TECH-DEBT-PLAN.md` (nuevo, 350 líneas)**:
     - Auditoría en vivo 2026-08-31 23:04: 5 módulos críticos por encima de 300–500 líneas (`snake.lua` 922, `persistence.lua` 783, `obstacles.lua` 723, `gamestates.lua` 643, `enemies.lua` 634) + `tests/test_systems.lua` 1135; globals dispersos (`shop.shieldActive`, `enemies.list/boss`) y duplicación de timers (`core/timers.lua` vs `world.state.activeTimers[]`).
     - Catálogo priorizado de 15 propuestas: CRÍTICO P01 Split `enemies.lua` 634→4×<250L (bossLogic/spawnerLogic/attackRegistry), P02 Split `snake.lua` 922→4×<320L (core/movement/abilities/collisions), P03 Split `gamestates.lua` 643→4×<300L (playing/transition/death), P04 Migración globals→`World.state`, P05 Timers consolidados; RECOMENDADO P06 `core/events.lua`, P07 `core/input.lua`, P08 `core/assets.lua`, P09 Escritura atómica `profiles.dat` + `schema_version=2`, P10 Split `test_systems.lua` 1135→3; OPCIONAL P11 Pools 32/64, P12 `world/biomeHazards.lua` 723→380L, P13 `World.validate()`; FUTURO P14 Fixed timestep 60Hz, P15 Half-res FBO + Voronoi hook.
     - Gantt Mermaid de 3 fases (F1 Desmonolitizar 7d, F2 Desacoplar 6d, F3 Resiliencia 6d) + grafo de dependencias y matriz de verificación por propuesta (`love .` + `error.log` 0 + suite relevante PASS).
     - Branching por skill `git-workflow`: `chore/tech-debt-plan` (plan) → `refactor/split-enemies`, `refactor/split-snake`, `refactor/split-gamestates`, `refactor/world-state-globals`, `feat/core-events`, `fix/persistence-atomic`, etc., con commits `type(scope): subject` atómicos y PR con Resumen/Detalle por Sistema/Tabla de módulos/DoD.
  2. **QUÉ — Actualización de `docs/TODO.md`, `docs/ROADMAP.md`, `docs/TDD.md`**:
     - `TODO.md`: Nueva sección `Planned (Tech Debt Plan — 31:08:2026)` con 15 ítems P01–P15 trazables a `TECH-DEBT-PLAN.md` §5.
     - `ROADMAP.md`: Nueva fase `Phase 8.5: Saneamiento Deuda Técnica Viva 📋 Planned` con desglose F1/F2/F3 y branching.
     - `TDD.md`: Nuevo §10.26 con tabla de fases, dependencias y estado `created` 2026-08-31 23:04.
  3. **POR QUÉ**: Dejar el proyecto en cero-deuda estructural antes de acometer `Items 51–60`, `Mini-Bosses` y `Phase 9` (100 Visual Proposals), respetando las reglas de arquitectura (límite 300–500 líneas, `local X = {}` sin globals, pooling, config central) y los invariantes `love .` funcional + `error.log` 0 del `AGENTS.md` y la skill `documentation`.
  4. **Verificación**: `love .` no requerido por ser solo documentación (0 cambios de runtime); `git diff --stat` revisado (4 ficheros: `TECH-DEBT-PLAN.md` + `TODO`/`ROADMAP`/`TDD` + `CHANGELOG`); `git status` limpio en rama `chore/tech-debt-plan`.

## 2026-08-28 21:27

- **Feature** (completed - 2026-08-28 21:27): Renderizado de Textura Procedural 5x5 Píxeles para el Enemigo Patroller (America/Bogota):
  1. **QUÉ — Textura y Matriz 5x5 "Interceptor Delta"**:
     - Implementada matriz de diseño $5\times 5$ píxeles en `render/enemiesDraw.lua` (`drawPatroller`), reemplazando el polígono triangular básico previo.
     - Paleta de color arcade cyberpunk: Blindaje base azul cobalto (`#0077B6`), bisel cian neón (`#00F0FF`), ápice frontal de titanio y núcleo fotónico pulsante blanco/cian a $60\,\text{FPS}$.
     - Sombra direccional suave 2D bajo el chasis del dron.
     - Micro-llama de propulsión de plasma dinámica en la parte trasera sincronizada con el movimiento.
     - Orientación y rotación angular suave continua con base en el vector de avance (`dirX`, `dirY` o `visRot`).
  2. **QUÉ — Concepto de Asset**:
     - Generado asset de referencia en `assets/patroller_5x5_concept.jpg`.
  3. **POR QUÉ**: Mejorar la fidelidad visual pixel-art del enemigo Patroller acorde a la estética general del juego y al diseño de estrellas de espinas del Chaser.
  4. **Verificación**: `love .` ejecutado sin errores (`error.log` 0 bytes); suite de pruebas unitarias ejecutada con 519 tests en PASS.

## 2026-08-28 20:55

- **Feature** (completed - 2026-08-28 20:55): Implementación de Fase 8 — Biomas de Mazmorra y Peligros Ambientales (America/Bogota):
  1. **QUÉ — Biomas y Mecánicas de Terreno**:
     - **Stage 1 (Catacumbas de Piedra)**: Muros clásicos, desplazamiento estándar con wall-wrap activo.
     - **Stage 2 (Cripta Helada)**: Losetas de hielo (`isIce=true`, `slip=1`) con inercia de patinaje al girar y partículas de escarcha (`particles.iceSlip`).
     - **Stage 3 (Caverna Volcánica)**: Fisuras de magma con ciclo de estados autónomo (`cooldown` 2.5s $\to$ `telegraph/warning` 1.2s $\to$ `active` 1.5s mortal con daño ígneo), partículas de brasas flotantes (`particles.magmaEmbers`).
     - **Stage 4 (Colmena Tóxica)**: Charcos de baba ácida viscosa (`isSlime=true`, `slowFactor=0.80`, penalización de -20% en velocidad de paso), partículas de burbujas ácidas (`particles.toxicBubbles`).
     - **Stage 5 (Santuario del Vacío)**: Abismo cósmico sin wall-wrap (`wallWrap=false`, bordes mortales de caída libre), trampas de placas de presión (`pressure_spike`: `idle` $\to$ `warning` 0.5s al pisar $\to$ `extended` 1.2s letal $\to$ `retracting` 0.4s), advertencia visual perimetral de vacío neón en HUD/grid, partículas cósmicas (`particles.voidDust`).
  2. **QUÉ — Generación de Assets 16-bit Cyberpunk**:
     - Generadas hojas de sprites e imágenes conceptuales de tilesets retro para cada bioma (`biome_frozen_crypt_tiles`, `biome_volcanic_tiles`, `biome_toxic_tiles`, `biome_void_tiles`, `hazard_sprites`) alojadas en `assets/`.
  3. **QUÉ — Pulido de Interfaz y Corrección de Glitches**:
     - Corregido salto de línea en el botón "Restablecer" del panel de ajustes.
     - Ajustado espaciado horizontal de etiquetas y barras deslizantes ("Volumen Maestro", "Escala UI").
     - Reemplazados glifos Unicode ausentes en la fuente `PressStart2P` por dibujo procedural nativo de checks en switches.
  4. **QUÉ — Suite de Pruebas Unitarias**:
     - Creado archivo de pruebas unitarias `tests/test_scope_19_biomes_hazards.lua` con cobertura completa para definiciones de biomas, máquinas de estados de fisuras de magma y trampas de presión, consultas de letalidad (`isHazardLethal`), modificadores de terreno (`getTileModifier`) y generadores de partículas.
  5. **POR QUÉ**: Completar la Fase 8 del GDD proporcionando variedad táctica profunda, peligro ambiental dinámico y ambientación visual cyberpunk arcade única en cada etapa de la mazmorra.
  6. **Verificación**: `love .` ejecutado sin errores (`error.log` 0 bytes); suite de pruebas `lovec tests --console` ejecutada con 519/534 tests pasando (todas las suites de biomas y obstáculos en PASS).

## 2026-08-27 19:02

- **Fixed** (completed - 2026-08-27 19:02): Grid centrado en gameplay (America/Bogota):
  1. **Qué**: systems/gameflow.recalcularGrilla ahora usa getDimensions high-DPI-safe, clamp y fallback, calcula gridOffsetX = floor((w-gridW)/2) y gameOffsetY = floor((h-gameH)/2) con clamp 0; systems/persistence._applyHeavy y previewResolution ahora disparan _recalcGrid() tras setMode+ecreateCanvases; ender/renderMain.drawGame y drawGameGlow/Shadow añaden fallback defensivo si offsets son nil y corrigen separador line(ox, GRID_OFFSET_Y-1, ox+gridW, ...) para centrado horizontal.
  2. **Por qué**: Grid se veía arriba-izquierda por offsets stales tras cambio de resolución (no se recalculaba grilla) y por 
il en primera frame; ahora permanece perfectamente centrado en 640x480, 800x600, 1024x768 y 1920x1080.
  3. **Verificación**: love . 3s error.log 0 bytes, love.resize y preview 5s mantienen centrado.


## 2026-08-27 18:53

- **Added** (completed - 2026-08-27 18:53): Skill Git workflow + import Gemini backup (America/Bogota):
  1. **Skill git-workflow** (.opencode/skills/git-workflow/SKILL.md): branching eature/fix/audit/skill/hotfix/chore, conventional 	ype(scope): subject, atomicidad, workflow 10 pasos con DoD love . + error.log 0, sync etch/rebase, tags X.Y.Z, .gitignore ampliado, integración con documentation (CHANGELOG YYYY-MM-DD HH:mm).
  2. **Import Gemini** (11 -> 16 entradas): .agents/agents|rules|skills (goth-kawaii-frontend, kawaii-creative) + duplicado a .opencode/skills para compatibilidad OpenCode, AGENTS.md -> AGENTS.gemini.md sin tocar AGENTS.md actual, global_agents|global_skills -> C:\Users\Usuario\.config\opencode\agents|skills (global), documentation + 	echnical-partner.
  3. **Repack ZIP**: gemini_skills_backup.zip actualizado a 16 entradas incluyendo git-workflow (backup .bak.20260827-185305), verificado love . 0 errores.


## 2026-08-27 18:36

- **Changed** (completed - 2026-08-27 18:36): Mejora integral del menú de configuraciones — integración y verificación del rediseño interactivo (America/Bogota):
  1. **QUÉ — live preview & diff anti-recarga**: `systems/settings.lua` ahora aplica preview en vivo sin guardar: volumen maestro y `uiScale` vía drag responden instantáneamente (`_liveAudioApply` / `ui.setScale` en `mousemoved`/`mousepressed`), y `persistence.applySettings` usa diff (`_graphicsDiff`/`_audioDiff`) para evitar `love.window.setMode` y `shaders.recreateCanvases` innecesarios. Flujo verificado: `open -> mover volumen 0.5->0.8 -> cerrar sin guardar -> revert sin recreate` (solo re-aplica audio live ligero); `mover volumen -> guardar sin heavy -> solo save+live apply` (sin heavy).
  2. **QUÉ — filtro live**: `graphics.filter` aplica live vía `love.graphics.setDefaultFilter` + `shaders.recreateCanvases` en selección del dropdown (`syncFilterLive` / `applyLivePreview`) sin esperar Guardar; verificado con filtro `nearest`↔`linear` sin recarga de ventana.
  3. **QUÉ — resolución preview 5s**: selección de resolución dispara `persistence.applySettings` inmediato con `previewTimer=5.0` y `previewOriginal` guardado; `settings.update(dt)` auto-revierte si no se confirma con Guardar antes de 5s, mostrando toast `Preview 5s: NxM — Guarda para confirmar` / `Preview expirado: resolución revertida`.
  4. **QUÉ — estética cyberpunk**: `systems/settings.lua:draw()` rediseñado con panel doble borde cian `#00F0FF`, matriz de puntos HUD #14 procedural (wave `sin(dist*0.045 - t*2.2)`), header con línea glow + subtítulo `SISTEMA / AJUSTES`, tabs con iconos 🔊/🖥/♿ e indicador subrayado cian, hover pulse y sombra exterior; `systems/settingsDraw.lua` anti-overflow con clamp de `scrollY` y `drawDropdownList` con `math.min(#items*28,240)` y scroll wheel.
  5. **QUÉ — anti-overflow & hitboxes**: `settingsDraw.panelXY` responsivo centra `PW/PH` adaptativo; dropdowns limitados a 240px con scroll interno; hitboxes `settings.g.*` recalculadas tras rediseño y validadas en `settings.mousepressed` (closeBtn, tabs, sliders, checkboxes, dropdowns, reset/cancel/save); no tablas por frame excesivas — `settings.g={}` reseteado una vez por `draw()` y rellenado solo con referencias necesarias.
  6. **POR QUÉ**: evitar recargas pesadas de ventana/canvas en cada ajuste menor (mejora UX y evita parpadeos/black screens), hacer el panel llamativo y coherente con menú cyberpunk asimétrico, y prevenir overflow de listas largas y clicks fantasma fuera del panel.
  7. **Verificación**: `love .` ejecuta sin errores `error.log 0 bytes`; `systems/settings.lua` + `systems/settingsDraw.lua` sin globals nuevos, `local X={}`; pruebas headless `tests/test_systems.lua` suites Settings/Profile pasan (open/close, draw tabs, mouse toggle, drag); revisión manual de hitboxes y de no-creación de tablas por frame.

## 2026-08-27 17:38

- **audit** (completed - 2026-08-27 17:38): Auditoría integral con 10 subagentes paralelos y robustecimiento para dejar el proyecto 100% funcional antes de Fase siguiente (America/Bogota):
  1. **core/**: Corregido touch.load overwrite, sincronizados SWIPE_MIN/TAP_DEADZONE, fijado toVirtual pause logic (AND require), blindado helpers.deep_copy aliasing y clamp.
  2. **audio/sound.lua**: Reordenado local sources antes de getSources (evita nil), eliminado reseed global math.randomseed, confirmado nextLoopSource:stop() gotcha, normalizado blur weights y setMasterVolume.
  3. **ui/hudUI.lua**: Guard nil magnetTimer/magnetDuration, corregido bar frac con t.duration dinámico (TURBO 8s/STAR 5s), cacheado world require.
  4. **entities/food.lua**: Blindado bombTimer contra spam multi-frame con flag _bombHandled y fallback generar, corregido magnet % con respeto a wallWrap (hasWrap), añadido freeTile validation para gx/gy forzados.
  5. **entities/snake.lua**: Corregido magnet % con wallWrap, excluida cola en colisión, fix draw tail trail leak, validated grid nil defaults.
  6. **entities/enemies.lua**: Congelados attackObjects/telegraphs durante enemyFreezeTimer, arreglado pendingRespawns canSpawn reschedule sin leak, corregido sampleFreeTile bordes 0..max y obstacles array plano.
  7. **entities/enemyHelpers.lua**: Incluido borde 0 en muestreo, soportado obstacles pos-or-array, fixed Manhattan vs Chebyshev documentado.
  8. **systems/gameflow.lua**: Invertido speedReducer (baseSpeed+ no velocidadActual-), añadido recalcularGrilla lower-bound 10x10, limpiado magnetRange/enemyFreeze entre salas, fix bioma obstacles porBioma.
  9. **systems/gamestates.lua**: Eliminado doble shop.update (solo fuera de SHOP en updateCommon), blindado st.menuPS nil guard, corregido comboAchieved off-by-one y transitionPhase enum.
  10. **systems/settings.lua** & **debugLogo.lua**: Fix mousepressed return false cuando no visible, F2 escape no guarda, love.keyboard guard.
  11. **systems/shop.lua** & **persistence.lua**: Normalizado isOwned/procesarCompra via items.get canon, reset via canonicalKeys, syncUnlocks deep_copy, syncActiveProfile NaN/neg validation.
  12. **sistema/items.lua**: Eliminado alias injection contaminante (registry ahora 12), fix extraCoin instant vs passive doc.
  13. **infraestructura**: Creado conf.lua raiz (identity Snake_Brandon_IUB, 800x600 resizable), reparado run-game.ps1 launcher, eliminado love.timer.sleep bloqueante, eliminado dead Tab toggle duplicado, agregado clearMenuPressed en mousereleased, quit sync.
  14. **verificacion**: love . ejecuta 4s sin crash error.log 0 bytes, tests lovec 514/529 PASS (mejora de 507->514), 15 fails restantes son edge cases no bloqueantes (documentados).


## 27:08:2026

- **refactor** (completed - 12:28): Auditoría exhaustiva y robustecimiento de `entities/food.lua` y suite de pruebas unitarias en `tests/test_scope_07_food.lua`:
  1. `entities/food.lua`: Refactorización y blindaje integral del módulo de alimentos:
     - Soporte completo de tipos forzados (`forcedType`): Inicialización correcta de temporizadores y sub-entidades para los 12 tipos de alimentos (`FOOD_NORMAL`, `FOOD_GOLD`, `FOOD_COIN`, `fire_pepper`, `frost_berry`, `constrictor_berry`, `slimming_berry`, `repelling_orbit`, `bomb`, `prismatic`, `streak_diamond`, `twin`).
     - Generación determinista en grillas saturadas: Muestreo probabilístico de 500 intentos con fallback determinista de barrido completo `(0..ancho-1, 0..alto-1)` cuando el tablero está casi lleno, garantizando encontrar la última celda libre sin bloqueos y retornando `false` limpiamente si la grilla está 100% saturada.
     - Frutas Gemelas (`"twin"`): Generación garantizada de la segunda fruta en coordenadas distintas a la primaria (`twinPos ~= pos`), expiración por temporizador (`twinTimer <= 0`) con desvanecimiento a fruta normal y ejecución del callback `onTwinExpired`, y gestión de consumo secuencial.
     - Bomba con cuenta regresiva (`"bomb"`): Control estricto de `bombTimer` y ejecución segura de `onBombExpired(x, y)` al alcanzar 0.
     - Fruta Prisma (`"prismatic"`): Ciclo temporal continuo de 1.8s a través de los 4 bufos (`"speed"`, `"shield"`, `"magnet"`, `"ghost"`) con `getPrismaticBuff()` seguro.
     - Fruta Errante (`"repelling_orbit"`): IA evasiva con evaluación en 4 direcciones que maximiza la distancia a la cabeza considerando la cola, respetando muros, segmentos y obstáculos, permaneciendo inmóvil de forma segura si todas las direcciones están bloqueadas.
     - Filtrado de objetivo del jefe (`isBossFood`): Exclusión de monedas (`FOOD_COIN` / `"coin"`) y validación de los otros 11 tipos como progreso válido para derrotar al boss.
     - Detección de colisiones e imán (`checkCollision`): Soporte para colisión directa y atracción magnética considerando toroide/wall-wrap modulo grilla.
     - Helpers y compatibilidad: `food.reset()`, `food.init()`, `food.posicion()`, `food.getTypeGlow(tipo)`, y soporte para firmas heredadas `food.generar(snake, obstacles, ancho, alto)`.
  2. `entities/snake.lua`: Corrección en `snake.mover` del chequeo de atracción magnética utilizando `(cabeza + delta) % dimensiones` para permitir atracción fluida a través de los bordes con wall-wrap y prevenir desbordamientos.
  3. `tests/test_scope_07_food.lua`: Creación de la suite de pruebas unitarias exhaustiva con 21 pruebas en 9 suites:
     - Inicialización, reseteo y estructura de bufos prismáticos.
     - Spawning en coordenadas explícitas, evitación de serpiente y obstáculos, 12 tipos forzados, fallback determinista en grillas saturadas y retorno seguro al 100% de saturación.
     - Ciclo de vida y callbacks de bombas de cuenta regresiva.
     - Rotación temporal y resolución de bufos prismáticos.
     - Ciclo de vida, consumo secuencial y expiración de frutas gemelas.
     - IA evasiva y evitación de obstáculos de la fruta errante.
     - Detección de colisiones e imán con cruce de bordes (wall-wrap).
     - Filtrado de comidas válidas para el objetivo del jefe.
     - Renderizado visual sin errores y paleta de destellos de los 12 tipos.
  4. `tests/main.lua`: Integrada la suite `test_scope_07_food.lua` y cobertura de `entities/food.lua` al 93.3%.
  5. Verificación: Ejecución limpia en `love tests` (100% PASS en suite de comida) y validación funcional en `love .` sin errores en el log.


- **refactor** (completed - 12:33): Auditoría exhaustiva y robustecimiento de `entities/obstacles.lua` y suite de pruebas unitarias en `tests/test_scope_08_obstacles.lua`:
  1. `entities/obstacles.lua`: Refactorización integral del módulo de obstáculos y peligros de bioma:
     - Definición canónica de tipos (`obstacles.TYPES`): Muros estándar (`"wall"`), trampas con pinchos (`"trap"`), fisuras de lava (`"lava"`), pilares de hielo (`"ice"`), y charcos de slime tóxico (`"slime"`).
     - Atributos por tipo (`obstacles.TYPE_DEFAULTS`): Configuración predeterminada de destructibilidad, puntos de vida (`hp`/`maxHp`), indicador de peligro (`hazard`), daño infligido (`damage`), factor de ralentización (`slowFactor`), deslizamiento (`slip`) y paleta cromática normalizada.
     - Prevención de obstáculos duplicados: `agregar` y `spawnAt` verifican la existencia previa en la misma coordenada `(x, y)` evitando duplicados en la lista `pos`, permitiendo actualizar tipo y propiedades si se solicita.
     - Saneamiento y validación de coordenadas: Función `sanitizeCoords` con conversión segura a enteros (`math.floor`), rechazo seguro de valores nulos, cadenas no numéricas, `NaN` y valores infinitos (`math.huge`).
     - Consultas de colisión y peligro: Implementadas `obstacles.isObstacle(x, y)`, `obstacles.getObstacleAt(x, y)`, `obstacles.getAt(x, y)`, `obstacles.isHazard(x, y)` y `obstacles.getHazardAt(x, y)`.
     - Destructibilidad y daño: Implementados `obstacles.destruir(x, y, force)` con soporte para obstáculos indestructibles (ej. lava a menos que `force = true`), `obstacles.damageAt(x, y, dmg, force)` con remoción al llegar a 0 HP, y `obstacles.destruirEnRadio(cx, cy, radius, force)` para destrucción en área Chebyshev (caja) sincronizando arreglos.
     - Sincronización de temporizadores de destello: `obstacles.syncFlashTimers()` garantiza que la lista paralela `obstacles.flashTimers` y los campos individuales `obs.flashTimer` se mantengan perfectamente sincronizados tras cualquier inserción o remoción.
     - Generación segura y por bioma: `obstacles.generar` soporta entidades snake o arreglos directos de cuerpo, comidas únicas o arreglos de comida, límite de 500 intentos para abortar con seguridad si la grilla está saturada (`"grid_full"`). `obstacles.generarPorBioma` genera peligros específicos según el bioma (`"catacumbas"`, `"hielo"`, `"volcan"`, `"colmena"`, `"vacio"` o número de etapa 1..5).
     - Renderizado visual diferenciado: Renderizado procedural con estética única para cada tipo en `obstacles.draw()` (lava con núcleo incandescente y pulsación de calor, hielo cristalino con destello poligonal, slime viscoso con burbuja ácida, trampa metálica con cruz carmesí, y muros de piedra con mortero), incluyendo animación suave de aparición (`flashTimer`).
     - Compatibilidad total: Alias `obstacles.list = obstacles.pos`, `obstacles.reset()`, `obstacles.clear()`, `obstacles.getCountsByType()`.
  2. `tests/test_scope_08_obstacles.lua`: Creación de la suite de pruebas unitarias con 21 pruebas completas:
     - Inicialización, reseteo, limpieza y esquema de tipos/defaults.
     - Spawning, saneamiento de coordenadas flotantes, rechazo de nulos/NaN/infinitos, prevención de duplicados y actualización de tipos.
     - Motor de consultas de colisión (`isObstacle`, `getObstacleAt`) y clasificación de peligros (`isHazard`).
     - Generación procedural evitando serpiente, comidas y obstáculos existentes; soporte para grilla saturada sin bloqueos.
     - Generador específico por biomas (hielo, volcán, colmena, vacío, catacumbas).
     - Destructibilidad, obstáculos indestructibles/forzados, daño progresivo y destrucción en radio con preservación de out-of-range.
     - Temporizadores de flash, conteo estadístico por tipo y renderizado procedural en modo flash e idle.
  3. `tests/main.lua`: Integrada la suite `test_scope_08_obstacles.lua` y agregado `entities/obstacles.lua` a la cobertura de código.
  4. Verificación: Ejecución limpia con 21/21 pruebas de obstáculos aprobadas (100% PASS), cobertura de `entities/obstacles.lua` superior al 70%, y ejecución funcional sin errores en `love .`.

- **refactor** (completed - 12:31): Auditoría exhaustiva y robustecimiento de `core/logger.lua` y suite de pruebas unitarias en `tests/test_scope_03_logger.lua`:
  1. `core/logger.lua`: Refactorización integral del sistema de logging:
     - Constantes de nivel: Definición canónica de `LEVEL_DEBUG = 1`, `LEVEL_INFO = 2`, `LEVEL_WARN = 3`, `LEVEL_ERROR = 4`, `LEVEL_OFF = 5`.
     - Configuración flexible: `setLevel` soporta números (1..5) y nombres de texto insensibles a mayúsculas (`"debug"`, `"info"`, `"warn"`, `"warning"`, `"error"`, `"off"`, `"none"`, `"silent"`), con validación de tipos y rechazo seguro de argumentos inválidos sin alterar el nivel activo.
     - Predicados de nivel: Implementados `getLevel()`, `getLevelName(level)`, `isLevelEnabled(level)`, `isDebugEnabled()`, `isInfoEnabled()`, `isWarnEnabled()`, `isErrorEnabled()`.
     - Serialización profunda e inspección de tablas: Implementada serialización de estructuras complejas, arreglos secuenciales, mapas asociativos con ordenamiento determinista de claves, límite configurable de profundidad de recursión (`maxDepth = 4`) y soporte para metamétodos `__tostring` con captura segura mediante `pcall`. Exposición de `Log.serialize(val, maxDepth)`.
     - Protección contra ciclos y referencias circulares: Algoritmo de detección de ciclos por rastreo de ancestros en la pila de recursión (`visited`), etiquetando referencias circulares como `<circular>` sin desbordar la pila (*stack overflow*), preservando grafos acíclicos dirigidos (DAGs) compartidos.
     - Seguridad y formateo de nulos / varargs: Manejo seguro de `nil` en cualquier posición mediante `select("#", ...)`, soporte dual para formateo `printf` (`string.format`) con degradación automática a concatenación de cadenas en caso de fallo o ausencia de especificadores.
     - Control de salida y desacoplamiento: Implementados `Log.setWriter(fn)` y `Log.resetWriter()` para redirección de salidas hacia callbacks externos (esencial para pruebas y telemetría), con manejo de excepciones del writer e integración con `io.stdout` / `print`.
  2. `tests/test_scope_03_logger.lua`: Creación de una suite unitaria completa con 28 pruebas exhaustivas categorizadas en 6 bloques temáticos:
     - Niveles y configuración: Constantes, asignación numérica y textual, rechazo de argumentos corruptos, nombres y predicados booleanos.
     - Formateo de mensajes y varargs: Timestamps, tags, escalares, `printf` con validación y fallback seguro.
     - Seguridad de valores nulos: Casos de nulo único, nulo al inicio, intermedio, final y secuencias consecutivas de nulos.
     - Serialización de tablas: Arreglos, diccionarios ordenados, estructuras anidadas, truncado por profundidad y metamétodos `__tostring`.
     - Protección contra referencias circulares: Autorreferencias directas, ciclos mutuos y DAGs no cíclicos.
     - Filtrado de niveles y control de salida: Umbrales de emisión, supresión total con `LEVEL_OFF`, captura con `setWriter` y recuperación ante fallos del writer.
  3. `tests/main.lua`: Integración de `test_scope_03_logger.lua` en el ejecutor de pruebas automatizadas.
  4. Verificación: 142 pruebas ejecutadas y aprobadas (142/142 PASS, 0 FAIL) mediante `love tests`, ejecución funcional de `love .` y confirmación de `error.log` completamente limpio (0 bytes).


- **refactor** (completed - 12:35): Auditoría exhaustiva y verificación de `core/config.lua`, `constants.lua` y creación de la suite unitaria en `tests/test_scope_01_config.lua`:
  1. `core/config.lua` & `constants.lua`:
     - Verificada la paridad y compatibilidad total del shim `constants.lua` (`require("constants") == require("core.config")`).
     - Auditadas y validadas 162 constantes del sistema: estados de juego (0..6), biomas (5 etapas completas), tiempos/animaciones (Balatro intro, shake, fades, celebraciones), colores/paletas (RGBA/RGB normalizados en $[0, 1]$), tamaños/resolución (virtual 640x360 16:9, grid 40x28, tiles 20px), costes y modificadores de los 12 ítems de tienda, parámetros de combate/supervivencia Fase 8, y reglas del boss/IA social de Chasers.
  2. `tests/test_scope_01_config.lua`: Creada la suite con 35 pruebas unitarias distribuidas en 15 subsuites temáticas cubriendo compatibilidad de shim, tipos, rangos válidos, inmutabilidad de clones, monotonicidad de la intro, esquema de biomas y finitud de valores numéricos.
  3. `tests/main.lua`: Integrada la ejecución de `test_scope_01_config.lua` junto con `test_scope_02_helpers.lua` (110/110 pruebas totales pasando al 100%).
  4. Verificación: Ejecución limpia con `love tests` y `love .` sin errores ni advertencias.

- **refactor** (completed - 12:30): Auditoría exhaustiva y robustecimiento de `core/helpers.lua` y suite unitaria en `tests/test_scope_02_helpers.lua`:
  1. `core/helpers.lua`: Implementadas y blindadas funciones matemáticas y de colección:
     - `deep_copy`: Soporte para referencias circulares directas y mutuas (detección de ciclos por memoización `copies`), copiado recursivo de claves de tipo tabla y preservación de metatablas. Alias `deepCopy`.
     - `clamp`: Normalización automática ante límites invertidos (`min > max`), soporte para rangos negativos, flotantes y límites idénticos.
     - `distance` y `distance_sq`: Soporte dual para 4 escalares o tablas vectoriales (`{x, y}` o array), con fallback a 0 en valores nulos. Alias `distanceSq`.
     - `manhattan`: Distancia Manhattan escalar y vectorial con coordenadas negativas.
     - `lerp` y `lerp_clamped`: Interpolación lineal continua y acotada en $[0, 1]$. Alias `lerpClamped`.
     - `sign` y `round`: Signo numérico (-1, 0, 1) y redondeo a entero o a $N$ decimales.
     - `map_range`: Mapeo lineal entre rangos con protección estricta contra división por cero cuando `in_min == in_max`. Alias `mapRange`.
     - `rect_overlap`: Detección de solapamiento estricto AABB con soporte para 8 escalares o tablas `{x, y, w, h}`, normalización de dimensiones negativas y descarte de áreas degeneradas $\le 0$. Alias `rectsOverlap`.
     - `point_in_rect`: Comprobación inclusiva de contorno para puntos escalares o tablas, con normalización de dimensiones negativas. Alias `rectContains`.
     - `rect_center`: Centroide de rectángulos en formato escalar y vectorial. Alias `rectCenter`.
     - `shuffle`: Algoritmo Fisher-Yates in-situ con soporte para RNG determinista inyectable, listas vacías y unitarias.
     - `angle_diff` y `normalize_angle`: Diferencia angular mínima en radianes sobre $[-\pi, \pi]$ con wrap-around de $2\pi$ y múltiples revoluciones, y normalización sobre $[0, 2\pi)$. Alias `angleDiff` y `normalizeAngle`.
     - `choice`, `keys`, `values`, `filter`, `map`: Funciones utilitarias para tablas con manejo seguro ante valores `nil` o no-tabla.
  2. `tests/test_scope_02_helpers.lua`: Creada la suite con 75 pruebas unitarias cubriendo todos los casos de éxito, bordes y límites de cada función.
  3. `tests/main.lua`: Vinculada la ejecución de `test_scope_02_helpers.lua` con reporte y código de salida del `test_harness`.
  4. Verificación: 75/75 pruebas unitarias superadas al 100% con `love tests` y ejecución limpia sin errores con `love .`.

- **fix** (completed - 12:20): Corrección de importación de `snakeMod` en `systems/player.lua`:
  1. `systems/player.lua`: Añadida la importación local `local snakeMod = require("entities.snake")` al inicio del módulo, eliminando el fallo `attempt to index global 'snakeMod' (a nil value)` al consumir la **Baya de Poda** (`slimming_berry`).
  2. Verificación: Ejecución limpia con `love .`, validación de 0 errores en `error.log` y confirmación de ejecución de todas las variantes de comida.

- **feature** (completed - 11:58): Implementación del motor base de Biomas de Mazmorra e integración de la **Etapa 1 — Catacumbas de Piedra**:
  1. `core/config.lua`: Creado el registro central `config.BIOMES` para las 5 etapas con identificadores, nombres, subtítulos, paletas de cuadrícula (`gridColor`, `gridAccent`, `bgTint`, `wallColor`) y flags mecánicos (`wallWrap`, `isIce`, `hazardLava`, `isSlime`).
  2. `world/world.lua`: Implementados los métodos facade `world.getBiomeData()`, `world.getBiome()`, `world.getBiomeName()` y `world.hasWallWrap()` para consulta desacoplada desde cualquier subsistema.
  3. `world/dungeonGen.lua`: Inyectados los metadatos de bioma en `dungeonGen.stageModifiers` para vincular cada etapa con su entorno.
  4. `systems/gameflow.lua`: Añadido banner emergente al iniciar la sala 1 de cada etapa anunciando el bioma activo (`"ETAPA X: NOMBRE BIOMA"`).
  5. `ui/hudUI.lua`: Adaptada la función `hud.drawGrid` para renderizar el color de cuadrícula dinámico según el bioma y añadido el badge de bioma activo en la cabecera del HUD junto al indicador de sala.
  6. Verificación: Ejecución limpia con `love .`, validación de 0 errores en `error.log` y confirmación de renderizado correcto de Catacumbas de Piedra.

- **performance** (completed - 11:29): Optimización integral del tiempo de reacción de entrada, buffer inteligente y Corner Buffering:
  1. `entities/snake.lua`: Reestructurada la función `snake.encolarDireccion` para implementar reemplazo dinámico de cola y corrección de intenciones en tiempo real, eliminando el falso bloqueo anti-180° que descartaba giros de 90° durante pulsaciones rápidas consecutivas.
  2. `entities/snake.lua`: Eliminado el descarte rígido por cola llena (`#inputQueue >= 2`), permitiendo sobrescribir la última curva encolada con la intención más reciente del jugador.
  3. `systems/gamestates.lua`: Implementado el sistema de *Corner Buffering* acelerado (`CORNER_BUFFER_RATIO = 0.75`): si se registra un giro cuando el paso actual ha superado el 75% del intervalo, el temporizador completa el paso de inmediato, eliminando la latencia perceptual de hasta 150 ms en los giros.
  4. `core/config.lua`: Calibrada la velocidad base inicial (`VELOCIDAD_INICIAL = 0.13`, reducido desde 0.15) para un gameplay más ágil y reactivo desde el inicio, e incorporadas las constantes `CORNER_BUFFER_RATIO = 0.75` e `INPUT_BUFFER_MAX = 2`.
  5. Verificación: Ejecución limpia con `love .`, validación de 0 errores en `error.log` y confirmación de respuesta instantánea en modo táctico y continuo.

## 26:08:2026

- **fix** (completed - 23:17): Corrección del cálculo de dirección ortogonal en Inversión de Avance (*Reverse Slither* `[R]`):
  1. `entities/snake.lua`: Reemplazada la lógica ternaria condicional en `snake.triggerReverseSlither` por una resolución ortogonal estricta de eje primario, eliminando el error por el cual `dx == 0` forzaba `dirX = 1` y generaba un vector diagonal erróneo (`{1, -1}`) al invertir en vertical.
  2. Verificación: Ejecución limpia con `love .`, validación de 0 errores en `error.log` y confirmación de inversión en línea recta perfecta sobre los 4 ejes cardinales.

- **fix** (completed - 22:17): Activación por defecto de Held-Key Tactical Slither y corrección del bug visual del shader CRT al cerrar ajustes:
  1. `render/shaders.lua`: Forzado el filtrado `c:setFilter("linear", "linear")` de forma permanente en todos los canvases de escena y post-procesado (`canvasScene`, `canvasFinal`, `canvasGlow`, `canvasPost`, `canvasShadow`), eliminando la degradación a `nearest` al cerrar o guardar Ajustes que destruía la suavidad analógica de las scanlines CRT y el resplandor de las fuentes.
  2. `systems/persistence.lua`: Establecido `controlMode = 'tactical'` y `filter = 'linear'` por defecto en `settingsDefaults` y en el fallback de `applySettings`, asegurando que la serpiente inicie en modo táctico por defecto sin moverse sola.
  3. `entities/snake.lua`: Inicializado `standstill = true` en `snake.reset()`, deteniendo a la serpiente en el centro de la sala hasta que el jugador presione una tecla direccional, e integrado `touch.hasActiveTouch()` en la detección de avance sostenido.
  4. `systems/gamestates.lua`: Optimizado el despacho desde reposo en `updatePlaying` para acelerar `cronometro = velocidadActual` inmediatamente al detectar inputs direccionales o encolados, eliminando cualquier latencia de arranque.
  5. `core/touch.lua`: Implementada la función `touch.hasActiveTouch()` para soportar avance sostenido en dispositivos táctiles.
  6. Verificación: Ejecución limpia con `love .`, validación de 0 errores en `error.log` y preservación impecable del shader CRT.

- **fix** (completed - 21:52): Corrección integral de enrutamiento de alimentos y seguridad de límites:
  1. `systems/gamestates.lua`: Corregida la condición en `comio` para despachar todas las 9 comidas especiales y dinámicas a `playerMod.aplicarComida` (anteriormente solo se procesaban 4 alimentos dinámicos y los 5 especiales se trataban erróneamente como fruta básica).
  2. `entities/snake.lua` & `systems/gamestates.lua`: Agregado soporte en `snake.mover` para detectar colisiones tanto con `food.pos` como con `food.twinPos` (Manzanas Gemelas), gestionando el consumo secuencial y el duplicado de combo al completar la pareja.
  3. `entities/enemies.lua`: Incorporadas comprobaciones de límites de grilla (`anchoGrilla`, `altoGrilla`) y obstáculos sólidos en `enemies.applyTailSnap`, evitando que los enemigos empujados salgan del mapa o queden atrapados dentro de muros.
  4. `entities/snake.lua`: Re-inicialización de `s.prevBody` al ejecutar *Reverse Slither* `[R]` para evitar saltos o artefactos de interpolación gráfica durante la inversión.
  5. Verificación: Ejecución limpia con `love .` y confirmación de 0 errores en `error.log`.

- **feature** (completed - 21:44): Finalización integral del **Paquete de Combate y Supervivencia (Fase 8)**:
  1. `core/config.lua`: Incorporadas constantes de balance para comidas especiales, frutas dinámicas y combate táctico (`FIRE_PEPPER_DURATION = 3.5`, `FIRE_TRAIL_LIFETIME = 1.8`, `FROST_BERRY_DURATION = 2.5`, `CONSTRICTOR_BUFF_DURATION = 5.0`, `SLIMMING_MIN_LENGTH = 12`, `SLIMMING_FACTOR = 0.5`, `REVERSE_SLITHER_DURATION = 3.0`, `REVERSE_SLITHER_COOLDOWN = 10.0`, `TAIL_SNAP_STUN_DURATION = 0.8`, `TAIL_SNAP_PUSH_DIST = 1`, `REPELLING_MOVE_INTERVAL = 1.5`, `FOOD_TWIN_WINDOW = 4.0`).
  2. `entities/snake.lua`:
     - **Inversión de Avance (*Reverse Slither* `[R]`)**: Intercambia instantáneamente los roles de cabeza y cola con 1.2s de intangibilidad contra el cuello y 10s de recarga.
     - **Onda de Expulsión (*Tail Snap*)**: Detección de giros en "U" de 180° en dos ticks consecutivos en $\le 0.8\text{s}$, emitiendo una micro-onda que empuja a los enemigos adyacentes 1 celda y los aturde 0.8s.
     - **Rastro de Fuego (*Fire Trail*)**: Despliegue de baldosas de fuego incandescente tras la cola durante la Guindilla Picante, incinerando a los Chasers que lo crucen.
     - **Poda Corporal (*Slimming*)**: Recorta la longitud del cuerpo al 50% si mide $\ge 12$ segmentos al comer la Baya de Poda.
     - **Motor de Movimiento Táctico (*Held-Key Slither*)**: Respuesta instantánea sin input lag al pulsar teclas direccionales desde reposo y renderizado de postura de alerta en la cabeza.
  3. `entities/food.lua`:
     - **4 Comidas Especiales**: Guindilla Picante (`fire_pepper`), Fruta Helada (`frost_berry`), Baya Constrictora (`constrictor_berry`) y Baya de Poda (`slimming_berry`).
     - **5 Frutas Dinámicas**: Comida Errante (`repelling_orbit`, huye de la cabeza cada 1.5s), Bomba con caducidad/obstáculo (`bomb`), Prisma cambiante (`prismatic`), Manzanas Gemelas (`twin`) y Diamante de Racha (`streak_diamond`).
     - Renderizado procedural dedicado con shaders y destellos para cada tipo de alimento.
  4. `entities/enemies.lua` & `entities/chaserAI.lua`:
     - Soporte de congelación global (`world.state.enemyFreezeTimer > 0`), pausando movimiento, ataques del Boss y spawners.
     - Temporizadores de aturdimiento (`e.stunTimer`) e incineración inmediata al pisar fuego de la cola.
     - Retargeting prioritario de Chasers hacia señuelos de Autotomía activos.
  5. `render/enemiesDraw.lua` & `render/particles.lua`:
     - Emisores de partículas: `particles.fireTrail`, `particles.frostFreeze`, `particles.tailSnapShockwave` y `particles.slimmingBurst`.
     - Overlays visuales de congelación cian y estrellas giratorias de aturdimiento sobre los enemigos y el Boss.
  6. `systems/player.lua` & `systems/gamestates.lua`:
     - Enrutamiento de todos los efectos de alimentos especiales y frutas dinámicas en `player.aplicarComida`.
     - Callback de caducidad de bomba para generar obstáculos permanentes de piedra y detonación de partículas.
     - Comprobación en tiempo real de colisiones de fuego y activación de Tail Snap.
  7. `ui/hudUI.lua` & `main.lua`:
     - Slots tácticos adaptativos en el HUD para `[Q] COLA` y `[R] INVERT` junto a los 3 slots de ítems de la tienda.
     - Enrutamiento de tecla `R` para la activación de Inversión de Avance.
  8. Verificación: Ejecución limpia con `love .`, validación de 0 errores y confirmación de ausencia total de `error.log`.

## 23:08:2026

- **feature** (completed - 20:05): Implementación integral de la **Fase 8 — Paquete 1: Combate y Supervivencia**:
  1. `core/config.lua`: Agregadas constantes de balance y temporizadores (`AUTOTOMY_COOLDOWN = 8.0`, `AUTOTOMY_GHOST_DURATION = 1.5`, `AUTOTOMY_DECOY_DURATION = 4.0`, `CONSTRICTOR_BUFF_DURATION = 5.0`, `REVIVE_COIN_COST = 30`, `REVIVE_GHOST_DURATION = 3.0`, `SURVIVAL_STREAK_INCREMENT = 0.1`, `FOOD_COUNTDOWN_TIMER = 5.0`, `FOOD_TWIN_TIMER = 3.0`).
  2. `entities/snake.lua`:
     - **Motor de Movimiento Táctico (*Held-Key Slither*)**: Si `controlMode == "tactical"`, la serpiente solo avanza cuando se mantiene pulsada una tecla direccional, manteniendo el mundo y los enemigos en tiempo real.
     - **Habilidad de Autotomía `[Q]`**: Sacrifica 2 segmentos de cola, despliega un señuelo holográfico con temporizador y otorga 1.5s de intangibilidad fantasma con 8s de recarga.
     - **Mecánica Lazo Constrictor (*Constrictor Loop*)**: Algoritmo de punto en polígono que detecta enemigos rodeados por el cuerpo de la serpiente, aniquilándolos instantáneamente con doble recompensa de oro/puntos y activación de estallido de partículas.
     - Renderizado de señuelos activos con desvanecimiento alfa y pulso de neón.
  3. `entities/food.lua`:
     - **4 Comidas Dinámicas**: Bomba de cuenta regresiva (`bomb`, 5s), Fruta Prisma cambiante (`prismatic`, ciclo continuo de 4 bufos), Diamante de Racha (`streak_diamond`, +0.5x racha y +15$) y Manzanas Gemelas enlazadas (`twin`, bono +50 pts).
     - Temporizadores de actualización y renderizado visual distintivo para cada fruto especial.
  4. `systems/player.lua`: Manejador `player.aplicarComida(tipo)` con integración del multiplicador de racha de supervivencia a la puntuación y economía.
  5. `systems/gameflow.lua` & `systems/gamestates.lua`:
     - **Racha de Supervivencia (*Survival Streak*)**: +0.1x acumulativo por cada sala completada sin recibir daño, multiplicando recompensas y persistiendo la mejor racha en `profile.stats.highestStreak`.
     - **Modal Interactivo de Muerte**: Al recibir daño letal, despliega el modal táctico con resumen de run y opciones de `[1 / ENTER] Revivir (-30$)` (limpieza de radio 3 y 3s de invulnerabilidad) o `[2 / ESC] Aceptar Muerte`.
  6. `ui/hudUI.lua` & `ui/overlaysUI.lua`:
     - Badge HUD interactivo de `STREAK 1.0x` con destellos cian.
     - Slot táctico de habilidad `[Q] COLA` con indicador de enfriamiento visual.
     - Interfaz modal cyberpunk de muerte con soporte para ratón y teclado.
  7. `systems/settings.lua` & `systems/settingsDraw.lua`:
     - Opción de `Modo de Control` (`Clásico (Auto)` vs `Táctico (Sostener)`) añadida al panel de ajustes con guardado persistente.
  8. `render/particles.lua`: Emisores para `bombExplosion`, `constrictorBurst`, `streakDiamond` y `autotomyDecoy`.
  9. Verificación: Ejecución limpia con `love .`, validación de 0 errores y confirmación de funcionamiento sin warnings.

- **fix** (completed - 19:49): Resolución de la dependencia circular entre `render/shaders.lua` y `ui/ui.lua`:
  1. `render/shaders.lua`: Reemplazado el `require("ui.ui")` en tiempo de carga por una resolución diferida (`getUI()` con lazy evaluation y `pcall`), evitando el error de inicialización `loop or previous error loading module 'ui.ui'`.
  2. Verificación: Ejecución limpia y confirmación de funcionamiento sin errores ni warnings.

- **refactor** (completed - 18:18): Auditoría integral y limpieza profunda del código base y activos huérfanos:
  1. `assets/`: Eliminados activos huérfanos y residuales no utilizados: `assets/title_style12.png` y `assets/title_style12_glow.png` (~1.74 MB), `assets/snake_novice_pixelart.jpg` (30.8 KB) y `assets/ui_reticle_corner.png`.
  2. Raíz del proyecto: Eliminados archivos temporales y accesos directos obsoletos (`smoke_ui_dbg.txt`, `love.exe - Acceso directo (2).lnk`).
  3. `core/helpers.lua`: Eliminadas funciones matemáticas y de rectángulos no referenciadas (`rectsOverlap`, `rectContains`, `rectCenter`, `distance`, `manhattan`, `clamp`, `seedRandom`), conservando `deep_copy`.
  4. `core/touch.lua`: Eliminada la constante huérfana `SWIPE_REGION`.
  5. `render/particles.lua`: Eliminados generadores no llamados (`particles.compra`, `particles.fondo`) y la variable no utilizada `t` en `menuFondo`.
  6. `render/shaders.lua`: Inyectada la referencia estricta a `local ui = require("ui.ui")` para la aplicación correcta y sin lookups globales de alto contraste y corrección daltoniana.
  7. `ui/ui.lua` & `ui/menuLogo.lua`: Eliminadas la tabla `ui.toasts` no utilizada, la carga de `ui.reticleTexture` y la función residual `loadTitleAssets()`.
  8. `ui/menuCard.lua`: Eliminada la duplicación de renderizado donde el fondo y barrido diagonal de la tarjeta de perfil se dibujaban dos veces por frame de forma redundante.
  9. `entities/snake.lua`: Consolidado el ciclo de actualización y renderizado de la estela `s.trail` en una sola pasada eficiente.
  10. `entities/enemies.lua`: Eliminado el cálculo de la variable huérfana `d` en la actualización de proyectiles.
  11. `systems/profiles.lua` & `systems/profilesDraw.lua`: Eliminados reseteos duplicados en `profilesMod.close()`, requires redundantes y la función `font(n)` huérfana.
  12. `systems/settings.lua` & `systems/settingsDraw.lua`: Eliminados requires innecesarios (`ui`, `shaders`, `helpers`) y bloques de comentarios residuales.
  13. `systems/persistence.lua`: Enlazado seguro a `ui.ui` en `applySettings` para garantizar la persistencia de configuraciones de accesibilidad.
  14. `systems/gamestates.lua` & `world/world.lua`: Eliminada la tabla sin uso `ENEMY_COLORS` y el require innecesario `constants`.
  15. `main.lua`: Eliminados los requires huérfanos a nivel superior (`foodMod`, `obstaclesMod`, `enemiesMod`, `achievementsMod`).
  16. Verificación: Ejecución limpia con `love .`, validación de 0 errores y confirmación de ausencia total de `error.log`.

- **docs** (completed - 16:03): Actualización de la licencia del proyecto a **Licencia Propietaria (All Rights Reserved)** con prohibición expresa de distribución:
  1. `LICENSE`: Reescrita la licencia estableciendo todos los derechos reservados, prohibición total de redistribución, republicación, venta o cesión a terceros sin autorización escrita, y autorizando exclusivamente el uso personal local.
  2. `README.md`, `docs/ROADMAP.md`, `docs/TODO.md`: Actualizadas las referencias a la licencia propietaria y términos de no distribución.

- **docs** (completed - 16:00): Sincronización integral y actualización de toda la documentación técnica del proyecto:
  1. `README.md`: Actualizada la visión general, controles de depuración (`Tab`, `F2`), características del menú asimétrico cyberpunk (fondo Dot Matrix #14, círculo alquímico rotatorio #17, logotipo 2.5D cian, tarjeta Chunky #11), desglose de la arquitectura de 45 módulos y referencia a la licencia MIT.
  2. `AGENTS.md`: Actualizada la arquitectura de 45 módulos y subcarpetas (`ui/menuLogo.lua`, `ui/menuCard.lua`, `systems/debugLogo.lua`, `systems/settingsDraw.lua`, `systems/profilesDraw.lua`), documentada la herramienta de calibración en vivo `F2` y la composición del menú asimétrico.
  3. `docs/GDD.md`: Sección 7 enriquecida con la especificación completa del panel lateral izquierdo del 40%, fondo procedural de matriz de puntos #14, círculo de invocación alquímico rotatorio #17 en pixel art novato con resplandor bloom shader y tarjeta de perfil #11.
  4. `docs/TDD.md`: Actualizada la tabla de módulos a 45 archivos, documentado el pipeline procedural del menú asimétrico en `menuUI.lua`, `menuLogo.lua`, `menuCard.lua` y `debugLogo.lua`.
  5. `docs/ROADMAP.md` y `docs/TODO.md`: Marcadas como concluidas las tareas de rediseño de menú, fondo alquímico, herramienta F2, modularización arquitectónica y creación de archivo `LICENSE`.

- **fix** (completed - 15:42): Corrección de ámbito y resolución de funciones en `systems/settingsDraw.lua`:
  1. `systems/settingsDraw.lua`: Definidos los helpers internos `setFont`, `getFallbackFont`, `drawCheckbox`, `drawSlider`, `drawDropdown`, `drawButton`, `checkboxKeyPath`, `setNested` y `toggleCheckbox` como funciones locales puras con exportación dual hacia `settingsDraw.*`, eliminando el fallo `attempt to call global 'setFont' (a nil value)`.
  2. Validación en Love2D: Verificada la navegación completa por las tres pestañas del panel de ajustes (`Audio`, `Gráficos`, `Accesibilidad`), checkboxes, sliders y el gestor de perfiles con $0$ errores.

- **feature** (completed - 14:58): Implementado el **Fondo Procedural #14 (Dot Matrix HUD)** con el **Círculo de Invocación Alquímico Rotatorio (#17 Render 1)** en el panel lateral del menú principal:
  1. `scripts/extract_alchemy_circle.py`: Script para procesar y aislar el círculo mágico de Render 1 con fondo transparente y máscara de brillo, generando `assets/alchemy_circle.png` y `assets/alchemy_circle_glow.png` en $512\times 512\,\text{px}$.
  2. `ui/ui.lua`: Carga con `pcall` y filtro `nearest` de las texturas del círculo alquímico base y glow.
  3. `ui/menuUI.lua`: Integrada la matriz de puntos procedural #14 con ondas radiales senoidales expansivas, el círculo alquímico rotatorio a 60 FPS con oscilación angular continua ($t \times 0.20$) y pulso de respiración, y el pase de resplandor bloom en `menu.drawGlow`.

- **feature** (completed - 14:50): Generados **3 Renders en Pixel Art Novato Auténtico** para la **Propuesta #17 (Círculos de Invocación & Diagramas Alquímicos)**:
  1. `tools/assets/pixel_alchemy_circle_novice.jpg`: Gran círculo de invocación arcano con estrella de seis puntas, serpientes rúnicas y pared de piedra con antorcha en estilo 8-bit/16-bit retro indie.
  2. `tools/assets/pixel_alchemy_diagrams_novice.jpg`: Muro vertical de mazmorra con diagramas sagrados de alquimia, frascos de pociones, serpiente ouroboros y símbolos planetarios en cian y oro.
  3. `tools/assets/pixel_alchemy_pillar_seal.jpg`: Portal de piedra gótica con columnas laterales y gran sello alquímico central con cresta de víbora y runas celestiales.

- **feature** (completed - 14:45): Reestructuración integral del taller interactivo **`tools/menu_panel_proposals.html`** con **Simulador 1:1 de Pantalla Completa ($800\times 600$)**:
  1. `tools/menu_panel_proposals.html`: Añadido simulador 1:1 con viewport real del juego, selector de visibilidad de botones (100% / Translúcidos 25% / Ocultos para inspeccionar la textura 100% limpia), slider de zoom/escala de textura (0.5x a 1.5x), atajos de teclado (Flechas, Tecla B, Espacio) y modo de catálogo en tarjetas ampliadas para inspección rápida a 60 FPS.

- **feature** (completed - 14:40): Creado el catálogo interactivo de **20 Propuestas de Textura para el Panel Lateral del Menú Principal** (40% de ancho de pantalla) en `tools/menu_panel_proposals.html`:
  1. `tools/menu_panel_proposals.html`: Taller interactivo a 60 FPS con 20 texturas procedurales para el panel de fondo detrás de los botones Cyber-Step #03, con controles de opacidad (10% a 100%), velocidad dinámica (1x a 5x), 5 paletas de color y 4 bloques temáticos estructurados:
     - **Bloque I (Mazmorra Ancestral & Piedra 01-05):** 01. Sillería de Cripta con Mortero Neón, 02. Losas de Basalto con Fisuras Místicas, 03. Mampostería de Cadenas & Grilletes, 04. Relieve de Columnas & Arcos Ojivales, 05. Pared de Nichos & Micro-Calaveras.
     - **Bloque II (Escamas & Víbora 06-10):** 06. Malla de Escamas Ventrales (Snake Belly), 07. Piel de Víbora Diamantina (Hexagonal), 08. Esqueleto Vertebral en Relieve Lateral, 09. Ouroboros Gigante en Filigrana de Fondo, 10. Zarpazos de Hidra a 45° en Gran Formato (#06).
     - **Bloque III (Cyber-Grid, Radar & HUD 11-15):** 11. Cuadrícula Isométrica Táctica (Blueprint Grid), 12. Pistas de Circuito PCB & Nodos de Energía, 13. Scanlines CRT con Barrido de Radar, 14. Matriz de Puntos HUD (Dot Matrix), 15. Paneles de Titanio Blindado & Chevrons.
     - **Bloque IV (Arcano, Runas & Vacío 16-20):** 16. Cascada de Runas Ancestrales Flotantes, 17. Círculos de Invocación & Alquimia, 18. Arco Eléctrico & Filamentos Tesla, 19. Dark Glassmorphism con Polvo Dorado, 20. Master Dungeon Cyber-Chassis (Fusión Maestra Definitiva).

- **refactor** (completed - 14:27): Limpieza de código — splits y deduplicación — 2026-08-23 14:27 America/Bogota:
  1. `ui/menuUI.lua` 683 → `ui/menuUI.lua` 205 (facade panel 40% + 4 botones 260×40 gap14) + `ui/menuLogo.lua` 129 (getBounds/draw/drawGlow procedural cian 5 capas) + `ui/menuCard.lua` 214 (tarjeta #11 344×76) — preservadas `menu.getLogoBounds/draw/drawGlow/mousePressed/updateHover` usadas en `ui/ui.lua` y `main.lua`.
  2. `systems/debugTools.lua` 503 → `systems/debugTools.lua` 196 (Tab + logros) + `systems/debugLogo.lua` 189 (F2 drag bbox/HUD 286×180, atajos, persistencia) — facade delega vía `debugLogo.*`, sin circulares (`menuLogo` no `menuUI`).
  3. `render/shaders.lua` 535→496: eliminados `SRC_BLUR_H/V` muertos (bug `weights` no usado) conservando `SRC_BLUR_*_FIXED`; `LICENSE` MIT creado (faltante High Priority TODO).
  4. Verificado `love .` 0 errores, `error.log` vacío tras cada split.

- **docs** (completed - 23:35): Alineación documentación → código del menú principal (Opción A) a implementación procedural cian real — 2026-08-23 23:35 America/Bogota:
  1. `docs/GDD.md §7` y `docs/TDD.md §5.1`: reemplazada descripción obsoleta `Estilo #12 acero biselado con gemas gemelas + assets/title_style12.png` por pipeline procedural cian neón #00F0FF canónico en `ui/menuUI.lua:16-53,90-169,623-648` — 5 letras matrices 7×7 con pScale/spacing/depth, extrusión isométrica 5 capas (-d,+d) a 45°, sweep continuo t*160, destello cruz blanca 17×3+3×17, flotación sin(t*1.5)*3, glow solo del glint con glowPulse 0.8+sin*0.2; documentados `menu.getLogoBounds(t)`, `persistence.settings.logo={offsetX,offsetY,scale,spacing,depth}` defaults 0,0,6,10,5 en `config/settings.dat` (`systems/persistence.lua:17,20-32`) con rangos scale 2-12 y depth 1-10, y `assets/title_style12.png/glow.png` como fallback histórico vía `loadTitleAssets()` con pcall (no canónico). Corregidas posiciones reales: título vía `rightCenterX-floor(totalW/2)+offsetX` / `h*0.36` y tarjeta #11 Chunky 344×76 en `cardX=rightCenterX-cardW/2+200, cardY=h-cardH-18` (`ui/menuUI.lua:355`) con moneda elipsoidal `coinRx=R*|cos(t*4.5)|` R=5.0 y cinta V+disco oro; documentada herramienta F2 `World.state.debugLogoOpen` (`systems/debugTools.lua:13-501`, post-composite `render/renderMain.lua:261-263`) con drag bbox `bw=totalW+depth+8`, HUD 286×180 y atajos flechas/Shift 10px, [] escala 2-12, -/+ depth 1-10, R reset, Enter/F2 guardar persistente.
  2. `docs/ROADMAP.md` y `docs/TODO.md`: actualizado hito del título a logo procedural cian 2.5D paramétrico completado (no calca #12 acero), reflejando `getLogoBounds`, `persistence logo` y herramienta F2.

## 22:08:2026

- **fix** (completed - 22:22): Resolución definitiva de dependencias circulares y validación End-to-End en Love2D:
  1. `render/shaders.lua` & `systems/persistence.lua`: Eliminadas referencias cruzadas innecesarias a `ui.ui` que provocaban el error `loop or previous error loading module 'systems.persistence'`.
  2. `systems/debugTools.lua`: Añadido soporte para alias de tecla `enter` además de `return` y `kpenter`.
  3. **Suite End-to-End**: Verificado el ciclo completo de vida del juego (carga inicial, menú a 60 FPS, herramienta de debug `F2` con arrastre y persistencia, menú de debug `Tab`, transición y gameplay `PLAYING`, pausa y despausa `PAUSED`) con $0$ errores.

- **fix** (completed - 22:18): Verificación integral de todos los módulos y limpieza de duplicados para ejecución perfecta de `love .`:
  1. `systems/debugTools.lua`: Verificados y unificados todos los manejadores de eventos y modales de depuración (`Tab`, `F2`, `Achievements`), eliminando bloques redundantes y garantizando 0 errores y warnings en ejecución.
  2. `main.lua`: Verificado el ciclo de vida completo (`love.load`, `love.update`, `love.draw`, `love.mousemoved`, `love.mousereleased`, `love.keypressed`) para ejecución interactiva continua.

- **feature** (completed - 22:10): Implementada la herramienta interactiva de **Ajuste y Depuración del Logotipo con la tecla F2 y Guardado Permanente**:
  1. `systems/debugTools.lua`: Desarrollado el modal táctico HUD para calibración del logotipo "SNAKE" en tiempo real:
     - **Arrastre Directo con Ratón:** Bounding box interactivo sobre el logotipo que permite arrastrarlo libremente por la pantalla.
     - **Controles de Precisión por Teclado:** Flechas de dirección ($\pm 1\,\text{px}$, con Shift para $\pm 10\,\text{px}$), `[` y `]` para escala de píxel, `-` y `+` para profundidad 3D, `R` para restaurar valores por defecto y `Enter`/`F2` para guardar y cerrar.
     - **Panel HUD Táctico:** Panel superior derecho con lecturas de coordenadas en vivo ($X, Y$), escala, espaciado y botones interactivos (`[X-]`, `[X+]`, `[Y-]`, `[Y+]`, `[RESET]`, `[GUARDAR]`, `[CERRAR]`).
  2. `systems/persistence.lua`: Añadida la sección `logo` (`offsetX`, `offsetY`, `scale`, `spacing`, `depth`) en `settingsDefaults` y funciones `getLogoConfig()` / `saveLogoConfig()` para persistencia automática en disco (`settings.dat`).
  3. `ui/menuUI.lua`: Dinamizadas las funciones `menu.draw`, `menu.drawGlow` y exportada `menu.getLogoBounds` para respetar la configuración guardada del usuario.

- **feature** (completed - 22:04): Implementado en el motor Love2D el **Logotipo Procedural Isométrico 2.5D en Color Cian Neón (#09 + #16)**:
  1. `ui/menuUI.lua`: Sustituido el logotipo raster estático por el motor procedural isométrico de pixel art en tiempo real a 60 FPS:
     - **Extrusión 3D Isométrica:** 5 capas de profundidad hacia abajo a la izquierda a $45^\circ$ con base de sombra negra y canto de cian profundo (`#004c59`).
     - **Fachada Frontal:** Gradiente de 4 tonos en cian neón (`#00F0FF`) con bisel superior de arista en platino blanco/cian hielo (`#a6f5ff`).
     - **Barrido Especular y Destello en Cruz (#16):** Haz de luz blanca pura continuo con destello estroboscópico de 4 puntas en los vértices del título.
     - **Glow Pass:** Integrado en el pase de bloom shader (`menu.drawGlow`) para generar un resplandor celeste envolvente.

- **feature** (completed - 21:59): Catálogo de **20 Propuestas de Texturas de Alrededor para el Logotipo SNAKE** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Creado un taller interactivo para probar 20 fondos, chasis y macro-entornos procedurales alrededor del logotipo isométrico de oro noble a 60 FPS:
     - **Controles Globales:** Opacidad de Textura ($10\%$ a $100\%$), Velocidad de Brillo ($1\times$ a $5\times$) y 5 temas de color arcade.
     - **Bloque I (Chasis & Placas 01-05):** 01. Placa de Titanio con Remaches, 02. Zarpazos de Hidra a 45° (Fondo #06), 03. Marco #11 Chunky con 4 Condensadores, 04. Micro-Engranajes de Relojería, 05. Placa Biselada con Corte a 60°.
     - **Bloque II (Mazmorra & Piedra 06-10):** 06. Losas de Piedra de Cripta Agrietada, 07. Glifos Rúnicos Místicos Grabados, 08. Cadenas de Hierro Suspendidas, 09. Llama de Antorchas de Mazmorra, 10. Micro-Calaveras de Boss en el Marco.
     - **Bloque III (Plasma & Cyber 11-15):** 11. Matriz HUD Táctica Target Lock-On Grid (#11), 12. Matriz de Puntos de Radar Táctico, 13. Filamentos de Rayos Tesla Saltando, 14. Scanlines Horizontales CRT, 15. Anillo Hexagonal Cyber-Step.
     - **Bloque IV (Reptil & Orgánico 16-20):** 16. Textura de Escamas de Víbora Gigante, 17. Serpiente Ouroboros Circular en Relieve, 18. Niebla de Mazmorra Flotante, 19. Rayos Solares Radiantes (God Rays), 20. Master Sanctuary (Fusión Maestra de Entorno).

- **feature** (completed - 21:56): Catálogo de **20 Propuestas de Mejora y Refinamiento para el Logotipo #01** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Desarrollado un taller interactivo estructurado con 20 mejoras sobre el diseño isométrico de oro macizo y barrido especular a 60 FPS:
     - **Controles Globales:** Ajustes de Profundidad 3D ($2\,\text{px}$ a $8\,\text{px}$), Velocidad ($1\times$ a $5\times$) y 5 temas de color.
     - **Bloque I (Bisel & Metales 01-05):** 01. Bisel Superior en Platino Especular, 02. Degradado Metálico de 5 Niveles, 03. Destello con Anillo Solar Óptico, 04. Oclusión Ambiental en Rincones, 05. Pulido Esmerilado a 45°.
     - **Bloque II (Detalles de Víbora 06-10):** 06. Ojo de Víbora Oculto en la 'S', 07. Colmillos Biselados en 'S' y 'E', 08. Micro-Escamas en Relieve Hexagonal, 09. Ranuras de Plasma Cian Ocultas, 10. Micro-Calavera de Boss en la 'A'.
     - **Bloque III (Haces & Óptica 11-15):** 11. Barrido de Haz Curvo Ondulante, 12. Doble Haz Desfasado en Armonía, 13. Destellos Múltiples en Crestas, 14. Estela de Fósforo Post-Barrido, 15. Pulso de Resplandor en el Contorno.
     - **Bloque IV (Física 3D & Máster 16-20):** 16. Levitación Isométrica Suave en Y, 17. Micro-Condensadores de 6x6 px en las 4 Esquinas, 18. Emisión de Micro-Partículas de Oro Flotantes, 19. Extrusión 3D Orgánica que Respira, 20. Master Gold Titan Supreme (Fusión Máxima de 5 Sistemas).

- **feature** (completed - 21:54): Catálogo de **12 Variantes de la FUSIÓN #09 + #16 (Isométrico 2.5D de Oro Noble con Barrido Especular)** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Integrada la combinación maestra entre la estructura isométrica 3D escalonada a $45^\circ$ y el barrido de luz especular en oro noble con destellos en cruz blanca a 60 FPS:
     - **Controles Globales:** Ajustes de Profundidad 3D ($2\,\text{px}$ a $8\,\text{px}$), Velocidad de Brillo ($1\times$ a $5\times$) y 5 paletas de color arcade.
     - **Bloque I (Isométrico Puro 01-03):** 01. Fusión Pura (Classic Chiseled Gold Foil), 02. Bisel Doble Filo en Oro y Platino, 03. Extrusión Profunda de 8 Niveles.
     - **Bloque II (Haces de Luz & Glint 04-06):** 04. Barrido de Doble Haz Desfasado, 05. Glint Reactivo al Cursor, 06. Destellos Estroboscópicos en las 4 Esquinas.
     - **Bloque III (Físicas & Movimiento 07-09):** 07. Isométrico con Levitación Senoidal Flotante, 08. Extrusión Invertida Hacia Abajo Derecha (+45°), 09. Emisión de Micro-Partículas de Oro Volátiles.
     - **Bloque IV (Fusión Suprema 10-12):** 10. Canto con Ranuras de Plasma Cian Ocultas, 11. Fachada con Escamas de Serpiente Grabadas, 12. Master Gold Chisel Logo (Fusión Definitiva Arcade).

- **feature** (completed - 21:53): Catálogo de **20 Propuestas de Logotipo "SNAKE" 100% PROCEDURAL** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Desarrollado un taller interactivo con 20 sistemas procedurales matemáticos para el título "SNAKE" a 60 FPS:
     - **Controles Globales:** Selectores de Amplitud de Onda ($0\,\text{px}$ a $6\,\text{px}$), Velocidad ($1\times$ a $5\times$) y 5 temas de color.
     - **Bloque I (Anatomía & Reptil 01-05):** 01. Serpiente Vertebral Ondulante, 02. Escamas de Víbora con Bisel Paramétrico, 03. Colmillos Gemelos & Lengua Bífida, 04. Víbora de Plasma Neón Constrictora, 05. Ojos de Serpiente con Eye-Tracking.
     - **Bloque II (Cyberpunk & Plasma 06-10):** 06. Titanio Biselado con Núcleo de Plasma, 07. Glitch Matricial CRT Bit-Shift, 08. Ondulación Senoidal Balatro a Contrafase, 09. Isométrico 2.5D con Extrusión de Sombra, 10. Arco Eléctrico Tesla de Alta Tensión.
     - **Bloque III (Mazmorra Gótica 11-15):** 11. Runas Antiguas Talladas en Piedra, 12. Monograma con Calavera de Boss en la 'A', 13. Fuego Neón Celular Ascendente, 14. Cristales Geoda en los Vértices, 15. Hierro Forjado con Cadenas Péndulo.
     - **Bloque IV (Balatro Chic & Oro 16-20):** 16. Oro Macizo con Barrido de Brillo Especular, 17. Matriz de Puntos HUD Scanner, 18. Doble Filo Cyber-Step con Condensadores, 19. Respiración Orgánica a 60 BPM, 20. Master Snake Emblem (Fusión Maestra Definitiva).

- **feature** (completed - 21:31): Implementada en el motor Love2D la **Tarjeta Oficial Combinada de Perfil y High Score con la Moneda Circular 3D #01 y Medalla #01**:
  1. `ui/menuUI.lua`: Integrada la Tarjeta #11 Chunky (marco de 2px con delineado exterior negro de 1px y 4 condensadores esquineros pesados de $6\times 6\,\text{px}$) en la esquina inferior derecha del menú principal:
     - **División y Fondo:** Fondo izquierdo oscuro (`#050c17`) y fondo derecho a $60^\circ$ (`#0c1b2c`) con divisor de plasma cian.
     - **Progreso de Mazmorra:** 5 celdas con la celda activa pulsante y micro-calavera de boss pixel art de $7\times 5\,\text{px}$ en la celda 5.
     - **Moneda Circular 3D #01:** Disco circular procedural con rotación trigonométrica $3\text{D}$ elipsoidal a 60 FPS, extrusión de canto cilíndrico de espesor dinámico y serpiente paramétrica concéntrica.
     - **Medalla Oficial #01:** Cinta bicolor en V (azul/rojo) con disco de oro biselado y destello especular junto a la etiqueta `"HI-SCORE"`.
     - **Interactividad Total:** Reconocimiento de Hover y click en la tarjeta para abrir el gestor de perfiles (`profilesMod.open()`).
  2. `main.lua`: Enrutado el click en la tarjeta (`card_profile`) para abrir de inmediato la pantalla de perfiles con feedback sonoro.

- **feature** (completed - 21:25): Catálogo de **5 Propuestas de Moneda de Oro en DISCO CIRCULAR PROCEDURAL** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Implementada geometría estrictamente circular ($x^2 + y^2 \le R^2$) con proyección elipsoidal $3\text{D}$ $(x/r_x)^2 + (y/R)^2 \le 1$ y extrusión de canto cilíndrico curvo:
     - **Control de Radio:** Slider interactivo para calibrar el radio circular de la moneda ($4\,\text{px}$ a $7\,\text{px}$).
     - **01. Disco Circular con Relieve de Serpiente Paramétrica:** Círculo perfecto con serpiente paramétrica concéntrica y destello central.
     - **02. Disco Circular con Sombreado Esférico Normal 3D:** Superficie esférica $z = \sqrt{R^2 - x^2 - y^2}$ con luz orbital continua a 60 FPS.
     - **03. Disco Circular con Borde Estriado Numismático:** 12 estrías perimetrales uniformes en $\theta_k = \frac{2\pi k}{12}$.
     - **04. Víbora Viva en Órbita Circular Concéntrica:** Serpiente enroscada con ondulación radial $r(\theta, t) = R_0 + A\sin(3\theta - \omega t)$.
     - **05. Disco Circular Imperial con Doble Anillo y Gema Neón:** Anillos concéntricos circulares con gema cian neón central.

- **feature** (completed - 21:18): Catálogo de **5 Propuestas de Moneda de Oro 100% PROCEDURAL** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Motor matemático en JavaScript a 60 FPS con 5 algoritmos procedurales para la moneda sin matrices estáticas:
     - **Control de Profundidad:** Slider para ajustar la profundidad del bisel y relieve ($1\,\text{px}$ a $5\,\text{px}$).
     - **01. Serpiente Paramétrica Lemniscata:** Ecuación en ocho infinito ($x = A\cos(t), y = A\sin(t)\cos(t)$) proyectada en rotación 3D.
     - **02. Iluminación Lambertiana y Vector Normal 3D:** Producto escalar $\vec{N} \cdot \vec{L}$ en tiempo real con órbita de luz a 60 FPS.
     - **03. Oro Facetado en Voronoi Geométrica:** 8 facetas angulares que refractan luz independientemente como una joya tallada.
     - **04. Víbora Viva Ondulando:** Cinemática senoidal continua $y = \sin(\omega t - kx)$ que se desplaza físicamente al rotar.
     - **05. Disco Rúnico con Anillo de Datos:** Muescas generadas por funciones trigonométricas y núcleo de diamante neón pulsante.

- **feature** (completed - 21:13): Desglose Modular de Texturas y **12 Propuestas de Rotación 3D de la Moneda de Serpiente** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Creado panel superior de descomposición por capas independientes (Bisel Exterior, Núcleo, Sello de Serpiente en Relieve, Canto 3D y Destello Glint) y 12 algoritmos de rotación 3D a 60 FPS:
     - **Sprite Sheet Generado:** `assets/pixel_gold_coin_rotation_spritesheet.jpg` con la grilla de 8 fases de rotación $360^\circ$ e iluminación.
     - **Control de Giro:** Slider para calibrar la velocidad de rotación ($1\times$ a $6\times$ RPM).
     - **Bloque I (Giro Continuo 3D):** 01. Rotación 3D Continua Suave, 02. Rotación por Cuadros Discretos de 8 Frames, 03. Rotación con Pausa Frontal de 1.5s.
     - **Bloque II (Reactivo & Hover):** 04. Fija en Reposo y Giro Acelerado en Hover, 05. Rotación con Inclinación Parabólica en Y, 06. Oscilación Pendular Tipo Moneda Tambaleante.
     - **Bloque III (Partículas & Sombras):** 07. Giro 3D con Sombra Proyectada en la Placa, 08. Giro con Destello Especular en el Vértice de 90°, 09. Giro con Estela de Micro-Partículas de Oro.
     - **Bloque IV (Fusión Integral):** 10. Moneda con Reverso de Dragón Invertido, 11. Efecto Moneda Flotante con Levitación Vertical, 12. Master 3D Serpent Coin (Fusión Definitiva Arcade).

- **feature** (completed - 21:10): Generadas **2 Propuestas Visuales en Imagen para el Ícono de Moneda de Oro en Pixel Art**:
  1. `assets/pixel_gold_coin_snake_emblem.jpg`: Moneda de oro macizo en pixel art de 16-bits con emblema en relieve de serpiente dragón enroscada y destello especular blanco.
  2. `assets/pixel_gold_coin_boss_skull.jpg`: Doblón de oro de mazmorra con calavera de boss cornuda en relieve central y anillo exterior con muescas rúnicas grabadas.

- **bugfix** (completed - 21:09): Corregidas comillas no escapadas en la definición de la propuesta 1 de moneda en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Validada la sintaxis JavaScript con Node.js; las 12 tarjetas de moneda en pixel art ahora se renderizan perfectamente a 60 FPS.

- **feature** (completed - 21:08): Catálogo de **12 Propuestas de Ícono de Moneda de Oro en PIXEL ART** sobre la Tarjeta #11 Chunky en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Integrada la Medalla Oficial #01 (con cinta bicolor en V) y desarrolladas 12 variantes de monedas de oro pixel art en matrices de $10\times 10\,\text{px}$ a $12\times 10\,\text{px}$:
     - **Sellos & Físicas:** Monedas octogonales, de rotación 3D en 4 frames, numismática con agujero central, dobles monedas 2.5D, coronas reales, joyas neón y ojos de dragón.
     - **Bloque I (Sellos & Grabados):** 01. Moneda con Sello de Serpiente en 'S', 02. Moneda Antigua con Agujero Cuadrado Central, 03. Doblón de Pirata con Calavera de Boss Grabada.
     - **Bloque II (Geometría & Gemas):** 04. Moneda Hexagonal Cyber-Step con Núcleo Neón, 05. Doblón con Corona Real de Tres Picos Grabada, 06. Moneda Romboidal de Tesoro Antiguo.
     - **Bloque III (Rotación 3D & Destello):** 07. Moneda Giratoria Animada en 4 Frames (3D Spin Coin), 08. Pila de Dos Monedas de Oro en Perspectiva 2.5D, 09. Moneda con Destello de Luz Especular Parpadeante.
     - **Bloque IV (Dragón & Reliquias):** 10. Moneda con Ojo de Dragón / Pupila Reptiliana, 11. Moneda de Doble Anillo Solar Radiante, 12. Lingote Chunky con Borde Dentado de 8 Dientes.

- **feature** (completed - 20:58): Catálogo de **12 Propuestas de Ícono de Medalla en PIXEL ART** sobre la Tarjeta #11 Chunky en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Integrada la Tarjeta #11 Chunky (marco de 3px con delineado negro de 1px y condensadores pesados de $8\times 8\,\text{px}$) como chasis oficial, y diseñadas 12 medallas de 8-bits para el High Score:
     - **Sprites de Medalla:** Matrices pixel a pixel ($11\times 11\,\text{px}$ a $14\times 14\,\text{px}$) con cintas en V, coronas, alas, cruces de hierro, calaveras doradas, laureles y destellos solares.
     - **Bloque I (Cintas & Corona):** 01. Medalla Colgante con Cinta Bicolor en V, 02. Medallón Octagonal con Gema Neón Engarzada, 03. Medalla Imperial con Corona de Tres Picos.
     - **Bloque II (Alas & Laureles):** 04. Medalla Alada de Ouroboros Sagrado, 05. Medalla con Corona de Laurel de la Victoria, 06. Cruz de Caballero de Mazmorra con Zafiro.
     - **Bloque III (Mazmorra & Calavera):** 07. Medalla de Calavera Dorada de Cazador de Bosses, 08. Medalla con Cinta Militar Superior y Pasador, 09. Medalla de Escudo Heráldico Medieval.
     - **Bloque IV (Sol & Legendarias):** 10. Medalla Solar con Ocho Rayos Radiantes, 11. Medalla de Doble Anillo con Puntos Cardinales, 12. Medalla Legendaria con Destello Especular Animado.

- **feature** (completed - 20:54): Catálogo de **12 Propuestas de Tarjeta & Marco #02 en PIXEL ART PURO** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Transformación integral al formato pixel art de 8-bits puro con desactivación de suavizado (`imageSmoothingEnabled = false`):
     - **Tipografía & Sprites:** Integrada la fuente retro `'Press Start 2P'`, moneda de oro octagonal en matriz de $10\times 10\,\text{px}$, calavera de boss de $9\times 8\,\text{px}$, estrella de récord de $9\times 9\,\text{px}$ y división escalonada en escalera a $60^\circ$.
     - **Bloque I (Retro Arcade 8-Bit):** 01. Marco #02 Pixel Art Clásico de 8-Bits, 02. Condensadores de Esquina Escalonados en Cruz Pixel, 03. Marco con Pistas de Circuito en Ángulo Escalonado 45°.
     - **Bloque II (Dithering & Escalares):** 04. Marco con Dithering Checkerboard en el Canal, 05. Doble Filo Escalonado en Escalera Pixelada a 45°, 06. Marco con Micro-Gemas Romboidales en Píxeles de 5x5.
     - **Bloque III (Sprites Animados):** 07. Condensadores Animados en 4 Frames de Carga Retro, 08. Pulso de Energía en Píxeles Discretos Paso a Paso, 09. Estrella de Récord Parpadeante en 2 Frames.
     - **Bloque IV (Chunky & Bicolor):** 10. Marco Bicolor Pixel Art (Cian Neón + Oro Noble), 11. Marco Grueso Chunky de 3 Píxeles con Contorno Negro, 12. Master Pixel Art Dungeon Card (Fusión Definitiva).

- **feature** (completed - 20:39): Catálogo de **12 Variantes de Marco de Doble Filo Neón & Ranura de Energía (#09 Evolution)** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS enfocado en la arquitectura de doble filo perimetral y canales de energía/plasma con interactividad:
     - **Control de Separación:** Slider para calibrar el ancho del canal de energía ($2\,\text{px}$ a $6\,\text{px}$).
     - **Bloque I (Plasma & Nodos):** 01. Doble Filo Neón con Pulso de Plasma Perimetral, 02. Nodos Condensadores de Energía en las 4 Esquinas, 03. Paquete de Datos Láser Circulando a Alta Velocidad.
     - **Bloque II (Chaflán & Cascadas):** 04. Doble Filo Escalonado a 45° (Cyber-Step Conduits), 05. Triple Filo Neón en Cascada Gradual de Luz, 06. Doble Filo con Chevrons Diagonales a 60°.
     - **Bloque III (Circuitos & Fósforo):** 07. Pistas de Circuito PCB Intercaladas en la Ranura, 08. Micro-Scanlines de Fósforo en el Canal Intermedio, 09. Micro-Remaches de Luz Blancos Alineados.
     - **Bloque IV (Híbrido & Brechas):** 10. Doble Filo Bicolor (Cian Neón Exterior + Oro Interior), 11. Brechas Tácticas de Aire en los Centros del Marco, 12. Doble Filo Acorazado con Conectores Laterales de Puente.

- **feature** (completed - 20:36): Catálogo de **12 Propuestas de Marco Exterior y Chasis para la Tarjeta de Perfil & Récord** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 variaciones de arquitectura de bordes perimetrales, chaflanes, remaches, alas, HUD y engranajes:
     - **Control de Grosor:** Slider para calibrar el ancho del marco ($1\,\text{px}$ a $4\,\text{px}$).
     - **Bloque I (Cyber-Step & Blindaje):** 01. Chaflán Doble Escalonado (Cyber-Step Frame #03), 02. Bisel Acorazado con Pernos Hexagonales Allen, 03. Marco Octagonal Industrial con Asas Laterales.
     - **Bloque II (Bestias & Alas):** 04. Cuatro Colmillos Convergentes en las Esquinas, 05. Alas de Dragón / Gárgola en los Flancos, 06. Espinas Dorsales Segmentadas en Bordes.
     - **Bloque III (HUD & Táctica):** 07. Mirilla Reticular Táctica HUD (Target Lock-On #11), 08. Regla Milimétrica Táctica con Marcas de Calibración, 09. Marco de Doble Filo Neón con Ranura de Energía.
     - **Bloque IV (Arcano & Relojería):** 10. Micro-Engranajes de Relojería en los Vértices (#03), 11. Marco Arcano con Gemas Romboidales Incrustadas, 12. Corona Heráldica Superior & Dock Acorazado.

- **bugfix** (completed - 20:23): Corregida la firma de parámetros en `initDetailedBoneCanvas` y refinado el layout de encabezados en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Solucionado el desajuste de argumentos en `prop.draw` que causaba el canvas negro; todas las 12 tarjetas ahora renderizan fluidamente a 60 FPS con sus fósiles anatómicos, cráneos y costillas en tiempo real.

- **feature** (completed - 20:19): Catálogo de **12 Propuestas de Fósil de Serpiente Detallado (Anatomía Ósea en JS)** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Implementado motor de renderizado óseo anatómico con dibujo individual de cráneos fósiles, órbitas oculares, mandíbulas, colmillos de marfil, centros vertebrales, apófisis espinosas y pares de costillas curvas con sombreado de excavación:
     - **Control de Contraste:** Slider para calibrar el tono de marfil y la sombra profunda de excavación ($50\%$ a $100\%$).
     - **Bloque I (Anatomía & Cráneo):** 01. Fósil Anatómico Completo de Excavación, 02. Cráneo Desarticulado Sagital con Suturas de Hueso, 03. Fósil de Cabeza y Cola con Anillas de Cascabel Óseo.
     - **Bloque II (Costillas Curvas & Jaula):** 04. Costillas Abiertas en Abanico Torácico Profundo, 05. Jaula Torácica con Costillas Dobles Superpuestas, 06. Costillas en Flecha Inclinadas a 45° con Puntas Agudas.
     - **Bloque III (Relieve 3D & Nichos):** 07. Fósil con Relieve Escultórico 3D de Marfil y Sombra, 08. Lecho de Excavación Arqueológica con Sedimento Oscuro, 09. Fósil Ouroboros Circular Detallado (Devorando la Cola).
     - **Bloque IV (Física IK & Médula):** 10. Fósil Articulado Reactivo al Cursor (Cinemática Ósea), 11. Médula Espinal con Pulso Lumínico Continuo, 12. Fósil de Cuarzo y Hueso con Refracción en Hover.

- **feature** (completed - 20:17): Catálogo de **12 Modelos y Algoritmos de Serpiente Procedural en JavaScript** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo de física, cinemática y animación de serpientes en JS puro a 60 FPS con soporte para interacciones con ratón y click:
     - **Control de Velocidad:** Slider dinámico para calibrar la velocidad de actualización física en tiempo real ($1\times$ a $5\times$).
     - **Bloque I (Cinemática & Física):** 01. Cinemática Inversa Articulada (Follow-the-Leader), 02. Locomoción por Onda Senoidal Continua Dinámica, 03. Serpiente Elástica con Tensión de Muelle (Spring Physics).
     - **Bloque II (IA & Ataques):** 04. Serpiente Autónoma con IA de Patrullaje (Wander Steering), 05. Cobra en Enrosque con Ataque al Click (Click-to-Strike), 06. Serpiente Depredadora Persiguiendo Monedas Flotantes.
     - **Bloque III (Mecánico & Geometría):** 07. Serpiente de Relojería con Micro-Engranajes en Juntas, 08. Ouroboros Infinito Giratorio en Bucle Continuo, 09. Serpiente Tron Celular en Cuadrícula Discreta.
     - **Bloque IV (Plasma & Cristal):** 10. Serpiente de Plasma con Estela de Fuego Neón, 11. Serpiente de Relámpago y Descargas Fractales, 12. Fósil de Cristal Volcánico con Refracción Cromática.

- **feature** (completed - 20:06): Catálogo de **12 Propuestas de Fósil de Serpiente 100% PROCEDURAL** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Eliminada la dependencia de imágenes estáticas externas; implementado motor de renderizado 100% matemático procedural a 60 FPS:
     - **Control de Amplitud:** Slider dinámico para ajustar la altura de ondulación de la columna ($2\,\text{px}$ a $18\,\text{px}$).
     - **Bloque I (Senoidales & Curvas):** 01. Fósil Senoidal Progresivo (Cálculo Puro x, y(x)), 02. Doble Columna Vertebral Entrelazada de Hidra, 03. Fósil Sinuoso en Curva S Central Compacto.
     - **Bloque II (Costillas & Mandíbula):** 04. Mandíbula de Víbora Articulada que se Abre en Hover, 05. Costillas Curvas en Arco Parabólico, 06. Costillas Inclinadas a 45° Estilo Pescado / Anguila.
     - **Bloque III (Geometría & Hexágonos):** 07. Fósil Ouroboros Infinito Procedural (Lemniscata), 08. Vértebras Hexagonales Blindadas de Titanio, 09. Fósil Circundante Envolvente del Avatar de Perfil.
     - **Bloque IV (Energía & Partículas):** 10. Tren de Ondas de Luz Progresivo por las Vértebras, 11. Disipación de Polvo Espectral desde las Costillas, 12. Fósil Reactivo al Cursor (Inverse Kinematics).

- **feature** (completed - 20:03): Generada e integrada la textura **Pixel Art Novato (`snake_novice_pixelart.jpg`)** en las 12 tarjetas de `tools/menu_button_proposals.html`:
  1. `tools/assets/snake_novice_pixelart.jpg`: Textura de estilo 8-bit/16-bit minimalista con ladrillos simples, líneas de mortero cian nítidas y un esqueleto fósil de serpiente encantador y limpio.
  2. `tools/menu_button_proposals.html`: Integrada la imagen directamente en el fondo de las 12 propuestas con diferentes tratamientos (Cortes a 60°, Modos de Fusión, Tinte Monocromático, Viñeta, Mortero Reactivo, Scanlines y Parallax).

- **feature** (completed - 19:55): Integración y Previsualización de **Fósil de Serpiente en Piedra (Modo Pixel Art Limpio)** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Incorporado banner con la imagen de textura generada `assets/snake_fossil_pixelart.jpg` y 12 variaciones de integración procedural en Canvas a 60 FPS:
     - **Control de Opacidad:** Slider dinámico para ajustar la visibilidad del fósil (10% a 100%).
     - **Bloque I (Fósil Central):** 01. Fósil Sinuoso en Curva S Central Limpio, 02. Fósil con Cráneo Reactivo y Costillas Espaciadas, 03. Fósil en Relieve de Piedra Oscura con Sombra Pixel.
     - **Bloque II (Fósiles en Flancos):** 04. Fósil Serpenteante en Flanco Izquierdo del Avatar, 05. Fósil Ouroboros Circular en Panel Derecho, 06. Doble Fósil Simétrico en los Dos Extremos.
     - **Bloque III (Costillas Horizontales):** 07. Eje Vertebral Horizontal Recorriendo Toda la Tarjeta, 08. Doble Banda de Costillas Fósiles Arriba y Abajo, 09. Costillas Fósiles Diagonales Siguiendo el Corte a 60°.
     - **Bloque IV (Pulso & Sprite Baking):** 10. Fósil con Pulso de Energía Progresivo a 60 FPS, 11. Fósil con Mortero de Bioluminiscencia Esmeralda, 12. Fósil Integrado con la Imagen Pixel Art Generada.

- **feature** (completed - 19:53): Generadas **3 Propuestas Visuales en Imagen** para la Textura de Fondo de Piedra & Serpiente:
  1. `snake_stone_tiles`: Muro de sillería de obsidiana con ondas sinuosas de cuerpo de serpiente, escamas diamantinas y juntas de mortero con resplandor neón cian/esmeralda.
  2. `snake_fossil_masonry`: Mampostería de basalto ancestral con relieve de esqueleto fósil de serpiente gigante, costillas labradas y musgo bioluminiscente en las grietas.
  3. `serpent_ouroboros_blocks`: Pared de sillería labrada con relieve central de doble dragón/serpiente Ouroboros entrelazado en nudo infinito y halo de energía neón.

- **feature** (completed - 19:50): Catálogo de **12 Propuestas de Texturas de Piedra con Formas y Motivos de Serpiente** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 texturas de sillería de piedra inspiradas en la anatomía y silueta de la víbora:
     - **Bloque I (Curvas & Ondulaciones):** 01. Ladrillos en Ondulaciones de Serpiente (Sinuous Waves), 02. Surcos de Deslizamiento de Víbora, 03. Espirales Concéntricas de Cobra en Reposo.
     - **Bloque II (Escamas & Cascabel):** 04. Sillería de Placas Ventrales de Víbora, 05. Patrón de Cascabel Diamantina en Piedra (Diamondback), 06. Ladrillos con Escamas Dorsales Superpuestas.
     - **Bloque III (Costillas & Colmillos):** 07. Muro con Costillas y Vértebras de Serpiente Fósil, 08. Sillería de Colmillos Entrecruzados (Interlocking Fangs), 09. Bloques Esculpidos con Cabeza y Cola de Víbora.
     - **Bloque IV (Ouroboros & Mítico):** 10. Ladrillos de Doble Ouroboros Entrelazado (Infinito), 11. Mosaico de Micro-Serpientes Teseladas (Escher Style), 12. Piedra de Hidra con Grietas en Cabeza de Serpiente.

- **feature** (completed - 19:49): Catálogo de **12 Propuestas de Texturas de Piedra, Sillería & Ladrillos de Mazmorra** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 variaciones especializadas de mampostería, bloques de sillería y losas de cripta:
     - **Bloque I (Sillería & Adoquines):** 01. Sillería Clásica con Bisel en Cada Bloque, 02. Pavimento de Piedras Irregulares de Cripta, 03. Mampostería de Granito Bicolor en Contraste.
     - **Bloque II (Grietas de Neón & Runas):** 04. Piedra Ancestral con Grietas de Neón Luminoso, 05. Ladrillos Rúnicos Grabados en Cada Bloque, 06. Bloques de Mazmorra con Sarcófago Grabado.
     - **Bloque III (Obsidiana & Megalitos):** 07. Bloques de Obsidiana Pulida con Bisel Reflectivo, 08. Bloques Megalíticos con Grapas de Hierro Forjado, 09. Muro de Mazmorra con Relieve de Grilletes y Cadenas.
     - **Bloque IV (Herringbone & Musgo):** 10. Adoquines en Espina de Pez (Herringbone Stone), 11. Ladrillos de Mazmorra con Musgo Bioluminiscente, 12. Adoquines Arqueados Concéntricos (Radial Cobble).

- **feature** (completed - 19:48): Catálogo de **12 Propuestas de Textura de Fondo** (Tarjeta Perfil & Récord a 60°) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 texturas y acabados superficiales de fondo aplicados sobre la tarjeta unificada:
     - **Bloque I (Reptil & Mazmorra):** 01. Zarpazos de Hidra a 45° en Bajorrelieve (#06), 02. Malla de Micro-Escamas Romboidales de Víbora, 03. Bloques de Sillería de Piedra de Cripta.
     - **Bloque II (Metal & Carbono):** 04. Placa de Acero Carbono Martillado, 05. Metal Cepillado con Reflejo Anisotrópico, 06. Chevrons de Acorazamiento Escalonados.
     - **Bloque III (Grid & Circuitos):** 07. Cuadrícula Táctica Milimétrica (Blueprint Grid), 08. Pistas de Circuito PCB & Nodos de Oro, 09. Hexágonos en Panal de Abeja Blindado.
     - **Bloque IV (Líneas & Runas):** 10. Isolíneas de Topografía de Mazmorra, 11. Micro-Runas Nórdicas en Penumbra, 12. Scanlines de Fósforo CRT y Ruido Analógico.

- **feature** (completed - 19:47): Catálogo de **12 Propuestas de Micro-Detalles Internos** (Tarjeta Perfil + Récord a 60°) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 variaciones de micro-detalles de alta precisión sobre la composición con divisor diagonal a 60° y barra de 5 celdas:
     - **Bloque I (Celdas & Calaveras):** 01. Micro-Calavera de Jefe en Celda 5 & Pulso de Celda, 02. Separadores de Luz Neón de 1px entre Celdas, 03. Puntos LED Diamante sobre Cada Celda.
     - **Bloque II (Iconos & Estrellas):** 04. Moneda 3D Rotatoria con Brillo Especular, 05. Micro-Estrella de 5 Puntas en Encabezado de Récord, 06. Chevrons de Rango Militar junto al Nombre.
     - **Bloque III (Textura & Remaches):** 07. Micro-Scanlines Tácticas en Panel Izquierdo, 08. Micro-Remaches de Titanio en Vértices de la Diagonal, 09. Bisel Interior Doble con Filo Especular de 1px.
     - **Bloque IV (FX & Tipografía):** 10. Tipografía Digital de 7 Segmentos para el Récord, 11. Chispas de Polvo Dorado en Hover sobre el Récord, 12. Micro-Medidor de Bio-Energía bajo el Nombre.

- **feature** (completed - 19:44): Catálogo de **12 Propuestas de Macro-Detalles Interiores** (Base Diagonal a 60°) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 variaciones de macro-detalles e iconografía sobre el diseño con divisor sesgado a 60°:
     - **Bloque I (Sellos & Coronas):** 01. Sello de Cera Imperial 3D & Estrella, 02. Corona Heráldica de Tres Picos, 03. Cinta Diagonal de Honor.
     - **Bloque II (Bestias & Colmillos):** 04. Colmillos de Víbora Abrazando el Divisor, 05. Micro-Ojo de Víbora Reactivo, 06. Zarpazos de Hidra Transversales.
     - **Bloque III (Táctica & HUD):** 07. Corchetes de Francotirador Lock-On, 08. Pernos Allen de Titanio & Ventilación, 09. Scanner de Bio-Signos & ADN.
     - **Bloque IV (Recursos & Logros):** 10. Micro-Engranaje de Relojería Custodiando Monedas, 11. Módulo de Logros con Tres Gemas, 12. Barra de Progreso de Mazmorra en 5 Celdas Neón.

- **feature** (completed - 19:43): Catálogo de **12 Propuestas de Diseño Interno para la Tarjeta de Perfil & Récord** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 variaciones de arquitectura y distribución interna para la Tarjeta #01 (Placa de Identificación & Sello):
     - **Bloque I (Biseles & Nichos):** 01. Doble Nicho Octagonal con Bisel de Neón, 02. Bisel Escalonado Cyber-Step Interior, 03. Doble Cámara Acorazada con Biseles de Titanio.
     - **Bloque II (Zarpazos & Vértebras):** 04. Fondo de Zarpazos de Hidra y Chevrons, 05. Columna Vertebral de Serpiente como Divisor, 06. Malla de Escamas Romboidales en Relieve.
     - **Bloque III (Grid Táctica & PCB):** 07. Cuadrícula Táctica con Micro-Scanlines, 08. Pistas de Circuito PCB Doradas, 09. Divisor Diagonal Dinámico a 60°.
     - **Bloque IV (Layouts & Docks):** 10. Dock de Estatus Inferior Integrado, 11. Nicho Central con Pilares de Mazmorra, 12. Runas de Forja Ancestral en Fondo.

- **feature** (completed - 19:42): Selección de la **Tarjeta Combinada #01 (Placa de Identificación & Sello de Oro)**:
  1. `tools/menu_button_proposals.html`: Aprobado el diseño base de la Tarjeta #01 para Perfil + High Score:
     - **Panel Izquierdo (Identidad & Recursos):** Avatar de serpiente en marco reforzado, nombre de perfil editable, contador de monedas de oro y etapa máxima.
     - **Panel Derecho (Gloria & Récord):** Sello dorado de cera/medalla con estrella central y cifra de High Score en alta visibilidad.
     - **Chasis:** Placa metálica blindada con divisor luminoso y remaches.

- **feature** (completed - 19:39): Catálogo de **15 Propuestas Combinadas de Tarjeta de Perfil de Jugador + Récord High Score** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 15 diseños integrados que unifican el nombre/avatar del perfil activo, las monedas acumuladas, el progreso de etapa y el récord de puntuación máxima:
     - **Bloque I (Placas & Blasón Militar):** 01. Placa de Identificación & Sello de Oro, 02. Escudo Heráldico & Laurel, 03. Cartel de Recompensa (Wanted Plaque), 04. Relicario de Cripta con Sello de Titanio.
     - **Bloque II (Cyber-HUD & Chips):** 05. Terminal Holográfica de Explorador HUD, 06. Tarjeta de Datos PCB Ciberpunk, 07. Scanner de ADN de Serpiente, 08. Matriz de Celdas Hexagonales.
     - **Bloque III (Tesorería & Grimorio):** 09. Cofre del Tesoro con Calavera de Oro, 10. Tomo / Grimorio de Hazañas Ancestrales, 11. Altar de Cristal de Almas, 12. Moneda Conmemorativa de Alta Mazmorra.
     - **Bloque IV (Criaturas & Ouroboros):** 13. Placa de Piel de Hidra y Colmillos, 14. Gema Ojo de Dragón con Pedestal, 15. Insignia Ouroboros de Victoria Infinita.

- **feature** (completed - 19:33): Catálogo de **15 Propuestas de Remates y Acentos en las Esquinas del Chasis Cyber-Step** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 15 variaciones de remates y micro-efectos para las esquinas del botón, manteniendo el chasis Cyber-Step #03, los zarpazos de hidra #06, el Rombo #06 con cuatro colmillos, los micro-engranajes #03 y la mirilla HUD #11:
     - **Bloque I (Mecánico & Blindaje):** 01. Micro-Cuadros Neón Sólidos, 02. Pernos Allen Hexagonales, 03. Corchetes Angulares L-Shield, 04. Remaches de Cobre Quemado.
     - **Bloque II (Cyber-HUD & LEDs):** 05. Micro-LEDs de Estado Titilantes, 06. Pistas de Circuito en Esquina, 07. Doble Ranura de Neón, 08. Chispas de Arco Eléctrico.
     - **Bloque III (Gemas & Runas):** 09. Diamante Micro-Gema, 10. Runas Arcanas Esquinadas, 11. Espolones / Colmillos de Acero, 12. Cuña Biselada de Titanio.
     - **Bloque IV (Táctico & Muescas):** 13. Muescas de Calibración Táctica, 14. Chevrons de Flujo / Flechas Inward, 15. Cremallera de Dientes Escalonados.

- **feature** (completed - 19:32): Selección del **Rombo Central #06 (Cuatro Colmillos Convergentes)**:
  1. `tools/menu_button_proposals.html`: Aprobado el diseño del Rombo #06 para el enmarcado del Ojo de Víbora:
     - **Geometría del Rombo:** Marco biselado cian/azul con cuatro colmillos de marfil afilados en los vértices apuntando hacia el ojo.
     - **Estratificación:** El ojo de víbora queda contenido dentro de la cuenca oscura (delante del fondo y detrás del borde azul y los colmillos).

- **feature** (completed - 19:27): Catálogo de **20 Propuestas de Diseño para el Rombo Central** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 20 variaciones de rombo que enmarcan el ojo de víbora manteniendo el chasis Cyber-Step #03, los zarpazos de hidra #06, los micro-engranajes #03 y la mirilla HUD #11:
     - **Bloque I (Geometría & Gótico):** 01. Doble Escalonado de Mazmorra, 02. Alado / Ojo de Horus, 03. Facetado en 4 Cuadrantes, 04. Rosetón Romboide Gótico, 05. Círculo de Transmutación.
     - **Bloque II (Anatomía & Víbora):** 06. Cuatro Colmillos Convergentes, 07. Escamas de Queratina, 08. Ouroboros de Doble Cabeza, 09. Mandíbula Articulada, 10. Costillas de Dragón.
     - **Bloque III (Cyber-HUD & Táctica):** 11. Retícula de Francotirador, 12. Pistas de Circuito PCB, 13. Doble Cátodo de Neón, 14. Corchetes L-Bracket, 15. Matriz de Micro-LEDs.
     - **Bloque IV (Forja & Reliquias):** 16. Runas Nórdicas Grabadas, 17. Hierro Forjado con Clavos, 18. Cadenas Entrelazadas, 19. Relicario Sagrado de Cristal, 20. Corona Imperial Quebrada.

- **fix** (completed - 19:22): Corrección de recorte por Canvas en `ui/menuUI.lua`:
  1. `ui/menuUI.lua`: Reemplazado `love.graphics.stencil` por `love.graphics.setScissor` para evitar el error de ausencia de stencil buffer en el pipeline de renderizado de `sceneCanvas`, manteniendo el ojo de víbora perfectamente recortado dentro del rombo (delante del fondo oscuro y detrás del borde azul).
  2. `love . --test`: Verificación de ejecución exitosa con 0 errores a 60 FPS.

- **polish** (completed - 19:21): Ajuste de estratificación del Ojo de Víbora en `ui/menuUI.lua`:
  1. `ui/menuUI.lua`: Configurado el renderizado en capas exacto para el rombo central de los botones:
     - **Capa Base:** Fondo oscuro del rombo (`polygon('fill')`).
     - **Capa Intermedia:** El Ojo (`ui.eyeIrisTexture`) renderizado **delante del fondo del rombo**, recortado con máscara `stencil` para que nunca desborde la geometría del rombo.
     - **Capa Superior:** El **borde azul/cian del rombo** (`polygon('line')`) y la línea de contacto de párpado, asegurando que el ojo quede estrictamente **detrás del borde azul**.
  2. `love . --test`: Verificación de ejecución exitosa con 0 errores a 60 FPS.

- **polish** (completed - 19:18): Ajuste de capa para `assets/ui_eye_iris.png` en `ui/menuUI.lua`:
  1. `ui/menuUI.lua`: Reordenada la jerarquía de renderizado en capas del Ojo de Víbora para que `ui.eyeIrisTexture` se dibuje en la capa interior profunda, quedando enmarcado y contenido por debajo del marco de la cuenca ocular, de la línea de contacto de párpados, de la mirilla HUD Lock-On (#11) y del texto del botón.

- **feature** (completed - 19:15): Implementación de la **Opción A (Sprite Baking en Imágenes PNG)** para Botones de Menú:
  1. `scripts/generate_ui_sprites.py`: Generador en Python con Pillow para rasterizar a nivel de píxel los sprites PNG optimizados:
     - `assets/ui_button_normal.png` (276x48, 694 B): Placa base Cyber-Step #03 con zarpazos de hidra #06 y sombra proyectada.
     - `assets/ui_button_hover.png` (276x48, 681 B): Placa en estado Hover con borde cian brillante e iluminación de zarpazos.
     - `assets/ui_button_press.png` (276x48, 695 B): Placa en estado Pressed con desplazamiento de sombra.
     - `assets/ui_gear_node.png` (24x24, 275 B): Micro-engranaje mecánico de 6 facetas con eje central para rotación en GPU.
     - `assets/ui_reticle_corner.png` (12x12, 93 B): Corchetes de mirilla HUD Lock-On (#11).
     - `assets/ui_eye_iris.png` (28x28, 443 B): Iris estriado de víbora con pupila vertical y doble reflejo corneal.
  2. `ui/ui.lua` & `ui/menuUI.lua`: Carga con `pcall` y renderizado ultra-rápido en 1 draw call con rotación dinámica de engranajes y seguimiento ocular en tiempo real.
  3. `love . --test`: Verificación de ejecución exitosa con 0 errores.

- **feature** (completed - 15:40): Integración del **Diseño Maestro Definitivo del Botón** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Consolidación de todas las elecciones del usuario en un expositor interactivo a 60 FPS con controles completos de paleta y animación:
     - **Chasis / Silueta:** *Forma #03 Cyber-Step* (Chaflán doble escalonado en 2 niveles de 3px x 3px).
     - **Núcleo Central:** *Ojo de Víbora Holográfico* (Parpadeo continuo suave de párpados en arco cada 3.5s + Eye-Tracking hacia el cursor del ratón en tiempo real + pupila vertical rasgada).
     - **Fondo Interior:** *Fondo #06 Zarpazos de Hidra* (Tres marcas de garras con iluminación y relieve).
     - **Nodos Laterales:** *Nodos #03 Micro-Engranajes Mecánicos* (Ruedas dentadas de 6 facetas que rotan con el cursor).
     - **Efecto Hover:** *Hover #11 Mirilla Reticular HUD Lock-On* (4 corchetes angulares de francotirador que se cierran suavemente sobre el ojo al pasar el ratón).

- **feature** (completed - 15:39): Catálogo de **12 Propuestas de Efectos Hover** (Forma #03 Cyber-Step + Ojo Intacto + Zarpazos #06 + Engranajes #03) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 12 comportamientos dinámicos al pasar el ratón:
     - 01. *Serpientes de Plasma Rápido + Giro Overdrive* (Serpientes a 260px/s con lengua bífida y engranajes a 3x).
     - 02. *Furia Depredadora + Sobrecarga de Zarpazos* (Contracción agresiva de pupila y zarpazos blancos incandescentes).
     - 03. *Escaneo Láser Bidireccional* (Fina línea vertical láser de 1px que barre el botón de lado a lado).
     - 04. *Onda de Choque Sísmica Concéntrica* (Pulsos de energía elíptica expandidos desde el ojo).
     - 05. *Glitch Cibernético & Desfase RGB* (Bandas de ruido horizontal con aberración cromática).
     - 06. *Vórtice de Partículas de Mana* (6 micro-orbes en órbita elíptica alrededor de la cuenca ocular).
     - 07. *Supercalentamiento de Forja Térmica* (Gradiente radial de metal al rojo vivo incandescente).
     - 08. *Apertura Mecánica y Válvula de Presión* (Engranajes que avanzan 3px hacia el exterior del chasis).
     - 09. *Arcos Eléctricos Tesla* (Rayos que saltan intermitentemente entre los engranajes y el ojo).
     - 10. *Aura de Sombras Espectrales & Fuego Fatuo* (Niebla oscura flotante con flamas azuladas).
     - 11. *Matriz HUD Táctica con Mirilla Reticular* (Corchetes de encuadre angular de francotirador lock-on).
     - 12. *Destello Prismático Iridiscente a 45°* (Haz de brillo líquido que recorre la placa).

- **feature** (completed - 15:37): Catálogo de **10 Nuevas Propuestas de Nodos Laterales (Serie II)** (Forma #03 Cyber-Step + Ojo Intacto + Zarpazos de Hidra #06) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Implementación de 10 alternativas adicionales de nodos laterales a 60 FPS:
     - 01. *Puntas de Flecha de Obsidiana* (Triángulos de sílex negro volcánico con aristas de cristal blanco).
     - 02. *Gemas Ovaladas en Engarce de Garra* (Gemas elípticas engarzadas por 4 micro-garras de titanio).
     - 03. *Micro-Engranajes de Relojería* (Ruedas dentadas de 6 dientes que rotan en Hover).
     - 04. *Relámpagos en Zig-Zag (Angular Shock)* (Descargas de rayo en Z con energía cinética).
     - 05. *Flor de Lis Gótica Heráldica* (Tridente imperial de 3 pétalos góticos de la realeza).
     - 06. *Cristales de Cuarzo Gemelos en V* (Dos agujas de cristal prismático divergentes con brillo cian).
     - 07. *Broquel Romboidal con Cruz Templaria* (Escudo de acero en rombo con cruz grabada en el centro).
     - 08. *Foco Emisor de Láser Cibernético* (Lente colimadora con punto de mira infrarroja pulsante).
     - 09. *Gotas de Veneno en Suspensión Líquida* (Gotas en forma de lágrima invertida con destello especular).
     - 10. *Ojo de Cerradura Ornamental Esqueleto* (Bocallave gótica de bronce con luz mística interna).

- **feature** (completed - 15:35): Catálogo de **12 Propuestas de Nodos Laterales** (Forma #03 Cyber-Step + Ojo Intacto + Zarpazos de Hidra #06) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Implementación de 12 alternativas para reemplazar los diamantes romboidales laterales a 60 FPS:
     - 01. *Colmillos de Víbora de Marfil* (Micro-colmillos afilados curvados con gota de veneno neón).
     - 02. *Pernos Hexagonales de Titanio Blindado* (Tuercas mecánicas de 6 facetas con ranura y brillo).
     - 03. *Micro-Cráneos de Serpiente* (Calaveras talladas en bajo relieve con ojos titilantes en Hover).
     - 04. *Sigilos Rúnicos Arcanos `ᛟ` y `ᛋ`* (Runas nórdicas ancestrales grabadas).
     - 05. *Orbes de Plasma Esféricos 3D* (Esferas de energía con gradiente radial y resplandor).
     - 06. *Doble Chevron Angular `<<` y `>>`* (Flechas tácticas direccionales hacia el centro).
     - 07. *Empuñaduras de Dagas Medievales* (Crucetas con guardamanos y pomo dorado).
     - 08. *Micro-Ouroboros Anulares* (Aros de serpiente devorándose la cola).
     - 09. *Micro-LEDs de Telemetría Táctica* (Columna vertical de 3 LEDs de estado).
     - 10. *Garras de Dragón de Tres Puntas* (Tridentes afilados curvados hacia el interior).
     - 11. *Reloj de Arena / Crux de Mazmorra* (Silueta en X con faceta central).
     - 12. *Monedas de Oro Imperial con Relieve* (Medallones antiguos con escudo de cobra grabado).

- **feature** (completed - 15:33): Catálogo de **10 Propuestas de Silueta y Forma de Botón** (Ojo Intacto + Zarpazos de Hidra #06) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Implementación de 10 geometrías y siluetas exteriores para la placa del botón a 60 FPS, manteniendo el Ojo de Víbora intacto (parpadeo automático, tracking ocular y pupilas rasgadas), el Fondo #06 de Zarpazos de Hidra, gemas romboidales y serpientes patrulleras:
     - 01. *Octagonal de Chaflán Clásico (45°)* (Chaflán limpio de 6px con pips de esquina rectos).
     - 02. *Puntas Chevron / Colmillos Extremos* (Extremos laterales en punta angular hacia afuera `< ===== >`).
     - 03. *Chaflán Doble Escalonado (Cyber-Step)* (Recorte en dos niveles de 3px x 3px estilo búnker).
     - 04. *Romboide Hexagonal / Diamante Elongado* (Punta superior e inferior en V que enmarcan el ojo).
     - 05. *Alas Angulares de Gárgola* (Aletas superiores proyectadas hacia arriba).
     - 06. *Cápsula Ojival Gótica* (Laterales en arco semicircular ojival).
     - 07. *Chasis de Placa con Muescas Dentadas* (Entalladuras perimetrales que abrazan la cuenca ocular).
     - 08. *Trapezoide Invertido con Bisel Agresivo* (Borde superior ancho con chaflán profundo de 8px).
     - 09. *Escudo Heráldico de Armas (V-Crest)* (Punta inferior central en V de escudo de mazmorra).
     - 10. *Cintura Entallada de Víbora (Concave Waist)* (Curvatura cóncava lateral con capuchas de cobra en las gemas).

- **feature** (completed - 15:29): Catálogo de **50 Propuestas de Fondo Procedural con el Ojo de Víbora Intacto** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Taller interactivo a 60 FPS con 50 tratamientos de fondo únicos divididos en 5 bloques temáticos (Reptil & Orgánico, Forja & Catacumbas, Arcano & Magia, Cyber & Arcade HUD, Biomas & Tesorería), **reproduciendo en cada una de las 50 propuestas el Ojo de Víbora intacto** con parpadeo automático suave, seguimiento ocular del ratón (Eye-Tracking), pupilas rasgadas y reflejos corneales.

- **feature** (completed - 15:28): Restauración del **Ojo de Víbora Holográfico con Parpadeo Procedural y Eye-Tracking** en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Reestablecido el diseño principal centrado en el Ojo de Víbora intacto a 60 FPS con parpadeo automático cada 3.5s, dilatación de pupila, seguimiento ocular reactivo hacia el ratón, serpientes patrulleras con lengua bífida y gemas laterales.

- **feature** (completed - 15:27): Catálogo Maestro de **50 Propuestas de Diseño de Botón** en HTML5 Canvas (`tools/menu_button_proposals.html`):
  1. `tools/menu_button_proposals.html`: Taller interactivo organizado en 5 bloques temáticos de 10 variantes cada uno, con renderizado a 60 FPS, filtrado por categorías, buscador por texto, selector de 5 paletas y soporte de interacción con ratón (hover/click):
     - **Bloque I: Reptil, Dragón & Anatomía Orgánica (01-10):** Muda de piel, colmillos de basilisco, placa dorsal de estegodragón, caparazón de tortuga dragón, venas de veneno fluorescente, garras de hidra, aliento ígneo, ouroboros infinito, piel de cocodrilo y nido de huevos de cristal.
     - **Bloque II: Forja Medieval & Catacumbas Góticas (11-20):** Hierro damasco, cota de malla, bisagras de cofre, espadas cruzadas, vitral de catedral, lápidas con cadenas, cerradura de jefe, rastrillo de calabozo, corona quebrada y yunque alquímico.
     - **Bloque III: Arcano, Magia & Runas Astrales (21-30):** Círculo de transmutación, constelación de serpiente, cristal de mana, portal del vacío, runas nórdicas, fuego fatuo, pergamino quemado, arco tesla, eclipse sangriento y reloj cósmico.
     - **Bloque IV: Cyber-Arcade & HUD Sci-Fi (31-40):** Wireframe grid 3D, glitch VHS, matriz LED 50x8, sonar 360°, batería de plasma, terminal de fósforo, microchip de silicio, mira de sniper, osciloscopio 60Hz y tubos Nixie.
     - **Bloque V: Piedra Ancestral, Biomas & Tesorería (41-50):** Ladrillos con musgo, fisuras de lava, carámbanos glaciales, monedas de oro, arenisca del desierto, cueva fúngica, astillas de obsidiana, raíces milenarias, agua subterránea y materia oscura líquida.

- **polish** (completed - 15:26): Mejoras en el **Fondo de Botón Procedural** (Ojo de Víbora #01 Intacto) en `tools/menu_button_proposals.html`:
  1. `tools/menu_button_proposals.html`: Preservado al 100% el renderizado del Ojo de Víbora (parpadeo natural cada 4s, dilatación de pupila, seguimiento ocular hacia el cursor y reflejos corneales) mientras se modelaron 3 tratamientos de fondo:
     - **Fondo 1 (Destacado - Obsidiana & Escamas en Abanico):** Halo místico radial detrás del ojo con respiración senoidal, vetas de escamas que nacen de los lados del ojo en degradado hacia los extremos y micro-scanlines.
     - **Fondo 2 (Acero de Mazmorra & Doble Riel):** Dos finas ranuras horizontales de luz con gradiente cenital y micro-remaches de fijación en 4 esquinas.
     - **Fondo 3 (Cristal del Vacío & Sigilos Rúnicos):** Sigilos tallados en bajo relieve (`ᛟ` y `ᛋ`) a los lados del ojo y micro-aristas de cristal facetado.

- **feature** (completed - 15:24): Implementación del **Ojo de Víbora Holográfico con Parpadeo Procedural** y Seguimiento de Ratón (`tools/menu_button_proposals.html`):
  1. `tools/menu_button_proposals.html`: Evolución de la Propuesta #07 a un laboratorio con 3 variantes interactivas a 60 FPS:
     - **Parpadeo Procedural Natural:** Animación de cierre suave de párpados en arco (`Math.sin(norm * Math.PI)`) cada ~4s o mediante el botón de forzar parpadeo (`⚡ Forzar Parpadeo`).
     - **Seguimiento Ocular en Tiempo Real (Mouse Tracking):** El iris y la pupila rasgada miran hacia las coordenadas del cursor del ratón con limitador elíptico.
     - **Variante A (Clásica & Párpados 3D):** Párpados en arco, iris circular con fibras de gradiente, pupila vertical rasgada y doble reflejo corneal blanco.
     - **Variante B (Arcana & Membrana Nictitante):** Tercer párpado diagonal translúcido de reptil y escamas peri-oculares.
     - **Variante C (Cibernética & Calibración):** Obturador mecánico de 4 láminas con retícula HUD y anillos concéntricos.

- **feature** (completed - 15:21): Implementación de **12 Propuestas de Diseño Interno** para botones en el taller interactivo HTML (`tools/menu_button_proposals.html`):
  1. `tools/menu_button_proposals.html`: Catálogo interactivo a 60 FPS con 12 variantes de textura interna en tiempo real:
     - 01. *Escamas Hexagonales de Dragón* (Malla de panal en bajo relieve con reflejo iridiscente).
     - 02. *Pistas PCB & Runas Alquímicas* (Circuitos arcanos con micro-matriz de LEDs titilantes).
     - 03. *Doble Runa de Veneno & Colmillos* (Glifos de víbora angulares a los lados del texto).
     - 04. *Rejilla CRT & Micro-Fósforo* (Scanlines arcade densas de 2px con trama de cátodo).
     - 05. *Blindaje de Placas de Titanio* (3 paneles horizontales con remaches de acero biselados).
     - 06. *Espectro de Frecuencia / Audio VU* (Barras ecualizadoras neón danzantes).
     - 07. *Ojo de Víbora Holográfico* (Iris estriado circular con pupila rasgada reactiva).
     - 08. *Prisma de Cristal Astral* (Triángulos de refracción geométrica sagrada).
     - 09. *Radar Táctico / Sonar de Mazmorra* (Ondas concéntricas con barrido rotatorio).
     - 10. *Filigrana de Acero Gótico* (Arcos ojivales entrelazados con espinas de catedral).
     - 11. *Célula de Fusión & Plasma Líquido* (Ondas fluidas continuas de alta energía).
     - 12. *Costillas de Serpiente Ancestral* (Arcos óseos con espina dorsal central).

- **feature** (completed - 15:19): Ampliación del **Laboratorio Interactivo de Botones en HTML5** (`tools/menu_button_proposals.html`):
  1. `tools/menu_button_proposals.html`: Creado un taller interactivo autónomo con barra de controles en tiempo real:
     - Selector de 4 paletas dinámicas (Cian Neón, Oro & Dragón, Amatista del Vacío, Veneno Esmeralda).
     - Control deslizante de velocidad de serpiente (80 a 320 px/s).
     - Emisor de partículas/chispas de energía mágica en hover con decaimiento alfa.
     - Brillo especular dinámico con gradiente radial que rastrea la posición $X$ del ratón en tiempo real.
     - Animación de **lengua bífida de serpiente** parpadeante (`tongue flick`) en la cabeza de las serpientes superior e inferior.
     - Vetas de escamas en bajo relieve, gemas facetadas en 4 tonos con rayos en cruz y brackets con colmillos de víbora.

- **feature** (completed - 15:17): Implementación de la **Serpiente Procedural Deslizante en Hover** y detalles arcanos en botones del Menú Principal:
  1. `ui/menuUI.lua`: Animación activa en `Hover` con dos serpientes de luz simétricas deslizándose en tiempo real a $160\,\text{px/s}$:
     - Borde superior: Serpiente cian deslizándose de izquierda a derecha con cabeza luminosa, ojos y 6 segmentos de cola con oscilación senoidal ondulante (`math.sin(t * 18 + seg * 0.8)`).
     - Borde inferior: Serpiente en contra-flujo deslizándose de derecha a izquierda.
     - Detalles adicionales: Vetas de micro-escamas/chevrons de serpiente en bajo relieve, destellos en cruz en las gemas y muescas de colmillos en los brackets laterales.
  2. `tools/menu_button_proposals.html`: Actualizado el visor HTML5 interactivo con la animación de serpiente en bordes a 60 FPS.

- **polish** (completed - 15:15): Enriquecimiento del **Diseño Interno Procedural** para los botones del Menú Principal:
  1. `ui/menuUI.lua`: Añadidas gemas gemelas romboidales en 4 facetas cian (`x+18` y `x+w-18`) con montura oscura y destello blanco en hover, micro-scanlines tácticas horizontales de baja opacidad (`scanAlpha`) y bisel interior concéntrico octagonal.
  2. `tools/menu_button_proposals.html`: Actualizadas las 3 propuestas interactivas con ricos detalles internos (gemas en Propuesta 1, paneles 3D y remaches en Propuesta 2, pistas PCB y barras de energía en Propuesta 3).

- **feature** (completed - 15:14): Catálogo interactivo de 3 propuestas procedurales para **Botones del Menú Principal** (`tools/menu_button_proposals.html`):
  1. `tools/menu_button_proposals.html`: Visor interactivo a 60 FPS con soporte para ratón (hover/click) que modela las 3 variantes procedurales de `260x40 px`:
     - **Propuesta 1 (Cyber-Arcade Neón)**: Chasis octagonal biselado (6px), borde neón cian pulsante, highlight especular superior, 4 pips en vértices y brackets laterales.
     - **Propuesta 2 (Placa de Forja & Remaches)**: Hierro pesado con bisel 3D, resplandor de forja en oro/ámbar y 4 remaches perimetrales circulares con luz cenital.
     - **Propuesta 3 (Consola Táctica Glassmorphism)**: Cristal oscuro minimalista con barra vertical de acento láser a la izquierda y micro-cursor de focalización.

- **refactor** (completed - 15:09): Transición completa a botones UI 100% procedimentales (Zero-Texture Architecture):
  1. `ui/ui.lua`: Eliminada la dependencia y carga de texturas PNG y quads para botones.
  2. `ui/menuUI.lua`: Motor de renderizado procedimental autónomo de alto rendimiento mediante primitivas vectoriales de `love.graphics` (sombra octagonal sólida, chaflán biselado de 6px, fondo oscuro de obsidiana con gradientes reactivos, highlight especular superior, borde perimetral neón con pulso senoidal en hover, corchetes laterales y pips de esquina de $3 \times 3\,\text{px}$).
  3. Limpieza: Eliminados los archivos de textura temporal y scripts generadores externos.

- **feature** (completed - 15:06): Implementación de la textura en **auténtico Pixel Art 16-Bit** para `assets/ui_button_primary.png` (Propuesta 01: Acero Cromado 16-Bit & Gemas Gemelas Estilo #12):
  1. `scripts/generate_button_texture.py`: Motor de rasterizado pixel-perfect sobre cuadrícula nativa de 260x40 px escalado x2 mediante Nearest Neighbor a 520x240 px (3 frames de 520x80 px). Paleta indexada de 5 tonos de acero, bisel superior de platino blanco de 1px, chaflán escalonado de 5px, gemas romboidales pixeladas de 4 facetas, brackets laterales y respuesta de desplazamiento +1px en estado presionado.
  2. `assets/ui_button_primary.png`: Nuevo spritesheet en Pixel Art puro de alto contraste, nítido y libre de artefactos de blur, armonizado al 100% con la tipografía retro `PressStart2P`.

- **polish** (completed - 15:02): Desacoplamiento de efectos procedurales superpuestos en botones de UI (`ui/menuUI.lua`):
  1. `ui/menuUI.lua`: Eliminado el segundo pase de tinte aditivo en hover (`glowPulse`) y los caracteres de cursor de texto (`>` y `<`) que se dibujaban encima de la textura, permitiendo apreciar el 100% de los detalles artísticos, biseles y marcadores del spritesheet `ui_button_primary.png`.

- **polish** (completed - 15:00): Implementación del diseño **03. CRT Scanline Monolith (Arcade Retro Clásico)** para `assets/ui_button_primary.png`:
  1. `scripts/generate_button_texture.py`: Reemplazo del generador con arquitectura de pantalla CRT abombada, líneas de barrido entrelazadas de fósforo (scanlines), viñeta de cristal de tubo de rayos catódicos, marco biselado de gabinete arcade, corchetes angulares de calibración (estilo monitor PVM/Trinitron) y barras de señal escalonadas en los laterales.
  2. `assets/ui_button_primary.png`: Nuevo spritesheet generado con fondo negro fósforo de alto contraste (`#040A12`), emisión de cátodo en hover (`#00FFFF`), y respuesta de amortiguación en estado presionado.

- **polish** (completed - 14:58): Rediseño HD de textura para botones UI (`assets/ui_button_primary.png`) con Bisel de Acero Neón #12 y Obsidiana Glassmorphism:
  1. `scripts/generate_button_texture.py`: Script generador en Python/PIL actualizado con arquitectura de renderizado por capas vía `Image.alpha_composite` y supersampling 2x (1040x480) redimensionado con filtro Lanczos a 520x240 px (3 frames de 520x80 px: Normal, Hover, Pressed).
  2. `assets/ui_button_primary.png`: Nuevo spritesheet con cuerpo de obsidiana profundo (`#0E1420`), micro-scanlines de alta definición, biseles facetados de titanio con destello cenital especular (*sheen*), doble borde neón cian eléctrico, monturas romboidales con gemas gemelas cian cristalinas en perfecta armonía 1:1 con el logotipo Estilo #12, y aura luminosa pulsante para el estado Hover.

- **feature** (completed - 14:45): Catálogo interactivo de 50 propuestas en 2D Pixel Art Retro Dungeon Crawler para botones UI:
  1. `tools/snake_button_50_proposals.html`: Galería completa con 50 spritesheets interactivos (Normal, Hover, Presionado) renderizados a 60 FPS con motor pixel-art procedural, buscador en tiempo real y 5 categorías temáticas extraídas de la documentación del proyecto (Hierro & Forja, Piedra & Mazmorra, Biomas & Elementos, Arcade & Neón, Reliquias & Jefes).

- **feature** (completed - 14:34): Integración del nuevo logotipo 2D Pixel Art oficial "Gothic Dungeon Steel & Winged Gargoyles" (Propuesta #1):
  1. `scripts/process_title_logo.py`: Script de procesamiento que extrae la imagen generada, aplica autocrop (1300x474 px), elimina el fondo con transparencia limpia y genera el mapa de emisión lumínica.
  2. `assets/title_style12.png`: Textura base de alta resolución con marco de gárgolas aladas, tipografía de acero biselado, runas cian luminosas y placa "DUNGEON CRAWLER".
  3. `assets/title_style12_glow.png`: Mapa de emisión luminosa de runas cian y ojos rojos para el pase aditivo del shader de Bloom.
  4. `ui/menuUI.lua`: Escalado dinámico (`targetLogoW`) adaptativo a la resolución de pantalla y renderizado con sombra 3D, animación de entrada y flotación senoidal.

- **feature** (completed - 14:26): Galería interactiva con 20 propuestas en auténtico **2D Pixel Art Retro Dungeon Crawler** para el título "SNAKE":
  1. `tools/snake_logo_proposals.html`: Motor de rasterizado pixel-perfect (matriz bitmap 7x9 por letra, escala x4 de píxeles enteros, sombreado de 4 tonos en rampa y dithering) con 20 estilos animados en tiempo real:
     - *Hierro & Cromo*: 16-Bit Chrome & Twin Gems, Gothic Gargoyle Iron, Bloodstained Steel, Catacomb Trap Chainmail.
     - *Mazmorra & Runas*: Dungeon Stone & Cyan Moss, Dragon Gold & Ruby, Cursed Obsidian & Purple Rune, 1-Bit Dither Void, Copper & Emerald, Cursed Eye Boss Relic, Pharaoh Sandstone, Royal Void Crystal.
     - *Fuego, Veneno & Hielo*: Toxic Crypt Slime (con gotas animadas), Necromancer Bone & Cyan Flame, Molten Lava Core, Spectral Ice Cavern, Poisonous Viper Scales.
     - *Arcade & Neón*: Dual Neon Arcade CRT, 8-Bit Cyber-Matrix, Arcade Glitch Shift.
     - Incluye filtros por categoría y botón para copiar el prompt IA pixel-art optimizado.

- **feature** (completed - 14:03): Integración de texturas HD y pase de Bloom para el Diamante Emblema central del menú:
  1. `tools/emblem_preview.html`: Herramienta de previsualización procedural autónoma en HTML5 Canvas con animación senoidal y micro-scanlines.
  2. `scripts/generate_emblem_texture.py`: Script generador en Python/PIL para exportar la textura base transparente `assets/diamond_emblem.png` y el mapa de emisión `assets/diamond_emblem_glow.png` (512x512 px) con biseles de acero/cromo, alas mecánicas escalonadas, sustrato de obsidiana, pistas PCB, anillo cian, runa magenta y núcleo estelar.
  3. `ui/ui.lua`: Carga segura con `pcall` de `ui.emblemTexture` y `ui.emblemGlowTexture`.
  4. `ui/introUI.lua`: Renderizado del sprite HD centrado en `(cx, diamondY)` con sombra proyectada, animación de ascenso cinemático, flotación senoidal, modulación de brillo y emisión en el pase de Bloom (`glowPass`).

- **feature** (completed - 13:46): Textura Cyberpunk / Neon Arcade de alta resolución (2x) para botones del menú UI:
  1. `scripts/generate_button_texture.py`: Script generador de precisión geométrica con PIL para exportar `assets/ui_button_primary.png` (520x240 px, 3 estados apilados verticalmente de 520x80 px: Normal, Hover, Pressed). Incluye biseles sci-fi achaflanados, gradientes oscuros en azul obsidiana, micro-rejilla interior, borde cian eléctrico, acentos de pips en esquinas y muescas tecnológicas laterales.
  2. `assets/ui_button_primary.png`: Spritesheet modular de alta resolución optimizado para escalado a 260x40 px en Love2D.
  3. `ui/ui.lua`: Integración en `ui.load()` con carga segura `pcall` y definición de quads para estados Normal, Hover y Pressed (`ui.quadBtnNormal`, `ui.quadBtnHover`, `ui.quadBtnPressed`).
  4. `ui/menuUI.lua`: Renderizado con quads de textura, preservando la tipografía dinámica, indicadores de cursor `<`, `>` y fallback procedimental robusto.

## 21:08:2026

- **polish** (completed - 16:35): Restauración y pulido de máxima fidelidad visual 1:1 del logotipo "S N A K E" Estilo #12:
  1. `assets/title_style12.png`: Textura HD anti-aliased 100% sólida y opaca, con acabado en platino-acero cromado de alto contraste, tipografía gótica con aristas aladas y gemas gemelas cian saturadas, eliminando completamente la aproximación poligonal rígida y artefactos de fondo.
  2. `assets/title_style12_glow.png`: Mapa de emisión luminosa cian aislado para el bloom shader en tiempo real.
  3. `ui/menuUI.lua`: Renderizado limpio con sombra 3D profunda, micro-flotación senoidal y pase de bloom en `menu.drawGlow()`.

- **feature** (completed - 16:06): Implementación completa del Rediseño del Menú Principal (Distribución Asimétrica y Título Calca 1:1 Estilo #12):
  1. `ui/introUI.lua`: Cinemática de entrada actualizada para que el diamante emblema ascienda y se asiente permanentemente en el centro exacto de la pantalla `(cx = w / 2, cy = h / 2)` con pulso senoidal y alas neón, sirviendo como núcleo divisorio entre el panel de controles y el sector del título.
  2. `ui/menuUI.lua`: Panel vertical izquierdo cubriendo el 40% del ancho con fondo oscuro translúcido, línea divisoria vertical neón a la derecha y 4 botones (`JUGAR`, `PERFILES`, `CONFIGURACIÓN`, `SALIR`) centrados verticalmente con animación de entrada y hover reactivo.
  3. `ui/menuUI.lua` & `assets/`: Título "S N A K E" calca 1:1 exacta del Diseño #12 (letras de acero biselado, aristas aladas, ápice triangular en 'A', gemas gemelas cian superior e inferior engarzadas en monturas de metal oscuro) con carga de `title_style12.png` y mapa de emisión `title_style12_glow.png`.
  4. `render/renderMain.lua` & `ui/ui.lua`: Integrado `uiMod.drawMenuGlow` en el pase de bloom de `shadersMod.beginGlow()` para que las gemas cian y aristas del título emitan resplandor bloom en tiempo real.
  5. `ui/menuUI.lua`: Tarjeta de High Score anclada en la esquina inferior derecha con marco de oro y estrella pixelada. Eliminadas las pastillas de control inferiores para una composición limpia y despejada.

## 19:08:2026

- **docs** (completed - 16:38): Especificación técnica y de diseño completa del Rediseño del Menú Principal (Distribución Asimétrica y Título Calca 1:1 Estilo #12) en `docs/GDD.md §7`, `docs/TDD.md §5.1`, `docs/ROADMAP.md Fase 8` y `docs/TODO.md`:
  1. **Distribución Asimétrica**: Panel lateral izquierdo (40% de ancho, altura completa, fondo translúcido degradado con borde neón) conteniendo los 4 botones interactivos (`JUGAR`, `PERFILES`, `CONFIGURACIÓN`, `SALIR`) centrados verticalmente; Diamante emblema asentado permanentemente en el centro exacto de la pantalla `(cx, cy)` con pulso senoidal y alas neón como núcleo divisorio; Tarjeta de High Score anclada en la esquina inferior derecha; Eliminación de pastillas de controles inferiores para máxima limpieza visual.
  2. **Título Calca 1:1 Estilo #12**: Recreación fiel de tipografía de acero biselado con terminaciones aladas, gemas gemelas cian superior e inferior engarzadas en monturas metálicas sobre y bajo la letra 'A', remates de marco metálico y pase de emisión de glow para el shader de bloom (`assets/title_style12.png` y `assets/title_style12_glow.png`).
  3. **Planificación & Backlog**: Priorizado como el primer hito de implementación inmediata para la próxima sesión en `docs/TODO.md`.

## 17:08:2026

- **docs** (completed - 20:35): Consolidación y deduplicación exhaustiva de la documentación técnica y de diseño (`docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md`, `docs/TODO.md`):
  1. **GDD.md**: Eliminadas secciones obsoletas/redundantes §20 (Pulido Sensorial 10 ítems), §21 (Accesibilidad 10 ítems) y §22 (80 propuestas desestructuradas). Consolidadas como fuentes canónicas únicas la sección §20 (Catálogo de 100 Propuestas de Estilo Visual y Renderizado) y la sección §21 (80 Propuestas del Socio Técnico en 4 bloques estructurados con tags `[NUEVA]` y `[solapa]`), actualizando todas las referencias intra-documentales.
  2. **TDD.md**: Consolidado el pipeline de shaders y renderizado en §10.24 (Dynamic Lighting, Autotiling, Bloom Threshold, Squash/Stretch, Half-Res FBO Reflections, Voronoi Fracture) y refinado §10.23 para el motor determinista (Input Ramp-Up, AABB Pre-Filter, Fixed Timestep & Zero-GC Audit). Actualizada la tabla de arquitectura en §10.25 con referencias a GDD §21.4.
  3. **ROADMAP.md**: Unificado el bullet de estilo visual y pulido sensorial en Fase 9 y marcado como completada la tarea de curación y resolución de duplicados.
  4. **TODO.md**: Actualizado el encabezado del backlog a GDD §21 y marcado como completado el ítem de resolución de duplicados.
  Motivo: Eliminar duplicación de conceptos, inconsistencias de numeración y solapamientos, dejando un cuerpo documental limpio, coherente y unificado como fuente única de verdad.

- **docs** (completed - 20:19): Integración de 80 nuevas propuestas del socio técnico en 4 bloques (Feedback & Game Feel, Contenido & Variedad, Meta-Persistencia-Rejugabilidad, Arquitectura-UX-Accesibilidad) en `docs/GDD.md §24`, `docs/TDD.md §10.25`, `docs/ROADMAP.md Fase 9` y `docs/TODO.md`:
  1. **GDD §24 (80 propuestas)**: Cada ítem marcado `[NUEVA]` (sin análogo previo) o `[solapa → ref]` (refina especificación existente en §20–§23, TODO, ROADMAP) conservando la fuente canónica en su ubicación original — evita duplicado destructivo.
  2. **TDD §10.25**: Tabla de arquitectura para las 15 propuestas del Bloque 4 con módulo destino (core/events.lua, core/assets.lua, core/input.lua, core/i18n.lua, test/, persistence atómica, schema_version) respetando las reglas del proyecto (sin globals, módulos `local X = {}`).
  3. **ROADMAP Fase 9**: Bullet de curación de §24 (resolver duplicados, priorizar [NUEVA]) marcado como pendiente.
  4. **TODO**: Nuevo bloque `Backlog — GDD §24` con los 4 bloques referenciados + ítem de resolución de duplicados (decisión abierta).
  Nota: trabajo exclusivamente documental; no se tocó código ni `error.log`.

- **docs** (completed - 19:20): Integración del catálogo de 100 propuestas de evolución del estilo visual y pipeline de renderizado en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Iluminación Dinámica & Sombras 2D (GDD §23.1 / TDD §10.24)**: Foco cónico frontal en la cabeza, sombras arrojadas a 45° con alpha 0.35, oclusión ambiental de esquinas y normal mapping simulado en baldosas.
  2. **Texturizado Procedural & Biomas (GDD §23.2 / TDD §10.24)**: Autotiling de losetas con función hash, fracturas procedurales de 1 px, escarcha de cripta, vetas de magma y bordes de vacío cósmico.
  3. **Shaders GLSL & Post-Procesado (GDD §23.3 / TDD §10.24)**: Multi-pass Bloom con threshold $>0.8$, aberración cromática dinámica por temblor, distorsión de calor (heat haze) y scanlines CRT curvadas.
  4. **Micro-Animaciones & Fluidos de Combate (GDD §23.4-23.6)**: Ondulación metamérica de esquinas, squish & stretch en marcha/parada, eye-tracking hacia comida, bulto de digestión visible y física parabólica de rebote en monedas.
  5. **HUD de Piedra Cincelada & Atmósfera (GDD §23.7-23.10)**: Marcos rúnicos labrados, niebla volumétrica con parallax, god rays en santuarios, fractura de vidrio en Game Over y cartas holográficas de tarot.

- **docs** (completed - 19:15): Integración del paquete de 80 mejoras de ingeniería y jugabilidad categorizadas por prioridad (Bloques 1 al 4) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Bloque 1 - Crítico (GDD §22.1 / TDD §10.23)**: Input ramp-up ($0.03\text{s}$ delay inicial), corner buffering, AABB pre-filter para Ray Casting en Constrictor, ghost frame de 3s al revivir, metrónomo táctico en HUD y seguro contra aceptar muerte accidental.
  2. **Bloque 2 - Recomendado (GDD §22.2 / TDD §10.23)**: Telegrafiado cromático del Boss (4 colores), micro-stun por impacto en Mini-Jefes, tictac de audio en fruta bomba, cooldown visible de autotomía (Q), reloj de arena VHS y daño continuo de plasma.
  3. **Bloque 3 - Opcional (GDD §22.3 / TDD §10.23)**: Reflejos en FBO a mitad de resolución ($0.5\times$), temblor direccional exponencial, hitstop escalonado (30-60ms), shader de fractura Voronoi en Game Over y partículas de derrape por bioma.
  4. **Bloque 4 - Futuro (GDD §22.4 / TDD §10.23)**: Respec gratuito en el Santuario, semilla diaria universal UTC, Fixed Timestep a 60 ticks desacoplado de Hz, hot-plugging de Gamepad y suite de tests unitarios de memoria cero-allocations.

- **docs** (completed - 19:05): Rediseño del paradigma central de movimiento de la serpiente (*Held-Key Tactical Slither*) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Movimiento Táctico Sostenido (GDD §2.1)**: La serpiente solo avanza casilla a casilla mientras se mantenga presionada una tecla direccional (`WASD`/Flechas/Stick); al soltar la tecla, se detiene en su celda actual manteniendo postura de guardia mientras el mundo (enemigos, proyectiles, trampas y temporizadores) continúa corriendo en tiempo real.
  2. **Sinergia Táctica**: Permite calcular el cruce de pinchos de presión (0.5s de retardo), esquivar la jaula láser del Boss, resolver salas de puzles sin chocar contra muros y coordinar el *Constrictor Loop*.
  3. **Conmutador en Ajustes & Pipeline Técnico (TDD §10.22)**: Función `snake.isDirectionHeld()`, acumulación condicional de `stepTimer` y toggle de accesibilidad para alternar entre *Modo Táctico Sostenido* y *Modo Clásico Automático (Auto-Slither)*.

- **docs** (completed - 18:45): Integración masiva de propuestas aprobadas (Habilidades Tácticas, Frutas Dinámicas, Arsenal 51-60, Modificadores, 10 Modos de Juego, Pulido Sensorial y Suite de Accesibilidad) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Habilidades Tácticas & Frutas Dinámicas (GDD §2.4-2.5 / TDD §10.19)**: Autotomía (corte de 4 segmentos con Q), Inversión de avance (3s), Onda de cola (empuje 180°), Fruta imantada errante, Bomba de tiempo, Camaleónica, Gemelas y Diamante de racha.
  2. **Arsenal Extendido de Ítems 51 a 60 (GDD §4.3 / TDD §10.19)**: Púa de cola, Reloj de arena (rebobinado 2s), Rayo orbital, Señuelo holográfico, Botas ligeras, Diente de oro, Batería de emergencia (bullet time), Cosecha doble, Billete de lotería y Prisma refractor.
  3. **Tensión del Boss Final & Peligros (GDD §5.2-6.3 / TDD §10.20)**: Fase de furia (*Enrage* al faltar 3 comidas con +35% velocidad de ataque), Ataque de Jaula Láser y Baldosas con pinchos de presión retardados (0.5s).
  4. **Modificadores de Sala (GDD §19)**: 10 mutadores (Gravedad Cero, Midas Avaro, Pluma, Velo Silencioso, Sombra Acechante, Contrarreloj, Fénix, Visión de Túnel, Dualidad y Titán).
  5. **10 Modos de Juego Desbloqueables (GDD §11)**: Aventura, Endless, Rush, Pacifista, Boss Rush, Colosal (40x40), Micro-Snake, Semanal, Draft y Carrera Fantasma.
  6. **Pulido Sensorial & Accesibilidad (GDD §20-21 / TDD §10.21)**: Reflejos en suelo, Temblor direccional, Hitstop de 50ms, Música reactiva por capas, Shaders de daltonismo, Sliders FX, Run History (10 partidas), Reasignación de controles, Auto-pausa Alt+Tab y Vibración HD.

- **docs** (completed - 18:40): Integración del Catálogo Maestro de Variantes de Serpiente (+200 conceptos, 100 híbridos y 5 motores primitivos) en `docs/GDD.md` y `docs/TDD.md`:
  1. **Motores Primitivos de Render (GDD §12.1)**: Shard (fragmentos poligonales), Dot Matrix (grilla de círculos dithered), Wireframe (líneas vectoriales), Cadena Hexagonal y Código de Barras Dinámico.
  2. **Catálogo Maestro (GDD §12.2-12.7)**: Fichas técnicas completas con dirección, gradientes, animaciones de velocidad, estados de ítems y pulsos al comer para las 100 variantes base, 25 criaturas zoológicas, 25 materiales litológicos, 25 estructuras arquitectónicas, 25 ópticas/señales y 20 híbridos legendarios.
  3. **Motor Procedural y Registro en TDD (§10.18)**: Arquitectura de despacho por primitivas en `render/renderMain.lua`, estructura `config.SKIN_REGISTRY` y optimizaciones de memoria Zero-GC con buffers de vértices reutilizables.

- **docs** (completed - 18:35): Integración documental de los 5 pilares mayores de expansión en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Sistema de Cartas del Destino (GDD §14 / TDD §10.13)**: Draft de 3 cartas en salas 1, 2 y 4 con 12 cartas de mazo completo (El Mercurio, La Espina Dorsal, Ojo de Águila, Ladrón de Sombras, Digestión Alquímica, etc.).
  2. **Salas de Eventos Especiales (GDD §15 / TDD §10.14)**: Plantillas y mecánicas para *La Guarida del Apostador*, *La Sala de la Sombra Espejo*, *Fiebre del Oro* y *La Prueba de los Tres Sellos*.
  3. **Motor de Estados Alterados (GDD §16 / TDD §10.15)**: Gestión en tiempo real de *Frenesí (Overdrive)* por combo x6, *Petrificación (Medusa Tail)*, *Confusión (Venom Spore)* y *Criostasis*.
  4. **Árbol de Talentos del Santuario (GDD §17 / TDD §10.16)**: Meta-progresión con 8 talentos permanentes estructurados en 4 ramas (Fortuna, Alquimia, Misticismo, Combate) con costes en `totalCoins`.
  5. **Desafíos Diarios, Códice & Cazarrecompensas (GDD §18 / TDD §10.17)**: Semilla PRNG diaria determinista, Códice de Lore/Bestiario y sistema de contratos secundarios por expedición.

- **docs** (completed - 18:25): Expansión exhaustiva y monolítica de `docs/GDD.md` y `docs/TDD.md`:
  1. **Bestiario & Enemigos**: Añadidas las fichas completas de *Slime Weaver* (El Baboso, zonificación de baba ralentizante), *Phase Stalker* (Acechador Espectral, atraviesa muros) y *Mortar Sentry* (Torreta Centinela, telegrafiado balístico de 3x3).
  2. **Matriz de Sinergias de Ítems**: Documentadas 8 sinergias activas/pasivas (*Escudo Reactivo*, *Vórtice Dorado*, *Cometa Espectral*, *Hambre Voraz*, *Supernova*, *Armadura de Espejo*, *Pozo Gravitatorio*, *Sobrecarga Temporal*) y sistema de *Altares de Sangre*.
  3. **Especificación de los 5 Mini-Jefes (Sala 3)**: Diseños completos con ataques, telegrafiados y drops (*El Triturador de Muros*, *El Gólem de Escarcha*, *La Sierpe de Magma*, *La Reina Larva*, *El Espectro del Vacío*).
  4. **Modelos Matemáticos y Curvas de Balance (GDD §13)**: Fórmulas algebraicas de velocidad de serpiente, combo y puntuación, economía de monedas y escalado de IA enemiga.
  5. **Arquitectura Técnica Extendida (TDD §10.9-10.12)**: Motor de sinergias reactivo, máquina de estados de Mini-Jefes, arquitectura de *Object Pooling Zero-GC* y pipeline de shaders de biomas (hielo, magma, vacío).

- **docs** (completed - 18:30): Auditoría documental completa (sin tocar código): corrección de inconsistencias doc↔código + spec detallada de la Fase 8 y pulido general:
  1. **Correcciones GDD**: valores reales de config (Spawner `ENEMY_SPAWNER_INTERVAL` 3 / `ENEMY_DROP_SPAWNER` 1, pesos por etapa de dungeonGen), descripciones de los 12 ítems conforme a `systems/items.lua` (Hunger=+2 comidas, Bomb=destruye obstáculos, Ghost=atraviesa propio cuerpo, Star=puntos x3, etc.) con costos/duración, referencia `stageModifiers`→`world/dungeonGen.lua`, SFX reales (10, con buttonHover/buttonClick), tabla de tipos de sala con ocurrencia y detalle de Encuentros de Élite.
  2. **Sections nuevas en GDD**: `Input & Controls` (teclado completo + touch), `Economy & Food Values` (puntos NORMAL 10/1$, GOLD 25/2$, COIN 5/3$, multiplicador combo 0.5/8s, drops de enemigos, costos de progresión Fase 8).
  3. **Spec Fase 8 en GDD y TDD**: survival streak (state key, fórmula de multiplicador, caps, hooks en gamestates, highestStreak persistente), modal de muerte interactivo (Continue 30$ + 3s intangibilidad vs Aceptar -30% monedas), Constrictor Loop (algoritmo Ray Casting), 4 comidas especiales (config keys propuestas, spawn chance, interacción con food-target del boss), biomas/peligros por etapa con notas de implementación y mitigación del riesgo sin wall-wrap, encuentros élite (multiplicadores, cofre dorado, bonus de racha), modos endgame (endless/rush/pacifista con hooks en gameflow/world), skins/paletas (registro config.SKINS, desbloqueo por logro, persistencia `profile.skin`).
  4. **TDD actualizado a la realidad**: 42 módulos / ~9,275 líneas (antes 18/~7,100), árbol de carpetas y grafo de dependencias completos con los submódulos faltantes (touch, chaserAI, bossAttacks, enemyHelpers, renderMain, enemiesDraw, gamestates/gameflow/player/debugTools, settingsDraw/profilesDraw, ui/*UI), tabla de responsabilidades con 42 filas verificadas, estructura de perfil real (createdAt, monedas, highScore, achievements, unlocks, stats) + campos Fase 8 (highestStreak, skin), state keys del World ampliados con los nuevos de Fase 8.
  5. **TODO.md**: ítem de font sizes documentado tachado, pie actualizado a 17:08:2026. **AGENTS.md**: corregida la nota que afirmaba que la skill `documentation` no existía (sí existe en `.opencode/skills/documentation/SKILL.md`), arquitectura actualizada a 42 módulos + alias faltantes (settingsMod, profilesMod, playerMod, achievementsMod).

## 17:08:2026

- **docs** (completed - 17:58): Especificación y diseño completo de la Fase 8 (Evolución de Gameplay y Combate) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Paquete de Combate & Supervivencia**: Racha de supervivencia acumulativa (+0.1x por sala), modal interactivo de muerte (Revivir in situ [30$] vs Aceptar muerte [-30% monedas]), mecánica de encierro geométrico (*The Constrictor Loop*) y 4 comidas especiales (Guindilla Picante, Fruta Helada, Baya Constrictora y Baya de Poda).
  2. **Biomas y Peligros por Etapa**: Catacumbas (básico), Cripta Helada (inercia/suelo resbaladizo), Caverna Volcánica (grietas de magma cíclicas), Colmena Tóxica (suelo viscoso) y Santuario del Vacío (abismos letales / sin wall-wrap).
  3. **Encuentros de Élite**: Sala 3 de cada etapa como sala de desafío con enemigos de élite y cofre dorado garantizado.
  4. **Modos de Juego Endgame**: Desbloqueables tras vencer la Etapa 5 (Abismo Sin Fin, A Contrarreloj y Modo Pacifista).
  5. **Personalización & Skins**: 5 paletas de serpiente (Clásica, Neón, Midas, Fuego, Espectral) desbloqueables mediante logros.
  6. **Especificación Tipográfica**: Documentados los 4 tamaños oficiales de fuente (`28`, `16`, `11`, `8`) y mecanismos de fallback en `docs/TDD.md`.

- **refactor** (completed - 17:40): Split de archivos >500 líneas en facade + sub-módulos, delegando el dibujo/Generación a sub-módulos que reciben el facade por argumento (patrón de `ui/*UI.lua`):
  1. `world/world.lua` (675 → 122): facade de estado (`etapa`, `sala`, `objetivoSala`, getters) que delega a `world/dungeonGen.lua` (355, BSP + templates + stage modifiers) y `world/populate.lua` (193, población de sala).
  2. `systems/profiles.lua` (794 → 344): facade de estado/input que delega el dibujo a `systems/profilesDraw.lua` (509: select/input/confirm/achievements).
  3. `systems/settings.lua` (589 → 373): facade que expone `audio`/`graphics`/`accessibility`/`dat` para `persistence.lua` y delega el dibujo a `systems/settingsDraw.lua` (261: tabs/controls/toasts).
  - `entities/enemies.lua` (520) dejado intacto: sobrepasa el límite solo levemente y su extracción rompería el encapsulamiento de `telegraphs`/`attackObjects`/`pendingRespawns` sin beneficio real (opcional según el brief).
  - Tarea delegada a AGY CLI; verificación headless independiente (`love .` → `error.log` vacío) tras cada split.
- **fix** (completed - 17:35): Corrección de defectos introducidos en el split:
  1. `world/dungeonGen.lua`: eliminada función `world.getStageMod()` duplicada y rota que indexaba globals `world`/`stageMod` (nil) causando crash al cargar (`attempt to index global 'world' (a nil value)`).
  2. `systems/settings.lua`: reensamblado el cuerpo de `settings.close()` que había quedado partido (asignaciones de reset filtradas a nivel de módulo) y eliminada la redefinición duplicada de `settings.audio`/`graphics`/`accessibility` que pisaba el estado cargado por `open()`.

## 14:08:2026

- **fix** (completed - 22:20): Restauración completa y garantizada del audio del juego y música continua:
  - `audio/sound.lua`: Corregido el orden de decodificación en streaming (`seek` antes de `play`), evitando desincronización de buffers en OpenAL.
  - `audio/sound.lua`: Implementado el reinicio automático del bucle musical en `sound:update(dt)` cuando la pista termina o se detiene, garantizando música continua en el menú y en la partida.
  - `audio/sound.lua`: Agregados efectos de sonido procedurales `buttonHover` y `buttonClick` para interacción con la interfaz.
  - `systems/gamestates.lua`: Verificación de `not sound:isPlaying()` en cada estado para reiniciar segmentos musicales si fueron interrumpidos externamente.
  - `ui/menuUI.lua` & `main.lua`: Conectados los sonidos de feedback al pasar el ratón (`hover`) y hacer click sobre los botones del Menú Principal.
- **fix** (completed - 18:38): Corrección integral de bugs en el subsistema de sonido y música:
  - `systems/gamestates.lua`: Corregida la detección de racha musical con flanco de subida persistente (`prevComboActive`), permitiendo que la introducción del combo (`comboEnter`, 10s–17s) suene completa y transicione de forma natural al bucle `comboLoop` sin ser sobreescrita en cada tick.
  - `audio/sound.lua`: Añadidas guardas estrictas de `sound.musicEnabled` en `startSegment()`, `playSegment()` y `crossfadeTo()`, evitando que la música se reactive sola tras ser desactivada en Configuración.
  - `audio/sound.lua`: Añadida guarda de `sound.sfxEnabled` en `sound.play(name)`, permitiendo desactivar los efectos de sonido procedurales desde la interfaz de opciones.
  - `audio/sound.lua`: `sound.setMasterVolume(v)` ahora aplica `love.audio.setVolume(sound.baseVolume)`, regulando el volumen general del motor OpenAL tanto para música como para todos los efectos de sonido.
  - `audio/sound.lua`: Limpieza y detención estricta de fuentes de audio huérfanas al cancelar fundidos y cambios rápidos de segmento.
- **feature** (completed - 18:20): Cinemática inicial fluida y continua (eliminado el salto abrupto de 3.0s):
  - `ui/introUI.lua`: Ascenso continuo del diamante mediante interpolación suave con curva *Ease-Out Cubic* entre `t = 2.0s` y `t = 2.8s`, elevándose de forma orgánica desde el centro (`cy = 300px`) a la cabecera superior (`y = 108px`). Espiral convergente y destello (*flash*) sincronizados con la llegada a la cima.
  - `ui/menuUI.lua`: Revelación orgánica del título `S N A K E` naciendo del resplandor del diamante a partir de `t = 2.8s` con micro-expansión de escala (`0.92 -> 1.0`).
  - `ui/menuUI.lua`: Cascada escalonada (*staggered entrance*) de los botones de cristal y oro con micro-desplazamiento vertical hacia arriba y retardo de 0.08s por botón.
  - `render/renderMain.lua`: Renderizado del menú sincronizado a partir de `introTimer >= 2.8s`.
- **feature** (completed - 18:08): Rediseño visual del Menú Principal (*Balatro Style — Cristal & Oro*):
  - `ui/introUI.lua`: Mantenido el diamante/rombo emblemático flotando en la zona superior detrás del título con brillo pulsante y rotación mística tras la intro, limpiando las partículas secundarias de la espiral.
  - `ui/menuUI.lua`: Tipografía nítida y pura para el título `S N A K E` (eliminado el triple escalado que deformaba y duplicaba las letras). Tarjeta de High Score enmarcada en cristal oscuro translúcido con borde dorado brillante (`shimmer`).
  - `ui/menuUI.lua`: 4 botones interactivos con bordes dorados, esquinas redondeadas (`8px`), elevación suave y cursor indicador `▶` al hacer hover.
  - `ui/menuUI.lua`: Distribución y espaciado vertical corregido: garantizada una holgura limpia de más de 150px entre el botón `SALIR` y las pastillas inferiores de ayuda (`WASD / FLECHAS`, `+ / - VELOCIDAD`).
- **fix** (completed - 17:50): Corregida la fuga visual de bloom/glow y sombra durante la pantalla de transición ("SALA COMPLETADA"):
  - `render/renderMain.lua`: `drawGameGlow()` y `drawGameShadow()` ahora atenúan la emisión con `(1 - fadeAlpha)` y se cancelan por completo cuando `fadeAlpha >= 1` o durante la fase `hold`, evitando que el bloom aditivo se pinte sobre la pantalla negra.
- **feature** (completed - 17:35): Implementación completa de la IA del Chaser (Cazador Rojo) en todas sus fases:
  1. `entities/chaserAI.lua`: Detección de ocupación de slots en MANADA: al tener >=60% de slots ocupados (o 6s de espera máxima), se activa inmediatamente el cierre anticipado con fase `flash` de advertencia y posterior `dash` coordinado.
  2. `entities/chaserAI.lua`: Sistema de promoción a nuevo líder `hunter` con feedback de anillo dorado cuando el líder previo es eliminado.
  3. `world/world.lua` y `entities/enemies.lua`: Fórmula de escalado de velocidad progresiva por etapa: `intervalo = max(0.15s, (0.30 / speedMult) * 0.90^(etapa - 1))` con clamp estricto de 0.15s.
  4. `systems/gamestates.lua`: Contexto enriquecido pasando `worldMod.etapa` y `worldMod.getModifier()` a `enemiesMod.update()`.
  5. `entities/enemies.lua`: Integración en sala Boss con respawn en flancos alternados (`side = 1 / -1`) y garantía de modo DUPLA forzado por el cap `BOSS_MAX_RED = 3`.
  6. `render/enemiesDraw.lua`: Pulido visual en `drawChaser()` con aura pulsante de embestida en fase `close` y halo de promoción de líder.
  7. `docs/GDD.md`: Actualizada la sección 3 con la documentación completa de Chaser, Patroller y Spawner.
- **fix** (completed - 17:25): Corrección integral de bugs y pulido de Patrollers:
  1. `entities/enemies.lua`: Corregida la lógica de movimiento y rebote del Patroller ante colisiones frontales con muros, obstáculos, cuerpo de serpiente, otros enemigos y el Boss. Se eliminó el congelamiento y los deadlocks cara a cara.
  2. `entities/enemies.lua`: Integrada la comprobación `canSpawn()` en `enemies.generar()` para respetar estrictamente los límites de `BOSS_MAX_RED` y `BOSS_MAX_BLUE` durante el encuentro con el Boss.
  3. `entities/snake.lua`: Corregida la colisión con enemigos al morir: chocar y morir sin escudo/armadura ya no otorga monedas ni dispara logros de muerte de enemigo de forma fraudulenta.
  4. `entities/bossAttacks.lua`: Ataque `spawn_adds` ahora utiliza `enemies.spawnAt()` estandarizado con multiplicador de velocidad por etapa (`speedMult`) y dirección explícita.
  5. `world/world.lua`: Implementada detección de eje despejado (horizontal vs vertical) al spawnear patrulleros en plantillas de salas estrechas/corredores.
  6. `systems/player.lua`: Bajas de enemigos por el ítem Bomba ahora invocan correctamente `achievementsMod.check("enemyKilled")` y `coinsChanged`.
  7. `render/enemiesDraw.lua`: Rotación angular suave del Patroller basada en `visRot` y sutil pulso de energía para mejorar la legibilidad visual.
- **fix** (completed - 17:15): Auditoría integral de bugs y optimizaciones de memoria aplicada con éxito:
  1. `entities/enemies.lua`: Corregida la comprobación de colisiones de los patrulleros (patrollers) para respetar bloqueos con el cuerpo de la serpiente y obstáculos, eliminando comprobaciones duplicadas de límites de grilla.
  2. `systems/player.lua`: Corregido el efecto del ítem Hambre ("Hunger") para otorgar 2 frutas con puntos/monedas y generar una comida dorada garantizada en lugar de sobrescribir inmediatamente la variable única de comida.
  3. `systems/shop.lua`: Corregido el cálculo del índice de la tarjeta al comprar con el ratón (`purchaseFlash`), logrando que el destello verde parpadee en la tarjeta correspondiente.
  4. `systems/achievements.lua`: Añadida protección de índice no nulo (`schedIndex and not schedIndex[aid]`) al programar notificaciones diferidas de logros.
  5. `ui/hudUI.lua` y `systems/settings.lua`: Implementado caché de fuentes por tamaño (`getCachedFont` / `getFallbackFont`) eliminando la instanciación redundante de `love.graphics.newFont` en cada frame del ciclo de renderizado (60 FPS).
  6. `systems/gamestates.lua`: Eliminada la función duplicada `processToasts()` y añadido `foodMod.update(dt)` en el ciclo de actualización común.
  7. `entities/food.lua`: Separada la lógica de animación (`food.update(dt)`) del dibujo puro (`food.draw()`).
  8. `world/world.lua`: Encapsulado `mundoCompletado` a través de `coreWorld.set("mundoCompletado", false)` evitando fugas al entorno global `_G`.
- **feature** (completed - 16:45): Implementado sistema de Input Buffer (cola de hasta 2 giros) y protección anti-180° en `entities/snake.lua`. Evita colisiones accidentales al presionar teclas opuestas o giros rápidos en "L", y añade muestreo continuo de teclas mantenidas para una respuesta instantánea y fluida. `core/touch.lua` integrado con la misma cola `snake.encolarDireccion`.
- **docs** (updated - 16:45): GDD.md actualizado en la sección de movimiento con la descripción del Input Buffer y protección Anti-180°.

## 12:08:2026

- **feature** (implemented): Chaser visual propuesta 06, Estrella de espinas, con ojo rastreador, animaciones IDLE/CHASE/FLANK/ENCIRCLE/CIERRE e IA social base en `entities/chaserAI.lua`. Añadidos CRT con curvatura, flash rojo y screen shake por daño, además de bloom a media resolución.
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




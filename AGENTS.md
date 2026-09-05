# Snake Love2D — Dungeon Crawler

## Estándares (obligatorio)
- **Siempre iterar hasta que el programa sea funcional**: `love .` debe ejecutar sin errores antes de dar una tarea por completada.
- **Siempre revisar el log en busca de errores** tras cada cambio; no declarar completada una tarea con errores/warnings nuevos.
- Aplicar las reglas de arquitectura del proyecto: sin variables globales, módulos `local X = {}`, `return X`, sistemas sobre entidades, object pooling, config central, logger, dividir archivos >300–500 líneas. (La skill `documentation` está en `.opencode/skills/documentation/SKILL.md` y se aplica junto a estas reglas.)
- El código actual (fases previas) aún tiene globals; la migración se hace de forma incremental y cada paso debe dejar el juego funcional.

## Ejecucion
`love .` (directorio raiz, NUNCA apuntar a `main.lua` suelto).

## Arquitectura (60 módulos juego + helpers, 93 con 31 tests)
Estructura de carpetas por sistema:
- `main.lua` (541L loop fixed timestep `FIXED_DT=1/60`, 7 estados), `constants.lua` — raíz (shim de `core/config.lua`)
- `core/` → `config.lua` (+`KEYBINDS`, `ENABLE_VORONOI`), `logger.lua`, `timers.lua` (único pooled P05), `world.lua` (369L dot-notation + `SCHEMA`/`validate()` P04/P13), `events.lua` 134L bus P06, `input.lua` 89L centralizado P07, `assets.lua` 144L cache P08, `touch.lua` (lazy), `helpers.lua`
- `entities/` → `snake.lua` 257L fachada + `snake/` 4, `enemies.lua` 341L fachada + `enemyAttackRegistry.lua` 224L pools + `enemyBossLogic.lua` + `enemySpawnLogic.lua` + `bossAttacks.lua` + `enemyHelpers.lua` + `chaserAI.lua` + `patrollerAI.lua`, `food.lua`, `obstacles.lua` 495L fachada (delega a `world/biomeHazards.lua`)
- `world/` → `world.lua` (facade: estado etapa/sala/objetivoSala, getters) + `dungeonGen.lua` (BSP, templates, stage modifiers) + `populate.lua` (población de sala)
- `systems/` → `items.lua` (12 items, slots 1-3), `shop.lua` (paginacion 4x3), `persistence.lua`, `settings.lua` (facade panel ajustes) + `settingsDraw.lua` (render pestañas/controles), `profiles.lua` (facade gestor max 3) + `profilesDraw.lua` (render perfiles/achievements), `achievements.lua` (11 logros), `player.lua` (calc speed/items), `gameflow.lua` (runs/rooms), `gamestates.lua` (update por estado), `debugTools.lua` (menu debug Tab) + `debugLogo.lua` (calibrador logo F2)
- `ui/` → `ui.lua` (facade: estado popups/toasts/menu, fuentes, texturas, accesibilidad) + submódulos `introUI.lua` (intro Balatro + diamante), `menuUI.lua` (facade menú + panel 40% + 4 botones Cyber-Step #03), `menuLogo.lua` (render 2.5D cian isométrico), `menuCard.lua` (tarjeta Chunky perfil #11), `hudUI.lua` (grid/HUD/slots/combo), `toastsUI.lua`, `popupsUI.lua`, `overlaysUI.lua` (pausa/minimapa/dungeon debug).
- `render/` → `shaders.lua` (bloom+CRT+sombra+heat), `particles.lua` (textura 4x4 procedural) + `renderMain.lua` (drawScene) + `enemiesDraw.lua`
- `audio/` → `sound.lua` (SFX procedural + single .ogg)

Alias: `snakeMod`, `foodMod`, `uiMod`, `enemiesMod`, `worldMod`, `shadersMod`, `obstaclesMod`, `particlesMod`, `persistenceMod`, `shopMod`, `settingsMod`, `profilesMod`, `playerMod`, `achievementsMod`.

## Estados (`constants.lua`)
`MENU=0`, `PLAYING=1`, `DEATH_ANIMATION=2`, `HIGH_SCORE=3`, `SHOP=4`, `PAUSED=5`, `TRANSITION=6`

## Flujo
`MENU`(4.5s intro) → `PLAYING` → `TRANSITION`(fade-out→hold2s→fade-in) → `SHOP` → `PLAYING`
`PLAYING` ↔ `PAUSED`(ESPACIO/ESC)
`PLAYING` → `DEATH_ANIMATION` → `HIGH_SCORE`(1.3s si record) o `SHOP` → `MENU`
Muerte: reinicia 1-1, conserva monedas e items. `worldMod.init()` en death anim.

## Boss (food-based defeat)
- Boss es `invulnerable = true` por defecto. `hitBoss()` retorna `{hit=true}` sin reducir vida.
- Unica forma de derrotarlo: recolectar `BOSS_FOOD_TARGET` (15) comidas NO-moneda durante el encuentro.
- `enemies.onBossDefeatedByFood()` limpia telegraphs/attackObjects/pendingRespawns y retorna resultado compatible (`{px, py, gx, gy, coins, type="boss"}`).
- Barra de vida sobre el boss (mundo): fill suave via `_uiBarFill` → `_uiBarTarget` lerp (6.0/s).
- `iniciarSala()` muestra popup: "Derrota al jefe recogiendo 15 comidas" si es sala boss.
- `world.populateRoom()` reserva las 9 celdas (centro + 8 adyacentes) en boss room para evitar comida sobre el boss.
- Los ataques tienen `telegraphTime` antes de ejecutarse (telegraph markers visibles).
- 4 ataques: `projectile_spread` (radial), `spawn_adds` (patrollers, respeta caps), `radial_pulse` (onda), `teleport` (pos aleatoria lejos de head).
- `canSpawn(type)` respeta `BOSS_MAX_RED=3` / `BOSS_MAX_BLUE=4` durante boss. `sampleFreeTile()` busca tile seguro >=6 de head, con attempts.
- **Timeout**: enemigos que llevan `BOSS_ENEMY_LIFETIME=15s` vivos durante boss: chasers se encolan en `pendingRespawns` (reaparecen 5s despues), patrollers se eliminan.
- Spawners: intervalo * 1.5 durante boss.

## Snake colisiones (`snake.mover()`)
Retorna 5 valores: `vivo, comio, enemyKilled, bossResult, attackHit`
Con `attackHit`: proyecto true si un ataque del boss conecta (sin shield/armor/ghost).
Orden colision: cuerpo → obstaculos → boss → proyectiles → enemigos
- `debugImmune` global: atraviesa todo sin morir
- `love.mousepressed()` maneja SHOP, debug menu, settings y profiles

## Sound (`sound.lua`)
Single .ogg, 4 segmentos: intro(1-9s), comboEnter(10-17s), comboLoop(13-17s), boss(18-24s)
- `comboLoop` usa seamless crossfade con `nextLoopSource`
- **Gotcha**: `nextLoopSource` debe ser `:stop()`'d antes de setear a `nil` al cambiar de segmento
- `playSegment()` cancela crossfade activo antes de cambiar
- `sound:update(dt)` se llama al inicio de `love.update()`, ANTES del movimiento
- SFX procedurales cargados en `sound.load()`: eat/death/buy/shieldBreak/highScore/enemyKill/boss_food_tick/boss_defeated

## Debug menu (Tab) & Calibrador Logo (F2)
- **Tab Debug Menu (`systems/debugTools.lua`)**: Toggle con `Tab`. Dibujado post-composite en PLAYING/PAUSED. Panel 210x250 en x=10,y=50. Botones: Skip Room, Skip Stage, +10 Coins, Inmune, Speed +/-, Racha +/-.
- **F2 Calibrador de Logo (`systems/debugLogo.lua`)**: Toggle con `F2` en el Menú Principal. Permite arrastrar el bounding box con el ratón o ajustar con flechas, modificar escala (`[` / `]`), profundidad (`-` / `+`), resetear (`R`) y guardar permanentemente con `Enter`/`F2` en `config/settings.dat` vía `persistence.saveLogoConfig()`.

## Menú Principal Asimétrico Cyberpunk (`ui/menuUI.lua`)
- Panel lateral izquierdo ($40\%$ de ancho de pantalla) con fondo procedural de Matriz de Puntos HUD (#14) y Círculo Alquímico de Invocación (#17 Render 1) rotatorio a 60 FPS con pulso de respiración y pase bloom glow.
- 4 Botones arcade Cyber-Step #03 de $260\times 40\,\text{px}$ centrados verticalmente.
- Logotipo 2.5D isométrico cian (`ui/menuLogo.lua`) y tarjeta de perfil Chunky #11 (`ui/menuCard.lua`).

## Pipeline render (`shaders.lua`)
`shaders.composite()`: sceneCanvas → (glow → blurH → blurV) bloom additive → shadow blur → CRT sobre canvasFinal.
Menu usa heat distortion. Debug menu se dibuja DESPUES del composite.

## Perfiles (`profiles.lua` + `persistence.lua`)
- Max 3 perfiles en `config/profiles.dat` (Lua nativo). `profile.stats.kills/bossesKilled/highestStage/highestScore/totalCoins`.
- `persistence.initProfiles()` en `love.load`. Sin perfil activo → `profilesMod.open()`.
- `persistence.syncActiveProfile()` persiste monedas/highScore. `persistence.syncUnlocks(unlocks)` persiste desbloqueos pasivos.
- `applyActiveProfile()` (global en main.lua) aplica datos del perfil: monedas, highScore, unlocks pasivos.
- Puntos de sync: muerte (highScore), compras tienda (monedas+unlocks), transiciones SHOP↔MENU/PLAYING, `love.quit()`.
- `love.textinput()` y `love.keypressed` se enrutan a `profilesMod.textinput()`.

## Achievements (`achievements.lua`)
- 11 logros: first_kill, enemy_25, enemy_100, combo_5, combo_10, coins_100, coins_500, stage_3, boss_kill, score_1000, score_5000.
- `achievements.check(event, params)` se llama en: `enemyKilled`, `comboAchieved`, `bossDefeated`, `stageChanged`, `scoreReached`, `coinsChanged`.
- Logros pendientes se encolan via `pendingAchievements` global y se vacian con `flushPendingAchievements()` en puntos de transicion/tienda.

## Love2D gotchas
- `ParticleSystem:getCount()` NO `count()`
- `ParticleSystem:setParticleLifetime(min,max)` NO `setLifetime()`
- `dt` no existe en `love.draw()` — timers en `love.update()`
- Font `PressStart2P-Regular.ttf` via `pcall` con fallback. Sizes: 28/16/11/8

## Estilo
- **LEGADO (a migrar)**: variables globales `puntuacion`, `monedas`, `comboCount`, `gameState`, `debugImmune`, `transitionTarget`, `transitionPhase`, `fadeDir`, `fadeAlpha`. Código nuevo: NO globals — módulos `local X = {}`, `return X`, estado administrado en un World.
- Código nuevo: `local` siempre, enums para estados, data-driven, timer manager, render separado de lógica, no crear tablas por frame.
- Colores como `{r,g,b}` o `{r,g,b,a}`
- Cero emojis
- No `print()` por todo el proyecto; usar `core/logger.lua`:`Log.info/warn/error`.

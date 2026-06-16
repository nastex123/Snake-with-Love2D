# Snake Love2D — Dungeon Crawler

## Ejecucion
`love .` (directorio raiz, NUNCA apuntar a `main.lua` suelto).

## Arquitectura (18 modulos + helpers)
`main.lua` (loop, 7 estados), `constants.lua`, `world.lua` (dungeon), `snake.lua` (mov/colisiones), `enemies.lua` (chasers/patrollers/spawners/boss), `food.lua` (3 tipos), `items.lua` (12 items, slots 1-3), `shop.lua` (paginacion 4x3), `ui.lua` (intro Balatro, HUD, popups, toasts), `obstacles.lua`, `particles.lua` (textura 4x4 procedural), `shaders.lua` (bloom+CRT+sombra+heat), `persistence.lua`, `sound.lua` (SFX procedural + single .ogg), `settings.lua` (mouse-only panel), `profiles.lua` (gestor max 3), `achievements.lua` (11 logros), `helpers.lua` (deep_copy).

Alias: `snakeMod`, `foodMod`, `uiMod`, `enemiesMod`, `worldMod`, `shadersMod`, `obstaclesMod`, `particlesMod`, `persistenceMod`, `shopMod`.

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

## Debug menu (Tab)
Toggle: `debugMenuOpen` (global). Dibujado post-composite en PLAYING/PAUSED.
Panel 210x250 en x=10,y=50. Botones: Skip Room, Skip Stage, +10 Coins, Inmune, Speed +/-, Racha +/-.
Click en `love.mousepressed()`. `debugButtons` rebuild cada frame.

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
- Variables globales (sin `local`): `puntuacion`, `monedas`, `comboCount`, `gameState`, `debugImmune`, `transitionTarget`, `transitionPhase`, `fadeDir`, `fadeAlpha`, etc.
- Colores como `{r,g,b}` o `{r,g,b,a}`
- Cero emojis

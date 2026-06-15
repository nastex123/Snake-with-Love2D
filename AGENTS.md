# Snake Love2D — Dungeon Crawler

## Ejecucion
`love .` (directorio raiz, NUNCA apuntar a `main.lua` suelto).

## Arquitectura (17 modulos)
| Archivo | Rol |
|---------|-----|
| `main.lua` | Loop, maquina de estados (7 estados), integracion |
| `constants.lua` | Config global (bloque 20px, colores, precios, timers) |
| `world.lua` | Mazmorra: etapa(1-5) x sala(1-5), objetivoSala, modificadores |
| `snake.lua` | Movimiento, colisiones (trade kill), gradiente, ojos |
| `enemies.lua` | Chaser/Patroller/Spawner/Boss. Patrollers se atraviesan entre si |
| `food.lua` | 3 tipos (Normal/Gold/Coin), valida contra todo |
| `items.lua` | Registry de 12 items. Activos van a slots (1-3) |
| `shop.lua` | Cards paginacion 4x3, slots activos inferiores |
| `ui.lua` | Intro Balatro, grid, HUD, popups |
| `obstacles.lua` | Obstaculos cada 50pts |
| `particles.lua` | ParticleSystem con textura 4x4 procedural |
| `shaders.lua` | Pipeline 7-canvas: bloom+CRT+sombra+heat. Balatro BG con pixelado+espiral |
| `persistence.lua` | Persistencia settings + perfiles (max 3) via `love.filesystem` |
| `sound.lua` | Sonidos procedurales (sine/sweep/noise) |
| `settings.lua` | Panel config mouse-only (Audio/Graphics/Accessibility) |
| `profiles.lua` | Gestor de perfiles UI (crear/renombrar/borrar/restablecer, max 3) |
| `achievements.lua` | Registry de 11 logros, check en eventos de juego |
| `helpers.lua` | Utilidades (deep_copy) |

Alias: `snakeMod`, `foodMod`, `uiMod`, `enemiesMod`, `worldMod`, `shadersMod`, `obstaclesMod`, `particlesMod`, `persistenceMod`, `shopMod`.

## Estados (`constants.lua`)
`MENU=0`, `PLAYING=1`, `DEATH_ANIMATION=2`, `HIGH_SCORE=3`, `SHOP=4`, `PAUSED=5`, `TRANSITION=6`

## Flujo
`MENU`(ENTER despues 4.5s) → `PLAYING` → `TRANSITION`(fade-out→hold2s→fade-in) → `SHOP` → `PLAYING`
`PLAYING` → `PAUSED`(ESPACIO/ESC)
`PLAYING` → `DEATH_ANIMATION` → `HIGH_SCORE`(1.3s si record) o `SHOP` → `MENU`
Muerte: reinicia 1-1, conserva monedas e items. `worldMod.init()` en death anim.

## Sound (`sound.lua`)
Single .ogg, 4 segmentos: intro(1-9s), comboEnter(10-17s), comboLoop(13-17s), boss(18-24s)
- `comboLoop` usa seamless crossfade con `nextLoopSource`
- **Gotcha:** `nextLoopSource` debe ser `:stop()`'d antes de setear a `nil` al cambiar de segmento
- `playSegment()` cancela crossfade activo antes de cambiar
- `sound:update(dt)` se llama al inicio de `love.update()`, ANTES del movimiento

## Snake colisiones (`snake.mover()`)
Retorna 4 valores: `vivo, comio, enemyKilled, bossResult`
Orden colision: cuerpo → obstaculos → boss → enemigos
- Trade kill: cabeza mata enemigo pero muere (a menos que shield/armor/ghost/immune)
- `hitBoss()` retorna 2 formas: `{hit=true, vida, vidaMax}` (vivo) o `{px, py, ..., type="boss"}` (muerto)
- `debugImmune` global: atraviesa todo sin morir (no consume shield/armor)

## Debug menu (Tab)
Toggle: `debugMenuOpen` (global). Dibujado post-composite en PLAYING/PAUSED.
Panel 210x250 en x=10,y=50. Botones: Skip Room, Skip Stage, +10 Coins, Inmune, Speed +/-, Racha +/-.
Click en `love.mousepressed()`. `debugButtons` rebuild cada frame.

## Dungeon
`world.objetivoSala = floor((50 + sala*30) * stageModifiers[etapa].targetMult)`
`iniciarSala(keepInventory)`: `foodMod.generar()` ANTES de `enemiesMod.generar()` (evita foodPos stale).

## Pipeline render (`shaders.lua`)
`shaders.composite()`: sceneCanvas → (glow → blurH → blurV) bloom additive → shadow blur → CRT sobre canvasFinal.
Menu usa heat distortion. Debug menu se dibuja DESPUES del composite.

## Perfiles (`profiles.lua` + `persistence.lua`)
- Max 3 perfiles, almacenados en `config/profiles.dat` (formato Lua nativo).
- Cada perfil guarda: `name`, `monedas`, `highScore`, `achievements`, `unlocks`, `stats`.
- `persistence.initProfiles()` en `love.load`. Si no hay perfil activo, se abre `profilesMod.open()`.
- Boton PERFILES en el menu principal abre el gestor.
- `profilesMod` tiene tres estados: `select` (tarjetas), `input` (nombre), `confirm` (confirmacion).
- `love.textinput` y `love.keypressed` se enrutan a `profilesMod.textinput()` para la entrada de nombre.

## Sincronizacion de perfil
- `persistence.syncActiveProfile()` persiste monedas/highScore del perfil activo.
- `persistence.syncUnlocks(unlocks)` persiste desbloqueos pasivos.
- `applyActiveProfile()` (global en main.lua) aplica datos del perfil al juego: monedas, highScore y unlocks pasivos a `shop.inventory`.
- Puntos de sync: muerte (highScore), compras en tienda (monedas+unlocks), transiciones SHOP->MENU/PLAYING, `love.quit()`.

## Achievements (`achievements.lua`)
- 11 logros: first_kill, enemy_25, enemy_100, combo_5, combo_10, coins_100, coins_500, stage_3, boss_kill, score_1000, score_5000.
- `achievements.check(event, params)` se llama en:
  - `enemyKilled` (mata enemigo)
  - `comboAchieved` (racha >= 5 o 10)
  - `bossDefeated` (mata jefe)
  - `stageChanged` (llega a etapa 3)
  - `scoreReached` (puntuacion record >= 1000/5000)
  - `coinsChanged` (monedas acumuladas)
- Stats acumulativos: `profile.stats.kills`, `profile.stats.bossesKilled`, `profile.stats.highestStage`, `profile.stats.highestScore`, `profile.stats.totalCoins`.

## Love2D gotchas
- `ParticleSystem:getCount()` NO `count()`
- `ParticleSystem:setParticleLifetime(min,max)` NO `setLifetime()`
- `dt` no existe en `love.draw()` — timers en `love.update()`
- `love.mousepressed()` maneja SHOP, debug menu, settings y profiles
- `love.textinput()` se enruta a profilesMod.textinput para entrada de nombre
- Font `PressStart2P-Regular.ttf` via `pcall` con fallback. Sizes: 28/16/11/8

## Estilo
- Variables globales (sin `local`): `puntuacion`, `monedas`, `comboCount`, `gameState`, `debugImmune`, etc.
- Colores como `{r,g,b}` o `{r,g,b,a}`
- Cero emojis

# Perfil del Desarrollador

* **Nombre:** Brandon Rangel | Estudiante IUB (1er semestre Ing. Sistemas)
* **Sistemas:** Dual-boot Zorin OS (principal) + Windows 10 v1607
* **Tecnologias:** HTML, CSS, JS, Python, Lua (Love2D), Godot (GDScript)
* **Estetica:** Glassmorphism, fondos oscuros, UI translucida, cero emojis
* **Respuesta:** Directa, sin preambulos, sin explicaciones condescendientes

# Proyecto: Snake en Love2D — Dungeon Crawler

## Ejecucion
`love <directorio-raiz>` — NUNCA apuntar a `main.lua` suelto. VS Code: abrir carpeta completa o task con `${fileDirname}`.

## Arquitectura (100% modular)
| Archivo | Rol |
|---------|-----|
| `main.lua` | Loop principal, maquina de estados, integracion de modulos |
| `constants.lua` | Config global (bloque 20px, colores, precios, timers, particulas, enemies, bosses) |
| `world.lua` | Mazmorra: etapa (1-5), sala (1-5), objetivoSala, modificadores por etapa |
| `snake.lua` | Movimiento, colisiones (cabeza mata enemigos con trade), gradiente, ojos |
| `enemies.lua` | Chaser, patroller, spawner, boss (teleporter). Patrollers se atraviesan entre si |
| `food.lua` | Comida validando contra serpiente, obstaculos y enemigos. 3 tipos: Normal/Gold/Coin |
| `items.lua` | Registry de 12 items. Activos van a slots (1-3), pasivos auto-aplican |
| `shop.lua` | Tienda con cards, paginacion 4x3, slots inferiores para items activos |
| `ui.lua` | Balatro intro (diamante+espiral+flash), grid lineas, HUD, popups |
| `obstacles.lua` | Obstaculos cada 50pts, validacion antisolapamiento |
| `particles.lua` | ParticleSystem nativo con textura 4x4 procedural (bursts) |
| `shaders.lua` | Pipeline multi-paso + Balatro BG shader (domain warping + spiral) |
| `persistence.lua` | High score en `love.filesystem` (identidad: `Snake_Brandon_IUB`) |
| `sound.lua` | Sonidos procedurales (sine/sweep/noise via SoundData) |

## Estados del juego
`GAME_STATE_MENU=0`, `PLAYING=1`, `DEATH_ANIMATION=2`, `HIGH_SCORE=3`, `SHOP=4`, `PAUSED=5`, `TRANSITION=6`

## Flujo de pantallas
`MENU` (ENTER) → `PLAYING` → (`PAUSED` ESPACIO/ESC) → `DEATH_ANIMATION` → (`HIGH_SCORE` 1.3s si nuevo record) → `SHOP` (1/2/3 comprar o click, 4 salir, 5 continuar) → `MENU`

**Dungeon progression:** `PLAYING` → (`TRANSITION` fade-out 2s hold + fade-in) → `SHOP` → `PLAYING` (siguiente sala). Sala 5 = boss. Etapa 5-5 = victoria.

**Muerte:** Reinicia desde 1-1 pero conserva monedas e items. `world.init()` en `DEATH_ANIMATION` → `SHOP`.

## Pipeline de render
`shaders.lua`: 7-canvas, 5-shaders. `shaders.composite()` aplica bloom (glow→blurH→blurV), sombra, CRT. Menu usa heat distortion. Balatro BG con spiral effect (`spiralIntensity` uniform).

## Mazmorra (world.lua)
- 5 etapas × 5 salas = 25 habitaciones
- Sala 5 de cada etapa = boss fight
- `stageModifiers[etapa]`: spawnRate, enemySpeed, chaserWeight, patrollerWeight, spawnerWeight, targetMult, bossVida
- `world.getModifier()` → pasa a `enemies.generar()` y `enemies.spawnBoss()`
- Objetivo por sala: `floor((50 + sala*30) * targetMult)`

## Enemigos (enemies.lua)
- **Chaser** (rojo, rombo): persigue cabeza de serpiente. Velocidad: 0.3
- **Patroller** (azul, triangulo direccional): rebota en paredes. Velocidad: 0.2. **Se atraviesan entre si** (solo verifican contra snake)
- **Spawner** (purpura, cuadrado): genera obstaculos cada 3s
- **Boss** (teleporter): aparece en sala 5. Se teletransporta cada 2s, genera minions patroller cada 4s. Multi-golpe (vida depende de etapa)

**Colision cabeza-enemigo:** Cabeza mata enemigo con trade. Shield/armor protegen. Ghost atraviesa. `snake.mover()` retorna 4to valor `bossResult`.

## Intro Balatro (ui.drawBalatroIntro)
| Tiempo | Efecto |
|--------|--------|
| 0-0.5s | Fade from black |
| 0.5-1.5s | Diamante cyan sube al centro (easeOutBack) |
| 1.5-2.5s | 35 formas espiralean hacia centro, background en espiral |
| 2.5-3.0s | Flash blanco |
| 3.0-4.5s | Titulo + menu aparecen, background se desenrosca |
| 4.5s+ | ENTER habilitado |

Background shader tiene `spiralIntensity` uniform que controla rotacion polar del domain warping.

## Transiciones (TRANSITION state)
3 fases: `transitionPhase == 1` (fade-out) → `"hold"` (2s, texto visible) → `2` (fade-in → SHOP). Texto: "SALA COMPLETADA", "ETAPA COMPLETADA" o "MAZMORRA SUPERADA". Dibujado DESPUES del fade overlay.

## Items (items.lua + shop.lua)
- **Activos** → slots 1-3 (teclas 1/2/3 para usar): shield, armor, ghost, magnet, bomb, hunger, turbo, slow, doubler
- **Pasivos** → auto-aplican al comprar: speedReducer (−0.02 permanente), extraCoin (+1 coin 10s)
- Shop: `shop.slots[1-3]`, `shop.inventory` para pasivos. `shop.slotActivate(n)` retorna itemId.
- `aplicarItem()` en main.lua maneja activacion. Colores via `itemColor()`.

## Mecanicas clave
- **Monedas:** 1 por fruta, 10 pts por fruta. Se conservan entre salas y al morir
- **Combo:** comer dentro de 8s incrementa. Multiplicador `1 + comboCount * 0.5`
- **Velocidad:** `baseSpeed - floor(frutas/5) * 0.01`, minimo 0.05. +/- en tiempo real
- **Wall wrap:** serpiente atraviesa paredes, aparece del lado opuesto
- **Screen shake:** al morir, 0.3s, intensidad 4px
- **Fade transitions:** velocidad 3/s. `fadeDir=1` (a negro), `fadeDir=-1` (desde negro)

## Gotchas Love2D
- `ParticleSystem:getCount()` — NO `count()` (metodo no existe)
- `ParticleSystem:setParticleLifetime(min, max)` — NO `setLifetime()` (no existe en 11.4)
- Fuente retro: `PressStart2P-Regular.ttf`. `ui.load()` y `shop.loadFonts()` usan `pcall` con fallback
- Font sizes: titulo 28, grande 16, normal 11, pequena 8
- Particulas: `emit(N)` para bursts, solo `fondoPS` usa `setEmissionRate` + `start()` continuo
- `dt` no existe en `love.draw()` — shockwave update en `love.update()`
- `menuPS` se crea en `love.load()`, se actualiza siempre, solo se dibuja en MENU

## Controles
- `WASD/Flechas` — mover serpiente
- `+/-` — ajustar velocidad base
- `ENTER` — comenzar desde menu (tras 4.5s de intro)
- `ESPACIO/ESC` — pausar/reanudar
- `1/2/3` — usar item activo en slot
- `L` — debug +10 monedas
- `K` — debug saltar ronda (con manejo correcto de boss sala 5)

## Estilo de codigo
- Variables globales para estado de juego (`puntuacion`, `monedas`, `gameState`, etc.)
- Modulos requereados con alias corto (`snakeMod`, `foodMod`, `uiMod`, `enemiesMod`, `worldMod`, `shadersMod`)
- Colores como tablas `{r, g, b}` o `{r, g, b, a}`
- `iniciarSala(keepInventory)` llama `foodMod.generar` ANTES de `enemiesMod.generar` para evitar foodPos stale

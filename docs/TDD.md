# Technical Design Document — Snake Dungeon Crawler

## 1. Architecture Overview

**Pattern**: Procedural module-based with global state management  
**Entry Point**: `main.lua`  
**Total Modules**: 45 .lua files  
**Total Lines**: ~9,100 (post-split 23:08:2026: menuUI 683→205+129+214, debugTools 503→196+189, shaders 535→496)

### Folder Structure

```
Snake-with-Love2D/
├── main.lua, constants.lua     ← raíz (constants.lua = shim → core/config.lua)
├── core/
│   ├── config.lua              ← configuracion central (canvas, gameplay, colores, boss)
│   ├── logger.lua              ← Log.info/warn/error/debug
│   ├── timers.lua              ← timer manager (after/every/cancel/clear, object pooling)
│   ├── world.lua               ← World.state (estado global, reemplaza globals)
│   ├── touch.lua               ← input táctil (swipes)
│   └── helpers.lua             ← deep_copy, math/rect utilities
├── entities/
│   ├── snake.lua               ← mov/colisiones, mover() retorna 5 valores
│   ├── food.lua                ← 3 tipos de comida
│   ├── obstacles.lua           ← obstáculos
│   ├── enemies.lua             ← facción enemigos/boss
│   ├── chaserAI.lua            ← IA social Chaser (SOLO/DUPLA/MANADA)
│   ├── bossAttacks.lua         ← 4 ataques del boss
│   └── enemyHelpers.lua        ← validarPos, sampleFreeTile, etc.
├── world/
│   ├── world.lua               ← facade: estado etapa/sala/objetivoSala + getters
│   ├── dungeonGen.lua          ← BSP, templates de sala, stage modifiers
│   └── populate.lua            ← población de sala
├── systems/
│   ├── items.lua               ← 12 ítems
│   ├── shop.lua                ← tienda (paginación por categoría 4x3)
│   ├── persistence.lua         ← save/load + syncActiveProfile
│   ├── profiles.lua            ← facade gestión de perfiles (max 3)
│   ├── profilesDraw.lua        ← render select/input/confirm/achievements
│   ├── achievements.lua        ← 11 logros
│   ├── settings.lua            ← facade panel ajustes (mouse-only)
│   ├── settingsDraw.lua        ← render tabs de ajustes
│   ├── player.lua              ← calc velocidad/items del jugador
│   ├── gameflow.lua            ← runs/rooms (resets)
│   ├── gamestates.lua          ← update por estado (7 estados)
│   └── debugTools.lua          ← menú debug (Tab)
├── ui/
│   ├── ui.lua                  ← facade: popups/toasts/menu/fuentes/accesibilidad
│   ├── introUI.lua             ← intro Balatro + high score
│   ├── menuUI.lua              ← facade 205l: panel 40% + botones 260×40 gap14, delega logo/card
│   ├── menuLogo.lua            ← logo procedural cian isométrico 2.5D (getBounds, draw, drawGlow) 129l
│   ├── menuCard.lua            ← tarjeta #11 Chunky 344×76 circular 3D coin 214l
│   ├── hudUI.lua               ← grid/HUD/slots/combo
│   ├── toastsUI.lua            ← toasts
│   ├── popupsUI.lua            ← popups
│   └── overlaysUI.lua          ← pausa/minimapa/overlay dungeon debug
├── render/
│   ├── shaders.lua             ← bloom+CRT+sombra+heat (dedup SRC_BLUR 496l)
│   ├── particles.lua           ← textura 4x4 procedural
│   ├── renderMain.lua          ← drawScene + menú
│   └── enemiesDraw.lua         ← draw enemigos/Chaser (estrella de espinas)
└── audio/
    └── sound.lua               ← 1 .ogg (4 segmentos) + SFX procedurales
```

### Module Dependency Graph

```
main.lua (raíz) ──→ core/*, entities/*, systems/*, ui/ui.lua, render/*, audio/sound.lua
├── constants.lua (raíz) ──→ core/config.lua
├── core/world.lua ← estado del juego (World.state, reemplaza globals)
├── core/timers.lua, core/logger.lua, core/touch.lua, core/helpers.lua
├── entities/snake.lua ──→ entities/enemies.lua, systems/shop.lua, core/world.lua
├── entities/enemies.lua ──→ entities/bossAttacks.lua, entities/enemyHelpers.lua, entities/chaserAI.lua
├── entities/food.lua, entities/obstacles.lua
├── world/world.lua (facade) ──→ world/dungeonGen.lua, world/populate.lua, core/helpers.lua
├── systems/items.lua, systems/shop.lua ──→ systems/items.lua
├── systems/persistence.lua → audio/sound.lua, ui/ui.lua, render/shaders.lua, core/helpers.lua, core/world.lua
├── systems/profiles.lua → systems/persistence.lua, ui/ui.lua, systems/achievements.lua, systems/profilesDraw.lua
├── systems/settings.lua → systems/persistence.lua, core/helpers.lua, ui/ui.lua, render/shaders.lua, systems/settingsDraw.lua
├── systems/achievements.lua → systems/persistence.lua, core/world.lua
├── systems/player.lua, systems/gameflow.lua, systems/gamestates.lua, systems/debugTools.lua → systems/debugLogo.lua
├── ui/ui.lua (facade) ──→ ui/introUI.lua, ui/menuUI.lua → ui/menuLogo.lua + ui/menuCard.lua, ui/hudUI.lua, ui/toastsUI.lua, ui/popupsUI.lua, ui/overlaysUI.lua
├── render/shaders.lua, render/particles.lua, render/renderMain.lua, render/enemiesDraw.lua
└── audio/sound.lua
```

## 2. Module Responsibilities

| Module | Folder | Lines | Alias | Responsibility |
|--------|--------|-------|-------|----------------|
| main.lua | raíz | 380 | — | Game loop, state machine, orchestration (split 08:08:2026) |
| constants.lua | raíz | 3 | — | Shim → core/config.lua (legacy compatibility) |
| config.lua | core/ | 184 | — | Centralized configuration |
| logger.lua | core/ | 45 | Log | Logging (info/warn/error/debug) |
| timers.lua | core/ | 91 | — | Timer manager with object pooling |
| world.lua | core/ | 29 | world | World state container (World.state, no globals) |
| touch.lua | core/ | 113 | — | Touch input (swipes) |
| helpers.lua | core/ | 52 | — | Utility functions |
| snake.lua | entities/ | 440 | snakeMod | Movement, collision detection (devuelve 5 valores) |
| enemies.lua | entities/ | 521 | enemiesMod | Enemy AI, boss logic (split 08:08:2026: bossAttacks + enemyHelpers) |
| chaserAI.lua | entities/ | 310 | — | IA social Chaser: SOLO/DUPLA/MANADA, flancos, anillo, cierre |
| bossAttacks.lua | entities/ | 146 | — | 4 ataques del boss (projectile_spread, spawn_adds, radial_pulse, teleport) |
| enemyHelpers.lua | entities/ | 61 | — | validarPos, sampleFreeTile, tiles seguros |
| food.lua | entities/ | 133 | foodMod | Food spawning and types (NORMAL/GOLD/COIN) |
| obstacles.lua | entities/ | 103 | obstaclesMod | Obstacle placement |
| world.lua | world/ | 122 | worldMod | Facade: estado (etapa/sala/objetivoSala), getters, delega a dungeonGen/populate |
| dungeonGen.lua | world/ | 355 | — | BSP dungeon generation, room templates, stage modifiers (split 17:08:2026) |
| populate.lua | world/ | 193 | — | Room population (enemies/food/obstacles) (split 17:08:2026) |
| items.lua | systems/ | 100 | itemsMod | Item definitions (registry + 4 categorías) |
| shop.lua | systems/ | 376 | shopMod | Shop logic and UI |
| persistence.lua | systems/ | 362 | persistenceMod | Save/load system (profiles.dat + settings.dat con logo {offsetX,offsetY,scale,spacing,depth}, syncActiveProfile) |
| profiles.lua | systems/ | 344 | profilesMod | Facade: profile state, input, delega draw a profilesDraw (split 17:08:2026) |
| profilesDraw.lua | systems/ | 509 | — | Profile UI rendering (select/input/confirm/achievements) (split 17:08:2026) |
| achievements.lua | systems/ | 184 | achievementsMod | Achievement tracking (11 logros) |
| settings.lua | systems/ | 373 | settingsMod | Facade: audio/graphics/accessibility dat + state, delega draw a settingsDraw (split 17:08:2026) |
| settingsDraw.lua | systems/ | 261 | — | Settings tabs/controls/toasts rendering (split 17:08:2026) |
| player.lua | systems/ | 141 | playerMod | Cálculo velocidad/items del jugador, uso de ítems |
| gameflow.lua | systems/ | 105 | — | Runs/rooms: init run, reset sala |
| gamestates.lua | systems/ | 464 | — | Update por estado (7 estados): playing, death, highScore, transition |
| debugTools.lua | systems/ | 196 | — | Menú debug Tab + modal logros (facade, delega F2 a debugLogo) |
| debugLogo.lua | systems/ | 189 | — | Herramienta F2 logo (drag bbox, HUD 286×180, atajos, persistencia) (split 23:08:2026) |
| ui.lua | ui/ | 143 | uiMod | UI facade + estado/fuentes/accesibilidad (split 08:08:2026: sub-módulos) |
| introUI.lua | ui/ | 152 | — | Intro Balatro + high score |
| menuUI.lua | ui/ | 205 | — | Facade menú (panel 40% + 4 botones 260×40 gap14, delega a menuLogo/menuCard) (split 23:08:2026) |
| menuLogo.lua | ui/ | 129 | — | Logo procedural cian 2.5D (getBounds, draw, drawGlow) (split 23:08:2026) |
| menuCard.lua | ui/ | 214 | — | Tarjeta #11 Chunky 344×76 + moneda circular 3D + medalla (split 23:08:2026) |
| hudUI.lua | ui/ | 235 | — | Grid/HUD/slots/combo |
| toastsUI.lua | ui/ | 88 | — | Toasts |
| popupsUI.lua | ui/ | 49 | — | Popups |
| overlaysUI.lua | ui/ | 118 | — | Pausa/minimapa/dungeon debug |
| shaders.lua | render/ | 496 | shadersMod | Post-processing pipeline (bloom/CRT/shadow/heat, dedup SRC_BLUR 23:08:2026) |
| particles.lua | render/ | 156 | particlesMod | Particle effects (textura 4x4 procedural) |
| renderMain.lua | render/ | 308 | — | drawScene, dibujo menú/glow/shadow (split 08:08:2026) |
| enemiesDraw.lua | render/ | 285 | — | Draw enemigos + Chaser estrella de espinas |
| sound.lua | audio/ | 341 | — | Audio management (1 .ogg 4 segmentos + 10 SFX) |

## 3. State Machine

```
         ┌─────────────────────────────────────┐
         │                                     ▼
   MENU ──→ PLAYING ──→ TRANSITION ──→ SHOP ──→ PLAYING
    ▲         │  ▲                                    │
    │         │  └────────────────────────────────────┘
    │         ▼
    │    DEATH_ANIMATION ──→ HIGH_SCORE ──→ SHOP ──→ MENU
    │                      (if record)
    │
    └──←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←┘

   PLAYING ←──→ PAUSED (Space/Esc)
```

### State Values (`constants.lua`)
| State | Value | Description |
|-------|-------|-------------|
| MENU | 0 | Title screen with intro |
| PLAYING | 1 | Active gameplay |
| DEATH_ANIMATION | 2 | Death sequence |
| HIGH_SCORE | 3 | Record celebration |
| SHOP | 4 | Item shop |
| PAUSED | 5 | Game paused |
| TRANSITION | 6 | Room transition |

## 4. Data Flow

### Game Loop (`main.lua`)
```
love.load()
    └── persistence.initProfiles()
    └── applyActiveProfile()  (hacia world.state)

love.update(dt)
    └── sound.update(dt)  ← FIRST, before movement
    └── state-specific update

love.draw()
    └── state-specific render
    └── shaders.composite()  ← post-processing
    └── debug menu (if open)
```

### Collision Pipeline (`snake.mover()`)
```
Input: dt, direction
  │
  ├── 1. Check body collision → death
  ├── 2. Check obstacle collision → death
  ├── 3. Check boss collision → handle boss
  ├── 4. Check projectile collision → attackHit
  └── 5. Check enemy collision → enemyKilled

Returns: vivo, comio, enemyKilled, bossResult, attackHit
```

## 5. Rendering Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                    shaders.composite()                       │
│                                                             │
│  sceneCanvas                                                │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────┐                                                │
│  │  Bloom   │  glow → blurH → blurV → additive blend       │
│  └─────────┘                                                │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────┐                                                │
│  │ Shadow   │  blur pass                                    │
│  └─────────┘                                                │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────┐                                                │
│  │   CRT    │  final composite to canvasFinal               │
│  └─────────┘                                                │
│       │                                                     │
│       ▼                                                     │
│  canvasFinal → screen                                       │
└─────────────────────────────────────────────────────────────┘

Menu: additional heat distortion pass
Debug menu: drawn AFTER composite (no post-processing)
```

### 5.1 Main Menu Asymmetric UI Architecture & Procedural Cyan Isometric Title Pipeline (Opción A: docs → código)

El menú principal opera con una composición asimétrica de alto impacto visual distribuida en 3 zonas (Opción A — el código es canónico, `assets/title_style12*.png` solo fallback):

```
┌──────────────────────────────────────┬──────────────────┬──────────────────────────────────────┐
│ PANEL LATERAL IZQUIERDO (40% Ancho)  │ CENTRO (cx, cy)  │     SECTOR DERECHO (60% Ancho)       │
│ • Rectángulo y = 0..h, w = w * 0.40  │ • Diamante       │ • Logo procedural cian isométrico    │
│ • Fondo oscuro con alpha progresivo  │   Emblema        │   2.5D 5 letras 7×7 pScale/spacing  │
│ • Borde divisorio neón a la derecha  │ • Pulso senoidal │ • Pos vía getLogoBounds(t)          │
│ • 4 botones centrados verticalmente  │ • Núcleo divisor │ • Glow solo glint en drawGlow()     │
│ • Hitbox menuButtons                 │                  │ • Tarjeta #11 344×76 en rightCenterX │
└──────────────────────────────────────┴──────────────────┴──────────────────────────────────────┘
```

#### Pipeline Procedural Cian Neón (#00F0FF) — `ui/menuUI.lua:16-53,90-169` + `systems/persistence.lua:17,20-32` + `systems/debugTools.lua:13-501`

1. **Configuración paramétrica (`systems/persistence.lua:17,20-32`)**:
   - `settingsDefaults.logo = {offsetX=0, offsetY=0, scale=6, spacing=10, depth=5}` persistido en `config/settings.dat` (Lua table via `lua_encode`/`lua_decode`, `deep_merge` contra defaults).
   - `persistence.getLogoConfig()` lazy-load con `deep_copy` si falta `logo`; `saveLogoConfig(cfg)` escribe `settings.dat` inmediato.
   - Rangos validados en `systems/debugTools.lua:313-326,472-493`: `scale` 2–12 (`[`/`]`), `depth` 1–10 (`-`/`+`/`kp±`), `offsetX/Y` int vía flechas (±1, Shift ±10) o drag, `spacing` default 10.
   - **`menu.getLogoBounds(t)` (`ui/menuUI.lua:36-53`)** calcula posición canónica: `panelW=w*0.40`, `rightCenterX=panelW+floor((w-panelW)/2)`, `float=sin(t*1.5)*3`, `totalW=5*(7*pScale)+4*spacing`, `totalH=7*pScale`, `startX=rightCenterX-floor(totalW/2)+offsetX`, `startY=floor(h*0.36-totalH/2)+float+offsetY`. Retorna `startX,startY,totalW,totalH,depth,pScale,spacing,floatOffset`.

2. **Motor procedural (`menu.draw` título, `ui/menuUI.lua:90-169`)**:
   - 5 letras en matrices $7\times7$ (char `'X'` = bloque $pScale\times pScale$): `titleLetters[1..5]` para S,N,A,K,E (`" XXXXX "`, etc.).
   - **Extrusión isométrica 3D a $45^\circ$**: `for d=depth..1` con offset `(-d,+d)`, color por profundidad: `d==depth` → sombra negra `{0,0,0,0.95}`, `d>2` → `{0,0.28,0.38}`, else `{0,0.55,0.70}`; dibuja 5×7×7 rects por capa.
   - **Fachada frontal en 4 tonos cian neón** con bisel platino: si `distToSweep<12` → blanco puro; `elseif r==1||c==1` → platino `{0.70,0.96,1.0}`; `elseif r<=3` → cian neón `COLOR_CYAN`; `elseif r<=5` → `{0,0.72,0.85}`; else `{0,0.45,0.58}`. **Sweep** $sweepX=(t*160)\%(totalW+100)-50$, $distToSweep=|px-(startX+sweepX)|$; float ya aplicado vía `getLogoBounds`.
   - **Glint cruz blanca (#16)**: `glintX=startX+sweepX` en `[startX,startX+totalW]`, `glintY=startY+12`, rects $17\times3$ + $3\times17$ blancas, halo cian $9\times9$ al 0.85 y núcleo $3\times3$ blanco.

3. **Glow pass (`menu.drawGlow`, `ui/menuUI.lua:623-648`, invocado en `render/renderMain.lua:58-60`)**:
   - Solo el glint aporta a `shaders.beginGlow()`: rects $21\times5$ + $5\times21$ cian al `glowPulse*0.95` + $5\times5$ blanco al `glowPulse`, con $glowPulse=0.8+\sin(t*3.5)*0.2$.
   - **Fallback histórico no canónico**: `loadTitleAssets()` (`ui/menuUI.lua:16-34`) mantiene `assets/title_style12.png` / `title_style12_glow.png` vía `pcall` + `filesystem.getInfo` como respaldo heredado; Opción A los deja sin uso canónico.

4. **Tarjeta #11 Chunky (`ui/menuUI.lua:343-620`)**:
   - Dimensiones $cardW=344, cardH=76$; **posición real** `cardX=rightCenterX-floor(cardW/2)+200` (`ui/menuUI.lua:355`), $cardY=h-cardH-18$ (corrige docs previos `w-cardW-28`); registrada en `ui.menuButtons` como `card_profile` para hover/click → `profilesMod.open()`.
   - Chasis: sombra `g=3`, borde chunky 2px cian + delineado 1px negro, filo interior blanco, 4 condensadores $6\times6$ px en `(±g±1)`.
   - Fondos: izquierdo `#050c17` sólido, derecho `#0c1b2c` a $60^\circ$ vía `splitStartX=cardX+floor(cardW*0.52)` + loop `py` con `currentSplitX=splitStartX+floor(py*0.45)`; divisor cian cada 2px.
   - Moneda elipsoidal 3D: $R=5.0$, $coinRx=\max(0.5,R\cdot|\cos(t\cdot4.5)|)$, $thickness=\max(1,\lfloor2(1-|\cos|)+0.5\rfloor)$, canto cilíndrico por scanline y disco elíptico $spanW=coinRx\sqrt{1-(py/R)^2}$ con núcleo y sello paramétrico de 10 ptos.

5. **Herramienta de calibración F2 (`systems/debugTools.lua:13-501`, post-composite `render/renderMain.lua:261-263`)**:
   - Estado `World.state.debugLogoOpen` toggled por `F2` (`debugTools.toggleLogoDebug()` / `debugTools.keypressed` + `love.keypressed` en `main.lua`), con toast + `sound.play("buttonClick")` y `persistence.saveLogoConfig()` al cerrar.
   - **BBox interactivo**: `bx=startX-depth-4, by=startY-4, bw=totalW+depth+8, bh=totalH+depth+8` con fill `pulse*0.4` y line `pulse` donde $pulse=0.7+\sin(t*6)*0.3$, retícula central $(cx,cy)$ y badge `X: startX (Off: offsetX)  Y: startY (Off: offsetY)`.
   - **HUD $286\times180$** en $(w-286-10,10)$ con header `Offset: X:±d  Y:±d` + `Escala: scale  Espacio: spacing  Prof: depth`, 8 botones `[X-][X+][Y-][Y+]` ($62\times22$), `[Esc-][Esc+][Prof-][Prof+]` y 3 acciones `[RESET]($80\times24$)/[GUARDAR]($94\times24$)/[CERRAR]($82\times24$)`; leyenda `Flechas: Mover (Shift: 10px) / []: Escala | -/+: Prof | R: Reset / Enter/F2: Guardar`.
   - **Input**: `mousepressed` detecta HUD buttons (actualiza `cfg` y `saveLogoConfig()` inmediato) o hit en bbox inicia drag (`logoDebugDragging=true`, guarda `logoDragStartX/Y` + `logoInitialOffsetX/Y`); `mousemoved` actualiza `offset=floor(initial+delta)`; `mousereleased` guarda; `keypressed` maneja flechas (±1/Shift ±10), `[`/`]` escala 2–12, `-`/`+` depth 1–10, `R` reset a $(0,0,6,10,5)$, `Enter`/`Esc`/`F2` → `toggleLogoDebug()`+save. Persistencia inmediata en cada ajuste.
   - **Render post-composite** en `renderMain.drawGame()` `if debugTools.isLogoDebugOpen() then drawLogoDebug()` tras `shaders.composite()` + debug menu, para evitar bloom/shadow sobre el HUD.

6. **Panel y botones (hitbox)**:
   - `ui.menuButtons` registra `x= floor((panelW-bw)/2)` + `slideX=(1-btnAlpha)*-16`, `y= floor((h-totalMenuHeight)/2)+(i-1)*(bh+gap)+yOffset` (hover -2/pressed +2), con $bw=260, bh=40, gap=14$; verificación exacta en `menu.mousePressed()` y `menu.updateHover()` (hover dispara `sound.play("buttonHover")`).

## 6. Persistence Layer

### Files
| File | Format | Content |
|------|--------|---------|
| config/profiles.dat | Lua native | Profile data (max 3) |

### Sync Points
| Event | Action |
|-------|--------|
| Death | Sync highScore |
| Shop purchase | Sync coins + unlocks |
| SHOP↔MENU/PLAYING transition | Sync active profile |
| love.quit() | Final sync |

### Profile Data Structure
```lua
profile = {
    name = string,
    createdAt = os.time(),      -- fecha de creación
    monedas = number,           -- monedas presentes del perfil
    highScore = number,         -- highScore del perfil
    achievements = table,       -- 11 logros (id → {done=true, at=os.time()})
    unlocks = table,            -- passive item unlocks
    stats = {
        kills = number,
        bossesKilled = number,
        highestStage = number,
        highestScore = number,
        totalCoins = number,
        highestStreak = number  -- FASE 8 (planificado): racha máxima de supervivencia
    },
    skin = string               -- FASE 8 (planificado): id de paleta seleccionada
}
```

## 7. Key Algorithms

### Boss Food Defeat
- Boss `invulnerable = true`
- `hitBoss()` returns `{hit=true}` without damage
- Collecting food increments counter
- At `BOSS_FOOD_TARGET = 15`: `onBossDefeatedByFood()`

### Boss Health Bar Lerp
```
_uiBarFill = lerp(_uiBarTarget, _uiBarFill, 6.0 * dt)
```

### Enemy Spawning (during boss)
```
canSpawn(type):
    if type == red and count >= BOSS_MAX_RED (3): return false
    if type == blue and count >= BOSS_MAX_BLUE (4): return false
    return true
```

### Boss Enemy Lifetime
- After `BOSS_ENEMY_LIFETIME = 15s`:
  - Chasers → queued to `pendingRespawns` (5s delay)
  - Patrollers → removed

### Food Tile Reservation (boss room)
```
world.populateRoom() reserves 9 tiles:
    center tile + 8 adjacent tiles
```

## 8. Sound System

### Music Segments (.ogg)
| Segment | Time Range | Loop |
|---------|-----------|------|
| intro | 1-9s | No |
| comboEnter | 10-17s | No |
| comboLoop | 13-17s | Yes (crossfade) |
| boss | 18-24s | Yes |

### Crossfade Implementation
```
comboLoop uses nextLoopSource for seamless transition
CRITICAL: nextLoopSource must be :stop()'d before setting to nil
playSegment() cancels active crossfade before switching
```

### SFX (procedural, loaded in sound.load())
- eat, death, buy, shieldBreak, highScore, enemyKill, boss_food_tick, boss_defeated

## 9. Typography & Font Specifications

The project uses `PressStart2P-Regular.ttf` loaded dynamically with `pcall` and standard fallback support. Four official font sizes are used across all UI and render subsystems:

| Size | Usage / Placement | Module References |
|---|---|---|
| **28** | Título principal del juego (`S N A K E`), cabecera de "HIGH SCORE", textos de victoria/game over. | `ui/introUI.lua`, `ui/menuUI.lua`, `ui/popupsUI.lua` |
| **16** | Títulos de sección, botones principales del menú, cabecera de la Tienda, nombres de pestañas en Settings/Profiles. | `ui/menuUI.lua`, `ui/hudUI.lua`, `systems/shop.lua`, `systems/profilesDraw.lua`, `systems/settingsDraw.lua` |
| **11** | Textos estándar del HUD (Puntos, Monedas, Racha), descripciones de ítems, textos de logros y botones secundarios. | `ui/hudUI.lua`, `ui/toastsUI.lua`, `systems/shop.lua`, `systems/profilesDraw.lua`, `systems/settingsDraw.lua` |
| **8** | Pastillas de ayuda inferior (WASD / Flechas, Versión), subtextos de estadísticas, timestamps y popups numéricos pequeños. | `ui/menuUI.lua`, `ui/popupsUI.lua`, `systems/debugTools.lua`, `systems/settingsDraw.lua` |

## 10. Phase 8 Technical Architecture & Extensions

### 10.1 Survival Streak & Multiplier Pipeline

**Estado**: `world.state.survivalStreak` (flotante).
- `SURVIVAL_STREAK_START = 1.0`, `SURVIVAL_STREAK_STEP = 0.1`, `SURVIVAL_STREAK_MAX = 2.0` (config propuesto en `core/config.lua`).
- Incremento: `worldMod.avanzarSala()` suma `STEP` y clamp a `MAX`.
- Aplicación: en `systems/gamestates.lua` el cálculo de puntos y monedas de comida/kills multiplica por `survivalStreak`.
- Sunk on death: se resetea a `START` salvo que el modal "Continue" lo preserve.

| Sitio | Hook |
|---|---|
| Comer comida (`FOOD_NORMAL/GOLD/COIN`) | `total = floor(puntosBase * comboMult * scoreMultiplier * survivalStreak)`; `monedas += (monedasExtra + coinBonus) * survivalStreak` |
| Kill de enemigo (`enemyKilled`) | `monedas += enemyKilled.coins * survivalStreak` |
| Boss food-drop | `monedas += bossResult.coins * survivalStreak` |

**Métricas**: en `persistence.syncActiveProfile()` además se actualiza `stats.highestStreak = max(stats.highestStreak, survivalStreak)`.

### 10.2 Interactive Death (Continue / Accept) Modal

- Nuevo hook en `systems/gamestates.lua` `updateDeath()`: en lugar de desintegrar el cuerpo de inmediato, si `muerteInteractiva` está habilitado (`config.DEATH_MODAL_ENABLED = true`) y no hay revive consumido:
  1. Congelar sala (timer de pausa `deathModalOpen`), no degradar segmentos.
  2. Dibujar modal en `render/renderMain.lua` (o submódulo `ui/deathUI.lua`): botones `CONTINUAR (30$)` y `ACEPTAR MUERTE`.
  3. `CONTINUAR`: requiere `st.monedas >= REVIVE_COST (30)`; resta costo, coloca body en celda libre central, activa `REVIVE_INTANGIBLE_TIME = 3.0` (estado `intangible = true` en `snake.lua`, sin colisiones letales), conserva `survivalStreak`, cierra modal, sigue `PLAYING`.
  4. `ACEPTAR MUERTE`: `st.monedas = floor(st.monedas * (1 - DEATH_COIN_PENALTY))` con `DEATH_COIN_PENALTY = 0.3`, `survivalStreak = 1.0`, y continúa el despiece clásico → `HIGH_SCORE`/`SHOP` → `MENU`.
- Config propuesto: `REVIVE_COST = 30`, `REVIVE_INTANGIBLE_TIME = 3.0`, `DEATH_MODAL_ENABLED = true`, `DEATH_COIN_PENALTY = 0.3`.

### 10.3 Constrictor Loop Detection Algorithm

- **Trigger**: comer `CONSTRICTOR_BERRY` → `world.state.constrictTimer = CONSTRICTOR_DURATION (5.0)`.
- **Loop detection** (por paso de serpiente, mientras `constrictTimer > 0`):
  1. Si `head` es adyacente Manhattan a un segmento no-cabeza (cierre de anillo), construir polígono desde los segmentos del cuerpo.
  2. Para cada celda encerrada: **Ray Casting** (even-odd) sobre el polígono en coordenadas de grilla `(gx, gy)`.
  3. Toda celda de enemigo (chasers/patrollers/spawners) dentro del polígono → destrucción instantánea vía `enemies.killEnemy(idx)` + `particles.shockwave` + `sound.play("enemyKill")` + bonus combo.
  4. No aplica sobre `invulnerable = true` (boss).
- Config propuesto: `CONSTRICTOR_DURATION = 5.0`.

### 10.4 Special Foods (4)

Extender `entities/food.lua` con nuevos tipos y sus efectos temporizados en `systems/gamestates.lua` (bloque `comio`):

| Food | Config key propuesta | Efecto |
|---|---|---|
| Fire Pepper | `FIRE_PEPPER_DURATION = 3.5`, `FIRE_PEPPER_DAMAGE` | `world.state.fireTrailTimer`: rastro de fuego tras la cola; quema Chasers en celdas del camino |
| Frost Berry | `FROST_BERRY_DURATION = 2.5` | `world.state.frostTimer`: enemigos (`enemies.list` + boss) congelados (pausa su update) |
| Constrictor Berry | `CONSTRICTOR_DURATION = 5.0` | Ver §10.3 |
| Slimming Berry | `SLIMMING_MIN_LENGTH = 12`, `SLIMMING_FACTOR = 0.5` | Recorta `body` a `math.max(3, floor(#body * 0.5))` si `#body >= 12` |

- **Spawn**: en `world/populate.lua` al elegir tipo de comida en salas no-boss, con `SPECIAL_FOOD_CHANCE = 0.12`.
- **Boss room**: no se generan especiales (el food-target del boss cuenta todas las comidas no-moneda, especiales incluidas si aparecen por única mecánica existente de comida normal).
- **Puntos base**: las especiales heredan la base de comida normal (+10 pts / +1$), excepto que el efecto temporizado sea el diferencial.

### 10.5 Stage Biome Hazard Hooks
- `world/dungeonGen.lua` inyecta reglas de peligro por etapa en instancias de sala generadas (campo `room.biome` en `stageModifiers`):

| Etapa | Biome | Campo | Hook |
|---|---|---|---|
| 1 | Catacumbas | `biome="catacumbas"` | Estándar (sin hook) |
| 2 | Cripta Helada | `isIce=true` | `entities/snake.lua`: al girar sobre loseta de hielo, +1 celda extra de deslizamiento (momento inercial) |
| 3 | Caverna Volcánica | `hazardGrid` (termal) | `systems/gamestates.lua`: losetas térmicas se calientan/arden cíclicamente (timers `heatTimer`) |
| 4 | Colmena Tóxica | `isSlime=true` | `entities/snake.lua`: paso sobre loseta viscosa reduce velocidad 20% |
| 5 | Santuario del Vacío | `wallWrap=false` | `entities/snake.lua`: salir del borde = muerte instantánea (sin wrap) |

**Riesgo documentado (Fase 8)**: el bioma 5 con `wallWrap = false` rompe las IA que asumen bordes envolventes (Patrollers rebotan, Spawners generan adyacentes, Chasers evalúan 4 direcciones con bounds). Medidas de mitigación previstas:
- Patrollers: en `wallWrap=false` rebotan también contra los bordes de la grilla (como ante obstáculo).
- Spawners: solo generan en celdas interiores no-borde.
- Chasers: la evaluación de 4 direcciones ya excluye celdas fuera de grilla (sin cambio; reforzar test de borde).
- **Ajuste de balance**: reducir caps de enemigos en bioma 5 (`BIOME5_ENEMY_CAP = 2` chasers, `3` patrollers) para compensar el espacio usable reducido.

### 10.6 Elite Encounters (Sala 3)

- En `world/dungeonGen.lua` (`selectTemplateForRoom` / generación), la **sala 3** de cada etapa se marca con `isElite = true`.
- `world/populate.lua`: en salas elite, el spawn de un enemigo usa estadísticas élite (multiplicadores):
  - `ELITE_HP_MULT = 2.0`, `ELITE_SPEED_MULT = 1.3`, `ELITE_DROP_MULT = 3.0` (config propuesta).
  - Un tipo de enemigo se convierte en élite (el de mayor peso de la etapa) + se garantiza un `cofre dorado` (drop de ítem/objeto dorado, +drop de monedas equivalente a `goldenChest`).
- Ganar sala elite otorga bonus de `survivalStreak +0.2` (además del +0.1) y `monedas` extra vía cofre dorado.

### 10.7 Unlockable Endgame Modes

- Estado en `world.state.modo` (string): `estandar` / `endless` / `rush` / `pacifista`. Almacenado en perfil (`profile.modo`), persistido por `persistence.lua`.
- Desbloqueos:
  - **Endless Abyss**: `profile.stats` → vencer Etapa 5 (mismo evento que `bossDefeated` en etapa 5).
  - **Time Attack / Rush**: récord de 3000 pts (`score_1000`/`score_5000` thresholds) o `highScore >= 3000`.
  - **Pacifist (Ghost Runner)**: logro `stage_3`.
- Hooks en `systems/gameflow.lua` y `world/world.lua`:
  - `endless`: `avanzarSala()` no termina en la sala 5 de la etapa 5; los `stageModifiers` escalan por etapa/índice infinito (reusar `stageMod` con `etapa = 1 + floor(sala/10)`).
  - `rush`: `world.state.timeLimit = 180`; al agotar → fin de run; `scoreMultiplier` fijo x3 (triple); spawn de comida acelerado.
  - `pacifista`: `world.state.pacifist = true`; `systems/player.lua` desactiva ítems ofensivos (bomb) y `gamestates.lua` ignora kills (sin monedas ni combo por kills); supervivencia por evasión.

### 10.8 Snake Customization & Palettes

- Estado: `world.state.skin` (string id). Persistido en perfil (`persistence.syncActiveProfile()` → `profile.skin`).
- Registro de paletas en `core/config.lua`: `config.SKINS = { classic = {...}, neon = {...}, midas = {...}, fire = {...}, ghost = {...} }`, cada uno `{ base = {r,g,b}, glow = {r,g,b} }`.
- Desbloqueo por logro (eventos `achievementsMod.check`): 
  - `neon` → `enemy_100` · `midas` → `score_5000` · `fire` → `boss_kill` · `ghost` → `stats.highestStreak >= 10`.
- Aplicación en render: `render/renderMain.lua` / `render/enemiesDraw.lua` no se ven afectados (lectura de color) — los colores del cuerpo usan `SKINS[world.state.skin].base`; glow en `shaders.lua` usa `SKINS[world.state.skin].glow`.
- UI: selector en `systems/settings.lua` (tab "Personalización" o en profiles) con preview, solo skins desbloqueados.

### 10.9 Item Synergies Engine Architecture

El sistema de sinergias opera de forma reactiva y no intrusiva sobre `systems/items.lua` y `systems/player.lua`:

* **Estructura de Definición**:
```lua
items.synergies = {
    reactive_shield = { items = {"shield", "bomb"}, onBreak = "triggerBombNova" },
    golden_vortex   = { items = {"magnet", "doubler"}, onAttract = "doubleReward" },
    spectral_comet  = { items = {"ghost", "turbo"}, onMoveThrough = "destroyCollided" },
    time_overload   = { items = {"turbo", "slow"}, onTick = "bulletTime" }
}
```
* **Hook de Verificación**: Al comprar o equipar cualquier ítem en `shop.lua`, se evalúa `items.checkSynergies(inventory)` y se activan los flags correspondientes en `world.state.activeSynergies`.
* **Dispatchers**:
  - `snake.mover()` consulta `world.state.activeSynergies.spectral_comet` para destruir enemigos atravesados durante el turbo fantasmal.
  - `systems/gamestates.lua` al romper un escudo ejecuta `items.triggerSynergy("reactive_shield")` si está activa.

### 10.10 Mini-Bosses & Threat State Machine Architecture

Los Mini-Jefes de Sala 3 se implementan extendiendo `entities/enemies.lua` y `entities/bossAttacks.lua` bajo un patrón de máquina de estados unificada:

```
[SPAWN] ──→ [IDLE / PATROL] ──→ [TELEGRAPH ATTACK] ──→ [EXECUTE ACTION] ──→ [COOLDOWN]
                 ▲                                                              │
                 └──────────────────────────────────────────────────────────────┘
```

* **Estructura de Datos del Mini-Jefe**:
```lua
miniboss = {
    id = "wall_crusher",        -- "frost_golem", "magma_wyrm", "brood_queen", "void_phantom"
    gx = 10, gy = 10,           -- Coordenadas de grilla (origen 2x2)
    w = 2, h = 2,               -- Tamaño en tiles
    hp = 4, maxHp = 4,          -- Golpes requeridos
    foodDefeatTarget = 8,       -- Comidas alternativas para derrotarlo
    state = "idle",             -- "telegraph", "charging", "cooldown"
    stateTimer = 0,
    telegraphCells = {},        -- Celdas marcadas para daño
    alive = true
}
```
* **Integración con Render**: `render/enemiesDraw.lua` incluye `drawMiniBoss(mb, dt)` con interpolación suave de posición, sombra proyectada y barra de salud superior.

### 10.11 Object Pooling & Zero-GC Memory Architecture

Para mantener 60 FPS estables y evitar micro-tirones por recolección de basura (*Garbage Collection stutter*) en salas de alta densidad (ej. proyectiles de mortero, rastro de fuego, esquirlas de hielo y partículas):

1. **Pools Estáticos Preasignados**:
   - `telegraphPool`: 32 tablas preasignadas `{gx, gy, timer, attackType, active}`.
   - `projectilePool`: 64 tablas preasignadas `{px, py, vx, vy, lifetime, active}`.
   - `hazardPool`: 64 celdas preasignadas para baba, lava y pinchos.
2. **Ciclo de Reutilización**: En lugar de `table.insert()` y `table.remove()`, los sistemas iteran sobre el pool activando `active = true` al spawnear y `active = false` al expirar, sin asignar tablas temporales en el game loop.

### 10.12 Biome Shaders & Post-Processing Extension

El pipeline de shaders en `render/shaders.lua` se amplía con 3 nuevos efectos aplicados condicionalmente según `worldMod.etapa`:

1. **Ice Frost Shader (Etapa 2 - Cripta Helada)**:
   - Viñeta de cristal de hielo en los bordes de la pantalla con aberración cromática sutil en las esquinas.
2. **Heat Distortion & Magma Glow (Etapa 3 - Caverna Volcánica)**:
   - Mapa de distorsión de calor senoidal con tinte rojizo/ámbar sobre las baldosas ardientes.
3. **Void Vignette & Gravitational Lens (Etapa 5 - Santuario del Vacío)**:
   - Distorsión de lente gravitatoria alrededor de agujeros negros y viñeta púrpura profunda en los bordes letales.

### 10.13 Tarot Draft Engine & Stage Card Architecture

* **Almacenamiento de Estado**: `world.state.stageCards` (array de strings con hasta 3 IDs de cartas activas).
* **Ciclo de Vida**:
  - `worldMod.avanzarEtapa()`: reinicia `stageCards = {}`.
  - Al completar salas 1, 2 y 4: `gamestates.lua` abre el estado `GAME_STATE_TAROT_DRAFT` (o modal integrado en `TRANSITION`).
  - Muestreo: selecciona 3 cartas aleatorias de `config.TAROT_CARDS` garantizando que no estén ya equipadas.
* **Hooks de Ejecución**:
  - `snake.mover()` consulta `hasTarot("mercury")` (+15% velocidad), `hasTarot("iron_spine")` (inmunidad en últimos 3 segmentos) y `hasTarot("astral_mirror")` (1 wrap de pared extra).
  - `foodMod.generar()` consulta `hasTarot("alchemical_digestion")` para aplicar el +25% de transformación a oro.

### 10.14 Mystery Room Templates & Generation Hooks

* **Extensión de `world/dungeonGen.lua`**:
  - Tabla de plantillas especiales `dungeonGen.mysteryTemplates`:
    - `gambler_den`: Genera entidad de ruleta central con estado de apuesta.
    - `doppelganger`: Instancia un objeto `enemies.doppelganger` que almacena una cola de inputs pasados de la serpiente con un buffer de 1.2s.
    - `gold_rush`: Configura temporizador de sala en 12.0s y spawnea 20 entidades cinemáticas de monedas con rebote elástico.
    - `trial_triads`: Marca 3 celdas con secuencia requerida `(1, 2, 3)` y valida el orden de paso de la cabeza.

### 10.15 Status Effects Runtime Pipeline

* **Gestor de Micro-Estados en `core/world.lua`**:
```lua
world.state.statusEffects = {
    overdrive = { active = false, timer = 0 },
    petrification = { active = false, timer = 0 },
    confusion = { active = false, timer = 0 },
    cryostasis = { active = false, timer = 0 }
}
```
* **Integración en Game Loop**:
  - `systems/gamestates.lua` descuenta `timer -= dt` en cada frame.
  - `Overdrive`: Si `comboCount >= 6`, activa `overdrive.active = true` con `timer = 4.0`. En `snake.mover()`, la colisión con obstáculos ejecuta `obstaclesMod.destruir(gx, gy)` en lugar de matar a la serpiente.
  - `Confusion`: En `core/touch.lua` y `entities/snake.lua`, si `confusion.active`, invierte los vectores de input `(dirX, dirY) = (-dirX, -dirY)`.

### 10.16 Meta-Progression Shrine & Persistence Architecture

* **Estructura de Datos en Perfil (`config/profiles.dat`)**:
```lua
profile.talents = {
    heritage_pouch  = 2,    -- Rango actual (0 a 3)
    residual_magnet = 1,    -- Rango actual (0 a 2)
    dragon_stomach  = 2,
    thick_potions   = 1,
    sixth_sense     = 1,
    mercy_pact      = 0,
    iron_body       = 1,
    hunter_focus    = 2
}
```
* **Aplicación en `gameflow.resetGame()`**:
  - `st.monedas = profile.talents.heritage_pouch * 5`.
  - `st.magnetRange = profile.talents.residual_magnet > 0 and profile.talents.residual_magnet or 0`.
  - `COMBO_WINDOW = 8.0 + (profile.talents.hunter_focus * 1.0)`.

### 10.17 Daily PRNG Seed & Bounty Verification Engine

* **Generador de Semilla Diaria**:
```lua
function gameflow.getDailySeed()
    local d = os.date("*t")
    return d.year * 10000 + d.month * 100 + d.day
end
```
* **Bounty Verification**:
  - Al inicio de la run, se generan 2 contratos desde `config.BOUNTY_POOL`.
  - `achievementsMod.check()` o `gamestates.lua` emite eventos de progreso (`bountyProgress(id, amount)`).
  - Al completar el objetivo en partida, se muestra un popup dorado en pantalla y se añaden las monedas directamente a `st.monedas`.

### 10.18 Procedural Snake Rendering Engine & Skin Registry Architecture

Para soportar el catálogo maestro de más de 200 variantes sin impacto en la memoria ni GC churn:

```
[world.state.skin] ──→ [core/config.SKINS registry]
                             │
       ┌─────────────────────┴─────────────────────┐
       ▼                                           ▼
[Geometry Primitive Dispatcher]             [Particle & Shader FX]
├── drawClassic(seg, idx, total)            ├── glowColor → shaders.composite()
├── drawShard(seg, idx, total)              ├── trailEmitter → particles.snakeTrail()
├── drawDotMatrix(seg, idx, total)          └── eatPulseWave → shockwaves table
├── drawWireframe(seg, idx, total)
├── drawHexMesh(seg, idx, total)
└── drawBarcode(seg, idx, total)
```

* **Estructura del Registro en `core/config.lua`**:
```lua
config.SKIN_REGISTRY = {
    arcane_neon = {
        name = "Neón Arcano",
        primitive = "shard",           -- "classic", "shard", "dot_matrix", "wireframe", "hex", "barcode"
        baseColor = {0.0, 0.9, 1.0},
        glowColor = {0.8, 0.2, 1.0},
        tailColor = {0.05, 0.1, 0.3},
        trailType = "linear_sparks",
        eatEffect = "luminescent_pulse"
    },
    wireframe_dragon = {
        name = "Dragón Wireframe",
        primitive = "wireframe",
        baseColor = {1.0, 0.4, 0.1},
        glowColor = {1.0, 0.8, 0.0},
        tailColor = {0.3, 0.1, 0.0},
        trailType = "flame_vectors",
        eatEffect = "fire_burst"
    }
}
```

* **Optimizaciones Zero-GC**:
  - Reutilización estricta del búfer de vértices `local hexVertices = {0,0, 0,0, 0,0, 0,0, 0,0, 0,0}` preasignado a nivel de módulo en `render/renderMain.lua`.
  - Cálculo de gradientes cromáticos mediante interpolación lineal de componentes RGB en registros de CPU sin instanciar tablas temporales por segmento.

### 10.19 Extended Items & Tactical Abilities Engine

* **Mapeo de Habilidades en `entities/snake.lua`**:
  - `autotomy(player)`: Remueve 4 segmentos de `player.body`, genera una entidad señuelo `enemies.decoy` en `(seg.x, seg.y)` con `timer = 3.0`.
  - `reverseSlither(player)`: Invierte el array `player.body` (`body[1] = tail`), recalcula `(dirX, dirY)` hacia el vector libre anterior.
  - `tailSnap(player)`: En flanco de giro 180°, evalúa celdas adyacentes a `body[#body]` y aplica `enemy.pushback(1)` + `enemy.stun(0.8)`.
* **Registro de Nuevos Ítems (51–60) en `systems/items.lua`**:
  - `tail_spike`: Activo que añade coordenadas a `world.state.placedTraps` (máx 3).
  - `hourglass`: Mantiene un búfer circular de 120 estados pasados (`historyBuffer`) para restaurar posición en $t - 2.0\,\text{s}$.
  - `orbital_beam`: Genera un colisionador continuo vertical `rect(head.x * tam, 0, tam, canvasHeight)` durante 2.5s.
  - `emergency_battery`: Hook en `snake.mover()` cuando `vivo == false`: activa `timeScale = 0.1` durante 1.5s antes de confirmar la muerte.

### 10.20 Boss Enrage & Laser Perimeter Collision Pipeline

* **Enrage State Machine**: En `entities/enemies.lua` `updateBoss()`, si `boss.foodCollected >= boss.foodTarget - 3`, conmuta `boss.enraged = true`, multiplica velocidades de ataque por $1.35$ y ajusta el pitch musical a $1.15$.
* **Laser Perimeter Pipeline**:
  - Telegrafiado: 4 líneas en `render/renderMain.lua` con `telegraphTimer = 1.0`.
  - Fase Activa: Genera 4 rayos continuos `(x1, y1) → (x2, y2)`. `snake.mover()` comprueba intersección de segmento de línea con la cabeza mediante `mathHelpers.lineIntersectsCell()`.

### 10.21 Accessibility, Keybind Mapping & Performance Metrics Engine

* **Colorblind Shaders en `render/shaders.lua`**:
  - Shader post-composite con matrices de transformación cromática para Protanopía, Deuteranopía y Tritanopía aplicadas antes de la viñeta final.
* **Vectorial Screen Shake**:
  - `shakeVector = {x = dirX * intensity, y = dirY * intensity}`; la traslación de la cámara amortigua según `shakeVector * math.sin(time * 30)`.
* **Auto-Pause en `main.lua`**:
  - Callback `love.focus(f)`: Si `not f` y `gameState == GAME_STATE_PLAYING`, conmuta automáticamente a `GAME_STATE_PAUSED`.
* **Mapeo de Teclas en `core/config.lua`**:
  - Tabla de asignación dinámica `config.KEYBINDS = { up = {"w", "up"}, down = {"s", "down"}, item1 = {"1", "kp1"}, autotomy = {"q", "triggerleft"} }`.

### 10.22 Held-Key Tactical Slither Engine (Pipeline de Movimiento Sostenido)

* **Estructura en `entities/snake.lua` y `systems/gamestates.lua`**:
```lua
function snake.isDirectionHeld()
    if settings.get("movementMode") == "classic" then
        return true -- Avance automático continuo
    end
    for _, key in ipairs(config.KEYBINDS.up)    do if love.keyboard.isDown(key) then return true,  0, -1 end end
    for _, key in ipairs(config.KEYBINDS.down)  do if love.keyboard.isDown(key) then return true,  0,  1 end end
    for _, key in ipairs(config.KEYBINDS.left)  do if love.keyboard.isDown(key) then return true, -1,  0 end end
    for _, key in ipairs(config.KEYBINDS.right) do if love.keyboard.isDown(key) then return true,  1,  0 end end
    return touch.isDragging()
end
```
* **Integración en `snake.update(dt)`**:
  - El temporizador de avance de cuadrícula `stepTimer` acumula `dt` **únicamente si `isDirectionHeld()` retorna `true`**.
  - Si no hay dirección sostenida:
    - La serpiente no ejecuta `snake.mover()`.
    - Las entidades enemigas (`enemies.update(dt)`), proyectiles (`bossAttacks.update(dt)`), partículas y shaders continúan su ciclo de actualización en tiempo real con normalidad.

### 10.23 Core Engine & Optimization Pipeline (Input, AABB Pre-Filter & Determinism)

#### 1. Input Ramp-Up & Corner Buffering (`entities/snake.lua`)
* **Input Ramp-Up**: Variable `local holdTime = 0`. Al pasar de `isHeld == false` a `true`, el primer `stepTimer` requiere un threshold de `interval + 0.03` antes del primer paso.
* **Corner Buffering**: Si se registra una tecla perpendicular a distancia Manhattan $= 1$ de un obstáculo/borde, el vector se encola en `inputQueue[2]` y se despacha automáticamente en el frame de colisión inminente.

#### 2. Ray Casting AABB Pre-Filter (`entities/snake.lua`)
```lua
local function getSnakeAABB(body)
    local minX, maxX = body[1].x, body[1].x
    local minY, maxY = body[1].y, body[1].y
    for i = 2, #body do
        local b = body[i]
        if b.x < minX then minX = b.x elseif b.x > maxX then maxX = b.x end
        if b.y < minY then minY = b.y elseif b.y > maxY then maxY = b.y end
    end
    return minX, minY, maxX, maxY
end
```
* Solo las celdas dentro del rectángulo `[minX..maxX, minY..maxY]` son sometidas al test *Point-in-Polygon*, reduciendo el coste algorítmico de $\mathcal{O}(W \times H)$ a $\mathcal{O}(AABB)$.

#### 3. Fixed Timestep & Zero-Allocation Memory Audit
* Bucle determinista desacoplado de la tasa de refresco del monitor:
```lua
local accumulator = 0
local FIXED_DT = 1 / 60
function love.update(dt)
    accumulator = accumulator + math.min(dt, 0.1)
    while accumulator >= FIXED_DT do
        tickFixed(FIXED_DT)
        accumulator = accumulator - FIXED_DT
    end
end
```
* Auditoría de memoria: Ejecución en test unitario de `local m1 = collectgarbage("count")` antes y después de 3600 frames con asserts estrictos de $\Delta M = 0\,\text{KB}$.

### 10.24 Visual Pipeline & Shader Architecture for Aesthetic Enhancements

#### 1. Dynamic Lighting & 2D Drop Shadow Pass (`render/renderMain.lua`)
```
[Scene Objects] ──→ [45° Shadow Pass (Alpha 0.35)] ──→ [Diffuse Floor Canvas]
                                                              │
[Head Conic Light] + [Antorcha Lights] ───────────────→ [Light Multiplier Pass]
                                                              │
[Bloom Selective Threshold (>0.8)] ───────────────────→ [Composite Canvas]
```
* **Sombra Arrojada**: Las primitivas dibujan un clon desplazado `(+3, +3)` con color `{0, 0, 0, 0.35}` antes del pase de color principal.
* **Foco Cónico Frontal**: Se dibuja un polígono de 5 vértices con gradiente de transparencia en un canvas de luz multiplicativo `lightCanvas`.

#### 2. Procedural Autotiling Hash (`world/dungeonGen.lua`)
```lua
local function getTileVariant(gx, gy, seed)
    local h = (gx * 374761393 + gy * 668265263 + seed) % 100
    if h < 60 then return 1      -- Losa estándar limpia
    elseif h < 80 then return 2  -- Losa con grieta
    elseif h < 95 then return 3  -- Losa con relieve rúnico
    else return 4 end            -- Losa con desgaste/moho
end
```

#### 3. Thresholded Multi-Pass Bloom (`render/shaders.lua`)
* El shader de brillo solo extrae fragmentos donde $\max(R, G, B) > 0.8$, evitando sobreexponer el suelo o los muros oscuros:
```glsl
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    if (luma > 0.8) {
        return tex * color;
    }
    return vec4(0.0);
}
```

#### 4. Metameric Wave Interpolation & Squash/Stretch (`entities/snake.lua`)
* En cada cambio de cuadrícula, el render interpola suavemente la posición entre `(prevX, prevY)` y `(currX, currY)` usando `t = stepTimer / interval`.
* Durante aceleración (`isHeld` prolongado), la cabeza se escala a `(1.15, 0.85)` a lo largo de su eje director, recuperando `(1.0, 1.0)` con amortiguación elástica.

#### 5. Half-Res FBO Specular Reflections (`render/shaders.lua`)
* Asignación en `shaders.load()`:
```lua
shaders.reflectionCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT / 2)
```
* En `renderMain.lua`, la escena invertida se dibuja en `reflectionCanvas`, se aplica un desenfoque horizontal rápido de 3 taps y se mezcla aditivamente sobre el `floorCanvas` con opacidad $0.25$.

#### 6. Voronoi Glass Fracture Shader (`render/shaders.lua`)
* Shader GLSL que toma 8 semillas precalculadas y calcula la distancia euclidiana mínima $d = \min_{i} \|p - s_i\|$. Si $\left|d_1 - d_2\right| < 0.015$, dibuja una arista blanca brillante simulando grietas de vidrio en Game Over.

### 10.25 Architecture & DX Proposals (GDD §21.4) — Implementación Pendiente
Las propuestas del Bloque 4 del GDD §21.4 que afectan arquitectura se catalogan aquí con su módulo destino. Estado inicial: backlog (pendiente de priorización y resolución de duplicados).

| Propuesta (§21.4) | Módulo(s) destino | Nota de implementación |
|---|---|---|
| **Event bus desacoplado** | `core/events.lua` (nuevo) | `Events.emit("death", {...})` / `Events.on("death", cb)`; migrar llamadas directas de achievements/persistence a suscriptores. Sin globals: módulo `local E = {}`, `return E`. |
| **Timers consolidados** | `core/timers.lua` | Ampliar API existente con tipos (once/loop/priority) y un único update desde `love.update()`; reusar pooling ya presente. |
| **Presets de dificultad** | `core/config.lua`, `world/populate.lua` | Tabla `DIFFICULTY = { relaxed={...}, normal={...}, intense={...} }` que escala spawn counts/caps; selección por perfil. |
| **Escalado de UI por resolución** | `ui/ui.lua`, `config.lua` | Factores proporcionales `w/640`, `h/360` aplicados a fuentes/espaciado; percentiles clamps para evitar superposición. |
| **Perfilado en runtime** | `systems/debugTools.lua` | Solapa en debug menu (Tab) con `avgMs` por sistema (movimiento, IA, render, shaders) vía timers de `love.update()`. |
| **Escritura atómica profiles.dat** | `systems/persistence.lua` | Escribir a `profiles.dat.tmp` + `os.rename`; merge de lecturas con `pcall` y backup `.bak` si corrupción. |
| **Asset manager formal** | `core/assets.lua` (nuevo) | Caché de fuentes/FBOs/canvases: `Assets.get("font_16")`; cero creación por frame (refuerza regla Zero-GC). |
| **Reducción de movimiento** | `settings.lua`, `render/renderMain.lua`, `systems/gamestates.lua` | `settings.accessibility.motion` pausa screen shake, hitstop y flashes; overlay de confirmación al activar. |
| **Reanudar run activa** | `systems/persistence.lua`, `core/world.lua` | Guardar snapshot de `World.state` + snake/food/enemies al salir; rehydrate en `love.load` si `world.state.resumeKey`. Ver §2.4. |
| **Smoke tests headless** | raíz `test/` (nuevo) | Suíte con `love . --test`: corre `snake.mover()`, colisiones y economía sin render; salida por `Log.info`. |
| **Tweaks avanzados** | `settings.lua` | Subconjunto de constantes (speed base, caps) leídas de `settings.json` con validación de rango y valores por defecto. |
| **schema_version de perfil** | `systems/persistence.lua` | Campo `schema_version` en `profiles.dat`; función de migración idempotente por bump (inicial = 1). |
| **i18n con fallback** | `core/i18n.lua` (nuevo), `ui/` | `I18n.t("shop.buy")` con diccionarios `locales/es.lua`, `en.lua`, `pt.lua`; fallback cadena clave en inglés si ausente. |
| **Input centralizado** | `core/input.lua` (nuevo) | `Input.action("left")` unifica teclado/ratón/gamepad/touch; prepara gamepad ROADMAP Fase 9; `Input.update()` en `love.update()`. |
| **Guía DX de extensión** | `docs/` | Checklist 10 pasos + scaffolding para añadir enemigo/ítem; referencia la convención `local X = {}` / `return X`. |

## 11. Love2D Gotchas

| Wrong | Correct |
|-------|---------|
| `ParticleSystem:count()` | `ParticleSystem:getCount()` |
| `ParticleSystem:setLifetime(min,max)` | `ParticleSystem:setParticleLifetime(min,max)` |
| Using `dt` in `love.draw()` | Timers in `love.update()` |
| Font without fallback | `pcall` with fallback for PressStart2P |

## 12. Global Variables Convention

All gameplay state is managed in `core/world.lua` as `World.state` (no globals).
Access via `world.state.X` (in main.lua) or `world.get("X")` from other modules.

### World-managed state keys
- `puntuacion`, `monedas`, `highScore`, `comboCount`, `comboFlashTimer`, `comboDisplay`, `survivalStreak`
- `gameState`, `time`, `timeScale`, `menuPS`, `celebrationTimer`, `nuevoHighScore`
- `transitionTarget`, `transitionPhase`, `transitionHoldTimer`, `fadeDir`, `fadeAlpha`
- `mundoCompletado`, `bossHealthDisplay`, `debugMenuOpen`, `debugImmune`
- `debugAchievementsOpen`, `debugDungeonOverlay`, `debugButtons`, `debugAchievementModalButtons`
- `pendingAchievements`, `scheduledToasts`, `scheduledIndex`, `introTimer`, `shakeTimer`
- `activePS`, `activeTimers`, `shockwaves`, `scoreMultiplier`, `coinBonus`
- `anchoGrilla`, `altoGrilla`, `gridOffsetX/Y`, `gameOffsetY`, `baseSpeed`, `velocidadActual`
- `frutasContador`, `cronometro`, `deathAnimTimer`, `lastObstacleScore`, `lastEatTime`
- `magnetRange`, `player`
- **Fase 8 (planificado)**: `constrictTimer`, `fireTrailTimer`, `frostTimer`, `deathModalOpen`, `reviveIntangible` / `intangible`, `modo` (estandar/endless/rush/pacifista), `skin`, `hazardGrid`, `timeLimit` (rush)

### Migration status
- `debugImmune`: entities/snake.lua reads via local `immune()` → `world.get("debugImmune")`
- `monedas`/`highScore`: systems/persistence.lua `syncActiveProfile()` → `world.get(...)`
- `pendingAchievements`/`scheduledToasts`/`scheduledIndex`/`time`: systems/achievements.lua → `world.get(...)`

Colors as `{r,g,b}` or `{r,g,b,a}` tables.

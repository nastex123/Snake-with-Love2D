# Technical Design Document — Snake Dungeon Crawler

## 1. Architecture Overview

**Pattern**: Procedural module-based with global state management  
**Entry Point**: `main.lua`  
**Total Modules**: 18 + helpers  
**Total Lines**: ~7,100

### Folder Structure

```
Snake-with-Love2D/
├── main.lua, constants.lua     ← raíz (constants.lua = shim → core/config.lua)
├── core/
│   ├── config.lua              ← configuracion central (canvas, gameplay, colores, boss)
│   ├── logger.lua              ← Log.info/warn/error/debug
│   ├── timers.lua              ← timer manager (after/every/cancel/clear, object pooling)
│   └── helpers.lua             ← deep_copy, math/rect utilities
├── entities/
│   ├── snake.lua, enemies.lua, food.lua, obstacles.lua
├── world/
│   └── world.lua
├── systems/
│   ├── items.lua, shop.lua, persistence.lua, profiles.lua, achievements.lua, settings.lua
├── ui/
│   └── ui.lua
├── render/
│   ├── shaders.lua, particles.lua
└── audio/
    └── sound.lua
```

### Module Dependency Graph

```
main.lua (raíz)
├── constants.lua (raíz)
├── core/config.lua
├── core/logger.lua
├── core/timers.lua
├── core/world.lua ← estado del juego (reemplaza globals)
├── entities/snake.lua ──→ systems/shop.lua, entities/enemies.lua, core/world.lua
├── entities/enemies.lua
├── entities/food.lua
├── entities/obstacles.lua
├── world/world.lua ──→ core/helpers.lua
├── systems/items.lua
├── systems/shop.lua ──→ systems/items.lua
├── systems/persistence.lua → audio/sound.lua, ui/ui.lua, render/shaders.lua, core/helpers.lua, core/world.lua
├── systems/profiles.lua → systems/persistence.lua, ui/ui.lua, systems/achievements.lua
├── systems/achievements.lua → systems/persistence.lua, core/world.lua
├── systems/settings.lua → systems/persistence.lua, core/helpers.lua, ui/ui.lua, render/shaders.lua
├── ui/ui.lua
├── render/shaders.lua
├── render/particles.lua
└── audio/sound.lua
```

## 2. Module Responsibilities

| Module | Folder | Lines | Alias | Responsibility |
|--------|--------|-------|-------|----------------|
| main.lua | raíz | 380 | — | Game loop, state machine, orchestration (split 08:08:2026) |
| constants.lua | raíz | 3 | — | Shim → core/config.lua (legacy compatibility) |
| config.lua | core/ | 183 | — | Centralized configuration |
| logger.lua | core/ | 44 | Log | Logging (info/warn/error/debug) |
| timers.lua | core/ | 90 | — | Timer manager with object pooling |
| world.lua | core/ | 28 | world | World state container (no globals) |
| helpers.lua | core/ | 52 | — | Utility functions |
| snake.lua | entities/ | 440 | snakeMod | Movement, collision detection |
| enemies.lua | entities/ | 520 | enemiesMod | Enemy AI, boss logic (split 08:08:2026: bossAttacks + enemyHelpers) |
| food.lua | entities/ | 133 | foodMod | Food spawning and types |
| obstacles.lua | entities/ | 103 | obstaclesMod | Obstacle placement |
| world.lua | world/ | 122 | worldMod | Facade: state (etapa/sala/objetivoSala), getters, delegates to dungeonGen/populate |
| world/dungeonGen.lua | world/ | 355 | — | BSP dungeon generation, room templates, stage modifiers (split 17:08:2026) |
| world/populate.lua | world/ | 193 | — | Room population (enemies/food/obstacles) (split 17:08:2026) |
| items.lua | systems/ | 100 | itemsMod | Item definitions |
| shop.lua | systems/ | 376 | shopMod | Shop logic and UI |
| persistence.lua | systems/ | 348 | persistenceMod | Save/load system |
| profiles.lua | systems/ | 344 | profilesMod | Facade: profile state, input, delegates draw to profilesDraw (split 17:08:2026) |
| profilesDraw.lua | systems/ | 509 | — | Profile UI rendering (select/input/confirm/achievements) (split 17:08:2026) |
| achievements.lua | systems/ | 184 | achievementsMod | Achievement tracking |
| settings.lua | systems/ | 373 | settingsMod | Facade: audio/graphics/accessibility dat + state, delegates draw to settingsDraw (split 17:08:2026) |
| settingsDraw.lua | systems/ | 261 | — | Settings tabs/controls/toasts rendering (split 17:08:2026) |
| ui.lua | ui/ | 142 | uiMod | UI facade + state/fonts (split 08:08:2026: intro/menu/hud/toasts/popups/overlays) |
| shaders.lua | render/ | 458 | shadersMod | Post-processing pipeline |
| particles.lua | render/ | 156 | particlesMod | Particle effects |
| sound.lua | audio/ | 341 | — | Audio management |

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
    stats = {
        kills = number,
        bossesKilled = number,
        highestStage = number,
        highestScore = number,
        totalCoins = number
    },
    unlocks = table  -- passive item unlocks
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

## 9. Love2D Gotchas

| Wrong | Correct |
|-------|---------|
| `ParticleSystem:count()` | `ParticleSystem:getCount()` |
| `ParticleSystem:setLifetime(min,max)` | `ParticleSystem:setParticleLifetime(min,max)` |
| Using `dt` in `love.draw()` | Timers in `love.update()` |
| Font without fallback | `pcall` with fallback for PressStart2P |

## 10. Global Variables Convention

All gameplay state is managed in `core/world.lua` as `World.state` (no globals).
Access via `world.state.X` (in main.lua) or `world.get("X")` from other modules.

### World-managed state keys
- `puntuacion`, `monedas`, `highScore`, `comboCount`, `comboFlashTimer`, `comboDisplay`
- `gameState`, `time`, `timeScale`, `menuPS`, `celebrationTimer`, `nuevoHighScore`
- `transitionTarget`, `transitionPhase`, `transitionHoldTimer`, `fadeDir`, `fadeAlpha`
- `mundoCompletado`, `bossHealthDisplay`, `debugMenuOpen`, `debugImmune`
- `debugAchievementsOpen`, `debugDungeonOverlay`, `debugButtons`, `debugAchievementModalButtons`
- `pendingAchievements`, `scheduledToasts`, `scheduledIndex`, `introTimer`, `shakeTimer`
- `activePS`, `activeTimers`, `shockwaves`, `scoreMultiplier`, `coinBonus`
- `anchoGrilla`, `altoGrilla`, `gridOffsetX/Y`, `gameOffsetY`, `baseSpeed`, `velocidadActual`
- `frutasContador`, `cronometro`, `deathAnimTimer`, `lastObstacleScore`, `lastEatTime`
- `magnetRange`, `player`

### Migration status
- `debugImmune`: entities/snake.lua reads via local `immune()` → `world.get("debugImmune")`
- `monedas`/`highScore`: systems/persistence.lua `syncActiveProfile()` → `world.get(...)`
- `pendingAchievements`/`scheduledToasts`/`scheduledIndex`/`time`: systems/achievements.lua → `world.get(...)`

Colors as `{r,g,b}` or `{r,g,b,a}` tables.

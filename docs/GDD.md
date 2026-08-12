# Game Design Document — Snake Dungeon Crawler

## 1. Overview

| Field | Value |
|-------|-------|
| **Genre** | Snake / Dungeon Crawler |
| **Platform** | Windows (Love2D 11.4+) |
| **Language** | Lua |
| **Objective** | Survive 25 rooms across 5 stages, defeat the boss |

## 2. Core Mechanics

### Movement
- Grid-based snake movement (WASD/Arrow keys)
- Speed adjustable in real-time (+/- keys)
- Snake grows when eating food

### Collision System
Order: Body → Obstacles → Boss → Projectiles → Enemies

Returns 5 values: `vivo, comio, enemyKilled, bossResult, attackHit`

### Scoring
- Points from food and enemy kills
- Combo system for consecutive kills
- High score persistence per profile

## 3. Enemies

| Type | Behavior |
|------|----------|
| **Chaser** | Pursues player directly |
| **Patroller** | Follows predetermined path |
| **Spawner** | Generates additional enemies |
| **Boss** | Multi-attack pattern, food-based defeat |

### Chaser (Red)

El cazador. Persigue directamente la cabeza del jugador. Se dibuja como un rombo rojo (`COLOR_ENEMY_CHASER = {0.9, 0.2, 0.2}`) en `render/enemiesDraw.lua`.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_CHASER_SPEED` | 0.3 | Intervalo de movimiento base (segundos por tile) |
| `ENEMY_DROP_CHASER` | 3 | Monedas al ser derrotado |
| `chaserWeight` | 0.40–0.50 | Peso de spawn por etapa (`stageModifiers` en `world.lua`) |
| `BOSS_MAX_RED` | 3 | Cap de chasers durante el boss |

#### Spawn
- Vía `enemies.generar()`: tile aleatorio validado por `enemyHelpers.validarPos()` (fuera de serpiente, comida, obstáculos y otros enemigos; intentos máximos 100).
- El modificador de etapa `enemySpeed` (1.0 → 1.8) divide el intervalo: más rápido en etapas altas.

#### IA de movimiento (estado actual)
- Cada `moveInterval`, evalúa las 4 direcciones (`enemies.lua` rama `chaser`): descarta celdas fuera de grilla u ocupadas por otros enemigos, y se mueve a la de **menor distancia Manhattan** a la cabeza.
- La evaluación usa orden fijo `{arriba, abajo, izquierda, derecha}` (sesgo hacia arriba en empates).
- Limitaciones conocidas: **ignora obstáculos y el cuerpo de la serpiente** (solo chequea otros enemigos); si las 4 celdas están bloqueadas, no se mueve.

#### Colisión
- Orden: cuerpo → obstáculos → boss → proyectiles → enemigos (ver `snake.mover()`).
- Muerte instantánea de la serpiente sin items activos (shield/armor/ghost).

#### Durante el boss
- Lifetime `BOSS_ENEMY_LIFETIME = 15s`: el chaser se encola en `pendingRespawns` y reaparece 5s después (`BOSS_RESPAWN_DELAY`) en tile libre a ≥6 de la cabeza (`sampleFreeTile`).
- Respeta el cap `BOSS_MAX_RED = 3`.

#### Derrota
- `enemies.killEnemy()` retorna `{px, py, gx, gy, coins = 3, type = "chaser"}` → alimenta combos, puntuación, logros (`enemy_25`, `enemy_100`, `combo_5`, `combo_10`) y stats de perfil (`kills`).

#### Diseño propuesto: comportamiento social (pendiente de implementación)

Mejora de IA en 3 fases por **modo de manada**, clasificado por chasers vivos en la sala:

| pack.count | Modo | Roles |
|---|---|---|
| 1 | **SOLO** | Hunter + predicción |
| 2–3 | **DUPLA** | 1 Hunter + 1–2 Flankers |
| 4+ | **MANADA** | Anillo de cerco + cierre coordinado |

**Estados por enemigo** (enums, no strings):
- `IDLE`: deambula si la cabeza está fuera de `CHASER_AGGRO_RADIUS = 8` (Manhattan).
- `CHASE` (hunter): greedy directo con evasión suave.
- `FLANK`: ataque lateral perpendicular a la dirección de la cabeza.
- `ENCIRCLE`: navegación a un slot del anillo.

**Arquitectura**: la IA pasa a un nuevo módulo `entities/chaserAI.lua` con dos niveles:
- `chaserAI.buildPack(ctx)` — pase "colmena" 1×/tick: clasifica pack, asigna roles estables (refresh 0.5s, guard de edad <1s para no robar rol).
- `chaserAI.update(e, dt, ctx, pack)` — navegación individual (greedy con scoring).

**Navegación mejorada**:
- Evasión suave: obstáculo = bloqueo duro, cuerpo de serpiente = penalización fuerte, otro enemigo = bloqueo duro.
- Tie-break anti-bias: direcciones barajadas cada tick (elimina el sesgo del orden fijo).
- Penalización anti-apilamiento (`CHASER_SPREAD_PENALTY`): celdas a ≤2 tiles de otro chaser puntúan peor.
- Contador de stuck: tras 3 ticks sin movimiento válido, escapa a cualquier celda libre.

**Geometría**:
- Dirección de cabeza `d = body[1] − body[2]`; perpendiculares `p1 = (−dy, dx)`, `p2 = (dy, −dx)`.
- Flanker L/R: target `head + d×1 ± p×2`; mantienen ≥2 tiles del hunter (pueden golpear a la serpiente si se cruza — sin distancia mínima a la cabeza).
- Anillo MANADA: radio `min(3, grilla/6)`, slots priorizados por producto punto `(slot − cabeza)·d` (tapan rutas de escape, flanco trasero flojo por diseño).
- Cierre: ≥60% de slots ocupados o 6s de hold max → todos pasan a hunter con destello de advertencia.
- Transición suave: si la manada cae a dupla, promoción inmediata del más cercano a hunter.

**Balance**:
- Slowdown de manada: `CHASER_PACK_SLOWDOWN = 1.15` (el anillo amenaza pero deja huecos).
- Durante el boss el cap 3 fuerza modo DUPLA (nunca MANADA).

**Escalado por etapa (propuesto)**: `intervalo = (0.3 / speedMult) × 1.10^(etapa−1)`, clamp mínimo 0.15s.

**Contra-juego del jugador**:
- Matar al **hunter** rompe el cerco (roles se re-anclan).
- La espalda de la serpiente es el punto débil del anillo (slots traseros no priorizados).
- En DUPLA, los flankers son menos letales solos: separarlos del hunter diluye la presión.

### Enemy Caps (during boss)
- Red (Chasers): max 3
- Blue (Patrollers): max 4

## 4. Items (12 total)

### Active Items (slots 1-3)
| Item | Effect |
|------|--------|
| Shield | Blocks one hit |
| Armor | Reduces damage |
| Ghost | Phase through enemies |
| Bomb | Destroys nearby enemies |
| Magnet | Attracts food |
| Hunger | Eat enemies for health |

### Passive Items
| Item | Effect |
|------|--------|
| SpeedReducer | Slows game speed |
| Turbo | Temporary speed boost |
| Slow | Slows enemies |
| Doubler | Double points |
| ExtraCoin | Bonus coins |
| Star | Invincibility |

## 5. Boss Mechanics

### Core Concept
- Boss is **invulnerable** to direct attacks
- Only defeated by collecting **15 non-coin foods** during encounter

### Attacks
| Attack | Description |
|--------|-------------|
| Projectile Spread | Radial projectiles |
| Spawn Adds | Summons patrollers |
| Radial Pulse | Shockwave damage |
| Teleport | Random repositioning |

### Boss Health Bar
- World-space display
- Smooth fill via lerp (6.0/s)
- Depletes as food is collected

## 6. Progression

```
5 Stages × 5 Rooms = 25 Rooms Total
```

### Room Types
- Corridor
- Arena
- Choke
- Hub
- Treasure
- Spawner
- Boss

### Flow
```
MENU → PLAYING → TRANSITION → SHOP → PLAYING → ...
PLAYING → DEATH_ANIMATION → HIGH_SCORE/SHOP → MENU
```

## 7. Visual Style

- Pixel art aesthetic (PressStart2P font)
- Procedural particle effects (4x4 texture)
- Post-processing shaders:
  - Bloom (glow → blurH → blurV)
  - CRT effect
  - Shadow blur
  - Heat distortion (menu)

## 8. Audio

- Single .ogg file with 4 segments:
  - Intro (1-9s)
  - Combo Enter (10-17s)
  - Combo Loop (13-17s)
  - Boss (18-24s)
- Seamless crossfade between combo segments
- Procedural SFX: eat, death, buy, shieldBreak, highScore, enemyKill, boss_food_tick, boss_defeated

## 9. Profiles System

- Max 3 profiles
- Per-profile stats: kills, bossesKilled, highestStage, highestScore, totalCoins
- Persistence in `config/profiles.dat`

## 10. Achievements (11 total)

| ID | Condition |
|----|-----------|
| first_kill | Kill first enemy |
| enemy_25 | Kill 25 enemies |
| enemy_100 | Kill 100 enemies |
| combo_5 | 5x combo |
| combo_10 | 10x combo |
| coins_100 | Collect 100 coins |
| coins_500 | Collect 500 coins |
| stage_3 | Reach stage 3 |
| boss_kill | Defeat boss |
| score_1000 | Score 1000 points |
| score_5000 | Score 5000 points |

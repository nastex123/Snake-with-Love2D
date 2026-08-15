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
- Grid-based snake movement (WASD/Arrow keys / Touch swipe)
- Speed adjustable in real-time (+/- keys)
- Snake grows when eating food
- **Input Buffer (2-step queue)**: Permite registrar giros de esquinas rápidas (giros en "L") sin pérdida de respuesta ni sobrescritura prematura.
- **Protección Anti-180°**: Descarta giros opuestos directos o en rápida sucesión para evitar colisiones accidentales contra el propio cuello/cuerpo.
- **Soporte de tecla mantenida**: Muestreo automático de dirección perpendicular válida en cada paso si la cola está vacía.

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

#### Diseño visual elegido: Estrella de espinas (propuesta 6)
- Cuerpo procedural de cuatro puntas con radios alternos, sin spritesheet.
- Ojo central: la pupila rastrea la cabeza de la serpiente en cada frame.
- `IDLE`: alpha atenuada, rotación lenta y párpado cerrado.
- `CHASE`: una punta se orienta hacia el movimiento mediante interpolación angular y el ojo se abre.
- `FLANK`: contorno blanco pulsante y pupila vertical para distinguir el rol flanker.
- `ENCIRCLE`: puntas elongadas con pulso ámbar.
- `CIERRE`: giro rápido, destello blanco y signo de advertencia antes de la embestida.
- La implementación está en `render/enemiesDraw.lua`; los estados y roles los administra `entities/chaserAI.lua`.

#### Comportamiento social (completamente implementado)

La implementación vive en `entities/chaserAI.lua` y cubre los modos SOLO, DUPLA y MANADA,
la navegación con penalizaciones, el escalado progresivo por etapa y el ciclo visual de cierre anticipado al 60%.

Modos de manada por cantidad de chasers vivos en la sala:

| pack.count | Modo | Roles |
|---|---|---|
| 1 | **SOLO** | Hunter con persecución y evasión |
| 2–3 | **DUPLA** | 1 Hunter líder + 1–2 Flankers laterales |
| 4+ | **MANADA** | Anillo de cerco orbital + cierre coordinado |

**Estados por enemigo**:
- `IDLE`: deambula si la cabeza está fuera de `CHASER_AGGRO_RADIUS = 8` (Manhattan).
- `CHASE` (hunter): persecución greedy directa con evasión suave.
- `FLANK`: ataque lateral perpendicular a la dirección de la cabeza (`head + d*1 ± p*2`).
- `ENCIRCLE`: navegación a un slot asignado del anillo orbital.
- `CLOSE`: fase de embestida grupal acelerada (`speedFactor = 0.5`) tras aviso flash.

**Navegación y Geometría**:
- Evasión suave: obstáculo = bloqueo duro, cuerpo de serpiente = penalización fuerte, otro enemigo = bloqueo duro.
- Tie-break barajado anti-sesgo en cada tick.
- Penalización anti-apilamiento (`CHASER_SPREAD_PENALTY`).
- **Cierre anticipado del 60%**: Al estar ≥60% de los slots ocupados (a distancia ≤1 del slot objetivo) o tras 6s de espera máxima, se dispara inmediatamente el cierre con destello de aviso (`flash`) y posterior embestida (`dash`).
- **Escalado por etapa**: `intervalo = max(0.15s, (0.30 / speedMult) * 0.90^(etapa - 1))`.
- **Durante Boss**: Cap `BOSS_MAX_RED = 3` fuerza permanentemente el modo DUPLA (1 Hunter + 2 Flankers); el respawn tras 15s reaparece en flancos laterales alternados (`side = 1 / -1`).

### Patroller (Blue)

El patrullero. Se mueve en línea recta continua y rebota ante paredes, obstáculos, el Boss y otros enemigos. Se dibuja como un triángulo azul (`COLOR_ENEMY_PATROLLER = {0.2, 0.4, 0.9}`) con rotación orientada a su vector de movimiento y pulso de energía.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_PATROLLER_SPEED` | 0.2 | Intervalo de movimiento base (segundos por tile) |
| `ENEMY_DROP_PATROLLER` | 2 | Monedas al ser derrotado |
| `patrollerWeight` | 0.20–0.35 | Peso de spawn por etapa |
| `BOSS_MAX_BLUE` | 4 | Cap de patrollers durante el boss |

#### Comportamiento
- Al spawnear en salas de tipo corredor, detecta el eje de mayor espacio despejado (horizontal vs vertical) para patrullar a lo largo del pasillo.
- Ante colisión frontal con cualquier elemento sólido (pared, obstáculo, cuerpo de serpiente, Boss u otro enemigo), invierte su dirección inmediatamente (`dirX = -dirX; dirY = -dirY`) y da el paso de rebote si la casilla opuesta está libre, evitando atascos o deadlocks cara a cara.

### Spawner (Purple)

El generador estático. Permanece inmóvil en su celda y genera periódicamente nuevos obstáculos adyacentes si hay celdas libres disponibles.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_SPAWNER_INTERVAL` | 8.0 | Intervalo de generación de obstáculos (segundos) |
| `ENEMY_DROP_SPAWNER` | 5 | Monedas al ser destruido |
| `spawnerWeight` | 0.20–0.35 | Peso de spawn por etapa |

#### Comportamiento
- Durante el combate contra el Boss, su intervalo de spawn se multiplica por 1.5x (`spawnerInterval * 1.5`) para balancear la densidad de amenazas.

### Enemy Caps (during boss)
- Red (Chasers): max 3 (fuerza modo DUPLA)
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

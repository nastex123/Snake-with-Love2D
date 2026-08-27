# Game Design Document — Snake Dungeon Crawler

## 1. Overview

| Field | Value |
|-------|-------|
| **Genre** | Snake / Dungeon Crawler |
| **Platform** | Windows (Love2D 11.4+) |
| **Language** | Lua |
| **Objective** | Survive 25 rooms across 5 stages, defeat the boss |
| **Core loops** | Fase 8: survival streak, comidas especiales, biomas con peligros, salas élite, modos endgame, skins |

## 2. Core Mechanics

### Movement Paradigm: Held-Key Tactical Slither (Movimiento Táctico Sostenido)
- **Nuevo Paradigma por Tecla Sostenida**: A diferencia de la serpiente retro tradicional que avanza automáticamente de forma continua, **la serpiente solo avanza mientras el jugador mantenga presionada una tecla de dirección** (`WASD`, Flechas o Stick/D-pad).
- **Detención Inmediata**: Al soltar las teclas direccionales, la serpiente se detiene en su celda actual, manteniendo su orientación y postura de guardia.
- **Entorno en Tiempo Real**: Mientras la serpiente está detenida, el mundo (enemigos, proyectiles, trampas y temporizadores) **sigue corriendo en tiempo real**. Esto transforma el juego en una experiencia de precisión y cálculo táctico donde el jugador puede:
  - Sincronizar el paso sobre *Pinchos de Presión* (esperar a que se retraigan).
  - Esperar el momento exacto para cruzar entre los rayos de la *Jaula Láser* del Boss.
  - Resolver salas de puzle y mystery rooms (*La Prueba de los Tres Sellos*) sin ser forzado a chocar contra paredes.
  - Coordinar la emboscada perfecta para ejecutar el *Constrictor Loop*.
- **Opción de Conmutación en Ajustes**: Los puristas del género pueden alternar en Ajustes entre `Modo Táctico Sostenido (Por defecto)` y `Modo Clásico Automático (Auto-Slither)`.
- **Input Buffer Inteligente (2-step queue con reemplazo dinámico)**: Permite registrar giros de esquinas rápidas (giros en "L") y rectificar intenciones al instante. Si el jugador presiona una nueva tecla ortogonal antes de ejecutarse el paso, se sobrescribe el comando previo en lugar de descartarlo rígidamente.
- **Corner Buffering Acelerado (`CORNER_BUFFER_RATIO = 0.75`)**: Si se registra un giro cuando el paso actual ha superado el 75% del intervalo, el paso se completa de inmediato, eliminando la latencia perceptual en esquinas.
- **Protección Anti-180° Contextual**: Descarta giros opuestos directos hacia el propio cuello basados en el avance real, sin bloquear secuencias ortogonales rápidas ni giros en "U" de dos tiempos (necesarios para el *Tail Snap*).
- **Touch / Mobile**: En dispositivos táctiles, mantener el dedo arrastrado en la dirección deseada mantiene el avance continuo; levantar el dedo detiene a la serpiente.

### Input & Controls

| Entrada | Contexto | Acción |
|---|---|---|
| `WASD` / `↑ ↓ ← →` | Playing | Movimiento de la serpiente (grid) |
| `+` | Playing | Acelera (reduce intervalo: `baseSpeed -= 0.01`) |
| `-` | Playing | Frena (aumenta intervalo: `baseSpeed += 0.01`) |
| `1` / `2` / `3` | Playing | Activa ítem de slot inventario (slots 1-3) |
| `Space` / `Esc` | Playing ↔ Paused | Pausar / reanudar |
| `Tab` | Cualquier estado | Toggle menú debug |
| `L` | Playing | Debug: +10 monedas |
| `K` | Playing | Debug: saltar sala actual |
| `Enter` | Menu | Iniciar partida |
| `A`/`D` o `← →` | Shop | Cambiar página de ítems |
| `Space`/`Enter` | Shop | Comprar ítem |
| `Esc` | Shop / Profiles / Settings | Cerrar panel |
| **Touch swipe** | Playing | Movimiento direccional (`core/touch.lua`) |

### Collision System
Order: Body → Obstacles → Boss → Projectiles → Enemies

Returns 5 values: `vivo, comio, enemyKilled, bossResult, attackHit`

### Scoring & Survival Streak
- Points from food and enemy kills
- Combo system for consecutive kills (ventana `COMBO_WINDOW = 8.0s`, multiplicador `COMBO_MULTIPLIER = 0.5`)
- **Survival Streak**: Multiplicador progresivo (+0.1x por sala consecutiva completada sin morir: x1.0, x1.1, x1.2... x2.0). Aumenta la ganancia de monedas y puntos de expedición.
- Estado: `world.state.survivalStreak` (flotante, inicia 1.0). Se incrementa en `worldMod.avanzarSala()` tras completar la sala; cap `2.0` (config propuesto: `SURVIVAL_STREAK_STEP = 0.1`, `SURVIVAL_STREAK_MAX = 2.0`, `SURVIVAL_STREAK_START = 1.0`).
- **Hook de multiplicador**: producción (`puntuacion` y `monedas`) se multiplica por `survivalStreak` tanto en comida como en kills de enemigos y drops del boss, aplicado en `systems/gamestates.lua`.
- **Riesgo de Muerte**: Al morir, el jugador puede pagar 30$ para *Continuar* en la sala actual con 3s de intangibilidad y mantener su racha, o *Aceptar Muerte* perdiendo el 30% de monedas acumuladas en la expedición y reseteando la racha a x1.0.
- **Flujo del modal de muerte (interactivo)**:
  1. `snake.mover()` retorna `vivo = false` con muerte letal (sin shield/armor/ghost y sin `debugImmune`).
  2. Pausa el despiece actual (`updateDeath`): en vez de degradar segmentos, se abre **modal** sobre la sala congelada (estado `DEATH_ANIMATION` en espera).
  3. Botón **CONTINUAR (30$)** — solo si `monedas >= 30` (config propuesto: `REVIVE_COST = 30`, `REVIVE_INTANGIBLE_TIME = 3.0`).
     - Resta 30$ · resetea posición del body a celda libre central (o spawn) · 3s de intangibilidad (sin colisiones letales) · conserva `survivalStreak` · reinicia el tiempo de sala tal cual.
  4. Botón **ACEPTAR MUERTE** — resta 30% de monedas (`-0.3 * monedas`, config propuesto: `DEATH_COIN_PENALTY = 0.3`), resetea `survivalStreak` a 1.0, y procede al flujo clásico: despiece → `HIGH_SCORE`/`SHOP` → `MENU`.
  5. En ambos botones, registra en `profile.stats.highestStreak` el máximo alcanzado (sync vía `persistence`).
- High score y racha máxima de supervivencia (`highestStreak`) persistentes por perfil.

### Economy & Food Values (valores actuales del código)

**Puntos y monedas por comida** — `systems/gamestates.lua` (bloque `comio`):

| Tipo | Puntos base | Monedas | Nota |
|---|---|---|---|
| Normal | 10 | 1 (`COINS_PER_FRUIT`) | Comida estándar |
| Gold | 25 | 2 | Aparece aleatoriamente |
| Coin | 5 | 3 | Da prioridad a monedas |

**Cálculo de puntos**: `total = floor(puntosBase * comboMult * scoreMultiplier)` donde `comboMult = 1 + comboCount * COMBO_MULTIPLIER (0.5)`. La ventana de combo es `COMBO_WINDOW = 8.0s` entre comidas.

**Drops de enemigos** — `core/config.lua`: chaser 3$, patroller 2$, spawner 1$. Boss: `5 + etapa * 2` (populate.lua).

**Costos de ítems**: ver tabla completa en §4 (10$–40$).

**Costos de progresión (Fase 8)**: Revivir = 30$; penalización por aceptar muerte = 30% de monedas.

### Special Combat Mechanics & Foods

**Comidas Especiales** — aparecen como variantes del dotador de comida (`entities/food.lua`) con `type` dedicado y ventana de duración de efecto temporizado:
  - *Guindilla Picante (Fire Pepper)*: 3.5s de rastro de fuego tras la cola que quema Chasers. Config propuesto: `FIRE_PEPPER_DURATION = 3.5`.
  - *Fruta Helada (Frost Berry)*: 2.5s de congelación de enemigos en toda la sala (enemigos se detienen; efecto aplicado a `enemies.list` y `boss`). Config propuesto: `FROST_BERRY_DURATION = 2.5`.
  - *Baya Constrictora (Constrictor Berry)*: 5s de bucle letal de encierro. Config propuesto: `CONSTRICTOR_DURATION = 5.0`.
  - *Baya de Poda (Slimming Berry)*: Reduce la longitud del cuerpo a la mitad si mide ≥12 segmentos. Config propuesto: `SLIMMING_MIN_LENGTH = 12`, `SLIMMING_FACTOR = 0.5`.
- **Spawn rate**: cada comida especial reemplaza con probabilidad baja una comida normal al generarse en salas no-boss (propuesto: `SPECIAL_FOOD_CHANCE = 0.12` por spawn); no aplican en sala boss (el food-target del boss solo cuenta comidas no-moneda y las especiales sí cuentan como comida no-moneda).

**Frutas Dinámicas Avanzadas**:
- *Comida Imantada Errante (Repelling Orbit)*: Se mueve 1 casilla cada 1.5s alejándose de la cabeza pero es atraída hacia la cola. Otorga +35 pts y +3$.
- *Comida Bomba de Relojería (Countdown Bomb)*: Parpadea con contador de 5s; si se come a tiempo otorga +50 pts y onda destructora en radio 3; si expira, explota y crea un obstáculo permanente.
- *Comida Camaleónica (Prismatic Shifter)*: Cambia cada 1.8s alternando entre Oro (+25 pts / +2$), Escudo (+1 carga) y Monedas (+5$).
- *Comida Gemela (Twin Apples)*: Comer una genera instantáneamente su contraparte en el punto simétrico opuesto; comer ambas en <4s activa Combo x2 instantáneo.
- *Gema de Diamante (Streak Diamond)*: 1.5% de probabilidad (5% en salas de tesoro); incrementa el multiplicador de `survivalStreak` en +0.3x de golpe.

**Mecánicas Tácticas del Cuerpo y Movimiento**:
- *Desprendimiento de Cola (Autotomía - Tecla Q / L2)*: Corta los últimos 4 segmentos del cuerpo (mínimo 7 segmentos). La cola desprendida distrae a los Chasers durante 3.0s antes de desintegrarse.
- *Inversión de Avance (Reverse Slither)*: Durante 3.0s, la cabeza y la cola intercambian roles, avanzando en sentido inverso sin colisión con el cuello.
- *Onda de Expulsión (Tail Snap)*: Al ejecutar un giro en "U" de 180° en dos ticks consecutivos, la punta de la cola emite una micro-onda que empuja a los enemigos adyacentes 1 celda hacia atrás y los aturde 0.8s.

**The Constrictor Loop**:
- Al consumir la *Baya Constrictora*: `constrictTimer = 5.0s` (poder de constricción activo).
- Mientras `constrictTimer > 0`, en cada paso la serpiente **cierra lazo** si su cabeza y cola son adyacentes en la grilla (contacto posterior propio); se evalúa vía *point-in-polygon* (Ray Casting) sobre las celdas del área encerrada.
- Todo enemigo (chasers/patrollers/spawners) cuya celda caiga dentro del polígono es **aplastado instantáneamente**: bonus de monedas (drop normal) y de combo (+1), con shockwave visual (`particles.lua`) y SFX `enemyKill`.
- Caso especial: si el encierro atrapa al boss (solo si este es vulnerable al bucle) se descarta al no poder derrotarlo por lazo (regla: el bucle no aplica sobre `invulnerable = true`).
- Detección solo en salas con wall-wrap clásico (etapas 1-4, ver biomas); en bioma sin wall-wrap (etapa 5) el lazo solo cuenta si el encierro es cerrado por las paredes.

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
| `chaserWeight` | 0.35–0.50 | Peso de spawn por etapa (`stageModifiers` en `world/dungeonGen.lua`, tabla por etapa: 0.40 / 0.50 / 0.35 / 0.50 / 0.40) |
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
| `patrollerWeight` | 0.20–0.35 | Peso de spawn por etapa (0.35 / 0.30 / 0.30 / 0.20 / 0.25) |
| `BOSS_MAX_BLUE` | 4 | Cap de patrollers durante el boss |

#### Comportamiento
- Al spawnear en salas de tipo corredor, detecta el eje de mayor espacio despejado (horizontal vs vertical) para patrullar a lo largo del pasillo.
- Ante colisión frontal con cualquier elemento sólido (pared, obstáculo, cuerpo de serpiente, Boss u otro enemigo), invierte su dirección inmediatamente (`dirX = -dirX; dirY = -dirY`) y da el paso de rebote si la casilla opuesta está libre, evitando atascos o deadlocks cara a cara.

### Spawner (Purple)

El generador estático. Permanece inmóvil en su celda y genera periódicamente nuevos obstáculos adyacentes si hay celdas libres disponibles.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_SPAWNER_INTERVAL` | 3 | Intervalo de generación de obstáculos (segundos) |
| `ENEMY_DROP_SPAWNER` | 1 | Monedas al ser destruido |
| `spawnerWeight` | 0.20–0.35 | Peso de spawn por etapa (0.25 / 0.20 / 0.35 / 0.30 / 0.35) |

#### Comportamiento
- Durante el combate contra el Boss, su intervalo de spawn se multiplica por 1.5x (`spawnerInterval * 1.5`) para balancear la densidad de amenazas.

### Slime Weaver (Green) — El Baboso

Enemigo de control de área y zonificación. Se desplaza lentamente en línea recta o persiguiendo de forma torpe al jugador, depositando un rastro de baba ácida en cada celda que pisa.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_SLIME_SPEED` | 0.45 | Intervalo de movimiento base (segundos por tile, más lento) |
| `ENEMY_DROP_SLIME` | 4 | Monedas al ser derrotado |
| `SLIME_TRAIL_LIFETIME` | 6.0 | Duración de la baba en la baldosa (segundos) |
| `SLIME_SLOW_FACTOR` | 0.75 | Multiplicador de velocidad para la serpiente al pisar baba (reduce 25%) |

#### Comportamiento & Render
- Al desplazarse, deja una mancha de baba translúcida verdosa (`{0.2, 0.8, 0.2, 0.5}`) con partículas de burbujas.
- **No es letal al pisar la baba**: la cabeza de la serpiente solo sufre ralentización temporal de paso (`st.velocidadActual = st.velocidadActual * 1.25`) durante 1.5s.
- El choque directo contra el cuerpo del Slime Weaver sí es letal para la serpiente (sin escudo).
- Se dibuja como una esfera gelatinosa amorfa con oscilación senoidal en sus vértices y núcleo pulsante.

---

### Phase Stalker (Cyan/White) — El Acechador Espectral

Enemigo etéreo capaz de ignorar la geometría sólida del nivel. Flota directamente hacia la cabeza de la serpiente atravesando obstáculos y bloques de piedra sin ser frenado.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_STALKER_SPEED` | 0.40 | Intervalo de movimiento base (segundos por tile) |
| `ENEMY_DROP_STALKER` | 4 | Monedas al ser derrotado |
| `STALKER_AGGRO_RADIUS` | 12 | Radio de detección Manhattan |

#### Comportamiento & Render
- **Inmunidad a colisión con obstáculos**: en su función de evaluación de movimiento, omite la comprobación de `obstaclePos`, pudiendo compartir celda con un muro temporalmente.
- **Vulnerabilidad**: puede ser destruido mediante la *Bomba*, el rastro de *Guindilla Picante* o la *Baya Constrictora*.
- Se dibuja como una calavera o espectro flotante con cola de vapor fantasmal (`COLOR_ENEMY_STALKER = {0.4, 0.9, 1.0, 0.75}`) y shader de parpadeo alfa.

---

### Mortar Sentry (Orange) — La Torreta Centinela

Enemigo estático de asedio que no se mueve de su celda de spawn, pero bombardea periódicamente la posición futura del jugador con proyectiles balísticos telegrafiados.

#### Datos de config (`core/config.lua`)
| Key | Valor | Descripción |
|-----|-------|-------------|
| `ENEMY_SENTRY_COOLDOWN` | 4.5 | Intervalo entre disparos de mortero (segundos) |
| `ENEMY_SENTRY_TELEGRAPH` | 1.5 | Tiempo de aviso telegrafiado en el suelo antes del impacto |
| `ENEMY_SENTRY_RADIUS` | 1 | Radio de explosión en celdas (área 3x3 alrededor del objetivo) |
| `ENEMY_DROP_SENTRY` | 5 | Monedas al ser derrotado |

#### Comportamiento & Render
- Cada 4.5 segundos, calcula la celda donde estará la cabeza de la serpiente (vector `head + dir * 3`).
- Coloca una marca de telegrafiado parpadeante de 3x3 celdas (`telegraphs`) en el suelo con aro decreciente.
- Al expirar el telegrafiado (1.5s), una bomba cae del cielo generando una onda de choque expansiva que destruye obstáculos y mata a la serpiente si se encuentra dentro del radio.
- Se dibuja como un hexágono metálico blindado con torreta giratoria y cañón retráctil.

### Enemy Caps (during boss)
- Red (Chasers): max 3 (fuerza modo DUPLA)
- Blue (Patrollers): max 4
- Green (Slimes): max 2
- Cyan (Stalkers): max 2

## 4. Items (12 total)

Descripciones y costos conforme a `systems/items.lua` + `core/config.lua`. Categorías: `defense`, `food`, `speed`, `score`. La tienda pagina los ítems en grupos de 3 dentro de cada categoría. Slots activos: 1-3.

### Active Items (slots 1-3)

| Item | Effect | Cost | Duration/Range |
|------|--------|------|----------------|
| Shield | Sobrevive a **1 impacto** | 30$ | — |
| Armor | Sobrevive a **2 impactos** | 40$ | — |
| Ghost | Atraviesas **tu propio cuerpo** | 25$ | 5s |
| Bomb | **Destruye obstáculos** (no enemigos) | 25$ | radio 3 |
| Magnet | Atrae comida | 20$ | 10s, radio 2 |
| Hunger | Aparecen **2 comidas extra** en el mapa | 15$ | — |

### Passive Items

| Item | Effect | Cost | Duration/Range |
|------|--------|------|----------------|
| SpeedReducer | Reduce la velocidad de la serpiente **permanentemente** | 15$ | 0.02 |
| Turbo | Aumenta velocidad | 20$ | 8s (x0.7) |
| Slow | Ralentiza el **tiempo** | 25$ | 5s (x0.5) |
| Doubler | Puntos x2 | 35$ | 8s |
| ExtraCoin | +1 moneda por fruta | 20$ | 10s |
| Star | Puntos x3 | 40$ | 5s |

### Extended Items Arsenal (51 al 60)

| # | Ítem | Tipo | Coste | Efecto Mecánico Detallado |
|---|---|:---:|:---:|---|
| **51** | **Púa de Cola** | Activo (Slot) | 20$ | Despliega una trampa fija en la celda de la cola. El primer enemigo que la pise muere al instante. Máx. 3 simultáneas. |
| **52** | **Reloj de Arena** | Activo (Slot) | 35$ | Rebobina la posición de la serpiente y enemigos a donde estaban hace exactamente **2.0 segundos**, conservando los puntos. |
| **53** | **Rayo Orbital** | Activo (Slot) | 30$ | Dispara un haz continuo a lo largo de toda la columna de la cabeza durante 2.5s que vaporiza enemigos y proyectiles. |
| **54** | **Señuelo Holográfico**| Activo (Slot) | 25$ | Despliega un señuelo estático de la cabeza que atrae a todos los Chasers durante 4.0s. |
| **55** | **Botas Ligeras** | Pasivo | 20$ | Reduce en un **50%** la penalización de lentitud provocada por la baba de Slime y el suelo viscoso. |
| **56** | **Diente de Oro** | Pasivo | 25$ | Por cada 10 segmentos de longitud corporal que tenga la serpiente, cada fruta comida otorga **+1 moneda adicional**. |
| **57** | **Batería de Emergencia**| Pasivo | 30$ | Al recibir un impacto mortal sin escudo activo, ralentiza el tiempo al **10% (*Bullet Time*)** durante 1.5s dándote margen de reacción. |
| **58** | **Cosecha Doble** | Pasivo | 30$ | **15% de probabilidad** de que comer cualquier fruta sume sus puntos y monedas pero **NO aumente la longitud del cuerpo**. |
| **59** | **Billete de Lotería** | Consumible | 5$ | Cuesta 5$ en la tienda. Al rascarlo en el inventario otorga una recompensa aleatoria entre **0$ y 35$ monedas**. |
| **60** | **Prisma Refractor** | Pasivo | 25$ | Si un proyectil impacta contra la serpiente con Escudo o Armadura activos, se refracta en **3 monedas de oro**. |

### Item Synergies Matrix (Sinergias de Ítems)

Cuando el jugador equipa o posee combinaciones específicas de ítems activos y pasivos, se desbloquean efectos combinados automáticos (*Synergies*):

| Sinergia | Componentes Requeridos | Efecto Mecánico | Feedback Visual & SFX |
|---|---|---|---|
| **Escudo Reactivo** | `shield` + `bomb` | Al romperse el escudo por un impacto enemigo, se detona una bomba de radio 3 instantánea sin consumir la bomba del inventario. | Shockwave roja + partículas de metralla + SFX `enemyKill`. |
| **Vórtice Dorado** | `magnet` + `doubler` | Toda comida atraída por el campo magnético otorga automáticamente el doble de monedas y combo. | Líneas de atracción doradas brillantes hacia la cabeza. |
| **Cometa Espectral** | `ghost` + `turbo` | Mientras ambos efectos están activos, atravesar enemigos o el propio cuerpo no solo es seguro sino que destruye a los enemigos tocados. | Estela de fuego blanco-azulada y glow intenso en el cuerpo. |
| **Hambre Voraz** | `hunger` + `speedReducer` | Cada comida extra generada por Hambre reduce permanentemente el retraso de giro de la serpiente un 5%. | Destello verde esmeralda al comer. |
| **Supernova** | `bomb` + `star` | La bomba detona con el doble de radio (radio 6) y convierte todos los obstáculos destruidos en monedas. | Destello de pantalla completa y lluvia de monedas. |
| **Armadura de Espejo** | `armor` + `star` | Mientras la armadura tenga cargas, los proyectiles del Boss o de enemigos que toquen el cuerpo rebotan y se destruyen. | Sonido metálico de deflexión y chispas doradas. |
| **Pozo Gravitatorio** | `magnet` + `slow` | El imán no solo atrae comida, sino que frena a los Chasers cercanos en radio 4 un 50%. | Anillo de gravedad púrpura pulsante. |
| **Sobrecarga Temporal** | `turbo` + `slow` | La serpiente se mueve al doble de velocidad mientras los enemigos y proyectiles se mueven a mitad de velocidad (efecto *Bullet Time*). | Tinte de pantalla monocromático con aberración cromática. |

### Altares de Sangre y Ofrendas (Blood Altars)

En salas especiales de tipo `treasure` o `hub`, puede aparecer un **Altar de Sacrificio** interactivo en una de las esquinas de la sala:

| Altar | Coste / Sacrificio Requerido | Recompensa Otorgada |
|---|---|---|
| **Altar de Carne** | Sacrificar **5 segmentos del cuerpo** | Otorga 1 carga de *Escudo* o revive un escudo roto. |
| **Altar de la Avaricia** | Sacrificar **el 50% de las monedas actuales** | Duplica el multiplicador de `survivalStreak` (+0.5x instantáneo). |
| **Altar del Vacío** | Perder **3 segundos de tiempo de sala / Racha a x1.0** | Entrega un ítem activo legendario aleatorio de la tienda sin costo. |
| **Altar de la Calma** | Sacrificar **20 monedas** | Reduce la velocidad base del juego (`baseSpeed += 0.03`) permanentemente en la run. |

## 5. Boss & Mini-Boss Mechanics

### Core Concept
- Boss is **invulnerable** to direct attacks
- Only defeated by collecting **15 non-coin foods** during encounter

### Attacks
Los 4 ataques viven en `entities/bossAttacks.lua` con `telegraphTime` (markers visibles antes de ejecutarse):

| Attack (id) | telegraphTime | Description |
|---|---|---|
| Projectile Spread (`projectile_spread`) | 0.8s | Proyectiles radiales |
| Spawn Adds (`spawn_adds`) | 0.6s | Invoca Patrollers (respeta caps) |
| Radial Pulse (`radial_pulse`) | 1.0s | Onda expansiva de daño |
| Teleport (`teleport`) | 0.3s | Reposicionamiento aleatorio lejos de la cabeza |
| Jaula Láser (`laser_perimeter`) | 1.0s | 4 rayos continuos que encierran el centro de la sala durante 4s |

### Fase de Furia del Boss (Enrage Phase)
- Se activa automáticamente al restar **3 comidas** para la victoria (a las 12/15 comidas).
- El Boss emite un pulso carmesí, la música acelera su tempo y el intervalo de telegrafiado y ataque se reduce un **35%**.

### Boss Health Bar
- World-space display sobre el boss
- Smooth fill via lerp: `_uiBarFill = lerp(_uiBarTarget, _uiBarFill, 6.0 * dt)` (`BOSS_HEALTH_BAR.lerpSpeed`)
- Depletes as food is collected (`foodCollected / foodTarget`, quita a COIN)
- Metadatos: `BOSS_HEALTH_BAR` en `core/config.lua` (width 96, height 8, yOffset -24)

### Fase 8: Boss & el survival streak
- El multiplicador `survivalStreak` aplica al drop final del boss (`bossResult.coins`).
- Las 4 comidas especiales cuentan para el food-target (todas no-moneda), coherente con la regla vigente.

---

### Mini-Bosses por Etapa (Encuentros Élite en Sala 3)

En la Sala 3 de cada etapa, el encuentro es custodiado por un **Mini-Jefe Temático** con barra de vida propia, tamaño aumentado (2x2 casillas en grid) y ataques únicos. A diferencia del Boss final, los Mini-Jefes son **vulnerables al daño directo** (mueren por ítems como Bomba, colisiones con Escudo/Armadura, rastro de fuego de Guindilla, o al cumplir el objetivo de puntos de la sala recolectando comida que los debilita).

#### 1. Mini-Jefe Etapa 1: El Triturador de Muros (Wall-Crusher)
* **Apariencia**: Un enorme bloque de piedra acorazado con púas de hierro (`COLOR = {0.6, 0.6, 0.7}`).
* **Vida / Resistencia**: 3 golpes de impacto / 6 comidas en la sala.
* **Ataque Principal — *Embestida Sísmica***: Telegrafía una línea roja en cruz de 1 casilla de ancho durante 1.2s y embiste a toda velocidad hasta el borde de la sala, destruyendo cualquier obstáculo en su camino y aturdiendo a la serpiente si está cerca.
* **Recompensa al morir**: 15 monedas + cofre dorado con ítem activo garantizado + `survivalStreak +0.2`.

#### 2. Mini-Jefe Etapa 2: El Gólem de Escarcha (Frost Golem)
* **Apariencia**: Gólem de cristal azul cian brillante con halo de escarcha (`COLOR = {0.2, 0.8, 1.0}`).
* **Vida / Resistencia**: 4 golpes de impacto / 7 comidas en la sala.
* **Ataque Principal — *Aliento Gélido***: Dispara un cono de 3 proyectiles de hielo que congelan las baldosas impactadas durante 5 segundos, convirtiéndolas en suelo ultra-resbaladizo.
* **Ataque Secundario — *Nova de Hielo***: Al recibir daño, expulsa esquirlas en 4 direcciones diagonales.
* **Recompensa al morir**: 20 monedas + Baya Helada garantizada + cofre de ítems.

#### 3. Mini-Jefe Etapa 3: La Sierpe de Magma (Magma Wyrm)
* **Apariencia**: Una serpiente enemiga independiente de 6 segmentos incandescentes (`COLOR = {1.0, 0.3, 0.0}`).
* **Vida / Resistencia**: Cada segmento se destruye individualmente al pasar sobre él con escudo o fuego (6 HP total) / 8 comidas.
* **Ataque Principal — *Rastro de Ceniza***: Se mueve en bucle por el perímetro de la sala dejando una estela de lava ardiente que dura 4 segundos.
* **Recompensa al morir**: 25 monedas + Guindilla Picante garantizada + cofre dorado.

#### 4. Mini-Jefe Etapa 4: La Reina Larva (Brood Queen)
* **Apariencia**: Nido arácnido gigante púrpura y verde que pulsa rítmicamente (`COLOR = {0.7, 0.1, 0.8}`).
* **Vida / Resistencia**: 5 golpes de impacto / 9 comidas en la sala.
* **Ataque Principal — *Enjambre Efervescente***: Invoca 3 larvas suicidas que corren hacia la serpiente y explotan en una nube de baba ralentizante tras 2 segundos.
* **Ataque Secundario — *Red Pegajosa***: Dispara una telaraña que cubre un área de 3x3 celdas, bloqueando los giros rápidos.
* **Recompensa al morir**: 30 monedas + Baya Constrictora garantizada + cofre dorado.

#### 5. Mini-Jefe Etapa 5: El Espectro del Vacío (Void Phantom)
* **Apariencia**: Figura estelar con halo de distorsión gravitatoria y ojos dorados (`COLOR = {0.1, 0.0, 0.3}`).
* **Vida / Resistencia**: 6 golpes de impacto / 10 comidas en la sala.
* **Ataque Principal — *Colapso Dimensional***: Abre una singularidad en el centro de la sala que atrae gravitatoriamente a la serpiente y los enemigos hacia el centro durante 3 segundos.
* **Ataque Secundario — *Desfase Cuántico***: Se teletransporta instantáneamente detrás de la cola de la serpiente, obligando a reaccionar con giros rápidos.
* **Recompensa al morir**: 40 monedas + cofre legendario + `survivalStreak +0.3`.

## 6. Progression

```
5 Stages × 5 Rooms = 25 Rooms Total
```

### Room Types

| Tipo | Comportamiento | Ocurrencia |
|------|----------------|------------|
| **Corridor** | Pasillo con enemigos patrullando a lo largo del eje despejado | Aleatoria |
| **Arena** | Sala abierta con chasers múltiples | Aleatoria |
| **Choke** | Paso estrecho con obstáculos | Aleatoria |
| **Hub** | Sala central con comida abundante | Aleatoria |
| **Treasure** | Sala de cofre/recompensa | Aleatoria |
| **Spawner** | Contiene uno o más Spawners (púrpura) | Aleatoria |
| **Elite** | Encuentro reforzado (sala 3 de cada etapa) | Fija: sala 3 |
| **Boss** | Encuentro con boss (derrota por comida, 15) | Fija: sala 5 |

**Encuentros de Élite (sala 3 de cada etapa)**:
- La sala 3 se marca con `isElite = true` en `world/dungeonGen.lua` (template override).
- Un enemigo élite con multiplicadores (`ELITE_HP_MULT = 2.0`, `ELITE_SPEED_MULT = 1.3`, `ELITE_DROP_MULT = 3.0` — propuestos):
  - HP x2, velocidad x1.3, monedas al morir x3 (ej. chaser élite = 9$).
  - Visual: halo/brillo especial en `render/enemiesDraw.lua` + aro dorado.
- **Cofre dorado garantizado** al vencer la sala: drop de monedas adicional (`goldenChest`) equivalente al doble del drop élite + bonus `survivalStreak +0.2` (además del +0.1 por sala).
- Spawn: el tipo élite es el de mayor `*Weight` de la etapa (chasers en etapas 1/2/4, spawners en 3/5).

### Stage Biomes & Environmental Hazards
| Stage | Biome Name | Visual Theme | Environmental Hazard / Mechanic |
|---|---|---|---|
| **1** | **Catacumbas de Piedra** | Piedra gris & musgo | Entorno clásico de aprendizaje, muros sólidos y pasillos estándar. |
| **2** | **Cripta Helada** | Hielo azul cian & escarcha | **Piso resbaladizo**: la serpiente se desliza 1 celda extra al girar sobre losetas heladas. |
| **3** | **Caverna Volcánica** | Magma naranja & brasas | **Grietas de lava temporizadas**: baldosas térmicas que se calientan y arden cíclicamente. |
| **4** | **Colmena Tóxica** | Baba verde & púrpura | **Suelo viscoso**: reduce la velocidad de paso un 20% y spawners de larvas rápidas. |
| **5** | **Santuario del Vacío** | Vacío cósmico & dorado | **Sin Wall-Wrap**: bordes de abismo letal (caer al borde es muerte instantánea). |

**Notas de implementación por bioma**:
- **Catacumbas (1)**: sin mecánica especial; es el bioma de aprendizaje.
- **Cripta Helada (2)**: loseta con `isIce=true` (campo `room.biome` en `stageModifiers`, inyectado por `dungeonGen.lua`); momento inercial aplicado en `entities/snake.lua` al girar (deslizamiento de +1 celda).
- **Caverna Volcánica (3)**: `hazardGrid` con timers térmicos evaluados en `systems/gamestates.lua` (ciclo caliente/arden); la loseta caliente daña si se pisa en fase ardiente.
- **Colmena Tóxica (4)**: `isSlime=true` → -20% velocidad de paso en losetas viscosas; además spawns de larvas rápidas (patrollers mini).
- **Santuario del Vacío (5)**: `wallWrap=false` → salir del borde es muerte instantánea; **balance**: se reducen caps de enemigos en este bioma (chasers 2 / patrollers 3, propuesta) para compensar el menor espacio usable.

**Ajuste de dificultad global por bioma**: los `stageModifiers` (spawnRate, enemySpeed, weights) ya escalan por etapa (ver `world/dungeonGen.lua`); los biomas aportan la mecánica extra, no el balance base.

### Flow
```
MENU → PLAYING → TRANSITION → SHOP → PLAYING → ...
PLAYING → DEATH_ANIMATION → HIGH_SCORE/SHOP → MENU
```

## 7. Visual Style & Main Menu Layout

- **Estética Retro-Arcade de Alto Contraste**: Tipografía pixel art (`PressStart2P`), paleta de acentos cian, oro y magenta, y renderizado nítido sin blur.
- **Rediseño Asimétrico del Menú Principal**:
  - *Panel Lateral Izquierdo ($40\%$ de ancho)*: Franja continua de $0$ a $100\%$ de altura ocupando el $40\%$ del ancho de pantalla (`panelW = math.floor(w * 0.40)` en `ui/menuUI.lua`). Base sólida `#030610` (`COLOR_BG_BOX`), cubierta por el **Fondo Procedural #14 (Matriz de Puntos HUD)** con micro-LEDs cian cada $18\,\text{px}$ y ondas senoidales radiales expansivas, y el **Círculo de Invocación Alquímico (#17 Render 1)** en pixel art novato (`assets/alchemy_circle.png`), centrado en $(panelW/2, h/2)$ y rotando continuamente a $t \times 0.20\,\text{rad/s}$ con pulso de respiración y pase de resplandor bloom en `menu.drawGlow()` (`assets/alchemy_circle_glow.png`). Borde divisorio vertical de plasma con terminales doradas.
  - *Botones Arcade Centrados (Cyber-Step #03)*: 4 botones interactivos (`JUGAR`, `PERFILES`, `CONFIGURACIÓN`, `SALIR`) de $260\times40\,\text{px}$, centrados horizontalmente en el panel y verticalmente en la pantalla con separación de $14\,\text{px}$, textura de zarpazos a 45°, micro-nodos de relojería, animación de entrada escalonada, sonido de hover y destello cian (`ui/menuUI.lua`).
  - *Diamante Emblema Central*: Núcleo divisorio en el centro exacto de la pantalla $(c_x = w/2, c_y = h/2)$ con pulso senoidal y alas neón (intro en `ui/introUI.lua`, render en `render/renderMain.lua:46`).
  - *Título "S N A K E" — Logotipo Procedural Isométrico 2.5D Cian Neón (#00F0FF, render canónico)*: Motor 100% procedural en `ui/menuLogo.lua` que es el render canónico (Opción A: docs → código). 5 letras en matrices $7\times7$ (`'X'` = píxel de $pScale\times pScale$), $pScale$ configurable, $spacing$ entre letras y $depth$ de extrusión. Pipeline:
    1. **Extrusión isométrica $45^\circ$ hacia $(-d,+d)$** con $depth$ capas (default 5, rango 1–10): base sombra negra en $d=depth$ (`{0,0,0,0.95}`) y cantos cian profundo `{0,0.28,0.38}` / intermedio `{0,0.55,0.70}`.
    2. **Fachada frontal en 4 tonos cian neón** con bisel superior platino `#a6f5ff` (`{0.70,0.96,1.0}` en fila/col 1), cian neón `{0,0.94,1.0}` en $r\le3$, cian medio `{0,0.72,0.85}` en $r\le5$, cian profundo `{0,0.45,0.58}` en el resto; **sweep especular continuo** $sweepX = (t\cdot160) \% (totalW+100)-50$ que pinta píxeles a $<12\,$px en blanco puro.
    3. **Destello en cruz blanca (#16)** de $17\times3$ + $3\times17$ con núcleo $3\times3$ blanco y halo cian $9\times9$, centrado en $glintX = startX+sweepX$, $glintY = startY+12$, visible solo si $glintX\in[startX,startX+totalW]$.
    4. **Flotación senoidal** $float = \sin(t\cdot1.5)\cdot3$ px.
    5. **Posición y escala parametrizadas vía `menuLogo.getBounds(t)`**: lee `persistence.getLogoConfig()` con `logo = {offsetX, offsetY, scale, spacing, depth}` (defaults $0,0,6,10,5$) persistido en `config/settings.dat` (Lua table). Cálculo canónico: $panelW=w\cdot0.40$, $rightCenterX=panelW+\lfloor(w-panelW)/2\rfloor$, $totalW=5\cdot(7\cdot pScale)+4\cdot spacing$, $totalH=7\cdot pScale$, $startX=rightCenterX-\lfloor totalW/2\rfloor+offsetX$, $startY=\lfloor h\cdot0.36-totalH/2\rfloor+float+offsetY$. Rangos: $scale$ 2–12 (teclas `[`/`]`), $depth$ 1–10 (`-`/`+`).
    6. **Glow selectivo solo del glint** en `menuLogo.drawGlow()` vía `shaders.beginGlow()` con $glowPulse=0.8+\sin(t\cdot3.5)\cdot0.2$ (rects $21\times5$ + $5\times21$ cian + $5\times5$ blanco).
    7. **Fallback histórico no canónico**: `assets/title_style12.png` / `assets/title_style12_glow.png` cargados con `pcall` solo como respaldo heredado; no son el render canónico tras la Opción A.
  - *Tarjeta Combinada Perfil & HIGH SCORE (#11 Chunky $344\times76$ + Medalla + Moneda 3D)*: Chasis chunky 2px cian con delineado negro 1px y 4 condensadores $6\times6$ px en esquinas (`ui/menuCard.lua`). **Posición real** `cardX = rightCenterX - \lfloor cardW/2\rfloor + 200`, $cardY = h - cardH - 18$, con fondo izquierdo `#050c17` y derecho a $60^\circ$ `#0c1b2c`, divisor plasma cian en `splitStartX = cardX+\lfloor cardW*0.52\rfloor$ con desplazamiento $0.45\cdot py$. Incluye: nombre perfil, 5 celdas de progreso con micro-calavera $7\times5$ en celda 5, moneda circular 3D elipsoidal procedural con $\text{coinRx}=R\cdot|\cos(t\cdot4.5)|$, $R=5.0$, espesor dinámico $thickness=\max(1,\lfloor2(1-|\cos|)+0.5\rfloor)$ y sello paramétrico de 10 ptos, y medalla oficial cinta V bicolor (azul/rojo $12\times6$) + disco oro $8\times8$ con glint $2\times2$ blanco. Hover sobre tarjeta (`card_profile` en `ui.menuButtons`) abre `profilesMod.open()`.
  - *Herramienta de Calibración F2 (debugLogoOpen)*: Toggle `World.state.debugLogoOpen` (`systems/debugLogo.lua`, post-composite en `render/renderMain.lua`). Activa bbox pulsante $bw=totalW+depth+8$, $bh=totalH+depth+8$ en `(startX-depth-4, startY-4)` con pulso $0.7+\sin(t\cdot6)\cdot0.3$, retícula central y badge $X/Y$ con offsets. **HUD táctico $286\times180$** en $(w-296,10)$ con 11 botones y atajos completos (flechas, Shift, `[`/`]`, `-`/`+`, `R`, `Enter`/`F2` para guardar en `config/settings.dat`). Todos los ajustes persisten inmediatamente. Dibujado **post-composite** para evitar bloom/shadow.
- **Efectos Procedurales y Partículas**: Textura $4 \times 4$ procedural para fuego, humo y chispas.
- **Pipeline de Shaders de Post-Procesado**:
  - Bloom selectivo (glow pass $\to$ blurH $\to$ blurV $\to$ mezcla aditiva) — en menú solo recibe el **glint del logo procedural** y el diamante central (no gemas gemelas del asset histórico).
  - Efecto CRT con scanlines y curvatura.
  - Sombra proyectada difusa.
  - Distorsión de calor (*Heat Haze*) en el fondo fluido Balatro.

## 8. Audio

- Single .ogg file with 4 segments:
  - Intro (1-9s)
  - Combo Enter (10-17s)
  - Combo Loop (13-17s)
  - Boss (18-24s)
- Seamless crossfade between combo segments
- Procedural SFX (10, loaded in `sound.load()`): eat, death, buy, shieldBreak, highScore, enemyKill, boss_food_tick, boss_defeated, buttonHover, buttonClick

## 9. Profiles System

- Max 3 profiles
- Per-profile stats: kills, bossesKilled, highestStage, highestScore, totalCoins, highestStreak (Fase 8)
- Skin seleccionada persistida por perfil (`profile.skin`, Fase 8)
- Persistence in `config/profiles.dat`

## 10. Achievements (11 total)

| ID | Condition |
|----|-----------|
| first_kill | Kill first enemy |
| enemy_25 | Kill 25 enemies |
| enemy_100 | Kill 100 enemies (desbloquea skin Neón) |
| combo_5 | 5x combo |
| combo_10 | 10x combo |
| coins_100 | Collect 100 coins |
| coins_500 | Collect 500 coins |
| stage_3 | Reach stage 3 (desbloquea Modo Pacifista) |
| boss_kill | Defeat boss (desbloquea skin Fuego) |
| score_1000 | Score 1000 points |
| score_5000 | Score 5000 points (desbloquea skin Midas) |

## 11. Unlockable Game Modes

Modos de juego adicionales desbloqueables. Estado en `world.state.modo` (string), persistido por perfil:

| Modo | Desbloqueo | Reglas Especiales |
|---|---|---|
| **Aventura Estándar** | Por defecto | 5 etapas x 5 salas con progresión clásica, tienda y Boss. |
| **Abismo Sin Fin (Endless Abyss)** | Vencer Etapa 5 | Salas infinitas más allá de la 5-5 con dificultad, velocidad y densidad escalando sin límite. |
| **A Contrarreloj (Time Attack / Rush)** | Récord 3000 pts | 3 minutos continuos para maximizar puntos con multiplicadores triples y comida frenética. |
| **Pacifista (Ghost Runner)** | Logro `stage_3` | Sin ítems ofensivos ni muerte a enemigos; la supervivencia depende exclusivamente de la evasión y el cuerpo. |
| **Boss Rush (Guantelete de Jefes)** | Vencer Etapa 5 | Combate consecutivo contra los 5 Mini-Jefes y el Boss final sin salas intermedias. |
| **Serpiente Gigante (Colossal Arena)** | Logro `score_5000` | Cuadrícula de 40x40 casillas con 4 comidas simultáneas y hordas masivas de enemigos. |
| **Micro-Serpiente (Speed Reflex)** | Logro `combo_10` | Longitud fija máxima de 3 segmentos; velocidad base doble (`0.08s`) centrada en reflejos puros. |
| **Desafío Semanal Temático** | Modo Online/Local | Semilla fija con 3 mutadores únicos que rota cada lunes. |
| **Modo Draft de Salida** | Comprar en Santuario | Elección inicial de 1 de 3 paquetes de Skin + Ítem Activo + Ítem Pasivo. |
| **Muerte Súbita (Sudden Death)** | Superar racha 15 | Sin escudos ni armaduras (un toque = muerte), pero todas las monedas y puntos valen el triple (x3). |
| **Laberinto Procedural (Maze Runner)** | Logro `stage_3` | Salas generadas mediante laberintos perfectos sin áreas abiertas. |
| **Carrera contra el Fantasma** | Por defecto | Silueta translúcida de tu mejor récord compitiendo en paralelo en tiempo real. |

**Detalle por modo (hooks de implementación)**:
- **Endless**: `worldMod.avanzarSala()` no se detiene en la sala 5 de la etapa 5; `stageModifiers` escalan por índice de sala (`etapa = 1 + floor(sala/10)`). Objetivo de sala sigue creciendo (`targetMult` acumulado).
- **Rush**: `world.state.timeLimit = 180s` (config propuesto `RUSH_TIME_LIMIT = 180`); `scoreMultiplier` fijo x3 durante el modo; spawn de comida acelerado (`SPECIAL_FOOD_CHANCE` más alto o intervalo de comida menor). Al agotar el tiempo → fin de run → `HIGH_SCORE`/`SHOP` → `MENU`.
- **Pacifista**: `world.state.pacifist = true`; `systems/player.lua` desactiva la BOMBA y el ítem Hunger queda neutro (no suma kills); `gamestates.lua` ignora `enemyKilled` (sin monedas/combo por matar); los enemigos persisten (no se eliminan al tocarlos). Ganar sala solo por objetivo de puntos de comida.

## 12. Snake Customization & Master Skin Catalog

El sistema de personalización visual de la serpiente cuenta con un catálogo exhaustivo de arquetipos procedimentales, variantes y skins desbloqueables mediante logros, récords del perfil y compras en el Santuario.

### 12.1 Motores Geométricos Base (Primitive Render Archetypes)

1. **La Serpiente Shard (Fragmentos Poligonales)**:
   - *Estética*: Compuesta por triángulos y polígonos irregulares apuntando hacia adelante en lugar de cuadrados estándar.
   - *Lectura Visual*: Los polígonos actúan como puntas de flecha orientadas. El borde cambia de color según el estado (Púrpura = Ghost, Amarillo = Shield, contorno interno extra = Armor). Al comer, un fragmento brillante viaja rápidamente de cabeza a cola.
2. **Matriz de Puntos (Dot Matrix)**:
   - *Estética*: Cada celda de 20x20 no es un bloque sólido sino una grilla de 3x3 o 4x4 círculos pequeños (`love.graphics.circle`).
   - *Lectura Visual*: La cabeza tiene mayor densidad de puntos; la cola pierde puntos progresivamente (dithering). A mayor velocidad los puntos se estiran formando elipses. Al comer, todos los puntos parpadean en blanco y aumentan de radio.
3. **El Pulso Wireframe (Líneas Vectoriales)**:
   - *Estética*: Solo se dibujan los contornos (`mode = "line"`), sin relleno, evocando estética retro-vectorial tipo arcade de los 80.
   - *Lectura Visual*: Grosor de línea decreciente hacia la cola. Ghost vuelve las líneas punteadas; Armor duplica el contorno. Al comer, una onda engrosa el trazo temporalmente.
4. **Cadena Hexagonal (Hexagon Mesh)**:
   - *Estética*: Segmentos hexagonales regulares calculados con `love.graphics.polygon` que encajan entre sí sin necesidad de conectores.
   - *Lectura Visual*: La cabeza cuenta con dos hexágonos superpuestos. Al comer, una onda de escala recorre los hexágonos en cascada.
5. **Código de Barras Dinámico (Dithered Barcode)**:
   - *Estética*: Segmentos compuestos por líneas verticales y horizontales de grosores variables dentro de cada celda que vibran según la velocidad de movimiento.

---

### 12.2 Catálogo Maestro de Variantes y Skins (01 a 100)

| # | Concepto | Cabeza / Dirección | Cuerpo / Gradiente | Velocidad | Items / Estados | Animación al Comer |
|---|---|---|---|---|---|---|
| **01** | **Neón Arcano** | Cabeza angular con ojos brillantes y punta frontal | Cuerpo oscuro → núcleo luminoso hacia cabeza | Trail de partículas lineales | Ghost: violeta, Shield: cian, Armor: dorado, Speed: rojo | Pulso luminoso recorre cabeza→cola |
| **02** | **Serpiente Espectral** | Cabeza calavérica con ojos flotantes | Segmentos semitransparentes superpuestos | Trail fantasma duplicando segmentos | Ghost altera opacidad; Shield crea halo; Armor solidifica silueta | Onda blanca atraviesa cada segmento |
| **03** | **Dragón Pixelado** | Cabeza con pequeños cuernos y hocico | Escamas representadas por patrones de 2–3 px | Cola desprende pequeñas escamas | Items aparecen como adornos sobre la cabeza | Pulso de fuego naranja por el cuerpo |
| **04** | **Cobra de Mazmorra** | Capucha triangular expandida | Gradiente verde oscuro → verde lima | Trail como humo verde tóxico | Ghost: capucha translúcida; Shield: disco; Armor: placas | La capucha se expande y una onda recorre el cuerpo |
| **05** | **Serpiente de Cristal** | Cabeza facetada, ojos tipo gema | Segmentos cristalinos con dos tonos por tile | Fragmentos luminosos quedan atrás | Ghost: cristal violeta; Shield: cristal azul; Armor: cristal dorado | Reflejo blanco viaja segmento por segmento |
| **06** | **Runas Vivientes** | Frente marcada con runa direccional | Cada segmento contiene una pequeña runa mística | Runas se desprenden a alta velocidad | Cada item modifica la runa de la cabeza | Runa de la cabeza explota y se propaga en cadena |
| **07** | **Veneno Ácido** | Ojos amarillos y mandíbula marcada | Verde ácido → verde oscuro hacia la cola | Gotas ácidas se desprenden del trail | Ghost: verde pálido; Shield: azul; Armor: gris; Speed: naranja | Mancha circular de ácido + onda amarilla |
| **08** | **Caballero Serpiente** | Cabeza con yelmo pixelado | Segmentos como piezas de armadura medieval | Trail de chispas metálicas | Armor se vuelve visible como placas de acero | Destello dorado viaja por las placas |
| **09** | **Serpiente Void** | Cabeza negra con ojos blancos contrastados | Negro → púrpura → azul oscuro | Deja copias oscuras de la serpiente | Ghost: casi invisible; Shield: esfera; Armor: contorno blanco | Pulso blanco distorsiona el cuerpo |
| **10** | **Electric Viper** | Dos ojos eléctricos + punta frontal | Azul eléctrico → azul oscuro | Rayos cortos saltan entre segmentos | Shield: campo eléctrico; Speed: rayos prolongados | Descarga eléctrica recorre toda la serpiente |
| **11** | **Pixel Fire** | Cabeza con ojos naranja/blanco | Rojo → naranja → amarillo hacia cabeza | Llamas pixeladas detrás | Speed intensifica fuego; Armor: lava endurecida | Explosión de fuego en cabeza + onda roja |
| **12** | **Sombra de Mazmorra** | Silueta de cabeza muy marcada | Negro → gris → color de acento | Trail como sombra proyectada | Ghost funde la serpiente con el fondo | Onda blanca revela momentáneamente la silueta |
| **13** | **Runic Dragon** | Cuernos + runa frontal | Escamas oscuras con líneas luminosas | Trail de símbolos rúnicos | Cada estado usa una runa diferente | Runas se encienden secuencialmente |
| **14** | **Slime Snake** | Cabeza redonda con ojos grandes | Segmentos gelatinosos con highlights | Gotas de slime viscoso detrás | Ghost: gel translúcido; Shield: burbuja; Armor: slime endurecido | Onda elástica recorre el cuerpo |
| **15** | **Holographic Snake** | Cabeza geométrica y ojos tipo visor | Franjas horizontales de color holográfico | Trail de líneas horizontales | Ghost: glitch violeta; Shield: interferencia azul | Glitch blanco atraviesa el cuerpo |
| **16** | **Plague Serpent** | Cráneo/colmillos estilizados | Verde enfermizo → negro | Trail de partículas tóxicas | Ghost: humo; Shield: burbuja; Armor: huesos | Pulso venenoso verde atraviesa los segmentos |
| **17** | **Lava Dungeon** | Cabeza rocosa con ojos incandescentes | Gris roca → naranja → amarillo | Brasas pixeladas incandescentes | Armor: roca; Shield: barrera térmica; Speed: fuego | Grietas luminosas recorren todo el cuerpo |
| **18** | **Moon Serpent** | Cabeza con ojos blancos tipo luna | Azul oscuro → azul claro → blanco | Partículas estelares brillantes | Ghost: fase espectral; Shield: luna; Armor: eclipse | Onda lunar blanca recorre cabeza→cola |
| **19** | **Retro Arcade** | Cabeza cuadrada muy reconocible | Cada segmento tiene highlight de 1–2 px | Trail compuesto por bloques | Cada item cambia un icono/color del borde | Flash blanco + expansión de 1 tile |
| **20** | **Dungeon Relic** | Cabeza de piedra tallada | Piedra oscura → piedra iluminada | Polvo pixelado detrás | Shield: runas azules; Armor: placas; Ghost: grietas púrpuras | Luz dorada recorre las grietas |
| **21** | **Primal Beast** | Cabeza agresiva con colmillos | Escamas/piel con patrón irregular | Trail de polvo y partículas | Ghost: espíritu; Shield: aura; Armor: placas; Speed: llamas | Rugido visual: onda circular + flash |
| **22** | **Huesos Ensamblados** | Vértebras conectadas en cadena | Marfil → gris → negro | Huesos se separan con la velocidad | Ghost: huesos fantasma; Shield: costillas; Armor: placas óseas | Luz blanca recorre las vértebras |
| **23** | **Cadena Viviente** | Eslabones metálicos entrelazados | Plata brillante → hierro oscuro | Eslabones dejan pequeñas chispas | Shield: eslabón circular; Armor: cadenas gruesas | Cada eslabón se ilumina sucesivamente |
| **24** | **Cinta Maldita** | Banda de tela enrollada | Rojo oscuro → negro | La cinta se estira al acelerar | Ghost: tela translúcida; Shield: sello; Armor: remaches | Marca luminosa viaja por la tela |
| **25** | **Ojo del Dungeon** | Cada segmento posee un ojo propio | Iris brillante → iris oscuro | Ojos miran hacia el movimiento | Items alteran color de iris y pupilas | Todos los ojos pestañean en secuencia |
| **26** | **Piedras Flotantes** | Segmentos con espacios visibles | Piedra clara → piedra oscura | Las piedras se separan al acelerar | Shield: piedras orbitando; Armor: bloques extra | Onda de polvo conecta todas las piedras |
| **27** | **Mantis Serpentina** | Cabeza y cuerpo insectoide con púas | Verde oliva → marrón oscuro | Patas producen pequeñas marcas | Armor añade exoesqueleto de quitina | Pulso amarillo recorre las placas |
| **28** | **Cadáver Reanimado** | Fragmentos de no-muerto unidos | Pálido → gris → púrpura | Partículas de ceniza | Ghost: espíritu; Armor: piel endurecida | Pulso rojizo a modo de latido |
| **29** | **Serpiente de Tinta** | Trazos de tinta caligráfica | Tinta sólida → tinta transparente | Salpicaduras de tinta detrás | Ghost: tinta diluida; Shield: círculo de tinta | Mancha negra se expande desde la cabeza |
| **30** | **Mosaico Viviente** | Baldosas geométricas variadas | Amarillo claro → naranja → marrón | Patrones se desplazan con velocidad | Cada item cambia el patrón geométrico | Todos los patrones se sincronizan |
| **31** | **Serpiente de Espinas** | Segmentos erizados de púas | Verde oscuro → gris → negro | Espinas apuntan hacia atrás | Armor multiplica las espinas | Espinas brillan y se retraen en cadena |
| **32** | **Ciempiés Mecánico** | Segmentos con engranajes y patas | Cobre → bronce → negro | Patas animadas venden la velocidad | Armor: piezas mecánicas; Shield: engranaje | Engranajes internos giran rápidamente |
| **33** | **Serpiente de Vapor** | Cuerpo de vapor condensado | Blanco → gris → transparente | Vapor aumenta con la velocidad | Ghost: vapor completo; Shield: condensación | Vapor explota y vuelve a comprimirse |
| **34** | **Carbón Ardiente** | Exterior de carbón con núcleo rojo | Amarillo → rojo → negro | Chispas y brasas | Armor: carbón sólido; Speed: núcleo ardiente | Una brasa recorre todo el cuerpo |
| **35** | **Serpiente de Papel** | Tiras de pergamino doblado (origami) | Crema → marrón → gris | Papeles se agitan detrás | Ghost: papel translúcido; Shield: sello de cera | Escritura luminosa atraviesa el cuerpo |
| **36** | **Marioneta Maldita** | Segmentos unidos por hilos | Dorado → marrón → negro | Hilos se tensan al acelerar | Shield: aro de control; Armor: madera reforzada | Una onda tira de todos los hilos |
| **37** | **Serpiente de Cera** | Cuerpo de cera derretida | Blanco cálido → amarillo → marrón | Deja pequeñas gotas de cera | Armor: cera endurecida | Flash caliente recorre el cuerpo |
| **38** | **Escarabajo Serpiente** | Caparazón de quitina brillante | Azul oscuro → turquesa → negro | Destellos de luz en el caparazón | Shield: caparazón circular; Armor: placas | Caparazón abre/cierra en secuencia |
| **39** | **Serpiente de Esporas** | Hongos creciendo sobre el cuerpo | Crema → verde oliva → marrón | Esporas forman un trail continuo | Ghost: nube de esporas; Shield: anillo | Explosión de esporas viaja por el cuerpo |
| **40** | **Serpiente de Sangre** | Líquido contenido en segmentos | Rojo brillante → rojo oscuro → negro | Gotas suspendidas detrás | Ghost: sangre translúcida; Armor: costra | Pulso rítmico como latido cardíaco |
| **41** | **Serpiente Astral** | Fragmentos de constelaciones | Blanco → azul → índigo | Deja estrellas formando una línea | Ghost: estrellas apagadas; Shield: órbita | Constelación se dibuja en todo el cuerpo |
| **42** | **Serpiente de Máscaras**| Cada tile lleva una máscara única | Dorado → rojo → negro | Máscaras giran ligeramente | Cada estado altera la máscara frontal | Todas las máscaras cambian de expresión |
| **43** | **Vidrio Roto** | Fragmentos angulares de cristal | Transparente → gris | Fragmentos vibran dejando reflejos | Ghost: invisible; Shield: cúpula; Armor: grueso | Reflejo blanco salta de trozo a trozo |
| **44** | **Cuerda Viviente** | Cuerda trenzada de cáñamo | Beige → marrón oscuro | Se estira y contrae al moverse | Ghost: deshilachada; Shield: nudo | Línea brillante recorre las fibras |
| **45** | **Serpiente de Musgo** | Piedra cubierta de vegetación | Verde claro → verde oscuro | Partículas vegetales quedan atrás | Ghost: musgo translúcido; Armor: corteza | Brote luminoso atraviesa el cuerpo |
| **46** | **Quimera Felina** | Cabeza felina + cuerpo serpentino | Dorado → marrón → negro | Pelo pixelado se agita | Ghost: silueta; Shield: aura; Armor: pelaje | Onda en forma de rugido sonoro |
| **47** | **Serpiente de Arena** | Partículas de polvo y dunas | Amarillo → ocre → marrón | La cola se deshace al avanzar | Ghost: dispersión; Shield: remolino | Ola de arena desde la cabeza |
| **48** | **Demonio de Carbón** | Silueta negra con cuernos | Rojo → naranja → negro | Cenizas ardientes | Ghost: humo; Shield: círculo infernal | Latido rojo por todo el cuerpo |
| **49** | **Cerámica Rota** | Porcelana con grietas doradas | Blanco → crema → gris | Fragmentos vibran | Ghost: piezas translúcidas; Shield: plato | Luz recorre las grietas (kintsugi) |
| **50** | **Serpiente de Óxido** | Metal viejo corroído | Naranja → marrón → gris | Virutas metálicas | Ghost: metal transparente; Armor: chapa | Oxidación roja recorre segmentos |
| **51** | **Serpiente de Cables** | Cables enrollados y circuitos | Blanco → gris → negro | Cables quedan extendidos | Ghost: cables sueltos; Shield: bobina | Corriente eléctrica recorre los cables |
| **52** | **Fuego Fatuo** | Llamas azules conectadas | Azul pálido → azul oscuro | Llamas se alargan con velocidad | Ghost: llama transparente; Shield: corona | Llama blanca atraviesa el cuerpo |
| **53** | **Serpiente de Humo** | Cuerpo basado en partículas | Gris claro → negro | Trail enorme y difuso | Ghost: difuminado; Shield: vórtice | Onda blanca comprime el humo |
| **54** | **Serpiente de Hiedra** | Tallos con hojas vivas | Verde claro → verde oscuro | Hojas caen detrás | Ghost: hojas transparentes; Armor: corteza | Flores brotan progresivamente |
| **55** | **Espantapájaros** | Tela rota y paja seca | Amarillo → marrón → negro | Paja sale despedida | Ghost: tela fantasma; Armor: costuras | Paja se enciende en secuencia |
| **56** | **Serpiente de Arcilla**| Bloques de barro húmedo | Terracota → marrón | El cuerpo se deforma levemente | Ghost: barro líquido; Armor: barro seco | Grietas atraviesan el cuerpo |
| **57** | **Serpiente de Marfil** | Bloques blancos tallados | Blanco → crema → gris | Polvo de tallado | Ghost: transparente; Shield: orbe | Brillo dorado recorre las tallas |
| **58** | **Espinas de Cristal** | Púas de cuarzo sobresalientes | Turquesa → azul → negro | Espinas vibran al moverse | Ghost: espinas translúcidas; Armor: púas | Todas las espinas brillan en cadena |
| **59** | **Serpiente de Garras** | Cada tile termina en pequeñas garras | Rojo oscuro → marrón → negro | Garras rasgan el suelo | Ghost: garras flotantes; Shield: círculo | Garras golpean en secuencia |
| **60** | **Piel de Serpiente** | Patrón de escamas pixeladas | Dorado → verde oscuro → negro | Escamas dejan huellas | Ghost: escamas tenues; Armor: gruesas | Escamas se iluminan sucesivamente |
| **61** | **Serpiente de Espiral**| Cada segmento es una espiral | Blanco → gris → negro | Espirales giran al acelerar | Ghost: espiral rota; Shield: gran espiral | Espiral luminosa viaja por el cuerpo |
| **62** | **Engranajes** | Dientes mecánicos articulados | Cobre → bronce → negro | Engranajes rotan activamente | Ghost: transparentes; Shield: orbital | Engranajes aceleran su rotación |
| **63** | **Serpiente de Llaves** | Pequeñas llaves de mazmorra | Oro → bronce → hierro | Llaves vibran | Ghost: llaves fantasma; Shield: cerradura | Una cerradura se ilumina y abre |
| **64** | **Serpiente de Cofre** | Madera y herrajes de cofre | Madera clara → caoba → negro | Astillas quedan atrás | Ghost: madera translúcida; Armor: hierro | Cerraduras se abren en cascada |
| **65** | **Pergamino Antiguo** | Tiras de papiro con escritura | Crema → marrón → sepia | Glifos flotan en el trail | Ghost: texto incompleto; Shield: sello | Escritura dorada se revela |
| **66** | **Serpiente de Monedas**| Pila de monedas apiladas | Oro → cobre → bronce | Monedas giran sobre su eje | Ghost: monedas transparentes; Shield: aro | Destellos dorados consecutivos |
| **67** | **Serpiente de Dados** | Cubos con puntos marcados | Blanco → gris → negro | Dados ruedan al avanzar | Ghost: dados transparentes; Armor: metal | Todos muestran el mismo número |
| **68** | **Serpiente de Ajedrez**| Piezas de ajedrez estilizadas | Blanco → gris → negro | Patrón de tablero en el trail | Ghost: pieza fantasma; Armor: torre | Flash siguiendo patrón de jaque |
| **69** | **Serpiente de Dominó** | Fichas rectangulares con puntos | Blanco → crema → negro | Fichas caen en el trail | Ghost: sin puntos; Shield: doble seis | Efecto dominó cabeza→cola |
| **70** | **Serpiente de Cartas** | Naipes superpuestos en abanico | Blanco → rojo/negro → gris | Cartas se dispersan en el trail | Ghost: cartas transparentes; Shield: mazo | Cartas se voltean en cadena |
| **71** | **Dados Malditos** | Dados negros con runas rojas | Rojo → púrpura → negro | Símbolos mutan con velocidad | Ghost: números vacíos; Shield: flotante | Todos los dados muestran calaveras |
| **72** | **Serpiente de Reloj** | Mecanismos con manecillas | Dorado → cobre → negro | Manecillas giran con velocidad | Ghost: tiempo detenido; Shield: reloj | Manecillas se sincronizan a las 12 |
| **73** | **Campanas de Mazmorra**| Campanas metálicas alineadas | Oro → bronce → negro | Vibración visible en el cuerpo | Ghost: campanas mudas; Armor: blindadas | Onda sónica atraviesa el cuerpo |
| **74** | **Teclas de Piano** | Teclas blancas y negras | Blanco → gris → negro | Teclas se presionan visualmente | Ghost: transparentes; Shield: notas | Onda musical de color |
| **75** | **Cuerda Sonora** | Cuerda de instrumento musical | Dorado → marrón → negro | La cuerda vibra con la velocidad | Ghost: vibración tenue; Shield: resonancia | Pulso armónico cabeza→cola |
| **76** | **Máscaras Teatrales** | Comedia y tragedia alternadas | Blanco → gris → negro | Expresiones cambian rápidamente | Ghost: sin rostro; Armor: máscara rígida | Todas cambian de expresión |
| **77** | **Marioneta de Madera** | Títere articulado por piezas | Beige → marrón → negro | Articulaciones exageradas | Ghost: hilos invisibles; Shield: aro | Hilos tiran del cuerpo en cascada |
| **78** | **Serpiente de Tótems** | Tótems tribales tallados | Rojo → marrón → negro | Tótems vibran rítmicamente | Ghost: espectrales; Shield: circular | Símbolos se encienden sucesivamente |
| **79** | **Campamento** | Troncos y maderas con cenizas | Marrón claro → marrón → carbón | Hojas/cenizas en el trail | Ghost: troncos transparentes; Shield: fuego | Una brasa recorre el cuerpo |
| **80** | **Serpiente Antorcha** | Cada segmento aloja una llama | Amarillo → naranja → rojo oscuro | Llamas se inclinan hacia atrás | Ghost: fuego azul tenue; Shield: anillo | Todas las llamas arden al máximo |
| **81** | **Serpiente de Faroles**| Faroles de hierro con velas | Amarillo → naranja → negro | Halos de luz en el suelo | Ghost: luz apagada; Shield: farol orbital | Los faroles se encienden uno a uno |
| **82** | **Ventanas de Cripta** | Ventanas góticas con luz | Azul claro → gris → negro | Luz se proyecta en el suelo | Ghost: ventanas apagadas; Shield: vitral | Todas las ventanas se iluminan |
| **83** | **Rejas de Prisión** | Barrotes metálicos enlazados | Plata → gris → negro | Trail de líneas verticales | Ghost: barrotes rotos; Shield: celda | Resplandor recorre las rejas |
| **84** | **Puertas de Mazmorra**| Pequeñas puertas con cerrojos | Madera clara → marrón → negro | Puertas vibran y se abren | Ghost: puertas abiertas; Armor: blindada | Todas las puertas se abren en cascada |
| **85** | **Ladrillos de Muro** | Muro de ladrillos trabados | Terracota → marrón → gris | Ladrillos se separan levemente | Ghost: ladrillos flotantes; Shield: muro | Grieta luminosa atraviesa el muro |
| **86** | **Baldosas de Cripta** | Losetas con dibujos grabados | Crema → ocre → gris | Dejan marcas en el suelo | Ghost: baldosas tenues; Armor: losa doble | Baldosas se iluminan en secuencia |
| **87** | **Píxeles Sueltos** | Conglomerado de píxeles libres | Blanco → gris → negro | Píxeles se dispersan al correr | Ghost: dispersión; Shield: orbital | Onda blanca reorganiza los píxeles |
| **88** | **Barras Horizontales**| Franjas de energía lineal | Amarillo → naranja → rojo oscuro | Barras se estiran hacia atrás | Ghost: incompletas; Shield: concéntricas | Barrido luminoso vertical |
| **89** | **Anillos Concéntricos**| Aros circulares pulsantes | Blanco → gris → negro | Anillos se expanden al correr | Ghost: anillos rotos; Shield: gran anillo | Onda circular atraviesa los aros |
| **90** | **Rompecabezas** | Piezas que encajan entre sí | Azul claro → azul oscuro → negro | Piezas se desacoplan al girar | Ghost: desencajadas; Armor: encaje doble | Todas las piezas encajan de golpe |
| **91** | **Serpiente de Código** | Caracteres de terminal verde | Verde claro → verde oscuro → negro | Deja rastro de caracteres | Ghost: código fragmentado; Shield: corchetes | Caracteres se vuelven blancos |
| **92** | **Glifos Arcanos** | Símbolos arcanos abstractos | Marfil → ocre → marrón | Glifos giran sobre su centro | Cada item tiene un glifo único | Glifos se activan cabeza→cola |
| **93** | **Sellos de Hechizo** | Sellos rúnicos circulares | Rojo → naranja → negro | Sellos se imprimen en el suelo | Ghost: sello roto; Shield: sello mayor | Sello blanco viaja por el cuerpo |
| **94** | **Cristal Negativo** | Solo el contorno es visible | Blanco → gris → negro | Contorno se fragmenta detrás | Ghost: desaparición; Armor: contorno grueso | Flash rellena la silueta entera |
| **95** | **Sombras Geométricas** | Proyección de sombras poligonales | Crema → gris → negro | Sombras se alargan con velocidad | Ghost: solo sombra; Shield: sombra orbe | Una luz elimina las sombras |
| **96** | **Serpiente de Capas** | 3–4 láminas desplazadas | Blanco → gris → negro | Las capas se abren al correr | Ghost: capas separadas; Armor: compactas | Todas las capas se alinean en onda |
| **97** | **Coordenadas** | Retícula con marcas de cuadrícula | Verde → oliva → negro | Coordenadas quedan impresas | Ghost: incompletas; Shield: cuadrícula | Línea de coordenadas recorre el cuerpo |
| **98** | **Serpiente de Portales**| Marcos de portal dimensional | Cian → azul → violeta oscuro | Portales dejan copias espectrales | Ghost: portal vacío; Shield: cerrado | Onda atraviesa todos los portales |
| **99** | **Prisma Cristalino** | Polígono con facetas internas | Blanco → gris → negro | Fragmentos salen disparados | Ghost: transparente; Shield: polígono | Flash blanco divide cada faceta |
| **100**| **Trazo Continuo** | Línea continua tipo pincelada | Amarillo → naranja → rojo | El trazo se estira detrás | Ghost: trazo discontinuo; Armor: doble | Onda fluida recorre el trazo |

---

### 12.3 Zoología, Fisiología y Criaturas de Mazmorra (101 a 125)

| # | Concepto | Identidad Visual y Rasgo Anatómico Distintivo |
|---|---|---|
| **101** | **Anguila Abisal** | Cuerpo largo y flexible con pequeñas aletas laterales que ondulan en sincronía con el giro. |
| **102** | **Axolote Serpentino** | Branquias externas ramificadas alrededor de la cabeza que emiten bioluminiscencia rosada. |
| **103** | **Lamprea de Mazmorra** | Boca circular con dientes cónicos concéntricos pixelados como rasgo dominante frontal. |
| **104** | **Salamandra de Fuego** | Cabeza ancha, pequeñas patas laterales que marcan el paso y cola de brasa. |
| **105** | **Gusano Acorazado** | Cuerpo blando protegido por anillos concéntricos de quitina articulada. |
| **106** | **Oruga Nocturna** | Segmentos redondeados con múltiples patas diminutas que avanzan en onda metamérica. |
| **107** | **Sanguijuela Gigante** | Cuerpo aplanado y ventosa anterior prominente que se expande al alimentarse. |
| **108** | **Planaria Fluida** | Cabeza triangular con ocelos diminutos y cuerpo con bordes ondulantes continuos. |
| **109** | **Tardígrado Blindado** | Cabeza compacta con micro-garras y segmentos cilíndricos ultra-resistentes. |
| **110** | **Ciempiés Fantasma** | Decenas de patas translúcidas que caminan bajo un exoesqueleto oscuro. |
| **111** | **Babosa Espinada** | Cuerpo viscoso con protuberancias sensoriales eréctiles a lo largo del dorso. |
| **112** | **Gusano de Cristal** | Silueta 100% transparente donde se aprecian los órganos y la comida ingerida viajando. |
| **113** | **Serpiente Marina** | Aleta dorsal continua festoneada en lugar de escamas convencionales. |
| **114** | **Mordedor Subterráneo** | Mandíbulas hipertrofiadas con cuerpo cónico ultra-delgado. |
| **115** | **Larva Colosal** | Cabeza diminuta con segmentos globulares exageradamente hinchados. |
| **116** | **Gusano de Arena** | Placas frontales pesadas con efecto visual de semi-enterramiento en la cuadrícula. |
| **117** | **Criatura Radial** | Cada segmento posee micro-tentáculos orientados radialmente en 360 grados. |
| **118** | **Parásito Arcano** | Cuerpo filiforme con órgano bucal desproporcionado que absorbe el maná de la sala. |
| **119** | **Depredador Ciego** | Sin ojos; dos antenas frontales vibrantes señalan el vector de avance. |
| **120** | **Murciélago Serpentino** | Membranas alares laterales que conectan los segmentos contiguos. |
| **121** | **Rata Segmentada** | Cabeza de roedor con cuerpo modular de vértebras y pelaje oscuro. |
| **122** | **Lagarto de Mazmorra** | Escamas reptilianas con pequeñas patas articuladas que tocan el suelo. |
| **123** | **Cangrejo Serpiente** | Pinzas frontales defensivas y caparazones convexos superpuestos. |
| **124** | **Escorpión Lineal** | Pedipalpos frontales y aguijón estilizado integrado en el segmento final de la cola. |
| **125** | **Araña Continua** | Cada segmento cuenta con un par de patas arácnidas que se mueven al unísono. |

---

### 12.4 Litología, Minerales y Metales Nobles (126 a 150)

| # | Concepto | Material y Textura Visual |
|---|---|---|
| **126** | **Mármol Viviente** | Bloques de mármol blanco de Carrara con vetas oscuras que mutan dinámicamente. |
| **127** | **Obsidiana Volcánica** | Negro azabache de fractura concoidea con destellos especulares violáceos en las aristas. |
| **128** | **Cobre Pulido** | Metal rojizo cálido con reflejos especulares metálicos que se desplazan con la dirección. |
| **129** | **Plata Lunar** | Plata pulida fría con brillo anisotrópico según el vector de movimiento. |
| **130** | **Oro Viejo** | Oro envejecido con pátina oscura en las hendiduras y brillo dorado en los vértices. |
| **131** | **Bronce Tallado** | Bloques de bronce con bajorrelieves rúnicos distintos en cada bloque. |
| **132** | **Pizarra Negra** | Láminas planas de piedra metamórfica oscura estratificada. |
| **133** | **Granito Moteado** | Textura compuesta por píxeles de cuarzo, feldespato y mica brillante. |
| **134** | **Basalto Columnar** | Prismas hexagonales oscuros con micro-grietas incandescentes. |
| **135** | **Caliza Porosa** | Roca sedimentaria beige con oquedades y micro-fósiles incrustados. |
| **136** | **Coral Calificado** | Ramificaciones de carbonato de calcio que crecen levemente al consumir comida. |
| **137** | **Nácar Iridiscente** | Superficie blanca perlada con reflejos de arcoíris cambiantes según la luz. |
| **138** | **Ámbar Fósil** | Resina fósil translúcida con pequeñas inclusiones de insectos atrapados. |
| **139** | **Jade Imperial** | Verde esmeralda profundo y denso con lustre ceroso en los bordes. |
| **140** | **Lapislázuli** | Azul ultramar intenso salpicado de motas doradas de pirita. |
| **141** | **Pergamino Quemado** | Bordes carbonizados quebradizos con centro traslúcido amarillento. |
| **142** | **Cuero Curtido** | Segmentos de cuero cosidos con pespuntes visibles de hilo grueso. |
| **143** | **Caucho Vulcanizado** | Negro mate con alta elasticidad visual durante los giros cerrados. |
| **144** | **Gelatina Arcana** | Masa viscosa coloidal que se deforma elásticamente con la aceleración. |
| **145** | **Porcelana de Dinastía** | Cerámica blanca inmaculada con finísimas fracturas de esmalte vitrificado. |
| **146** | **Alquitrán Denso** | Brea negra hiper-viscosa que deja gotas elásticas en el trail. |
| **147** | **Tiza de Pizarra** | Trazo blanco puro con textura polvorienta que desprende partículas al rozar paredes. |
| **148** | **Grafito Metálico** | Gris plomo oscuro con brillo especular sutil en los ángulos rectos. |
| **149** | **Ceniza Compacta** | Bloques de ceniza volcánica prensada que pierden fragmentos con la velocidad. |
| **150** | **Arcilla Policromada** | Cerámica cocida pintada a mano con pigmentos minerales tradicionales. |

---

### 12.5 Arquitectura y Espacios del Calabozo (151 a 175)

| # | Concepto | Estructura Arquitectónica en Miniatura |
|---|---|---|
| **151** | **Muralla Almenada** | Cada segmento representa una sección de muralla fortificada con aspilleras. |
| **152** | **Acueducto Romano** | Arcos de piedra sucesivos por cuyo interior fluye agua cristalina animada. |
| **153** | **Puente Levadizo** | Tablones y cadenas que se ensamblan sucesivamente al avanzar la cabeza. |
| **154** | **Escalera de Caracol** | Peldaños de piedra concéntricos que simulan un descenso al abismo. |
| **155** | **Túnel de Sillar** | Bóvedas de cañón en miniatura que forman un pasadizo continuo móvil. |
| **156** | **Columna Clásica** | Tambores de columna estriados apilados horizontalmente. |
| **157** | **Catedral Gótica** | Arbotantes, ojivas y pequeños vitrales de colores iluminados desde el interior. |
| **158** | **Mazmorra de Celdas** | Conjunto de barrotes y cadenas que encierran sombras misteriosas. |
| **159** | **Castillo Modular** | Torreones almenados que emergen periódicamente en los nodos del cuerpo. |
| **160** | **Torre Invertida** | Arquitectura que se proyecta hacia la profundidad del suelo. |
| **161** | **Altar Ceremonial** | Bloques de piedra ritual con canalizaciones y símbolos tallados. |
| **162** | **Cripta de Nichos** | Nichos funerarios excavados con pequeñas lápidas y velas votivas. |
| **163** | **Biblioteca Prohibida**| Estanterías de libros antiguos con lomos de cuero y pergaminos enrollados. |
| **164** | **Laboratorio Alquímico**| Matraces, retortas y alambiques con líquidos de colores burbujeantes. |
| **165** | **Presidio de Hierro** | Celdas de castigo de hierro remachado con cerrojos oxidados. |
| **166** | **Torre del Hechicero** | Tejados cónicos de pizarra azul con pequeñas buhardillas iluminadas. |
| **167** | **Campanario Olvidado** | Estructuras de madera y vigas que sostienen campanas de bronce. |
| **168** | **Alcantarilla Mayor** | Tuberías de piedra y desagües con agua verdosa fluyendo. |
| **169** | **Galería de Mina** | Entibados de madera de pino y raíles metálicos en miniatura. |
| **170** | **Ferrocarril Minero** | Vagones de carbón articulados con enganches mecánicos funcionales. |
| **171** | **Elevador Hidráulico** | Cajas de montacargas con cables y contrapesos móviles. |
| **172** | **Acueducto en Ruinas** | Mampostería fracturada con cascadas de agua cayendo entre bloques. |
| **173** | **Callejón Sombrío** | Fachadas de edificios medievales con faroles de gas encendidos. |
| **174** | **Puente de Cuerdas** | Tablas de madera suspendidas sobre cuerdas tensadas que oscilan. |
| **175** | **Ruina Ancestral** | Bloques ciclópeos fracturados cubiertos de musgo y líquenes milenarios. |

---

### 12.6 Señales, Frecuencias, Glitches y Óptica (176 a 200)

| # | Concepto | Fenómeno Óptico / Físico Representado |
|---|---|---|
| **176** | **Pulso Vital** | Segmentos que se expanden y contraen rítmicamente siguiendo una función senoidal. |
| **177** | **Frecuencia Modulada** | Barras de ecualizador gráfico que reaccionan a la música y la velocidad. |
| **178** | **Onda Sinusoidal** | El cuerpo oscila transversalmente simulando una función matemática pura. |
| **179** | **Espectro Visible** | Gradiente cromático completo de Newton ($380\,\text{nm} \to 750\,\text{nm}$). |
| **180** | **Interferencia de Moiré**| Dos tramas de líneas superpuestas que generan patrones cinéticos al moverse. |
| **181** | **Eco de Fósforo** | Segmentos sólidos acompañados por sombras de persistencia fósforo verde. |
| **182** | **Afterimage Cuántico** | Deja copias holográficas fijas en la cuadrícula que se desvanecen en 0.5s. |
| **183** | **Desfase Temporal** | Cada bloque muestra el estado visual que tenía la cabeza hace $N$ frames. |
| **184** | **Glitch Cromático** | Desplazamientos aleatorios horizontales en los canales rojo y azul. |
| **185** | **Scanline CRT** | Rayado horizontal de televisión de tubo con parpadeo de 60 Hz. |
| **186** | **Dither de Difusión** | Sombreado generado mediante el algoritmo de Floyd-Steinberg. |
| **187** | **Halftone Imprenta** | Trama de semitonos de puntos CMYK de imprenta de cómic retro. |
| **188** | **Matriz de Bayer** | Dithering ordenado de $4 \times 4$ que modula su densidad hacia la cola. |
| **189** | **Ruido de Perlin** | Textura procedural de ruido coherente que fluye a lo largo del cuerpo. |
| **190** | **Vector de Láser** | Líneas de fósforo puro de osciloscopio con vértices sobreiluminados. |
| **191** | **Wireframe 3D** | Geometría tridimensional proyectada en alambre sin oclusión de caras. |
| **192** | **Outline Hueco** | Contorno exterior de 2 px con interior 100% transparente. |
| **193** | **Espacio Negativo** | El cuerpo es un vacío que recorta el fondo y revela el tapiz inferior. |
| **194** | **Retícula de Mira** | Cruces de puntería táctica orientadas hacia el vector director. |
| **195** | **Sub-Grilla Cuadrada** | Cada segmento se divide en una cuadrícula interna de $4 \times 4$ sub-bloques. |
| **196** | **Rosa de los Vientos** | Marcas cardinales (N, S, E, O) que rotan según la orientación. |
| **197** | **Simetría Bilateral** | Cada bloque es un espejo geométrico perfecto de su eje central. |
| **198** | **Asimetría Fractal** | Deformación orgánica no lineal que nunca se repite entre bloques. |
| **199** | **Conjunto de Mandelbrot**| Pequeños fractales iterados grabados en el interior de cada celda. |
| **200** | **Mosaico Caleidoscópico**| Patrones triangulares que giran en direcciones opuestas en cada paso. |

---

### 12.7 Variantes Híbridas Especiales (Selección de Alto Impacto)

| Concepto Híbrido | Fusión de Arquetipos | Efecto Visual y Sinergia |
|---|---|---|
| **Dragón Wireframe** | Dragón Pixelado + Wireframe | Cuernos, hocico y alas definidos exclusivamente por aristas vectoriales brillantes. |
| **Cobra Glitch** | Cobra de Mazmorra + Glitch | La capucha vibra con franjas horizontales desplazadas y ruido cromático. |
| **Cristal Rúnico** | Serpiente de Cristal + Runas | Bloques de cuarzo transparente con runas doradas flotando en su interior. |
| **Víbora Hexagonal** | Electric Viper + Hexágonos | Rayos eléctricos que saltan entre los vértices de hexágonos engranados. |
| **Void Shard** | Serpiente Void + Shard | Fragmentos poligonales negros flotantes con bordes de glow ultravioleta. |
| **Esqueleto Neón** | Huesos Ensamblados + Neón | Vértebras de hueso negro con médula espinal luminosa de color cian neón. |
| **Cadena Espectral** | Cadena Viviente + Espectral | Eslabones de hierro fantasmal que dejan copias semitransparentes en el camino. |
| **Ojo de Cristal** | Ojo del Dungeon + Cristal | Globos oculares facetados como diamantes que refractan la luz de la sala. |
| **Piedra Eléctrica** | Piedras Flotantes + Electric Viper | Bloques de granito levitando con arcos voltaicos uniendo los huecos intermedios. |
| **Mantis Mecánica** | Mantis + Ciempiés Mecánico | Exoesqueleto de bronce con patas de pistones hidráulicos funcionales. |
| **Tinta Void** | Tinta + Void | Líquido negro puro que absorbe la luz y deja manchas de vacío en el suelo. |
| **Espinas Cristalinas** | Espinas + Espinas de Cristal | Púas de amatista translúcida que vibran y refractan proyectiles enemigos. |
| **Fuego Fatuo Astral** | Fuego Fatuo + Astral | Llamas de plasma azul que contienen pequeñas nebulosas y estrellas fugaces. |
| **Antorcha Espectral** | Antorchas + Espectral | Fuego verde fantasmal que proyecta sombras invertidas en las paredes. |
| **Código Eléctrico** | Código + Electric Viper | Caracteres binarios verdes por los que circulan descargas eléctricas de alto voltaje. |
| **Anguila Eléctrica** | Anguila Abisal + Electric Viper | Aletas dorsales bioluminiscentes que se sobrecargan de chispas en las curvas. |
| **Axolote Cristalino** | Axolote + Cristal | Branquias de cristal rosado translúcido que emiten destellos al comer fruta. |
| **Gusano de Magma** | Gusano Acorazado + Lava | Anillos de roca volcánica con núcleo incandescente que gotea lava. |
| **Obsidiana Void** | Obsidiana + Void | Vidrio volcánico negro con absorción lumínica absoluta y aristas moradas. |
| **Cobre Eléctrico** | Cobre Pulido + Electric Viper | Superficie de cobre rojizo con pátina verde y arcos eléctricos chispeantes. |

---

### 12.8 Arquitectura de Selección y Persistencia
* **Almacenamiento**: `profile.skin = "nombre_id"` en `config/profiles.dat`.
* **Desbloqueo**: Asociado a hitos de juego, logros de [`systems/achievements.lua`](file:///c:/Users/Usuario/Documents/Games%20Creation/Snake-with-Love2D/systems/achievements.lua) o compra mediante `totalCoins` en el **Santuario**.
* **Integración en Render**: `render/renderMain.lua` consulta el descriptor de la skin activa para invocar la rutina procedural correspondiente (`drawSnakeClassic`, `drawSnakeShard`, `drawSnakeDotMatrix`, `drawSnakeWireframe`, `drawSnakeHex`, `drawSnakeBarcode`) garantizando cero asignaciones de tablas por frame (*Zero-GC*).

## 13. Mathematical Models & Economy Curves

Especificación formal de las fórmulas algebraicas que rigen la economía, la dificultad y las curvas de progresión:

### 13.1 Curva de Velocidad de la Serpiente
El intervalo de tiempo en segundos por casilla recorrida ($T$) se calcula en función de la velocidad base ($T_{\text{base}}$) y las frutas consumidas ($N_{\text{frutas}}$):

$$T(N_{\text{frutas}}) = \max\left(T_{\text{min}}, T_{\text{base}} \cdot (1 - \text{decremento})^{N_{\text{frutas}}}\right)$$

* Parámetros estándar:
  * $T_{\text{base}} = 0.15\,\text{s}$ (`VELOCIDAD_INICIAL`).
  * $T_{\text{min}} = 0.04\,\text{s}$ (`VELOCIDAD_MINIMA`).
  * $\text{decremento} = 0.005$ por cada comida ingerida.

### 13.2 Puntuación y Multiplicadores de Combo
La puntuación otorgada por cada comida o enemigo eliminado se rige por:

$$S_{\text{total}} = \lfloor P_{\text{base}} \times (1 + C \times M_{\text{combo}}) \times M_{\text{score}} \times M_{\text{streak}} \rfloor$$

* $P_{\text{base}}$: Puntos base de la acción (Normal: 10, Oro: 25, Moneda: 5, Chaser: 50, Boss: 500).
* $C$: Contador de combo actual (`comboCount`), activo dentro de una ventana de tiempo $t \le 8.0\,\text{s}$.
* $M_{\text{combo}} = 0.5$ (`COMBO_MULTIPLIER`).
* $M_{\text{score}}$: Multiplicadores de ítems activos (Duplicador: 2.0, Estrella: 3.0).
* $M_{\text{streak}}$: Multiplicador de racha de supervivencia ($1.0 \le M_{\text{streak}} \le 2.0$, con paso $+0.1$ por sala).

### 13.3 Economía de Monedas y Drop Rate
Monedas generadas por evento ($G_{\text{monedas}}$):

$$G_{\text{monedas}} = \lfloor (D_{\text{base}} + B_{\text{coin}}) \times M_{\text{streak}} \rfloor$$

* $D_{\text{base}}$: Normal: 1$, Oro: 2$, Moneda: 3$, Chaser: 3$, Patroller: 2$, Spawner: 1$, Boss: $5 + 2 \times \text{etapa}$.
* $B_{\text{coin}} = 1$ si el pasivo `extraCoin` está activo.

### 13.4 Escalado de Dificultad e IA por Etapa
La velocidad de decisión de los enemigos Chaser disminuye su intervalo ($I_{\text{chaser}}$) según la etapa actual $E \in [1, 5]$:

$$I_{\text{chaser}}(E) = \max\left(0.15\,\text{s}, \frac{0.30}{S_{\text{mult}}} \times 0.90^{E - 1}\right)$$

* $S_{\text{mult}}$: Modificador de velocidad de etapa (1.0 en E1 hasta 1.8 en E5).

## 14. Stage Tarot Draft System (Cartas del Destino)

### 14.1 Flujo y Ciclo de Vida
* **Momento de Selección**: Al completar la Sala 1, 2 y 4 de cada etapa (durante la transición "SALA COMPLETADA"), la pantalla se abre en un tapete místico con 3 cartas aleatorias.
* **Duración**: Las cartas seleccionadas permanecen activas durante toda la etapa en curso. Al derrotar al Boss o Mini-Jefe y avanzar a la siguiente etapa, el mazo se limpia para iniciar un nuevo ciclo de *draft*.
* **Límite**: Máximo 3 cartas activas simultáneamente por etapa.

### 14.2 Mazo Completo de 12 Cartas del Destino
| ID Carta | Arquetipo | Efecto Mecánico | Feedback Visual & SFX |
|---|:---:|---|---|
| **I. El Mercurio** | Velocidad | `baseSpeed` se acelera un 15%, pero cada comida consumida duplica el valor del multiplicador de combo. | Estela de viento y silbido al doblar esquinas. |
| **II. La Espina Dorsal** | Defensa | Los 3 últimos segmentos de la cola se vuelven de hierro sólido: destruyen a cualquier Chaser que intente morder la cola. | Chispas metálicas y tinte gris acero en los últimos 3 bloques. |
| **III. El Ojo de Águila** | Puntuación | La ventana de tiempo de combo se extiende de 8.0s a 12.0s. | Reloj de combo parpadeante con aura dorada. |
| **IV. Ladrón de Sombras** | Economía | Rozar (*Near-Miss*) a un enemigo pasando por una celda contigua genera +1 moneda automáticamente. | Partícula de moneda voladora hacia el HUD con sonido `buttonClick`. |
| **V. Digestión Alquímica**| Alquimia | 25% de probabilidad de que cualquier comida normal aparezca como comida de Oro (+25 pts / +2$). | Brillo centelleante en la comida recién generada. |
| **VI. Sangre de Dragón** | Ofensivo | Las comidas Picantes aumentan la duración de su rastro de fuego a 6.0 segundos (base 3.5s). | Llamas más altas y con partículas de brasas densas. |
| **VII. Cero Absoluto** | Control | La Fruta Helada congela a los enemigos durante 4.0 segundos y los vuelve frágiles (mueren al chocar con ellos). | Los enemigos congelados se cubren de un bloque de hielo cúbico. |
| **VIII. El Círculo Mágico**| Constricción| El radio de atracción del bucle de constricción aumenta +1 casilla alrededor del cuerpo. | Anillo rúnico concéntrico visible durante la constricción. |
| **IX. Espejo Astral** | Evasión | La serpiente puede atravesar las paredes exteriores 1 vez por sala sin morir incluso en biomas sin *wall-wrap*. | Resplandor holográfico en los bordes del nivel. |
| **X. La Bolsa de Midas** | Economía | Al iniciar cada sala, caen 3 monedas en celdas aleatorias de la cuadrícula. | Lluvia inicial de monedas con sonido de tintineo. |
| **XI. Corazón de Hierro** | Supervivencia| Sobrevivir a una sala con menos de 5 segmentos otorga automáticamente 1 carga de Escudo gratis. | Aura blanca pulsante en el corazón de la cabeza. |
| **XII. El Segador** | Ofensivo | Cada enemigo eliminado extiende la duración de los buffs de comida activos en +0.5 segundos. | Destello morado en el cronómetro de buff. |

## 15. Special Mystery Rooms (Salas de Eventos Especiales)

Aparecen con una probabilidad del 6% en lugar de una sala estándar, introduciendo mecánicas de juego alternativas:

### 15.1 La Guarida del Apostador (Gambler's Den)
* **Mecánica**: En el centro de la sala hay una loseta con una Ruleta de la Fortuna. Al pasar la cabeza por encima, se abre una apuesta rápida de 10 monedas.
* **Desafío**: La sala genera 3 comidas doradas y un temporizador de 15 segundos.
  * **Victoria (recoger las 3 antes de 0s)**: Otorga 40 monedas, un ítem aleatorio de la tienda y `survivalStreak +0.3`.
  * **Derrota (tiempo agotado)**: Pierdes las 10 monedas apostadas y se generan 2 Chasers adicionales antes de abrir la puerta.

### 15.2 La Sala de la Sombra Espejo (Doppelgänger Mirror)
* **Mecánica**: Una serpiente espectral de color amatista oscuro (`{0.5, 0.1, 0.8, 0.7}`) nace del lado opuesto de la sala con la misma longitud que el jugador y replica sus giros con 1.2 segundos de retraso.
* **Objetivo**: La sombra no te ataca activamente pero su cuerpo es un obstáculo móvil letal. Si logras encerrarla con el *Constrictor Loop* o alimentarla con 3 frutas normales, se disuelve en una supernova de 30 monedas y un cofre dorado.

### 15.3 Fiebre del Oro (Gold Rush Chamber)
* **Mecánica**: Una sala de bonificación sin enemigos letales. Durante 12 segundos, 20 monedas rebotan a toda velocidad por la cuadrícula como pelotas de pinball.
* **Objetivo**: Recoger tantas monedas como sea posible antes de que expire el tiempo y se desbloquee la puerta de salida.

### 15.4 La Prueba de los Tres Sellos (Trial of Triads)
* **Mecánica**: Tres baldosas rúnicas numeradas (1, 2, 3) aparecen en tres esquinas. El jugador debe pisarlas en orden secuencial en menos de 10 segundos mientras evita patrulleros en cruz. Completar el sello abre una cámara secreta con un Altar legendario.

## 16. Status Effects Engine (Motor de Estados Alterados)

Sistema de micro-estados temporales que modifican el comportamiento de la serpiente:

### 16.1 Estado de Frenesí (Overdrive)
* **Activación**: Alcanzar una racha de Combo x6 en cualquier sala.
* **Duración**: 4.0 segundos.
* **Efectos**: Velocidad +25%, glow dorado cegador, y la cabeza destruye cualquier obstáculo de piedra o Chaser menor al chocar contra ellos sin sufrir daño.

### 16.2 Petrificación Defensiva (Medusa Tail)
* **Activación**: Pisada de loseta rúnica o activación del ítem de piedra.
* **Duración**: 2.0 segundos.
* **Efectos**: La serpiente se vuelve de granito rígido y no puede alterar su dirección (sigue recto a velocidad fija), siendo 100% invulnerable: destruye a cualquier proyectil o enemigo que colisione contra ella.

### 16.3 Intoxicación / Confusión (Venom Spore)
* **Activación**: Atravesar nubes de esporas venenosas generadas por trampas en la Colmena Tóxica.
* **Duración**: 1.8 segundos.
* **Efectos**: Controles invertidos (`Arriba ↔ Abajo`, `Izquierda ↔ Derecha`), shader de aberración cromática verde y viñeta ondulante en pantalla.

### 16.4 Criostasis (Cryo-Stasis)
* **Activación**: Al recibir esquirlas del Gólem de Escarcha o pisar trampas de hielo puro.
* **Duración**: 2.5 segundos.
* **Efectos**: La velocidad de paso se reduce un 30%, pero la serpiente se vuelve inmune a proyectiles de daño a distancia.

## 17. Meta-Progression Shrine (Árbol de Talentos del Santuario)

Ubicado en el Menú Principal bajo el botón "SANTUARIO". Permite gastar las monedas acumuladas en `profile.stats.totalCoins` para desbloquear bendiciones permanentes:

| Rama | Talento | Rangos | Coste (Tier I / II / III) | Efecto Permanente en Toda Expedición |
|---|---|:---:|---|---|
| **Fortuna** | **Bolsa de Herencia** | III | 100$ / 250$ / 500$ | Inicia cada nueva partida con **5 / 10 / 15 monedas** en el bolsillo. |
| **Fortuna** | **Imán Residual** | II | 150$ / 350$ | La cabeza de la serpiente atrae monedas a **radio 1 / radio 2** pasivamente. |
| **Alquimia** | **Estómago de Dragón**| II | 200$ / 450$ | Aumenta la duración de todos los buffs de comida especial en **+1.0s / +2.0s**. |
| **Alquimia** | **Pociones Espesas** | I | 300$ | Los efectos de ralentización del tiempo duran **1.5s extra**. |
| **Misticismo**| **Sexto Sentido** | I | 250$ | Muestra un icono sobre la puerta indicando el tipo de la siguiente sala (Élite, Tesoro, Normal). |
| **Misticismo**| **Pacto de Piedad** | II | 180$ / 400$ | Reduce el coste de revivir en el modal de muerte de 30$ a **25$ / 20$**. |
| **Combate** | **Cuerpo Temple** | I | 500$ | La serpiente puede resistir **1 impacto accidental contra su propia cola** por etapa sin morir. |
| **Combate** | **Foco del Cazador** | II | 220$ / 480$ | La ventana de combo se amplía permanentemente a **9.0s / 10.0s** (base 8.0s). |

## 18. Daily Challenges, Codex & Bounties (Desafíos Diarios y Códice)

### 18.1 Mazmorra Diaria (Daily Challenge)
* **Semilla Determinista**: Generada mediante el hash numérico del día (`año * 10000 + mes * 100 + día`), garantizando que todos los jugadores jueguen exactamente la misma disposición de salas, enemigos y comida.
* **Reglas**: 1 único intento diario por perfil, mutadores diarios aleatorios (ej. *"Lunes de Fuego"*: todas las comidas son Guindillas Picantes, velocidad base +30%), tabla de clasificación local.

### 18.2 Códice de la Serpiente Antigua (Lore & Bestiary)
* **Bestiario Ilustrado**: Fichas pixel-art interactivas que muestran modelos en rotación, estadísticas y descripciones místicas de los 6 enemigos y 5 mini-jefes, desbloqueados al derrotarlos por primera vez.
* **Matriz de Sinergias Descubiertas**: Panel estilo álbum que registra las 8 sinergias de ítems a medida que el jugador las descubre en sus partidas.

### 18.3 Tablón de Cazarrecompensas (Bounty Board)
En cada expedición se activan 2 contratos secundarios con recompensas inmediatas:
* *Contrato 1: "El Cerco Maestro"*: Destruye 4 enemigos mediante el *Constrictor Loop* en una sola run (Recompensa: +30$).
* *Contrato 2: "Rápido y Furioso"*: Supera 3 salas consecutivas manteniendo un combo ≥ x3 (Recompensa: Cofre de ítems).
* *Contrato 3: "Pacifista Táctico"*: Completa una sala de tipo Arena sin usar bombas ni escudo (Recompensa: +50$).

## 19. Room Modifiers, Curses & Blessings (Maldiciones y Bendiciones de Sala)

| # | Modificador | Tipo | Regla Mecánica | Impacto Jugable |
|---|---|:---:|---|---|
| **61** | **Sala de Gravedad Cero** | Entorno | La serpiente mantiene su inercia de avance sin fricción; solo altera su rumbo al pulsar un nuevo giro. | Sensación de deslizamiento espacial / reflejos rápidos. |
| **62** | **Maldición de Midas Avaro**| Maldición | Todas las frutas otorgan +2 monedas extra, pero cada segundo en la sala descuenta -1 punto de la puntuación. | Empuja a resolver la sala con máxima velocidad. |
| **63** | **Bendición de la Pluma** | Bendición | La masa del cuerpo no penaliza la inercia de giro; responde con la agilidad de 3 segmentos. | Alivio absoluto para salas con colas muy largas. |
| **64** | **Sala del Velo Silencioso**| Desafío | El uso de ítems activos de inventario queda sellado; superarla otorga el doble de monedas. | Prueba de habilidad pura sin ayudas de inventario. |
| **65** | **Sombra Acechante** | Maldición | Un espectro invulnerable avanza a velocidad lenta persiguiendo a la serpiente durante toda la etapa. | Elimina cualquier posibilidad de juego pasivo o campeo. |
| **66** | **Desafío Contrarreloj** | Desafío | Temporizador de 10.0s; si se cumple el objetivo a tiempo otorga un ítem pasivo legendario gratis. | Tensión frenética y recompensa de alto valor. |
| **67** | **Bendición del Fénix** | Bendición | Si la serpiente muere en la etapa, revive 1 vez gratis con 3 segmentos y 3s de invulnerabilidad. | Red de seguridad para runs de racha alta. |
| **68** | **Visión de Túnel** | Maldición | Máscara de oscuridad que cubre todo el mapa excepto un radio de 5 celdas de la cabeza. | Juego tenso de memoria espacial y reflejos. |
| **69** | **Sala de la Dualidad** | Entorno | Todos los spawns de enemigos y frutas se generan en pares simétricos duplicados. | Gran densidad de amenazas y abundancia de recursos. |
| **70** | **Pacto del Titán** | Pacto | Cuerpo ocupa grosor de 1.5x, pero cada fruta ingerida suma +50 puntos base. | Riesgo extremo de colisión a cambio de récords masivos. |

## 20. Visual Style & Rendering Evolution (100 Propuestas de Arte y Renderizado)

### 20.1 Iluminación Dinámica & Sombras 2D (1–10)
1. **Foco Cónico Frontal**: La cabeza proyecta un cono de luz suave que ilumina baldosas y paredes en tiempo real.
2. **Sombra Arrojada 2D (Drop Shadows)**: Sombras proyectadas con ángulo de $45^\circ$ bajo la serpiente, enemigos y rocas.
3. **Oclusión Ambiental en Esquinas**: Sombreado de contacto oscuro en los vértices donde los muros tocan el piso.
4. **Resplandor de Antorchas de Pared**: Puntos de luz oscilantes con gradiente senoidal cálido en las antorchas fijas.
5. **Glow Emisivo por Color de Ítem**: Los ítems activos proyectan una corona de luz de su color temático en el suelo.
6. **Luz Reactiva al Combo**: El brillo global de la mazmorra se satura y gana contraste conforme sube el combo ($x1 \to x5$).
7. **Normal Mapping Simulado en Baldosas**: Iluminación biselada que reacciona a la posición de la cabeza para dar relieve a las losetas.
8. **Sombras de Contacto entre Segmentos**: Micro-sombra en la unión entre vértebras para enfatizar la superposición.
9. **Atenuación Cuadrática de Luz**: Caída de luz realista en salas oscuras tipo niebla de mazmorra.
10. **Flash Estroboscópico en Explosiones**: Pulso de sobreexposición blanca de 1 frame al detonar bombas.

### 20.2 Texturizado Procedural de Mazmorra & Biomas (11–20)
11. **Variación de Baldosas con Autotiling**: 4 variantes de losetas de suelo mezcladas con ruido hash para evitar monotonía.
12. **Grietas y Desgaste Procedural**: Líneas de fractura de 1 px generadas dinámicamente en paredes y rocas.
13. **Manchas de Humedad y Moho**: Decals verdes/marrones tenues en las esquinas inferiores de las Catacumbas.
14. **Escarcha Cristalina en Bordes**: Cristales de hielo procedurales en las paredes de la Cripta Helada.
15. **Vetas de Magma Pulsante**: Líneas de lava animadas entre losetas en la Caverna Volcánica.
16. **Membranas Orgánicas**: Texturas carnosas y pegajosas en las paredes de la Colmena Tóxica.
17. **Bordes Cósmicos de Vacío**: Degradado de nebulosa púrpura en los límites del Santuario del Vacío.
18. **Relieves Rúnicos en el Suelo**: Glifos antiguos grabados en baldosas centrales de salas de tesoro.
19. **Biselado de Muros Exteriores**: Efecto 2.5D en los muros perimetrales con cara superior iluminada y frontal sombreada.
20. **Rejillas de Desagüe Decorativas**: Baldosas con rejillas metálicas que emiten vapor sutil.

### 20.3 Post-Procesado & Shaders GLSL (21–30)
21. **Aberración Cromática Dinámica**: Separación de canales RGB en los bordes de la pantalla proporcional al temblor.
22. **CRT Scanlines Curvadas**: Simulación de pantalla convexa arcade con líneas de fósforo entrelazadas.
23. **Bloom Selectivo con Threshold**: Resplandor restringido a elementos con brillo $>0.8$ (frutas, ojos, láseres).
24. **Efecto de Lente Ojo de Pez Sutil**: Ligera distorsión esférica en las esquinas que acentúa la profundidad.
25. **Viñeta Adaptativa**: Oscurecimiento suave de bordes que se cierra cuando la serpiente está en peligro.
26. **Distorsión de Calor (Heat Haze)**: Ondulación senoidal sobre charcos de lava y fuego.
27. **Efecto de Película Granulada (Film Grain)**: Ruido analógico dinámico de baja opacidad para textura retro.
28. **Shader de Paleta Indexada (Color Grading)**: Remapeo de colores a paletas clásicas de 16 colores según el bioma.
29. **Refracción de Ondas de Choque**: Shader de distorsión radial en anillos tras explosiones o golpes de boss.
30. **Glitch Cromático en Daño**: Desfase de líneas horizontales durante 2 frames al recibir un impacto en el escudo.

### 20.4 Micro-Animaciones & Cinemática de la Serpiente (31–40)
31. **Ondulación Metamérica Suave**: Movimiento senoidal lateral en las esquinas del cuerpo al doblar.
32. **Deformación Squish & Stretch**: Estiramiento al acelerar y compresión elástica al frenar en *Held-Key*.
33. **Ojos con Seguimiento de Objetivos**: Los ojos de la cabeza miran hacia la fruta más cercana.
34. **Parpadeo Ocular Espontáneo**: Animación de parpadeo cada 4–6 segundos cuando la serpiente está quieta.
35. **Apertura de Mandíbula al Acercarse**: La boca se abre 1 celda antes de comer la fruta.
36. **Onda de Digestión Visible**: Un bulto viaja desde la cabeza hasta la punta de la cola al tragar comida.
37. **Inclinación de Cabeza en Curvas (Bank Angle)**: Rotación ligera de la cabeza en giros de 90°.
38. **Disolución de Segmentos al Morir**: Los bloques caen con física de gravedad individual al despiezarse.
39. **Punta de Cola con Terminación Estilizada**: Segmento final con forma cónica o aguijón decorativo.
40. **Vibración de Tensión en Parada**: Micro-temblor de 1 px en la cabeza cuando un enemigo está a distancia 1.

### 20.5 Legibilidad de Enemigos & Telegrafiado (41–50)
41. **Líneas de Visión de Chasers**: Conos tenues de color rojo que indican hacia dónde están mirando los cazadores.
42. **Patrulleros con Rastro de Ruta**: Puntos de luz tenues sobre las baldosas que muestran el camino predeterminado.
43. **Spawners con Núcleo Pulsante**: El orbe central del spawner se hincha conforme se acerca el momento del spawn.
44. **Flash de Telegrafiado con Barrido**: Los marcadores de ataque del Boss se llenan de color desde el centro hacia afuera.
45. **Contorno de Alerta de Proximidad**: Los enemigos a menos de 2 casillas ganan un borde pulsante de alto contraste.
46. **Animación de Anticipación de Salto**: El Mini-Jefe se agacha 0.3s antes de embestir.
47. **Indicador de Vulnerabilidad de Jefes**: El borde del Mini-Jefe cambia a dorado cuando está en estado de aturdimiento.
48. **Efecto de Desvanecimiento Espectral**: Los Phase Stalkers se vuelven traslúcidos y ondulan al cruzar muros.
49. **Proyectiles con Cola de Cometa**: Balas del Boss con estela luminosa de 3 partículas que marcan su trayectoria.
50. **Sombras de Caída de Ataques Balísticos**: Círculos crecientes en el suelo para ataques de mortero aéreo.

### 20.6 Partículas, Fluidos & Combate (51–60)
51. **Salpicaduras de Monedas al Matar**: Monedas que saltan en arcos parabólicos con física de rebote en el suelo.
52. **Chispas Metálicas en Golpes de Armadura**: Estallido de esquirlas doradas con fricción al bloquear daño.
53. **Humo Volumétrico en Derrapes**: Pequeñas nubes redondas que se disipan lentamente en giros cerrados.
54. **Burbujas en Charcos de Slime**: Micro-burbujas que nacen y revientan en baldosas venenosas.
55. **Brasas Flotantes en Bioma Volcánico**: Partículas de fuego que ascienden suavemente por la pantalla.
56. **Polvo de Piedra al Destruir Muros**: Fragmentos angulares que rebotan y dejan marcas temporales.
57. **Onda Expansiva Anisotrópica en Bombas**: Shockwave de plasma elíptica que se adapta al espacio de la sala.
58. **Gotas de Sangre Pixelada en Autotomía**: Gotas que quedan fijas en las baldosas donde se cortó la cola.
59. **Estelas de Turbo con Desvanecimiento Fósforo**: Líneas persistentes de luz que se disuelven en gradiente.
60. **Partículas de Hielo al Romper Criostasis**: Esquirlas transparentes que estallan en 8 direcciones.

### 20.7 UI, HUD & Tipografía Pixel-Art (61–70)
61. **Contador de Combo con Shake Dinámico**: El texto del combo aumenta de escala y vibra según el multiplicador.
62. **Barra de Boss con Cristales de Vida**: Segmentada en gemas individuales que se rompen al recolectar comida.
63. **Iconos de Ítems Animados en Slots**: Los ítems activos flotan suavemente con bobbing senoidal en sus casillas.
64. **Toasts con Despliegue de Pergamino**: Notificaciones que se desenrollan como pergaminos medievales.
65. **Bordes de HUD con Estilo de Piedra Cincelada**: Marcos de interfaz labrados con runas doradas en las esquinas.
66. **Tipografía con Sombra Proyectada de 1 px**: Doble pase de texto con offset negro para máxima legibilidad.
67. **Números Flotantes de Puntos (Score Popups)**: Cifras de `+100` y `+2$` que ascienden y se desvanecen con aceleración.
68. **Minimapa con Iconos Diferenciados**: Iconos pixel-art para tienda, jefe, élite y tesoro en el radar.
69. **Cursor de Ratón con Brillo Reactivo**: El puntero destella al pasar sobre botones interactivos.
70. **Indicador de Racha con Llamas Animadas**: El fuego del multiplicador de racha crece en el HUD al subir de nivel.

### 20.8 Atmósfera, Clima & Fondos (71–80)
71. **Niebla Ambiental Volumétrica en Capas**: Capas de niebla lenta desplazándose a diferentes velocidades (Parallax).
72. **Lluvia de Cenizas en Cavernas**: Partículas oscuras cayendo en diagonal con turbulencia suave.
73. **Goteras de Techo con Ondas en Suelo**: Gotas ocasionales que caen del techo y generan ondas circulares en charcos.
74. **Rayos de Luz Divina (God Rays)**: Haces de luz que atraviesan grietas en el techo en salas de santuario.
75. **Telarañas Decorativas en Esquinas**: Sprites de telarañas semitransparentes en salas de mazmorra antigua.
76. **Polvo en Suspensión (Dust Motes)**: Micro-partículas doradas flotando lentamente en salas iluminadas.
77. **Parallax Sutil en el Fondo de Abismo**: Profundidad visual bajo las baldosas rotas del Santuario del Vacío.
78. **Efecto de Calor en Charcos de Lava**: Resplandor ondulante que tiñe los pies de los muros cercanos.
79. **Cristales con Resonancia Lumínica**: Geodas en las paredes que parpadean al ritmo de la música.
80. **Siluetas de Criaturas en la Oscuridad**: Ojos que brillan temporalmente en los bordes negros fuera de la sala.

### 20.9 Cinemática, Muerte & Celebración (81–90)
81. **Fade-Out con Patrón de Cuadrícula (Dither Wipe)**: Transición entre salas disolviendo los píxeles en damero.
82. **Despiece en Cámara Lenta al Morir**: Desintegración progresiva segmento a segmento con estela dorada.
83. **Efecto de Descompresión en Victoria**: Explosión de confetti pixel-art y monedas doradas al vencer al Boss.
84. **Zoom Dramático en Golpe de Gracia**: Micro-zoom de cámara al recolectar la última fruta del Boss.
85. **Efecto de Tinta Expansiva en Game Over**: Mancha negra que cubre la pantalla desde el punto del impacto fatal.
86. **Entrada en Escena con Caída de Techo**: La serpiente cae del techo al iniciar cada nueva etapa.
87. **Puertas de Mazmorra con Apertura Mecánica**: Barrotes que se levantan con sonido de cadenas al cumplir el objetivo.
88. **Destello Estelar en Nuevos Récords**: Explosión de rayos dorados detrás del trofeo de High Score.
89. **Cámara Lenta en Esquivas Extremas (Near-Miss)**: Ralentización de 0.05s cuando pasas a 1 px de un proyectil mortal.
90. **Tarjeta de Fin de Run con Estilo de Tapiz**: Fondo de pergamino con el mapa recorrido y estadísticas ilustradas.

### 20.10 Coleccionables, Cartas de Tarot & Tienda (91–100)
91. **Cartas de Tarot con Efecto Holográfico**: Brillo arcoíris que se desplaza sobre las cartas al pasar el ratón.
92. **Frutas Especiales con Halos de Energía**: Auras de fuego, hielo o constricción orbitando alrededor de la fruta.
93. **Monedas con Giro Tridimensional Falso**: Animación de 4 frames simulando rotación sobre el eje vertical.
94. **Vendedor de la Tienda con Ojos Animados**: Tendero encapuchado que sigue a la serpiente con la mirada.
95. **Estanterías de Tienda Iluminadas**: Focos individuales sobre cada uno de los 4 ítems en venta.
96. **Cofres de Tesoro con Apertura y Resplandor**: Tapa que se abre revelando un cono de luz dorada ascendente.
97. **Gemas con Refracción de Luz**: Diamantes que emiten destellos en cruz de 4 puntas periódicamente.
98. **Sellos de Cera Rotos en Cartas**: Animación de fractura del sello de cera al elegir una carta de tarot.
99. **Efecto de Compra con Absorción de Monedas**: Monedas que vuelan físicamente desde el HUD hacia el tendero.
100. **Bolsas de Botín con Física de Rebote**: Sacos de monedas que se deforman elásticamente al caer al suelo.

## 21. Experiencia, Variedad, Meta y Arquitectura (80 Propuestas del Socio Técnico)

Conjunto de 4 bloques × 20 propuestas para evolución del juego. Marcador: **[NUEVA]** = sin análogo previo; **[solapa → ref]** = reutiliza/refina especificación existente conservando la fuente canónica.

### 21.1 Bloque 1: Feedback & Game Feel (1–20)
1. **Causa de muerte explícita** — Icono + texto del agente letal (proyectil, chaser, cola propia, obstáculo, boss) en la pantalla de muerte; se registra en el perfil. **[NUEVA]**
2. **Replay en cámara lenta al morir** — 0.4s previos en slow-mo con retícula sobre el origen del daño antes del modal de muerte. **[solapa → §20 #82]**
3. **Indicador de amenaza en bordes** — Flechas pulsantes en el marco de pantalla cuando hay enemigos/proyectiles ≤3 celdas fuera del viewport. **[NUEVA]**
4. **Escala de amenaza por color** — Anillo verde→amarillo→rojo alrededor de enemigos según tiempo real restante hasta contacto letal. **[solapa → §20 #45]**
5. **Pitch ascendente en combo** — El SFX de la racha sube de tono por nivel (x2, x3…) con un tick único por nivel ganado. **[NUEVA]**
6. **Temblor de proximidad del boss** — Mover sutilmente fondo/HUD antes de cada ataque, con patrón distinto por ataque (telegraph físico que refuerza el visual). **[solapa → §20 #21]**
7. **Flash de comidas activas** — Las comidas con efecto (bomba, reloj de arena…) parpadean con su color de estado para no confundirse con las normales. **[solapa → §20 #92]**
8. **HUD de defensas segmentado** — Ranuras por escudo/armadura/ghost que se rompen con chip sonoro por punto perdido, en vez de barra. **[NUEVA]**
9. **Score popups con easing por valor** — Aceleración distinta según monto (bronce=lineal, oro=arco) para legibilidad a alta velocidad. **[solapa → §20 #67]**
10. **Ghost frame con cuenta atrás radial** — Tras revivir, halo de intangibilidad con reloj radial en la cabeza marcando la duración restante. **[solapa → §2.4]**
11. **Preview de Autotomy** — Línea punteada desde la cola al punto de desprendimiento (si el tile está libre), para decidir informado. **[NUEVA]**
12. **Acorde de muertes en cadena** — En Constrictor, un acorde por enemigo encerrado (nota única→acorde completo al quinto), audible progresión. **[NUEVA]**
13. **Timer de racha visible** — Reloj descendente + anillo en el HUD para el contador de racha (además del "xN" actual). **[NUEVA]**
14. **Campana de última defensa** — Al agotarse la última protección, un golpe de campana + borde rojo; aviso de estado vulnerable. **[NUEVA]**
15. **Distinción visual de estados defensivos** — Trazo/color distinto por escudo, armadura y ghost para leer inmunidad de un vistazo. **[NUEVA]**
16. **Hundimiento de tiles de presión** — Al pisar/ver una baldosa trampa, se hunde sutilmente para recordar su posición. **[NUEVA]**
17. **Barra de botín del boss con pulso** — El progreso de comidas del boss late al estar a 2–3 del objetivo y emite un tick SFX por comida. **[NUEVA]**
18. **Zoom-out breve en jefes/minis** — 0.5s de encuadre al aparecer la arena de jefe (sin dolly permanente). **[solapa → §20 #84]**
19. **Resolución sonora/visual por sala** — Completar una sala normal vs élite vs tesoro suena y se ilumina distinto (dorado vs neutro); feedback de calidad de recompensa. **[NUEVA]**
20. **Modo "eco" de guía** — Puntero sonoro stereo hacia la comida más cercana (toggle en accesibilidad; ayuda a dificultad visual). **[NUEVA]**

### 21.2 Bloque 2: Contenido & Variedad (21–40)
21. **Templates concretos** — Cruz (4 pasillos con cámara central), Espiral (pasillos radiales), Laberinto (corredores sin abrir); +10 layouts data-driven en `dungeonGen.lua`. **[solapa → TODO + §20 #75; los 3 layouts concretos son NUEVOS]**
22. **Cofres de tributo** — Variante de tesoro con 3 cofres: 1 es trampa (libera chasers), 2 dan recompensa; reveal con icono al acercarse. **[NUEVA]**
23. **Muros vivos regenerantes** — Obstáculos que reaparecen tras N segundos, forzando rutas cambiantes por sala. **[NUEVA]**
24. **Cofre que huye** — Se aleja de la serpiente al acercarte; se abre si lo alcanzas (nueva micro-dinámica de caza). **[NUEVA]**
25. **Enemigo "mimic"** — Chaser disfrazado de comida (parpadea apenas); al comerse, explota radio 2. Frecuencia baja por etapa. **[NUEVA]**
26. **Comida "canguro"** — Salta a una celda libre adyacente cuando la serpiente está a 1 celda; recompensa mayor por esquivarla. **[NUEVA]**
27. **Orbes de purga** — Ítem de celda única que revierte un tile de presión/hielo a normal (usos por etapa). **[NUEVA]**
28. **Muros reflectores en Void** — En esa etapa los proyectiles del boss rebotan en muros hacia él, sin shield (uso táctico de geometría). **[NUEVA]**
29. **Spawner en constelación** — Liberan enemigos en patrones (línea, diamante, cuña) según etapa, no solo aleatorio. **[NUEVA]**
30. **Arena del boss final dinámica** — Tiles letales rotan cada 15s (fases de arena), obligando a reposicionamiento. **[NUEVA]**
31. **Élite gigante rara** — 1% de salas élite con enemigo de 2x2 tiles, movimiento lento + dash. **[solapa → §6.1 Encuentros Élite; el cuerpo 2x2 es NUEVO]**
32. **Interruptores de piso** — Pisar un tile abre/cierra una puerta a una mini-sala lateral de recompensa (en la misma etapa). **[NUEVA]**
33. **Frutas por bioma** — Cada bioma añade 1 fruta local (congelante en Cripta, abrasadora en Volcánica) con efecto solo en esa etapa. **[NUEVA]**
34. **Enemigo parásito** — Patroller que se adhiere a un segmento de cola a ≤4 celdas; eliminarlo requiere Constrictor/comida especial. **[NUEVA]**
35. **Salas de memoria** — Sin adversarios pero con cofres falsos; al pausar 2s aparece una réplica del boss sola variando la recompensa. **[NUEVA]**
36. **Boss alternativo en etapa 3** — Algunas runs presentan un mini-jefe aleatorio de la misma etapa en lugar del fijo (variar el encuentro obligatorio). **[NUEVA]**
37. **Objetos ambientales activables** — Palancas que modifican el layout (abren pasillo, activan trampas) con coste de combo -x, no monedas. **[NUEVA]**
38. **Comida-llave** — Dorada; al comerla abres la puerta de tesoro de esa sala. Si no la comes antes de salir, desaparece (elección táctica). **[NUEVA]**
39. **Oleadas con respiro** — Salas élite tipo "sobrevive N oleadas" con 70% más pausa entre oleadas que el spawn continuo. **[NUEVA]**
40. **Salidas duales por sala** — Al completar, elegir entre +monedas o +combo (dos puertas), personalizando cada run. **[NUEVA]**

### 21.3 Bloque 3: Meta-Persistencia-Rejugabilidad (41–60)
41. **Mejor sala por etapa** — Guardar mejor tiempo/mayor combo/menor daño por sala con gráfica de calor en el perfil. **[NUEVA]**
42. **Leaderboard local por modo** — Top 5 por modo (Rush, Boss Rush, Endless) aparte del score global, con fecha. **[solapa → §18.1 / §21.4 #71]**
43. **Historial de las últimas 20 runs** — Causa de muerte, sala, monedas, duración + export JSON (complementa el PNG de §20 #90). **[solapa → §18.1 / §21.4 #71]**
44. **Ver semilla de la run** — Botón en High Score que enseña la semilla exacta de esa run para replicarla manualmente. **[solapa → §18.1]**
45. **Prestigio de perfil** — Completar Etapa 5 al 100% desbloquea Prestigio 1: reinicia logros, añade un mutador global permanente (difícil). **[NUEVA]**
46. **Contratos semanales con skin exclusiva** — 3 contratos que acumulan pólvora hacia una skin semanal (además del Bounty Board interno). **[solapa → §18.3]**
47. **Modo "Trial de corazones"** — Cada sala consume un corazón entre salas; sin corazones mueres (economía de riesgo añadida). **[NUEVA]**
48. **Racha de etapas completadas** — Stat separada de highestStreak con gráfica en perfil (consecutivas de etapas). **[NUEVA]**
49. **Colección de runas** — Las 12 cartas de Draft obtenidas se guardan como colección "runas descubiertas" (completismo). **[NUEVA]**
50. **Bonus por clean run** — Terminar una etapa sin usar ítems activos ni recibir daño da +5% monedas en la siguiente run (caché persistente). **[NUEVA]**
51. **Skin por run** — Elegir skin al iniciar cada run (además del perfil) y registrar la skin usada en el historial. **[solapa → §12.8]**
52. **Desafíos por enemigo** — Meta-logro "caza al Stalker" (elimina X Stalkers) que desbloquea una skin de ese enemigo — contador por arquetipo. **[NUEVA]**
53. **Partida de 10 minutos** — Limitador opcional de duración; al agotarse se resuelve el mejor récord y se compara entre runs. **[NUEVA]**
54. **Torneo local hot-seat** — 2 perfiles en la misma máquina, turnos alternos con la misma seed, score acumulado por sala. **[NUEVA]**
55. **Descubrir sala → ficha en Códice** — Encontrar tipos de sala (Tesoro, Élite) desbloquea su ficha informativa en el Bestiario/Códice. **[solapa → §18.2]**
56. **highestCombo por perfil** — Persistir el pico de combo (junto a highestStreak) y mostrarlo en el menú de perfil. **[solapa → §2.4]**
57. **Apuestas opcionales post-etapa** — Continuar con -50% monedas si fallas en la siguiente sala (stakes extra). **[NUEVA]**
58. **Orden semanal de mini-jefes** — En Weekly Seed, el orden de los 5 minis rota cada semana para no volverse predecible. **[NUEVA]**
59. **Stats de inversión en tienda** — Registro de gasto por ítem y mejor retorno (monedas/combo ganados) en el perfil; datos para balance. **[NUEVA]**
60. **3 logros ocultos** — Aparecen como "??" con pista críptica (además de los 11 existentes), fomentando experimentación. **[NUEVA]**

### 21.4 Bloque 4: Arquitectura-UX-Accesibilidad (61–80)
61. **Event bus desacoplado** — Eventos tipados (death, roomCleared, itemBought) que varios sistemas suscriben; reemplaza las llamadas directas de achievements. **[NUEVA]**
62. **Timers consolidados en core/timers.lua** — Un solo gestor con tipos y prioridad, en vez de timers dispersos por módulo. **[NUEVA]**
63. **Presets de dificultad** — Relajado/Normal/Intenso que ajustan spawn counts sin tocar la arquitectura de datos. **[NUEVA]**
64. **Escalado de UI por resolución** — Fuentes/HUD adaptativos a tamaño de ventana, con percentiles en config. **[NUEVA]**
65. **Perfilado en runtime (Tab)** — Solapa de ms por sistema (movimiento, IA, render, shaders) con target 60fps en el debug menu. **[solapa → §21.4 #74]**
66. **Escritura atómica de profiles.dat** — Merge/bloqueo temporal para evitar corrupción al cerrar brusco. **[NUEVA]**
67. **Asset manager formal** — FBOs/fuentes/canvases creados una vez y compartidos (convierte la práctica actual en un módulo explícito). **[NUEVA]**
68. **Modo alto contraste** — Paleta independiente del bioma + toggle que detecta protanopia/deuteranopia. **[solapa → §20.3 #28]**
69. **Reducción de movimiento** — Toggle único que apaga screen shake, hitstop y flashes intensos (detrás de `settings.accessibility.motion`). **[NUEVA]**
70. **Tooltips instantáneos en tienda** — Al hoverear un ítem, panel con sinergias conocidas y valor real; delay configurable. **[NUEVA]**
71. **Reanudar run activa** — Persistir la run completa (incluso a mitad de sala) y retomarla al volver, no solo "última run". **[NUEVA]**
72. **Metrónomo de grid opcional** — Toggle que muestra dónde caerá el próximo paso para novatos; off por defecto. **[NUEVA]**
73. **Suíte headless de smoke tests** — Movimiento y colisiones validados sin render vía `love . --test` (lógica pura). **[solapa → TDD §10.23]**
74. **Escena de estrés fija** — Benchmark reproducible (N enemigos, proyectiles) en debug para medir regresiones de FPS. **[NUEVA]**
75. **Tweaks para jugadores avanzados** — Algunas constantes (speed, caps) editables vía settings.json con validación de rango. **[NUEVA]**
76. **Contrato de API de los 42 módulos** — Encabezado de 1 línea por función pública en cada módulo (DX). **[NUEVA]**
77. **Versionado del perfil** — `schema_version` en profiles.dat para migraciones suaves al actualizar. **[NUEVA]**
78. **i18n con fallback** — Diccionarios `locales/es.lua`, `en.lua`, `pt.lua`; fallback a inglés si falta clave. **[NUEVA]**
79. **Input centralizado** — `input.lua` que emite acciones desde teclado/ratón/gamepad/touch (prepara el gamepad del ROADMAP Fase 9). **[NUEVA]**
80. **Guía DX de extensión** — Checklist de 10 pasos + scaffolding para agregar un enemigo/ítem nuevo, en docs/. **[NUEVA]**


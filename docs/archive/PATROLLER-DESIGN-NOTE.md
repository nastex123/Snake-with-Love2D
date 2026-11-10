# Patroller (Interceptor Delta) — Nota de Diseño & Arquitectura de IA

**Fecha:** 2026-08-29  
**Estado:** Propuesta Técnica y Documentación de Diseño  
**Destino:** Módulo de IA `entities/patrollerAI.lua` y `docs/GDD.md` (Sección 3)  

---

## 1. Diagnóstico del Estado Actual

Actualmente, el Patroller vive de forma monolítica en [`entities/enemies.lua:389-434`](file:///c:/Users/Usuario/Documents/Games%20Creation/Snake-with-Love2D/entities/enemies.lua#L389-L434):

```lua
local nx = e.x + e.dirX
local ny = e.y + e.dirY
if isCellBlocked(nx, ny) then
    e.dirX = -e.dirX
    e.dirY = -e.dirY
    local rx = e.x + e.dirX
    local ry = e.y + e.dirY
    if not isCellBlocked(rx, ry) then
        e.x = rx; e.y = ry
    end
else
    e.x = nx; e.y = ny
end
```

### Problemas Detectados:
1. **Comportamiento 1D Estéril**: El dron se limita a una línea recta fija de ida y vuelta. Si choca de frente, simplemente invierte su dirección en 180°.
2. **Atascos en Laberintos y Esquinas**: Si la celda opuesta también queda bloqueada por un obstáculo o la serpiente, el dron se queda congelado (*deadlock*).
3. **Cero Conciencia Táctica del Jugador**: No reacciona a la presencia, posición ni movimiento de la serpiente. El jugador simplemente esquiva una línea recta predecible.
4. **Desaprovechamiento de la Geometría**: En salas amplias (*Arena* o *Hub*), el rebote lineal no cubre las zonas clave del mapa.
5. **Deuda Técnica de Acoplamiento**: [`entities/enemies.lua`](file:///c:/Users/Usuario/Documents/Games%20Creation/Snake-with-Love2D/entities/enemies.lua) acumula 666 líneas (por encima del límite recomendado de 500 líneas), mientras que el Chaser ya está modularizado en [`entities/chaserAI.lua`](file:///c:/Users/Usuario/Documents/Games%20Creation/Snake-with-Love2D/entities/chaserAI.lua).

---

## 2. Visión del Nuevo Patroller: "Dron Interceptor Delta"

El Patroller deja de ser un simple obstáculo móvil de rebote y pasa a ser un **dron de patrullaje militar autónomo**:
- **Metódico y predecible en su patrulla básica**, permitiendo que el jugador calcule sus tiempos de paso.
- **Letal y reactivo al entrar en su línea de visión**, activando micro-turbinas de plasma para cortar el avance de la serpiente.
- **Ágil en la navegación**, capaz de doblar esquinas a 90° para bordear salas y obstáculos sin atascarse.

---

## 3. Pilares de la Nueva Inteligencia Artificial

### Pilar A: Modos de Patrullaje Contextuales (`patrolMode`)

Al spawnear en una sala, el Patroller evalúa el tipo de sala y su posición para adoptar uno de 4 modos:

| Modo | Comportamiento | Contexto / Tipo de Sala |
| :--- | :--- | :--- |
| **`corridor_sweep`** | Recorre el eje principal del pasillo. Al topar con una pared o esquina, evalúa giros ortogonales libres a 90° para continuar por la ramificación. | Pasillos y corredores angostos (*Corridor* / *BSP branch*). |
| **`perimeter_orbit`** | Bordea el perímetro exterior o muros interiores en sentido horario o antihorario, barriendo los bordes de la sala. | Salas amplias abiertas (*Arena*, *Hub*, *Boss Room*). |
| **`diagonal_bounce`** | Rebote reflectivo tipo salvapantallas: al chocar en el eje X gira hacia el Y, y viceversa, cubriendo el mapa en zigzag. | Salas cuadradas intermedias (*Chamber*). |
| **`radar_sentry`** | Patrulla un segmento corto de 3 a 5 casillas, se detiene 0.5s escaneando con un barrido cónico de luz y gira 90° hacia el siguiente sector. | Salas de tesoro, pasajes clave o cerca de objetivos. |

---

### Pilar B: Resolución Inteligente de Esquinas (Anti-Deadlock a 90°)

Cuando la celda frontal está bloqueada (`isCellBlocked(nx, ny)`):

1. **Prioridad 1 (Giro en Esquina a 90°)**:
   - Evalúa las dos direcciones ortogonales a su vector actual: `izq = (-dirY, dirX)` y `der = (dirY, -dirX)`.
   - Si una está libre, vira hacia ella manteniendo su inercia de patrulla.
   - En modo `perimeter_orbit`, prefiere la dirección que bordea el muro más cercano.
2. **Prioridad 2 (Rebote de Retorno 180°)**:
   - Solo si ambos lados están bloqueados (un callejón sin salida o túnel de 1 celda), retrocede en 180°.
3. **Resultado**: El Patroller puede recorrer circuitos rectangulares continuos alrededor de pilares y obstáculos sin quedarse estancado.

---

### Pilar C: Línea de Visión & Embestida de Intercepción (*Line-of-Sight Dash*)

Esta es la mecánica que transforma al Patroller en una amenaza táctica activa:

1. **Detección de Intercepción (Raycast Ortogonal)**:
   - En cada paso, el dron lanza un rayo en su dirección de avance hasta una distancia máxima de `PATROLLER_LOS_RANGE = 6` celdas.
   - Si la cabeza de la serpiente entra en esa misma línea recta y **no hay muros ni obstáculos intermedios**:
2. **Fase de Telegrafiado (`alert`)**:
   - Duración: `PATROLLER_ALERT_TIME = 0.25s`.
   - El dron se frena momentáneamente; el núcleo fotónico central parpadea en blanco puro neón y emite un micro-bip de alerta.
   - Esto le da al jugador tiempo de reacción táctica (girar para esquivar o acelerar).
3. **Fase de Aceleración (`turbo_dash`)**:
   - El dron activa su propulsor de plasma: su velocidad se duplica temporalmente (`moveInterval = ENEMY_PATROLLER_SPEED * 0.5`) durante `PATROLLER_DASH_TILES = 3` celdas o hasta impactar con un obstáculo.
   - Visual: la micro-llama de plasma trasera se triplica en longitud con estela de partículas cian.
   - Cooldown: `PATROLLER_DASH_COOLDOWN = 3.0s` tras una embestida para evitar spams continuos.

---

### Pilar D: Coordinación en Parejas (Patrulla Escolta)

Cuando hay 2 Patrollers en la misma sala:
- **Ejes Opuestos o Paralelos**: Se sincronizan para cubrir carriles alternos o patrullar el perímetro en sentidos contrarios (uno horario y otro antihorario), creando compuertas dinámicas donde la serpiente debe cronometrar su cruce.
- **Evasión Mutua**: Al encontrarse de frente en un pasillo de 2 celdas, ambos viran a la derecha según su vector relativo, evitando el clásico rebote monótono.

---

### Pilar E: Seccionamiento Quirúrgico de Cola (*Guillotine Slice*)

A diferencia del Chaser (cuyo objetivo es la cabeza para muerte letal directa), el Patroller funciona como una cuchilla volante implacable que interactúa con la longitud del cuerpo de la serpiente:

1. **Zonificación del Impacto (Cabeza vs Cola)**:
   - **Segmentos 1 a 3 (Cabeza y Cuello)**: **Impacto Letal**. Consume Escudo/Armadura o provoca muerte directa de la serpiente.
   - **Segmentos 4 en adelante (Cuerpo y Cola)**: **Corte Quirúrgico**. Si el Patroller colisiona contra un segmento $\ge 4$, secciona la serpiente cortando desde ese punto exacto hasta la punta de la cola.
2. **Requisito de Longitud Mínima**:
   - La serpiente debe tener una longitud total de **al menos 5 segmentos** (`#snake.body >= 5`) para que el corte ocurra.
   - Si la serpiente mide 4 segmentos o menos, no hay suficiente masa corporal de seguridad: cualquier impacto en cualquier punto de su cuerpo es letal.
3. **Destino de los Segmentos Cortados**:
   - Los segmentos desprendidos **se desintegran instantáneamente** en un estallido cinético de chispas y partículas metálicas/cian (`particles.spawnShockwave(px, py, {0.0, 0.9, 1.0})`), reduciendo el tamaño de la serpiente de golpe.
4. **Comportamiento del Patroller al Cortar**:
   - **Corte Limpio sin Frenado**: El dron atraviesa el cuerpo a velocidad normal sin detenerse, aturdirse ni rebotar, continuando su trayectoria predeterminada como una guillotina implacable.
5. **Ventana de Gracia e Intangibilidad**:
   - Tras el corte, la serpiente restante recibe **1.0s de intangibilidad y parpadeo visual** (`invulnerableTimer = 1.0s`) para evitar que el mismo dron vuelva a dañarla en ticks consecutivos mientras termina de cruzar su carril.
6. **Penalización**:
   - **Combo**: Resetea el contador de combo actual a x1.
   - **Survival Streak**: No penaliza el multiplicador de racha de supervivencia (*Survival Streak* se mantiene intacto, premiando el haber sobrevivido a la amputación).

---

## 4. Arquitectura de Módulos (Separación de Responsabilidades)

Para mantener la estricta modularidad del proyecto (máx. 300–500 líneas por archivo):

```
┌─────────────────────────────────────────────────────────────────┐
│ entities/enemies.lua (Facade central de enemigos)               │
│  ├── chaserAI.step()    ──► entities/chaserAI.lua               │
│  ├── patrollerAI.step() ──► entities/patrollerAI.lua  [NUEVO]   │
│  └── bossAttacks.step() ──► entities/bossAttacks.lua            │
└─────────────────────────────────────────────────────────────────┘
```

### Nuevo Archivo: `entities/patrollerAI.lua`
- `patrollerAI.init(e, roomType, anchoGrilla, altoGrilla)`: Inicializa el modo de patrulla, vector y temporizadores.
- `patrollerAI.step(e, ctx)`: Ejecuta la máquina de estados del Patroller (`PATROL`, `ALERT`, `DASH`, `COOLDOWN`).
- `patrollerAI.checkLineOfSight(e, snakeHead, obstacles, gridW, gridH)`: Raycast libre en línea recta.
- `patrollerAI.resolveNextStep(e, ctx)`: Cálculo de giros a 90° vs rebote 180°.

### Conexión con `render/enemiesDraw.lua`:
- La función `drawPatroller(e, tam, time, head)` leerá `e.aiState`:
  - `alert`: Núcleo blanco intermitente a alta frecuencia.
  - `dash`: Llama de plasma alargada con chispas de propulsión.
  - `patrol`: Renderizado estándar actual del sprite `assets/patroller_delta.png`.

---

## 5. Parámetros de Balance y Configuración (`core/config.lua`)

```lua
-- Nuevas claves para la IA del Patroller
config.PATROLLER_LOS_RANGE       = 6      -- Rango máximo de detección en celdas
config.PATROLLER_ALERT_TIME      = 0.25   -- Tiempo de telegrafiado antes del dash (s)
config.PATROLLER_DASH_TILES      = 3      -- Cantidad de celdas recorridas a velocidad turbo
config.PATROLLER_DASH_SPEED_MULT = 2.0    -- Multiplicador de velocidad durante el dash
config.PATROLLER_DASH_COOLDOWN   = 3.0    -- Tiempo de recarga entre embestidas (s)
```

---

## 6. Plan de Pruebas y Validación (TDD)

1. **Tests Unitarios Headless (`tests/test_scope_20_patroller_ai.lua`)**:
   - `test_init`: Verificación de asignación de `patrolMode` según la sala.
   - `test_corner_turn`: Comprobación de que el dron gira a 90° cuando se bloquea el frente pero hay un lado libre.
   - `test_deadlock_prevention`: Comprobación de que ante 3 lados bloqueados retrocede 180° sin congelarse.
   - `test_los_detection`: Detección certera de la cabeza de la serpiente en línea recta y descarte si hay una pared en medio.
   - `test_dash_lifecycle`: Ciclo completo `PATROL -> ALERT -> DASH -> COOLDOWN -> PATROL`.
2. **Pruebas en Gameplay (`love .`)**:
   - Cero errores en `error.log`.
   - 60 FPS estables sin generación de basura en memoria (*Zero-GC* en el raycast).

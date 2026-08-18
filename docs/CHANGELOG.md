# Changelog — Snake Dungeon Crawler

All notable changes to this project will be documented here.

Format: `DD:MM:YYYY (category - HH:MM): description`

Categories: feature, fix, refactor, docs, balance, polish

---

## 17:08:2026

- **docs** (completed - 20:35): Consolidación y deduplicación exhaustiva de la documentación técnica y de diseño (`docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md`, `docs/TODO.md`):
  1. **GDD.md**: Eliminadas secciones obsoletas/redundantes §20 (Pulido Sensorial 10 ítems), §21 (Accesibilidad 10 ítems) y §22 (80 propuestas desestructuradas). Consolidadas como fuentes canónicas únicas la sección §20 (Catálogo de 100 Propuestas de Estilo Visual y Renderizado) y la sección §21 (80 Propuestas del Socio Técnico en 4 bloques estructurados con tags `[NUEVA]` y `[solapa]`), actualizando todas las referencias intra-documentales.
  2. **TDD.md**: Consolidado el pipeline de shaders y renderizado en §10.24 (Dynamic Lighting, Autotiling, Bloom Threshold, Squash/Stretch, Half-Res FBO Reflections, Voronoi Fracture) y refinado §10.23 para el motor determinista (Input Ramp-Up, AABB Pre-Filter, Fixed Timestep & Zero-GC Audit). Actualizada la tabla de arquitectura en §10.25 con referencias a GDD §21.4.
  3. **ROADMAP.md**: Unificado el bullet de estilo visual y pulido sensorial en Fase 9 y marcado como completada la tarea de curación y resolución de duplicados.
  4. **TODO.md**: Actualizado el encabezado del backlog a GDD §21 y marcado como completado el ítem de resolución de duplicados.
  Motivo: Eliminar duplicación de conceptos, inconsistencias de numeración y solapamientos, dejando un cuerpo documental limpio, coherente y unificado como fuente única de verdad.

- **docs** (completed - 20:19): Integración de 80 nuevas propuestas del socio técnico en 4 bloques (Feedback & Game Feel, Contenido & Variedad, Meta-Persistencia-Rejugabilidad, Arquitectura-UX-Accesibilidad) en `docs/GDD.md §24`, `docs/TDD.md §10.25`, `docs/ROADMAP.md Fase 9` y `docs/TODO.md`:
  1. **GDD §24 (80 propuestas)**: Cada ítem marcado `[NUEVA]` (sin análogo previo) o `[solapa → ref]` (refina especificación existente en §20–§23, TODO, ROADMAP) conservando la fuente canónica en su ubicación original — evita duplicado destructivo.
  2. **TDD §10.25**: Tabla de arquitectura para las 15 propuestas del Bloque 4 con módulo destino (core/events.lua, core/assets.lua, core/input.lua, core/i18n.lua, test/, persistence atómica, schema_version) respetando las reglas del proyecto (sin globals, módulos `local X = {}`).
  3. **ROADMAP Fase 9**: Bullet de curación de §24 (resolver duplicados, priorizar [NUEVA]) marcado como pendiente.
  4. **TODO**: Nuevo bloque `Backlog — GDD §24` con los 4 bloques referenciados + ítem de resolución de duplicados (decisión abierta).
  Nota: trabajo exclusivamente documental; no se tocó código ni `error.log`.

- **docs** (completed - 19:20): Integración del catálogo de 100 propuestas de evolución del estilo visual y pipeline de renderizado en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Iluminación Dinámica & Sombras 2D (GDD §23.1 / TDD §10.24)**: Foco cónico frontal en la cabeza, sombras arrojadas a 45° con alpha 0.35, oclusión ambiental de esquinas y normal mapping simulado en baldosas.
  2. **Texturizado Procedural & Biomas (GDD §23.2 / TDD §10.24)**: Autotiling de losetas con función hash, fracturas procedurales de 1 px, escarcha de cripta, vetas de magma y bordes de vacío cósmico.
  3. **Shaders GLSL & Post-Procesado (GDD §23.3 / TDD §10.24)**: Multi-pass Bloom con threshold $>0.8$, aberración cromática dinámica por temblor, distorsión de calor (heat haze) y scanlines CRT curvadas.
  4. **Micro-Animaciones & Fluidos de Combate (GDD §23.4-23.6)**: Ondulación metamérica de esquinas, squish & stretch en marcha/parada, eye-tracking hacia comida, bulto de digestión visible y física parabólica de rebote en monedas.
  5. **HUD de Piedra Cincelada & Atmósfera (GDD §23.7-23.10)**: Marcos rúnicos labrados, niebla volumétrica con parallax, god rays en santuarios, fractura de vidrio en Game Over y cartas holográficas de tarot.

- **docs** (completed - 19:15): Integración del paquete de 80 mejoras de ingeniería y jugabilidad categorizadas por prioridad (Bloques 1 al 4) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Bloque 1 - Crítico (GDD §22.1 / TDD §10.23)**: Input ramp-up ($0.03\text{s}$ delay inicial), corner buffering, AABB pre-filter para Ray Casting en Constrictor, ghost frame de 3s al revivir, metrónomo táctico en HUD y seguro contra aceptar muerte accidental.
  2. **Bloque 2 - Recomendado (GDD §22.2 / TDD §10.23)**: Telegrafiado cromático del Boss (4 colores), micro-stun por impacto en Mini-Jefes, tictac de audio en fruta bomba, cooldown visible de autotomía (Q), reloj de arena VHS y daño continuo de plasma.
  3. **Bloque 3 - Opcional (GDD §22.3 / TDD §10.23)**: Reflejos en FBO a mitad de resolución ($0.5\times$), temblor direccional exponencial, hitstop escalonado (30-60ms), shader de fractura Voronoi en Game Over y partículas de derrape por bioma.
  4. **Bloque 4 - Futuro (GDD §22.4 / TDD §10.23)**: Respec gratuito en el Santuario, semilla diaria universal UTC, Fixed Timestep a 60 ticks desacoplado de Hz, hot-plugging de Gamepad y suite de tests unitarios de memoria cero-allocations.

- **docs** (completed - 19:05): Rediseño del paradigma central de movimiento de la serpiente (*Held-Key Tactical Slither*) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Movimiento Táctico Sostenido (GDD §2.1)**: La serpiente solo avanza casilla a casilla mientras se mantenga presionada una tecla direccional (`WASD`/Flechas/Stick); al soltar la tecla, se detiene en su celda actual manteniendo postura de guardia mientras el mundo (enemigos, proyectiles, trampas y temporizadores) continúa corriendo en tiempo real.
  2. **Sinergia Táctica**: Permite calcular el cruce de pinchos de presión (0.5s de retardo), esquivar la jaula láser del Boss, resolver salas de puzles sin chocar contra muros y coordinar el *Constrictor Loop*.
  3. **Conmutador en Ajustes & Pipeline Técnico (TDD §10.22)**: Función `snake.isDirectionHeld()`, acumulación condicional de `stepTimer` y toggle de accesibilidad para alternar entre *Modo Táctico Sostenido* y *Modo Clásico Automático (Auto-Slither)*.

- **docs** (completed - 18:45): Integración masiva de propuestas aprobadas (Habilidades Tácticas, Frutas Dinámicas, Arsenal 51-60, Modificadores, 10 Modos de Juego, Pulido Sensorial y Suite de Accesibilidad) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Habilidades Tácticas & Frutas Dinámicas (GDD §2.4-2.5 / TDD §10.19)**: Autotomía (corte de 4 segmentos con Q), Inversión de avance (3s), Onda de cola (empuje 180°), Fruta imantada errante, Bomba de tiempo, Camaleónica, Gemelas y Diamante de racha.
  2. **Arsenal Extendido de Ítems 51 a 60 (GDD §4.3 / TDD §10.19)**: Púa de cola, Reloj de arena (rebobinado 2s), Rayo orbital, Señuelo holográfico, Botas ligeras, Diente de oro, Batería de emergencia (bullet time), Cosecha doble, Billete de lotería y Prisma refractor.
  3. **Tensión del Boss Final & Peligros (GDD §5.2-6.3 / TDD §10.20)**: Fase de furia (*Enrage* al faltar 3 comidas con +35% velocidad de ataque), Ataque de Jaula Láser y Baldosas con pinchos de presión retardados (0.5s).
  4. **Modificadores de Sala (GDD §19)**: 10 mutadores (Gravedad Cero, Midas Avaro, Pluma, Velo Silencioso, Sombra Acechante, Contrarreloj, Fénix, Visión de Túnel, Dualidad y Titán).
  5. **10 Modos de Juego Desbloqueables (GDD §11)**: Aventura, Endless, Rush, Pacifista, Boss Rush, Colosal (40x40), Micro-Snake, Semanal, Draft y Carrera Fantasma.
  6. **Pulido Sensorial & Accesibilidad (GDD §20-21 / TDD §10.21)**: Reflejos en suelo, Temblor direccional, Hitstop de 50ms, Música reactiva por capas, Shaders de daltonismo, Sliders FX, Run History (10 partidas), Reasignación de controles, Auto-pausa Alt+Tab y Vibración HD.

- **docs** (completed - 18:40): Integración del Catálogo Maestro de Variantes de Serpiente (+200 conceptos, 100 híbridos y 5 motores primitivos) en `docs/GDD.md` y `docs/TDD.md`:
  1. **Motores Primitivos de Render (GDD §12.1)**: Shard (fragmentos poligonales), Dot Matrix (grilla de círculos dithered), Wireframe (líneas vectoriales), Cadena Hexagonal y Código de Barras Dinámico.
  2. **Catálogo Maestro (GDD §12.2-12.7)**: Fichas técnicas completas con dirección, gradientes, animaciones de velocidad, estados de ítems y pulsos al comer para las 100 variantes base, 25 criaturas zoológicas, 25 materiales litológicos, 25 estructuras arquitectónicas, 25 ópticas/señales y 20 híbridos legendarios.
  3. **Motor Procedural y Registro en TDD (§10.18)**: Arquitectura de despacho por primitivas en `render/renderMain.lua`, estructura `config.SKIN_REGISTRY` y optimizaciones de memoria Zero-GC con buffers de vértices reutilizables.

- **docs** (completed - 18:35): Integración documental de los 5 pilares mayores de expansión en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Sistema de Cartas del Destino (GDD §14 / TDD §10.13)**: Draft de 3 cartas en salas 1, 2 y 4 con 12 cartas de mazo completo (El Mercurio, La Espina Dorsal, Ojo de Águila, Ladrón de Sombras, Digestión Alquímica, etc.).
  2. **Salas de Eventos Especiales (GDD §15 / TDD §10.14)**: Plantillas y mecánicas para *La Guarida del Apostador*, *La Sala de la Sombra Espejo*, *Fiebre del Oro* y *La Prueba de los Tres Sellos*.
  3. **Motor de Estados Alterados (GDD §16 / TDD §10.15)**: Gestión en tiempo real de *Frenesí (Overdrive)* por combo x6, *Petrificación (Medusa Tail)*, *Confusión (Venom Spore)* y *Criostasis*.
  4. **Árbol de Talentos del Santuario (GDD §17 / TDD §10.16)**: Meta-progresión con 8 talentos permanentes estructurados en 4 ramas (Fortuna, Alquimia, Misticismo, Combate) con costes en `totalCoins`.
  5. **Desafíos Diarios, Códice & Cazarrecompensas (GDD §18 / TDD §10.17)**: Semilla PRNG diaria determinista, Códice de Lore/Bestiario y sistema de contratos secundarios por expedición.

- **docs** (completed - 18:25): Expansión exhaustiva y monolítica de `docs/GDD.md` y `docs/TDD.md`:
  1. **Bestiario & Enemigos**: Añadidas las fichas completas de *Slime Weaver* (El Baboso, zonificación de baba ralentizante), *Phase Stalker* (Acechador Espectral, atraviesa muros) y *Mortar Sentry* (Torreta Centinela, telegrafiado balístico de 3x3).
  2. **Matriz de Sinergias de Ítems**: Documentadas 8 sinergias activas/pasivas (*Escudo Reactivo*, *Vórtice Dorado*, *Cometa Espectral*, *Hambre Voraz*, *Supernova*, *Armadura de Espejo*, *Pozo Gravitatorio*, *Sobrecarga Temporal*) y sistema de *Altares de Sangre*.
  3. **Especificación de los 5 Mini-Jefes (Sala 3)**: Diseños completos con ataques, telegrafiados y drops (*El Triturador de Muros*, *El Gólem de Escarcha*, *La Sierpe de Magma*, *La Reina Larva*, *El Espectro del Vacío*).
  4. **Modelos Matemáticos y Curvas de Balance (GDD §13)**: Fórmulas algebraicas de velocidad de serpiente, combo y puntuación, economía de monedas y escalado de IA enemiga.
  5. **Arquitectura Técnica Extendida (TDD §10.9-10.12)**: Motor de sinergias reactivo, máquina de estados de Mini-Jefes, arquitectura de *Object Pooling Zero-GC* y pipeline de shaders de biomas (hielo, magma, vacío).

- **docs** (completed - 18:30): Auditoría documental completa (sin tocar código): corrección de inconsistencias doc↔código + spec detallada de la Fase 8 y pulido general:
  1. **Correcciones GDD**: valores reales de config (Spawner `ENEMY_SPAWNER_INTERVAL` 3 / `ENEMY_DROP_SPAWNER` 1, pesos por etapa de dungeonGen), descripciones de los 12 ítems conforme a `systems/items.lua` (Hunger=+2 comidas, Bomb=destruye obstáculos, Ghost=atraviesa propio cuerpo, Star=puntos x3, etc.) con costos/duración, referencia `stageModifiers`→`world/dungeonGen.lua`, SFX reales (10, con buttonHover/buttonClick), tabla de tipos de sala con ocurrencia y detalle de Encuentros de Élite.
  2. **Sections nuevas en GDD**: `Input & Controls` (teclado completo + touch), `Economy & Food Values` (puntos NORMAL 10/1$, GOLD 25/2$, COIN 5/3$, multiplicador combo 0.5/8s, drops de enemigos, costos de progresión Fase 8).
  3. **Spec Fase 8 en GDD y TDD**: survival streak (state key, fórmula de multiplicador, caps, hooks en gamestates, highestStreak persistente), modal de muerte interactivo (Continue 30$ + 3s intangibilidad vs Aceptar -30% monedas), Constrictor Loop (algoritmo Ray Casting), 4 comidas especiales (config keys propuestas, spawn chance, interacción con food-target del boss), biomas/peligros por etapa con notas de implementación y mitigación del riesgo sin wall-wrap, encuentros élite (multiplicadores, cofre dorado, bonus de racha), modos endgame (endless/rush/pacifista con hooks en gameflow/world), skins/paletas (registro config.SKINS, desbloqueo por logro, persistencia `profile.skin`).
  4. **TDD actualizado a la realidad**: 42 módulos / ~9,275 líneas (antes 18/~7,100), árbol de carpetas y grafo de dependencias completos con los submódulos faltantes (touch, chaserAI, bossAttacks, enemyHelpers, renderMain, enemiesDraw, gamestates/gameflow/player/debugTools, settingsDraw/profilesDraw, ui/*UI), tabla de responsabilidades con 42 filas verificadas, estructura de perfil real (createdAt, monedas, highScore, achievements, unlocks, stats) + campos Fase 8 (highestStreak, skin), state keys del World ampliados con los nuevos de Fase 8.
  5. **TODO.md**: ítem de font sizes documentado tachado, pie actualizado a 17:08:2026. **AGENTS.md**: corregida la nota que afirmaba que la skill `documentation` no existía (sí existe en `.opencode/skills/documentation/SKILL.md`), arquitectura actualizada a 42 módulos + alias faltantes (settingsMod, profilesMod, playerMod, achievementsMod).

## 17:08:2026

- **docs** (completed - 17:58): Especificación y diseño completo de la Fase 8 (Evolución de Gameplay y Combate) en `docs/GDD.md`, `docs/TDD.md`, `docs/ROADMAP.md` y `docs/TODO.md`:
  1. **Paquete de Combate & Supervivencia**: Racha de supervivencia acumulativa (+0.1x por sala), modal interactivo de muerte (Revivir in situ [30$] vs Aceptar muerte [-30% monedas]), mecánica de encierro geométrico (*The Constrictor Loop*) y 4 comidas especiales (Guindilla Picante, Fruta Helada, Baya Constrictora y Baya de Poda).
  2. **Biomas y Peligros por Etapa**: Catacumbas (básico), Cripta Helada (inercia/suelo resbaladizo), Caverna Volcánica (grietas de magma cíclicas), Colmena Tóxica (suelo viscoso) y Santuario del Vacío (abismos letales / sin wall-wrap).
  3. **Encuentros de Élite**: Sala 3 de cada etapa como sala de desafío con enemigos de élite y cofre dorado garantizado.
  4. **Modos de Juego Endgame**: Desbloqueables tras vencer la Etapa 5 (Abismo Sin Fin, A Contrarreloj y Modo Pacifista).
  5. **Personalización & Skins**: 5 paletas de serpiente (Clásica, Neón, Midas, Fuego, Espectral) desbloqueables mediante logros.
  6. **Especificación Tipográfica**: Documentados los 4 tamaños oficiales de fuente (`28`, `16`, `11`, `8`) y mecanismos de fallback en `docs/TDD.md`.

- **refactor** (completed - 17:40): Split de archivos >500 líneas en facade + sub-módulos, delegando el dibujo/Generación a sub-módulos que reciben el facade por argumento (patrón de `ui/*UI.lua`):
  1. `world/world.lua` (675 → 122): facade de estado (`etapa`, `sala`, `objetivoSala`, getters) que delega a `world/dungeonGen.lua` (355, BSP + templates + stage modifiers) y `world/populate.lua` (193, población de sala).
  2. `systems/profiles.lua` (794 → 344): facade de estado/input que delega el dibujo a `systems/profilesDraw.lua` (509: select/input/confirm/achievements).
  3. `systems/settings.lua` (589 → 373): facade que expone `audio`/`graphics`/`accessibility`/`dat` para `persistence.lua` y delega el dibujo a `systems/settingsDraw.lua` (261: tabs/controls/toasts).
  - `entities/enemies.lua` (520) dejado intacto: sobrepasa el límite solo levemente y su extracción rompería el encapsulamiento de `telegraphs`/`attackObjects`/`pendingRespawns` sin beneficio real (opcional según el brief).
  - Tarea delegada a AGY CLI; verificación headless independiente (`love .` → `error.log` vacío) tras cada split.
- **fix** (completed - 17:35): Corrección de defectos introducidos en el split:
  1. `world/dungeonGen.lua`: eliminada función `world.getStageMod()` duplicada y rota que indexaba globals `world`/`stageMod` (nil) causando crash al cargar (`attempt to index global 'world' (a nil value)`).
  2. `systems/settings.lua`: reensamblado el cuerpo de `settings.close()` que había quedado partido (asignaciones de reset filtradas a nivel de módulo) y eliminada la redefinición duplicada de `settings.audio`/`graphics`/`accessibility` que pisaba el estado cargado por `open()`.

## 14:08:2026

- **fix** (completed - 22:20): Restauración completa y garantizada del audio del juego y música continua:
  - `audio/sound.lua`: Corregido el orden de decodificación en streaming (`seek` antes de `play`), evitando desincronización de buffers en OpenAL.
  - `audio/sound.lua`: Implementado el reinicio automático del bucle musical en `sound:update(dt)` cuando la pista termina o se detiene, garantizando música continua en el menú y en la partida.
  - `audio/sound.lua`: Agregados efectos de sonido procedurales `buttonHover` y `buttonClick` para interacción con la interfaz.
  - `systems/gamestates.lua`: Verificación de `not sound:isPlaying()` en cada estado para reiniciar segmentos musicales si fueron interrumpidos externamente.
  - `ui/menuUI.lua` & `main.lua`: Conectados los sonidos de feedback al pasar el ratón (`hover`) y hacer click sobre los botones del Menú Principal.
- **fix** (completed - 18:38): Corrección integral de bugs en el subsistema de sonido y música:
  - `systems/gamestates.lua`: Corregida la detección de racha musical con flanco de subida persistente (`prevComboActive`), permitiendo que la introducción del combo (`comboEnter`, 10s–17s) suene completa y transicione de forma natural al bucle `comboLoop` sin ser sobreescrita en cada tick.
  - `audio/sound.lua`: Añadidas guardas estrictas de `sound.musicEnabled` en `startSegment()`, `playSegment()` y `crossfadeTo()`, evitando que la música se reactive sola tras ser desactivada en Configuración.
  - `audio/sound.lua`: Añadida guarda de `sound.sfxEnabled` en `sound.play(name)`, permitiendo desactivar los efectos de sonido procedurales desde la interfaz de opciones.
  - `audio/sound.lua`: `sound.setMasterVolume(v)` ahora aplica `love.audio.setVolume(sound.baseVolume)`, regulando el volumen general del motor OpenAL tanto para música como para todos los efectos de sonido.
  - `audio/sound.lua`: Limpieza y detención estricta de fuentes de audio huérfanas al cancelar fundidos y cambios rápidos de segmento.
- **feature** (completed - 18:20): Cinemática inicial fluida y continua (eliminado el salto abrupto de 3.0s):
  - `ui/introUI.lua`: Ascenso continuo del diamante mediante interpolación suave con curva *Ease-Out Cubic* entre `t = 2.0s` y `t = 2.8s`, elevándose de forma orgánica desde el centro (`cy = 300px`) a la cabecera superior (`y = 108px`). Espiral convergente y destello (*flash*) sincronizados con la llegada a la cima.
  - `ui/menuUI.lua`: Revelación orgánica del título `S N A K E` naciendo del resplandor del diamante a partir de `t = 2.8s` con micro-expansión de escala (`0.92 -> 1.0`).
  - `ui/menuUI.lua`: Cascada escalonada (*staggered entrance*) de los botones de cristal y oro con micro-desplazamiento vertical hacia arriba y retardo de 0.08s por botón.
  - `render/renderMain.lua`: Renderizado del menú sincronizado a partir de `introTimer >= 2.8s`.
- **feature** (completed - 18:08): Rediseño visual del Menú Principal (*Balatro Style — Cristal & Oro*):
  - `ui/introUI.lua`: Mantenido el diamante/rombo emblemático flotando en la zona superior detrás del título con brillo pulsante y rotación mística tras la intro, limpiando las partículas secundarias de la espiral.
  - `ui/menuUI.lua`: Tipografía nítida y pura para el título `S N A K E` (eliminado el triple escalado que deformaba y duplicaba las letras). Tarjeta de High Score enmarcada en cristal oscuro translúcido con borde dorado brillante (`shimmer`).
  - `ui/menuUI.lua`: 4 botones interactivos con bordes dorados, esquinas redondeadas (`8px`), elevación suave y cursor indicador `▶` al hacer hover.
  - `ui/menuUI.lua`: Distribución y espaciado vertical corregido: garantizada una holgura limpia de más de 150px entre el botón `SALIR` y las pastillas inferiores de ayuda (`WASD / FLECHAS`, `+ / - VELOCIDAD`).
- **fix** (completed - 17:50): Corregida la fuga visual de bloom/glow y sombra durante la pantalla de transición ("SALA COMPLETADA"):
  - `render/renderMain.lua`: `drawGameGlow()` y `drawGameShadow()` ahora atenúan la emisión con `(1 - fadeAlpha)` y se cancelan por completo cuando `fadeAlpha >= 1` o durante la fase `hold`, evitando que el bloom aditivo se pinte sobre la pantalla negra.
- **feature** (completed - 17:35): Implementación completa de la IA del Chaser (Cazador Rojo) en todas sus fases:
  1. `entities/chaserAI.lua`: Detección de ocupación de slots en MANADA: al tener >=60% de slots ocupados (o 6s de espera máxima), se activa inmediatamente el cierre anticipado con fase `flash` de advertencia y posterior `dash` coordinado.
  2. `entities/chaserAI.lua`: Sistema de promoción a nuevo líder `hunter` con feedback de anillo dorado cuando el líder previo es eliminado.
  3. `world/world.lua` y `entities/enemies.lua`: Fórmula de escalado de velocidad progresiva por etapa: `intervalo = max(0.15s, (0.30 / speedMult) * 0.90^(etapa - 1))` con clamp estricto de 0.15s.
  4. `systems/gamestates.lua`: Contexto enriquecido pasando `worldMod.etapa` y `worldMod.getModifier()` a `enemiesMod.update()`.
  5. `entities/enemies.lua`: Integración en sala Boss con respawn en flancos alternados (`side = 1 / -1`) y garantía de modo DUPLA forzado por el cap `BOSS_MAX_RED = 3`.
  6. `render/enemiesDraw.lua`: Pulido visual en `drawChaser()` con aura pulsante de embestida en fase `close` y halo de promoción de líder.
  7. `docs/GDD.md`: Actualizada la sección 3 con la documentación completa de Chaser, Patroller y Spawner.
- **fix** (completed - 17:25): Corrección integral de bugs y pulido de Patrollers:
  1. `entities/enemies.lua`: Corregida la lógica de movimiento y rebote del Patroller ante colisiones frontales con muros, obstáculos, cuerpo de serpiente, otros enemigos y el Boss. Se eliminó el congelamiento y los deadlocks cara a cara.
  2. `entities/enemies.lua`: Integrada la comprobación `canSpawn()` en `enemies.generar()` para respetar estrictamente los límites de `BOSS_MAX_RED` y `BOSS_MAX_BLUE` durante el encuentro con el Boss.
  3. `entities/snake.lua`: Corregida la colisión con enemigos al morir: chocar y morir sin escudo/armadura ya no otorga monedas ni dispara logros de muerte de enemigo de forma fraudulenta.
  4. `entities/bossAttacks.lua`: Ataque `spawn_adds` ahora utiliza `enemies.spawnAt()` estandarizado con multiplicador de velocidad por etapa (`speedMult`) y dirección explícita.
  5. `world/world.lua`: Implementada detección de eje despejado (horizontal vs vertical) al spawnear patrulleros en plantillas de salas estrechas/corredores.
  6. `systems/player.lua`: Bajas de enemigos por el ítem Bomba ahora invocan correctamente `achievementsMod.check("enemyKilled")` y `coinsChanged`.
  7. `render/enemiesDraw.lua`: Rotación angular suave del Patroller basada en `visRot` y sutil pulso de energía para mejorar la legibilidad visual.
- **fix** (completed - 17:15): Auditoría integral de bugs y optimizaciones de memoria aplicada con éxito:
  1. `entities/enemies.lua`: Corregida la comprobación de colisiones de los patrulleros (patrollers) para respetar bloqueos con el cuerpo de la serpiente y obstáculos, eliminando comprobaciones duplicadas de límites de grilla.
  2. `systems/player.lua`: Corregido el efecto del ítem Hambre ("Hunger") para otorgar 2 frutas con puntos/monedas y generar una comida dorada garantizada en lugar de sobrescribir inmediatamente la variable única de comida.
  3. `systems/shop.lua`: Corregido el cálculo del índice de la tarjeta al comprar con el ratón (`purchaseFlash`), logrando que el destello verde parpadee en la tarjeta correspondiente.
  4. `systems/achievements.lua`: Añadida protección de índice no nulo (`schedIndex and not schedIndex[aid]`) al programar notificaciones diferidas de logros.
  5. `ui/hudUI.lua` y `systems/settings.lua`: Implementado caché de fuentes por tamaño (`getCachedFont` / `getFallbackFont`) eliminando la instanciación redundante de `love.graphics.newFont` en cada frame del ciclo de renderizado (60 FPS).
  6. `systems/gamestates.lua`: Eliminada la función duplicada `processToasts()` y añadido `foodMod.update(dt)` en el ciclo de actualización común.
  7. `entities/food.lua`: Separada la lógica de animación (`food.update(dt)`) del dibujo puro (`food.draw()`).
  8. `world/world.lua`: Encapsulado `mundoCompletado` a través de `coreWorld.set("mundoCompletado", false)` evitando fugas al entorno global `_G`.
- **feature** (completed - 16:45): Implementado sistema de Input Buffer (cola de hasta 2 giros) y protección anti-180° en `entities/snake.lua`. Evita colisiones accidentales al presionar teclas opuestas o giros rápidos en "L", y añade muestreo continuo de teclas mantenidas para una respuesta instantánea y fluida. `core/touch.lua` integrado con la misma cola `snake.encolarDireccion`.
- **docs** (updated - 16:45): GDD.md actualizado en la sección de movimiento con la descripción del Input Buffer y protección Anti-180°.

## 12:08:2026

- **feature** (implemented): Chaser visual propuesta 06, Estrella de espinas, con ojo rastreador, animaciones IDLE/CHASE/FLANK/ENCIRCLE/CIERRE e IA social base en `entities/chaserAI.lua`. Añadidos CRT con curvatura, flash rojo y screen shake por daño, además de bloom a media resolución.
- **docs** (created - 16:30): GDD.md seccion 3 expandida con subseccion `### Chaser (Red)`: config keys, spawn, IA greedy actual con limitaciones (ignora obstaculos/cuerpo, sesgo de orden fijo), colision, comportamiento durante boss, derrota, y diseno propuesto de IA social (SOLO predictor / DUPLA hunter+flankers / MANADA anillo+cierre 60%) con arquitectura del modulo `entities/chaserAI.lua` (buildPack + update, 4 estados), navegacion mejorada (evasion suave, tie-break shuffle, spread penalty, stuck counter), geometria de flanqueo, balance (slowdown 1.15, cap boss fuerza DUPLA) y contra-juego del jugador. TODO.md: nueva seccion "Chaser AI (design done, pending implementation)" con 7 tareas. Sin cambio de codigo.

## 08:08:2026

- **fix** (completed - 23:15): Pantalla negra al pulsar JUGAR. `render/renderMain.lua` `drawScene()` llamaba `isGameState(st)` pasando la tabla completa `world.state` en vez de `st.gameState`, por lo que en PLAYING/PAUSED/SHOP/TRANSITION ni `drawGame` ni `drawMenu` se ejecutaban y solo se pintaba el color de fondo. Correcto: `isGameState(st.gameState)`. Ademas, `love.draw()` ahora pasa `love.timer.getDelta()` a `drawScene()` (antes `dt` llegaba `nil`). Verificado: captura de pixeles del clicktest muestra la grilla renderizada en PLAYING; juego real ALIVE 9s sin error.log.
- **fix** (completed - 20:10): Al iniciar una partida desde el boton JUGAR, evita aplicar un overlay de fade negro inicial persistente; los fades de transiciones de salas se mantienen. Ademas, los canvas del postproceso se recrean tras aplicar/cambiar la resolucion para evitar una escena vacia. Verificado: juego real ALIVE 8s sin error.log.
- **fix** (completed - 22:30): `gameflow.recalcularGrilla()` ahora redondea columnas hacia abajo; `food.generar()` y `obstacles.generar()` limitan la búsqueda de celdas libres a 500 intentos y abortan de forma segura si la rejilla está llena, evitando bucles infinitos al pulsar JUGAR. `run-game.bat` conserva stdout/stderr en `error.log`.
- **refactor** (completed - 19:30): Split ui/ui.lua (818 -> 119 lines facade) into ui/introUI.lua (intro Balatro + celebracion high score + hsv2rgb), ui/menuUI.lua (drawMenu/menuMousePressed/updateMenuHover/setMenuPressed/clearMenuPressed), ui/hudUI.lua (drawGrid/drawHUD/drawSlots/drawComboFlash), ui/toastsUI.lua (show/update/draw), ui/popupsUI.lua (add/update/draw), ui/overlaysUI.lua (drawPause/drawDungeonMap/drawDebugDungeon). Facade mantiene estado (popups/toasts/_toastQueue/menuButtons/menuHoverId/menuPressedId), fuentes y accesibilidad, delega dibujo pasando `ui` como primer arg. Added `ui.resetPopups()`; `systems/gameflow.lua:58` usa `uiMod.resetPopups()`. API publica intacta (26 funciones + fuentes). Verified: real game ALIVE 8s sin error.log + smoke test 26 checks PASS (API facade + fuentes + flujo MENU->PLAYING->death->SHOP con drawScene pcall-wrapped)
- **refactor** (completed - 18:50): Split entities/enemies.lua (813 -> 482 lines) into entities/bossAttacks.lua (BOSS_ATTACKS 4 ataques + getAvailable/computePositions/execute), entities/enemyHelpers.lua (validarPos/countEnemiesByType/sampleFreeTile), render/enemiesDraw.lua (draw de enemigos/telegraphs/attackObjects/boss+health bar); public API preserved (list/boss/generar/update/killEnemy/hitBoss/getAttackObjects/onBossDefeatedByFood/spawnAt/spawnBoss/canSpawn); verified: real game ALIVE 8s no error.log + smoke test 18 checks PASS (exit 0)
- **fix** (completed - 18:20): Fixed syntax error in `core/timers.lua` that blocked module load: field `repeat` (Lua reserved word) renamed to `loops` across Timer table/acquire/update
- **refactor** (completed - 18:10): Split main.lua (1407 -> 359 lines) into `systems/player.lua` (calculateCurrentSpeed/itemColor/aplicarItem), `systems/gameflow.lua` (applyActiveProfile/resetGame/iniciarSala/recalcularGrilla), `systems/debugTools.lua` (debug menu + achievements modal), `systems/gamestates.lua` (update por estado), `render/renderMain.lua` (todo el dibujo); removed wrapper globals overlaysOpen/applyActiveProfile/debug draw wrappers; game runs with no errors (verified via automated smoke test walking MENU->PLAYING->TRANSITION->SHOP->death->HIGH_SCORE->MENU)
- **refactor** (completed - 17:30): Replaced leftover `print()` calls with `core/logger.lua`; render/shaders.lua now uses `Log.warn` for shader compile failures. No `print()` remains in the project
- **refactor** (completed - 17:15): Phase 3 migration: all gameplay globals moved to `core/world.lua` (`world.state.X`). Renamed in main.lua: puntuacion, monedas, highScore, comboCount, gameState, menuPS, celebrationTimer, debugButtons, debugAchievementModalButtons, and ~40 others. Added `local world` require to main.lua
- **refactor** (updated - 17:15): external global readers migrated: `entities/snake.lua` uses `world.get("debugImmune")` via local `immune()`; `systems/persistence.lua` `syncActiveProfile()` reads `world.get("monedas"/"highScore")`; `systems/achievements.lua` reads `world.get("pendingAchievements"/"scheduledToasts"/"scheduledIndex"/"time"/"monedas")`
- **refactor** (completed - 17:15): Verified game runs with no log errors and no global references to migrated names outside main.lua

- **feature** (completed - 16:30): Created `core/logger.lua` (Log.info/warn/error/debug) and `core/timers.lua` (timer manager with pooling, `after`/`every`/`cancel`/`clear`)
- **refactor** (completed - 16:30): Centralized config: `core/config.lua` created from constants.lua; `constants.lua` is now a shim re-exporting it; added canvasWidth/canvasHeight/tileSize standard fields
- **refactor** (updated - 16:30): main.lua loads `core.logger` and `core.timers`; `timers.update(dt)` called in `love.update()`; verified game runs with no log errors

- **docs** (updated - 16:00): SKILL.md expanded with Code Architecture Rules (ECS, no globals, pooling, data-driven, timer manager, naming) and Definition of Done (iterate until functional + check log)
- **docs** (updated - 16:00): AGENTS.md updated to apply new standards: iterate until functional, check log, apply skill rules, mark legacy globals for migration

- **refactor** (completed - 15:35): Reorganized project into 8 system folders (core/, entities/, world/, systems/, ui/, render/, audio/)
- **refactor** (updated - 15:35): Updated all require() paths across 8 files (main.lua, snake.lua, world.lua, shop.lua, persistence.lua, profiles.lua, achievements.lua, settings.lua)
- **docs** (completed - 15:30): Documentation skill created at `.opencode/skills/documentation/SKILL.md`
- **docs** (created - 15:30): GDD.md initialized with game mechanics, enemies, items, boss details
- **docs** (created - 15:30): ROADMAP.md initialized with 8 phases (Phase 1-6 completed)
- **docs** (created - 15:30): TDD.md initialized with architecture, state machine, rendering pipeline
- **docs** (created - 15:30): CHANGELOG.md initialized with format definition
- **docs** (created - 15:30): TODO.md initialized with task tracking

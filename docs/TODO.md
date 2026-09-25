# TODO — Snake Dungeon Crawler


## Completed (Base)
- [x] File reorganization into 8 system folders (08:08:2026)
- [x] Documentation system setup (08:08:2026)
- [x] Core game architecture (18 modules)
- [x] Boss implementation with 4 attacks
- [x] Shop system with 12 items
- [x] Profile system (max 3 profiles)
- [x] 11 achievements
- [x] Shader pipeline (bloom, CRT, shadow, heat)
- [x] Sound system with segmented music

**Última actualización**: 24:09:2026 (America/Bogota)  
**Estado general**: 825 tests aprobados (100% PASS), `error.log` 0 bytes, Cero-Deuda Estructural (<500L/archivo).  
**Fuente canónica de backlog unificado**: Este documento consolida el plan de sprints activos y la matriz maestra de las 100 propuestas técnicas.  
**Archivo histórico de planes y notas transitorias**: Consultar [`docs/archive/`](archive/).

---

## 1. Sprint Activo en Desarrollo

### 🔄 Sprint 2: Modo Boss Rush, Survival Waves, Eventos de Sala y Gamefeel
- [x] **Rediseño de Progresión: Survival Waves Escalation Engine (GDD §6 / TDD §10.26)**:
  - [x] Implementar campos `waveCurrent`, `waveTotal`, `waveTimer`, `waveMaxTimer` en `core/world.lua` (`World.SCHEMA`).
  - [x] Reemplazar la condición por puntaje por el control de tiempo y oleadas en `systems/gamestates/playing.lua`.
  - [x] Preservar el rol de la comida para economía, combo y habilidades especiales (sin reducción de tiempo).
  - [x] Función `populate.spawnWave` con telegrafiado seguro de 0.8s en celdas libres a distancia Manhattan >= 4.
  - [x] Adaptar la cabecera superior en `ui/hudUI.lua` con indicador de oleada (`OLEADA X/Y`) y micro-barra de tiempo.
  - [x] Añadir bonificación de "Limpieza Total" (+20$) al superar la sala eliminando todos los enemigos activos.
- [x] **Modo Boss Rush (Propuesta #47 / GDD §11)**:
  - [x] Añadir modo `"boss_rush"` a `systems/modes.lua`, soporte de desbloqueo condicional por progreso/logros y multiplicadores.
  - [x] Secuenciación de salas en `world/world.lua` y `world/populate.lua`: secuencia de 6 salas (5 mini-jefes + Boss final con tiendas intermedias).
- [x] **Motor de Eventos Aleatorios de Sala E1–E7 (GDD §22 / TDD §10.31)**:
  - [x] Crear módulo data-driven `systems/roomEvents.lua` (E1 gold_rain, E2 big_hunt, E3 merchant, E4 eclipse, E5 duel, E6 void_echo, E7 blood_offer) con probabilidad 25%, vetos en boss/élite/misterio y 1 evento por sala.
  - [x] Integración de actualización de temporizadores, badge HUD e impactos gameplay en combate.
- [x] **Gamefeel y Defensa Perceptual (Propuestas #5, #6, #7)**:
  - [x] Propuesta #5: Pulso lumínico sobre el polígono cerrado del lazo constrictor (`constrictorPulse`) en `render/renderMain.lua`.
  - [x] Propuesta #6: Capas cromáticas diferenciadas para Ghost (blanco), Armadura (azul cobalto) y Escudo (cian) en `entities/snake.lua`.
  - [x] Propuesta #7: SFX sintetizado procedural `last_defense` en `audio/sound.lua` y destello carmesí al romper la última defensa.
- [ ] **Tooltips e Indicadores de Sinergia en Tienda (Propuesta #33 / GDD §18.2)**:
  - [ ] Pre-indexar matriz de adyacencia de sinergias en `systems/codex.lua` ($O(1)$ sin generar basura en el frame loop).
  - [ ] Renderizado en `systems/shopDraw.lua` de sinergias activas o potenciales al posar el cursor sobre un ítem en venta.
- [ ] **Sierpe Volcánica (Magma Wyrm) Multi-Segmento (Propuesta #14 / GDD §5)**:
  - [ ] Modular en `entities/minibossWyrm.lua` (para mantener `entities/enemyMiniBoss.lua` <500L).
  - [ ] 6 segmentos físicos independientes con 1 HP cada uno, destruibles mediante cabezazos tácticos o bombas.
- [ ] **Motor de Eventos Aleatorios Mixtos por Bioma (GDD §19.2 / TDD §10.27)**:
  - [ ] Implementar `activeEvent`, `activeEventTimer`, `activeEventData` en `core/world.lua`.
  - [ ] Crear módulo desacoplado `systems/eventsEngine.lua` con pools Zero-GC de amenazas por bioma.
  - [ ] Diseñar telegrafiado seguro de 1.0s para los 10 eventos dinámicos en combate (E-01 a E-10) con aislamiento de salas de Boss/Mini-jefe.
  - [ ] Integrar los 10 micro-eventos de decisión táctica interactivos en pedestales rúnicos (D-01 a D-10).
- [ ] **Eventos E8–E14 riesgo-recompensa (GDD §22.3–§22.5 / TDD §10.32)**:
  - [ ] IDs `blood_roulette`, `hunter_fever`, `shadow_pact`, `cursed_chest`, `void_debt`, `split_heart`, `total_eclipse` con vetos por fase/mutador, saldo negativo E12 y bypass Fénix E14.
- [x] **Verificación y Pruebas Unitarias**:
  - [x] Crear `tests/test_scope_41_sprint2.lua` cubriendo Survival Waves, Boss Rush, Eventos E1-E7 y Gamefeel/Audio.
  - [x] 825/825 tests PASS (100%), `error.log` 0 bytes, Cero-Deuda Estructural (<500L/archivo).

---

## 2. Matriz Maestra de las 100 Propuestas de Evolución

A continuación se presenta el estado de implementación de las 100 propuestas de evolución arquitectónica y jugable.

### 2.1 Gameplay & Combate (Propuestas 1–12)
- [x] **#1 Ghost Frame con Indicador Visible**: Micro-barra segmentada sobre la cabeza con cuenta regresiva en décimas Zero-GC (`entities/snake.lua`).
- [ ] **#2 Previsualizador de Autotomía (`Q`)**: Línea punteada que proyecta la celda del señuelo antes de soltar la tecla (`entities/snake/abilities.lua`).
- [ ] **#3 Input Buffer Ramp-Up ($0.03\text{s}$)**: Filtrar micro-pulsaciones parásitas de $<0.03\text{s}$ en giros cerrados (`entities/snake/movement.lua`).
- [ ] **#4 AABB Pre-Filter en Constrictor Loop**: Caja delimitadora previa a Ray Casting poligonal en colas de >20 segmentos (`entities/snake/collisions.lua`).
- [ ] **#5 Highlight de Lazo Cerrado**: Pulso lumínico instantáneo sobre el polígono cerrado en el tick de conexión (`render/particles.lua`).
- [ ] **#6 Distinción Visual de Capas Defensivas**: Halos cromáticos diferenciados (Escudo cian, Armadura cobalto, Ghost blanco) (`render/renderMain.lua`).
- [ ] **#7 Campana de Última Defensa**: Golpe de campana sordo y flash perimetral rojo al romper la última protección (`audio/sound.lua`).
- [ ] **#8 Comida Canguro (Jumping Food)**: Fruta que salta a celda libre al acercarse la cabeza a radio 1 (`entities/food.lua`).
- [ ] **#9 Comida Mimic Sorpresa**: Fruta con 2% de probabilidad de emboscada enemiga (`entities/food.lua`).
- [ ] **#10 Frutas Especiales Autóctonas por Bioma**: Mora de Escarcha y Guindilla Magmática nativas por región (`entities/food.lua`).
- [ ] **#11 Metrónomo Táctico de Grid**: Indicador rítmico opcional en el HUD pulsando al compás de `moveInterval` (`ui/hudUI.lua`).
- [ ] **#12 Frenado Progresivo en Celdas de Baba**: Deceleración suave interpolada en lugar de salto rígido (`entities/snake/movement.lua`).

### 2.2 Enemigos & Jefes (Propuestas 13–22)
- [ ] **#13 Líneas de Visión Tenues en Chasers**: Conos tenues orientados clarificando roles Hunter y Flanker (`render/enemiesDraw.lua`).
- [ ] **#14 Wyrm Volcánico Segmentado (6 HP)**: 6 segmentos destruibles uno a uno mediante cabezazos tácticos (`entities/minibossWyrm.lua`).
- [ ] **#15 Red Pegajosa de Reina del Enjambre**: Telaraña que restringe giros a 90° durante 2.0s (`entities/enemyMiniBoss.lua`).
- [ ] **#16 Patrulleros con Rastro de Ruta Proyectada**: Nodos tenues 3 celdas por delante de la ruta de patrullaje (`render/enemiesDraw.lua`).
- [ ] **#17 Enemigo Parásito de Cola**: Dron que se acopla a la cola aumentando peso hasta ejecutar Tail Snap (`entities/enemies.lua`).
- [ ] **#18 Spawner en Constelación**: Patrones geométricos sincronizados (diamantes, murallas en L) (`entities/enemySpawnLogic.lua`).
- [ ] **#19 Arena Dinámica de Jefe Final**: Hilera perimetral electrificada cada 15s forzando combate central (`entities/enemyBossLogic.lua`).
- [ ] **#20 Boss Alternativo en Etapa 3**: Probabilidad de combate dual coordinado de dos mini-jefes (`world/dungeonGen.lua`).
- [ ] **#21 Animación de Anticipación de Salto en Minis**: Squash de 0.3s antes de embestidas pesadas (`render/enemiesDraw.lua`).
- [ ] **#22 Orbe Central Pulsante en Spawners**: Núcleo cristalino que acelera pulso previo a spawn (`render/enemiesDraw.lua`).

### 2.3 Mazmorra & Biomas (Propuestas 23–32)
- [x] **#23 Templates Cruz, Espiral y Laberinto**: 3 plantillas complejas con reglas propias (`world/wallPatterns.lua`, scope_38).
- [ ] **#24 Cofres de Tributo (Ruleta de 3)**: Sala especial con 3 cofres (1 trampa y 2 legendarios) (`systems/mystery.lua`).
- [ ] **#25 Muros Vivos Regenerantes**: Obstáculos que se regeneran tras 8 segundos (`entities/obstacles.lua`).
- [ ] **#26 Interruptores de Presión para Salas Secretas**: Baldosa oculta que abre cámara secreta (`world/biomeHazards.lua`).
- [ ] **#27 Muros Reflectores en Void Sanctuary**: Rebote especular de proyectiles en monolitos del vacío (`entities/enemyAttackRegistry.lua`).
- [ ] **#28 Salidas Duales de Sala**: Dos compuertas de salida al cumplir objetivo (recompensa vs desafío) (`systems/gameflow.lua`).
- [ ] **#29 Hundimiento Háptico de Pinchos de Presión**: Animación de descenso de losetas durante recarga (`world/biomeHazards.lua`).
- [ ] **#30 Salas Élite de Respiro por Oleadas**: 3 oleadas separadas por respiro de 2.0s (`world/populate.lua`).
- [ ] **#31 Niebla de Visión Dinámica en Túnel**: Máscara con gradiente alfa radial suave (`render/renderMain.lua`).
- [ ] **#32 Decoración Orgánica Dinámica por Bioma**: Telarañas y micro-estalactitas decorativas sin colisión (`render/renderMain.lua`).

### 2.4 Economía & Ítems (Propuestas 33–42)
- [ ] **#33 Tooltips Dinámicos con Sinergias en Tienda**: Panel flotante con recetas de sinergia en tienda (`systems/shopDraw.lua`).
- [x] **#34 Curva de Inflación y Descuentos en Tienda**: Escala de precios por etapa `SHOP_STAGE_PRICE_MULT` (scope_28).
- [ ] **#35 Animación de Monedas Voladoras al Comprar**: Partículas parabólicas desde HUD hacia vendedor (`systems/shopDraw.lua`).
- [ ] **#36 Ítem Activo: Péndulo del Tiempo**: Congela enemigos 2.0s manteniendo velocidad completa (`systems/items.lua`).
- [ ] **#37 Ítem Pasivo: Ojo de Basilisco**: Ralentiza 40% a enemigos en línea frontal de 4 casillas (`systems/items.lua`).
- [ ] **#38 Ítem Pasivo: Piel de Adamantio**: 1.0s de invulnerabilidad dorada tras romper escudo (`systems/items.lua`).
- [ ] **#39 Reroll Especial en Tienda con Token**: Consumible con oferta garantizada Tier S (`systems/shop.lua`).
- [ ] **#40 Sinergia Especial: Lazo Explosivo**: Lazo con Baya Constrictora y Bomba detona micro-explosiones (`entities/snake/collisions.lua`).
- [ ] **#41 Stats de Inversión Financiera en Perfil**: Registro de retorno en puntuación por ítem (`systems/persistence.lua`).
- [ ] **#42 Comida-Llave de Bóveda**: Fruto dorado místico que abre cámara de 3 cofres (`entities/food.lua`).

### 2.5 Meta-Progresión & Modos (Propuestas 43–52)
- [x] **#43 Árbol de Talentos del Santuario (Shrine UI)**: Pantalla interactiva en Santuario con 8 talentos (scope_34).
- [x] **#44 Mazmorra Diaria con Semilla Determinista**: Semilla YYYYMMDD y bloqueo estricto de un intento diario (scope_39).
- [x] **#45 Códice de la Serpiente y Bestiario**: Álbum de lectura con bestiario y sinergias (`systems/codex.lua`, scope_37).
- [x] **#46 Tablón de Cazarrecompensas (Bounties)**: Contratos activos por expedición con recompensas (`systems/bounty.lua`, scope_35).
- [ ] **#47 Modo de Juego: Boss Rush**: Consecución directa de los 5 mini-jefes y Boss final (`systems/modes.lua`).
- [x] **#48 Modo de Juego: Pacifista Táctico**: Modo sin daño directo con avance por evasión pura (`systems/modes.lua`, scope_36).
- [x] **#49 Modo de Juego: Abismo Sin Fin (Endless)**: Partida infinita con escalado dinámico continuo (`systems/modes.lua`, scope_36).
- [x] **#50 Catálogo de Skins de la Serpiente**: Registro Zero-GC con 4 apariencias desbloqueables por logros (`systems/skinRegistry.lua`).
- [ ] **#51 Nivel de Prestigio de Perfil**: Reinicio voluntario para cosméticos de élite (`systems/profiles.lua`).
- [ ] **#52 Historial Detallado de Últimas 20 Runs**: Resumen histórico persistente exportable a JSON (`systems/profilesDraw.lua`).

### 2.6 UI, UX & Feedback (Propuestas 53–64)
- [x] **#53 Causa de Muerte Explícita en Modal**: Icono y causa fatal exacta con número de sala (`ui/overlaysUI.lua`, scope_39).
- [ ] **#54 HUD de Defensas por Segmentos Rotos**: Placas o gemas animadas que se agrietan (`ui/hudUI.lua`).
- [ ] **#55 Indicador de Amenaza en Bordes de Pantalla**: Chevrons pulsantes advirtiendo proyectiles entrantes (`ui/hudUI.lua`).
- [ ] **#56 Contador de Combo con Shake Dinámico**: Oscilación senoidal proporcional al combo activo (`ui/hudUI.lua`).
- [ ] **#57 Score Popups con Trayectoria Parabólica**: Textos flotantes con física parabólica suave (`ui/hudUI.lua`).
- [ ] **#58 Cursor de Ratón Personalizado Reactivo**: Puntero pixel art temático con destellos interactivos (`ui/ui.lua`).
- [x] **#59 Barra de Vida de Boss Segmentada en Gemas**: Cabecera épica 8.1 con gemas y alerta de Enrage (`ui/hudUI.lua`).
- [ ] **#60 Minimapa con Iconografía Diferenciada**: Glifos exclusivos para salas élite, tiendas y jefes (`ui/overlaysUI.lua`).
- [ ] **#61 Feedback de Near-Miss (Esquiva al Límite)**: Micro-ralentización de 2 frames y chispas al rozar peligro (`systems/gamestates/playing.lua`).
- [ ] **#62 Toasts con Despliegue de Pergamino**: Notificaciones desplegables animadas estilo cyberpunk (`ui/toastsUI.lua`).
- [ ] **#63 Reloj de Racha de Supervivencia en HUD**: Medidor visual del multiplicador de supervivencia (`ui/hudUI.lua`).
- [ ] **#64 Transición de Sala por Dither Wipe**: Disolución en damero pixelado retro (`render/renderMain.lua`).

### 2.7 Renderizado & Shaders (Propuestas 65–74) — Fase 9
- [ ] **#65 Foco Cónico Frontal en la Cabeza**: Iluminación dinámica 2D orientada desde la serpiente (`render/shaders.lua`).
- [ ] **#66 Sombras Arrojadas 2D (Drop Shadows a 45°)**: Proyección diagonal bajo serpiente y enemigos (`render/renderMain.lua`).
- [ ] **#67 Bloom Selectivo con Threshold (>0.8)**: Glow restringido a fuentes de alta intensidad (`render/shaders.lua`).
- [ ] **#68 Shader de Fractura Voronoi en Game Over**: Pantalla que se resquebraja como cristal templado al morir (`render/shaders.lua`).
- [ ] **#69 Reflejos Especulares en FBO Half-Res**: Canvas a mitad de resolución para reflejos en hielo y agua (`render/shaders.lua`).
- [ ] **#70 Oclusión Ambiental en Vértices de Paredes**: Sombreado de contacto en esquinas de mazmorra (`render/renderMain.lua`).
- [ ] **#71 Aberración Cromática Dinámica en Shake**: Separación de canales RGB en impactos masivos (`render/shaders.lua`).
- [ ] **#72 Micro-Animación de Squish & Stretch**: Compresión y elongación según aceleración (`entities/snake.lua`).
- [ ] **#73 Bulto de Digestión Visible (Swallowing Bulge)**: Dilatación ondulante que recorre el cuerpo al comer (`render/renderMain.lua`).
- [ ] **#74 Distorsión Térmica en Lava (Heat Haze)**: Calor confinado estrictamente sobre los charcos de magma (`render/shaders.lua`).

### 2.8 Audio & Música (Propuestas 75–82) — Fase 9
- [ ] **#75 Capas Musicales Reactivas (Stems Dinámicos)**: Pistas instrumentales que entran según tensión y combo (`audio/sound.lua`).
- [ ] **#76 Pitch Escalonado Progresivo en Combo**: Escala musical ascendente en el SFX de comida (`audio/sound.lua`).
- [ ] **#77 Acorde Armónico en Muertes de Constrictor**: Notas simultáneas formando acorde al cerrar lazo (`audio/sound.lua`).
- [ ] **#78 Puntero Sonoro Estéreo para Comida**: Audio cue direccional de accesibilidad auditiva (`audio/sound.lua`).
- [ ] **#79 Feedback Sonoro Diferenciado por Sala**: Fanfarria de victoria según tipo de sala superada (`audio/sound.lua`).
- [ ] **#80 Filtro Paso-Bajo (Low-Pass) al Pausar**: Atenuación de frecuencias agudas en pausa o menú (`audio/sound.lua`).
- [ ] **#81 Reverberación Acústica por Bioma**: Modulación de reverberación OpenAL por bioma (`audio/sound.lua`).
- [ ] **#82 SFX Exclusivo de Armadura vs Escudo**: Impacto metálico seco vs fractura cristalina (`audio/sound.lua`).

### 2.9 Arquitectura & Deuda Técnica (Propuestas 83–90)
- [x] **#83 División de Módulo Monolítico: `playing.lua`**: Desacoplado en fachada + combat + pickups + events (<400L) (scope_18).
- [x] **#84 División de Módulo: `persistence.lua`**: Desacoplado en códec, perfiles y settings (<484L) (AUD-3).
- [x] **#85 División de Módulo: `settingsDraw.lua`**: Desacoplado en fachada + widgets + input (<320L) (AUD-3).
- [x] **#86 Migración Final de Variables Globales**: 100% de variables encapsuladas en `World.state` (AUD-1 / P04).
- [x] **#87 Contrato de API y Esquema Tipado**: `World.SCHEMA` con validación estricta de 13 campos clave (`core/world.lua`).
- [x] **#88 Consolidación de Bus de Eventos**: Sistema reactivo con `core/events.lua` para logros y persistencia (P06).
- [x] **#89 Modularización por Sistemas (Mini-ECS)**: Separación estricta de datos en World y lógica en sistemas (`systems/`).
- [x] **#90 Saneamiento de Mocks Pre-existentes**: 20 fallos históricos resueltos (752/752 PASS, hoy 811/811 PASS).

### 2.10 Accesibilidad, Controles & Packaging (Propuestas 91–100)
- [ ] **#91 Integración Nativa de Gamepad & Thumbsticks**: Mapeo completo en `core/input.lua` con zonas muertas y D-pad.
- [ ] **#92 Soporte de Vibración Háptica (Rumble)**: Vibración táctica en mandos en cabezazos y explosiones (`core/input.lua`).
- [ ] **#93 Paletas de Daltonismo**: Modos Protanopía, Deuteranopía y Tritanopía en Ajustes (`render/shaders.lua`).
- [ ] **#94 Interruptor Maestro de Reducción de Movimiento**: Conmutador para apagar shakes y distorsiones (`systems/settings.lua`).
- [ ] **#95 Reasignación Completa de Teclas (Custom Keybinds)**: Panel de configuración de teclas en pantalla (`systems/settingsDraw.lua`).
- [x] **#96 Test de Memoria Zero-Allocation (60s)**: Harness headless de 3,600 frames verificando Δ0KB (`test_scope_33_zerogc.lua`).
- [ ] **#97 Benchmark y Escena de Estrés en Menú Debug**: Escena pesada para medir frametime en consola Tab (`systems/debugTools.lua`).
- [ ] **#98 Monitor de Rendimiento en HUD**: Gráfico de frame time y memoria en esquina (`ui/hudUI.lua`).
- [ ] **#99 Integración Continua con GitHub Actions**: Workflow headless en `.github/workflows/ci.yml`.
- [ ] **#100 Generación de Builds Multiplataforma**: Scripts automatizados para empaquetar Windows, Linux y macOS.

---

## 3. Resumen Histórico de Fases Cerradas

- **Sprint 1 (Cierre de Experiencia Fase 8 — 21:09:2026)**: Causa de muerte explícita en modal, micro-barra Ghost Frame Zero-GC, catálogo de 4 skins y bloqueo diario. (811/811 PASS).
- **Review Deuda Residual (22:09:2026)**: Sincronización de mapa de objetivos en templates Cruz/Espiral/Laberinto, fallback de cabezazos a `HEADBUTT_MAX_DMG=5`, unificación de costo de revive dinámico y validación EV en tienda. (800/800 PASS).
- **Fase 8.5 — Saneamiento Estructural (31:08:2026 – 04:09:2026)**: P01 a P15 completadas. Desmonolitización de `snake.lua`, `enemies.lua`, `gamestates.lua`, pools de ataques, desacople de `World.state`, Event Bus, timers centralizados y fixed timestep a 60Hz.
- **Fases 1 a 7 (08:08:2026 – 23:08:2026)**: Arquitectura base de 18 módulos, loop de 7 estados, items y tienda, perfiles y logros, shaders básicos, intro Balatro y diseño del Menú Principal asimétrico.

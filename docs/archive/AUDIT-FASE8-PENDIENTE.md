# Auditoria Tecnica Fase 8 Pendiente: Santuario, Desafios Diarios, Endgame y Skins

## Portada

| Campo | Valor |
|---|---|
| Proyecto | Snake Love2D, Dungeon Crawler |
| Rama auditada | refactor/test-suite-and-playing-split |
| Fecha | 2026-09-20 America/Bogota |
| Tipo | Auditoria de arquitectura y riesgos |
| Alcance | Meta-Progression Shrine, Daily Challenges, Lore Codex, Bounty Board, Endgame Modes, Master Skin Catalog |
| Documentos base | GDD, TDD, ROADMAP, TODO, TECH-DEBT-PLAN, CHANGELOG, las-100-propuestas-para-revision, AGENTS.md |
| Estado de log | error.log en 0 bytes |

## Resumen

La inspeccion documental exhaustiva y la verificacion estatica del codigo confirman que los cuatro bloques pendientes de Fase 8 presentan especificacion completa en documentos y una implementacion del 0 por ciento en codigo Lua. No existe ninguna referencia funcional a santuario, talentos, semilla diaria, contratos, modos desbloqueables ni registro de skins fuera de documentos. La base actual ofrece ganchos reutilizables para persistencia atomica, bus de eventos, temporizadores centralizados y generacion con semilla parcial. La deuda estructural bloqueante se concentra en seis archivos por encima del limite de 500 lineas y en asignacion de tablas por frame en el render de la serpiente. Este informe define nueve recomendaciones categorizadas y un roadmap secuencial con definicion de hecho verificable.

> [!IMPORTANT]
> Decision vinculante previa a codificar: fijar billetera del Santuario, fijar MVP en 4 modos y 5 skins, y aislar el generador aleatorio determinista antes de implementar contenido.

> [!NOTE]
> Convencion: las rutas se citan como archivo:linea. Las tablas usan celdas multilinea para impresion sin desbordamiento.

## 1. Metodo

### 1.1 Inspeccion documental

Se leyeron linea por linea los documentos README.md, AGENTS.md, docs/GDD.md, docs/TDD.md, docs/ROADMAP.md, docs/TODO.md, docs/TECH-DEBT-PLAN.md, docs/CHANGELOG.md, docs/las-100-propuestas-para-revision.md, CHANGELOG.md y error.log. Se contrasto cada afirmacion de diseno contra busquedas estaticas en codigo.

### 1.2 Verificacion estatica

Se ejecutaron busquedas de patrones shrine, talent, heritage, daily, bounty, codex, contract, modo, endless, rush, pacifist, SKINS y profile.talents en archivos Lua. Todas retornaron cero resultados funcionales. Se midieron lineas de codigo con conteo por archivo excluyendo .git, tests y scratch. Se verificaron puntos de enganche en systems/persistence.lua, systems/gameflow.lua, world/dungeonGen.lua, core/events.lua y render/renderMain.lua.

### 1.3 Criterios de evaluacion

Integridad de datos, determinismo, complejidad temporal y espacial en notacion Big-O, impacto en memoria y recoleccion de basura, costo de renderizado, acoplamiento entre sistemas, y cumplimiento de reglas de arquitectura del proyecto.

## 2. Estado actual por bloque

### 2.1 Santuario de meta-progresion

Especificacion en docs/GDD.md seccion 17 y docs/TDD.md seccion 10.16. Ocho talentos en cuatro ramas con costo total aproximado de 4330 monedas. Efectos sobre monedas iniciales, iman residual, duracion de buffs, sexto sentido, descuento de revive, perdon de autocolision y ventana de combo.

Estado en codigo:

| Requerimiento | Evidencia | Estado |
|---|---|---|
| Campo profile.talents<br>y migracion de esquema | systems/persistence.lua:190<br>systems/persistence.lua:309<br>systems/persistence.lua:396<br>shape sin talents<br>schema_version 2 | Ausente |
| Sincronizacion de talentos<br>y evento talentsDirty | systems/persistence.lua:420<br>systems/persistence.lua:439<br>systems/persistence.lua:867<br>solo coinsChanged y unlocksDirty | Ausente |
| Interfaz Santuario<br>en menu o perfiles | ui/menuUI.lua 3 botones<br>systems/profiles.lua sin estado shrine | Ausente |
| Aplicacion de efectos<br>en reset e iniciar sala | systems/gameflow.lua:53<br>systems/gameflow.lua:71<br>magnetRange forzado a 0 | Base reutilizable<br>sin ramas Shrine |
| Costo de revive<br>parametrizado | systems/gameflow.lua:260<br>costo fijo 30 | Sin descuento<br>por Pacto Piedad |

> [!WARNING]
> Riesgo economico: stats.totalCoins se calcula como maximo historico, no como saldo gastable. Si el Santuario gasta totalCoins sin decrementar monedas se duplica valor. Si gasta monedas de run se permite farmeo por creacion y reseteo de perfiles. La billetera debe definirse antes del diseno de UI.

Colisiones funcionales detectadas:

| Talento | Punto de colision actual |
|---|---|
| Iman Residual | systems/gamestates/playing.lua recalcula magnetRange por frame desde tienda y lo pasa a snake.mover. Un talento pasivo requiere base persistente y funcion maximo entre base y tienda, no asignacion unica en resetGame. |
| Foco Cazador | systems/tarot.lua funcion comboWindow retorna 12.0 con eagle_eye o 8.0 base. Hunter 9.0 y 10.0 debe componerse con maximo o suma capada en un unico punto. |
| Estomago Dragon<br>Pociones Espesas | systems/player.lua aplicarComida y aplicarItem dispersan duraciones de fuego, hielo, slow, ghost y turbo. Se requiere envoltorio unico de duracion. |
| Cuerpo Temple | entities/snake/movement.lua resuelve autocolision como letal salvo ghost, shield o armor. Iron Body exige flag de un uso por etapa antes de shield y armor, con feedback explicito. |
| Sexto Sentido | No existe entidad puerta ni tipo de sala siguiente pre-generado. Requiere world.nextRoomType y render de icono. |

### 2.2 Desafios diarios, codice y contratos

Especificacion en docs/GDD.md secciones 18.1 a 18.3 y docs/TDD.md seccion 10.17. Mazmorra diaria con semilla ano por 10000 mas mes por 100 mas dia, un intento por perfil, mutadores del dia y tabla local. Codice con bestiario de 6 enemigos y 5 mini-jefes mas matriz de 8 sinergias. Tablon con 2 contratos por run y recompensas fijas.

Infraestructura existente:

| Capacidad | Evidencia | Utilidad |
|---|---|---|
| Generacion con semilla<br>parcial | world/dungeonGen.lua:354<br>world/dungeonGen.lua:378<br>world/dungeonGen.lua:381<br>setRandomSeed global<br>rama os.time no determinista | Gancho listo<br>pero contamina RNG global |
| Utilidades deterministas<br>desconectadas | core/helpers.lua seedRandom<br>shuffle y choice con rng inyectable | Patron a replicar<br>en 15 call-sites |
| Bus de eventos | core/events.lua on y emit<br>systems/achievements.lua check | Apto para bountyProgress<br>sin eventos nuevos |
| Persistencia atomica | systems/persistence.lua<br>atomicWrite tmp mas rename mas bak | Base para dailyHistory<br>y codex |

> [!WARNING]
> Riesgo determinismo: fijar la semilla global no produce runs diarias identicas porque populate, food, shop, mutators, mystery, particulas y sonido consumen la misma secuencia compartida en orden variable. Cualquier random adicional rompe compatibilidad de semillas. Se requiere generador aislado y orden de consumo congelado con test snapshot.

Telemetria faltante para contratos: kills por lazo constrictor, racha de salas con combo minimo, y salas pacifistas sin bomba ni escudo no emiten eventos actuales.

### 2.3 Modos endgame

Divergencia documental:

| Fuente | Alcance declarado |
|---|---|
| docs/GDD.md seccion 11 | 12 modos incluyendo Estandar<br>y Carrera Fantasma |
| docs/TDD.md seccion 10.7 | 4 modos: estandar<br>endless, rush y pacifista |
| docs/TODO.md y ROADMAP | 10 modos desbloqueables |

Estado en codigo: world/world.lua funcion avanzarSala limitada a salas del dungeon y avanzarEtapa sin rama endless. core/config.lua sin RUSH_TIME_LIMIT ni SPECIAL_FOOD_CHANCE. systems/gameflow.lua sin world.state.modo, timeLimit ni pacifist. No existe seleccion de modo en menu ni persistencia de profile.modo.

### 2.4 Catalogo maestro de skins

Especificacion en docs/GDD.md seccion 12 con 5 motores primitivos y mas de 200 variantes, y en docs/TDD.md secciones 10.8 y 10.18 con registro SKINS de 5 entradas base y dispatcher con buffers reutilizados.

Estado en codigo: render/renderMain.lua invoca snakeMod.draw tres veces por frame sin consulta a skin. entities/snake.lua implementa un unico motor de rectangulos con gradiente por tiempo y crea tablas positions y colors por segmento por frame. core/config.lua sin SKINS ni SKIN_REGISTRY. systems/settings.lua sin pestana de personalizacion con preview.

> [!IMPORTANT]
> Riesgo de memoria: la asignacion por segmento por frame multiplicada por tres pasadas de dibujo produce stutter por recoleccion de basura. En Endless infinito y arena Colosal de 40 por 40 con hordas el costo se vuelve critico. El dispatcher por referencia y los buffers preasignados son condicion previa, no optimizacion posterior.

## 3. Deuda estructural bloqueante

Medicion actual excluyendo tests y scratch:

| Archivo | Lineas | Efecto sobre Fase 8 |
|---|---|---|
| systems/persistence.lua | 874 | Sin split no hay migracion<br>segura a schema 3 |
| render/shaders.lua | 681 | Sin facade no hay glow<br>por skin ni lente void |
| systems/settingsDraw.lua | 647 | Sin split no hay tab<br>de personalizacion con preview |
| systems/player.lua | 632 | Sin split no hay ramas<br>por modo ni envoltorio de duracion |
| systems/settings.lua | 574 | Acoplado a preview<br>y persistencia |
| world/dungeonGen.lua | 530 | Sin facade no hay Endless<br>Maze ni Colosal |
| main.lua | 530 | Limite, mantener<br>fuera de logica de modos |

Archivos ya saneados en esta rama como playing.lua modularizado no aparecen en el top y no deben reabrirse.

## 4. Evaluacion de alternativas

### 4.1 Determinismo para semilla diaria

| Alternativa | Tiempo | Espacio | Memoria | Costo | Recomendacion |
|---|---|---|---|---|---|
| A. Semilla global<br>con setRandomSeed | O(1) por llamada<br>O(n) divergencia<br>en n llamadas | O(1) | Nula adicional<br>pero secuencia compartida | Bajo e impredecible | Descartar<br>para Daily |
| B. Generador aislado<br>por subsistema | O(1) por sorteo<br>O(n) determinista<br>en n sorteos | O(k) generadores<br>k subsistemas | Constante pequena<br>sin GC por frame | Medio<br>refactor 15 call-sites | Adoptar<br>para juego |
| C. LCG propio<br>con rng threaded | O(1) por sorteo<br>O(n) determinista | O(1) estado | Minima<br>testeable sin Love2D | Medio<br>congelar orden | Adoptar<br>para tests snapshot |

### 4.2 Render de skins

| Alternativa | Tiempo | Espacio | Memoria | Costo render | Recomendacion |
|---|---|---|---|---|---|
| A. Cadena if por skin<br>en draw | O(s) ramas<br>por segmento<br>s skins | O(1) | Tablas por frame<br>GC churn | Alto<br>insostenible en 200 | Descartar |
| B. Registro estatico<br>mas dispatcher | O(1) dispatch<br>O(n) en n segmentos | O(s) defs<br>estaticas | Buffers preasignados<br>Zero-GC | Bajo<br>constante | Adoptar<br>MVP y escala |
| C. Variante shader<br>por skin | O(1) uniforme<br>O(n) GPU | O(m) shaders | VRAM adicional<br>recompilacion | Medio alto<br>riesgo en shaders 681L | Futuro<br>tras split |

### 4.3 Migracion de persistencia

| Alternativa | Tiempo | Espacio | Memoria | Riesgo | Recomendacion |
|---|---|---|---|---|---|
| A. Campos sin versionar | O(1) | O(1) | Nula | Corrupcion<br>de dat antiguos | Rechazar |
| B. schema 2 a 3<br>con defaults | O(p) perfiles<br>p menor o igual a 3 | O(1) | Despreciable | Bajo<br>con bak | Requerido |
| C. Split persistence<br>mas profileSchema | O(p) mas refactor | O(1) | Despreciable | Medio<br>desbloquea Fase 8 | Requerido<br>antes de Shrine |

## 5. Recomendaciones

### Critico

**CRITICO-1. Migracion schema_version 3.** Anadir talents de 8 entradas, codex, bounties, dailyHistory, modo y skin con valores por defecto. Migrar perfiles antiguos sin borrar unlocks, stats ni achievements. Extender World.SCHEMA y validate. Anadir syncTalents y evento talentsDirty junto a syncUnlocks. Validar tipos antes de atomicWrite.

**CRITICO-2. Aislamiento RNG determinista.** Introducir generador aislado para dungeon, populate, shop, mutators, mystery y food. Implementar getDailySeed por hash de fecha con semilla visible. Congelar orden de consumo aleatorio. Anadir test snapshot de mazmorra con semilla fija. Documentar que ningun sistema nuevo puede llamar random global directo.

**CRITICO-3. Desmonolitizar bloqueantes antes de contenido.** Dividir persistence, settingsDraw, player, shaders y dungeonGen en fachada mas submodulos bajo 500 lineas. Crear systems/shrine.lua mas shrineDraw mas shrineDefs, systems/daily.lua, systems/bounty.lua, systems/codex.lua, systems/modes.lua y systems/skinRegistry.lua desde el inicio.

**CRITICO-4. Eliminar asignacion por frame en serpiente.** Reemplazar positions y colors por buffers de modulo reutilizados e interpolacion RGB sin tablas. Unificar triple pasada de renderMain en datos compartidos. Anadir test de cero asignacion en 3600 frames.

### Recomendado

**RECOMENDADO-5. Santuario MVP data-driven.** Tabla de 8 talentos con costo, rangos y hook. Definir billetera unica gastable y costo total frente a ingresos de 1 a 3 monedas por fruta. Centralizar shrine.reviveCost, shrine.comboWindow y shrine.magnetBase para componer con tarot y tienda sin suplantar. Interfaz como cuarto acceso o pestana de perfiles con layout existente preservado.

**RECOMENDADO-6. Motor de contratos por eventos.** Definir BOUNTY_POOL con Cerco Maestro, Rapido y Furioso y Pacifista Tactico. Guardar 2 contratos activos en world.state.bounties. Emitir bountyProgress desde combate, pickups y player. Pagar en monedas directas con popup dorado trazable.

**RECOMENDADO-7. Endgame MVP de 4 modos.** Implementar estandar, endless sin tope en sala 5 de etapa 5, rush con limite 180 y multiplicador triple, y pacifista sin bomba con kills neutros. Diferir Boss Rush, Colosal, Micro, Semanal, Draft, Sudden Death, Maze y Fantasma hasta validar balance del MVP.

### Opcional

**OPCIONAL-8. Codice album MVP.** Registro de bestiario y sinergias, estado profile.codex, hooks de avistamiento en player, miniBoss, items y tarot, y vista de solo lectura en perfiles. Bajo riesgo y alto valor de coleccion.

### Futuro

**FUTURO-9. Escala completa.** Catalogo de 200 skins con dispatcher, 12 modos, tabla diaria local con semilla visible, semilla semanal con 3 mutadores rotativos, y tooltips de tienda con sinergias. Solo tras definicion de hecho de CRITICO-1 a CRITICO-4 y 60 FPS estables.

> [!TIP]
> Secuencia sugerida: CRITICO-1 mas CRITICO-3 en paralelo de persistencia, luego CRITICO-2, luego CRITICO-4, luego RECOMENDADO-5 y RECOMENDADO-6, luego RECOMENDADO-7, finalmente OPCIONAL-8.

## 6. Roadmap

| Fase | Entregable | Dependencias | Verificacion |
|---|---|---|---|
| 6.1 Base de datos | schema 3 mas splits<br>persistence y settings | Ninguna | Perfiles antiguos migran<br>sin perdida, tests PASS |
| 6.2 Determinismo | Generador aislado<br>mas Daily Seed | 6.1 | Misma semilla produce<br>misma mazmorra |
| 6.3 Rendimiento | Zero-GC serpiente<br>mas split shaders | 6.1 | 3600 frames sin delta<br>de memoria |
| 6.4 Santuario | 8 talentos MVP<br>mas UI | 6.1 y 6.3 | Compra, persistencia<br>y efecto verificados |
| 6.5 Contratos | 3 bounties MVP<br>por eventos | 6.2 | Progreso y pago<br>trazables |
| 6.6 Modos | 4 modos MVP | 6.2 y 6.4 | Endless, Rush y Pacifista<br>jugables |
| 6.7 Codice | Album MVP | 6.1 | Avistamientos<br>persisten |
| 6.8 Escala | 200 skins y 12 modos | 6.3 a 6.7 | 60 FPS y log limpio |

## 7. Definicion de hecho

Codigo probado con suite verde. Programa funcional con love punto sin errores. error.log en 0 bytes. Archivos bajo 500 lineas. Sin variables globales nuevas. Modulos con local y retorno. Estado en World con SCHEMA validado. Sin tablas por frame en loops de 60 FPS. Uso de logger en lugar de print. Documentacion GDD, TDD, ROADMAP, CHANGELOG y TODO sincronizada con timestamp America/Bogota. Commits atomicos con categoria feat, fix, refactor, docs, balance o polish.

## Referencias

GDD secciones 11, 12, 17 y 18. TDD secciones 10.7, 10.8 y 10.16 a 10.18. ROADMAP Fase 8. TODO bloques Meta-Progression Shrine, Daily Codex Bounties y Endgame Skins. TECH-DEBT-PLAN Fases 1 a 3. las-100-propuestas-para-revision propuestas 45, 54 y 58. AGENTS.md reglas de arquitectura y ejecucion. Archivos systems/persistence.lua, systems/gameflow.lua, world/dungeonGen.lua, core/events.lua, core/helpers.lua, entities/snake/movement.lua, systems/player.lua, systems/tarot.lua y render/renderMain.lua.

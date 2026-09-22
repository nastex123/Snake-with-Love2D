# Tarea para AGY (Antigravity) — Split de archivos >500 líneas

**Repositorio**: `Snake-with-Love2D` (Love2D 11.4+)
**Branch**: `feat/ai-behavior`
**Objetivo**: Partir los módulos que superan 500 líneas en sub-módulos cohesivos,
**sin romper el juego** y **sin alterar las APIs públicas** que consumen los demás módulos.

---

## 0. Definition of Done (OBLIGATORIO)

El trabajo NO está completo hasta que:

1. `run-game.bat` (ejecuta `"C:\Program Files\LOVE\love.exe" . > error.log 2>&1`) corre y
   **`error.log` queda VACÍO** (sin errores ni warnings nuevos). Hoy está vacío = baseline limpio.
2. El flujo completo sigue funcional: MENU → PLAYING → TRANSITION → SHOP → PLAYING,
   y muerte → HIGH_SCORE/SHOP → MENU. Verificar con el juego real (8–10s ALIVE) tras cada archivo partido.
3. No se introducen variables globales nuevas. Código nuevo usa `local X = {}` + `return X`.
4. Cero `print()` en el proyecto; usar `core/logger.lua` (`Log.info/warn/error/debug`).
5. Se preservan EXACTAMENTE los nombres de función/campo listados en la sección "API pública a preservar"
   de cada archivo, y las rutas `require(...)` que usan los consumidores.

> Regla del proyecto (AGENTS.md): "Siempre iterar hasta que el programa sea funcional: `love .`
> debe ejecutar sin errores antes de dar una tarea por completada. Siempre revisar el log en busca
> de errores tras cada cambio."

---

## 1. Archivos a partir (conteo REAL actual)

| Archivo | Líneas | Prioridad |
|---------|-------:|-----------|
| `systems/profiles.lua` | 794 | ALTA |
| `world/world.lua` | 675 | ALTA |
| `systems/settings.lua` | 589 | ALTA |
| `entities/enemies.lua` | 520 | BAJA (borderline; ver §5) |

**Orden sugerido**: `world.lua` → `profiles.lua` → `settings.lua` → `enemies.lua` (opcional).
Partir UN archivo a la vez, verificar `error.log` vacío tras cada uno, antes de seguir.

---

## 2. `world/world.lua` (675 líneas)

**Requerido por** (rutas `require("world.world")`): `main.lua`, `render/renderMain.lua`,
`systems/debugTools.lua`, `systems/gameflow.lua`, `systems/gamestates.lua`.
Alias externo: `worldMod`.

### API pública a preservar (en `world` / `worldMod`)
- `world.getStageMod()`
- `world.calcularObjetivo()`
- `world.generarMazmorra(anchoVirtual, altoVirtual, targetRooms)`
- `world.getCurrentRoom()`
- `world.getRoomCount()`
- `world.init()`
- `world.getModifier()`
- `world.esJefe()`
- `world.avanzarSala()`
- `world.avanzarEtapa()`
- `world.etapaCompletada()`
- `world.isLastRoom()`
- `world.populateRoom(snakeBody, anchoGrilla, altoGrilla, obstaclesList, foodMod, enemiesMod, obstaclesMod)`
- `world.getDungeonMapData()`
- **Campos leídos por fuera** (en `gamestates.lua`): `worldMod.etapa`, `worldMod.objetivoSala`, `worldMod.getModifier`, `worldMod.isLastRoom`, `worldMod.esJefe`. NO renombrar.

### Descomposición sugerida (criterio de cohesión)
- `world/dungeonGen.lua` → lógica BSP puramente local: `bspSplit`, `carveRoomInLeaf`,
  `corridorPath`, `selectTemplateForRoom`, `stageModifiers`/`stageMod` (modificadores de etapa),
  y `generarMazmorra` (orquesta el BSP). Expone `dungeonGen.generar(...)` o similar.
- `world/populate.lua` → población de sala: `buildAvoidList`, `samplePosition`, `reservePosition`,
  `placeNEntities`, `populateRoom`. (Estas usan `foodMod`/`enemiesMod`/`obstaclesMod` pasados como args.)
- `world/world.lua` queda como **facade**: mantiene `world` table, los campos de estado
  (`etapa`, `objetivoSala`, `currentRoom`, etc.), y delega a los sub-módulos.
- `getDungeonMapData` y los getters de sala/etapa pueden quedar en el facade.

**Trampa**: `populateRoom` recibe `foodMod`, `enemiesMod`, `obstaclesMod` por parámetro → mantener la firma.
`stageModifiers`/`stageMod` son `local` y los lee `getStageMod`/`getModifier` → si se mueven a
`dungeonGen`, exportarlos o requerirlos desde el facade.

---

## 3. `systems/profiles.lua` (794 líneas)

**Requerido por** (rutas `require("systems.profiles")`): `main.lua`, `render/renderMain.lua`,
`systems/gamestates.lua` (dentro de funciones), `systems/persistence.lua` (vía `profilesMod.*` y `persistence`).
Alias externo: `profilesMod`.

### API pública a preservar (en `profilesMod`)
- `profilesMod.open()` / `close()`
- `profilesMod.draw()`
- `profilesMod.drawSelect(w, h)`
- `profilesMod.drawInputModal()`
- `profilesMod.drawConfirmModal()`
- `profilesMod.drawAchievements()`
- `profilesMod.buttonHover(x, y, w, h, mx, my)`
- `profilesMod.mousepressed(x, y, button)`
- `profilesMod.wheelmoved(dx, dy)`
- `profilesMod.textinput(text)`
- `profilesMod.keypressed(key)`
- `profilesMod.handleSelect(index)`
- `profilesMod.handleInputConfirm()`
- `profilesMod.handleConfirmYes()`
- `profilesMod.visible` (campo booleano, leído por fuera)

### Estado local compartido (CUIDADO)
`profiles.lua` tiene estado local vivo usado por draw + input: `cardRects`, `buttonRects`,
`backBtn`, `inputRect` (y los campos de `profilesMod`). Si extraes draw a un sub-módulo
(`systems/profilesDraw.lua`), ese estado debe seguir accesible: o bien queda en el facade y se
pasa al sub-módulo vía argumento/upvalue, o el sub-módulo lo requiere. **No duplicar ni perder estos rects**.

### Descomposición sugerida
- `systems/profilesDraw.lua` → funciones puras de dibujo pesadas:
  `drawSelect` (109–317), `drawInputModal` (317–392), `drawConfirmModal` (392–442),
  `drawAchievements` (624–788). Reciben `profilesMod` (o el estado compartido) como primer arg,
  igual que el patrón de `ui/*UI.lua` que recibe `ui` como primer argumento.
- `systems/profiles.lua` queda como facade: estado + `open/close/mousepressed/textinput/keypressed/
  wheelmoved/handle*` + delega `draw*` a `profilesDraw`.
- `font(n)` (helper local) puede ir a `profilesDraw` o a un helper compartido.

**Patrón de referencia ya usado en el repo**: `ui/ui.lua` (facade 142 líneas) delega a
`ui/introUI.lua`, `ui/menuUI.lua`, `ui/hudUI.lua`, etc. Imitar ese estilo.

---

## 4. `systems/settings.lua` (589 líneas)

**Requerido por** (rutas `require("systems.settings")`): `main.lua`, `render/renderMain.lua`,
`systems/gamestates.lua` (dentro de funciones), `systems/persistence.lua`.
Alias externo: `settingsMod` (en algunos archivos aparece como `settings`).

### API pública a preservar (en `settings`)
- `settings.open()` / `close()`
- `settings.update(dt)`
- `settings.draw()`
- `settings.mousepressed(x, y, button)` / `mousereleased` / `mousemoved`
- `settings.visible` (campo)
- `settings.dat` (campo/estructura persistida)

### TABLAS DE DATOS — NO MOVER COMO TALES SIN PRESERVAR EL ACCESO
`persistence.lua` (líneas 290–316) lee **directamente**:
- `settings.audio` (tabla: `master`, `music`, `sfx`)
- `settings.graphics` (tabla)
- `settings.accessibility` (tabla)

Estas son **campos de datos** (no funciones). Tras el split, `settings.audio` / `settings.graphics` /
`settings.accessibility` deben seguir siendo tablas accesibles desde `persistence.lua`. Opción limpia:
definirlas en el facade `systems/settings.lua` (o en un `systems/settingsData.lua` que el facade
requiere y expone como campos). NO enterrarlas donde `persistence` no pueda leerlas.

### Descomposición sugerida
- `systems/settingsDraw.lua` → helpers de dibujo y pestañas: `drawCheckbox`, `drawSlider`,
  `drawDropdown`, `drawButton`, `drawAudioTab`, `drawGraphicsTab`, `drawAccessibilityTab`,
  `drawDropdownList`, `drawToast`, `setFont`, `getFallbackFont`, `showToast`, `hitTest`,
  `checkboxKeyPath`, `setNested`, `toggleCheckbox`, `panelXY`. Reciben `settings` (o estado) como arg.
- `systems/settings.lua` queda como facade: tablas `audio/graphics/accessibility/dat`, estado
  (`g` hit-areas, `editing`, etc.), `open/close/update/mouse*`, y delega el draw a `settingsDraw`.

**Trampa**: `drawAudioTab` etc. usan `editing.audio.master` y `ui['font'..size]` — el estado `editing`
y las fuentes deben seguir disponibles para el sub-módulo. Pasarlos como argumento o requerirlos.

---

## 5. `entities/enemies.lua` (520 líneas) — PRIORIDAD BAJA / OPCIONAL

Supera 500 por poco. Solo partir si hay un extracto cohesivo y limpio de ≥100 líneas.
Si no, **dejarlo intacto** y marcar la tarea como "no necesario en este paso".

**Requerido por** (rutas `require("entities.enemies")`): `main.lua`, `render/renderMain.lua`,
`systems/gameflow.lua`, `systems/gamestates.lua`, `systems/player.lua`, `entities/snake.lua`.
Alias externo: `enemiesMod`.

### API pública a preservar (en `enemies`)
- `enemies.addTelegraph(gx, gy, timer, attackType)`
- `enemies.addProjectile(gx, gy, dx, dy, lifetime, damage)`
- `enemies.addRadialPulse(cx, cy, maxRadius, speed, damage)`
- `enemies.getAttackObjects()` / `clearAttackObjects()`
- `enemies.canSpawn(type)`
- `enemies.init()`
- `enemies.spawnAt(type, gx, gy, params)`
- `enemies.generar(snake, foodPos, obstacles, anchoGrilla, altoGrilla, stageModifier)`
- `enemies.spawnBoss(etapa, anchoGrilla, altoGrilla, bossVida, dropCoins)`
- `enemies.hitBoss()`
- `enemies.onBossDefeatedByFood()`
- `enemies.update(dt, snakeBody, anchoGrilla, altoGrilla, obstaclesMod, etapa, stageModifier)`
- `enemies.killEnemy(idx)`
- `enemies.draw(snakeHead)`
- `enemies.boss` (campo), `enemies.list` (campo) — leídos por fuera (13× `enemiesMod.boss`, 3× `enemiesMod.list`)

**Ya está parcialmente dividido**: `bossAttacks.lua` y `enemyHelpers.lua` existen. Los `local`
`telegraphs`, `attackObjects`, `pendingRespawns` son estado de módulo — si se extrae algo, conservarlos.

---

## 6. Reglas duras transversales

1. **No cambiar rutas `require` de consumidores**. Los consumidores hacen
   `require("world.world")`, `require("systems.profiles")`, `require("systems.settings")`,
   `require("entities.enemies")`. El módulo original debe seguir siendo el punto de entrada
   (ahora facade) que require los sub-módulos.
2. **No globals nuevos**. `world.state` (en `core/world.lua`) sigue siendo la fuente de estado
   global del juego; los splits no deben introducir `_G.X`.
3. **Logger, no print**. Reemplazar cualquier `print` por `Log.*` (ya no queda ninguno en el repo).
4. **Preservar firmas exactas** de las funciones listadas arriba (número y orden de parámetros).
5. **Un split a la vez + verificación**. Tras cada archivo: correr `run-game.bat`, confirmar
   `error.log` vacío, y jugar ~8s para validar flujo y render.
6. **No tocar `core/world.lua`, `main.lua`, `constants.lua`** salvo que un split lo requiera
   explícitamente (no debería).
7. **No commitear** salvo que el usuario lo pida. Dejar el trabajo en el branch `feat/ai-behavior`.

---

## 7. Love2D gotchas (evitar regresiones)

- `ParticleSystem:getCount()` NO `count()`.
- `ParticleSystem:setParticleLifetime(min,max)` NO `setLifetime()`.
- `dt` NO existe en `love.draw()` — los timers van en `love.update()`.
- Fuente `PressStart2P-Regular.ttf` vía `pcall` con fallback. Sizes: 28/16/11/8.
- `nextLoopSource` (audio) debe `:stop()`'arse antes de setear a `nil` al cambiar segmento de música.

---

## 8. Verificación final

```
1. Ejecutar run-game.bat
2. Comprobar que error.log está vacío (0 bytes)
3. Jugar 8-10s: moverse, comer, morir, pasar por SHOP
4. Abrir menú de perfiles (crear/seleccionar perfil) y Settings (cambiar audio/gráficos)
5. Confirmar que no hay errores nuevos en consola ni en error.log
```

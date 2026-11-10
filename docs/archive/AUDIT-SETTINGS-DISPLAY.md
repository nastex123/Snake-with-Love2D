# Auditoría Técnica y Especificación de Corrección: Pipeline de Pantalla, Resolución, Filtros y Pixel Scale

> **Fecha de Elaboración**: 2026-09-08 (America/Bogota)  
> **Rama de Trabajo**: `docs/audit-settings-display-pipeline`  
> **Objetivo**: Diagnóstico de causas raíz y plan paso a paso para la próxima sesión para solucionar fallos en persistencia de resolución, conmutación de filtros (`nearest`/`linear`) y escala de píxeles (`pixelScale`).

---

## 1. Diagnóstico de Causas Raíz (Audit Findings)

### 1.1. Fallo de Persistencia de Resolución (Aparece a 720p en Menú pero inicia en ventana pequeña)
1. **Sobrescritura por `conf.lua` en arranque**:
   - `conf.lua` define de forma rígida `t.window.width = 800` y `t.window.height = 600`. Love2D crea la ventana en 800x600 *antes* de que cualquier código Lua o `love.load()` se ejecute.
2. **Desincronización en `love.load()`**:
   - En `main.lua:98-99`, se llama a `persistence.loadSettings()` y luego `persistence.applySettings(persistence.settings)`.
   - En `persistence.applySettings`:
     - Compara `g` con `prev.graphics`. En la primera llamada en el arranque, `prev = persistence.settings`, por lo que `_graphicsDiff(g, prev.graphics)` evalúa a `false` (no detecta diferencia contra el archivo recién cargado) o no ejecuta `_applyHeavy` si no se fuerza explícitamente (`opts.heavy = true`).
     - Al no invocarse `_applyHeavy`, **jamás se llama a `love.window.setMode(w, h)` con la resolución guardada al arrancar**.
3. **Pérdida de Resolución al Guardar Settings**:
   - En `systems/settings.lua`, la selección del dropdown de resolución genera un preview temporal de 5s (`previewResolution`), pero al pulsar "Guardar", la tabla `settings.editing.graphics.resolution` a veces no sincroniza el ancho y alto numéricos o el formato `{width = W, height = H}` contra lo que espera el decodificador/codificador atómico `lua_encode`.

---

### 1.2. Fallo en Conmutación de Filtro (`nearest` vs `linear`)
1. **Filtro aplicado tarde a nivel de motor**:
   - En Love2D, el filtrado de texturas e imágenes cargadas requiere `love.graphics.setDefaultFilter(filter, filter)`. Si este método no se invoca antes de crear los canvases o antes de renderizar imágenes rasterizadas, los sprites (`patroller_delta.png`, `chaser_shuriken.png`, texturas de interfaz) permanecen con el filtro con el que se inicializaron.
2. **Sobrescritura interna en Shaders**:
   - En `render/shaders.lua:380-409`, `newC()` y `newCLow()` hardcodean `"linear", "linear"` en los canvases de post-proceso (`canvasFinal`, `canvasGlowLow`, `canvasBlurH`, `canvasBlurV`).
   - Al cambiar a `nearest`, `shaders.setFilter('nearest')` cambia el filtro del canvas, pero en el shader de composite final, `love.graphics.draw(canvasFinal, 0, 0)` se dibuja 1:1 sobre el backbuffer. Para que `nearest` sea perceptible, el render de escena debe proyectarse con muestreo point-sampling o escalado fraccional sin interpolación bilinear en el muestreo de texturas `Texel(tex, uv)`.

---

### 1.3. Fallo en `pixelScale`
1. **Desconexión entre Settings y Shaders**:
   - El parámetro `graphics.pixelScale` (1, 2, 3, 4) en `settings.lua` está catalogado como `HEAVY` (requiere recrear canvases).
   - Sin embargo, en `render/shaders.lua:442`, `recreateCanvases(pixelScale, filter)` **ignora completamente el argumento `pixelScale`**:
     - `W = love.graphics.getWidth()` y `H = love.graphics.getHeight()`. Los canvases siempre se instancian al 100% de la resolución de la ventana, sin dividir `W / pixelScale` ni `H / pixelScale`.
     - Como resultado, cambiar `pixelScale` de 1 a 4 no altera en absoluto la resolución interna del canvas ni produce el efecto de agrandamiento o reducción de píxel virtual deseado.

---

## 2. Hoja de Ruta y Tareas para la Próxima Sesión

### Tarea 1: Corrección de Persistencia de Resolución y Arranque
- [ ] **Modificar `main.lua` (`love.load`)**:
  - Asegurar que en el arranque se invoque `persistence.applySettings(persistence.settings, {heavy = true})` para forzar la llamada a `love.window.setMode(savedW, savedH, flags)`.
- [ ] **Robustecer `_applyHeavy` en `systems/persistence.lua`**:
  - Validar que si `g.resolution` existe y tiene `width` y `height`, se compare con el tamaño real de `love.graphics.getWidth()` / `getHeight()`. Si difiere, aplicar el cambio de modo de ventana inmediatamente y llamar a `recalcularGrilla()`.
- [ ] **Sincronización en `systems/settings.lua`**:
  - Garantizar que al seleccionar una resolución en el dropdown y pulsar "Guardar", se guarde de forma permanente en `config/settings.dat` con el esquema canónico `{width = W, height = H}`.

### Tarea 2: Pipeline de Filtro (`nearest` vs `linear`)
- [ ] **Configuración global en Love2D**:
  - Implementar `love.graphics.setDefaultFilter(filter, filter)` en `persistence.applyFilter`.
- [ ] **Propagación a Assets y Shaders**:
  - Asegurar que `shaders.setFilter` configure `canvasScene:setFilter(f, f)` y `canvasFinal:setFilter(f, f)`.
  - Asegurar que `Assets.getImage()` aplique el filtro actual al recargar o consultar sprites.

### Tarea 3: Implementación Real de `pixelScale`
- [ ] **Actualizar `render/shaders.lua`**:
  - Utilizar el parámetro `pixelScale` en `recreateCanvases`:
    - `local virtualW = math.floor(W / pixelScale)`
    - `local virtualH = math.floor(H / pixelScale)`
    - Instanciar `canvasScene = love.graphics.newCanvas(virtualW, virtualH)` cuando `pixelScale > 1`.
  - En `shaders.composite()`, escalar el canvas al tamaño de la pantalla mediante `love.graphics.draw(canvasFinal, 0, 0, 0, pixelScale, pixelScale)`.
- [ ] **Ajustar Proyección de Ratón en `core/input.lua` y `systems/shop.lua`**:
  - Sincronizar las coordenadas de entrada considerando `pixelScale`.

---

## 3. Matriz de Pruebas Automatizadas a Implementar
- [ ] **`tests/test_scope_27_display_settings.lua`**:
  1. Test de carga de resolución guardada: verificar que un archivo con `{width = 1280, height = 720}` retorne el modo de ventana correcto.
  2. Test de filtro `nearest` y `linear`: verificar que `shaders.getFilter()` refleje el estado tras aplicar settings.
  3. Test de `pixelScale`: verificar que las dimensiones virtuales del canvas correspondan a `W / pixelScale`.

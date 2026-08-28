local settings = {}
local persistence = require('systems.persistence')
local helpers = require('core.helpers')
local settingsDraw = require('systems.settingsDraw')

-- State
settings.visible = false

settings.editing = nil
settings.lastSaved = nil
settings.activeTab = 'Audio'
settings.toastTimer = 0
settings.toastText = ''
settings.toastError = false
settings.dragState = nil
settings.openDropdown = nil
settings.g = {}
settings.PW = 500
settings.PH = 380
settings.previewTimer = 0
settings.previewOriginal = nil

-- Exposed for persistence
settings.audio = {}
settings.graphics = {}
settings.accessibility = {}

-- Helpers: LIVE vs HEAVY clasificacion (sin crear tablas por frame excesivo) ----
local world = require('core.world')

local function isLiveKey(k)
    return k == 'audio.master' or k == 'audio.music' or k == 'audio.sfx'
        or k == 'accessibility.uiScale' or k == 'accessibility.highContrast' or k == 'accessibility.colorblind'
        or k == 'gameplay.controlMode' or k == 'controls.controlMode'
        or k == 'graphics.filter'
end

local function isHeavyKey(k)
    return k == 'graphics.pixelScale' or k == 'graphics.fullscreen' or k == 'graphics.vsync'
end

local function applyLiveImmediate()
    if not settings.editing then return end
    pcall(function() persistence.applyLive(settings.editing) end)
end

local function applyLiveForKey(k)
    if isLiveKey(k) then
        applyLiveImmediate()
    end
end

-- Public API ----------------------------------------------------------------

function settings.open()
    local s = persistence.settings or persistence.loadSettings()
    settings.lastSaved = helpers.deep_copy(s)
    settings.editing = helpers.deep_copy(s)
    settings.activeTab = 'Audio'
    settings.openDropdown = nil
    settings.dragState = nil
    settings.visible = true
end

function settings.close()
    settings.visible = false
    settings.editing = nil
    settings.lastSaved = nil
    settings.activeTab = 'Audio'
    settings.toastTimer = 0
    settings.toastText = ''
    settings.toastError = false
    settings.dragState = nil
    settings.openDropdown = nil
    settings.g = {}
    settings.previewTimer = 0
    settings.previewOriginal = nil
end

function settings.update(dt)
    if settings.toastTimer > 0 then
        settings.toastTimer = settings.toastTimer - dt
        if settings.toastTimer < 0 then settings.toastTimer = 0 end
    end
    -- world.state.resolutionConfirmTimer es manejado por persistence.previewResolution via core/timers
    -- Fallback si timers no disponible: decremento manual del contador world.state
    if world and world.state and world.state.resolutionConfirmTimer and type(world.state.resolutionConfirmTimer) == 'number' then
        -- No auto-revert aquí: persistence.revertResolutionPreview es disparado por timer; solo mantenemos contador para toast
        world.state.resolutionConfirmTimer = math.max(0, world.state.resolutionConfirmTimer - dt)
        if world.state.resolutionConfirmTimer <= 0 then
            world.state.resolutionConfirmTimer = nil
        end
    end
end

-- Main draw (rediseño cyberpunk cian, responsive, anti-overflow) -----------

function settings.draw()
    if not settings.visible then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    -- responsive sizing se calcula dentro de panelXY y sincroniza PW/PH
    local px, py = settingsDraw.panelXY(settings)
    settings.g = {}

    -- Dim background (oscurece juego detrás)
    love.graphics.setColor(0, 0, 0, 0.68)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Panel background doble borde cyber
    -- sombra exterior
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', px + 3, py + 4, settings.PW, settings.PH, 12)
    -- fondo panel oscuro translúcido
    love.graphics.setColor(0.07, 0.09, 0.15, 0.97)
    love.graphics.rectangle('fill', px, py, settings.PW, settings.PH, 12)
    -- matriz de puntos HUD #14 sutil (como menuUI) dentro del panel
    local gap = 16
    local t = love.timer.getTime()
    for pyy = py + 10, py + settings.PH - 10, gap do
        for pxx = px + 10, px + settings.PW - 10, gap do
            local dist = math.sqrt((pxx - (px + settings.PW / 2)) ^ 2 + (pyy - (py + settings.PH / 2)) ^ 2)
            local wave = math.sin(dist * 0.045 - t * 2.2)
            local a = (wave > 0.55) and 0.18 or 0.05
            love.graphics.setColor(0, 0.94, 1.0, a)
            love.graphics.rectangle('fill', pxx - 1, pyy - 1, 2, 2)
        end
    end
    -- borde outer negro 1px
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', px, py, settings.PW, settings.PH, 12)
    -- borde inner cyan glow 0.6
    love.graphics.setColor(0, 0.94, 1.0, 0.60)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle('line', px + 1.2, py + 1.2, settings.PW - 2.4, settings.PH - 2.4, 10)
    love.graphics.setLineWidth(1)
    -- glow externo sutil
    love.graphics.setColor(0, 0.94, 1.0, 0.14)
    love.graphics.rectangle('line', px - 2, py - 2, settings.PW + 4, settings.PH + 4, 14)

    -- Title + header línea glow cyan
    love.graphics.setColor(1, 1, 1)
    settingsDraw.setFont(settings, 'Large')
    love.graphics.printf('CONFIGURACIÓN', px + 18, py + 14, settings.PW - 70, 'left')
    -- subtítulo jerarquía tipográfica
    settingsDraw.setFont(settings, 'Small')
    love.graphics.setColor(0, 0.94, 1.0, 0.75)
    love.graphics.print('SISTEMA / AJUSTES', px + 18, py + 34)
    -- línea glow bajo header
    love.graphics.setColor(0, 0.94, 1.0, 0.85)
    love.graphics.rectangle('fill', px + 14, py + 46, settings.PW - 28, 1.6, 1)
    love.graphics.setColor(0, 0.94, 1.0, 0.18)
    love.graphics.rectangle('fill', px + 14, py + 47.5, settings.PW - 28, 6, 2)

    -- Close [X] cyber
    local cx = px + settings.PW - 36
    local cy = py + 12
    local mx, my = love.mouse.getPosition()
    local closeHover = mx and my and mx >= cx and mx <= cx + 24 and my >= cy and my <= cy + 24
    if closeHover then
        love.graphics.setColor(0, 0.94, 1.0, 0.22)
        love.graphics.rectangle('fill', cx - 2, cy - 2, 28, 28, 7)
    end
    love.graphics.setColor(closeHover and {0.85, 0.15, 0.18} or {0.62, 0.14, 0.16})
    love.graphics.rectangle('fill', cx, cy, 24, 24, 6)
    love.graphics.setColor(0, 0.94, 1.0, closeHover and 0.95 or 0.55)
    love.graphics.rectangle('line', cx, cy, 24, 24, 6)
    love.graphics.setColor(1, 1, 1)
    settingsDraw.setFont(settings, 'Normal')
    love.graphics.printf('X', cx, cy + 4, 24, 'center')
    settings.g.closeBtn = {cx, cy, 24, 24}

    -- Tabs con iconos (🔊/🖥/♿) e indicador activo subrayado cyan + hover pulse
    local tabs = {'Audio', 'Gráficos', 'Accesibilidad'}
    local icons = {'🔊', '🖥', '♿'}
    local tabW = math.floor((settings.PW - 44) / 3)
    local tabY = py + 56
    local tx = px + 22
    settings.g.tabs = {}
    for i, tname in ipairs(tabs) do
        local isActive = (tname == settings.activeTab)
        local isHover = mx and my and mx >= tx and mx <= tx + tabW and my >= tabY and my <= tabY + 30
        -- fondo tab
        if isActive then
            love.graphics.setColor(0.06, 0.14, 0.20, 1)
        else
            love.graphics.setColor(isHover and {0.12, 0.16, 0.24} or {0.10, 0.12, 0.16})
        end
        love.graphics.rectangle('fill', tx, tabY, tabW, 30, 7)
        -- borde
        if isActive then
            love.graphics.setColor(0, 0.94, 1.0, 0.92)
        else
            love.graphics.setColor(0, 0.94, 1.0, isHover and 0.45 or 0.18)
        end
        love.graphics.rectangle('line', tx, tabY, tabW, 30, 7)
        -- hover pulse glow
        if isHover and not isActive then
            local pulse = 0.5 + math.sin(love.timer.getTime() * 6 + i) * 0.35
            love.graphics.setColor(0, 0.94, 1.0, 0.18 * pulse)
            love.graphics.rectangle('line', tx - 1, tabY - 1, tabW + 2, 32, 8)
        end
        -- texto centrado con icono
        love.graphics.setColor(1, 1, 1)
        settingsDraw.setFont(settings, 'Normal')
        local label = icons[i] .. '  ' .. tname
        -- fallback si emoji no renderiza (width 0), usar solo texto
        local font = love.graphics.getFont()
        if font:getWidth(icons[i]) < 4 then label = tname end
        love.graphics.printf(label, tx, tabY + 7, tabW, 'center')
        -- indicador activo subrayado cyan + glow
        if isActive then
            love.graphics.setColor(0, 0.94, 1.0, 1)
            love.graphics.rectangle('fill', tx + 8, tabY + 27, tabW - 16, 2.5, 1)
            love.graphics.setColor(0, 0.94, 1.0, 0.28)
            love.graphics.rectangle('fill', tx + 6, tabY + 29, tabW - 12, 5, 2)
        end
        settings.g.tabs[#settings.g.tabs + 1] = {tx, tabY, tabW, 30, name = tname}
        tx = tx + tabW + 4
    end

    -- Content area con scissor si excede
    local contentX = px + 22
    local contentY = py + 98
    local by = py + settings.PH - 54
    local contentBottom = by - 12
    local contentH = contentBottom - contentY
    if contentH < 40 then contentH = 40 end
    local contentW = settings.PW - 44

    -- scissor pre-contenido (evita overflow vertical)
    local needScissor = contentH < 200 -- siempre scissor para garantizar recorte
    if needScissor then love.graphics.setScissor(contentX - 2, contentY - 2, contentW + 4, contentH + 4) end

    if settings.activeTab == 'Audio' then
        settingsDraw.drawAudioTab(settings, contentX, contentY, contentW)
    elseif settings.activeTab == 'Gráficos' then
        settingsDraw.drawGraphicsTab(settings, contentX, contentY, contentW)
    elseif settings.activeTab == 'Accesibilidad' then
        settingsDraw.drawAccessibilityTab(settings, contentX, contentY, contentW)
    end

    if needScissor then love.graphics.setScissor() end

    -- Bottom buttons (estilo Cyber-Step, Guardar deshabilitado gris si diff empty)
    settings.g.resetBtn = {settingsDraw.drawButton(settings, px + 18, by, 116, 34, 'Restablecer', {0.10, 0.22, 0.16})}
    settings.g.cancelBtn = {settingsDraw.drawButton(settings, px + settings.PW / 2 - 65, by, 130, 34, 'Cancelar', {0.38, 0.12, 0.14})}
    settings.g.saveBtn = {settingsDraw.drawButton(settings, px + settings.PW - 148, by, 130, 34, 'Guardar', {0.08, 0.32, 0.22})}

    -- Dropdown list on top of everything (ya con clamp anti-overflow)
    if settings.openDropdown then
        settingsDraw.drawDropdownList(settings)
    end

    -- Toast badge cian slide
    if settings.toastTimer > 0 and settings.toastText then
        settingsDraw.drawToast(settings, w, h)
    end
end

-- Input handling ---------------------------------------------------------

function settings.mousepressed(x, y, button)
    if not settings.visible then return false end
    if button ~= 1 then return true end

    -- If dropdown is open, check dropdown list items first (con scroll)
    if settings.openDropdown then
        local dd = settings.openDropdown
        if settingsDraw.hitTest(settings, x, y, dd.x, dd.y, dd.w, dd.h) then
            local scrollY = dd.scrollY or 0
            local relY = y - dd.y + scrollY
            local idx = math.floor(relY / dd.itemH) + 1
            if idx >= 1 and idx <= #dd.items then
                local selected = dd.items[idx]
                local parts = settingsDraw.checkboxKeyPath(settings, dd.key)
                settingsDraw.setNested(settings, settings.editing, parts, selected.value)
                -- Resolución: preview inmediato con confirmación 5s y revert si no confirmas
                if dd.key == 'graphics.resolution' then
                    if selected.value and selected.value.width and selected.value.height then
                        local ok = false
                        pcall(function() ok = persistence.previewResolution(selected.value) end)
                        if ok then
                            settingsDraw.showToast(settings, '¿Mantener resolución? 5s', false)
                            settings.toastTimer = 5
                            if world and world.state then world.state.resolutionConfirmTimer = 5 end
                        else
                            local applied = false
                            pcall(function()
                                applied = persistence.previewResolution(selected.value)
                            end)
                            settingsDraw.showToast(settings, '¿Mantener resolución? 5s', false)
                            settings.toastTimer = 5
                        end
                    else
                        settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                    end
                elseif isLiveKey(dd.key) then
                    -- LIVE_AUDIO / LIVE_UI / LIVE filter aplica EN VIVO sin escribir disco
                    pcall(function() persistence.applyLive(settings.editing) end)
                    settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                else
                    -- HEAVY (pixelScale/fullscreen/vsync): solo muta editing, Guarda lo aplicará
                    settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                end
                settings.openDropdown = nil
            end
            return true
        else
            -- Click fuera de dropdown cierra
            -- Si click en scrollbar track, no cerrar sino ajustar scroll? Por ahora cerrar
            settings.openDropdown = nil
            -- no return inmediatamente? permitir que click caiga al panel debajo
            -- pero spec dice cerrar y consumir click; retornamos true
            return true
        end
    end

    -- Close [X] : revert LIVE sin heavy, y resolución preview si activa
    if settings.g.closeBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.closeBtn)) then
        local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
        settings.editing = helpers.deep_copy(settings.lastSaved)
        if diff.audio or diff.ui or diff.filter then
            pcall(function() persistence.applyLive(settings.lastSaved) end)
        end
        if diff.resolution and persistence._previewPrev then
            pcall(function() persistence.revertResolutionPreview() end)
        end
        settings.close()
        return true
    end

    -- Tabs
    if settings.g.tabs then
        for _, tab in ipairs(settings.g.tabs) do
            if settingsDraw.hitTest(settings, x, y, tab[1], tab[2], tab[3], tab[4]) then
                if tab.name ~= settings.activeTab then
                    settings.activeTab = tab.name
                    settings.openDropdown = nil
                end
                return true
            end
        end
    end

    -- Content widgets (based on active tab)
    if settings.activeTab == 'Audio' then
        if settings.g.masterSlider and settingsDraw.hitTest(settings, x, y, settings.g.masterSlider[1], settings.g.masterSlider[2], settings.g.masterSlider[3], 16) then
            local rel = math.max(0, math.min(1, (x - settings.g.masterSlider[1]) / settings.g.masterSlider[3]))
            settings.editing.audio.master = rel
            pcall(function() persistence.applyLive(settings.editing) end)
            settings.dragState = {type = 'master', bx = settings.g.masterSlider[1], bw = settings.g.masterSlider[3]}
            return true
        end
        if settings.g.musicBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.musicBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.musicBox.key)
            applyLiveForKey(settings.g.musicBox.key)
            return true
        end
        if settings.g.sfxBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.sfxBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.sfxBox.key)
            applyLiveForKey(settings.g.sfxBox.key)
            return true
        end
    elseif settings.activeTab == 'Gráficos' then
        if settings.g.pixelScaleDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.pixelScaleDrop)) then
            local bx, by, bw, bh = unpack(settings.g.pixelScaleDrop)
            local items = {{label='1', value=1},{label='2', value=2},{label='3', value=3},{label='4', value=4}}
            settings.openDropdown = {
                key = settings.g.pixelScaleDrop.key,
                items = items, current = settings.editing.graphics.pixelScale,
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28, scrollY = 0
            }
            return true
        end
        if settings.g.resolutionDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.resolutionDrop)) then
            local bx, by, bw, bh = unpack(settings.g.resolutionDrop)
            local items = {}
            local dw, dh = love.window.getDesktopDimensions(1)
            if dw and dh then
                table.insert(items, {label = 'Escritorio: '..dw..'x'..dh, value = {width=dw, height=dh}})
            end
            local commons = {{800,600},{1024,768},{1280,720},{1366,768},{1600,900},{1920,1080}}
            for _, r in ipairs(commons) do
                table.insert(items, {label = r[1]..'x'..r[2], value = {width=r[1], height=r[2]}})
            end
            table.insert(items, {label = 'Auto (actual)', value = nil})
            local ddH = math.min(#items * 28, 240)
            settings.openDropdown = {
                key = settings.g.resolutionDrop.key,
                items = items, current = settings.editing.graphics.resolution,
                x = bx, y = by + bh + 2, w = bw, h = ddH, itemH = 28, scrollY = 0
            }
            return true
        end
        if settings.g.filterDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.filterDrop)) then
            local bx, by, bw, bh = unpack(settings.g.filterDrop)
            local items = {{label='nearest', value='nearest'},{label='linear', value='linear'}}
            settings.openDropdown = {
                key = settings.g.filterDrop.key,
                items = items, current = settings.editing.graphics.filter,
                x = bx, y = by + bh + 2, w = bw, h = 56, itemH = 28, scrollY = 0
            }
            return true
        end
        if settings.g.fullscreenBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.fullscreenBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.fullscreenBox.key)
            -- HEAVY: no live apply
            return true
        end
        if settings.g.vsyncBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.vsyncBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.vsyncBox.key)
            -- HEAVY: no live apply
            return true
        end
    elseif settings.activeTab == 'Accesibilidad' then
        if settings.g.uiScaleSlider and settingsDraw.hitTest(settings, x, y, settings.g.uiScaleSlider[1], settings.g.uiScaleSlider[2], settings.g.uiScaleSlider[3], 16) then
            local minS, maxS = 0.8, 1.5
            local rel = math.max(0, math.min(1, (x - settings.g.uiScaleSlider[1]) / settings.g.uiScaleSlider[3]))
            settings.editing.accessibility.uiScale = minS + rel * (maxS - minS)
            pcall(function() persistence.applyLive(settings.editing) end)
            settings.dragState = {type = 'uiScale', bx = settings.g.uiScaleSlider[1], bw = settings.g.uiScaleSlider[3], min = minS, max = maxS}
            return true
        end
        if settings.g.highContrastBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.highContrastBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.highContrastBox.key)
            applyLiveForKey(settings.g.highContrastBox.key)
            return true
        end
        if settings.g.colorblindDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.colorblindDrop)) then
            local bx, by, bw, bh = unpack(settings.g.colorblindDrop)
            local items = {{label='Off', value='off'},{label='Protanopia', value='protanopia'},{label='Deuteranopia', value='deuteranopia'},{label='Tritanopia', value='tritanopia'}}
            settings.openDropdown = {
                key = settings.g.colorblindDrop.key,
                items = items, current = settings.editing.accessibility.colorblind,
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28, scrollY = 0
            }
            return true
        end
        if settings.g.controlModeDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.controlModeDrop)) then
            local bx, by, bw, bh = unpack(settings.g.controlModeDrop)
            local items = {{label='Clásico (Auto)', value='classic'},{label='Táctico (Sostener)', value='tactical'}}
            settings.openDropdown = {
                key = settings.g.controlModeDrop.key,
                items = items, current = (settings.editing.gameplay and settings.editing.gameplay.controlMode) or 'classic',
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28, scrollY = 0
            }
            return true
        end
    end

    -- Bottom buttons
    if settings.g.resetBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.resetBtn)) then
        local def = persistence.defaults()
        settings.editing = helpers.deep_copy(def)
        -- LIVE preview para valores live, HEAVY queda pendiente hasta Guardar
        pcall(function() persistence.applyLive(settings.editing) end)
        settingsDraw.showToast(settings, 'Valores restablecidos (sin guardar)', false)
        return true
    end
    if settings.g.cancelBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.cancelBtn)) then
        local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
        settings.editing = helpers.deep_copy(settings.lastSaved)
        if diff.audio or diff.ui or diff.filter then
            pcall(function() persistence.applyLive(settings.lastSaved) end)
        end
        if diff.resolution and persistence._previewPrev then
            pcall(function() persistence.revertResolutionPreview() end)
        end
        settingsDraw.showToast(settings, 'Cambios descartados', false)
        settings.close()
        return true
    end
    if settings.g.saveBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.saveBtn)) then
        local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
        if diff.empty then
            settingsDraw.showToast(settings, 'Sin cambios', false)
            return true
        end
        local ok, err = persistence.saveAndApplySelective(settings.lastSaved, settings.editing)
        if ok then
            settings.lastSaved = helpers.deep_copy(settings.editing)
            settingsDraw.showToast(settings, 'Configuración guardada', false)
            settings.close()
        else
            if err == 'no_changes' then
                settingsDraw.showToast(settings, 'Sin cambios', false)
            else
                settingsDraw.showToast(settings, 'Error al guardar: ' .. tostring(err), true)
            end
        end
        return true
    end

    -- Click dentro del panel pero fuera de widgets consume evento (no pasa al juego)
    local px, py = settingsDraw.panelXY(settings)
    if x >= px and x <= px + settings.PW and y >= py and y <= py + settings.PH then
        return true
    end
    return true
end

function settings.mousereleased(x, y, button)
    if button ~= 1 then return end
    settings.dragState = nil
end

function settings.mousemoved(x, y, dx, dy)
    if not settings.dragState or not settings.editing then return end
    local rel = math.max(0, math.min(1, (x - settings.dragState.bx) / settings.dragState.bw))
    if settings.dragState.type == 'master' then
        if settings.editing.audio then
            settings.editing.audio.master = rel
            pcall(function() persistence.applyLive(settings.editing) end)
        end
    elseif settings.dragState.type == 'uiScale' then
        if settings.editing.accessibility then
            local minS = settings.dragState.min or 0.8
            local maxS = settings.dragState.max or 1.5
            settings.editing.accessibility.uiScale = minS + rel * (maxS - minS)
            pcall(function() persistence.applyLive(settings.editing) end)
        end
    end
end

function settings.wheelmoved(dx, dy)
    if not settings.visible or not settings.openDropdown then return false end
    local dd = settings.openDropdown
    if not dd._needScroll then return false end
    local maxScroll = math.max(0, (dd._totalH or dd.h) - (dd._visibleH or dd.h))
    if maxScroll <= 0 then return false end
    dd.scrollY = math.max(0, math.min(maxScroll, (dd.scrollY or 0) - dy * 28))
    return true
end

function settings.keypressed(key)
    if not settings.visible then return false end
    if key == 'escape' then
        if settings.openDropdown then
            settings.openDropdown = nil
            return true
        end
        if settings.lastSaved then
            local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
            settings.editing = helpers.deep_copy(settings.lastSaved)
            if diff.audio or diff.ui or diff.filter then
                pcall(function() persistence.applyLive(settings.lastSaved) end)
            end
            if diff.resolution and persistence._previewPrev then
                pcall(function() persistence.revertResolutionPreview() end)
            end
        end
        settings.close()
        return true
    end
    return false
end

return settings

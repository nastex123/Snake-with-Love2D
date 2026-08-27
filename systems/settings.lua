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

-- Exposed for persistence
settings.audio = {}
settings.graphics = {}
settings.accessibility = {}

-- Public API ----------------------------------------------------------------

function settings.open()
    -- Use in-memory settings if available; only read from disk if first load
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
end

function settings.update(dt)
    if settings.toastTimer > 0 then
        settings.toastTimer = settings.toastTimer - dt
        if settings.toastTimer < 0 then settings.toastTimer = 0 end
    end
end

-- Main draw -------------------------------------------------------------

function settings.draw()
    if not settings.visible then return end
    local px, py = settingsDraw.panelXY(settings)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    settings.g = {} -- reset hit areas

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Panel background
    love.graphics.setColor(0.1, 0.1, 0.13, 0.95)
    love.graphics.rectangle('fill', px, py, settings.PW, settings.PH, 10)
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle('line', px, py, settings.PW, settings.PH, 10)

    -- Title
    love.graphics.setColor(1, 1, 1)
    settingsDraw.setFont(settings, 'Large')
    love.graphics.print('CONFIGURACIÓN', px + 18, py + 14)

    -- Close [X]
    local cx = px + settings.PW - 34
    local cy = py + 12
    love.graphics.setColor(0.7, 0.15, 0.15)
    love.graphics.rectangle('fill', cx, cy, 24, 24, 5)
    love.graphics.setColor(1, 1, 1)
    settingsDraw.setFont(settings, 'Normal')
    love.graphics.print('X', cx + 6, cy + 4)
    settings.g.closeBtn = {cx, cy, 24, 24}

    -- Tabs
    local tabs = {'Audio', 'Gráficos', 'Accesibilidad'}
    local tabW = math.floor((settings.PW - 44) / 3)
    local tabY = py + 50
    local tx = px + 22
    settings.g.tabs = {}
    for _, t in ipairs(tabs) do
        local tabIdx = #settings.g.tabs + 1
        local isActive = (t == settings.activeTab)
        love.graphics.setColor(isActive and {0, 0.65, 0.9} or {0.2, 0.2, 0.25})
        love.graphics.rectangle('fill', tx, tabY, tabW, 30, 6)
        love.graphics.setColor(1, 1, 1)
        settingsDraw.setFont(settings, 'Normal')
        love.graphics.printf(t, tx, tabY + 6, tabW, 'center')
        settings.g.tabs[#settings.g.tabs + 1] = {tx, tabY, tabW, 30, name = t}
        tx = tx + tabW + 4
    end

    -- Content area
    local contentY = py + 95
    if settings.activeTab == 'Audio' then
        settingsDraw.drawAudioTab(settings, px + 22, contentY, settings.PW - 44)
    elseif settings.activeTab == 'Gráficos' then
        settingsDraw.drawGraphicsTab(settings, px + 22, contentY, settings.PW - 44)
    elseif settings.activeTab == 'Accesibilidad' then
        settingsDraw.drawAccessibilityTab(settings, px + 22, contentY, settings.PW - 44)
    end

    -- Bottom buttons
    local by = py + settings.PH - 54
    settings.g.resetBtn = {settingsDraw.drawButton(settings, px + 20, by, 120, 34, 'Restablecer', {0.3, 0.35, 0.2})}
    settings.g.cancelBtn = {settingsDraw.drawButton(settings, px + settings.PW/2 - 65, by, 130, 34, 'Cancelar', {0.5, 0.2, 0.2})}
    settings.g.saveBtn = {settingsDraw.drawButton(settings, px + settings.PW - 150, by, 130, 34, 'Guardar', {0.2, 0.45, 0.2})}

    -- Dropdown list on top of everything
    if settings.openDropdown then
        settingsDraw.drawDropdownList(settings)
    end

    -- Toast
    if settings.toastTimer > 0 and settings.toastText then
        settingsDraw.drawToast(settings, w, h)
    end
end

-- Input handling ---------------------------------------------------------





function settings.mousepressed(x, y, button)
    if not settings.visible or button ~= 1 then return true end

    -- If dropdown is open, check dropdown list items first
    if settings.openDropdown then
        local dd = settings.openDropdown
        if settingsDraw.hitTest(settings, x, y, dd.x, dd.y, dd.w, dd.h) then
            local idx = math.floor((y - dd.y) / dd.itemH) + 1
            if idx >= 1 and idx <= #dd.items then
                local selected = dd.items[idx]
                -- Update settings.editing
                local parts = settingsDraw.checkboxKeyPath(settings, dd.key)
                settingsDraw.setNested(settings, settings.editing, parts, selected.value)
                settingsDraw.showToast(settings, 'Seleccionado: ' .. selected.label, false)
                settings.openDropdown = nil
            end
            return true
        else
            -- Click outside dropdown closes it
            settings.openDropdown = nil
            return true
        end
    end

    -- Close [X]
    if settings.g.closeBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.closeBtn)) then
        settings.editing = helpers.deep_copy(settings.lastSaved)
        persistence.applySettings(settings.lastSaved)
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
        -- Master slider
        if settings.g.masterSlider and settingsDraw.hitTest(settings, x, y, settings.g.masterSlider[1], settings.g.masterSlider[2], settings.g.masterSlider[3], 16) then
            local rel = math.max(0, math.min(1, (x - settings.g.masterSlider[1]) / settings.g.masterSlider[3]))
            settings.editing.audio.master = rel
            settings.dragState = {type = 'master', bx = settings.g.masterSlider[1], bw = settings.g.masterSlider[3]}
            return true
        end
        -- Music checkbox
        if settings.g.musicBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.musicBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.musicBox.key)
            return true
        end
        -- SFX checkbox
        if settings.g.sfxBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.sfxBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.sfxBox.key)
            return true
        end
    elseif settings.activeTab == 'Gráficos' then
        -- Pixel Scale dropdown
        if settings.g.pixelScaleDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.pixelScaleDrop)) then
            local bx, by, bw, bh = unpack(settings.g.pixelScaleDrop)
            local items = {{label='1', value=1},{label='2', value=2},{label='3', value=3},{label='4', value=4}}
            settings.openDropdown = {
                key = settings.g.pixelScaleDrop.key,
                items = items, current = settings.editing.graphics.pixelScale,
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28
            }
            return true
        end
        -- Resolution dropdown
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
                x = bx, y = by + bh + 2, w = bw, h = ddH, itemH = 28
            }
            return true
        end
        -- Filter dropdown
        if settings.g.filterDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.filterDrop)) then
            local bx, by, bw, bh = unpack(settings.g.filterDrop)
            local items = {{label='nearest', value='nearest'},{label='linear', value='linear'}}
            settings.openDropdown = {
                key = settings.g.filterDrop.key,
                items = items, current = settings.editing.graphics.filter,
                x = bx, y = by + bh + 2, w = bw, h = 56, itemH = 28
            }
            return true
        end
        -- Fullscreen checkbox
        if settings.g.fullscreenBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.fullscreenBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.fullscreenBox.key)
            return true
        end
        -- VSync checkbox
        if settings.g.vsyncBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.vsyncBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.vsyncBox.key)
            return true
        end
    elseif settings.activeTab == 'Accesibilidad' then
        -- UI Scale slider
        if settings.g.uiScaleSlider and settingsDraw.hitTest(settings, x, y, settings.g.uiScaleSlider[1], settings.g.uiScaleSlider[2], settings.g.uiScaleSlider[3], 16) then
            local minS, maxS = 0.8, 1.5
            local rel = math.max(0, math.min(1, (x - settings.g.uiScaleSlider[1]) / settings.g.uiScaleSlider[3]))
            settings.editing.accessibility.uiScale = minS + rel * (maxS - minS)
            settings.dragState = {type = 'uiScale', bx = settings.g.uiScaleSlider[1], bw = settings.g.uiScaleSlider[3], min = minS, max = maxS}
            return true
        end
        -- High Contrast checkbox
        if settings.g.highContrastBox and settingsDraw.hitTest(settings, x, y, unpack(settings.g.highContrastBox)) then
            settingsDraw.toggleCheckbox(settings, settings.g.highContrastBox.key)
            return true
        end
        -- Colorblind dropdown
        if settings.g.colorblindDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.colorblindDrop)) then
            local bx, by, bw, bh = unpack(settings.g.colorblindDrop)
            local items = {{label='Off', value='off'},{label='Protanopia', value='protanopia'},{label='Deuteranopia', value='deuteranopia'},{label='Tritanopia', value='tritanopia'}}
            settings.openDropdown = {
                key = settings.g.colorblindDrop.key,
                items = items, current = settings.editing.accessibility.colorblind,
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28
            }
            return true
        end
        -- Control Mode dropdown
        if settings.g.controlModeDrop and settingsDraw.hitTest(settings, x, y, unpack(settings.g.controlModeDrop)) then
            local bx, by, bw, bh = unpack(settings.g.controlModeDrop)
            local items = {{label='Clásico (Auto)', value='classic'},{label='Táctico (Sostener)', value='tactical'}}
            settings.openDropdown = {
                key = settings.g.controlModeDrop.key,
                items = items, current = (settings.editing.gameplay and settings.editing.gameplay.controlMode) or 'classic',
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28
            }
            return true
        end
    end

    -- Bottom buttons
    if settings.g.resetBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.resetBtn)) then
        local def = persistence.defaults()
        settings.editing = helpers.deep_copy(def)
        settingsDraw.showToast(settings, 'Valores restablecidos (sin guardar)', false)
        return true
    end
    if settings.g.cancelBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.cancelBtn)) then
        settings.editing = helpers.deep_copy(settings.lastSaved)
        persistence.applySettings(settings.lastSaved)
        settingsDraw.showToast(settings, 'Cambios descartados', false)
        settings.close()
        return true
    end
    if settings.g.saveBtn and settingsDraw.hitTest(settings, x, y, unpack(settings.g.saveBtn)) then
        local ok, err = persistence.saveAndApply(settings.editing)
        if ok then
            settings.lastSaved = helpers.deep_copy(settings.editing)
            settingsDraw.showToast(settings, 'Configuración guardada', false)
            settings.close()
        else
            settingsDraw.showToast(settings, 'Error al guardar: ' .. tostring(err), true)
        end
        return true
    end

    return true
end

function settings.mousereleased(x, y, button)
    if button ~= 1 then return end
    settings.dragState = nil
end

function settings.mousemoved(x, y, dx, dy)
    if not settings.dragState then return end
    local rel = math.max(0, math.min(1, (x - settings.dragState.bx) / settings.dragState.bw))
    if settings.dragState.type == 'master' then
        settings.editing.audio.master = rel
    elseif settings.dragState.type == 'uiScale' then
        settings.editing.accessibility.uiScale = settings.dragState.min + rel * (settings.dragState.max - settings.dragState.min)
    end
end

return settings

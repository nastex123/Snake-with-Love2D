local settings = {}
local persistence = require('persistence')
local helpers = require('helpers')
local ui = require('ui')
local shaders = require('shaders')

-- State
settings.visible = false
local editing = nil
local lastSaved = nil
local activeTab = 'Audio'
local toastTimer = 0
local toastText = ''
local toastError = false
local dragState = nil
local openDropdown = nil
local g = {}  -- hit areas, recalculated each draw frame

-- Panel dimensions (fixed)
local PW = 500
local PH = 380

local function panelXY()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    return math.floor((w - PW) / 2), math.floor((h - PH) / 2)
end

local function showToast(text, isError)
    toastText = text
    toastTimer = 2.5
    toastError = isError or false
end

-- Public API ----------------------------------------------------------------

function settings.open()
    -- Use in-memory settings if available; only read from disk if first load
    local s = persistence.settings or persistence.loadSettings()
    lastSaved = helpers.deep_copy(s)
    editing = helpers.deep_copy(s)
    activeTab = 'Audio'
    openDropdown = nil
    dragState = nil
    settings.visible = true
end

function settings.close()
    settings.visible = false
    openDropdown = nil
    dragState = nil
end

function settings.update(dt)
    if toastTimer > 0 then
        toastTimer = toastTimer - dt
        if toastTimer < 0 then toastTimer = 0 end
    end
end

-- Widget helpers for hit areas (populated during draw, consumed by mousepressed)

local function setFont(size)
    if ui and ui['font'..size] then
        love.graphics.setFont(ui['font'..size])
    else
        local s = size == 'Large' and 22 or size == 'Normal' and 16 or 12
        love.graphics.setFont(love.graphics.newFont(s))
    end
end

local function drawCheckbox(x, y, label, value)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y + 2)
    local bx = x + 250
    local by = y
    love.graphics.setColor(value and {0.2, 0.8, 0.2} or {0.3, 0.3, 0.35})
    love.graphics.rectangle('fill', bx, by, 22, 22, 4)
    if value then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.print('✓', bx + 4, by + 2)
    end
    return bx, by, 22, 22
end

local function drawSlider(x, y, w, label, val)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y + 2)
    local bx = x + 250
    local bw = w - 250
    -- track
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle('fill', bx, y + 8, bw, 8, 4)
    -- fill
    love.graphics.setColor(0, 0.85, 1)
    love.graphics.rectangle('fill', bx, y + 8, bw * val, 8, 4)
    -- knob
    local kx = bx + bw * val - 6
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', kx, y + 2, 12, 20, 6)
    -- value text
    local pct = math.floor(val * 100)
    love.graphics.setColor(0.7, 0.7, 0.7)
    setFont('Small')
    love.graphics.print(tostring(pct) .. '%', bx + bw + 8, y + 4)
    return bx, y, bw, 24
end

local function drawDropdown(x, y, w, label, valueLabel)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y + 2)
    local bx = x + 250
    local bw = w - 250
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle('fill', bx, y, bw, 24, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(ui and ui.fontNormal or love.graphics.newFont(14))
    love.graphics.print(tostring(valueLabel), bx + 6, y + 4)
    -- ▾ arrow
    love.graphics.print('▾', bx + bw - 18, y + 4)
    return bx, y, bw, 24
end

local function drawButton(x, y, w, h, text, color)
    love.graphics.setColor(unpack(color or {0.3, 0.3, 0.4}))
    love.graphics.rectangle('fill', x, y, w, h, 6)
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    love.graphics.printf(text, x, y + (h - 16) / 2, w, 'center')
    return x, y, w, h
end

-- Content drawing per tab -----------------------------------------------

function drawAudioTab(cx, cy, cw)
    -- Row 0: Master volume slider
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Volumen Maestro', cx, cy + 2)
    local bx = cx + 180
    local bw = cw - 180
    local vy = cy + 8
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle('fill', bx, vy, bw, 10, 5)
    local val = editing.audio.master
    love.graphics.setColor(0, 0.85, 1)
    love.graphics.rectangle('fill', bx, vy, bw * val, 10, 5)
    local kx = bx + bw * val - 7
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', kx, vy - 3, 14, 16, 8)
    local pct = math.floor(val * 100)
    love.graphics.setColor(0.7, 0.7, 0.7)
    setFont('Small')
    love.graphics.print(tostring(pct) .. '%', bx + bw + 6, vy - 1)
    -- Store slider hitbox
    g.masterSlider = {bx, vy, bw}
    g.masterVal = 'audio.master'

    -- Checkboxes
    local ___bx, ___by, ___bw, ___bh = drawCheckbox(cx, cy + 40, 'Música', editing.audio.music)
    g.musicBox = {___bx, ___by, ___bw, ___bh, key='audio.music'}
    local ___bx, ___by, ___bw, ___bh = drawCheckbox(cx, cy + 72, 'Efectos de sonido', editing.audio.sfx)
    g.sfxBox = {___bx, ___by, ___bw, ___bh, key='audio.sfx'}
end

function drawGraphicsTab(cx, cy, cw)
    local function label(label, y)
        love.graphics.setColor(1, 1, 1)
        setFont('Normal')
        love.graphics.print(label, cx, y + 2)
    end

    -- Pixel Scale
    local ps = tostring(editing.graphics.pixelScale)
    local ___bx, ___by, ___bw, ___bh = drawDropdown(cx, cy, cw, 'Pixel Scale', ps)
    g.pixelScaleDrop = {___bx, ___by, ___bw, ___bh, key='graphics.pixelScale'}

    -- Resolution
    local res = editing.graphics.resolution
    local resLabel = res and (tostring(res.width) .. 'x' .. tostring(res.height)) or 'Auto'
    local ___bx, ___by, ___bw, ___bh = drawDropdown(cx, cy + 32, cw, 'Resolución', resLabel)
    g.resolutionDrop = {___bx, ___by, ___bw, ___bh, key='graphics.resolution'}

    -- Filter
    local ___bx, ___by, ___bw, ___bh = drawDropdown(cx, cy + 64, cw, 'Filtro', editing.graphics.filter)
    g.filterDrop = {___bx, ___by, ___bw, ___bh, key='graphics.filter'}

    -- Fullscreen checkbox
    local ___bx, ___by, ___bw, ___bh = drawCheckbox(cx, cy + 100, 'Pantalla completa', editing.graphics.fullscreen)
    g.fullscreenBox = {___bx, ___by, ___bw, ___bh, key='graphics.fullscreen'}

    -- VSync checkbox
    local ___bx, ___by, ___bw, ___bh = drawCheckbox(cx, cy + 132, 'VSync', editing.graphics.vsync)
    g.vsyncBox = {___bx, ___by, ___bw, ___bh, key='graphics.vsync'}
end

function drawAccessibilityTab(cx, cy, cw)
    -- UI Scale slider
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    love.graphics.print('Escala UI', cx, cy + 2)
    local bx = cx + 180
    local bw = cw - 180
    local vy = cy + 8
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle('fill', bx, vy, bw, 10, 5)
    local minS, maxS = 0.8, 1.5
    local val = editing.accessibility.uiScale
    local frac = (val - minS) / (maxS - minS)
    love.graphics.setColor(0, 0.85, 1)
    love.graphics.rectangle('fill', bx, vy, bw * frac, 10, 5)
    local kx = bx + bw * frac - 7
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', kx, vy - 3, 14, 16, 8)
    love.graphics.setColor(0.7, 0.7, 0.7)
    setFont('Small')
    love.graphics.print(string.format('%.1f', val), bx + bw + 6, vy - 1)
    g.uiScaleSlider = {bx, vy, bw}
    g.uiScaleVal = 'accessibility.uiScale'

    -- High contrast checkbox
    local ___bx, ___by, ___bw, ___bh = drawCheckbox(cx, cy + 40, 'Alto contraste', editing.accessibility.highContrast)
    g.highContrastBox = {___bx, ___by, ___bw, ___bh, key='accessibility.highContrast'}

    -- Colorblind dropdown
    local cbLabel = editing.accessibility.colorblind or 'off'
    local ___bx, ___by, ___bw, ___bh = drawDropdown(cx, cy + 72, cw, 'Daltonismo', cbLabel)
    g.colorblindDrop = {___bx, ___by, ___bw, ___bh, key='accessibility.colorblind'}
end

-- Dropdown list drawing -------------------------------------------------

local function drawDropdownList()
    local dd = openDropdown
    if not dd then return end
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.18, 0.98)
    love.graphics.rectangle('fill', dd.x, dd.y, dd.w, dd.h, 6)
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.rectangle('line', dd.x, dd.y, dd.w, dd.h, 6)
    -- Items
    love.graphics.setFont(ui and ui.fontNormal or love.graphics.newFont(14))
    for i, item in ipairs(dd.items) do
        local iy = dd.y + (i - 1) * dd.itemH
        local isSel = (item.value == dd.current)
            or (type(item.value) == 'table' and type(dd.current) == 'table' and item.value.width == dd.current.width and item.value.height == dd.current.height)
        if isSel then
            love.graphics.setColor(0, 0.85, 1, 0.3)
            love.graphics.rectangle('fill', dd.x + 2, iy, dd.w - 4, dd.itemH, 4)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(item.label, dd.x + 8, iy + 4, dd.w - 16, 'left')
    end
end

-- Toast drawing ---------------------------------------------------------

local function drawToast(w, h)
    local tw = 360
    local th = 40
    local tx = (w - tw) / 2
    local ty = h - 80
    if toastError then
        love.graphics.setColor(0.5, 0.1, 0.1, 0.92)
    else
        love.graphics.setColor(0, 0, 0, 0.9)
    end
    love.graphics.rectangle('fill', tx, ty, tw, th, 8)
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    love.graphics.printf(toastText or '', tx + 12, ty + 10, tw - 24, 'center')
end

-- Main draw -------------------------------------------------------------

function settings.draw()
    if not settings.visible then return end
    local px, py = panelXY()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    g = {} -- reset hit areas

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Panel background
    love.graphics.setColor(0.1, 0.1, 0.13, 0.95)
    love.graphics.rectangle('fill', px, py, PW, PH, 10)
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle('line', px, py, PW, PH, 10)

    -- Title
    love.graphics.setColor(1, 1, 1)
    setFont('Large')
    love.graphics.print('CONFIGURACIÓN', px + 18, py + 14)

    -- Close [X]
    local cx = px + PW - 34
    local cy = py + 12
    love.graphics.setColor(0.7, 0.15, 0.15)
    love.graphics.rectangle('fill', cx, cy, 24, 24, 5)
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    love.graphics.print('X', cx + 6, cy + 4)
    g.closeBtn = {cx, cy, 24, 24}

    -- Tabs
    local tabs = {'Audio', 'Gráficos', 'Accesibilidad'}
    local tabW = math.floor((PW - 44) / 3)
    local tabY = py + 50
    local tx = px + 22
    g.tabs = {}
    for _, t in ipairs(tabs) do
        local tabIdx = #g.tabs + 1
        local isActive = (t == activeTab)
        love.graphics.setColor(isActive and {0, 0.65, 0.9} or {0.2, 0.2, 0.25})
        love.graphics.rectangle('fill', tx, tabY, tabW, 30, 6)
        love.graphics.setColor(1, 1, 1)
        setFont('Normal')
        love.graphics.printf(t, tx, tabY + 6, tabW, 'center')
        g.tabs[#g.tabs + 1] = {tx, tabY, tabW, 30, name = t}
        tx = tx + tabW + 4
    end

    -- Content area
    local contentY = py + 95
    if activeTab == 'Audio' then
        drawAudioTab(px + 22, contentY, PW - 44)
    elseif activeTab == 'Gráficos' then
        drawGraphicsTab(px + 22, contentY, PW - 44)
    elseif activeTab == 'Accesibilidad' then
        drawAccessibilityTab(px + 22, contentY, PW - 44)
    end

    -- Bottom buttons
    local by = py + PH - 54
    g.resetBtn = {drawButton(px + 20, by, 120, 34, 'Restablecer', {0.3, 0.35, 0.2})}
    g.cancelBtn = {drawButton(px + PW/2 - 65, by, 130, 34, 'Cancelar', {0.5, 0.2, 0.2})}
    g.saveBtn = {drawButton(px + PW - 150, by, 130, 34, 'Guardar', {0.2, 0.45, 0.2})}

    -- Dropdown list on top of everything
    if openDropdown then
        drawDropdownList()
    end

    -- Toast
    if toastTimer > 0 and toastText then
        drawToast(w, h)
    end
end

-- Input handling ---------------------------------------------------------

local function hitTest(x, y, hx, hy, hw, hh)
    return x >= hx and x <= hx + hw and y >= hy and y <= hy + hh
end

local function checkboxKeyPath(key)
    -- 'audio.music' -> editing.audio.music
    local parts = {}
    for part in key:gmatch('[^.]+') do parts[#parts+1] = part end
    return parts
end

local function setNested(tbl, keypath, value)
    local t = tbl
    for i = 1, #keypath - 1 do
        t = t[keypath[i]]
        if not t then return end
    end
    t[keypath[#keypath]] = value
end

local function toggleCheckbox(keypath)
    local parts = checkboxKeyPath(keypath)
    local t = editing
    for i = 1, #parts - 1 do t = t[parts[i]] end
    t[parts[#parts]] = not t[parts[#parts]]
end

function settings.mousepressed(x, y, button)
    if not settings.visible or button ~= 1 then return true end

    -- If dropdown is open, check dropdown list items first
    if openDropdown then
        local dd = openDropdown
        if hitTest(x, y, dd.x, dd.y, dd.w, dd.h) then
            local idx = math.floor((y - dd.y) / dd.itemH) + 1
            if idx >= 1 and idx <= #dd.items then
                local selected = dd.items[idx]
                -- Update editing
                local parts = checkboxKeyPath(dd.key)
                setNested(editing, parts, selected.value)
                showToast('Seleccionado: ' .. selected.label, false)
                openDropdown = nil
            end
            return true
        else
            -- Click outside dropdown closes it
            openDropdown = nil
            return true
        end
    end

    -- Close [X]
    if g.closeBtn and hitTest(x, y, unpack(g.closeBtn)) then
        editing = helpers.deep_copy(lastSaved)
        persistence.applySettings(lastSaved)
        settings.close()
        return true
    end

    -- Tabs
    if g.tabs then
        for _, tab in ipairs(g.tabs) do
            if hitTest(x, y, tab[1], tab[2], tab[3], tab[4]) then
                if tab.name ~= activeTab then
                    activeTab = tab.name
                    openDropdown = nil
                end
                return true
            end
        end
    end

    -- Content widgets (based on active tab)
    if activeTab == 'Audio' then
        -- Master slider
        if g.masterSlider and hitTest(x, y, g.masterSlider[1], g.masterSlider[2], g.masterSlider[3], 16) then
            local rel = math.max(0, math.min(1, (x - g.masterSlider[1]) / g.masterSlider[3]))
            editing.audio.master = rel
            dragState = {type = 'master', bx = g.masterSlider[1], bw = g.masterSlider[3]}
            return true
        end
        -- Music checkbox
        if g.musicBox and hitTest(x, y, unpack(g.musicBox)) then
            toggleCheckbox(g.musicBox.key)
            return true
        end
        -- SFX checkbox
        if g.sfxBox and hitTest(x, y, unpack(g.sfxBox)) then
            toggleCheckbox(g.sfxBox.key)
            return true
        end
    elseif activeTab == 'Gráficos' then
        -- Pixel Scale dropdown
        if g.pixelScaleDrop and hitTest(x, y, unpack(g.pixelScaleDrop)) then
            local bx, by, bw, bh = unpack(g.pixelScaleDrop)
            local items = {{label='1', value=1},{label='2', value=2},{label='3', value=3},{label='4', value=4}}
            openDropdown = {
                key = g.pixelScaleDrop.key,
                items = items, current = editing.graphics.pixelScale,
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28
            }
            return true
        end
        -- Resolution dropdown
        if g.resolutionDrop and hitTest(x, y, unpack(g.resolutionDrop)) then
            local bx, by, bw, bh = unpack(g.resolutionDrop)
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
            openDropdown = {
                key = g.resolutionDrop.key,
                items = items, current = editing.graphics.resolution,
                x = bx, y = by + bh + 2, w = bw, h = ddH, itemH = 28
            }
            return true
        end
        -- Filter dropdown
        if g.filterDrop and hitTest(x, y, unpack(g.filterDrop)) then
            local bx, by, bw, bh = unpack(g.filterDrop)
            local items = {{label='nearest', value='nearest'},{label='linear', value='linear'}}
            openDropdown = {
                key = g.filterDrop.key,
                items = items, current = editing.graphics.filter,
                x = bx, y = by + bh + 2, w = bw, h = 56, itemH = 28
            }
            return true
        end
        -- Fullscreen checkbox
        if g.fullscreenBox and hitTest(x, y, unpack(g.fullscreenBox)) then
            toggleCheckbox(g.fullscreenBox.key)
            return true
        end
        -- VSync checkbox
        if g.vsyncBox and hitTest(x, y, unpack(g.vsyncBox)) then
            toggleCheckbox(g.vsyncBox.key)
            return true
        end
    elseif activeTab == 'Accesibilidad' then
        -- UI Scale slider
        if g.uiScaleSlider and hitTest(x, y, g.uiScaleSlider[1], g.uiScaleSlider[2], g.uiScaleSlider[3], 16) then
            local minS, maxS = 0.8, 1.5
            local rel = math.max(0, math.min(1, (x - g.uiScaleSlider[1]) / g.uiScaleSlider[3]))
            editing.accessibility.uiScale = minS + rel * (maxS - minS)
            dragState = {type = 'uiScale', bx = g.uiScaleSlider[1], bw = g.uiScaleSlider[3], min = minS, max = maxS}
            return true
        end
        -- High Contrast checkbox
        if g.highContrastBox and hitTest(x, y, unpack(g.highContrastBox)) then
            toggleCheckbox(g.highContrastBox.key)
            return true
        end
        -- Colorblind dropdown
        if g.colorblindDrop and hitTest(x, y, unpack(g.colorblindDrop)) then
            local bx, by, bw, bh = unpack(g.colorblindDrop)
            local items = {{label='Off', value='off'},{label='Protanopia', value='protanopia'},{label='Deuteranopia', value='deuteranopia'},{label='Tritanopia', value='tritanopia'}}
            openDropdown = {
                key = g.colorblindDrop.key,
                items = items, current = editing.accessibility.colorblind,
                x = bx, y = by + bh + 2, w = bw, h = #items * 28, itemH = 28
            }
            return true
        end
    end

    -- Bottom buttons
    if g.resetBtn and hitTest(x, y, unpack(g.resetBtn)) then
        local def = persistence.defaults()
        editing = helpers.deep_copy(def)
        showToast('Valores restablecidos (sin guardar)', false)
        return true
    end
    if g.cancelBtn and hitTest(x, y, unpack(g.cancelBtn)) then
        editing = helpers.deep_copy(lastSaved)
        persistence.applySettings(lastSaved)
        showToast('Cambios descartados', false)
        settings.close()
        return true
    end
    if g.saveBtn and hitTest(x, y, unpack(g.saveBtn)) then
        local ok, err = persistence.saveAndApply(editing)
        if ok then
            lastSaved = helpers.deep_copy(editing)
            showToast('Configuración guardada', false)
            settings.close()
        else
            showToast('Error al guardar: ' .. tostring(err), true)
        end
        return true
    end

    return true
end

function settings.mousereleased(x, y, button)
    if button ~= 1 then return end
    dragState = nil
end

function settings.mousemoved(x, y, dx, dy)
    if not dragState then return end
    local rel = math.max(0, math.min(1, (x - dragState.bx) / dragState.bw))
    if dragState.type == 'master' then
        editing.audio.master = rel
    elseif dragState.type == 'uiScale' then
        editing.accessibility.uiScale = dragState.min + rel * (dragState.max - dragState.min)
    end
end

-- No keyboard handling needed (mouse-only)

return settings





-- systems/settingsDraw.lua — Submódulo de renderizado y controles para el panel de ajustes
local settingsDraw = {}
local ui = require('ui.ui')

local fallbackFonts = {}

local function getFallbackFont(s)
    if not fallbackFonts[s] then
        fallbackFonts[s] = love.graphics.newFont(s)
    end
    return fallbackFonts[s]
end

local function setFont(size)
    if ui and ui['font' .. size] then
        love.graphics.setFont(ui['font' .. size])
    else
        local s = size == 'Large' and 22 or (size == 'Normal' and 16 or 12)
        love.graphics.setFont(getFallbackFont(s))
    end
end

local function panelXY(settings)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    return math.floor((w - settings.PW) / 2), math.floor((h - settings.PH) / 2)
end

local function showToast(settings, text, isError)
    settings.toastText = text
    settings.toastTimer = 2.5
    settings.toastError = isError or false
end

local function hitTest(settings, x, y, hx, hy, hw, hh)
    return x >= hx and x <= hx + hw and y >= hy and y <= hy + hh
end

local function checkboxKeyPath(key)
    local parts = {}
    for part in key:gmatch('[^.]+') do parts[#parts + 1] = part end
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

local function toggleCheckbox(settings, keypath)
    local parts = checkboxKeyPath(keypath)
    local t = settings.editing
    for i = 1, #parts - 1 do t = t[parts[i]] end
    t[parts[#parts]] = not t[parts[#parts]]
end

local function drawCheckbox(settings, x, y, label, value)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y + 2)
    local bx = x + 250
    local by = y
    love.graphics.setColor(value and {0.2, 0.8, 0.2} or {0.3, 0.3, 0.35})
    love.graphics.rectangle('fill', bx, by, 22, 22, 4)
    if value then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(ui and ui.fontNormal or getFallbackFont(16))
        love.graphics.print('✓', bx + 4, by + 2)
    end
    return bx, by, 22, 22
end

local function drawSlider(settings, x, y, w, label, val)
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

local function drawDropdown(settings, x, y, w, label, valueLabel)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y + 2)
    local bx = x + 250
    local bw = w - 250
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle('fill', bx, y, bw, 24, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(ui and ui.fontNormal or getFallbackFont(14))
    love.graphics.print(tostring(valueLabel), bx + 6, y + 4)
    -- ▾ arrow
    love.graphics.print('▾', bx + bw - 18, y + 4)
    return bx, y, bw, 24
end

local function drawButton(settings, x, y, w, h, text, color)
    love.graphics.setColor(unpack(color or {0.3, 0.3, 0.4}))
    love.graphics.rectangle('fill', x, y, w, h, 6)
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    love.graphics.printf(text, x, y + (h - 16) / 2, w, 'center')
    return x, y, w, h
end

-- Exportar helpers para llamadas con self o con settingsDraw.*
settingsDraw.getFallbackFont = function(settings, s) return getFallbackFont(s) end
settingsDraw.setFont = function(settings, size) return setFont(size) end
settingsDraw.panelXY = panelXY
settingsDraw.showToast = showToast
settingsDraw.hitTest = hitTest
settingsDraw.checkboxKeyPath = function(settings, key) return checkboxKeyPath(key) end
settingsDraw.setNested = function(settings, tbl, keypath, value) return setNested(tbl, keypath, value) end
settingsDraw.toggleCheckbox = toggleCheckbox
settingsDraw.drawCheckbox = drawCheckbox
settingsDraw.drawSlider = drawSlider
settingsDraw.drawDropdown = drawDropdown
settingsDraw.drawButton = drawButton

function settingsDraw.drawAudioTab(settings, cx, cy, cw)
    -- Row 0: Master volume slider
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Volumen Maestro', cx, cy + 2)
    local bx = cx + 180
    local bw = cw - 180
    local vy = cy + 8
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle('fill', bx, vy, bw, 10, 5)
    local val = settings.editing.audio.master or 1.0
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
    settings.g.masterSlider = {bx, vy, bw}
    settings.g.masterVal = 'audio.master'

    -- Checkboxes
    local mbx, mby, mbw, mbh = drawCheckbox(settings, cx, cy + 40, 'Música', settings.editing.audio.music)
    settings.g.musicBox = {mbx, mby, mbw, mbh, key = 'audio.music'}
    local sbx, sby, sbw, sbh = drawCheckbox(settings, cx, cy + 72, 'Efectos de sonido', settings.editing.audio.sfx)
    settings.g.sfxBox = {sbx, sby, sbw, sbh, key = 'audio.sfx'}
end

function settingsDraw.drawGraphicsTab(settings, cx, cy, cw)
    -- Pixel Scale
    local ps = tostring(settings.editing.graphics.pixelScale or 2)
    local psx, psy, psw, psh = drawDropdown(settings, cx, cy, cw, 'Pixel Scale', ps)
    settings.g.pixelScaleDrop = {psx, psy, psw, psh, key = 'graphics.pixelScale'}

    -- Resolution
    local res = settings.editing.graphics.resolution
    local resLabel = res and (tostring(res.width) .. 'x' .. tostring(res.height)) or 'Auto'
    local rx, ry, rw, rh = drawDropdown(settings, cx, cy + 32, cw, 'Resolución', resLabel)
    settings.g.resolutionDrop = {rx, ry, rw, rh, key = 'graphics.resolution'}

    -- Filter
    local fx, fy, fw, fh = drawDropdown(settings, cx, cy + 64, cw, 'Filtro', settings.editing.graphics.filter or 'nearest')
    settings.g.filterDrop = {fx, fy, fw, fh, key = 'graphics.filter'}

    -- Fullscreen checkbox
    local fsx, fsy, fsw, fsh = drawCheckbox(settings, cx, cy + 100, 'Pantalla completa', settings.editing.graphics.fullscreen)
    settings.g.fullscreenBox = {fsx, fsy, fsw, fsh, key = 'graphics.fullscreen'}

    -- VSync checkbox
    local vx, vy, vw, vh = drawCheckbox(settings, cx, cy + 132, 'VSync', settings.editing.graphics.vsync)
    settings.g.vsyncBox = {vx, vy, vw, vh, key = 'graphics.vsync'}
end

function settingsDraw.drawAccessibilityTab(settings, cx, cy, cw)
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
    local val = settings.editing.accessibility.uiScale or 1.0
    local frac = (val - minS) / (maxS - minS)
    love.graphics.setColor(0, 0.85, 1)
    love.graphics.rectangle('fill', bx, vy, bw * frac, 10, 5)
    local kx = bx + bw * frac - 7
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', kx, vy - 3, 14, 16, 8)
    love.graphics.setColor(0.7, 0.7, 0.7)
    setFont('Small')
    love.graphics.print(string.format('%.1f', val), bx + bw + 6, vy - 1)
    settings.g.uiScaleSlider = {bx, vy, bw}
    settings.g.uiScaleVal = 'accessibility.uiScale'

    -- High contrast checkbox
    local hx, hy, hw, hh = drawCheckbox(settings, cx, cy + 40, 'Alto contraste', settings.editing.accessibility.highContrast)
    settings.g.highContrastBox = {hx, hy, hw, hh, key = 'accessibility.highContrast'}

    -- Colorblind dropdown
    local cbLabel = settings.editing.accessibility.colorblind or 'off'
    local cbx, cby, cbw, cbh = drawDropdown(settings, cx, cy + 72, cw, 'Daltonismo', cbLabel)
    settings.g.colorblindDrop = {cbx, cby, cbw, cbh, key = 'accessibility.colorblind'}

    -- Control Mode dropdown
    local curMode = (settings.editing.gameplay and settings.editing.gameplay.controlMode)
        or (settings.editing.controls and settings.editing.controls.controlMode) or 'classic'
    local modeLabel = curMode == 'tactical' and 'Táctico (Sostener)' or 'Clásico (Auto)'
    local cmx, cmy, cmw, cmh = drawDropdown(settings, cx, cy + 104, cw, 'Modo Control', modeLabel)
    settings.g.controlModeDrop = {cmx, cmy, cmw, cmh, key = 'gameplay.controlMode'}
end

function settingsDraw.drawDropdownList(settings)
    local dd = settings.openDropdown
    if not dd then return end
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.18, 0.98)
    love.graphics.rectangle('fill', dd.x, dd.y, dd.w, dd.h, 6)
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.rectangle('line', dd.x, dd.y, dd.w, dd.h, 6)
    -- Items
    love.graphics.setFont(ui and ui.fontNormal or getFallbackFont(14))
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

function settingsDraw.drawToast(settings, w, h)
    local tw = 360
    local th = 40
    local tx = (w - tw) / 2
    local ty = h - 80
    if settings.toastError then
        love.graphics.setColor(0.5, 0.1, 0.1, 0.92)
    else
        love.graphics.setColor(0, 0, 0, 0.9)
    end
    love.graphics.rectangle('fill', tx, ty, tw, th, 8)
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    love.graphics.printf(settings.toastText or '', tx + 12, ty + 10, tw - 24, 'center')
end

return settingsDraw

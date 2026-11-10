local Widgets = {}
local ui = require('ui.ui')
Widgets.CYAN = {0, 0.94, 1.0}
Widgets.CYAN_DIM = {0, 0.55, 0.70}
Widgets.CYAN_DEEP = {0.02, 0.14, 0.18}
Widgets.BG_DARK = {0.05, 0.07, 0.11}
Widgets.BG_PANEL = {0.07, 0.09, 0.15}
Widgets.TRACK_BG = {0.10, 0.13, 0.18}
Widgets.WHITE = {1, 1, 1}
local CYAN = Widgets.CYAN
local TRACK_BG = Widgets.TRACK_BG
local fallbackFonts = {}
local function getFallbackFont(s)
    if not fallbackFonts[s] then fallbackFonts[s] = love.graphics.newFont(s) end
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
    local pw = math.min(560, math.floor(w * 0.78))
    local ph = math.min(440, h - 40)
    pw = math.max(320, math.min(pw, w - 16))
    ph = math.max(280, math.min(ph, h - 16))
    settings.PW = pw
    settings.PH = ph
    local px = math.floor((w - pw) / 2)
    local py = math.floor((h - ph) / 2)
    px = math.max(8, math.min(px, w - pw - 8))
    py = math.max(8, math.min(py, h - ph - 8))
    return px, py
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
    local wAvail = settings.PW and (settings.PW - 44) or 456
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + 2, wAvail - 60, 'left')
    local bx = x + wAvail - 36
    local by = y
    local bw, bh = 36, 20
    local mx, my = love.mouse.getPosition()
    local isHover = mx and my and hitTest(settings, mx, my, bx, by, bw, bh)
    local t = love.timer.getTime()
    if value then
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], isHover and 0.95 or 0.88)
        love.graphics.rectangle('fill', bx, by, bw, bh, 10)
        love.graphics.setColor(1, 1, 1, 0.18)
        love.graphics.rectangle('fill', bx + 2, by + 2, bw - 4, bh / 2 - 1, 8)
    else
        love.graphics.setColor(0.18, 0.20, 0.26, 1)
        love.graphics.rectangle('fill', bx, by, bw, bh, 10)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle('line', bx, by, bw, bh, 10)
    end
    if isHover then
        local pulse = 0.5 + math.sin(t * 6) * 0.25
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.22 * pulse)
        love.graphics.rectangle('line', bx - 2, by - 2, bw + 4, bh + 4, 12)
    end
    local thumbX = value and (bx + bw - 18) or (bx + 2)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.circle('fill', thumbX + 9, by + 10 + 1, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('fill', thumbX + 8, by + 10, 7.5)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.circle('fill', thumbX + 6, by + 8, 2.2)
    if value then
        love.graphics.setColor(0.02, 0.14, 0.18, 1)
        love.graphics.setLineWidth(1.8)
        love.graphics.line(thumbX + 5, by + 10, thumbX + 7.5, by + 13)
        love.graphics.line(thumbX + 7.5, by + 13, thumbX + 11.5, by + 7)
        love.graphics.setLineWidth(1)
    end
    return bx, by, bw, bh
end
local function drawSlider(settings, x, y, w, label, val)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + 2, 170, 'left')
    local badgeW = 44
    local bx = x + 176
    local bw = w - 176 - badgeW - 8
    if bw < 60 then bx = x + 140; bw = w - 140 - badgeW - 8 end
    local trackY = y + 8
    local trackH = 10
    love.graphics.setColor(TRACK_BG[1], TRACK_BG[2], TRACK_BG[3], 1)
    love.graphics.rectangle('fill', bx, trackY, bw, trackH, 5)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('line', bx, trackY, bw, trackH, 5)
    local fillW = math.floor(bw * math.max(0, math.min(1, val)))
    if fillW > 0 then
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 1)
        love.graphics.rectangle('fill', bx, trackY, fillW, trackH, 5)
        local gradW = math.min(fillW, 28)
        if gradW > 4 then
            love.graphics.setColor(1, 1, 1, 0.32)
            love.graphics.rectangle('fill', bx + fillW - gradW, trackY, gradW, trackH, 5)
        end
        love.graphics.setColor(1, 1, 1, 0.22)
        love.graphics.rectangle('fill', bx, trackY, fillW, trackH / 2, 5)
    end
    local kx = bx + bw * math.max(0, math.min(1, val))
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', kx - 7, trackY - 3 + 2, 14, 16, 7)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', kx - 7, trackY - 3, 14, 16, 7)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.85)
    love.graphics.rectangle('line', kx - 7, trackY - 3, 14, 16, 7)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.rectangle('fill', kx - 4, trackY - 1, 6, 3, 2)
    local badgeX = bx + bw + 8
    local badgeY = y + 2
    love.graphics.setColor(0.06, 0.14, 0.18, 0.96)
    love.graphics.rectangle('fill', badgeX, badgeY, badgeW, 18, 9)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.65)
    love.graphics.rectangle('line', badgeX, badgeY, badgeW, 18, 9)
    love.graphics.setColor(1, 1, 1)
    setFont('Small')
    local pct = math.floor(math.max(0, math.min(1, val)) * 100)
    love.graphics.printf(tostring(pct) .. '%', badgeX, badgeY + 3, badgeW, 'center')
    return bx, trackY - 3, bw, 16
end
local function drawDropdown(settings, x, y, w, label, valueLabel)
    setFont('Normal')
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + 2, 170, 'left')
    local bx = x + 176
    local bw = w - 176
    if bw < 80 then bx = x + 140; bw = w - 140 end
    local mx, my = love.mouse.getPosition()
    local isHover = mx and my and hitTest(settings, mx, my, bx, y, bw, 24)
    local isOpen = settings.openDropdown and settings.openDropdown.key and settings.openDropdown.x == bx and settings.openDropdown.y == y + 26
    if isHover or isOpen then love.graphics.setColor(0.16, 0.22, 0.30, 1) else love.graphics.setColor(0.13, 0.16, 0.22, 1) end
    love.graphics.rectangle('fill', bx, y, bw, 24, 6)
    if isHover or isOpen then
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.85)
        love.graphics.setLineWidth(1.5)
    else
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.32)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle('line', bx, y, bw, 24, 6)
    love.graphics.setLineWidth(1)
    if isHover then
        local t = love.timer.getTime()
        local pulse = 0.5 + math.sin(t * 5) * 0.3
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.16 * pulse)
        love.graphics.rectangle('line', bx - 1, y - 1, bw + 2, 26, 7)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(ui and ui.fontNormal or getFallbackFont(11))
    local str = tostring(valueLabel)
    love.graphics.printf(str, bx + 8, y + 5, bw - 28, 'left')
    local chevron = isOpen and '▴' or '▾'
    local cx = bx + bw - 18
    local offY = 0
    if isOpen then offY = math.sin(love.timer.getTime() * 8) * 0.7 end
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], isHover and 1 or 0.85)
    love.graphics.print(chevron, cx, y + 4 + offY)
    return bx, y, bw, 24
end
local function tablesEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do
        local bv = b[k]
        if type(v) == 'table' and type(bv) == 'table' then
            if not tablesEqual(v, bv) then return false end
        else
            if v ~= bv then return false end
        end
    end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function drawButton(settings, x, y, w, h, text, color)
    local mx, my = love.mouse.getPosition()
    local isHover = mx and my and hitTest(settings, mx, my, x, y, w, h)
    local isSave = (text == 'Guardar')
    local isDisabled = false
    if isSave and settings.editing and settings.lastSaved then isDisabled = tablesEqual(settings.editing, settings.lastSaved) end
    local yOff = (isHover and not isDisabled) and -2 or 0
    local drawY = y + yOff
    if not isDisabled then
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', x + 2, drawY + 3, w, h, 6)
    end
    if isHover and not isDisabled then
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.18)
        love.graphics.rectangle('fill', x - 3, drawY - 3, w + 6, h + 6, 8)
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.32)
        love.graphics.rectangle('line', x - 2, drawY - 2, w + 4, h + 4, 8)
    end
    if isDisabled then
        love.graphics.setColor(0.18, 0.20, 0.22, 1)
    else
        if color then love.graphics.setColor(unpack(color)) else love.graphics.setColor(0.08, 0.12, 0.18, 1) end
        if isHover and not isDisabled then love.graphics.setColor(0.10, 0.16, 0.24, 1) end
    end
    love.graphics.rectangle('fill', x, drawY, w, h, 6)
    if isDisabled then love.graphics.setColor(0.28, 0.30, 0.34, 0.9) else love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], isHover and 0.95 or 0.55) end
    love.graphics.setLineWidth(isHover and 1.6 or 1.1)
    love.graphics.rectangle('line', x, drawY, w, h, 6)
    love.graphics.setLineWidth(1)
    if not isDisabled then
        love.graphics.setColor(1, 1, 1, 0.10)
        love.graphics.rectangle('fill', x + 1, drawY + 1, w - 2, h / 2 - 1, 6)
    end
    love.graphics.setColor(isDisabled and {0.55, 0.58, 0.62} or {1, 1, 1})
    setFont('Normal')
    love.graphics.printf(text, x, drawY + (h - 12) / 2, w, 'center')
    return x, y, w, h
end
Widgets.getFallbackFont = getFallbackFont
Widgets.setFont = setFont
Widgets.panelXY = panelXY
Widgets.showToast = showToast
Widgets.hitTest = hitTest
Widgets.checkboxKeyPath = checkboxKeyPath
Widgets.setNested = setNested
Widgets.toggleCheckbox = toggleCheckbox
Widgets.drawCheckbox = drawCheckbox
Widgets.drawSlider = drawSlider
Widgets.drawDropdown = drawDropdown
Widgets.tablesEqual = tablesEqual
Widgets.drawButton = drawButton
return Widgets

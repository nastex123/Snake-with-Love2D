local settingsDraw = {}
local ui = require('ui.ui')
local Widgets = require('systems.settingsWidgets')
local CYAN = Widgets.CYAN
local CYAN_DIM = Widgets.CYAN_DIM
local CYAN_DEEP = Widgets.CYAN_DEEP
local BG_DARK = Widgets.BG_DARK
local BG_PANEL = Widgets.BG_PANEL
local TRACK_BG = Widgets.TRACK_BG
local WHITE = Widgets.WHITE
local getFallbackFont = Widgets.getFallbackFont
local setFont = Widgets.setFont

local panelXY = Widgets.panelXY
local showToast = Widgets.showToast
local hitTest = Widgets.hitTest
local checkboxKeyPath = Widgets.checkboxKeyPath
local setNested = Widgets.setNested
local toggleCheckbox = Widgets.toggleCheckbox

-- ============================================================
-- Controles rediseñados
-- ============================================================

local drawCheckbox = Widgets.drawCheckbox

local drawSlider = Widgets.drawSlider

local drawDropdown = Widgets.drawDropdown

local tablesEqual = Widgets.tablesEqual

local drawButton = Widgets.drawButton

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

-- Tabs helpers
function settingsDraw.drawAudioTab(settings, cx, cy, cw)
    -- Master volume slider
    local val = settings.editing.audio.master or 1.0
    local bx, by, bw, bh = drawSlider(settings, cx, cy, cw, 'Volumen Maestro', val)
    settings.g.masterSlider = {bx, by, bw}
    settings.g.masterVal = 'audio.master'
    -- checkboxes como toggles
    local mbx, mby, mbw, mbh = drawCheckbox(settings, cx, cy + 40, 'Música', settings.editing.audio.music)
    settings.g.musicBox = {mbx, mby, mbw, mbh, key = 'audio.music'}
    local sbx, sby, sbw, sbh = drawCheckbox(settings, cx, cy + 72, 'Efectos de sonido', settings.editing.audio.sfx)
    settings.g.sfxBox = {sbx, sby, sbw, sbh, key = 'audio.sfx'}
end

function settingsDraw.drawGraphicsTab(settings, cx, cy, cw)
    local ps = tostring(settings.editing.graphics.pixelScale or 2)
    local psx, psy, psw, psh = drawDropdown(settings, cx, cy, cw, 'Pixel Scale', ps)
    settings.g.pixelScaleDrop = {psx, psy, psw, psh, key = 'graphics.pixelScale'}

    local res = settings.editing.graphics.resolution
    local resLabel = res and (tostring(res.width) .. 'x' .. tostring(res.height)) or 'Auto'
    local rx, ry, rw, rh = drawDropdown(settings, cx, cy + 32, cw, 'Resolución', resLabel)
    settings.g.resolutionDrop = {rx, ry, rw, rh, key = 'graphics.resolution'}

    local fx, fy, fw, fh = drawDropdown(settings, cx, cy + 64, cw, 'Filtro', settings.editing.graphics.filter or 'nearest')
    settings.g.filterDrop = {fx, fy, fw, fh, key = 'graphics.filter'}

    local fsx, fsy, fsw, fsh = drawCheckbox(settings, cx, cy + 100, 'Pantalla completa', settings.editing.graphics.fullscreen)
    settings.g.fullscreenBox = {fsx, fsy, fsw, fsh, key = 'graphics.fullscreen'}

    local vx, vy, vw, vh = drawCheckbox(settings, cx, cy + 132, 'VSync', settings.editing.graphics.vsync)
    settings.g.vsyncBox = {vx, vy, vw, vh, key = 'graphics.vsync'}
end

function settingsDraw.drawAccessibilityTab(settings, cx, cy, cw)
    love.graphics.setColor(1, 1, 1)
    setFont('Normal')
    -- UI Scale slider (custom rango 0.8-1.5)
    local minS, maxS = 0.8, 1.5
    local val = settings.editing.accessibility.uiScale or 1.0
    local frac = (val - minS) / (maxS - minS)
    frac = math.max(0, math.min(1, frac))
    local bx, by, bw, bh = drawSlider(settings, cx, cy, cw, 'Escala UI', frac)
    -- sobrescribir badge con valor 1 decimal (drawSlider puso %)
    -- redibujar badge correcto
    local badgeW = 44
    local badgeX = bx + bw + 8
    local badgeY = cy + 2
    love.graphics.setColor(0.06, 0.14, 0.18, 0.96)
    love.graphics.rectangle('fill', badgeX, badgeY, badgeW, 18, 9)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.65)
    love.graphics.rectangle('line', badgeX, badgeY, badgeW, 18, 9)
    love.graphics.setColor(1, 1, 1)
    setFont('Small')
    love.graphics.printf(string.format('%.1f', val), badgeX, badgeY + 3, badgeW, 'center')
    settings.g.uiScaleSlider = {bx, by, bw}
    settings.g.uiScaleVal = 'accessibility.uiScale'

    local hx, hy, hw, hh = drawCheckbox(settings, cx, cy + 40, 'Alto contraste', settings.editing.accessibility.highContrast)
    settings.g.highContrastBox = {hx, hy, hw, hh, key = 'accessibility.highContrast'}

    local cbLabel = settings.editing.accessibility.colorblind or 'off'
    local cbx, cby, cbw, cbh = drawDropdown(settings, cx, cy + 72, cw, 'Daltonismo', cbLabel)
    settings.g.colorblindDrop = {cbx, cby, cbw, cbh, key = 'accessibility.colorblind'}
end

-- Dropdown list con clamp anti-overflow, flip y scrollbar + scissor
function settingsDraw.drawDropdownList(settings)
    local dd = settings.openDropdown
    if not dd then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local px, py = panelXY(settings)
    local panelBottom = py + settings.PH
    local neededH = dd.h
    local itemH = dd.itemH or 28
    -- medidas clamp: maxH = min(dd.h, panelBottom - dd.y -12, h - dd.y -16)
    local spaceBelowPanel = panelBottom - dd.y - 12
    local spaceBelowScreen = h - dd.y - 16
    local maxHBelow = math.min(neededH, spaceBelowPanel, spaceBelowScreen)
    maxHBelow = math.max(0, maxHBelow)
    local spaceAbovePanel = dd.y - (py + 8) - 4
    -- el ancla real del dropdown es by = dd.y - dd.itemH? dd.y = by+bh+2, así que by = dd.y - bh -2
    -- para flip usamos la posición del control (bx, by)
    local ctrlBy = dd.y - (itemH - 4) -- aprox bh+2, pero tenemos bh guardado? no, inferimos
    -- mejor recuperar bh del registro original: buscamos en settings.g
    local ctrlH = 24
    local anchorY = dd.y -- top de la lista
    local anchorX = dd.x
    local listW = dd.w
    -- clamp horizontal: no salirse del panel ni de pantalla por derecha
    local maxW = math.min(listW, (px + settings.PW - anchorX - 12))
    maxW = math.max(80, math.min(listW, w - anchorX - 16))
    -- si se sale por derecha, ajustar x
    local drawX = anchorX
    if drawX + maxW > w - 8 then drawX = w - maxW - 8 end
    if drawX + maxW > px + settings.PW - 8 then drawX = px + settings.PW - maxW - 8 end
    drawX = math.max(8, drawX)
    -- asegurar ancho respeta panel
    if maxW ~= listW then listW = maxW end

    local drawY = anchorY
    local visibleH = neededH
    local needScroll = false
    local scrollY = dd.scrollY or 0

    if neededH <= maxHBelow or maxHBelow == neededH then
        visibleH = neededH
        drawY = anchorY
    else
        -- intentar flip arriba
        local spaceAbove = anchorY - math.max(py + 8, 16) - 4
        -- posición flip: y = controlTop - neededH -4
        local ctrlTop = anchorY - ctrlH - 4 -- control top aprox
        -- intentar buscar control real para flip preciso
        -- si tenemos espacio arriba para todo, flip completo
        if neededH <= spaceAbove then
            drawY = ctrlTop - neededH
            visibleH = neededH
        else
            -- ninguno cabe completo: elegir el lado con más espacio
            if maxHBelow >= spaceAbove then
                visibleH = math.max(48, maxHBelow)
                drawY = anchorY
                needScroll = neededH > visibleH
            else
                visibleH = math.max(48, math.min(spaceAbove, neededH))
                -- flip con scroll
                needScroll = neededH > visibleH
                if needScroll then
                    drawY = math.max(py + 8, ctrlTop - visibleH)
                else
                    drawY = ctrlTop - visibleH
                end
            end
        end
    end

    -- clamp final visibleH a rango válido y dentro pantalla
    visibleH = math.max(28, math.min(visibleH, h - drawY - 8))
    visibleH = math.min(visibleH, neededH)
    -- si aún con scroll excede, forzar scroll
    if visibleH < neededH then needScroll = true end
    -- clamp scrollY
    local maxScroll = math.max(0, neededH - visibleH)
    scrollY = math.max(0, math.min(scrollY, maxScroll))
    dd.scrollY = scrollY
    dd._drawX = drawX
    dd._drawY = drawY
    dd._drawW = listW
    dd._drawH = neededH
    dd._visibleH = visibleH
    dd._needScroll = needScroll

    -- Background con borde doble cyber
    -- outer shadow
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', drawX + 2, drawY + 3, listW, visibleH, 8)
    -- panel
    love.graphics.setColor(0.07, 0.09, 0.14, 0.98)
    love.graphics.rectangle('fill', drawX, drawY, listW, visibleH, 8)
    -- borde outer negro 1px
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', drawX, drawY, listW, visibleH, 8)
    -- borde inner cyan glow 0.6
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.62)
    love.graphics.rectangle('line', drawX + 0.8, drawY + 0.8, listW - 1.6, visibleH - 1.6, 7)
    -- línea superior cyan glow sutil
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.38)
    love.graphics.rectangle('fill', drawX + 10, drawY, listW - 20, 1.5, 1)

    -- scissor para contenido con scroll
    local hasScissor = false
    if needScroll or visibleH < neededH then
        love.graphics.setScissor(drawX, drawY, listW, visibleH)
        hasScissor = true
    end

    love.graphics.setFont(ui and ui.fontNormal or getFallbackFont(11))
    for i, item in ipairs(dd.items) do
        local iy = drawY + (i - 1) * itemH - scrollY
        -- culling si fuera de visible (con scissor ya recorta, pero evita dibujar fuera)
        if iy + itemH >= drawY - itemH and iy <= drawY + visibleH then
            local isSel = (item.value == dd.current)
                or (type(item.value) == 'table' and type(dd.current) == 'table' and item.value.width == dd.current.width and item.value.height == dd.current.height)
            -- hover highlight
            local mx, my = love.mouse.getPosition()
            local isHover = mx and my and mx >= drawX and mx <= drawX + listW and my >= iy and my <= iy + itemH and my >= drawY and my <= drawY + visibleH
            if isSel then
                love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.22)
                love.graphics.rectangle('fill', drawX + 3, iy + 1, listW - 6, itemH - 2, 5)
                love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.95)
                love.graphics.rectangle('line', drawX + 3, iy + 1, listW - 6, itemH - 2, 5)
            elseif isHover then
                love.graphics.setColor(1, 1, 1, 0.07)
                love.graphics.rectangle('fill', drawX + 3, iy + 1, listW - 6, itemH - 2, 5)
            end
            love.graphics.setColor(isSel and CYAN or WHITE)
            if isSel then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.92, 0.94, 0.98, 1)
            end
            love.graphics.printf(item.label, drawX + 10, iy + 7, listW - 20, 'left')
            if isSel then
                love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 1)
                love.graphics.print('●', drawX + listW - 18, iy + 6)
            end
        end
    end
    if hasScissor then love.graphics.setScissor() end

    -- scrollbar si necesita scroll
    if needScroll and maxScroll > 0 then
        local trackX = drawX + listW - 6
        local trackY = drawY + 4
        local trackH = visibleH - 8
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', trackX, trackY, 4, trackH, 2)
        local thumbH = math.max(18, trackH * (visibleH / neededH))
        local thumbY = trackY + (trackH - thumbH) * (scrollY / maxScroll)
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.85)
        love.graphics.rectangle('fill', trackX, thumbY, 4, thumbH, 2)
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.rectangle('fill', trackX, thumbY, 4, 3, 2)
    end
    -- actualizar hitbox lógico para mousepressed mapping
    dd.x = drawX
    dd.y = drawY
    dd.w = listW
    dd.h = visibleH
    -- mantener referencia a totalH para cálculo de idx con scroll
    dd._totalH = neededH
end

-- Toast: badge cian con icono, slide desde abajo
function settingsDraw.drawToast(settings, w, h)
    local tw = 360
    local th = 40
    local tx = (w - tw) / 2
    local baseTy = h - 68
    -- animación slide desde abajo (últimos 0.3s de aparición)
    local slide = 0
    if settings.toastTimer > 2.2 then
        local p = (2.5 - settings.toastTimer) / 0.3 -- 0→1
        p = math.max(0, math.min(1, p))
        slide = (1 - p) * 22
    elseif settings.toastTimer < 0.32 then
        local p = settings.toastTimer / 0.32
        p = math.max(0, math.min(1, p))
        slide = (1 - p) * 14
    end
    local ty = baseTy + slide
    local alpha = 1
    if settings.toastTimer < 0.28 then alpha = settings.toastTimer / 0.28 end
    -- glow externo cyan
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.22 * alpha)
    love.graphics.rectangle('fill', tx - 3, ty - 3, tw + 6, th + 6, 12)
    -- fondo badge
    if settings.toastError then
        love.graphics.setColor(0.42, 0.08, 0.10, 0.96 * alpha)
    else
        love.graphics.setColor(0.04, 0.12, 0.16, 0.96 * alpha)
    end
    love.graphics.rectangle('fill', tx, ty, tw, th, 10)
    -- borde cyan
    love.graphics.setColor(settings.toastError and {0.9, 0.2, 0.2, 0.88 * alpha} or {CYAN[1], CYAN[2], CYAN[3], 0.88 * alpha})
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle('line', tx, ty, tw, th, 10)
    love.graphics.setLineWidth(1)
    -- icono circular cian
    local icon = settings.toastError and '✕' or '✓'
    local iconR = 13
    local ix = tx + 14 + iconR
    local iy = ty + th / 2
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], alpha)
    love.graphics.circle('fill', ix, iy, iconR)
    love.graphics.setColor(0, 0, 0, 0.9 * alpha)
    love.graphics.circle('fill', ix, iy, iconR - 1.5)
    love.graphics.setColor(1, 1, 1, alpha)
    setFont('Normal')
    local fw = love.graphics.getFont():getWidth(icon)
    local fh = love.graphics.getFont():getHeight()
    love.graphics.print(icon, ix - fw / 2, iy - fh / 2 + 1)
    -- texto
    love.graphics.setColor(1, 1, 1, alpha)
    setFont('Normal')
    love.graphics.printf(settings.toastText or '', tx + 36, ty + 12, tw - 48, 'center')
end

return settingsDraw

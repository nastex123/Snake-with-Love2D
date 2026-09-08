-- systems/shopDraw.lua — Cyberpunk Bio-Rack v3 Layout & UI Renderer (GDD §13)
-- Renderiza el Top Bar HUD, los 3 cartuchos en Rack izquierdo y el Chassis Loadout inferior en 640x360.
local shopDraw = {}
local constants = require("constants")
local tarotArtMod = require("systems.tarotArt")
local shopBioScanner = require("systems.shopBioScanner")

local cardRects = {}
local rerollRect = nil

local TIER_COLORS = {
    S = {1.0, 0.82, 0.24}, -- Oro
    A = {0.61, 0.36, 1.0},  -- Púrpura
    B = {0.0, 0.94, 1.0},   -- Cian
    C = {0.47, 0.50, 0.60}, -- Gris azulado
}

local function drawItemIcon(id, x, y, size)
    local half = size / 2
    if id == "shield" then
        love.graphics.setColor(0.0, 0.94, 1.0)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4)
        love.graphics.rectangle("fill", x + 4, y + 4, size - 8, size - 8)
    elseif id == "armor" then
        love.graphics.setColor(0.61, 0.36, 1.0)
        love.graphics.rectangle("line", x + 1, y + 1, size - 2, size - 2)
        love.graphics.rectangle("line", x + 4, y + 4, size - 8, size - 8)
    elseif id == "ghost" then
        love.graphics.setColor(0.6, 0.4, 1.0, 0.7)
        love.graphics.circle("fill", x + half, y + half, half - 2)
    elseif id == "magnet" then
        love.graphics.setColor(0.0, 0.94, 1.0)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4)
        love.graphics.setColor(0.0, 0.94, 1.0, 0.4)
        love.graphics.rectangle("fill", x + 4, y + 4, size - 8, size - 8)
    elseif id == "bomb" then
        love.graphics.setColor(1.0, 0.3, 0.2)
        love.graphics.circle("fill", x + half, y + half, half - 2)
    else
        love.graphics.setColor(1.0, 0.82, 0.24)
        local pts = {x + half, y + 1, x + size - 1, y + half, x + half, y + size - 1, x + 1, y + half}
        love.graphics.polygon("fill", pts)
    end
end

function shopDraw.getRects()
    return cardRects, rerollRect
end

function shopDraw.draw(shopData)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0

    local monedas = shopData.monedas or 0
    local displayCoins = shopData.displayCoins or monedas
    local stock = shopData.stock or {}
    local focusedStall = shopData.focusedStall or 1
    local purchaseFlash = shopData.purchaseFlash or {}
    local rcost = shopData.rerollCost or 5
    local openTimer = shopData.openTimer or 1
    local fontNormal = shopData.fontNormal
    local fontSmall = shopData.fontSmall
    local fontLarge = shopData.fontLarge
    local slots = shopData.slots or {nil, nil, nil}
    local passives = shopData.passives or {}
    local offerDefFn = shopData.offerDefFn

    local mx, my = love.mouse.getPosition()
    cardRects = {}

    -- 1. Fondo Cyber-Dark semitransparente con rejilla sutil
    love.graphics.setColor(0.03, 0.02, 0.06, 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.12, 0.10, 0.20, 0.4)
    for xg = 0, w, 20 do
        love.graphics.line(xg, 0, xg, h)
    end
    for yg = 0, h, 20 do
        love.graphics.line(0, yg, w, yg)
    end

    -- 2. Top Bar HUD (y = 6..30)
    love.graphics.setColor(0.06, 0.05, 0.12, 0.95)
    love.graphics.rectangle("fill", 10, 6, w - 20, 24, 3)
    love.graphics.setColor(0.0, 0.94, 1.0, 0.4)
    love.graphics.rectangle("line", 10, 6, w - 20, 24, 3)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.0, 0.94, 1.0)
    love.graphics.print("SNAKE // BIO-RACK v3", 18, 12)

    -- Monedas en el centro
    if fontNormal then love.graphics.setFont(fontNormal) end
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf("GOLD: $" .. math.floor(displayCoins + 0.5), 180, 10, 180, "center")

    -- Botón Purgar / Reroll
    local rbW, rbH = 130, 18
    local rbX, rbY = 380, 9
    rerollRect = {x = rbX, y = rbY, w = rbW, h = rbH}
    local rHover = mx >= rbX and mx <= rbX + rbW and my >= rbY and my <= rbY + rbH
    local rAfford = monedas >= rcost

    love.graphics.setColor(0.12, 0.08, 0.22, 0.95)
    love.graphics.rectangle("fill", rbX, rbY, rbW, rbH, 2)
    love.graphics.setColor(rAfford and (rHover and {1, 0.8, 0.2} or {0.61, 0.36, 1.0}) or {0.4, 0.4, 0.4})
    love.graphics.rectangle("line", rbX, rbY, rbW, rbH, 2)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(rAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
    love.graphics.printf("PURGAR (R): $" .. rcost, rbX, rbY + 3, rbW, "center")

    -- Indicador de sistema
    love.graphics.setColor(0.4, 0.5, 0.6)
    love.graphics.print("ONLINE // 60FPS", w - 130, 12)

    -- 3. Columna Izquierda: Bio-Rack Cartuchos (x = 10, w = 220, y = 34..246)
    local rackX = 10
    local rackY = 34
    local cardW = 220
    local cardH = 68
    local cardGap = 4

    for idx = 1, 3 do
        local offer = stock[idx]
        local def = offerDefFn and offerDefFn(offer)
        local cardY = rackY + (idx - 1) * (cardH + cardGap)

        local isFocused = (idx == focusedStall)
        local isHovered = (mx >= rackX and mx <= rackX + cardW and my >= cardY and my <= cardY + cardH)
        cardRects[idx] = {x = rackX, y = cardY, w = cardW, h = cardH}

        local sold = offer and offer.sold
        local affordable = offer and not sold and monedas >= (offer.price or 0)
        local info = def and shopBioScanner.getInfo(def.id) or {tier = "C"}
        local tierColor = TIER_COLORS[info.tier or "C"] or {0.0, 0.94, 1.0}

        -- Fondo del cartucho
        local bgA = isFocused and 0.95 or 0.8
        love.graphics.setColor(0.06, 0.05, 0.12, bgA)
        love.graphics.rectangle("fill", rackX, cardY, cardW, cardH, 3)

        -- Borde
        if sold then
            love.graphics.setColor(0.3, 0.8, 0.3, 0.6)
        elseif isFocused or (isHovered and affordable) then
            local pulse = (math.sin(time * 6) + 1) * 0.2 + 0.8
            love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], pulse)
        elseif affordable then
            love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.5)
        else
            love.graphics.setColor(0.3, 0.3, 0.35, 0.6)
        end
        love.graphics.setLineWidth(isFocused and 2 or 1)
        love.graphics.rectangle("line", rackX, cardY, cardW, cardH, 3)
        love.graphics.setLineWidth(1)

        -- Purchase flash overlay
        for i = #purchaseFlash, 1, -1 do
            if purchaseFlash[i].idx == idx then
                love.graphics.setColor(0.3, 0.9, 0.3, purchaseFlash[i].timer / 0.3 * 0.5)
                love.graphics.rectangle("fill", rackX, cardY, cardW, cardH, 3)
            end
        end

        if not offer or not def then
            if fontNormal then love.graphics.setFont(fontNormal) end
            love.graphics.setColor(0.4, 0.4, 0.45)
            love.graphics.printf("VACIO", rackX, cardY + 24, cardW, "center")
        else
            -- Header de cartucho: Slot [1] + Tipo + Tier Badge
            if fontSmall then love.graphics.setFont(fontSmall) end
            love.graphics.setColor(0.0, 0.94, 1.0, 0.9)
            love.graphics.print("[" .. idx .. "]", rackX + 6, cardY + 5)

            love.graphics.setColor(offer.kind == "tarot" and {0.61, 0.36, 1.0} or {0.5, 0.6, 0.7})
            love.graphics.print(offer.kind == "tarot" and "TAROT" or "ITEM", rackX + 30, cardY + 5)

            love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.9)
            love.graphics.print("TIER " .. (info.tier or "C"), rackX + cardW - 52, cardY + 5)

            -- Icono / Arte de la carta
            if offer.kind == "tarot" then
                tarotArtMod.draw(offer.id, rackX + 6, cardY + 20, 36)
            else
                drawItemIcon(def.icon or def.id, rackX + 8, cardY + 22, 32)
            end

            -- Nombre y mini-stat/resumen
            if fontNormal then love.graphics.setFont(fontNormal) end
            love.graphics.setColor(sold and {0.5, 0.5, 0.5} or {1, 1, 1})
            love.graphics.print(def.name or def.id, rackX + 48, cardY + 20)

            if fontSmall then love.graphics.setFont(fontSmall) end
            if sold then
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.print("/// INSTALADO ///", rackX + 48, cardY + 38)
            else
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
                love.graphics.print("$" .. (offer.price or 0), rackX + 48, cardY + 38)

                love.graphics.setColor(isFocused and {0.0, 0.94, 1.0} or {0.45, 0.5, 0.6})
                local actText = isFocused and "ENTER -> INSTALAR" or "VER DETALLES"
                love.graphics.printf(actText, rackX + 110, cardY + 40, cardW - 116, "right")
            end
        end
    end

    -- 4. Columna Derecha: Holographic Bio-Scanner (x = 236, y = 34, w = 394, h = 212)
    local scanX = 236
    local scanY = 34
    local scanW = w - scanX - 10
    local scanH = 212
    local curOffer = stock[focusedStall]
    local curDef = offerDefFn and offerDefFn(curOffer)
    shopBioScanner.draw(curOffer, curDef, scanX, scanY, scanW, scanH, fontNormal, fontSmall, fontLarge)

    -- 5. Panel Inferior: Loadout / Chassis (x = 10, y = 252, w = 620, h = 80)
    local botX = 10
    local botY = 252
    local botW = w - 20
    local botH = 80

    love.graphics.setColor(0.04, 0.03, 0.08, 0.95)
    love.graphics.rectangle("fill", botX, botY, botW, botH, 3)
    love.graphics.setColor(0.2, 0.18, 0.3, 0.8)
    love.graphics.rectangle("line", botX, botY, botW, botH, 3)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.0, 0.94, 1.0)
    love.graphics.print("CHASSIS ACTIVE SOCKETS", botX + 8, botY + 6)

    -- 3 Active Slots
    for si = 1, 3 do
        local sx = botX + 8 + (si - 1) * 88
        local sy = botY + 22
        local sw = 82
        local sh = 34
        local itemId = slots[si]

        love.graphics.setColor(0.08, 0.06, 0.14)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 2)
        love.graphics.setColor(itemId and {0.0, 0.94, 1.0, 0.8} or {0.2, 0.18, 0.28, 0.6})
        love.graphics.rectangle("line", sx, sy, sw, sh, 2)

        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
        love.graphics.print("[" .. si .. "]", sx + 4, sy + 3)

        if itemId then
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(itemId, sx + 20, sy + 10, sw - 24, "left")
        else
            love.graphics.setColor(0.35, 0.4, 0.45)
            love.graphics.printf("EMPTY", sx + 20, sy + 10, sw - 24, "left")
        end
    end

    -- Passive Matrix
    local pX = botX + 280
    love.graphics.setColor(0.61, 0.36, 1.0)
    love.graphics.print("PASSIVE MATRIX", pX, botY + 6)

    local pCount = 0
    for key, val in pairs(passives) do
        if val == true then
            pCount = pCount + 1
            if pCount <= 3 then
                local px = pX + (pCount - 1) * 105
                local py = botY + 22
                love.graphics.setColor(0.10, 0.08, 0.18)
                love.graphics.rectangle("fill", px, py, 100, 34, 2)
                love.graphics.setColor(0.61, 0.36, 1.0, 0.7)
                love.graphics.rectangle("line", px, py, 100, 34, 2)
                love.graphics.setColor(0.85, 0.75, 1.0)
                love.graphics.printf(key, px + 4, py + 10, 92, "center")
            end
        end
    end
    if pCount == 0 then
        love.graphics.setColor(0.35, 0.35, 0.45)
        love.graphics.print("SIN PASIVAS ACTIVAS", pX, botY + 30)
    end

    -- 6. Footer de Controles Arcade (y = 338..354)
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.5, 0.55, 0.65)
    love.graphics.printf("[1-3] COMPRAR / SELECCIONAR    [R] REROLL    [ESPACIO/ENTER] DESCENDER AL MAZE    [ESC] SALIR", 0, h - 18, w, "center")
end

return shopDraw

-- systems/shopDraw.lua — Gothic Altar Shrine UI & Layout Renderer (GDD §13 / Propuesta C)
-- Renderiza la Bóveda de la Cripta, las 3 Hornacinas con Arcos Ojivales y los dos contenedores inferiores con escalado adaptativo (Opción A).
local shopDraw = {}
local constants = require("constants")
local tarotArtMod = require("systems.tarotArt")
local shopBioScanner = require("systems.shopBioScanner")

local cardRects = {}
local rerollRect = nil
local currentScale = 1.0
local currentOffsetX = 0
local currentOffsetY = 0

local TIER_COLORS = {
    S = {1.0, 0.82, 0.25}, -- Oro sacro
    A = {0.68, 0.38, 1.0},  -- Púrpura relicario
    B = {0.25, 0.75, 1.0},  -- Azul vidriera
    C = {0.65, 0.65, 0.75}, -- Plata de cripta
}

local function drawRelicIcon(id, x, y, size)
    local half = size / 2
    if id == "shield" then
        love.graphics.setColor(0.25, 0.75, 1.0)
        local pts = {x + 3, y + 2, x + size - 3, y + 2, x + size - 5, y + size - 8, x + half, y + size - 2, x + 5, y + size - 8}
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", pts)
        love.graphics.line(x + half, y + 4, x + half, y + size - 5)
        love.graphics.line(x + 6, y + half - 2, x + size - 6, y + half - 2)
    elseif id == "armor" then
        love.graphics.setColor(0.68, 0.38, 1.0)
        love.graphics.rectangle("fill", x + 3, y + 3, size - 6, size - 6, 2)
        love.graphics.setColor(1.0, 0.82, 0.25)
        love.graphics.rectangle("line", x + 3, y + 3, size - 6, size - 6, 2)
        love.graphics.circle("fill", x + half, y + half, 3)
    elseif id == "ghost" then
        love.graphics.setColor(0.7, 0.45, 1.0, 0.75)
        love.graphics.circle("fill", x + half, y + half - 2, half - 3)
        love.graphics.setColor(0.1, 0.05, 0.2)
        love.graphics.circle("fill", x + half - 4, y + half - 3, 2)
        love.graphics.circle("fill", x + half + 4, y + half - 3, 2)
    elseif id == "magnet" then
        love.graphics.setColor(1.0, 0.82, 0.25)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", x + half, y + half + 2, half - 4, math.pi, 2 * math.pi)
        love.graphics.line(x + 4, y + half + 2, x + 4, y + size - 4)
        love.graphics.line(x + size - 4, y + half + 2, x + size - 4, y + size - 4)
        love.graphics.setLineWidth(1)
    elseif id == "bomb" then
        love.graphics.setColor(0.9, 0.3, 0.15)
        love.graphics.circle("fill", x + half, y + half + 2, half - 4)
        love.graphics.setColor(1.0, 0.85, 0.2)
        love.graphics.rectangle("fill", x + half - 2, y + 2, 4, 6)
    else
        love.graphics.setColor(1.0, 0.82, 0.25)
        local pts = {x + half, y + 2, x + size - 2, y + half, x + half, y + size - 2, x + 2, y + half}
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(0.1, 0.08, 0.15)
        love.graphics.circle("fill", x + half, y + half, 2)
    end
end

function shopDraw.getRects()
    return cardRects, rerollRect, currentScale, currentOffsetX, currentOffsetY
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
    local fontNormal = shopData.fontNormal
    local fontSmall = shopData.fontSmall
    local fontLarge = shopData.fontLarge
    local slots = shopData.slots or {nil, nil, nil}
    local passives = shopData.passives or {}
    local offerDefFn = shopData.offerDefFn

    -- 1. Fondo completo de Lajas de Cripta Subterránea
    love.graphics.setColor(0.04, 0.03, 0.07, 0.96)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.12, 0.10, 0.18, 0.5)
    for yg = 0, h, 28 do
        love.graphics.line(0, yg, w, yg)
        local offset = (math.floor(yg / 28) % 2 == 0) and 0 or 32
        for xg = offset, w, 64 do
            love.graphics.line(xg, yg, xg, yg + 28)
        end
    end

    -- Viñeta de antorchas cálidas en esquinas
    local torchA = (math.sin(time * 3.5) + 1) * 0.03 + 0.06
    love.graphics.setColor(0.9, 0.45, 0.1, torchA)
    love.graphics.circle("fill", 20, 20, 100)
    love.graphics.circle("fill", w - 20, 20, 100)

    -- ESCALADO ADAPTATIVO CON CONTROL MANUAL (core/config.lua -> SHOP_MANUAL_SCALE)
    -- Contenedor virtual base: 600 de ancho x 342 de alto (incluye top bar, cards, containers y pie de mandatos)
    local containerW = 600
    local containerH = 344
    local safeMargin = 16 -- Margen de seguridad para respetar la curvatura CRT de bordes de pantalla

    local availW = math.max(200, w - safeMargin * 2)
    local availH = math.max(200, h - safeMargin * 2)
    local autoScale = math.min(availW / containerW, availH / containerH)
    if autoScale < 0.75 then autoScale = 0.75 end

    -- Factor manual (1.0 = automático adaptado a pantalla con márgenes seguros)
    local manualFactor = tonumber(constants.SHOP_MANUAL_SCALE) or 1.0
    local scale = autoScale * manualFactor
    currentScale = scale

    local scaledW = containerW * scale
    local scaledH = containerH * scale

    local offsetX = math.floor((w - scaledW) / 2)
    local offsetY = math.floor((h - scaledH) / 2)
    currentOffsetX = offsetX
    currentOffsetY = offsetY

    -- Coordenadas de ratón en espacio virtual escalado
    local okInp, Input = pcall(require, "core.input")
    local rawMx, rawMy
    if okInp and Input and Input.getMousePosition then
        rawMx, rawMy = Input.getMousePosition()
    else
        rawMx, rawMy = love.mouse.getPosition()
    end
    local mx = (rawMx - offsetX) / scale
    local my = (rawMy - offsetY) / scale

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    cardRects = {}
    local startX = 0
    local startY = 0

    -- 2. Dintel Superior — Bóveda de Cripta
    local topBarX = startX
    local topBarY = startY
    local topBarW = containerW
    local topBarH = 24

    love.graphics.setColor(0.08, 0.06, 0.12, 0.95)
    love.graphics.rectangle("fill", topBarX, topBarY, topBarW, topBarH, 2)
    love.graphics.setColor(0.35, 0.28, 0.48, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", topBarX, topBarY, topBarW, topBarH, 2)

    -- Tributo en Oro a la izquierda
    if fontNormal then love.graphics.setFont(fontNormal) end
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.print("✝ TRIBUTO: $" .. math.floor(displayCoins + 0.5), topBarX + 12, topBarY + 5)

    -- Botón de Reroll a la derecha
    local rbW, rbH = 144, 18
    local rbX, rbY = topBarX + topBarW - rbW - 4, topBarY + 3
    rerollRect = {x = rbX, y = rbY, w = rbW, h = rbH}
    local rHover = mx >= rbX and mx <= rbX + rbW and my >= rbY and my <= rbY + rbH
    local rAfford = monedas >= rcost

    love.graphics.setColor(0.18, 0.08, 0.14, 0.95)
    love.graphics.rectangle("fill", rbX, rbY, rbW, rbH, 2)
    love.graphics.setColor(rAfford and (rHover and {1.0, 0.85, 0.3} or {0.85, 0.55, 0.2}) or {0.4, 0.35, 0.4})
    love.graphics.rectangle("line", rbX, rbY, rbW, rbH, 2)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(rAfford and {1.0, 0.95, 0.85} or {0.5, 0.45, 0.5})
    love.graphics.printf("OFRENDA (R): $" .. rcost, rbX, rbY + 3, rbW, "center")

    -- 3. Columna Izquierda: Tres Hornacinas con Arcos Ojivales
    local rackX = startX
    local rackY = topBarY + topBarH + 4
    local cardW = 210
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
        local tierColor = TIER_COLORS[info.tier or "C"] or {1.0, 0.82, 0.25}

        love.graphics.setColor(0.07, 0.05, 0.10, isFocused and 0.98 or 0.85)
        love.graphics.rectangle("fill", rackX, cardY, cardW, cardH, 2)

        love.graphics.setColor(sold and {0.3, 0.75, 0.3, 0.7} or (isFocused and tierColor or {0.28, 0.22, 0.36, 0.8}))
        love.graphics.setLineWidth(isFocused and 2 or 1)
        love.graphics.rectangle("line", rackX, cardY, cardW, cardH, 2)

        love.graphics.line(rackX + 4, cardY + 10, rackX + 10, cardY + 4)
        love.graphics.line(rackX + cardW - 4, cardY + 10, rackX + cardW - 10, cardY + 4)
        love.graphics.setLineWidth(1)

        for i = #purchaseFlash, 1, -1 do
            if purchaseFlash[i].idx == idx then
                love.graphics.setColor(0.9, 0.8, 0.3, purchaseFlash[i].timer / 0.3 * 0.5)
                love.graphics.rectangle("fill", rackX, cardY, cardW, cardH, 2)
            end
        end

        if not offer or not def then
            if fontNormal then love.graphics.setFont(fontNormal) end
            love.graphics.setColor(0.4, 0.38, 0.48)
            love.graphics.printf("ALTAR VACIO", rackX, cardY + 24, cardW, "center")
        else
            if fontSmall then love.graphics.setFont(fontSmall) end
            love.graphics.setColor(1.0, 0.82, 0.25, 0.9)
            love.graphics.print("[" .. idx .. "]", rackX + 6, cardY + 5)

            love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.95)
            love.graphics.print("TIER " .. (info.tier or "C"), rackX + cardW - 50, cardY + 5)

            -- Textura / Icono arriba a la izquierda
            local iconBoxX = rackX + 6
            local iconBoxY = cardY + 18
            if offer.kind == "tarot" then
                love.graphics.setColor(0.3, 0.25, 0.4, 0.8)
                love.graphics.rectangle("fill", iconBoxX, iconBoxY, 34, 32, 1)
                love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.7)
                love.graphics.rectangle("line", iconBoxX, iconBoxY, 34, 32, 1)
                tarotArtMod.draw(offer.id, iconBoxX + 3, iconBoxY + 2, 28)
            else
                drawRelicIcon(def.icon or def.id, iconBoxX + 3, iconBoxY + 2, 28)
            end

            -- Tipo de Item DEBAJO de la textura
            if fontSmall then love.graphics.setFont(fontSmall) end
            love.graphics.setColor(offer.kind == "tarot" and {0.75, 0.45, 1.0} or {0.6, 0.65, 0.75})
            local typeLabel = offer.kind == "tarot" and "TAROT" or "ITEM"
            love.graphics.printf(typeLabel, iconBoxX - 2, cardY + 53, 38, "center")

            -- Nombre del ítem / Tarot a la derecha de la textura
            local nameStr = def.name or def.id
            local textW = cardW - 48
            if #nameStr > 11 then
                if fontSmall then love.graphics.setFont(fontSmall) end
                love.graphics.setColor(sold and {0.5, 0.48, 0.55} or {1, 0.98, 0.92})
                love.graphics.printf(nameStr, rackX + 44, cardY + 18, textW, "left")
            else
                if fontNormal then love.graphics.setFont(fontNormal) end
                love.graphics.setColor(sold and {0.5, 0.48, 0.55} or {1, 0.98, 0.92})
                love.graphics.printf(nameStr, rackX + 44, cardY + 16, textW, "left")
            end

            -- Precio y botón de acción
            if fontSmall then love.graphics.setFont(fontSmall) end
            if sold then
                love.graphics.setColor(0.35, 0.8, 0.35)
                love.graphics.print("/// CONSAGRADO ///", rackX + 44, cardY + 48)
            else
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
                love.graphics.print("$" .. (offer.price or 0) .. " ORO", rackX + 44, cardY + 48)

                love.graphics.setColor(isFocused and {1.0, 0.82, 0.25} or {0.5, 0.48, 0.6})
                local actText = isFocused and "ENTER -> COMPRA" or "ELEGIR"
                love.graphics.printf(actText, rackX + 96, cardY + 48, cardW - 100, "right")
            end
        end
    end

    -- 4. Columna Derecha: Retablo Mayor & Espina del Dragón
    local scanX = rackX + cardW + 6
    local scanY = rackY
    local scanW = containerW - cardW - 6
    local scanH = 212
    local curOffer = stock[focusedStall]
    local curDef = offerDefFn and offerDefFn(curOffer)
    shopBioScanner.draw(curOffer, curDef, scanX, scanY, scanW, scanH, fontNormal, fontSmall, fontLarge)

    -- 5. Panel Inferior: Dos Contenedores Claramente Separados (Cálices y Sellos)
    local botY = rackY + scanH + 4
    local botH = 80
    local gapContainers = 8
    local calicesW = 296
    local sellosW = containerW - calicesW - gapContainers

    -- Contenedor 1 (Izquierda): Cálices de Poder Activo
    local calicesX = startX
    love.graphics.setColor(0.06, 0.05, 0.09, 0.96)
    love.graphics.rectangle("fill", calicesX, botY, calicesW, botH, 2)
    love.graphics.setColor(0.3, 0.24, 0.42, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", calicesX, botY, calicesW, botH, 2)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(1.0, 0.82, 0.25)
    love.graphics.print("CÁLICES DE PODER ACTIVO", calicesX + 8, botY + 6)

    for si = 1, 3 do
        local sx = calicesX + 8 + (si - 1) * 94
        local sy = botY + 22
        local sw = 88
        local sh = 48
        local itemId = slots[si]

        love.graphics.setColor(0.10, 0.08, 0.15)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 2)
        love.graphics.setColor(itemId and {1.0, 0.82, 0.25, 0.85} or {0.25, 0.22, 0.32, 0.6})
        love.graphics.rectangle("line", sx, sy, sw, sh, 2)

        local romanSlots = {"[I]", "[II]", "[III]"}
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
        love.graphics.print(romanSlots[si], sx + 4, sy + 3)

        if itemId then
            drawRelicIcon(itemId, sx + 32, sy + 4, 22)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(itemId, sx + 2, sy + 30, sw - 4, "center")
        else
            love.graphics.setColor(0.45, 0.42, 0.5)
            love.graphics.printf("VACÍO", sx + 2, sy + 22, sw - 4, "center")
        end
    end

    -- Contenedor 2 (Derecha): Sellos y Arcanos Activos
    local sellosX = calicesX + calicesW + gapContainers
    love.graphics.setColor(0.06, 0.05, 0.09, 0.96)
    love.graphics.rectangle("fill", sellosX, botY, sellosW, botH, 2)
    love.graphics.setColor(0.3, 0.24, 0.42, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sellosX, botY, sellosW, botH, 2)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.75, 0.45, 1.0)
    love.graphics.print("SELLOS Y ARCANOS ACTIVOS", sellosX + 8, botY + 6)

    local pCount = 0
    for key, val in pairs(passives) do
        if val == true then
            pCount = pCount + 1
            if pCount <= 3 then
                local px = sellosX + 8 + (pCount - 1) * 92
                local py = botY + 22
                local pw = 86
                local ph = 48

                love.graphics.setColor(0.14, 0.10, 0.20)
                love.graphics.rectangle("fill", px, py, pw, ph, 2)
                love.graphics.setColor(0.75, 0.45, 1.0, 0.7)
                love.graphics.rectangle("line", px, py, pw, ph, 2)

                love.graphics.setColor(0.92, 0.85, 1.0)
                love.graphics.printf(key, px + 2, py + 16, pw - 4, "center")
            end
        end
    end
    if pCount == 0 then
        love.graphics.setColor(0.45, 0.42, 0.5)
        love.graphics.print("NINGÚN SELLO GRABADO", sellosX + 12, botY + 34)
    end

    -- 6. Pie Sacro de Mandatos
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.65, 0.62, 0.72)
    love.graphics.printf("[1-3] OFRENDAR / SELECCIONAR    [R] PLEGARIA/REROLL    [ESPACIO/ENTER] DESCENDER AL CALABOZO    [ESC] RETROCEDER", 0, botY + botH + 6, containerW, "center")

    love.graphics.pop()
end

return shopDraw

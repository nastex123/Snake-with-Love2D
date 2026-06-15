local shop = {}
local constants = require("constants")
local items = require("items")

shop.slots = {nil, nil, nil}

shop.inventory = {
    speedReducer = false, extraCoin = false
}

shop.magnetTimer = 0
shop.shieldActive = false

local fontNormal, fontSmall, fontLarge
local page = 1
local openTimer = 0
local displayCoins = 0
local purchaseFlash = {}
local totalPages

-- Build pages from items registry (3 per page)
local pageItems = {}
do
    local flat = {}
    for _, def in ipairs(items.pages) do
        table.insert(flat, def)
    end
    for i = 1, #flat, 3 do
        table.insert(pageItems, {flat[i], flat[i+1], flat[i+2]})
    end
    totalPages = #pageItems
end

function shop.loadFonts()
    local ok, err = pcall(function()
        fontLarge = love.graphics.newFont(constants.FONT_FILE, constants.FONT_LARGE)
        fontNormal = love.graphics.newFont(constants.FONT_FILE, constants.FONT_NORMAL)
        fontSmall = love.graphics.newFont(constants.FONT_FILE, constants.FONT_SMALL)
    end)
    if not ok then
        fontLarge = love.graphics.newFont(constants.FONT_LARGE)
        fontNormal = love.graphics.newFont(constants.FONT_NORMAL)
        fontSmall = love.graphics.newFont(constants.FONT_SMALL)
    end
end

local CARD_W = 220
local CARD_H = 100
local CARD_GAP = 10

local cardRects = {}

local function drawIcon(id, x, y, size)
    local half = size / 2
    if id == "shield" then
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 3, y + 3, size - 6, size - 6)
        love.graphics.rectangle("fill", x + 5, y + 5, size - 10, size - 10)
    elseif id == "armor" then
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4)
        love.graphics.rectangle("line", x + 5, y + 5, size - 10, size - 10)
    elseif id == "ghost" then
        love.graphics.setColor(0.6, 0.4, 1, 0.6)
        love.graphics.circle("fill", x + half, y + half, half - 2)
        love.graphics.setColor(0.6, 0.4, 1)
        love.graphics.circle("line", x + half, y + half, half - 2)
    elseif id == "magnet" then
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4)
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
        love.graphics.rectangle("fill", x + 5, y + 5, size - 10, size - 10)
    elseif id == "bomb" then
        love.graphics.setColor(1, 0.4, 0.2)
        love.graphics.circle("fill", x + half, y + half, half - 2)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("fill", x + half - 2, y + half - 2, 3)
    elseif id == "hunger" then
        love.graphics.setColor(1, 0.6, 0.2)
        local pts = {x + half, y + 2,  x + 2, y + size - 2,  x + size - 2, y + size - 2}
        love.graphics.polygon("fill", pts)
    elseif id == "speed" then
        love.graphics.setColor(constants.COLOR_GREEN[1], constants.COLOR_GREEN[2], constants.COLOR_GREEN[3])
        local pts = {x + half, y + 2,  x + 2, y + size - 2,  x + size - 2, y + size - 2}
        love.graphics.polygon("fill", pts)
    elseif id == "turbo" then
        love.graphics.setColor(0, 1, 0.5)
        local pts = {x + half, y + 2,  x + size - 2, y + half,  x + half, y + size - 2,  x + 2, y + half}
        love.graphics.polygon("fill", pts)
    elseif id == "slow" then
        love.graphics.setColor(0.5, 0.5, 1)
        love.graphics.circle("line", x + half, y + half, half - 2)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + half, y + half, x + half, y + 4)
        love.graphics.line(x + half, y + half, x + size - 4, y + half)
        love.graphics.setLineWidth(1)
    elseif id == "doubler" then
        love.graphics.setColor(1, 0.84, 0)
        love.graphics.circle("fill", x + half, y + half, half - 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("x2", x + half - 8, y + half - 6)
    elseif id == "extraCoin" then
        love.graphics.setColor(1, 0.84, 0)
        love.graphics.circle("fill", x + half, y + half, half - 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", x + half, y + half, 2)
    elseif id == "star" then
        love.graphics.setColor(1, 0.84, 0)
        local pts = {}
        for i = 0, 9 do
            local angle = math.pi / 2 - i * math.pi * 2 / 10
            local r = i % 2 == 0 and half - 1 or (half - 1) * 0.4
            table.insert(pts, x + half + math.cos(angle) * r)
            table.insert(pts, y + half - math.sin(angle) * r)
        end
        love.graphics.polygon("fill", pts)
    end
end

function shop.draw(monedas, velocidadActual)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local time = love.timer.getTime()

    -- semitransparente para ver el fondo animado
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local fontNormal = fontNormal or love.graphics.newFont(constants.FONT_NORMAL)
    local fontSmall = fontSmall or love.graphics.newFont(constants.FONT_SMALL)
    local fontLarge = fontLarge or love.graphics.newFont(constants.FONT_LARGE)

    love.graphics.setFont(fontLarge)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("T I E N D A", 0, 15, w, "center")

    displayCoins = displayCoins + (monedas - displayCoins) * 0.1
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf("MONEDAS: " .. math.floor(displayCoins + 0.5), 0, 42, w, "center")

    -- paginacion
    local mx, my = love.mouse.getPosition()
    cardRects = {}

    local currentItems = pageItems[page]
    if not currentItems then return end

    local totalW = CARD_W + CARD_GAP
    local startX = (w - totalW) / 2
    local gridStartY = 70

    -- animacion de entrada
    if openTimer < 1 then
        openTimer = openTimer + 0.03
    end

    for idx, def in ipairs(currentItems) do
        local cardY = gridStartY + (idx - 1) * (CARD_H + CARD_GAP)
        local entryDelay = (page - 1) * #pageItems[1] + idx
        local entryFrac = math.min(1, math.max(0, (openTimer - entryDelay * 0.06) / 0.3))
        local eased = entryFrac * entryFrac * (3 - 2 * entryFrac)
        local drawY = cardY + (1 - eased) * 40

        cardRects[#cardRects + 1] = {x = startX, y = drawY, w = CARD_W, h = CARD_H, item = def}

        local own = shop.isOwned(def.id)
        local affordable = monedas >= def.cost
        local hovered = mx >= startX and mx <= startX + CARD_W and my >= drawY and my <= drawY + CARD_H

        -- card bg
        love.graphics.setColor(constants.COLOR_PANEL[1], constants.COLOR_PANEL[2], constants.COLOR_PANEL[3], constants.COLOR_PANEL[4] * (0.5 + eased * 0.5))
        love.graphics.rectangle("fill", startX, drawY, CARD_W, CARD_H, 4)

        -- borde
        local borderAlpha
        if own then
            borderAlpha = 0.3
            love.graphics.setColor(0.3, 0.8, 0.3, 0.4)
        elseif hovered and affordable then
            local pulse = math.sin(time * 4) * 0.3 + 0.7
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pulse)
            love.graphics.setLineWidth(2)
        elseif affordable then
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
            love.graphics.setLineWidth(1)
        else
            borderAlpha = 0.3
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", startX, drawY, CARD_W, CARD_H, 4)
        love.graphics.setLineWidth(1)

        -- purchase flash
        for i = #purchaseFlash, 1, -1 do
            local pf = purchaseFlash[i]
            if pf.idx == (page - 1) * #currentItems + idx then
                love.graphics.setColor(0.3, 0.9, 0.3, pf.timer / 0.3 * 0.4)
                love.graphics.rectangle("fill", startX, drawY, CARD_W, CARD_H, 4)
            end
        end

        -- icono
        local iconSize = 28
        local iconX = startX + 10
        local iconY = drawY + (CARD_H - iconSize) / 2
        drawIcon(def.icon, iconX, iconY, iconSize)

        -- texto
        local textX = iconX + iconSize + 12
        local textColor = {1, 1, 1}
        if own then
            textColor = {0.4, 0.4, 0.4}
        elseif not affordable then
            textColor = {0.5, 0.5, 0.5}
        end

        love.graphics.setFont(fontNormal)
        love.graphics.setColor(textColor[1], textColor[2], textColor[3])
        love.graphics.print(def.name, textX, drawY + 12)

        love.graphics.setFont(fontSmall)
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], 0.7)
        love.graphics.print(def.desc, textX, drawY + 34)
        love.graphics.print(def.desc2, textX, drawY + 46)

        love.graphics.setFont(fontNormal)
        if own then
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.print("ADQUIRIDO", textX, drawY + 68)
        else
            love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
            love.graphics.print(def.cost .. " monedas", textX, drawY + 68)
        end
    end

    -- pie: controles + paginacion
    local footerY = h - 60
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("A/D - PAGINA    ESPACIO - CONTINUAR    ESC - SALIR", 0, footerY, w, "center")

    -- indicador de pagina
    love.graphics.setFont(fontNormal)
    for p = 1, totalPages do
        local px = w / 2 - (totalPages * 12) / 2 + (p - 1) * 12
        if p == page then
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", px, footerY + 16, 3)
    end
end

function shop.abrir(monedas)
    shop.loadFonts()
    openTimer = 0
    displayCoins = monedas
end

function shop.update(dt)
    for i = #purchaseFlash, 1, -1 do
        purchaseFlash[i].timer = purchaseFlash[i].timer - dt
        if purchaseFlash[i].timer <= 0 then
            table.remove(purchaseFlash, i)
        end
    end
end

function shop.keypressed(tecla, monedas)
    if tecla == "a" or tecla == "left" then
        page = ((page - 2 + totalPages) % totalPages) + 1
        openTimer = 0
        return nil
    elseif tecla == "d" or tecla == "right" then
        page = (page % totalPages) + 1
        openTimer = 0
        return nil
    end

    if tecla == "space" or tecla == "return" or tecla == "kpenter" then
        return "continue"
    elseif tecla == "escape" then
        return "exit"
    end

    -- teclas 1-3 para items de la pagina actual
    local num = tonumber(tecla)
    if num and num >= 1 and num <= 3 then
        local currentItems = pageItems[page]
        if currentItems and currentItems[num] then
            local result = shop.procesarCompra(monedas, currentItems[num].id, currentItems[num].cost)
            if result then
                table.insert(purchaseFlash, {idx = (page - 1) * 3 + num, timer = 0.3})
            end
            return result
        end
    end

    return nil
end

function shop.isOwned(itemId)
    local def = items.registry[itemId]
    if not def then return false end
    if def.itemType == "passive" then
        return shop.inventory[itemId]
    else
        for i = 1, 3 do
            if shop.slots[i] == itemId then return true end
        end
        return false
    end
end

function shop.slotActivate(slotIdx)
    local id = shop.slots[slotIdx]
    if not id then return nil end
    shop.slots[slotIdx] = nil
    return id
end

function shop.procesarCompra(monedas, itemId, costo)
    local def = items.registry[itemId]
    if not def then return nil end
    if monedas < costo then return nil end

    if shop.isOwned(itemId) then return nil end

    if def.itemType == "passive" then
        shop.inventory[itemId] = true
        return {item = itemId, costo = costo}
    else
        for i = 1, 3 do
            if shop.slots[i] == nil then
                shop.slots[i] = itemId
                return {item = itemId, costo = costo, slot = i}
            end
        end
        return nil
    end
end

function shop.mousepressed(x, y, monedas)
    for _, rect in ipairs(cardRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            local result = shop.procesarCompra(monedas, rect.item.id, rect.item.cost)
            if result then
                table.insert(purchaseFlash, {idx = 1, timer = 0.3})
            end
            return result
        end
    end
    return nil
end

function shop.reset(keepInventory)
    shop.slots = {nil, nil, nil}
    if not keepInventory then
        shop.inventory = {
            speedReducer = false, extraCoin = false
        }
    end
    shop.magnetTimer = 0
    shop.shieldActive = false
    page = 1
    purchaseFlash = {}
end

return shop

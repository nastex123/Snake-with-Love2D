local shop = {}
local constants = require("constants")
local items = require("systems.items")
local world = require("core.world")
local tarotMod = require("systems.tarot")
local tarotArtMod = require("systems.tarotArt")

-- P04: World.state.shop como fuente de verdad (shop.shieldActive/magnetTimer/ghostActive)
if not world.state.shop then
    world.state.shop = { shieldActive = false, magnetTimer = 0, ghostActive = false }
else
    world.state.shop.shieldActive = world.state.shop.shieldActive or false
    world.state.shop.magnetTimer = world.state.shop.magnetTimer or 0
    world.state.shop.ghostActive = world.state.shop.ghostActive or false
end

-- Proxy para sincronizar shop.* ↔ World.state.shop.* y notificar via World.set
-- P04: World.state.shop es fuente de verdad; shop.* es proxy sin rawset para proxied keys
-- para que World.reset (que borra world.state.shop) no deje raw fields desincronizados.
do
    local proxyKeys = { shieldActive = true, magnetTimer = true, ghostActive = true }
    local mt = {
        __index = function(t, k)
            if proxyKeys[k] then
                if world.state.shop then
                    return world.state.shop[k]
                end
                return nil
            end
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if proxyKeys[k] then
                if not world.state.shop then
                    world.state.shop = { shieldActive = false, magnetTimer = 0, ghostActive = false }
                end
                world.state.shop[k] = v
                -- No rawset para proxied keys: mantiene proxy activo tras World.reset
                world.set("shop." .. k, v)
            else
                rawset(t, k, v)
            end
        end
    }
    setmetatable(shop, mt)
end

shop.slots = {nil, nil, nil}

shop.inventory = {
    speedReducer = false, extraCoin = false
}
-- Inicializa World.state.shop si no existe (ya hecho arriba), no crear raw fields
if not world.state.shop then
    world.state.shop = { shieldActive = false, magnetTimer = 0, ghostActive = false }
end

local fontNormal, fontSmall, fontLarge
local openTimer = 0
local displayCoins = 0
local purchaseFlash = {}
local rerollRect = nil

-- Tienda v2: 3 puestos con stock mixto (60% item / 40% tarot), sin duplicados.
shop.stock = nil
shop.rerolls = 0

-- Tira una oferta mixta evitando duplicados del roll y poseidos.
function shop.rollOffer(usedItems, usedTarots, chance)
    usedItems = usedItems or {}
    usedTarots = usedTarots or {}
    chance = chance or tonumber(constants.SHOP_TAROT_CHANCE) or 0.40
    for _ = 1, 30 do
        if love.math.random() < chance then
            local avail = {}
            for _, id in ipairs(tarotMod.shopPool()) do
                if not usedTarots[id] then avail[#avail + 1] = id end
            end
            if #avail > 0 then
                local id = avail[love.math.random(#avail)]
                usedTarots[id] = true
                return {kind = "tarot", id = id, price = tarotMod.price(id), sold = false}
            end
        else
            local avail = {}
            for _, key in ipairs(items.canonicalKeys or {}) do
                local def = items.get(key)
                if def and not usedItems[def.id] and not shop.isOwned(def.id) then
                    avail[#avail + 1] = def
                end
            end
            if #avail > 0 then
                local def = avail[love.math.random(#avail)]
                usedItems[def.id] = true
                return {kind = "item", id = def.id, price = def.cost or 0, sold = false}
            end
        end
    end
    return nil
end

function shop.rollStock()
    local stalls = tonumber(constants.SHOP_STALLS) or 3
    local chance = tonumber(constants.SHOP_TAROT_CHANCE) or 0.40
    local stock = {}
    local usedItems, usedTarots = {}, {}
    for i = 1, stalls do
        stock[i] = shop.rollOffer(usedItems, usedTarots, chance)
    end
    shop.stock = stock
    return stock
end

function shop.getStock()
    return shop.stock or {}
end

function shop.rerollCost()
    return (tonumber(constants.SHOP_REROLL_BASE) or 5)
        + (shop.rerolls or 0) * (tonumber(constants.SHOP_REROLL_STEP) or 2)
end

-- Reroll global escalado; retorna {reroll=true, costo} o nil sin fondos.
function shop.doReroll(monedas)
    local cost = shop.rerollCost()
    if (monedas or 0) < cost then return nil end
    shop.rerolls = (shop.rerolls or 0) + 1
    shop.rollStock()
    openTimer = 0
    return {reroll = true, costo = cost}
end

-- Compra el puesto i; retorna {item, costo[, kind="tarot"]} o nil.
function shop.buyStall(i, monedas)
    local offer = shop.stock and shop.stock[i]
    if not offer or offer.sold then return nil end
    if offer.kind == "tarot" then
        if (monedas or 0) < offer.price then return nil end
        if tarotMod.buy(offer.id) then
            offer.sold = true
            table.insert(purchaseFlash, {idx = i, timer = 0.3})
            return {item = offer.id, costo = offer.price, kind = "tarot"}
        end
        return nil
    end
    local res = shop.procesarCompra(monedas, offer.id, offer.price)
    if res then
        offer.sold = true
        table.insert(purchaseFlash, {idx = i, timer = 0.3})
    end
    return res
end

function shop.getSlots()
    return {shop.slots[1], shop.slots[2], shop.slots[3]}
end

function shop.getInventory()
    return shop.inventory
end

function shop.loadFonts()
    local ok = pcall(function()
        fontLarge = love.graphics.newFont(constants.FONT_FILE, constants.FONT_LARGE)
        fontNormal = love.graphics.newFont(constants.FONT_FILE, constants.FONT_NORMAL)
        fontSmall = love.graphics.newFont(constants.FONT_FILE, constants.FONT_SMALL)
    end)
    if not ok then
        pcall(function()
            fontLarge = love.graphics.newFont(constants.FONT_LARGE)
            fontNormal = love.graphics.newFont(constants.FONT_NORMAL)
            fontSmall = love.graphics.newFont(constants.FONT_SMALL)
        end)
    end
end

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
    elseif id == "speed" or id == "speedReducer" then
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
    else
        -- Fallback generico para el arsenal 51-60: diamante dorado
        love.graphics.setColor(1, 0.84, 0)
        local pts = {x + half, y + 2, x + size - 2, y + half, x + half, y + size - 2, x + 2, y + half}
        love.graphics.polygon("fill", pts)
    end
end

local STALL_W = 190
local STALL_H = 215
local STALL_GAP = 15

local cardRects = {}
local function offerDef(offer)
    if not offer then return nil end
    if offer.kind == "tarot" then
        for _, d in ipairs(tarotMod.TAROT_DEFS) do
            if d.id == offer.id then return d end
        end
        return nil
    end
    return items.get(offer.id)
end

-- Parte el texto en dos lineas por palabras (sin allocs fuera de draw).
local function splitDesc(text, maxChars)
    text = text or ""
    if #text <= maxChars then return text, "" end
    local cut = maxChars
    while cut > 0 and text:sub(cut, cut) ~= " " do cut = cut - 1 end
    if cut == 0 then cut = maxChars end
    return text:sub(1, cut), text:sub(cut + 1):gsub("^%s+", "")
end

function shop.draw(monedas, velocidadActual)
    monedas = monedas or 0
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0

    -- semitransparente para ver el fondo animado
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)

    if not fontNormal or not fontSmall or not fontLarge then
        shop.loadFonts()
    end

    if fontLarge then love.graphics.setFont(fontLarge) end
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("T I E N D A", 0, 15, w, "center")

    displayCoins = displayCoins + (monedas - displayCoins) * 0.1
    if fontNormal then love.graphics.setFont(fontNormal) end
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf("MONEDAS: " .. math.floor(displayCoins + 0.5), 0, 42, w, "center")

    -- 3 puestos en fila
    local mx, my = love.mouse.getPosition()
    cardRects = {}

    local stock = shop.getStock()
    local totalW = STALL_W * 3 + STALL_GAP * 2
    local startX = (w - totalW) / 2
    local gridStartY = 72

    -- animacion de entrada (tambien al rerollear)
    if openTimer < 1 then
        openTimer = openTimer + 0.03
    end

    for idx = 1, 3 do
        local offer = stock[idx]
        local cardX = startX + (idx - 1) * (STALL_W + STALL_GAP)
        local entryFrac = math.min(1, math.max(0, (openTimer - (idx - 1) * 0.12) / 0.3))
        local eased = entryFrac * entryFrac * (3 - 2 * entryFrac)
        local drawY = gridStartY + (1 - eased) * 40

        cardRects[idx] = {x = cardX, y = drawY, w = STALL_W, h = STALL_H}
        local def = offerDef(offer)
        local sold = offer and offer.sold
        local affordable = offer and not sold and monedas >= (offer.price or 0)
        local hovered = mx >= cardX and mx <= cardX + STALL_W and my >= drawY and my <= drawY + STALL_H

        -- card bg
        local bgA = offer and (0.5 + eased * 0.5) or 0.3
        love.graphics.setColor(constants.COLOR_PANEL[1], constants.COLOR_PANEL[2], constants.COLOR_PANEL[3], constants.COLOR_PANEL[4] * bgA)
        love.graphics.rectangle("fill", cardX, drawY, STALL_W, STALL_H, 4)

        -- borde por estado
        if not offer then
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.setLineWidth(1)
        elseif sold then
            love.graphics.setColor(0.3, 0.8, 0.3, 0.6)
            love.graphics.setLineWidth(2)
        elseif hovered and affordable then
            local pulse = math.sin(time * 4) * 0.3 + 0.7
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pulse)
            love.graphics.setLineWidth(2)
        elseif affordable then
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", cardX, drawY, STALL_W, STALL_H, 4)
        love.graphics.setLineWidth(1)

        -- purchase flash
        for i = #purchaseFlash, 1, -1 do
            local pf = purchaseFlash[i]
            if pf.idx == idx then
                love.graphics.setColor(0.3, 0.9, 0.3, pf.timer / 0.3 * 0.4)
                love.graphics.rectangle("fill", cardX, drawY, STALL_W, STALL_H, 4)
            end
        end

        if not offer or not def then
            if fontNormal then love.graphics.setFont(fontNormal) end
            love.graphics.setColor(0.4, 0.4, 0.45)
            love.graphics.printf("VACIO", cardX, drawY + 90, STALL_W, "center")
        else
            -- etiqueta de tipo
            if fontSmall then love.graphics.setFont(fontSmall) end
            if offer.kind == "tarot" then
                love.graphics.setColor(def.color[1], def.color[2], def.color[3])
                love.graphics.printf("TAROT", cardX, drawY + 8, STALL_W, "center")
                tarotArtMod.draw(offer.id, cardX + (STALL_W - 56) / 2, drawY + 24, 56)
            else
                love.graphics.setColor(0.5, 0.6, 0.7)
                love.graphics.printf("ITEM", cardX, drawY + 8, STALL_W, "center")
                drawIcon(def.icon or def.id, cardX + (STALL_W - 40) / 2, drawY + 24, 40)
            end

            -- nombre + descripcion
            local textColor = {1, 1, 1}
            if sold or not affordable then textColor = {0.5, 0.5, 0.5} end
            if fontNormal then love.graphics.setFont(fontNormal) end
            love.graphics.setColor(textColor[1], textColor[2], textColor[3])
            love.graphics.printf(def.name or def.id, cardX + 8, drawY + 88, STALL_W - 16, "center")
            if fontSmall then love.graphics.setFont(fontSmall) end
            love.graphics.setColor(textColor[1], textColor[2], textColor[3], 0.75)
            if offer.kind == "tarot" then
                local l1, l2 = splitDesc(def.desc or "", 24)
                love.graphics.printf(l1, cardX + 8, drawY + 112, STALL_W - 16, "center")
                love.graphics.printf(l2, cardX + 8, drawY + 124, STALL_W - 16, "center")
            else
                love.graphics.printf(def.desc or "", cardX + 8, drawY + 112, STALL_W - 16, "center")
                love.graphics.printf(def.desc2 or "", cardX + 8, drawY + 124, STALL_W - 16, "center")
            end

            -- precio o estado
            if fontNormal then love.graphics.setFont(fontNormal) end
            if sold then
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.printf("ADQUIRIDO", cardX, drawY + 150, STALL_W, "center")
            else
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
                love.graphics.printf("[" .. idx .. "] " .. (offer.price or 0) .. " monedas", cardX, drawY + 150, STALL_W, "center")
            end
            if fontSmall then love.graphics.setFont(fontSmall) end
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.printf("tecla " .. idx, cardX, drawY + STALL_H - 20, STALL_W, "center")
        end
    end

    -- boton reroll global escalado
    local rcost = shop.rerollCost()
    local rbW, rbH = 240, 34
    local rbX, rbY = (w - rbW) / 2, gridStartY + STALL_H + 12
    rerollRect = {x = rbX, y = rbY, w = rbW, h = rbH}
    local rHover = mx >= rbX and mx <= rbX + rbW and my >= rbY and my <= rbY + rbH
    local rAfford = monedas >= rcost
    love.graphics.setColor(0.15, 0.12, 0.05, 0.9)
    love.graphics.rectangle("fill", rbX, rbY, rbW, rbH, 6)
    if rAfford then
        love.graphics.setColor(1, 0.8, 0.2, rHover and 1 or 0.6)
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
    end
    love.graphics.setLineWidth(rHover and 2 or 1)
    love.graphics.rectangle("line", rbX, rbY, rbW, rbH, 6)
    love.graphics.setLineWidth(1)
    if fontNormal then love.graphics.setFont(fontNormal) end
    love.graphics.printf("REROLL (R): " .. rcost .. "$", rbX, rbY + 8, rbW, "center")

    -- mini slots ocupados
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.5, 0.6, 0.7)
    local slotNames = {}
    for i = 1, 3 do slotNames[i] = shop.slots[i] or "-" end
    love.graphics.printf("SLOTS: [" .. table.concat(slotNames, "] [") .. "]", 0, rbY + rbH + 8, w, "center")

    -- pie: controles
    local footerY = h - 30
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("1-3 COMPRAR    R REROLL    ESPACIO CONTINUAR    ESC SALIR", 0, footerY, w, "center")
end

-- renew=true en visita fresca (nuevo stock + reroll a 0); sin renew conserva stock.
function shop.abrir(monedas, renew)
    shop.loadFonts()
    openTimer = 0
    displayCoins = monedas or 0
    if renew or not shop.stock then
        shop.newVisit()
    end
end

function shop.newVisit()
    shop.rerolls = 0
    shop.rollStock()
    openTimer = 0
end

function shop.update(dt)
    dt = dt or 0
    for i = #purchaseFlash, 1, -1 do
        purchaseFlash[i].timer = purchaseFlash[i].timer - dt
        if purchaseFlash[i].timer <= 0 then
            table.remove(purchaseFlash, i)
        end
    end
end

function shop.keypressed(tecla, monedas)
    monedas = monedas or 0
    if tecla == "r" then
        return shop.doReroll(monedas)
    end

    if tecla == "space" or tecla == "return" or tecla == "kpenter" then
        return "continue"
    elseif tecla == "escape" then
        return "exit"
    end

    -- teclas 1-3 (incluyendo keypad) compran el puesto correspondiente
    local num = tonumber(tecla)
    if not num and type(tecla) == "string" and tecla:match("^kp([1-9])$") then
        num = tonumber(tecla:match("^kp([1-9])$"))
    end

    if num and num >= 1 and num <= 3 then
        return shop.buyStall(num, monedas)
    end

    return nil
end

function shop.isOwned(itemId)
    if not itemId then return false end
    local def = items.get(itemId)
    if not def then return false end
    local canon = def.id
    if def.itemType == "passive" then
        return shop.inventory[canon] == true
    else
        for i = 1, 3 do
            if shop.slots[i] == canon then return true end
        end
        return false
    end
end

function shop.slotActivate(slotIdx)
    if type(slotIdx) ~= "number" or slotIdx < 1 or slotIdx > 3 then return nil end
    local id = shop.slots[slotIdx]
    if not id then return nil end
    shop.slots[slotIdx] = nil
    return id
end

function shop.procesarCompra(monedas, itemId, costo)
    monedas = monedas or 0
    if not itemId then return nil end
    local def = items.get(itemId)
    if not def then return nil end
    local canon = def.id
    costo = costo or def.cost or 0

    if monedas < costo then return nil end
    if shop.isOwned(canon) then return nil end

    if def.itemType == "passive" then
        shop.inventory[canon] = true
        return {item = canon, costo = costo}
    else
        for i = 1, 3 do
            if shop.slots[i] == nil then
                shop.slots[i] = canon
                return {item = canon, costo = costo, slot = i}
            end
        end
        return nil
    end
end

function shop.mousepressed(x, y, monedas)
    monedas = monedas or 0
    if rerollRect and x >= rerollRect.x and x <= rerollRect.x + rerollRect.w
        and y >= rerollRect.y and y <= rerollRect.y + rerollRect.h then
        return shop.doReroll(monedas)
    end
    for idx, rect in ipairs(cardRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return shop.buyStall(idx, monedas)
        end
    end
    return nil
end

function shop.reset(keepInventory)
    shop.slots = {nil, nil, nil}
    if not keepInventory then
        shop.inventory = {}
        for _, key in ipairs(items.canonicalKeys or {}) do
            local def = items.registry[key]
            if def and def.itemType == "passive" then
                shop.inventory[key] = false
            end
        end
        -- ensure at least speedReducer/extraCoin exist even if canonicalKeys empty
        if shop.inventory.speedReducer == nil then shop.inventory.speedReducer = false end
        if shop.inventory.extraCoin == nil then shop.inventory.extraCoin = false end
    end
    shop.magnetTimer = 0
    shop.shieldActive = false
    shop.stock = nil
    shop.rerolls = 0
    purchaseFlash = {}
end

return shop

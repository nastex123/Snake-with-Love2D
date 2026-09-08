local shop = {}
local constants = require("constants")
local items = require("systems.items")
local world = require("core.world")
local tarotMod = require("systems.tarot")
local tarotArtMod = require("systems.tarotArt")
local shopDrawMod = require("systems.shopDraw")

-- P04: World.state.shop como fuente de verdad (shop.shieldActive/magnetTimer/ghostActive)
if not world.state.shop then
    world.state.shop = { shieldActive = false, magnetTimer = 0, ghostActive = false }
else
    world.state.shop.shieldActive = world.state.shop.shieldActive or false
    world.state.shop.magnetTimer = world.state.shop.magnetTimer or 0
    world.state.shop.ghostActive = world.state.shop.ghostActive or false
end

-- Proxy para sincronizar shop.* ↔ World.state.shop.* y notificar via World.set
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
                world.set("shop." .. k, v)
            else
                rawset(t, k, v)
            end
        end
    }
    setmetatable(shop, mt)
end

shop.slots = {nil, nil, nil}
shop.inventory = { speedReducer = false, extraCoin = false }

local fontNormal, fontSmall, fontLarge
local openTimer = 0
local displayCoins = 0
local purchaseFlash = {}
shop.stock = nil
shop.rerolls = 0
shop.focusedStall = 1

function shop.offerDef(offer)
    if not offer then return nil end
    if offer.kind == "tarot" then
        for _, d in ipairs(tarotMod.TAROT_DEFS) do
            if d.id == offer.id then return d end
        end
        return nil
    end
    return items.get(offer.id)
end

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

function shop.doReroll(monedas)
    local cost = shop.rerollCost()
    if (monedas or 0) < cost then return nil end
    shop.rerolls = (shop.rerolls or 0) + 1
    shop.rollStock()
    openTimer = 0
    shop.focusedStall = 1
    return {reroll = true, costo = cost}
end

function shop.buyStall(i, monedas)
    local offer = shop.stock and shop.stock[i]
    if not offer or offer.sold then return nil end
    shop.focusedStall = i

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

function shop.draw(monedas, velocidadActual)
    monedas = monedas or 0
    if not fontNormal or not fontSmall or not fontLarge then
        shop.loadFonts()
    end

    displayCoins = displayCoins + (monedas - displayCoins) * 0.1
    if openTimer < 1 then
        openTimer = openTimer + 0.03
    end

    local passivesMap = {}
    for k, v in pairs(shop.inventory) do
        if v == true then passivesMap[k] = true end
    end
    for _, tid in ipairs(tarotMod.getActive()) do
        passivesMap[tid] = true
    end

    shopDrawMod.draw({
        monedas = monedas,
        displayCoins = displayCoins,
        stock = shop.getStock(),
        focusedStall = shop.focusedStall,
        purchaseFlash = purchaseFlash,
        rerollCost = shop.rerollCost(),
        openTimer = openTimer,
        fontNormal = fontNormal,
        fontSmall = fontSmall,
        fontLarge = fontLarge,
        slots = shop.slots,
        passives = passivesMap,
        offerDefFn = shop.offerDef,
    })
end

function shop.abrir(monedas, renew)
    shop.loadFonts()
    openTimer = 0
    displayCoins = monedas or 0
    shop.focusedStall = 1
    if renew or not shop.stock then
        shop.newVisit()
    end
end

function shop.newVisit()
    shop.rerolls = 0
    shop.rollStock()
    openTimer = 0
    shop.focusedStall = 1
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

    -- Navegación con flechas / Tab
    if tecla == "up" or tecla == "w" then
        shop.focusedStall = ((shop.focusedStall - 2) % 3) + 1
        return nil
    elseif tecla == "down" or tecla == "s" or tecla == "tab" then
        shop.focusedStall = (shop.focusedStall % 3) + 1
        return nil
    end

    -- Teclas 1-3 compran el stall correspondiente y ajustan el foco
    local num = tonumber(tecla)
    if not num and type(tecla) == "string" and tecla:match("^kp([1-9])$") then
        num = tonumber(tecla:match("^kp([1-9])$"))
    end

    if num and num >= 1 and num <= 3 then
        shop.focusedStall = num
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
    local cardRects, rerollRect = shopDrawMod.getRects()

    if rerollRect and x >= rerollRect.x and x <= rerollRect.x + rerollRect.w
        and y >= rerollRect.y and y <= rerollRect.y + rerollRect.h then
        return shop.doReroll(monedas)
    end

    for idx, rect in ipairs(cardRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            shop.focusedStall = idx
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
        if shop.inventory.speedReducer == nil then shop.inventory.speedReducer = false end
        if shop.inventory.extraCoin == nil then shop.inventory.extraCoin = false end
    end
    shop.magnetTimer = 0
    shop.shieldActive = false
    shop.stock = nil
    shop.rerolls = 0
    shop.focusedStall = 1
    purchaseFlash = {}
end

return shop

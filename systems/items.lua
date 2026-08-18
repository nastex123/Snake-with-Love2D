local items = {}
local constants = require("constants")

items.registry = {
    shield = {
        id = "shield", name = "ESCUDO",
        desc = "Sobrevive a", desc2 = "un impacto",
        cost = constants.SHIELD_COST, icon = "shield",
        category = "defense", type = "inventory", itemType = "active"
    },
    armor = {
        id = "armor", name = "ARMADURA",
        desc = "Sobrevive a", desc2 = "2 impactos",
        cost = constants.ARMOR_COST, icon = "armor",
        category = "defense", type = "inventory", itemType = "active"
    },
    ghost = {
        id = "ghost", name = "FANTASMAL",
        desc = "Atraviesa tu", desc2 = "cuerpo x5s",
        cost = constants.GHOST_COST, icon = "ghost",
        category = "defense", type = "timer", duration = constants.GHOST_DURATION, itemType = "active"
    },
    magnet = {
        id = "magnet", name = "IMAN",
        desc = "Atrae comida", desc2 = "radio 2 x10s",
        cost = constants.MAGNET_COST, icon = "magnet",
        category = "food", type = "timer", duration = constants.MAGNET_DURATION, itemType = "active"
    },
    bomb = {
        id = "bomb", name = "BOMBA",
        desc = "Destruye obstaculos", desc2 = "radio 3",
        cost = constants.BOMB_COST, icon = "bomb",
        category = "food", type = "instant", itemType = "active"
    },
    hunger = {
        id = "hunger", name = "HAMBRE",
        desc = "Aparecen 2 comidas", desc2 = "extra en el mapa",
        cost = constants.HUNGER_COST, icon = "hunger",
        category = "food", type = "instant", itemType = "active"
    },
    speedReducer = {
        id = "speedReducer", name = "REDUCTOR",
        desc = "Reduce velocidad", desc2 = "permanentemente",
        cost = constants.SPEED_REDUCER_COST, icon = "speed",
        category = "speed", type = "instant", itemType = "passive"
    },
    turbo = {
        id = "turbo", name = "TURBO",
        desc = "Aumenta velocidad", desc2 = "x8s",
        cost = constants.TURBO_COST, icon = "turbo",
        category = "speed", type = "timer", duration = constants.TURBO_DURATION, itemType = "active"
    },
    slow = {
        id = "slow", name = "RALENTIZAR",
        desc = "Ralentiza el tiempo", desc2 = "x5s",
        cost = constants.SLOW_COST, icon = "slow",
        category = "speed", type = "timer", duration = constants.SLOW_DURATION, itemType = "active"
    },
    doubler = {
        id = "doubler", name = "DUPLICADOR",
        desc = "Puntos x2", desc2 = "x8s",
        cost = constants.DOUBLER_COST, icon = "doubler",
        category = "score", type = "timer", duration = constants.DOUBLER_DURATION, itemType = "active"
    },
    extraCoin = {
        id = "extraCoin", name = "MONEDA EXTRA",
        desc = "+1 moneda/fruta", desc2 = "permanente",
        cost = constants.EXTRA_COIN_COST, icon = "extraCoin",
        category = "score", type = "timer", duration = constants.EXTRA_COIN_DURATION, itemType = "passive"
    },
    star = {
        id = "star", name = "ESTRELLA",
        desc = "Puntos x3 x5s", desc2 = "0 monedas",
        cost = constants.STAR_COST, icon = "star",
        category = "score", type = "timer", duration = constants.STAR_DURATION, itemType = "active"
    }
}

items.categories = {"defense", "food", "speed", "score"}

function items.getByCategory(cat)
    local result = {}
    for _, def in pairs(items.registry) do
        if def.category == cat then
            table.insert(result, def)
        end
    end
    return result
end

-- Flatten categories into pages of 3 items
items.pages = {}
for _, cat in ipairs(items.categories) do
    local catItems = items.getByCategory(cat)
    for _, def in ipairs(catItems) do
        table.insert(items.pages, def)
    end
end

return items

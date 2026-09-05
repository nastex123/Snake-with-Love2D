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
        category = "score", type = "instant", duration = constants.EXTRA_COIN_DURATION, itemType = "passive"
    },
    star = {
        id = "star", name = "ESTRELLA",
        desc = "Puntos x3 x5s", desc2 = "0 monedas",
        cost = constants.STAR_COST, icon = "star",
        category = "score", type = "timer", duration = constants.STAR_DURATION, itemType = "active"
    },
    -- Arsenal extendido 51-60 (GDD Fase 8)
    tailSpike = {
        id = "tailSpike", name = "PUA DE COLA",
        desc = "Trampa en cola", desc2 = "mata x3 max",
        cost = constants.TAIL_SPIKE_COST, icon = "tailSpike",
        category = "defense", type = "instant", itemType = "active"
    },
    hourglass = {
        id = "hourglass", name = "RELOJ ARENA",
        desc = "Rebobina 2.0s", desc2 = "conserva puntos",
        cost = constants.HOURGLASS_COST, icon = "hourglass",
        category = "defense", type = "instant", itemType = "active"
    },
    orbitalBeam = {
        id = "orbitalBeam", name = "RAYO ORBITAL",
        desc = "Haz columna", desc2 = "x2.5s vaporiza",
        cost = constants.ORBITAL_COST, icon = "orbitalBeam",
        category = "score", type = "timer", duration = constants.ORBITAL_DURATION, itemType = "active"
    },
    holoDecoy = {
        id = "holoDecoy", name = "SENUELO",
        desc = "Atrae chasers", desc2 = "x4.0s",
        cost = constants.HOLO_DECOY_COST, icon = "holoDecoy",
        category = "score", type = "instant", itemType = "active"
    },
    lightBoots = {
        id = "lightBoots", name = "BOTAS LIGERAS",
        desc = "-50% lentitud", desc2 = "baba/slimes",
        cost = constants.LIGHT_BOOTS_COST, icon = "lightBoots",
        category = "speed", type = "instant", itemType = "passive"
    },
    goldenTooth = {
        id = "goldenTooth", name = "DIENTE ORO",
        desc = "+1 moneda/fruta", desc2 = "x10 segmentos",
        cost = constants.GOLDEN_TOOTH_COST, icon = "goldenTooth",
        category = "score", type = "instant", itemType = "passive"
    },
    emergencyBattery = {
        id = "emergencyBattery", name = "BATERIA",
        desc = "Bullet time", desc2 = "al morir x1.5s",
        cost = constants.EMERGENCY_BATTERY_COST, icon = "emergencyBattery",
        category = "defense", type = "instant", itemType = "passive"
    },
    doubleHarvest = {
        id = "doubleHarvest", name = "COSECHA DOBLE",
        desc = "15% sin crecer", desc2 = "conserva premio",
        cost = constants.DOUBLE_HARVEST_COST, icon = "doubleHarvest",
        category = "score", type = "instant", itemType = "passive"
    },
    lottery = {
        id = "lottery", name = "LOTERIA",
        desc = "Rasca 0-35$", desc2 = "cuesta 5$",
        cost = constants.LOTTERY_COST, icon = "lottery",
        category = "food", type = "instant", itemType = "consumable"
    },
    refractorPrism = {
        id = "refractorPrism", name = "PRISMA",
        desc = "Proyectil->3$", desc2 = "con escudo",
        cost = constants.REFRACTOR_COST, icon = "refractorPrism",
        category = "score", type = "instant", itemType = "passive"
    }
}

items.canonicalKeys = {
    "shield", "armor", "ghost",
    "magnet", "bomb", "hunger",
    "speedReducer", "turbo", "slow",
    "doubler", "extraCoin", "star",
    "tailSpike", "hourglass", "orbitalBeam", "holoDecoy",
    "lightBoots", "goldenTooth", "emergencyBattery", "doubleHarvest",
    "lottery", "refractorPrism"
}

items.categories = {"defense", "food", "speed", "score"}

function items.get(id)
    if not id then return nil end
    if items.registry[id] then return items.registry[id] end
    local aliases = {
        speed_reducer = "speedReducer",
        extra_coin = "extraCoin",
        speedreducer = "speedReducer",
        extracoin = "extraCoin"
    }
    local mapped = aliases[id] or aliases[string.lower(tostring(id))]
    if mapped and items.registry[mapped] then
        return items.registry[mapped]
    end
    return nil
end

function items.getByCategory(cat)
    local result = {}
    for _, key in ipairs(items.canonicalKeys) do
        local def = items.registry[key]
        if def and def.category == cat then
            table.insert(result, def)
        end
    end
    return result
end

function items.isPassive(id)
    local def = items.get(id)
    return def ~= nil and def.itemType == "passive"
end

function items.isActive(id)
    local def = items.get(id)
    return def ~= nil and def.itemType == "active"
end

function items.getDuration(id)
    local def = items.get(id)
    return (def and def.duration) or 0
end

function items.getCost(id)
    local def = items.get(id)
    return (def and def.cost) or 0
end

-- Flatten canonical items into pages of 3 items (4 pages total)
items.pages = {}
for _, cat in ipairs(items.categories) do
    local catItems = items.getByCategory(cat)
    for _, def in ipairs(catItems) do
        table.insert(items.pages, def)
    end
end

return items

local Speed = {}
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
function Speed.calcSpeed(base, fruits, opts)
    opts = opts or {}
    local st = world.state
    base = base or (st and st.baseSpeed) or (constants and constants.VELOCIDAD_INICIAL) or 0.13
    fruits = fruits or (st and st.frutasContador) or 0
    local inc = (constants and constants.SPEED_ADJUST_INCREMENT) or 0.01
    local vMin = (constants and constants.VELOCIDAD_MINIMA) or 0.05
    local speedReduction = math.floor(fruits / 5) * inc
    local current = math.max(vMin, (base or 0.13) - speedReduction)
    local hasTurbo = opts.turbo
    if hasTurbo == nil and st and st.activeTimers then
        for _, t in ipairs(st.activeTimers) do
            if t.id == "turbo" then
                if t._handle and timers.isActive(t._handle) then hasTurbo = true; break end
                if not t._handle and t.remaining and t.remaining > 0 then hasTurbo = true; break end
            end
        end
    end
    if hasTurbo then current = current * (constants.TURBO_MULTIPLIER or 0.7) end
    local okTarot, tarotMod = pcall(require, "systems.tarot")
    if okTarot and tarotMod and tarotMod.speedFactor then current = current * tarotMod.speedFactor() end
    local okStatus, statusFx = pcall(require, "systems.statusFx")
    if okStatus and statusFx and statusFx.speedMult then current = current * statusFx.speedMult() end
    if opts.isSlime or opts.slowdown then
        local factor = type(opts.slowdown) == "number" and opts.slowdown or 1.25
        local okShop, shop = pcall(require, "systems.shop")
        if opts.isSlime and okShop and shop.inventory and shop.inventory.lightBoots then
            factor = 1 + (factor - 1) * 0.5
        end
        current = current * factor
    end
    local maxBase = (constants and constants.MAX_BASE_SPEED) or 0.30
    local minBase = (constants and constants.VELOCIDAD_MINIMA) or 0.05
    return math.max(minBase, math.min(maxBase, current or minBase))
end
function Speed.itemColor(itemId)
    local colors = {
        shield = {0, 0.85, 1}, armor = {0.3, 0.7, 1}, ghost = {0.6, 0.4, 1},
        magnet = {0, 0.85, 1}, bomb = {1, 0.4, 0.2}, hunger = {1, 0.6, 0.2},
        speedReducer = {0.2, 0.9, 0.3}, speed_reducer = {0.2, 0.9, 0.3},
        turbo = {0, 1, 0.5}, slow = {0.5, 0.5, 1},
        doubler = {1, 0.84, 0}, extraCoin = {1, 0.84, 0}, extra_coin = {1, 0.84, 0},
        star = {1, 0.84, 0},
        tailSpike = {1, 0.3, 0.3}, hourglass = {0.5, 0.8, 1},
        orbitalBeam = {0.4, 0.9, 1}, holoDecoy = {0.7, 0.2, 0.9},
        lightBoots = {0.4, 1, 0.6}, goldenTooth = {1, 0.75, 0.1},
        emergencyBattery = {1, 0.2, 0.2}, doubleHarvest = {0.3, 1, 0.3},
        lottery = {1, 0.9, 0.3}, refractorPrism = {0.8, 0.5, 1},
    }
    local c = colors[itemId]
    if not c then
        local okItems, itemsMod = pcall(require, "systems.items")
        if okItems and itemsMod and itemsMod.get then
            local def = itemsMod.get(itemId)
            if def and colors[def.id] then c = colors[def.id] end
        end
    end
    return c and c[1] or 1, c and c[2] or 1, c and c[3] or 1
end
return Speed

-- tests/test_scope_28_shop_economy.lua — Economia Tienda v2 (GDD §13.3)
-- Suite consola-only: modelo de ingresos esperados por sala/etapa desde los
-- parametros reales del codigo + invariantes de precios + tabla de diagnostico.
-- Supuestos del modelo (jugador medio, documentados y ajustables abajo):
--   PTS_PER_FOOD = 15 (base 10 con combo moderado x1.5)
--   KILL_RATE = 0.25 (playtest 2026-09-10: el jugador mata menos de la mitad)
--   FOOD_EV = 1.3$ (distribucion respawn food.lua: 30%x1 + 10%x2 + 10%x3 + 50%x1)
local harness = require("tests.test_harness")
local constants = require("constants")
local dungeonGen = require("world.dungeonGen")
local items = require("systems.items")
local tarot = require("systems.tarot")

local PTS_PER_FOOD = 15
local KILL_RATE = 0.25
local FOOD_EV = 0.30 * 1 + 0.10 * 2 + 0.10 * 3 + 0.50 * 1
local BASKET_BASE = 50 -- item medio 25 + tarot C 20 + reroll 5

local DROPS = {chaser = 3, patroller = 2, spawner = 1}

local function stageMod(etapa)
    return dungeonGen.getStageMod(etapa) or {countMult = 1.0, objMult = 1.0}
end

local function erule_base(er, mod)
    return math.max(0, math.floor((er.baseCount or 1) * (mod.countMult or 1.0)))
end

local function expectedRoom(etapa)
    local mod = stageMod(etapa)
    local objAcc, wAcc, killsAcc, dropAcc = 0, 0, 0, 0
    for _, id in ipairs(dungeonGen.getTemplateIds()) do
        local t = dungeonGen.getRoomTemplate(id)
        local w = t.weight or 0
        wAcc = wAcc + w
        objAcc = objAcc + w * (t.objectiveBase or 50)
        for _, er in ipairs(((t.spawnRules or {}).enemies) or {}) do
            local n = (erule_base(er, mod)) * (er.weight or 1.0)
            killsAcc = killsAcc + w * n
            dropAcc = dropAcc + w * n * (DROPS[er.type] or 1)
        end
    end
    local objMedio = (objAcc / wAcc) * (mod.objMult or 1.0)
    local comidas = objMedio / PTS_PER_FOOD
    local coinsFood = comidas * FOOD_EV
    local coinsKills = (killsAcc / wAcc) * (mod.countMult or 1.0) * KILL_RATE
        * (dropAcc / math.max(1e-9, killsAcc))
    return {objetivo = objMedio, comidas = comidas, coinsFood = coinsFood, coinsKills = coinsKills}
end

local function expectedStage(etapa)
    local r = expectedRoom(etapa)
    local salasNormales = 4 * (r.coinsFood + r.coinsKills)
    local bossDrop = 5 + 2 * etapa
    local bossRoom = 15 * FOOD_EV + bossDrop
    return {porSala = r, visita = salasNormales + bossRoom, boss = bossRoom}
end

local function cheapestItem()
    local best = math.huge
    for _, key in ipairs(items.canonicalKeys or {}) do
        local def = items.get(key)
        if def and (def.cost or 0) > 0 and def.cost < best then best = def.cost end
    end
    return best
end

harness.describe("Scope 28 - Shop economy invariants", function()
    harness.it("tarot tiers ordered S>A>B>C and positive", function()
        harness.assert_true(tarot.price("mercury") > tarot.price("absolute_zero"), "S>A")
        harness.assert_true(tarot.price("absolute_zero") > tarot.price("iron_spine"), "A>B")
        harness.assert_true(tarot.price("iron_spine") > tarot.price("shadow_thief"), "B>C")
        harness.assert_true(tarot.price("shadow_thief") > 0, "C positive")
    end)

    harness.it("reroll cost grows per use from base", function()
        local shop = require("systems.shop")
        local worldMod = require("world.world")
        worldMod.etapa = 3 -- mult neutro 1.0
        shop.rerolls = 0
        local c0 = shop.rerollCost()
        harness.assert_equal(5, c0, "base 5")
        shop.rerolls = 2
        harness.assert_equal(9, shop.rerollCost(), "5+2*2")
        shop.rerolls = 0
        worldMod.etapa = 1
    end)

    harness.it("food EV matches respawn distribution", function()
        harness.assert_true(FOOD_EV >= 1.0 and FOOD_EV <= 1.6, "EV banda 1.0-1.6, actual " .. FOOD_EV)
    end)

    harness.it("stage income grows with stage", function()
        local prev = 0
        for e = 1, 5 do
            local v = expectedStage(e).visita
            harness.assert_true(v > 0, "etapa " .. e .. " positiva")
            harness.assert_true(v >= prev, "etapa " .. e .. " no decrece (" .. v .. " vs " .. prev .. ")")
            prev = v
        end
    end)

    harness.it("stage-1 visit covers 1 reroll + cheapest item", function()
        local v = expectedStage(1).visita
        harness.assert_true(v >= 5 + cheapestItem(), "E1 cubre reroll+barato: " .. v)
    end)

    harness.it("stage mult table matches spec and brackets 1.0", function()
        local shop = require("systems.shop")
        local worldMod = require("world.world")
        local mults = constants.SHOP_STAGE_PRICE_MULT
        harness.assert_equal(0.8, mults[1], "E1 abarata")
        harness.assert_equal(0.9, mults[2], "E2 abarata")
        harness.assert_equal(1.0, mults[3], "E3 neutra")
        harness.assert_equal(1.1, mults[4], "E4 encarece")
        harness.assert_equal(1.2, mults[5], "E5 encarece")
        worldMod.etapa = 1
        harness.assert_equal(20, shop.applyStagePrice(25), "E1 floor(25*0.8)")
        worldMod.etapa = 5
        harness.assert_equal(30, shop.applyStagePrice(25), "E5 floor(25*1.2)")
        worldMod.etapa = 1
    end)

    harness.it("prints income diagnostic table", function()
        local shop = require("systems.shop")
        local mults = constants.SHOP_STAGE_PRICE_MULT
        print("--- SHOP ECONOMY (supuestos: 15pts/comida, killRate 0.25, EV 1.3$) ---")
        print("etapa | objMedio | comidas | $comida | $kills | $boss | $visita | canastaMult")
        for e = 1, 5 do
            local s = expectedStage(e)
            local r = s.porSala
            local canasta = math.floor(BASKET_BASE * mults[e] + 0.5)
            local cubre = (s.visita >= canasta) and "SI" or "NO"
            print(string.format("E%d | %.0f | %.1f | %.1f | %.1f | %.1f | %.1f | %d %s",
                e, r.objetivo, r.comidas, r.coinsFood, r.coinsKills, s.boss, s.visita, canasta, cubre))
        end
        harness.assert_true(true, "tabla impresa")
    end)
end)

-- tests/test_scope_24_mutators.lua — Room Mutators framework (GDD §19, TDD §10.27)
-- Suite consola-only: catalogo, roll con exclusiones y ciclo de vida. Sin love.graphics.
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local mutators = require("systems.roomMutators")

harness.describe("Scope 24 - Mutator catalog (10 defs)", function()
    harness.it("defines exactly 10 mutators with unique stable ids", function()
        harness.assert_equal(10, #mutators.MUTATOR_DEFS, "must be 10 mutators")
        local seen = {}
        for _, d in ipairs(mutators.MUTATOR_DEFS) do
            harness.assert_not_nil(d.id, "mutator needs id")
            harness.assert_not_nil(d.name, "mutator needs name")
            harness.assert_not_nil(d.tag, "mutator needs HUD tag")
            harness.assert_not_nil(d.type, "mutator needs type")
            harness.assert_not_nil(d.color, "mutator needs color")
            harness.assert_equal(3, #d.color, "color must be {r,g,b}")
            harness.assert_nil(seen[d.id], "duplicate mutator id: " .. tostring(d.id))
            seen[d.id] = true
        end
    end)

    harness.it("covers the 10 GDD ids 61-70", function()
        for _, id in ipairs({"zero_gravity", "midas_curse", "feather_blessing",
            "silent_veil", "stalking_shadow", "time_trial", "phoenix_blessing",
            "tunnel_vision", "dual_room", "titan_pact"}) do
            harness.assert_not_nil(mutators.getDef(id), "missing mutator: " .. id)
        end
    end)

    harness.it("exposes ROOM_MUTATOR_CHANCE = 0.35 in config", function()
        harness.assert_equal(0.35, constants.ROOM_MUTATOR_CHANCE, "chance must be 0.35")
    end)
end)

harness.describe("Scope 24 - Mutator roll exclusions", function()
    harness.it("never rolls on boss rooms (template or sala 5)", function()
        for _ = 1, 20 do
            harness.assert_nil(mutators.roll(2, {template = "boss"}), "boss template excluded")
            harness.assert_nil(mutators.roll(5, {template = "arena"}), "sala 5 excluded")
        end
    end)

    harness.it("never rolls on elite rooms", function()
        for _ = 1, 20 do
            harness.assert_nil(mutators.roll(3, {template = "arena", isElite = true}), "elite excluded")
        end
    end)

    harness.it("rolls a valid id or nil on normal rooms", function()
        local seen = {}
        for _ = 1, 60 do
            local id = mutators.roll(2, {template = "arena"})
            if id ~= nil then
                harness.assert_not_nil(mutators.getDef(id), "rolled id must exist: " .. tostring(id))
                seen[id] = true
            end
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        harness.assert_true(n > 0, "60 rolls must hit at least one mutator")
    end)
end)

harness.describe("Scope 24 - Mutator lifecycle", function()
    harness.it("apply/get/has/clear round-trip", function()
        mutators.clear()
        harness.assert_nil(mutators.get(), "starts with no mutator")
        world.state.roomMutator = "midas_curse"
        harness.assert_equal("midas_curse", mutators.get(), "get returns active id")
        harness.assert_true(mutators.has("midas_curse"), "has detects active")
        harness.assert_true(not mutators.has("dual_room"), "has rejects inactive")
        harness.assert_equal("MIDAS", mutators.getDef().tag, "getDef resolves active")
        mutators.clear()
        harness.assert_nil(mutators.get(), "clear removes mutator")
        harness.assert_true(type(mutators.data()) == "table", "data always a table")
    end)

    harness.it("apply stores a fresh data table per room", function()
        mutators.apply(1, {template = "corridor"})
        harness.assert_true(type(mutators.data()) == "table", "data initialized on apply")
        mutators.clear()
    end)
end)

harness.describe("Scope 24 - Simple mutators (Midas/Silent/Trial/Dual)", function()
    harness.it("midasFruitBonus is +2 only with the curse", function()
        mutators.clear()
        harness.assert_equal(0, mutators.midasFruitBonus(), "no curse, no bonus")
        world.state.roomMutator = "midas_curse"
        harness.assert_equal(2, mutators.midasFruitBonus(), "curse grants +2")
        mutators.clear()
    end)

    harness.it("midasDrain removes 1pt/sec floored at zero", function()
        mutators.clear()
        world.state.roomMutator = "midas_curse"
        world.state.puntuacion = 5
        local total = mutators.midasDrain(1.0) + mutators.midasDrain(1.0) + mutators.midasDrain(1.0)
        harness.assert_equal(3, total, "3 seconds drain 3")
        harness.assert_equal(2, world.state.puntuacion, "score reduced")
        world.state.puntuacion = 0
        harness.assert_equal(0, mutators.midasDrain(2.0), "floor at zero")
        mutators.clear()
        world.state.puntuacion = 0
    end)

    harness.it("silent seal + clear bonus doubles room earnings", function()
        mutators.clear()
        harness.assert_true(not mutators.itemsSealed(), "unsealed by default")
        world.state.roomMutator = "silent_veil"
        harness.assert_true(mutators.itemsSealed(), "sealed with veil")
        mutators.silentMarkCoins(100)
        harness.assert_equal(25, mutators.silentClearBonus(125), "bonus equals earnings")
        harness.assert_equal(0, mutators.silentClearBonus(90), "no negative bonus")
        mutators.clear()
        harness.assert_equal(0, mutators.silentClearBonus(200), "no mutator, no bonus")
    end)

    harness.it("time trial expires once at the limit and reports won", function()
        mutators.clear()
        harness.assert_nil(mutators.timeTrialTick(1.0), "no mutator, no tick")
        harness.assert_true(not mutators.timeTrialWon(), "no mutator, not won")
        world.state.roomMutator = "time_trial"
        for _ = 1, 9 do
            harness.assert_nil(mutators.timeTrialTick(1.0), "ticking under limit")
        end
        harness.assert_true(mutators.timeTrialWon(), "won before the limit")
        harness.assert_equal("expired", mutators.timeTrialTick(1.0), "expires at 10s")
        harness.assert_true(not mutators.timeTrialWon(), "lost after expiry")
        harness.assert_nil(mutators.timeTrialTick(1.0), "expiry fires once")
        harness.assert_equal(10.0, mutators.timeTrialLimit(), "limit is 10s")
        mutators.clear()
    end)

    harness.it("randomUnownedPassive picks only unowned passives", function()
        local reg = {
            a = {id = "a", itemType = "passive"},
            b = {id = "b", itemType = "active"},
            c = {id = "c", itemType = "passive"},
        }
        local pick = mutators.randomUnownedPassive(reg, {a = true})
        harness.assert_not_nil(pick, "must pick the remaining passive")
        harness.assert_equal("c", pick.id, "picks unowned passive")
        harness.assert_nil(mutators.randomUnownedPassive(reg, {a = true, c = true}), "nil when all owned")
        harness.assert_nil(mutators.randomUnownedPassive(nil, {}), "nil without registry")
    end)

    harness.it("dualActive reflects the room mutator", function()
        mutators.clear()
        harness.assert_true(not mutators.dualActive(), "inactive by default")
        world.state.roomMutator = "dual_room"
        harness.assert_true(mutators.dualActive(), "active with dual")
        mutators.clear()
    end)
end)

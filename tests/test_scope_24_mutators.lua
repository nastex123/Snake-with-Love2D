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

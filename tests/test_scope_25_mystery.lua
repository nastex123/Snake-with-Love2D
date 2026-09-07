-- tests/test_scope_25_mystery.lua — Special Mystery Rooms framework (GDD §15, TDD §10.28)
-- Suite consola-only: catalogo, exclusiones, asignacion y sala actual. Sin love.graphics.
local harness = require("tests.test_harness")
local constants = require("constants")
local mystery = require("systems.mystery")

harness.describe("Scope 25 - Mystery catalog (4 defs)", function()
    harness.it("defines exactly 4 rooms with unique stable ids", function()
        harness.assert_equal(4, #mystery.MYSTERY_DEFS, "must be 4 rooms")
        local seen = {}
        for _, d in ipairs(mystery.MYSTERY_DEFS) do
            harness.assert_not_nil(d.id, "room needs id")
            harness.assert_not_nil(d.name, "room needs name")
            harness.assert_not_nil(d.tag, "room needs HUD tag")
            harness.assert_equal(3, #d.color, "color must be {r,g,b}")
            harness.assert_nil(seen[d.id], "duplicate room id: " .. tostring(d.id))
            seen[d.id] = true
        end
    end)

    harness.it("covers the 4 GDD rooms", function()
        for _, id in ipairs({"gambler_den", "doppelganger", "gold_rush", "trial_triads"}) do
            harness.assert_not_nil(mystery.getDef(id), "missing room: " .. id)
        end
        harness.assert_nil(mystery.getDef("no_existe"), "unknown id is nil")
    end)

    harness.it("exposes ROOM_MYSTERY_CHANCE = 0.06 in config", function()
        harness.assert_equal(0.06, constants.ROOM_MYSTERY_CHANCE, "chance must be 0.06")
    end)
end)

harness.describe("Scope 25 - Mystery roll exclusions", function()
    harness.it("never rolls on boss, elite or first room", function()
        for _ = 1, 20 do
            harness.assert_nil(mystery.roll({template = "boss"}, 4), "boss excluded")
            harness.assert_nil(mystery.roll({template = "arena", isElite = true}, 3), "elite excluded")
            harness.assert_nil(mystery.roll({template = "arena"}, 1), "first room excluded")
            harness.assert_nil(mystery.roll(nil, 2), "nil room excluded")
        end
    end)

    harness.it("rolls a valid id or nil on candidate rooms", function()
        local seen = {}
        for _ = 1, 120 do
            local id = mystery.roll({template = "arena"}, 2)
            if id ~= nil then
                harness.assert_not_nil(mystery.getDef(id), "rolled id must exist")
                seen[id] = true
            end
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        harness.assert_true(n > 0, "120 rolls at 6% must hit at least once")
    end)
end)

harness.describe("Scope 25 - Mystery assign and current room", function()
    harness.it("assign flags only candidate rooms and keeps exclusions clean", function()
        local dungeon = {rooms = {
            {id = 1, template = "corridor"},
            {id = 2, template = "arena"},
            {id = 3, template = "arena", isElite = true},
            {id = 4, template = "hub"},
            {id = 5, template = "boss"},
        }}
        mystery.assign(dungeon)
        harness.assert_nil(dungeon.rooms[1].mystery, "room 1 stays normal")
        harness.assert_nil(dungeon.rooms[3].mystery, "elite stays normal")
        harness.assert_nil(dungeon.rooms[5].mystery, "boss stays normal")
        for _, r in ipairs(dungeon.rooms) do
            if r.mystery ~= nil then
                harness.assert_not_nil(mystery.getDef(r.mystery), "flagged id must exist")
            end
        end
    end)

    harness.it("assign on nil dungeon returns 0 without crashing", function()
        harness.assert_equal(0, mystery.assign(nil), "nil-safe")
        harness.assert_equal(0, mystery.assign({}), "empty-safe")
    end)

    harness.it("current resolves the active room mystery", function()
        local fakeWorld = {getCurrentRoom = function() return {mystery = "gold_rush"} end}
        harness.assert_equal("gold_rush", mystery.current(fakeWorld), "resolves flag")
        harness.assert_equal("ORO", mystery.currentDef(fakeWorld).tag, "resolves def")
        harness.assert_nil(mystery.current({getCurrentRoom = function() return {} end}), "normal room is nil")
        harness.assert_nil(mystery.current(nil), "nil-safe")
    end)

    harness.it("begin refreshes per-room runtime data", function()
        mystery.begin().timer = 9
        harness.assert_equal(9, mystery.data().timer, "data writable")
        mystery.begin()
        harness.assert_nil(mystery.data().timer, "begin clears runtime")
    end)
end)

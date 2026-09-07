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

harness.describe("Scope 25 - Gambler Den (bet, timer, golds)", function()
    harness.it("roulette sits at the grid center", function()
        local r = mystery.gamblerRoulette(10, 8)
        harness.assert_equal(5, r.x, "center x")
        harness.assert_equal(4, r.y, "center y")
    end)

    harness.it("bet requires funds and starts the timer", function()
        mystery.begin()
        harness.assert_true(not mystery.gamblerPlaceBet(5), "no bet without funds")
        harness.assert_true(mystery.gamblerPlaceBet(10), "bet with funds")
        harness.assert_true(not mystery.gamblerPlaceBet(100), "single bet per room")
        harness.assert_equal(15.0, mystery.data().timer, "15s timer")
        mystery.begin()
    end)

    harness.it("timer loses once at zero and golds win at three", function()
        mystery.begin()
        mystery.gamblerPlaceBet(10)
        harness.assert_nil(mystery.gamblerTick(14.9), "ticking under limit")
        harness.assert_nil(mystery.gamblerGoldEaten(), "first gold")
        harness.assert_nil(mystery.gamblerGoldEaten(), "second gold")
        harness.assert_equal("win", mystery.gamblerGoldEaten(), "third gold wins")
        harness.assert_true(mystery.gamblerNeedsGold() == false, "no more golds needed")
        mystery.begin()
        mystery.gamblerPlaceBet(10)
        harness.assert_equal("lose", mystery.gamblerTick(15.0), "timeout loses")
        harness.assert_nil(mystery.gamblerTick(1.0), "lose fires once")
        harness.assert_nil(mystery.gamblerGoldEaten(), "no counting after done")
        mystery.begin()
    end)
end)

harness.describe("Scope 25 - Gold Rush (bounce, collect, timer)", function()
    harness.it("begin spawns 20 moving coins", function()
        mystery.begin()
        local rush = mystery.beginGoldRush(12, 10)
        harness.assert_equal(12.0, rush.timer, "12s timer")
        harness.assert_equal(20, #rush.coins, "20 coins")
        for _, c in ipairs(rush.coins) do
            harness.assert_true(c.dx ~= 0 or c.dy ~= 0, "coin moves")
            harness.assert_true(c.x >= 0 and c.x < 12, "coin inside grid")
        end
        mystery.begin()
    end)

    harness.it("stepCoins bounces off walls", function()
        local coins = {{x = 0.1, y = 5, dx = -1, dy = 0, speed = 6.0}}
        mystery.stepCoins(coins, 12, 10, 0.1)
        harness.assert_equal(0, coins[1].x, "clamped to wall")
        harness.assert_equal(1, coins[1].dx, "direction inverted")
    end)

    harness.it("collectCoins removes only overlapping coins", function()
        local coins = {{x = 5, y = 5, dx = 0, dy = 0, speed = 0}, {x = 0, y = 0, dx = 0, dy = 0, speed = 0}}
        harness.assert_equal(1, mystery.collectCoins(coins, {x = 5, y = 5}), "one collected")
        harness.assert_equal(1, #coins, "one remains")
        harness.assert_equal(0, mystery.collectCoins(coins, {x = 9, y = 9}), "none in range")
    end)

    harness.it("goldRushTick collects and ends at zero", function()
        mystery.begin()
        mystery.beginGoldRush(12, 10)
        mystery.data().rush.coins = {{x = 3, y = 3, dx = 0, dy = 0, speed = 0}}
        local got, done = mystery.goldRushTick(1.0, {x = 3, y = 3})
        harness.assert_equal(1, got, "collects overlapped")
        harness.assert_true(not done, "timer still running")
        got, done = mystery.goldRushTick(11.5, {x = 0, y = 0})
        harness.assert_true(done, "ends at zero")
        harness.assert_equal(0, mystery.data().rush.timer, "timer clamped")
        mystery.begin()
    end)
end)

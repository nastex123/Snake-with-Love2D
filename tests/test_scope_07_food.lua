local harness = require("tests.test_harness")
local food = require("entities.food")
local constants = require("constants")
local snakeMod = require("entities.snake")

harness.describe("Food Subsystem - Initialization & State Management", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("initializes default state and coordinates properly", function()
        harness.assert_equal(0, food.pos.x, "food.pos.x should be 0")
        harness.assert_equal(0, food.pos.y, "food.pos.y should be 0")
        harness.assert_nil(food.twinPos, "twinPos should be nil")
        harness.assert_equal(constants.FOOD_NORMAL, food.tipo, "food.tipo should be FOOD_NORMAL")
        harness.assert_equal(0, food.spawnTimer, "spawnTimer should be 0")
        harness.assert_equal(0, food.bombTimer, "bombTimer should be 0")
        harness.assert_equal(0, food.prismaticTimer, "prismaticTimer should be 0")
        harness.assert_equal(1, food.prismaticIndex, "prismaticIndex should be 1")
        harness.assert_equal(0, food.twinTimer, "twinTimer should be 0")
        harness.assert_equal(0, food.orbitTimer, "orbitTimer should be 0")
        harness.assert_nil(food.onBombExpired, "onBombExpired should be nil")
        harness.assert_nil(food.onTwinExpired, "onTwinExpired should be nil")
    end)

    harness.it("reset() and init() clean all modified state variables", function()
        food.pos.x = 14
        food.pos.y = 9
        food.twinPos = {x = 12, y = 8}
        food.tipo = "bomb"
        food.spawnTimer = 0.15
        food.bombTimer = 3.2
        food.prismaticTimer = 5.4
        food.prismaticIndex = 3
        food.twinTimer = 2.1
        food.orbitTimer = 1.0
        food.onBombExpired = function() end
        food.onTwinExpired = function() end

        food.reset()

        harness.assert_equal(0, food.pos.x)
        harness.assert_equal(0, food.pos.y)
        harness.assert_nil(food.twinPos)
        harness.assert_equal(constants.FOOD_NORMAL, food.tipo)
        harness.assert_equal(0, food.spawnTimer)
        harness.assert_equal(0, food.bombTimer)
        harness.assert_equal(0, food.prismaticTimer)
        harness.assert_equal(1, food.prismaticIndex)
        harness.assert_equal(0, food.twinTimer)
        harness.assert_equal(0, food.orbitTimer)
        harness.assert_nil(food.onBombExpired)
        harness.assert_nil(food.onTwinExpired)
    end)

    harness.it("prismaticBuffs contains the 4 core power-ups", function()
        harness.assert_equal(4, #food.prismaticBuffs)
        harness.assert_equal("speed", food.prismaticBuffs[1])
        harness.assert_equal("shield", food.prismaticBuffs[2])
        harness.assert_equal("magnet", food.prismaticBuffs[3])
        harness.assert_equal("ghost", food.prismaticBuffs[4])
    end)
end)

harness.describe("Food Subsystem - Spawning & Coordinate Placement", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("spawns at explicit (gx, gy) coordinates when provided", function()
        local ok = food.generar(nil, 20, 20, nil, constants.FOOD_NORMAL, 7, 13)
        harness.assert_true(ok, "generar should return true")
        harness.assert_equal(7, food.pos.x)
        harness.assert_equal(13, food.pos.y)
        harness.assert_equal(constants.FOOD_NORMAL, food.tipo)
    end)

    harness.it("spawns procedurally avoiding snake body segments", function()
        local snake = {
            {x = 2, y = 2},
            {x = 2, y = 3},
            {x = 2, y = 4},
            {x = 2, y = 5}
        }
        for _ = 1, 20 do
            local ok = food.generar(snake, 10, 10)
            harness.assert_true(ok)
            for _, seg in ipairs(snake) do
                harness.assert_false(food.pos.x == seg.x and food.pos.y == seg.y, "food must not spawn on snake")
            end
        end
    end)

    harness.it("spawns procedurally avoiding obstacle coordinates", function()
        local obstacles = {
            {x = 0, y = 0},
            {x = 1, y = 1},
            {x = 2, y = 2},
            {x = 3, y = 3}
        }
        for _ = 1, 20 do
            local ok = food.generar(nil, 10, 10, obstacles)
            harness.assert_true(ok)
            for _, obs in ipairs(obstacles) do
                harness.assert_false(food.pos.x == obs.x and food.pos.y == obs.y, "food must not spawn on obstacle")
            end
        end
    end)

    harness.it("supports forced spawn for all 12 food types with correct timer setup", function()
        local types = {
            constants.FOOD_NORMAL,
            constants.FOOD_GOLD,
            constants.FOOD_COIN,
            "fire_pepper",
            "frost_berry",
            "constrictor_berry",
            "slimming_berry",
            "repelling_orbit",
            "bomb",
            "prismatic",
            "streak_diamond",
            "twin"
        }

        for _, t in ipairs(types) do
            food.reset()
            local ok = food.generar(nil, 20, 20, nil, t, 5, 5)
            harness.assert_true(ok, "should spawn forced type: " .. tostring(t))
            harness.assert_equal(t, food.tipo, "tipo should match forced type")
            harness.assert_almost_equal(0.18, food.spawnTimer, 0.01, "spawnTimer should be set")

            if t == "bomb" then
                harness.assert_almost_equal(constants.FOOD_COUNTDOWN_TIMER or 5.0, food.bombTimer, 0.01)
            elseif t == "prismatic" then
                harness.assert_equal(0, food.prismaticTimer)
                harness.assert_equal(1, food.prismaticIndex)
            elseif t == "twin" then
                harness.assert_almost_equal(constants.FOOD_TWIN_TIMER or 4.0, food.twinTimer, 0.01)
                harness.assert_not_nil(food.twinPos, "twinPos should be generated for forced twin")
                harness.assert_false(food.pos.x == food.twinPos.x and food.pos.y == food.twinPos.y, "twinPos must differ from food.pos")
            elseif t == "repelling_orbit" then
                harness.assert_almost_equal(constants.REPELLING_MOVE_INTERVAL or 1.5, food.orbitTimer, 0.01)
            end
        end
    end)

    harness.it("finds the single remaining tile on a crowded grid via deterministic fallback", function()
        -- 3x3 grid (9 tiles). Fill 8 tiles with snake.
        local snake = {
            {x = 0, y = 0}, {x = 1, y = 0}, {x = 2, y = 0},
            {x = 0, y = 1}, {x = 1, y = 1}, {x = 2, y = 1},
            {x = 0, y = 2}, {x = 1, y = 2}
        }
        -- Only (2, 2) is free
        local ok = food.generar(snake, 3, 3)
        harness.assert_true(ok, "should find free tile on crowded grid")
        harness.assert_equal(2, food.pos.x)
        harness.assert_equal(2, food.pos.y)
    end)

    harness.it("handles 100% saturated grid gracefully returning false without error", function()
        -- 2x2 grid (4 tiles). Fill all 4 tiles with snake.
        local snake = {
            {x = 0, y = 0}, {x = 1, y = 0},
            {x = 0, y = 1}, {x = 1, y = 1}
        }
        local ok = food.generar(snake, 2, 2)
        harness.assert_false(ok, "should return false when grid is 100% full")
    end)
end)

harness.describe("Food Subsystem - Countdown Bomb (bomb) Lifecycle", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("counts down bombTimer and triggers onBombExpired at zero", function()
        food.generar(nil, 20, 20, nil, "bomb", 8, 12)
        harness.assert_equal("bomb", food.tipo)
        harness.assert_almost_equal(5.0, food.bombTimer, 0.01)

        local expiredX, expiredY = nil, nil
        local callCount = 0
        food.onBombExpired = function(bx, by)
            callCount = callCount + 1
            expiredX = bx
            expiredY = by
        end

        food.update(2.0)
        harness.assert_almost_equal(3.0, food.bombTimer, 0.01)
        harness.assert_equal(0, callCount, "callback should not fire before expiry")

        food.update(3.0)
        harness.assert_lte(food.bombTimer, 0)
        harness.assert_equal(1, callCount, "callback should fire on expiry")
        harness.assert_equal(8, expiredX)
        harness.assert_equal(12, expiredY)
    end)

    harness.it("does not crash when bomb expires and onBombExpired is nil", function()
        food.generar(nil, 20, 20, nil, "bomb", 4, 4)
        food.onBombExpired = nil
        local ok = pcall(function() food.update(6.0) end)
        harness.assert_true(ok, "updating expired bomb without callback must not error")
    end)
end)

harness.describe("Food Subsystem - Prismatic Fruit Cycle & Buffs", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("cycles through prismatic buffs sequentially over time", function()
        food.generar(nil, 20, 20, nil, "prismatic", 5, 5)
        harness.assert_equal("prismatic", food.tipo)
        harness.assert_equal(1, food.prismaticIndex)
        harness.assert_equal("speed", food.getPrismaticBuff())

        -- Advance 1.8s -> index 2 (shield)
        food.update(1.8)
        harness.assert_equal(2, food.prismaticIndex)
        harness.assert_equal("shield", food.getPrismaticBuff())

        -- Advance another 1.8s -> index 3 (magnet)
        food.update(1.8)
        harness.assert_equal(3, food.prismaticIndex)
        harness.assert_equal("magnet", food.getPrismaticBuff())

        -- Advance another 1.8s -> index 4 (ghost)
        food.update(1.8)
        harness.assert_equal(4, food.prismaticIndex)
        harness.assert_equal("ghost", food.getPrismaticBuff())

        -- Advance another 1.8s -> wraps back to index 1 (speed)
        food.update(1.8)
        harness.assert_equal(1, food.prismaticIndex)
        harness.assert_equal("speed", food.getPrismaticBuff())
    end)

    harness.it("getPrismaticBuff safely defaults to speed on out-of-range index", function()
        food.prismaticIndex = 99
        harness.assert_equal("speed", food.getPrismaticBuff())
        food.prismaticIndex = nil
        harness.assert_equal("speed", food.getPrismaticBuff())
    end)
end)

harness.describe("Food Subsystem - Twin Fruits (twin) Lifecycle & Expiration", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("generates twin fruit at distinct valid coordinates", function()
        food.generar(nil, 20, 20, nil, "twin", 6, 6)
        harness.assert_equal("twin", food.tipo)
        harness.assert_equal(6, food.pos.x)
        harness.assert_equal(6, food.pos.y)
        harness.assert_not_nil(food.twinPos)
        harness.assert_false(food.pos.x == food.twinPos.x and food.pos.y == food.twinPos.y)
        harness.assert_gte(food.twinPos.x, 0)
        harness.assert_lt(food.twinPos.x, 20)
        harness.assert_gte(food.twinPos.y, 0)
        harness.assert_lt(food.twinPos.y, 20)
    end)

    harness.it("expires un-eaten twin fruit when twinTimer reaches zero", function()
        food.generar(nil, 20, 20, nil, "twin", 4, 4)
        local expiredCalled = false
        food.onTwinExpired = function(x, y)
            expiredCalled = true
        end

        food.update(2.0)
        harness.assert_not_nil(food.twinPos, "twinPos should still exist before timeout")
        harness.assert_equal("twin", food.tipo)
        harness.assert_false(expiredCalled)

        food.update(2.5)
        harness.assert_nil(food.twinPos, "twinPos should disappear after timer expires")
        harness.assert_equal(constants.FOOD_NORMAL, food.tipo, "tipo should revert to FOOD_NORMAL")
        harness.assert_true(expiredCalled, "onTwinExpired should be called")
    end)

    harness.it("reverts remaining fruit to normal when timer expires after first fruit was eaten", function()
        food.generar(nil, 20, 20, nil, "twin", 10, 10)
        -- Simulate player ate the twinPos fruit first
        food.twinPos = nil
        harness.assert_equal("twin", food.tipo)

        food.update(5.0)
        harness.assert_equal(constants.FOOD_NORMAL, food.tipo, "remaining fruit should revert to normal food")
        harness.assert_nil(food.twinPos)
    end)
end)

harness.describe("Food Subsystem - Repelling Fruit (repelling_orbit) AI Movement", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("does not move before orbitTimer expires", function()
        food.generar(nil, 20, 20, nil, "repelling_orbit", 10, 10)
        local snake = {{x = 9, y = 10}}
        food.update(0.5, snake, 20, 20)
        harness.assert_equal(10, food.pos.x)
        harness.assert_equal(10, food.pos.y)
    end)

    harness.it("moves away from snake head when orbitTimer triggers", function()
        food.generar(nil, 20, 20, nil, "repelling_orbit", 10, 10)
        -- Snake head is directly left of food at (9, 10)
        local snake = {{x = 9, y = 10}, {x = 8, y = 10}}

        local initialDist = math.abs(food.pos.x - snake[1].x) + math.abs(food.pos.y - snake[1].y)
        harness.assert_equal(1, initialDist)

        -- Trigger AI move
        food.update(2.0, snake, 20, 20)

        local newDist = math.abs(food.pos.x - snake[1].x) + math.abs(food.pos.y - snake[1].y)
        harness.assert_gt(newDist, initialDist, "repelling fruit must increase distance from head")
        harness.assert_gte(food.pos.x, 0)
        harness.assert_lt(food.pos.x, 20)
        harness.assert_gte(food.pos.y, 0)
        harness.assert_lt(food.pos.y, 20)
    end)

    harness.it("avoids stepping onto obstacle tiles when repelling", function()
        food.generar(nil, 20, 20, nil, "repelling_orbit", 5, 5)
        local snake = {{x = 5, y = 6}}
        -- Place obstacles in 3 out of 4 directions: right(6,5), left(4,5), down(5,6) is snake
        -- Only up (5,4) is valid and free
        local obstacles = {
            {x = 6, y = 5},
            {x = 4, y = 5}
        }

        food.update(2.0, snake, 20, 20, obstacles)
        harness.assert_equal(5, food.pos.x)
        harness.assert_equal(4, food.pos.y, "should move to the only free tile (5, 4)")
    end)

    harness.it("safely remains in place if all 4 neighbor tiles are blocked", function()
        food.generar(nil, 20, 20, nil, "repelling_orbit", 5, 5)
        local snake = {{x = 5, y = 6}}
        local obstacles = {
            {x = 5, y = 4},
            {x = 6, y = 5},
            {x = 4, y = 5}
        }
        -- All 4 directions blocked (snake down, obstacles up/left/right)
        food.update(2.0, snake, 20, 20, obstacles)
        harness.assert_equal(5, food.pos.x)
        harness.assert_equal(5, food.pos.y, "should safely remain in place")
    end)
end)

harness.describe("Food Subsystem - Magnetic Attraction & Collision Checking", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("checkCollision detects direct tile contact (magnetRange = 0)", function()
        food.pos.x = 5
        food.pos.y = 7

        local hit1, isTwin1 = food.checkCollision(5, 7, 0, 20, 20)
        harness.assert_true(hit1)
        harness.assert_false(isTwin1)

        local hit2, isTwin2 = food.checkCollision(5, 6, 0, 20, 20)
        harness.assert_false(hit2)
        harness.assert_false(isTwin2)
    end)

    harness.it("checkCollision detects twin fruit direct tile contact", function()
        food.pos.x = 5
        food.pos.y = 7
        food.twinPos = {x = 12, y = 14}

        local hitTwin, isTwin = food.checkCollision(12, 14, 0, 20, 20)
        harness.assert_true(hitTwin)
        harness.assert_true(isTwin)
    end)

    harness.it("checkCollision detects food within magnet radius", function()
        food.pos.x = 10
        food.pos.y = 10

        -- Head at (12, 11), distance dx = 2, dy = 1 with magnetRange = 2
        local hitNear, isTwinNear = food.checkCollision(12, 11, 2, 20, 20)
        harness.assert_true(hitNear, "should detect food within magnet range 2")
        harness.assert_false(isTwinNear)

        -- Head at (13, 10), distance dx = 3 (out of range 2)
        local hitFar = food.checkCollision(13, 10, 2, 20, 20)
        harness.assert_false(hitFar, "should not detect food outside magnet range 2")
    end)

    harness.it("checkCollision handles boundary wrap-around with magnet active", function()
        local ancho, alto = 20, 20
        -- Food at right boundary x = 19, y = 5
        food.pos.x = 19
        food.pos.y = 5

        -- Snake head at left boundary x = 0, y = 5 (wrap distance = 1)
        local hitWrap = food.checkCollision(0, 5, 2, ancho, alto)
        harness.assert_true(hitWrap, "should attract across screen wrap boundary (x=0 to x=19)")
    end)

    harness.it("integrates with snake.mover for magnet-based consumption", function()
        local s = snakeMod.reset()
        s.body = {{x = 4, y = 5}, {x = 3, y = 5}, {x = 2, y = 5}}
        s.dirX = 1
        s.dirY = 0
        s.inputQueue = {{x = 1, y = 0}}

        -- Food at (6, 5). Moving right brings head to (5, 5), distance 1 from food
        food.pos.x = 6
        food.pos.y = 5

        -- Without magnet (magnetRange = 0): head arrives at (5, 5), food is at (6, 5) -> not eaten yet
        local sCopy1 = snakeMod.reset()
        sCopy1.body = {{x = 4, y = 5}, {x = 3, y = 5}, {x = 2, y = 5}}
        sCopy1.dirX = 1; sCopy1.dirY = 0; sCopy1.inputQueue = {{x = 1, y = 0}}
        local vivo1, comio1 = snakeMod.mover(sCopy1, food.pos, 20, 20, nil, 0)
        harness.assert_true(vivo1)
        harness.assert_false(comio1, "should not eat without magnet from distance 1")

        -- With magnet (magnetRange = 2): head arrives at (5, 5), food is at (6, 5) -> eaten by magnet!
        local sCopy2 = snakeMod.reset()
        sCopy2.body = {{x = 4, y = 5}, {x = 3, y = 5}, {x = 2, y = 5}}
        sCopy2.dirX = 1; sCopy2.dirY = 0; sCopy2.inputQueue = {{x = 1, y = 0}}
        local vivo2, comio2 = snakeMod.mover(sCopy2, food.pos, 20, 20, nil, 2)
        harness.assert_true(vivo2)
        harness.assert_true(comio2, "should eat with magnet range 2 from distance 1")
    end)
end)

harness.describe("Food Subsystem - Boss Food Objective Filtering", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("identifies non-coin foods as valid boss objective progression", function()
        harness.assert_true(food.isBossFood(constants.FOOD_NORMAL))
        harness.assert_true(food.isBossFood(constants.FOOD_GOLD))
        harness.assert_true(food.isBossFood("fire_pepper"))
        harness.assert_true(food.isBossFood("frost_berry"))
        harness.assert_true(food.isBossFood("constrictor_berry"))
        harness.assert_true(food.isBossFood("slimming_berry"))
        harness.assert_true(food.isBossFood("repelling_orbit"))
        harness.assert_true(food.isBossFood("bomb"))
        harness.assert_true(food.isBossFood("prismatic"))
        harness.assert_true(food.isBossFood("streak_diamond"))
        harness.assert_true(food.isBossFood("twin"))
    end)

    harness.it("filters out coin foods from boss objective progression", function()
        harness.assert_false(food.isBossFood(constants.FOOD_COIN))
        harness.assert_false(food.isBossFood("coin"))
    end)

    harness.it("isBossFood defaults to current food.tipo when argument is omitted", function()
        food.tipo = constants.FOOD_GOLD
        harness.assert_true(food.isBossFood())

        food.tipo = constants.FOOD_COIN
        harness.assert_false(food.isBossFood())
    end)
end)

harness.describe("Food Subsystem - Visuals, Glow & Render Safety", function()
    harness.before_each(function()
        food.reset()
    end)

    harness.it("getTypeGlow returns valid RGB tables for all 12 types", function()
        local types = {
            constants.FOOD_NORMAL, constants.FOOD_GOLD, constants.FOOD_COIN,
            "fire_pepper", "frost_berry", "constrictor_berry", "slimming_berry",
            "repelling_orbit", "bomb", "prismatic", "streak_diamond", "twin",
            "normal", "gold", "coin"
        }
        for _, t in ipairs(types) do
            local glow = food.getTypeGlow(t)
            harness.assert_not_nil(glow)
            harness.assert_equal(3, #glow)
            harness.assert_gte(glow[1], 0)
            harness.assert_lte(glow[1], 1)
            harness.assert_gte(glow[2], 0)
            harness.assert_lte(glow[2], 1)
            harness.assert_gte(glow[3], 0)
            harness.assert_lte(glow[3], 1)
        end
    end)

    harness.it("draws all 12 food types without runtime errors", function()
        local types = {
            constants.FOOD_NORMAL, constants.FOOD_GOLD, constants.FOOD_COIN,
            "fire_pepper", "frost_berry", "constrictor_berry", "slimming_berry",
            "repelling_orbit", "bomb", "prismatic", "streak_diamond", "twin"
        }

        for _, t in ipairs(types) do
            food.generar(nil, 20, 20, nil, t, 5, 5)
            local ok = pcall(function() food.draw(1.23, 0.016) end)
            harness.assert_true(ok, "food.draw should execute cleanly for type: " .. tostring(t))
        end
    end)

    harness.it("draws twin fruit with and without active twin link cleanly", function()
        food.generar(nil, 20, 20, nil, "twin", 5, 5)
        -- With twin link
        local ok1 = pcall(function() food.draw(0.5, 0.016) end)
        harness.assert_true(ok1, "should draw twin with twinPos")

        -- Without twin link (after one fruit eaten)
        food.twinPos = nil
        local ok2 = pcall(function() food.draw(0.5, 0.016) end)
        harness.assert_true(ok2, "should draw twin without twinPos")
    end)
end)

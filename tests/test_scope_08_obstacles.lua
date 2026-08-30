local harness = require("tests.test_harness")
local obstacles = require("entities.obstacles")
local constants = require("constants")

harness.describe("Obstacles Subsystem - Initialization & Lifecycle", function()
    harness.before_each(function()
        obstacles.init()
    end)

    harness.it("initializes empty obstacle lists and flash timers", function()
        harness.assert_equal(0, #obstacles.pos, "pos should be empty")
        harness.assert_equal(0, #obstacles.flashTimers, "flashTimers should be empty")
    end)

    harness.it("reset() and clear() reset all internal state", function()
        obstacles.agregar(5, 5, "wall")
        obstacles.agregar(6, 6, "lava")
        harness.assert_equal(2, #obstacles.pos, "should have 2 obstacles")

        obstacles.reset()
        harness.assert_equal(0, #obstacles.pos, "pos should be empty after reset")
        harness.assert_equal(0, #obstacles.flashTimers, "flashTimers should be empty after reset")

        obstacles.agregar(1, 1, "ice")
        obstacles.clear()
        harness.assert_equal(0, #obstacles.pos, "pos should be empty after clear")
    end)

    harness.it("defines valid obstacle types and defaults", function()
        harness.assert_not_nil(obstacles.TYPES.WALL)
        harness.assert_not_nil(obstacles.TYPES.TRAP)
        harness.assert_not_nil(obstacles.TYPES.LAVA)
        harness.assert_not_nil(obstacles.TYPES.ICE)
        harness.assert_not_nil(obstacles.TYPES.SLIME)

        harness.assert_equal("wall", obstacles.TYPE_DEFAULTS.wall.type)
        harness.assert_false(obstacles.TYPE_DEFAULTS.wall.hazard)
        harness.assert_true(obstacles.TYPE_DEFAULTS.lava.hazard)
        harness.assert_false(obstacles.TYPE_DEFAULTS.lava.destructible)
        harness.assert_true(obstacles.TYPE_DEFAULTS.ice.hazard)
        harness.assert_equal(1, obstacles.TYPE_DEFAULTS.ice.slip)
        harness.assert_true(obstacles.TYPE_DEFAULTS.slime.hazard)
        harness.assert_almost_equal(0.5, obstacles.TYPE_DEFAULTS.slime.slowFactor, 0.01)
    end)
end)

harness.describe("Obstacles Subsystem - Spawning & Coordinate Edge Cases", function()
    harness.before_each(function()
        obstacles.init()
    end)

    harness.it("spawns standard obstacles with valid coordinates", function()
        local ok, obs = obstacles.agregar(10, 15)
        harness.assert_true(ok, "should successfully add obstacle")
        harness.assert_equal(10, obs.x)
        harness.assert_equal(15, obs.y)
        harness.assert_equal("wall", obs.type)
        harness.assert_true(obs.destructible)
        harness.assert_equal(1, obs.hp)
        harness.assert_equal(1, #obstacles.pos)
        harness.assert_equal(1, #obstacles.flashTimers)
    end)

    harness.it("sanitizes float coordinates by flooring them to integers", function()
        local ok, obs = obstacles.agregar(4.8, 7.2)
        harness.assert_true(ok)
        harness.assert_equal(4, obs.x)
        harness.assert_equal(7, obs.y)
    end)

    harness.it("rejects invalid coordinate types safely without throwing errors", function()
        local ok1, err1 = obstacles.agregar(nil, 5)
        harness.assert_false(ok1)
        harness.assert_equal("invalid_coords", err1)

        local ok2, err2 = obstacles.agregar(5, "bad_coord")
        harness.assert_false(ok2)
        harness.assert_equal("invalid_coords", err2)

        local ok3, err3 = obstacles.agregar(0/0, 5) -- NaN
        harness.assert_false(ok3)
        harness.assert_equal("invalid_coords", err3)

        local ok4, err4 = obstacles.agregar(math.huge, 5)
        harness.assert_false(ok4)
        harness.assert_equal("invalid_coords", err4)
    end)

    harness.it("prevents duplicate obstacles at the same position", function()
        local ok1, obs1 = obstacles.agregar(3, 4, "wall")
        harness.assert_true(ok1)
        harness.assert_equal(1, #obstacles.pos)

        local ok2, err2, existing = obstacles.agregar(3, 4, "wall")
        harness.assert_false(ok2, "duplicate spawn should return false")
        harness.assert_equal("already_exists", err2)
        harness.assert_equal(obs1, existing)
        harness.assert_equal(1, #obstacles.pos, "pos count should remain 1")
    end)

    harness.it("updates obstacle type when adding over existing with new type", function()
        obstacles.agregar(8, 8, "wall")
        local isWallObs = obstacles.getObstacleAt(8, 8)
        harness.assert_equal("wall", isWallObs.type)

        obstacles.agregar(8, 8, "lava")
        local isLavaObs = obstacles.getObstacleAt(8, 8)
        harness.assert_equal("lava", isLavaObs.type)
        harness.assert_true(isLavaObs.hazard)
        harness.assert_equal(1, #obstacles.pos)
    end)

    harness.it("spawnAt aliases agregar correctly", function()
        local ok, obs = obstacles.spawnAt(12, 18, "ice")
        harness.assert_true(ok)
        harness.assert_equal("ice", obs.type)
        harness.assert_equal(12, obs.x)
        harness.assert_equal(18, obs.y)
    end)
end)

harness.describe("Obstacles Subsystem - Collision & Query Engine", function()
    harness.before_each(function()
        obstacles.init()
        obstacles.agregar(2, 2, "wall")
        obstacles.agregar(4, 4, "trap")
        obstacles.agregar(6, 6, "lava")
        obstacles.agregar(8, 8, "ice")
        obstacles.agregar(10, 10, "slime")
    end)

    harness.it("isObstacle returns true for occupied coordinates and false for empty", function()
        local hasObs, obs = obstacles.isObstacle(2, 2)
        harness.assert_true(hasObs)
        harness.assert_not_nil(obs)
        harness.assert_equal("wall", obs.type)

        local emptyObs = obstacles.isObstacle(0, 0)
        harness.assert_false(emptyObs)

        local invalidObs = obstacles.isObstacle(nil, 2)
        harness.assert_false(invalidObs)
    end)

    harness.it("getObstacleAt returns obstacle and index", function()
        local obs, idx = obstacles.getObstacleAt(6, 6)
        harness.assert_not_nil(obs)
        harness.assert_equal("lava", obs.type)
        harness.assert_equal(3, idx)

        local notFound = obstacles.getObstacleAt(99, 99)
        harness.assert_nil(notFound)
    end)

    harness.it("isHazard identifies hazards vs non-hazard walls", function()
        local isHzWall = obstacles.isHazard(2, 2)
        harness.assert_false(isHzWall, "wall is not a hazard")

        local isHzTrap, typeTrap = obstacles.isHazard(4, 4)
        harness.assert_true(isHzTrap)
        harness.assert_equal("trap", typeTrap)

        local isHzLava, typeLava = obstacles.isHazard(6, 6)
        harness.assert_true(isHzLava)
        harness.assert_equal("lava", typeLava)

        local isHzIce, typeIce = obstacles.isHazard(8, 8)
        harness.assert_true(isHzIce)
        harness.assert_equal("ice", typeIce)

        local isHzSlime, typeSlime = obstacles.isHazard(10, 10)
        harness.assert_true(isHzSlime)
        harness.assert_equal("slime", typeSlime)

        local isHzEmpty = obstacles.isHazard(0, 0)
        harness.assert_false(isHzEmpty)
    end)
end)

harness.describe("Obstacles Subsystem - Procedural Generation & Avoidance", function()
    harness.before_each(function()
        obstacles.init()
    end)

    harness.it("generates obstacles avoiding snake body and food positions", function()
        local snake = {
            body = {
                {x = 5, y = 5},
                {x = 5, y = 6},
                {x = 5, y = 7}
            }
        }
        local foodPos = {x = 10, y = 10}
        local ancho = 20
        local alto = 20

        for _ = 1, 10 do
            local ok, obs = obstacles.generar(snake, foodPos, ancho, alto)
            harness.assert_true(ok)
            harness.assert_not_nil(obs)

            -- Ensure not on snake
            for _, seg in ipairs(snake.body) do
                harness.assert_false(obs.x == seg.x and obs.y == seg.y, "must not spawn on snake")
            end

            -- Ensure not on food
            harness.assert_false(obs.x == foodPos.x and obs.y == foodPos.y, "must not spawn on food")

            -- Ensure within bounds
            harness.assert_gte(obs.x, 0)
            harness.assert_lt(obs.x, ancho)
            harness.assert_gte(obs.y, 0)
            harness.assert_lt(obs.y, alto)
        end
    end)

    harness.it("supports raw snake array without body wrapper", function()
        local rawSnake = {{x = 2, y = 2}, {x = 2, y = 3}}
        local ok, obs = obstacles.generar(rawSnake, nil, 10, 10)
        harness.assert_true(ok)
        harness.assert_not_nil(obs)
    end)

    harness.it("supports multiple food positions in foodPos array", function()
        local snake = {{x = 1, y = 1}}
        local foods = {{x = 2, y = 2}, {x = 3, y = 3}, {x = 4, y = 4}}
        local ok, obs = obstacles.generar(snake, foods, 10, 10)
        harness.assert_true(ok)
        for _, f in ipairs(foods) do
            harness.assert_false(obs.x == f.x and obs.y == f.y)
        end
    end)

    harness.it("handles grid saturation gracefully without infinite loops", function()
        -- 2x2 grid with 4 spots
        local snake = {{x = 0, y = 0}, {x = 0, y = 1}}
        local food = {x = 1, y = 0}
        -- Only (1, 1) is free
        local ok1, obs1 = obstacles.generar(snake, food, 2, 2)
        harness.assert_true(ok1)
        harness.assert_equal(1, obs1.x)
        harness.assert_equal(1, obs1.y)

        -- Now grid is 100% full (2 snake + 1 food + 1 obstacle = 4 tiles)
        local ok2, err2 = obstacles.generar(snake, food, 2, 2)
        harness.assert_false(ok2, "should abort gracefully when grid is full")
        harness.assert_equal("grid_full", err2)
    end)
end)

harness.describe("Obstacles Subsystem - Biome Generator", function()
    harness.before_each(function()
        obstacles.init()
    end)

    harness.it("generates biome-specific hazards based on stage or biome name", function()
        local snake = {{x = 0, y = 0}}
        local food = {x = 1, y = 1}

        -- Stage 2 / Hielo
        local iceObs = obstacles.generarPorBioma("hielo", snake, food, 20, 20, 10)
        harness.assert_equal(10, #iceObs)
        local countsIce = obstacles.getCountsByType()
        harness.assert_gt(countsIce.ice, 0, "should have generated ice hazards")

        -- Stage 3 / Volcan
        obstacles.init()
        local lavaObs = obstacles.generarPorBioma(3, snake, food, 20, 20, 10)
        harness.assert_equal(10, #lavaObs)
        local countsLava = obstacles.getCountsByType()
        harness.assert_gt(countsLava.lava, 0, "should have generated lava hazards")

        -- Stage 4 / Colmena
        obstacles.init()
        local slimeObs = obstacles.generarPorBioma("colmena", snake, food, 20, 20, 10)
        harness.assert_equal(10, #slimeObs)
        local countsSlime = obstacles.getCountsByType()
        harness.assert_gt(countsSlime.slime, 0, "should have generated slime hazards")

        -- Stage 5 / Vacio
        obstacles.init()
        local voidObs = obstacles.generarPorBioma("vacio", snake, food, 20, 20, 10)
        harness.assert_equal(10, #voidObs)
        local countsVoid = obstacles.getCountsByType()
        harness.assert_gt(countsVoid.trap + countsVoid.wall, 0)
    end)
end)

harness.describe("Obstacles Subsystem - Destructibility & Radius Damage", function()
    harness.before_each(function()
        obstacles.init()
        obstacles.agregar(5, 5, "wall", true, 2)
        obstacles.agregar(6, 5, "lava", false, 999) -- Indestructible
        obstacles.agregar(7, 5, "ice", true, 1)
        obstacles.agregar(8, 8, "slime", true, 1)
    end)

    harness.it("destroys destructible obstacles and keeps flashTimers synchronized", function()
        harness.assert_equal(4, #obstacles.pos)
        harness.assert_equal(4, #obstacles.flashTimers)

        local ok, destroyed = obstacles.destruir(7, 5)
        harness.assert_true(ok)
        harness.assert_equal(7, destroyed.x)
        harness.assert_equal(5, destroyed.y)
        harness.assert_equal("ice", destroyed.type)

        harness.assert_equal(3, #obstacles.pos)
        harness.assert_equal(3, #obstacles.flashTimers)
        harness.assert_false(obstacles.isObstacle(7, 5))
    end)

    harness.it("respects indestructible obstacles unless forced", function()
        local ok1, err1 = obstacles.destruir(6, 5, false)
        harness.assert_false(ok1)
        harness.assert_equal("indestructible", err1)
        harness.assert_true(obstacles.isObstacle(6, 5), "lava should still exist")

        local ok2, destroyed = obstacles.destruir(6, 5, true)
        harness.assert_true(ok2, "forced destruction should succeed")
        harness.assert_equal("lava", destroyed.type)
        harness.assert_false(obstacles.isObstacle(6, 5))
    end)

    harness.it("damages obstacles and removes them when hp reaches zero", function()
        -- (5, 5) has 2 hp
        local destroyed1, hp1, obs1 = obstacles.damageAt(5, 5, 1)
        harness.assert_false(destroyed1, "should not be destroyed at 1 hp remaining")
        harness.assert_equal(1, hp1)
        harness.assert_true(obstacles.isObstacle(5, 5))

        local destroyed2, hp2, obs2 = obstacles.damageAt(5, 5, 1)
        harness.assert_true(destroyed2, "should be destroyed when hp reaches 0")
        harness.assert_equal(0, hp2)
        harness.assert_false(obstacles.isObstacle(5, 5))
    end)

    harness.it("destruirEnRadio destroys obstacles in area and preserves out-of-range ones", function()
        -- At (5, 5): wall (destructible), at (6, 5): lava (indestructible), at (7, 5): ice (destructible), at (8, 8): slime (destructible)
        local count, list = obstacles.destruirEnRadio(5, 5, 2, false)
        -- In radius 2 from (5, 5): (5, 5) wall -> destroyed, (6, 5) lava -> skipped (indestructible), (7, 5) ice -> destroyed
        -- (8, 8) is distance 3 away -> untouched
        harness.assert_equal(2, count)
        harness.assert_equal(2, #list)

        harness.assert_false(obstacles.isObstacle(5, 5))
        harness.assert_true(obstacles.isObstacle(6, 5), "lava should remain")
        harness.assert_false(obstacles.isObstacle(7, 5))
        harness.assert_true(obstacles.isObstacle(8, 8), "slime out of range should remain")
        harness.assert_equal(2, #obstacles.pos)
        harness.assert_equal(2, #obstacles.flashTimers)
    end)
end)

harness.describe("Obstacles Subsystem - Timers, Update & Render", function()
    harness.before_each(function()
        obstacles.init()
        obstacles.agregar(1, 1, "wall")
        obstacles.agregar(2, 2, "lava")
    end)

    harness.it("updates flash timers smoothly down to zero", function()
        harness.assert_almost_equal(0.4, obstacles.flashTimers[1], 0.01)
        harness.assert_almost_equal(0.4, obstacles.pos[1].flashTimer, 0.01)

        obstacles.update(0.2)
        harness.assert_almost_equal(0.2, obstacles.flashTimers[1], 0.01)
        harness.assert_almost_equal(0.2, obstacles.pos[1].flashTimer, 0.01)

        obstacles.update(0.3)
        harness.assert_equal(0, obstacles.flashTimers[1])
        harness.assert_equal(0, obstacles.pos[1].flashTimer)
    end)

    harness.it("counts obstacles by type correctly", function()
        obstacles.agregar(3, 3, "ice")
        obstacles.agregar(4, 4, "ice")
        obstacles.agregar(5, 5, "slime")
        obstacles.agregar(6, 6, "trap")

        local counts = obstacles.getCountsByType()
        harness.assert_equal(1, counts.wall)
        harness.assert_equal(1, counts.lava)
        harness.assert_equal(2, counts.ice)
        harness.assert_equal(1, counts.slime)
        harness.assert_equal(1, counts.trap)
        harness.assert_equal(6, counts.total)
    end)

    harness.it("draws all obstacle types without errors during flash and idle phases", function()
        -- During flash phase
        local okFlash = pcall(function() obstacles.draw() end)
        harness.assert_true(okFlash, "obstacles.draw should execute cleanly during flash")

        -- Advance timers to idle phase
        obstacles.update(1.0)
        local okIdle = pcall(function() obstacles.draw() end)
        harness.assert_true(okIdle, "obstacles.draw should execute cleanly during idle phase")
    end)
end)

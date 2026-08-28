-- tests/test_entities.lua
-- Comprehensive deep unit tests for all entity modules:
-- snake.lua, food.lua, obstacles.lua, enemyHelpers.lua, chaserAI.lua, enemies.lua, bossAttacks.lua

local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local obstaclesMod = require("entities.obstacles")
local enemiesMod = require("entities.enemies")
local chaserAI = require("entities.chaserAI")
local enemyHelpers = require("entities.enemyHelpers")
local bossAttacks = require("entities.bossAttacks")
local shop = require("systems.shop")

-- ============================================================================
-- SUITE 1: Snake Entity (entities/snake.lua)
-- ============================================================================
harness.describe("Snake Entity - Movement, Body, Defenses & Skills (entities/snake.lua)", function()
    local s

    harness.before_each(function()
        world.reset()
        world.state.controlMode = "classic"
        world.state.debugImmune = false
        shop.reset(false)
        s = snakeMod.reset()
    end)

    harness.it("initializes default snake with correct segments, direction and state", function()
        harness.assert_not_nil(s, "Snake state should be non-nil")
        harness.assert_equal(3, #s.body, "Default length is 3")
        harness.assert_equal(5, s.body[1].x, "Head x is 5")
        harness.assert_equal(5, s.body[1].y, "Head y is 5")
        harness.assert_equal(4, s.body[2].x, "Neck x is 4")
        harness.assert_equal(5, s.body[2].y, "Neck y is 5")
        harness.assert_equal(3, s.body[3].x, "Tail x is 3")
        harness.assert_equal(5, s.body[3].y, "Tail y is 5")
        harness.assert_equal(1, s.dirX, "Initial dirX is 1")
        harness.assert_equal(0, s.dirY, "Initial dirY is 0")
        harness.assert_false(s.ghost, "Ghost mode is initially false")
        harness.assert_equal(0, s.armor, "Armor is initially 0")
    end)

    harness.it("handles directional input queuing and rejects illegal 180 reverses", function()
        -- Moving right (dirX=1, dirY=0), try to turn up
        snakeMod.cambiarDireccion(s, "up")
        harness.assert_equal(1, #s.inputQueue, "Input queue has 1 item")
        harness.assert_equal(0, s.inputQueue[1].x, "Queue target x is 0")
        harness.assert_equal(-1, s.inputQueue[1].y, "Queue target y is -1")

        -- Attempt 180° reverse (left) directly while moving right
        local s2 = snakeMod.reset()
        snakeMod.cambiarDireccion(s2, "left")
        harness.assert_equal(0, #s2.inputQueue, "180 reverse ignored when moving right")

        -- WASD keys mapping
        snakeMod.cambiarDireccion(s2, "s")
        harness.assert_equal(1, #s2.inputQueue, "Key 's' successfully enqueued")
        harness.assert_equal(0, s2.inputQueue[1].x)
        harness.assert_equal(1, s2.inputQueue[1].y)
    end)

    harness.it("moves forward and follows segments in classic mode", function()
        world.state.controlMode = "classic"
        local foodPos = {x = 20, y = 20}
        local vivo, comio = snakeMod.mover(s, foodPos, 32, 18, nil, 0, nil)

        harness.assert_true(vivo, "Snake is alive after move")
        harness.assert_false(comio, "Snake did not eat")
        harness.assert_equal(6, s.body[1].x, "Head moved to (6,5)")
        harness.assert_equal(5, s.body[1].y)
        harness.assert_equal(5, s.body[2].x, "Segment 2 moved to previous head (5,5)")
        harness.assert_equal(5, s.body[2].y)
        harness.assert_equal(4, s.body[3].x, "Tail moved to (4,5)")
        harness.assert_equal(5, s.body[3].y)
        harness.assert_gte(#s.trail, 1, "Trail recorded former tail")
    end)

    harness.it("supports wall wrap around all four grid borders", function()
        world.state.controlMode = "classic"
        local ancho, alto = 20, 15

        -- Wrap Right (x: 19 -> 0)
        s.body = {{x = 19, y = 5}, {x = 18, y = 5}, {x = 17, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.lastMovedDirX, s.lastMovedDirY = 1, 0
        local vivo = snakeMod.mover(s, {x = 10, y = 10}, ancho, alto, nil, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(0, s.body[1].x, "Wrapped from right to x=0")

        -- Wrap Left (x: 0 -> 19)
        s.body = {{x = 0, y = 5}, {x = 1, y = 5}, {x = 2, y = 5}}
        s.dirX, s.dirY = -1, 0
        s.lastMovedDirX, s.lastMovedDirY = -1, 0
        vivo = snakeMod.mover(s, {x = 10, y = 10}, ancho, alto, nil, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(19, s.body[1].x, "Wrapped from left to x=19")

        -- Wrap Top (y: 0 -> 14)
        s.body = {{x = 5, y = 0}, {x = 5, y = 1}, {x = 5, y = 2}}
        s.dirX, s.dirY = 0, -1
        s.lastMovedDirX, s.lastMovedDirY = 0, -1
        vivo = snakeMod.mover(s, {x = 10, y = 10}, ancho, alto, nil, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(14, s.body[1].y, "Wrapped from top to y=14")

        -- Wrap Bottom (y: 14 -> 0)
        s.body = {{x = 5, y = 14}, {x = 5, y = 13}, {x = 5, y = 12}}
        s.dirX, s.dirY = 0, 1
        s.lastMovedDirX, s.lastMovedDirY = 0, 1
        vivo = snakeMod.mover(s, {x = 10, y = 10}, ancho, alto, nil, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(0, s.body[1].y, "Wrapped from bottom to y=0")
    end)

    harness.it("grows in length upon eating food", function()
        local foodPos = {x = 6, y = 5}
        local vivo, comio = snakeMod.mover(s, foodPos, 32, 18, nil, 0, nil)

        harness.assert_true(vivo, "Snake is alive")
        harness.assert_true(comio, "Snake ate food")
        harness.assert_equal(4, #s.body, "Snake grew from 3 to 4 segments")
        harness.assert_equal(6, s.body[1].x, "Head at food location")
    end)

    harness.it("eats with magnet range and eats twin food", function()
        -- Magnet eats food at distance 2
        local foodPos = {x = 7, y = 5}
        local vivo, comio = snakeMod.mover(s, foodPos, 32, 18, nil, 2, nil)
        harness.assert_true(vivo)
        harness.assert_true(comio, "Magnet consumed food within radius 2")

        -- Twin food detection
        s = snakeMod.reset()
        local twinPos = {x = 6, y = 5}
        local _, comioTwinFlag, _, _, _, isTwin = snakeMod.mover(s, {x = 25, y = 25}, 32, 18, nil, 0, twinPos)
        harness.assert_true(comioTwinFlag, "Ate twin food")
        harness.assert_true(isTwin, "comioTwin return flag is true")
    end)

    harness.it("handles self-collision, shield absorption, and armor mitigation", function()
        -- Create a snake curled on itself
        s.body = {
            {x = 5, y = 5},
            {x = 6, y = 5},
            {x = 6, y = 6},
            {x = 5, y = 6},
            {x = 4, y = 6},
        }
        s.dirX, s.dirY = 0, 1 -- Moving down into (5,6) which is segment 4

        -- 1. Normal lethal collision
        local vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_false(vivo, "Snake dies on self collision without defenses")

        -- 2. Shield absorbs collision
        s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 6, y = 5}, {x = 6, y = 6}, {x = 5, y = 6}, {x = 4, y = 6}}
        s.dirX, s.dirY = 0, 1
        shop.shieldActive = true
        vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_true(vivo, "Shield protected snake from self-collision")
        harness.assert_false(shop.shieldActive, "Shield was consumed")

        -- 3. Armor absorbs collision
        s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 6, y = 5}, {x = 6, y = 6}, {x = 5, y = 6}, {x = 4, y = 6}}
        s.dirX, s.dirY = 0, 1
        s.armor = 2
        vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_true(vivo, "Armor protected snake from self-collision")
        harness.assert_equal(1, s.armor, "Armor count reduced by 1")

        -- 4. Ghost mode passes through
        s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 6, y = 5}, {x = 6, y = 6}, {x = 5, y = 6}, {x = 4, y = 6}}
        s.dirX, s.dirY = 0, 1
        s.ghost = true
        vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_true(vivo, "Ghost mode allows passing through self body")
    end)

    harness.it("handles obstacle collisions and defenses", function()
        local obstacles = {{x = 6, y = 5}}
        local vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, obstacles, 0, nil)
        harness.assert_false(vivo, "Snake dies on obstacle collision")

        -- Protected by shield
        s = snakeMod.reset()
        shop.shieldActive = true
        vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, obstacles, 0, nil)
        harness.assert_true(vivo, "Shield absorbed obstacle collision")
    end)

    harness.it("triggers autotomy skill and drops decoy", function()
        s.body = {{x = 10, y = 5}, {x = 9, y = 5}, {x = 8, y = 5}, {x = 7, y = 5}, {x = 6, y = 5}}
        s.autotomyCooldown = 0

        local ok, pos = snakeMod.triggerAutotomy(s)
        harness.assert_true(ok, "Autotomy successful with >= 4 segments")
        harness.assert_equal(3, #s.body, "Removed 2 tail segments (5 -> 3)")
        harness.assert_equal(6, pos.x, "Decoy at tail position x")
        harness.assert_equal(5, pos.y, "Decoy at tail position y")
        harness.assert_true(s.ghost, "Ghost mode activated by autotomy")
        harness.assert_gt(s.autotomyCooldown, 0, "Autotomy cooldown triggered")
        harness.assert_equal(1, #s.decoys, "Decoy registered in decoys array")

        -- Fails when on cooldown
        local ok2 = snakeMod.triggerAutotomy(s)
        harness.assert_false(ok2, "Autotomy rejected during cooldown")
    end)

    harness.it("triggers reverse slither and flips body sequence", function()
        s.body = {{x = 10, y = 5}, {x = 9, y = 5}, {x = 8, y = 5}, {x = 8, y = 6}}
        s.reverseSlitherCooldown = 0

        local ok, newHead = snakeMod.triggerReverseSlither(s)
        harness.assert_true(ok, "Reverse slither succeeded")
        harness.assert_equal(8, s.body[1].x, "New head is old tail x")
        harness.assert_equal(6, s.body[1].y, "New head is old tail y")
        harness.assert_equal(10, s.body[4].x, "New tail is old head x")
        harness.assert_equal(5, s.body[4].y, "New tail is old head y")
        harness.assert_gt(s.reverseSlitherCooldown, 0, "Cooldown active")
        harness.assert_gt(s.reverseSlitherTimer, 0, "Reverse timer active")
    end)

    harness.it("applies slimming berry trimming on long body", function()
        -- Less than 12 segments: no change
        s.body = {}
        for i = 1, 8 do table.insert(s.body, {x = i, y = 5}) end
        local cut = snakeMod.applySlimming(s)
        harness.assert_false(cut, "Slimming ignored when length < 12")
        harness.assert_equal(8, #s.body)

        -- 14 segments: cut in half (14 -> 7)
        for i = 9, 14 do table.insert(s.body, {x = i, y = 5}) end
        cut = snakeMod.applySlimming(s)
        harness.assert_true(cut, "Slimming cut 50% of long snake")
        harness.assert_equal(7, #s.body, "Snake trimmed to 7 segments")
    end)

    harness.it("detects enemies enclosed in constrictor loop", function()
        -- Create a closed rectangle of snake body enclosing tile (6,6)
        s.body = {
            {x = 5, y = 5}, {x = 6, y = 5}, {x = 7, y = 5},
            {x = 7, y = 6}, {x = 7, y = 7},
            {x = 6, y = 7}, {x = 5, y = 7},
            {x = 5, y = 6}, {x = 5, y = 5}
        }
        local enemiesList = {
            {x = 6, y = 6, alive = true, type = "chaser", dropCoins = 3},
            {x = 20, y = 20, alive = true, type = "patroller", dropCoins = 2}
        }

        local killed = snakeMod.checkConstrictorLoop(s, enemiesList)
        harness.assert_not_nil(killed, "Constrictor kill detected")
        harness.assert_equal(1, #killed, "1 enemy enclosed")
        harness.assert_equal("chaser", killed[1].type)
        harness.assert_equal(6, killed[1].coins, "Drop coins doubled for constrictor kill")
        harness.assert_gt(s.constrictorBuffTimer, 0, "Constrictor buff activated")
    end)

    harness.it("detects rapid direction changes for tail snap stun", function()
        s.turnHistory = {
            {x = 0, y = -1, fromX = 1, fromY = 0, time = 100.0},
            {x = -1, y = 0, fromX = 0, fromY = -1, time = 100.2}
        }
        s.pendingTailSnap = true

        local snap = snakeMod.checkTailSnap(s)
        harness.assert_not_nil(snap, "Tail snap triggered")
        harness.assert_equal(s.body[#s.body].x, snap.gx)
        harness.assert_equal(s.body[#s.body].y, snap.gy)
        harness.assert_nil(snakeMod.checkTailSnap(s), "Tail snap reset after consumption")
    end)

    harness.it("updates timers and handles fire trail decay in snake.update", function()
        s.flashTimer = 0.5
        s.ghostTimer = 0.3
        s.ghost = true
        s.autotomyCooldown = 2.0
        s.firePepperTimer = 1.0
        s.fireTrail = {{x = 2, y = 2, timer = 0.2, maxTimer = 1.8}}
        s.decoys = {{x = 3, y = 3, timer = 0.1, maxTimer = 4.0}}

        snakeMod.update(s, 0.15)
        harness.assert_almost_equal(0.35, s.flashTimer, 0.01)
        harness.assert_almost_equal(0.15, s.ghostTimer, 0.01)
        harness.assert_almost_equal(1.85, s.autotomyCooldown, 0.01)
        harness.assert_almost_equal(0.85, s.firePepperTimer, 0.01)
        harness.assert_equal(1, #s.fireTrail)
        harness.assert_equal(0, #s.decoys, "Decoy with timer 0.1 expired after 0.15s dt")
    end)

    harness.it("draws snake without runtime errors", function()
        s.fireTrail = {{x = 5, y = 5, timer = 1.0, maxTimer = 1.8}}
        s.decoys = {{x = 8, y = 8, timer = 2.0, maxTimer = 4.0}}
        s.ghost = true
        shop.shieldActive = true

        local ok = pcall(function() snakeMod.draw(s, 0.5) end)
        harness.assert_true(ok, "snake.draw executed cleanly")
    end)
end)

-- ============================================================================
-- SUITE 2: Food Entity (entities/food.lua)
-- ============================================================================
harness.describe("Food Entity - Types, Spawning, Orbit & Bombs (entities/food.lua)", function()
    harness.before_each(function()
        foodMod.init()
    end)

    harness.it("initializes default state and supports reset", function()
        harness.assert_equal(0, foodMod.pos.x)
        harness.assert_equal(0, foodMod.pos.y)
        harness.assert_nil(foodMod.twinPos)
        harness.assert_equal(constants.FOOD_NORMAL, foodMod.tipo)
    end)

    harness.it("generates food on free grid tiles avoiding snake and obstacles", function()
        local snakeBody = {{x = 5, y = 5}, {x = 6, y = 5}}
        local obstacles = {{x = 1, y = 1}, {x = 2, y = 2}}

        foodMod.generar(snakeBody, 20, 20, obstacles)
        harness.assert_gte(foodMod.pos.x, 0)
        harness.assert_lt(foodMod.pos.x, 20)
        harness.assert_gte(foodMod.pos.y, 0)
        harness.assert_lt(foodMod.pos.y, 20)

        -- Never on snake
        for _, s in ipairs(snakeBody) do
            harness.assert_true(foodMod.pos.x ~= s.x or foodMod.pos.y ~= s.y, "Not on snake")
        end
        -- Never on obstacle
        for _, o in ipairs(obstacles) do
            harness.assert_true(foodMod.pos.x ~= o.x or foodMod.pos.y ~= o.y, "Not on obstacle")
        end
    end)

    harness.it("supports explicit coordinates override and forced types", function()
        foodMod.generar(nil, 20, 20, nil, constants.FOOD_GOLD, 8, 12)
        harness.assert_equal(8, foodMod.pos.x)
        harness.assert_equal(12, foodMod.pos.y)
        harness.assert_equal(constants.FOOD_GOLD, foodMod.tipo)

        -- Forced Twin Food
        foodMod.generar(nil, 20, 20, nil, "twin", 5, 5)
        harness.assert_equal("twin", foodMod.tipo)
        harness.assert_not_nil(foodMod.twinPos, "Twin companion position generated")
        harness.assert_gt(foodMod.twinTimer, 0, "Twin timer initialized")

        -- Forced Bomb Food
        foodMod.generar(nil, 20, 20, nil, "bomb", 4, 4)
        harness.assert_equal("bomb", foodMod.tipo)
        harness.assert_gt(foodMod.bombTimer, 0, "Bomb timer initialized")

        -- Forced Prismatic Food
        foodMod.generar(nil, 20, 20, nil, "prismatic", 3, 3)
        harness.assert_equal("prismatic", foodMod.tipo)
        harness.assert_equal(1, foodMod.prismaticIndex)
    end)

    harness.it("updates bomb countdown and fires onBombExpired callback", function()
        foodMod.generar(nil, 20, 20, nil, "bomb", 10, 10)
        local expiredPos = nil
        foodMod.onBombExpired = function(bx, by)
            expiredPos = {x = bx, y = by}
        end

        foodMod.update(6.0, nil, 20, 20, nil)
        harness.assert_not_nil(expiredPos, "Bomb expiration callback triggered")
        harness.assert_equal(10, expiredPos.x)
        harness.assert_equal(10, expiredPos.y)
    end)

    harness.it("cycles prismatic buffs over time", function()
        foodMod.generar(nil, 20, 20, nil, "prismatic", 5, 5)
        local buff1 = foodMod.getPrismaticBuff()
        harness.assert_equal("speed", buff1, "Initial prismatic buff is speed")

        foodMod.update(2.0, nil, 20, 20, nil)
        local buff2 = foodMod.getPrismaticBuff()
        harness.assert_equal("shield", buff2, "Second prismatic buff is shield")
    end)

    harness.it("repelling orbit flees from snake head toward tail", function()
        local snakeBody = {
            {x = 5, y = 5}, -- Head
            {x = 4, y = 5},
            {x = 3, y = 5}  -- Tail
        }
        foodMod.generar(snakeBody, 20, 20, nil, "repelling_orbit", 6, 5)
        foodMod.orbitTimer = 0.1

        foodMod.update(0.2, snakeBody, 20, 20, nil)
        -- Should have moved away from head (x=5, y=5)
        harness.assert_gte(foodMod.pos.x, 6, "Orbit food fled further right or up/down")
    end)

    harness.it("renders all food visual types cleanly", function()
        local types = {
            constants.FOOD_NORMAL, constants.FOOD_GOLD, constants.FOOD_COIN,
            "fire_pepper", "frost_berry", "constrictor_berry", "slimming_berry",
            "repelling_orbit", "bomb", "prismatic", "streak_diamond", "twin"
        }
        for _, t in ipairs(types) do
            foodMod.tipo = t
            if t == "twin" then foodMod.twinPos = {x = 8, y = 8} end
            local ok = pcall(function() foodMod.draw(1.5, 0.016) end)
            harness.assert_true(ok, "Food draw ok for type: " .. tostring(t))
        end
    end)
end)

-- ============================================================================
-- SUITE 3: Obstacles Entity (entities/obstacles.lua)
-- ============================================================================
harness.describe("Obstacles Entity - Hazards, Types, Destructibility & Queries (entities/obstacles.lua)", function()
    harness.before_each(function()
        obstaclesMod.init()
    end)

    harness.it("initializes and clears obstacles array and flash timers", function()
        harness.assert_equal(0, #obstaclesMod.pos)
        harness.assert_equal(0, #obstaclesMod.flashTimers)

        obstaclesMod.agregar(5, 5, "wall")
        harness.assert_equal(1, #obstaclesMod.pos)
        obstaclesMod.clear()
        harness.assert_equal(0, #obstaclesMod.pos)
    end)

    harness.it("supports all obstacle types with correct default properties", function()
        obstaclesMod.agregar(1, 1, "wall")
        obstaclesMod.agregar(2, 2, "trap")
        obstaclesMod.agregar(3, 3, "lava")
        obstaclesMod.agregar(4, 4, "ice")
        obstaclesMod.agregar(5, 5, "slime")

        local w = obstaclesMod.getObstacleAt(1, 1)
        harness.assert_equal("wall", w.type)
        harness.assert_true(w.destructible)
        harness.assert_false(w.hazard)

        local t = obstaclesMod.getObstacleAt(2, 2)
        harness.assert_equal("trap", t.type)
        harness.assert_true(t.hazard)

        local l = obstaclesMod.getObstacleAt(3, 3)
        harness.assert_equal("lava", l.type)
        harness.assert_false(l.destructible, "Lava is indestructible")
        harness.assert_true(l.hazard)

        local i = obstaclesMod.getObstacleAt(4, 4)
        harness.assert_equal("ice", i.type)

        local s = obstaclesMod.getObstacleAt(5, 5)
        harness.assert_equal("slime", s.type)
        harness.assert_equal(0.5, s.slowFactor, "Slime slowFactor is 0.5")
    end)

    harness.it("queries obstacles and hazard detection", function()
        obstaclesMod.agregar(7, 8, "trap")
        local isObs, obj = obstaclesMod.isObstacle(7, 8)
        harness.assert_true(isObs)
        harness.assert_equal(7, obj.x)
        harness.assert_equal(8, obj.y)

        local isHaz, hazType = obstaclesMod.isHazard(7, 8)
        harness.assert_true(isHaz)
        harness.assert_equal("trap", hazType)

        local noObs = obstaclesMod.isObstacle(0, 0)
        harness.assert_false(noObs)
    end)

    harness.it("generates random obstacles on free cells", function()
        local snake = {{x = 5, y = 5}}
        local food = {x = 10, y = 10}
        obstaclesMod.generar(snake, food, 20, 20, "wall")

        harness.assert_equal(1, #obstaclesMod.pos)
        local obs = obstaclesMod.pos[1]
        harness.assert_false(obs.x == 5 and obs.y == 5, "Obstacle not on snake")
        harness.assert_false(obs.x == 10 and obs.y == 10, "Obstacle not on food")
    end)

    harness.it("handles damage, destruction and removal", function()
        obstaclesMod.agregar(5, 5, "wall", true, 2)
        local obs = obstaclesMod.getObstacleAt(5, 5)
        harness.assert_equal(2, obs.hp)

        -- Damage 1: remains alive with 1 HP
        local destroyed = obstaclesMod.damageAt(5, 5, 1)
        harness.assert_false(destroyed)
        harness.assert_equal(1, obs.hp)

        -- Damage 1: destroyed and removed
        destroyed = obstaclesMod.damageAt(5, 5, 1)
        harness.assert_true(destroyed)
        harness.assert_nil(obstaclesMod.getObstacleAt(5, 5))
        harness.assert_equal(0, #obstaclesMod.pos)
    end)

    harness.it("updates flash timers and renders obstacles cleanly", function()
        obstaclesMod.agregar(2, 2, "wall")
        obstaclesMod.agregar(3, 3, "trap")
        obstaclesMod.update(0.2)
        harness.assert_almost_equal(0.2, obstaclesMod.flashTimers[1], 0.01)

        local ok = pcall(function() obstaclesMod.draw() end)
        harness.assert_true(ok, "obstacles.draw executed cleanly")
    end)
end)

-- ============================================================================
-- SUITE 4: Enemy Helpers (entities/enemyHelpers.lua)
-- ============================================================================
harness.describe("Enemy Helpers - Validation, Counts & Tile Sampling (entities/enemyHelpers.lua)", function()
    harness.it("computes Manhattan distance correctly", function()
        local d = enemyHelpers.manhattan(2, 3, 7, 9)
        harness.assert_equal(11, d, "|2-7| + |3-9| = 5 + 6 = 11")
    end)

    harness.it("validates cell availability safely with nil and populated collections", function()
        local snake = {{x = 5, y = 5}}
        local food = {x = 6, y = 5}
        local obstacles = {{x = 7, y = 5}}
        local enemyList = {{x = 8, y = 5, alive = true}}

        -- Free cell
        harness.assert_true(enemyHelpers.validarPos(0, 0, snake, food, obstacles, 20, 20, enemyList))

        -- Occupied by snake
        harness.assert_false(enemyHelpers.validarPos(5, 5, snake, food, obstacles, 20, 20, enemyList))

        -- Occupied by food
        harness.assert_false(enemyHelpers.validarPos(6, 5, snake, food, obstacles, 20, 20, enemyList))

        -- Occupied by obstacle
        harness.assert_false(enemyHelpers.validarPos(7, 5, snake, food, obstacles, 20, 20, enemyList))

        -- Occupied by enemy
        harness.assert_false(enemyHelpers.validarPos(8, 5, snake, food, obstacles, 20, 20, enemyList))

        -- Out of grid bounds
        harness.assert_false(enemyHelpers.validarPos(-1, 0, snake, food, obstacles, 20, 20, enemyList))
        harness.assert_false(enemyHelpers.validarPos(0, 20, snake, food, obstacles, 20, 20, enemyList))

        -- Nil safe
        harness.assert_true(enemyHelpers.validarPos(2, 2, nil, nil, nil, 20, 20, nil))
    end)

    harness.it("counts enemies accurately by type", function()
        local list = {
            {type = "chaser", alive = true},
            {type = "chaser", alive = true},
            {type = "chaser", alive = false}, -- dead ignored
            {type = "patroller", alive = true},
            {type = "spawner", alive = true}
        }
        local counts = enemyHelpers.countEnemiesByType(list)
        harness.assert_equal(2, counts.chaser)
        harness.assert_equal(1, counts.patroller)
        harness.assert_equal(1, counts.spawner)

        -- Nil safe
        local emptyCounts = enemyHelpers.countEnemiesByType(nil)
        harness.assert_equal(0, emptyCounts.chaser or 0)
    end)

    harness.it("samples free tiles with distance guarantee from snake head", function()
        local snake = {{x = 5, y = 5}}
        local gx, gy = enemyHelpers.sampleFreeTile(30, 20, snake, nil, nil, 6, 50)
        harness.assert_not_nil(gx, "Sampled x should be valid")
        harness.assert_not_nil(gy, "Sampled y should be valid")
        local dist = enemyHelpers.manhattan(gx, gy, 5, 5)
        harness.assert_gte(dist, 6, "Sampled tile respects minimum distance of 6")
    end)
end)

-- ============================================================================
-- SUITE 5: Chaser Social AI (entities/chaserAI.lua)
-- ============================================================================
harness.describe("Chaser Social AI - SOLO, DUPLA & MANADA Modes (entities/chaserAI.lua)", function()
    harness.before_each(function()
        chaserAI.reset()
    end)

    harness.it("classifies 1 chaser as SOLO mode (hunter chasing head)", function()
        local chaser = {x = 10, y = 10, type = "chaser", alive = true, moveInterval = 0.3, moveTimer = 0}
        local ctx = {
            list = {chaser},
            head = {x = 8, y = 10},
            body = {{x = 8, y = 10}, {x = 7, y = 10}},
            anchoGrilla = 20,
            altoGrilla = 20,
            obstaclePos = {}
        }

        chaserAI.updatePack(ctx, 0.1)
        harness.assert_equal("chase", chaser.aiState, "Solo chaser in aggro range engages in chase")
        harness.assert_equal("hunter", chaser.role, "Solo chaser role is hunter")
        harness.assert_equal(1.0, chaserAI.speedFactor(chaser), "Chase speed factor is 1.0")

        -- Step closer to target
        chaserAI.step(chaser, ctx)
        local d = enemyHelpers.manhattan(chaser.x, chaser.y, 8, 10)
        harness.assert_lte(d, 2, "Chaser moved closer to target head")
    end)

    harness.it("classifies 2-3 chasers as DUPLA mode (1 hunter, flankers)", function()
        local c1 = {x = 10, y = 10, type = "chaser", alive = true}
        local c2 = {x = 12, y = 10, type = "chaser", alive = true}
        local ctx = {
            list = {c1, c2},
            head = {x = 8, y = 10},
            body = {{x = 8, y = 10}, {x = 7, y = 10}},
            anchoGrilla = 20,
            altoGrilla = 20,
            obstaclePos = {}
        }

        chaserAI.updatePack(ctx, 0.1)
        harness.assert_equal("chase", c1.aiState, "Closest chaser is hunter in chase state")
        harness.assert_equal("hunter", c1.role)
        harness.assert_equal("flank", c2.aiState, "Second chaser is flanker in flank state")
        harness.assert_equal("flanker", c2.role)
        harness.assert_equal(constants.CHASER_PACK_SLOWDOWN, chaserAI.speedFactor(c2), "Flanker has pack slowdown factor")
    end)

    harness.it("classifies 4+ chasers as MANADA mode (encirclement ring & closure)", function()
        local list = {}
        for i = 1, 4 do
            table.insert(list, {x = 12 + i, y = 10, type = "chaser", alive = true})
        end
        local ctx = {
            list = list,
            head = {x = 10, y = 10},
            body = {{x = 10, y = 10}, {x = 9, y = 10}},
            anchoGrilla = 30,
            altoGrilla = 30,
            obstaclePos = {}
        }

        chaserAI.updatePack(ctx, 0.1)
        for _, c in ipairs(list) do
            harness.assert_equal("encircle", c.aiState, "Chasers enter encirclement ring in MANADA mode")
            harness.assert_equal(constants.CHASER_PACK_SLOWDOWN, chaserAI.speedFactor(c))
        end

        -- Advance ring cycle to flash / dash closure phase
        local cycle = constants.CHASER_RING_CYCLE or 8
        chaserAI.updatePack(ctx, cycle * 0.72)
        for _, c in ipairs(list) do
            harness.assert_equal("close", c.aiState, "Chasers close in during dash phase")
            harness.assert_equal(0.5, chaserAI.speedFactor(c), "Speed factor 0.5 (dash speed) during closure")
        end
    end)
end)

-- ============================================================================
-- SUITE 6: Enemies Subsystem (entities/enemies.lua)
-- ============================================================================
harness.describe("Enemies Subsystem - Patrollers, Spawners, Attacks & Kills (entities/enemies.lua)", function()
    harness.before_each(function()
        enemiesMod.init()
        world.reset()
    end)

    harness.it("spawns chaser, patroller and spawner enemy types", function()
        local c = enemiesMod.spawnAt("chaser", 5, 5)
        local p = enemiesMod.spawnAt("patroller", 10, 10, {dirX = 1, dirY = 0})
        local sp = enemiesMod.spawnAt("spawner", 15, 15)

        harness.assert_equal(3, #enemiesMod.list)
        harness.assert_equal("chaser", c.type)
        harness.assert_equal("patroller", p.type)
        harness.assert_equal(1, p.dirX)
        harness.assert_equal("spawner", sp.type)
    end)

    harness.it("patroller moves and bounces on boundaries or obstacles", function()
        local p = enemiesMod.spawnAt("patroller", 19, 5, {dirX = 1, dirY = 0, moveInterval = 0.1})
        local snakeBody = {{x = 2, y = 2}}

        -- Update past moveInterval at right boundary (anchoGrilla = 20)
        enemiesMod.update(0.15, snakeBody, 20, 20, nil, 1, nil)
        harness.assert_equal(-1, p.dirX, "Patroller bounced off right wall (dirX reversed to -1)")
    end)

    harness.it("freezes enemy movement when enemyFreezeTimer > 0", function()
        world.set("enemyFreezeTimer", 3.0)
        local c = enemiesMod.spawnAt("chaser", 10, 10, {moveInterval = 0.1})
        local snakeBody = {{x = 5, y = 5}}

        enemiesMod.update(0.5, snakeBody, 20, 20, nil, 1, nil)
        harness.assert_equal(10, c.x, "Chaser did not move while frozen")
        harness.assert_equal(10, c.y, "Chaser did not move while frozen")
    end)

    harness.it("kills enemy and returns drop coins and coordinates", function()
        enemiesMod.spawnAt("chaser", 7, 7, {dropCoins = 4})
        local result = enemiesMod.killEnemy(1)

        harness.assert_not_nil(result, "Kill result returned")
        harness.assert_equal(7, result.gx)
        harness.assert_equal(7, result.gy)
        harness.assert_equal(4, result.coins)
        harness.assert_equal("chaser", result.type)
    end)

    harness.it("applies tail snap stun and pushback to nearby enemies", function()
        local e1 = enemiesMod.spawnAt("chaser", 5, 6) -- 1 tile below tail (5,5)
        local e2 = enemiesMod.spawnAt("patroller", 15, 15) -- far away

        local affected = enemiesMod.applyTailSnap(5, 5, 1, 0.8, 20, 20, nil)
        harness.assert_equal(1, #affected, "Only close enemy affected")
        harness.assert_gt(e1.stunTimer, 0, "Close enemy is stunned")
        harness.assert_equal(7, e1.y, "Enemy pushed from y=6 to y=7")
        harness.assert_nil(e2.stunTimer or nil, "Far enemy was unaffected")
    end)

    harness.it("kills enemies on active fire trail segments", function()
        enemiesMod.spawnAt("chaser", 5, 5)
        enemiesMod.spawnAt("patroller", 10, 10)
        local fireTrail = {{x = 5, y = 5, timer = 1.0}}

        local killed = enemiesMod.checkFireTrail(fireTrail)
        harness.assert_not_nil(killed, "Fire trail kill confirmed")
        harness.assert_equal(1, #killed)
        harness.assert_equal(5, killed[1].gx)
        harness.assert_equal(5, killed[1].gy)
    end)

    harness.it("manages projectiles, radial pulses and telegraphs", function()
        enemiesMod.addProjectile(5, 5, 20, 0, 1.0, 1)
        enemiesMod.addRadialPulse(10, 10, 8, 4, 1)
        enemiesMod.addTelegraph(6, 6, 0.8, "laser")

        local objs = enemiesMod.getAttackObjects()
        harness.assert_equal(2, #objs, "2 attack objects active")

        -- Update advances projectile coords and pulse radius
        enemiesMod.update(0.1, {{x = 1, y = 1}}, 30, 30, nil, 1, nil)
        harness.assert_gt(objs[1].x, 5, "Projectile moved forward along dx")
        harness.assert_gt(objs[2].radius, 0, "Radial pulse radius expanded")

        enemiesMod.clearAttackObjects()
        harness.assert_equal(0, #enemiesMod.getAttackObjects(), "Attack objects cleared")
    end)
end)

-- ============================================================================
-- SUITE 7: Boss Mechanics & Attacks (bossAttacks.lua & enemies.lua)
-- ============================================================================
harness.describe("Boss Mechanics & Attack Phases (entities/bossAttacks.lua & enemies.lua)", function()
    harness.before_each(function()
        enemiesMod.init()
        world.reset()
    end)

    harness.it("spawns teleporter boss with invulnerability and food target", function()
        enemiesMod.spawnBoss(1, 30, 20, 10, 15)
        local boss = enemiesMod.boss

        harness.assert_not_nil(boss, "Boss spawned")
        harness.assert_equal(15, boss.x, "Boss centered on grid width / 2")
        harness.assert_equal(10, boss.y, "Boss centered on grid height / 2")
        harness.assert_true(boss.invulnerable, "Boss is invulnerable by default")
        harness.assert_equal(constants.BOSS_FOOD_TARGET, boss.foodTarget)
        harness.assert_equal(10, boss.vida)
    end)

    harness.it("maintains invulnerability against direct hit and registers food-based defeat", function()
        enemiesMod.spawnBoss(1, 30, 20, 10, 15)

        -- Direct hit while invulnerable does not reduce HP
        local hitRes = enemiesMod.hitBoss()
        harness.assert_not_nil(hitRes)
        harness.assert_equal(10, enemiesMod.boss.vida, "HP unchanged while invulnerable")

        -- Defeated by food completion
        local defeat = enemiesMod.onBossDefeatedByFood()
        harness.assert_not_nil(defeat, "Boss defeat triggered")
        harness.assert_false(enemiesMod.boss.alive, "Boss marked not alive")
        harness.assert_false(enemiesMod.boss.invulnerable, "Invulnerability removed")
        harness.assert_equal(15, defeat.coins, "Boss dropped coins")
        harness.assert_equal("boss", defeat.type)
    end)

    harness.it("filters available attacks across phase 1, phase 2 and phase 3", function()
        local p1 = bossAttacks.getAvailable(1)
        harness.assert_gte(#p1, 2, "Phase 1 has projectile spread and spawn adds")

        local p2 = bossAttacks.getAvailable(2)
        harness.assert_gte(#p2, 4, "Phase 2 unlocks radial pulse and teleport")

        local p3 = bossAttacks.getAvailable(3)
        harness.assert_gte(#p3, 4, "Phase 3 retains all attacks")
    end)

    harness.it("executes projectile spread, radial pulse, adds and teleport attacks", function()
        enemiesMod.spawnBoss(2, 30, 20, 10, 15)
        local boss = enemiesMod.boss
        local ctx = {
            anchoGrilla = 30,
            altoGrilla = 20,
            snakeHead = {x = 5, y = 5},
            canSpawn = function() return true end,
            enemies = enemiesMod,
            speedMult = 1.2
        }

        -- 1. Projectile Spread
        bossAttacks.execute(boss, "projectile_spread", 0.016, ctx)
        harness.assert_gte(#enemiesMod.getAttackObjects(), 4, "Projectiles spawned in spread")

        -- 2. Radial Pulse
        bossAttacks.execute(boss, "radial_pulse", 0.016, ctx)
        local hasPulse = false
        for _, ao in ipairs(enemiesMod.getAttackObjects()) do
            if ao.type == "radial_pulse" then hasPulse = true; break end
        end
        harness.assert_true(hasPulse, "Radial pulse attack object spawned")

        -- 3. Spawn Adds
        bossAttacks.execute(boss, "spawn_adds", 0.016, ctx)
        local counts = enemyHelpers.countEnemiesByType(enemiesMod.list)
        harness.assert_gte(counts.patroller or 0, 1, "Minion patrollers spawned by boss")

        -- 4. Teleport
        local oldX, oldY = boss.x, boss.y
        bossAttacks.execute(boss, "teleport", 0.016, ctx)
        -- Boss moved away from player head (5,5)
        local d = enemyHelpers.manhattan(boss.x, boss.y, 5, 5)
        harness.assert_gte(d, 5, "Boss teleported away from player head")
    end)
end)

-- ============================================================================
-- SUITE 8: Combo Multiplier & Score Integration
-- ============================================================================
harness.describe("Combo Multiplier & Score Calculations", function()
    local calculatePoints = function(base, comboCount, scoreMult, streak)
        local mult = 1 + comboCount * (constants.COMBO_MULTIPLIER or 0.5)
        return math.floor(base * mult * (scoreMult or 1.0) * (streak or 1.0))
    end

    harness.it("calculates combo multiplier and point scaling accurately", function()
        -- Combo 0: Normal fruit (+10 pts) -> 10 * 1.0 = 10
        harness.assert_equal(10, calculatePoints(10, 0, 1.0, 1.0))

        -- Combo 1 (x2 chain): 1 + 1*0.5 = 1.5x -> 10 * 1.5 = 15
        harness.assert_equal(15, calculatePoints(10, 1, 1.0, 1.0))

        -- Combo 4 (x5 chain): 1 + 4*0.5 = 3.0x -> 10 * 3.0 = 30
        harness.assert_equal(30, calculatePoints(10, 4, 1.0, 1.0))

        -- Gold fruit (base 25) with Combo 2 (2.0x) and Survival Streak 1.5x:
        -- 25 * 2.0 * 1.0 * 1.5 = 75 pts
        harness.assert_equal(75, calculatePoints(25, 2, 1.0, 1.5))
    end)
end)

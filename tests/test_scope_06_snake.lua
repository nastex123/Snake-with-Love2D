-- Test Scope 06: Snake Entity Module
-- Exhaustive unit tests for entities/snake.lua

local harness = require("tests.test_harness")
local snake = require("entities.snake")
local constants = require("constants")
local shop = require("systems.shop")
local worldState = require("core.world")
local enemies = require("entities.enemies")

-- Helper to create a standard grid environment
local GRID_W = 40
local GRID_H = 28

harness.describe("entities.snake - Initialization and Reset", function()
    harness.it("initializes default state with 3 segments and facing right", function()
        local s = snake.reset()
        harness.assert_not_nil(s, "snake instance created")
        harness.assert_equal(3, #s.body, "initial body length is 3")
        harness.assert_equal(5, s.body[1].x)
        harness.assert_equal(5, s.body[1].y)
        harness.assert_equal(4, s.body[2].x)
        harness.assert_equal(5, s.body[2].y)
        harness.assert_equal(3, s.body[3].x)
        harness.assert_equal(5, s.body[3].y)
        harness.assert_equal(1, s.dirX, "facing right x=1")
        harness.assert_equal(0, s.dirY, "facing right y=0")
        harness.assert_equal(1, s.lastMovedDirX)
        harness.assert_equal(0, s.lastMovedDirY)
        harness.assert_equal(0, #s.inputQueue)
        harness.assert_equal(3, #s.prevBody)
        harness.assert_equal(false, s.ghost)
        harness.assert_equal(0, s.ghostTimer)
        harness.assert_equal(0, s.armor)
        harness.assert_equal(0, s.flashTimer)
        harness.assert_equal(0, s.autotomyCooldown)
        harness.assert_equal(0, #s.decoys)
        harness.assert_equal(0, s.constrictorBuffTimer)
        harness.assert_equal(0, s.reverseSlitherTimer)
        harness.assert_equal(0, s.reverseSlitherCooldown)
        harness.assert_equal(0, s.firePepperTimer)
        harness.assert_equal(0, #s.fireTrail)
        harness.assert_equal(0, #s.turnHistory)
        harness.assert_equal(false, s.pendingTailSnap)
        harness.assert_equal(true, s.standstill)
        harness.assert_equal(false, s.hasNewInput)
    end)
end)

harness.describe("entities.snake - Movement and Tactical Standstill", function()
    harness.before_each(function()
        worldState.reset()
        shop.reset(false)
        enemies.list = {}
        enemies.boss = nil
    end)

    harness.it("stands still in tactical mode when no directional key/input active", function()
        worldState.set("controlMode", "tactical")
        local s = snake.reset()
        local vivo, comio = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "snake remains alive")
        harness.assert_false(comio, "snake did not eat")
        harness.assert_true(s.standstill, "standstill is true")
        harness.assert_equal(5, s.body[1].x, "head x unchanged")
        harness.assert_equal(5, s.body[1].y, "head y unchanged")
    end)

    harness.it("advances 1 tile when input queue has direction", function()
        worldState.set("controlMode", "tactical")
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local vivo, comio = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "snake alive")
        harness.assert_false(comio, "did not eat")
        harness.assert_false(s.standstill, "standstill is false")
        harness.assert_equal(6, s.body[1].x, "head moved from 5 to 6")
        harness.assert_equal(5, s.body[1].y, "head y is 5")
        harness.assert_equal(5, s.body[2].x, "segment 2 moved to 5")
        harness.assert_equal(4, s.body[3].x, "segment 3 moved to 4")
        harness.assert_equal(3, #s.body, "length remains 3")
        harness.assert_gte(#s.trail, 1, "tail added to trail")
    end)

    harness.it("updates prevBody for rendering interpolation", function()
        local s = snake.reset()
        s.inputQueue = {{x = 0, y = 1}} -- move down
        snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_equal(5, s.prevBody[1].x, "prevBody head x")
        harness.assert_equal(5, s.prevBody[1].y, "prevBody head y")
        harness.assert_equal(5, s.body[1].x, "current head x")
        harness.assert_equal(6, s.body[1].y, "current head y")
    end)

    harness.it("guards against nil snake or empty body in mover safely", function()
        local v1, c1 = snake.mover(nil, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(v1)
        harness.assert_false(c1)

        local v2, c2 = snake.mover({body = {}}, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(v2)
        harness.assert_false(c2)
    end)
end)

harness.describe("entities.snake - Eating and Growth", function()
    harness.before_each(function()
        worldState.reset()
        shop.reset(false)
        enemies.list = {}
    end)

    harness.it("grows body by 1 and retains tail when eating primary food", function()
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local foodPos = {x = 6, y = 5}
        local vivo, comio, enemyKilled, bossResult, attackHit, comioTwin = snake.mover(s, foodPos, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo)
        harness.assert_true(comio, "comio is true")
        harness.assert_nil(enemyKilled)
        harness.assert_nil(bossResult)
        harness.assert_nil(attackHit)
        harness.assert_false(comioTwin or false)
        harness.assert_equal(4, #s.body, "body grew from 3 to 4")
        harness.assert_equal(6, s.body[1].x)
        harness.assert_equal(3, s.body[4].x, "old tail preserved")
    end)

    harness.it("detects twin food consumption and flags comioTwin", function()
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local foodPos = {x = 10, y = 10}
        local twinPos = {x = 6, y = 5}
        local vivo, comio, enemyKilled, bossResult, attackHit, comioTwin = snake.mover(s, foodPos, GRID_W, GRID_H, {}, 0, twinPos)
        harness.assert_true(vivo)
        harness.assert_true(comio)
        harness.assert_true(comioTwin, "comioTwin is true")
        harness.assert_equal(4, #s.body)
    end)

    harness.it("attracts food within magnetRange", function()
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}} -- head moves to (6, 5)
        local foodPos = {x = 7, y = 6} -- distance dx=1, dy=1 from (6,5)
        local vivo, comio = snake.mover(s, foodPos, GRID_W, GRID_H, {}, 2, nil)
        harness.assert_true(vivo)
        harness.assert_true(comio, "eaten via magnet range 2")
        harness.assert_equal(4, #s.body)
    end)

    harness.it("leaves fireTrail when moving with firePepper active without eating", function()
        local s = snake.reset()
        s.firePepperTimer = 3.0
        s.inputQueue = {{x = 1, y = 0}}
        snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_equal(1, #s.fireTrail, "1 fire trail segment created")
        harness.assert_equal(3, s.fireTrail[1].x, "placed at old tail position x=3")
        harness.assert_equal(5, s.fireTrail[1].y, "placed at old tail position y=5")
        harness.assert_gt(s.fireTrail[1].timer, 0)
    end)
end)

harness.describe("entities.snake - Wall Wrap and Biome Boundaries", function()
    harness.before_each(function()
        worldState.reset()
        shop.reset(false)
        enemies.list = {}
    end)

    harness.it("wraps around right boundary to x=0 in wrapping biomes", function()
        local s = snake.reset()
        s.body[1] = {x = GRID_W - 1, y = 10}
        s.body[2] = {x = GRID_W - 2, y = 10}
        s.body[3] = {x = GRID_W - 3, y = 10}
        s.inputQueue = {{x = 1, y = 0}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(0, s.body[1].x, "wrapped from GRID_W-1 to 0")
        harness.assert_equal(10, s.body[1].y)
    end)

    harness.it("wraps around left boundary to x=GRID_W-1", function()
        local s = snake.reset()
        s.body[1] = {x = 0, y = 10}
        s.body[2] = {x = 1, y = 10}
        s.body[3] = {x = 2, y = 10}
        s.inputQueue = {{x = -1, y = 0}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(GRID_W - 1, s.body[1].x, "wrapped from 0 to GRID_W-1")
    end)

    harness.it("wraps around top boundary to y=GRID_H-1", function()
        local s = snake.reset()
        s.body[1] = {x = 10, y = 0}
        s.body[2] = {x = 10, y = 1}
        s.body[3] = {x = 10, y = 2}
        s.inputQueue = {{x = 0, y = -1}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(GRID_H - 1, s.body[1].y, "wrapped from 0 to GRID_H-1")
    end)

    harness.it("wraps around bottom boundary to y=0", function()
        local s = snake.reset()
        s.body[1] = {x = 10, y = GRID_H - 1}
        s.body[2] = {x = 10, y = GRID_H - 2}
        s.body[3] = {x = 10, y = GRID_H - 3}
        s.inputQueue = {{x = 0, y = 1}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(0, s.body[1].y, "wrapped from GRID_H-1 to 0")
    end)

    harness.it("causes death in non-wrap biome when hitting boundary", function()
        local worldFacade = require("world.world")
        worldFacade.etapa = 5 -- Stage 5 Vacío has wallWrap = false
        local s = snake.reset()
        s.body[1] = {x = 0, y = 10}
        s.body[2] = {x = 1, y = 10}
        s.body[3] = {x = 2, y = 10}
        s.inputQueue = {{x = -1, y = 0}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(vivo, "dies when hitting border in non-wrap biome")
        worldFacade.etapa = 1 -- reset
    end)

    harness.it("consumes shield when hitting boundary in non-wrap biome", function()
        local worldFacade = require("world.world")
        worldFacade.etapa = 5
        shop.shieldActive = true
        local s = snake.reset()
        s.body[1] = {x = 0, y = 10}
        s.body[2] = {x = 1, y = 10}
        s.body[3] = {x = 2, y = 10}
        s.inputQueue = {{x = -1, y = 0}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives via shield")
        harness.assert_false(shop.shieldActive, "shield broken")
        worldFacade.etapa = 1
    end)

    harness.it("consumes armor when hitting boundary in non-wrap biome", function()
        local worldFacade = require("world.world")
        worldFacade.etapa = 5
        local s = snake.reset()
        s.armor = 2
        s.body[1] = {x = 0, y = 10}
        s.body[2] = {x = 1, y = 10}
        s.body[3] = {x = 2, y = 10}
        s.inputQueue = {{x = -1, y = 0}}
        local vivo = snake.mover(s, {x = 5, y = 5}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives via armor")
        harness.assert_equal(1, s.armor, "armor reduced from 2 to 1")
        worldFacade.etapa = 1
    end)
end)

harness.describe("entities.snake - Body Collisions and Defense Buffs", function()
    harness.before_each(function()
        worldState.reset()
        shop.reset(false)
        enemies.list = {}
    end)

    local function makeLoopSnake()
        return {
            body = {
                {x = 5, y = 5}, -- head facing down
                {x = 5, y = 4},
                {x = 6, y = 4},
                {x = 6, y = 6},
                {x = 5, y = 6}  -- body segment at (5, 6)
            },
            dirX = 0,
            dirY = 1,
            lastMovedDirX = 0,
            lastMovedDirY = 1,
            inputQueue = {{x = 0, y = 1}},
            prevBody = {},
            trail = {},
            ghost = false,
            armor = 0
        }
    end

    harness.it("dies on self-collision without active defenses", function()
        local s = makeLoopSnake()
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(vivo, "dies on body collision")
    end)

    harness.it("passes through own body with ghost active", function()
        local s = makeLoopSnake()
        s.ghost = true
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives body collision with ghost")
        harness.assert_equal(5, s.body[1].x)
        harness.assert_equal(6, s.body[1].y)
    end)

    harness.it("passes through own body with debugImmune", function()
        worldState.set("debugImmune", true)
        local s = makeLoopSnake()
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives body collision with debugImmune")
        worldState.set("debugImmune", false)
    end)

    harness.it("absorbs body collision with shield and breaks shield", function()
        shop.shieldActive = true
        local s = makeLoopSnake()
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives body collision with shield")
        harness.assert_false(shop.shieldActive, "shield broken")
    end)

    harness.it("absorbs body collision with armor and decrements armor count", function()
        local s = makeLoopSnake()
        s.armor = 2
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives body collision with armor")
        harness.assert_equal(1, s.armor, "armor reduced from 2 to 1")
    end)
end)

harness.describe("entities.snake - Obstacle Collisions", function()
    harness.before_each(function()
        worldState.reset()
        shop.reset(false)
        enemies.list = {}
    end)

    harness.it("dies on obstacle collision without defenses", function()
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}} -- head moves to (6, 5)
        local obstacles = {{x = 6, y = 5}}
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, obstacles, 0, nil)
        harness.assert_false(vivo, "dies on obstacle")
    end)

    harness.it("survives obstacle with debugImmune", function()
        worldState.set("debugImmune", true)
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local obstacles = {{x = 6, y = 5}}
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, obstacles, 0, nil)
        harness.assert_true(vivo)
        worldState.set("debugImmune", false)
    end)

    harness.it("absorbs obstacle collision with shield", function()
        shop.shieldActive = true
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local obstacles = {{x = 6, y = 5}}
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, obstacles, 0, nil)
        harness.assert_true(vivo)
        harness.assert_false(shop.shieldActive, "shield broken")
    end)

    harness.it("absorbs obstacle collision with armor", function()
        local s = snake.reset()
        s.armor = 1
        s.inputQueue = {{x = 1, y = 0}}
        local obstacles = {{x = 6, y = 5}}
        local vivo = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, obstacles, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(0, s.armor, "armor reduced to 0")
    end)
end)

harness.describe("entities.snake - Enemy and Boss Collisions", function()
    harness.before_each(function()
        worldState.reset()
        shop.reset(false)
        enemies.list = {
            {x = 6, y = 5, alive = true, type = "chaser", dropCoins = 3}
        }
        enemies.boss = nil
    end)

    harness.it("dies on enemy collision without defenses and does not kill enemy", function()
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local vivo, comio, enemyKilled = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(vivo, "snake dies")
        harness.assert_nil(enemyKilled, "no kill reward granted on death")
        harness.assert_true(enemies.list[1].alive, "enemy still alive")
    end)

    harness.it("passes through enemy with ghost active without killing it", function()
        local s = snake.reset()
        s.ghost = true
        s.inputQueue = {{x = 1, y = 0}}
        local vivo, comio, enemyKilled = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "survives with ghost")
        harness.assert_nil(enemyKilled, "enemy not killed")
        harness.assert_true(enemies.list[1].alive, "enemy still alive")
        harness.assert_equal(6, s.body[1].x, "head stepped on enemy tile")
    end)

    harness.it("kills enemy and survives when shield absorbs impact", function()
        shop.shieldActive = true
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local vivo, comio, enemyKilled = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo, "snake survives")
        harness.assert_false(shop.shieldActive, "shield broken")
        harness.assert_not_nil(enemyKilled, "enemy kill result returned")
        harness.assert_equal("chaser", enemyKilled.type)
        harness.assert_false(enemies.list[1].alive, "enemy dead")
    end)

    harness.it("kills enemy and survives when armor absorbs impact", function()
        local s = snake.reset()
        s.armor = 2
        s.inputQueue = {{x = 1, y = 0}}
        local vivo, comio, enemyKilled = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_true(vivo)
        harness.assert_equal(1, s.armor, "armor reduced to 1")
        harness.assert_not_nil(enemyKilled)
    end)

    harness.it("handles boss collision and returns bossResult", function()
        enemies.boss = {x = 6, y = 5, alive = true, type = "boss", hp = 5, maxHp = 5}
        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}}
        local vivo, comio, enemyKilled, bossResult = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(vivo, "snake dies hitting boss without defense")
        harness.assert_not_nil(bossResult, "bossResult returned")
    end)

    harness.it("handles projectile attack collision returning attackHit", function()
        local origGetAO = enemies.getAttackObjects
        enemies.getAttackObjects = function()
            return {
                {type = "projectile", x = 6.0, y = 5.0, damage = 1}
            }
        end

        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}} -- head moves to (6, 5)
        local vivo, comio, enemyKilled, bossResult, attackHit = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(vivo, "dies from projectile")
        harness.assert_not_nil(attackHit, "attackHit returned")
        harness.assert_true(attackHit.hit)

        enemies.getAttackObjects = origGetAO
    end)

    harness.it("handles radial pulse attack collision", function()
        local origGetAO = enemies.getAttackObjects
        enemies.getAttackObjects = function()
            return {
                {type = "radial_pulse", cx = 6.0, cy = 8.0, radius = 3.0, damage = 1} -- dist to (6,5) is 3.0
            }
        end

        local s = snake.reset()
        s.inputQueue = {{x = 1, y = 0}} -- moves to (6, 5)
        local vivo, comio, enemyKilled, bossResult, attackHit = snake.mover(s, {x = 20, y = 20}, GRID_W, GRID_H, {}, 0, nil)
        harness.assert_false(vivo, "dies from pulse")
        harness.assert_not_nil(attackHit)

        enemies.getAttackObjects = origGetAO
    end)
end)

harness.describe("entities.snake - Input Queue and Anti-180 Protection", function()
    harness.it("rejects direct 180 degree reversal when moving right", function()
        local s = snake.reset() -- moving right dirX=1, dirY=0
        snake.encolarDireccion(s, -1, 0) -- try left
        harness.assert_equal(0, #s.inputQueue, "direct 180 rejected")
    end)

    harness.it("rejects duplicate direction identical to current", function()
        local s = snake.reset()
        snake.encolarDireccion(s, 1, 0) -- try right again
        harness.assert_equal(0, #s.inputQueue, "duplicate direction ignored")
    end)

    harness.it("enqueues valid perpendicular turn (90 degrees)", function()
        local s = snake.reset()
        snake.encolarDireccion(s, 0, -1) -- turn up
        harness.assert_equal(1, #s.inputQueue)
        harness.assert_equal(0, s.inputQueue[1].x)
        harness.assert_equal(-1, s.inputQueue[1].y)
        harness.assert_true(s.hasNewInput)
    end)

    harness.it("enqueues L-turn sequence with 2 rapid turns", function()
        local s = snake.reset() -- moving right
        snake.encolarDireccion(s, 0, -1) -- 1. turn up
        snake.encolarDireccion(s, -1, 0) -- 2. turn left
        harness.assert_equal(2, #s.inputQueue, "both turns enqueued")
        harness.assert_equal(0, s.inputQueue[1].x)
        harness.assert_equal(-1, s.inputQueue[1].y)
        harness.assert_equal(-1, s.inputQueue[2].x)
        harness.assert_equal(0, s.inputQueue[2].y)
    end)

    harness.it("replaces queued direction if player changes mind on same axis", function()
        local s = snake.reset() -- moving right
        snake.encolarDireccion(s, 0, -1) -- turn up
        snake.encolarDireccion(s, 0, 1)  -- changed mind: turn down
        harness.assert_equal(1, #s.inputQueue, "queue length remains 1")
        harness.assert_equal(0, s.inputQueue[1].x)
        harness.assert_equal(1, s.inputQueue[1].y, "replaced with down")
    end)

    harness.it("replaces second queued direction if third direction is entered", function()
        local s = snake.reset()
        snake.encolarDireccion(s, 0, -1) -- up
        snake.encolarDireccion(s, -1, 0) -- left
        snake.encolarDireccion(s, 1, 0)  -- right
        harness.assert_equal(2, #s.inputQueue)
        harness.assert_equal(1, s.inputQueue[2].x, "second slot replaced with latest intention")
    end)

    harness.it("detects rapid U-turn and sets pendingTailSnap", function()
        local s = snake.reset()
        s.lastMovedDirX = 1
        s.lastMovedDirY = 0
        snake.encolarDireccion(s, 0, -1) -- turn up from right
        snake.encolarDireccion(s, -1, 0) -- turn left from up
        harness.assert_true(s.pendingTailSnap, "tail snap detected on rapid U-turn")

        local snap = snake.checkTailSnap(s)
        harness.assert_not_nil(snap)
        harness.assert_equal(3, snap.gx, "tail grid x")
        harness.assert_equal(5, snap.gy, "tail grid y")
        harness.assert_false(s.pendingTailSnap, "cleared after consumption")
    end)

    harness.it("handles cambiarDireccion with arrows, WASD, and case normalization", function()
        local s = snake.reset()
        snake.cambiarDireccion(s, "Up")
        harness.assert_equal(1, #s.inputQueue)
        harness.assert_equal(-1, s.inputQueue[1].y)

        s = snake.reset()
        s.lastMovedDirX = 0
        s.lastMovedDirY = 1 -- moving down
        snake.cambiarDireccion(s, "w") -- 180 rejected
        harness.assert_equal(0, #s.inputQueue)

        snake.cambiarDireccion(s, "D") -- turn right
        harness.assert_equal(1, #s.inputQueue)
        harness.assert_equal(1, s.inputQueue[1].x)

        snake.cambiarDireccion(s, nil) -- nil safe
    end)
end)

harness.describe("entities.snake - Reverse Slither Ability", function()
    harness.it("reverses body order and updates direction smoothly", function()
        local s = {
            body = {
                {x = 10, y = 5}, -- head
                {x = 9, y = 5},
                {x = 8, y = 5},  -- tail
            },
            dirX = 1,
            dirY = 0,
            reverseSlitherCooldown = 0
        }
        local ok, newHead = snake.triggerReverseSlither(s)
        harness.assert_true(ok)
        harness.assert_equal(8, s.body[1].x, "new head is old tail x=8")
        harness.assert_equal(10, s.body[3].x, "new tail is old head x=10")
        harness.assert_equal(-1, s.dirX, "new direction is left (x=-1)")
        harness.assert_equal(0, s.dirY)
        harness.assert_true(s.ghost, "grants temporary ghost")
        harness.assert_gt(s.ghostTimer, 0)
        harness.assert_gt(s.reverseSlitherTimer, 0)
        harness.assert_gt(s.reverseSlitherCooldown, 0)
    end)

    harness.it("handles vertical reverse slither correctly", function()
        local s = {
            body = {
                {x = 5, y = 10}, -- head moving down
                {x = 5, y = 9},
                {x = 5, y = 8},  -- tail
            },
            dirX = 0,
            dirY = 1,
            reverseSlitherCooldown = 0
        }
        local ok = snake.triggerReverseSlither(s)
        harness.assert_true(ok)
        harness.assert_equal(8, s.body[1].y, "new head y=8")
        harness.assert_equal(0, s.dirX, "dirX is 0")
        harness.assert_equal(-1, s.dirY, "dirY is -1 (up)")
    end)

    harness.it("handles reverse slither across wrapped grid borders", function()
        local s = {
            body = {
                {x = 0, y = 5},  -- head
                {x = 39, y = 5}, -- neck across border
                {x = 38, y = 5}, -- tail
            },
            dirX = 1,
            dirY = 0,
            reverseSlitherCooldown = 0
        }
        local ok = snake.triggerReverseSlither(s)
        harness.assert_true(ok)
        harness.assert_equal(38, s.body[1].x)
        harness.assert_equal(-1, s.dirX, "moves left towards tail direction")
    end)

    harness.it("fails when on cooldown or body too short", function()
        local s = snake.reset()
        s.reverseSlitherCooldown = 5.0
        harness.assert_false(snake.triggerReverseSlither(s), "fails on cooldown")

        s.reverseSlitherCooldown = 0
        s.body = {{x = 5, y = 5}} -- length 1
        harness.assert_false(snake.triggerReverseSlither(s), "fails with length 1")
    end)
end)

harness.describe("entities.snake - Autotomy and Slimming", function()
    harness.it("triggers autotomy: drops 2 tail segments, spawns decoy, grants ghost", function()
        local s = {
            body = {
                {x = 10, y = 5},
                {x = 9, y = 5},
                {x = 8, y = 5},
                {x = 7, y = 5},
                {x = 6, y = 5}
            },
            autotomyCooldown = 0,
            decoys = {}
        }
        local ok, decoy = snake.triggerAutotomy(s)
        harness.assert_true(ok)
        harness.assert_equal(3, #s.body, "body reduced by 2 (from 5 to 3)")
        harness.assert_equal(1, #s.decoys, "1 decoy added")
        harness.assert_equal(6, s.decoys[1].x, "decoy at dropped tail x=6")
        harness.assert_equal(5, s.decoys[1].y, "decoy at dropped tail y=5")
        harness.assert_true(s.ghost, "ghost enabled")
        harness.assert_gt(s.ghostTimer, 0)
        harness.assert_gt(s.autotomyCooldown, 0)
        harness.assert_equal(3, #s.prevBody, "prevBody synced")
    end)

    harness.it("fails autotomy when body length < 4 or on cooldown", function()
        local s = snake.reset() -- length 3
        harness.assert_false(snake.triggerAutotomy(s), "fails with length 3")

        s.body = {{x=1,y=1}, {x=2,y=1}, {x=3,y=1}, {x=4,y=1}}
        s.autotomyCooldown = 4.0
        harness.assert_false(snake.triggerAutotomy(s), "fails on cooldown")
    end)

    harness.it("applies slimming: cuts body length by 50% if length >= 12", function()
        local body = {}
        for i = 1, 16 do
            table.insert(body, {x = i, y = 10})
        end
        local s = { body = body }
        local cut = snake.applySlimming(s)
        harness.assert_true(cut)
        harness.assert_equal(8, #s.body, "reduced from 16 to 8 (50%)")
        harness.assert_equal(8, #s.prevBody, "prevBody synced to 8")
    end)

    harness.it("does not apply slimming if body length < 12", function()
        local body = {}
        for i = 1, 10 do
            table.insert(body, {x = i, y = 10})
        end
        local s = { body = body }
        harness.assert_false(snake.applySlimming(s), "no cut for len 10")
        harness.assert_equal(10, #s.body)
    end)
end)

harness.describe("entities.snake - Constrictor Loop Detection", function()
    harness.it("detects enemy enclosed inside snake body polygon", function()
        -- Create a closed loop with 8 segments surrounding (5, 5)
        local loopBody = {
            {x = 4, y = 4},
            {x = 5, y = 4},
            {x = 6, y = 4},
            {x = 6, y = 5},
            {x = 6, y = 6},
            {x = 5, y = 6},
            {x = 4, y = 6},
            {x = 4, y = 5}
        }
        local s = {
            body = loopBody,
            constrictorBuffTimer = 0
        }
        local enemiesList = {
            {x = 5, y = 5, alive = true, type = "chaser", dropCoins = 2},
            {x = 15, y = 15, alive = true, type = "patroller", dropCoins = 1}
        }
        local kills = snake.checkConstrictorLoop(s, enemiesList)
        harness.assert_not_nil(kills, "constrictor kills found")
        harness.assert_equal(1, #kills, "1 enemy inside loop")
        harness.assert_equal(1, kills[1].index)
        harness.assert_equal(4, kills[1].coins, "double coins for constrictor kill")
        harness.assert_gt(s.constrictorBuffTimer, 0, "constrictor buff activated")
    end)

    harness.it("returns nil if snake body length < 8", function()
        local s = snake.reset() -- length 3
        local enemiesList = {{x = 5, y = 5, alive = true}}
        harness.assert_nil(snake.checkConstrictorLoop(s, enemiesList))
    end)

    harness.it("does not kill enemy that is outside the loop", function()
        local loopBody = {
            {x = 4, y = 4}, {x = 5, y = 4}, {x = 6, y = 4},
            {x = 6, y = 5}, {x = 6, y = 6}, {x = 5, y = 6},
            {x = 4, y = 6}, {x = 4, y = 5}
        }
        local s = { body = loopBody }
        local enemiesList = {{x = 10, y = 10, alive = true}}
        harness.assert_nil(snake.checkConstrictorLoop(s, enemiesList))
    end)
end)

harness.describe("entities.snake - Timers and Update", function()
    harness.before_each(function()
        shop.reset(false)
    end)

    harness.it("updates all timers and removes expired trail/decoys", function()
        local s = {
            flashTimer = 0.5,
            ghostTimer = 0.5,
            ghost = true,
            autotomyCooldown = 1.0,
            reverseSlitherTimer = 1.0,
            reverseSlitherCooldown = 2.0,
            constrictorBuffTimer = 1.0,
            firePepperTimer = 1.0,
            fireTrail = {
                {x = 1, y = 1, timer = 0.2, maxTimer = 1.0},
                {x = 2, y = 2, timer = 0.8, maxTimer = 1.0}
            },
            decoys = {
                {x = 3, y = 3, timer = 0.2, maxTimer = 4.0},
                {x = 4, y = 4, timer = 1.5, maxTimer = 4.0}
            }
        }

        snake.update(s, 0.3)
        harness.assert_almost_equal(0.2, s.flashTimer, 0.01)
        harness.assert_almost_equal(0.2, s.ghostTimer, 0.01)
        harness.assert_true(s.ghost, "ghost remains active while ghostTimer > 0")
        harness.assert_almost_equal(0.7, s.autotomyCooldown, 0.01)
        harness.assert_almost_equal(0.7, s.reverseSlitherTimer, 0.01)
        harness.assert_almost_equal(1.7, s.reverseSlitherCooldown, 0.01)
        harness.assert_almost_equal(0.7, s.constrictorBuffTimer, 0.01)
        harness.assert_almost_equal(0.7, s.firePepperTimer, 0.01)
        harness.assert_equal(1, #s.fireTrail, "expired fire trail removed")
        harness.assert_equal(2, s.fireTrail[1].x)
        harness.assert_equal(1, #s.decoys, "expired decoy removed")
        harness.assert_equal(4, s.decoys[1].x)

        -- Advance past ghost timer
        snake.update(s, 0.5)
        harness.assert_equal(0, s.ghostTimer)
        harness.assert_false(s.ghost, "ghost disabled when ghostTimer reaches 0")
    end)

    harness.it("handles nil snake argument safely", function()
        snake.update(nil, 0.1) -- must not error
    end)
end)

harness.describe("entities.snake - Rendering Pipeline", function()
    harness.it("draws snake in mock graphics context without errors across various states", function()
        local s = snake.reset()
        s.ghost = true
        s.flashTimer = 0.3
        s.firePepperTimer = 2.0
        s.fireTrail = {{x = 2, y = 2, timer = 1.0, maxTimer = 1.8}}
        s.decoys = {{x = 10, y = 10, timer = 3.0, maxTimer = 4.0}}
        s.trail = {{x = 3, y = 5, alpha = 0.5}}

        snake.draw(s, 0.5)
    end)

    harness.it("draws empty body gracefully", function()
        snake.draw({body = {}}, 0.5)
    end)
end)

-- tests/test_scope_09_enemies.lua
-- Comprehensive Unit Test Suite for Enemies Subsystem & Helpers
-- Covers: Enemy lifecycle, Chaser/Patroller/Spawner/Boss mechanics, Spawn Caps,
-- Boss Food Defeat, Attack Objects/Telegraphs, Helpers & Manhattan Distance.

local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local enemies = require("entities.enemies")
local enemyHelpers = require("entities.enemyHelpers")
local bossAttacks = require("entities.bossAttacks")
local chaserAI = require("entities.chaserAI")

-- Mock love.timer.getTime if needed
love = love or {}
love.timer = love.timer or {}
local fakeTime = 100.0
love.timer.getTime = function() return fakeTime end
local function advanceFakeTime(dt)
    fakeTime = fakeTime + (dt or 1.0)
end

-- =============================================================================
-- 1. ENEMY HELPERS: MANHATTAN DISTANCE & PURE UTILITIES
-- =============================================================================
harness.describe("Enemy Helpers - Manhattan Distance & Math Calculations", function()
    harness.it("calculates exact Manhattan distance between points", function()
        harness.assert_equal(0, enemyHelpers.manhattan(5, 5, 5, 5), "Same point distance is 0")
        harness.assert_equal(7, enemyHelpers.manhattan(0, 0, 3, 4), "Distance (0,0) to (3,4) is 7")
        harness.assert_equal(10, enemyHelpers.manhattan(-2, -3, 3, 2), "Distance with negative coordinates")
        harness.assert_equal(enemyHelpers.manhattan(10, 20, 3, 8), enemyHelpers.manhattanDistance(10, 20, 3, 8), "manhattanDistance is alias")
    end)
end)

-- =============================================================================
-- 2. ENEMY HELPERS: POSITION VALIDATION (validarPos)
-- =============================================================================
harness.describe("Enemy Helpers - Position Validation (validarPos)", function()
    local snake = {{x = 5, y = 5}, {x = 5, y = 6}, {x = 5, y = 7}}
    local foodPos = {x = 10, y = 10}
    local obstacles = {{x = 2, y = 2}, {x = 2, y = 3}}
    local enemyList = {
        {x = 8, y = 8, alive = true, type = "chaser"},
        {x = 9, y = 9, alive = false, type = "patroller"} -- dead enemy
    }

    harness.it("validates free tiles correctly within grid bounds", function()
        harness.assert_true(enemyHelpers.validarPos(0, 0, snake, foodPos, obstacles, 20, 20, enemyList), "Corner (0,0) is free")
        harness.assert_true(enemyHelpers.validarPos(15, 15, snake, foodPos, obstacles, 20, 20, enemyList), "(15,15) is free")
    end)

    harness.it("rejects out-of-bounds coordinates", function()
        harness.assert_false(enemyHelpers.validarPos(-1, 5, snake, foodPos, obstacles, 20, 20, enemyList), "Negative x")
        harness.assert_false(enemyHelpers.validarPos(5, -1, snake, foodPos, obstacles, 20, 20, enemyList), "Negative y")
        harness.assert_false(enemyHelpers.validarPos(20, 5, snake, foodPos, obstacles, 20, 20, enemyList), "x >= width")
        harness.assert_false(enemyHelpers.validarPos(5, 20, snake, foodPos, obstacles, 20, 20, enemyList), "y >= height")
    end)

    harness.it("rejects coordinates occupied by snake body segments", function()
        harness.assert_false(enemyHelpers.validarPos(5, 5, snake, foodPos, obstacles, 20, 20, enemyList), "Snake head")
        harness.assert_false(enemyHelpers.validarPos(5, 6, snake, foodPos, obstacles, 20, 20, enemyList), "Snake body 1")
        harness.assert_false(enemyHelpers.validarPos(5, 7, snake, foodPos, obstacles, 20, 20, enemyList), "Snake body 2")
    end)

    harness.it("rejects coordinates occupied by food", function()
        harness.assert_false(enemyHelpers.validarPos(10, 10, snake, foodPos, obstacles, 20, 20, enemyList), "Food tile")
        -- Support food array
        local foods = {{x = 12, y = 12}, {x = 13, y = 13}}
        harness.assert_false(enemyHelpers.validarPos(12, 12, snake, foods, obstacles, 20, 20, enemyList), "Food array tile")
    end)

    harness.it("rejects coordinates occupied by obstacles (table or module format)", function()
        harness.assert_false(enemyHelpers.validarPos(2, 2, snake, foodPos, obstacles, 20, 20, enemyList), "Obstacle list")
        local obstaclesMod = {pos = {{x = 4, y = 4}}}
        harness.assert_false(enemyHelpers.validarPos(4, 4, snake, foodPos, obstaclesMod, 20, 20, enemyList), "Obstacles module format")
    end)

    harness.it("rejects coordinates occupied by living enemies, but allows dead enemy tiles", function()
        harness.assert_false(enemyHelpers.validarPos(8, 8, snake, foodPos, obstacles, 20, 20, enemyList), "Living enemy tile rejected")
        harness.assert_true(enemyHelpers.validarPos(9, 9, snake, foodPos, obstacles, 20, 20, enemyList), "Dead enemy tile allowed")
    end)

    harness.it("handles nil arguments gracefully without crashing", function()
        harness.assert_true(enemyHelpers.validarPos(5, 5, nil, nil, nil, 20, 20, nil), "All nil collections")
    end)
end)

-- =============================================================================
-- 3. ENEMY HELPERS: COUNTING & TILE SAMPLING
-- =============================================================================
harness.describe("Enemy Helpers - Count by Type & Safe Tile Sampling", function()
    harness.it("counts alive enemies by type accurately", function()
        local list = {
            {type = "chaser", alive = true},
            {type = "chaser", alive = true},
            {type = "chaser", alive = false},
            {type = "patroller", alive = true},
            {type = "spawner", alive = true},
            {type = "spawner", alive = false},
        }
        local counts = enemyHelpers.countEnemiesByType(list)
        harness.assert_equal(2, counts.chaser, "2 alive chasers")
        harness.assert_equal(1, counts.patroller, "1 alive patroller")
        harness.assert_equal(1, counts.spawner, "1 alive spawner")

        local emptyCounts = enemyHelpers.countEnemiesByType({})
        harness.assert_equal(0, emptyCounts.chaser or 0)

        local nilCounts = enemyHelpers.countEnemiesByType(nil)
        harness.assert_equal(0, nilCounts.chaser or 0)
    end)

    harness.it("samples safe tiles maintaining minimum distance from snake head", function()
        local snake = {{x = 10, y = 10}, {x = 9, y = 10}}
        local obstaclesMod = {pos = {{x = 2, y = 2}}}
        local enemyList = {{x = 15, y = 15, alive = true, type = "chaser"}}

        for _ = 1, 10 do
            local gx, gy = enemyHelpers.sampleFreeTile(30, 20, snake, obstaclesMod, enemyList, 6, 40)
            harness.assert_not_nil(gx, "Sampled gx not nil")
            harness.assert_not_nil(gy, "Sampled gy not nil")

            -- Must be >= minDist 6 from head
            local dist = enemyHelpers.manhattan(gx, gy, 10, 10)
            harness.assert_gte(dist, 6, "Distance from snake head must be >= 6")

            -- Must not match obstacle or enemy
            harness.assert_false(gx == 2 and gy == 2, "Cannot spawn on obstacle")
            harness.assert_false(gx == 15 and gy == 15, "Cannot spawn on alive enemy")
        end
    end)

    harness.it("handles small or saturated grids without throwing errors", function()
        local snake = {{x = 0, y = 0}}
        -- Small 2x2 grid
        local gx, gy = enemyHelpers.sampleFreeTile(2, 2, snake, nil, nil, 1, 10)
        -- Could be found or nil, but must not crash
        if gx then
            harness.assert_gte(gx, 0)
            harness.assert_lt(gx, 2)
        end
    end)
end)

-- =============================================================================
-- 4. ENEMY LIFECYCLE & POOLING (init, spawnAt, killEnemy, cleanup)
-- =============================================================================
harness.describe("Enemies Subsystem - Lifecycle & Management", function()
    harness.before_each(function()
        fakeTime = 100.0
        enemies.init()
    end)

    harness.it("initializes empty enemy lists and clean boss state", function()
        harness.assert_equal(0, #enemies.list)
        harness.assert_nil(enemies.boss)
        harness.assert_equal(0, #enemies.getTelegraphs())
        harness.assert_equal(0, #enemies.getAttackObjects())
        harness.assert_equal(0, #enemies.getPendingRespawns())
    end)

    harness.it("spawns chaser with social AI and correct coin drops", function()
        local e = enemies.spawnAt("chaser", 5, 5)
        harness.assert_not_nil(e)
        harness.assert_equal("chaser", e.type)
        harness.assert_equal(5, e.x)
        harness.assert_equal(5, e.y)
        harness.assert_true(e.alive)
        harness.assert_equal(constants.ENEMY_DROP_CHASER, e.dropCoins)
        harness.assert_equal(constants.ENEMY_CHASER_SPEED, e.moveInterval)
        harness.assert_equal("idle", e.aiState)
        harness.assert_equal("hunter", e.role)
        harness.assert_equal(1, #enemies.list)
    end)

    harness.it("spawns patroller with directional velocity and coin drops", function()
        local e = enemies.spawnAt("patroller", 7, 7, {dirX = 1, dirY = 0})
        harness.assert_not_nil(e)
        harness.assert_equal("patroller", e.type)
        harness.assert_equal(1, e.dirX)
        harness.assert_equal(0, e.dirY)
        harness.assert_equal(constants.ENEMY_DROP_PATROLLER, e.dropCoins)
        harness.assert_equal(constants.ENEMY_PATROLLER_SPEED, e.moveInterval)
    end)

    harness.it("spawns spawner with static movement and coin drops", function()
        local e = enemies.spawnAt("spawner", 12, 12)
        harness.assert_not_nil(e)
        harness.assert_equal("spawner", e.type)
        harness.assert_equal(constants.ENEMY_DROP_SPAWNER, e.dropCoins)
        harness.assert_equal(999, e.moveInterval)
    end)

    harness.it("kills enemy via index or object and returns reward loot data", function()
        local e1 = enemies.spawnAt("chaser", 4, 4)
        local e2 = enemies.spawnAt("patroller", 6, 6)
        harness.assert_equal(2, #enemies.list)

        -- Kill e1 by index
        local loot1 = enemies.killEnemy(1)
        harness.assert_not_nil(loot1)
        harness.assert_equal("chaser", loot1.type)
        harness.assert_equal(constants.ENEMY_DROP_CHASER, loot1.coins)
        harness.assert_equal(4, loot1.gx)
        harness.assert_equal(4, loot1.gy)
        harness.assert_false(e1.alive)

        -- Kill e2 by table reference
        local loot2 = enemies.killEnemy(e2)
        harness.assert_not_nil(loot2)
        harness.assert_equal("patroller", loot2.type)
        harness.assert_equal(constants.ENEMY_DROP_PATROLLER, loot2.coins)
        harness.assert_false(e2.alive)

        -- Attempt to kill already dead enemy returns nil
        local lootDead = enemies.killEnemy(e1)
        harness.assert_nil(lootDead)
    end)

    harness.it("removes dead enemies during update pass", function()
        local e1 = enemies.spawnAt("chaser", 4, 4)
        local e2 = enemies.spawnAt("patroller", 6, 6)
        local e3 = enemies.spawnAt("spawner", 8, 8)
        harness.assert_equal(3, #enemies.list)

        enemies.killEnemy(2) -- kill e2
        harness.assert_equal(3, #enemies.list, "Still in list until update runs")

        local snakeBody = {{x = 20, y = 20}}
        enemies.update(0.016, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(2, #enemies.list, "Dead enemy removed on update")
        harness.assert_equal("chaser", enemies.list[1].type)
        harness.assert_equal("spawner", enemies.list[2].type)
    end)
end)

-- =============================================================================
-- 5. SPAWN CAPS & canSpawn LOGIC
-- =============================================================================
harness.describe("Enemies Subsystem - Spawn Caps & canSpawn()", function()
    harness.before_each(function()
        enemies.init()
    end)

    harness.it("allows unlimited spawns when no boss is active", function()
        for i = 1, 10 do
            enemies.spawnAt("chaser", i, 1)
            enemies.spawnAt("patroller", i, 2)
        end
        harness.assert_true(enemies.canSpawn("chaser"), "Chaser allowed when boss not active")
        harness.assert_true(enemies.canSpawn("patroller"), "Patroller allowed when boss not active")
        harness.assert_true(enemies.canSpawn("spawner"), "Spawner allowed")
    end)

    harness.it("enforces BOSS_MAX_RED (3) cap during boss fight", function()
        enemies.spawnBoss(1, 30, 20, 10, 5)
        harness.assert_true(enemies.canSpawn("chaser"))

        enemies.spawnAt("chaser", 1, 1)
        enemies.spawnAt("chaser", 2, 1)
        harness.assert_true(enemies.canSpawn("chaser"), "2/3 chasers allows spawn")

        enemies.spawnAt("chaser", 3, 1)
        harness.assert_false(enemies.canSpawn("chaser"), "3/3 chasers reaches cap (false)")

        -- Killing one allows spawn again
        enemies.killEnemy(1)
        harness.assert_true(enemies.canSpawn("chaser"), "Dead chasers do not count towards cap")
    end)

    harness.it("enforces BOSS_MAX_BLUE (4) cap during boss fight", function()
        enemies.spawnBoss(1, 30, 20, 10, 5)
        harness.assert_true(enemies.canSpawn("patroller"))

        for i = 1, constants.BOSS_MAX_BLUE do
            enemies.spawnAt("patroller", i, 2)
        end
        harness.assert_false(enemies.canSpawn("patroller"), "Patroller cap reached")

        enemies.killEnemy(1)
        harness.assert_true(enemies.canSpawn("patroller"), "Dead patroller frees cap slot")
    end)

    harness.it("generar() respects caps and falls back or aborts gracefully", function()
        enemies.spawnBoss(1, 30, 20, 10, 5)
        -- Fill red cap
        for i = 1, constants.BOSS_MAX_RED do
            enemies.spawnAt("chaser", i, 1)
        end

        local snake = {{x = 20, y = 20}}
        -- Force chaser weight 1.0; should fallback to patroller or spawner
        local generated = enemies.generar(snake, {x = 0, y = 0}, nil, 30, 20, {chaserWeight = 1.0, patrollerWeight = 0, spawnerWeight = 0})
        harness.assert_not_nil(generated)
        harness.assert_equal("patroller", generated.type, "Fell back to patroller when chaser cap full")
    end)
end)

-- =============================================================================
-- 6. BOSS LIFECYCLE, PHASES & FOOD-BASED DEFEAT
-- =============================================================================
harness.describe("Enemies Subsystem - Boss Lifecycle, Phases & Food Defeat", function()
    harness.before_each(function()
        fakeTime = 100.0
        enemies.init()
    end)

    harness.it("spawns boss with invulnerability and food target configuration", function()
        local boss = enemies.spawnBoss(1, 30, 20, 10, 8)
        harness.assert_not_nil(boss)
        harness.assert_equal(15, boss.x, "Boss centered at grid center")
        harness.assert_equal(10, boss.y)
        harness.assert_true(boss.alive)
        harness.assert_true(boss.invulnerable, "Boss is invulnerable to direct hits")
        harness.assert_equal(constants.BOSS_FOOD_TARGET, boss.foodTarget)
        harness.assert_equal(0, boss.foodCollected)
        harness.assert_equal(1, boss.phase)
        harness.assert_equal(8, boss.dropCoins)
    end)

    harness.it("hitBoss() returns hit feedback without reducing HP while invulnerable", function()
        local boss = enemies.spawnBoss(1, 30, 20, 10, 8)
        local res = enemies.hitBoss()
        harness.assert_not_nil(res)
        harness.assert_true(res.hit)
        harness.assert_equal(10, res.vida, "HP does not decrease when invulnerable")
        harness.assert_true(boss.alive)
    end)

    harness.it("hitBoss() deals damage and produces loot when invulnerability is disabled", function()
        local boss = enemies.spawnBoss(1, 30, 20, 2, 8)
        boss.invulnerable = false

        local res1 = enemies.hitBoss()
        harness.assert_equal(1, boss.vida)
        harness.assert_true(boss.alive)

        local res2 = enemies.hitBoss()
        harness.assert_equal(0, boss.vida)
        harness.assert_false(boss.alive)
        harness.assert_equal("boss", res2.type)
        harness.assert_equal(8, res2.coins)
    end)

    harness.it("onBossDefeatedByFood() cleanly defeats boss, resets objects and awards coins", function()
        local boss = enemies.spawnBoss(1, 30, 20, 10, 12)
        enemies.addTelegraph(5, 5, 1.0, "laser")
        enemies.addProjectile(5, 5, 1, 0, 3.0, 1)

        local loot = enemies.onBossDefeatedByFood()
        harness.assert_not_nil(loot)
        harness.assert_false(boss.alive, "Boss alive set to false")
        harness.assert_false(boss.invulnerable)
        harness.assert_equal("boss", loot.type)
        harness.assert_equal(12, loot.coins)
        harness.assert_equal(0, #enemies.getTelegraphs(), "Telegraphs cleared")
        harness.assert_equal(0, #enemies.getAttackObjects(), "Attack objects cleared")
    end)

    harness.it("progresses through Boss Phase 1 -> 2 -> 3 and enrage as food is collected", function()
        local boss = enemies.spawnBoss(1, 30, 20, 10, 5)
        local snakeBody = {{x = 2, y = 2}}

        -- Start: 0/15 food collected -> Phase 1
        enemies.update(0.016, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(1, boss.phase, "Initial phase is 1")
        harness.assert_false(boss.enraged)

        -- 7/15 food collected (remaining 8/15 = 0.53 <= 0.60) -> Phase 2
        boss.foodCollected = 7
        enemies.update(0.016, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(2, boss.phase, "Phase transitions to 2 at <= 60% remaining")

        -- 12/15 food collected (remaining 3/15 = 0.20 <= 0.30) -> Phase 3 and Enrage
        boss.foodCollected = 12
        enemies.update(0.016, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(3, boss.phase, "Phase transitions to 3 at <= 30% remaining")
        harness.assert_true(boss.enraged, "Boss is enraged when foodCollected >= foodTarget - 3")
    end)

    harness.it("smoothly animates boss UI health bar fill towards target", function()
        local boss = enemies.spawnBoss(1, 30, 20, 10, 5)
        boss._uiBarFill = 1.0
        boss._uiBarTarget = 0.5

        local snakeBody = {{x = 2, y = 2}}
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_lt(boss._uiBarFill, 1.0, "Bar fill interpolated downwards")
        harness.assert_gt(boss._uiBarFill, 0.5, "Bar fill smoothly approaches target")
    end)
end)

-- =============================================================================
-- 7. BOSS ENEMY LIFETIME TIMEOUT & DELAYED RESPAWNS
-- =============================================================================
harness.describe("Enemies Subsystem - Boss Enemy Lifetime & Delayed Respawns", function()
    harness.before_each(function()
        fakeTime = 100.0
        enemies.init()
    end)

    harness.it("times out chasers after BOSS_ENEMY_LIFETIME and enqueues delayed respawn", function()
        enemies.spawnBoss(1, 30, 20, 10, 5)
        local chaser = enemies.spawnAt("chaser", 5, 5)
        chaser.spawnTime = fakeTime

        local snakeBody = {{x = 20, y = 20}}

        -- Advance 10s: still alive
        advanceFakeTime(10)
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(1, #enemies.list, "Chaser still alive before lifetime expires")
        harness.assert_equal(0, #enemies.getPendingRespawns())

        -- Advance another 6s (total 16s >= 15s lifetime)
        advanceFakeTime(6)
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(0, #enemies.list, "Chaser timed out and removed")
        harness.assert_equal(1, #enemies.getPendingRespawns(), "Chaser enqueued for delayed respawn")

        local pending = enemies.getPendingRespawns()[1]
        harness.assert_equal("chaser", pending.type)
        harness.assert_equal(fakeTime + constants.BOSS_RESPAWN_DELAY, pending.respawnAt)

        -- Advance 3s: pending respawn still waiting
        advanceFakeTime(3)
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(0, #enemies.list)
        harness.assert_equal(1, #enemies.getPendingRespawns())

        -- Advance 3s (total > 5s delay): respawns chaser on safe tile
        advanceFakeTime(3)
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(1, #enemies.list, "Chaser successfully respawned")
        harness.assert_equal(0, #enemies.getPendingRespawns(), "Pending queue cleared")
    end)

    harness.it("times out patrollers after BOSS_ENEMY_LIFETIME without enqueuing respawn", function()
        enemies.spawnBoss(1, 30, 20, 10, 5)
        local patroller = enemies.spawnAt("patroller", 6, 6)
        patroller.spawnTime = fakeTime

        local snakeBody = {{x = 20, y = 20}}
        advanceFakeTime(16)
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)

        harness.assert_equal(0, #enemies.list, "Patroller timed out and vanished")
        harness.assert_equal(0, #enemies.getPendingRespawns(), "Patrollers do not queue respawns")
    end)
end)

-- =============================================================================
-- 8. PATROLLER & SPAWNER MECHANICS
-- =============================================================================
harness.describe("Enemies Subsystem - Patroller & Spawner AI Behaviors", function()
    harness.before_each(function()
        enemies.init()
    end)

    harness.it("moves patroller along direction vector and reverses on collision", function()
        local p = enemies.spawnAt("patroller", 5, 5, {dirX = 1, dirY = 0, moveInterval = 0.2})
        local snakeBody = {{x = 20, y = 20}}

        -- Tick movement
        enemies.update(0.25, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(6, p.x, "Patroller advanced 1 cell right")
        harness.assert_equal(5, p.y)

        -- Place obstacle directly ahead at (7, 5)
        local obstaclesMod = {pos = {{x = 7, y = 5}}}
        enemies.update(0.25, snakeBody, 30, 20, obstaclesMod, 1, nil)
        -- Patroller hits obstacle, reverses dirX to -1 and steps back to 5
        harness.assert_equal(-1, p.dirX, "Direction reversed on obstacle collision")
        harness.assert_equal(5, p.x, "Patroller stepped backwards after collision")
    end)

    harness.it("spawner places new obstacle on adjacent free tile without overlapping enemies", function()
        local s = enemies.spawnAt("spawner", 10, 10)
        local obstaclesCreated = {}
        local obstaclesMod = {
            pos = {},
            agregar = function(nx, ny)
                table.insert(obstaclesCreated, {x = nx, y = ny})
            end
        }
        local snakeBody = {{x = 20, y = 20}}

        -- Advance timer past interval
        enemies.update(constants.ENEMY_SPAWNER_INTERVAL + 0.1, snakeBody, 30, 20, obstaclesMod, 1, nil)
        harness.assert_gte(#obstaclesCreated, 1, "Spawner placed an obstacle")

        local obs = obstaclesCreated[1]
        local dist = enemyHelpers.manhattan(10, 10, obs.x, obs.y)
        harness.assert_equal(1, dist, "Obstacle placed adjacent to spawner (Manhattan distance 1)")
    end)
end)

-- =============================================================================
-- 9. ATTACK OBJECTS & TELEGRAPH MARKERS
-- =============================================================================
harness.describe("Enemies Subsystem - Attack Objects & Telegraphs", function()
    harness.before_each(function()
        enemies.init()
    end)

    harness.it("creates, advances and removes projectiles when expiring or out of bounds", function()
        enemies.addProjectile(5, 5, 10, 0, 2.0, 1) -- moves right at 10 cells/s
        local objs = enemies.getAttackObjects()
        harness.assert_equal(1, #objs)
        local proj = objs[1]
        harness.assert_equal("projectile", proj.type)
        harness.assert_equal(5, proj.x)

        -- Advance 0.1s
        local snakeBody = {{x = 20, y = 20}}
        enemies.update(0.1, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_almost_equal(6.0, proj.x, 0.05, "Projectile moved to x=6")

        -- Advance past lifetime (2.0s)
        enemies.update(2.5, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(0, #enemies.getAttackObjects(), "Projectile removed after lifetime expiry")
    end)

    harness.it("creates and expands radial pulse attack objects", function()
        enemies.addRadialPulse(10, 10, 6, 2, 1) -- maxRadius 6, speed 2
        local objs = enemies.getAttackObjects()
        harness.assert_equal(1, #objs)
        local pulse = objs[1]
        harness.assert_equal("radial_pulse", pulse.type)
        harness.assert_equal(0, pulse.radius)

        local snakeBody = {{x = 20, y = 20}}
        enemies.update(1.0, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_almost_equal(2.0, pulse.radius, 0.05, "Pulse radius expanded by speed*dt")

        -- Advance past maxRadius (6 / 2 = 3s total)
        enemies.update(3.0, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(0, #enemies.getAttackObjects(), "Radial pulse removed when radius >= maxRadius")
    end)

    harness.it("creates, updates and expires telegraph markers", function()
        enemies.addTelegraph(4, 4, 0.5, "laser")
        enemies.addTelegraph(5, 5, 0.8, "laser")
        harness.assert_equal(2, #enemies.getTelegraphs())

        local snakeBody = {{x = 20, y = 20}}
        enemies.update(0.6, snakeBody, 30, 20, nil, 1, nil)
        harness.assert_equal(1, #enemies.getTelegraphs(), "First telegraph expired and removed")
        harness.assert_equal(5, enemies.getTelegraphs()[1].gx)

        enemies.clearAttackObjects()
        harness.assert_equal(0, #enemies.getTelegraphs(), "clearAttackObjects clears telegraphs")
        harness.assert_equal(0, #enemies.getAttackObjects(), "clearAttackObjects clears attack objects")
    end)
end)

-- =============================================================================
-- 10. TACTICAL COMBAT HOOKS: TAIL SNAP & FIRE TRAIL
-- =============================================================================
harness.describe("Enemies Subsystem - Tactical Hooks (Tail Snap & Fire Trail)", function()
    harness.before_each(function()
        enemies.init()
    end)

    harness.it("applyTailSnap() stuns and pushes back nearby enemies", function()
        local e1 = enemies.spawnAt("chaser", 5, 5)
        local e2 = enemies.spawnAt("patroller", 6, 5)
        local e3 = enemies.spawnAt("spawner", 15, 15) -- far away

        local affected = enemies.applyTailSnap(5, 5, 1, 0.8, 30, 20, nil)
        harness.assert_equal(2, #affected, "2 nearby enemies affected")

        harness.assert_gt(e1.stunTimer or 0, 0, "e1 stunned")
        harness.assert_gt(e2.stunTimer or 0, 0, "e2 stunned")
        harness.assert_nil(e3.stunTimer, "Far away e3 not stunned")

        -- e2 was at (6, 5), pushed away from (5, 5) -> new x is 7
        harness.assert_equal(7, e2.x, "e2 pushed back along delta vector")
    end)

    harness.it("checkFireTrail() eliminates enemies stepping onto flame trail tiles", function()
        local e1 = enemies.spawnAt("chaser", 3, 3)
        local e2 = enemies.spawnAt("patroller", 4, 4)
        local e3 = enemies.spawnAt("spawner", 10, 10)

        local fireTrail = {{x = 3, y = 3}, {x = 4, y = 4}}
        local killed = enemies.checkFireTrail(fireTrail)

        harness.assert_not_nil(killed)
        harness.assert_equal(2, #killed, "Both enemies on fire trail eliminated")
        harness.assert_false(e1.alive)
        harness.assert_false(e2.alive)
        harness.assert_true(e3.alive, "e3 off trail remains alive")
    end)
end)

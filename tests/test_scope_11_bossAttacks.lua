-- tests/test_scope_11_bossAttacks.lua
-- Comprehensive Unit Test Suite for entities/bossAttacks.lua & Boss Combat Lifecycle (Scope 11)

local harness = require("tests.test_harness")
local describe = harness.describe
local it = harness.it
local before_each = harness.before_each
local assert_equal = harness.assert_equal
local assert_not_equal = harness.assert_not_equal
local assert_true = harness.assert_true
local assert_false = harness.assert_false
local assert_nil = harness.assert_nil
local assert_not_nil = harness.assert_not_nil
local assert_table_equal = harness.assert_table_equal
local assert_almost_equal = harness.assert_almost_equal
local assert_gt = harness.assert_gt
local assert_gte = harness.assert_gte
local assert_lt = harness.assert_lt
local assert_lte = harness.assert_lte
local assert_type = harness.assert_type

local bossAttacks = require("entities.bossAttacks")
local enemies = require("entities.enemies")
local snake = require("entities.snake")
local constants = require("constants")
local coreWorld = require("core.world")
local shop = require("systems.shop")

-- =========================================================================
-- SUITE 1: Attack Definitions & Metadata Integrity
-- =========================================================================
describe("Scope 11 - Boss Attack Definitions & Metadata", function()
    it("should export definitions table and ATTACKS mapping", function()
        assert_type(bossAttacks.ATTACKS, "table", "ATTACKS table must be exported")
        assert_equal(bossAttacks.ATTACKS, bossAttacks.definitions, "definitions alias must match ATTACKS")
    end)

    it("should contain exactly the 4 canonical boss attack patterns", function()
        local attacks = bossAttacks.ATTACKS
        assert_not_nil(attacks.projectile_spread, "projectile_spread pattern must exist")
        assert_not_nil(attacks.spawn_adds, "spawn_adds pattern must exist")
        assert_not_nil(attacks.radial_pulse, "radial_pulse pattern must exist")
        assert_not_nil(attacks.teleport, "teleport pattern must exist")
    end)

    it("should specify valid numerical parameters for each attack pattern", function()
        local expected = {
            projectile_spread = { minPhase = 1, telegraphTime = 0.8, cooldown = 3.5 },
            spawn_adds = { minPhase = 1, telegraphTime = 0.6, cooldown = 6.0 },
            radial_pulse = { minPhase = 2, telegraphTime = 1.0, cooldown = 5.0 },
            teleport = { minPhase = 2, telegraphTime = 0.3, cooldown = 4.0 },
        }

        for name, exp in pairs(expected) do
            local atk = bossAttacks.get(name)
            assert_not_nil(atk, "Attack '" .. name .. "' must be retrievable via get()")
            assert_equal(name, atk.name, "Attack name must match key")
            assert_equal(exp.minPhase, atk.minPhase, name .. " minPhase mismatch")
            assert_almost_equal(exp.telegraphTime, atk.telegraphTime, 0.001, name .. " telegraphTime mismatch")
            assert_almost_equal(exp.cooldown, atk.cooldown, 0.001, name .. " cooldown mismatch")
        end
    end)

    it("should provide introspection helpers get(), getAll(), and isPhaseValid()", function()
        local all = bossAttacks.getAll()
        assert_type(all, "table")
        assert_equal(4, (all.projectile_spread and 1 or 0) + (all.spawn_adds and 1 or 0) + (all.radial_pulse and 1 or 0) + (all.teleport and 1 or 0))

        assert_nil(bossAttacks.get("non_existent_attack"))
        assert_nil(bossAttacks.get(nil))

        assert_true(bossAttacks.isPhaseValid("projectile_spread", 1))
        assert_true(bossAttacks.isPhaseValid("spawn_adds", 1))
        assert_false(bossAttacks.isPhaseValid("radial_pulse", 1))
        assert_false(bossAttacks.isPhaseValid("teleport", 1))

        assert_true(bossAttacks.isPhaseValid("radial_pulse", 2))
        assert_true(bossAttacks.isPhaseValid("teleport", 2))
        assert_true(bossAttacks.isPhaseValid("radial_pulse", 3))
        assert_true(bossAttacks.isPhaseValid("teleport", 3))
    end)
end)

-- =========================================================================
-- SUITE 2: Phase Availability & Progression
-- =========================================================================
describe("Scope 11 - Attack Phase Progression", function()
    it("should return only Phase 1 attacks when phase is 1", function()
        local available = bossAttacks.getAvailable(1)
        assert_equal(2, #available, "Phase 1 must provide exactly 2 attacks")

        local names = {}
        for _, atk in ipairs(available) do
            names[atk.name] = true
            assert_lte(atk.minPhase, 1, "Attack must belong to phase 1")
        end
        assert_true(names.projectile_spread, "projectile_spread must be available in Phase 1")
        assert_true(names.spawn_adds, "spawn_adds must be available in Phase 1")
        assert_nil(names.radial_pulse, "radial_pulse must NOT be available in Phase 1")
        assert_nil(names.teleport, "teleport must NOT be available in Phase 1")
    end)

    it("should return all 4 attacks when phase is 2 or 3", function()
        local phase2 = bossAttacks.getAvailable(2)
        assert_equal(4, #phase2, "Phase 2 must provide all 4 attacks")

        local phase3 = bossAttacks.getAvailable(3)
        assert_equal(4, #phase3, "Phase 3 must provide all 4 attacks")

        local names = {}
        for _, atk in ipairs(phase2) do names[atk.name] = true end
        assert_true(names.projectile_spread)
        assert_true(names.spawn_adds)
        assert_true(names.radial_pulse)
        assert_true(names.teleport)
    end)

    it("should handle default / nil phase safely", function()
        local fallback = bossAttacks.getAvailable(nil)
        assert_equal(2, #fallback, "Nil phase should fallback safely to Phase 1")
    end)

    it("should return deterministic attack ordering across repeated calls", function()
        local run1 = bossAttacks.getAvailable(2)
        local run2 = bossAttacks.getAvailable(2)
        assert_equal(#run1, #run2)
        for i = 1, #run1 do
            assert_equal(run1[i].name, run2[i].name, "Order mismatch at index " .. i)
        end
    end)
end)

-- =========================================================================
-- SUITE 3: Telegraph Position Computation
-- =========================================================================
describe("Scope 11 - Telegraph Position Computation (computePositions)", function()
    local ctx = { anchoGrilla = 20, altoGrilla = 20 }

    it("should compute 8 directional surrounding positions for projectile_spread", function()
        local boss = { x = 10, y = 10 }
        local positions = bossAttacks.computePositions(boss, "projectile_spread", ctx)
        assert_equal(8, #positions, "Centered projectile_spread should have 8 telegraph tiles")

        local lookup = {}
        for _, p in ipairs(positions) do
            lookup[p.x .. "," .. p.y] = true
        end

        local expectedDirs = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}
        for _, d in ipairs(expectedDirs) do
            local key = (10 + d[1]) .. "," .. (10 + d[2])
            assert_true(lookup[key], "Missing telegraph position: " .. key)
        end
    end)

    it("should clip projectile_spread positions within grid boundaries at corners", function()
        local cornerBoss = { x = 0, y = 0 }
        local positions = bossAttacks.computePositions(cornerBoss, "projectile_spread", ctx)
        assert_equal(3, #positions, "Corner (0,0) should only yield 3 valid in-bound tiles")

        for _, p in ipairs(positions) do
            assert_gte(p.x, 0)
            assert_lt(p.x, ctx.anchoGrilla)
            assert_gte(p.y, 0)
            assert_lt(p.y, ctx.altoGrilla)
        end
    end)

    it("should compute 4 cardinal tiles at distance 2 for spawn_adds", function()
        local boss = { x = 10, y = 10 }
        local positions = bossAttacks.computePositions(boss, "spawn_adds", ctx)
        assert_equal(4, #positions, "Centered spawn_adds should have 4 telegraph tiles")

        local lookup = {}
        for _, p in ipairs(positions) do
            lookup[p.x .. "," .. p.y] = true
        end

        assert_true(lookup["12,10"], "Right +2 missing")
        assert_true(lookup["8,10"], "Left -2 missing")
        assert_true(lookup["10,12"], "Down +2 missing")
        assert_true(lookup["10,8"], "Up -2 missing")
    end)

    it("should compute Manhattan diamond radius 2 for radial_pulse", function()
        local boss = { x = 10, y = 10 }
        local positions = bossAttacks.computePositions(boss, "radial_pulse", ctx)
        assert_equal(13, #positions, "Radial pulse diamond should contain 13 tiles")

        for _, p in ipairs(positions) do
            local dist = math.abs(p.x - 10) + math.abs(p.y - 10)
            assert_lte(dist, 2, "Tile distance must be <= 2")
        end
    end)

    it("should return empty positions for teleport (since telegraph happens upon execution)", function()
        local boss = { x = 10, y = 10 }
        local positions = bossAttacks.computePositions(boss, "teleport", ctx)
        assert_equal(0, #positions, "Teleport should produce 0 initial telegraph tiles")
    end)

    it("should handle edge cases and invalid parameters without throwing", function()
        assert_equal(0, #bossAttacks.computePositions(nil, "projectile_spread", ctx))
        assert_equal(0, #bossAttacks.computePositions({x=5, y=5}, nil, ctx))
        -- String name vs table name
        local posTable = bossAttacks.computePositions({x=5, y=5}, {name = "projectile_spread"}, ctx)
        local posStr = bossAttacks.computePositions({x=5, y=5}, "projectile_spread", ctx)
        assert_equal(#posTable, #posStr)
    end)
end)

-- =========================================================================
-- SUITE 4: Attack Execution (execute)
-- =========================================================================
describe("Scope 11 - Attack Execution Patterns", function()
    local mockEnemies

    before_each(function()
        mockEnemies = {
            projectiles = {},
            pulses = {},
            telegraphs = {},
            spawned = {},
            list = {},
            addProjectile = function(gx, gy, dx, dy, lifetime, damage)
                table.insert(mockEnemies.projectiles, {gx=gx, gy=gy, dx=dx, dy=dy, lifetime=lifetime, damage=damage})
            end,
            addRadialPulse = function(cx, cy, maxRadius, speed, damage)
                table.insert(mockEnemies.pulses, {cx=cx, cy=cy, maxRadius=maxRadius, speed=speed, damage=damage})
            end,
            addTelegraph = function(gx, gy, timer, attackType)
                table.insert(mockEnemies.telegraphs, {gx=gx, gy=gy, timer=timer, attackType=attackType})
            end,
            spawnAt = function(type, gx, gy, params)
                local e = {type=type, x=gx, y=gy, params=params, alive=true}
                table.insert(mockEnemies.spawned, e)
                table.insert(mockEnemies.list, e)
                return e
            end,
            canSpawn = function(type)
                return true
            end
        }
    end)

    it("executes projectile_spread with radial pattern scaling with boss phase", function()
        local bossP1 = { x = 10, y = 10, phase = 1 }
        local ctx = { enemies = mockEnemies, anchoGrilla = 30, altoGrilla = 20 }

        bossAttacks.execute(bossP1, "projectile_spread", 0.016, ctx)
        assert_equal(4, #mockEnemies.projectiles, "Phase 1 should spawn 4 projectiles")

        -- Phase 2
        mockEnemies.projectiles = {}
        local bossP2 = { x = 10, y = 10, phase = 2 }
        bossAttacks.execute(bossP2, "projectile_spread", 0.016, ctx)
        assert_equal(5, #mockEnemies.projectiles, "Phase 2 should spawn 5 projectiles")

        -- Phase 3
        mockEnemies.projectiles = {}
        local bossP3 = { x = 10, y = 10, phase = 3 }
        bossAttacks.execute(bossP3, "projectile_spread", 0.016, ctx)
        assert_equal(6, #mockEnemies.projectiles, "Phase 3 should spawn 6 projectiles")

        for _, proj in ipairs(mockEnemies.projectiles) do
            assert_equal(10, proj.gx)
            assert_equal(10, proj.gy)
            assert_almost_equal(3.0, proj.lifetime, 0.01)
            assert_equal(1, proj.damage)
        end
    end)

    it("executes spawn_adds placing patrollers without reward coins", function()
        local boss = { x = 10, y = 10, phase = 1 }
        local ctx = {
            enemies = mockEnemies,
            canSpawn = function(t) return true end,
            anchoGrilla = 30,
            altoGrilla = 20,
            speedMult = 1.2
        }

        bossAttacks.execute(boss, "spawn_adds", 0.016, ctx)
        assert_lte(#mockEnemies.spawned, 2, "Should spawn up to 2 patrollers")
        assert_gt(#mockEnemies.spawned, 0, "Should spawn at least 1 patroller")

        for _, sp in ipairs(mockEnemies.spawned) do
            assert_equal("patroller", sp.type)
            assert_equal(0, sp.params.dropCoins, "Spawned boss adds must not drop coins")
            assert_not_nil(sp.params.moveInterval)
        end
    end)

    it("spawn_adds avoids player position and obstacles", function()
        local boss = { x = 10, y = 10, phase = 1 }
        local ctx = {
            enemies = mockEnemies,
            canSpawn = function(t) return true end,
            snakeHead = { x = 12, y = 10 }, -- Player at right spawn spot
            snakeBody = { {x=8, y=10} },     -- Player body at left spawn spot
            obstacles = { pos = { {x=10, y=12} } }, -- Obstacle at down spot
            anchoGrilla = 30,
            altoGrilla = 20
        }

        bossAttacks.execute(boss, "spawn_adds", 0.016, ctx)
        for _, sp in ipairs(mockEnemies.spawned) do
            assert_false(sp.x == 12 and sp.y == 10, "Must not spawn on player head")
            assert_false(sp.x == 8 and sp.y == 10, "Must not spawn on player body")
            assert_false(sp.x == 10 and sp.y == 12, "Must not spawn on obstacle")
        end
    end)

    it("executes radial_pulse spawning expanding shockwave object", function()
        local boss = { x = 15, y = 12, phase = 2 }
        local ctx = { enemies = mockEnemies, anchoGrilla = 30, altoGrilla = 20 }

        bossAttacks.execute(boss, "radial_pulse", 0.016, ctx)
        assert_equal(1, #mockEnemies.pulses)
        local pulse = mockEnemies.pulses[1]
        assert_equal(15, pulse.cx)
        assert_equal(12, pulse.cy)
        assert_equal(8, pulse.maxRadius)
        assert_equal(3, pulse.speed)
        assert_equal(1, pulse.damage)
    end)

    it("executes teleport relocating boss safely and leaving departure telegraphs", function()
        local boss = { x = 10, y = 10, phase = 2 }
        local snakeHead = { x = 10, y = 11 }
        local ctx = {
            enemies = mockEnemies,
            snakeHead = snakeHead,
            anchoGrilla = 30,
            altoGrilla = 20
        }

        bossAttacks.execute(boss, "teleport", 0.016, ctx)

        -- Boss moved
        assert_gte(boss.x, 2)
        assert_lte(boss.x, 27)
        assert_gte(boss.y, 2)
        assert_lte(boss.y, 17)

        -- Boss is safe distance from snake head (> 5 Manhattan tiles)
        local dist = math.abs(boss.x - snakeHead.x) + math.abs(boss.y - snakeHead.y)
        assert_gt(dist, 5, "Boss must teleport to safe distance > 5 from snake head")

        -- Departure telegraphs (3x3 grid around old (10,10) position)
        assert_gt(#mockEnemies.telegraphs, 0, "Departure telegraphs must be created")
        for _, tel in ipairs(mockEnemies.telegraphs) do
            assert_equal("teleport", tel.attackType)
            assert_almost_equal(0.3, tel.timer, 0.01)
        end
    end)

    it("teleport handles nil snakeHead safely", function()
        local boss = { x = 10, y = 10, phase = 2 }
        local ctx = {
            enemies = mockEnemies,
            snakeHead = nil,
            anchoGrilla = 25,
            altoGrilla = 25
        }
        bossAttacks.execute(boss, "teleport", 0.016, ctx)
        assert_not_nil(boss.x)
        assert_not_nil(boss.y)
    end)
end)

-- =========================================================================
-- SUITE 5: Full Combat Lifecycle, Telegraphs, Projectiles & Cleanup
-- =========================================================================
describe("Scope 11 - Full Combat Lifecycle & enemies.lua Integration", function()
    before_each(function()
        enemies.init()
        coreWorld.reset()
        shop.reset()
    end)

    it("spawns boss with default state and invulnerability", function()
        enemies.spawnBoss(1, 40, 28, 5, 10)
        assert_not_nil(enemies.boss)
        assert_true(enemies.boss.alive)
        assert_true(enemies.boss.invulnerable)
        assert_equal(1, enemies.boss.phase)
        assert_equal("idle", enemies.boss.state)
        assert_equal(0, enemies.boss.foodCollected)
        assert_equal(constants.BOSS_FOOD_TARGET or 15, enemies.boss.foodTarget)
        assert_equal(0, #enemies.getAttackObjects())
        assert_equal(0, #enemies.getTelegraphs())
    end)

    it("manages telegraph timers and attack object lifecycles during enemies.update", function()
        enemies.spawnBoss(1, 40, 28, 5, 10)
        enemies.addTelegraph(5, 5, 0.5, "test_telegraph")
        enemies.addProjectile(10, 10, 5, 0, 1.0, 1)
        enemies.addRadialPulse(10, 10, 8, 4, 1)

        assert_equal(1, #enemies.getTelegraphs())
        assert_equal(2, #enemies.getAttackObjects())

        -- Advance dt = 0.2
        local mockSnake = {{x=0, y=0}}
        enemies.update(0.2, mockSnake, 40, 28, {pos={}}, 1, {})

        -- Telegraph timer decremented
        local tels = enemies.getTelegraphs()
        assert_equal(1, #tels)
        assert_almost_equal(0.3, tels[1].timer, 0.02)

        -- Projectile moved
        local objs = enemies.getAttackObjects()
        assert_equal(2, #objs)
        local proj = objs[1]
        assert_equal("projectile", proj.type)
        assert_almost_equal(11.0, proj.x, 0.05) -- 10 + 5 * 0.2 = 11

        -- Radial pulse expanded
        local pulse = objs[2]
        assert_equal("radial_pulse", pulse.type)
        assert_almost_equal(0.8, pulse.radius, 0.05) -- 0 + 4 * 0.2 = 0.8

        -- Advance dt = 0.4 -> telegraph expires and is removed
        enemies.update(0.4, mockSnake, 40, 28, {pos={}}, 1, {})
        assert_equal(0, #enemies.getTelegraphs(), "Expired telegraph must be removed")
    end)

    it("removes projectiles when they move out of grid bounds", function()
        enemies.init()
        -- Projectile at x = 39 moving right with speed 10
        enemies.addProjectile(39.0, 10.0, 10, 0, 3.0, 1)
        assert_equal(1, #enemies.getAttackObjects())

        -- Move by 0.2s -> x = 41 (out of bounds for anchoGrilla=40)
        enemies.update(0.2, {{x=0, y=0}}, 40, 28, {pos={}}, 1, {})
        assert_equal(0, #enemies.getAttackObjects(), "Out of bounds projectile must be pruned")
    end)

    it("detects projectile and radial pulse collisions in snake.mover", function()
        local s = snake.reset()
        coreWorld.set("controlMode", "classic")
        s.body = {{x=5, y=5}, {x=4, y=5}}
        s.dirX = 1
        s.dirY = 0
        s.inputQueue = {{x=1, y=0}}

        -- Place projectile at new head position (6, 5)
        enemies.init()
        enemies.addProjectile(6.0, 5.0, 0, 0, 3.0, 1)

        -- Snake moves forward into projectile
        local vivo, comio, enemyKilled, bossResult, attackHit = snake.mover(s, {x=99, y=99}, 20, 20, {})
        assert_false(vivo, "Snake should die from unshielded attack hit")
        assert_not_nil(attackHit, "attackHit result should be returned")
        assert_true(attackHit.hit)
    end)

    it("shield absorbs attack collision without player death", function()
        local s = snake.reset()
        coreWorld.set("controlMode", "classic")
        s.body = {{x=5, y=5}, {x=4, y=5}}
        s.dirX = 1
        s.dirY = 0
        s.inputQueue = {{x=1, y=0}}

        shop.shieldActive = true
        enemies.init()
        enemies.addProjectile(6.0, 5.0, 0, 0, 3.0, 1)

        local vivo, comio, enemyKilled, bossResult, attackHit = snake.mover(s, {x=99, y=99}, 20, 20, {})
        assert_true(vivo, "Shield absorbs projectile hit")
        assert_false(shop.shieldActive, "Shield is consumed")
    end)

    it("cleans all active attackObjects, telegraphs, and pendingRespawns on defeat", function()
        enemies.spawnBoss(1, 40, 28, 5, 10)
        enemies.addTelegraph(10, 10, 1.0, "projectile_spread")
        enemies.addProjectile(5, 5, 2, 2, 3.0, 1)
        enemies.addRadialPulse(10, 10, 8, 3, 1)

        assert_equal(1, #enemies.getTelegraphs())
        assert_equal(2, #enemies.getAttackObjects())

        -- Defeat boss via food
        local result = enemies.onBossDefeatedByFood()
        assert_not_nil(result)
        assert_equal("boss", result.type)
        assert_false(enemies.boss.alive)

        -- All combat artifacts cleared
        assert_equal(0, #enemies.getTelegraphs(), "Telegraphs must be cleared on boss defeat")
        assert_equal(0, #enemies.getAttackObjects(), "Attack objects must be cleared on boss defeat")
        assert_equal(0, #enemies.getPendingRespawns(), "Pending respawns must be cleared on boss defeat")
    end)

    it("clearAttackObjects() wipes telegraphs and projectiles cleanly", function()
        enemies.addTelegraph(1, 1, 1.0, "test")
        enemies.addProjectile(2, 2, 1, 1, 3.0, 1)
        assert_equal(1, #enemies.getTelegraphs())
        assert_equal(1, #enemies.getAttackObjects())

        enemies.clearAttackObjects()
        assert_equal(0, #enemies.getTelegraphs())
        assert_equal(0, #enemies.getAttackObjects())
    end)
end)

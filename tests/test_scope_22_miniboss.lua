-- tests/test_scope_22_miniboss.lua
-- Suite de pruebas para Mini-Jefes de Sala 3 (GDD §5, entities/enemyMiniBoss.lua)

local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local enemies = require("entities.enemies")
local miniBoss = require("entities.enemyMiniBoss")
local bossAttacks = require("entities.bossAttacks")

local function setupMiniWorld()
    world.reset()
    local st = world.state
    st.anchoGrilla = 32
    st.altoGrilla = 18
    st.gameState = constants.GAME_STATE_PLAYING
    st.time = 0
    st.monedas = 100
    st.survivalStreak = 1.0
    st.highestStreak = 1.0
    st.activePS = {}
    enemies.init()
end

local function testCtx()
    local obstacles = {pos = {}}
    obstacles.spawnAt = function(gx, gy, t)
        table.insert(obstacles.pos, {x = gx, y = gy, type = t})
    end
    return {
        enemies = enemies,
        obstacles = obstacles,
        attackRegistry = require("entities.enemyAttackRegistry"),
        head = {x = 20, y = 10},
        tail = {x = 5, y = 10},
        body = {{x = 20, y = 10}},
        anchoGrilla = 32,
        altoGrilla = 18,
    }
end

harness.describe("MiniBoss - Definitions per Stage (GDD §5)", function()
    harness.before_each(function()
        setupMiniWorld()
    end)

    harness.it("defines 5 thematic mini-bosses with GDD stats", function()
        local expected = {
            [1] = {id = "wall_crusher", hp = 3, food = 6, coins = 15},
            [2] = {id = "frost_golem", hp = 4, food = 7, coins = 20},
            [3] = {id = "magma_wyrm", hp = 6, food = 8, coins = 25},
            [4] = {id = "brood_queen", hp = 5, food = 9, coins = 30},
            [5] = {id = "void_phantom", hp = 6, food = 10, coins = 40},
        }
        for etapa, exp in pairs(expected) do
            local def = miniBoss.getDef(etapa)
            harness.assert_equal(exp.id, def.id, "Stage " .. etapa .. " id mismatch")
            harness.assert_equal(exp.hp, def.hp, "Stage " .. etapa .. " hp mismatch")
            harness.assert_equal(exp.food, def.foodTarget, "Stage " .. etapa .. " food mismatch")
            harness.assert_equal(exp.coins, def.coins, "Stage " .. etapa .. " coins mismatch")
        end
    end)

    harness.it("spawns mini-boss stored in World.state", function()
        local mb = enemies.spawnMiniBoss(2, 10, 8)
        harness.assert_not_nil(mb, "Spawn must return entity")
        harness.assert_equal("frost_golem", mb.defId, "Stage 2 must spawn Frost Golem")
        harness.assert_true(mb.alive, "Mini-boss must spawn alive")
        harness.assert_equal(4, mb.hp, "Golem must have 4 HP")
        harness.assert_equal(mb, enemies.getMiniBoss(), "Must be readable via facade")
        harness.assert_equal(mb, world.get("enemies.miniboss"), "Must live in World.state")
    end)
end)

harness.describe("MiniBoss - Direct Damage & Food Defeat", function()
    harness.before_each(function()
        setupMiniWorld()
    end)

    harness.it("dies after hp hits and pays golden reward", function()
        local mb = enemies.spawnMiniBoss(1, 10, 8)
        local ctx = testCtx()
        harness.assert_nil(enemies.hitMiniBoss(1, ctx), "1/3 hits must not kill")
        harness.assert_nil(enemies.hitMiniBoss(1, ctx), "2/3 hits must not kill")
        harness.assert_equal(1, mb.hp, "HP must decrease per hit")
        local loot = enemies.hitMiniBoss(1, ctx)
        harness.assert_not_nil(loot, "3/3 hits must kill")
        harness.assert_equal("miniboss", loot.type, "Loot type must be miniboss")
        harness.assert_equal(15, loot.coins, "Wall-Crusher must pay 15 coins")
        harness.assert_false(mb.alive, "Mini-boss must be dead")
        harness.assert_nil(enemies.getMiniBoss(), "Store must clear on death")
    end)

    harness.it("is defeated by collecting its food target", function()
        enemies.spawnMiniBoss(3, 10, 8)
        local loot = nil
        for _ = 1, 8 do loot = enemies.addMiniBossFood() end
        harness.assert_not_nil(loot, "8/8 foods must defeat the Wyrm")
        harness.assert_equal(25, loot.coins, "Wyrm must pay 25 coins")
    end)

    harness.it("frost nova fires 4 diagonal shards when damaged", function()
        enemies.spawnMiniBoss(2, 10, 8)
        local countBefore = #enemies.getAttackObjects()
        enemies.hitMiniBoss(1, testCtx())
        harness.assert_equal(countBefore + 4, #enemies.getAttackObjects(), "Nova must fire 4 shards")
    end)
end)

harness.describe("MiniBoss - Attacks", function()
    harness.before_each(function()
        setupMiniWorld()
    end)

    harness.it("wall-crusher charge destroys obstacles along its row", function()
        local ctx = testCtx()
        local mb = enemies.spawnMiniBoss(1, 10, 8)
        ctx.head = {x = 25, y = 8}
        mb.currentAttack = "charge"
        ctx.obstacles.pos = {{x = 15, y = 8, type = "wall"}, {x = 20, y = 8, type = "wall"}}
        miniBoss.execute(mb, ctx)
        harness.assert_equal(0, #ctx.obstacles.pos, "Charge must destroy obstacles in path")
        harness.assert_true(mb.slammed, "Slam flag must raise for feedback")
        harness.assert_gt(mb.x, 10, "Crusher must dash toward the edge")
    end)

    harness.it("magma wyrm leaves expiring lava trail on the perimeter", function()
        local ctx = testCtx()
        local mb = enemies.spawnMiniBoss(3, 10, 8)
        for _ = 1, 4 do
            mb.moveTimer = 99
            miniBoss.update(0.5, mb, ctx)
        end
        harness.assert_gt(#ctx.obstacles.pos, 0, "Wyrm must leave lava trail")
        harness.assert_gt(#mb.trail, 0, "Trail timers must track lava")
        for _, t in ipairs(mb.trail) do t.timer = 0 end
        miniBoss.update(0.1, mb, ctx)
        harness.assert_equal(0, #mb.trail, "Expired trail must clear")
        harness.assert_equal(0, #ctx.obstacles.pos, "Expired lava must be removed")
    end)

    harness.it("brood queen swarms max 3 larvae and webs slime 3x3", function()
        local ctx = testCtx()
        local mb = enemies.spawnMiniBoss(4, 10, 8)
        mb.currentAttack = "swarm"
        miniBoss.execute(mb, ctx)
        local larvae = 0
        for _, e in ipairs(enemies.list) do
            if e.larva then
                larvae = larvae + 1
                harness.assert_equal(2.0, e.fuse, "Larvae must carry 2s fuse")
            end
        end
        harness.assert_equal(3, larvae, "Swarm must invoke 3 larvae")
        mb.currentAttack = "swarm"
        miniBoss.execute(mb, ctx)
        larvae = 0
        for _, e in ipairs(enemies.list) do if e.larva then larvae = larvae + 1 end end
        harness.assert_equal(3, larvae, "Swarm must cap at 3 live larvae")
        mb.currentAttack = "web"
        miniBoss.execute(mb, ctx)
        harness.assert_equal(9, #ctx.obstacles.pos, "Web must cover 3x3 slime")
    end)

    harness.it("fused larvae explode into slime via enemies.update", function()
        setupMiniWorld()
        local e = enemies.spawnAt("chaser", 5, 5)
        e.fuse = 0.05
        e.fuseSlime = true
        local obstacles = {pos = {}}
        obstacles.spawnAt = function(gx, gy, t)
            table.insert(obstacles.pos, {x = gx, y = gy, type = t})
        end
        enemies.update(0.1, {{x = 20, y = 10}}, 32, 18, obstacles, 1, nil)
        harness.assert_false(e.alive, "Fused larva must die")
        harness.assert_equal(1, #obstacles.pos, "Explosion must leave slime")
        harness.assert_equal("slime", obstacles.pos[1].type)
    end)

    harness.it("void phantom teleports behind the tail and singularity detonates", function()
        local ctx = testCtx()
        ctx.head = {x = 10, y = 10}
        ctx.tail = {x = 5, y = 10}
        local mb = enemies.spawnMiniBoss(5, 15, 10)
        mb.currentAttack = "teleport"
        miniBoss.execute(mb, ctx)
        harness.assert_true(mb.justTeleported, "Teleport flag must raise")
        harness.assert_gt(5, mb.x, "Phantom must relocate near the tail")
        mb.currentAttack = "singularity"
        miniBoss.execute(mb, ctx)
        harness.assert_not_nil(mb.singu, "Singularity must open")
        -- Congelar la máquina de ataques para medir solo la singularidad
        mb.state = "cooldown"
        mb.stateTimer = 99
        mb.attackCooldown = 99
        ctx.head = {x = mb.singu.cx + 1, y = mb.singu.cy}
        for _ = 1, 8 do miniBoss.update(0.5, mb, ctx) end
        harness.assert_nil(mb.singu, "Singularity must close after 3s")
        harness.assert_true(mb.pendingHit, "Head near center must arm detonation")
    end)
end)

harness.describe("MiniBoss - Elite Room 3 Integration", function()
    harness.before_each(function()
        setupMiniWorld()
    end)

    harness.it("marks dungeon room 3 as elite", function()
        local dungeonGen = require("world.dungeonGen")
        local fake = {etapa = 2}
        dungeonGen.generar(fake, 800, 600, 5, 12345)
        harness.assert_not_nil(fake.dungeon, "Dungeon must generate")
        harness.assert_gte(#fake.dungeon.rooms, 3, "Dungeon must have room 3")
        harness.assert_true(fake.dungeon.rooms[3].isElite, "Room 3 must be elite")
        harness.assert_false(fake.dungeon.rooms[1].isElite or false, "Room 1 must not be elite")
    end)

    harness.it("populates room 3 with the stage mini-boss", function()
        local worldMod = require("world.world")
        local populate = require("world.populate")
        local foodMod = require("entities.food")
        local obstaclesMod = require("entities.obstacles")
        worldMod.init()
        worldMod.etapa = 2
        worldMod.generarMazmorra(800, 600, 5)
        worldMod.sala = 3
        local snakeBody = {{x = 2, y = 2}, {x = 1, y = 2}}
        obstaclesMod.init()
        foodMod.pos = nil
        populate.populateRoom(worldMod, snakeBody, 20, 14, {}, foodMod, enemies, obstaclesMod)
        local mb = enemies.getMiniBoss()
        harness.assert_not_nil(mb, "Room 3 must spawn a mini-boss")
        harness.assert_equal("frost_golem", mb.defId, "Stage 2 room 3 must spawn Frost Golem")
    end)

    harness.it("drawMiniBoss renders without errors headless", function()
        enemies.spawnMiniBoss(4, 10, 8)
        local draw = require("render.enemiesDraw")
        draw.drawMiniBoss(enemies.getMiniBoss())
        harness.assert_true(true, "Draw must not throw")
    end)
end)

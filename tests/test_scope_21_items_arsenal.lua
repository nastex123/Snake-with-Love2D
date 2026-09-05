-- tests/test_scope_21_items_arsenal.lua
-- Suite de pruebas para el Arsenal Extendido 51-60 (GDD Fase 8, items.lua + player.lua)

local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local items = require("systems.items")
local shop = require("systems.shop")
local playerMod = require("systems.player")
local snakeMod = require("entities.snake")
local enemiesMod = require("entities.enemies")
local states = require("systems.gamestates")
local gameflow = require("systems.gameflow")

local function setupArsenalWorld()
    world.reset()
    local st = world.state
    st.anchoGrilla = 32
    st.altoGrilla = 18
    st.gameState = constants.GAME_STATE_PLAYING
    st.time = 0
    st.cronometro = 0
    st.baseSpeed = constants.VELOCIDAD_INICIAL
    st.velocidadActual = constants.VELOCIDAD_INICIAL
    st.puntuacion = 0
    st.frutasContador = 0
    st.monedas = 100
    st.coinBonus = 0
    st.scoreMultiplier = 1
    st.survivalStreak = 1.0
    st.highestStreak = 1.0
    st.roomDamaged = false
    st.deathModalOpen = false
    st.shakeTimer = 0
    st.comboCount = 0
    st.comboDisplay = 0
    st.comboIntensity = 0
    st.comboFlashTimer = 0
    st.lastEatTime = -100
    st.magnetRange = 0
    st.lastObstacleScore = 0
    st.activePS = {}
    st.activeTimers = {}
    st.shockwaves = {}
    st.timeScale = 1
    st.player = snakeMod.reset()
    local foodMod = require("entities.food")
    foodMod.pos = {x = 20, y = 10}
    foodMod.tipo = constants.FOOD_NORMAL
    foodMod.twinPos = nil
    local worldMod = require("world.world")
    worldMod.objetivoSala = 10000
    world.set("controlMode", "classic")
    shop.slots = {nil, nil, nil}
    shop.inventory = {speedReducer = false, extraCoin = false}
    shop.shieldActive = false
    shop.magnetTimer = 0
    enemiesMod.init()
end

harness.describe("Items Arsenal 51-60 - Registry & Config", function()
    harness.before_each(function()
        setupArsenalWorld()
    end)

    harness.it("registers all 10 arsenal items with GDD costs", function()
        local costs = {
            tailSpike = 20, hourglass = 35, orbitalBeam = 30, holoDecoy = 25,
            lightBoots = 20, goldenTooth = 25, emergencyBattery = 30,
            doubleHarvest = 30, lottery = 5, refractorPrism = 25
        }
        for id, cost in pairs(costs) do
            local def = items.get(id)
            harness.assert_not_nil(def, "Item " .. id .. " must exist")
            harness.assert_equal(cost, def.cost, id .. " cost mismatch")
        end
    end)

    harness.it("routes consumable lottery to slots like actives", function()
        local res = shop.procesarCompra(100, "lottery", 5)
        harness.assert_not_nil(res, "Lottery purchase must succeed")
        harness.assert_equal(1, res.slot, "Lottery must go to slot 1")
        harness.assert_equal("lottery", shop.slots[1])
    end)
end)

harness.describe("Items Arsenal 51-60 - Active Effects", function()
    harness.before_each(function()
        setupArsenalWorld()
    end)

    harness.it("tailSpike plants a trap at the tail (max 3)", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        for _ = 1, 4 do playerMod.aplicarItem("tailSpike") end
        harness.assert_equal(3, #st.placedTraps, "Max 3 simultaneous traps")
        harness.assert_equal(3, st.placedTraps[3].x, "Trap must be planted at tail cell")
    end)

    harness.it("trap kills the first enemy stepping on it via update", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        st.player.dirX, st.player.dirY = 0, 0
        st.player.inputQueue = {}
        world.set("controlMode", "tactical")
        playerMod.aplicarItem("tailSpike")
        local e = enemiesMod.spawnAt("chaser", 4, 5)
        local coinsBefore = st.monedas
        states.updatePlaying(0.016)
        harness.assert_false(e.alive, "Enemy on trap must die")
        harness.assert_equal(0, #st.placedTraps, "Trap must be consumed")
        harness.assert_gt(st.monedas, coinsBefore, "Trap kill must award coins")
    end)

    harness.it("hourglass rewinds snake body to the oldest snapshot", function()
        local st = world.state
        st.player.body = {{x = 9, y = 9}, {x = 8, y = 9}}
        st.historyBuffer = {
            {body = {{x = 1, y = 1}, {x = 0, y = 1}}, enemies = {}, boss = nil},
            {body = {{x = 5, y = 5}, {x = 4, y = 5}}, enemies = {}, boss = nil},
        }
        playerMod.aplicarItem("hourglass")
        harness.assert_equal(1, st.player.body[1].x, "Body must rewind to oldest snapshot")
        harness.assert_equal(1, st.player.body[1].y, "Body must rewind to oldest snapshot")
    end)

    harness.it("orbitalBeam vaporizes enemies in its column via update", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        st.player.dirX, st.player.dirY = 0, 0
        st.player.inputQueue = {}
        world.set("controlMode", "tactical")
        playerMod.aplicarItem("orbitalBeam")
        harness.assert_not_nil(st.orbitalBeam, "Beam must be active")
        harness.assert_equal(5, st.orbitalBeam.x, "Beam must lock head column")
        local e = enemiesMod.spawnAt("chaser", 5, 8)
        states.updatePlaying(0.016)
        harness.assert_false(e.alive, "Enemy in beam column must vaporize")
    end)

    harness.it("holoDecoy deploys a static 4s decoy at the head", function()
        local st = world.state
        st.player.body = {{x = 7, y = 7}, {x = 6, y = 7}}
        playerMod.aplicarItem("holoDecoy")
        harness.assert_equal(1, #st.player.decoys, "Decoy must deploy")
        harness.assert_equal(7, st.player.decoys[1].x, "Decoy must stay at head cell")
        harness.assert_almost_equal(4.0, st.player.decoys[1].timer, 0.01, "Decoy must last 4.0s")
    end)

    harness.it("lottery awards 0-35 coins on activation", function()
        local st = world.state
        local before = st.monedas
        playerMod.aplicarItem("lottery")
        local win = st.monedas - before
        harness.assert_gte(win, 0, "Lottery must award >= 0")
        harness.assert_lte(win, 35, "Lottery must award <= 35")
    end)
end)

harness.describe("Items Arsenal 51-60 - Passives", function()
    harness.before_each(function()
        setupArsenalWorld()
    end)

    harness.it("lightBoots halves the slime slow factor", function()
        local slow = playerMod.calculateCurrentSpeed(0.13, 0, {isSlime = true})
        harness.assert_almost_equal(0.1625, slow, 0.001, "Slime without boots")
        playerMod.aplicarItem("lightBoots")
        local booted = playerMod.calculateCurrentSpeed(0.13, 0, {isSlime = true})
        harness.assert_almost_equal(0.14625, booted, 0.001, "Slime with boots must be halved")
        harness.assert_true(shop.inventory.lightBoots, "Boots must persist in inventory")
    end)

    harness.it("slime tile arms slimeSlowTimer on step", function()
        local st = world.state
        local s = st.player
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.inputQueue = {{x = 1, y = 0}}
        local vivo = snakeMod.mover(s, {x = 99, y = 99}, 32, 18, {{x = 6, y = 5, type = "slime"}})
        harness.assert_true(vivo, "Slime must be passable")
        harness.assert_equal(1.0, s.slimeSlowTimer, "Slime step must arm 1.0s slow")
    end)

    harness.it("goldenTooth grants bonus coins per 10 body segments", function()
        local st = world.state
        local body = {{x = 5, y = 5}}
        for i = 1, 24 do body[#body + 1] = {x = 5 - i, y = 5} end
        st.player.body = body
        st.player.dirX, st.player.dirY = 1, 0
        st.player.inputQueue = {{x = 1, y = 0}}
        st.cronometro = st.velocidadActual
        playerMod.aplicarItem("goldenTooth")
        local foodMod = require("entities.food")
        foodMod.pos = {x = 6, y = 5}
        foodMod.tipo = constants.FOOD_NORMAL
        foodMod.twinPos = nil
        local before = st.monedas
        states.updatePlaying(0.02)
        harness.assert_equal(26, #st.player.body, "Snake must have eaten and grown")
        harness.assert_equal(before + 3, st.monedas, "1 base + 2 tooth bonus coins expected")
    end)

    harness.it("emergencyBattery opens bullet-time instead of instant modal", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        playerMod.aplicarItem("emergencyBattery")
        local e = enemiesMod.spawnAt("chaser", 5, 5)
        world.set("controlMode", "tactical")
        states.updatePlaying(0.016)
        harness.assert_true(st.batteryUsed, "Battery must be consumed")
        harness.assert_almost_equal(0.1, st.timeScale, 0.001, "Bullet-time 0.1x must engage")
        harness.assert_false(st.deathModalOpen, "Modal must wait for bullet-time")
        harness.assert_not_nil(st.pendingDeathTimer, "Pending death must be scheduled")
    end)

    harness.it("doubleHarvest eventually procs without growth", function()
        playerMod.aplicarItem("doubleHarvest")
        harness.assert_true(shop.inventory.doubleHarvest, "Must persist in inventory")
        local procs = 0
        for _ = 1, 60 do
            local s = snakeMod.reset()
            s.body = {{x = 5, y = 5}, {x = 4, y = 5}}
            s.dirX, s.dirY = 1, 0
            s.inputQueue = {{x = 1, y = 0}}
            world.set("controlMode", "classic")
            local _, comio = snakeMod.mover(s, {x = 6, y = 5}, 32, 18, {}, 0, nil)
            if s.doubleHarvestProc then
                procs = procs + 1
                harness.assert_true(comio, "Proc must still count as eaten")
                harness.assert_equal(2, #s.body, "Proc must not grow the body")
                break
            end
        end
        harness.assert_gt(procs, 0, "15% must proc within 60 tries")
    end)

    harness.it("refractorPrism converts shielded projectile into coins", function()
        local st = world.state
        local s = st.player
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.inputQueue = {{x = 1, y = 0}}
        world.set("controlMode", "classic")
        shop.shieldActive = true
        playerMod.aplicarItem("refractorPrism")
        enemiesMod.addProjectile(6.0, 5.0, 0, 0, 3.0, 1)
        local before = st.monedas
        local vivo = snakeMod.mover(s, {x = 99, y = 99}, 32, 18, {}, 0, nil)
        harness.assert_true(vivo, "Shield must absorb")
        harness.assert_true(s.prismRefract, "Prism flag must raise")
        harness.assert_equal(before, st.monedas, "Coins awarded by playing, not mover")
    end)

    harness.it("resetGame clears arsenal per-room state", function()
        local st = world.state
        st.placedTraps = {{x = 1, y = 1}}
        st.orbitalBeam = {x = 2, timer = 1.0}
        st.historyBuffer = {{{body = {}}}}
        st.batteryUsed = true
        st.pendingDeathTimer = 0.1
        gameflow.resetGame(false)
        harness.assert_equal(0, #st.placedTraps, "Traps must clear per room")
        harness.assert_nil(st.orbitalBeam, "Beam must clear per room")
        harness.assert_equal(0, #st.historyBuffer, "History must clear per room")
        harness.assert_false(st.batteryUsed, "Battery must rearm per room")
        harness.assert_nil(st.pendingDeathTimer, "Pending death must clear per room")
    end)
end)

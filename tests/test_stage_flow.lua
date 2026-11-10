local harness = require("tests.test_harness")
local world = require("core.world")
local worldMod = require("world.world")
local enemies = require("entities.enemies")
local obstacles = require("entities.obstacles")
local food = require("entities.food")
local stageFlow = require("systems.stageFlow")

harness.describe("Stage progression", function()
    harness.before_each(function()
        world.reset()
        world.state.modo = "estandar"
        worldMod.init()
        enemies.init()
        obstacles.init()
        food.pos = {x = 10, y = 7}
        local st = world.state
        st.anchoGrilla, st.altoGrilla = 32, 18
        st.player = {body = {{x = 16, y = 9}, {x = 15, y = 9}, {x = 14, y = 9}}}
        st.waveCurrent, st.waveTotal = 1, 2
        st.waveTimer, st.waveMaxTimer = 1, 1
        st.transitionTarget = nil
        stageFlow.start(st)
    end)

    harness.it("uses a single arena and advances through encounters without resetting the player", function()
        local st = world.state
        local player = st.player
        harness.assert_equal(1, worldMod.getRoomCount(), "one arena per stage")
        stageFlow.update(st, 1)
        harness.assert_equal("survival", st.stagePhase)
        harness.assert_equal(2, st.waveCurrent)
        stageFlow.update(st, 1)
        harness.assert_equal("miniboss", st.stagePhase)
        stageFlow.update(st, 0)
        local mini = enemies.getMiniBoss()
        harness.assert_not_nil(mini, "mini-boss spawns")
        enemies.hitMiniBoss(999, {enemies = enemies})
        stageFlow.update(st, 0)
        harness.assert_equal("boss", st.stagePhase)
        stageFlow.update(st, 0)
        harness.assert_true(enemies.boss and enemies.boss.alive, "stage boss spawns")
        harness.assert_equal(player, st.player, "player is preserved between phases")
        harness.assert_true(worldMod.isLastRoom(), "boss victory advances stage")
    end)

    harness.it("builds a full-size arena with a reproducible random seed", function()
        local arena = require("world.stageArena")
        local first = arena.generate(800, 600, 12345, 1)
        local firstRoll = love.math.random()
        local second = arena.generate(800, 600, 12345, 1)
        local secondRoll = love.math.random()
        harness.assert_equal(1, #first.rooms)
        harness.assert_equal(0, #first.corridors)
        harness.assert_equal(800, first.rooms[1].rect.w)
        harness.assert_equal(600, second.rooms[1].rect.h)
        harness.assert_equal(firstRoll, secondRoll)
    end)

    harness.it("debug skip changes phase without changing arena", function()
        local st = world.state
        harness.assert_true(stageFlow.skipPhase(st))
        stageFlow.update(st, 0)
        harness.assert_equal("miniboss", st.stagePhase)
        harness.assert_true(stageFlow.skipPhase(st))
        harness.assert_equal("boss", st.stagePhase)
        harness.assert_equal(1, worldMod.getRoomCount())
    end)

    harness.it("ends an active stage event before the mini-boss starts", function()
        local st = world.state
        local roomEvents = require("systems.roomEvents")
        local chance = roomEvents.EVENT_CHANCE
        roomEvents.EVENT_CHANCE = 1
        local event = roomEvents.roll(worldMod, st, enemies)
        roomEvents.EVENT_CHANCE = chance
        harness.assert_not_nil(event, "event begins during survival")
        st.waveCurrent = st.waveTotal
        st.waveTimer = 0
        stageFlow.update(st, 0)
        harness.assert_equal("miniboss", st.stagePhase)
        harness.assert_nil(roomEvents.getCurrent(), "event no longer active")
        harness.assert_nil(st.roomEvent, "event marker cleared")
    end)

    harness.it("finishes a mystery event without changing the stage or arena", function()
        local st = world.state
        local mystery = require("systems.mystery")
        local events = require("systems.gamestates.playingEvents")
        local arena = worldMod.getCurrentRoom()
        arena.mystery = "gold_rush"
        mystery.begin()
        mystery.beginGoldRush(st.anchoGrilla, st.altoGrilla)
        st.monedas = 0
        events.updateRoomEvents(st, 100)
        harness.assert_nil(st.transitionTarget)
        harness.assert_equal("survival", st.stagePhase)
        harness.assert_equal(arena, worldMod.getCurrentRoom())
        harness.assert_nil(mystery.current(worldMod))
    end)

    harness.it("does not assign mystery events during mini-boss encounters", function()
        local st = world.state
        local mystery = require("systems.mystery")
        local constants = require("constants")
        local chance = constants.ROOM_MYSTERY_CHANCE
        constants.ROOM_MYSTERY_CHANCE = 1
        st.stagePhase = "miniboss"
        local result = mystery.assignStage(worldMod)
        constants.ROOM_MYSTERY_CHANCE = chance
        harness.assert_nil(result)
        harness.assert_nil(mystery.current(worldMod))
    end)

    harness.it("preserves score and coins when starting the next stage", function()
        local st = world.state
        local gameflow = require("systems.gameflow")
        st.puntuacion, st.monedas = 123, 42
        worldMod.avanzarEtapa()
        gameflow.iniciarSala(true)
        harness.assert_equal(2, worldMod.etapa)
        harness.assert_equal(123, st.puntuacion)
        harness.assert_equal(42, st.monedas)
        harness.assert_equal("survival", st.stagePhase)
        harness.assert_equal(1, worldMod.getRoomCount())
    end)

    harness.it("advances the stage after a boss victory", function()
        local st = world.state
        local transition = require("systems.gamestates.transition")
        st.stagePhase = "boss"
        st.transitionTarget = "siguienteEtapa"
        st.transitionPhase = 1
        st.fadeAlpha = 1
        st.roomDamaged = true
        st.pendingAchievements = {}
        st.monedas = 42
        transition.update(0)
        harness.assert_equal(2, worldMod.etapa)
        harness.assert_equal("hold", st.transitionPhase)
        harness.assert_equal(1, worldMod.getRoomCount())
    end)

    harness.it("stores completed stages without reinterpreting old room records", function()
        local daily = require("systems.daily")
        local profile = {}
        daily.recordRun(profile, 100, 3, 0, {year = 2026, month = 1, day = 2}, 2)
        daily.recordRun(profile, 80, 2, 4, {year = 2026, month = 1, day = 1})
        local history = daily.getHistoryList(profile)
        harness.assert_equal(2, history[1].stagesCleared)
        harness.assert_nil(history[2].stagesCleared)
        harness.assert_equal(4, history[2].roomsCleared)
    end)

    harness.it("sets the daily seed before generating the first arena", function()
        local st = world.state
        local gameflow = require("systems.gameflow")
        local daily = require("systems.daily")
        local originalInit = worldMod.init
        local seedAtInit
        worldMod.init = function()
            seedAtInit = st.dailySeed
            return originalInit()
        end
        st.modo, st.dailySeed = "diario", nil
        local expectedSeed = gameflow.getDailySeed()
        gameflow.startRun()
        worldMod.init = originalInit
        harness.assert_equal(expectedSeed, seedAtInit)
        harness.assert_true(daily.isDailyActive())
    end)

    harness.it("returns to the menu with a summary after the fifth stage", function()
        local st = world.state
        local transition = require("systems.gamestates.transition")
        local constants = require("constants")
        worldMod.setEtapa(5)
        st.stagePhase = "boss"
        st.transitionTarget, st.transitionPhase = "completado", 1
        st.fadeAlpha, st.roomDamaged = 1, true
        st.puntuacion, st.monedas = 500, 70
        st.pendingAchievements = {}
        st.mundoCompletado = false
        transition.update(0)
        harness.assert_true(st.mundoCompletado)
        transition.update(2)
        st.fadeAlpha = 0
        transition.update(0)
        harness.assert_equal(constants.GAME_STATE_MENU, st.gameState)
        harness.assert_equal(500, st.stageVictorySummary.score)
        harness.assert_equal(70, st.stageVictorySummary.coins)
    end)

    harness.it("records five completed stages when the daily challenge is won", function()
        local st = world.state
        local transition = require("systems.gamestates.transition")
        local persistence = require("systems.persistence")
        local profile = {stats = {endlessUnlocked = true}, dailyHistory = {}}
        local oldGet, oldSync = persistence.getActiveProfile, persistence.syncDailyHistory
        persistence.getActiveProfile = function() return profile end
        persistence.syncDailyHistory = function() end
        worldMod.setEtapa(5)
        st.modo, st.dailySeed = "diario", 123
        st.stagePhase, st.transitionTarget, st.transitionPhase = "boss", "completado", 1
        st.fadeAlpha, st.roomDamaged = 1, true
        st.puntuacion, st.monedas, st.pendingAchievements = 500, 70, {}
        transition.update(0)
        local result = st.lastDailyResult
        persistence.getActiveProfile, persistence.syncDailyHistory = oldGet, oldSync
        st.dailySeed = nil
        harness.assert_not_nil(result)
        harness.assert_equal(5, result.stagesCleared)
        harness.assert_equal(500, result.score)
    end)

    harness.it("continues past stage five in endless mode", function()
        local st = world.state
        local transition = require("systems.gamestates.transition")
        worldMod.setEtapa(5)
        st.modo = "endless"
        st.stagePhase, st.transitionTarget, st.transitionPhase = "boss", "completado", 1
        st.fadeAlpha, st.roomDamaged = 1, true
        st.mundoCompletado, st.pendingAchievements = false, {}
        st.monedas = 0
        transition.update(0)
        harness.assert_equal(6, worldMod.etapa)
        harness.assert_equal("siguienteEtapa", st.transitionTarget)
        harness.assert_false(st.mundoCompletado)
    end)

    harness.it("completes five stages through the real combat and transition handlers", function()
        local st = world.state
        local gameflow = require("systems.gameflow")
        local combat = require("systems.gamestates.playingCombat")
        local transition = require("systems.gamestates.transition")
        local constants = require("constants")
        local sound = require("audio.sound")
        local musicWasEnabled = sound.musicEnabled
        sound.musicEnabled = false
        st.mundoCompletado = false
        st.pendingAchievements = {}
        st.puntuacion, st.monedas = 0, 0
        gameflow.iniciarSala(false)
        st.gameState = constants.GAME_STATE_PLAYING
        for expectedStage = 1, 5 do
            harness.assert_equal(expectedStage, worldMod.etapa)
            stageFlow.skipPhase(st)
            stageFlow.update(st, 0)
            stageFlow.update(st, 0)
            harness.assert_not_nil(enemies.getMiniBoss(), "mini-boss should spawn")
            enemies.hitMiniBoss(999, {enemies = enemies})
            stageFlow.update(st, 0)
            stageFlow.update(st, 0)
            harness.assert_true(enemies.boss and enemies.boss.alive, "boss should spawn")
            local loot = enemies.hitBossRam(999)
            harness.assert_true(combat.handleBossResult(st, loot), "boss defeat starts transition")
            st.fadeAlpha, st.roomDamaged = 1, true
            transition.update(0)
            transition.update(2)
            st.fadeAlpha = 0
            transition.update(0)
            if expectedStage < 5 then
                harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState)
                gameflow.continueFromShop()
            else
                harness.assert_equal(constants.GAME_STATE_MENU, st.gameState)
                harness.assert_not_nil(st.stageVictorySummary)
            end
        end
        sound.musicEnabled = musicWasEnabled
    end)

    harness.it("plays five mini-bosses and the final boss in Boss Rush", function()
        local st = world.state
        local gameflow = require("systems.gameflow")
        local transition = require("systems.gamestates.transition")
        local combat = require("systems.gamestates.playingCombat")
        local constants = require("constants")
        local sound = require("audio.sound")
        local musicWasEnabled = sound.musicEnabled
        sound.musicEnabled = false
        st.modo = "boss_rush"
        worldMod.init()
        st.mundoCompletado, st.pendingAchievements = false, {}
        st.puntuacion, st.monedas = 0, 0
        gameflow.iniciarSala(false)
        st.gameState = constants.GAME_STATE_PLAYING
        for encounter = 1, 5 do
            harness.assert_equal(encounter, worldMod.etapa)
            harness.assert_equal("miniboss", st.stagePhase)
            stageFlow.update(st, 0)
            local mini = enemies.getMiniBoss()
            harness.assert_not_nil(mini)
            harness.assert_equal(encounter, mini.etapa)
            enemies.hitMiniBoss(999, {enemies = enemies})
            stageFlow.update(st, 0)
            harness.assert_equal("siguienteEtapa", st.transitionTarget)
            st.fadeAlpha, st.roomDamaged = 1, true
            transition.update(0)
            transition.update(2)
            st.fadeAlpha = 0
            transition.update(0)
            harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState)
            gameflow.continueFromShop()
        end
        harness.assert_equal(6, worldMod.etapa)
        harness.assert_equal("boss", st.stagePhase)
        stageFlow.update(st, 0)
        harness.assert_true(enemies.boss and enemies.boss.alive)
        local loot = enemies.hitBossRam(999)
        harness.assert_true(combat.handleBossResult(st, loot))
        harness.assert_equal("completado", st.transitionTarget)
        sound.musicEnabled = musicWasEnabled
    end)
end)

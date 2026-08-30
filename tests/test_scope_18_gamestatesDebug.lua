-- tests/test_scope_18_gamestatesDebug.lua
-- Unit tests for systems/gamestates.lua, systems/debugTools.lua, and systems/debugLogo.lua

local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
local persistence = require("systems.persistence")
local achievements = require("systems.achievements")
local gameflow = require("systems.gameflow")
local playerMod = require("systems.player")
local shop = require("systems.shop")
local states = require("systems.gamestates")
local debugTools = require("systems.debugTools")
local debugLogo = require("systems.debugLogo")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local uiMod = require("ui.ui")
local sound = require("audio.sound")

local function setupWorldState()
    world.reset()
    persistence.init()
    persistence.initProfiles()
    shop.slots = {nil, nil, nil}
    shop.inventory = { speedReducer = false, extraCoin = false }
    shop.shieldActive = false
    shop.magnetTimer = 0

    local profile = persistence.getActiveProfile()
    if not profile then
        persistence.createProfile("TestUser", 1)
        persistence.selectProfile(1)
        profile = persistence.getActiveProfile()
    end
    profile.monedas = 100
    profile.highScore = 500
    profile.achievements = {}
    profile.unlocks = {}

    local st = world.state
    st.anchoGrilla = 32
    st.altoGrilla = 18
    st.gameState = constants.GAME_STATE_PLAYING
    st.time = 0
    st.introTimer = 0
    st.celebrationTimer = 0
    st.cronometro = 0
    st.baseSpeed = constants.VELOCIDAD_INICIAL
    st.velocidadActual = constants.VELOCIDAD_INICIAL
    st.puntuacion = 0
    st.frutasContador = 0
    st.monedas = 100
    st.highScore = 500
    st.nuevoHighScore = false
    st.coinBonus = 0
    st.scoreMultiplier = 1
    st.survivalStreak = 1.0
    st.highestStreak = 1.0
    st.roomDamaged = false
    st.deathModalOpen = false
    st.deathAnimTimer = 0
    st.shakeTimer = 0
    st.fadeAlpha = 0
    st.fadeDir = 0
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
    st.scheduledToasts = {}
    st.scheduledIndex = {}
    st.pendingAchievements = {}
    st.debugMenuOpen = false
    st.debugImmune = false
    st.debugAchievementsOpen = false
    st.debugDungeonOverlay = false
    st.debugLogoOpen = false
    st.transitionTarget = nil
    st.transitionPhase = nil
    st.transitionHoldTimer = 0
    st.mundoCompletado = false
    st.bossHealthDisplay = nil

    st.player = snakeMod.reset()
    foodMod.pos = {x = 10, y = 10}
    foodMod.tipo = constants.FOOD_NORMAL
    foodMod.twinPos = nil
    obstaclesMod.pos = {}
    obstaclesMod.flashTimers = {}
    enemiesMod.list = {}
    enemiesMod.boss = nil
    worldMod.etapa = 1
    worldMod.sala = 1
    worldMod.objetivoSala = 100
end

harness.describe("Game States Dispatcher & Logic (systems/gamestates.lua)", function()
    harness.before_each(function()
        setupWorldState()
    end)

    harness.it("states.overlaysOpen returns true when modals or overlays are open", function()
        local profilesMod = require("systems.profiles")
        local settingsMod = require("systems.settings")
        profilesMod.visible = false
        settingsMod.visible = false
        world.state.debugAchievementsOpen = false
        harness.assert_false(states.overlaysOpen(), "Overlays should be closed")

        world.state.debugAchievementsOpen = true
        harness.assert_true(states.overlaysOpen(), "debugAchievementsOpen should count as overlay")

        world.state.debugAchievementsOpen = false
        settingsMod.visible = true
        harness.assert_true(states.overlaysOpen(), "settingsMod.visible should count as overlay")

        settingsMod.visible = false
        profilesMod.visible = true
        harness.assert_true(states.overlaysOpen(), "profilesMod.visible should count as overlay")
        profilesMod.visible = false
    end)

    harness.it("states.flushPendingAchievements empties queue and generates toasts", function()
        world.state.pendingAchievements = {"first_kill", "coins_100"}
        states.flushPendingAchievements()
        harness.assert_equal(0, #world.state.pendingAchievements, "Queue should be empty after flush")
    end)

    harness.it("states.updateCommon advances time, timers, shake, shockwaves and toasts", function()
        local st = world.state
        st.time = 10.0
        st.shakeTimer = 0.5
        st.fadeDir = 1
        st.fadeAlpha = 0.2
        table.insert(st.shockwaves, {x = 100, y = 100, radio = 10, timer = 0, alpha = 1})
        local timerEnded = false
        table.insert(st.activeTimers, {remaining = 0.05, onEnd = function() timerEnded = true end})

        states.updateCommon(0.1)

        harness.assert_almost_equal(10.1, st.time, 0.001, "st.time should advance")
        harness.assert_almost_equal(0.4, st.shakeTimer, 0.001, "shakeTimer should decrement")
        harness.assert_gt(st.fadeAlpha, 0.2, "fadeAlpha should increase")
        harness.assert_true(timerEnded, "activeTimer callback should fire")
        harness.assert_equal(0, #st.activeTimers, "expired activeTimer should be removed")
    end)

    harness.it("states.updateMenu advances intro timer", function()
        local st = world.state
        st.introTimer = 1.0
        states.updateMenu(0.5)
        harness.assert_almost_equal(1.5, st.introTimer, 0.001, "introTimer should increase by dt")
    end)

    harness.it("states.updatePlaying updates snake movement and triggers food eating", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        st.player.dir = {x = 1, y = 0}
        foodMod.pos = {x = 6, y = 5}
        foodMod.tipo = constants.FOOD_NORMAL
        st.cronometro = st.velocidadActual - 0.01

        local died = states.updatePlaying(0.02)
        harness.assert_false(died, "Snake should not die")
        harness.assert_equal(6, st.player.body[1].x, "Snake head should advance onto food")
        harness.assert_gt(st.puntuacion, 0, "Score should increase from eating food")
        harness.assert_equal(1, st.frutasContador, "Fruit counter should increment")
    end)

    harness.it("states.updatePlaying handles death modal and death return value", function()
        local st = world.state
        st.player.body = {{x = 0, y = 5}, {x = 1, y = 5}}
        st.player.dir = {x = -1, y = 0} -- Move left outside grid boundary (x = -1)
        st.cronometro = st.velocidadActual - 0.01

        local died = states.updatePlaying(0.02)
        harness.assert_true(died, "Snake leaving grid should die")
        harness.assert_true(st.deathModalOpen, "Death modal should be opened")
        harness.assert_true(st.roomDamaged, "roomDamaged should be flagged")
    end)

    harness.it("states.updatePlaying progresses to transition when score target is reached", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        st.player.dir = {x = 1, y = 0}
        foodMod.pos = {x = 6, y = 5}
        worldMod.objetivoSala = 10
        st.puntuacion = 5
        st.cronometro = st.velocidadActual - 0.01

        local transitioned = states.updatePlaying(0.02)
        harness.assert_true(transitioned, "Reaching objective should return true and trigger transition")
        harness.assert_equal("siguienteSala", st.transitionTarget, "Target should be siguienteSala")
        harness.assert_equal(constants.GAME_STATE_TRANSITION, st.gameState, "State should be TRANSITION")
    end)

    harness.it("states.updatePlaying handles boss defeat by food target", function()
        local st = world.state
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        st.player.dir = {x = 1, y = 0}
        foodMod.pos = {x = 6, y = 5}
        foodMod.tipo = constants.FOOD_NORMAL

        enemiesMod.boss = {
            alive = true,
            foodCollected = 14,
            foodTarget = 15,
            _uiBarTarget = 0.1,
            gx = 16, gy = 9,
            px = 320, py = 180,
            onBossDefeatedByFood = function()
                enemiesMod.boss.alive = false
                return {coins = 20, gx = 16, gy = 9, px = 320, py = 180, type = "boss"}
            end
        }
        enemiesMod.onBossDefeatedByFood = enemiesMod.boss.onBossDefeatedByFood
        worldMod.sala = 5 -- Last room of stage

        st.cronometro = st.velocidadActual - 0.01
        states.updatePlaying(0.02)

        harness.assert_gte(st.monedas, 120, "Boss defeat coins should be awarded")
        harness.assert_equal(constants.GAME_STATE_TRANSITION, st.gameState, "Boss defeat should transition stage")
    end)

    harness.it("states.updateDeath removes snake segments and transitions to shop/highScore", function()
        local st = world.state
        st.gameState = constants.GAME_STATE_DEATH_ANIMATION
        st.player.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        st.deathAnimTimer = 0

        -- Pop first segment
        states.updateDeath(constants.DEATH_ANIMATION_SEGMENT_DELAY + 0.01)
        harness.assert_equal(1, #st.player.body, "One segment should be removed")

        -- Pop second segment -> body empty -> transition to SHOP
        st.nuevoHighScore = false
        states.updateDeath(constants.DEATH_ANIMATION_SEGMENT_DELAY + 0.01)
        harness.assert_equal(0, #st.player.body, "Snake body should be empty")
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState, "State should become SHOP")
    end)

    harness.it("states.updateHighScore counts down celebration timer then enters shop", function()
        local st = world.state
        st.gameState = constants.GAME_STATE_HIGH_SCORE
        st.celebrationTimer = 0.2

        states.updateHighScore(0.1)
        harness.assert_equal(constants.GAME_STATE_HIGH_SCORE, st.gameState, "Celebration still ongoing")

        states.updateHighScore(0.15)
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState, "Should transition to SHOP on celebration end")
    end)

    harness.it("states.updateTransition executes Phase 1 -> Hold -> Phase 2 -> Shop", function()
        local st = world.state
        st.gameState = constants.GAME_STATE_TRANSITION
        st.transitionPhase = 1
        st.fadeAlpha = 1.0
        st.transitionTarget = "siguienteSala"
        st.roomDamaged = false

        local initialStreak = st.survivalStreak

        -- Phase 1 trigger (fadeAlpha >= 1)
        states.updateTransition(0.016)
        harness.assert_equal("hold", st.transitionPhase, "Phase should advance to hold")
        harness.assert_gt(st.survivalStreak, initialStreak, "Survival streak should increment on undamaged room")

        -- Hold phase
        states.updateTransition(1.0)
        harness.assert_equal("hold", st.transitionPhase, "Phase should remain hold before 2s")
        states.updateTransition(1.1)
        harness.assert_equal(2, st.transitionPhase, "Phase should become 2 after 2s hold")
        harness.assert_equal(-1, st.fadeDir, "fadeDir should be -1 for fade-in")

        -- Phase 2 completion (fadeAlpha <= 0)
        st.fadeAlpha = 0.0
        states.updateTransition(0.016)
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState, "State should be SHOP after transition")
        harness.assert_nil(st.transitionTarget, "transitionTarget should be cleared")
    end)

    harness.it("states.update master dispatcher routes all 7 game states cleanly", function()
        local st = world.state

        -- MENU
        st.gameState = constants.GAME_STATE_MENU
        st.introTimer = 0
        states.update(0.1)
        harness.assert_almost_equal(0.1, st.introTimer, 0.001, "MENU state dispatched")

        -- PLAYING
        st.gameState = constants.GAME_STATE_PLAYING
        states.update(0.016)
        harness.assert_gt(st.cronometro, 0, "PLAYING state dispatched")

        -- PAUSED
        st.gameState = constants.GAME_STATE_PAUSED
        states.update(0.016)
        harness.assert_equal(constants.GAME_STATE_PAUSED, st.gameState, "PAUSED state dispatched")

        -- SHOP
        st.gameState = constants.GAME_STATE_SHOP
        states.update(0.016)
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState, "SHOP state dispatched")

        -- DEATH_ANIMATION
        st.gameState = constants.GAME_STATE_DEATH_ANIMATION
        st.player.body = {{x = 1, y = 1}}
        st.deathAnimTimer = 0
        states.update(0.01)
        harness.assert_gt(st.deathAnimTimer, 0, "DEATH state dispatched")

        -- HIGH_SCORE
        st.gameState = constants.GAME_STATE_HIGH_SCORE
        st.celebrationTimer = 1.0
        states.update(0.1)
        harness.assert_almost_equal(0.9, st.celebrationTimer, 0.001, "HIGH_SCORE state dispatched")

        -- TRANSITION
        st.gameState = constants.GAME_STATE_TRANSITION
        st.transitionPhase = "hold"
        st.transitionHoldTimer = 0
        states.update(0.1)
        harness.assert_almost_equal(0.1, st.transitionHoldTimer, 0.001, "TRANSITION state dispatched")
    end)
end)

harness.describe("Debug Tools (systems/debugTools.lua)", function()
    harness.before_each(function()
        setupWorldState()
    end)

    harness.it("Menu open/close/toggle and keypressed Tab work properly", function()
        debugTools.closeMenu()
        harness.assert_false(debugTools.isMenuOpen(), "Menu should be closed")

        debugTools.openMenu()
        harness.assert_true(debugTools.isMenuOpen(), "Menu should be open")

        debugTools.toggleMenu()
        harness.assert_false(debugTools.isMenuOpen(), "Menu should be closed after toggle")

        local consumed = debugTools.keypressed("tab")
        harness.assert_true(consumed, "Tab key should be consumed")
        harness.assert_true(debugTools.isMenuOpen(), "Tab key should open menu")
    end)

    harness.it("dibujarDebugMenu populates interactive button list", function()
        world.state.debugMenuOpen = true
        debugTools.dibujarDebugMenu()
        harness.assert_not_nil(world.state.debugButtons, "debugButtons should be created")
        harness.assert_gte(#world.state.debugButtons, 8, "All debug buttons should be registered")
    end)

    harness.it("mousepressed handles coins, immune, speed, combo, skip, achievements", function()
        local st = world.state
        st.debugMenuOpen = true
        debugTools.dibujarDebugMenu()

        local function clickBtn(action)
            for _, btn in ipairs(st.debugButtons) do
                if btn.action == action then
                    return debugTools.mousepressed(btn.x + 2, btn.y + 2, 1)
                end
            end
            return false
        end

        -- Coins +10
        local oldCoins = st.monedas
        harness.assert_true(clickBtn("coins"), "Click coins button")
        harness.assert_equal(oldCoins + 10, st.monedas, "+10 coins awarded")

        -- Toggle Inmune
        st.debugImmune = false
        harness.assert_true(clickBtn("immune"), "Click immune button")
        harness.assert_true(st.debugImmune, "Inmune should be ON")
        harness.assert_true(clickBtn("immune"), "Click immune button again")
        harness.assert_false(st.debugImmune, "Inmune should be OFF")

        -- Speed Up / Down
        local base = st.baseSpeed
        harness.assert_true(clickBtn("speedUp"), "Click speedUp button")
        harness.assert_lt(st.baseSpeed, base, "Speed Up should decrease frame delay")
        harness.assert_true(clickBtn("speedDown"), "Click speedDown button")
        harness.assert_almost_equal(base, st.baseSpeed, 0.001, "Speed Down should restore baseSpeed")

        -- Combo Up / Down
        st.comboCount = 0
        harness.assert_true(clickBtn("comboUp"), "Click comboUp button")
        harness.assert_equal(1, st.comboCount, "Combo count should increase")
        harness.assert_true(clickBtn("comboDown"), "Click comboDown button")
        harness.assert_equal(0, st.comboCount, "Combo count should decrease to 0")

        -- Logros modal toggle
        st.debugAchievementsOpen = false
        harness.assert_true(clickBtn("achievements"), "Click achievements button")
        harness.assert_true(st.debugAchievementsOpen, "Achievements modal should be open")

        -- Dungeon Map toggle
        st.debugDungeonOverlay = false
        harness.assert_true(clickBtn("dungeonMap"), "Click dungeonMap button")
        harness.assert_true(st.debugDungeonOverlay, "Dungeon overlay should be enabled")

        -- Skip Room
        st.transitionTarget = nil
        harness.assert_true(clickBtn("skip"), "Click skip button")
        harness.assert_equal("siguienteSala", st.transitionTarget, "skip should set siguienteSala target")
        harness.assert_equal(constants.GAME_STATE_TRANSITION, st.gameState, "skip should enter transition")
    end)

    harness.it("Debug achievements modal drawing and toggles", function()
        local st = world.state
        st.debugAchievementsOpen = true
        debugTools.drawDebugAchievementsModal()
        harness.assert_not_nil(st.debugAchievementModalButtons, "Modal buttons should be created")
        harness.assert_gte(#st.debugAchievementModalButtons, 5, "Achievement rows created")

        -- Toggle achievement
        local aid = "first_kill"
        harness.assert_false(debugTools.getAchievementState(aid), "first_kill initially locked")
        debugTools.toggleDebugAchievement(aid)
        harness.assert_true(debugTools.getAchievementState(aid), "first_kill unlocked after toggle")
        debugTools.toggleDebugAchievement(aid)
        harness.assert_false(debugTools.getAchievementState(aid), "first_kill locked after second toggle")
    end)
end)

harness.describe("Debug Logo Calibrator (systems/debugLogo.lua)", function()
    harness.before_each(function()
        setupWorldState()
        local cfg = persistence.getLogoConfig()
        cfg.offsetX = 0
        cfg.offsetY = 0
        cfg.scale = 6
        cfg.spacing = 10
        cfg.depth = 5
        persistence.saveLogoConfig()
    end)

    harness.it("debugLogo open, close, and toggle state management", function()
        debugLogo.close()
        harness.assert_false(debugLogo.isOpen(), "Logo debug should be closed")

        debugLogo.open()
        harness.assert_true(debugLogo.isOpen(), "Logo debug should be open")

        debugLogo.toggle()
        harness.assert_false(debugLogo.isOpen(), "Logo debug should close after toggle")

        local consumed = debugLogo.keypressed("f2")
        harness.assert_true(consumed, "F2 key should be consumed")
        harness.assert_true(debugLogo.isOpen(), "F2 should open logo debug")
    end)

    harness.it("debugLogo.draw renders controls and allows interactive button clicks", function()
        debugLogo.open()
        debugLogo.draw()

        local cfg = persistence.getLogoConfig()
        harness.assert_equal(0, cfg.offsetX, "Initial offsetX is 0")
        harness.assert_equal(0, cfg.offsetY, "Initial offsetY is 0")

        -- Click X+ button (located around px + 74, py + 50)
        local w = love.graphics.getWidth()
        local pw = 286
        local px = w - pw - 10
        local py = 10

        -- Click x_inc
        local clicked = debugLogo.mousepressed(px + 74 + 10, py + 50 + 5, 1)
        harness.assert_true(clicked, "Clicking x_inc should be handled")
        harness.assert_equal(1, cfg.offsetX, "offsetX should increment to 1")

        -- Click x_dec
        clicked = debugLogo.mousepressed(px + 8 + 10, py + 50 + 5, 1)
        harness.assert_true(clicked, "Clicking x_dec should be handled")
        harness.assert_equal(0, cfg.offsetX, "offsetX should decrement back to 0")

        -- Click scale_inc
        clicked = debugLogo.mousepressed(px + 74 + 10, py + 76 + 5, 1)
        harness.assert_true(clicked, "Clicking scale_inc should be handled")
        harness.assert_equal(7, cfg.scale, "scale should increment to 7")

        -- Click reset
        clicked = debugLogo.mousepressed(px + 8 + 10, py + 104 + 5, 1)
        harness.assert_true(clicked, "Clicking reset button should be handled")
        harness.assert_equal(6, cfg.scale, "scale should reset to 6")
        harness.assert_equal(0, cfg.offsetX, "offsetX should reset to 0")
    end)

    harness.it("debugLogo mouse dragging modifies offset and persists on release", function()
        debugLogo.open()
        local cfg = persistence.getLogoConfig()
        cfg.offsetX = 0
        cfg.offsetY = 0

        -- Click inside logo bounds to start dragging
        local menuLogo = require("ui.menuLogo")
        local startX, startY, totalW, totalH, depth = menuLogo.getBounds(0)
        local clickX = startX + 20
        local clickY = startY + 20

        local started = debugLogo.mousepressed(clickX, clickY, 1)
        harness.assert_true(started, "Clicking logo bounds should start dragging")
        harness.assert_true(debugLogo.isDragging(), "Dragging flag should be active")

        -- Move mouse by (+50, +30)
        debugLogo.mousemoved(clickX + 50, clickY + 30)
        harness.assert_equal(50, cfg.offsetX, "offsetX should follow drag delta")
        harness.assert_equal(30, cfg.offsetY, "offsetY should follow drag delta")

        -- Release mouse
        debugLogo.mousereleased()
        harness.assert_false(debugLogo.isDragging(), "Dragging flag should be reset")
        harness.assert_equal(50, cfg.offsetX, "offsetX should remain 50 after release")
    end)

    harness.it("debugLogo keyboard adjustments (arrows, brackets, plus/minus, reset)", function()
        debugLogo.open()
        local cfg = persistence.getLogoConfig()

        -- Arrow Right
        debugLogo.keypressed("right")
        harness.assert_equal(1, cfg.offsetX, "Arrow right increments offsetX")

        -- Arrow Left
        debugLogo.keypressed("left")
        harness.assert_equal(0, cfg.offsetX, "Arrow left decrements offsetX")

        -- Arrow Down
        debugLogo.keypressed("down")
        harness.assert_equal(1, cfg.offsetY, "Arrow down increments offsetY")

        -- Arrow Up
        debugLogo.keypressed("up")
        harness.assert_equal(0, cfg.offsetY, "Arrow up decrements offsetY")

        -- Scale '[' and ']'
        debugLogo.keypressed("]")
        harness.assert_equal(7, cfg.scale, "] increments scale")
        debugLogo.keypressed("[")
        harness.assert_equal(6, cfg.scale, "[ decrements scale")

        -- Depth '+' and '-'
        debugLogo.keypressed("+")
        harness.assert_equal(6, cfg.depth, "+ increments depth")
        debugLogo.keypressed("-")
        harness.assert_equal(5, cfg.depth, "- decrements depth")

        -- Reset 'r'
        cfg.offsetX = 40
        debugLogo.keypressed("r")
        harness.assert_equal(0, cfg.offsetX, "r resets offsetX to 0")

        -- Enter / Escape closes
        debugLogo.keypressed("escape")
        harness.assert_false(debugLogo.isOpen(), "escape closes calibrator")
    end)
end)

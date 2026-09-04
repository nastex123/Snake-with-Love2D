local harness = require("tests.test_harness")
local helper = require("tests.test_systems_helper")
local setupCleanWorld = helper.setupCleanWorld
local shop = helper.shop
local persistence = helper.persistence
local items = helper.items
local settings = helper.settings
local settingsDraw = helper.settingsDraw
local profilesMod = helper.profilesMod
local profilesDraw = helper.profilesDraw
local achievementsMod = helper.achievementsMod
local playerMod = helper.playerMod
local gameflow = helper.gameflow
local gamestates = helper.gamestates
local debugTools = helper.debugTools
local debugLogo = helper.debugLogo
local constants = helper.constants
local world = helper.world

harness.describe("Systems: Gameflow Lifecycle & Room Transitions", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("gameflow.applyActiveProfile should load profile coins, highScore, streak, and passive unlocks", function()
        persistence.createProfile("Loader")
        local p = persistence.getActiveProfile()
        p.monedas = 250
        p.highScore = 4000
        p.stats.highestStreak = 3.0
        p.unlocks = {speedReducer = true, extraCoin = true}

        gameflow.applyActiveProfile()
        local st = world.state
        harness.assert_equal(250, st.monedas)
        harness.assert_equal(4000, st.highScore)
        harness.assert_equal(3.0, st.highestStreak)
        harness.assert_true(shop.inventory.speedReducer)
        harness.assert_true(shop.inventory.extraCoin)
    end)

    harness.it("gameflow.resetGame should differentiate fresh run vs keepShopInventory", function()
        shop.inventory.speedReducer = true
        shop.inventory.extraCoin = true

        -- fresh run (keepShopInventory = false)
        gameflow.resetGame(false)
        local st = world.state
        harness.assert_equal(0, st.monedas)
        harness.assert_equal(0, st.puntuacion)
        harness.assert_equal(0, st.coinBonus)
        harness.assert_false(shop.inventory.speedReducer)

        -- continuous room (keepShopInventory = true)
        shop.inventory.speedReducer = true
        shop.inventory.extraCoin = true
        st.monedas = 80
        gameflow.resetGame(true)
        harness.assert_equal(80, st.monedas, "Monedas should be preserved when keeping inventory")
        harness.assert_equal(1, st.coinBonus, "extraCoin passive should apply coinBonus=1")
    end)

    harness.it("gameflow.iniciarSala should reset room score and populate entities", function()
        world.state.anchoGrilla = 32
        world.state.altoGrilla = 18
        gameflow.iniciarSala(true)
        harness.assert_equal(0, world.state.puntuacion)
        harness.assert_equal(0, worldMod.puntajeSala)
        harness.assert_not_nil(foodMod.pos)
    end)

    harness.it("gameflow.revivePlayer should deduct coins, apply ghost immunity, and clear nearby enemies", function()
        persistence.createProfile("ReviveUser")
        local st = world.state
        st.monedas = 20 -- not enough for 30 cost
        local okFail = gameflow.revivePlayer()
        harness.assert_false(okFail, "Revive with 20 coins must fail")

        st.monedas = 50
        st.player.body[1] = {x = 10, y = 10}
        enemiesMod.list = {
            {x = 11, y = 10, alive = true, type = "chaser", px = 220, py = 200, gx = 11, gy = 10},
            {x = 25, y = 25, alive = true, type = "patroller", px = 500, py = 500, gx = 25, gy = 25}
        }
        local okSuccess = gameflow.revivePlayer()
        harness.assert_true(okSuccess, "Revive with 50 coins must succeed")
        harness.assert_equal(20, st.monedas, "30 coins should be deducted")
        harness.assert_false(st.deathModalOpen)
        harness.assert_true(st.player.ghost)
        harness.assert_equal(constants.GAME_STATE_PLAYING, st.gameState)
        harness.assert_false(enemiesMod.list[1].alive, "Nearby enemy within 3 tiles must be killed")
        harness.assert_true(enemiesMod.list[2].alive, "Distant enemy should remain alive")
    end)

    harness.it("gameflow.recalcularGrilla should calculate valid grid dimensions", function()
        gameflow.recalcularGrilla()
        local st = world.state
        harness.assert_gt(st.anchoGrilla, 0)
        harness.assert_lte(st.anchoGrilla, constants.MAX_GRID_COLS)
        harness.assert_gt(st.altoGrilla, 0)
        harness.assert_lte(st.altoGrilla, constants.MAX_GRID_ROWS)
        harness.assert_gte(st.gridOffsetX, 0)
        harness.assert_gte(st.gridOffsetY, 0)
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 9: Gamestates Logic & State Updates
--------------------------------------------------------------------------------
harness.describe("Systems: Gamestates Update & Transitions", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("states.overlaysOpen should detect active UI modals", function()
        harness.assert_false(gamestates.overlaysOpen())

        settings.open()
        harness.assert_true(gamestates.overlaysOpen())
        settings.close()

        profilesMod.open()
        harness.assert_true(gamestates.overlaysOpen())
        profilesMod.close()

        world.state.debugAchievementsOpen = true
        harness.assert_true(gamestates.overlaysOpen())
        world.state.debugAchievementsOpen = false
    end)

    harness.it("states.flushPendingAchievements should drain queue and trigger toasts", function()
        world.state.pendingAchievements = {"first_kill", "stage_3"}
        gamestates.flushPendingAchievements()
        harness.assert_equal(0, #world.state.pendingAchievements, "Pending achievements queue should be empty")
    end)

    harness.it("states.updateCommon should advance time, timers, and trigger onEnd callbacks", function()
        local callbackFired = false
        table.insert(world.state.activeTimers, {
            remaining = 0.1,
            onEnd = function() callbackFired = true end
        })

        gamestates.updateCommon(0.05)
        harness.assert_false(callbackFired)
        harness.assert_equal(1, #world.state.activeTimers)

        gamestates.updateCommon(0.06)
        harness.assert_true(callbackFired, "Timer onEnd callback should fire when remaining <= 0")
        harness.assert_equal(0, #world.state.activeTimers)
    end)

    harness.it("states.updateMenu should advance introTimer", function()
        world.state.introTimer = 0
        gamestates.updateMenu(0.5)
        harness.assert_almost_equal(0.5, world.state.introTimer, 0.001)
    end)

    harness.it("states.updateDeath should disassemble snake body and switch to SHOP or HIGH_SCORE", function()
        local st = world.state
        st.player.body = {{x=5,y=5}, {x=4,y=5}, {x=3,y=5}}
        st.deathAnimTimer = 0

        -- Step 1
        gamestates.updateDeath(constants.DEATH_ANIMATION_SEGMENT_DELAY)
        harness.assert_equal(2, #st.player.body)

        -- Step 2
        gamestates.updateDeath(constants.DEATH_ANIMATION_SEGMENT_DELAY)
        harness.assert_equal(1, #st.player.body)

        -- Step 3
        gamestates.updateDeath(constants.DEATH_ANIMATION_SEGMENT_DELAY)
        harness.assert_equal(0, #st.player.body)

        -- Final step triggers transition
        gamestates.updateDeath(constants.DEATH_ANIMATION_SEGMENT_DELAY)
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState)
    end)

    harness.it("states.updateHighScore should transition to SHOP after celebrationTimer", function()
        local st = world.state
        st.celebrationTimer = 0.5
        gamestates.updateHighScore(0.3)
        harness.assert_almost_equal(0.2, st.celebrationTimer, 0.001)

        gamestates.updateHighScore(0.3)
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState)
    end)

    harness.it("states.updateTransition should handle Phase 1, hold, and Phase 2 progression", function()
        local st = world.state
        st.transitionPhase = 1
        st.fadeAlpha = 1.0
        st.transitionTarget = "siguienteSala"

        gamestates.updateTransition(0.016)
        harness.assert_equal("hold", st.transitionPhase)
        harness.assert_equal(0, st.transitionHoldTimer)

        -- Hold for 2s
        gamestates.updateTransition(1.5)
        harness.assert_equal("hold", st.transitionPhase)

        gamestates.updateTransition(0.6)
        harness.assert_equal(2, st.transitionPhase)
        harness.assert_equal(-1, st.fadeDir)

        -- Fade in finishes
        st.fadeAlpha = 0
        gamestates.updateTransition(0.016)
        harness.assert_nil(st.transitionPhase)
        harness.assert_nil(st.transitionTarget)
        harness.assert_equal(constants.GAME_STATE_SHOP, st.gameState)
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 10: Debug Tools & Logo Calibration
--------------------------------------------------------------------------------
harness.describe("Systems: Debug Tools & Logo Calibration", function()
    harness.before_each(function()
        setupCleanWorld()
        persistence.createProfile("DebugUser")
    end)

    harness.it("debugTools.toggleDebugAchievement should toggle achievements on and off in active profile", function()
        harness.assert_false(debugTools.getAchievementState("first_kill"))

        debugTools.toggleDebugAchievement("first_kill")
        harness.assert_true(debugTools.getAchievementState("first_kill"))

        debugTools.toggleDebugAchievement("first_kill")
        harness.assert_false(debugTools.getAchievementState("first_kill"))
    end)

    harness.it("debugTools.dibujarDebugMenu and drawDebugAchievementsModal should execute cleanly", function()
        debugTools.dibujarDebugMenu()
        harness.assert_not_nil(world.state.debugButtons)
        harness.assert_gt(#world.state.debugButtons, 0)

        world.state.debugAchievementsOpen = true
        debugTools.drawDebugAchievementsModal()
        harness.assert_not_nil(world.state.debugAchievementModalButtons)
        harness.assert_gt(#world.state.debugAchievementModalButtons, 0)
    end)

    harness.it("debugTools.mousepressed should handle debug action clicks", function()
        world.state.debugMenuOpen = true
        debugTools.dibujarDebugMenu()

        -- Click +10 Coins button
        for _, btn in ipairs(world.state.debugButtons) do
            if btn.action == "coins" then
                local prevCoins = world.state.monedas
                local handled = debugTools.mousepressed(btn.x + 2, btn.y + 2, 1)
                harness.assert_true(handled)
                harness.assert_equal(prevCoins + 10, world.state.monedas)
                break
            end
        end

        -- Click Immune button
        for _, btn in ipairs(world.state.debugButtons) do
            if btn.action == "immune" then
                local prevImmune = world.state.debugImmune
                debugTools.mousepressed(btn.x + 2, btn.y + 2, 1)
                harness.assert_equal(not prevImmune, world.state.debugImmune)
                break
            end
        end

        -- Click Speed + / -
        for _, btn in ipairs(world.state.debugButtons) do
            if btn.action == "speedUp" then
                local prevBase = world.state.baseSpeed
                debugTools.mousepressed(btn.x + 2, btn.y + 2, 1)
                harness.assert_almost_equal(prevBase - constants.SPEED_ADJUST_INCREMENT, world.state.baseSpeed, 0.001)
                break
            end
        end
    end)

    harness.it("debugLogo should handle toggle, keyboard adjustments, and reset", function()
        harness.assert_false(debugLogo.isOpen())
        debugLogo.toggle()
        harness.assert_true(debugLogo.isOpen())

        local cfg = persistence.getLogoConfig()
        local origX = cfg.offsetX or 0
        local origScale = cfg.scale or 6
        local origDepth = cfg.depth or 5

        -- Adjust X with Right arrow
        debugLogo.keypressed("right")
        harness.assert_equal(origX + 1, cfg.offsetX)

        -- Adjust Scale with ]
        debugLogo.keypressed("]")
        harness.assert_equal(origScale + 1, cfg.scale)

        -- Adjust Depth with +
        debugLogo.keypressed("+")
        harness.assert_equal(origDepth + 1, cfg.depth)

        -- Reset with 'r'
        debugLogo.keypressed("r")
        harness.assert_equal(0, cfg.offsetX)
        harness.assert_equal(0, cfg.offsetY)
        harness.assert_equal(6, cfg.scale)
        harness.assert_equal(5, cfg.depth)

        -- Close with return
        debugLogo.keypressed("return")
        harness.assert_false(debugLogo.isOpen())
    end)

    harness.it("debugLogo.draw and mouse events should execute without errors", function()
        debugLogo.toggle()
        debugLogo.draw()
        debugLogo.mousemoved(100, 100)
        debugLogo.mousereleased()
        debugLogo.toggle()
    end)
end)


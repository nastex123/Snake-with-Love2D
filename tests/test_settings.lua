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

harness.describe("Systems: Settings & SettingsDraw", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("settings.open and close should manage modal visibility and backups", function()
        settings.open()
        harness.assert_true(settings.visible, "Settings should be visible after open")
        harness.assert_not_nil(settings.editing, "Editing table must be populated")
        harness.assert_not_nil(settings.lastSaved, "LastSaved table must be populated")
        harness.assert_equal("Audio", settings.activeTab)

        settings.close()
        harness.assert_false(settings.visible, "Settings should be hidden after close")
        harness.assert_nil(settings.editing)
    end)

    harness.it("settings.draw should execute without error across all tabs", function()
        settings.open()
        settings.draw()

        settings.activeTab = "Gráficos"
        settings.draw()

        settings.activeTab = "Accesibilidad"
        settings.draw()

        settings.close()
    end)

    harness.it("settings.mousepressed should handle tab switching and control updates", function()
        settings.open()
        settings.draw() -- populates hitboxes

        -- Click close button
        if settings.g.closeBtn then
            settings.mousepressed(settings.g.closeBtn[1] + 2, settings.g.closeBtn[2] + 2, 1)
            harness.assert_false(settings.visible, "Close button should close settings")
        end

        settings.open()
        settings.draw()

        -- Toggle music checkbox
        if settings.g.musicBox then
            local prevMusic = settings.editing.audio.music
            settings.mousepressed(settings.g.musicBox[1] + 2, settings.g.musicBox[2] + 2, 1)
            harness.assert_equal(not prevMusic, settings.editing.audio.music, "Music checkbox should toggle")
        end

        -- Click save button
        if settings.g.saveBtn then
            settings.mousepressed(settings.g.saveBtn[1] + 2, settings.g.saveBtn[2] + 2, 1)
            harness.assert_false(settings.visible, "Save button should save and close")
        end
    end)

    harness.it("settings.mousemoved and mousereleased should handle slider dragging", function()
        settings.open()
        settings.draw()
        settings.dragState = {type = "master", bx = 100, bw = 100}
        settings.mousemoved(150, 50, 0, 0)
        harness.assert_almost_equal(0.5, settings.editing.audio.master, 0.05)

        settings.mousereleased(150, 50, 1)
        harness.assert_nil(settings.dragState)
        settings.close()
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 5: Profiles UI & Modal Interactions
--------------------------------------------------------------------------------
harness.describe("Systems: Profiles & ProfilesDraw UI", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("profilesMod.open and close should manage visible state", function()
        profilesMod.open()
        harness.assert_true(profilesMod.visible)
        harness.assert_equal("select", profilesMod.state)

        profilesMod.close()
        harness.assert_false(profilesMod.visible)
    end)

    harness.it("profilesMod.draw should render in select, input, confirm, and achievements states", function()
        persistence.createProfile("TestProfile")
        profilesMod.open()

        profilesMod.state = "select"
        profilesMod.draw()

        profilesMod.state = "input"
        profilesMod.confirmType = "create"
        profilesMod.draw()

        profilesMod.state = "confirm"
        profilesMod.confirmMsg = "Test confirm"
        profilesMod.draw()

        profilesMod.state = "achievements"
        profilesMod.confirmIndex = 1
        profilesMod.draw()

        profilesMod.close()
    end)

    harness.it("profilesMod.textinput and keypressed should handle text entry and confirmation", function()
        profilesMod.open()
        profilesMod.state = "input"
        profilesMod.confirmType = "create"
        profilesMod.inputIndex = 1
        profilesMod.textInputActive = true

        profilesMod.textinput("N")
        profilesMod.textinput("e")
        profilesMod.textinput("o")
        harness.assert_equal("Neo", profilesMod.nameInput)

        profilesMod.keypressed("backspace")
        harness.assert_equal("Ne", profilesMod.nameInput)

        profilesMod.keypressed("return")
        harness.assert_equal("select", profilesMod.state)
        local p = persistence.getActiveProfile()
        harness.assert_not_nil(p)
        harness.assert_equal("Ne", p.name)

        profilesMod.close()
    end)

    harness.it("profilesMod.mousepressed should trigger create, select, rename, reset, delete", function()
        profilesMod.open()
        profilesMod.draw()

        -- Click CREATE on slot 1
        for _, btn in ipairs(profilesMod.buttonRects) do
            if btn.action == "create" and btn.index == 1 then
                profilesMod.mousepressed(btn.x + 2, btn.y + 2, 1)
                break
            end
        end
        harness.assert_equal("input", profilesMod.state)
        harness.assert_equal("create", profilesMod.confirmType)

        -- Confirm creation
        profilesMod.nameInput = "CreatedViaMouse"
        profilesMod.handleInputConfirm()
        harness.assert_equal("select", profilesMod.state)
        harness.assert_equal("CreatedViaMouse", persistence.getActiveProfile().name)

        profilesMod.close()
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 6: 11 Achievements Detection & Triggers
--------------------------------------------------------------------------------
harness.describe("Systems: Achievements Triggers & Detection", function()
    harness.before_each(function()
        setupCleanWorld()
        persistence.createProfile("AchTester")
    end)

    harness.it("should have all 11 defined achievements in registry", function()
        local expected = {
            "first_kill", "enemy_25", "enemy_100",
            "combo_5", "combo_10",
            "coins_100", "coins_500",
            "stage_3", "boss_kill",
            "score_1000", "score_5000"
        }
        harness.assert_equal(11, #expected)
        for _, id in ipairs(expected) do
            local def = achievementsMod.registry[id]
            harness.assert_not_nil(def, "Achievement " .. id .. " must exist in registry")
            harness.assert_type(def.title, "string")
            harness.assert_type(def.desc, "string")
        end
    end)

    harness.it("should trigger first_kill, enemy_25, and enemy_100 on enemy kills", function()
        local p = persistence.getActiveProfile()

        -- 1st kill -> first_kill
        achievementsMod.check("enemyKilled")
        harness.assert_not_nil(p.achievements.first_kill, "first_kill should be unlocked")
        harness.assert_true(p.achievements.first_kill.done)
        harness.assert_nil(p.achievements.enemy_25, "enemy_25 should not yet be unlocked")

        -- 24 more kills (total 25) -> enemy_25
        for _ = 1, 24 do achievementsMod.check("enemyKilled") end
        harness.assert_not_nil(p.achievements.enemy_25, "enemy_25 should be unlocked at 25 kills")

        -- 75 more kills (total 100) -> enemy_100
        for _ = 1, 75 do achievementsMod.check("enemyKilled") end
        harness.assert_not_nil(p.achievements.enemy_100, "enemy_100 should be unlocked at 100 kills")
    end)

    harness.it("should trigger combo_5 and combo_10 on combo counts", function()
        local p = persistence.getActiveProfile()

        achievementsMod.check("comboAchieved", {count = 4})
        harness.assert_nil(p.achievements.combo_5)

        achievementsMod.check("comboAchieved", {count = 5})
        harness.assert_not_nil(p.achievements.combo_5)
        harness.assert_nil(p.achievements.combo_10)

        achievementsMod.check("comboAchieved", {count = 10})
        harness.assert_not_nil(p.achievements.combo_10)
    end)

    harness.it("should trigger boss_kill on boss defeat", function()
        local p = persistence.getActiveProfile()
        achievementsMod.check("bossDefeated")
        harness.assert_not_nil(p.achievements.boss_kill)
        harness.assert_equal(1, p.stats.bossesKilled)
    end)

    harness.it("should trigger stage_3 on reaching stage 3", function()
        local p = persistence.getActiveProfile()
        achievementsMod.check("stageChanged", {stage = 2})
        harness.assert_nil(p.achievements.stage_3)

        achievementsMod.check("stageChanged", {stage = 3})
        harness.assert_not_nil(p.achievements.stage_3)
    end)

    harness.it("should trigger score_1000 and score_5000 on score thresholds", function()
        local p = persistence.getActiveProfile()
        achievementsMod.check("scoreReached", {score = 999})
        harness.assert_nil(p.achievements.score_1000)

        achievementsMod.check("scoreReached", {score = 1000})
        harness.assert_not_nil(p.achievements.score_1000)
        harness.assert_nil(p.achievements.score_5000)

        achievementsMod.check("scoreReached", {score = 5000})
        harness.assert_not_nil(p.achievements.score_5000)
    end)

    harness.it("should trigger coins_100 and coins_500 on coins accumulation", function()
        local p = persistence.getActiveProfile()
        achievementsMod.check("coinsChanged", {totalCoins = 99})
        harness.assert_nil(p.achievements.coins_100)

        achievementsMod.check("coinsChanged", {totalCoins = 100})
        harness.assert_not_nil(p.achievements.coins_100)
        harness.assert_nil(p.achievements.coins_500)

        achievementsMod.check("coinsChanged", {totalCoins = 500})
        harness.assert_not_nil(p.achievements.coins_500)
    end)

    harness.it("should enqueue unlocked achievements into pendingAchievements queue", function()
        achievementsMod.check("enemyKilled")
        local pending = world.get("pendingAchievements")
        harness.assert_not_nil(pending)
        harness.assert_equal(1, #pending)
        harness.assert_equal("first_kill", pending[1])
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 7: Player Speed, Passives & Buff Calculations
--------------------------------------------------------------------------------
harness.describe("Systems: Player Speed & Item Effects", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("player.calculateCurrentSpeed should decrease speed every 5 fruits and clamp to VELOCIDAD_MINIMA", function()
        local base = constants.VELOCIDAD_INICIAL -- 0.13

        harness.assert_almost_equal(0.13, playerMod.calculateCurrentSpeed(base, 0), 0.001)
        harness.assert_almost_equal(0.13, playerMod.calculateCurrentSpeed(base, 4), 0.001)
        harness.assert_almost_equal(0.12, playerMod.calculateCurrentSpeed(base, 5), 0.001)
        harness.assert_almost_equal(0.12, playerMod.calculateCurrentSpeed(base, 9), 0.001)
        harness.assert_almost_equal(0.11, playerMod.calculateCurrentSpeed(base, 10), 0.001)
        harness.assert_almost_equal(0.08, playerMod.calculateCurrentSpeed(base, 25), 0.001)
        -- At 50 fruits: 0.13 - 10*0.01 = 0.03 -> clamped to 0.05
        harness.assert_almost_equal(constants.VELOCIDAD_MINIMA, playerMod.calculateCurrentSpeed(base, 50), 0.001)
    end)

    harness.it("player.aplicarItem should handle active and passive item effects", function()
        local st = world.state

        -- shield
        playerMod.aplicarItem("shield")
        harness.assert_true(shop.shieldActive)

        -- armor
        playerMod.aplicarItem("armor")
        harness.assert_equal(2, st.player.armor)

        -- ghost
        playerMod.aplicarItem("ghost")
        harness.assert_true(st.player.ghost)
        harness.assert_equal(1, #st.activeTimers)

        -- magnet
        playerMod.aplicarItem("magnet")
        harness.assert_equal(constants.MAGNET_DURATION, shop.magnetTimer)
        harness.assert_equal(constants.MAGNET_RANGE, st.magnetRange)

        -- hunger
        local prevFruits = st.frutasContador
        local prevScore = st.puntuacion
        playerMod.aplicarItem("hunger")
        harness.assert_equal(prevFruits + 2, st.frutasContador)
        harness.assert_equal(prevScore + 20, st.puntuacion)

        -- speedReducer
        local prevSpeed = st.velocidadActual
        playerMod.aplicarItem("speedReducer")
        harness.assert_almost_equal(prevSpeed - constants.SPEED_REDUCER_AMOUNT, st.velocidadActual, 0.001)

        -- turbo
        playerMod.aplicarItem("turbo")
        harness.assert_lte(st.velocidadActual, prevSpeed)

        -- slow
        playerMod.aplicarItem("slow")
        harness.assert_equal(constants.SLOW_TIMESCALE, st.timeScale)

        -- doubler
        playerMod.aplicarItem("doubler")
        harness.assert_equal(2, st.scoreMultiplier)

        -- star (overrides doubler)
        playerMod.aplicarItem("star")
        harness.assert_equal(3, st.scoreMultiplier)

        -- extraCoin
        playerMod.aplicarItem("extraCoin")
        harness.assert_equal(1, st.coinBonus)
    end)

    harness.it("player.aplicarItem bomb should clear nearby obstacles and kill nearby enemies", function()
        local st = world.state
        st.player.body[1] = {x = 10, y = 10}
        obstaclesMod.pos = {{x = 11, y = 10}, {x = 25, y = 25}}
        enemiesMod.list = {{x = 10, y = 12, alive = true, type = "chaser", coins = 3, px = 200, py = 240, gx = 10, gy = 12}}

        playerMod.aplicarItem("bomb")
        harness.assert_equal(1, #obstaclesMod.pos, "Nearby obstacle should be removed")
        harness.assert_equal(25, obstaclesMod.pos[1].x)
        harness.assert_false(enemiesMod.list[1].alive, "Nearby enemy should be killed")
    end)

    harness.it("player.aplicarComida should handle all special fruit types", function()
        local st = world.state
        st.player.body[1] = {x = 5, y = 5}

        playerMod.aplicarComida("fire_pepper")
        harness.assert_not_nil(st.player.firePepperTimer)

        playerMod.aplicarComida("frost_berry")
        harness.assert_not_nil(st.enemyFreezeTimer)

        playerMod.aplicarComida("constrictor_berry")
        harness.assert_not_nil(st.player.constrictorBuffTimer)

        playerMod.aplicarComida("streak_diamond")
        harness.assert_almost_equal(1.5, st.survivalStreak, 0.001)

        local prevScore = st.puntuacion
        playerMod.aplicarComida("twin")
        harness.assert_gt(st.puntuacion, prevScore)
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 8: Gameflow, Lifecycle & Transitions
--------------------------------------------------------------------------------

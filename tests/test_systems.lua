-- tests/test_systems.lua — Deep Unit Tests for all Systems & Progression modules
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local items = require("systems.items")
local shop = require("systems.shop")
local persistence = require("systems.persistence")
local settings = require("systems.settings")
local settingsDraw = require("systems.settingsDraw")
local profilesMod = require("systems.profiles")
local profilesDraw = require("systems.profilesDraw")
local achievementsMod = require("systems.achievements")
local playerMod = require("systems.player")
local gameflow = require("systems.gameflow")
local gamestates = require("systems.gamestates")
local debugTools = require("systems.debugTools")
local debugLogo = require("systems.debugLogo")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local uiMod = require("ui.ui")

-- Helper to set up clean world state before tests
local function setupCleanWorld()
    love.filesystem.__clearVFS()
    persistence.init()
    persistence.initProfiles()
    world.reset()
    world.stateInit({
        time = 0,
        gameState = constants.GAME_STATE_PLAYING,
        monedas = 100,
        puntuacion = 0,
        highScore = 0,
        highestStreak = 1.0,
        survivalStreak = 1.0,
        baseSpeed = constants.VELOCIDAD_INICIAL,
        velocidadActual = constants.VELOCIDAD_INICIAL,
        anchoGrilla = 32,
        altoGrilla = 18,
        frutasContador = 0,
        lastObstacleScore = 0,
        magnetRange = 0,
        activeTimers = {},
        scoreMultiplier = 1,
        coinBonus = 0,
        timeScale = 1,
        activePS = {},
        menuPS = { update = function() end, emit = function() end, getCount = function() return 0 end },
        shockwaves = {},
        comboCount = 0,
        comboDisplay = 0,
        comboIntensity = 0,
        comboFlashTimer = 0,
        lastEatTime = 0,
        fadeDir = 0,
        fadeAlpha = 0,
        shakeTimer = 0,
        introTimer = 0,
        deathAnimTimer = 0,
        celebrationTimer = 0,
        deathModalOpen = false,
        roomDamaged = false,
        debugImmune = false,
        debugMenuOpen = false,
        debugAchievementsOpen = false,
        debugDungeonOverlay = false,
        debugLogoOpen = false,
        pendingAchievements = {},
        scheduledToasts = {},
        scheduledIndex = {},
        player = snakeMod.reset()
    })
    shop.reset()
    obstaclesMod.init()
    enemiesMod.init()
    worldMod.init()
end

--------------------------------------------------------------------------------
-- SUITE 1: Items System & Registry
--------------------------------------------------------------------------------
harness.describe("Systems: Items Registry & Configuration", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("should contain exactly 12 items in registry", function()
        local count = 0
        for _, _ in pairs(items.registry) do
            count = count + 1
        end
        harness.assert_equal(12, count, "items.registry should have 12 items")
    end)

    harness.it("should have valid schema for each registered item", function()
        local expectedItems = {
            "shield", "armor", "ghost", "magnet", "bomb", "hunger",
            "speedReducer", "turbo", "slow", "doubler", "extraCoin", "star"
        }
        for _, id in ipairs(expectedItems) do
            local def = items.registry[id]
            harness.assert_not_nil(def, "Item " .. id .. " must exist")
            harness.assert_equal(id, def.id, "def.id must match item key")
            harness.assert_type(def.name, "string", "def.name must be a string")
            harness.assert_type(def.desc, "string", "def.desc must be a string")
            harness.assert_type(def.desc2, "string", "def.desc2 must be a string")
            harness.assert_type(def.cost, "number", "def.cost must be a number")
            harness.assert_gt(def.cost, 0, "def.cost must be > 0")
            harness.assert_type(def.icon, "string", "def.icon must be a string")
            harness.assert_type(def.category, "string", "def.category must be a string")
            harness.assert_type(def.type, "string", "def.type must be a string")
            harness.assert_type(def.itemType, "string", "def.itemType must be a string")
            harness.assert_true(def.itemType == "active" or def.itemType == "passive", "def.itemType must be active or passive")
        end
    end)

    harness.it("should categorize 3 items per category across 4 categories", function()
        harness.assert_equal(4, #items.categories, "items.categories must have 4 categories")
        for _, cat in ipairs(items.categories) do
            local catItems = items.getByCategory(cat)
            harness.assert_equal(3, #catItems, "Category " .. cat .. " must have 3 items")
            for _, def in ipairs(catItems) do
                harness.assert_equal(cat, def.category, "Item category must match")
            end
        end
    end)

    harness.it("should build items.pages containing all 12 items", function()
        harness.assert_equal(12, #items.pages, "items.pages must have 12 items")
    end)

    harness.it("player.itemColor should return valid RGB components for all 12 items and fallback", function()
        for id, _ in pairs(items.registry) do
            local r, g, b = playerMod.itemColor(id)
            harness.assert_gte(r, 0, id .. " red >= 0")
            harness.assert_lte(r, 1, id .. " red <= 1")
            harness.assert_gte(g, 0, id .. " green >= 0")
            harness.assert_lte(g, 1, id .. " green <= 1")
            harness.assert_gte(b, 0, id .. " blue >= 0")
            harness.assert_lte(b, 1, id .. " blue <= 1")
        end
        local r, g, b = playerMod.itemColor("non_existent_item")
        harness.assert_equal(1, r, "Fallback red must be 1")
        harness.assert_equal(1, g, "Fallback green must be 1")
        harness.assert_equal(1, b, "Fallback blue must be 1")
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 2: Shop System, Purchasing, Slots & Pagination
--------------------------------------------------------------------------------
harness.describe("Systems: Shop Purchasing & Pagination", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("should reset shop slots, inventory, and timers cleanly", function()
        shop.slots = {"shield", "armor", "ghost"}
        shop.inventory.speedReducer = true
        shop.inventory.extraCoin = true
        shop.magnetTimer = 5
        shop.shieldActive = true

        shop.reset(false)
        harness.assert_nil(shop.slots[1], "Slot 1 must be nil")
        harness.assert_nil(shop.slots[2], "Slot 2 must be nil")
        harness.assert_nil(shop.slots[3], "Slot 3 must be nil")
        harness.assert_false(shop.inventory.speedReducer, "speedReducer must be false")
        harness.assert_false(shop.inventory.extraCoin, "extraCoin must be false")
        harness.assert_equal(0, shop.magnetTimer, "magnetTimer must be 0")
        harness.assert_false(shop.shieldActive, "shieldActive must be false")
    end)

    harness.it("should preserve passive inventory when shop.reset(true) is called", function()
        shop.slots = {"shield", nil, nil}
        shop.inventory.speedReducer = true
        shop.inventory.extraCoin = true

        shop.reset(true)
        harness.assert_nil(shop.slots[1], "Active slot 1 must be cleared")
        harness.assert_true(shop.inventory.speedReducer, "speedReducer should be kept")
        harness.assert_true(shop.inventory.extraCoin, "extraCoin should be kept")
    end)

    harness.it("should reject purchases when funds are insufficient", function()
        local res = shop.procesarCompra(10, "shield", 30)
        harness.assert_nil(res, "Purchase with 10 coins for 30 cost must fail")
    end)

    harness.it("should reject purchases for invalid items", function()
        local res = shop.procesarCompra(100, "nonexistent", 10)
        harness.assert_nil(res, "Purchase of nonexistent item must fail")
    end)

    harness.it("should purchase passive items and mark them in shop.inventory", function()
        local res = shop.procesarCompra(50, "speedReducer", 15)
        harness.assert_not_nil(res, "speedReducer purchase must succeed")
        harness.assert_equal("speedReducer", res.item)
        harness.assert_equal(15, res.costo)
        harness.assert_true(shop.inventory.speedReducer, "speedReducer should be marked owned")
        harness.assert_true(shop.isOwned("speedReducer"), "isOwned should return true for speedReducer")

        -- Second purchase of same passive should fail
        local res2 = shop.procesarCompra(50, "speedReducer", 15)
        harness.assert_nil(res2, "Second purchase of speedReducer must fail")
    end)

    harness.it("should purchase active items into available slots 1, 2, 3", function()
        local res1 = shop.procesarCompra(100, "shield", 30)
        harness.assert_not_nil(res1, "Shield purchase should succeed")
        harness.assert_equal(1, res1.slot, "Shield should go to slot 1")
        harness.assert_equal("shield", shop.slots[1])
        harness.assert_true(shop.isOwned("shield"), "Shield is owned")

        local res2 = shop.procesarCompra(100, "armor", 40)
        harness.assert_not_nil(res2, "Armor purchase should succeed")
        harness.assert_equal(2, res2.slot, "Armor should go to slot 2")
        harness.assert_equal("armor", shop.slots[2])

        local res3 = shop.procesarCompra(100, "ghost", 25)
        harness.assert_not_nil(res3, "Ghost purchase should succeed")
        harness.assert_equal(3, res3.slot, "Ghost should go to slot 3")
        harness.assert_equal("ghost", shop.slots[3])

        -- 4th active item purchase should fail because slots are full
        local res4 = shop.procesarCompra(100, "magnet", 20)
        harness.assert_nil(res4, "4th active item purchase must fail when slots are full")
    end)

    harness.it("should reject duplicate active item purchases", function()
        shop.procesarCompra(100, "shield", 30)
        local dup = shop.procesarCompra(100, "shield", 30)
        harness.assert_nil(dup, "Duplicate shield purchase must fail")
    end)

    harness.it("slotActivate should consume active item and free the slot", function()
        shop.slots[1] = "shield"
        shop.slots[2] = "ghost"

        local activated = shop.slotActivate(1)
        harness.assert_equal("shield", activated, "Activated item must be shield")
        harness.assert_nil(shop.slots[1], "Slot 1 should now be nil")

        local empty = shop.slotActivate(1)
        harness.assert_nil(empty, "Activating empty slot must return nil")

        -- Now slot 1 can be purchased again
        local repurchased = shop.procesarCompra(100, "bomb", 25)
        harness.assert_not_nil(repurchased, "Should be able to buy bomb into newly freed slot 1")
        harness.assert_equal(1, repurchased.slot)
    end)

    harness.it("keypressed should handle navigation and slot purchases", function()
        shop.abrir(100)
        -- Left / Right wrap-around
        local resNavL = shop.keypressed("a", 100)
        harness.assert_nil(resNavL, "Navigation key should return nil")
        local resNavR = shop.keypressed("d", 100)
        harness.assert_nil(resNavR, "Navigation key should return nil")

        -- Continue / Exit
        harness.assert_equal("continue", shop.keypressed("space", 100))
        harness.assert_equal("continue", shop.keypressed("return", 100))
        harness.assert_equal("exit", shop.keypressed("escape", 100))

        -- Number keys 1, 2, 3 purchase item on current page
        local buyRes = shop.keypressed("1", 100)
        harness.assert_not_nil(buyRes, "Key '1' purchase on page 1 should succeed")
    end)

    harness.it("shop.update should decrease purchaseFlash timer", function()
        shop.keypressed("1", 100)
        shop.update(0.1)
        shop.update(0.3)
        harness.assert_true(true)
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 3: Profile Persistence, Serialization & Corruption Handling
--------------------------------------------------------------------------------
harness.describe("Systems: Profile Persistence & Serialization", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("should initialize default profiles state when no file exists", function()
        persistence.initProfiles()
        local profiles = persistence.getProfiles()
        harness.assert_equal(3, #profiles, "Profiles table must have 3 slots")
        harness.assert_nil(profiles[1])
        harness.assert_nil(profiles[2])
        harness.assert_nil(profiles[3])
        harness.assert_nil(persistence.getActiveProfileIndex())
        harness.assert_nil(persistence.getActiveProfile())
    end)

    harness.it("should create profiles up to 3 max limit with complete default schema", function()
        local ok1, err1, idx1 = persistence.createProfile("SnakeMaster")
        harness.assert_true(ok1, "Profile 1 creation should succeed")
        harness.assert_equal(1, idx1, "Profile 1 should be at index 1")
        harness.assert_equal(1, persistence.getActiveProfileIndex(), "Active profile index should be 1")

        local p1 = persistence.getActiveProfile()
        harness.assert_not_nil(p1, "Active profile must not be nil")
        harness.assert_equal("SnakeMaster", p1.name)
        harness.assert_equal(0, p1.monedas)
        harness.assert_equal(0, p1.highScore)
        harness.assert_type(p1.achievements, "table")
        harness.assert_type(p1.unlocks, "table")
        harness.assert_type(p1.stats, "table")

        local ok2, _, idx2 = persistence.createProfile("Viper")
        harness.assert_true(ok2, "Profile 2 creation should succeed")
        harness.assert_equal(2, idx2)

        local ok3, _, idx3 = persistence.createProfile("Cobra")
        harness.assert_true(ok3, "Profile 3 creation should succeed")
        harness.assert_equal(3, idx3)

        -- 4th profile attempt must fail
        local ok4, errMsg, idx4 = persistence.createProfile("Python")
        harness.assert_false(ok4, "4th profile creation must fail")
        harness.assert_not_nil(errMsg, "Error message must be returned")
        harness.assert_nil(idx4)
    end)

    harness.it("should switch active profile and reject invalid index selection", function()
        persistence.createProfile("P1")
        persistence.createProfile("P2")

        local okSel, _, p = persistence.selectProfile(1)
        harness.assert_true(okSel, "Selecting P1 should succeed")
        harness.assert_equal(1, persistence.getActiveProfileIndex())
        harness.assert_equal("P1", p.name)

        local okInv1 = persistence.selectProfile(0)
        harness.assert_false(okInv1, "Selecting slot 0 must fail")

        local okInv3 = persistence.selectProfile(3)
        harness.assert_false(okInv3, "Selecting empty slot 3 must fail")
    end)

    harness.it("should rename profiles cleanly and sanitize whitespace/length", function()
        persistence.createProfile("OldName")
        local ok = persistence.renameProfile(1, "  NewShinyName  ")
        harness.assert_true(ok, "Rename should succeed")
        local p = persistence.getActiveProfile()
        harness.assert_equal("NewShinyName", p.name)

        local okInvalid = persistence.renameProfile(3, "Ghost")
        harness.assert_false(okInvalid, "Renaming non-existent profile must fail")
    end)

    harness.it("should reset profile data while preserving name and createdAt", function()
        persistence.createProfile("Hero")
        local p = persistence.getActiveProfile()
        p.monedas = 500
        p.highScore = 9999
        p.achievements.first_kill = {done = true, at = 123}
        p.stats.kills = 100
        persistence.saveProfiles()

        local okReset = persistence.resetProfile(1)
        harness.assert_true(okReset, "Reset should succeed")
        local pReset = persistence.getActiveProfile()
        harness.assert_equal("Hero", pReset.name, "Name must be preserved")
        harness.assert_equal(0, pReset.monedas, "Monedas must be 0")
        harness.assert_equal(0, pReset.highScore, "HighScore must be 0")
        harness.assert_nil(pReset.achievements.first_kill, "Achievements must be reset")
    end)

    harness.it("should delete profile and fall back activeProfileIndex to another existing profile", function()
        persistence.createProfile("P1")
        persistence.createProfile("P2")
        persistence.selectProfile(1)

        local okDel = persistence.deleteProfile(1)
        harness.assert_true(okDel, "Delete P1 should succeed")
        harness.assert_nil(persistence.getProfiles()[1], "Slot 1 should be nil")
        harness.assert_equal(2, persistence.getActiveProfileIndex(), "Active profile should fall back to P2 (slot 2)")

        -- Delete remaining profile
        persistence.deleteProfile(2)
        harness.assert_nil(persistence.getActiveProfileIndex(), "Active index should be nil when no profiles remain")
    end)

    harness.it("syncActiveProfile should persist coins, high score, and highest streak from world.state", function()
        persistence.createProfile("SyncTester")
        world.set("monedas", 350)
        world.set("highScore", 1250)
        world.set("highestStreak", 2.5)

        local ok = persistence.syncActiveProfile()
        harness.assert_true(ok, "syncActiveProfile should succeed")

        local p = persistence.getActiveProfile()
        harness.assert_equal(350, p.monedas)
        harness.assert_equal(1250, p.highScore)
        harness.assert_equal(2.5, p.stats.highestStreak)
    end)

    harness.it("syncUnlocks should persist passive unlock flags", function()
        persistence.createProfile("UnlocksTester")
        persistence.syncUnlocks({speedReducer = true, extraCoin = true})

        local p = persistence.getActiveProfile()
        harness.assert_true(p.unlocks.speedReducer)
        harness.assert_true(p.unlocks.extraCoin)
    end)

    harness.it("should handle corrupted profile save files gracefully", function()
        love.filesystem.write("config/profiles.dat", "{ invalid lua syntax %%% !!!")
        persistence.initProfiles()
        local profiles = persistence.getProfiles()
        harness.assert_equal(3, #profiles, "Corrupted file must fall back to 3 empty slots")
        harness.assert_nil(persistence.getActiveProfileIndex())
    end)

    harness.it("should handle corrupted settings files gracefully and merge defaults", function()
        love.filesystem.write("config/settings.dat", "corrupted string without return table")
        local loaded = persistence.loadSettings()
        harness.assert_not_nil(loaded.audio, "Loaded settings must have audio defaults")
        harness.assert_equal(1.0, loaded.audio.master)
        harness.assert_true(loaded.audio.music)
        harness.assert_true(loaded.audio.sfx)
    end)

    harness.it("should save and load logo calibration settings", function()
        local cfg = persistence.getLogoConfig()
        harness.assert_not_nil(cfg, "Logo config should exist")
        cfg.offsetX = 42
        cfg.offsetY = -15
        cfg.scale = 8
        persistence.saveLogoConfig(cfg)

        local reloaded = persistence.getLogoConfig()
        harness.assert_equal(42, reloaded.offsetX)
        harness.assert_equal(-15, reloaded.offsetY)
        harness.assert_equal(8, reloaded.scale)
    end)
end)

--------------------------------------------------------------------------------
-- SUITE 4: Settings Management & UI Modals
--------------------------------------------------------------------------------
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

return harness

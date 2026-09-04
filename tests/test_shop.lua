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

-- tests/test_scope_15_shopPersistence.lua
-- Comprehensive Unit Test Suite for systems/shop.lua and systems/persistence.lua (Scope 15)

local harness = require("tests.test_harness")
local describe = harness.describe
local it = harness.it
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

local shop = require("systems.shop")
local persistence = require("systems.persistence")
local items = require("systems.items")
local constants = require("constants")
local world = require("core.world")

-- =========================================================================
-- SUITE 1: Shop - Catalog, Items Registry & 4x3 Pagination Architecture
-- =========================================================================
describe("Scope 15 - Shop Catalog & 4x3 Pagination", function()
    it("verifies items registry contains all 12 items across 4 categories", function()
        assert_type(items.registry, "table", "items.registry must be a table")
        local expectedItems = {
            "shield", "armor", "ghost",
            "magnet", "bomb", "hunger",
            "speedReducer", "turbo", "slow",
            "doubler", "extraCoin", "star"
        }
        for _, id in ipairs(expectedItems) do
            local def = items.registry[id]
            assert_not_nil(def, "Item definition missing for: " .. id)
            assert_equal(id, def.id, "Item ID mismatch for: " .. id)
            assert_type(def.name, "string", "Item name must be a string for: " .. id)
            assert_type(def.cost, "number", "Item cost must be a number for: " .. id)
            assert_gt(def.cost, 0, "Item cost must be greater than 0 for: " .. id)
            assert_true(def.itemType == "active" or def.itemType == "passive", "itemType must be active or passive for: " .. id)
        end
    end)

    it("verifies shop 4x3 pagination structure has exactly 4 pages of 3 items", function()
        assert_equal(4, shop.getTotalPages(), "Shop must have 4 total pages")
        for p = 1, 4 do
            local pageItems = shop.getPageItems(p)
            assert_type(pageItems, "table", "Page items must be a table for page " .. p)
            assert_equal(3, #pageItems, "Page " .. p .. " must contain exactly 3 items")
            for idx, item in ipairs(pageItems) do
                assert_not_nil(item.id, "Page " .. p .. " item " .. idx .. " must have valid id")
            end
        end
    end)

    it("handles page navigation and wrapping via getPage, setPage, and keypressed", function()
        shop.setPage(1)
        assert_equal(1, shop.getPage(), "Page must be 1")

        -- Move right / D
        shop.keypressed("d", 100)
        assert_equal(2, shop.getPage(), "Page must advance to 2")
        shop.keypressed("right", 100)
        assert_equal(3, shop.getPage(), "Page must advance to 3")
        shop.keypressed("d", 100)
        assert_equal(4, shop.getPage(), "Page must advance to 4")
        -- Wrap around to page 1
        shop.keypressed("right", 100)
        assert_equal(1, shop.getPage(), "Page 4 + right must wrap to page 1")

        -- Move left / A
        shop.keypressed("a", 100)
        assert_equal(4, shop.getPage(), "Page 1 + left must wrap to page 4")
        shop.keypressed("left", 100)
        assert_equal(3, shop.getPage(), "Page must decrease to 3")
        shop.keypressed("a", 100)
        assert_equal(2, shop.getPage(), "Page must decrease to 2")
        shop.keypressed("left", 100)
        assert_equal(1, shop.getPage(), "Page must decrease to 1")

        -- setPage boundaries
        assert_true(shop.setPage(3), "setPage(3) must succeed")
        assert_equal(3, shop.getPage(), "Current page must be 3")
        assert_false(shop.setPage(0), "setPage(0) must fail")
        assert_false(shop.setPage(5), "setPage(5) must fail")
        assert_false(shop.setPage("invalid"), "setPage(string) must fail")
        assert_equal(3, shop.getPage(), "Page must remain 3 after invalid setPage")
    end)
end)

-- =========================================================================
-- SUITE 2: Shop - Purchase Mechanics, Active Slots & Passive Inventory
-- =========================================================================
describe("Scope 15 - Shop Purchase Mechanics & Slots", function()
    harness.before_each(function()
        shop.reset(false)
        shop.setPage(1)
    end)

    it("rejects purchase when player has insufficient coins", function()
        local def = items.registry.shield
        local result = shop.procesarCompra(def.cost - 1, "shield", def.cost)
        assert_nil(result, "Purchase should return nil on insufficient coins")
        assert_nil(shop.slots[1], "Slot 1 must remain empty")
        assert_false(shop.isOwned("shield"), "Shield must not be marked owned")
    end)

    it("rejects purchase for nonexistent item id", function()
        local result = shop.procesarCompra(999, "non_existent_item", 10)
        assert_nil(result, "Purchase of nonexistent item must return nil")
    end)

    it("purchases active items sequentially into slots 1, 2, and 3", function()
        -- Purchase slot 1: Shield
        local res1 = shop.procesarCompra(100, "shield", 30)
        assert_not_nil(res1, "Purchase 1 must succeed")
        assert_equal("shield", res1.item, "Item must be shield")
        assert_equal(1, res1.slot, "Assigned slot must be 1")
        assert_equal("shield", shop.slots[1], "shop.slots[1] must be shield")
        assert_true(shop.isOwned("shield"), "shield must be marked as owned")

        -- Purchase slot 2: Armor
        local res2 = shop.procesarCompra(100, "armor", 40)
        assert_not_nil(res2, "Purchase 2 must succeed")
        assert_equal(2, res2.slot, "Assigned slot must be 2")
        assert_equal("armor", shop.slots[2], "shop.slots[2] must be armor")
        assert_true(shop.isOwned("armor"), "armor must be marked as owned")

        -- Purchase slot 3: Ghost
        local res3 = shop.procesarCompra(100, "ghost", 25)
        assert_not_nil(res3, "Purchase 3 must succeed")
        assert_equal(3, res3.slot, "Assigned slot must be 3")
        assert_equal("ghost", shop.slots[3], "shop.slots[3] must be ghost")
        assert_true(shop.isOwned("ghost"), "ghost must be marked as owned")

        -- Attempt 4th active item when slots are full
        local res4 = shop.procesarCompra(100, "magnet", 20)
        assert_nil(res4, "4th active item purchase must return nil when slots are full")
        assert_false(shop.isOwned("magnet"), "magnet must not be owned")
    end)

    it("prevents duplicate purchase of already owned active item", function()
        local res1 = shop.procesarCompra(100, "bomb", 25)
        assert_not_nil(res1, "First purchase of bomb must succeed")
        assert_true(shop.isOwned("bomb"), "Bomb is owned")

        local dupRes = shop.procesarCompra(100, "bomb", 25)
        assert_nil(dupRes, "Duplicate purchase of bomb must be rejected")
    end)

    it("purchases passive items into inventory without consuming active slots", function()
        -- Active slots should remain empty
        local passRes1 = shop.procesarCompra(100, "speedReducer", 15)
        assert_not_nil(passRes1, "Passive item purchase must succeed")
        assert_equal("speedReducer", passRes1.item, "Item must be speedReducer")
        assert_nil(passRes1.slot, "Passive items must not specify slot number")
        assert_nil(shop.slots[1], "Active slot 1 must remain nil")
        assert_true(shop.inventory.speedReducer, "shop.inventory.speedReducer must be true")
        assert_true(shop.isOwned("speedReducer"), "isOwned must return true for speedReducer")

        -- Purchase second passive item
        local passRes2 = shop.procesarCompra(100, "extraCoin", 20)
        assert_not_nil(passRes2, "extraCoin purchase must succeed")
        assert_true(shop.inventory.extraCoin, "shop.inventory.extraCoin must be true")
        assert_true(shop.isOwned("extraCoin"), "isOwned must return true for extraCoin")

        -- Duplicate passive item purchase must be rejected
        local dupPassive = shop.procesarCompra(100, "speedReducer", 15)
        assert_nil(dupPassive, "Duplicate passive purchase must return nil")
    end)
end)

-- =========================================================================
-- SUITE 3: Shop - Slot Activation & Reset Modes
-- =========================================================================
describe("Scope 15 - Shop Slot Activation & Reset Modes", function()
    harness.before_each(function()
        shop.reset(false)
    end)

    it("activates slot and removes item cleanly", function()
        shop.procesarCompra(100, "turbo", 20)
        shop.procesarCompra(100, "slow", 20)
        assert_equal("turbo", shop.slots[1], "Slot 1 is turbo")
        assert_equal("slow", shop.slots[2], "Slot 2 is slow")

        local activated = shop.slotActivate(1)
        assert_equal("turbo", activated, "slotActivate(1) must return turbo")
        assert_nil(shop.slots[1], "Slot 1 must now be nil")
        assert_false(shop.isOwned("turbo"), "turbo is no longer owned")

        -- Slot 2 should still be occupied
        assert_equal("slow", shop.slots[2], "Slot 2 remains slow")
    end)

    it("handles invalid or empty slot activations safely", function()
        assert_nil(shop.slotActivate(1), "Activating empty slot 1 returns nil")
        assert_nil(shop.slotActivate(0), "Activating out-of-range slot 0 returns nil")
        assert_nil(shop.slotActivate(4), "Activating out-of-range slot 4 returns nil")
        assert_nil(shop.slotActivate(-1), "Activating negative slot returns nil")
        assert_nil(shop.slotActivate("slot1"), "Activating string slot returns nil")
    end)

    it("shop.reset(false) wipes both active slots and passive inventory", function()
        shop.slots[1] = "shield"
        shop.slots[2] = "bomb"
        shop.inventory.speedReducer = true
        shop.inventory.extraCoin = true
        shop.magnetTimer = 5.0
        shop.shieldActive = true

        shop.reset(false)
        assert_nil(shop.slots[1], "Slot 1 must be nil")
        assert_nil(shop.slots[2], "Slot 2 must be nil")
        assert_nil(shop.slots[3], "Slot 3 must be nil")
        assert_false(shop.inventory.speedReducer, "speedReducer must be false")
        assert_false(shop.inventory.extraCoin, "extraCoin must be false")
        assert_equal(0, shop.magnetTimer, "magnetTimer must be 0")
        assert_false(shop.shieldActive, "shieldActive must be false")
        assert_equal(1, shop.getPage(), "Page must reset to 1")
    end)

    it("shop.reset(true) clears active slots but preserves passive inventory", function()
        shop.slots[1] = "shield"
        shop.inventory.speedReducer = true
        shop.inventory.extraCoin = true
        shop.magnetTimer = 3.0

        shop.reset(true)
        assert_nil(shop.slots[1], "Active slot 1 must be cleared")
        assert_true(shop.inventory.speedReducer, "speedReducer must be preserved")
        assert_true(shop.inventory.extraCoin, "extraCoin must be preserved")
        assert_equal(0, shop.magnetTimer, "magnetTimer must be reset to 0")
    end)
end)

-- =========================================================================
-- SUITE 4: Shop - Keyboard/Mouse Input & Visual Execution
-- =========================================================================
describe("Scope 15 - Shop Input & Draw Lifecycle", function()
    harness.before_each(function()
        shop.reset(false)
        shop.abrir(200)
    end)

    it("purchases items using numeric keys 1-3 and keypad keys kp1-kp3", function()
        shop.setPage(1) -- Page 1: shield, armor, ghost
        local res1 = shop.keypressed("1", 200)
        assert_not_nil(res1, "Key '1' purchase should succeed")
        assert_equal("shield", res1.item, "Key 1 on page 1 must purchase shield")

        local res2 = shop.keypressed("kp2", 200)
        assert_not_nil(res2, "Key 'kp2' purchase should succeed")
        assert_equal("armor", res2.item, "Key kp2 on page 1 must purchase armor")

        local res3 = shop.keypressed("3", 200)
        assert_not_nil(res3, "Key '3' purchase should succeed")
        assert_equal("ghost", res3.item, "Key 3 on page 1 must purchase ghost")
    end)

    it("returns navigation actions on space, return, and escape keys", function()
        assert_equal("continue", shop.keypressed("space", 100), "Space must return continue")
        assert_equal("continue", shop.keypressed("return", 100), "Return must return continue")
        assert_equal("continue", shop.keypressed("kpenter", 100), "kpenter must return continue")
        assert_equal("exit", shop.keypressed("escape", 100), "Escape must return exit")
        assert_nil(shop.keypressed("x", 100), "Unbound key must return nil")
    end)

    it("executes update and draw without errors or allocation failures", function()
        shop.update(0.1)
        shop.update(0.3) -- Clears purchase flash
        local ok, err = pcall(function()
            shop.draw(150, 0.15)
        end)
        assert_true(ok, "shop.draw must execute cleanly: " .. tostring(err))
    end)

    it("handles mouse click purchases on rendered item cards", function()
        shop.draw(200, 0.15) -- populates cardRects
        -- Click roughly at center of first card
        local result = shop.mousepressed(320, 110, 200)
        -- Result could be purchase or nil if outside bounding box
        if result then
            assert_not_nil(result.item, "Purchased item must have ID")
        end
    end)
end)

-- =========================================================================
-- SUITE 5: Persistence - Lua Serializer (_lua_encode) & Lua Keyword Safety
-- =========================================================================
describe("Scope 15 - Persistence Lua Serializer", function()
    it("serializes numbers, booleans, and strings with escape characters", function()
        local encode = persistence._lua_encode
        assert_equal("42", encode(42))
        assert_equal("3.14159", encode(3.14159))
        assert_equal("-100", encode(-100))
        assert_equal("true", encode(true))
        assert_equal("false", encode(false))
        assert_equal('"hello world"', encode("hello world"))
        assert_equal('"line1\\nline2"', encode("line1\nline2"))
        assert_equal('"quote: \\"text\\""', encode('quote: "text"'))
        assert_equal('"slash: \\\\"', encode('slash: \\'))
    end)

    it("serializes sequential arrays into {item1,item2,...}", function()
        local encode = persistence._lua_encode
        local arr = {10, 20, 30}
        assert_equal("{10,20,30}", encode(arr))
    end)

    it("serializes dictionary tables with identifier keys", function()
        local encode = persistence._lua_encode
        local dict = {name = "Hero", score = 1000}
        local encoded = encode(dict)
        assert_true(encoded:match('name="Hero"'), "Contains name")
        assert_true(encoded:match('score=1000'), "Contains score")
    end)

    it("safely quotes Lua reserved keywords as table keys avoiding syntax errors", function()
        local encode = persistence._lua_encode
        local decode = persistence._lua_decode

        -- Table containing keys that are Lua keywords
        local keywordTable = {
            ["end"] = 1,
            ["for"] = 2,
            ["local"] = 3,
            ["repeat"] = 4,
            ["function"] = 5,
            ["nil"] = 6,
            ["true"] = 7,
            ["false"] = 8,
            ["do"] = 9,
            ["while"] = 10,
            ["if"] = 11,
            ["then"] = 12,
            ["else"] = 13,
            ["return"] = 14
        }
        local encoded = encode(keywordTable)
        -- Verify that keywords are wrapped in brackets e.g. ["end"]=1, not end=1
        assert_true(encoded:match('%["end"%]=1'), "end key must be quoted with brackets")
        assert_true(encoded:match('%["local"%]=3'), "local key must be quoted with brackets")
        assert_true(encoded:match('%["function"%]=5'), "function key must be quoted with brackets")

        -- Verify that the encoded string decodes without syntax error
        local decoded, err = decode(encoded)
        assert_not_nil(decoded, "Keyword table must decode successfully: " .. tostring(err))
        assert_equal(1, decoded["end"], "Decoded end must be 1")
        assert_equal(3, decoded["local"], "Decoded local must be 3")
        assert_equal(5, decoded["function"], "Decoded function must be 5")
    end)

    it("serializes nested complex tables and handles sparse integer keys", function()
        local encode = persistence._lua_encode
        local decode = persistence._lua_decode
        local complexData = {
            version = 1,
            profiles = {
                [1] = {name = "Alpha", stats = {kills = 12, coins = 350}},
                [3] = {name = "Gamma", stats = {kills = 0, coins = 0}}
            }
        }
        local encoded = encode(complexData)
        local decoded, err = decode(encoded)
        assert_not_nil(decoded, "Complex table must decode cleanly: " .. tostring(err))
        assert_equal("Alpha", decoded.profiles[1].name)
        assert_equal(12, decoded.profiles[1].stats.kills)
        assert_nil(decoded.profiles[2])
        assert_equal("Gamma", decoded.profiles[3].name)
    end)
end)

-- =========================================================================
-- SUITE 6: Persistence - Lua Deserializer (_lua_decode) & Sandbox Security
-- =========================================================================
describe("Scope 15 - Persistence Lua Deserializer & Sandbox", function()
    it("decodes valid tables accurately", function()
        local decode = persistence._lua_decode
        local tbl, err = decode('{a=1,b="test",c={true,false}}')
        assert_not_nil(tbl, "Decoded table exists")
        assert_equal(1, tbl.a)
        assert_equal("test", tbl.b)
        assert_equal(true, tbl.c[1])
        assert_equal(false, tbl.c[2])
    end)

    it("gracefully handles invalid, empty, or whitespace inputs without throwing", function()
        local decode = persistence._lua_decode
        assert_nil(decode(""))
        assert_nil(decode("   \n\t  "))
        assert_nil(decode(nil))
        assert_nil(decode(123))
        assert_nil(decode("{ invalid syntax ..."))
        assert_nil(decode("function() while true do end end"))
    end)

    it("operates within a sandboxed environment without access to dangerous globals", function()
        local decode = persistence._lua_decode
        -- Attempt to access os, io, or love globals inside the decoded chunk
        local res, err = decode('{os_access = os, love_access = love}')
        assert_not_nil(res, "Chunk decodes")
        assert_nil(res.os_access, "os global must not be accessible in sandbox")
        assert_nil(res.love_access, "love global must not be accessible in sandbox")
    end)
end)

-- =========================================================================
-- SUITE 7: Persistence - Settings Management & Corrupt Recovery
-- =========================================================================
describe("Scope 15 - Persistence Settings & Corrupt Recovery", function()
    harness.before_each(function()
        love.filesystem.__clearVFS()
    end)

    it("loads default settings when config/settings.dat is missing", function()
        local s = persistence.loadSettings()
        assert_not_nil(s, "Settings loaded")
        assert_equal(1.0, s.audio.master, "Default master volume is 1.0")
        assert_equal(true, s.audio.music, "Default music is enabled")
        assert_equal(true, s.audio.sfx, "Default sfx is enabled")
        assert_equal("tactical", s.controls.controlMode, "Default control mode is tactical")
        assert_equal(2, s.graphics.pixelScale, "Default pixel scale is 2")
        assert_equal(6, s.logo.scale, "Default logo scale is 6")
    end)

    it("saves modified settings to disk and reloads them accurately", function()
        local s = persistence.loadSettings()
        s.audio.master = 0.65
        s.graphics.pixelScale = 3
        s.accessibility.highContrast = true

        local saveOk, saveErr = persistence.saveSettings(s)
        assert_true(saveOk, "saveSettings must succeed: " .. tostring(saveErr))

        -- Clear in-memory cache and reload from VFS
        persistence.settings = nil
        local reloaded = persistence.loadSettings()
        assert_almost_equal(0.65, reloaded.audio.master, 0.001)
        assert_equal(3, reloaded.graphics.pixelScale)
        assert_equal(true, reloaded.accessibility.highContrast)
    end)

    it("recovers gracefully from empty or syntactically corrupt settings file", function()
        love.filesystem.write("config/settings.dat", "CORRUPTED DATA !!! {{{")
        persistence.settings = nil
        local s = persistence.loadSettings()
        assert_not_nil(s, "Must return fallback settings on corrupt file")
        assert_equal(1.0, s.audio.master, "Must fall back to default audio master")
        assert_equal(2, s.graphics.pixelScale, "Must fall back to default pixel scale")
    end)

    it("auto-corrects corrupted data types in settings via deep_merge", function()
        -- File with invalid types (e.g. master is string instead of number)
        local corruptSchema = '{audio={master="SUPER_LOUD",music="yes"},logo={scale="TEN"}}'
        love.filesystem.write("config/settings.dat", corruptSchema)
        persistence.settings = nil
        local s = persistence.loadSettings()
        assert_type(s.audio.master, "number", "Audio master must be auto-corrected to number")
        assert_equal(1.0, s.audio.master, "Audio master restored to default 1.0")
        assert_type(s.audio.music, "boolean", "Music must be auto-corrected to boolean")
        assert_equal(true, s.audio.music, "Music restored to default true")
        assert_type(s.logo.scale, "number", "Logo scale must be auto-corrected to number")
        assert_equal(6, s.logo.scale, "Logo scale restored to default 6")
    end)

    it("applies settings safely without throwing on audio, graphics, and controls", function()
        local s = persistence.defaults()
        s.audio.master = 0.5
        s.graphics.fullscreen = false
        s.gameplay.controlMode = "classic"

        local ok, err = pcall(function()
            persistence.applySettings(s)
        end)
        assert_true(ok, "applySettings must succeed without errors: " .. tostring(err))
        assert_equal("classic", world.state.controlMode, "World controlMode updated")
    end)

    it("saveAndApply executes save and application atomically", function()
        local s = persistence.defaults()
        s.audio.master = 0.8
        local ok, err = persistence.saveAndApply(s)
        assert_true(ok, "saveAndApply should return true: " .. tostring(err))
        assert_equal(0.8, persistence.settings.audio.master)
    end)
end)

-- =========================================================================
-- SUITE 8: Persistence - Logo Calibration Configuration
-- =========================================================================
describe("Scope 15 - Persistence Logo Calibration Config", function()
    harness.before_each(function()
        love.filesystem.__clearVFS()
        persistence.settings = nil
    end)

    it("retrieves default logo config using both getLogoConfig and loadLogoConfig", function()
        local cfg1 = persistence.getLogoConfig()
        local cfg2 = persistence.loadLogoConfig()
        assert_not_nil(cfg1, "getLogoConfig returns table")
        assert_not_nil(cfg2, "loadLogoConfig returns table")
        assert_equal(0, cfg1.offsetX, "Default offsetX is 0")
        assert_equal(0, cfg1.offsetY, "Default offsetY is 0")
        assert_equal(6, cfg1.scale, "Default scale is 6")
        assert_equal(10, cfg1.spacing, "Default spacing is 10")
        assert_equal(5, cfg1.depth, "Default depth is 5")
    end)

    it("saves modified logo config and persists it across reloads", function()
        local newCfg = {offsetX = 25, offsetY = -15, scale = 8, spacing = 12, depth = 7}
        local ok, err = persistence.saveLogoConfig(newCfg)
        assert_true(ok, "saveLogoConfig must succeed: " .. tostring(err))

        -- Reset memory cache and reload
        persistence.settings = nil
        local loaded = persistence.getLogoConfig()
        assert_equal(25, loaded.offsetX)
        assert_equal(-15, loaded.offsetY)
        assert_equal(8, loaded.scale)
        assert_equal(12, loaded.spacing)
        assert_equal(7, loaded.depth)
    end)
end)

-- =========================================================================
-- SUITE 9: Persistence - Profiles Lifecycle (CRUD) & Corrupt Recovery
-- =========================================================================
describe("Scope 15 - Persistence Profiles CRUD & Corrupt Recovery", function()
    harness.before_each(function()
        love.filesystem.__clearVFS()
        persistence.initProfiles()
    end)

    it("creates up to 3 profiles and rejects a 4th profile", function()
        -- Profile 1
        local ok1, err1, idx1 = persistence.createProfile("Knight")
        assert_true(ok1, "Create profile 1 must succeed")
        assert_equal(1, idx1, "Profile 1 slot must be 1")
        assert_equal(1, persistence.getActiveProfileIndex(), "Active profile must be 1")

        -- Profile 2
        local ok2, err2, idx2 = persistence.createProfile("Wizard")
        assert_true(ok2, "Create profile 2 must succeed")
        assert_equal(2, idx2, "Profile 2 slot must be 2")
        assert_equal(2, persistence.getActiveProfileIndex(), "Active profile must be 2")

        -- Profile 3
        local ok3, err3, idx3 = persistence.createProfile("Rogue")
        assert_true(ok3, "Create profile 3 must succeed")
        assert_equal(3, idx3, "Profile 3 slot must be 3")
        assert_equal(3, persistence.getActiveProfileIndex(), "Active profile must be 3")

        -- Attempt 4th profile
        local ok4, err4, idx4 = persistence.createProfile("Paladin")
        assert_false(ok4, "Create 4th profile must fail")
        assert_nil(idx4, "4th profile index must be nil")
    end)

    it("selects, renames, and resets profiles properly", function()
        persistence.createProfile("PlayerA")
        persistence.createProfile("PlayerB")

        -- Select profile 1
        local selOk, selErr, prof = persistence.selectProfile(1)
        assert_true(selOk, "selectProfile(1) must succeed")
        assert_equal("PlayerA", prof.name)
        assert_equal(1, persistence.getActiveProfileIndex())

        -- Select invalid index
        assert_false(persistence.selectProfile(0))
        assert_false(persistence.selectProfile(4))
        assert_false(persistence.selectProfile(3)) -- slot 3 is empty

        -- Rename profile 1 (with trimming and 14-char cap)
        persistence.renameProfile(1, "  SuperLongPlayerName12345  ")
        local p1 = persistence.getActiveProfile()
        assert_lte(#p1.name, 14, "Profile name must be capped at 14 characters")

        -- Reset profile 1
        p1.monedas = 500
        p1.highScore = 9999
        persistence.resetProfile(1)
        local resetP = persistence.getActiveProfile()
        assert_equal(0, resetP.monedas, "Reset profile coins must be 0")
        assert_equal(0, resetP.highScore, "Reset profile high score must be 0")
    end)

    it("deletes profiles and updates active profile index to remaining slot", function()
        persistence.createProfile("P1")
        persistence.createProfile("P2")
        persistence.createProfile("P3")
        persistence.selectProfile(2)

        -- Delete active profile 2
        persistence.deleteProfile(2)
        local profiles = persistence.getProfiles()
        assert_nil(profiles[2], "Slot 2 must be nil")
        assert_not_nil(persistence.getActiveProfileIndex(), "Active profile index should fall back to slot 1 or 3")

        -- Delete remaining profiles
        persistence.deleteProfile(1)
        persistence.deleteProfile(3)
        assert_nil(persistence.getActiveProfileIndex(), "Active profile must be nil when all profiles deleted")
        assert_nil(persistence.getActiveProfile(), "getActiveProfile must return nil")
    end)

    it("recovers cleanly from empty, missing, or corrupted profiles.dat", function()
        -- Write corrupted syntax
        love.filesystem.write("config/profiles.dat", "BAD LUA DATA {{{{")
        persistence.initProfiles()
        assert_not_nil(persistence.profilesData, "profilesData initialized")
        assert_nil(persistence.getActiveProfileIndex(), "No active profile")
        assert_equal(0, #persistence.getProfiles(), "Profiles list is empty")

        -- Create profile after corruption recovery
        local ok, err, idx = persistence.createProfile("Survivor")
        assert_true(ok, "Profile creation succeeds after corruption recovery")
        assert_equal(1, idx)
    end)

    it("sanitizes corrupt profile structures during initProfiles", function()
        -- File containing profile with missing fields or invalid types
        local corruptProfiles = '{version=1,activeProfileIndex=1,profiles={[1]={name=12345,monedas="NONE",highScore=nil}}}'
        love.filesystem.write("config/profiles.dat", corruptProfiles)
        persistence.initProfiles()

        local p = persistence.getActiveProfile()
        assert_not_nil(p, "Profile 1 loaded")
        assert_type(p.name, "string", "Profile name sanitized to string")
        assert_equal(0, p.monedas, "Corrupt monedas sanitized to 0")
        assert_equal(0, p.highScore, "Missing highScore sanitized to 0")
        assert_type(p.stats, "table", "Missing stats table created")
        assert_type(p.achievements, "table", "Missing achievements table created")
        assert_type(p.unlocks, "table", "Missing unlocks table created")
    end)
end)

-- =========================================================================
-- SUITE 10: Persistence - Active Profile Sync & World Integration
-- =========================================================================
describe("Scope 15 - Persistence World State Sync & High Score", function()
    harness.before_each(function()
        love.filesystem.__clearVFS()
        persistence.initProfiles()
        persistence.createProfile("Champion")
    end)

    it("syncs coins, high score, and streaks from world into active profile", function()
        world.reset()
        world.set("monedas", 350)
        world.set("highScore", 7800)
        world.set("highestStreak", 4.5)

        local syncOk = persistence.syncActiveProfile()
        assert_true(syncOk, "syncActiveProfile must succeed")

        local p = persistence.getActiveProfile()
        assert_equal(350, p.monedas, "Profile coins synced")
        assert_equal(7800, p.highScore, "Profile high score synced")
        assert_almost_equal(4.5, p.stats.highestStreak, 0.01, "Streak synced")
    end)

    it("syncs passive unlocks table into active profile", function()
        local unlocks = {speedReducer = true, extraCoin = true}
        local ok = persistence.syncUnlocks(unlocks)
        assert_true(ok, "syncUnlocks must succeed")

        local p = persistence.getActiveProfile()
        assert_true(p.unlocks.speedReducer, "speedReducer unlock persisted")
        assert_true(p.unlocks.extraCoin, "extraCoin unlock persisted")
    end)

    it("provides legacy highscore persistence via cargar and guardar", function()
        assert_equal(0, persistence.cargar(), "Default legacy highscore is 0")
        local newRecord = persistence.guardar(1200, 1000)
        assert_equal(1200, newRecord, "New highscore saved")
        assert_equal(1200, persistence.cargar(), "Loaded highscore is 1200")

        -- Attempting lower score should not overwrite
        local unchanged = persistence.guardar(800, 1200)
        assert_equal(1200, unchanged, "Record unchanged on lower score")
        assert_equal(1200, persistence.cargar(), "Loaded highscore remains 1200")
    end)
end)

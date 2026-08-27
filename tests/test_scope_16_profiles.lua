-- tests/test_scope_16_profiles.lua
-- Comprehensive unit tests for systems/profiles.lua and systems/profilesDraw.lua

local harness = require("tests.test_harness")
local persistence = require("systems.persistence")
local gameflow = require("systems.gameflow")
local world = require("core.world")
local shop = require("systems.shop")
local items = require("systems.items")
local profilesMod = require("systems.profiles")
local profilesDraw = require("systems.profilesDraw")
local achievementsMod = require("systems.achievements")

-- Helper to reset persistence environment
local function reset_test_env()
    love.filesystem.__clearVFS()
    persistence.profilesData = {
        version = 1,
        activeProfileIndex = nil,
        profiles = {}
    }
    persistence.settings = nil
    world.state.monedas = 0
    world.state.highScore = 0
    world.state.highestStreak = 1.0
    shop.reset()
    profilesMod.close()
end

-- ============================================================
-- SUITE 1: Profile CRUD and Max 3 Limit
-- ============================================================
harness.describe("Profiles: CRUD & Max 3 Limit", function()
    harness.before_each(function()
        reset_test_env()
    end)

    harness.it("creates profiles up to 3 slots and tracks activeProfileIndex", function()
        harness.assert_nil(persistence.getActiveProfileIndex(), "Initially no active profile")
        harness.assert_nil(persistence.getActiveProfile(), "Initially getActiveProfile returns nil")

        local ok1, err1, slot1 = persistence.createProfile("Alice")
        harness.assert_true(ok1, "Slot 1 creation succeeded")
        harness.assert_nil(err1, "No error on slot 1")
        harness.assert_equal(1, slot1, "Returned slot index 1")
        harness.assert_equal(1, persistence.getActiveProfileIndex(), "Active profile index is 1")
        harness.assert_equal("Alice", persistence.getActiveProfile().name, "Active profile name is Alice")

        local ok2, err2, slot2 = persistence.createProfile("Bob")
        harness.assert_true(ok2, "Slot 2 creation succeeded")
        harness.assert_equal(2, slot2, "Returned slot index 2")
        harness.assert_equal(2, persistence.getActiveProfileIndex(), "Active profile becomes 2")

        local ok3, err3, slot3 = persistence.createProfile("Charlie")
        harness.assert_true(ok3, "Slot 3 creation succeeded")
        harness.assert_equal(3, slot3, "Returned slot index 3")
        harness.assert_equal(3, persistence.getActiveProfileIndex(), "Active profile becomes 3")

        local ok4, err4, slot4 = persistence.createProfile("Dave")
        harness.assert_false(ok4, "4th profile creation rejected")
        harness.assert_equal("Máximo 3 perfiles alcanzado", err4, "Error message matches max 3")
        harness.assert_nil(slot4, "Slot index is nil on failure")
    end)

    harness.it("initializes profile structure and default stats correctly", function()
        persistence.createProfile("Hero")
        local profile = persistence.getActiveProfile()
        harness.assert_not_nil(profile, "Profile exists")
        harness.assert_equal("Hero", profile.name, "Name is Hero")
        harness.assert_equal(0, profile.monedas, "Default monedas is 0")
        harness.assert_equal(0, profile.highScore, "Default highScore is 0")
        harness.assert_type(profile.createdAt, "number", "createdAt is timestamp")
        harness.assert_type(profile.achievements, "table", "achievements is table")
        harness.assert_type(profile.unlocks, "table", "unlocks is table")
        harness.assert_type(profile.stats, "table", "stats is table")

        harness.assert_equal(0, profile.stats.kills, "stats.kills defaults to 0")
        harness.assert_equal(0, profile.stats.bossesKilled, "stats.bossesKilled defaults to 0")
        harness.assert_equal(1, profile.stats.highestStage, "stats.highestStage defaults to 1")
        harness.assert_equal(0, profile.stats.highestScore, "stats.highestScore defaults to 0")
        harness.assert_equal(0, profile.stats.totalCoins, "stats.totalCoins defaults to 0")
        harness.assert_almost_equal(1.0, profile.stats.highestStreak, 0.001, "stats.highestStreak defaults to 1.0")
    end)

    harness.it("handles empty or whitespace name with fallback", function()
        persistence.createProfile("")
        local p1 = persistence.getProfiles()[1]
        harness.assert_equal("Jugador 1", p1.name, "Fallback to Jugador 1 for empty string")

        persistence.createProfile("   ")
        local p2 = persistence.getProfiles()[2]
        harness.assert_equal("Jugador 2", p2.name, "Fallback to Jugador 2 for spaces")

        persistence.createProfile(nil)
        local p3 = persistence.getProfiles()[3]
        harness.assert_equal("Jugador 3", p3.name, "Fallback to Jugador 3 for nil")
    end)

    harness.it("clamps long profile names to MAX_NAME_LENGTH (14 chars)", function()
        local longName = "SuperUltraMegaSlayer99"
        persistence.createProfile(longName)
        local profile = persistence.getActiveProfile()
        harness.assert_equal(14, #profile.name, "Clamped to 14 chars")
        harness.assert_equal("SuperUltraMega", profile.name, "Matches prefix of length 14")
    end)

    harness.it("selects profiles and rejects invalid indices", function()
        persistence.createProfile("P1")
        persistence.createProfile("P2")

        local okSel, _, prof = persistence.selectProfile(1)
        harness.assert_true(okSel, "Selecting slot 1 succeeded")
        harness.assert_equal(1, persistence.getActiveProfileIndex(), "Active is 1")
        harness.assert_equal("P1", prof.name, "Selected profile is P1")

        local okInv1, errInv1 = persistence.selectProfile(0)
        harness.assert_false(okInv1, "Index 0 rejected")
        harness.assert_equal("Índice inválido", errInv1, "Error is Índice inválido")

        local okInv4, errInv4 = persistence.selectProfile(4)
        harness.assert_false(okInv4, "Index 4 rejected")
        harness.assert_equal("Índice inválido", errInv4, "Error is Índice inválido")

        local okEmpty, errEmpty = persistence.selectProfile(3)
        harness.assert_false(okEmpty, "Empty slot 3 rejected")
        harness.assert_equal("Perfil vacío", errEmpty, "Error is Perfil vacío")
    end)

    harness.it("renames existing profile and clamps new name", function()
        persistence.createProfile("OldName")
        local okRename = persistence.renameProfile(1, "NewName")
        harness.assert_true(okRename, "Rename succeeded")
        harness.assert_equal("NewName", persistence.getActiveProfile().name, "Name updated")

        persistence.renameProfile(1, "VeryLongPlayerNameExceeding14")
        harness.assert_equal(14, #persistence.getActiveProfile().name, "Clamped renamed name to 14 chars")
        harness.assert_equal("VeryLongPlayer", persistence.getActiveProfile().name)

        local okRenameInv = persistence.renameProfile(3, "EmptySlot")
        harness.assert_false(okRenameInv, "Renaming non-existent profile rejected")
    end)

    harness.it("resets profile progress while preserving profile name", function()
        persistence.createProfile("Slayer")
        local p = persistence.getActiveProfile()
        p.monedas = 250
        p.highScore = 1500
        p.achievements = { first_kill = { done = true, at = os.time() } }
        p.unlocks = { ghostPotion = true }
        p.stats.kills = 50

        local okReset = persistence.resetProfile(1)
        harness.assert_true(okReset, "Reset succeeded")

        local resP = persistence.getActiveProfile()
        harness.assert_equal("Slayer", resP.name, "Name is preserved")
        harness.assert_equal(0, resP.monedas, "Monedas reset to 0")
        harness.assert_equal(0, resP.highScore, "HighScore reset to 0")
        harness.assert_equal(0, resP.stats.kills, "Stats kills reset to 0")
        harness.assert_equal(0, #persistence.getProfiles()[1].unlocks, "Unlocks reset")
    end)
end)

-- ============================================================
-- SUITE 2: Deletion & Edge Cases (Deleting Last Profile)
-- ============================================================
harness.describe("Profiles: Deletion & Deleting Last Profile", function()
    harness.before_each(function()
        reset_test_env()
    end)

    harness.it("deletes middle slot and allows re-creation in that slot", function()
        persistence.createProfile("P1")
        persistence.createProfile("P2")
        persistence.createProfile("P3")

        local okDel = persistence.deleteProfile(2)
        harness.assert_true(okDel, "Delete slot 2 succeeded")
        harness.assert_nil(persistence.getProfiles()[2], "Slot 2 is now nil")
        harness.assert_not_nil(persistence.getProfiles()[1], "Slot 1 remains")
        harness.assert_not_nil(persistence.getProfiles()[3], "Slot 3 remains")

        -- New profile should fill the freed slot 2
        local okCreate, _, slot = persistence.createProfile("NewP2")
        harness.assert_true(okCreate, "Created profile in slot 2")
        harness.assert_equal(2, slot, "Assigned to slot 2")
        harness.assert_equal("NewP2", persistence.getProfiles()[2].name)
    end)

    harness.it("shifts activeProfileIndex when active profile is deleted", function()
        persistence.createProfile("P1")
        persistence.createProfile("P2")
        persistence.selectProfile(1)
        harness.assert_equal(1, persistence.getActiveProfileIndex())

        persistence.deleteProfile(1)
        harness.assert_equal(2, persistence.getActiveProfileIndex(), "Active shifted to remaining profile slot 2")
        harness.assert_equal("P2", persistence.getActiveProfile().name)
    end)

    harness.it("clears activeProfileIndex when deleting the last remaining profile", function()
        persistence.createProfile("SoleProfile")
        harness.assert_equal(1, persistence.getActiveProfileIndex())

        local okDel = persistence.deleteProfile(1)
        harness.assert_true(okDel, "Delete succeeded")
        harness.assert_nil(persistence.getActiveProfileIndex(), "activeProfileIndex is nil")
        harness.assert_nil(persistence.getActiveProfile(), "getActiveProfile() returns nil")
    end)

    harness.it("gameflow.applyActiveProfile cleanly resets world state when no profile is active", function()
        persistence.createProfile("RichProfile")
        local p = persistence.getActiveProfile()
        p.monedas = 999
        p.highScore = 8888
        p.stats.highestStreak = 3.5
        p.unlocks = { speedReducer = true }

        gameflow.applyActiveProfile()
        harness.assert_equal(999, world.state.monedas, "Monedas applied")
        harness.assert_equal(8888, world.state.highScore, "HighScore applied")
        harness.assert_almost_equal(3.5, world.state.highestStreak, 0.001, "Streak applied")
        harness.assert_true(shop.inventory.speedReducer == true, "Shop unlock applied")

        -- Delete the only profile
        persistence.deleteProfile(1)
        gameflow.applyActiveProfile()

        harness.assert_equal(0, world.state.monedas, "Monedas reset to 0")
        harness.assert_almost_equal(1.0, world.state.highestStreak, 0.001, "Highest streak reset to 1.0")
        harness.assert_nil(shop.inventory.speedReducer, "Shop inventory cleared")
    end)

    harness.it("prevents cross-profile shop inventory leakage on profile switch", function()
        persistence.createProfile("ProfileA")
        local pa = persistence.getActiveProfile()
        pa.unlocks = { extraCoin = true }

        persistence.createProfile("ProfileB")
        local pb = persistence.getActiveProfile()
        pb.unlocks = {}

        -- Switch to ProfileA
        persistence.selectProfile(1)
        gameflow.applyActiveProfile()
        harness.assert_true(shop.inventory.extraCoin == true, "ProfileA has extraCoin")

        -- Switch to ProfileB
        persistence.selectProfile(2)
        gameflow.applyActiveProfile()
        harness.assert_nil(shop.inventory.extraCoin, "ProfileB does NOT inherit ProfileA extraCoin")
    end)
end)

-- ============================================================
-- SUITE 3: Persistence & Serialization
-- ============================================================
harness.describe("Profiles: Persistence & Serialization", function()
    harness.before_each(function()
        reset_test_env()
    end)

    harness.it("saves and reloads profiles from filesystem correctly", function()
        persistence.createProfile("PersistentPlayer")
        local p = persistence.getActiveProfile()
        p.monedas = 77
        p.highScore = 540
        p.stats.kills = 12
        p.stats.bossesKilled = 1
        p.achievements = { first_kill = { done = true, at = 12345 } }
        p.unlocks = { ghostPotion = true }
        persistence.saveProfiles()

        -- Re-initialize profiles from storage
        persistence.initProfiles()
        harness.assert_equal(1, persistence.getActiveProfileIndex(), "Active profile index preserved")
        local loaded = persistence.getActiveProfile()
        harness.assert_not_nil(loaded, "Profile loaded successfully")
        harness.assert_equal("PersistentPlayer", loaded.name, "Name matches")
        harness.assert_equal(77, loaded.monedas, "Monedas match")
        harness.assert_equal(540, loaded.highScore, "HighScore matches")
        harness.assert_equal(12, loaded.stats.kills, "Stats kills match")
        harness.assert_equal(1, loaded.stats.bossesKilled, "Stats bossesKilled match")
        harness.assert_true(loaded.achievements.first_kill.done, "Achievement preserved")
        harness.assert_true(loaded.unlocks.ghostPotion, "Unlock preserved")
    end)

    harness.it("preserves sparse profile slots (slot 2 only) after reload without wiping", function()
        persistence.createProfile("Slot1")
        persistence.createProfile("Slot2")
        persistence.deleteProfile(1)

        -- Now only slot 2 exists
        harness.assert_nil(persistence.getProfiles()[1], "Slot 1 is nil")
        harness.assert_not_nil(persistence.getProfiles()[2], "Slot 2 exists")
        harness.assert_equal("Slot2", persistence.getProfiles()[2].name)
        persistence.saveProfiles()

        -- Reload from disk
        persistence.initProfiles()
        local proms = persistence.getProfiles()
        harness.assert_nil(proms[1], "Slot 1 remains nil")
        harness.assert_not_nil(proms[2], "Slot 2 was NOT wiped out by reload")
        harness.assert_equal("Slot2", proms[2].name, "Slot 2 data intact")
        harness.assert_equal(2, persistence.getActiveProfileIndex(), "Active is slot 2")
    end)

    harness.it("syncActiveProfile updates world metrics to active profile", function()
        persistence.createProfile("SyncPlayer")
        world.state.monedas = 150
        world.state.highScore = 3200
        world.state.highestStreak = 2.4

        persistence.syncActiveProfile()
        local p = persistence.getActiveProfile()
        harness.assert_equal(150, p.monedas, "Monedas synced")
        harness.assert_equal(3200, p.highScore, "HighScore synced")
        harness.assert_almost_equal(2.4, p.stats.highestStreak, 0.001, "Highest streak synced")
        harness.assert_equal(3200, p.stats.highestScore, "Stats highestScore synced")
        harness.assert_equal(150, p.stats.totalCoins, "Stats totalCoins synced")
    end)

    harness.it("syncUnlocks writes unlock table to active profile", function()
        persistence.createProfile("UnlockPlayer")
        local unlocks = { speedReducer = true, extraCoin = true }
        persistence.syncUnlocks(unlocks)

        local p = persistence.getActiveProfile()
        harness.assert_true(p.unlocks.speedReducer, "speedReducer synced")
        harness.assert_true(p.unlocks.extraCoin, "extraCoin synced")
    end)
end)

-- ============================================================
-- SUITE 4: UI Controller, Modals & State Machine (profiles.lua)
-- ============================================================
harness.describe("Profiles: UI Controller & Modals", function()
    harness.before_each(function()
        reset_test_env()
    end)

    harness.it("open() and close() manage visibility and reset fields", function()
        profilesMod.open()
        harness.assert_true(profilesMod.visible, "Visible after open()")
        harness.assert_equal("select", profilesMod.state, "State is select")
        harness.assert_equal("", profilesMod.nameInput, "nameInput is empty")

        profilesMod.state = "input"
        profilesMod.nameInput = "Temp"
        profilesMod.close()
        harness.assert_false(profilesMod.visible, "Hidden after close()")
        harness.assert_equal("select", profilesMod.state, "State reset to select")
        harness.assert_equal("", profilesMod.nameInput, "nameInput cleared")
    end)

    harness.it("handles mouse click on create button and opens input modal", function()
        profilesMod.open()
        profilesMod.buttonRects = {
            { x = 100, y = 100, w = 80, h = 30, action = "create", index = 1 }
        }

        profilesMod.mousepressed(120, 110, 1)
        harness.assert_equal("input", profilesMod.state, "State changed to input")
        harness.assert_equal("create", profilesMod.confirmType, "confirmType is create")
        harness.assert_equal(1, profilesMod.inputIndex, "inputIndex is 1")
        harness.assert_true(profilesMod.textInputActive, "textInputActive is true")
    end)

    harness.it("handles text input confirmation for profile creation", function()
        profilesMod.open()
        profilesMod.state = "input"
        profilesMod.confirmType = "create"
        profilesMod.inputIndex = 1
        profilesMod.nameInput = "CyberSnake"
        profilesMod.textInputActive = true

        profilesMod.handleInputConfirm()
        harness.assert_equal("select", profilesMod.state, "Returns to select state")
        harness.assert_false(profilesMod.textInputActive, "textInput deactivated")
        harness.assert_equal("", profilesMod.nameInput, "nameInput cleared")

        local p = persistence.getProfiles()[1]
        harness.assert_not_nil(p, "Profile 1 created")
        harness.assert_equal("CyberSnake", p.name, "Name matches")
    end)

    harness.it("handles rename flow via modal and input confirm", function()
        persistence.createProfile("Original")
        profilesMod.open()
        profilesMod.buttonRects = {
            { x = 100, y = 100, w = 80, h = 30, action = "rename", index = 1 }
        }

        profilesMod.mousepressed(120, 110, 1)
        harness.assert_equal("input", profilesMod.state, "State is input")
        harness.assert_equal("rename", profilesMod.confirmType, "confirmType is rename")
        harness.assert_equal("Original", profilesMod.nameInput, "nameInput preloaded with existing name")

        profilesMod.nameInput = "Renamed"
        profilesMod.handleInputConfirm()
        harness.assert_equal("Renamed", persistence.getActiveProfile().name, "Profile renamed")
    end)

    harness.it("handles delete confirmation modal flow", function()
        persistence.createProfile("ToBeDeleted")
        profilesMod.open()
        profilesMod.buttonRects = {
            { x = 100, y = 100, w = 80, h = 30, action = "delete", index = 1 }
        }

        profilesMod.mousepressed(120, 110, 1)
        harness.assert_equal("confirm", profilesMod.state, "State is confirm")
        harness.assert_equal("delete", profilesMod.confirmType, "confirmType is delete")
        harness.assert_equal(1, profilesMod.confirmIndex, "confirmIndex is 1")

        -- Click Confirm Yes
        profilesMod.buttonRects = {
            { x = 100, y = 150, w = 80, h = 30, action = "confirm_yes" }
        }
        profilesMod.mousepressed(110, 160, 1)
        harness.assert_equal("select", profilesMod.state, "Returns to select")
        harness.assert_nil(persistence.getProfiles()[1], "Profile 1 deleted")
    end)

    harness.it("handles cancel in delete confirmation modal", function()
        persistence.createProfile("KeepMe")
        profilesMod.open()
        profilesMod.state = "confirm"
        profilesMod.confirmType = "delete"
        profilesMod.confirmIndex = 1

        profilesMod.buttonRects = {
            { x = 200, y = 150, w = 80, h = 30, action = "confirm_no" }
        }
        profilesMod.mousepressed(210, 160, 1)
        harness.assert_equal("select", profilesMod.state, "State reset to select")
        harness.assert_nil(profilesMod.confirmType, "confirmType cleared")
        harness.assert_not_nil(persistence.getProfiles()[1], "Profile preserved")
    end)

    harness.it("handles achievements modal view and closing", function()
        persistence.createProfile("Achiever")
        profilesMod.open()
        profilesMod.buttonRects = {
            { x = 50, y = 50, w = 70, h = 20, action = "achievements", index = 1 }
        }

        profilesMod.mousepressed(60, 60, 1)
        harness.assert_equal("achievements", profilesMod.state, "State is achievements")
        harness.assert_equal(1, profilesMod.confirmIndex, "Target profile is index 1")

        profilesMod.buttonRects = {
            { x = 100, y = 200, w = 100, h = 30, action = "close_achievements" }
        }
        profilesMod.mousepressed(110, 210, 1)
        harness.assert_equal("select", profilesMod.state, "Closed achievements modal back to select")
    end)

    harness.it("handles back button to close profilesMod", function()
        profilesMod.open()
        profilesMod.backBtn = { x = 300, y = 400, w = 140, h = 30 }
        profilesMod.mousepressed(320, 410, 1)
        harness.assert_false(profilesMod.visible, "Profiles closed via backBtn")
    end)
end)

-- ============================================================
-- SUITE 5: Text Input & Keyboard Shortcuts
-- ============================================================
harness.describe("Profiles: Text Input & Keyboard Shortcuts", function()
    harness.before_each(function()
        reset_test_env()
    end)

    harness.it("textinput appends text up to MAX_NAME_LENGTH", function()
        profilesMod.open()
        profilesMod.state = "input"
        profilesMod.textInputActive = true
        profilesMod.nameInput = ""

        profilesMod.textinput("A")
        profilesMod.textinput("B")
        profilesMod.textinput("C")
        harness.assert_equal("ABC", profilesMod.nameInput)

        -- Try to exceed 14 characters
        profilesMod.nameInput = "12345678901234"
        profilesMod.textinput("X")
        harness.assert_equal("12345678901234", profilesMod.nameInput, "Did not append beyond 14 chars")
    end)

    harness.it("keypressed backspace removes last character", function()
        profilesMod.open()
        profilesMod.state = "input"
        profilesMod.textInputActive = true
        profilesMod.nameInput = "Gamer"

        profilesMod.keypressed("backspace")
        harness.assert_equal("Game", profilesMod.nameInput)
        profilesMod.keypressed("backspace")
        harness.assert_equal("Gam", profilesMod.nameInput)
    end)

    harness.it("keypressed return confirms input", function()
        profilesMod.open()
        profilesMod.state = "input"
        profilesMod.confirmType = "create"
        profilesMod.inputIndex = 1
        profilesMod.nameInput = "ProSnake"
        profilesMod.textInputActive = true

        profilesMod.keypressed("return")
        harness.assert_equal("select", profilesMod.state, "State returned to select")
        harness.assert_equal("ProSnake", persistence.getActiveProfile().name, "Profile created via Enter")
    end)

    harness.it("keypressed escape cancels input modal", function()
        profilesMod.open()
        profilesMod.state = "input"
        profilesMod.confirmType = "create"
        profilesMod.nameInput = "DiscardMe"
        profilesMod.textInputActive = true

        profilesMod.keypressed("escape")
        harness.assert_equal("select", profilesMod.state, "State returned to select")
        harness.assert_equal("", profilesMod.nameInput, "Input cleared")
        harness.assert_nil(persistence.getActiveProfile(), "No profile created")
    end)

    harness.it("keypressed in confirm modal: y/return confirms, n/escape cancels", function()
        persistence.createProfile("DeleteTest")
        profilesMod.open()

        -- Test confirm with 'y'
        profilesMod.state = "confirm"
        profilesMod.confirmType = "delete"
        profilesMod.confirmIndex = 1
        profilesMod.keypressed("y")
        harness.assert_equal("select", profilesMod.state)
        harness.assert_nil(persistence.getProfiles()[1], "Deleted via 'y'")

        -- Recreate and test cancel with 'escape'
        persistence.createProfile("CancelTest")
        profilesMod.state = "confirm"
        profilesMod.confirmType = "delete"
        profilesMod.confirmIndex = 1
        profilesMod.keypressed("escape")
        harness.assert_equal("select", profilesMod.state)
        harness.assert_not_nil(persistence.getProfiles()[1], "Not deleted after escape")
    end)

    harness.it("keypressed in achievements modal: escape/return/space returns to select", function()
        profilesMod.open()
        profilesMod.state = "achievements"
        profilesMod.keypressed("space")
        harness.assert_equal("select", profilesMod.state, "Returned to select on space")

        profilesMod.state = "achievements"
        profilesMod.keypressed("escape")
        harness.assert_equal("select", profilesMod.state, "Returned to select on escape")
    end)

    harness.it("keypressed in select state: 1, 2, 3 shortcuts select or prompt create", function()
        persistence.createProfile("Slot1Player")
        profilesMod.open()

        -- Key '1' selects existing slot 1
        profilesMod.keypressed("1")
        harness.assert_equal(1, persistence.getActiveProfileIndex(), "Selected slot 1")

        -- Key '2' opens create dialog for empty slot 2
        profilesMod.keypressed("2")
        harness.assert_equal("input", profilesMod.state, "Switched to input for slot 2")
        harness.assert_equal("create", profilesMod.confirmType, "confirmType is create")
        harness.assert_equal(2, profilesMod.inputIndex, "inputIndex is 2")
    end)

    harness.it("keypressed in select state: escape closes profiles menu", function()
        profilesMod.open()
        harness.assert_true(profilesMod.visible)
        profilesMod.keypressed("escape")
        harness.assert_false(profilesMod.visible, "Profiles closed on escape")
    end)
end)

-- ============================================================
-- SUITE 6: profilesDraw Rendering & Safety
-- ============================================================
harness.describe("Profiles: profilesDraw Rendering & Safety", function()
    harness.before_each(function()
        reset_test_env()
    end)

    harness.it("drawSelect renders empty and filled slots without error", function()
        persistence.createProfile("DrawHero")
        profilesMod.open()
        profilesMod.panelX, profilesMod.panelY = 50, 50
        profilesMod.panelW, profilesMod.panelH = 600, 400

        local ok, err = pcall(function()
            profilesDraw.drawSelect(profilesMod, 800, 600)
        end)
        harness.assert_true(ok, "drawSelect executed without error: " .. tostring(err))
        harness.assert_gt(#profilesMod.buttonRects, 0, "Generated clickable button rects")
        harness.assert_gt(#profilesMod.cardRects, 0, "Generated card rects")
    end)

    harness.it("drawInputModal and drawConfirmModal render without error", function()
        profilesMod.open()
        profilesMod.panelX, profilesMod.panelY = 50, 50
        profilesMod.panelW, profilesMod.panelH = 600, 400

        local okInput, errInput = pcall(function()
            profilesDraw.drawInputModal(profilesMod)
        end)
        harness.assert_true(okInput, "drawInputModal executed without error: " .. tostring(errInput))

        profilesMod.confirmMsg = "¿Borrar perfil?"
        local okConfirm, errConfirm = pcall(function()
            profilesDraw.drawConfirmModal(profilesMod)
        end)
        harness.assert_true(okConfirm, "drawConfirmModal executed without error: " .. tostring(errConfirm))
    end)

    harness.it("drawAchievements renders achievements grid and progress without error", function()
        persistence.createProfile("AchTester")
        local p = persistence.getActiveProfile()
        p.achievements = {
            first_kill = { done = true, at = os.time() },
            stage_3 = { done = true, at = os.time() }
        }
        profilesMod.open()
        profilesMod.confirmIndex = 1
        profilesMod.panelX, profilesMod.panelY = 50, 50
        profilesMod.panelW, profilesMod.panelH = 600, 500

        local ok, err = pcall(function()
            profilesDraw.drawAchievements(profilesMod)
        end)
        harness.assert_true(ok, "drawAchievements executed without error: " .. tostring(err))
    end)

    harness.it("profilesMod.draw handles scroll wheel in select state", function()
        profilesMod.open()
        profilesMod.scrollEnabled = true
        profilesMod.maxScroll = 100
        profilesMod.scrollOffset = 0

        profilesMod.wheelmoved(0, -2)
        harness.assert_equal(48, profilesMod.scrollOffset, "Scroll offset incremented")

        profilesMod.wheelmoved(0, 1)
        harness.assert_equal(24, profilesMod.scrollOffset, "Scroll offset decremented")
    end)
end)

-- tests/test_scope_05_world.lua
-- Suite completa de pruebas unitarias para core/world.lua y core/touch.lua

package.path = "../?.lua;../?/init.lua;./?.lua;./tests/?.lua;" .. package.path

local harness = require("tests.test_harness")
local world = require("core.world")
local touch = require("core.touch")
local snakeMod = require("entities.snake")
local constants = require("constants")

harness.describe("Core World: State Management & Getters/Setters", function()
    harness.before_each(function()
        world.reset()
        world.clearListeners()
        world.clearSnapshots()
    end)

    harness.it("World.state is a valid table and allows direct property access", function()
        harness.assert_type(world.state, "table", "world.state must be a table")
        world.state.puntuacion = 250
        harness.assert_equal(250, world.state.puntuacion, "Direct property assignment should work")
    end)

    harness.it("World.stateInit populates state without breaking table reference", function()
        local originalRef = world.state
        local res = world.stateInit({ score = 100, coins = 25, stage = 2 })
        harness.assert_equal(originalRef, world.state, "Table reference must be preserved")
        harness.assert_equal(originalRef, res, "stateInit must return world.state")
        harness.assert_equal(100, world.state.score, "score should be initialized")
        harness.assert_equal(25, world.state.coins, "coins should be initialized")
        harness.assert_equal(2, world.state.stage, "stage should be initialized")
    end)

    harness.it("World.reset clears state in-place and optionally applies defaults", function()
        local originalRef = world.state
        world.set("tempKey", 999)
        world.set("name", "hero")
        world.reset({ lives = 3, debugImmune = false })

        harness.assert_equal(originalRef, world.state, "Table reference must be preserved after reset")
        harness.assert_nil(world.get("tempKey"), "tempKey should be cleared")
        harness.assert_nil(world.get("name"), "name should be cleared")
        harness.assert_equal(3, world.get("lives"), "default lives should be set")
        harness.assert_equal(false, world.get("debugImmune"), "default debugImmune should be set")
    end)

    harness.it("World.get returns value or default fallback", function()
        world.set("volume", 0.8)
        world.set("isMuted", false)

        harness.assert_equal(0.8, world.get("volume", 1.0), "Should return existing volume")
        harness.assert_equal(false, world.get("isMuted", true), "Should return false, not fallback")
        harness.assert_equal("default_mode", world.get("non_existent", "default_mode"), "Should return fallback when nil")
        harness.assert_nil(world.get("missing_key"), "Should return nil if no fallback provided")
    end)

    harness.it("World.has correctly checks key existence", function()
        world.set("foundKey", 123)
        harness.assert_true(world.has("foundKey"), "Should return true for existing key")
        harness.assert_false(world.has("missingKey"), "Should return false for missing key")
    end)

    harness.it("World.delete removes key and returns old value", function()
        world.set("toDelete", "secret")
        local old = world.delete("toDelete")
        harness.assert_equal("secret", old, "delete should return deleted value")
        harness.assert_nil(world.get("toDelete"), "key should be nil after delete")
        harness.assert_false(world.has("toDelete"), "has should return false after delete")
    end)

    harness.it("World.update atomically mutates state using a function", function()
        world.set("counter", 10)
        local newVal = world.update("counter", function(c) return c * 2 + 5 end, 0)
        harness.assert_equal(25, newVal, "update should return updated value")
        harness.assert_equal(25, world.get("counter"), "world.get should reflect updated value")

        -- Update nil key with defaultVal
        local fromNil = world.update("nilCounter", function(c) return c + 1 end, 100)
        harness.assert_equal(101, fromNil, "update with fallback should compute correctly")
    end)

    harness.it("World.increment and World.decrement work with bounds clamping", function()
        world.set("count", 5)
        harness.assert_equal(6, world.increment("count"), "Default increment should add 1")
        harness.assert_equal(10, world.increment("count", 4), "Custom increment should add 4")
        harness.assert_equal(12, world.increment("count", 5, 12), "Increment should respect maxVal")

        harness.assert_equal(11, world.decrement("count"), "Default decrement should subtract 1")
        harness.assert_equal(7, world.decrement("count", 4), "Custom decrement should subtract 4")
        harness.assert_equal(5, world.decrement("count", 10, 5), "Decrement should respect minVal")
    end)

    harness.it("World.toggle switches boolean states", function()
        world.set("flag", false)
        harness.assert_equal(true, world.toggle("flag"), "false should toggle to true")
        harness.assert_equal(false, world.toggle("flag"), "true should toggle to false")
        harness.assert_equal(true, world.toggle("unsetFlag"), "nil should toggle to true")
    end)

    harness.it("World.clamp bounds numbers within min and max", function()
        world.set("val1", -5)
        world.set("val2", 150)
        world.set("val3", 42)

        harness.assert_equal(0, world.clamp("val1", 0, 100), "-5 should be clamped to 0")
        harness.assert_equal(100, world.clamp("val2", 0, 100), "150 should be clamped to 100")
        harness.assert_equal(42, world.clamp("val3", 0, 100), "42 should stay 42")
    end)

    harness.it("World.subscribe notifies listeners on key changes", function()
        local received = {}
        local unsub = world.subscribe("score", function(newVal, oldVal, key)
            table.insert(received, { new = newVal, old = oldVal, key = key })
        end)

        world.set("score", 10)
        world.set("score", 25)
        harness.assert_equal(2, #received, "Listener should have been called twice")
        harness.assert_equal(10, received[1].new)
        harness.assert_nil(received[1].old)
        harness.assert_equal(25, received[2].new)
        harness.assert_equal(10, received[2].old)

        -- Test unsubscribe
        unsub()
        world.set("score", 50)
        harness.assert_equal(2, #received, "Listener should not receive events after unsubscribe")
    end)

    harness.it("In-memory Snapshots allow saving and restoring state", function()
        world.set("score", 500)
        world.set("playerData", { hp = 100, inv = { "shield", "turbo" } })
        world.saveSnapshot("slot_1")

        harness.assert_true(world.hasSnapshot("slot_1"), "Snapshot slot_1 should exist")

        -- Mutate current state
        world.set("score", 0)
        world.get("playerData").hp = 0
        table.insert(world.get("playerData").inv, "bomb")

        -- Restore snapshot
        local ok = world.loadSnapshot("slot_1")
        harness.assert_true(ok, "loadSnapshot should succeed")
        harness.assert_equal(500, world.get("score"), "Restored score must be 500")
        harness.assert_equal(100, world.get("playerData").hp, "Restored hp must be 100")
        harness.assert_equal(2, #world.get("playerData").inv, "Restored inventory should have 2 items")

        world.deleteSnapshot("slot_1")
        harness.assert_false(world.hasSnapshot("slot_1"), "Snapshot slot_1 should be deleted")
    end)

    harness.it("World.exportState and World.importState create deep copies", function()
        world.set("config", { sound = true, volume = 0.5 })
        local exported = world.exportState()

        -- Modify original
        world.get("config").volume = 1.0
        harness.assert_equal(0.5, exported.config.volume, "Exported state must be an independent deep copy")

        -- Import back
        world.importState(exported)
        harness.assert_equal(0.5, world.get("config").volume, "Imported state should restore 0.5 volume")
    end)
end)

harness.describe("Core Touch: Virtual Coordinates, Deadzones, and Gestures", function()
    local dummyPlayer

    harness.before_each(function()
        touch.reset()
        touch.setSwipeMin(18)
        touch.setTapMaxDist(12)
        world.reset({
            gameState = constants.GAME_STATE_PLAYING,
            player = snakeMod.reset()
        })
        dummyPlayer = world.state.player
    end)

    harness.it("touch.toVirtual transforms normalized [0, 1] to screen pixels", function()
        -- With 640x360 mock screen
        local vx1, vy1 = touch.toVirtual(0.5, 0.5)
        harness.assert_almost_equal(320, vx1, 0.1, "Normalized 0.5 X should be 320")
        harness.assert_almost_equal(180, vy1, 0.1, "Normalized 0.5 Y should be 180")

        -- Pixel coordinates >= 1 remain untouched
        local vx2, vy2 = touch.toVirtual(100, 200)
        harness.assert_equal(100, vx2, "Pixel coordinate 100 should remain 100")
        harness.assert_equal(200, vy2, "Pixel coordinate 200 should remain 200")
    end)

    harness.it("touch.hasActiveTouch and active touch tracking lifecycle", function()
        harness.assert_false(touch.hasActiveTouch(), "Initially should have no active touches")
        harness.assert_equal(0, touch.getActiveTouchCount(), "Count should be 0")

        touch.touchpressed(1, 100, 150)
        harness.assert_true(touch.hasActiveTouch(), "Should have active touch after pressed")
        harness.assert_equal(1, touch.getActiveTouchCount(), "Count should be 1")

        local t = touch.getActiveTouch(1)
        harness.assert_not_nil(t, "Active touch entry should exist")
        harness.assert_equal(100, t.startX)
        harness.assert_equal(150, t.startY)
        harness.assert_equal(false, t.moved)

        touch.touchmoved(1, 105, 150)
        harness.assert_equal(105, t.x)

        touch.touchreleased(1, 105, 150)
        harness.assert_false(touch.hasActiveTouch(), "Should have no active touches after release")
        harness.assert_equal(0, touch.getActiveTouchCount(), "Count should be 0 after release")
    end)

    harness.it("Tap deadzone correctly distinguishes micro-movements from intentional drags", function()
        touch.touchpressed(1, 100, 100)
        local t = touch.getActiveTouch(1)

        -- Micro movement (5px <= TAP_DEADZONE 12px)
        touch.touchmoved(1, 105, 100)
        harness.assert_false(t.moved, "Micro-movement within deadzone should not set moved = true")

        -- Movement exceeding deadzone (15px > 12px)
        touch.touchmoved(1, 115, 100)
        harness.assert_true(t.moved, "Displacement > 12px should set moved = true")
    end)

    harness.it("Pause Button detection and pause toggle", function()
        local bx, by, bw, bh = touch.getPauseButtonRect()
        harness.assert_gt(bw, 0, "Button width should be positive")
        harness.assert_gt(bh, 0, "Button height should be positive")

        local insideX = bx + bw / 2
        local insideY = by + bh / 2
        harness.assert_true(touch.isInsidePauseButton(insideX, insideY), "Center of pause button must be inside")
        harness.assert_false(touch.isInsidePauseButton(10, 10), "Top-left point must not be inside pause button")

        -- Tap pause button while PLAYING -> PAUSED
        world.state.gameState = constants.GAME_STATE_PLAYING
        touch.touchpressed(1, insideX, insideY)
        touch.touchreleased(1, insideX, insideY)
        harness.assert_equal(constants.GAME_STATE_PAUSED, world.state.gameState, "Tap inside button should toggle PLAYING to PAUSED")

        -- Tap pause button while PAUSED -> PLAYING
        touch.touchpressed(1, insideX, insideY)
        touch.touchreleased(1, insideX, insideY)
        harness.assert_equal(constants.GAME_STATE_PLAYING, world.state.gameState, "Tap inside button should toggle PAUSED to PLAYING")
    end)

    harness.it("Horizontal swipe right enqueues (1, 0)", function()
        dummyPlayer.dirX = 0
        dummyPlayer.dirY = -1
        dummyPlayer.lastMovedDirX = 0
        dummyPlayer.lastMovedDirY = -1

        touch.touchpressed(1, 100, 100)
        touch.touchreleased(1, 150, 100) -- dx = +50 (> SWIPE_MIN)

        harness.assert_equal(1, #dummyPlayer.inputQueue, "Should have 1 direction enqueued")
        harness.assert_equal(1, dummyPlayer.inputQueue[1].x, "Enqueued dirX should be 1")
        harness.assert_equal(0, dummyPlayer.inputQueue[1].y, "Enqueued dirY should be 0")
    end)

    harness.it("Horizontal swipe left enqueues (-1, 0)", function()
        dummyPlayer.dirX = 0
        dummyPlayer.dirY = 1
        dummyPlayer.lastMovedDirX = 0
        dummyPlayer.lastMovedDirY = 1

        touch.touchpressed(1, 200, 100)
        touch.touchreleased(1, 150, 100) -- dx = -50

        harness.assert_equal(1, #dummyPlayer.inputQueue, "Should have 1 direction enqueued")
        harness.assert_equal(-1, dummyPlayer.inputQueue[1].x, "Enqueued dirX should be -1")
        harness.assert_equal(0, dummyPlayer.inputQueue[1].y, "Enqueued dirY should be 0")
    end)

    harness.it("Vertical swipe down enqueues (0, 1)", function()
        dummyPlayer.dirX = 1
        dummyPlayer.dirY = 0
        dummyPlayer.lastMovedDirX = 1
        dummyPlayer.lastMovedDirY = 0

        touch.touchpressed(1, 100, 100)
        touch.touchreleased(1, 100, 160) -- dy = +60

        harness.assert_equal(1, #dummyPlayer.inputQueue, "Should have 1 direction enqueued")
        harness.assert_equal(0, dummyPlayer.inputQueue[1].x, "Enqueued dirX should be 0")
        harness.assert_equal(1, dummyPlayer.inputQueue[1].y, "Enqueued dirY should be 1")
    end)

    harness.it("Vertical swipe up enqueues (0, -1)", function()
        dummyPlayer.dirX = 1
        dummyPlayer.dirY = 0
        dummyPlayer.lastMovedDirX = 1
        dummyPlayer.lastMovedDirY = 0

        touch.touchpressed(1, 100, 200)
        touch.touchreleased(1, 100, 140) -- dy = -60

        harness.assert_equal(1, #dummyPlayer.inputQueue, "Should have 1 direction enqueued")
        harness.assert_equal(0, dummyPlayer.inputQueue[1].x, "Enqueued dirX should be 0")
        harness.assert_equal(-1, dummyPlayer.inputQueue[1].y, "Enqueued dirY should be -1")
    end)

    harness.it("Diagonal swipe respects dominant axis", function()
        dummyPlayer.dirX = 0
        dummyPlayer.dirY = 1
        dummyPlayer.lastMovedDirX = 0
        dummyPlayer.lastMovedDirY = 1

        -- dx = 40, dy = 20 -> dx dominates
        touch.touchpressed(1, 100, 100)
        touch.touchreleased(1, 140, 120)

        harness.assert_equal(1, #dummyPlayer.inputQueue, "Should enqueue dominant direction")
        harness.assert_equal(1, dummyPlayer.inputQueue[1].x)
        harness.assert_equal(0, dummyPlayer.inputQueue[1].y)
    end)

    harness.it("Continuous drag during touchmoved triggers real-time swipe", function()
        dummyPlayer.dirX = 1
        dummyPlayer.dirY = 0
        dummyPlayer.lastMovedDirX = 1
        dummyPlayer.lastMovedDirY = 0

        touch.touchpressed(1, 100, 100)
        -- Move down past SWIPE_MIN
        touch.touchmoved(1, 100, 130)

        harness.assert_equal(1, #dummyPlayer.inputQueue, "Swipe should trigger in real-time on move")
        harness.assert_equal(0, dummyPlayer.inputQueue[1].x)
        harness.assert_equal(1, dummyPlayer.inputQueue[1].y)

        -- Releasing should not double-queue if anchor was reset
        touch.touchreleased(1, 100, 130)
        harness.assert_equal(1, #dummyPlayer.inputQueue, "Release should not duplicate turn")
    end)

    harness.it("Swipe ignored when game state is not PLAYING", function()
        world.state.gameState = constants.GAME_STATE_PAUSED
        touch.touchpressed(1, 100, 100)
        touch.touchreleased(1, 200, 100)

        harness.assert_equal(0, #dummyPlayer.inputQueue, "Swipes during PAUSED must be ignored")
    end)

    harness.it("touch.draw executes safely in PLAYING and PAUSED states", function()
        world.state.gameState = constants.GAME_STATE_PLAYING
        local ok1 = pcall(function() touch.draw(1.0) end)
        harness.assert_true(ok1, "touch.draw should execute without error in PLAYING")

        world.state.gameState = constants.GAME_STATE_PAUSED
        local ok2 = pcall(function() touch.draw(0.8) end)
        harness.assert_true(ok2, "touch.draw should execute without error in PAUSED")
    end)
end)


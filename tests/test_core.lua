local harness = require("tests.test_harness")
local config = require("core.config")
local helpers = require("core.helpers")
local Log = require("core.logger")
local timers = require("core.timers")
local world = require("core.world")
local touch = require("core.touch")
local constants = require("constants")

--------------------------------------------------------------------------------
-- 1. SUITE: core/config.lua
--------------------------------------------------------------------------------
harness.describe("Core - config.lua (Configuration & Constants)", function()
    harness.it("defines valid canvas dimensions and grid geometry", function()
        harness.assert_equal(640, config.canvasWidth, "canvas width should be 640")
        harness.assert_equal(360, config.canvasHeight, "canvas height should be 360")
        harness.assert_equal(20, config.tileSize, "tile size should be 20")
        harness.assert_equal(20, config.TAMANIO_BLOQUE, "block size should be 20")

        -- Compatibility aliases
        harness.assert_equal(config.tileSize, config.GRID_SIZE, "GRID_SIZE alias must match tileSize")
        harness.assert_equal(config.canvasWidth, config.ANCHO, "ANCHO alias must match canvasWidth")
        harness.assert_equal(config.canvasHeight, config.ALTO, "ALTO alias must match canvasHeight")
    end)

    harness.it("defines all 7 canonical game states with unique IDs", function()
        harness.assert_equal(0, config.GAME_STATE_MENU)
        harness.assert_equal(1, config.GAME_STATE_PLAYING)
        harness.assert_equal(2, config.GAME_STATE_DEATH_ANIMATION)
        harness.assert_equal(3, config.GAME_STATE_HIGH_SCORE)
        harness.assert_equal(4, config.GAME_STATE_SHOP)
        harness.assert_equal(5, config.GAME_STATE_PAUSED)
        harness.assert_equal(6, config.GAME_STATE_TRANSITION)

        local states = {
            config.GAME_STATE_MENU,
            config.GAME_STATE_PLAYING,
            config.GAME_STATE_DEATH_ANIMATION,
            config.GAME_STATE_HIGH_SCORE,
            config.GAME_STATE_SHOP,
            config.GAME_STATE_PAUSED,
            config.GAME_STATE_TRANSITION
        }
        local unique = {}
        for _, s in ipairs(states) do
            harness.assert_type(s, "number")
            harness.assert_nil(unique[s], "game state IDs must be strictly unique")
            unique[s] = true
        end
    end)

    harness.it("defines valid gameplay timers, speeds, and buffer constants", function()
        harness.assert_gt(config.VELOCIDAD_INICIAL, 0)
        harness.assert_gt(config.VELOCIDAD_MINIMA, 0)
        harness.assert_lte(config.VELOCIDAD_MINIMA, config.VELOCIDAD_INICIAL)
        harness.assert_gt(config.CORNER_BUFFER_RATIO, 0)
        harness.assert_gte(config.INPUT_BUFFER_MAX, 1)
        harness.assert_gt(config.SHAKE_DURATION, 0)
        harness.assert_gt(config.SHAKE_INTENSITY, 0)
        harness.assert_gt(config.FADE_SPEED, 0)
    end)

    harness.it("defines valid shop costs and ability parameters", function()
        local costKeys = {
            "SHIELD_COST", "MAGNET_COST", "SPEED_REDUCER_COST", "ARMOR_COST",
            "GHOST_COST", "BOMB_COST", "HUNGER_COST", "TURBO_COST",
            "SLOW_COST", "DOUBLER_COST", "EXTRA_COIN_COST", "STAR_COST"
        }
        for _, key in ipairs(costKeys) do
            harness.assert_type(config[key], "number", key .. " must be a number")
            harness.assert_gt(config[key], 0, key .. " must be positive")
        end

        harness.assert_gt(config.MAGNET_DURATION, 0)
        harness.assert_gt(config.MAGNET_RANGE, 0)
        harness.assert_gt(config.BOMB_RADIUS, 0)
        harness.assert_gt(config.TURBO_DURATION, 0)
        harness.assert_gt(config.SLOW_DURATION, 0)
        harness.assert_gt(config.COMBO_WINDOW, 0)
        harness.assert_gt(config.COMBO_MULTIPLIER, 0)
    end)

    harness.it("defines valid color palettes with normalized RGB values", function()
        local colorKeys = {
            "COLOR_BG", "COLOR_GRID_A", "COLOR_GRID_B", "COLOR_ACCENT",
            "COLOR_GRID_HOT_A", "COLOR_GRID_HOT_B", "COLOR_GOLD", "COLOR_PANEL",
            "COLOR_RED", "COLOR_GREEN", "COLOR_ENEMY_CHASER",
            "COLOR_ENEMY_PATROLLER", "COLOR_ENEMY_SPAWNER"
        }
        for _, key in ipairs(colorKeys) do
            local color = config[key]
            harness.assert_type(color, "table", key .. " must be a color table")
            harness.assert_gte(#color, 3, key .. " must have at least 3 channels (RGB)")
            for i = 1, #color do
                harness.assert_gte(color[i], 0.0, key .. " channel must be >= 0")
                harness.assert_lte(color[i], 1.0, key .. " channel must be <= 1")
            end
        end
    end)

    harness.it("defines all 5 dungeon biomes with complete schema", function()
        harness.assert_not_nil(config.BIOMES, "BIOMES table must exist")
        harness.assert_equal(5, #config.BIOMES, "Exactly 5 biomes must be configured")

        local requiredFields = {"id", "name", "subtitle", "wallWrap", "gridColor", "wallColor"}
        for i = 1, 5 do
            local biome = config.BIOMES[i]
            harness.assert_type(biome, "table", "biome " .. i .. " must be a table")
            for _, field in ipairs(requiredFields) do
                harness.assert_not_nil(biome[field], "biome " .. i .. " missing field: " .. field)
            end
            harness.assert_type(biome.wallWrap, "boolean", "biome " .. i .. " wallWrap must be boolean")
        end

        -- Verify specific biome flags
        harness.assert_equal("catacumbas", config.BIOMES[1].id)
        harness.assert_true(config.BIOMES[1].wallWrap)

        harness.assert_equal("hielo", config.BIOMES[2].id)
        harness.assert_true(config.BIOMES[2].isIce)

        harness.assert_equal("volcan", config.BIOMES[3].id)
        harness.assert_true(config.BIOMES[3].hazardLava)

        harness.assert_equal("colmena", config.BIOMES[4].id)
        harness.assert_true(config.BIOMES[4].isSlime)

        harness.assert_equal("vacio", config.BIOMES[5].id)
        harness.assert_false(config.BIOMES[5].wallWrap, "Void biome must have wallWrap = false")
    end)

    harness.it("defines HUD and font configurations", function()
        harness.assert_gt(config.HUD_HEIGHT, 0)
        harness.assert_gt(config.FONT_TITLE, 0)
        harness.assert_gt(config.FONT_LARGE, 0)
        harness.assert_gt(config.FONT_NORMAL, 0)
        harness.assert_gt(config.FONT_SMALL, 0)
        harness.assert_type(config.FONT_FILE, "string")
    end)
end)

--------------------------------------------------------------------------------
-- 2. SUITE: core/logger.lua
--------------------------------------------------------------------------------
harness.describe("Core - logger.lua (Structured Logging System)", function()
    local loggedMessages = {}
    local originalLevel = Log.getLevel()

    harness.before_each(function()
        loggedMessages = {}
        Log.setWriter(function(msg, lvl)
            table.insert(loggedMessages, { message = msg, level = lvl })
        end)
        Log.setLevel(Log.LEVEL_INFO)
    end)

    harness.after_each(function()
        Log.setWriter(nil)
        Log.setLevel(originalLevel)
    end)

    harness.it("exposes log level constants correctly", function()
        harness.assert_equal(1, Log.LEVEL_DEBUG)
        harness.assert_equal(2, Log.LEVEL_INFO)
        harness.assert_equal(3, Log.LEVEL_WARN)
        harness.assert_equal(4, Log.LEVEL_ERROR)
    end)

    harness.it("validates and sets log levels strictly", function()
        Log.setLevel(Log.LEVEL_DEBUG)
        harness.assert_equal(Log.LEVEL_DEBUG, Log.getLevel())

        Log.setLevel(Log.LEVEL_ERROR)
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel())

        -- Invalid values must be ignored without raising errors
        Log.setLevel(0)
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel())

        Log.setLevel(999)
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel())

        Log.setLevel(nil)
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel())

        Log.setLevel("INVALID")
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel())
    end)

    harness.it("filters messages below the current log level", function()
        Log.setLevel(Log.LEVEL_WARN)

        Log.debug("should not appear")
        Log.info("should not appear")
        harness.assert_equal(0, #loggedMessages, "DEBUG and INFO should be filtered at WARN level")

        Log.warn("warning message")
        Log.error("error message")
        harness.assert_equal(2, #loggedMessages, "WARN and ERROR should pass through")
        harness.assert_equal(Log.LEVEL_WARN, loggedMessages[1].level)
        harness.assert_equal(Log.LEVEL_ERROR, loggedMessages[2].level)
    end)

    harness.it("passes all messages when set to LEVEL_DEBUG", function()
        Log.setLevel(Log.LEVEL_DEBUG)

        Log.debug("dbg")
        Log.info("inf")
        Log.warn("wrn")
        Log.error("err")

        harness.assert_equal(4, #loggedMessages)
        harness.assert_equal(Log.LEVEL_DEBUG, loggedMessages[1].level)
        harness.assert_equal(Log.LEVEL_INFO, loggedMessages[2].level)
        harness.assert_equal(Log.LEVEL_WARN, loggedMessages[3].level)
        harness.assert_equal(Log.LEVEL_ERROR, loggedMessages[4].level)
    end)

    harness.it("formats multi-argument messages with string conversion", function()
        Log.setLevel(Log.LEVEL_DEBUG)
        Log.info("Score:", 1500, "Alive:", true, "Table:", {x = 1})

        harness.assert_equal(1, #loggedMessages)
        local msg = loggedMessages[1].message
        harness.assert_not_nil(msg:find("%[INFO%]"), "Tag [INFO] should be present")
        harness.assert_not_nil(msg:find("Score:"), "Score prefix should be present")
        harness.assert_not_nil(msg:find("1500"), "Number 1500 should be present")
        harness.assert_not_nil(msg:find("true"), "Boolean true should be present")
    end)

    harness.it("formats messages via Log.formatMessage directly", function()
        local formatted = Log.formatMessage(Log.LEVEL_DEBUG, "System", "Online", 100)
        harness.assert_type(formatted, "string")
        harness.assert_not_nil(formatted:find("%[DEBUG%]"))
        harness.assert_not_nil(formatted:find("System Online 100"))
    end)
end)

--------------------------------------------------------------------------------
-- 3. SUITE: core/timers.lua
--------------------------------------------------------------------------------
harness.describe("Core - timers.lua (Object Pooled Timer Engine)", function()
    harness.before_each(function()
        timers.clear()
    end)

    harness.after_each(function()
        timers.clear()
    end)

    harness.it("executes a one-shot timer after exact elapsed duration", function()
        local executed = false
        local t = timers.after(0.5, function()
            executed = true
        end)

        harness.assert_not_nil(t, "timer object created")
        harness.assert_true(t.active, "timer should be active")
        harness.assert_equal(1, timers.getActiveCount())

        timers.update(0.2)
        harness.assert_false(executed, "should not trigger before 0.5s")
        harness.assert_equal(1, timers.getActiveCount())

        timers.update(0.29)
        harness.assert_false(executed, "should not trigger at 0.49s")

        timers.update(0.02)
        harness.assert_true(executed, "should trigger at >= 0.5s")
        harness.assert_false(t.active, "one-shot timer must become inactive")
        harness.assert_equal(0, timers.getActiveCount())
        harness.assert_gte(timers.getFreeCount(), 1, "expired timer returned to free pool")
    end)

    harness.it("executes a repeating timer across multiple intervals", function()
        local count = 0
        local t = timers.every(0.1, function()
            count = count + 1
        end)

        harness.assert_true(t.active)
        harness.assert_true(t.loops)

        timers.update(0.15)
        harness.assert_equal(1, count)

        timers.update(0.1)
        harness.assert_equal(2, count)

        timers.update(0.1)
        harness.assert_equal(3, count)

        -- Canceling repeating timer
        t:cancel()
        harness.assert_false(t.active)
        timers.update(0.3)
        harness.assert_equal(3, count, "cancelled timer must not fire again")
        harness.assert_equal(0, timers.getActiveCount())
    end)

    harness.it("handles timer cancellation via timers.cancel()", function()
        local fired = false
        local t = timers.after(0.3, function()
            fired = true
        end)

        timers.update(0.1)
        timers.cancel(t)
        harness.assert_false(t.active)
        harness.assert_nil(t.callback)

        timers.update(0.5)
        harness.assert_false(fired, "cancelled timer must not fire")
        harness.assert_equal(0, timers.getActiveCount())
    end)

    harness.it("cancelling an already inactive timer is safe no-op", function()
        local t = timers.after(0.1, function() end)
        timers.cancel(t)
        local freeBefore = timers.getFreeCount()
        timers.cancel(t) -- duplicate cancel
        timers.cancel(nil) -- nil cancel
        harness.assert_equal(freeBefore, timers.getFreeCount())
    end)

    harness.it("clears all active timers and returns them to free pool", function()
        local runs = {false, false, false}
        timers.after(0.1, function() runs[1] = true end)
        timers.every(0.2, function() runs[2] = true end)
        timers.after(0.3, function() runs[3] = true end)

        harness.assert_equal(3, timers.getActiveCount())
        timers.clear()
        harness.assert_equal(0, timers.getActiveCount())
        harness.assert_gte(timers.getFreeCount(), 3)

        timers.update(1.0)
        harness.assert_false(runs[1])
        harness.assert_false(runs[2])
        harness.assert_false(runs[3])
    end)

    harness.it("recycles free timer objects without allocating new tables", function()
        timers.clear()
        local t1 = timers.after(0.1, function() end)
        timers.cancel(t1)
        harness.assert_gte(timers.getFreeCount(), 1)

        -- Next acquisition should pop the recycled timer
        local t2 = timers.after(0.2, function() end)
        harness.assert_equal(t1, t2, "acquired timer should reuse table from free pool")
        harness.assert_true(t2.active)
        harness.assert_equal(0.2, t2.delay)
    end)

    harness.it("prevents double-ticking when cancelling and reacquiring in same frame", function()
        local callCount = 0
        local t1 = timers.after(1.0, function() end)
        timers.cancel(t1)

        -- Reacquire timer before next update
        local t2 = timers.after(1.0, function()
            callCount = callCount + 1
        end)

        -- Advance 0.5s: if double-ticked, accum would become 1.0 and fire prematurely
        timers.update(0.5)
        harness.assert_equal(0, callCount, "timer must not tick twice per update")

        timers.update(0.5)
        harness.assert_equal(1, callCount, "timer fires exactly after full 1.0s elapsed")
    end)

    harness.it("supports a timer cancelling itself inside its callback", function()
        local count = 0
        local myTimer
        myTimer = timers.every(0.1, function()
            count = count + 1
            if count == 2 then
                myTimer:cancel()
            end
        end)

        timers.update(0.1)
        harness.assert_equal(1, count)
        timers.update(0.1)
        harness.assert_equal(2, count)
        timers.update(0.1)
        harness.assert_equal(2, count, "timer cancelled inside callback must stop")
        harness.assert_equal(0, timers.getActiveCount())
    end)

    harness.it("supports creating new timers inside a callback", function()
        local childExecuted = false
        timers.after(0.1, function()
            timers.after(0.1, function()
                childExecuted = true
            end)
        end)

        timers.update(0.1)
        harness.assert_false(childExecuted)
        harness.assert_equal(1, timers.getActiveCount())

        timers.update(0.1)
        harness.assert_true(childExecuted)
        harness.assert_equal(0, timers.getActiveCount())
    end)

    harness.it("handles zero and negative delay gracefully", function()
        local zeroFired = false
        timers.after(0, function()
            zeroFired = true
        end)
        timers.update(0.01)
        harness.assert_true(zeroFired)
    end)
end)

--------------------------------------------------------------------------------
-- 4. SUITE: core/world.lua
--------------------------------------------------------------------------------
harness.describe("Core - world.lua (Encapsulated State Container)", function()
    harness.before_each(function()
        world.reset()
    end)

    harness.after_each(function()
        world.reset()
    end)

    harness.it("initializes state from key-value table", function()
        local st = world.stateInit({
            score = 2500,
            coins = 75,
            isAlive = true,
            gameState = constants.GAME_STATE_PLAYING
        })
        harness.assert_not_nil(st)
        harness.assert_equal(2500, world.get("score"))
        harness.assert_equal(75, world.get("coins"))
        harness.assert_true(world.get("isAlive"))
        harness.assert_equal(constants.GAME_STATE_PLAYING, world.get("gameState"))
    end)

    harness.it("safely handles stateInit with nil or empty argument", function()
        local st1 = world.stateInit()
        harness.assert_type(st1, "table")

        local st2 = world.stateInit(nil)
        harness.assert_type(st2, "table")
    end)

    harness.it("sets and gets various data types", function()
        world.set("numVal", 42)
        world.set("strVal", "snake")
        world.set("boolVal", false)
        world.set("tblVal", { a = 1, b = 2 })
        local fn = function() return "test" end
        world.set("fnVal", fn)

        harness.assert_equal(42, world.get("numVal"))
        harness.assert_equal("snake", world.get("strVal"))
        harness.assert_false(world.get("boolVal"))
        harness.assert_table_equal({ a = 1, b = 2 }, world.get("tblVal"))
        harness.assert_equal(fn, world.get("fnVal"))
        harness.assert_equal("test", world.get("fnVal")())
    end)

    harness.it("returns nil for unset keys", function()
        harness.assert_nil(world.get("nonExistentKey"))
    end)

    harness.it("resets state completely while preserving table reference", function()
        local stRef = world.state
        world.set("tempA", 100)
        world.set("tempB", 200)

        world.reset()
        harness.assert_nil(world.get("tempA"))
        harness.assert_nil(world.get("tempB"))
        harness.assert_equal(stRef, world.state, "world.state table identity must be preserved")
    end)
end)

--------------------------------------------------------------------------------
-- 5. SUITE: core/touch.lua
--------------------------------------------------------------------------------
harness.describe("Core - touch.lua (Touch Gestures & Swipe Engine)", function()
    local mockPlayer

    harness.before_each(function()
        touch.reset()
        mockPlayer = {
            directionQueue = {},
            xDir = 1,
            yDir = 0
        }
        world.stateInit({
            gameState = constants.GAME_STATE_PLAYING,
            player = mockPlayer
        })
    end)

    harness.after_each(function()
        touch.reset()
        world.reset()
    end)

    harness.it("tracks active touch states on press and release", function()
        harness.assert_false(touch.hasActiveTouch())
        touch.touchpressed(1, 100, 150)
        harness.assert_true(touch.hasActiveTouch())
        local t = touch.getActiveTouch(1)
        harness.assert_not_nil(t)
        harness.assert_equal(100, t.startX)
        harness.assert_equal(150, t.startY)

        touch.touchreleased(1, 100, 150)
        harness.assert_false(touch.hasActiveTouch())
        harness.assert_nil(touch.getActiveTouch(1))
    end)

    harness.it("manages multi-touch IDs independently", function()
        touch.touchpressed(1, 50, 50)
        touch.touchpressed(2, 200, 200)
        harness.assert_true(touch.hasActiveTouch())
        harness.assert_not_nil(touch.getActiveTouch(1))
        harness.assert_not_nil(touch.getActiveTouch(2))

        touch.touchreleased(1, 50, 50)
        harness.assert_true(touch.hasActiveTouch())
        harness.assert_nil(touch.getActiveTouch(1))
        harness.assert_not_nil(touch.getActiveTouch(2))

        touch.touchreleased(2, 200, 200)
        harness.assert_false(touch.hasActiveTouch())
    end)

    harness.it("detects horizontal swipes (Right and Left)", function()
        -- Swipe Right (dx >= SWIPE_MIN)
        touch.touchpressed(1, 100, 100)
        touch.touchmoved(1, 120, 100)
        touch.touchmoved(1, 160, 102)
        touch.touchreleased(1, 160, 102)

        -- Swipe Left (dx <= -SWIPE_MIN)
        touch.touchpressed(2, 300, 100)
        touch.touchmoved(2, 280, 99)
        touch.touchmoved(2, 240, 100)
        touch.touchreleased(2, 240, 100)

        harness.assert_false(touch.hasActiveTouch())
    end)

    harness.it("detects vertical swipes (Down and Up)", function()
        -- Swipe Down (dy >= SWIPE_MIN)
        touch.touchpressed(1, 100, 100)
        touch.touchmoved(1, 101, 130)
        touch.touchmoved(1, 100, 170)
        touch.touchreleased(1, 100, 170)

        -- Swipe Up (dy <= -SWIPE_MIN)
        touch.touchpressed(2, 100, 300)
        touch.touchmoved(2, 99, 270)
        touch.touchmoved(2, 100, 230)
        touch.touchreleased(2, 100, 230)

        harness.assert_false(touch.hasActiveTouch())
    end)

    harness.it("ignores tiny drag movements below SWIPE_MIN threshold", function()
        touch.touchpressed(1, 100, 100)
        touch.touchmoved(1, 105, 105)
        touch.touchreleased(1, 105, 105)
        -- Small delta (< 18) should not crash or trigger invalid turns
        harness.assert_false(touch.hasActiveTouch())
    end)

    harness.it("ignores swipes when gameState is not PLAYING", function()
        world.set("gameState", constants.GAME_STATE_MENU)
        touch.touchpressed(1, 100, 100)
        touch.touchmoved(1, 200, 100)
        touch.touchreleased(1, 200, 100)

        world.set("gameState", constants.GAME_STATE_SHOP)
        touch.touchpressed(2, 100, 100)
        touch.touchmoved(2, 200, 100)
        touch.touchreleased(2, 200, 100)
        harness.assert_false(touch.hasActiveTouch())
    end)

    harness.it("toggles pause when tapping the pause button in bottom-right corner", function()
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        local btnSize = math.min(56, w * 0.12)
        local btnX = w - btnSize - 14
        local btnY = h - btnSize - 14

        -- Tap inside button area to pause
        touch.touchpressed(1, btnX + btnSize / 2, btnY + btnSize / 2)
        touch.touchreleased(1, btnX + btnSize / 2, btnY + btnSize / 2)
        harness.assert_equal(constants.GAME_STATE_PAUSED, world.get("gameState"))

        -- Tap again to resume
        touch.touchpressed(2, btnX + btnSize / 2, btnY + btnSize / 2)
        touch.touchreleased(2, btnX + btnSize / 2, btnY + btnSize / 2)
        harness.assert_equal(constants.GAME_STATE_PLAYING, world.get("gameState"))
    end)

    harness.it("renders touch overlay in playing and paused states without error", function()
        world.set("gameState", constants.GAME_STATE_PLAYING)
        touch.draw()
        touch.draw(0.5)

        world.set("gameState", constants.GAME_STATE_PAUSED)
        touch.draw()

        world.set("gameState", constants.GAME_STATE_MENU)
        touch.draw() -- no-op in menu
    end)
end)

--------------------------------------------------------------------------------
-- 6. SUITE: core/helpers.lua
--------------------------------------------------------------------------------
harness.describe("Core - helpers.lua (Math, Geometry & Table Utilities)", function()
    -- deep_copy
    harness.it("deep copies primitive types directly", function()
        harness.assert_equal(100, helpers.deep_copy(100))
        harness.assert_equal("snake", helpers.deep_copy("snake"))
        harness.assert_equal(true, helpers.deep_copy(true))
        harness.assert_equal(false, helpers.deep_copy(false))
        harness.assert_nil(helpers.deep_copy(nil))
    end)

    harness.it("deep copies complex nested tables with full isolation", function()
        local original = {
            id = 1,
            info = { name = "viper", stats = { speed = 10, hp = 100 } },
            items = { { name = "bomb", count = 3 }, { name = "shield", count = 1 } }
        }
        local copy = helpers.deep_copy(original)
        harness.assert_table_equal(original, copy)

        -- Mutate copy deeply
        copy.info.stats.hp = 50
        copy.items[1].count = 99
        harness.assert_equal(100, original.info.stats.hp, "original nested value must not mutate")
        harness.assert_equal(3, original.items[1].count, "original nested item count must not mutate")
    end)

    harness.it("handles circular table references in deep_copy safely", function()
        local node = { name = "cycle" }
        node.self = node
        local copy = helpers.deep_copy(node)
        harness.assert_equal("cycle", copy.name)
        harness.assert_equal(copy, copy.self, "circular reference must point to copied table")
    end)

    -- clamp
    harness.it("clamps values within numeric bounds", function()
        harness.assert_equal(5, helpers.clamp(5, 0, 10))
        harness.assert_equal(0, helpers.clamp(-5, 0, 10))
        harness.assert_equal(10, helpers.clamp(15, 0, 10))
        harness.assert_equal(5, helpers.clamp(5, 5, 5))
        -- Inverted bounds check
        harness.assert_equal(5, helpers.clamp(5, 10, 0))
    end)

    -- distance & distance_sq
    harness.it("calculates euclidean distance and squared distance", function()
        harness.assert_almost_equal(5.0, helpers.distance(0, 0, 3, 4))
        harness.assert_almost_equal(25.0, helpers.distance_sq(0, 0, 3, 4))
        harness.assert_almost_equal(0.0, helpers.distance(10, 10, 10, 10))

        -- Table argument format
        local p1 = { x = 1, y = 1 }
        local p2 = { x = 4, y = 5 }
        harness.assert_almost_equal(5.0, helpers.distance(p1, p2))
        harness.assert_almost_equal(25.0, helpers.distance_sq(p1, p2))
    end)

    -- manhattan
    harness.it("calculates Manhattan distance", function()
        harness.assert_equal(7, helpers.manhattan(1, 2, 4, 6))
        harness.assert_equal(0, helpers.manhattan(5, 5, 5, 5))
        harness.assert_equal(8, helpers.manhattan({x = 0, y = 0}, {x = 4, y = 4}))
    end)

    -- rectsOverlap
    harness.it("detects AABB rectangle overlaps accurately", function()
        local r1 = { x = 0, y = 0, w = 10, h = 10 }
        local r2 = { x = 5, y = 5, w = 10, h = 10 }
        local r3 = { x = 20, y = 20, w = 10, h = 10 }
        local rAdjacent = { x = 10, y = 0, w = 10, h = 10 }

        harness.assert_true(helpers.rectsOverlap(r1, r2), "overlapping rects must return true")
        harness.assert_false(helpers.rectsOverlap(r1, r3), "distant rects must return false")
        harness.assert_false(helpers.rectsOverlap(r1, rAdjacent), "touching edges must not overlap")

        -- Scalar parameter format
        harness.assert_true(helpers.rectsOverlap(0, 0, 10, 10, 5, 5, 10, 10))
        harness.assert_false(helpers.rectsOverlap(0, 0, 10, 10, 15, 15, 10, 10))
        harness.assert_false(helpers.rectsOverlap(0, 0, 0, 10, 0, 0, 10, 10), "zero dimension rect must return false")
    end)

    -- rectContains
    harness.it("checks point inclusion in rectangle", function()
        local r = { x = 10, y = 20, w = 30, h = 40 }

        -- Inside
        harness.assert_true(helpers.rectContains(r, 15, 25))
        -- On boundary (inclusive)
        harness.assert_true(helpers.rectContains(r, 10, 20))
        harness.assert_true(helpers.rectContains(r, 40, 60))
        -- Outside
        harness.assert_false(helpers.rectContains(r, 9, 25))
        harness.assert_false(helpers.rectContains(r, 41, 25))
        harness.assert_false(helpers.rectContains(r, 20, 19))
        harness.assert_false(helpers.rectContains(r, 20, 61))
    end)

    -- rectCenter
    harness.it("calculates rectangle center point", function()
        local cx, cy = helpers.rectCenter({ x = 10, y = 20, w = 40, h = 60 })
        harness.assert_equal(30, cx)
        harness.assert_equal(50, cy)

        local scx, scy = helpers.rectCenter(0, 0, 100, 200)
        harness.assert_equal(50, scx)
        harness.assert_equal(100, scy)
    end)

    -- lerp & lerp_clamped
    harness.it("performs linear interpolation", function()
        harness.assert_almost_equal(10, helpers.lerp(10, 20, 0))
        harness.assert_almost_equal(20, helpers.lerp(10, 20, 1))
        harness.assert_almost_equal(15, helpers.lerp(10, 20, 0.5))
        harness.assert_almost_equal(25, helpers.lerp(10, 20, 1.5))

        harness.assert_almost_equal(20, helpers.lerp_clamped(10, 20, 1.5))
        harness.assert_almost_equal(10, helpers.lerp_clamped(10, 20, -0.5))
    end)

    -- sign
    harness.it("computes numeric sign correctly", function()
        harness.assert_equal(1, helpers.sign(42))
        harness.assert_equal(1, helpers.sign(0.001))
        harness.assert_equal(-1, helpers.sign(-100))
        harness.assert_equal(-1, helpers.sign(-0.5))
        harness.assert_equal(0, helpers.sign(0))
    end)

    -- round
    harness.it("rounds numbers to integers and decimals", function()
        harness.assert_equal(4, helpers.round(3.6))
        harness.assert_equal(3, helpers.round(3.4))
        harness.assert_equal(4, helpers.round(3.5))
        harness.assert_equal(-4, helpers.round(-3.6))
        harness.assert_equal(-3, helpers.round(-3.4))

        harness.assert_almost_equal(3.14, helpers.round(3.14159, 2))
        harness.assert_almost_equal(3.142, helpers.round(3.14159, 3))
    end)

    -- map_range
    harness.it("maps values across numerical ranges", function()
        harness.assert_almost_equal(50, helpers.map_range(5, 0, 10, 0, 100))
        harness.assert_almost_equal(0, helpers.map_range(0, 0, 10, 0, 100))
        harness.assert_almost_equal(100, helpers.map_range(10, 0, 10, 0, 100))
        -- Inverted mapping
        harness.assert_almost_equal(0, helpers.map_range(10, 0, 10, 100, 0))
        -- Zero input range protection
        harness.assert_equal(50, helpers.map_range(5, 10, 10, 50, 100))
    end)

    -- seedRandom
    harness.it("generates deterministic pseudo-random sequences with seedRandom", function()
        helpers.seedRandom(12345)
        local val1 = helpers.seedRandom()
        local val2 = helpers.seedRandom()

        helpers.seedRandom(12345)
        local resetVal1 = helpers.seedRandom()
        local resetVal2 = helpers.seedRandom()

        harness.assert_equal(val1, resetVal1, "seeded PRNG must produce deterministic sequence")
        harness.assert_equal(val2, resetVal2, "seeded PRNG must reproduce sequence step 2")
        harness.assert_gte(val1, 0.0)
        harness.assert_lt(val1, 1.0)
    end)

    -- angle_diff & normalize_angle
    harness.it("normalizes angles and calculates angular differences", function()
        harness.assert_almost_equal(0.0, helpers.angle_diff(0, 0))
        harness.assert_almost_equal(math.pi / 2, helpers.angle_diff(0, math.pi / 2))
        harness.assert_almost_equal(-math.pi / 2, helpers.angle_diff(math.pi / 2, 0))

        harness.assert_almost_equal(0.0, helpers.normalize_angle(math.pi * 2))
        harness.assert_almost_equal(math.pi, helpers.normalize_angle(math.pi))
        harness.assert_almost_equal(math.pi, helpers.normalize_angle(-math.pi))
    end)

    -- table utilities: keys, values, filter, map
    harness.it("provides functional table utilities", function()
        local tbl = { a = 1, b = 2, c = 3 }
        local k = helpers.keys(tbl)
        local v = helpers.values(tbl)
        harness.assert_equal(3, #k)
        harness.assert_equal(3, #v)

        local nums = {1, 2, 3, 4, 5, 6}
        local evens = helpers.filter(nums, function(x) return x % 2 == 0 end)
        harness.assert_table_equal({2, 4, 6}, evens)

        local doubled = helpers.map(nums, function(x) return x * 2 end)
        harness.assert_table_equal({2, 4, 6, 8, 10, 12}, doubled)
    end)
end)

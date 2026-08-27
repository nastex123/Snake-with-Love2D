-- Test Suite: Scope 04 - Core Timers Manager & Tween Engine
-- Comprehensive unit tests covering after, every, tween, cancel, clear, pooling, update, easings, and error resilience.

local harness = require("tests.test_harness")
local timers = require("core.timers")

harness.describe("Core Timers: 'after' One-Shot Timers", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should trigger callback once after exact duration", function()
        local triggered = 0
        local t = timers.after(0.5, function()
            triggered = triggered + 1
        end)

        harness.assert_true(timers.isActive(t), "Timer should be active initially")
        harness.assert_equal(1, timers.getActiveCount(), "Active count should be 1")

        timers.update(0.2)
        harness.assert_equal(0, triggered, "Should not trigger at 0.2s")
        harness.assert_true(timers.isActive(t), "Timer should still be active")

        timers.update(0.3)
        harness.assert_equal(1, triggered, "Should trigger once at 0.5s")
        harness.assert_false(timers.isActive(t), "Timer should become inactive after firing")
        harness.assert_equal(0, timers.getActiveCount(), "Active count should be 0")

        -- Subsequent updates should not trigger again
        timers.update(1.0)
        harness.assert_equal(1, triggered, "Should not trigger again")
    end)

    harness.it("should handle 0 delay by firing on first update", function()
        local triggered = 0
        local t = timers.after(0, function()
            triggered = triggered + 1
        end)

        harness.assert_equal(0, triggered, "Should not trigger before update")
        timers.update(0.016)
        harness.assert_equal(1, triggered, "Should trigger on first update")
        harness.assert_false(timers.isActive(t), "Timer should be inactive")
    end)

    harness.it("should execute multiple one-shot timers in chronological order", function()
        local order = {}
        timers.after(0.3, function() table.insert(order, "t3") end)
        timers.after(0.1, function() table.insert(order, "t1") end)
        timers.after(0.2, function() table.insert(order, "t2") end)

        timers.update(0.15)
        harness.assert_equal(1, #order, "Only t1 should fire")
        harness.assert_equal("t1", order[1], "t1 should be first")

        timers.update(0.1)
        harness.assert_equal(2, #order, "t1 and t2 should have fired")
        harness.assert_equal("t2", order[2], "t2 should be second")

        timers.update(0.1)
        harness.assert_equal(3, #order, "All 3 should have fired")
        harness.assert_equal("t3", order[3], "t3 should be third")
    end)
end)

harness.describe("Core Timers: 'every' Periodic Timers", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should trigger callback repeatedly at each interval", function()
        local count = 0
        local t = timers.every(0.1, function()
            count = count + 1
        end)

        harness.assert_true(timers.isActive(t), "Timer should be active")

        timers.update(0.05)
        harness.assert_equal(0, count, "No tick at 0.05s")

        timers.update(0.05)
        harness.assert_equal(1, count, "Tick 1 at 0.10s")

        timers.update(0.1)
        harness.assert_equal(2, count, "Tick 2 at 0.20s")

        timers.update(0.1)
        harness.assert_equal(3, count, "Tick 3 at 0.30s")
        harness.assert_true(timers.isActive(t), "Timer should stay active")
    end)

    harness.it("should handle multiple ticks in a single large dt frame", function()
        local count = 0
        timers.every(0.1, function()
            count = count + 1
        end)

        -- Simulating a frame lag of 0.35s (should trigger 3 ticks and leave 0.05 accum)
        timers.update(0.35)
        harness.assert_equal(3, count, "Should have triggered 3 times")

        -- Advance another 0.06s (total accum now 0.11s -> 1 more tick)
        timers.update(0.06)
        harness.assert_equal(4, count, "Should have triggered 4th time")
    end)

    harness.it("should clamp maximum ticks per frame to prevent freeze during massive lag", function()
        local count = 0
        timers.every(0.001, function()
            count = count + 1
        end)

        -- Advance 10 seconds in 1 frame (without clamp, this would loop 10,000 times)
        timers.update(10.0)
        harness.assert_lte(count, 20, "Should clamp to at most 20 ticks per frame")
    end)
end)

harness.describe("Core Timers: Tween Engine & Interpolation", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should linearly interpolate single and multiple numeric values", function()
        local obj = { x = 0, y = 50, alpha = 0.0 }
        local completed = false

        local tw = timers.tween(1.0, obj, { x = 100, y = 150, alpha = 1.0 }, "linear", function()
            completed = true
        end)

        harness.assert_true(timers.isActive(tw), "Tween should be active")

        timers.update(0.5)
        harness.assert_almost_equal(50, obj.x, 0.001, "x should be halfway (50)")
        harness.assert_almost_equal(100, obj.y, 0.001, "y should be halfway (100)")
        harness.assert_almost_equal(0.5, obj.alpha, 0.001, "alpha should be halfway (0.5)")
        harness.assert_false(completed, "Should not complete yet")

        timers.update(0.5)
        harness.assert_almost_equal(100, obj.x, 0.0001, "x should reach exact target 100")
        harness.assert_almost_equal(150, obj.y, 0.0001, "y should reach exact target 150")
        harness.assert_almost_equal(1.0, obj.alpha, 0.0001, "alpha should reach exact target 1.0")
        harness.assert_true(completed, "onComplete callback should be called")
        harness.assert_false(timers.isActive(tw), "Tween should become inactive after completion")
    end)

    harness.it("should handle duration 0 by applying target immediately and invoking callback", function()
        local obj = { val = 10 }
        local done = false

        timers.tween(0, obj, { val = 99 }, "linear", function()
            done = true
        end)

        harness.assert_equal(99, obj.val, "Target value should apply immediately on duration 0")
        harness.assert_true(done, "Callback should be called immediately")
    end)

    harness.it("should support overloaded signature (duration, subject, target, onComplete)", function()
        local obj = { pos = 0 }
        local done = false

        timers.tween(0.4, obj, { pos = 40 }, function()
            done = true
        end)

        timers.update(0.2)
        harness.assert_almost_equal(20, obj.pos, 0.001, "Should interpolate with default linear easing")
        harness.assert_false(done, "Not done yet")

        timers.update(0.2)
        harness.assert_almost_equal(40, obj.pos, 0.001, "Reached target 40")
        harness.assert_true(done, "Callback invoked")
    end)

    harness.it("should support custom easing functions", function()
        local obj = { val = 0 }
        -- Custom step function easing
        local customEase = function(t)
            return t < 0.5 and 0 or 1
        end

        timers.tween(1.0, obj, { val = 100 }, customEase)

        timers.update(0.4)
        harness.assert_almost_equal(0, obj.val, 0.001, "Custom ease returns 0 before 0.5")

        timers.update(0.2)
        harness.assert_almost_equal(100, obj.val, 0.001, "Custom ease returns 1 after 0.5")
    end)

    harness.it("should fall back gracefully to linear on invalid or unknown easing string", function()
        local obj = { val = 0 }
        timers.tween(1.0, obj, { val = 100 }, "nonExistentEasing123")

        timers.update(0.5)
        harness.assert_almost_equal(50, obj.val, 0.001, "Should fall back to linear")
    end)

    harness.it("should handle non-table subjects or targets safely without throwing errors", function()
        local ok1 = timers.tween(1.0, nil, { x = 10 })
        local ok2 = timers.tween(1.0, { x = 10 }, nil)
        harness.assert_nil(ok1, "Should return nil for nil subject")
        harness.assert_nil(ok2, "Should return nil for nil target")
    end)
end)

harness.describe("Core Timers: Easing Curves Coverage", function()
    harness.it("should evaluate all standard easing functions at t=0, t=0.5, t=1", function()
        local easingNames = {
            "linear", "quadIn", "quadOut", "quadInOut",
            "cubicIn", "cubicOut", "cubicInOut",
            "quartIn", "quartOut", "quartInOut",
            "quintIn", "quintOut", "quintInOut",
            "sineIn", "sineOut", "sineInOut",
            "expoIn", "expoOut", "expoInOut",
            "circIn", "circOut", "circInOut",
            "backIn", "backOut", "backInOut",
            "bounceIn", "bounceOut", "bounceInOut",
            "elasticIn", "elasticOut", "elasticInOut"
        }

        for _, name in ipairs(easingNames) do
            local fn = timers.easings[name]
            harness.assert_not_nil(fn, "Easing '" .. name .. "' must exist in timers.easings")
            local v0 = fn(0)
            local v1 = fn(1)
            harness.assert_almost_equal(0, v0, 0.001, name .. "(0) should be 0")
            harness.assert_almost_equal(1, v1, 0.001, name .. "(1) should be 1")
            local mid = fn(0.5)
            harness.assert_type(mid, "number", name .. "(0.5) must return a number")
        end
    end)
end)

harness.describe("Core Timers: Cancellation and Clear", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should cancel one-shot timer via timers.cancel(t)", function()
        local triggered = false
        local t = timers.after(0.5, function()
            triggered = true
        end)

        timers.update(0.2)
        timers.cancel(t)

        harness.assert_false(timers.isActive(t), "Timer should not be active after cancel")
        timers.update(0.5)
        harness.assert_false(triggered, "Cancelled timer callback must not run")
    end)

    harness.it("should cancel timer via timer:cancel() object method", function()
        local triggered = false
        local t = timers.after(0.5, function()
            triggered = true
        end)

        t:cancel()
        harness.assert_false(t:isActive(), "Method t:isActive() should return false")
        timers.update(0.6)
        harness.assert_false(triggered, "Callback must not run after t:cancel()")
    end)

    harness.it("should cancel looping timer and stop subsequent ticks", function()
        local count = 0
        local t = timers.every(0.1, function()
            count = count + 1
        end)

        timers.update(0.25)
        harness.assert_equal(2, count, "Should tick twice")

        timers.cancel(t)
        timers.update(0.5)
        harness.assert_equal(2, count, "Should not tick again after cancel")
    end)

    harness.it("should cancel active tween preserving current values and skipping onComplete", function()
        local obj = { x = 0 }
        local done = false
        local tw = timers.tween(1.0, obj, { x = 100 }, "linear", function()
            done = true
        end)

        timers.update(0.3)
        harness.assert_almost_equal(30, obj.x, 0.001, "x should be at 30 before cancel")
        tw:cancel()

        timers.update(1.0)
        harness.assert_almost_equal(30, obj.x, 0.001, "x should freeze at 30 after cancel")
        harness.assert_false(done, "Tween onComplete must not be called after cancellation")
    end)

    harness.it("should be safe and idempotent to cancel nil or already cancelled timers", function()
        local ok, err = pcall(function()
            timers.cancel(nil)
            timers.cancel({})
            local t = timers.after(0.1, function() end)
            t:cancel()
            t:cancel()
            timers.cancel(t)
        end)
        harness.assert_true(ok, "Repeated/nil cancels should never error: " .. tostring(err))
    end)

    harness.it("should cancel and clear all active timers via timers.clear()", function()
        local c1, c2, c3 = false, false, false
        timers.after(0.2, function() c1 = true end)
        timers.every(0.1, function() c2 = true end)
        timers.tween(0.5, { v = 0 }, { v = 10 }, "linear", function() c3 = true end)

        harness.assert_equal(3, timers.getActiveCount(), "Should have 3 active timers")
        timers.clear()
        harness.assert_equal(0, timers.getActiveCount(), "Active count should be 0 after clear")

        timers.update(1.0)
        harness.assert_false(c1, "c1 should not trigger")
        harness.assert_false(c2, "c2 should not trigger")
        harness.assert_false(c3, "c3 should not trigger")
    end)
end)

harness.describe("Core Timers: Mutation During Update Loop", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should allow a timer to cancel itself inside its callback", function()
        local ticks = 0
        local t
        t = timers.every(0.1, function()
            ticks = ticks + 1
            if ticks == 2 then
                t:cancel()
            end
        end)

        timers.update(0.5)
        harness.assert_equal(2, ticks, "Timer should tick exactly 2 times and self-cancel")
        harness.assert_false(timers.isActive(t), "Timer should be inactive")
        harness.assert_equal(0, timers.getActiveCount(), "Active count should be 0")
    end)

    harness.it("should allow a callback to cancel another timer ahead in the queue", function()
        local t2_ran = false
        local t2
        local t1 = timers.after(0.1, function()
            timers.cancel(t2)
        end)
        t2 = timers.after(0.1, function()
            t2_ran = true
        end)

        timers.update(0.15)
        harness.assert_false(t2_ran, "t2 should have been cancelled by t1 and not run")
        harness.assert_equal(0, timers.getActiveCount(), "All timers should be cleaned up")
    end)

    harness.it("should allow a callback to schedule new timers without affecting current frame", function()
        local t2_ran = false
        timers.after(0.1, function()
            timers.after(0.1, function()
                t2_ran = true
            end)
        end)

        timers.update(0.1)
        harness.assert_false(t2_ran, "Newly scheduled timer should not run in same frame")
        harness.assert_equal(1, timers.getActiveCount(), "New timer should be active")

        timers.update(0.1)
        harness.assert_true(t2_ran, "New timer should run on the subsequent frame")
    end)

    harness.it("should allow a callback to call timers.clear() safely", function()
        local t2_ran = false
        timers.after(0.1, function()
            timers.clear()
        end)
        timers.after(0.1, function()
            t2_ran = true
        end)

        local ok, err = pcall(function()
            timers.update(0.15)
        end)

        harness.assert_true(ok, "timers.clear() inside callback should not crash update loop: " .. tostring(err))
        harness.assert_false(t2_ran, "t2 should not run because clear was called")
        harness.assert_equal(0, timers.getActiveCount(), "Active count should be 0")
    end)
end)

harness.describe("Core Timers: Object Pooling & Zero-Leak Recycling", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should recycle timer objects to free pool after completion", function()
        harness.assert_equal(0, timers.getFreeCount(), "Pool should be empty initially")

        timers.after(0.1, function() end)
        timers.after(0.1, function() end)
        harness.assert_equal(2, timers.getActiveCount(), "2 active timers")

        timers.update(0.15)
        harness.assert_equal(0, timers.getActiveCount(), "0 active timers after firing")
        harness.assert_equal(2, timers.getFreeCount(), "2 recycled timers in free pool")

        -- Re-acquiring should draw from the pool without increasing memory footprint
        local t3 = timers.after(0.5, function() end)
        harness.assert_equal(1, timers.getActiveCount(), "1 active timer")
        harness.assert_equal(1, timers.getFreeCount(), "1 timer left in free pool")
    end)

    harness.it("should clear references on recycled objects to prevent closure leaks", function()
        local capturedObj = { name = "large_object" }
        local t = timers.after(0.1, function()
            return capturedObj.name
        end)

        timers.update(0.15)
        -- The timer has finished and been recycled
        harness.assert_nil(t.callback, "Callback reference must be cleared on recycled timer")
        harness.assert_nil(t.subject, "Subject reference must be cleared")
        harness.assert_nil(t.target, "Target reference must be cleared")
        harness.assert_nil(t.onComplete, "onComplete reference must be cleared")
    end)

    harness.it("should recycle cancelled timers into the pool without duplicates", function()
        local t1 = timers.after(1.0, function() end)
        local t2 = timers.every(1.0, function() end)
        harness.assert_equal(2, timers.getActiveCount(), "2 active timers")

        timers.cancel(t1)
        timers.cancel(t2)

        -- Inactive timers are swept and placed in free pool during update
        timers.update(0.016)
        harness.assert_equal(0, timers.getActiveCount(), "0 active timers")
        harness.assert_equal(2, timers.getFreeCount(), "Both cancelled timers returned to pool")
    end)
end)

harness.describe("Core Timers: Error Resilience & Edge Cases", function()
    harness.before_each(function()
        timers.reset()
    end)

    harness.it("should catch errors in callback without crashing update or stopping other timers", function()
        local t2_ran = false
        timers.after(0.1, function()
            error("Simulated catastrophic timer error in callback")
        end)
        timers.after(0.1, function()
            t2_ran = true
        end)

        local ok, err = pcall(function()
            timers.update(0.15)
        end)

        harness.assert_true(ok, "timers.update should not propagate callback errors: " .. tostring(err))
        harness.assert_true(t2_ran, "Subsequent timers must execute despite previous timer error")
        harness.assert_equal(0, timers.getActiveCount(), "Errored timer should be cleaned up")
    end)

    harness.it("should catch errors in tween onComplete without crashing update", function()
        local obj = { x = 0 }
        timers.tween(0.1, obj, { x = 10 }, "linear", function()
            error("Error in onComplete callback")
        end)

        local ok, err = pcall(function()
            timers.update(0.15)
        end)

        harness.assert_true(ok, "Tween update must survive onComplete error: " .. tostring(err))
        harness.assert_equal(10, obj.x, "Tween property should still reach final target")
        harness.assert_equal(0, timers.getActiveCount(), "Tween should be cleaned up")
    end)

    harness.it("should ignore update with dt <= 0 or nil", function()
        local ran = false
        timers.after(0.1, function() ran = true end)

        timers.update(0)
        timers.update(-0.5)
        timers.update(nil)
        harness.assert_false(ran, "Should not trigger with dt <= 0 or nil")
        harness.assert_equal(1, timers.getActiveCount(), "Timer remains active")
    end)
end)

-- tests/test_scope_29_status_fx.lua — Status Effects Engine (GDD §16)
-- Suite consola-only: nucleo data-driven, ciclo de vida y hook de velocidad.
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
local statusFx = require("systems.statusFx")

harness.describe("Scope 29 - Status core (defs y ciclo)", function()
    harness.it("defines 4 effects with label and color", function()
        for _, id in ipairs({"overdrive", "medusa", "venom", "cryo"}) do
            local d = statusFx.STATUS_DEFS[id]
            harness.assert_not_nil(d, "def " .. id)
            harness.assert_not_nil(d.label, "label " .. id)
            harness.assert_not_nil(d.color, "color " .. id)
        end
    end)

    harness.it("rejects unknown ids", function()
        statusFx.clearAll()
        harness.assert_false(statusFx.apply("no_existe"), "apply false")
        harness.assert_false(statusFx.has("no_existe"), "has false")
        harness.assert_equal(0, statusFx.durationFor("no_existe"), "duration 0")
    end)

    harness.it("apply/has/clear roundtrip with HUD timer entry", function()
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        harness.assert_true(statusFx.apply("overdrive"), "apply true")
        harness.assert_true(statusFx.has("overdrive"), "has after apply")
        harness.assert_false(statusFx.has("medusa"), "other inactive")
        local found = false
        for _, t in ipairs(world.state.activeTimers) do
            if t.id == "status_overdrive" then found = true end
        end
        harness.assert_true(found, "HUD entry status_overdrive")
        statusFx.clear("overdrive")
        harness.assert_false(statusFx.has("overdrive"), "cleared")
        timers.clear()
        statusFx.clearAll()
    end)

    harness.it("durations match config", function()
        harness.assert_equal(constants.STATUS_OVERDRIVE_DURATION, statusFx.durationFor("overdrive"), "overdrive")
        harness.assert_equal(constants.STATUS_MEDUSA_DURATION, statusFx.durationFor("medusa"), "medusa")
        harness.assert_equal(constants.STATUS_VENOM_DURATION, statusFx.durationFor("venom"), "venom")
        harness.assert_equal(constants.STATUS_CRYO_DURATION, statusFx.durationFor("cryo"), "cryo")
    end)

    harness.it("timer expiry clears the flag", function()
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        statusFx.apply("venom", 0.1)
        harness.assert_true(statusFx.has("venom"), "active")
        timers.update(0.2)
        harness.assert_false(statusFx.has("venom"), "expired")
        timers.clear()
        statusFx.clearAll()
    end)

    harness.it("speedMult combines overdrive and cryo", function()
        statusFx.clearAll()
        world.state.activeTimers = {}
        timers.clear()
        harness.assert_equal(1.0, statusFx.speedMult(), "base")
        statusFx.apply("overdrive", 30)
        harness.assert_equal(0.8, statusFx.speedMult(), "overdrive x0.8")
        statusFx.apply("cryo", 30)
        local m = statusFx.speedMult()
        harness.assert_true(m > 1.13 and m < 1.15, "0.8x1.43=" .. tostring(m))
        statusFx.clear("cryo")
        harness.assert_equal(0.8, statusFx.speedMult(), "cryo cleared")
        statusFx.clearAll()
        timers.clear()
    end)

    harness.it("calcSpeed honors status mult", function()
        local playerMod = require("systems.player")
        statusFx.clearAll()
        world.state.activeTimers = {}
        timers.clear()
        local base = playerMod.calcSpeed(0.13, 0)
        statusFx.apply("overdrive", 30)
        local fast = playerMod.calcSpeed(0.13, 0)
        harness.assert_true(fast < base, "overdrive acelera")
        statusFx.clearAll()
        statusFx.apply("cryo", 30)
        local slow = playerMod.calcSpeed(0.13, 0)
        harness.assert_true(slow > base, "cryo frena")
        statusFx.clearAll()
        timers.clear()
    end)
end)

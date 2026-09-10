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

harness.describe("Scope 29 - Overdrive (GDD 16.1)", function()
    harness.it("checkOverdrive triggers at x6 with fresh flag once", function()
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        local applied, fresh = statusFx.checkOverdrive(5)
        harness.assert_false(applied, "x5 no activa")
        harness.assert_false(statusFx.has("overdrive"), "inactivo")
        applied, fresh = statusFx.checkOverdrive(6)
        harness.assert_true(applied and fresh, "x6 activa fresco")
        applied, fresh = statusFx.checkOverdrive(7)
        harness.assert_true(applied and not fresh, "x7 refresca")
        statusFx.clearAll()
        timers.clear()
    end)

    harness.it("head smash destroys chaser without damage", function()
        local enemiesMod = require("entities.enemies")
        local collisions = require("entities.snake.collisions")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        enemiesMod.init()
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        local e = enemiesMod.spawnAt("chaser", 5, 5)
        local col = collisions.checkEnemyCollisions({body = {{x = 5, y = 5}}}, enemiesMod.list)
        harness.assert_equal("death", col.type, "sin overdrive muere")
        enemiesMod.init()
        statusFx.apply("overdrive", 30)
        local e2 = enemiesMod.spawnAt("chaser", 5, 5)
        local col2 = collisions.checkEnemyCollisions({body = {{x = 5, y = 5}}}, enemiesMod.list)
        harness.assert_equal("overdrive_smash", col2.type, "aplasta con overdrive")
        harness.assert_false(e2.alive, "chaser destruido")
        harness.assert_not_nil(col2.result, "kill result attached")
        statusFx.clearAll()
        timers.clear()
        enemiesMod.init()
    end)

    harness.it("head demolishes stone walls while active", function()
        local snakeMod = require("entities.snake")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        world.set("controlMode", "classic")
        local s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.inputQueue = {}
        local walls = {{x = 6, y = 5, type = "wall"}}
        local vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, walls, 0, nil)
        harness.assert_false(vivo, "muro mata sin overdrive")
        statusFx.apply("overdrive", 30)
        local s2 = snakeMod.reset()
        s2.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s2.dirX, s2.dirY = 1, 0
        s2.inputQueue = {}
        local walls2 = {{x = 6, y = 5, type = "wall"}}
        local vivo2 = snakeMod.mover(s2, {x = 20, y = 20}, 32, 18, walls2, 0, nil)
        harness.assert_true(vivo2, "sobrevive con overdrive")
        harness.assert_equal(0, #walls2, "muro demolido")
        statusFx.clearAll()
        timers.clear()
        world.set("controlMode", "tactical")
    end)
end)

harness.describe("Scope 29 - Medusa Tail (GDD 16.2)", function()
    harness.it("trap step petrifies and absorbs the hit", function()
        local snakeMod = require("entities.snake")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        world.set("controlMode", "classic")
        local s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.inputQueue = {}
        local traps = {{x = 6, y = 5, type = "trap"}}
        local vivo = snakeMod.mover(s, {x = 20, y = 20}, 32, 18, traps, 0, nil)
        harness.assert_true(vivo, "trampa petrifica en vez de matar")
        harness.assert_true(statusFx.has("medusa"), "medusa activa")
        statusFx.clearAll()
        timers.clear()
        world.set("controlMode", "tactical")
    end)

    harness.it("locked direction ignores new inputs", function()
        local snakeMod = require("entities.snake")
        local movement = require("entities.snake.movement")
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        local s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.inputQueue = {{x = 0, y = 1}}
        statusFx.apply("medusa", 30)
        movement.encolarDireccion(s, 0, 1)
        harness.assert_equal(1, s.dirX, "dir intacta tras encolar")
        movement.mover(s, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_equal(0, #s.inputQueue, "cola vaciada")
        harness.assert_equal(1, s.dirX, "sigue recto")
        statusFx.clearAll()
        timers.clear()
    end)

    harness.it("granite body shatters any enemy on contact", function()
        local enemiesMod = require("entities.enemies")
        local collisions = require("entities.snake.collisions")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        enemiesMod.init()
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        statusFx.apply("medusa", 30)
        local e = enemiesMod.spawnAt("patroller", 5, 5)
        local col = collisions.checkEnemyCollisions({body = {{x = 5, y = 5}}}, enemiesMod.list)
        harness.assert_equal("medusa_shatter", col.type, "patroller aplastado")
        harness.assert_false(e.alive, "enemigo destruido")
        statusFx.clearAll()
        timers.clear()
        enemiesMod.init()
    end)
end)

harness.describe("Scope 29 - Venom Spore (GDD 16.3)", function()
    harness.it("slime step rolls spore chance", function()
        local snakeMod = require("entities.snake")
        local shop = require("systems.shop")
        local realRandom = love.math.random
        world.reset()
        shop.reset(false)
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        world.set("controlMode", "classic")
        love.math.random = function() return 0.01 end
        local s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.inputQueue = {}
        snakeMod.mover(s, {x = 20, y = 20}, 32, 18, {{x = 6, y = 5, type = "slime"}}, 0, nil)
        harness.assert_true(statusFx.has("venom"), "espora con suerte")
        statusFx.clearAll()
        love.math.random = function() return 0.99 end
        local s2 = snakeMod.reset()
        s2.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s2.dirX, s2.dirY = 1, 0
        s2.inputQueue = {}
        snakeMod.mover(s2, {x = 20, y = 20}, 32, 18, {{x = 6, y = 5, type = "slime"}}, 0, nil)
        harness.assert_false(statusFx.has("venom"), "sin suerte no hay espora")
        love.math.random = realRandom
        statusFx.clearAll()
        timers.clear()
        world.set("controlMode", "tactical")
    end)

    harness.it("controls invert while venom is active", function()
        local snakeMod = require("entities.snake")
        local shop = require("systems.shop")
        local Input = require("core.input")
        local realIsHeld = Input.isHeld
        Input.isHeld = function(d) return d == "up" end
        world.reset()
        shop.reset(false)
        statusFx.clearAll()
        timers.clear()
        world.state.activeTimers = {}
        world.set("controlMode", "classic")
        local s = snakeMod.reset()
        s.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s.dirX, s.dirY = 1, 0
        s.lastMovedDirX, s.lastMovedDirY = 1, 0
        s.inputQueue = {}
        snakeMod.mover(s, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_equal(-1, s.dirY, "arriba sube sin veneno")
        statusFx.apply("venom", 30)
        local s2 = snakeMod.reset()
        s2.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        s2.dirX, s2.dirY = 1, 0
        s2.lastMovedDirX, s2.lastMovedDirY = 1, 0
        s2.inputQueue = {}
        snakeMod.mover(s2, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_equal(1, s2.dirY, "arriba baja con veneno")
        Input.isHeld = realIsHeld
        statusFx.clearAll()
        timers.clear()
        world.set("controlMode", "tactical")
    end)
end)

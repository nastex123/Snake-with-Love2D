-- tests/test_scope_30_combat_ram.lua — Cabezazos contra jefes (GDD §5 rework)
-- Suite consola-only: daño por combo display, rebote y fantasma.
local harness = require("tests.test_harness")
local combatRam = require("systems.combatRam")

harness.describe("Scope 30 - combatRam damage table", function()
    harness.it("deals 0 below min combo x2", function()
        harness.assert_equal(0, combatRam.damageFor(0), "x0")
        harness.assert_equal(0, combatRam.damageFor(1), "x1")
        harness.assert_equal(0, combatRam.damageFor(nil), "nil")
    end)

    harness.it("deals display-1 from x2 up", function()
        harness.assert_equal(1, combatRam.damageFor(2), "x2->1")
        harness.assert_equal(2, combatRam.damageFor(3), "x3->2")
        harness.assert_equal(5, combatRam.damageFor(6), "x6->5")
    end)

    harness.it("caps damage at HEADBUTT_MAX_DMG", function()
        local constants = require("constants")
        local cap = constants.HEADBUTT_MAX_DMG or 4
        harness.assert_equal(cap, combatRam.damageFor(10), "x10 capado")
        harness.assert_equal(cap, combatRam.damageFor(99), "x99 capado")
    end)
end)

harness.describe("Scope 30 - combatRam bounce and ghost", function()
    harness.it("bounce steps head back and grants ghost", function()
        local s = {body = {{x = 5, y = 5}}, dirX = 1, dirY = 0}
        harness.assert_true(combatRam.ram(s, 32, 18), "rebote ok")
        harness.assert_equal(4, s.body[1].x, "retrocede en x")
        harness.assert_equal(5, s.body[1].y, "y intacta")
        harness.assert_true(combatRam.hasGhost(s), "fantasma activo")
    end)

    harness.it("bounce at edge stays but still grants ghost", function()
        local s = {body = {{x = 0, y = 5}}, dirX = 1, dirY = 0}
        harness.assert_true(combatRam.ram(s, 32, 18), "rebote ok")
        harness.assert_equal(0, s.body[1].x, "no sale de la grilla")
        harness.assert_true(combatRam.hasGhost(s), "fantasma activo")
    end)

    harness.it("ghost expires via core.update", function()
        local core = require("entities.snake.core")
        local s = {body = {{x = 5, y = 5}}, dirX = 1, dirY = 0}
        harness.assert_false(combatRam.hasGhost(s), "sin fantasma al inicio")
        combatRam.ram(s, 32, 18)
        harness.assert_true(combatRam.hasGhost(s), "fantasma tras choque")
        core.update(s, 1.0)
        harness.assert_false(combatRam.hasGhost(s), "expira tras 1s")
    end)
end)

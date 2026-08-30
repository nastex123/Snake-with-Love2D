-- tests/test_scope_19_biomes_hazards.lua
-- Unit testing suite for Stage Biomes, Hazard State Machines, and Terrain Physics (Fase 8)

local harness = require("tests.test_harness")
local constants = require("constants")
local obstacles = require("entities.obstacles")
local world = require("world.world")
local populate = require("world.populate")
local particles = require("render.particles")

harness.describe("Biomes Subsystem - Configuration & Properties", function()
    harness.it("defines all 5 biome configurations with required metadata", function()
        harness.assert_not_nil(constants.BIOMES)
        harness.assert_equal(5, #constants.BIOMES)

        -- Stage 1: Catacumbas
        local b1 = constants.BIOMES[1]
        harness.assert_equal("catacumbas", b1.id)
        harness.assert_true(b1.wallWrap)
        harness.assert_false(b1.isIce)
        harness.assert_false(b1.hazardLava)
        harness.assert_false(b1.isSlime)

        -- Stage 2: Cripta Helada
        local b2 = constants.BIOMES[2]
        harness.assert_equal("hielo", b2.id)
        harness.assert_true(b2.wallWrap)
        harness.assert_true(b2.isIce)

        -- Stage 3: Caverna Volcánica
        local b3 = constants.BIOMES[3]
        harness.assert_equal("volcan", b3.id)
        harness.assert_true(b3.hazardLava)

        -- Stage 4: Colmena Tóxica
        local b4 = constants.BIOMES[4]
        harness.assert_equal("colmena", b4.id)
        harness.assert_true(b4.isSlime)

        -- Stage 5: Santuario del Vacío
        local b5 = constants.BIOMES[5]
        harness.assert_equal("vacio", b5.id)
        harness.assert_false(b5.wallWrap, "Stage 5 must NOT have wall wrap (lethal borders)")
    end)
end)

harness.describe("Environmental Hazards - State Machines & Lethality", function()
    harness.before_each(function()
        obstacles.init()
    end)

    harness.it("manages dynamic lava fissure warning and active states", function()
        local ok, lava = obstacles.agregar(5, 5, "lava")
        harness.assert_true(ok)
        harness.assert_equal("cooldown", lava.state)

        -- In cooldown, lava is NOT lethal
        local isLethal1 = obstacles.isHazardLethal(5, 5)
        harness.assert_false(isLethal1)

        -- Advance timer through cooldown to warning
        obstacles.update(lava.timer + 0.1)
        harness.assert_equal("warning", lava.state)
        local isLethal2 = obstacles.isHazardLethal(5, 5)
        harness.assert_false(isLethal2, "Lava in warning state should telegraph, not damage yet")

        -- Advance timer through warning to active
        obstacles.update(lava.timer + 0.1)
        harness.assert_equal("active", lava.state)
        local isLethal3 = obstacles.isHazardLethal(5, 5)
        harness.assert_true(isLethal3, "Lava in active state must be lethal")

        -- Advance timer through active back to cooldown
        obstacles.update(lava.timer + 0.1)
        harness.assert_equal("cooldown", lava.state)
    end)

    harness.it("manages pressure spike triggering, extension and retraction", function()
        local ok, spike = obstacles.agregar(8, 8, "pressure_spike")
        harness.assert_true(ok)
        harness.assert_equal("idle", spike.state)

        -- Trigger pressure spike on contact
        obstacles.triggerPressureSpike(8, 8)
        harness.assert_equal("warning", spike.state)
        harness.assert_false(obstacles.isHazardLethal(8, 8))

        -- Advance to extended (active spike)
        obstacles.update(spike.timer + 0.1)
        harness.assert_equal("extended", spike.state)
        harness.assert_true(obstacles.isHazardLethal(8, 8), "Extended spike must be lethal")

        -- Advance to retracting
        obstacles.update(spike.timer + 0.1)
        harness.assert_equal("retracting", spike.state)
        harness.assert_false(obstacles.isHazardLethal(8, 8))
    end)

    harness.it("correctly queries terrain modifiers for ice slip and slime slow", function()
        obstacles.agregar(2, 2, "ice")
        obstacles.agregar(4, 4, "slime")
        obstacles.agregar(6, 6, "wall")

        local slipIce, slowIce = obstacles.getTileModifier(2, 2)
        harness.assert_equal(1, slipIce)

        local slipSlime, slowSlime = obstacles.getTileModifier(4, 4)
        harness.assert_equal(0, slipSlime)
        harness.assert_almost_equal(0.5, slowSlime, 0.05)

        local slipWall, slowWall = obstacles.getTileModifier(6, 6)
        harness.assert_equal(0, slipWall)
        harness.assert_equal(1.0, slowWall)
    end)
end)

harness.describe("Biomes Particle Systems", function()
    harness.it("creates biome-specific particle systems without crashing", function()
        if love and love.graphics then
            local p1 = particles.iceSlip(10, 10)
            harness.assert_not_nil(p1)

            local p2 = particles.magmaEmbers(10, 10)
            harness.assert_not_nil(p2)

            local p3 = particles.toxicBubbles(10, 10)
            harness.assert_not_nil(p3)

            local p4 = particles.voidDust(10, 10)
            harness.assert_not_nil(p4)
        end
    end)
end)

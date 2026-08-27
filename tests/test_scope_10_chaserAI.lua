-- tests/test_scope_10_chaserAI.lua
-- Comprehensive Unit Test Suite for entities/chaserAI.lua (Scope 10)
-- Covers: SOLO, DUPLA, MANADA social AI modes, aggro hysteresis, separation radius,
-- ring formation & rotation, early close detection, spread penalty, lerp rotation,
-- and extensive mathematical robustness & edge cases.

local harness = require("tests.test_harness")
local describe = harness.describe
local it = harness.it
local assert_equal = harness.assert_equal
local assert_not_equal = harness.assert_not_equal
local assert_true = harness.assert_true
local assert_false = harness.assert_false
local assert_nil = harness.assert_nil
local assert_not_nil = harness.assert_not_nil
local assert_almost_equal = harness.assert_almost_equal
local assert_gt = harness.assert_gt
local assert_gte = harness.assert_gte
local assert_lt = harness.assert_lt
local assert_lte = harness.assert_lte
local assert_type = harness.assert_type

local chaserAI = require("entities.chaserAI")
local constants = require("constants")

-- Helper to construct a standard clean context
local function createContext(opts)
    opts = opts or {}
    local ctx = {
        list = opts.list or {},
        body = opts.body or {{x = 10, y = 10}, {x = 9, y = 10}},
        head = opts.head or {x = 10, y = 10},
        anchoGrilla = opts.anchoGrilla or constants.MAX_GRID_COLS or 32,
        altoGrilla = opts.altoGrilla or constants.MAX_GRID_ROWS or 18,
        obstaclePos = opts.obstaclePos or {},
        etapa = opts.etapa or 1,
        stageModifier = opts.stageModifier or {},
    }
    return ctx
end

-- Helper to construct a mock chaser
local function createChaser(x, y, extra)
    local e = {
        x = x or 0,
        y = y or 0,
        type = "chaser",
        alive = true,
        aiState = "idle",
        role = "hunter",
        side = 1,
        visRot = 0,
        moveAng = 0,
        ringIndex = 0,
        ringSize = 1,
        ringTighten = false,
        wanderWait = 2,
        promotedTimer = 0,
        moveInterval = constants.ENEMY_CHASER_SPEED or 0.3,
        moveTimer = 0,
    }
    if extra then
        for k, v in pairs(extra) do e[k] = v end
    end
    return e
end

-- =========================================================================
-- SUITE 1: Module Structure, API & Initialization
-- =========================================================================
describe("Scope 10 - Module Structure & Initial State", function()
    it("should export all mandatory API functions", function()
        assert_type(chaserAI, "table", "chaserAI must be a table")
        assert_type(chaserAI.reset, "function", "reset must be a function")
        assert_type(chaserAI.updatePack, "function", "updatePack must be a function")
        assert_type(chaserAI.step, "function", "step must be a function")
        assert_type(chaserAI.speedFactor, "function", "speedFactor must be a function")
        assert_type(chaserAI.getRingState, "function", "getRingState must be a function")
    end)

    it("reset() should restore ringTimer, ringPhase and lastMode to clean defaults", function()
        chaserAI.reset()
        local timer, phase, mode = chaserAI.getRingState()
        assert_equal(0, timer, "ringTimer must reset to 0")
        assert_equal("enc", phase, "ringPhase must reset to 'enc'")
        assert_nil(mode, "lastMode must reset to nil")
    end)
end)

-- =========================================================================
-- SUITE 2: Classification of Social Pack Modes (0, 1, 2, 3, >=4 Chasers)
-- =========================================================================
describe("Scope 10 - Pack Classification & Edge Counts", function()
    it("should handle 0 chasers gracefully without modifying state", function()
        chaserAI.reset()
        local ctx = createContext({ list = {} })
        chaserAI.updatePack(ctx, 0.1)
        local timer, phase, mode = chaserAI.getRingState()
        assert_equal(0, timer)
        assert_equal("enc", phase)
        assert_nil(mode)
    end)

    it("should classify 1 chaser as SOLO mode", function()
        chaserAI.reset()
        local c1 = createChaser(10, 15)
        local ctx = createContext({ list = { c1 } })
        chaserAI.updatePack(ctx, 0.1)
        local _, _, mode = chaserAI.getRingState()
        assert_equal("solo", mode, "1 chaser must classify as 'solo'")
        assert_equal("hunter", c1.role, "Solo chaser must be assigned hunter role")
    end)

    it("should classify 2 chasers as DUPLA mode", function()
        chaserAI.reset()
        local c1 = createChaser(10, 14)
        local c2 = createChaser(10, 16)
        local ctx = createContext({ list = { c1, c2 } })
        chaserAI.updatePack(ctx, 0.1)
        local _, _, mode = chaserAI.getRingState()
        assert_equal("dupla", mode, "2 chasers must classify as 'dupla'")
    end)

    it("should classify 3 chasers as DUPLA mode (1 hunter + 2 flankers)", function()
        chaserAI.reset()
        local c1 = createChaser(10, 12)
        local c2 = createChaser(10, 14)
        local c3 = createChaser(10, 16)
        local ctx = createContext({ list = { c1, c2, c3 } })
        chaserAI.updatePack(ctx, 0.1)
        local _, _, mode = chaserAI.getRingState()
        assert_equal("dupla", mode, "3 chasers must classify as 'dupla'")
    end)

    it("should classify 4 or more chasers as MANADA mode", function()
        chaserAI.reset()
        local chasers = {
            createChaser(5, 5),
            createChaser(6, 5),
            createChaser(5, 6),
            createChaser(6, 6)
        }
        local ctx = createContext({ list = chasers })
        chaserAI.updatePack(ctx, 0.1)
        local _, _, mode = chaserAI.getRingState()
        assert_equal("manada", mode, ">=4 chasers must classify as 'manada'")
    end)

    it("should ignore dead chasers (alive == false) and other enemy types", function()
        chaserAI.reset()
        local c1 = createChaser(10, 12)
        local c2_dead = createChaser(10, 14, { alive = false })
        local patroller = { x = 10, y = 15, type = "patroller", alive = true }
        local spawner = { x = 10, y = 16, type = "spawner", alive = true }
        local ctx = createContext({ list = { c1, c2_dead, patroller, spawner } })
        chaserAI.updatePack(ctx, 0.1)
        local _, _, mode = chaserAI.getRingState()
        assert_equal("solo", mode, "Dead chasers and non-chasers must be ignored")
    end)
end)

-- =========================================================================
-- SUITE 3: SOLO Mode Behaviors & Aggro Hysteresis
-- =========================================================================
describe("Scope 10 - SOLO Mode & Aggro Radius Hysteresis", function()
    it("should stay in 'idle' state when distance > CHASER_AGGRO_RADIUS (8)", function()
        chaserAI.reset()
        local c1 = createChaser(10, 20, { aiState = "idle" }) -- dist = 10 to head(10,10)
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)
        assert_equal("idle", c1.aiState, "Chaser outside aggro radius must remain idle")
        assert_equal("hunter", c1.role)
    end)

    it("should enter 'chase' state when distance <= CHASER_AGGRO_RADIUS (8)", function()
        chaserAI.reset()
        local c1 = createChaser(10, 18, { aiState = "idle" }) -- dist = 8 to head(10,10)
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)
        assert_equal("chase", c1.aiState, "Chaser within aggro radius (8) must switch to chase")
        assert_equal("hunter", c1.role)
    end)

    it("should exhibit hysteresis: remain in 'chase' when dist is between 8 and 10", function()
        chaserAI.reset()
        local c1 = createChaser(10, 19, { aiState = "chase" }) -- dist = 9 to head(10,10)
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)
        assert_equal("chase", c1.aiState, "Chaser already in chase must remain in chase at dist 9 (hysteresis <= 10)")
    end)

    it("should drop back to 'idle' when distance exceeds aggroOut (> 10)", function()
        chaserAI.reset()
        local c1 = createChaser(10, 21, { aiState = "chase" }) -- dist = 11 to head(10,10)
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)
        assert_equal("idle", c1.aiState, "Chaser beyond aggroOut (10) must drop to idle")
    end)

    it("single chaser in chase mode should step directly toward head", function()
        chaserAI.reset()
        local c1 = createChaser(10, 15, { aiState = "chase" })
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.step(c1, ctx)
        -- Manhattan distance must decrease from 5 to 4
        local newDist = math.abs(c1.x - 10) + math.abs(c1.y - 10)
        assert_equal(4, newDist, "Step toward head must reduce distance by 1")
    end)
end)

-- =========================================================================
-- SUITE 4: DUPLA Mode (Hunter & Flankers Geometry & Leader Promotion)
-- =========================================================================
describe("Scope 10 - DUPLA Mode & Flanking Roles", function()
    it("should sort chasers by distance to head and assign roles accordingly", function()
        chaserAI.reset()
        local farChaser = createChaser(10, 16, { aiState = "chase" })   -- dist = 6
        local closeChaser = createChaser(10, 13, { aiState = "chase" }) -- dist = 3
        local ctx = createContext({ list = { farChaser, closeChaser }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)

        assert_equal("hunter", closeChaser.role, "Closest chaser must be leader hunter")
        assert_equal("chase", closeChaser.aiState)

        assert_equal("flanker", farChaser.role, "Secondary chaser must be flanker")
        assert_equal("flank", farChaser.aiState)
        assert_equal(1, farChaser.side, "First flanker (index 2) must have side = 1")
    end)

    it("in 3-chaser DUPLA mode, flankers must alternate left/right sides (1 and -1)", function()
        chaserAI.reset()
        local c1 = createChaser(10, 12, { aiState = "chase" }) -- dist = 2
        local c2 = createChaser(10, 14, { aiState = "chase" }) -- dist = 4
        local c3 = createChaser(10, 16, { aiState = "chase" }) -- dist = 6
        local ctx = createContext({ list = { c1, c2, c3 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)

        assert_equal("hunter", c1.role)
        assert_equal("flanker", c2.role)
        assert_equal(1, c2.side, "Chaser 2 must flank on side 1")
        assert_equal("flanker", c3.role)
        assert_equal(-1, c3.side, "Chaser 3 must flank on side -1")
    end)

    it("flanker should compute perpendicular flank position based on snake movement vector", function()
        chaserAI.reset()
        -- Snake body: head at (10, 10), body[2] at (9, 10) -> moving in direction (+1, 0) (East)
        local flanker = createChaser(15, 15, { aiState = "flank", side = 1 })
        local leader = createChaser(10, 11, { aiState = "chase" })
        local ctx = createContext({
            list = { leader, flanker },
            body = { { x = 10, y = 10 }, { x = 9, y = 10 } },
            head = { x = 10, y = 10 },
        })
        chaserAI.updatePack(ctx, 0.1)
        local initialDist = math.abs(flanker.x - 11) + math.abs(flanker.y - 12)
        chaserAI.step(flanker, ctx)
        local newDist = math.abs(flanker.x - 11) + math.abs(flanker.y - 12)
        assert_lte(newDist, initialDist, "Flanker must step toward its designated flank target")
    end)

    it("should promote flanker to leader hunter when previous leader dies with promotedTimer = 0.5", function()
        chaserAI.reset()
        local leader = createChaser(10, 12, { aiState = "chase", role = "hunter" })
        local flanker = createChaser(10, 15, { aiState = "flank", role = "flanker" })
        local ctx = createContext({ list = { leader, flanker }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)

        assert_equal("hunter", leader.role)
        assert_equal("flanker", flanker.role)

        -- Leader is eliminated
        leader.alive = false
        chaserAI.updatePack(ctx, 0.05)

        assert_equal("hunter", flanker.role, "Surviving flanker must be promoted to hunter")
        assert_equal("chase", flanker.aiState)
        assert_gt(flanker.promotedTimer, 0.4, "Promotion must set promotedTimer around 0.5")
    end)
end)

-- =========================================================================
-- SUITE 5: MANADA Mode & Ring Cycle Phases (enc -> flash -> dash -> reform)
-- =========================================================================
describe("Scope 10 - MANADA Mode & Ring State Machine", function()
    it("should initialize in 'enc' (encircle) phase with ringTighten = false", function()
        chaserAI.reset()
        local chasers = {
            createChaser(5, 5), createChaser(15, 5),
            createChaser(5, 15), createChaser(15, 15)
        }
        local ctx = createContext({ list = chasers, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)

        local timer, phase, mode = chaserAI.getRingState()
        assert_equal("manada", mode)
        assert_equal("enc", phase)
        for _, c in ipairs(chasers) do
            assert_equal("encircle", c.aiState)
            assert_false(c.ringTighten)
            assert_equal(4, c.ringSize)
        end
    end)

    it("should transition into 'flash' phase when timer advances past 57.5% of cycle", function()
        chaserAI.reset()
        local chasers = {
            createChaser(1, 1), createChaser(2, 1),
            createChaser(1, 2), createChaser(2, 2)
        }
        local ctx = createContext({ list = chasers, head = { x = 10, y = 10 } })
        local cycle = constants.CHASER_RING_CYCLE or 8

        -- Advance timer to flash threshold (58% of cycle = 4.64s)
        chaserAI.updatePack(ctx, cycle * 0.58)

        local timer, phase = chaserAI.getRingState()
        assert_equal("flash", phase, "Ring phase must be 'flash'")
        for _, c in ipairs(chasers) do
            assert_equal("close", c.aiState)
            assert_true(c.ringTighten, "ringTighten must be true during flash phase")
        end
    end)

    it("should transition into 'dash' phase when timer advances past 70% of cycle", function()
        chaserAI.reset()
        local chasers = {
            createChaser(1, 1), createChaser(2, 1),
            createChaser(1, 2), createChaser(2, 2)
        }
        local ctx = createContext({ list = chasers, head = { x = 10, y = 10 } })
        local cycle = constants.CHASER_RING_CYCLE or 8

        -- Advance timer to dash threshold (72% of cycle = 5.76s)
        chaserAI.updatePack(ctx, cycle * 0.72)

        local timer, phase = chaserAI.getRingState()
        assert_equal("dash", phase, "Ring phase must be 'dash'")
        for _, c in ipairs(chasers) do
            assert_equal("close", c.aiState)
            assert_false(c.ringTighten, "ringTighten must be false during dash phase")
        end
    end)

    it("should transition into 'reform' phase when timer advances past 77% of cycle", function()
        chaserAI.reset()
        local chasers = {
            createChaser(1, 1), createChaser(2, 1),
            createChaser(1, 2), createChaser(2, 2)
        }
        local ctx = createContext({ list = chasers, head = { x = 10, y = 10 } })
        local cycle = constants.CHASER_RING_CYCLE or 8

        -- Advance timer to reform threshold (80% of cycle = 6.4s)
        chaserAI.updatePack(ctx, cycle * 0.80)

        local timer, phase = chaserAI.getRingState()
        assert_equal("reform", phase, "Ring phase must be 'reform'")
        for _, c in ipairs(chasers) do
            assert_equal("encircle", c.aiState)
            assert_false(c.ringTighten)
        end
    end)

    it("should loop back to 'enc' upon reaching full cycle length", function()
        chaserAI.reset()
        local chasers = {
            createChaser(1, 1), createChaser(2, 1),
            createChaser(1, 2), createChaser(2, 2)
        }
        local ctx = createContext({ list = chasers, head = { x = 10, y = 10 } })
        local cycle = constants.CHASER_RING_CYCLE or 8

        -- Advance full cycle + 0.1s
        chaserAI.updatePack(ctx, cycle + 0.1)

        local timer, phase = chaserAI.getRingState()
        assert_equal("enc", phase, "Ring phase must loop back to 'enc'")
        assert_almost_equal(0.1, timer, 0.001)
    end)
end)

-- =========================================================================
-- SUITE 6: MANADA Mode Early Close Trigger (>= 60% Slot Occupation)
-- =========================================================================
describe("Scope 10 - Early Close Trigger (60% Ring Formation)", function()
    it("should trigger early flash close when 3 of 4 chasers (75% >= 60%) reach their ring slots", function()
        chaserAI.reset()
        local head = { x = 10, y = 10 }
        local ctx = createContext({ head = head, anchoGrilla = 32, altoGrilla = 18 })

        -- Base radius in standard grid: min(32, 18)/6 = 3
        -- 4 slots evenly spaced around head (10, 10) with r = 3:
        -- a = 0 -> (13, 10)
        -- a = pi/2 -> (10, 13)
        -- a = pi -> (7, 10)
        -- a = 3pi/2 -> (10, 7)
        local c1 = createChaser(13, 10) -- slot 0 exact
        local c2 = createChaser(10, 13) -- slot 1 exact
        local c3 = createChaser(7, 10)  -- slot 2 exact
        local c4 = createChaser(0, 0)   -- far away

        ctx.list = { c1, c2, c3, c4 }

        -- Update with tiny dt (0.01s)
        chaserAI.updatePack(ctx, 0.01)

        local timer, phase = chaserAI.getRingState()
        assert_equal("flash", phase, "Early close must trigger 'flash' phase when 75% in position")
        assert_almost_equal((constants.CHASER_RING_CYCLE or 8) * 0.575, timer, 0.01)
    end)

    it("should NOT trigger early close if only 1 of 4 chasers (25% < 60%) is in position", function()
        chaserAI.reset()
        local head = { x = 10, y = 10 }
        local ctx = createContext({ head = head, anchoGrilla = 32, altoGrilla = 18 })

        local c1 = createChaser(13, 10) -- slot 0 exact
        local c2 = createChaser(0, 0)
        local c3 = createChaser(0, 5)
        local c4 = createChaser(5, 0)

        ctx.list = { c1, c2, c3, c4 }

        chaserAI.updatePack(ctx, 0.01)

        local _, phase = chaserAI.getRingState()
        assert_equal("enc", phase, "Early close must NOT trigger when only 25% in position")
    end)
end)

-- =========================================================================
-- SUITE 7: Movement Navigation, Obstacle Avoidance & Spread Penalty
-- =========================================================================
describe("Scope 10 - Movement Navigation & Anti-Stacking Spread Penalty", function()
    it("should strictly avoid solid obstacles", function()
        chaserAI.reset()
        local c1 = createChaser(10, 11, { aiState = "chase" })
        -- Head at (10, 10); obstacle blocking direct path at (10, 10) or (10, 10)
        local obstacles = { { x = 10, y = 10 } }
        local ctx = createContext({
            list = { c1 },
            head = { x = 10, y = 10 },
            obstaclePos = obstacles,
        })

        chaserAI.step(c1, ctx)
        -- Must not step into (10, 10)
        assert_false(c1.x == 10 and c1.y == 10, "Chaser must never step onto an obstacle tile")
    end)

    it("should strictly avoid stepping onto another living enemy", function()
        chaserAI.reset()
        local c1 = createChaser(10, 12, { aiState = "chase" })
        local c2 = createChaser(10, 11, { aiState = "chase" })
        local ctx = createContext({
            list = { c1, c2 },
            head = { x = 10, y = 10 },
        })

        chaserAI.step(c1, ctx)
        -- c1 must not move onto c2's cell (10, 11)
        assert_false(c1.x == 10 and c1.y == 11, "Chaser must never step onto another enemy tile")
    end)

    it("should apply spread penalty to disperse when multiple chasers are clustered", function()
        chaserAI.reset()
        -- Target is straight ahead at (10, 5)
        -- c1 at (10, 10). Two nearby chasers at (10, 8) and (10, 9)
        local c1 = createChaser(10, 10, { aiState = "chase" })
        local c2 = createChaser(10, 9)
        local c3 = createChaser(10, 8)
        local ctx = createContext({
            list = { c1, c2, c3 },
            head = { x = 10, y = 5 },
        })

        chaserAI.step(c1, ctx)
        -- c1 should choose left or right to route around rather than stay blocked/crowded
        assert_true(c1.x ~= 10 or c1.y ~= 9, "Chaser should flank around crowded line")
    end)

    it("should update e.moveAng with proper atan2 angle upon movement", function()
        chaserAI.reset()
        local c1 = createChaser(10, 12, { aiState = "chase" })
        local ctx = createContext({
            list = { c1 },
            head = { x = 10, y = 8 },
        })
        chaserAI.step(c1, ctx)
        -- Moving North: dx = 0, dy = -1 -> atan2(-1, 0) = -pi/2
        assert_almost_equal(-math.pi / 2, c1.moveAng, 0.001, "moveAng must correspond to movement direction")
    end)

    it("should remain in place safely if completely surrounded by obstacles", function()
        chaserAI.reset()
        local c1 = createChaser(5, 5, { aiState = "chase" })
        local obstacles = {
            { x = 5, y = 4 }, -- North
            { x = 5, y = 6 }, -- South
            { x = 4, y = 5 }, -- West
            { x = 6, y = 5 }, -- East
        }
        local ctx = createContext({
            list = { c1 },
            head = { x = 10, y = 10 },
            obstaclePos = obstacles,
        })
        chaserAI.step(c1, ctx)
        assert_equal(5, c1.x, "Boxed-in chaser must remain in place X")
        assert_equal(5, c1.y, "Boxed-in chaser must remain in place Y")
    end)
end)

-- =========================================================================
-- SUITE 8: Visual Rotation, Lerp, and Spin States
-- =========================================================================
describe("Scope 10 - Visual Rotation & Lerp Animations", function()
    it("should spin at CHASER_IDLE_SPIN rate in 'idle' state", function()
        chaserAI.reset()
        local c1 = createChaser(0, 0, { aiState = "idle", visRot = 0 })
        local ctx = createContext({ list = { c1 }, head = { x = 20, y = 20 } })
        local dt = 0.5
        chaserAI.updatePack(ctx, dt)
        local expectedRot = (0.5 * (constants.CHASER_IDLE_SPIN or 0.7)) % (math.pi * 2)
        assert_almost_equal(expectedRot, c1.visRot, 0.001, "Idle chaser must rotate with idle spin")
    end)

    it("should spin fast at CHASER_CLOSE_SPIN rate in 'close' state", function()
        chaserAI.reset()
        local chasers = {
            createChaser(1, 1), createChaser(2, 1),
            createChaser(1, 2), createChaser(2, 2)
        }
        local ctx = createContext({ list = chasers, head = { x = 10, y = 10 } })
        -- Trigger dash phase
        chaserAI.updatePack(ctx, (constants.CHASER_RING_CYCLE or 8) * 0.72)
        local c1 = chasers[1]
        c1.visRot = 0
        chaserAI.updatePack(ctx, 0.1)
        local expectedSpin = (0.1 * (constants.CHASER_CLOSE_SPIN or 10)) % (math.pi * 2)
        assert_almost_equal(expectedSpin, c1.visRot, 0.001, "Close chaser must rotate with fast close spin")
    end)

    it("should lerp rotation toward moveAng in 'chase' state", function()
        chaserAI.reset()
        local c1 = createChaser(10, 12, { aiState = "chase", visRot = 0, moveAng = math.pi })
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        local dt = 0.05
        chaserAI.updatePack(ctx, dt)
        -- Must advance towards math.pi
        assert_gt(c1.visRot, 0.0, "visRot must advance towards moveAng")
        assert_lte(c1.visRot, math.pi, "visRot must not overshoot moveAng")
    end)
end)

-- =========================================================================
-- SUITE 9: Speed Factor Multipliers
-- =========================================================================
describe("Scope 10 - Speed Factor Multipliers", function()
    it("should return correct speed factors per state", function()
        assert_equal(1.0, chaserAI.speedFactor({ aiState = "chase" }), "Chase speed factor must be 1.0")
        assert_almost_equal(constants.CHASER_PACK_SLOWDOWN or 1.15, chaserAI.speedFactor({ aiState = "encircle" }), 0.001)
        assert_almost_equal(constants.CHASER_PACK_SLOWDOWN or 1.15, chaserAI.speedFactor({ aiState = "flank" }), 0.001)
        assert_equal(0.5, chaserAI.speedFactor({ aiState = "close" }), "Close dash speed factor must be 0.5 (2x fast)")
        assert_equal(1.8, chaserAI.speedFactor({ aiState = "idle" }), "Idle speed factor must be 1.8 (slow wander)")
    end)

    it("should default to 1.0 for nil or unknown state", function()
        assert_equal(1.0, chaserAI.speedFactor(nil))
        assert_equal(1.0, chaserAI.speedFactor({}))
        assert_equal(1.0, chaserAI.speedFactor({ aiState = "unknown_state" }))
    end)
end)

-- =========================================================================
-- SUITE 10: Mathematical Robustness, NaNs, Zero Divisions & Degenerate Contexts
-- =========================================================================
describe("Scope 10 - Mathematical Robustness & Edge Cases", function()
    it("should handle distance 0 between chaser and target without error", function()
        chaserAI.reset()
        local c1 = createChaser(10, 10, { aiState = "chase" })
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)
        chaserAI.step(c1, ctx)
        assert_type(c1.x, "number")
        assert_type(c1.y, "number")
    end)

    it("should handle multiple chasers on the exact same tile without division by zero", function()
        chaserAI.reset()
        local c1 = createChaser(10, 10)
        local c2 = createChaser(10, 10)
        local c3 = createChaser(10, 10)
        local c4 = createChaser(10, 10)
        local ctx = createContext({ list = { c1, c2, c3, c4 }, head = { x = 10, y = 10 } })
        chaserAI.updatePack(ctx, 0.1)
        local _, _, mode = chaserAI.getRingState()
        assert_equal("manada", mode)
    end)

    it("should handle ringSize = 0 or ringIndex = nil without division by zero or NaN", function()
        chaserAI.reset()
        local c1 = createChaser(5, 5, { ringSize = 0, ringIndex = nil, aiState = "encircle" })
        local ctx = createContext({ list = { c1 }, head = { x = 10, y = 10 } })
        chaserAI.step(c1, ctx)
        assert_false(c1.x ~= c1.x, "X must not be NaN")
        assert_false(c1.y ~= c1.y, "Y must not be NaN")
    end)

    it("should handle nil / empty / corrupted context objects safely", function()
        chaserAI.reset()
        -- Entirely nil ctx
        chaserAI.updatePack(nil, 0.1)
        -- Empty ctx
        chaserAI.updatePack({}, 0.1)
        -- Missing head with valid body
        local c1 = createChaser(5, 5)
        local ctx = { list = { c1 }, body = { { x = 8, y = 8 } } }
        chaserAI.updatePack(ctx, 0.1)
        assert_equal("hunter", c1.role)
    end)

    it("should handle dt = 0, dt < 0, or dt = NaN safely", function()
        chaserAI.reset()
        local c1 = createChaser(5, 5, { aiState = "idle" })
        local ctx = createContext({ list = { c1 } })
        chaserAI.updatePack(ctx, 0)
        chaserAI.updatePack(ctx, -1.0)
        local nan = 0 / 0
        chaserAI.updatePack(ctx, nan)
        assert_false(c1.visRot ~= c1.visRot, "visRot must not be NaN")
    end)

    it("should clamp positions strictly inside grid boundaries", function()
        chaserAI.reset()
        local c1 = createChaser(0, 0, { aiState = "chase" })
        local ctx = createContext({
            list = { c1 },
            head = { x = -10, y = -10 },
            anchoGrilla = 10,
            altoGrilla = 10,
        })
        chaserAI.step(c1, ctx)
        assert_gte(c1.x, 0, "Chaser X must stay >= 0")
        assert_lte(c1.x, 9, "Chaser X must stay < anchoGrilla")
        assert_gte(c1.y, 0, "Chaser Y must stay >= 0")
        assert_lte(c1.y, 9, "Chaser Y must stay < altoGrilla")
    end)
end)

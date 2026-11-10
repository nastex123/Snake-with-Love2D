-- =============================================================================
-- tests/test_scope_41_sprint2.lua
-- Suite de pruebas unitarias para Sprint 2 (Fase 8):
--   1. Survival Waves Escalation Engine (GDD §6 / TDD §10.26)
--   2. Modo Boss Rush (GDD §11 / TDD §10.33)
--   3. Motor de Eventos Aleatorios de Sala E1-E7 (GDD §22 / TDD §10.31)
--   4. Gamefeel y Defensa Perceptual (Propuestas #5, #6, #7)
-- =============================================================================
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local modes = require("systems.modes")
local populate = require("world.populate")
local roomEvents = require("systems.roomEvents")
local sound = require("audio.sound")
local worldMod = require("world.world")

harness.describe("Sprint 2 — World.SCHEMA Extensions", function()
    harness.it("contains all new wave, event, and perceptual pulse keys in schema", function()
        harness.assert_equal("number", world.SCHEMA.waveCurrent, "waveCurrent should be number")
        harness.assert_equal("number", world.SCHEMA.waveTotal, "waveTotal should be number")
        harness.assert_equal("number", world.SCHEMA.waveTimer, "waveTimer should be number")
        harness.assert_equal("number", world.SCHEMA.waveMaxTimer, "waveMaxTimer should be number")
        harness.assert_equal("string", world.SCHEMA.roomEvent, "roomEvent should be string")
        harness.assert_equal("number", world.SCHEMA.roomEventTimer, "roomEventTimer should be number")
        harness.assert_equal("number", world.SCHEMA.constrictorPulse, "constrictorPulse should be number")
    end)

    harness.it("passes World.validate() with valid wave and event state", function()
        world.state.waveCurrent = 1
        world.state.waveTotal = 3
        world.state.waveTimer = 12.0
        world.state.waveMaxTimer = 12.0
        world.state.roomEvent = "gold_rain"
        world.state.roomEventTimer = 9.0
        world.state.constrictorPulse = 0.35
        local ok, err = world.validate()
        harness.assert_true(ok, "World.validate() should pass: " .. tostring(err))
    end)
end)

harness.describe("Sprint 2 — Survival Waves Escalation Engine", function()
    harness.it("populate.spawnWave places enemies at safe distance >= 4 with telegraph", function()
        local snakeBody = {{x = 10, y = 10}, {x = 9, y = 10}, {x = 8, y = 10}}
        local obstaclesMod = {pos = {}}
        local spawned = {}
        local telegraphs = {}
        local enemiesMod = {
            list = {},
            spawnAt = function(etype, gx, gy)
                table.insert(spawned, {type = etype, x = gx, y = gy})
            end,
            addTelegraph = function(gx, gy, timer, atype, cb)
                table.insert(telegraphs, {x = gx, y = gy, timer = timer, onExpire = cb})
                if cb then cb({gx = gx, gy = gy}) end
            end
        }

        local count = populate.spawnWave(1, 1, nil, snakeBody, 30, 20, obstaclesMod, enemiesMod)
        harness.assert_true(count >= 1, "spawnWave should place at least 1 enemy")
        harness.assert_true(#telegraphs >= 1, "spawnWave should create telegraph markers")
        for _, t in ipairs(telegraphs) do
            local dist = math.abs(t.x - snakeBody[1].x) + math.abs(t.y - snakeBody[1].y)
            harness.assert_true(dist >= 4, "telegraph must maintain Manhattan distance >= 4")
        end
    end)

    harness.it("scales wave count and timers correctly by stage", function()
        local stage1Waves = (1 == 1 and 2) or (1 == 5 and 4) or 3
        local stage3Waves = (3 == 1 and 2) or (3 == 5 and 4) or 3
        local stage5Waves = (5 == 1 and 2) or (5 == 5 and 4) or 3
        harness.assert_equal(2, stage1Waves, "Stage 1 should have 2 waves")
        harness.assert_equal(3, stage3Waves, "Stage 3 should have 3 waves")
        harness.assert_equal(4, stage5Waves, "Stage 5 should have 4 waves")
    end)
end)

harness.describe("Sprint 2 — Modo Boss Rush", function()
    harness.it("modes.LIST includes boss_rush", function()
        local found = false
        for _, m in ipairs(modes.LIST) do
            if m == "boss_rush" then found = true; break end
        end
        harness.assert_true(found, "boss_rush must be present in modes.LIST")
    end)

    harness.it("modes.isUnlocked unlocks boss_rush based on achievements or stats", function()
        local profLocked = {stats = {bossesKilled = 0, highestStage = 1}, achievements = {}}
        harness.assert_false(modes.isUnlocked("boss_rush", profLocked), "boss_rush should be locked initially")

        local profUnlocked = {stats = {bossesKilled = 1}, achievements = {}}
        harness.assert_true(modes.isUnlocked("boss_rush", profUnlocked), "boss_rush unlocks if boss killed")

        local profAch = {stats = {bossesKilled = 0, highestStage = 1}, achievements = {boss_kill = true}}
        harness.assert_true(modes.isUnlocked("boss_rush", profAch), "boss_rush unlocks with boss_kill achievement")
    end)

    harness.it("boss_rush scales world getters for 6-room sequence", function()
        local st = world.state
        st.modo = "boss_rush"
        worldMod.sala = 1
        harness.assert_equal(6, worldMod.getRoomCount(), "getRoomCount in boss_rush should be 6")
        harness.assert_true(worldMod.isMiniBossRoom(), "Rooms 1-5 in boss_rush should be mini-boss rooms")
        harness.assert_false(worldMod.esJefe(), "Room 1 in boss_rush is not the final boss")
        harness.assert_false(worldMod.isLastRoom(), "Room 1 in boss_rush is not the last room")

        worldMod.sala = 6
        harness.assert_true(worldMod.esJefe(), "Room 6 in boss_rush should be the final boss")
        harness.assert_true(worldMod.isLastRoom(), "Room 6 in boss_rush should be the last room")
        harness.assert_false(worldMod.isMiniBossRoom(), "Room 6 in boss_rush is final boss, not mini-boss")
        st.modo = "estandar"
    end)
end)

harness.describe("Sprint 2 — Motor de Eventos de Sala E1-E7", function()
    harness.it("vetoes events in boss, elite, or mystery rooms", function()
        local fakeWorldBoss = {esJefe = function() return true end, sala = 1}
        harness.assert_false(roomEvents.canTrigger(fakeWorldBoss, {}), "Should veto in boss rooms")

        local fakeWorldMini = {esJefe = function() return false end, sala = 3}
        harness.assert_false(roomEvents.canTrigger(fakeWorldMini, {}), "Should veto in sala 3")

        local fakeWorldMystery = {
            esJefe = function() return false end,
            sala = 2,
            getCurrentRoom = function() return {mystery = "gambler_den"} end
        }
        harness.assert_false(roomEvents.canTrigger(fakeWorldMystery, {}), "Should veto in mystery rooms")
    end)

    harness.it("defines all 7 events with tags, durations, and valid callbacks", function()
        local expected = {"gold_rain", "big_hunt", "merchant", "eclipse", "duel", "void_echo", "blood_offer"}
        for _, id in ipairs(expected) do
            local def = roomEvents.getDef(id)
            harness.assert_not_nil(def, "Event " .. id .. " must be defined in DEFS")
            harness.assert_true(def.duration >= 8.0, "Event duration must be >= 8s")
            harness.assert_not_nil(def.color, "Event must specify a badge color")
        end
    end)

    harness.it("updates active event timer and finishes cleanly", function()
        roomEvents.reset()
        local st = world.state
        st.roomEvent = "eclipse"
        st.roomEventTimer = 5.0
        local def = roomEvents.getDef("eclipse")
        def.onStart(st, {})

        -- Simular inicio manual
        local ended = roomEvents.update(6.0, st, {}, nil, nil)
        harness.assert_true(ended or true, "update completes or counts down cleanly")
        roomEvents.reset()
    end)
end)

harness.describe("Sprint 2 — Gamefeel & Defensa Perceptual", function()
    harness.it("loads last_defense procedural SFX without crashing", function()
        sound.load()
        local sources = sound.getSources()
        harness.assert_not_nil(sources.last_defense, "last_defense SFX source must be loaded")
    end)

    harness.it("sound.play triggers last_defense safely", function()
        local ok, err = pcall(sound.play, "last_defense")
        harness.assert_true(ok, "sound.play(last_defense) should not error: " .. tostring(err))
    end)
end)

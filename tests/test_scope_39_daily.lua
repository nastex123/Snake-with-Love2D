local harness = require("tests.test_harness")
local daily = require("systems.daily")
local gameflow = require("systems.gameflow")
local world = require("core.world")
local persistence = require("systems.persistence")

harness.describe("Daily: reglas de intento y registro", function()
    harness.it("formatea la fecha correctamente", function()
        local ds = daily.getDateString({year = 2026, month = 9, day = 21})
        harness.assert_equal("2026-09-21", ds, "Formato YYYY-MM-DD")
    end)

    harness.it("detecta perfil sin intentos hoy", function()
        local p = {dailyHistory = {}}
        local d = {year = 2026, month = 9, day = 21}
        harness.assert_false(daily.hasAttemptedToday(p, d), "Sin intento")
        harness.assert_nil(daily.getTodayRecord(p, d), "Sin record")
    end)

    harness.it("registra un intento y bloquea nuevo intento para esa fecha", function()
        local p = {dailyHistory = {}}
        local d = {year = 2026, month = 9, day = 21}
        local entry = daily.recordRun(p, 1450, 3, 7, d)
        harness.assert_equal(1450, entry.score, "Score guardado")
        harness.assert_equal(3, entry.stage, "Stage guardado")
        harness.assert_equal(7, entry.roomsCleared, "Rooms guardado")
        harness.assert_true(daily.hasAttemptedToday(p, d), "Ya intentado hoy")
        local rec = daily.getTodayRecord(p, d)
        harness.assert_equal(1450, rec.score, "Record coincidente")
    end)

    harness.it("ordena el historial por fecha descendente y respeta maxEntries", function()
        local p = {
            dailyHistory = {
                ["2026-09-18"] = {date = "2026-09-18", score = 100},
                ["2026-09-20"] = {date = "2026-09-20", score = 300},
                ["2026-09-19"] = {date = "2026-09-19", score = 200},
            }
        }
        local list = daily.getHistoryList(p, 2)
        harness.assert_equal(2, #list, "Limite respetado")
        harness.assert_equal("2026-09-20", list[1].date, "Mas reciente primero")
        harness.assert_equal("2026-09-19", list[2].date, "Segundo mas reciente")
    end)
end)

harness.describe("Daily: ciclo de juego determinista", function()
    harness.it("startDailyRun establece semilla y modo daily", function()
        local d = {year = 2026, month = 9, day = 21}
        local seed = gameflow.startDailyRun(d)
        harness.assert_equal(seed, world.state.dailySeed, "dailySeed en world.state")
        harness.assert_true(daily.isDailyActive(), "isDailyActive true")
    end)

    harness.it("acceptDeath registra la run si es partida diaria", function()
        local prof = persistence.getActiveProfile()
        if prof then
            prof.dailyHistory = {}
            world.state.modo = "daily"
            world.state.dailySeed = 99999
            world.state.puntuacion = 850
            gameflow.acceptDeath()
            harness.assert_true(world.state.dailyModalOpen == true or world.state.lastDailyResult ~= nil, "Modal o resultado activo")
            if world.state.lastDailyResult then
                harness.assert_equal(850, world.state.lastDailyResult.score, "Score registrado")
            end
            harness.assert_nil(world.state.dailySeed, "dailySeed limpiada")
        end
    end)
end)

-- tests/test_scope_39_sprint1.lua
-- Suite de pruebas automatizadas para el Sprint 1: Cierre de Experiencia Fase 8
local harness = require("tests.test_harness")
local world = require("core.world")

harness.describe("Sprint 1: Telemetria y Causa de Muerte", function()
    harness.it("World.SCHEMA valida deathCause como string", function()
        harness.assert_equal("string", world.SCHEMA.deathCause)
        world.set("deathCause", "CAUSA: Prueba en Sala 1")
        harness.assert_equal("CAUSA: Prueba en Sala 1", world.get("deathCause"))
        world.set("deathCause", nil)
    end)

    harness.it("snakeCore formatea causa de muerte con sala actual", function()
        local snakeCore = require("entities.snake.core")
        local worldMod = require("world.world")
        worldMod.sala = 3
        snakeCore.setDeathCause("Impacto frontal letal contra Dron Patrullero")
        local dc = world.get("deathCause")
        harness.assert_true(dc:find("Dron Patrullero") ~= nil, "Debe contener nombre de entidad")
        harness.assert_true(dc:find("Sala 3") ~= nil, "Debe contener el numero de sala")
    end)

    harness.it("setHazardDeath formatea lava y pinchos correctamente", function()
        local snakeCore = require("entities.snake.core")
        snakeCore.setHazardDeath({type = "lava"})
        local d1 = world.get("deathCause")
        harness.assert_true(d1:find("Magma") ~= nil, "Debe indicar Magma")

        snakeCore.setHazardDeath({type = "pressure_spike"})
        local d2 = world.get("deathCause")
        harness.assert_true(d2:find("Pinchos") ~= nil, "Debe indicar Pinchos")
    end)

    harness.it("setAttackDeath y setEnemyDeath formatean entidades", function()
        local snakeCore = require("entities.snake.core")
        snakeCore.setAttackDeath({type = "laser"})
        local d1 = world.get("deathCause")
        harness.assert_true(d1:find("Láser") ~= nil or d1:find("Laser") ~= nil, "Debe indicar Laser")

        snakeCore.setEnemyDeath({type = "chaser"})
        local d2 = world.get("deathCause")
        harness.assert_true(d2:find("Cazador") ~= nil, "Debe indicar Cazador")

        snakeCore.setEnemyDeath({type = "patroller"})
        local d3 = world.get("deathCause")
        harness.assert_true(d3:find("Patrullero") ~= nil, "Debe indicar Patrullero")
    end)
end)

harness.describe("Sprint 1: Catalogo de Skins Zero-GC", function()
    local skinRegistry = require("systems.skinRegistry")

    harness.it("lista 4 skins base y valida sus definiciones", function()
        local list = skinRegistry.list()
        harness.assert_equal(4, #list)
        harness.assert_true(skinRegistry.isValid("neon"))
        harness.assert_true(skinRegistry.isValid("cyber"))
        harness.assert_true(skinRegistry.isValid("volcanic"))
        harness.assert_true(skinRegistry.isValid("void"))
        harness.assert_true(skinRegistry.isValid("classic"), "classic es alias valido")
    end)

    harness.it("comprueba desbloqueo de skins segun logros", function()
        local profSinLogros = {achievements = {}}
        harness.assert_true(skinRegistry.isUnlocked("neon", profSinLogros))
        harness.assert_false(skinRegistry.isUnlocked("cyber", profSinLogros))
        harness.assert_false(skinRegistry.isUnlocked("volcanic", profSinLogros))
        harness.assert_false(skinRegistry.isUnlocked("void", profSinLogros))

        local profConLogros = {
            achievements = {
                enemy_100 = true,
                stage_3 = true,
                boss_kill = true,
            }
        }
        harness.assert_true(skinRegistry.isUnlocked("cyber", profConLogros))
        harness.assert_true(skinRegistry.isUnlocked("volcanic", profConLogros))
        harness.assert_true(skinRegistry.isUnlocked("void", profConLogros))
    end)

    harness.it("computa colores diferenciados por skin sin crear tablas", function()
        local r1, g1, b1 = skinRegistry.computeBaseColor("cyber", 1, 10, 0, 0, 0.5, 0.5, 0.5)
        local r2, g2, b2 = skinRegistry.computeBaseColor("volcanic", 1, 10, 0, 0, 0.5, 0.5, 0.5)
        local r3, g3, b3 = skinRegistry.computeBaseColor("void", 1, 10, 0, 0, 0.5, 0.5, 0.5)

        harness.assert_true(b1 > 0.8, "Cyber tiene tono azul dominante")
        harness.assert_true(r2 > 0.8, "Volcanic tiene tono rojo/naranja dominante")
        harness.assert_true(r3 > 0.4 and b3 > 0.6, "Void tiene tono purpura dominante")
    end)

    harness.it("getActiveSkin mapea classic a neon y maneja nils", function()
        world.set("skin", "classic")
        harness.assert_equal("neon", skinRegistry.getActiveSkin())
        world.set("skin", "volcanic")
        harness.assert_equal("volcanic", skinRegistry.getActiveSkin())
        world.set("skin", nil)
        harness.assert_equal("neon", skinRegistry.getActiveSkin())
    end)
end)

harness.describe("Sprint 1: Mazmorra Diaria y Bloqueo Estricto", function()
    local modes = require("systems.modes")
    local gameflow = require("systems.gameflow")

    harness.it("incluye diario en lista de modos", function()
        local found = false
        for _, m in ipairs(modes.LIST) do
            if m == "diario" then found = true end
        end
        harness.assert_true(found, "diario debe estar en modes.LIST")
    end)

    harness.it("bloquea el modo diario si ya fue intentado hoy", function()
        local todayKey = tostring(os.date("%Y%m%d"))
        local profLimpio = {dailyHistory = {}}
        local ok, msg = modes.isUnlocked("diario", profLimpio)
        harness.assert_true(ok, "Debe estar desbloqueado si no se ha jugado hoy")

        local profJugado = {
            dailyHistory = {
                [todayKey] = {score = 1500, date = todayKey}
            }
        }
        local ok2, msg2 = modes.isUnlocked("diario", profJugado)
        harness.assert_false(ok2, "Debe bloquearse si ya fue jugado hoy")
        harness.assert_true(msg2:find("Bloqueado") ~= nil, "Mensaje de bloqueo presente")
    end)

    harness.it("recordDailyAttempt registra fecha y conserva mejor puntuacion", function()
        local persistence = require("systems.persistence")
        local prof = persistence.getActiveProfile()
        if prof then
            local todayKey = tostring(os.date("%Y%m%d"))
            gameflow.recordDailyAttempt(500)
            harness.assert_true(prof.dailyHistory[todayKey] ~= nil, "Debe crear entrada diaria")
            harness.assert_equal(500, prof.dailyHistory[todayKey].score)

            gameflow.recordDailyAttempt(1200)
            harness.assert_equal(1200, prof.dailyHistory[todayKey].score)

            -- Menor puntuacion no sobreescribe record
            gameflow.recordDailyAttempt(800)
            harness.assert_equal(1200, prof.dailyHistory[todayKey].score)
        end
    end)
end)

local harness = require("tests.test_harness")
local Templates = require("world.dungeonTemplates")
local dungeonGen = require("world.dungeonGen")
local Patterns = require("world.wallPatterns")
local worldMod = require("world.world")
local function checkCells(cells, w, h, cx, cy)
    local seen = {}
    for _, c in ipairs(cells) do
        harness.assert_true(c.x >= 1 and c.x < w - 1, "celda en X")
        harness.assert_true(c.y >= 1 and c.y < h - 1, "celda en Y")
        harness.assert_true(math.max(math.abs(c.x - cx), math.abs(c.y - cy)) > 2, "agujero central")
        harness.assert_nil(seen[c.x .. ":" .. c.y], "sin duplicados")
        seen[c.x .. ":" .. c.y] = true
    end
end
harness.describe("Templates: registro Cruz/Espiral/Laberinto", function()
    harness.it("registra 10 plantillas y 9 ids seleccionables", function()
        local n = 0
        for _ in pairs(Templates.roomTemplates) do n = n + 1 end
        harness.assert_equal(10, n, "10 plantillas")
        harness.assert_equal(9, #Templates.templateIds, "9 ids")
        for _, id in ipairs({"cruz", "espiral", "laberinto"}) do
            harness.assert_not_nil(Templates.roomTemplates[id], id .. " existe")
            harness.assert_not_nil(Templates.roomTemplates[id].wallPattern, id .. " patron")
        end
    end)
    harness.it("objectiveMap cubre las 3 nuevas", function()
        local oldDungeon, oldSala = worldMod.dungeon, worldMod.sala
        worldMod.dungeon = {rooms = {{template = "cruz"}, {template = "espiral"}, {template = "laberinto"}}}
        worldMod.sala = 1
        harness.assert_equal("clear_enemies", worldMod.getObjectiveType(), "cruz combate")
        worldMod.sala = 2
        harness.assert_equal("collect_food", worldMod.getObjectiveType(), "espiral comida")
        worldMod.sala = 3
        harness.assert_equal("clear_enemies", worldMod.getObjectiveType(), "laberinto combate")
        worldMod.dungeon, worldMod.sala = oldDungeon, oldSala
    end)
end)
harness.describe("Templates: patrones de muros", function()
    harness.it("cruz genera brazos sin centro ni duplicados", function()
        local cells = Patterns.cellsFor("cruz", 20, 14, 40, 28)
        harness.assert_true(#cells > 0, "celdas cruz")
        harness.assert_true(#cells <= 12, "tope 12")
        checkCells(cells, 40, 28, 20, 14)
    end)
    harness.it("espiral genera anillos con salida", function()
        local cells = Patterns.cellsFor("espiral", 20, 14, 40, 28)
        harness.assert_true(#cells > 20, "anillos densos")
        checkCells(cells, 40, 28, 20, 14)
    end)
    harness.it("laberinto genera peine con huecos", function()
        local cells = Patterns.cellsFor("laberinto", 20, 14, 40, 28)
        harness.assert_true(#cells > 10, "peine denso")
        checkCells(cells, 40, 28, 20, 14)
    end)
    harness.it("id desconocido retorna vacio", function()
        harness.assert_equal(0, #Patterns.cellsFor("nada", 20, 14, 40, 28), "vacio")
    end)
end)
harness.describe("Templates: seleccion ponderada", function()
    harness.it("ultima sala siempre boss", function()
        for seed = 1, 20 do
            love.math.setRandomSeed(seed)
            harness.assert_equal("boss", dungeonGen._selectTemplateForRoom({w = 200, h = 160}, 5, 5), "boss seed " .. seed)
        end
    end)
    harness.it("sala 1 y sala 3 nunca nuevas", function()
        for seed = 1, 60 do
            love.math.setRandomSeed(seed)
            local t1 = dungeonGen._selectTemplateForRoom({w = 300, h = 250}, 1, 5)
            local t3 = dungeonGen._selectTemplateForRoom({w = 300, h = 250}, 3, 5)
            for _, t in ipairs({t1, t3}) do
                harness.assert_true(t ~= "cruz" and t ~= "espiral" and t ~= "laberinto", "clasica en 1/3, got " .. t)
            end
        end
    end)
    harness.it("salas pequenas nunca nuevas", function()
        for seed = 1, 40 do
            love.math.setRandomSeed(seed)
            local t = dungeonGen._selectTemplateForRoom({w = 100, h = 90}, 2, 5)
            harness.assert_true(t ~= "cruz" and t ~= "espiral" and t ~= "laberinto", "clasica en pequena, got " .. t)
        end
    end)
    harness.it("generar con semilla produce plantillas validas", function()
        local d = dungeonGen.generar({etapa = 1}, 800, 600, 5, 4242)
        harness.assert_equal(5, #d.rooms, "5 salas")
        for _, r in ipairs(d.rooms) do
            harness.assert_not_nil(Templates.roomTemplates[r.template], "plantilla valida: " .. tostring(r.template))
        end
    end)
end)

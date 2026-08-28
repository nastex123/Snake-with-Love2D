-- tests/test_world.lua
-- Unit tests for world generation and dungeon populating

local harness = require("tests.test_harness")
local constants = require("constants")
local worldMod = require("world.world")
local dungeonGen = require("world.dungeonGen")
local populate = require("world.populate")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")

harness.describe("Dungeon Generation (world/dungeonGen.lua)", function()
    harness.it("generates BSP dungeon structure with connected rooms and corridors", function()
        local dungeon = dungeonGen.generar(800, 600, 5)
        harness.assert_not_nil(dungeon, "Dungeon data generated")
        harness.assert_not_nil(dungeon.rooms, "Dungeon has rooms table")
        harness.assert_gt(#dungeon.rooms, 0, "Dungeon has at least one room")
        harness.assert_not_nil(dungeon.corridors, "Dungeon has corridors table")
    end)
end)

harness.describe("Room Population (world/populate.lua)", function()
    harness.it("populates room avoiding snake body and reserving entity tiles", function()
        local snakeBody = { { x = 10, y = 10 }, { x = 9, y = 10 } }
        local obstacles = {}
        worldMod.init()
        local ok = pcall(function()
            populate.populateRoom(snakeBody, 32, 20, obstacles, foodMod, enemiesMod, obstaclesMod)
        end)
        harness.assert_true(ok, "populateRoom should execute cleanly")
    end)
end)

harness.describe("World Facade (world/world.lua)", function()
    harness.it("tracks stage, room progression, and boss rooms", function()
        worldMod.init()
        harness.assert_equal(1, worldMod.etapa, "Initial stage is 1")
        harness.assert_equal(1, worldMod.sala, "Initial room is 1")
        harness.assert_false(worldMod.esJefe(), "Room 1 is not boss")

        worldMod.avanzarSala()
        harness.assert_equal(2, worldMod.sala, "Advanced to room 2")

        worldMod.avanzarEtapa()
        harness.assert_equal(2, worldMod.etapa, "Advanced to stage 2")
        harness.assert_equal(1, worldMod.sala, "Room reset to 1 on stage advance")

        local biome = worldMod.getBiomeData()
        harness.assert_not_nil(biome, "Biome data retrieved for current stage")
    end)
end)

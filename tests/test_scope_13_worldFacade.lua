-- tests/test_scope_13_worldFacade.lua
-- Comprehensive Unit Test Suite for world/world.lua and world/populate.lua (Scope 13)

local harness = require("tests.test_harness")
local describe = harness.describe
local it = harness.it
local before_each = harness.before_each
local assert_equal = harness.assert_equal
local assert_not_equal = harness.assert_not_equal
local assert_true = harness.assert_true
local assert_false = harness.assert_false
local assert_nil = harness.assert_nil
local assert_not_nil = harness.assert_not_nil
local assert_gt = harness.assert_gt
local assert_gte = harness.assert_gte
local assert_lt = harness.assert_lt
local assert_lte = harness.assert_lte
local assert_type = harness.assert_type

local world = require("world.world")
local populate = require("world.populate")
local dungeonGen = require("world.dungeonGen")
local constants = require("constants")
local coreWorld = require("core.world")

-- =========================================================================
-- SUITE 1: World Initialization, State Management & Lifecycle
-- =========================================================================
describe("Scope 13 - World Facade: State Lifecycle & Setters", function()
    before_each(function()
        world.init()
    end)

    it("initializes state to stage 1, room 1, score 0, and generates dungeon", function()
        assert_equal(1, world.etapa, "world.etapa must start at 1")
        assert_equal(1, world.sala, "world.sala must start at 1")
        assert_equal(0, world.puntajeSala, "world.puntajeSala must start at 0")
        assert_not_nil(world.dungeon, "world.dungeon must not be nil")
        assert_type(world.dungeon.rooms, "table", "world.dungeon.rooms must be a table")
        assert_gte(#world.dungeon.rooms, 3, "dungeon should have at least 3 rooms")
        assert_false(coreWorld.get("mundoCompletado"), "mundoCompletado should be false on init")
    end)

    it("provides clean getters for etapa, sala, puntajeSala, objetivoSala", function()
        assert_equal(world.etapa, world.getEtapa(), "getEtapa must match world.etapa")
        assert_equal(world.sala, world.getSala(), "getSala must match world.sala")
        assert_equal(world.puntajeSala, world.getPuntajeSala(), "getPuntajeSala must match world.puntajeSala")
        assert_equal(world.objetivoSala, world.getObjetivoSala(), "getObjetivoSala must match world.objetivoSala")
    end)

    it("allows safely setting stage and updates objective accordingly", function()
        world.setEtapa(3)
        assert_equal(3, world.getEtapa(), "etapa should be updated to 3")
        local expectedObj = world.calcularObjetivo()
        assert_equal(expectedObj, world.getObjetivoSala(), "objetivoSala should match stage 3 calculation")
    end)

    it("allows safely setting room index with clamping and visited flag", function()
        local count = world.getRoomCount()
        world.setSala(2)
        assert_equal(2, world.getSala(), "sala should be set to 2")
        local r2 = world.getCurrentRoom()
        assert_not_nil(r2, "current room 2 should exist")
        assert_true(r2.visited, "room 2 should be marked visited")

        -- Clamping beyond bounds
        world.setSala(999)
        assert_equal(count, world.getSala(), "sala should clamp to max room count")
        world.setSala(-10)
        assert_equal(1, world.getSala(), "sala should clamp to min 1")
    end)

    it("resets room score and recalculates objective on resetSala", function()
        world.puntajeSala = 150
        world.resetSala()
        assert_equal(0, world.getPuntajeSala(), "puntajeSala should be reset to 0")
        assert_equal(world.calcularObjetivo(), world.getObjetivoSala(), "objetivoSala should be refreshed")
    end)
end)

-- =========================================================================
-- SUITE 2: Room & Stage Progression & Completion
-- =========================================================================
describe("Scope 13 - World Facade: Room & Stage Progression", function()
    before_each(function()
        world.init()
    end)

    it("advances room, marks previous as cleared, and new room as visited", function()
        world.setSala(1)
        local r1 = world.getCurrentRoom()
        assert_not_nil(r1, "room 1 must exist")
        assert_false(r1.cleared or false, "room 1 should not be cleared before advance")

        world.avanzarSala()
        assert_equal(2, world.getSala(), "sala should advance to 2")
        assert_true(r1.cleared, "room 1 must be marked cleared after advancing")

        local r2 = world.getCurrentRoom()
        assert_not_nil(r2, "room 2 must exist")
        assert_true(r2.visited, "room 2 must be marked visited")
        assert_equal(0, world.getPuntajeSala(), "puntajeSala should be 0")
    end)

    it("advances stage, regenerates dungeon, and resets to room 1", function()
        world.setEtapa(1)
        world.setSala(3)
        world.avanzarEtapa()
        assert_equal(2, world.getEtapa(), "etapa should be 2")
        assert_equal(1, world.getSala(), "sala should be reset to 1")
        assert_equal(0, world.getPuntajeSala(), "puntajeSala should be 0")
        assert_not_nil(world.dungeon, "new dungeon must be generated")
    end)

    it("accurately reports etapaCompletada for stages > 5", function()
        world.setEtapa(1)
        assert_false(world.etapaCompletada(), "stage 1 is not completed")
        world.setEtapa(5)
        assert_false(world.etapaCompletada(), "stage 5 is not completed")
        world.setEtapa(6)
        assert_true(world.etapaCompletada(), "stage 6 indicates full game completion")
    end)

    it("accurately detects last room and boss room", function()
        local count = world.getRoomCount()
        world.setSala(1)
        if count > 1 then
            assert_false(world.isLastRoom(), "room 1 is not last room")
        end

        world.setSala(count)
        assert_true(world.isLastRoom(), "room count should be last room")
        assert_true(world.esJefe(), "last room template should be boss")
    end)
end)

-- =========================================================================
-- SUITE 3: Stage Modifiers, Biomes & Fallbacks
-- =========================================================================
describe("Scope 13 - World Facade: Modifiers & Biomes", function()
    it("returns valid stage modifiers for stages 1 to 5", function()
        for s = 1, 5 do
            local mod = world.getStageMod(s)
            assert_not_nil(mod, "stageMod should exist for stage " .. s)
            assert_gte(mod.countMult, 1.0, "countMult >= 1.0")
            assert_gte(mod.hpMult, 1.0, "hpMult >= 1.0")
            assert_gte(mod.objMult, 1.0, "objMult >= 1.0")
            assert_gte(mod.bossHP, 3, "bossHP >= 3")
        end
    end)

    it("falls back to stage 5 modifier for invalid/out-of-range stage", function()
        local fb = world.getStageMod(99)
        local s5 = world.getStageMod(5)
        assert_equal(s5.bossHP, fb.bossHP, "fallback bossHP matches stage 5")
        assert_equal(s5.objMult, fb.objMult, "fallback objMult matches stage 5")
    end)

    it("returns correct biome metadata and wallWrap flags", function()
        assert_equal("catacumbas", world.getBiome(1), "stage 1 biome")
        assert_equal("Catacumbas de Piedra", world.getBiomeName(1), "stage 1 biome name")
        assert_true(world.hasWallWrap(1), "stage 1 wall wrap enabled")

        assert_equal("hielo", world.getBiome(2), "stage 2 biome")
        assert_equal("volcan", world.getBiome(3), "stage 3 biome")
        assert_equal("colmena", world.getBiome(4), "stage 4 biome")

        assert_equal("vacio", world.getBiome(5), "stage 5 biome")
        assert_false(world.hasWallWrap(5), "stage 5 wall wrap disabled")
    end)
end)

-- =========================================================================
-- SUITE 4: Room Objectives System
-- =========================================================================
describe("Scope 13 - World Facade: Room Objectives System", function()
    before_each(function()
        world.init()
    end)

    it("maps room templates to correct objective types", function()
        local templates = {
            corridor = "collect_food",
            arena = "clear_enemies",
            choke = "clear_enemies",
            hub = "collect_food",
            treasure = "collect_food",
            spawner = "clear_enemies",
            boss = "defeat_boss",
        }

        for i = 1, world.getRoomCount() do
            world.setSala(i)
            local r = world.getCurrentRoom()
            local expectedObj = templates[r.template] or "collect_food"
            assert_equal(expectedObj, world.getObjectiveType(), "Room " .. i .. " (" .. r.template .. ") objective type")
        end
    end)

    it("calculates room objective scaling with stage multiplier", function()
        world.setEtapa(1)
        local obj1 = world.calcularObjetivo()
        assert_gt(obj1, 0, "objective > 0")

        world.setEtapa(4)
        local obj4 = world.calcularObjetivo()
        assert_gt(obj4, obj1, "stage 4 objective > stage 1 objective")
    end)

    it("provides formatted objective description per objective type", function()
        world.setSala(1)
        local desc = world.getObjectiveDescription()
        assert_type(desc, "string", "description is string")
        assert_gt(#desc, 5, "description is non-empty")

        -- Last room (boss)
        world.setSala(world.getRoomCount())
        local bossDesc = world.getObjectiveDescription()
        assert_true(bossDesc:find("jefe") ~= nil, "boss description mentions jefe")
    end)

    it("evaluates objective completion correctly for collect_food", function()
        local mockRoom = { template = "corridor", objectiveBase = 30 }
        world.dungeon.rooms[1] = mockRoom
        world.setSala(1)
        world.objetivoSala = 30

        assert_false(world.isObjectiveComplete(10, 2, 5, false), "score 10 < 30 not complete")
        assert_true(world.isObjectiveComplete(30, 2, 5, false), "score 30 >= 30 complete")
        assert_true(world.isObjectiveComplete(45, 2, 5, false), "score 45 >= 30 complete")
    end)

    it("evaluates objective completion correctly for clear_enemies", function()
        local mockRoom = { template = "arena", objectiveBase = 60 }
        world.dungeon.rooms[1] = mockRoom
        world.setSala(1)
        world.objetivoSala = 60

        assert_false(world.isObjectiveComplete(20, 3, 5, false), "enemies remaining & low score not complete")
        assert_true(world.isObjectiveComplete(20, 0, 5, false), "all enemies cleared complete")
        assert_true(world.isObjectiveComplete(60, 2, 5, false), "target score reached complete")
    end)

    it("evaluates objective completion correctly for defeat_boss", function()
        local mockRoom = { template = "boss", objectiveBase = 100 }
        world.dungeon.rooms[1] = mockRoom
        world.setSala(1)

        assert_false(world.isObjectiveComplete(200, 0, 5, true), "boss alive not complete")
        assert_true(world.isObjectiveComplete(0, 0, 5, false), "boss dead complete")
    end)
end)

-- =========================================================================
-- SUITE 5: Dungeon Generation & Map Data
-- =========================================================================
describe("Scope 13 - World Facade: Dungeon Generation & Map Data", function()
    before_each(function()
        world.init()
    end)

    it("returns structured dungeon map data for minimap", function()
        local mapData = world.getDungeonMapData()
        assert_not_nil(mapData, "mapData must exist")
        assert_type(mapData.rooms, "table", "mapData.rooms must be table")
        assert_type(mapData.corridors, "table", "mapData.corridors must be table")
        assert_gt(#mapData.rooms, 0, "rooms list non-empty")
        assert_gt(#mapData.corridors, 0, "corridors list non-empty")

        for _, r in ipairs(mapData.rooms) do
            assert_not_nil(r.id, "room id")
            assert_not_nil(r.rect, "room rect")
            assert_not_nil(r.template, "room template")
            assert_not_nil(r.name, "room name")
            assert_type(r.visited, "boolean", "room visited flag")
            assert_type(r.cleared, "boolean", "room cleared flag")
        end
    end)

    it("can retrieve individual rooms by index via getRoom", function()
        local r1 = world.getRoom(1)
        assert_not_nil(r1, "getRoom(1) must return room")
        assert_equal(1, r1.id, "room 1 id")

        local rNil = world.getRoom(999)
        assert_nil(rNil, "getRoom(999) must return nil")
    end)
end)

-- =========================================================================
-- SUITE 6: Populate Subsystem - Avoid List & Distance Sampling
-- =========================================================================
describe("Scope 13 - Populate: Avoid List & Coordinate Distance Checks", function()
    it("builds avoid list from snake, obstacles, enemies, food, and twin food", function()
        local snake = {{x = 5, y = 5}, {x = 5, y = 6}}
        local obs = {{x = 10, y = 10}}
        local enemies = {{x = 15, y = 15, alive = true}, {x = 20, y = 20, alive = false}}
        local food = {x = 8, y = 8}
        local twin = {x = 9, y = 9}

        local list = populate.buildAvoidList(snake, obs, enemies, food, twin)
        assert_equal(6, #list, "should include 2 snake + 1 obs + 1 alive enemy + 1 food + 1 twin")
    end)

    it("handles nil parameters safely in buildAvoidList", function()
        local list = populate.buildAvoidList(nil, nil, nil, nil, nil)
        assert_type(list, "table", "returns empty table")
        assert_equal(0, #list, "length 0")
    end)

    it("prevents zero-distance overlap: cannot sample on exact occupied cell", function()
        local avoid = {{x = 5, y = 5, radius = 0}}
        -- Sample 1x1 grid at (5,5) - should always fail because (5,5) is blocked
        -- We simulate a 6x6 grid where only (5,5) exists
        for _ = 1, 20 do
            local gx, gy = populate.samplePosition(6, 6, avoid, 100, 1)
            if gx and gy then
                local isOverlap = (gx == 5 and gy == 5)
                assert_false(isOverlap, "samplePosition must NEVER return exact occupied cell (5,5)")
            end
        end
    end)

    it("respects minDist parameter to enforce clearance", function()
        local avoid = {{x = 10, y = 10, radius = 0}}
        local minDist = 4
        for _ = 1, 30 do
            local gx, gy = populate.samplePosition(20, 20, avoid, 100, minDist)
            if gx and gy then
                local dist = math.abs(gx - 10) + math.abs(gy - 10)
                assert_gte(dist, minDist, "sampled distance must be >= minDist")
            end
        end
    end)

    it("placeNEntities places entities and reserves clearance", function()
        local placed = {}
        local avoid = {}
        local count = populate.placeNEntities(function(gx, gy)
            table.insert(placed, {x = gx, y = gy})
        end, 4, 20, 20, avoid, {avoidRadius = 2, minDist = 2})

        assert_equal(4, count, "4 entities placed")
        assert_equal(4, #placed, "placed list length")

        -- Ensure none of the placed entities overlap each other
        for i = 1, #placed do
            for j = i + 1, #placed do
                local dist = math.abs(placed[i].x - placed[j].x) + math.abs(placed[i].y - placed[j].y)
                assert_gt(dist, 0, "No two placed entities occupy the exact same cell")
            end
        end
    end)
end)

-- =========================================================================
-- SUITE 7: Populate Subsystem - Boss 3x3 Reservation & Room Population
-- =========================================================================
describe("Scope 13 - Populate: Boss Room 3x3 Reservation & Room Rules", function()
    before_each(function()
        world.init()
    end)

    it("reserves center + 8 adjacent cells (3x3) in boss room", function()
        local count = world.getRoomCount()
        world.setSala(count) -- Boss room
        assert_true(world.esJefe(), "should be boss room")

        local anchoGrilla, altoGrilla = 30, 20
        local cx = math.floor(anchoGrilla / 2)
        local cy = math.floor(altoGrilla / 2)

        local snake = {{x = 2, y = 2}}
        local obsSpawned = {}
        local foodPos = nil
        local bossSpawned = nil

        local mockFood = {
            pos = {x = 0, y = 0},
            generar = function(self, s, w, h, obs, t, gx, gy)
                foodPos = {x = gx or 0, y = gy or 0}
            end
        }
        local mockEnemies = {
            list = {},
            spawnAt = function() end,
            spawnBoss = function(self, etapa, w, h, hp, coins)
                bossSpawned = {etapa = etapa, hp = hp, coins = coins}
            end
        }
        local mockObsMod = {
            pos = {},
            spawnAt = function(gx, gy)
                table.insert(obsSpawned, {x = gx, y = gy})
            end
        }

        populate.populateRoom(world, snake, anchoGrilla, altoGrilla, {}, mockFood, mockEnemies, mockObsMod)

        assert_not_nil(bossSpawned, "boss must be spawned")
        assert_not_nil(foodPos, "food must be spawned")

        -- Verify food is NOT placed in 3x3 boss area (cx-1..cx+1, cy-1..cy+1)
        local foodDistX = math.abs(foodPos.x - cx)
        local foodDistY = math.abs(foodPos.y - cy)
        local foodInBossArea = (foodDistX <= 1 and foodDistY <= 1)
        assert_false(foodInBossArea, "Food must NOT spawn inside the boss 3x3 reserved area")

        -- Verify no obstacles spawned inside 3x3 boss area
        for _, o in ipairs(obsSpawned) do
            local oxDist = math.abs(o.x - cx)
            local oyDist = math.abs(o.y - cy)
            local obsInBossArea = (oxDist <= 1 and oyDist <= 1)
            assert_false(obsInBossArea, "Obstacles must NOT spawn inside the boss 3x3 reserved area")
        end
    end)

    it("spawns 0 obstacles in corridor and boss rooms (baseCount = 0)", function()
        -- Test corridor template
        local mockCorridorWorld = {
            getCurrentRoom = function() return { template = "corridor" } end,
            roomTemplates = dungeonGen.roomTemplates,
            getStageMod = function() return { countMult = 1.5, hpMult = 1.0 } end,
            getModifier = function() return {} end,
            esJefe = function() return false end,
        }

        local obsList = {}
        local mockObsMod = {
            pos = {},
            spawnAt = function(gx, gy) table.insert(obsList, {x = gx, y = gy}) end
        }
        local mockFood = { pos = {x = 0, y = 0}, generar = function() end }
        local mockEnemies = { list = {}, spawnAt = function() end }

        populate.populateRoom(mockCorridorWorld, {{x=1,y=1}}, 25, 25, {}, mockFood, mockEnemies, mockObsMod)
        assert_equal(0, #obsList, "corridor room with baseCount=0 must spawn exactly 0 obstacles")
    end)

    it("spawns obstacles and enemies in arena room according to template rules", function()
        local mockArenaWorld = {
            getCurrentRoom = function() return { template = "arena" } end,
            roomTemplates = dungeonGen.roomTemplates,
            getStageMod = function() return { countMult = 1.0, hpMult = 1.0 } end,
            getModifier = function() return { enemySpeed = 1.0 } end,
            esJefe = function() return false end,
            etapa = 1,
        }

        local obsList = {}
        local enemiesList = {}
        local mockObsMod = {
            pos = {},
            spawnAt = function(gx, gy) table.insert(obsList, {x = gx, y = gy}) end
        }
        local mockFood = { pos = {x = 0, y = 0}, generar = function() end }
        local mockEnemies = {
            list = {},
            spawnAt = function(t, gx, gy, params)
                table.insert(enemiesList, {type = t, x = gx, y = gy, params = params})
            end
        }

        populate.populateRoom(mockArenaWorld, {{x=1,y=1}}, 30, 30, {}, mockFood, mockEnemies, mockObsMod)
        assert_gt(#obsList, 0, "arena should spawn obstacles")
        assert_gt(#enemiesList, 0, "arena should spawn enemies")
    end)
end)


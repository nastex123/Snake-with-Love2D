local world = {}
local coreWorld = require("core.world")
local dungeonGen = require("world.dungeonGen")
local populate = require("world.populate")
local constants = require("constants")

-- Tracked state
world.etapa = 1
world.sala = 1
world.puntajeSala = 0
world.objetivoSala = 50
world.dungeon = nil
world.roomTemplates = dungeonGen.roomTemplates

-- Objective types mapping by room template
local templateObjectiveMap = {
    corridor = "collect_food",
    arena = "clear_enemies",
    choke = "clear_enemies",
    hub = "collect_food",
    treasure = "collect_food",
    spawner = "clear_enemies",
    boss = "defeat_boss",
}

function world.calcularObjetivo()
    local room = world.getCurrentRoom()
    if not room then return 50 end
    local base = room.objectiveBase or 50
    local mod = world.getStageMod()
    return math.floor(base * (mod.objMult or 1.0))
end

function world.getStageMod(stage)
    local s = stage or world.etapa or 1
    return dungeonGen.stageMod[s] or dungeonGen.stageMod[5]
end

function world.generarMazmorra(anchoVirtual, altoVirtual, targetRooms)
    dungeonGen.generar(world, anchoVirtual, altoVirtual, targetRooms)
end

function world.getCurrentRoom()
    if not world.dungeon or not world.dungeon.rooms then return nil end
    return world.dungeon.rooms[world.sala]
end

function world.getRoom(index)
    if not world.dungeon or not world.dungeon.rooms then return nil end
    return world.dungeon.rooms[index]
end

function world.getRoomCount()
    if not world.dungeon or not world.dungeon.rooms then return 5 end
    return #world.dungeon.rooms
end

function world.init()
    world.etapa = 1
    world.sala = 1
    world.puntajeSala = 0
    world.objetivoSala = 50
    world.dungeon = nil
    world.generarMazmorra()
    coreWorld.set("mundoCompletado", false)
end

function world.getModifier(stage)
    local s = stage or world.etapa or 1
    return dungeonGen.stageModifiers[s] or dungeonGen.stageModifiers[5]
end

function world.getBiomeData(stage)
    local cfg = require("core.config")
    local s = math.min(5, math.max(1, stage or world.etapa or 1))
    return (cfg.BIOMES and cfg.BIOMES[s]) or cfg.BIOMES[1]
end

function world.getBiome(stage)
    local b = world.getBiomeData(stage)
    return b and b.id or "catacumbas"
end

function world.getBiomeName(stage)
    local b = world.getBiomeData(stage)
    return b and b.name or "Catacumbas de Piedra"
end

function world.hasWallWrap(stage)
    local b = world.getBiomeData(stage)
    return b and (b.wallWrap ~= false)
end

function world.esJefe()
    local room = world.getCurrentRoom()
    return (room and room.template == "boss") or false
end

function world.getObjectiveType()
    local room = world.getCurrentRoom()
    if not room then return "collect_food" end
    if room.template == "boss" then return "defeat_boss" end
    if room.objectiveType then return room.objectiveType end
    return templateObjectiveMap[room.template] or "collect_food"
end

function world.getObjectiveTarget()
    local objType = world.getObjectiveType()
    if objType == "defeat_boss" then
        return constants.BOSS_FOOD_TARGET or 15
    elseif objType == "survive_time" then
        local mod = world.getStageMod()
        return math.floor(20 * (mod.objMult or 1.0))
    else
        return world.objetivoSala or world.calcularObjetivo()
    end
end

function world.getObjectiveDescription()
    local objType = world.getObjectiveType()
    local target = world.getObjectiveTarget()
    if objType == "defeat_boss" then
        return string.format("Derrota al jefe recogiendo %d comidas", target)
    elseif objType == "clear_enemies" then
        return string.format("Elimina enemigos y consigue %d pts", target)
    elseif objType == "survive_time" then
        return string.format("Sobrevive %d segundos", target)
    else
        return string.format("Consigue %d puntos", target)
    end
end

function world.isObjectiveComplete(score, enemiesCount, timeElapsed, bossAlive)
    local objType = world.getObjectiveType()
    score = score or world.puntajeSala or 0
    if objType == "defeat_boss" then
        return bossAlive == false
    elseif objType == "clear_enemies" then
        if enemiesCount and enemiesCount == 0 and score > 0 then
            return true
        end
        return score >= (world.objetivoSala or 50)
    elseif objType == "survive_time" then
        local target = world.getObjectiveTarget()
        return (timeElapsed or 0) >= target
    else
        return score >= (world.objetivoSala or 50)
    end
end

function world.getEtapa()
    return world.etapa
end

function world.getSala()
    return world.sala
end

function world.getPuntajeSala()
    return world.puntajeSala
end

function world.getObjetivoSala()
    return world.objetivoSala
end

function world.setEtapa(stage)
    world.etapa = math.max(1, stage or 1)
    world.objetivoSala = world.calcularObjetivo()
end

function world.setSala(sala)
    local maxRooms = world.getRoomCount()
    world.sala = math.max(1, math.min(maxRooms, sala or 1))
    if world.dungeon and world.dungeon.rooms[world.sala] then
        world.dungeon.rooms[world.sala].visited = true
    end
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
end

function world.resetSala()
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
end

function world.avanzarSala()
    local currentRoom = world.getCurrentRoom()
    if currentRoom then
        currentRoom.cleared = true
    end
    local nextSala = world.sala + 1
    local maxRoom = world.dungeon and #world.dungeon.rooms or 5
    if nextSala <= maxRoom then
        world.sala = nextSala
        if world.dungeon and world.dungeon.rooms[world.sala] then
            world.dungeon.rooms[world.sala].visited = true
        end
    else
        world.sala = maxRoom
    end
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
end

function world.avanzarEtapa()
    world.etapa = world.etapa + 1
    world.generarMazmorra()
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
end

function world.etapaCompletada()
    return world.etapa > 5
end

function world.isLastRoom()
    if not world.dungeon or not world.dungeon.rooms then return world.sala >= 5 end
    return world.sala >= #world.dungeon.rooms
end

function world.populateRoom(snakeBody, anchoGrilla, altoGrilla, obstaclesList, foodMod, enemiesMod, obstaclesMod)
    populate.populateRoom(world, snakeBody, anchoGrilla, altoGrilla, obstaclesList, foodMod, enemiesMod, obstaclesMod)
end

function world.getDungeonMapData()
    if not world.dungeon then return nil end
    local data = {
        rooms = {},
        corridors = {},
        virtualW = world.dungeon.virtualW,
        virtualH = world.dungeon.virtualH,
    }
    for _, r in ipairs(world.dungeon.rooms) do
        table.insert(data.rooms, {
            id = r.id,
            rect = r.rect,
            template = r.template,
            name = r.name,
            centerX = r.centerX,
            centerY = r.centerY,
            visited = r.visited,
            cleared = r.cleared,
            current = (r.id == world.sala),
        })
    end
    for _, c in ipairs(world.dungeon.corridors) do
        table.insert(data.corridors, {from = c.from, to = c.to, path = c.path})
    end
    return data
end

return world

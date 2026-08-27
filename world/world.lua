local world = {}
local coreWorld = require("core.world")
local dungeonGen = require("world.dungeonGen")
local populate = require("world.populate")

-- Tracked state
world.etapa = 1
world.sala = 1
world.puntajeSala = 0
world.objetivoSala = 50
world.dungeon = nil
world.roomTemplates = dungeonGen.roomTemplates

function world.calcularObjetivo()
    local room = world.getCurrentRoom()
    if not room then return 50 end
    local base = room.objectiveBase or 50
    local mod = world.getStageMod()
    return math.floor(base * mod.objMult)
end

function world.getStageMod()
    return dungeonGen.stageMod[world.etapa] or dungeonGen.stageMod[5]
end

function world.generarMazmorra(anchoVirtual, altoVirtual, targetRooms)
    dungeonGen.generar(world, anchoVirtual, altoVirtual, targetRooms)
end

function world.getCurrentRoom()
    if not world.dungeon or not world.dungeon.rooms then return nil end
    return world.dungeon.rooms[world.sala]
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

function world.getModifier()
    return dungeonGen.stageModifiers[world.etapa] or dungeonGen.stageModifiers[5]
end

function world.esJefe()
    local room = world.getCurrentRoom()
    return room and room.template == "boss"
end

function world.avanzarSala()
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

-- Arena unica de etapa. La estructura de mapa conserva la interfaz usada
-- por el render y los sistemas anteriores mientras se migran sus consumidores.
local stageArena = {}
local constants = require("constants")
local templates = require("world.dungeonTemplates")

function stageArena.generate(width, height, seed, stage)
    local w = math.max(200, width or constants.DUNGEON_VIRTUAL_W or 800)
    local h = math.max(200, height or constants.DUNGEON_VIRTUAL_H or 600)
    local rngSeed = seed or (os.time() + (stage or 1) * 1000 + love.math.random(1, 99999))
    love.math.setRandomSeed(rngSeed)
    local template = templates.roomTemplates.arena
    local arena = {
        id = 1, rect = {x = 0, y = 0, w = w, h = h},
        template = "arena", name = template.name, objectiveBase = template.objectiveBase,
        centerX = w / 2, centerY = h / 2, visited = true, cleared = false, isElite = false,
    }
    return {rooms = {arena}, corridors = {}, roomGraph = {{}}, virtualW = w, virtualH = h}
end

return stageArena

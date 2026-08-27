-- entities/enemyHelpers.lua — Funciones de utilidad puras para generación/posicionamiento de enemigos
local helpers = {}
local constants = require("constants")

--- Distancia de Manhattan entre dos puntos
function helpers.manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

helpers.manhattanDistance = helpers.manhattan

--- Valida si una celda (x, y) está libre de serpiente, comida, obstáculos y otros enemigos
function helpers.validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla, enemyList)
    if x < 0 or x >= anchoGrilla or y < 0 or y >= altoGrilla then return false end
    if snake then
        for _, s in ipairs(snake) do
            if x == s.x and y == s.y then return false end
        end
    end
    if foodPos then
        if foodPos.x and foodPos.y then
            if x == foodPos.x and y == foodPos.y then return false end
        elseif #foodPos > 0 then
            for _, f in ipairs(foodPos) do
                if x == f.x and y == f.y then return false end
            end
        end
    end
    if obstacles then
        local obs = obstacles.pos or obstacles
        for _, o in ipairs(obs) do
            if x == o.x and y == o.y then return false end
        end
    end
    if enemyList then
        for _, e in ipairs(enemyList) do
            if e.alive and x == e.x and y == e.y then return false end
        end
    end
    return true
end

--- Cuenta enemigos vivos agrupados por tipo
function helpers.countEnemiesByType(enemyList)
    local counts = {}
    if not enemyList then return counts end
    for _, e in ipairs(enemyList) do
        if e.alive then
            counts[e.type] = (counts[e.type] or 0) + 1
        end
    end
    return counts
end

--- Muestrea una celda libre segura aleatoria a distancia >= minDist de la cabeza de la serpiente
function helpers.sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, enemyList, minDist, attempts)
    minDist = minDist or 6
    attempts = attempts or constants.BOSS_RESPAWN_RETRY or 40
    local head = snakeBody and snakeBody[1]
    local maxGX = math.max(1, anchoGrilla - 2)
    local maxGY = math.max(1, altoGrilla - 2)
    for _ = 1, attempts do
        local gx = love.math.random(1, maxGX)
        local gy = love.math.random(1, maxGY)
        local valid = true
        if head then
            if math.abs(gx - head.x) + math.abs(gy - head.y) < minDist then valid = false end
        end
        if valid and snakeBody then
            for _, s in ipairs(snakeBody) do
                if gx == s.x and gy == s.y then valid = false; break end
            end
        end
        if valid and obstaclesMod and obstaclesMod.pos then
            for _, o in ipairs(obstaclesMod.pos) do
                if gx == o.x and gy == o.y then valid = false; break end
            end
        end
        if valid and enemyList then
            for _, e in ipairs(enemyList) do
                if e.alive and gx == e.x and gy == e.y then valid = false; break end
            end
        end
        if valid then return gx, gy end
    end
    return nil, nil
end

return helpers
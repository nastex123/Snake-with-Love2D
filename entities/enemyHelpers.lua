-- entities/enemyHelpers.lua — Funciones de utilidad puras para generación/posicionamiento de enemigos
local helpers = {}
local constants = require("constants")

function helpers.validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla, enemyList)
    if x < 0 or x >= anchoGrilla or y < 0 or y >= altoGrilla then return false end
    for _, s in ipairs(snake) do
        if x == s.x and y == s.y then return false end
    end
    if foodPos and x == foodPos.x and y == foodPos.y then return false end
    for _, o in ipairs(obstacles) do
        if x == o.x and y == o.y then return false end
    end
    for _, e in ipairs(enemyList) do
        if e.alive and x == e.x and y == e.y then return false end
    end
    return true
end

function helpers.countEnemiesByType(enemyList)
    local counts = {}
    for _, e in ipairs(enemyList) do
        if e.alive then
            counts[e.type] = (counts[e.type] or 0) + 1
        end
    end
    return counts
end

function helpers.sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, enemyList, minDist, attempts)
    minDist = minDist or 6
    attempts = attempts or constants.BOSS_RESPAWN_RETRY
    local head = snakeBody and snakeBody[1]
    for _ = 1, attempts do
        local gx = love.math.random(1, anchoGrilla - 2)
        local gy = love.math.random(1, altoGrilla - 2)
        local valid = true
        if head then
            if math.abs(gx - head.x) + math.abs(gy - head.y) < minDist then valid = false end
        end
        if valid then
            for _, s in ipairs(snakeBody) do
                if gx == s.x and gy == s.y then valid = false; break end
            end
        end
        if valid and obstaclesMod then
            for _, o in ipairs(obstaclesMod.pos) do
                if gx == o.x and gy == o.y then valid = false; break end
            end
        end
        if valid then
            for _, e in ipairs(enemyList) do
                if e.alive and gx == e.x and gy == e.y then valid = false; break end
            end
        end
        if valid then return gx, gy end
    end
    return nil, nil
end

return helpers
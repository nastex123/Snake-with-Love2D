local food = {}
local constants = require("constants")

food.pos = {x = 0, y = 0}
food.tipo = constants.FOOD_NORMAL
food.spawnTimer = 0
local SPAWN_DURATION = 0.18

function food.generar(snake, anchoGrilla, altoGrilla, obstaclePos)
    local nuevaX, nuevaY
    local colisiona

    repeat
        nuevaX = love.math.random(0, anchoGrilla - 1)
        nuevaY = love.math.random(0, altoGrilla - 1)
        colisiona = false

        for _, segmento in ipairs(snake) do
            if nuevaX == segmento.x and nuevaY == segmento.y then
                colisiona = true
                break
            end
        end

        if not colisiona and obstaclePos then
            for _, obs in ipairs(obstaclePos) do
                if nuevaX == obs.x and nuevaY == obs.y then
                    colisiona = true
                    break
                end
            end
        end
    until not colisiona

    food.pos.x = nuevaX
    food.pos.y = nuevaY
    food.spawnTimer = SPAWN_DURATION

    local r = love.math.random()
    if r < 0.15 then
        food.tipo = constants.FOOD_GOLD
    elseif r < 0.30 then
        food.tipo = constants.FOOD_COIN
    else
        food.tipo = constants.FOOD_NORMAL
    end
end

local tipoColors = {
    [constants.FOOD_NORMAL] = {1, 0.3, 0.3},
    [constants.FOOD_GOLD] = {1, 0.84, 0.0},
    [constants.FOOD_COIN] = {0.2, 0.6, 1}
}

local tipoGlow = {
    [constants.FOOD_NORMAL] = {1, 0.3, 0.3},
    [constants.FOOD_GOLD] = {1, 0.84, 0.0},
    [constants.FOOD_COIN] = {0.2, 0.6, 1}
}

function food.draw(time, dt)
    if food.spawnTimer > 0 then
        food.spawnTimer = math.max(0, food.spawnTimer - (dt or 0.016))
    end
    local spawnFrac = 1 - food.spawnTimer / SPAWN_DURATION
    -- easing elástico suave: overshoot leve al aparecer
    local spawnScale = spawnFrac < 1
        and (1.15 - 0.15 * math.cos(spawnFrac * math.pi))
        or 1.0

    local tam = constants.TAMANIO_BLOQUE
    local px = food.pos.x * tam
    local py = food.pos.y * tam
    local pulse = 1 + math.sin(time * 4) * 0.08
    local size = (tam - 1) * pulse * spawnScale
    local offset = (tam - size) / 2
    local c = tipoGlow[food.tipo]
    local half = tam / 2

    love.graphics.setColor(c[1], c[2], c[3], 0.15 + math.sin(time * 3) * 0.08)
    love.graphics.rectangle("fill", px - 2, py - 2, tam + 4, tam + 4, 3, 3)

    if food.tipo == constants.FOOD_NORMAL then
        love.graphics.setColor(c[1], c[2], c[3], 0.5 + math.sin(time * 4) * 0.2)
        love.graphics.rectangle("fill", px + offset, py + offset, size, size, 3, 3)
    elseif food.tipo == constants.FOOD_GOLD then
        local sparkle = math.sin(time * 8) * 0.3 + 0.7
        love.graphics.setColor(c[1], c[2], c[3], sparkle)
        love.graphics.rectangle("fill", px + offset, py + offset, size, size, 3, 3)
        love.graphics.setColor(1, 1, 1, sparkle * 0.5)
        love.graphics.rectangle("fill", px + tam * 0.3, py + tam * 0.2, tam * 0.15, tam * 0.15, 2, 2)
    elseif food.tipo == constants.FOOD_COIN then
        local rpulse = 1 + math.sin(time * 6) * 0.05
        love.graphics.setColor(c[1], c[2], c[3], 0.5 + math.sin(time * 4) * 0.15)
        love.graphics.circle("fill", px + half, py + half, size / 2 * rpulse)
        love.graphics.setColor(1, 1, 1, 0.4 + math.sin(time * 6) * 0.2)
        love.graphics.circle("fill", px + half - 2, py + half - 2, size / 4)
    end
end

return food
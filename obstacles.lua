local obstacles = {}
local constants = require("constants")

obstacles.pos = {}
obstacles.flashTimers = {}

function obstacles.init()
    obstacles.pos = {}
    obstacles.flashTimers = {}
end

function obstacles.generar(snake, foodPos, anchoGrilla, altoGrilla)
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

        if not colisiona and foodPos then
            if nuevaX == foodPos.x and nuevaY == foodPos.y then
                colisiona = true
            end
        end

        if not colisiona then
            for _, obs in ipairs(obstacles.pos) do
                if nuevaX == obs.x and nuevaY == obs.y then
                    colisiona = true
                    break
                end
            end
        end
    until not colisiona

    table.insert(obstacles.pos, {x = nuevaX, y = nuevaY})
    table.insert(obstacles.flashTimers, 0.4)
end

function obstacles.agregar(x, y)
    table.insert(obstacles.pos, {x = x, y = y})
    table.insert(obstacles.flashTimers, 0.4)
end

function obstacles.update(dt)
    for i = #obstacles.flashTimers, 1, -1 do
        obstacles.flashTimers[i] = obstacles.flashTimers[i] - dt
        if obstacles.flashTimers[i] <= 0 then
            obstacles.flashTimers[i] = 0
        end
    end
end

function obstacles.draw()
    local tam = constants.TAMANIO_BLOQUE
    local time = love.timer.getTime()
    for i, obs in ipairs(obstacles.pos) do
        local flash = obstacles.flashTimers[i]
        if flash > 0 then
            local frac = 1 - flash / 0.4
            local sc = frac * frac * (3 - 2 * frac)
            local drawSize = (tam - 1) * sc
            local drawOff = ((tam - 1) - drawSize) / 2
            love.graphics.setColor(1, 1, 1, (1 - frac) * 0.8 + 0.2)
            love.graphics.rectangle("fill",
                obs.x * tam + drawOff, obs.y * tam + drawOff,
                drawSize, drawSize, 3, 3)
        else
            local pulse = math.sin(time * 2 + i * 1.5) * 0.06
            local size = (tam - 1) * (1 + pulse * 0.5)
            local off = ((tam - 1) - size) / 2 + 0.5
            love.graphics.setColor(0.3 + pulse, 0.3 + pulse, 0.35 + pulse * 0.5)
            love.graphics.rectangle("fill",
                obs.x * tam + off, obs.y * tam + off,
                size, size, 3, 3)
            love.graphics.setColor(0.2 + pulse * 0.3, 0.2 + pulse * 0.3, 0.25 + pulse * 0.2)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line",
                obs.x * tam + off, obs.y * tam + off,
                size, size, 3, 3)
        end
    end
end

return obstacles
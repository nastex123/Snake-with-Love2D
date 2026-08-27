local food = {}
local constants = require("constants")

food.pos = {x = 0, y = 0}
food.twinPos = nil
food.tipo = constants.FOOD_NORMAL
food.spawnTimer = 0
food.bombTimer = 0
food.prismaticTimer = 0
food.prismaticBuffs = {"speed", "shield", "magnet", "ghost"}
food.prismaticIndex = 1
food.twinTimer = 0
food.orbitTimer = 0
food.onBombExpired = nil

local SPAWN_DURATION = 0.18

function food.generar(snake, anchoGrilla, altoGrilla, obstaclePos, forcedType, gx, gy)
    local function findFreeTile()
        local attempts = 0
        local nx, ny, hit
        repeat
            nx = love.math.random(0, anchoGrilla - 1)
            ny = love.math.random(0, altoGrilla - 1)
            hit = false
            attempts = attempts + 1
            if snake then
                for _, seg in ipairs(snake) do
                    if nx == seg.x and ny == seg.y then hit = true; break end
                end
            end
            if not hit and obstaclePos then
                for _, obs in ipairs(obstaclePos) do
                    if nx == obs.x and ny == obs.y then hit = true; break end
                end
            end
        until not hit or attempts > 500
        if not hit then return nx, ny end
        return nil, nil
    end

    local nuevaX, nuevaY
    if gx ~= nil and gy ~= nil then
        nuevaX = gx
        nuevaY = gy
    else
        nuevaX, nuevaY = findFreeTile()
        if not nuevaX then return end
    end

    food.pos.x = nuevaX
    food.pos.y = nuevaY
    food.twinPos = nil
    food.spawnTimer = SPAWN_DURATION
    food.orbitTimer = constants.REPELLING_MOVE_INTERVAL or 1.5

    if forcedType then
        food.tipo = forcedType
        if forcedType == "bomb" then
            food.bombTimer = constants.FOOD_COUNTDOWN_TIMER or 5.0
        end
    else
        local r = love.math.random()
        if r < 0.10 then
            food.tipo = constants.FOOD_GOLD
        elseif r < 0.20 then
            food.tipo = constants.FOOD_COIN
        elseif r < 0.26 then
            food.tipo = "fire_pepper"
        elseif r < 0.32 then
            food.tipo = "frost_berry"
        elseif r < 0.38 then
            food.tipo = "constrictor_berry"
        elseif r < 0.43 then
            food.tipo = "slimming_berry"
        elseif r < 0.48 then
            food.tipo = "repelling_orbit"
        elseif r < 0.54 then
            food.tipo = "bomb"
            food.bombTimer = constants.FOOD_COUNTDOWN_TIMER or 5.0
        elseif r < 0.60 then
            food.tipo = "prismatic"
            food.prismaticTimer = 0
            food.prismaticIndex = 1
        elseif r < 0.65 then
            food.tipo = "streak_diamond"
        elseif r < 0.70 then
            food.tipo = "twin"
            food.twinTimer = constants.FOOD_TWIN_TIMER or 4.0
            local tx, ty = findFreeTile()
            if tx and ty then
                food.twinPos = {x = tx, y = ty}
            end
        else
            food.tipo = constants.FOOD_NORMAL
        end
    end
end

local tipoGlow = {
    [constants.FOOD_NORMAL] = {1.0, 0.3, 0.3},
    [constants.FOOD_GOLD]   = {1.0, 0.84, 0.0},
    [constants.FOOD_COIN]   = {0.2, 0.6, 1.0},
    ["fire_pepper"]         = {1.0, 0.25, 0.0},
    ["frost_berry"]         = {0.2, 0.85, 1.0},
    ["constrictor_berry"]   = {0.7, 0.2, 0.9},
    ["slimming_berry"]      = {0.3, 0.9, 0.3},
    ["repelling_orbit"]     = {0.0, 0.94, 0.8},
    ["bomb"]                = {1.0, 0.2, 0.1},
    ["prismatic"]           = {0.9, 0.2, 0.9},
    ["streak_diamond"]      = {0.0, 0.94, 1.0},
    ["twin"]                = {0.3, 0.9, 0.4}
}

function food.update(dt, snake, anchoGrilla, altoGrilla, obstaclePos)
    if food.spawnTimer > 0 then
        food.spawnTimer = math.max(0, food.spawnTimer - dt)
    end

    if food.tipo == "bomb" then
        food.bombTimer = food.bombTimer - dt
        if food.bombTimer <= 0 then
            if food.onBombExpired then
                food.onBombExpired(food.pos.x, food.pos.y)
            end
        end
    elseif food.tipo == "prismatic" then
        food.prismaticTimer = food.prismaticTimer + dt
        food.prismaticIndex = (math.floor(food.prismaticTimer / 1.8) % #food.prismaticBuffs) + 1
    elseif food.tipo == "twin" then
        if food.twinTimer > 0 then
            food.twinTimer = math.max(0, food.twinTimer - dt)
        end
    elseif food.tipo == "repelling_orbit" and snake and #snake > 0 and anchoGrilla and altoGrilla then
        food.orbitTimer = food.orbitTimer - dt
        if food.orbitTimer <= 0 then
            food.orbitTimer = constants.REPELLING_MOVE_INTERVAL or 1.5
            local head = snake[1]
            local tail = snake[#snake]
            local bestX, bestY = food.pos.x, food.pos.y
            local bestScore = -9999
            local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
            for _, d in ipairs(dirs) do
                local nx = food.pos.x + d[1]
                local ny = food.pos.y + d[2]
                if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                    local blocked = false
                    for _, seg in ipairs(snake) do
                        if seg.x == nx and seg.y == ny then blocked = true; break end
                    end
                    if not blocked and obstaclePos then
                        for _, obs in ipairs(obstaclePos) do
                            if obs.x == nx and obs.y == ny then blocked = true; break end
                        end
                    end
                    if not blocked then
                        local distHead = math.abs(nx - head.x) + math.abs(ny - head.y)
                        local distTail = math.abs(nx - tail.x) + math.abs(ny - tail.y)
                        local score = distHead * 2 - distTail
                        if score > bestScore then
                            bestScore = score
                            bestX, bestY = nx, ny
                        end
                    end
                end
            end
            food.pos.x = bestX
            food.pos.y = bestY
        end
    end
end

function food.getPrismaticBuff()
    return food.prismaticBuffs[food.prismaticIndex] or "speed"
end

function food.draw(time, dt)
    local spawnFrac = 1 - food.spawnTimer / SPAWN_DURATION
    local spawnScale = spawnFrac < 1 and (1.15 - 0.15 * math.cos(spawnFrac * math.pi)) or 1.0

    local tam = constants.TAMANIO_BLOQUE
    local px = food.pos.x * tam
    local py = food.pos.y * tam
    local pulse = 1 + math.sin(time * 4) * 0.08
    local size = (tam - 1) * pulse * spawnScale
    local offset = (tam - size) / 2
    local c = tipoGlow[food.tipo] or {1.0, 0.3, 0.3}
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

    elseif food.tipo == "fire_pepper" then
        local fPulse = math.sin(time * 10) * 0.2 + 0.8
        love.graphics.setColor(1.0, 0.2, 0.0, fPulse)
        love.graphics.polygon("fill", px + half, py + 2, px + size, py + size - 2, px + 2, py + size - 2)
        love.graphics.setColor(1.0, 0.8, 0.1, fPulse)
        love.graphics.circle("fill", px + half, py + half + 2, size / 4)

    elseif food.tipo == "frost_berry" then
        local icePulse = math.sin(time * 6) * 0.15 + 0.85
        love.graphics.setColor(0.2, 0.85, 1.0, icePulse)
        love.graphics.circle("fill", px + half, py + half, size / 2)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle("fill", px + half - 1, py + 3, 2, size - 4)
        love.graphics.rectangle("fill", px + 3, py + half - 1, size - 4, 2)

    elseif food.tipo == "constrictor_berry" then
        local cPulse = math.sin(time * 8) * 0.2 + 0.8
        love.graphics.setColor(0.7, 0.2, 0.9, cPulse)
        love.graphics.circle("fill", px + half, py + half, size / 2.2)
        love.graphics.setColor(1, 0.4, 1.0, cPulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", px + half, py + half, size / 1.7)
        love.graphics.setLineWidth(1)

    elseif food.tipo == "slimming_berry" then
        love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
        love.graphics.rectangle("fill", px + offset, py + offset, size, size, 4, 4)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.line(px + 4, py + half, px + size - 4, py + half)

    elseif food.tipo == "repelling_orbit" then
        local oPulse = math.sin(time * 8) * 0.2 + 0.8
        love.graphics.setColor(0.0, 0.94, 0.8, oPulse)
        love.graphics.circle("fill", px + half, py + half, size / 2.5)
        love.graphics.setColor(0.0, 0.94, 1.0, 0.6 * oPulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", px + half, py + half, size / 1.8)
        love.graphics.setLineWidth(1)

    elseif food.tipo == "bomb" then
        local bPulse = math.sin(time * 12) * 0.25 + 0.75
        love.graphics.setColor(1.0, 0.2 * bPulse, 0.1, bPulse)
        love.graphics.rectangle("fill", px + offset, py + offset, size, size, 4, 4)
        love.graphics.setColor(1, 1, 0.2, 0.9)
        local sec = math.max(0, math.ceil(food.bombTimer))
        local txt = tostring(sec)
        local font = love.graphics.getFont()
        local tw = font and font:getWidth(txt) or 6
        local th = font and font:getHeight() or 8
        love.graphics.print(txt, px + half - tw / 2, py + half - th / 2)

    elseif food.tipo == "prismatic" then
        local pColors = {
            {0.0, 0.94, 1.0},
            {1.0, 0.84, 0.0},
            {0.8, 0.2, 0.9},
            {0.3, 0.9, 0.4}
        }
        local curC = pColors[food.prismaticIndex] or {1, 1, 1}
        love.graphics.setColor(curC[1], curC[2], curC[3], 0.85 + math.sin(time * 8) * 0.15)
        love.graphics.circle("fill", px + half, py + half, size / 2)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", px + half - 2, py + half - 2, size / 4)

    elseif food.tipo == "streak_diamond" then
        local dSize = size * 0.6
        local pts = {
            px + half, py + half - dSize,
            px + half + dSize, py + half,
            px + half, py + half + dSize,
            px + half - dSize, py + half
        }
        love.graphics.setColor(0.0, 0.94, 1.0, 0.9 + math.sin(time * 10) * 0.1)
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", pts)
        love.graphics.setLineWidth(1)

    elseif food.tipo == "twin" then
        love.graphics.setColor(0.3, 0.9, 0.4, 0.85)
        love.graphics.circle("fill", px + half, py + half, size / 2.2)
        if food.twinPos then
            local tpx = food.twinPos.x * tam
            local tpy = food.twinPos.y * tam
            love.graphics.setColor(0.3, 0.9, 0.4, 0.85)
            love.graphics.circle("fill", tpx + half, tpy + half, size / 2.2)
            local aPulse = math.sin(time * 8) * 0.2 + 0.4
            love.graphics.setColor(0.0, 0.94, 1.0, aPulse)
            love.graphics.line(px + half, py + half, tpx + half, tpy + half)
        end
    end
end

return food

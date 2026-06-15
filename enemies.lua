local enemies = {}
local constants = require("constants")

enemies.list = {}
enemies.boss = nil

local function validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla)
    if x < 0 or x >= anchoGrilla or y < 0 or y >= altoGrilla then return false end
    for _, s in ipairs(snake) do
        if x == s.x and y == s.y then return false end
    end
    if foodPos and x == foodPos.x and y == foodPos.y then return false end
    for _, o in ipairs(obstacles) do
        if x == o.x and y == o.y then return false end
    end
    for _, e in ipairs(enemies.list) do
        if e.alive and x == e.x and y == e.y then return false end
    end
    return true
end

function enemies.init()
    enemies.list = {}
    enemies.boss = nil
end

function enemies.spawnBoss(etapa, anchoGrilla, altoGrilla, bossVida, dropCoins)
    local cx = math.floor(anchoGrilla / 2)
    local cy = math.floor(altoGrilla / 2)
    enemies.boss = {
        x = cx, y = cy,
        vida = bossVida,
        vidaMax = bossVida,
        bossType = "teleporter",
        alive = true,
        moveTimer = 0,
        spawnTimer = 0,
        dropCoins = dropCoins or 5,
        phase = 1
    }
end

function enemies.hitBoss()
    if not enemies.boss or not enemies.boss.alive then return nil end
    enemies.boss.vida = enemies.boss.vida - 1
    if enemies.boss.vida <= 0 then
        enemies.boss.alive = false
        local tam = constants.TAMANIO_BLOQUE
        return {
            px = enemies.boss.x * tam + tam / 2,
            py = enemies.boss.y * tam + tam / 2,
            gx = enemies.boss.x, gy = enemies.boss.y,
            coins = enemies.boss.dropCoins,
            type = "boss"
        }
    end
    return {hit = true, vida = enemies.boss.vida, vidaMax = enemies.boss.vidaMax}
end

function enemies.generar(snake, foodPos, obstacles, anchoGrilla, altoGrilla, stageModifier)
    local mod = stageModifier or {}
    local cw = mod.chaserWeight or 0.40
    local pw = mod.patrollerWeight or 0.35
    local sw = mod.spawnerWeight or 0.25
    local speedMult = mod.enemySpeed or 1.0

    local r = love.math.random()
    local eType
    if r < cw then
        eType = "chaser"
    elseif r < cw + pw then
        eType = "patroller"
    else
        eType = "spawner"
    end

    local x, y
    local attempts = 0
    repeat
        x = love.math.random(0, anchoGrilla - 1)
        y = love.math.random(0, altoGrilla - 1)
        attempts = attempts + 1
    until (validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla) or attempts > 100)
    if attempts > 100 then return end

    local e = {
        x = x, y = y, type = eType, alive = true,
        dirX = 0, dirY = 0, moveTimer = 0, spawnTimer = 0,
        dropCoins = (eType == "chaser" and constants.ENEMY_DROP_CHASER)
            or (eType == "patroller" and constants.ENEMY_DROP_PATROLLER)
            or constants.ENEMY_DROP_SPAWNER
    }

    if eType == "chaser" then
        e.moveInterval = constants.ENEMY_CHASER_SPEED / speedMult
    elseif eType == "patroller" then
        e.moveInterval = constants.ENEMY_PATROLLER_SPEED / speedMult
        local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
        local d = dirs[love.math.random(1, 4)]
        e.dirX, e.dirY = d[1], d[2]
    else
        e.moveInterval = 999
    end

    table.insert(enemies.list, e)
end

function enemies.update(dt, snakeBody, anchoGrilla, altoGrilla, obstaclesMod)
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]
        if not e.alive then
            table.remove(enemies.list, i)
        else
            e.moveTimer = e.moveTimer + dt

            if e.type == "chaser" then
                if e.moveTimer >= e.moveInterval then
                    e.moveTimer = 0
                    if not snakeBody[1] then break end
                    local hx, hy = snakeBody[1].x, snakeBody[1].y
                    local bestDir = nil
                    local bestDist = 9999
                    local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
                    for _, d in ipairs(dirs) do
                        local nx = e.x + d[1]
                        local ny = e.y + d[2]
                        if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                            local occupied = false
                            for _, oe in ipairs(enemies.list) do
                                if oe ~= e and oe.alive and oe.x == nx and oe.y == ny then
                                    occupied = true; break
                                end
                            end
                            if not occupied then
                                local dist = math.abs(nx - hx) + math.abs(ny - hy)
                                if dist < bestDist then
                                    bestDist = dist
                                    bestDir = d
                                end
                            end
                        end
                    end
                    if bestDir then
                        e.x = e.x + bestDir[1]
                        e.y = e.y + bestDir[2]
                    end
                end

            elseif e.type == "patroller" then
                if e.moveTimer >= e.moveInterval then
                    e.moveTimer = 0
                    local nx = e.x + e.dirX
                    local ny = e.y + e.dirY

                    if nx < 0 or nx >= anchoGrilla then
                        e.dirX = -e.dirX
                        nx = e.x + e.dirX
                    end
                    if ny < 0 or ny >= altoGrilla then
                        e.dirY = -e.dirY
                        ny = e.y + e.dirY
                    end

                    local blocked = false
                    for _, s in ipairs(snakeBody) do
                        if s.x == nx and s.y == ny then blocked = true; break end
                    end
                    if not blocked then
                        e.x = nx
                        e.y = ny
                    end
                    if ny < 0 or ny >= altoGrilla then
                        e.dirY = -e.dirY
                        ny = e.y + e.dirY
                    end

                    local occupied = false
                    for _, oe in ipairs(enemies.list) do
                        if oe ~= e and oe.alive and oe.x == nx and oe.y == ny then
                            occupied = true; break
                        end
                    end
                    if not occupied then
                        e.x = nx
                        e.y = ny
                    end
                end

            elseif e.type == "spawner" then
                e.spawnTimer = e.spawnTimer + dt
                if e.spawnTimer >= constants.ENEMY_SPAWNER_INTERVAL then
                    e.spawnTimer = 0
                    local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
                    for _, d in ipairs(dirs) do
                        local nx = e.x + d[1]
                        local ny = e.y + d[2]
                        if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                            local occupied = false
                            for _, s in ipairs(snakeBody) do
                                if s.x == nx and s.y == ny then occupied = true; break end
                            end
                            if not occupied then
                                for _, o in ipairs(obstaclesMod.pos) do
                                    if o.x == nx and o.y == ny then occupied = true; break end
                                end
                            end
                            if not occupied then
                                obstaclesMod.agregar(nx, ny)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Boss update
    if enemies.boss and enemies.boss.alive then
        enemies.boss.moveTimer = enemies.boss.moveTimer + dt
        enemies.boss.spawnTimer = enemies.boss.spawnTimer + dt

        if enemies.boss.moveTimer >= 2.0 then
            enemies.boss.moveTimer = 0
            local attempts = 0
            local nx, ny
            repeat
                nx = love.math.random(1, anchoGrilla - 2)
                ny = love.math.random(1, altoGrilla - 2)
                attempts = attempts + 1
            until attempts > 50 or (math.abs(nx - snakeBody[1].x) + math.abs(ny - snakeBody[1].y) > 3)
            if attempts <= 50 then
                enemies.boss.x = nx
                enemies.boss.y = ny
            end
        end

        if enemies.boss.spawnTimer >= 4.0 then
            enemies.boss.spawnTimer = 0
            local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
            for _, d in ipairs(dirs) do
                local nx = enemies.boss.x + d[1]
                local ny = enemies.boss.y + d[2]
                if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                    local occupied = false
                    for _, s in ipairs(snakeBody) do
                        if s.x == nx and s.y == ny then occupied = true; break end
                    end
                    if not occupied then
                        table.insert(enemies.list, {
                            x = nx, y = ny, type = "patroller", alive = true,
                            dirX = d[1], dirY = d[2], moveTimer = 0, spawnTimer = 0,
                            moveInterval = constants.ENEMY_PATROLLER_SPEED,
                            dropCoins = 0
                        })
                        break
                    end
                end
            end
        end
    end
end

function enemies.killEnemy(idx)
    local e = enemies.list[idx]
    if not e or not e.alive then return nil end
    local tam = constants.TAMANIO_BLOQUE
    local result = {
        px = e.x * tam + tam / 2,
        py = e.y * tam + tam / 2,
        gx = e.x, gy = e.y,
        coins = e.dropCoins, type = e.type
    }
    e.alive = false
    return result
end

function enemies.draw()
    local tam = constants.TAMANIO_BLOQUE
    local time = love.timer.getTime()

    for _, e in ipairs(enemies.list) do
        if e.alive then
            local cx = e.x * tam + tam / 2
            local cy = e.y * tam + tam / 2

            if e.type == "chaser" then
                love.graphics.setColor(constants.COLOR_ENEMY_CHASER[1], constants.COLOR_ENEMY_CHASER[2], constants.COLOR_ENEMY_CHASER[3])
                local pts = {cx, cy - tam/3, cx + tam/3, cy, cx, cy + tam/3, cx - tam/3, cy}
                love.graphics.polygon("fill", pts)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.setLineWidth(1)
                love.graphics.polygon("line", pts)

            elseif e.type == "patroller" then
                love.graphics.setColor(constants.COLOR_ENEMY_PATROLLER[1], constants.COLOR_ENEMY_PATROLLER[2], constants.COLOR_ENEMY_PATROLLER[3])
                local dx, dy = e.dirX, e.dirY
                if dx == 0 and dy == 0 then dx = 1 end
                local angle = math.atan2(dy, dx)
                local r = tam * 0.4
                local pts = {
                    cx + math.cos(angle) * r, cy + math.sin(angle) * r,
                    cx + math.cos(angle + 2.5) * r, cy + math.sin(angle + 2.5) * r,
                    cx + math.cos(angle - 2.5) * r, cy + math.sin(angle - 2.5) * r
                }
                love.graphics.polygon("fill", pts)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.setLineWidth(1)
                love.graphics.polygon("line", pts)

            elseif e.type == "spawner" then
                local pulse = math.sin(time * 2) * 0.2 + 0.8
                love.graphics.setColor(
                    constants.COLOR_ENEMY_SPAWNER[1] * pulse,
                    constants.COLOR_ENEMY_SPAWNER[2] * pulse,
                    constants.COLOR_ENEMY_SPAWNER[3] * pulse
                )
                love.graphics.rectangle("fill", e.x * tam + 2, e.y * tam + 2, tam - 4, tam - 4, 3, 3)
                love.graphics.setColor(1, 1, 1, 0.3 + math.sin(time * 3) * 0.15)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", e.x * tam + 1, e.y * tam + 1, tam - 2, tam - 2, 3, 3)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Boss draw
    if enemies.boss and enemies.boss.alive then
        local cx = enemies.boss.x * tam + tam / 2
        local cy = enemies.boss.y * tam + tam / 2
        local vidaFrac = enemies.boss.vida / enemies.boss.vidaMax
        local pulse = math.sin(time * 3) * 0.2 + 0.8

        local r = 1.0 * pulse
        local g = 0.2 * vidaFrac * pulse
        local b = 0.6 * pulse

        love.graphics.setColor(r, g, b)
        local size = tam * 1.5
        local pts = {
            cx, cy - size/2,
            cx + size/2, cy,
            cx, cy + size/2,
            cx - size/2, cy
        }
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", pts)
        love.graphics.setLineWidth(1)

        -- Ojo del boss
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", cx, cy, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", cx, cy, 1.5)
    end
end

return enemies

-- =============================================================================
-- MÓDULO: entities/snake/movement.lua
-- Parte de P02 — Split de entities/snake.lua (922 → 4 submódulos + fachada)
-- Gestiona movimiento táctico, cola de inputs y colisiones de paso.
-- Extraído de entities/snake.lua sin cambios de semántica.
-- =============================================================================
local movement = {}
local constants = require("constants")
local shop = require("systems.shop")
local enemies = require("entities.enemies")
local world = require("core.world")

local function immune()
    return world.get("debugImmune") or false
end

local function hasWrap()
    local wf = package.loaded["world.world"]
    if not wf then
        local ok, res = pcall(require, "world.world")
        if ok then wf = res end
    end
    if wf and wf.hasWallWrap then
        return wf.hasWallWrap()
    end
    return true
end

function movement.checkTailSnap(s)
    if not s or not s.pendingTailSnap or not s.body or #s.body == 0 then return nil end
    s.pendingTailSnap = false
    local tail = s.body[#s.body]
    local tam = constants.TAMANIO_BLOQUE or 20
    return {
        gx = tail.x,
        gy = tail.y,
        px = tail.x * tam + tam / 2,
        py = tail.y * tam + tam / 2
    }
end

function movement.mover(s, foodPos, anchoGrilla, altoGrilla, obstaclePos, magnetRange, twinPos)
    if not s or not s.body or #s.body == 0 then return false, false end
    s.inputQueue = s.inputQueue or {}

    local controlMode = world.get("controlMode") or "tactical"
    if controlMode == "tactical" then
        local isHeld = false
        if love.keyboard and love.keyboard.isDown then
            isHeld = love.keyboard.isDown("up", "w", "down", "s", "left", "a", "right", "d")
        end
        local touchMod = package.loaded["core.touch"]
        if touchMod and touchMod.hasActiveTouch and touchMod.hasActiveTouch() then
            isHeld = true
        end
        if #s.inputQueue > 0 then isHeld = true end

        if not isHeld then
            s.standstill = true
            s.prevBody = {}
            for i, segment in ipairs(s.body) do
                s.prevBody[i] = {x = segment.x, y = segment.y}
            end
            return true, false
        end
        s.standstill = false
    end

    if #s.inputQueue == 0 and love.keyboard and love.keyboard.isDown then
        local refY = s.lastMovedDirY or s.dirY
        local refX = s.lastMovedDirX or s.dirX
        if (love.keyboard.isDown("up") or love.keyboard.isDown("w")) and refY == 0 then
            table.insert(s.inputQueue, {x = 0, y = -1})
        elseif (love.keyboard.isDown("down") or love.keyboard.isDown("s")) and refY == 0 then
            table.insert(s.inputQueue, {x = 0, y = 1})
        elseif (love.keyboard.isDown("left") or love.keyboard.isDown("a")) and refX == 0 then
            table.insert(s.inputQueue, {x = -1, y = 0})
        elseif (love.keyboard.isDown("right") or love.keyboard.isDown("d")) and refX == 0 then
            table.insert(s.inputQueue, {x = 1, y = 0})
        end
    end

    if #s.inputQueue > 0 then
        local nextDir = table.remove(s.inputQueue, 1)
        s.dirX = nextDir.x
        s.dirY = nextDir.y
    end
    s.hasNewInput = false

    s.lastMovedDirX = s.dirX
    s.lastMovedDirY = s.dirY

    local nuevaCabezaX = s.body[1].x + s.dirX
    local nuevaCabezaY = s.body[1].y + s.dirY

    s.prevBody = {}
    for i, segment in ipairs(s.body) do
        s.prevBody[i] = {x = segment.x, y = segment.y}
    end

    if hasWrap() then
        if nuevaCabezaX < 0 then nuevaCabezaX = anchoGrilla - 1
        elseif nuevaCabezaX >= anchoGrilla then nuevaCabezaX = 0
        end
        if nuevaCabezaY < 0 then nuevaCabezaY = altoGrilla - 1
        elseif nuevaCabezaY >= altoGrilla then nuevaCabezaY = 0
        end
    else
        if nuevaCabezaX < 0 or nuevaCabezaX >= anchoGrilla or nuevaCabezaY < 0 or nuevaCabezaY >= altoGrilla then
            if not immune() then
                if shop.shieldActive then
                    shop.shieldActive = false
                    return true, false
                elseif s.armor and s.armor > 0 then
                    s.armor = s.armor - 1
                    return true, false
                else
                    return false, false
                end
            else
                nuevaCabezaX = math.max(0, math.min(anchoGrilla - 1, nuevaCabezaX))
                nuevaCabezaY = math.max(0, math.min(altoGrilla - 1, nuevaCabezaY))
            end
        end
    end

    for _, segmento in ipairs(s.body) do
        if nuevaCabezaX == segmento.x and nuevaCabezaY == segmento.y then
            if s.ghost or immune() then
            elseif shop.shieldActive then
                shop.shieldActive = false
                return true, false
            elseif s.armor and s.armor > 0 then
                s.armor = s.armor - 1
                return true, false
            else
                return false, false
            end
        end
    end

    local obstaclesMod = package.loaded["entities.obstacles"]
    if not obstaclesMod then
        local ok, res = pcall(require, "entities.obstacles")
        if ok then obstaclesMod = res end
    end

    if obstaclesMod then
        obstaclesMod.triggerPressureSpike(nuevaCabezaX, nuevaCabezaY)
        local isLethal, hazardObs = obstaclesMod.isHazardLethal(nuevaCabezaX, nuevaCabezaY)
        if isLethal and not s.ghost and not immune() then
            if shop.shieldActive then
                shop.shieldActive = false
                return true, false
            elseif s.armor and s.armor > 0 then
                s.armor = s.armor - 1
                return true, false
            else
                return false, false
            end
        end
    end

    if obstaclePos then
        for _, obs in ipairs(obstaclePos) do
            if nuevaCabezaX == obs.x and nuevaCabezaY == obs.y then
                local isPassable = (obs.type == "ice" or obs.type == "slime" or (obs.type == "lava" and obs.state ~= "active") or (obs.type == "pressure_spike" and obs.state ~= "extended"))
                if not isPassable then
                    if immune() then
                    elseif shop.shieldActive then
                        shop.shieldActive = false
                        return true, false
                    elseif s.armor and s.armor > 0 then
                        s.armor = s.armor - 1
                        return true, false
                    else
                        return false, false
                    end
                end
            end
        end
    end

    if enemies.boss and enemies.boss.alive and nuevaCabezaX == enemies.boss.x and nuevaCabezaY == enemies.boss.y then
        if not s.ghost and not immune() then
            local bossResult = enemies.hitBoss and enemies.hitBoss() or {hit = true}
            if bossResult then
                if shop.shieldActive then
                    shop.shieldActive = false
                    return true, false, nil, bossResult
                elseif s.armor and s.armor > 0 then
                    s.armor = s.armor - 1
                    return true, false, nil, bossResult
                else
                    return false, false, nil, bossResult
                end
            end
        end
    end

    if enemies.getAttackObjects then
        for _, ao in ipairs(enemies.getAttackObjects() or {}) do
            local hit = false
            if ao.type == "projectile" then
                if math.abs(nuevaCabezaX - ao.x) < 0.6 and math.abs(nuevaCabezaY - ao.y) < 0.6 then
                    hit = true
                end
            elseif ao.type == "radial_pulse" then
                local dist = math.sqrt((nuevaCabezaX - ao.cx) ^ 2 + (nuevaCabezaY - ao.cy) ^ 2)
                if dist >= ao.radius - 0.5 and dist <= ao.radius + 0.5 then
                    hit = true
                end
            end
            if hit then
                if s.ghost or immune() then
                elseif shop.shieldActive then
                    shop.shieldActive = false
                elseif s.armor and s.armor > 0 then
                    s.armor = s.armor - 1
                else
                    return false, false, nil, nil, {hit = true, damage = ao.damage or 1}
                end
            end
        end
    end

    if enemies.list then
        for i = #enemies.list, 1, -1 do
            local e = enemies.list[i]
            if e and e.alive and nuevaCabezaX == e.x and nuevaCabezaY == e.y then
                if s.ghost or immune() then
                else
                    if shop.shieldActive then
                        shop.shieldActive = false
                        local result = enemies.killEnemy(i)
                        return true, false, result
                    elseif s.armor and s.armor > 0 then
                        s.armor = s.armor - 1
                        local result = enemies.killEnemy(i)
                        return true, false, result
                    else
                        return false, false, nil
                    end
                end
            end
        end
    end

    table.insert(s.body, 1, {x = nuevaCabezaX, y = nuevaCabezaY})

    local comio = false
    local comioTwin = false
    if magnetRange and magnetRange > 0 and anchoGrilla and altoGrilla then
        local wrap = hasWrap()
        for dy = -magnetRange, magnetRange do
            for dx = -magnetRange, magnetRange do
                local checkX, checkY
                if wrap then
                    checkX = (nuevaCabezaX + dx) % anchoGrilla
                    checkY = (nuevaCabezaY + dy) % altoGrilla
                else
                    checkX = nuevaCabezaX + dx
                    checkY = nuevaCabezaY + dy
                    if checkX <0 or checkX>=anchoGrilla or checkY<0 or checkY>=altoGrilla then
                        checkX=nil; checkY=nil
                    end
                end
                if checkX and foodPos and checkX == foodPos.x and checkY == foodPos.y then
                    comio = true
                    break
                elseif checkX and twinPos and checkX == twinPos.x and checkY == twinPos.y then
                    comio = true
                    comioTwin = true
                    break
                end
            end
            if comio then break end
        end
    else
        if foodPos and nuevaCabezaX == foodPos.x and nuevaCabezaY == foodPos.y then
            comio = true
        elseif twinPos and nuevaCabezaX == twinPos.x and nuevaCabezaY == twinPos.y then
            comio = true
            comioTwin = true
        end
    end

    if comio then
        return true, true, nil, nil, nil, comioTwin
    else
        local removed = table.remove(s.body)
        table.insert(s.trail, {x = removed.x, y = removed.y, alpha = 0.5})
        if #s.trail > 6 then table.remove(s.trail, 1) end

        if s.firePepperTimer and s.firePepperTimer > 0 then
            table.insert(s.fireTrail, {
                x = removed.x,
                y = removed.y,
                timer = constants.FIRE_TRAIL_LIFETIME or 1.8,
                maxTimer = constants.FIRE_TRAIL_LIFETIME or 1.8
            })
        end

        return true, false
    end
end

function movement.encolarDireccion(s, tx, ty)
    if not s or not tx or not ty then return end
    s.inputQueue = s.inputQueue or {}

    local curX = s.lastMovedDirX or s.dirX
    local curY = s.lastMovedDirY or s.dirY
    local qLen = #s.inputQueue

    if qLen == 0 then
        if tx == curX and ty == curY then return end
        if (tx == -curX and curX ~= 0) or (ty == -curY and curY ~= 0) then return end
        if (curX ~= 0 and ty ~= 0 and tx == 0) or (curY ~= 0 and tx ~= 0 and ty == 0) then
            table.insert(s.inputQueue, {x = tx, y = ty})
            s.hasNewInput = true
            s.turnHistory = s.turnHistory or {}
            local now = love.timer.getTime()
            table.insert(s.turnHistory, {x = tx, y = ty, fromX = curX, fromY = curY, time = now})
            if #s.turnHistory > 4 then table.remove(s.turnHistory, 1) end
        end
    elseif qLen == 1 then
        local q1 = s.inputQueue[1]
        if tx == q1.x and ty == q1.y then return end

        if (curX ~= 0 and ty ~= 0 and tx == 0) or (curY ~= 0 and tx ~= 0 and ty == 0) then
            s.inputQueue[1] = {x = tx, y = ty}
            s.hasNewInput = true
            s.turnHistory = s.turnHistory or {}
            local now = love.timer.getTime()
            table.insert(s.turnHistory, {x = tx, y = ty, fromX = curX, fromY = curY, time = now})
            if #s.turnHistory > 4 then table.remove(s.turnHistory, 1) end
        elseif (q1.x ~= 0 and ty ~= 0 and tx == 0) or (q1.y ~= 0 and tx ~= 0 and ty == 0) then
            if not ((tx == -q1.x and q1.x ~= 0) or (ty == -q1.y and q1.y ~= 0)) then
                table.insert(s.inputQueue, {x = tx, y = ty})
                s.hasNewInput = true
                s.turnHistory = s.turnHistory or {}
                local now = love.timer.getTime()
                table.insert(s.turnHistory, {x = tx, y = ty, fromX = q1.x, fromY = q1.y, time = now})
                if #s.turnHistory > 4 then table.remove(s.turnHistory, 1) end
            end
        end
    else
        local q1 = s.inputQueue[1]
        if (curX ~= 0 and ty ~= 0 and tx == 0) or (curY ~= 0 and tx ~= 0 and ty == 0) then
            s.inputQueue[1] = {x = tx, y = ty}
            s.inputQueue[2] = nil
            s.hasNewInput = true
        elseif (q1.x ~= 0 and ty ~= 0 and tx == 0) or (q1.y ~= 0 and tx ~= 0 and ty == 0) then
            if not ((tx == -q1.x and q1.x ~= 0) or (ty == -q1.y and q1.y ~= 0)) then
                s.inputQueue[2] = {x = tx, y = ty}
                s.hasNewInput = true
            end
        end
    end

    if s.turnHistory and #s.turnHistory >= 2 then
        local now = love.timer.getTime()
        local t1 = s.turnHistory[#s.turnHistory - 1]
        local t2 = s.turnHistory[#s.turnHistory]
        if now - t1.time <= 0.8 then
            if (t1.fromX == -t2.x and t1.fromX ~= 0) or (t1.fromY == -t2.y and t1.fromY ~= 0) then
                s.pendingTailSnap = true
            end
        end
    end
end

function movement.cambiarDireccion(s, tecla)
    if not tecla then return end
    tecla = string.lower(tostring(tecla))
    local tx, ty
    if tecla == "up" or tecla == "w" then
        tx, ty = 0, -1
    elseif tecla == "down" or tecla == "s" then
        tx, ty = 0, 1
    elseif tecla == "left" or tecla == "a" then
        tx, ty = -1, 0
    elseif tecla == "right" or tecla == "d" then
        tx, ty = 1, 0
    end

    if tx and ty then
        movement.encolarDireccion(s, tx, ty)
    end
end

return movement

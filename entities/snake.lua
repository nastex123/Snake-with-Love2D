-- =============================================================================
-- MÃ“DULO DE LA SERPIENTE
-- Contiene la lÃ³gica de movimiento, colisiones y dibujo del cuerpo.
-- =============================================================================
local snake = {}
local constants = require("constants")
local shop = require("systems.shop")
local enemies = require("entities.enemies")
local world = require("core.world")

-- lectura del estado debug (legacy global debugImmune -> world.state.debugImmune)
local function immune()
    return world.get("debugImmune") or false
end

local function hsv2rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p end
    if i == 1 then return q, v, p end
    if i == 2 then return p, v, t end
    if i == 3 then return p, q, v end
    if i == 4 then return t, p, v end
    return v, p, q
end

function snake.reset()
    return {
        body = {
            {x = 5, y = 5},
            {x = 4, y = 5},
            {x = 3, y = 5}
        },
        dirX = 1,
        dirY = 0,
        lastMovedDirX = 1,
        lastMovedDirY = 0,
        inputQueue = {},
        prevBody = {
            {x = 5, y = 5},
            {x = 4, y = 5},
            {x = 3, y = 5}
        },
        trail = {},
        ghost = false,
        ghostTimer = 0,
        armor = 0,
        flashTimer = 0,
        autotomyCooldown = 0,
        decoys = {},
        constrictorBuffTimer = 0,
        reverseSlitherTimer = 0,
        reverseSlitherCooldown = 0,
        firePepperTimer = 0,
        fireTrail = {},
        turnHistory = {},
        standstill = true,
        hasNewInput = false
    }
end

function snake.update(s, dt)
    if not s then return end
    if s.flashTimer and s.flashTimer > 0 then
        s.flashTimer = math.max(0, s.flashTimer - dt)
    end
    if s.ghostTimer and s.ghostTimer > 0 then
        s.ghostTimer = math.max(0, s.ghostTimer - dt)
        if s.ghostTimer <= 0 and not shop.ghostActive then
            s.ghost = false
        end
    end
    if s.autotomyCooldown and s.autotomyCooldown > 0 then
        s.autotomyCooldown = math.max(0, s.autotomyCooldown - dt)
    end
    if s.reverseSlitherTimer and s.reverseSlitherTimer > 0 then
        s.reverseSlitherTimer = math.max(0, s.reverseSlitherTimer - dt)
    end
    if s.reverseSlitherCooldown and s.reverseSlitherCooldown > 0 then
        s.reverseSlitherCooldown = math.max(0, s.reverseSlitherCooldown - dt)
    end
    if s.constrictorBuffTimer and s.constrictorBuffTimer > 0 then
        s.constrictorBuffTimer = math.max(0, s.constrictorBuffTimer - dt)
    end
    if s.firePepperTimer and s.firePepperTimer > 0 then
        s.firePepperTimer = math.max(0, s.firePepperTimer - dt)
    end
    if s.fireTrail then
        for i = #s.fireTrail, 1, -1 do
            local ft = s.fireTrail[i]
            ft.timer = ft.timer - dt
            if ft.timer <= 0 then
                table.remove(s.fireTrail, i)
            end
        end
    end
    if s.decoys then
        for i = #s.decoys, 1, -1 do
            local dec = s.decoys[i]
            dec.timer = dec.timer - dt
            if dec.timer <= 0 then
                table.remove(s.decoys, i)
            end
        end
    end
end

function snake.triggerReverseSlither(s)
    if not s or not s.body or #s.body < 2 then return false end
    s.reverseSlitherCooldown = s.reverseSlitherCooldown or 0
    if s.reverseSlitherCooldown > 0 then return false end

    local n = #s.body
    for i = 1, math.floor(n / 2) do
        s.body[i], s.body[n - i + 1] = s.body[n - i + 1], s.body[i]
    end

    local h = s.body[1]
    local neck = s.body[2]
    local dx = h.x - neck.x
    local dy = h.y - neck.y
    if math.abs(dx) > 1 then dx = dx > 0 and -1 or 1 end
    if math.abs(dy) > 1 then dy = dy > 0 and -1 or 1 end

    if dx ~= 0 and dy == 0 then
        s.dirX = dx
        s.dirY = 0
    elseif dy ~= 0 and dx == 0 then
        s.dirX = 0
        s.dirY = dy
    elseif dx ~= 0 then
        s.dirX = dx
        s.dirY = 0
    elseif dy ~= 0 then
        s.dirX = 0
        s.dirY = dy
    else
        s.dirX = -s.dirX
        s.dirY = -s.dirY
    end

    s.lastMovedDirX = s.dirX
    s.lastMovedDirY = s.dirY
    s.inputQueue = {}

    s.ghost = true
    s.ghostTimer = 1.2
    s.reverseSlitherTimer = constants.REVERSE_SLITHER_DURATION or 3.0
    s.reverseSlitherCooldown = constants.REVERSE_SLITHER_COOLDOWN or 10.0

    s.prevBody = {}
    for i, seg in ipairs(s.body) do
        s.prevBody[i] = {x = seg.x, y = seg.y}
    end
    return true, h
end

function snake.applySlimming(s)
    if not s or not s.body then return false end
    local minLen = constants.SLIMMING_MIN_LENGTH or 12
    if #s.body >= minLen then
        local factor = constants.SLIMMING_FACTOR or 0.5
        local target = math.max(3, math.floor(#s.body * factor))
        while #s.body > target do
            table.remove(s.body)
        end
        return true
    end
    return false
end

function snake.triggerAutotomy(s)
    if not s or not s.body then return false end
    s.autotomyCooldown = s.autotomyCooldown or 0
    s.decoys = s.decoys or {}

    if s.autotomyCooldown <= 0 and #s.body >= 4 then
        local r1 = table.remove(s.body)
        local r2 = table.remove(s.body)
        local decoyPos = r1 or r2
        table.insert(s.decoys, {
            x = decoyPos.x,
            y = decoyPos.y,
            timer = constants.AUTOTOMY_DECOY_DURATION or 4.0,
            maxTimer = constants.AUTOTOMY_DECOY_DURATION or 4.0
        })
        s.ghost = true
        s.ghostTimer = constants.AUTOTOMY_GHOST_DURATION or 1.5
        s.autotomyCooldown = constants.AUTOTOMY_COOLDOWN or 8.0
        return true, decoyPos
    end
    return false
end

local function pointInPolygon(px, py, poly)
    local inside = false
    local n = #poly
    if n < 4 then return false end
    local j = n
    for i = 1, n do
        local xi, yi = poly[i].x + 0.5, poly[i].y + 0.5
        local xj, yj = poly[j].x + 0.5, poly[j].y + 0.5
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / ((yj - yi) + 1e-9) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function snake.checkConstrictorLoop(s, enemiesList)
    if not s or not s.body or #s.body < 8 or not enemiesList then return nil end
    local killed = {}
    for i = #enemiesList, 1, -1 do
        local e = enemiesList[i]
        if e.alive then
            local onBody = false
            for _, seg in ipairs(s.body) do
                if seg.x == e.x and seg.y == e.y then
                    onBody = true
                    break
                end
            end
            if not onBody and pointInPolygon(e.x + 0.5, e.y + 0.5, s.body) then
                table.insert(killed, {
                    index = i,
                    enemy = e,
                    x = e.x,
                    y = e.y,
                    type = e.type,
                    coins = (e.dropCoins or 1) * 2
                })
            end
        end
    end
    if #killed > 0 then
        s.constrictorBuffTimer = constants.CONSTRICTOR_BUFF_DURATION or 5.0
        return killed
    end
    return nil
end

function snake.mover(s, foodPos, anchoGrilla, altoGrilla, obstaclePos, magnetRange, twinPos)
    s.inputQueue = s.inputQueue or {}

    -- Modo de control táctico: requiere tecla direccional sostenida para avanzar
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

    -- Si la cola está vacía, revisar si el jugador mantiene pulsada una tecla perpendicular válida
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

    -- Consumir el siguiente comando en cola si existe
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

    -- Colisiones con bordes: wall wrap
    if nuevaCabezaX < 0 then nuevaCabezaX = anchoGrilla - 1
    elseif nuevaCabezaX >= anchoGrilla then nuevaCabezaX = 0
    end
    if nuevaCabezaY < 0 then nuevaCabezaY = altoGrilla - 1
    elseif nuevaCabezaY >= altoGrilla then nuevaCabezaY = 0
    end

    -- Verificación de colisiones con el cuerpo
    for _, segmento in ipairs(s.body) do
        if nuevaCabezaX == segmento.x and nuevaCabezaY == segmento.y then
            if s.ghost or immune() then
            elseif shop.shieldActive then
                shop.shieldActive = false
                return true, false
            elseif s.armor > 0 then
                s.armor = s.armor - 1
                return true, false
            else
                return false, false
            end
        end
    end

    -- Verificación de colisiones con obstáculos
    if obstaclePos then
        for _, obs in ipairs(obstaclePos) do
            if nuevaCabezaX == obs.x and nuevaCabezaY == obs.y then
                if immune() then
                elseif shop.shieldActive then
                    shop.shieldActive = false
                    return true, false
                elseif s.armor > 0 then
                    s.armor = s.armor - 1
                    return true, false
                else
                    return false, false
                end
            end
        end
    end

    -- Colision con jefe
    if enemies.boss and enemies.boss.alive and nuevaCabezaX == enemies.boss.x and nuevaCabezaY == enemies.boss.y then
        if not s.ghost and not immune() then
            local bossResult = enemies.hitBoss()
            if bossResult then
                if shop.shieldActive then
                    shop.shieldActive = false
                    return true, false, nil, bossResult
                elseif s.armor > 0 then
                    s.armor = s.armor - 1
                    return true, false, nil, bossResult
                else
                    return false, false, nil, bossResult
                end
            end
        end
    end

    -- Colision con objetos de ataque (proyectiles, pulsos)
    for _, ao in ipairs(enemies.getAttackObjects()) do
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
                -- pass through
            elseif shop.shieldActive then
                shop.shieldActive = false
            elseif s.armor > 0 then
                s.armor = s.armor - 1
            else
                return false, false, nil, nil, {hit = true, damage = ao.damage or 1}
            end
        end
    end

    -- Verificacion de colisiones con enemigos
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]
        if e.alive and nuevaCabezaX == e.x and nuevaCabezaY == e.y then
            if s.ghost or immune() then
            else
                if shop.shieldActive then
                    shop.shieldActive = false
                    local result = enemies.killEnemy(i)
                    return true, false, result
                elseif s.armor > 0 then
                    s.armor = s.armor - 1
                    local result = enemies.killEnemy(i)
                    return true, false, result
                else
                    return false, false, nil
                end
            end
        end
    end

    table.insert(s.body, 1, {x = nuevaCabezaX, y = nuevaCabezaY})

    -- Verificar si come comida primaria o gemela (con o sin iman)
    local comio = false
    local comioTwin = false
    if magnetRange and magnetRange > 0 then
        for dy = -magnetRange, magnetRange do
            for dx = -magnetRange, magnetRange do
                local checkX = nuevaCabezaX + dx
                local checkY = nuevaCabezaY + dy
                if checkX == foodPos.x and checkY == foodPos.y then
                    comio = true
                    break
                elseif twinPos and checkX == twinPos.x and checkY == twinPos.y then
                    comio = true
                    comioTwin = true
                    break
                end
            end
            if comio then break end
        end
    else
        if nuevaCabezaX == foodPos.x and nuevaCabezaY == foodPos.y then
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

function snake.checkTailSnap(s)
    if not s or not s.pendingTailSnap or not s.body or #s.body == 0 then return nil end
    s.pendingTailSnap = false
    local tail = s.body[#s.body]
    local tam = constants.TAMANIO_BLOQUE
    return {
        gx = tail.x,
        gy = tail.y,
        px = tail.x * tam + tam / 2,
        py = tail.y * tam + tam / 2
    }
end

function snake.draw(s, alpha)
    local numSegments = #s.body
    if numSegments == 0 then return end
    local tam = constants.TAMANIO_BLOQUE
    local size = tam
    local time = love.timer.getTime()

    -- Dibujar rastro de fuego de Fire Pepper
    if s.fireTrail and #s.fireTrail > 0 then
        for _, ft in ipairs(s.fireTrail) do
            local frac = math.max(0, ft.timer / (ft.maxTimer or 1.8))
            local fPulse = math.sin(time * 15 + ft.x * 3) * 0.2 + 0.8
            love.graphics.setColor(1.0, 0.4 * frac, 0.0, frac * fPulse * 0.7)
            love.graphics.rectangle("fill", ft.x * tam + 1, ft.y * tam + 1, tam - 2, tam - 2, 3, 3)
            love.graphics.setColor(1.0, 0.9, 0.2, frac * fPulse * 0.9)
            love.graphics.rectangle("fill", ft.x * tam + 3, ft.y * tam + 3, tam - 6, tam - 6, 2, 2)
        end
    end

    -- Easing cubico: suaviza arranque y frenado de cada paso
    local easedAlpha = alpha * alpha * (3 - 2 * alpha)

    local positions = {}
    local colors = {}
    for i, segmento in ipairs(s.body) do
        local dx, dy
        if s.prevBody[i] then
            local rawDx = segmento.x - s.prevBody[i].x
            local rawDy = segmento.y - s.prevBody[i].y
            if math.abs(rawDx) > 1 or math.abs(rawDy) > 1 then
                dx = segmento.x
                dy = segmento.y
            else
                dx = s.prevBody[i].x * (1 - easedAlpha) + segmento.x * easedAlpha
                dy = s.prevBody[i].y * (1 - easedAlpha) + segmento.y * easedAlpha
            end
        else
            dx = segmento.x
            dy = segmento.y
        end
        positions[i] = {x = dx, y = dy}
        local t = numSegments > 1 and (i - 1) / (numSegments - 1) or 0
        local hue = ((love.timer.getTime() * 30 + i * 20) % 360) / 360
        local sat = 0.7 + t * 0.3
        local val = 0.5 + (1 - t) * 0.4
        local r, g, b = hsv2rgb(hue, sat, val)
        if s.firePepperTimer and s.firePepperTimer > 0 then
            r, g, b = 1.0, 0.3 + t * 0.4, 0.1
        elseif s.constrictorBuffTimer and s.constrictorBuffTimer > 0 then
            r, g, b = 0.6 + t * 0.3, 0.1, 0.9
        elseif s.reverseSlitherTimer and s.reverseSlitherTimer > 0 then
            r, g, b = 0.0, 0.94, 0.8 + t * 0.2
        end
        colors[i] = {r, g, b, 1.0 - t * 0.4}
    end

    for i = 1, numSegments - 1 do
        local p1, p2 = positions[i], positions[i + 1]
        if math.abs(p1.x - p2.x) <= 1 and math.abs(p1.y - p2.y) <= 1 then
            local c1, c2 = colors[i], colors[i + 1]
            love.graphics.setColor(
                (c1[1] + c2[1]) / 2, (c1[2] + c2[2]) / 2,
                (c1[3] + c2[3]) / 2, (c1[4] + c2[4]) / 2
            )
            local minX = math.min(p1.x, p2.x) * tam + 2
            local minY = math.min(p1.y, p2.y) * tam + 2
            local maxX = math.max(p1.x, p2.x) * tam + tam - 2
            local maxY = math.max(p1.y, p2.y) * tam + tam - 2
            love.graphics.rectangle("fill", minX, minY, maxX - minX, maxY - minY)
        end
    end

    for i = #s.trail, 1, -1 do
        local t = s.trail[i]
        t.alpha = t.alpha - 0.02
        if t.alpha > 0 then
            local ti = (i - 1) / math.max(1, #s.trail - 1)
            local r = 0.2 + ti * 0.1
            local g = 0.7 - ti * 0.3
            local b = 0.3 + ti * 0.2
            love.graphics.setColor(r, g, b, t.alpha * 0.3)
            love.graphics.rectangle("fill", t.x * tam + 4, t.y * tam + 4, tam - 8, tam - 8, 2, 2)
        else
            table.remove(s.trail, i)
        end
    end

    for i, segmento in ipairs(s.body) do
        local px = positions[i].x * tam
        local py = positions[i].y * tam
        local c = colors[i]
        local esCola = (i == numSegments)
        local animarCola = esCola and s.flashTimer > 0
        local breath = math.sin(time * 2 + i * 0.7) * 0.3
        local segSize = size

        love.graphics.setColor(c[1], c[2], c[3], c[4])

        if animarCola then
            local pulso = 1 + math.sin(s.flashTimer * 30) * 0.2
            love.graphics.push()
            love.graphics.translate(px + segSize / 2, py + segSize / 2)
            love.graphics.scale(pulso)
            love.graphics.translate(-(px + segSize / 2), -(py + segSize / 2))
            if math.floor(s.flashTimer * 15) % 2 == 0 then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(c[1], c[2], c[3], c[4])
            end
            love.graphics.rectangle("fill", px, py, segSize, segSize, 3, 3)
            love.graphics.pop()
        else
            if esCola then
                local inset = 3 + breath
                love.graphics.rectangle("fill", px + inset, py + inset,
                    segSize - inset * 2, segSize - inset * 2, 2, 2)
            else
                love.graphics.rectangle("fill", px, py, segSize, segSize, 3, 3)
                love.graphics.setColor(
                    math.min(1, c[1] + 0.12 + breath * 0.02),
                    math.min(1, c[2] + 0.12 + breath * 0.02),
                    math.min(1, c[3] + 0.12 + breath * 0.02),
                    c[4] * 0.35
                )
                love.graphics.rectangle("fill", px + 2, py + 2,
                    segSize - 4, segSize - 4, 2, 2)
            end

            if i == 1 and numSegments > 0 then
                local eyeOff, eyeGap
                if s.dirX == 1 then
                    eyeOff = {x = segSize - 6, y = 3}
                    eyeGap = {x = 0, y = 4}
                elseif s.dirX == -1 then
                    eyeOff = {x = 3, y = 3}
                    eyeGap = {x = 0, y = 4}
                elseif s.dirY == -1 then
                    eyeOff = {x = 3, y = 2}
                    eyeGap = {x = 4, y = 0}
                elseif s.dirY == 1 then
                    eyeOff = {x = 3, y = segSize - 6}
                    eyeGap = {x = 4, y = 0}
                else
                    eyeOff = {x = segSize - 6, y = 3}
                    eyeGap = {x = 0, y = 4}
                end
                for e = 0, 1 do
                    local ex = px + eyeOff.x + e * eyeGap.x
                    local ey = py + eyeOff.y + e * eyeGap.y
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.rectangle("fill", ex, ey, 3, 3)
                    local pupilCol = s.standstill and {0.0, 0.94, 1.0} or {0, 0, 0}
                    love.graphics.setColor(pupilCol[1], pupilCol[2], pupilCol[3])
                    love.graphics.rectangle("fill", ex + 1, ey + 1, 1, 1)
                end

                if s.ghost then
                    local ghostPulse = math.sin(time * 6) * 0.3 + 0.7
                    love.graphics.setColor(0.6, 0.4, 1, ghostPulse * 0.3)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", px - 2, py - 2, segSize + 4, segSize + 4, 4, 4)
                    love.graphics.setLineWidth(1)
                end

                if shop.shieldActive then
                    local pulse = math.sin(time * 5) * 0.3 + 0.7
                    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pulse * 0.6)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", px - 1, py - 1, segSize + 2, segSize + 2, 4, 4)
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end

    -- Dibujar señuelos de autotomia activos
    if s.decoys and #s.decoys > 0 then
        for _, dec in ipairs(s.decoys) do
            local dFrac = math.max(0, dec.timer / (dec.maxTimer or 4.0))
            local pulse = math.sin(time * 12) * 0.2 + 0.8
            love.graphics.setColor(0.7, 0.2, 0.9, dFrac * pulse * 0.8)
            love.graphics.rectangle("fill", dec.x * tam + 2, dec.y * tam + 2, tam - 4, tam - 4, 3, 3)
            love.graphics.setColor(0.0, 0.94, 1.0, dFrac * pulse)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", dec.x * tam + 1, dec.y * tam + 1, tam - 2, tam - 2, 3, 3)
            love.graphics.setLineWidth(1)
        end
    end
end

function snake.encolarDireccion(s, tx, ty)
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

function snake.cambiarDireccion(s, tecla)
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
        snake.encolarDireccion(s, tx, ty)
    end
end

return snake

-- =============================================================================
-- MÓDULO DE LA SERPIENTE
-- Contiene la lógica de movimiento, colisiones y dibujo del cuerpo.
-- =============================================================================
local snake = {}
local constants = require("constants")
local shop = require("shop")
local enemies = require("enemies")

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
        prevBody = {
            {x = 5, y = 5},
            {x = 4, y = 5},
            {x = 3, y = 5}
        },
        trail = {},
        ghost = false,
        armor = 0,
        flashTimer = 0
    }
end

function snake.mover(s, foodPos, anchoGrilla, altoGrilla, obstaclePos, magnetRange)
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
            if s.ghost then
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
                if shop.shieldActive then
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
        if not s.ghost then
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

    -- Verificacion de colisiones con enemigos
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]
        if e.alive and nuevaCabezaX == e.x and nuevaCabezaY == e.y then
            if s.ghost then
            else
                local result = enemies.killEnemy(i)
                if result then
                    if shop.shieldActive then
                        shop.shieldActive = false
                        return true, false, result
                    elseif s.armor > 0 then
                        s.armor = s.armor - 1
                        return true, false, result
                    else
                        return false, false, result
                    end
                end
            end
        end
    end

    table.insert(s.body, 1, {x = nuevaCabezaX, y = nuevaCabezaY})

    -- Verificar si come con rango normal o de imán
    local comio = false
    if magnetRange and magnetRange > 0 then
        for dy = -magnetRange, magnetRange do
            for dx = -magnetRange, magnetRange do
                local checkX = nuevaCabezaX + dx
                local checkY = nuevaCabezaY + dy
                if checkX == foodPos.x and checkY == foodPos.y then
                    comio = true
                    break
                end
            end
            if comio then break end
        end
    else
        if nuevaCabezaX == foodPos.x and nuevaCabezaY == foodPos.y then
            comio = true
        end
    end

    if comio then
        return true, true
    else
        local removed = table.remove(s.body)
        table.insert(s.trail, {x = removed.x, y = removed.y, alpha = 0.5})
        if #s.trail > 6 then table.remove(s.trail, 1) end
        return true, false
    end
end

function snake.draw(s, alpha)
    local numSegments = #s.body
    if numSegments == 0 then return end
    local tam = constants.TAMANIO_BLOQUE
    local size = tam

    -- Easing cúbico: suaviza arranque y frenado de cada paso
    local easedAlpha = alpha * alpha * (3 - 2 * alpha)

    local positions = {}
    local colors = {}
    for i, segmento in ipairs(s.body) do
        local dx, dy
        if s.prevBody[i] then
            local rawDx = segmento.x - s.prevBody[i].x
            local rawDy = segmento.y - s.prevBody[i].y
            -- Si el delta supera 1 celda es un wrap: no interpolar ese segmento
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
        colors[i] = {r, g, b, 1.0 - t * 0.4}
    end

    for i = 1, numSegments - 1 do
        local p1, p2 = positions[i], positions[i + 1]
        -- Si los segmentos están separados más de 1 celda es un wrap: no dibujar conector
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
        end
    end
    for i = #s.trail, 1, -1 do
        if s.trail[i].alpha <= 0 then table.remove(s.trail, i) end
    end

    local time = love.timer.getTime()

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
                    love.graphics.setColor(0, 0, 0)
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
end

function snake.cambiarDireccion(s, tecla)
    if (tecla == "up" or tecla == "w") and s.dirY ~= 1 then
        s.dirX = 0
        s.dirY = -1
    elseif (tecla == "down" or tecla == "s") and s.dirY ~= -1 then
        s.dirX = 0
        s.dirY = 1
    elseif (tecla == "left" or tecla == "a") and s.dirX ~= 1 then
        s.dirX = -1
        s.dirY = 0
    elseif (tecla == "right" or tecla == "d") and s.dirX ~= -1 then
        s.dirX = 1
        s.dirY = 0
    end
end

return snake
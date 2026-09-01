-- =============================================================================
-- MÓDULO DE LA SERPIENTE — Fachada (P02)
-- P02 Split 922 → fachada ~320L + 4 submódulos:
--   entities/snake/core.lua       (reset, update)
--   entities/snake/abilities.lua  (triggerReverseSlither, applySlimming, triggerAutotomy)
--   entities/snake/collisions.lua (checkEnemyCollisions, checkPatrollerSlice, checkConstrictorLoop)
--   entities/snake/movement.lua   (mover, encolarDireccion, cambiarDireccion, checkTailSnap)
-- Mantiene API pública idéntica.
-- =============================================================================
local snake = {}
local constants = require("constants")
local shop = require("systems.shop")
local core = require("entities.snake.core")
local abilities = require("entities.snake.abilities")
local collisions = require("entities.snake.collisions")
local movement = require("entities.snake.movement")

-- ---------------------------------------------------------------------------
-- Helpers de render (solo usado en draw)
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Delegaciones — Core
-- ---------------------------------------------------------------------------
snake.reset = core.reset
snake.update = core.update

-- ---------------------------------------------------------------------------
-- Delegaciones — Abilities
-- ---------------------------------------------------------------------------
snake.triggerReverseSlither = abilities.triggerReverseSlither
snake.applySlimming = abilities.applySlimming
snake.triggerAutotomy = abilities.triggerAutotomy

-- ---------------------------------------------------------------------------
-- Delegaciones — Collisions
-- ---------------------------------------------------------------------------
snake.checkEnemyCollisions = collisions.checkEnemyCollisions
snake.checkPatrollerSlice = collisions.checkPatrollerSlice
snake.checkConstrictorLoop = collisions.checkConstrictorLoop

-- ---------------------------------------------------------------------------
-- Delegaciones — Movement
-- ---------------------------------------------------------------------------
snake.mover = movement.mover
snake.encolarDireccion = movement.encolarDireccion
snake.cambiarDireccion = movement.cambiarDireccion
snake.checkTailSnap = movement.checkTailSnap

-- ---------------------------------------------------------------------------
-- Draw — permanece en fachada (render separado de lógica, pero evita 5º módulo)
-- ---------------------------------------------------------------------------
function snake.draw(s, alpha)
    local numSegments = s and s.body and #s.body or 0
    if numSegments == 0 then return end
    s.prevBody = s.prevBody or s.body
    local tam = constants.TAMANIO_BLOQUE or 20
    local size = tam
    local time = love.timer.getTime()

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

    if s.trail then
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

return snake

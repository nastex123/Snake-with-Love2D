local draw = {}
local constants = require("constants")
local world = require("core.world")

local TAU = math.pi * 2

-- Chaser "Estrella de espinas" (propuesta 6): estrella de 4 puntas con ojo
-- central que rastrea a la serpiente. Estados: idle/chase/flank/encircle/close.
local AMBER = {0.95, 0.64, 0.24}
local EYE_DARK = {0.09, 0.04, 0.05}
local WARM_WHITE = {1, 0.91, 0.69}

local function starPoints(cx, cy, rot, rOut, rIn)
    local pts = {}
    for i = 0, 7 do
        local r = (i % 2 == 0) and rOut or rIn
        local a = rot + i * math.pi / 4 - math.pi / 2
        pts[#pts + 1] = cx + math.cos(a) * r
        pts[#pts + 1] = cy + math.sin(a) * r
    end
    return pts
end

local function drawChaser(e, tam, time, head)
    local cx = e.x * tam + tam / 2
    local cy = e.y * tam + tam / 2
    local st = e.aiState or "chase"
    local k = tam / 15
    local seed = e.seed or 0
    local col = constants.COLOR_ENEMY_CHASER

    local on = math.floor(time * 14) % 2 == 0
    local blink = st == "close" and on
    local pul = 0.5 + 0.5 * math.sin(time * 7 + seed)
    local th = 0.5 + 0.5 * math.sin(time * 4 + seed)
    local alpha = 1
    if st == "idle" then
        alpha = 0.38 + 0.14 * math.sin(time * 2 + seed)
    end

    -- Aura (encircle ámbar pulsante, close cálido con estela de embestida)
    if st == "encircle" then
        love.graphics.setColor(AMBER[1], AMBER[2], AMBER[3], alpha * (0.14 + 0.26 * th))
        love.graphics.circle("fill", cx, cy, 7.6 * k)
    elseif st == "close" then
        local dashPulse = e.ringTighten and 0.45 or (0.6 + 0.25 * math.sin(time * 20))
        love.graphics.setColor(WARM_WHITE[1], WARM_WHITE[2], WARM_WHITE[3], alpha * dashPulse)
        love.graphics.circle("fill", cx, cy, (8.2 + 1.2 * pul) * k)
    end

    -- Efecto de promocion a nuevo lider (corona dorada en expansion)
    if e.promotedTimer and e.promotedTimer > 0 then
        local pFrac = e.promotedTimer / 0.5
        love.graphics.setColor(1, 0.85, 0.2, pFrac * 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", cx, cy, (6.0 + (1 - pFrac) * 8.0) * k)
        love.graphics.setLineWidth(1)
    end

    -- Cuerpo: estrella de 4 puntas (elongadas en encircle)
    local rOut
    if st == "encircle" then
        rOut = (6.6 + 1.3 * th) * k
    elseif st == "idle" then
        rOut = 5.2 * k
    else
        rOut = 6.4 * k
    end
    local rot = e.visRot or 0

    if blink then
        love.graphics.setColor(1, 1, 1, alpha)
    else
        love.graphics.setColor(col[1], col[2], col[3], alpha)
    end
    love.graphics.polygon("fill", starPoints(cx, cy, rot, rOut, 2.5 * k))

    -- FLANK: contorno blanco pulsante
    if st == "flank" then
        love.graphics.setColor(1, 1, 1, alpha * (0.3 + 0.7 * pul))
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", starPoints(cx, cy, rot, rOut + 1.2 * k, 3.2 * k))
    end

    -- Ojo central: pupila que rastrea a la cabeza de la serpiente
    local ux, uy = 0, 0
    if head then
        local dx = head.x * tam + tam / 2 - cx
        local dy = head.y * tam + tam / 2 - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.001 then ux, uy = dx / d, dy / d end
    end
    local po = (st == "idle" and 0.2 or 1.4) * k

    if blink then
        love.graphics.setColor(WARM_WHITE[1], WARM_WHITE[2], WARM_WHITE[3], alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha)
    end
    love.graphics.circle("fill", cx, cy, 2.4 * k)

    love.graphics.setColor(EYE_DARK[1], EYE_DARK[2], EYE_DARK[3], alpha)
    if e.role == "flanker" then
        -- Rol flanker: pupila de rendija orientada al objetivo
        love.graphics.push()
        love.graphics.translate(cx + ux * po, cy + uy * po)
        love.graphics.rotate(math.atan2(uy, ux))
        love.graphics.rectangle("fill", -0.5 * k, -1.6 * k, 1.0 * k, 3.2 * k)
        love.graphics.pop()
    else
        love.graphics.circle("fill", cx + ux * po, cy + uy * po, 1.1 * k)
    end

    -- Brillo especular
    love.graphics.setColor(1, 1, 1, alpha * 0.9)
    love.graphics.rectangle("fill", cx + ux * po - 1.2 * k, cy + uy * po - 1.2 * k, 0.8 * k, 0.8 * k)

    -- IDLE: párpado cerrado (media luna superior)
    if st == "idle" then
        if blink then
            love.graphics.setColor(1, 1, 1, alpha)
        else
            love.graphics.setColor(col[1], col[2], col[3], alpha)
        end
        love.graphics.arc("fill", cx, cy, 2.6 * k, math.pi, TAU)
    end

    -- CIERRE: signo de advertencia parpadeante
    if st == "close" then
        if on then
            love.graphics.setColor(1, 1, 1, alpha)
        else
            love.graphics.setColor(1, 1, 1, alpha * 0.25)
        end
        local y0 = cy - 12.5 * k
        love.graphics.rectangle("fill", cx - 0.7 * k, y0, 1.4 * k, 3.4 * k)
        love.graphics.rectangle("fill", cx - 0.7 * k, y0 + 4.2 * k, 1.4 * k, 1.4 * k)
    end
end

function draw.draw(list, boss, telegraphs, attackObjects, snakeHead)
    local tam = constants.TAMANIO_BLOQUE
    local time = love.timer.getTime()

    -- Draw telegraph markers (under enemies)
    for _, t in ipairs(telegraphs) do
        local frac = 1 - t.timer / t.maxTimer
        local alpha = 0.3 + frac * 0.5
        local pulse = math.sin(time * 10 + frac * math.pi * 2) * 0.2 + 0.8
        love.graphics.setColor(1, 0.2 + frac * 0.8, 0.1, alpha * pulse)
        love.graphics.rectangle("fill", t.gx * tam + 1, t.gy * tam + 1, tam - 2, tam - 2, 2, 2)
        love.graphics.setColor(1, 1, 0.3, alpha * pulse * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", t.gx * tam + 1, t.gy * tam + 1, tam - 2, tam - 2, 2, 2)
        love.graphics.setLineWidth(1)
    end

    -- Draw normal enemies
    for _, e in ipairs(list) do
        if e.alive then
            local cx = e.x * tam + tam / 2
            local cy = e.y * tam + tam / 2

            if e.type == "chaser" then
                drawChaser(e, tam, time, snakeHead)

            elseif e.type == "patroller" then
                local pulse = math.sin(time * 5) * 0.1 + 0.9
                love.graphics.setColor(
                    constants.COLOR_ENEMY_PATROLLER[1] * pulse,
                    constants.COLOR_ENEMY_PATROLLER[2] * pulse,
                    constants.COLOR_ENEMY_PATROLLER[3] * pulse
                )
                local angle = e.visRot or math.atan2(e.dirY or 0, e.dirX or 1)
                local r = tam * 0.45
                local pts = {
                    cx + math.cos(angle) * r, cy + math.sin(angle) * r,
                    cx + math.cos(angle + 2.5) * r, cy + math.sin(angle + 2.5) * r,
                    cx + math.cos(angle - 2.5) * r, cy + math.sin(angle - 2.5) * r
                }
                love.graphics.polygon("fill", pts)
                love.graphics.setColor(1, 1, 1, 0.4)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", pts)
                love.graphics.setLineWidth(1)

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

            -- Efecto visual de aturdimiento (Tail Snap)
            if e.stunTimer and e.stunTimer > 0 then
                local cx = e.x * tam + tam / 2
                local cy = e.y * tam + tam / 2
                local starRot = time * 8
                love.graphics.setColor(1.0, 0.9, 0.2, 0.9)
                for sIdx = 0, 2 do
                    local sa = starRot + sIdx * (math.pi * 2 / 3)
                    local sx = cx + math.cos(sa) * 6
                    local sy = cy - 6 + math.sin(sa) * 3
                    love.graphics.circle("fill", sx, sy, 1.8)
                end
            end

            -- Efecto visual de congelacion global (Frost Berry)
            local freezeTimer = world.get("enemyFreezeTimer") or 0
            if freezeTimer > 0 then
                local cx = e.x * tam + tam / 2
                local cy = e.y * tam + tam / 2
                love.graphics.setColor(0.2, 0.85, 1.0, 0.45 + math.sin(time * 6) * 0.15)
                love.graphics.rectangle("fill", e.x * tam, e.y * tam, tam, tam, 2, 2)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.7)
                love.graphics.setLineWidth(1.5)
                love.graphics.rectangle("line", e.x * tam, e.y * tam, tam, tam, 2, 2)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Draw attack objects
    for _, ao in ipairs(attackObjects) do
        if ao.type == "projectile" then
            love.graphics.setColor(1, 0.8, 0.2, 1)
            love.graphics.circle("fill", ao.x * tam + tam/2, ao.y * tam + tam/2, 3)
            love.graphics.setColor(1, 1, 0.5, 0.4)
            love.graphics.circle("fill", ao.x * tam + tam/2, ao.y * tam + tam/2, 5)
        elseif ao.type == "radial_pulse" then
            local px = ao.cx * tam + tam / 2
            local py = ao.cy * tam + tam / 2
            local r = ao.radius * tam
            local alpha = 0.5 * (1 - ao.radius / ao.maxRadius)
            love.graphics.setColor(1, 0.3, 0.1, alpha)
            love.graphics.circle("line", px, py, r)
            love.graphics.setColor(1, 0.6, 0.2, alpha * 0.3)
            love.graphics.circle("fill", px, py, r * 0.8)
        end
    end

    -- Boss draw
    if boss and boss.alive then
        local cx = boss.x * tam + tam / 2
        local cy = boss.y * tam + tam / 2
        local vidaFrac = boss.vida / boss.vidaMax
        local pulse = math.sin(time * 3) * 0.2 + 0.8

        local r, g, b
        if boss.state == "telegraph" then
            -- Brillo durante telegraph
            local flash = math.sin(time * 15) * 0.3 + 0.7
            r = 1.0 * pulse * flash
            g = 0.2 * vidaFrac * pulse
            b = 0.6 * pulse
        else
            r = 1.0 * pulse
            g = 0.2 * vidaFrac * pulse
            b = 0.6 * pulse
        end

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

        -- Health bar (mapped to food collected)
        local cfg = constants.BOSS_HEALTH_BAR
        local bx = cx - cfg.width / 2
        local by = cy + cfg.yOffset
        -- Background
        love.graphics.setColor(cfg.bgColor)
        love.graphics.rectangle("fill", bx, by, cfg.width, cfg.height)
        -- Border
        love.graphics.setColor(cfg.borderColor)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx - 1, by - 1, cfg.width + 2, cfg.height + 2)
        -- Foreground fill
        local fillW = math.floor(math.max(0, math.min(1, boss._uiBarFill or 1)) * cfg.width)
        love.graphics.setColor(cfg.fgColor)
        love.graphics.rectangle("fill", bx, by, fillW, cfg.height)
        -- Counter text
        local txt = string.format("%d / %d", boss.foodCollected or 0, boss.foodTarget or constants.BOSS_FOOD_TARGET)
        local txtW = love.graphics.getFont():getWidth(txt)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(txt, cx - txtW / 2, by - 14)
    end
end

return draw
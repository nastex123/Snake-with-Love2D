-- render/enemiesDraw.lua — Dibujo de enemigos, telegraphs, objetos de ataque y boss
local draw = {}
local constants = require("constants")

function draw.draw(list, boss, telegraphs, attackObjects)
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
        local fillW = math.floor(math.max(0, math.min(1, boss._uiBarFill)) * cfg.width)
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
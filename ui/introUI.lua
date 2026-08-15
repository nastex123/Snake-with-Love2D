-- ui/introUI.lua - Intro Balatro: diamante, espiral, flash, celebracion high score
local intro = {}
local constants = require("constants")

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

function intro.draw(ui, t, globalTime, glowPass)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local cx, cy = w / 2, h / 2

    -- Fade from black (0-0.5s) — scene pass only
    if not glowPass then
        local fadeAlpha = math.max(0, math.min(1, 1 - t / 0.5))
        if fadeAlpha > 0 then
            love.graphics.setColor(0, 0, 0, fadeAlpha)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end

    -- Diamond emblem (0.5s onwards, smooth continuous movement)
    if t >= 0.5 then
        local targetY = h * 0.18 + math.sin((globalTime or t) * 1.5) * 4
        local diamondY
        local ds = 16

        if t < 1.2 then
            -- Ascenso inicial desde la parte inferior al centro de la pantalla
            local riseProgress = (t - 0.5) / 0.7
            local c1 = 1.70158
            local c3 = c1 + 1
            local eased = 1 + c3 * (riseProgress - 1)^3 + c1 * (riseProgress - 1)^2
            diamondY = cy + (1 - eased) * 140
            ds = 18 + (1 - riseProgress) * 4
        elseif t < 2.0 then
            -- Permanece en el centro absorbiendo la energía de la espiral
            diamondY = cy
            ds = 18
        elseif t < 2.8 then
            -- Ascenso continuo y suave del centro hacia la cabecera (Ease-Out Cubic)
            local p = (t - 2.0) / 0.8
            local eased = 1 - (1 - p)^3
            diamondY = cy + (targetY - cy) * eased
            ds = 18
        else
            -- Asentado como sello místico en la cabecera
            diamondY = targetY
            ds = 18
        end

        local glowPulse = 0.5 + math.sin((globalTime or t) * 2) * 0.3
        local glowR = (t >= 2.8) and (36 + glowPulse * 6) or (40 + math.sin(t * 2) * 5)
        local glowA = (t >= 2.8) and (0.22 + glowPulse * 0.15) or (math.min(0.4, 0.2 + (t - 0.5) * 0.15))

        -- Outer glow
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], glowA)
        love.graphics.circle("fill", cx, diamondY, glowR)

        -- Core diamond
        love.graphics.push()
        love.graphics.translate(cx, diamondY)
        love.graphics.rotate(math.pi / 4 + math.sin((globalTime or t) * 1.2) * 0.05)
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.85)
        love.graphics.rectangle("fill", -ds, -ds, ds * 2, ds * 2, 2, 2)
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.rectangle("fill", -ds * 0.4, -ds * 0.4, ds * 0.8, ds * 0.8, 1, 1)
        love.graphics.pop()
    end

    -- Spiral build (1.2-2.7s during intro, converging as diamond ascends)
    if t >= 1.2 and t < 2.7 then
        local sp = math.min(1, (t - 1.2) / 1.5)
        local numShapes = 35
        local maxRadius = math.min(w, h) * 0.55
        local speedMult = 1 + sp * 3

        -- Centro dinámico de la espiral que sigue al diamante
        local spiralCenterY = (t >= 2.0) and (cy + (h * 0.18 - cy) * (1 - (1 - (t - 2.0) / 0.8)^3)) or cy

        for i = 0, numShapes - 1 do
            local frac = i / numShapes
            local angle = frac * 6.2832 + (t - 1.2) * speedMult * 2 + i * 0.1
            local radius = (1 - sp) * maxRadius * (0.6 + frac * 0.4)
            radius = radius + math.sin(angle * 2 + t * 3) * 4
            local px = cx + math.cos(angle) * radius
            local py = spiralCenterY + math.sin(angle) * radius

            if px >= -20 and px <= w + 20 and py >= -20 and py <= h + 20 then
                local hue = (frac + (t - 1.2) * 0.05) % 1
                local cr, cg, cb = hsv2rgb(hue, 0.65, 0.85 + math.sin(t * 2 + i) * 0.15)
                local a = (1 - sp * 0.7) * 0.6 + 0.2

                love.graphics.setColor(cr, cg, cb, a)

                local size = 12 + math.sin(t * 4 + i * 1.7) * 4
                if i % 3 == 0 then
                    love.graphics.rectangle("fill", px - size / 2, py - size / 2, size, size)
                elseif i % 3 == 1 then
                    love.graphics.circle("fill", px, py, size / 2)
                else
                    local pts = {px, py - size / 2, px + size / 2, py, px, py + size / 2, px - size / 2, py}
                    love.graphics.polygon("fill", pts)
                end
            end
        end

        -- Center glow intensifies during build
        local centerGlow = 0.3 + sp * 0.7
        love.graphics.setColor(1, 1, 1, centerGlow * 0.4)
        love.graphics.circle("fill", cx, spiralCenterY, 35 + sp * 20)
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], centerGlow * 0.3)
        love.graphics.circle("fill", cx, spiralCenterY, 50 + sp * 25)
    end

    -- Flash (2.5-2.9s) — scene pass only, masks peak transition
    if not glowPass then
        if t >= 2.5 and t < 2.9 then
            local fp = (t - 2.5) / 0.4
            local flashAlpha = math.sin(fp * math.pi)
            if flashAlpha > 0 then
                love.graphics.setColor(1, 1, 1, flashAlpha * 0.85)
                love.graphics.rectangle("fill", 0, 0, w, h)
            end
        end
    end
end

function intro.drawHighScore(ui, puntuacion, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf("NUEVO HIGH SCORE!", 0, h / 2 - 40, w, "center")
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(puntuacion .. " puntos", 0, h / 2, w, "center")
end

return intro
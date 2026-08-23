-- ui/introUI.lua - Intro Arcade Alto Contraste: diamante neon, espiral pixelada, flash, celebracion high score
local intro = {}
local constants = require("constants")

-- Paleta Arcade Alto Contraste
local COLOR_CYAN    = {0.0, 0.94, 1.0}
local COLOR_MAGENTA = {1.0, 0.0, 0.33}
local COLOR_GOLD    = {1.0, 0.82, 0.25}
local COLOR_GREEN   = {0.22, 1.0, 0.08}
local COLOR_BG_BOX  = {0.039, 0.051, 0.094}

local function getNeonPalette(idx)
    local p = (idx % 4)
    if p == 0 then return COLOR_CYAN end
    if p == 1 then return COLOR_MAGENTA end
    if p == 2 then return COLOR_GOLD end
    return COLOR_GREEN
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

    -- Diamante Emblema Arcade (0.5s en adelante)
    if t >= 0.5 then
        local floatOffset = math.sin((globalTime or t) * 1.5) * 3
        local diamondY
        local ds = 20

        if t < 1.2 then
            -- Ascenso inicial desde la parte inferior al centro de la pantalla
            local riseProgress = (t - 0.5) / 0.7
            local c1 = 1.70158
            local c3 = c1 + 1
            local eased = 1 + c3 * (riseProgress - 1)^3 + c1 * (riseProgress - 1)^2
            diamondY = cy + (1 - eased) * 140
            ds = 20 + (1 - riseProgress) * 4
        else
            -- Asentado de forma permanente en el centro exacto (cx, cy) con flotacion senoidal
            diamondY = cy + floatOffset
            ds = 20
        end

        local pulse = 0.8 + math.sin((globalTime or t) * 3) * 0.2
        if ui.emblemTexture then
            -- Renderizado HD del Diamante Emblema (Textura + Glow)
            local embScale = (ds / 20) * 0.22 -- ~112px de ancho en pantalla
            local originX, originY = 256, 256

            if glowPass then
                if ui.emblemGlowTexture then
                    love.graphics.setColor(1, 1, 1, 0.9 * pulse)
                    love.graphics.draw(ui.emblemGlowTexture, cx, diamondY, 0, embScale, embScale, originX, originY)
                end
            else
                -- Sombra proyectada sutil
                love.graphics.setColor(0, 0, 0, 0.85)
                love.graphics.draw(ui.emblemTexture, cx + 3, diamondY + 3, 0, embScale, embScale, originX, originY)

                -- Textura base completa
                love.graphics.setColor(1, 1, 1, 1.0)
                love.graphics.draw(ui.emblemTexture, cx, diamondY, 0, embScale, embScale, originX, originY)

                -- Pulso de brillo sobre la textura base
                if ui.emblemGlowTexture and pulse > 0.8 then
                    local overlayAlpha = (pulse - 0.8) * 1.5
                    love.graphics.setColor(1, 1, 1, overlayAlpha)
                    love.graphics.draw(ui.emblemGlowTexture, cx, diamondY, 0, embScale, embScale, originX, originY)
                end
            end
        else
            -- Fallback procedimental básico
            local ptsOuter = {
                cx, diamondY - ds,
                cx + ds, diamondY,
                cx, diamondY + ds,
                cx - ds, diamondY
            }
            local innerDs = ds * 0.55
            local ptsInner = {
                cx, diamondY - innerDs,
                cx + innerDs, diamondY,
                cx, diamondY + innerDs,
                cx - innerDs, diamondY
            }

            if glowPass then
                -- Elementos luminosos para bloom shader (bordes y nucleo neon)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], 0.9 * pulse)
                love.graphics.polygon("line", ptsOuter)
                love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], 0.8 * pulse)
                love.graphics.polygon("line", ptsInner)

                -- Lineas de alas laterales neon
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], 0.85 * pulse)
                love.graphics.line(cx - ds - 16, diamondY, cx - ds - 2, diamondY)
                love.graphics.line(cx + ds + 2, diamondY, cx + ds + 16, diamondY)
                love.graphics.line(cx, diamondY - ds - 10, cx, diamondY - ds - 2)
                love.graphics.line(cx, diamondY + ds + 2, cx, diamondY + ds + 10)

                -- Nucleo brillante
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.rectangle("fill", cx - 3, diamondY - 3, 6, 6)
                love.graphics.setLineWidth(1)
            else
                -- Scene pass: Sombra negra nitida
                local ptsShadow = {
                    cx + 3, diamondY - ds + 3,
                    cx + ds + 3, diamondY + 3,
                    cx + 3, diamondY + ds + 3,
                    cx - ds + 3, diamondY + 3
                }
                love.graphics.setColor(0, 0, 0, 0.85)
                love.graphics.polygon("fill", ptsShadow)

                -- Relleno solido oscuro
                love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], 0.95)
                love.graphics.polygon("fill", ptsOuter)

                -- Borde exterior NEON CIAN (2px, bordes rectos)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], 0.95)
                love.graphics.polygon("line", ptsOuter)

                -- Borde interior NEON MAGENTA (2px, bordes rectos)
                love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], 0.85)
                love.graphics.polygon("line", ptsInner)

                -- Lineas de conexion / alas neon de 2px
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], 0.9)
                love.graphics.line(cx - ds - 16, diamondY, cx - ds - 2, diamondY)
                love.graphics.line(cx + ds + 2, diamondY, cx + ds + 16, diamondY)
                love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], 0.9)
                love.graphics.line(cx, diamondY - ds - 10, cx, diamondY - ds - 2)
                love.graphics.line(cx, diamondY + ds + 2, cx, diamondY + ds + 10)

                -- Puntos terminales en las alas
                love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], 0.95)
                love.graphics.rectangle("fill", cx - ds - 18, diamondY - 1, 3, 3)
                love.graphics.rectangle("fill", cx + ds + 16, diamondY - 1, 3, 3)

                -- Nucleo blanco pixelado
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.rectangle("fill", cx - 3, diamondY - 3, 6, 6)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Espiral de pixeles/cuadrados Arcade (1.2-2.7s)
    if t >= 1.2 and t < 2.7 then
        local sp = math.min(1, (t - 1.2) / 1.5)
        local numShapes = 36
        local maxRadius = math.min(w, h) * 0.55
        local speedMult = 1 + sp * 3

        -- Centro de la espiral en el centro exacto (cx, cy)
        local spiralCenterY = cy

        for i = 0, numShapes - 1 do
            local frac = i / numShapes
            local angle = frac * 6.2832 + (t - 1.2) * speedMult * 2 + i * 0.1
            local radius = (1 - sp) * maxRadius * (0.6 + frac * 0.4)
            radius = radius + math.sin(angle * 2 + t * 3) * 4
            local px = cx + math.cos(angle) * radius
            local py = spiralCenterY + math.sin(angle) * radius

            if px >= -20 and px <= w + 20 and py >= -20 and py <= h + 20 then
                local col = getNeonPalette(i)
                local a = (1 - sp * 0.6) * 0.8 + 0.2
                local sz = 8 + math.floor((math.sin(t * 5 + i * 1.5) * 0.5 + 0.5) * 6)

                if glowPass then
                    love.graphics.setColor(col[1], col[2], col[3], a * 0.9)
                    if i % 2 == 0 then
                        love.graphics.rectangle("fill", px - sz / 2, py - sz / 2, sz, sz)
                    else
                        local pDiam = {px, py - sz / 2, px + sz / 2, py, px, py + sz / 2, px - sz / 2, py}
                        love.graphics.polygon("fill", pDiam)
                    end
                else
                    -- Sombra negra
                    love.graphics.setColor(0, 0, 0, a * 0.8)
                    love.graphics.rectangle("fill", px - sz / 2 + 1, py - sz / 2 + 1, sz, sz)

                    -- Cuadrado o diamante pixelado solido
                    love.graphics.setColor(col[1], col[2], col[3], a)
                    if i % 2 == 0 then
                        love.graphics.rectangle("fill", px - sz / 2, py - sz / 2, sz, sz)
                        love.graphics.setColor(1, 1, 1, a * 0.6)
                        love.graphics.rectangle("fill", px - 1, py - 1, 2, 2)
                    else
                        local pDiam = {px, py - sz / 2, px + sz / 2, py, px, py + sz / 2, px - sz / 2, py}
                        love.graphics.polygon("fill", pDiam)
                    end
                end
            end
        end

        -- Ondas de choque concentricas de rombos arcade en el centro
        local centerPulse = 0.4 + sp * 0.6
        love.graphics.setLineWidth(2)
        local r1 = 24 + sp * 35
        local r2 = 38 + sp * 50
        local ptsWave1 = {cx, spiralCenterY - r1, cx + r1, spiralCenterY, cx, spiralCenterY + r1, cx - r1, spiralCenterY}
        local ptsWave2 = {cx, spiralCenterY - r2, cx + r2, spiralCenterY, cx, spiralCenterY + r2, cx - r2, spiralCenterY}

        if glowPass then
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], centerPulse * 0.8)
            love.graphics.polygon("line", ptsWave1)
            love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], centerPulse * 0.6)
            love.graphics.polygon("line", ptsWave2)
        else
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], centerPulse * 0.75)
            love.graphics.polygon("line", ptsWave1)
            love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], centerPulse * 0.5)
            love.graphics.polygon("line", ptsWave2)
        end
        love.graphics.setLineWidth(1)
    end

    -- Flash (2.5-2.9s) — scene pass only
    if not glowPass then
        if t >= 2.5 and t < 2.9 then
            local fp = (t - 2.5) / 0.4
            local flashAlpha = math.sin(fp * math.pi)
            if flashAlpha > 0 then
                love.graphics.setColor(1, 1, 1, flashAlpha * 0.9)
                love.graphics.rectangle("fill", 0, 0, w, h)
            end
        end
    end
end

function intro.drawHighScore(ui, puntuacion, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    local boxW = 380
    local boxH = 100
    local boxX = (w - boxW) / 2
    local boxY = (h - boxH) / 2

    -- Sombra solida negra
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", boxX + 4, boxY + 4, boxW, boxH)

    -- Fondo solido arcade
    love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)

    -- Borde doble neon oro/magenta
    love.graphics.setLineWidth(2)
    love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], 1.0)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
    love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], 0.8)
    love.graphics.rectangle("line", boxX + 4, boxY + 4, boxW - 8, boxH - 8)
    love.graphics.setLineWidth(1)

    -- Titulo
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.printf("NUEVO RECORD!", boxX + 2, boxY + 18, boxW, "center")
    love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], 1)
    love.graphics.printf("NUEVO RECORD!", boxX, boxY + 16, boxW, "center")

    -- Puntuacion
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.printf(tostring(puntuacion) .. " PUNTOS", boxX + 1, boxY + 57, boxW, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(tostring(puntuacion) .. " PUNTOS", boxX, boxY + 56, boxW, "center")
end

return intro
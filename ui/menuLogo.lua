-- ui/menuLogo.lua - Logotipo procedural isométrico cian + bounds (extraído de menuUI.lua)
local menuLogo = {}
local persistence = require("systems.persistence")

local COLOR_CYAN = {0.0, 0.94, 1.0}

function menuLogo.getBounds(t)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local floatOffset = math.sin((t or 0) * 1.5) * 3
    local logoCfg = persistence.getLogoConfig()
    local spacing = logoCfg.spacing or 10
    local depth = logoCfg.depth or 5

    -- El area derecha comienza tras el diamante central (w/2 + radio del emblema)
    local diamondRight = math.floor(w * 0.5) + 56
    local rightAreaW = w - diamondRight

    -- Ajuste responsivo de escala si el espacio horizontal disponible es reducido
    local pScale = logoCfg.scale or 6
    local totalW = 5 * (7 * pScale) + 4 * spacing
    if totalW > rightAreaW - 16 then
        pScale = math.max(2, math.floor((rightAreaW - 16 - 4 * spacing) / 35))
        totalW = 5 * (7 * pScale) + 4 * spacing
    end
    local totalH = 7 * pScale

    -- Posicionamiento horizontal: anclado a la derecha de la pantalla con margen simétrico responsivo
    local marginX = math.max(20, math.floor(w * 0.04))
    local rawX = w - totalW - marginX + (logoCfg.offsetX or 0)
    local startX = math.max(diamondRight + 12, math.min(w - totalW - 10, rawX))

    -- Posicionamiento vertical: siempre centrado verticalmente en la pantalla
    local centerY = math.floor(h / 2)
    local rawY = centerY - math.floor(totalH / 2) + floatOffset + (logoCfg.offsetY or 0)
    local startY = math.max(10, math.min(h - totalH - 10, rawY))

    return startX, startY, totalW, totalH, depth, pScale, spacing, floatOffset
end

function menuLogo.draw(titleAlpha, t)
    if titleAlpha <= 0 then return end
    local startX, startY, totalW, totalH, depth, pScale, spacing = menuLogo.getBounds(t)
    local titleLetters = {
        {" XXXXX ", "XX   XX", "XX     ", " XXXXX ", "     XX", "XX   XX", " XXXXX "},
        {"XX   XX", "XXX  XX", "XXXX XX", "XX XXXX", "XX  XXX", "XX   XX", "XX   XX"},
        {" XXXXX ", "XX   XX", "XX   XX", "XXXXXXX", "XX   XX", "XX   XX", "XX   XX"},
        {"XX   XX", "XX  XX ", "XX XX  ", "XXXX   ", "XX XX  ", "XX  XX ", "XX   XX"},
        {"XXXXXXX", "XX     ", "XX     ", "XXXXXX ", "XX     ", "XX     ", "XXXXXXX"}
    }
    local sweepX = (t * 160) % (totalW + 100) - 50
    for d = depth, 1, -1 do
        local offX = -d
        local offY = d
        local curX = startX + offX
        local col = (d == depth) and {0.0, 0.0, 0.0, titleAlpha * 0.95} or ((d > 2) and {0.0, 0.28, 0.38, titleAlpha} or {0.0, 0.55, 0.70, titleAlpha})
        love.graphics.setColor(col[1], col[2], col[3], col[4])
        for i = 1, 5 do
            local mat = titleLetters[i]
            for r = 1, 7 do
                local line = mat[r]
                for c = 1, 7 do
                    if line:sub(c, c) == 'X' then
                        love.graphics.rectangle("fill", curX + (c - 1) * pScale, startY + offY + (r - 1) * pScale, pScale, pScale)
                    end
                end
            end
            curX = curX + 7 * pScale + spacing
        end
    end
    local curX = startX
    for i = 1, 5 do
        local mat = titleLetters[i]
        for r = 1, 7 do
            local line = mat[r]
            for c = 1, 7 do
                if line:sub(c, c) == 'X' then
                    local px = curX + (c - 1) * pScale
                    local py = startY + (r - 1) * pScale
                    local distToSweep = math.abs(px - (startX + sweepX))
                    if distToSweep < 12 then
                        love.graphics.setColor(1.0, 1.0, 1.0, titleAlpha)
                    elseif r == 1 or c == 1 then
                        love.graphics.setColor(0.70, 0.96, 1.0, titleAlpha)
                    elseif r <= 3 then
                        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha)
                    elseif r <= 5 then
                        love.graphics.setColor(0.0, 0.72, 0.85, titleAlpha)
                    else
                        love.graphics.setColor(0.0, 0.45, 0.58, titleAlpha)
                    end
                    love.graphics.rectangle("fill", px, py, pScale, pScale)
                end
            end
        end
        curX = curX + 7 * pScale + spacing
    end
    local glintX = startX + sweepX
    if glintX >= startX and glintX <= startX + totalW then
        local glintY = startY + 12
        love.graphics.setColor(1, 1, 1, titleAlpha)
        love.graphics.rectangle("fill", glintX - 8, glintY - 1, 17, 3)
        love.graphics.rectangle("fill", glintX - 1, glintY - 8, 3, 17)
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * 0.85)
        love.graphics.rectangle("fill", glintX - 4, glintY - 4, 9, 9)
        love.graphics.setColor(1, 1, 1, titleAlpha)
        love.graphics.rectangle("fill", glintX - 1, glintY - 1, 3, 3)
    end
end

function menuLogo.drawGlow(titleAlpha, t)
    if titleAlpha <= 0 then return end
    local startX, startY, totalW = menuLogo.getBounds(t)
    local sweepX = (t * 160) % (totalW + 100) - 50
    local glowPulse = 0.8 + math.sin(t * 3.5) * 0.2
    local glintX = startX + sweepX
    if glintX >= startX and glintX <= startX + totalW then
        local glintY = startY + 12
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * glowPulse * 0.95)
        love.graphics.rectangle("fill", glintX - 10, glintY - 2, 21, 5)
        love.graphics.rectangle("fill", glintX - 2, glintY - 10, 5, 21)
        love.graphics.setColor(1, 1, 1, titleAlpha * glowPulse)
        love.graphics.rectangle("fill", glintX - 2, glintY - 2, 5, 5)
    end
end

return menuLogo

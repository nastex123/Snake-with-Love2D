-- ui/menuUI.lua - Menu principal: titulo arcade neon, high score card, botones y mouse
local menu = {}
local constants = require("constants")
local sound = require("audio.sound")

-- Paleta Arcade Alto Contraste
local COLOR_CYAN     = {0.0, 0.94, 1.0}
local COLOR_MAGENTA  = {1.0, 0.0, 0.33}
local COLOR_GOLD     = {1.0, 0.82, 0.25}
local COLOR_GREEN    = {0.22, 1.0, 0.08}
local COLOR_BG_BOX   = {0.039, 0.051, 0.094}
local COLOR_BG_HOVER = {0.06, 0.09, 0.18}
local COLOR_BG_PRESS = {0.02, 0.03, 0.06}

function menu.draw(ui, menuTime, globalTime, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local cx = w / 2

    -- Timings para aparicion
    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.4))
    local pillAlpha = math.min(1, math.max(0, (menuTime - 3.6) / 0.4))

    -- === TITULO ARCADE "S N A K E" ===
    if titleAlpha > 0 then
        local titleText = "S N A K E"
        local ty = h * 0.13
        local floatOffset = math.sin((globalTime or menuTime) * 1.5) * 2

        -- Micro-escala fluida de entrada (de 0.92 a 1.0)
        local scaleProgress = math.min(1, (menuTime - 2.8) / 0.5)
        local enterScale = 0.92 + 0.08 * (1 - (1 - scaleProgress)^2)

        love.graphics.setFont(ui.fontTitle)
        local th = ui.fontTitle:getHeight()
        local tw = ui.fontTitle:getWidth(titleText)

        love.graphics.push()
        love.graphics.translate(cx, ty + floatOffset + th / 2)
        love.graphics.scale(enterScale, enterScale)
        love.graphics.translate(-cx, -(ty + floatOffset + th / 2))

        -- Decoracion arcade lateral (lineas neon rectas con caps cuadrados)
        local lineY = ty + floatOffset + th / 2
        local lx1 = cx - tw / 2 - 32
        local lx2 = cx - tw / 2 - 10
        local rx1 = cx + tw / 2 + 10
        local rx2 = cx + tw / 2 + 32

        love.graphics.setLineWidth(2)
        -- Sombra de lineas
        love.graphics.setColor(0, 0, 0, titleAlpha * 0.8)
        love.graphics.line(lx1 + 2, lineY + 2, lx2 + 2, lineY + 2)
        love.graphics.line(rx1 + 2, lineY + 2, rx2 + 2, lineY + 2)
        -- Lineas neon
        love.graphics.setColor(COLOR_MAGENTA[1], COLOR_MAGENTA[2], COLOR_MAGENTA[3], titleAlpha * 0.9)
        love.graphics.line(lx1, lineY, lx2, lineY)
        love.graphics.line(rx1, lineY, rx2, lineY)
        -- Caps cuadrados
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * 0.95)
        love.graphics.rectangle("fill", lx1 - 4, lineY - 2, 4, 4)
        love.graphics.rectangle("fill", rx2, lineY - 2, 4, 4)
        love.graphics.setLineWidth(1)

        -- 1. Sombra negra nitida y profunda
        love.graphics.setColor(0, 0, 0, titleAlpha * 0.95)
        love.graphics.printf(titleText, 3, ty + floatOffset + 3, w, "center")
        love.graphics.printf(titleText, -2, ty + floatOffset + 3, w, "center")
        love.graphics.printf(titleText, 2, ty + floatOffset + 4, w, "center")

        -- 2. Glow / Contorno NEON simulado (offset multicapa en CIAN)
        local glowPulse = 0.7 + math.sin((globalTime or menuTime) * 3) * 0.3
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * glowPulse * 0.6)
        love.graphics.printf(titleText, -2, ty + floatOffset, w, "center")
        love.graphics.printf(titleText, 2, ty + floatOffset, w, "center")
        love.graphics.printf(titleText, 0, ty + floatOffset - 2, w, "center")
        love.graphics.printf(titleText, 0, ty + floatOffset + 2, w, "center")

        -- 3. Texto principal blanco puro brillante
        love.graphics.setColor(1, 1, 1, titleAlpha)
        love.graphics.printf(titleText, 0, ty + floatOffset, w, "center")

        love.graphics.pop()
    end

    -- === HIGH SCORE CARD (Arcade Alto Contraste con Borde Recto) ===
    if cardAlpha > 0 then
        local cardW = 280
        local cardH = 34
        local cardX = (w - cardW) / 2
        local slideY = (1 - cardAlpha) * -8
        local cardY = h * 0.23 + slideY
        local shimmer = 0.85 + math.sin((globalTime or menuTime) * 3) * 0.15

        -- Sombra negra solida (bordes rectos)
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.85)
        love.graphics.rectangle("fill", cardX + 3, cardY + 3, cardW, cardH)

        -- Fondo solido oscuro
        love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], cardAlpha * 0.98)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)

        -- Borde NEON ORO recto de 2px
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha * shimmer)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH)
        love.graphics.setLineWidth(1)

        -- Marcadores de esquina arcade (pixeles cian)
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * 0.9)
        love.graphics.rectangle("fill", cardX + 2, cardY + 2, 2, 2)
        love.graphics.rectangle("fill", cardX + cardW - 4, cardY + 2, 2, 2)
        love.graphics.rectangle("fill", cardX + 2, cardY + cardH - 4, 2, 2)
        love.graphics.rectangle("fill", cardX + cardW - 4, cardY + cardH - 4, 2, 2)

        -- Estrella geometrica pixelada en oro neon
        local starX = cardX + 20
        local starY = cardY + cardH / 2
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
        local pts = {}
        for i = 0, 9 do
            local angle = math.pi / 2 - i * math.pi * 2 / 10
            local ri = (i % 2 == 0) and 7 or 3
            table.insert(pts, starX + math.cos(angle) * ri)
            table.insert(pts, starY + math.sin(angle) * ri)
        end
        love.graphics.polygon("fill", pts)

        -- Texto High Score con sombra negra para maximo contraste
        love.graphics.setFont(ui.fontNormal)
        local textY = starY - ui.fontNormal:getHeight() / 2
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 17, textY + 1)
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 16, textY)
    end

    -- === BOTONES DEL MENU (Estilo Arcade Alto Contraste) ===
    ui.menuButtons = {}
    local bw = 240
    local bh = 38
    local bx = cx - bw / 2
    local by = h * 0.33
    local gap = 11
    local labels = {
        {id = 'play', text = 'JUGAR'},
        {id = 'profiles', text = 'PERFILES'},
        {id = 'settings', text = 'CONFIGURACIÓN'},
        {id = 'exit', text = 'SALIR'}
    }

    for i, btn in ipairs(labels) do
        -- Entrada escalonada por boton
        local btnStart = 3.20 + (i - 1) * 0.08
        local btnAlpha = math.min(1, math.max(0, (menuTime - btnStart) / 0.35))

        if btnAlpha > 0 then
            local isHover = (ui.menuHoverId == btn.id)
            local isPressed = (ui.menuPressedId == btn.id)
            local yOffset = isPressed and 2 or (isHover and -2 or 0)
            local slideUp = (1 - btnAlpha) * 12
            local x = bx
            local y = by + (i - 1) * (bh + gap) + yOffset + slideUp

            ui.menuButtons[#ui.menuButtons + 1] = {id = btn.id, x = x, y = y, w = bw, h = bh}

            -- Sombra inferior solida negra (radius 0)
            love.graphics.setColor(0, 0, 0, btnAlpha * 0.85)
            love.graphics.rectangle('fill', x + 3, y + 3, bw, bh)

            -- Fondo del boton solido oscuro (radius 0)
            if isPressed then
                love.graphics.setColor(COLOR_BG_PRESS[1], COLOR_BG_PRESS[2], COLOR_BG_PRESS[3], btnAlpha * 0.98)
            elseif isHover then
                love.graphics.setColor(COLOR_BG_HOVER[1], COLOR_BG_HOVER[2], COLOR_BG_HOVER[3], btnAlpha * 0.98)
            else
                love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], btnAlpha * 0.95)
            end
            love.graphics.rectangle('fill', x, y, bw, bh)

            -- Borde NEON RECTO de 2px (radius 0)
            love.graphics.setLineWidth(2)
            if isHover then
                local glow = 0.85 + math.sin((globalTime or menuTime) * 8) * 0.15
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * glow)
                love.graphics.rectangle('line', x, y, bw, bh)

                -- Cuadros decorativos en las 4 esquinas en hover
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha)
                love.graphics.rectangle('fill', x, y, 4, 4)
                love.graphics.rectangle('fill', x + bw - 4, y, 4, 4)
                love.graphics.rectangle('fill', x, y + bh - 4, 4, 4)
                love.graphics.rectangle('fill', x + bw - 4, y + bh - 4, 4, 4)
            else
                love.graphics.setColor(0.0, 0.55, 0.75, btnAlpha * 0.65)
                love.graphics.rectangle('line', x, y, bw, bh)
            end
            love.graphics.setLineWidth(1)

            -- Indicador de cursor en hover
            if isHover then
                love.graphics.setFont(ui.fontNormal)
                local arrowY = y + (bh - ui.fontNormal:getHeight()) / 2
                -- Sombra de flecha
                love.graphics.setColor(0, 0, 0, btnAlpha * 0.9)
                love.graphics.print(">", x + 13, arrowY + 1)
                love.graphics.print("<", x + bw - 21, arrowY + 1)
                -- Flecha neon
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha)
                love.graphics.print(">", x + 12, arrowY)
                love.graphics.print("<", x + bw - 22, arrowY)
            end

            -- Texto del boton (mayusculas, alto contraste)
            love.graphics.setFont(ui.fontNormal)
            local textY = y + (bh - ui.fontNormal:getHeight()) / 2

            -- Sombra negra del texto
            love.graphics.setColor(0, 0, 0, btnAlpha * 0.95)
            love.graphics.printf(btn.text, x + 1, textY + 1, bw, 'center')

            -- Color del texto
            if isHover then
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha)
            elseif isPressed then
                love.graphics.setColor(0.7, 0.8, 0.9, btnAlpha * 0.9)
            else
                love.graphics.setColor(1, 1, 1, btnAlpha * 0.95)
            end
            love.graphics.printf(btn.text, x, textY, bw, 'center')
        end
    end

    -- === CONTROL PILLS (Bordes rectos, solido oscuro, borde neon) ===
    if pillAlpha > 0 then
        local pillY = h - 32
        local pills = {
            {text = "WASD / FLECHAS", x = cx - 145},
            {text = "+ / - VELOCIDAD", x = cx + 15}
        }

        for _, pill in ipairs(pills) do
            local pw = ui.fontSmall:getWidth(pill.text) + 16
            local ph = 20
            local px = pill.x
            local py = pillY

            -- Sombra solida negra
            love.graphics.setColor(0, 0, 0, pillAlpha * 0.8)
            love.graphics.rectangle("fill", px + 2, py + 2, pw, ph)

            -- Fondo solido oscuro (radius 0)
            love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], pillAlpha * 0.95)
            love.graphics.rectangle("fill", px, py, pw, ph)

            -- Borde neon cian de 2px (radius 0)
            love.graphics.setLineWidth(2)
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], pillAlpha * 0.5)
            love.graphics.rectangle("line", px, py, pw, ph)
            love.graphics.setLineWidth(1)

            -- Texto
            love.graphics.setFont(ui.fontSmall)
            local textY = py + (ph - ui.fontSmall:getHeight()) / 2
            love.graphics.setColor(0, 0, 0, pillAlpha * 0.9)
            love.graphics.print(pill.text, px + 9, textY + 1)
            love.graphics.setColor(1, 1, 1, pillAlpha * 0.9)
            love.graphics.print(pill.text, px + 8, textY)
        end
    end
end

function menu.mousePressed(ui, x, y)
    if not ui.menuButtons then return nil end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return b.id
        end
    end
    return nil
end

function menu.updateHover(ui, x, y)
    local prevHover = ui.menuHoverId
    ui.menuHoverId = nil
    if not ui.menuButtons then return end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            ui.menuHoverId = b.id
            if prevHover ~= b.id then
                sound.play("buttonHover")
            end
            return
        end
    end
end

function menu.setPressed(ui, id)
    ui.menuPressedId = id
end

function menu.clearPressed(ui)
    ui.menuPressedId = nil
end

return menu
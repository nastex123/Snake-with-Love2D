-- ui/menuUI.lua - Menu principal: titulo, high score card, botones y mouse
local menu = {}
local constants = require("constants")
local sound = require("audio.sound")

function menu.draw(ui, menuTime, globalTime, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local cx = w / 2

    -- Timings para aparicion suave y continua (sin saltos)
    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.4))
    local pillAlpha = math.min(1, math.max(0, (menuTime - 3.6) / 0.4))

    -- === TITLE (Revelacion organica naciendo del halo del diamante) ===
    if titleAlpha > 0 then
        local titleText = "S N A K E"
        local ty = h * 0.13
        local floatOffset = math.sin((globalTime or menuTime) * 1.5) * 2

        -- Micro-escala fluida de entrada (de 0.92 a 1.0)
        local scaleProgress = math.min(1, (menuTime - 2.8) / 0.5)
        local enterScale = 0.92 + 0.08 * (1 - (1 - scaleProgress)^2)

        love.graphics.setFont(ui.fontTitle)

        love.graphics.push()
        love.graphics.translate(cx, ty + floatOffset + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(enterScale, enterScale)
        love.graphics.translate(-cx, -(ty + floatOffset + ui.fontTitle:getHeight() / 2))

        -- Sombra nítida proyectada
        love.graphics.setColor(0, 0, 0, titleAlpha * 0.85)
        love.graphics.printf(titleText, 2, ty + floatOffset + 3, w, "center")
        love.graphics.printf(titleText, -2, ty + floatOffset + 3, w, "center")

        -- Resplandor exterior suave
        local glowPulse = 0.5 + math.sin((globalTime or menuTime) * 2) * 0.3
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], titleAlpha * glowPulse * 0.35)
        love.graphics.printf(titleText, 0, ty + floatOffset - 1, w, "center")
        love.graphics.printf(titleText, 0, ty + floatOffset + 1, w, "center")

        -- Texto principal blanco puro/marfil con tinte Balatro
        love.graphics.setColor(1, 0.98, 0.92, titleAlpha)
        love.graphics.printf(titleText, 0, ty + floatOffset, w, "center")

        love.graphics.pop()
    end

    -- === HIGH SCORE CARD (Balatro Cristal & Oro con slide-down sutil) ===
    if cardAlpha > 0 then
        local cardW = 270
        local cardH = 38
        local cardX = (w - cardW) / 2
        local slideY = (1 - cardAlpha) * -8
        local cardY = h * 0.23 + slideY
        local shimmer = math.sin((globalTime or menuTime) * 2) * 0.3 + 0.7

        -- Fondo translúcido (Glassmorphism oscuro)
        love.graphics.setColor(0.07, 0.09, 0.16, cardAlpha * 0.85)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 8, 8)

        -- Borde dorado pulsante
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha * 0.45 * shimmer)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 8, 8)
        love.graphics.setLineWidth(1)

        -- Estrella dorada
        local starX = cardX + 18
        local starY = cardY + cardH / 2
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha)
        local pts = {}
        for i = 0, 9 do
            local angle = math.pi / 2 - i * math.pi * 2 / 10
            local ri = (i % 2 == 0) and 7 or 3
            table.insert(pts, starX + math.cos(angle) * ri)
            table.insert(pts, starY + math.sin(angle) * ri)
        end
        love.graphics.polygon("fill", pts)

        -- Texto de High Score nítido
        love.graphics.setFont(ui.fontNormal)
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 16, starY - ui.fontNormal:getHeight() / 2)
    end

    -- === MAIN MENU BUTTONS (Cascada escalonada Staggered de Cristal & Oro) ===
    ui.menuButtons = {}
    local bw = 230
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
        -- Entrada escalonada por cada botón
        local btnStart = 3.20 + (i - 1) * 0.08
        local btnAlpha = math.min(1, math.max(0, (menuTime - btnStart) / 0.35))

        if btnAlpha > 0 then
            local isHover = (ui.menuHoverId == btn.id)
            local isPressed = (ui.menuPressedId == btn.id)
            local yOffset = isPressed and 1 or (isHover and -2 or 0)
            local slideUp = (1 - btnAlpha) * 12
            local x = bx
            local y = by + (i - 1) * (bh + gap) + yOffset + slideUp

            ui.menuButtons[#ui.menuButtons + 1] = {id = btn.id, x = x, y = y, w = bw, h = bh}

            -- Sombra inferior del botón
            love.graphics.setColor(0, 0, 0, btnAlpha * 0.45)
            love.graphics.rectangle('fill', x + 1, y + 3, bw, bh, 8, 8)

            -- Fondo del botón (Cristal oscuro con realce en hover)
            if isPressed then
                love.graphics.setColor(0.08, 0.10, 0.18, btnAlpha * 0.95)
            elseif isHover then
                love.graphics.setColor(0.14, 0.18, 0.32, btnAlpha * 0.95)
            else
                love.graphics.setColor(0.07, 0.09, 0.16, btnAlpha * 0.85)
            end
            love.graphics.rectangle('fill', x, y, bw, bh, 8, 8)

            -- Borde del botón (Dorado en hover, sutil en reposo)
            if isHover then
                local glow = 0.7 + math.sin((globalTime or menuTime) * 8) * 0.25
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], btnAlpha * glow)
                love.graphics.setLineWidth(1.5)
            else
                love.graphics.setColor(1, 1, 1, btnAlpha * 0.15)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle('line', x, y, bw, bh, 8, 8)
            love.graphics.setLineWidth(1)

            -- Indicador de flecha en hover
            if isHover then
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], btnAlpha)
                love.graphics.print("▶", x + 12, y + (bh - ui.fontSmall:getHeight()) / 2)
            end

            -- Texto del botón
            love.graphics.setFont(ui.fontNormal)
            if isHover then
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], btnAlpha)
            else
                love.graphics.setColor(0.88, 0.91, 0.96, btnAlpha * 0.9)
            end
            love.graphics.printf(btn.text, x, y + (bh - ui.fontNormal:getHeight()) / 2, bw, 'center')
        end
    end

    -- === CONTROL PILLS (Espaciado inferior sin solapamientos) ===
    if pillAlpha > 0 then
        local pillY = h - 34
        local pills = {
            {text = "WASD / FLECHAS", x = cx - 140},
            {text = "+ / - VELOCIDAD", x = cx + 15}
        }

        for _, pill in ipairs(pills) do
            local pw = ui.fontSmall:getWidth(pill.text) + 16
            local ph = 20
            local px = pill.x
            local py = pillY

            love.graphics.setColor(0.07, 0.09, 0.16, pillAlpha * 0.6)
            love.graphics.rectangle("fill", px, py, pw, ph, 10, 10)
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pillAlpha * 0.25)
            love.graphics.rectangle("line", px, py, pw, ph, 10, 10)

            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(0.8, 0.85, 0.95, pillAlpha * 0.75)
            love.graphics.print(pill.text, px + 8, py + (ph - ui.fontSmall:getHeight()) / 2)
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
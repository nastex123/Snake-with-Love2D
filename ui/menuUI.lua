-- ui/menuUI.lua - Menu principal asimetrico: panel vertical izquierdo, titulo Estilo #12 y high score
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

-- Texturas del logotipo Estilo #12 (Calca 1:1 HD)
local titleImage = nil
local titleGlowImage = nil
local titleLoaded = false

local function loadTitleAssets()
    if titleLoaded then return end
    titleLoaded = true
    pcall(function()
        if love.filesystem.getInfo("assets/title_style12.png") then
            titleImage = love.graphics.newImage("assets/title_style12.png")
            titleImage:setFilter("linear", "linear")
        end
        if love.filesystem.getInfo("assets/title_style12_glow.png") then
            titleGlowImage = love.graphics.newImage("assets/title_style12_glow.png")
            titleGlowImage:setFilter("linear", "linear")
        end
    end)
end

function menu.draw(ui, menuTime, globalTime, highScore)
    loadTitleAssets()

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local panelW = math.floor(w * 0.40)
    local rightCenterX = panelW + math.floor((w - panelW) / 2)

    -- Timings para aparicion
    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.4))
    local panelAlpha = math.min(1, math.max(0, (menuTime - 2.6) / 0.5))

    -- === PANEL LATERAL IZQUIERDO (40% de ancho, 100% de alto) ===
    if panelAlpha > 0 then
        -- 1. Fondo solido oscuro translúcido con leve degradado
        love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], panelAlpha * 0.92)
        love.graphics.rectangle("fill", 0, 0, panelW, h)

        -- 2. Linea divisoria vertical neón en el borde derecho
        local lineGlow = 0.75 + math.sin((globalTime or menuTime) * 3) * 0.25
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0, 0, 0, panelAlpha * 0.8)
        love.graphics.line(panelW + 2, 0, panelW + 2, h)

        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], panelAlpha * lineGlow * 0.85)
        love.graphics.line(panelW, 0, panelW, h)

        -- Marcadores arcade en los extremos de la linea
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], panelAlpha * 0.95)
        love.graphics.rectangle("fill", panelW - 2, 0, 4, 12)
        love.graphics.rectangle("fill", panelW - 2, h - 12, 4, 12)
        love.graphics.setLineWidth(1)
    end

    -- === TITULO "S N A K E" (Calca 1:1 HD Estilo #12 en Sector Derecho) ===
    if titleAlpha > 0 and titleImage then
        local ty = math.floor(h * 0.40)
        local floatOffset = math.sin((globalTime or menuTime) * 1.5) * 3
        local scaleProgress = math.min(1, (menuTime - 2.8) / 0.5)
        local enterScale = 0.92 + 0.08 * (1 - (1 - scaleProgress)^2)

        local iw = titleImage:getWidth()
        local ih = titleImage:getHeight()
        local imgScale = enterScale * 0.90

        -- 1. Sombra negra 3D profunda
        love.graphics.setColor(0, 0, 0, titleAlpha * 0.95)
        love.graphics.draw(titleImage, rightCenterX + 4, ty + floatOffset + 5, 0, imgScale, imgScale, iw / 2, ih / 2)
        love.graphics.draw(titleImage, rightCenterX + 2, ty + floatOffset + 3, 0, imgScale, imgScale, iw / 2, ih / 2)

        -- 2. Logotipo a todo color (acero biselado orgánico + gemas gemelas cian)
        love.graphics.setColor(1, 1, 1, titleAlpha)
        love.graphics.draw(titleImage, rightCenterX, ty + floatOffset, 0, imgScale, imgScale, iw / 2, ih / 2)
    end

    -- === BOTONES DEL MENU (Centrados Verticalmente en Panel Izquierdo) ===
    ui.menuButtons = {}
    local bw = 260
    local bh = 40
    local gap = 14
    local labels = {
        {id = 'play', text = 'JUGAR'},
        {id = 'profiles', text = 'PERFILES'},
        {id = 'settings', text = 'CONFIGURACIÓN'},
        {id = 'exit', text = 'SALIR'}
    }

    local totalMenuHeight = #labels * bh + (#labels - 1) * gap
    local bx = math.floor((panelW - bw) / 2)
    local by = math.floor((h - totalMenuHeight) / 2)

    for i, btn in ipairs(labels) do
        local btnStart = 3.0 + (i - 1) * 0.08
        local btnAlpha = math.min(1, math.max(0, (menuTime - btnStart) / 0.35))

        if btnAlpha > 0 then
            local isHover = (ui.menuHoverId == btn.id)
            local isPressed = (ui.menuPressedId == btn.id)
            local yOffset = isPressed and 2 or (isHover and -2 or 0)
            local slideX = (1 - btnAlpha) * -16
            local x = bx + slideX
            local y = by + (i - 1) * (bh + gap) + yOffset

            ui.menuButtons[#ui.menuButtons + 1] = {id = btn.id, x = x, y = y, w = bw, h = bh}

            -- Sombra solida negra
            love.graphics.setColor(0, 0, 0, btnAlpha * 0.85)
            love.graphics.rectangle('fill', x + 3, y + 3, bw, bh)

            -- Fondo solido del boton
            if isPressed then
                love.graphics.setColor(COLOR_BG_PRESS[1], COLOR_BG_PRESS[2], COLOR_BG_PRESS[3], btnAlpha * 0.98)
            elseif isHover then
                love.graphics.setColor(COLOR_BG_HOVER[1], COLOR_BG_HOVER[2], COLOR_BG_HOVER[3], btnAlpha * 0.98)
            else
                love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], btnAlpha * 0.95)
            end
            love.graphics.rectangle('fill', x, y, bw, bh)

            -- Borde neon recto de 2px
            love.graphics.setLineWidth(2)
            if isHover then
                local glow = 0.85 + math.sin((globalTime or menuTime) * 8) * 0.15
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * glow)
                love.graphics.rectangle('line', x, y, bw, bh)

                -- Cuadros decorativos en las 4 esquinas
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
                love.graphics.setColor(0, 0, 0, btnAlpha * 0.9)
                love.graphics.print(">", x + 15, arrowY + 1)
                love.graphics.print("<", x + bw - 23, arrowY + 1)
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha)
                love.graphics.print(">", x + 14, arrowY)
                love.graphics.print("<", x + bw - 24, arrowY)
            end

            -- Texto del boton
            love.graphics.setFont(ui.fontNormal)
            local textY = y + (bh - ui.fontNormal:getHeight()) / 2

            love.graphics.setColor(0, 0, 0, btnAlpha * 0.95)
            love.graphics.printf(btn.text, x + 1, textY + 1, bw, 'center')

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

    -- === HIGH SCORE CARD (Esquina Inferior Derecha) ===
    if cardAlpha > 0 then
        local cardW = 260
        local cardH = 34
        local cardX = w - cardW - 28
        local cardY = h - cardH - 22
        local shimmer = 0.85 + math.sin((globalTime or menuTime) * 3) * 0.15

        -- Sombra solida negra
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.85)
        love.graphics.rectangle("fill", cardX + 3, cardY + 3, cardW, cardH)

        -- Fondo solido oscuro
        love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], cardAlpha * 0.98)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)

        -- Borde neon oro
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha * shimmer)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH)
        love.graphics.setLineWidth(1)

        -- Marcadores de esquina arcade en cian
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * 0.9)
        love.graphics.rectangle("fill", cardX + 2, cardY + 2, 2, 2)
        love.graphics.rectangle("fill", cardX + cardW - 4, cardY + 2, 2, 2)
        love.graphics.rectangle("fill", cardX + 2, cardY + cardH - 4, 2, 2)
        love.graphics.rectangle("fill", cardX + cardW - 4, cardY + cardH - 4, 2, 2)

        -- Estrella geometrica pixelada en oro
        local starX = cardX + 18
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

        -- Texto High Score
        love.graphics.setFont(ui.fontNormal)
        local textY = starY - ui.fontNormal:getHeight() / 2
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 15, textY + 1)
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 14, textY)
    end
end

function menu.drawGlow(ui, menuTime, globalTime)
    loadTitleAssets()
    if not titleGlowImage then return end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local panelW = math.floor(w * 0.40)
    local rightCenterX = panelW + math.floor((w - panelW) / 2)

    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    if titleAlpha <= 0 then return end

    local ty = math.floor(h * 0.40)
    local floatOffset = math.sin((globalTime or menuTime) * 1.5) * 3
    local scaleProgress = math.min(1, (menuTime - 2.8) / 0.5)
    local enterScale = 0.92 + 0.08 * (1 - (1 - scaleProgress)^2)

    local iw = titleGlowImage:getWidth()
    local ih = titleGlowImage:getHeight()
    local imgScale = enterScale * 0.90

    local glowPulse = 0.8 + math.sin((globalTime or menuTime) * 3.5) * 0.2
    love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * glowPulse * 0.95)
    love.graphics.draw(titleGlowImage, rightCenterX, ty + floatOffset, 0, imgScale, imgScale, iw / 2, ih / 2)
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
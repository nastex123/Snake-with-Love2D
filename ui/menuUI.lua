-- ui/menuUI.lua - Facade menu principal (panel + botones) delega logo/tarjeta a submodulos
local menu = {}
local sound = require("audio.sound")
local menuLogo = require("ui.menuLogo")
local menuCard = require("ui.menuCard")

local COLOR_CYAN     = {0.0, 0.94, 1.0}
local COLOR_GOLD     = {1.0, 0.82, 0.25}
local COLOR_BG_BOX   = {0.039, 0.051, 0.094}
local COLOR_BG_HOVER = {0.06, 0.09, 0.18}
local COLOR_BG_PRESS = {0.02, 0.03, 0.06}

function menu.getLogoBounds(t)
    return menuLogo.getBounds(t)
end

function menu.draw(ui, menuTime, globalTime, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local panelW = math.floor(w * 0.40)
    local rightCenterX = panelW + math.floor((w - panelW) / 2)
    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.4))
    local panelAlpha = math.min(1, math.max(0, (menuTime - 2.6) / 0.5))
    if panelAlpha > 0 then
        local t = (globalTime or menuTime)
        local pcx = math.floor(panelW / 2)
        local pcy = math.floor(h / 2)

        -- 1. Fondo base oscuro
        love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], panelAlpha * 0.94)
        love.graphics.rectangle("fill", 0, 0, panelW, h)

        -- 2. Fondo Procedural #14: Matriz de Puntos HUD (Dot Matrix Táctico)
        local gap = 18
        for py = 12, h - 8, gap do
            for px = 12, panelW - 12, gap do
                local dist = math.sqrt((px - pcx)^2 + (py - pcy)^2)
                local wave = math.sin(dist * 0.04 - t * 2.8)
                local ptAlpha = (wave > 0.6) and 0.38 or 0.08
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], panelAlpha * ptAlpha * 0.75)
                love.graphics.rectangle("fill", px - 1, py - 1, 2, 2)
            end
        end

        -- 3. Figura Circular Alquímica Rotatoria (#17 Render 1)
        if ui.alchemyCircleTex then
            local diameter = panelW * 0.92
            local scale = diameter / 512
            local rot = t * 0.20
            local pulse = 0.85 + math.sin(t * 2.5) * 0.15
            love.graphics.setColor(1, 1, 1, panelAlpha * pulse * 0.90)
            love.graphics.draw(ui.alchemyCircleTex, pcx, pcy, rot, scale, scale, 256, 256)
        end

        -- 4. Borde divisorio vertical de plasma con terminaciones doradas
        local lineGlow = 0.75 + math.sin(t * 3) * 0.25
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0, 0, 0, panelAlpha * 0.8)
        love.graphics.line(panelW + 2, 0, panelW + 2, h)
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], panelAlpha * lineGlow * 0.85)
        love.graphics.line(panelW, 0, panelW, h)
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], panelAlpha * 0.95)
        love.graphics.rectangle("fill", panelW - 2, 0, 4, 12)
        love.graphics.rectangle("fill", panelW - 2, h - 12, 4, 12)
        love.graphics.setLineWidth(1)
    end
    if titleAlpha > 0 then
        local t = (globalTime or menuTime)
        menuLogo.draw(titleAlpha, t)
    end
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
            local t = (globalTime or menuTime)
            local midY = y + bh / 2
            local ecx = x + bw / 2
            local ecy = midY
            local btnTex = isPressed and ui.btnTexPress or (isHover and ui.btnTexHover or ui.btnTexNormal)
            if btnTex then
                love.graphics.setColor(1, 1, 1, btnAlpha)
                love.graphics.draw(btnTex, x - 3, y - 3)
            else
                local c = 6
                local poly = {x + c, y, x + bw - c, y, x + bw, y + c, x + bw, y + bh - c, x + bw - c, y + bh, x + c, y + bh, x, y + bh - c, x, y + c}
                love.graphics.setColor(0, 0, 0, btnAlpha * 0.85)
                love.graphics.polygon('fill', x + c + 2, y + 3, x + bw - c + 2, y + 3, x + bw + 2, y + c + 3, x + bw + 2, y + bh - c + 3, x + bw - c + 2, y + bh + 3, x + c + 2, y + bh + 3, x + 2, y + bh - c + 3, x + 2, y + c + 3)
                love.graphics.setColor(isPressed and COLOR_BG_PRESS or (isHover and COLOR_BG_HOVER or COLOR_BG_BOX))
                love.graphics.polygon('fill', poly)
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * (isHover and 0.9 or 0.5))
                love.graphics.polygon('line', poly)
            end
            local blinkCycle = 3.5
            local blinkProg = (t + (i - 1) * 0.75) % blinkCycle
            local blink = 0.0
            if blinkProg < 0.28 then blink = math.sin((blinkProg / 0.28) * math.pi) end
            local eyeW = 26
            local eyeH = 13
            local openH = eyeH * (1.0 - blink)
            local mx, my = love.mouse.getPosition()
            local lookX, lookY = 0, 0
            if mx and my then
                local dx = mx - ecx
                local dy = my - ecy
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    lookX = (dx / dist) * math.min(3.8, dist / 20)
                    lookY = (dy / dist) * math.min(2.0, dist / 40)
                end
            end
            love.graphics.setColor(0.02, 0.04, 0.08, btnAlpha * 0.95)
            love.graphics.polygon('fill', ecx - eyeW, ecy, ecx, ecy - eyeH, ecx + eyeW, ecy, ecx, ecy + eyeH)
            if openH > 0.5 then
                love.graphics.setScissor(ecx - eyeW, ecy - eyeH, eyeW * 2, eyeH * 2)
                local irisX = ecx + lookX
                local irisY = ecy + lookY
                if ui.eyeIrisTexture then
                    love.graphics.setColor(1, 1, 1, btnAlpha * (openH / eyeH))
                    love.graphics.draw(ui.eyeIrisTexture, irisX, irisY, 0, 1, openH / eyeH, 14, 14)
                else
                    love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * 0.9)
                    love.graphics.circle('fill', irisX, irisY, 10.5 * (openH / eyeH))
                    love.graphics.setColor(0, 0, 0, btnAlpha)
                    love.graphics.polygon('fill', irisX - 1.5, irisY - 8, irisX + 1.5, irisY - 8, irisX + 1.5, irisY + 8, irisX - 1.5, irisY + 8)
                end
                love.graphics.setScissor()
            end
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * (isHover and 0.85 or 0.45))
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon('line', ecx - eyeW, ecy, ecx, ecy - eyeH, ecx + eyeW, ecy, ecx, ecy + eyeH)
            if blink > 0.1 then
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * 0.95 * blink)
                love.graphics.line(ecx - eyeW + 2, ecy, ecx + eyeW - 2, ecy)
            end
            love.graphics.setLineWidth(1)
            if isHover then
                local o = 3
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * 0.95)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(ecx - 32 - o, ecy - 12, ecx - 32, ecy - 12)
                love.graphics.line(ecx - 32, ecy - 12, ecx - 32, ecy - 12 + o)
                love.graphics.line(ecx + 32 + o, ecy - 12, ecx + 32, ecy - 12)
                love.graphics.line(ecx + 32, ecy - 12, ecx + 32, ecy - 12 + o)
                love.graphics.line(ecx - 32 - o, ecy + 12, ecx - 32, ecy + 12)
                love.graphics.line(ecx - 32, ecy + 12, ecx - 32, ecy + 12 - o)
                love.graphics.line(ecx + 32 + o, ecy + 12, ecx + 32, ecy + 12)
                love.graphics.line(ecx + 32, ecy + 12, ecx + 32, ecy + 12 - o)
                love.graphics.setLineWidth(1)
            end
            local gearSpeed = isHover and 5.0 or 1.5
            local gearAngle = (t * gearSpeed) % (math.pi * 2)
            local lx = x + 18
            local rx = x + bw - 18
            if ui.gearTexture then
                love.graphics.setColor(1, 1, 1, btnAlpha)
                love.graphics.draw(ui.gearTexture, lx, midY, gearAngle, 1, 1, 12, 12)
                love.graphics.draw(ui.gearTexture, rx, midY, -gearAngle, 1, 1, 12, 12)
            else
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * (isHover and 0.9 or 0.6))
                love.graphics.circle('line', lx, midY, 5)
                love.graphics.circle('line', rx, midY, 5)
            end
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
    if cardAlpha > 0 then
        menuCard.draw(ui, cardAlpha, globalTime, menuTime, highScore, rightCenterX, h)
    end
end

function menu.drawGlow(ui, menuTime, globalTime)
    local t = (globalTime or menuTime)

    -- Glow del Círculo Alquímico en el Panel Izquierdo
    local panelAlpha = math.min(1, math.max(0, (menuTime - 2.6) / 0.5))
    if panelAlpha > 0 and ui.alchemyCircleGlow then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        local panelW = math.floor(w * 0.40)
        local pcx = math.floor(panelW / 2)
        local pcy = math.floor(h / 2)
        local diameter = panelW * 0.92
        local scale = diameter / 512
        local rot = t * 0.20
        local pulse = 0.75 + math.sin(t * 2.5) * 0.25
        love.graphics.setColor(1, 1, 1, panelAlpha * pulse * 0.65)
        love.graphics.draw(ui.alchemyCircleGlow, pcx, pcy, rot, scale, scale, 256, 256)
    end

    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    if titleAlpha > 0 then
        menuLogo.drawGlow(titleAlpha, t)
    end
end

function menu.mousePressed(ui, x, y)
    if not ui.menuButtons then return nil end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then return b.id end
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
            if prevHover ~= b.id then sound.play("buttonHover") end
            return
        end
    end
end

function menu.setPressed(ui, id) ui.menuPressedId = id end
function menu.clearPressed(ui) ui.menuPressedId = nil end

return menu

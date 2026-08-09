-- ui/menuUI.lua - Menu principal: titulo, high score card, botones y mouse
local menu = {}
local constants = require("constants")

function menu.draw(ui, menuTime, globalTime, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local cx = w / 2

    -- Timings shifted for Balatro intro (flash ends at 3.0s)
    local titleAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.3) / 0.5))
    local pillAlpha = math.min(1, math.max(0, (menuTime - 3.5) / 0.5))
    local enterAlpha = math.min(1, math.max(0, (menuTime - 4.0) / 0.3))

    -- === TITLE ===
    if titleAlpha > 0 then
        local titleText = "S N A K E"
        local ty = h / 2 - 70
        local letterSpread = 1 + math.sin(globalTime * 0.6) * 0.04
        local glowPulse = 0.5 + math.sin(globalTime * 1.5) * 0.3

        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(letterSpread, 1)
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))

        -- outer glow
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], titleAlpha * glowPulse * 0.2)
        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(1.06, 1.06)
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))
        love.graphics.printf(titleText, 0, ty, w, "center")
        love.graphics.pop()

        -- mid glow
        love.graphics.setColor(1, 1, 1, titleAlpha * (0.2 + glowPulse * 0.2))
        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(1.03, 1.03)
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))
        love.graphics.printf(titleText, 0, ty, w, "center")
        love.graphics.pop()

        -- core text (scaled bigger)
        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(1.4, 1.4) -- increase title size
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], titleAlpha)
        love.graphics.printf(titleText, 0, ty, w, "center")
        love.graphics.pop()

        love.graphics.pop()
    end

    -- === HIGH SCORE CARD ===
    if cardAlpha > 0 then
        local cardW = 280
        local cardH = 44
        local cardX = (w - cardW) / 2
        local cardY = h / 2 + 10
        local shimmer = math.sin(globalTime * 2) * 0.3 + 0.7

        -- bg glassmorphism
        love.graphics.setColor(0.12, 0.12, 0.22, cardAlpha * 0.6)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6)
        -- border
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], cardAlpha * 0.3 * shimmer)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6)
        -- star icon
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha)
        local starX = cardX + 14
        local starY = cardY + cardH / 2
        local pts = {}
        for i = 0, 9 do
            local angle = math.pi / 2 - i * math.pi * 2 / 10
            local ri = i % 2 == 0 and 8 or 3
            table.insert(pts, starX + math.cos(angle) * ri)
            table.insert(pts, starY + math.sin(angle) * ri)
        end
        love.graphics.polygon("fill", pts)
        -- text
        love.graphics.setFont(ui.fontLarge)
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 20, starY - ui.fontLarge:getHeight() / 2)
        love.graphics.setLineWidth(1)
    end

    -- === CONTROL PILLS ===
    if pillAlpha > 0 then
        local pillY = h - 36
        local pills = {
            {text = "WASD / FLECHAS", x = cx - 120},
            {text = "+ / - VELOCIDAD", x = cx + 20}
        }

        for _, pill in ipairs(pills) do
            local pw = ui.fontSmall:getWidth(pill.text) + 16
            local ph = 20
            local px = pill.x
            local py = pillY

            love.graphics.setColor(0.12, 0.12, 0.22, pillAlpha * 0.5)
            love.graphics.rectangle("fill", px, py, pw, ph, 10)
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pillAlpha * 0.25)
            love.graphics.rectangle("line", px, py, pw, ph, 10)

            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 1, 1, pillAlpha * 0.7)
            love.graphics.print(pill.text, px + 8, py + (ph - ui.fontSmall:getHeight()) / 2)
        end
    end

    -- (Removed the ENTER prompt - UI uses buttons and mouse now)

    -- === MAIN MENU BUTTONS (Play / Settings / Exit) ===
    -- Buttons are stored in ui.menuButtons for click handling
    ui.menuButtons = ui.menuButtons or {}
    ui.menuButtons = {}
    if enterAlpha > 0 then
        local bw = 220
        local bh = 44
        local bx = cx - bw/2
        local by = h/2 + 80
        local gap = 14
            local labels = { {id='play', text='JUGAR'}, {id='profiles', text='PERFILES'}, {id='settings', text='CONFIGURACIÓN'}, {id='exit', text='SALIR'} }
        for i, btn in ipairs(labels) do
            local x = bx
            local y = by + (i-1) * (bh + gap)
            ui.menuButtons[#ui.menuButtons+1] = {id = btn.id, x=x, y=y, w=bw, h=bh}
            local isHover = (ui.menuHoverId == btn.id)
            local isPressed = (ui.menuPressedId == btn.id)
            local alpha = enterAlpha * 0.95
            local baseColor = {0.12, 0.12, 0.22}
            if isPressed then
                love.graphics.setColor(baseColor[1]*0.6, baseColor[2]*0.6, baseColor[3]*0.6, alpha)
            elseif isHover then
                love.graphics.setColor(baseColor[1]*0.8, baseColor[2]*0.8, baseColor[3]*0.8, alpha)
            else
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], alpha)
            end
            love.graphics.rectangle('fill', x, y, bw, bh, 8)
            love.graphics.setColor(1,1,1, enterAlpha)
            love.graphics.setFont(ui.fontNormal)
            love.graphics.printf(btn.text, x, y + (bh - ui.fontNormal:getHeight())/2, bw, 'center')
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
    ui.menuHoverId = nil
    if not ui.menuButtons then return end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            ui.menuHoverId = b.id
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
-- ui/overlaysUI.lua - Overlays: pausa, minimap y depuracion dungeon
local overlays = {}
local constants = require("constants")

function overlays.drawPause(ui)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(ui.fontTitle)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("PAUSA", 0, h / 2 - 30, w, "center")

    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("ESPACIO / ESC PARA CONTINUAR", 0, h / 2 + 10, w, "center")
end

-- Dungeon minimap (top-right corner)
function overlays.drawDungeonMap(ui, dungeonData)
    if not dungeonData then return end
    local w = love.graphics.getWidth()
    local mapW = 140
    local mapH = 100
    local mx = w - mapW - 8
    local my = 34
    local scaleX = mapW / dungeonData.virtualW
    local scaleY = mapH / dungeonData.virtualH

    -- Background
    love.graphics.setColor(0.06, 0.06, 0.10, 0.75)
    love.graphics.rectangle("fill", mx, my, mapW, mapH, 4)
    love.graphics.setColor(0.2, 0.2, 0.3, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mapW, mapH, 4)

    -- Corridors
    love.graphics.setColor(0.3, 0.3, 0.4, 0.4)
    for _, c in ipairs(dungeonData.corridors) do
        for _, pt in ipairs(c.path or {}) do
            love.graphics.rectangle("fill", mx + pt.x * scaleX, my + pt.y * scaleY, pt.w * scaleX, pt.h * scaleY)
        end
    end

    -- Rooms
    for _, r in ipairs(dungeonData.rooms) do
        local rx = mx + r.rect.x * scaleX
        local ry = my + r.rect.y * scaleY
        local rw = math.max(2, r.rect.w * scaleX)
        local rh = math.max(2, r.rect.h * scaleY)

        if r.current then
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.7)
        elseif r.cleared then
            love.graphics.setColor(0.3, 0.7, 0.3, 0.5)
        elseif r.visited then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
        else
            love.graphics.setColor(0.2, 0.2, 0.25, 0.3)
        end
        love.graphics.rectangle("fill", rx, ry, rw, rh, 2)

        if r.current then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", rx, ry, rw, rh, 2)
        end
    end
end

-- Debug dungeon overlay: draw full room rects and info
function overlays.drawDebugDungeon(ui, dungeonData)
    if not dungeonData then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local scaleX = w / dungeonData.virtualW
    local scaleY = h / dungeonData.virtualH
    love.graphics.setFont(ui.fontSmall)

    -- Corridors
    love.graphics.setColor(0.6, 0.6, 0.3, 0.15)
    for _, c in ipairs(dungeonData.corridors) do
        for _, pt in ipairs(c.path or {}) do
            love.graphics.rectangle("fill", pt.x * scaleX, pt.y * scaleY, pt.w * scaleX, pt.h * scaleY)
        end
    end

    -- Rooms
    for _, r in ipairs(dungeonData.rooms) do
        local rx = r.rect.x * scaleX
        local ry = r.rect.y * scaleY
        local rw = math.max(4, r.rect.w * scaleX)
        local rh = math.max(4, r.rect.h * scaleY)

        local color = r.current and {0, 0.85, 1, 0.3} or {0.3, 0.3, 0.5, 0.2}
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", rx, ry, rw, rh)
        love.graphics.setColor(0.8, 0.8, 0.8, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rx, ry, rw, rh)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(r.id .. ":" .. r.name, rx + 2, ry + 2)
    end

    -- Connections
    love.graphics.setColor(0, 0.85, 1, 0.3)
    for _, c in ipairs(dungeonData.corridors) do
        local ra = dungeonData.rooms[c.from]
        local rb = dungeonData.rooms[c.to]
        if ra and rb then
            love.graphics.line(ra.centerX * scaleX, ra.centerY * scaleY, rb.centerX * scaleX, rb.centerY * scaleY)
        end
    end
end

function overlays.drawDeathModal(ui)
    local world = require("core.world")
    local st = world.state
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local time = love.timer.getTime()

    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local pw = 420
    local ph = 230
    local px = math.floor((w - pw) / 2)
    local py = math.floor((h - ph) / 2)

    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", px + 4, py + 4, pw, ph, 4)

    love.graphics.setColor(0.04, 0.05, 0.08, 0.96)
    love.graphics.rectangle("fill", px, py, pw, ph, 4)

    local aPulse = math.sin(time * 8) * 0.2 + 0.8
    love.graphics.setColor(0.9, 0.1, 0.2, aPulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(1.0, 0.2, 0.2, 1.0)
    love.graphics.printf("[ CRITICO: HAS CAIDO ]", px, py + 14, pw, "center")

    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1, 0.85)
    local ptsText = "Puntaje: " .. (st.puntuacion or 0)
    local streakText = string.format("Racha: %.1fx", st.survivalStreak or 1.0)
    local coinsText = "Oro: " .. (st.monedas or 0) .. "$"
    love.graphics.printf(ptsText .. "  |  " .. streakText .. "  |  " .. coinsText, px, py + 46, pw, "center")

    local canRevive = (st.monedas or 0) >= (constants.REVIVE_COIN_COST or 30)
    local btn1X = px + 24
    local btn1Y = py + 78
    local btn1W = pw - 48
    local btn1H = 46

    local mx, my = love.mouse.getPosition()
    local hover1 = (mx >= btn1X and mx <= btn1X + btn1W and my >= btn1Y and my <= btn1Y + btn1H)

    if canRevive then
        love.graphics.setColor(hover1 and 0.08 or 0.05, hover1 and 0.25 or 0.18, hover1 and 0.35 or 0.25, 0.95)
        love.graphics.rectangle("fill", btn1X, btn1Y, btn1W, btn1H, 3)
        love.graphics.setColor(0.0, 0.94, 1.0, hover1 and 1.0 or 0.7)
        love.graphics.rectangle("line", btn1X, btn1Y, btn1W, btn1H, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("[1 / ENTER] CONTINUAR / REVIVIR (-30$)", btn1X, btn1Y + 8, btn1W, "center")
        love.graphics.setFont(ui.fontSmall)
        love.graphics.setColor(0.0, 0.94, 1.0, 0.8)
        love.graphics.printf("Otorga 3s de invulnerabilidad y despeja el area", btn1X, btn1Y + 26, btn1W, "center")
    else
        love.graphics.setColor(0.12, 0.06, 0.06, 0.6)
        love.graphics.rectangle("fill", btn1X, btn1Y, btn1W, btn1H, 3)
        love.graphics.setColor(0.4, 0.2, 0.2, 0.4)
        love.graphics.rectangle("line", btn1X, btn1Y, btn1W, btn1H, 3)
        love.graphics.setColor(0.6, 0.4, 0.4, 0.6)
        love.graphics.printf("[1 / ENTER] REVIVIR (Requiere 30$)", btn1X, btn1Y + 14, btn1W, "center")
    end

    love.graphics.setFont(ui.fontNormal)
    local btn2X = px + 24
    local btn2Y = py + 140
    local btn2W = pw - 48
    local btn2H = 40

    local hover2 = (mx >= btn2X and mx <= btn2X + btn2W and my >= btn2Y and my <= btn2Y + btn2H)
    love.graphics.setColor(hover2 and 0.25 or 0.15, hover2 and 0.08 or 0.04, hover2 and 0.08 or 0.04, 0.95)
    love.graphics.rectangle("fill", btn2X, btn2Y, btn2W, btn2H, 3)
    love.graphics.setColor(0.9, 0.2, 0.2, hover2 and 1.0 or 0.6)
    love.graphics.rectangle("line", btn2X, btn2Y, btn2W, btn2H, 3)
    love.graphics.setColor(1, 1, 1, hover2 and 1.0 or 0.8)
    love.graphics.printf("[2 / ESC] ACEPTAR MUERTE", btn2X, btn2Y + 12, btn2W, "center")

    overlays._deathButtons = {
        revive = {x = btn1X, y = btn1Y, w = btn1W, h = btn1H, enabled = canRevive},
        accept = {x = btn2X, y = btn2Y, w = btn2W, h = btn2H, enabled = true}
    }
    love.graphics.setFont(ui.fontNormal)
end

function overlays.deathMousePressed(x, y)
    local btns = overlays._deathButtons
    if not btns then return nil end
    if btns.revive and btns.revive.enabled and x >= btns.revive.x and x <= btns.revive.x + btns.revive.w and y >= btns.revive.y and y <= btns.revive.y + btns.revive.h then
        return "revive"
    end
    if btns.accept and x >= btns.accept.x and x <= btns.accept.x + btns.accept.w and y >= btns.accept.y and y <= btns.accept.y + btns.accept.h then
        return "accept"
    end
    return nil
end

return overlays
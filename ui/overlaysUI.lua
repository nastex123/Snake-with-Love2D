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

return overlays
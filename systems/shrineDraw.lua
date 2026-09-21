local shrineDraw = {}
local defs = require("systems.shrineDefs")
local CYAN = {0, 0.94, 1.0}
local GOLD = {1.0, 0.84, 0.0}
local function setFontNormal()
    local ok, ui = pcall(require, "ui.ui")
    if ok and ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
end
function shrineDraw.layout()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local pw = math.min(560, math.floor(w * 0.8))
    local ph = math.min(440, h - 40)
    local px = math.floor((w - pw) / 2)
    local py = math.floor((h - ph) / 2)
    return px, py, pw, ph
end
function shrineDraw.draw(balance, ranks, modeInfo)
    local px, py, pw, ph = shrineDraw.layout()
    local rects = {buttons = {}, modes = {}}
    love.graphics.setColor(0.03, 0.05, 0.09, 0.96)
    love.graphics.rectangle("fill", px, py, pw, ph, 8)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.8)
    love.graphics.rectangle("line", px, py, pw, ph, 8)
    setFontNormal()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SANTUARIO", px, py + 10, pw, "center")
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3])
    love.graphics.printf("Reliquias: " .. tostring(balance or 0), px, py + 28, pw, "center")
    if modeInfo and modeInfo.list then
        local mw = math.floor((pw - 32 - 3 * 8) / 4)
        local mx = px + 16
        local my = py + 46
        for _, m in ipairs(modeInfo.list) do
            local cur = (modeInfo.current == m.id)
            if m.unlocked then love.graphics.setColor(0.08, 0.16, 0.22, 1)
            else love.graphics.setColor(0.12, 0.12, 0.14, 1) end
            love.graphics.rectangle("fill", mx, my, mw, 24, 4)
            if cur then love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
            else love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.6) end
            love.graphics.rectangle("line", mx, my, mw, 24, 4)
            love.graphics.setColor(m.unlocked and 1 or 0.45, m.unlocked and 1 or 0.45, m.unlocked and 1 or 0.45)
            love.graphics.printf(string.upper(m.id), mx, my + 6, mw, "center")
            if m.unlocked then
                rects.modes[#rects.modes + 1] = {id = m.id, x = mx, y = my, w = mw, h = 24}
            end
            mx = mx + mw + 8
        end
    end
    local y = py + 76
    local rowH = 36
    for i, d in ipairs(defs.LIST) do
        if y + rowH > py + ph - 48 then break end
        local rank = (ranks and ranks[d.id]) or 0
        local maxR = defs.maxRank(d.id)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(d.name .. " (" .. rank .. "/" .. maxR .. ")", px + 16, y + 2, pw - 160, "left")
        love.graphics.setColor(0.7, 0.75, 0.85)
        local rankText = (rank < maxR) and (d.ranks[rank + 1] or "") or "MAX"
        love.graphics.printf(rankText, px + 16, y + 18, pw - 160, "left")
        local bx, bw, bh = px + pw - 128, 110, 26
        local by = y + 5
        local afford = rank < maxR
        if afford then love.graphics.setColor(0.08, 0.16, 0.22, 1) else love.graphics.setColor(0.15, 0.15, 0.17, 1) end
        love.graphics.rectangle("fill", bx, by, bw, bh, 5)
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.7)
        love.graphics.rectangle("line", bx, by, bw, bh, 5)
        love.graphics.setColor(1, 1, 1)
        local price = defs.cost(d.id, rank + 1)
        love.graphics.printf(afford and (tostring(price) .. "$") or "--", bx, by + 6, bw, "center")
        rects.buttons[#rects.buttons + 1] = {id = d.id, x = bx, y = by, w = bw, h = bh}
        y = y + rowH
    end
    local cx, cw, ch = px + math.floor((pw - 140) / 2), 140, 30
    local cy = py + ph - 38
    love.graphics.setColor(0.08, 0.12, 0.18, 1)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 6)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.8)
    love.graphics.rectangle("line", cx, cy, cw, ch, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("VOLVER", cx, cy + 8, cw, "center")
    rects.close = {x = cx, y = cy, w = cw, h = ch}
    return rects
end
return shrineDraw

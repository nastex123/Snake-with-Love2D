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
    local pw = math.min(600, math.floor(w * 0.85))
    local ph = math.min(470, h - 20)
    local px = math.floor((w - pw) / 2)
    local py = math.floor((h - ph) / 2)
    return px, py, pw, ph
end
function shrineDraw.draw(balance, ranks, modeInfo, skinInfo)
    local px, py, pw, ph = shrineDraw.layout()
    local rects = {buttons = {}, modes = {}, skins = {}}
    love.graphics.setColor(0.03, 0.05, 0.09, 0.96)
    love.graphics.rectangle("fill", px, py, pw, ph, 8)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.8)
    love.graphics.rectangle("line", px, py, pw, ph, 8)
    setFontNormal()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SANTUARIO", px, py + 8, pw, "center")
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3])
    love.graphics.printf("Reliquias: " .. tostring(balance or 0), px, py + 26, pw, "center")
    if modeInfo and modeInfo.list and #modeInfo.list > 0 then
        local numM = #modeInfo.list
        local mw = math.floor((pw - 32 - (numM - 1) * 6) / numM)
        local mx = px + 16
        local my = py + 44
        for _, m in ipairs(modeInfo.list) do
            local cur = (modeInfo.current == m.id)
            if m.unlocked then love.graphics.setColor(0.08, 0.16, 0.22, 1)
            else love.graphics.setColor(0.12, 0.08, 0.08, 1) end
            love.graphics.rectangle("fill", mx, my, mw, 22, 4)
            if cur then love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
            elseif m.unlocked then love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.6)
            else love.graphics.setColor(0.5, 0.2, 0.2, 0.5) end
            love.graphics.rectangle("line", mx, my, mw, 22, 4)
            love.graphics.setColor(m.unlocked and 1 or 0.5, m.unlocked and 1 or 0.35, m.unlocked and 1 or 0.35)
            local label = (m.id == "diario" and not m.unlocked) and "[00:00]" or string.upper(m.id)
            love.graphics.printf(label, mx, my + 5, mw, "center")
            if m.unlocked then
                rects.modes[#rects.modes + 1] = {id = m.id, x = mx, y = my, w = mw, h = 22}
            end
            mx = mx + mw + 6
        end
    end
    local y = py + 72
    local rowH = 34
    for i, d in ipairs(defs.LIST) do
        if y + rowH > py + ph - 74 then break end
        local rank = (ranks and ranks[d.id]) or 0
        local maxR = defs.maxRank(d.id)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(d.name .. " (" .. rank .. "/" .. maxR .. ")", px + 16, y + 2, pw - 160, "left")
        love.graphics.setColor(0.7, 0.75, 0.85)
        local rankText = (rank < maxR) and (d.ranks[rank + 1] or "") or "MAX"
        love.graphics.printf(rankText, px + 16, y + 17, pw - 160, "left")
        local bx, bw, bh = px + pw - 128, 110, 24
        local by = y + 5
        local afford = rank < maxR
        if afford then love.graphics.setColor(0.08, 0.16, 0.22, 1) else love.graphics.setColor(0.15, 0.15, 0.17, 1) end
        love.graphics.rectangle("fill", bx, by, bw, bh, 5)
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.7)
        love.graphics.rectangle("line", bx, by, bw, bh, 5)
        love.graphics.setColor(1, 1, 1)
        local price = defs.cost(d.id, rank + 1)
        love.graphics.printf(afford and (tostring(price) .. "$") or "--", bx, by + 5, bw, "center")
        rects.buttons[#rects.buttons + 1] = {id = d.id, x = bx, y = by, w = bw, h = bh}
        y = y + rowH
    end

    -- Fila de selección de Skins
    if skinInfo and skinInfo.list and #skinInfo.list > 0 then
        local sy = py + ph - 68
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf("SKIN:", px + 16, sy + 3, 48, "left")
        local numS = #skinInfo.list
        local skW = math.floor((pw - 76 - (numS - 1) * 6) / numS)
        local skX = px + 68
        for _, s in ipairs(skinInfo.list) do
            local isCur = (skinInfo.current == s.id)
            if s.unlocked then love.graphics.setColor(0.06, 0.12, 0.18, 1)
            else love.graphics.setColor(0.12, 0.08, 0.08, 0.8) end
            love.graphics.rectangle("fill", skX, sy, skW, 22, 3)
            if isCur then love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1.0)
            elseif s.unlocked then love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.6)
            else love.graphics.setColor(0.4, 0.2, 0.2, 0.4) end
            love.graphics.rectangle("line", skX, sy, skW, 22, 3)

            -- Previsualización miniatura (3 puntitos de color)
            local ch = s.colorHead or {0, 1, 1}
            local cb = s.colorBody or {0, 0.6, 0.8}
            love.graphics.setColor(ch[1], ch[2], ch[3], s.unlocked and 1 or 0.3)
            love.graphics.rectangle("fill", skX + 4, sy + 7, 4, 8)
            love.graphics.setColor(cb[1], cb[2], cb[3], s.unlocked and 1 or 0.3)
            love.graphics.rectangle("fill", skX + 9, sy + 8, 3, 6)
            love.graphics.rectangle("fill", skX + 13, sy + 9, 3, 4)

            love.graphics.setColor(s.unlocked and 1 or 0.4, s.unlocked and 1 or 0.4, s.unlocked and 1 or 0.4)
            local sname = s.unlocked and s.name or "[BLOQ]"
            love.graphics.printf(sname, skX + 18, sy + 5, skW - 20, "center")
            if s.unlocked then
                rects.skins[#rects.skins + 1] = {id = s.id, x = skX, y = sy, w = skW, h = 22}
            end
            skX = skX + skW + 6
        end
    end

    local cx, cw, ch = px + math.floor((pw - 140) / 2), 140, 26
    local cy = py + ph - 34
    love.graphics.setColor(0.08, 0.12, 0.18, 1)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 6)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.8)
    love.graphics.rectangle("line", cx, cy, cw, ch, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("VOLVER", cx, cy + 6, cw, "center")
    rects.close = {x = cx, y = cy, w = cw, h = ch}
    return rects
end
return shrineDraw

local codexUI = {}
local persistence = require("systems.persistence")
local constants = require("constants")
local ui = require("ui.ui")
function codexUI.cardLinks(mod, innerX, cy, cardH, statY, mx, my, index)
    local achX = innerX + 56
    local achY2 = math.min(cy + cardH - 18, statY + ((cardH >= 90) and 14 or 0))
    local achW, achH = 70, 14
    local function link(x, label, action)
        if mod.buttonHover(x, achY2, achW, achH, mx, my) then
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.7)
        else
            love.graphics.setColor(0.4, 0.4, 0.6, 0.4)
        end
        love.graphics.setFont(ui.fontSmall)
        love.graphics.print(label, x, achY2)
        mod.buttonRects[#mod.buttonRects + 1] = {x = x, y = achY2, w = achW, h = achH, action = action, index = index}
    end
    link(achX, "Ver Logros", "achievements")
    link(achX + achW + 10, "Ver Codice", "codex")
end
function codexUI.draw(mod)
    mod.buttonRects = {}
    local codexMod = require("systems.codex")
    local p = persistence.getActiveProfile()
    local pad = mod.panelPad
    local px, py, pw = mod.panelX, mod.panelY, mod.panelW
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("CODICE DE LA SERPIENTE", px, py + 10, pw, "center")
    local y = py + 44
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("BESTIARIO", px + pad, y, pw - pad * 2, "left")
    y = y + 20
    love.graphics.setFont(ui.fontSmall)
    for _, e in ipairs(codexMod.BESTIARY) do
        local seen = p and p.codex and (
            (e.kind == "mini" and p.codex.miniBossesSeen and p.codex.miniBossesSeen[e.id]) or
            (e.kind ~= "mini" and p.codex.enemiesSeen and p.codex.enemiesSeen[e.id]))
        if seen then love.graphics.setColor(1, 0.84, 0) else love.graphics.setColor(0.45, 0.45, 0.5) end
        local label = (seen and e.name) or "???"
        love.graphics.printf("- " .. label .. "  " .. (seen and e.desc or ""), px + pad + 8, y, pw - pad * 2 - 16, "left")
        y = y + 15
    end
    y = y + 6
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SINERGIAS", px + pad, y, pw - pad * 2, "left")
    y = y + 20
    love.graphics.setFont(ui.fontSmall)
    for _, s in ipairs(codexMod.SYNERGIES) do
        local known = p and p.codex and p.codex.synergies and p.codex.synergies[s.id]
        if known then love.graphics.setColor(0.4, 0.9, 1) else love.graphics.setColor(0.45, 0.45, 0.5) end
        local req = table.concat(s.items, " + ")
        local label = (known and s.name) or "???"
        love.graphics.printf("- " .. label .. "  [" .. req .. "]  " .. (known and s.desc or ""), px + pad + 8, y, pw - pad * 2 - 16, "left")
        y = y + 15
    end
    local bw, bh = 130, 28
    local bx = px + math.floor((pw - bw) / 2)
    local by = py + mod.panelH - 38
    love.graphics.setColor(0.08, 0.12, 0.18, 1)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.8)
    love.graphics.rectangle("line", bx, by, bw, bh, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(ui.fontNormal)
    love.graphics.printf("CERRAR", bx, by + 7, bw, "center")
    mod.buttonRects[#mod.buttonRects + 1] = {action = "close_codex", x = bx, y = by, w = bw, h = bh}
end
return codexUI

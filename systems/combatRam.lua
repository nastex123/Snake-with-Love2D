-- systems/combatRam.lua — Cabezazos contra jefes (GDD §5 rework)
-- Daño por combo display + rebote con fantasma. Sin estado propio.
local combatRam = {}
local constants = require("constants")

-- Daño del cabezazo: 0 bajo el minimo, display-1 capado arriba
function combatRam.damageFor(comboDisplay)
    local minC = constants.HEADBUTT_MIN_COMBO or 2
    if (comboDisplay or 0) < minC then return 0 end
    local dmg = (comboDisplay or 0) - 1
    local cap = constants.HEADBUTT_MAX_DMG or 4
    if dmg > cap then dmg = cap end
    if dmg < 1 then dmg = 1 end
    return dmg
end

-- Rebote: retrocede la cabeza 1 celda (si cabe) y otorga fantasma
function combatRam.ram(s, w, h)
    if not s or not s.body or #s.body == 0 then return false end
    local head = s.body[1]
    local nx, ny = head.x - (s.dirX or 0), head.y - (s.dirY or 0)
    w = w or constants.MAX_GRID_COLS or 32
    h = h or constants.MAX_GRID_ROWS or 18
    if nx >= 0 and nx < w and ny >= 0 and ny < h then
        head.x, head.y = nx, ny
    end
    s.bumpGhostTimer = constants.HEADBUTT_GHOST_TIME or 0.8
    return true
end

function combatRam.hasGhost(s)
    return s and s.bumpGhostTimer and s.bumpGhostTimer > 0
end

return combatRam

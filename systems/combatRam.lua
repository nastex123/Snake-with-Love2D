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

-- Rebote seguro: atrás → laterales → quedarse. Nunca sobre cuerpo/muro/rect.
-- opts = {body={{x,y}...}, avoidRects={{x0,y0,x1,y1}...}} ; retorna true si movió.
function combatRam.ram(s, w, h, opts)
    if not s or not s.body or #s.body == 0 then return false end
    local head = s.body[1]
    local dx, dy = (s.dirX or 0), (s.dirY or 0)
    w = w or constants.MAX_GRID_COLS or 32
    h = h or constants.MAX_GRID_ROWS or 18
    local cands = {{x = head.x - dx, y = head.y - dy}}
    if dx ~= 0 then
        cands[#cands + 1] = {x = head.x, y = head.y - 1}
        cands[#cands + 1] = {x = head.x, y = head.y + 1}
    else
        cands[#cands + 1] = {x = head.x - 1, y = head.y}
        cands[#cands + 1] = {x = head.x + 1, y = head.y}
    end
    local function blocked(cx, cy)
        if cx < 0 or cx >= w or cy < 0 or cy >= h then return true end
        if opts and opts.body then
            for i = 2, #opts.body do
                local seg = opts.body[i]
                if seg and seg.x == cx and seg.y == cy then return true end
            end
        end
        if opts and opts.avoidRects then
            for _, r in ipairs(opts.avoidRects) do
                if cx >= r.x0 and cx <= r.x1 and cy >= r.y0 and cy <= r.y1 then return true end
            end
        end
        return false
    end
    for _, c in ipairs(cands) do
        if not blocked(c.x, c.y) then
            head.x, head.y = c.x, c.y
            s.bumpGhostTimer = constants.HEADBUTT_GHOST_TIME or 0.8
            return true
        end
    end
    s.bumpGhostTimer = constants.HEADBUTT_GHOST_TIME or 0.8
    return false
end

function combatRam.hasGhost(s)
    return s ~= nil and s.bumpGhostTimer ~= nil and s.bumpGhostTimer > 0
end

return combatRam

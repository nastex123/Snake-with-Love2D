-- =============================================================================
-- MÓDULO: entities/snake/abilities.lua
-- Parte de P02 — Split de entities/snake.lua (922 → 4 submódulos + fachada)
-- Gestiona habilidades tácticas: Autotomía, Reverse Slither y Slimming.
-- Extraído de entities/snake.lua sin cambios de semántica.
-- =============================================================================
local abilities = {}
local constants = require("constants")

function abilities.triggerReverseSlither(s)
    if not s or not s.body or #s.body < 2 then return false end
    s.reverseSlitherCooldown = s.reverseSlitherCooldown or 0
    if s.reverseSlitherCooldown > 0 then return false end

    local n = #s.body
    for i = 1, math.floor(n / 2) do
        s.body[i], s.body[n - i + 1] = s.body[n - i + 1], s.body[i]
    end

    local h = s.body[1]
    local neck = s.body[2]
    local dx = h.x - neck.x
    local dy = h.y - neck.y
    if math.abs(dx) > 1 then dx = dx > 0 and -1 or 1 end
    if math.abs(dy) > 1 then dy = dy > 0 and -1 or 1 end

    if dx ~= 0 and dy == 0 then
        s.dirX = dx
        s.dirY = 0
    elseif dy ~= 0 and dx == 0 then
        s.dirX = 0
        s.dirY = dy
    elseif dx ~= 0 then
        s.dirX = dx
        s.dirY = 0
    elseif dy ~= 0 then
        s.dirX = 0
        s.dirY = dy
    else
        s.dirX = -s.dirX
        s.dirY = -s.dirY
    end

    s.lastMovedDirX = s.dirX
    s.lastMovedDirY = s.dirY
    s.inputQueue = {}

    s.ghost = true
    s.ghostTimer = 1.2
    s.reverseSlitherTimer = constants.REVERSE_SLITHER_DURATION or 3.0
    s.reverseSlitherCooldown = constants.REVERSE_SLITHER_COOLDOWN or 10.0

    s.prevBody = {}
    for i, seg in ipairs(s.body) do
        s.prevBody[i] = {x = seg.x, y = seg.y}
    end
    return true, h
end

function abilities.applySlimming(s)
    if not s or not s.body then return false end
    local minLen = constants.SLIMMING_MIN_LENGTH or 12
    if #s.body >= minLen then
        local factor = constants.SLIMMING_FACTOR or 0.5
        local target = math.max(3, math.floor(#s.body * factor))
        while #s.body > target do
            table.remove(s.body)
        end
        s.prevBody = {}
        for i, seg in ipairs(s.body) do
            s.prevBody[i] = {x = seg.x, y = seg.y}
        end
        return true
    end
    return false
end

function abilities.triggerAutotomy(s)
    if not s or not s.body then return false end
    s.autotomyCooldown = s.autotomyCooldown or 0
    s.decoys = s.decoys or {}

    if s.autotomyCooldown <= 0 and #s.body >= 4 then
        local r1 = table.remove(s.body)
        local r2 = table.remove(s.body)
        local decoyPos = r1 or r2
        table.insert(s.decoys, {
            x = decoyPos.x,
            y = decoyPos.y,
            timer = constants.AUTOTOMY_DECOY_DURATION or 4.0,
            maxTimer = constants.AUTOTOMY_DECOY_DURATION or 4.0
        })
        s.ghost = true
        s.ghostTimer = constants.AUTOTOMY_GHOST_DURATION or 1.5
        s.autotomyCooldown = constants.AUTOTOMY_COOLDOWN or 8.0
        s.prevBody = {}
        for i, seg in ipairs(s.body) do
            s.prevBody[i] = {x = seg.x, y = seg.y}
        end
        return true, decoyPos
    end
    return false
end

return abilities

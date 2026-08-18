local helpers = {}

function helpers.deep_copy(orig)
    local orig_type = type(orig)
    if orig_type ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[k] = helpers.deep_copy(v) end
    return copy
end

-- Debounce helper: devuelve una función que ejecuta fn después de delay segundos desde la última llamada
-- (Removed debounce helper — menu.lua implements debounce directly)

-- Rectangle utilities for dungeon generation
function helpers.rectsOverlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x
        and a.y < b.y + b.h and a.y + a.h > b.y
end

function helpers.rectContains(r, px, py)
    return px >= r.x and px < r.x + r.w
        and py >= r.y and py < r.y + r.h
end

function helpers.rectCenter(r)
    return r.x + r.w / 2, r.y + r.h / 2
end

function helpers.distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function helpers.manhattan(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

function helpers.clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

-- Seeded random number generator state
local rngState = 0

function helpers.seedRandom(seed)
    if seed then
        rngState = seed
    end
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648
end

return helpers

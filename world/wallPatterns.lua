local Patterns = {}
local function inside(gx, gy, w, h)
    return gx >= 1 and gy >= 1 and gx < w - 1 and gy < h - 1
end
local function farFromSpawn(gx, gy, cx, cy)
    return math.max(math.abs(gx - cx), math.abs(gy - cy)) > 2
end
function Patterns.cruz(cx, cy, w, h)
    local cells = {}
    for k = 3, 5 do
        for _, d in ipairs({{k, 0}, {-k, 0}, {0, k}, {0, -k}}) do
            local gx, gy = cx + d[1], cy + d[2]
            if inside(gx, gy, w, h) and farFromSpawn(gx, gy, cx, cy) then
                cells[#cells + 1] = {x = gx, y = gy}
            end
        end
    end
    return cells
end
function Patterns.espiral(cx, cy, w, h)
    local cells = {}
    for _, ring in ipairs({{d = 3, gap = "east"}, {d = 5, gap = "west"}}) do
        local d = ring.d
        for a = -d, d do
            local candidates = {{a, -d}, {a, d}, {-d, a}, {d, a}}
            for _, c in ipairs(candidates) do
                local gx, gy = cx + c[1], cy + c[2]
                local isGap = (ring.gap == "east" and c[1] == d) or (ring.gap == "west" and c[1] == -d)
                if not isGap and inside(gx, gy, w, h) and farFromSpawn(gx, gy, cx, cy) then
                    cells[#cells + 1] = {x = gx, y = gy}
                end
            end
        end
    end
    return cells
end
function Patterns.laberinto(cx, cy, w, h)
    local cells = {}
    local col = 0
    for gx = cx - 6, cx + 6, 4 do
        col = col + 1
        local gapY = (col % 2 == 1) and (cy - 5) or (cy + 5)
        for gy = cy - 5, cy + 5 do
            if gy ~= gapY and inside(gx, gy, w, h) and farFromSpawn(gx, gy, cx, cy) then
                cells[#cells + 1] = {x = gx, y = gy}
            end
        end
    end
    return cells
end
function Patterns.cellsFor(patternId, cx, cy, w, h)
    local raw
    if patternId == "cruz" then raw = Patterns.cruz(cx, cy, w, h)
    elseif patternId == "espiral" then raw = Patterns.espiral(cx, cy, w, h)
    elseif patternId == "laberinto" then raw = Patterns.laberinto(cx, cy, w, h)
    else return {} end
    local seen, out = {}, {}
    for _, c in ipairs(raw) do
        local k = c.x .. ":" .. c.y
        if not seen[k] then
            seen[k] = true
            out[#out + 1] = c
        end
    end
    return out
end
return Patterns

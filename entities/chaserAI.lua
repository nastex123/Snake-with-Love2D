-- entities/chaserAI.lua — IA social del chaser (GDD seccion 3)
-- Modos: SOLO (hunter), DUPLA (hunter + flankers), MANADA (anillo + cierre).
-- Estados por enemigo: idle / chase / flank / encircle / close.
-- El dibujo state-driven vive en render/enemiesDraw.lua (Estrella de espinas).
local chaserAI = {}
local constants = require("constants")

local TAU = math.pi * 2

local ringTimer = 0
local ringPhase = "enc"
local lastMode = nil

local function rnd(a, b)
    if love and love.math and love.math.random then
        if not a then return love.math.random() end
        if not b then return love.math.random(a) end
        return love.math.random(a, b)
    end
    if not a then return math.random() end
    if not b then return math.random(a) end
    return math.random(a, b)
end

local function angDiff(a, b)
    a = (a and a == a) and a or 0
    b = (b and b == b) and b or 0
    local d = (b - a) % TAU
    if d > math.pi then d = d - TAU end
    return d
end

local function clamp(v, lo, hi)
    if not v or v ~= v then return lo or 0 end
    lo = lo or 0
    hi = hi or lo
    if lo > hi then lo, hi = hi, lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function manhattan(ax, ay, bx, by)
    ax = (ax and ax == ax) and ax or 0
    ay = (ay and ay == ay) and ay or 0
    bx = (bx and bx == bx) and bx or 0
    by = (by and by == by) and by or 0
    return math.abs(ax - bx) + math.abs(ay - by)
end

function chaserAI.reset()
    ringTimer = 0
    ringPhase = "enc"
    lastMode = nil
end

function chaserAI.getRingState()
    return ringTimer, ringPhase, lastMode
end

local function classify(n)
    n = tonumber(n) or 0
    if n <= 1 then return "solo" end
    if n <= 3 then return "dupla" end
    return "manada"
end

local function occupiedByEnemy(nx, ny, self, list)
    if not list then return false end
    for _, oe in ipairs(list) do
        if oe ~= self and oe.alive ~= false and oe.x == nx and oe.y == ny then
            return true
        end
    end
    return false
end

local function occupiedByObstacle(nx, ny, obstaclePos)
    if not obstaclePos then return false end
    for _, o in ipairs(obstaclePos) do
        if o.x == nx and o.y == ny then return true end
    end
    return false
end

local function occupiedBySnake(nx, ny, body)
    if not body then return false end
    for _, s in ipairs(body) do
        if s.x == nx and s.y == ny then return true end
    end
    return false
end

local function chasersNear(nx, ny, self, list)
    if not list then return 0 end
    local c = 0
    for _, oe in ipairs(list) do
        if oe ~= self and oe.alive ~= false and oe.type == "chaser"
            and manhattan(nx, ny, oe.x, oe.y) <= 2 then
            c = c + 1
        end
    end
    return c
end

local function shuffledDirs()
    local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
    for i = #dirs, 2, -1 do
        local j = rnd(i)
        dirs[i], dirs[j] = dirs[j], dirs[i]
    end
    return dirs
end

local function freeDir(e, ctx, dirs)
    local gw = ctx.anchoGrilla or constants.MAX_GRID_COLS or 32
    local gh = ctx.altoGrilla or constants.MAX_GRID_ROWS or 18
    local ex = e.x or 0
    local ey = e.y or 0
    for _, d in ipairs(dirs) do
        local nx, ny = ex + d[1], ey + d[2]
        if nx >= 0 and nx < gw and ny >= 0 and ny < gh
            and not occupiedByObstacle(nx, ny, ctx.obstaclePos)
            and not occupiedByEnemy(nx, ny, e, ctx.list)
            and not occupiedBySnake(nx, ny, ctx.body) then
            return d
        end
    end
    return nil
end

-- Navegacion greedy con scoring: obstaculo/enemigo = bloqueo duro,
-- cuerpo de la serpiente = penalizacion fuerte, anti-apilamiento,
-- tie-break barajado (sin sesgo de orden fijo).
local function stepToward(e, tx, ty, ctx)
    local gw = ctx.anchoGrilla or constants.MAX_GRID_COLS or 32
    local gh = ctx.altoGrilla or constants.MAX_GRID_ROWS or 18
    local ex = e.x or 0
    local ey = e.y or 0
    tx = (tx and tx == tx) and tx or (ctx.head and ctx.head.x) or 0
    ty = (ty and ty == ty) and ty or (ctx.head and ctx.head.y) or 0
    local spreadPenalty = constants.CHASER_SPREAD_PENALTY or 1.5

    local dirs = shuffledDirs()
    local best, bestScore = nil, nil
    for _, d in ipairs(dirs) do
        local nx, ny = ex + d[1], ey + d[2]
        if nx >= 0 and nx < gw and ny >= 0 and ny < gh
            and not occupiedByObstacle(nx, ny, ctx.obstaclePos)
            and not occupiedByEnemy(nx, ny, e, ctx.list) then
            local score = manhattan(nx, ny, tx, ty)
            if occupiedBySnake(nx, ny, ctx.body) then score = score + 6 end
            score = score + chasersNear(nx, ny, e, ctx.list) * spreadPenalty
            if not bestScore or score < bestScore then
                best, bestScore = d, score
            end
        end
    end
    if not best then
        best = freeDir(e, ctx, dirs)
    end
    if best then
        e.x = ex + best[1]
        e.y = ey + best[2]
        e.moveAng = math.atan2(best[2], best[1])
    end
end

local function flankSlot(e, ctx)
    local b1 = (ctx.body and ctx.body[1]) or ctx.head or {x = 0, y = 0}
    local b2 = ctx.body and ctx.body[2]
    local dx, dy = 1, 0
    if b2 then
        local rx, ry = b1.x - b2.x, b1.y - b2.y
        if (rx ~= 0 or ry ~= 0) and math.abs(rx) <= 1 and math.abs(ry) <= 1 then
            dx, dy = rx, ry
        end
    end
    local px, py = -dy, dx
    local side = (e.side and e.side ~= 0) and e.side or 1
    local tx = b1.x + dx + px * 2 * side
    local ty = b1.y + dy + py * 2 * side
    local gw = ctx.anchoGrilla or constants.MAX_GRID_COLS or 32
    local gh = ctx.altoGrilla or constants.MAX_GRID_ROWS or 18
    return clamp(tx, 0, gw - 1), clamp(ty, 0, gh - 1)
end

local function ringSlot(e, ctx)
    local head = ctx.head or (ctx.body and ctx.body[1]) or {x = 0, y = 0}
    local gw = ctx.anchoGrilla or constants.MAX_GRID_COLS or 32
    local gh = ctx.altoGrilla or constants.MAX_GRID_ROWS or 18
    local minDim = math.min(gw, gh)
    local rBase = math.min(3, math.floor(minDim / 6))
    rBase = math.max(2, rBase)
    local r = rBase
    if ringPhase == "flash" then r = math.max(1, rBase - 1) end
    local n = (e.ringSize and e.ringSize > 0) and e.ringSize or 4
    local a = (e.ringIndex or 0) * (TAU / n) + ringTimer * 0.4
    local tx = math.floor(head.x + math.cos(a) * r + 0.5)
    local ty = math.floor(head.y + math.sin(a) * r + 0.5)
    return clamp(tx, 0, gw - 1), clamp(ty, 0, gh - 1)
end

-- Pase "colmena" 1x/tick: clasifica el pack, asigna roles/estados,
-- avanza el ciclo de cierre y anima la rotacion de cada chaser.
-- ctx = { list, body, head, anchoGrilla, altoGrilla, obstaclePos }
function chaserAI.updatePack(ctx, dt)
    if not ctx then return end
    if not ctx.head and ctx.body and ctx.body[1] then
        ctx.head = ctx.body[1]
    end
    if not ctx.head then return end
    dt = (dt and dt == dt and dt > 0) and dt or 0

    local chasers = {}
    if ctx.list then
        for _, e in ipairs(ctx.list) do
            if e.alive ~= false and e.type == "chaser" then
                chasers[#chasers + 1] = e
            end
        end
    end
    local n = #chasers
    if n == 0 then
        lastMode = nil
        return
    end

    local mode = classify(n)

    if mode == "manada" then
        if lastMode ~= "manada" then
            ringTimer = 0
            ringPhase = "enc"
        end
        local cycle = (constants.CHASER_RING_CYCLE and constants.CHASER_RING_CYCLE > 0) and constants.CHASER_RING_CYCLE or 8
        ringTimer = (ringTimer + dt) % cycle
        if ringTimer < cycle * 0.575 then ringPhase = "enc"
        elseif ringTimer < cycle * 0.70 then ringPhase = "flash"
        elseif ringTimer < cycle * 0.77 then ringPhase = "dash"
        else ringPhase = "reform" end
    else
        ringTimer = 0
        ringPhase = "enc"
    end
    lastMode = mode

    if mode == "manada" then
        local hx, hy = ctx.head.x, ctx.head.y
        table.sort(chasers, function(a, b)
            local angA = (math.atan2(a.y - hy, a.x - hx)) % TAU
            local angB = (math.atan2(b.y - hy, b.x - hx)) % TAU
            if math.abs(angA - angB) > 0.0001 then
                return angA < angB
            end
            return manhattan(a.x, a.y, hx, hy) < manhattan(b.x, b.y, hx, hy)
        end)
    else
        table.sort(chasers, function(a, b)
            return manhattan(a.x, a.y, ctx.head.x, ctx.head.y)
                < manhattan(b.x, b.y, ctx.head.x, ctx.head.y)
        end)
    end

    local aggroIn = constants.CHASER_AGGRO_RADIUS or 8
    local aggroOut = aggroIn + 2

    -- Deteccion de ocupacion de slots para cierre anticipado del 60%
    if mode == "manada" and ringPhase == "enc" then
        local inPositionCount = 0
        for i, e in ipairs(chasers) do
            e.ringIndex = i - 1
            e.ringSize = n
            local sx, sy = ringSlot(e, ctx)
            if manhattan(e.x, e.y, sx, sy) <= 1 then
                inPositionCount = inPositionCount + 1
            end
        end
        if n > 0 and (inPositionCount / n) >= 0.60 then
            local cycle = (constants.CHASER_RING_CYCLE and constants.CHASER_RING_CYCLE > 0) and constants.CHASER_RING_CYCLE or 8
            ringTimer = cycle * 0.575
            ringPhase = "flash"
        end
    end

    for i, e in ipairs(chasers) do
        local dist = manhattan(e.x, e.y, ctx.head.x, ctx.head.y)

        if mode == "manada" then
            e.role = "hunter"
            e.ringIndex = i - 1
            e.ringSize = n
            if ringPhase == "dash" or ringPhase == "flash" then
                e.aiState = "close"
                e.ringTighten = (ringPhase == "flash")
            else
                e.aiState = "encircle"
                e.ringTighten = false
            end
        else
            local wasIdle = (e.aiState == "idle")
            local aggro = wasIdle and (dist <= aggroIn) or ((not wasIdle) and dist <= aggroOut)
            if not aggro then
                e.aiState = "idle"
                e.role = "hunter"
            elseif i == 1 then
                if e.role ~= "hunter" then
                    e.promotedTimer = 0.5
                end
                e.aiState = "chase"
                e.role = "hunter"
            else
                if e.aiState ~= "flank" then
                    e.side = ((i % 2) == 0) and 1 or -1
                end
                e.aiState = "flank"
                e.role = "flanker"
            end
        end

        if e.promotedTimer and e.promotedTimer > 0 then
            e.promotedTimer = math.max(0, e.promotedTimer - dt)
        end

        e.visRot = (e.visRot and e.visRot == e.visRot) and e.visRot or 0
        local idleSpin = constants.CHASER_IDLE_SPIN or 0.7
        local closeSpin = constants.CHASER_CLOSE_SPIN or 10
        local rotLerp = constants.CHASER_ROT_LERP or 7

        if e.aiState == "idle" then
            e.visRot = (e.visRot + idleSpin * dt) % TAU
        elseif e.aiState == "close" then
            e.visRot = (e.visRot + closeSpin * dt) % TAU
        else
            local target = (e.moveAng and e.moveAng == e.moveAng) and e.moveAng or 0
            local lerpFactor = clamp(dt * rotLerp, 0, 1)
            e.visRot = (e.visRot + angDiff(e.visRot, target) * lerpFactor) % TAU
        end
    end
end

-- Un paso de movimiento (se llama cuando vence el moveInterval del chaser).
function chaserAI.step(e, ctx)
    if not e or not ctx or not ctx.head then return end
    local st = e.aiState or "chase"

    if st == "idle" then
        e.wanderWait = (e.wanderWait or 2) - 1
        if e.wanderWait <= 0 then
            e.wanderWait = rnd(2, 5)
            local d = freeDir(e, ctx, shuffledDirs())
            if d then
                e.x = (e.x or 0) + d[1]
                e.y = (e.y or 0) + d[2]
                e.moveAng = math.atan2(d[2], d[1])
            end
        end
    elseif st == "chase" then
        stepToward(e, ctx.head.x, ctx.head.y, ctx)
    elseif st == "close" then
        if e.ringTighten then
            -- fase flash: el anillo se cierra (aviso) antes de la embestida
            local tx, ty = ringSlot(e, ctx)
            stepToward(e, tx, ty, ctx)
        else
            stepToward(e, ctx.head.x, ctx.head.y, ctx)
        end
    elseif st == "flank" then
        local tx, ty = flankSlot(e, ctx)
        stepToward(e, tx, ty, ctx)
    elseif st == "encircle" then
        local tx, ty = ringSlot(e, ctx)
        stepToward(e, tx, ty, ctx)
    else
        stepToward(e, ctx.head.x, ctx.head.y, ctx)
    end
end

-- Multiplicador del moveInterval segun estado (slowdown de manada, dash, etc.)
function chaserAI.speedFactor(e)
    if not e then return 1.0 end
    local st = e.aiState or "chase"
    if st == "encircle" or st == "flank" then return constants.CHASER_PACK_SLOWDOWN or 1.15 end
    if st == "close" then return 0.5 end
    if st == "idle" then return 1.8 end
    return 1.0
end

return chaserAI

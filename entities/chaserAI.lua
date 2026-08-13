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

local function angDiff(a, b)
    local d = (b - a) % TAU
    if d > math.pi then d = d - TAU end
    return d
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

function chaserAI.reset()
    ringTimer = 0
    ringPhase = "enc"
    lastMode = nil
end

local function classify(n)
    if n <= 1 then return "solo" end
    if n <= 3 then return "dupla" end
    return "manada"
end

local function occupiedByEnemy(nx, ny, self, list)
    for _, oe in ipairs(list) do
        if oe ~= self and oe.alive and oe.x == nx and oe.y == ny then return true end
    end
    return false
end

local function occupiedByObstacle(nx, ny, obstaclePos)
    for _, o in ipairs(obstaclePos) do
        if o.x == nx and o.y == ny then return true end
    end
    return false
end

local function occupiedBySnake(nx, ny, body)
    for _, s in ipairs(body) do
        if s.x == nx and s.y == ny then return true end
    end
    return false
end

local function chasersNear(nx, ny, self, list)
    local c = 0
    for _, oe in ipairs(list) do
        if oe ~= self and oe.alive and oe.type == "chaser"
            and manhattan(nx, ny, oe.x, oe.y) <= 2 then
            c = c + 1
        end
    end
    return c
end

local function shuffledDirs()
    local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
    for i = #dirs, 2, -1 do
        local j = love.math.random(i)
        dirs[i], dirs[j] = dirs[j], dirs[i]
    end
    return dirs
end

local function freeDir(e, ctx, dirs)
    for _, d in ipairs(dirs) do
        local nx, ny = e.x + d[1], e.y + d[2]
        if nx >= 0 and nx < ctx.anchoGrilla and ny >= 0 and ny < ctx.altoGrilla
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
    local dirs = shuffledDirs()
    local best, bestScore = nil, nil
    for _, d in ipairs(dirs) do
        local nx, ny = e.x + d[1], e.y + d[2]
        if nx >= 0 and nx < ctx.anchoGrilla and ny >= 0 and ny < ctx.altoGrilla
            and not occupiedByObstacle(nx, ny, ctx.obstaclePos)
            and not occupiedByEnemy(nx, ny, e, ctx.list) then
            local score = manhattan(nx, ny, tx, ty)
            if occupiedBySnake(nx, ny, ctx.body) then score = score + 6 end
            score = score + chasersNear(nx, ny, e, ctx.list) * constants.CHASER_SPREAD_PENALTY
            if not bestScore or score < bestScore then
                best, bestScore = d, score
            end
        end
    end
    if not best then
        best = freeDir(e, ctx, dirs)
    end
    if best then
        e.x = e.x + best[1]
        e.y = e.y + best[2]
        e.moveAng = math.atan2(best[2], best[1])
    end
end

local function flankSlot(e, ctx)
    local b1 = ctx.body[1]
    local b2 = ctx.body[2]
    local dx, dy = 1, 0
    if b2 then
        local rx, ry = b1.x - b2.x, b1.y - b2.y
        if (rx ~= 0 or ry ~= 0) and math.abs(rx) <= 1 and math.abs(ry) <= 1 then
            dx, dy = rx, ry
        end
    end
    local px, py = -dy, dx
    local side = e.side or 1
    local tx = b1.x + dx + px * 2 * side
    local ty = b1.y + dy + py * 2 * side
    return clamp(tx, 0, ctx.anchoGrilla - 1), clamp(ty, 0, ctx.altoGrilla - 1)
end

local function ringSlot(e, ctx)
    local head = ctx.head
    local rBase = math.min(3, math.floor(math.min(ctx.anchoGrilla, ctx.altoGrilla) / 6))
    rBase = math.max(2, rBase)
    local r = rBase
    if ringPhase == "flash" then r = math.max(1, rBase - 1) end
    local n = e.ringSize or 4
    local a = (e.ringIndex or 0) * (TAU / n) + ringTimer * 0.4
    local tx = math.floor(head.x + math.cos(a) * r + 0.5)
    local ty = math.floor(head.y + math.sin(a) * r + 0.5)
    return clamp(tx, 0, ctx.anchoGrilla - 1), clamp(ty, 0, ctx.altoGrilla - 1)
end

-- Pase "colmena" 1x/tick: clasifica el pack, asigna roles/estados,
-- avanza el ciclo de cierre y anima la rotacion de cada chaser.
-- ctx = { list, body, head, anchoGrilla, altoGrilla, obstaclePos }
function chaserAI.updatePack(ctx, dt)
    if not ctx.head then return end

    local chasers = {}
    for _, e in ipairs(ctx.list) do
        if e.alive and e.type == "chaser" then chasers[#chasers + 1] = e end
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
        local cycle = constants.CHASER_RING_CYCLE
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

    table.sort(chasers, function(a, b)
        return manhattan(a.x, a.y, ctx.head.x, ctx.head.y)
            < manhattan(b.x, b.y, ctx.head.x, ctx.head.y)
    end)

    local aggroIn = constants.CHASER_AGGRO_RADIUS
    local aggroOut = constants.CHASER_AGGRO_RADIUS + 2

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

        if e.aiState == "idle" then
            e.visRot = (e.visRot + constants.CHASER_IDLE_SPIN * dt) % TAU
        elseif e.aiState == "close" then
            e.visRot = (e.visRot + constants.CHASER_CLOSE_SPIN * dt) % TAU
        else
            local target = e.moveAng or 0
            e.visRot = e.visRot + angDiff(e.visRot, target) * math.min(1, dt * constants.CHASER_ROT_LERP)
        end
    end
end

-- Un paso de movimiento (se llama cuando vence el moveInterval del chaser).
function chaserAI.step(e, ctx)
    if not ctx.head then return end
    local st = e.aiState or "chase"

    if st == "idle" then
        e.wanderWait = (e.wanderWait or 2) - 1
        if e.wanderWait <= 0 then
            e.wanderWait = love.math.random(2, 5)
            local d = freeDir(e, ctx, shuffledDirs())
            if d then
                e.x = e.x + d[1]
                e.y = e.y + d[2]
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
    end
end

-- Multiplicador del moveInterval segun estado (slowdown de manada, dash, etc.)
function chaserAI.speedFactor(e)
    local st = e.aiState or "chase"
    if st == "encircle" or st == "flank" then return constants.CHASER_PACK_SLOWDOWN end
    if st == "close" then return 0.5 end
    if st == "idle" then return 1.8 end
    return 1.0
end

return chaserAI

local registry = {}

local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end

local TELEGRAPH_POOL = 32
local ATTACK_POOL = 64
local RESPAWN_POOL = 32

local telegraphPool = {}
local attackPool = {}
local respawnPool = {}

local activeTelegraphs = {}
local activeAttacks = {}
local activeRespawns = {}

for i = 1, TELEGRAPH_POOL do
    telegraphPool[i] = {active = false, gx = 0, gy = 0, timer = 0, maxTimer = 0, attackType = "default"}
end
for i = 1, ATTACK_POOL do
    attackPool[i] = {active = false, x = 0, y = 0, dx = 0, dy = 0, cx = 0, cy = 0, px = 0, py = 0, radius = 0, maxRadius = 0, speed = 0, lifetime = 0, maxLifetime = 0, damage = 0, type = "projectile", x1 = 0, y1 = 0, x2 = 0, y2 = 0}
end
for i = 1, RESPAWN_POOL do
    respawnPool[i] = {active = false, type = "chaser", respawnAt = 0, attempts = 0, side = 1}
end

local freeTelegraphs = {}
local freeAttacks = {}
local freeRespawns = {}

for i = 1, TELEGRAPH_POOL do freeTelegraphs[i] = telegraphPool[i] end
for i = 1, ATTACK_POOL do freeAttacks[i] = attackPool[i] end
for i = 1, RESPAWN_POOL do freeRespawns[i] = respawnPool[i] end

local function acquireFree(freeList)
    if #freeList == 0 then return nil end
    return table.remove(freeList)
end

local function releaseToFree(freeList, entry)
    entry.active = false
    table.insert(freeList, entry)
end

function registry.addTelegraph(gx, gy, timer, attackType)
    local e = acquireFree(freeTelegraphs)
    if not e then
        if Log and Log.warn then Log.warn("telegraph pool exhausted") end
        e = {active = false, gx = 0, gy = 0, timer = 0, maxTimer = 0, attackType = "default"}
    end
    e.active = true
    e.gx = gx
    e.gy = gy
    e.timer = timer or 0.8
    e.maxTimer = timer or 0.8
    e.attackType = attackType or "default"
    table.insert(activeTelegraphs, e)
    return e
end

function registry.getTelegraphs()
    return activeTelegraphs
end

function registry.getTelegraphPool()
    return telegraphPool
end

function registry.addProjectile(gx, gy, dx, dy, lifetime, damage)
    local e = acquireFree(freeAttacks)
    if not e then
        if Log and Log.warn then Log.warn("attack pool exhausted") end
        e = {active = false, x = 0, y = 0, dx = 0, dy = 0, cx = 0, cy = 0, px = 0, py = 0, radius = 0, maxRadius = 0, speed = 0, lifetime = 0, maxLifetime = 0, damage = 0, type = "projectile"}
    end
    e.active = true
    e.x = gx
    e.y = gy
    e.dx = dx
    e.dy = dy
    e.lifetime = lifetime or 3.0
    e.maxLifetime = lifetime or 3.0
    e.damage = damage or 1
    e.type = "projectile"
    e.cx = gx
    e.cy = gy
    table.insert(activeAttacks, e)
    return e
end

function registry.addRadialPulse(cx, cy, maxRadius, speed, damage, lifetime)
    local e = acquireFree(freeAttacks)
    if not e then
        if Log and Log.warn then Log.warn("attack pool exhausted") end
        e = {active = false, x = 0, y = 0, dx = 0, dy = 0, cx = 0, cy = 0, px = 0, py = 0, radius = 0, maxRadius = 0, speed = 0, lifetime = 0, maxLifetime = 0, damage = 0, type = "radial_pulse"}
    end
    local r = maxRadius or 8
    local s = speed or 3
    local lt = lifetime or (r / s)
    e.active = true
    e.cx = cx
    e.cy = cy
    e.px = cx
    e.py = cy
    e.radius = 0
    e.maxRadius = r
    e.speed = s
    e.lifetime = lt
    e.maxLifetime = lt
    e.damage = damage or 1
    e.type = "radial_pulse"
    table.insert(activeAttacks, e)
    return e
end

function registry.addLaser(x1, y1, x2, y2, lifetime, damage)
    local e = acquireFree(freeAttacks)
    if not e then
        if Log and Log.warn then Log.warn("attack pool exhausted") end
        e = {active = false, x = 0, y = 0, dx = 0, dy = 0, cx = 0, cy = 0, px = 0, py = 0, radius = 0, maxRadius = 0, speed = 0, lifetime = 0, maxLifetime = 0, damage = 0, type = "projectile", x1 = 0, y1 = 0, x2 = 0, y2 = 0}
    end
    e.active = true
    e.x1 = x1
    e.y1 = y1
    e.x2 = x2
    e.y2 = y2
    e.cx = (x1 + x2) / 2
    e.cy = (y1 + y2) / 2
    e.lifetime = lifetime or 4.0
    e.maxLifetime = lifetime or 4.0
    e.damage = damage or 1
    e.type = "laser"
    table.insert(activeAttacks, e)
    return e
end

function registry.getAttackObjects()
    return activeAttacks
end

function registry.getAttackPool()
    return attackPool
end

function registry.getPendingRespawns()
    return activeRespawns
end

function registry.getRespawnPool()
    return respawnPool
end

function registry.addPendingRespawn(entry)
    local e = acquireFree(freeRespawns)
    if not e then
        if Log and Log.warn then Log.warn("respawn pool exhausted") end
        e = {active = false, type = "chaser", respawnAt = 0, attempts = 0, side = 1}
    end
    e.active = true
    e.type = entry.type or "chaser"
    e.respawnAt = entry.respawnAt or 0
    e.attempts = entry.attempts or 0
    e.side = entry.side or 1
    table.insert(activeRespawns, e)
    return e
end

function registry.removePendingRespawn(idx)
    local e = activeRespawns[idx]
    if e then
        table.remove(activeRespawns, idx)
        releaseToFree(freeRespawns, e)
    end
end

function registry.clearAttackObjects()
    for i = #activeTelegraphs, 1, -1 do
        local e = activeTelegraphs[i]
        activeTelegraphs[i] = nil
        releaseToFree(freeTelegraphs, e)
    end
    for i = #activeAttacks, 1, -1 do
        local e = activeAttacks[i]
        activeAttacks[i] = nil
        releaseToFree(freeAttacks, e)
    end
end

function registry.clearPendingRespawns()
    for i = #activeRespawns, 1, -1 do
        local e = activeRespawns[i]
        activeRespawns[i] = nil
        releaseToFree(freeRespawns, e)
    end
end

function registry.clearAll()
    registry.clearAttackObjects()
    registry.clearPendingRespawns()
end

registry.clear = registry.clearAttackObjects

function registry.updateAttackObjects(dt, anchoGrilla, altoGrilla, isFrozen)
    if isFrozen then return end
    for i = #activeAttacks, 1, -1 do
        local ao = activeAttacks[i]
        local expired = false
        if ao.lifetime then
            ao.lifetime = ao.lifetime - dt
            if ao.lifetime <= 0 then expired = true end
        end
        if expired then
            table.remove(activeAttacks, i)
            releaseToFree(freeAttacks, ao)
        elseif ao.type == "projectile" then
            ao.x = ao.x + ao.dx * dt
            ao.y = ao.y + ao.dy * dt
            if ao.x < 0 or ao.x >= anchoGrilla or ao.y < 0 or ao.y >= altoGrilla then
                table.remove(activeAttacks, i)
                releaseToFree(freeAttacks, ao)
            end
        elseif ao.type == "radial_pulse" then
            ao.radius = ao.radius + ao.speed * dt
            if ao.radius >= ao.maxRadius then
                table.remove(activeAttacks, i)
                releaseToFree(freeAttacks, ao)
            end
        elseif ao.type == "laser" then
            -- Rayo estatico: solo decae por lifetime (manejado arriba)
        end
    end
end

function registry.updateTelegraphs(dt, isFrozen)
    if isFrozen then return end
    for i = #activeTelegraphs, 1, -1 do
        local t = activeTelegraphs[i]
        t.timer = t.timer - dt
        if t.timer <= 0 then
            table.remove(activeTelegraphs, i)
            releaseToFree(freeTelegraphs, t)
        end
    end
end

return registry

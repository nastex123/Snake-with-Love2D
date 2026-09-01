-- =============================================================================
-- MÓDULO: enemyAttackRegistry.lua
-- Parte de P01 — Split de entities/enemies.lua (634 → 4 módulos)
-- Gestiona telegraphs, attackObjects y pendingRespawns con API estable.
-- Extraído de entities/enemies.lua sin cambios de semántica.
-- =============================================================================
local registry = {}

local telegraphs = {}
local attackObjects = {}
local pendingRespawns = {}

-- ---------------------------------------------------------------------------
-- Telegraph API
-- ---------------------------------------------------------------------------
function registry.addTelegraph(gx, gy, timer, attackType)
    table.insert(telegraphs, {
        gx = gx, gy = gy,
        timer = timer or 0.8,
        maxTimer = timer or 0.8,
        attackType = attackType or "default"
    })
end

function registry.getTelegraphs()
    return telegraphs
end

-- ---------------------------------------------------------------------------
-- Projectile / Pulse API
-- ---------------------------------------------------------------------------
function registry.addProjectile(gx, gy, dx, dy, lifetime, damage)
    table.insert(attackObjects, {
        x = gx, y = gy,
        dx = dx, dy = dy,
        lifetime = lifetime or 3.0,
        maxLifetime = lifetime or 3.0,
        damage = damage or 1,
        type = "projectile"
    })
end

function registry.addRadialPulse(cx, cy, maxRadius, speed, damage, lifetime)
    local r = maxRadius or 8
    local s = speed or 3
    local lt = lifetime or (r / s)
    table.insert(attackObjects, {
        cx = cx, cy = cy, px = cx, py = cy,
        radius = 0, maxRadius = r, speed = s,
        lifetime = lt, maxLifetime = lt,
        damage = damage or 1, type = "radial_pulse"
    })
end

function registry.getAttackObjects()
    return attackObjects
end

-- ---------------------------------------------------------------------------
-- Pending respawns (boss timeout → chaser reaparece 5s después)
-- ---------------------------------------------------------------------------
function registry.getPendingRespawns()
    return pendingRespawns
end

function registry.addPendingRespawn(entry)
    table.insert(pendingRespawns, entry)
end

function registry.removePendingRespawn(idx)
    table.remove(pendingRespawns, idx)
end

-- ---------------------------------------------------------------------------
-- Clear
-- ---------------------------------------------------------------------------
function registry.clearAttackObjects()
    telegraphs = {}
    attackObjects = {}
end

function registry.clearPendingRespawns()
    pendingRespawns = {}
end

function registry.clearAll()
    telegraphs = {}
    attackObjects = {}
    pendingRespawns = {}
end

-- Mantiene compatibilidad con enemies.clearAttackObjects() que solo limpia telegraphs/attackObjects
registry.clear = registry.clearAttackObjects

-- ---------------------------------------------------------------------------
-- Updates — llamados desde enemies.update(dt, ...) con isFrozen
-- ---------------------------------------------------------------------------
function registry.updateAttackObjects(dt, anchoGrilla, altoGrilla, isFrozen)
    if isFrozen then return end
    for i = #attackObjects, 1, -1 do
        local ao = attackObjects[i]
        local expired = false
        if ao.lifetime then
            ao.lifetime = ao.lifetime - dt
            if ao.lifetime <= 0 then expired = true end
        end
        if expired then
            table.remove(attackObjects, i)
        elseif ao.type == "projectile" then
            ao.x = ao.x + ao.dx * dt
            ao.y = ao.y + ao.dy * dt
            if ao.x < 0 or ao.x >= anchoGrilla or ao.y < 0 or ao.y >= altoGrilla then
                table.remove(attackObjects, i)
            end
        elseif ao.type == "radial_pulse" then
            ao.radius = ao.radius + ao.speed * dt
            if ao.radius >= ao.maxRadius then
                table.remove(attackObjects, i)
            end
        end
    end
end

function registry.updateTelegraphs(dt, isFrozen)
    if isFrozen then return end
    for i = #telegraphs, 1, -1 do
        local t = telegraphs[i]
        t.timer = t.timer - dt
        if t.timer <= 0 then
            table.remove(telegraphs, i)
        end
    end
end

-- Pending respawns: delega la lógica de reintento a spawnLogic/bossLogic a través de callback
-- Aquí solo expone el tick para que el facade itere y use spawnLogic.canSpawn + spawnAt.
-- Para mantener compatibilidad, no se implementa updatePendingRespawns aquí; lo hace enemies.lua.

return registry

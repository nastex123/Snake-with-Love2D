-- =============================================================================
-- MÓDULO DE ENEMIGOS — Fachada (P01)
-- Sistema de enemigos: chasers, patrollers, spawners y boss.
-- P01 Split 634→ ~210L facade + 3 submódulos:
--   entities/enemyAttackRegistry.lua (telegraphs/attackObjects/pendingRespawns)
--   entities/enemyBossLogic.lua      (spawnBoss/hitBoss/onBossDefeated + máquina de estados)
--   entities/enemySpawnLogic.lua     (canSpawn/spawnAt/generar)
-- Mantiene API pública idéntica para compatibilidad con snake.lua, gamestates.lua, tests.
-- =============================================================================
local enemies = {}
local constants = require("constants")
local enemyHelpers = require("entities.enemyHelpers")
local chaserAI = require("entities.chaserAI")
local patrollerAI = require("entities.patrollerAI")
local enemiesDraw = require("render.enemiesDraw")
local attackRegistry = require("entities.enemyAttackRegistry")
local bossLogic = require("entities.enemyBossLogic")
local spawnLogic = require("entities.enemySpawnLogic")
local world = require("core.world")

-- P04: World.state.enemies como fuente de verdad (enemies.list / enemies.boss)
-- Inicializa World.state.enemies si no existe; no crear raw fields en enemies para mantener proxy activo tras World.reset
if not world.state.enemies then
    world.state.enemies = { list = {}, boss = nil }
else
    world.state.enemies.list = world.state.enemies.list or {}
end

do
    local proxyKeys = { list = true, boss = true }
    local mt = {
        __index = function(t, k)
            if proxyKeys[k] then
                if world.state.enemies then
                    return world.state.enemies[k]
                end
                return nil
            end
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if proxyKeys[k] then
                if not world.state.enemies then
                    world.state.enemies = { list = {}, boss = nil }
                end
                world.state.enemies[k] = v
                -- No rawset para proxied keys: evita desincronización tras World.reset
                world.set("enemies." .. k, v)
            else
                rawset(t, k, v)
            end
        end
    }
    setmetatable(enemies, mt)
end

-- ============================================================
-- Telegraph / attack object API — delega a attackRegistry
-- ============================================================
function enemies.addTelegraph(gx, gy, timer, attackType)
    return attackRegistry.addTelegraph(gx, gy, timer, attackType)
end

function enemies.addProjectile(gx, gy, dx, dy, lifetime, damage)
    return attackRegistry.addProjectile(gx, gy, dx, dy, lifetime, damage)
end

function enemies.addRadialPulse(cx, cy, maxRadius, speed, damage, lifetime)
    return attackRegistry.addRadialPulse(cx, cy, maxRadius, speed, damage, lifetime)
end

function enemies.addLaser(x1, y1, x2, y2, lifetime, damage)
    return attackRegistry.addLaser(x1, y1, x2, y2, lifetime, damage)
end

function enemies.getAttackObjects()
    return attackRegistry.getAttackObjects()
end

function enemies.getTelegraphs()
    return attackRegistry.getTelegraphs()
end

function enemies.getPendingRespawns()
    return attackRegistry.getPendingRespawns()
end

function enemies.clearAttackObjects()
    return attackRegistry.clearAttackObjects()
end

-- ============================================================
-- Spawn helpers — delega a spawnLogic
-- ============================================================
function enemies.canSpawn(type)
    return spawnLogic.canSpawn(enemies.boss, enemies.list, type)
end

function enemies.init()
    enemies.list = {}
    enemies.boss = nil
    attackRegistry.clearAll()
    chaserAI.reset()
end

enemies.limpiar = enemies.init
enemies.clear = enemies.init

function enemies.spawnAt(type, gx, gy, params)
    return spawnLogic.spawnAt(enemies.list, type, gx, gy, params)
end

function enemies.generar(snake, foodPos, obstacles, anchoGrilla, altoGrilla, stageModifier)
    return spawnLogic.generar(enemies.list, enemies.boss, snake, foodPos, obstacles, anchoGrilla, altoGrilla, stageModifier)
end

-- ============================================================
-- Boss — delega a bossLogic
-- ============================================================
function enemies.spawnBoss(etapa, anchoGrilla, altoGrilla, bossVida, dropCoins)
    return bossLogic.spawnBoss(enemies, etapa, anchoGrilla, altoGrilla, bossVida, dropCoins, attackRegistry)
end

function enemies.hitBoss()
    return bossLogic.hitBoss(enemies, attackRegistry)
end

function enemies.onBossDefeatedByFood()
    return bossLogic.onBossDefeatedByFood(enemies, attackRegistry)
end

-- ============================================================
-- Combat helpers — permanecen en fachada (sin estado externo)
-- ============================================================
function enemies.applyTailSnap(gx, gy, pushDist, stunDuration, anchoGrilla, altoGrilla, obstaclePos)
    local tam = constants.TAMANIO_BLOQUE
    local affected = {}
    stunDuration = stunDuration or constants.TAIL_SNAP_STUN_DURATION or 0.8
    anchoGrilla = anchoGrilla or constants.MAX_GRID_COLS
    altoGrilla = altoGrilla or constants.MAX_GRID_ROWS
    for _, e in ipairs(enemies.list) do
        if e.alive then
            local dist = math.max(math.abs(e.x - gx), math.abs(e.y - gy))
            if dist <= 2 then
                e.stunTimer = stunDuration
                local dx = e.x - gx
                local dy = e.y - gy
                if dx ~= 0 then dx = dx > 0 and 1 or -1 end
                if dy ~= 0 then dy = dy > 0 and 1 or -1 end
                if dx == 0 and dy == 0 then dx = 1 end
                local nx = e.x + dx
                local ny = e.y + dy
                if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                    local blocked = false
                    if obstaclePos then
                        local obs = obstaclePos.pos or obstaclePos
                        for _, obsItem in ipairs(obs) do
                            if obsItem.x == nx and obsItem.y == ny then blocked = true; break end
                        end
                    end
                    if not blocked then
                        e.x = nx
                        e.y = ny
                    end
                end
                table.insert(affected, {x = e.x, y = e.y, px = e.x * tam + tam/2, py = e.y * tam + tam/2})
            end
        end
    end
    return affected
end

function enemies.checkFireTrail(fireTrail)
    if not fireTrail or #fireTrail == 0 then return nil end
    local killed = {}
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]
        if e.alive and (e.type == "chaser" or e.type == "patroller" or e.type == "spawner") then
            for _, ft in ipairs(fireTrail) do
                if ft.x == e.x and ft.y == e.y then
                    local res = enemies.killEnemy(i)
                    if res then table.insert(killed, res) end
                    break
                end
            end
        end
    end
    return #killed > 0 and killed or nil
end

-- ============================================================
-- Update — orquesta chaserAI, patrollerAI, spawners, bossLogic y attackRegistry
-- ============================================================
function enemies.update(dt, snakeBody, anchoGrilla, altoGrilla, obstaclesMod, etapa, stageModifier, snakeDecoys)
    snakeBody = snakeBody or {}
    anchoGrilla = anchoGrilla or constants.MAX_GRID_COLS or 32
    altoGrilla = altoGrilla or constants.MAX_GRID_ROWS or 18
    local now = love.timer.getTime()
    local world = require("core.world")
    local freezeTimer = world.get("enemyFreezeTimer") or 0
    local isFrozen = freezeTimer > 0

    local targetHead = snakeBody[1]
    if snakeDecoys and #snakeDecoys > 0 then
        targetHead = {x = snakeDecoys[1].x, y = snakeDecoys[1].y}
    end

    local worldFacade = package.loaded["world.world"]
    local currRoom = worldFacade and worldFacade.getCurrentRoom and worldFacade.getCurrentRoom()
    local roomType = currRoom and currRoom.type or "corridor"

    local ctx = {
        list = enemies.list,
        enemiesList = enemies.list,
        body = snakeBody or {},
        snake = { body = snakeBody or {} },
        head = targetHead,
        anchoGrilla = anchoGrilla,
        altoGrilla = altoGrilla,
        obstacles = obstaclesMod,
        obstaclePos = obstaclesMod and (obstaclesMod.pos or obstaclesMod) or {},
        boss = enemies.boss,
        roomType = roomType,
        etapa = (type(etapa) == "number") and etapa or 1,
        stageModifier = stageModifier or {},
        dt = dt,
    }
    if not isFrozen then
        chaserAI.updatePack(ctx, dt)
    end

    -- Enemigos regulares
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]
        if e.stunTimer and e.stunTimer > 0 then
            e.stunTimer = math.max(0, e.stunTimer - dt)
        end

        if enemies.boss and enemies.boss.alive and e.alive then
            local age = now - (e.spawnTime or now)
            if age >= constants.BOSS_ENEMY_LIFETIME then
                if e.type == "chaser" then
                    attackRegistry.addPendingRespawn({
                        type = "chaser",
                        respawnAt = now + constants.BOSS_RESPAWN_DELAY,
                        attempts = constants.BOSS_RESPAWN_RETRY,
                        side = (e.side and -e.side) or (love.math.random() < 0.5 and 1 or -1),
                    })
                end
                e.alive = false
            end
        end

        if not e.alive then
            table.remove(enemies.list, i)
        elseif not isFrozen and (not e.stunTimer or e.stunTimer <= 0) then
            e.moveTimer = e.moveTimer + dt
            if e.type == "chaser" then
                if e.moveTimer >= e.moveInterval * chaserAI.speedFactor(e) then
                    e.moveTimer = 0
                    chaserAI.step(e, ctx)
                end
            elseif e.type == "patroller" then
                patrollerAI.step(e, ctx)
            elseif e.type == "spawner" then
                local spawnerInterval = constants.ENEMY_SPAWNER_INTERVAL
                if enemies.boss and enemies.boss.alive then spawnerInterval = spawnerInterval * 1.5 end
                e.spawnTimer = e.spawnTimer + dt
                if e.spawnTimer >= spawnerInterval then
                    e.spawnTimer = 0
                    local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
                    for _, d in ipairs(dirs) do
                        local nx = e.x + d[1]
                        local ny = e.y + d[2]
                        if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                            local occupied = false
                            for _, s in ipairs(snakeBody or {}) do if s.x == nx and s.y == ny then occupied = true; break end end
                            if not occupied and obstaclesMod then
                                local obs = obstaclesMod.pos or obstaclesMod
                                for _, o in ipairs(obs) do if o.x == nx and o.y == ny then occupied = true; break end end
                            end
                            if not occupied then
                                for _, oe in ipairs(enemies.list) do if oe.alive and oe.x == nx and oe.y == ny then occupied = true; break end end
                                if enemies.boss and enemies.boss.alive and enemies.boss.x == nx and enemies.boss.y == ny then occupied = true end
                            end
                            if not occupied and obstaclesMod and obstaclesMod.agregar then
                                obstaclesMod.agregar(nx, ny)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Boss — delega máquina de estados
    if enemies.boss and enemies.boss.alive and not isFrozen then
        local bossCtx = {
            snakeHead = targetHead,
            head = targetHead,
            anchoGrilla = anchoGrilla,
            altoGrilla = altoGrilla,
            canSpawn = function(t) return enemies.canSpawn(t) end,
            enemies = enemies,
            speedMult = 1.0,
        }
        bossLogic.updateBoss(dt, enemies.boss, bossCtx, attackRegistry, enemies)
    end

    if enemies.boss and enemies.boss.alive then
        bossLogic.updateBarLerp(enemies.boss, dt)
    end

    -- Pending respawns (chasers)
    local pending = attackRegistry.getPendingRespawns()
    local nowRespawn = love.timer.getTime()
    for i = #pending, 1, -1 do
        local p = pending[i]
        if p.respawnAt <= nowRespawn then
            if not enemies.canSpawn("chaser") then
                p.respawnAt = nowRespawn + 0.25
            else
                local gx, gy = enemyHelpers.sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, enemies.list, 6, p.attempts)
                if gx then
                    local speedMult = (stageModifier and stageModifier.enemySpeed) or 1.0
                    local etapaVal = (type(etapa) == "number") and etapa or 1
                    local chaserInterval = math.max(0.15, (constants.ENEMY_CHASER_SPEED / speedMult) * (0.90 ^ (math.max(1, etapaVal) - 1)))
                    local spawned = enemies.spawnAt("chaser", gx, gy, { moveInterval = chaserInterval })
                    if spawned and p.side then
                        spawned.side = p.side
                        spawned.aiState = "flank"
                        spawned.role = "flanker"
                    end
                    attackRegistry.removePendingRespawn(i)
                else
                    p.attempts = p.attempts - 5
                    if p.attempts <= 0 then
                        attackRegistry.removePendingRespawn(i)
                    else
                        p.respawnAt = nowRespawn + 0.5
                    end
                end
            end
        end
    end

    -- Attack objects y telegraphs — delega a registry
    attackRegistry.updateAttackObjects(dt, anchoGrilla, altoGrilla, isFrozen)
    attackRegistry.updateTelegraphs(dt, isFrozen)
end

-- ============================================================
-- Kill / Draw — permanecen en fachada
-- ============================================================
function enemies.killEnemy(target)
    local e
    if type(target) == "number" then
        e = enemies.list[target]
    elseif type(target) == "table" then
        e = target
    end
    if not e or not e.alive then return nil end
    local tam = constants.TAMANIO_BLOQUE
    local result = {
        px = e.x * tam + tam / 2,
        py = e.y * tam + tam / 2,
        gx = e.x, gy = e.y,
        coins = e.dropCoins or 0, type = e.type
    }
    e.alive = false
    return result
end

function enemies.draw(snakeHead)
    enemiesDraw.draw(enemies.list, enemies.boss, attackRegistry.getTelegraphs(), attackRegistry.getAttackObjects(), snakeHead)
end

return enemies

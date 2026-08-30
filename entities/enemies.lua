-- =============================================================================
-- MÓDULO DE ENEMIGOS
-- Sistema de enemigos: chasers, patrollers, spawners y boss.
-- La lógica de ataques del boss vive en entities/bossAttacks.lua,
-- los helpers de posicionamiento en entities/enemyHelpers.lua y
-- el dibujo en render/enemiesDraw.lua.
-- =============================================================================
local enemies = {}
local constants = require("constants")
local bossAttacks = require("entities.bossAttacks")
local enemyHelpers = require("entities.enemyHelpers")
local chaserAI = require("entities.chaserAI")
local patrollerAI = require("entities.patrollerAI")
local enemiesDraw = require("render.enemiesDraw")

local telegraphs = {}
local attackObjects = {}
local pendingRespawns = {}

enemies.list = {}
enemies.boss = nil

-- ============================================================
--  Telegraph / attack object API
-- ============================================================

function enemies.addTelegraph(gx, gy, timer, attackType)
    table.insert(telegraphs, {gx=gx, gy=gy, timer=timer or 0.8, maxTimer=timer or 0.8, attackType=attackType or "default"})
end

function enemies.addProjectile(gx, gy, dx, dy, lifetime, damage)
    table.insert(attackObjects, {x=gx, y=gy, dx=dx, dy=dy, lifetime=lifetime or 3.0, maxLifetime=lifetime or 3.0, damage=damage or 1, type="projectile"})
end

function enemies.addRadialPulse(cx, cy, maxRadius, speed, damage, lifetime)
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

function enemies.getAttackObjects()
    return attackObjects
end

function enemies.getTelegraphs()
    return telegraphs
end

function enemies.getPendingRespawns()
    return pendingRespawns
end

function enemies.clearAttackObjects()
    telegraphs = {}
    attackObjects = {}
end

-- ============================================================
--  Standard helpers
-- ============================================================

function enemies.canSpawn(type)
    if not enemies.boss or not enemies.boss.alive then return true end
    local counts = enemyHelpers.countEnemiesByType(enemies.list)
    if type == "chaser" and (counts.chaser or 0) >= constants.BOSS_MAX_RED then return false end
    if type == "patroller" and (counts.patroller or 0) >= constants.BOSS_MAX_BLUE then return false end
    return true
end

-- ============================================================
--  Init
-- ============================================================

function enemies.init()
    enemies.list = {}
    enemies.boss = nil
    telegraphs = {}
    attackObjects = {}
    pendingRespawns = {}
    chaserAI.reset()
end

enemies.limpiar = enemies.init
enemies.clear = enemies.init

-- ============================================================
--  Spawn API
-- ============================================================

function enemies.spawnAt(type, gx, gy, params)
    params = params or {}
    local e = {
        x = gx, y = gy, type = type, alive = true,
        dirX = 0, dirY = 0, moveTimer = 0, spawnTimer = 0,
        spawnTime = love.timer.getTime(),
        dropCoins = params.dropCoins
            or (type == "chaser" and constants.ENEMY_DROP_CHASER)
            or (type == "patroller" and constants.ENEMY_DROP_PATROLLER)
            or constants.ENEMY_DROP_SPAWNER
    }
    if type == "chaser" then
        e.moveInterval = params.moveInterval or constants.ENEMY_CHASER_SPEED
        -- Estado de IA social + animación visual (Estrella de espinas)
        e.aiState = "idle"
        e.role = "hunter"
        e.side = love.math.random() < 0.5 and 1 or -1
        e.seed = love.math.random() * math.pi * 2
        e.visRot = love.math.random() * math.pi * 2
        e.moveAng = e.visRot
        e.ringIndex = 0
        e.ringSize = 1
        e.ringTighten = false
        e.wanderWait = love.math.random(2, 5)
    elseif type == "patroller" then
        e.moveInterval = params.moveInterval or constants.ENEMY_PATROLLER_SPEED
        if params.dirX and params.dirY then
            e.dirX, e.dirY = params.dirX, params.dirY
        else
            local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
            local d = dirs[love.math.random(1, 4)]
            e.dirX, e.dirY = d[1], d[2]
        end
        e.visRot = math.atan2(e.dirY, e.dirX)
        patrollerAI.init(e, params.roomType, params.anchoGrilla, params.altoGrilla)
    else
        e.moveInterval = 999
    end
    table.insert(enemies.list, e)
    return e
end

function enemies.generar(snake, foodPos, obstacles, anchoGrilla, altoGrilla, stageModifier)
    local mod = stageModifier or {}
    local cw = mod.chaserWeight or 0.40
    local pw = mod.patrollerWeight or 0.35
    local sw = mod.spawnerWeight or 0.25
    local speedMult = mod.enemySpeed or 1.0

    local r = love.math.random()
    local eType
    if r < cw then
        eType = "chaser"
    elseif r < cw + pw then
        eType = "patroller"
    else
        eType = "spawner"
    end

    if not enemies.canSpawn(eType) then
        if eType == "chaser" and enemies.canSpawn("patroller") then
            eType = "patroller"
        elseif eType == "patroller" and enemies.canSpawn("chaser") then
            eType = "chaser"
        elseif not enemies.canSpawn("chaser") and not enemies.canSpawn("patroller") then
            eType = "spawner"
        end
    end
    if not enemies.canSpawn(eType) then return end

    local x, y
    local attempts = 0
    repeat
        x = love.math.random(0, anchoGrilla - 1)
        y = love.math.random(0, altoGrilla - 1)
        attempts = attempts + 1
    until (enemyHelpers.validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla, enemies.list) or attempts > 100)
    if attempts > 100 then return end

    local etapa = (mod and mod.stage) or 1
    local chaserInterval = math.max(0.15, (constants.ENEMY_CHASER_SPEED / speedMult) * (0.90 ^ (math.max(1, etapa) - 1)))

    return enemies.spawnAt(eType, x, y, {
        moveInterval = (eType == "chaser" and chaserInterval)
            or (eType == "patroller" and constants.ENEMY_PATROLLER_SPEED / speedMult)
            or nil
    })
end

-- ============================================================
--  Boss spawning
-- ============================================================

function enemies.spawnBoss(etapa, anchoGrilla, altoGrilla, bossVida, dropCoins)
    local cx = math.floor(anchoGrilla / 2)
    local cy = math.floor(altoGrilla / 2)
    enemies.boss = {
        x = cx, y = cy,
        vida = bossVida,
        vidaMax = bossVida,
        bossType = "teleporter",
        alive = true,
        moveTimer = 0,
        spawnTimer = 0,
        dropCoins = dropCoins or 5,
        phase = 1,
        state = "idle",
        stateTimer = 0,
        attackCooldown = 2.0,
        currentAttack = nil,
        telegraphPositions = {},
        foodCollected = 0,
        foodTarget = constants.BOSS_FOOD_TARGET,
        invulnerable = true,
        enraged = false,
        _uiBarFill = 1.0,
        _uiBarTarget = 1.0,
    }
    telegraphs = {}
    attackObjects = {}
    pendingRespawns = {}
    return enemies.boss
end

-- ============================================================
--  Boss hit
-- ============================================================

function enemies.hitBoss()
    if not enemies.boss or not enemies.boss.alive then return nil end
    if enemies.boss.invulnerable then
        return {hit = true, vida = enemies.boss.vida, vidaMax = enemies.boss.vidaMax}
    end
    enemies.boss.vida = enemies.boss.vida - 1
    if enemies.boss.vida <= 0 then
        enemies.boss.alive = false
        telegraphs = {}
        attackObjects = {}
        pendingRespawns = {}
        local tam = constants.TAMANIO_BLOQUE
        return {
            px = enemies.boss.x * tam + tam / 2,
            py = enemies.boss.y * tam + tam / 2,
            gx = enemies.boss.x, gy = enemies.boss.y,
            coins = enemies.boss.dropCoins,
            type = "boss"
        }
    end
    return {hit = true, vida = enemies.boss.vida, vidaMax = enemies.boss.vidaMax}
end

function enemies.onBossDefeatedByFood()
    if not enemies.boss or not enemies.boss.alive then return nil end
    enemies.boss.alive = false
    enemies.boss.invulnerable = false
    telegraphs = {}
    attackObjects = {}
    pendingRespawns = {}
    local tam = constants.TAMANIO_BLOQUE
    return {
        px = enemies.boss.x * tam + tam / 2,
        py = enemies.boss.y * tam + tam / 2,
        gx = enemies.boss.x, gy = enemies.boss.y,
        coins = enemies.boss.dropCoins,
        type = "boss"
    }
end

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
                    if res then
                        table.insert(killed, res)
                    end
                    break
                end
            end
        end
    end
    return #killed > 0 and killed or nil
end

-- ============================================================
--  Update
-- ============================================================

function enemies.update(dt, snakeBody, anchoGrilla, altoGrilla, obstaclesMod, etapa, stageModifier, snakeDecoys)
    snakeBody = snakeBody or {}
    anchoGrilla = anchoGrilla or constants.MAX_GRID_COLS or 32
    altoGrilla = altoGrilla or constants.MAX_GRID_ROWS or 18
    local now = love.timer.getTime()
    local world = require("core.world")
    local freezeTimer = world.get("enemyFreezeTimer") or 0
    local isFrozen = freezeTimer > 0

    -- Target selection: decoy prioritario sobre cabeza si existe
    local targetHead = snakeBody[1]
    if snakeDecoys and #snakeDecoys > 0 then
        targetHead = {x = snakeDecoys[1].x, y = snakeDecoys[1].y}
    end

    -- IA social de chasers: clasificacion del pack, roles y ciclo de cierre
    local ctx = {
        list = enemies.list,
        body = snakeBody or {},
        head = targetHead,
        anchoGrilla = anchoGrilla,
        altoGrilla = altoGrilla,
        obstaclePos = obstaclesMod and (obstaclesMod.pos or obstaclesMod) or {},
        etapa = (type(etapa) == "number") and etapa or 1,
        stageModifier = stageModifier or {},
    }
    if not isFrozen then
        chaserAI.updatePack(ctx, dt)
    end

    -- Update regular enemies
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]

        if e.stunTimer and e.stunTimer > 0 then
            e.stunTimer = math.max(0, e.stunTimer - dt)
        end

        -- Boss timeout: reds get queued for respawn with alternating flank side, blues vanish
        if enemies.boss and enemies.boss.alive and e.alive then
            local age = now - (e.spawnTime or now)
            if age >= constants.BOSS_ENEMY_LIFETIME then
                if e.type == "chaser" then
                    table.insert(pendingRespawns, {
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
                if enemies.boss and enemies.boss.alive then
                    spawnerInterval = spawnerInterval * 1.5
                end
                e.spawnTimer = e.spawnTimer + dt
                if e.spawnTimer >= spawnerInterval then
                    e.spawnTimer = 0
                    local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
                    for _, d in ipairs(dirs) do
                        local nx = e.x + d[1]
                        local ny = e.y + d[2]
                        if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                            local occupied = false
                            for _, s in ipairs(snakeBody or {}) do
                                if s.x == nx and s.y == ny then occupied = true; break end
                            end
                            if not occupied and obstaclesMod then
                                local obs = obstaclesMod.pos or obstaclesMod
                                for _, o in ipairs(obs) do
                                    if o.x == nx and o.y == ny then occupied = true; break end
                                end
                            end
                            if not occupied then
                                for _, oe in ipairs(enemies.list) do
                                    if oe.alive and oe.x == nx and oe.y == ny then occupied = true; break end
                                end
                                if enemies.boss and enemies.boss.alive and enemies.boss.x == nx and enemies.boss.y == ny then
                                    occupied = true
                                end
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

    -- Boss state machine
    if enemies.boss and enemies.boss.alive and not isFrozen then
        local boss = enemies.boss

        -- Update phase based on HP or Food progress
        local vidaFrac
        if boss.foodTarget and boss.foodTarget > 0 then
            vidaFrac = math.max(0, 1 - (boss.foodCollected or 0) / boss.foodTarget)
        else
            vidaFrac = (boss.vidaMax and boss.vidaMax > 0) and (boss.vida / boss.vidaMax) or 1.0
        end

        if vidaFrac <= 0.30 then
            boss.phase = 3
        elseif vidaFrac <= 0.60 then
            boss.phase = 2
        else
            boss.phase = 1
        end

        if boss.foodTarget and (boss.foodCollected or 0) >= (boss.foodTarget - 3) then
            boss.enraged = true
        else
            boss.enraged = false
        end

        local speedMult = 1.0 + (boss.phase - 1) * 0.2
        if boss.enraged then
            speedMult = speedMult * 1.35
        end

        local ctx = {
            snakeHead = targetHead,
            anchoGrilla = anchoGrilla,
            altoGrilla = altoGrilla,
            canSpawn = enemies.canSpawn,
            enemies = enemies,
            speedMult = speedMult,
        }

        if boss.state == "idle" then
            boss.attackCooldown = boss.attackCooldown - dt
            if boss.attackCooldown <= 0 then
                local attacks = bossAttacks.getAvailable(boss.phase)
                if #attacks > 0 then
                    local chosen = attacks[love.math.random(1, #attacks)]
                    boss.currentAttack = chosen
                    boss.telegraphPositions = bossAttacks.computePositions(boss, chosen, ctx)
                    -- Add telegraph markers
                    for _, pos in ipairs(boss.telegraphPositions) do
                        enemies.addTelegraph(pos.x, pos.y, chosen.telegraphTime, chosen.name)
                    end
                    boss.state = "telegraph"
                    boss.stateTimer = chosen.telegraphTime
                end
            end

        elseif boss.state == "telegraph" then
            boss.stateTimer = boss.stateTimer - dt
            if boss.stateTimer <= 0 then
                bossAttacks.execute(boss, boss.currentAttack.name, dt, ctx)
                telegraphs = {}
                boss.state = "cooldown"
                local cd = boss.currentAttack.cooldown * (boss.phase == 3 and 0.7 or 1.0)
                if boss.enraged then cd = cd / 1.35 end
                boss.stateTimer = cd
            end

        elseif boss.state == "cooldown" then
            boss.stateTimer = boss.stateTimer - dt
            if boss.stateTimer <= 0 then
                boss.state = "idle"
                boss.attackCooldown = 1.0
            end
        end
    end

    -- Lerp boss UI bar smooth animation
    if enemies.boss and enemies.boss.alive then
        local lerpSpeed = constants.BOSS_HEALTH_BAR.lerpSpeed or 6.0
        enemies.boss._uiBarFill = enemies.boss._uiBarFill + (enemies.boss._uiBarTarget - enemies.boss._uiBarFill) * math.min(1, dt * lerpSpeed)
    end

    -- Process pending respawns (chasers delayed after boss death timeout)
    local nowRespawn = love.timer.getTime()
    for i = #pendingRespawns, 1, -1 do
        local p = pendingRespawns[i]
        if p.respawnAt <= nowRespawn then
            if not enemies.canSpawn("chaser") then
                p.respawnAt = nowRespawn + 0.25
            elseif enemies.canSpawn("chaser") then
                local gx, gy = enemyHelpers.sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, enemies.list, 6, p.attempts)
                if gx then
                    local speedMult = (stageModifier and stageModifier.enemySpeed) or 1.0
                    local etapaVal = (type(etapa) == "number") and etapa or 1
                    local chaserInterval = math.max(0.15, (constants.ENEMY_CHASER_SPEED / speedMult) * (0.90 ^ (math.max(1, etapaVal) - 1)))
                    local spawned = enemies.spawnAt("chaser", gx, gy, {
                        moveInterval = chaserInterval,
                    })
                    if spawned and p.side then
                        spawned.side = p.side
                        spawned.aiState = "flank"
                        spawned.role = "flanker"
                    end
                    table.remove(pendingRespawns, i)
                else
                    p.attempts = p.attempts - 5
                    if p.attempts <= 0 then
                        table.remove(pendingRespawns, i)
                    else
                        p.respawnAt = nowRespawn + 0.5
                    end
                end
            end
        end
    end

    -- Update attack objects (frozen during enemyFreeze)
    if isFrozen then
        -- skip attack/telegraph ticks while frozen
    else
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
            -- Remove if out of bounds
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

    -- Update telegraph timers
    for i = #telegraphs, 1, -1 do
        local t = telegraphs[i]
        t.timer = t.timer - dt
        if t.timer <= 0 then
            table.remove(telegraphs, i)
        end
    end
    end
end

-- ============================================================
--  Kill enemy
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

-- ============================================================
--  Draw
-- ============================================================

function enemies.draw(snakeHead)
    enemiesDraw.draw(enemies.list, enemies.boss, telegraphs, attackObjects, snakeHead)
end

return enemies
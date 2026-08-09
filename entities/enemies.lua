-- =============================================================================
-- MÃ“DULO DE ENEMIGOS
-- Sistema de enemigos: chasers, patrollers, spawners y boss.
-- La lógica de ataques del boss vive en entities/bossAttacks.lua,
-- los helpers de posicionamiento en entities/enemyHelpers.lua y
-- el dibujo en render/enemiesDraw.lua.
-- =============================================================================
local enemies = {}
local constants = require("constants")
local bossAttacks = require("entities.bossAttacks")
local enemyHelpers = require("entities.enemyHelpers")
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

function enemies.addRadialPulse(cx, cy, maxRadius, speed, damage)
    table.insert(attackObjects, {cx=cx, cy=cy, px=cx, py=cy, radius=0, maxRadius=maxRadius or 8, speed=speed or 3, damage=damage or 1, type="radial_pulse"})
end

function enemies.getAttackObjects()
    return attackObjects
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
end

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
    elseif type == "patroller" then
        e.moveInterval = params.moveInterval or constants.ENEMY_PATROLLER_SPEED
        local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
        local d = dirs[love.math.random(1, 4)]
        e.dirX, e.dirY = d[1], d[2]
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

    local x, y
    local attempts = 0
    repeat
        x = love.math.random(0, anchoGrilla - 1)
        y = love.math.random(0, altoGrilla - 1)
        attempts = attempts + 1
    until (enemyHelpers.validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla, enemies.list) or attempts > 100)
    if attempts > 100 then return end

    enemies.spawnAt(eType, x, y, {
        moveInterval = (eType == "chaser" and constants.ENEMY_CHASER_SPEED / speedMult)
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
        _uiBarFill = 1.0,
        _uiBarTarget = 1.0,
    }
    telegraphs = {}
    attackObjects = {}
    pendingRespawns = {}
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

-- ============================================================
--  Update
-- ============================================================

function enemies.update(dt, snakeBody, anchoGrilla, altoGrilla, obstaclesMod)
    -- Update regular enemies
    local now = love.timer.getTime()
    for i = #enemies.list, 1, -1 do
        local e = enemies.list[i]

        -- Boss timeout: reds get queued for respawn, blues vanish
        if enemies.boss and enemies.boss.alive and e.alive then
            local age = now - (e.spawnTime or now)
            if age >= constants.BOSS_ENEMY_LIFETIME then
                if e.type == "chaser" then
                    table.insert(pendingRespawns, {
                        type = "chaser",
                        respawnAt = now + constants.BOSS_RESPAWN_DELAY,
                        attempts = constants.BOSS_RESPAWN_RETRY,
                    })
                end
                e.alive = false
            end
        end

        if not e.alive then
            table.remove(enemies.list, i)
        else
            e.moveTimer = e.moveTimer + dt

            if e.type == "chaser" then
                if e.moveTimer >= e.moveInterval then
                    e.moveTimer = 0
                    if not snakeBody[1] then break end
                    local hx, hy = snakeBody[1].x, snakeBody[1].y
                    local bestDir = nil
                    local bestDist = 9999
                    local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
                    for _, d in ipairs(dirs) do
                        local nx = e.x + d[1]
                        local ny = e.y + d[2]
                        if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                            local occupied = false
                            for _, oe in ipairs(enemies.list) do
                                if oe ~= e and oe.alive and oe.x == nx and oe.y == ny then
                                    occupied = true; break
                                end
                            end
                            if not occupied then
                                local dist = math.abs(nx - hx) + math.abs(ny - hy)
                                if dist < bestDist then
                                    bestDist = dist
                                    bestDir = d
                                end
                            end
                        end
                    end
                    if bestDir then
                        e.x = e.x + bestDir[1]
                        e.y = e.y + bestDir[2]
                    end
                end

            elseif e.type == "patroller" then
                if e.moveTimer >= e.moveInterval then
                    e.moveTimer = 0
                    local nx = e.x + e.dirX
                    local ny = e.y + e.dirY

                    if nx < 0 or nx >= anchoGrilla then
                        e.dirX = -e.dirX
                        nx = e.x + e.dirX
                    end
                    if ny < 0 or ny >= altoGrilla then
                        e.dirY = -e.dirY
                        ny = e.y + e.dirY
                    end

                    local blocked = false
                    for _, s in ipairs(snakeBody) do
                        if s.x == nx and s.y == ny then blocked = true; break end
                    end
                    if not blocked then
                        e.x = nx
                        e.y = ny
                    end
                    if ny < 0 or ny >= altoGrilla then
                        e.dirY = -e.dirY
                        ny = e.y + e.dirY
                    end

                    local occupied = false
                    for _, oe in ipairs(enemies.list) do
                        if oe ~= e and oe.alive and oe.x == nx and oe.y == ny then
                            occupied = true; break
                        end
                    end
                    if not occupied then
                        e.x = nx
                        e.y = ny
                    end
                end

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
                            for _, s in ipairs(snakeBody) do
                                if s.x == nx and s.y == ny then occupied = true; break end
                            end
                            if not occupied then
                                for _, o in ipairs(obstaclesMod.pos) do
                                    if o.x == nx and o.y == ny then occupied = true; break end
                                end
                            end
                            if not occupied then
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
    if enemies.boss and enemies.boss.alive then
        local boss = enemies.boss

        -- Update phase based on HP
        local vidaFrac = boss.vida / boss.vidaMax
        if vidaFrac <= 0.30 then
            boss.phase = 3
        elseif vidaFrac <= 0.60 then
            boss.phase = 2
        else
            boss.phase = 1
        end

        local ctx = {
            snakeHead = snakeBody[1],
            anchoGrilla = anchoGrilla,
            altoGrilla = altoGrilla,
            canSpawn = enemies.canSpawn,
            enemies = enemies,
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
                boss.stateTimer = boss.currentAttack.cooldown * (boss.phase == 3 and 0.7 or 1.0)
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
            if enemies.canSpawn("chaser") then
                local gx, gy = enemyHelpers.sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, enemies.list, 6, p.attempts)
                if gx then
                    enemies.spawnAt("chaser", gx, gy, {moveInterval = constants.ENEMY_CHASER_SPEED})
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

    -- Update attack objects
    for i = #attackObjects, 1, -1 do
        local ao = attackObjects[i]
        ao.lifetime = ao.lifetime - dt
        if ao.lifetime <= 0 then
            table.remove(attackObjects, i)
        elseif ao.type == "projectile" then
            local d = math.sqrt(ao.dx * ao.dx + ao.dy * ao.dy) * dt
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

-- ============================================================
--  Kill enemy
-- ============================================================

function enemies.killEnemy(idx)
    local e = enemies.list[idx]
    if not e or not e.alive then return nil end
    local tam = constants.TAMANIO_BLOQUE
    local result = {
        px = e.x * tam + tam / 2,
        py = e.y * tam + tam / 2,
        gx = e.x, gy = e.y,
        coins = e.dropCoins, type = e.type
    }
    e.alive = false
    return result
end

-- ============================================================
--  Draw
-- ============================================================

function enemies.draw()
    enemiesDraw.draw(enemies.list, enemies.boss, telegraphs, attackObjects)
end

return enemies
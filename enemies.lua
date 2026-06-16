local enemies = {}
local constants = require("constants")

local telegraphs = {}
local attackObjects = {}
local pendingRespawns = {}

enemies.list = {}
enemies.boss = nil

-- ============================================================
--  Attack definitions
-- ============================================================

local BOSS_ATTACKS = {
    projectile_spread = {
        name = "projectile_spread",
        telegraphTime = 0.8,
        cooldown = 3.5,
        minPhase = 1,
    },
    spawn_adds = {
        name = "spawn_adds",
        telegraphTime = 0.6,
        cooldown = 6.0,
        minPhase = 1,
    },
    radial_pulse = {
        name = "radial_pulse",
        telegraphTime = 1.0,
        cooldown = 5.0,
        minPhase = 2,
    },
    teleport = {
        name = "teleport",
        telegraphTime = 0.3,
        cooldown = 4.0,
        minPhase = 2,
    },
}

local function getAvailableAttacks(phase)
    local available = {}
    for _, attack in pairs(BOSS_ATTACKS) do
        if attack.minPhase <= phase then
            table.insert(available, attack)
        end
    end
    return available
end

local function computeTelegraphPositions(boss, attack, ctx)
    local positions = {}
    if attack.name == "projectile_spread" then
        local dirs = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}
        for _, d in ipairs(dirs) do
            local tx = boss.x + d[1]
            local ty = boss.y + d[2]
            if tx >= 0 and tx < ctx.anchoGrilla and ty >= 0 and ty < ctx.altoGrilla then
                table.insert(positions, {x = tx, y = ty})
            end
        end
    elseif attack.name == "spawn_adds" then
        local dirs = {{2,0},{-2,0},{0,2},{0,-2}}
        for _, d in ipairs(dirs) do
            local tx = boss.x + d[1]
            local ty = boss.y + d[2]
            if tx >= 0 and tx < ctx.anchoGrilla and ty >= 0 and ty < ctx.altoGrilla then
                table.insert(positions, {x = tx, y = ty})
            end
        end
    elseif attack.name == "radial_pulse" then
        for dx = -2, 2 do
            for dy = -2, 2 do
                if math.abs(dx) + math.abs(dy) <= 2 then
                    local tx = boss.x + dx
                    local ty = boss.y + dy
                    if tx >= 0 and tx < ctx.anchoGrilla and ty >= 0 and ty < ctx.altoGrilla then
                        table.insert(positions, {x = tx, y = ty})
                    end
                end
            end
        end
    elseif attack.name == "teleport" then
        -- no telegraph tiles; instant flush
    end
    return positions
end

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
--  Attack execution
-- ============================================================

local function bossExecuteAttack(boss, attackName, dt, ctx)
    if attackName == "projectile_spread" then
        local n = 4 + math.max(0, boss.phase - 1) * 1
        local speed = 40 + (boss.phase - 1) * 15
        local angleStep = 2 * math.pi / n
        for i = 0, n - 1 do
            local angle = i * angleStep
            enemies.addProjectile(boss.x, boss.y, math.cos(angle) * speed, math.sin(angle) * speed, 3.0, 1)
        end
    elseif attackName == "spawn_adds" then
        local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
        local spawnCount = 0
        -- Shuffle directions to avoid bias
        for i = #dirs, 2, -1 do
            local j = love.math.random(1, i)
            dirs[i], dirs[j] = dirs[j], dirs[i]
        end
        for _, d in ipairs(dirs) do
            if spawnCount >= 2 then break end
            if not canSpawn("patroller") then break end
            local nx, ny = boss.x + d[1]*2, boss.y + d[2]*2
            if nx >= 0 and nx < ctx.anchoGrilla and ny >= 0 and ny < ctx.altoGrilla then
                local occupied = false
                for _, e in ipairs(enemies.list) do
                    if e.alive and e.x == nx and e.y == ny then occupied = true; break end
                end
                if not occupied then
                    local e = {
                        x = nx, y = ny, type = "patroller", alive = true,
                        dirX = d[1], dirY = d[2], moveTimer = 0, spawnTimer = 0,
                        moveInterval = constants.ENEMY_PATROLLER_SPEED,
                        dropCoins = 0, spawnTime = love.timer.getTime()
                    }
                    table.insert(enemies.list, e)
                    spawnCount = spawnCount + 1
                end
            end
        end
    elseif attackName == "radial_pulse" then
        enemies.addRadialPulse(boss.x, boss.y, 8, 3, 1)
    elseif attackName == "teleport" then
        local attempts = 0
        local nx, ny
        repeat
            nx = love.math.random(2, ctx.anchoGrilla - 3)
            ny = love.math.random(2, ctx.altoGrilla - 3)
            attempts = attempts + 1
        until attempts > 30 or (math.abs(nx - ctx.snakeHead.x) + math.abs(ny - ctx.snakeHead.y) > 5)
        if attempts <= 30 then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local tx = boss.x + dx
                    local ty = boss.y + dy
                    if tx >= 0 and tx < ctx.anchoGrilla and ty >= 0 and ty < ctx.altoGrilla then
                        enemies.addTelegraph(tx, ty, 0.3, "teleport")
                    end
                end
            end
            boss.x = nx
            boss.y = ny
        end
    end
end

-- ============================================================
--  Standard helpers
-- ============================================================

local function validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla)
    if x < 0 or x >= anchoGrilla or y < 0 or y >= altoGrilla then return false end
    for _, s in ipairs(snake) do
        if x == s.x and y == s.y then return false end
    end
    if foodPos and x == foodPos.x and y == foodPos.y then return false end
    for _, o in ipairs(obstacles) do
        if x == o.x and y == o.y then return false end
    end
    for _, e in ipairs(enemies.list) do
        if e.alive and x == e.x and y == e.y then return false end
    end
    return true
end

local function countEnemiesByType()
    local counts = {}
    for _, e in ipairs(enemies.list) do
        if e.alive then
            counts[e.type] = (counts[e.type] or 0) + 1
        end
    end
    return counts
end

function canSpawn(type)
    if not enemies.boss or not enemies.boss.alive then return true end
    local counts = countEnemiesByType()
    if type == "chaser" and (counts.chaser or 0) >= constants.BOSS_MAX_RED then return false end
    if type == "patroller" and (counts.patroller or 0) >= constants.BOSS_MAX_BLUE then return false end
    return true
end

local function sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, minDist, attempts)
    minDist = minDist or 6
    attempts = attempts or constants.BOSS_RESPAWN_RETRY
    local head = snakeBody and snakeBody[1]
    for _ = 1, attempts do
        local gx = love.math.random(1, anchoGrilla - 2)
        local gy = love.math.random(1, altoGrilla - 2)
        local valid = true
        if head then
            if math.abs(gx - head.x) + math.abs(gy - head.y) < minDist then valid = false end
        end
        if valid then
            for _, s in ipairs(snakeBody) do
                if gx == s.x and gy == s.y then valid = false; break end
            end
        end
        if valid and obstaclesMod then
            for _, o in ipairs(obstaclesMod.pos) do
                if gx == o.x and gy == o.y then valid = false; break end
            end
        end
        if valid then
            for _, e in ipairs(enemies.list) do
                if e.alive and gx == e.x and gy == e.y then valid = false; break end
            end
        end
        if valid then return gx, gy end
    end
    return nil, nil
end

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
    until (validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla) or attempts > 100)
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
        }

        if boss.state == "idle" then
            boss.attackCooldown = boss.attackCooldown - dt
            if boss.attackCooldown <= 0 then
                local attacks = getAvailableAttacks(boss.phase)
                if #attacks > 0 then
                    local chosen = attacks[love.math.random(1, #attacks)]
                    boss.currentAttack = chosen
                    boss.telegraphPositions = computeTelegraphPositions(boss, chosen, ctx)
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
                bossExecuteAttack(boss, boss.currentAttack.name, dt, ctx)
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
            if canSpawn("chaser") then
                local gx, gy = sampleFreeTile(anchoGrilla, altoGrilla, snakeBody, obstaclesMod, 6, p.attempts)
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
    local tam = constants.TAMANIO_BLOQUE
    local time = love.timer.getTime()

    -- Draw telegraph markers (under enemies)
    for _, t in ipairs(telegraphs) do
        local frac = 1 - t.timer / t.maxTimer
        local alpha = 0.3 + frac * 0.5
        local pulse = math.sin(time * 10 + frac * math.pi * 2) * 0.2 + 0.8
        love.graphics.setColor(1, 0.2 + frac * 0.8, 0.1, alpha * pulse)
        love.graphics.rectangle("fill", t.gx * tam + 1, t.gy * tam + 1, tam - 2, tam - 2, 2, 2)
        love.graphics.setColor(1, 1, 0.3, alpha * pulse * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", t.gx * tam + 1, t.gy * tam + 1, tam - 2, tam - 2, 2, 2)
        love.graphics.setLineWidth(1)
    end

    -- Draw normal enemies
    for _, e in ipairs(enemies.list) do
        if e.alive then
            local cx = e.x * tam + tam / 2
            local cy = e.y * tam + tam / 2

            if e.type == "chaser" then
                love.graphics.setColor(constants.COLOR_ENEMY_CHASER[1], constants.COLOR_ENEMY_CHASER[2], constants.COLOR_ENEMY_CHASER[3])
                local pts = {cx, cy - tam/3, cx + tam/3, cy, cx, cy + tam/3, cx - tam/3, cy}
                love.graphics.polygon("fill", pts)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.setLineWidth(1)
                love.graphics.polygon("line", pts)

            elseif e.type == "patroller" then
                love.graphics.setColor(constants.COLOR_ENEMY_PATROLLER[1], constants.COLOR_ENEMY_PATROLLER[2], constants.COLOR_ENEMY_PATROLLER[3])
                local dx, dy = e.dirX, e.dirY
                if dx == 0 and dy == 0 then dx = 1 end
                local angle = math.atan2(dy, dx)
                local r = tam * 0.4
                local pts = {
                    cx + math.cos(angle) * r, cy + math.sin(angle) * r,
                    cx + math.cos(angle + 2.5) * r, cy + math.sin(angle + 2.5) * r,
                    cx + math.cos(angle - 2.5) * r, cy + math.sin(angle - 2.5) * r
                }
                love.graphics.polygon("fill", pts)
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.setLineWidth(1)
                love.graphics.polygon("line", pts)

            elseif e.type == "spawner" then
                local pulse = math.sin(time * 2) * 0.2 + 0.8
                love.graphics.setColor(
                    constants.COLOR_ENEMY_SPAWNER[1] * pulse,
                    constants.COLOR_ENEMY_SPAWNER[2] * pulse,
                    constants.COLOR_ENEMY_SPAWNER[3] * pulse
                )
                love.graphics.rectangle("fill", e.x * tam + 2, e.y * tam + 2, tam - 4, tam - 4, 3, 3)
                love.graphics.setColor(1, 1, 1, 0.3 + math.sin(time * 3) * 0.15)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", e.x * tam + 1, e.y * tam + 1, tam - 2, tam - 2, 3, 3)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Draw attack objects
    for _, ao in ipairs(attackObjects) do
        if ao.type == "projectile" then
            love.graphics.setColor(1, 0.8, 0.2, 1)
            love.graphics.circle("fill", ao.x * tam + tam/2, ao.y * tam + tam/2, 3)
            love.graphics.setColor(1, 1, 0.5, 0.4)
            love.graphics.circle("fill", ao.x * tam + tam/2, ao.y * tam + tam/2, 5)
        elseif ao.type == "radial_pulse" then
            local px = ao.cx * tam + tam / 2
            local py = ao.cy * tam + tam / 2
            local r = ao.radius * tam
            local alpha = 0.5 * (1 - ao.radius / ao.maxRadius)
            love.graphics.setColor(1, 0.3, 0.1, alpha)
            love.graphics.circle("line", px, py, r)
            love.graphics.setColor(1, 0.6, 0.2, alpha * 0.3)
            love.graphics.circle("fill", px, py, r * 0.8)
        end
    end

    -- Boss draw
    if enemies.boss and enemies.boss.alive then
        local cx = enemies.boss.x * tam + tam / 2
        local cy = enemies.boss.y * tam + tam / 2
        local vidaFrac = enemies.boss.vida / enemies.boss.vidaMax
        local pulse = math.sin(time * 3) * 0.2 + 0.8

        local r, g, b
        if enemies.boss.state == "telegraph" then
            -- Brillo durante telegraph
            local flash = math.sin(time * 15) * 0.3 + 0.7
            r = 1.0 * pulse * flash
            g = 0.2 * vidaFrac * pulse
            b = 0.6 * pulse
        else
            r = 1.0 * pulse
            g = 0.2 * vidaFrac * pulse
            b = 0.6 * pulse
        end

        love.graphics.setColor(r, g, b)
        local size = tam * 1.5
        local pts = {
            cx, cy - size/2,
            cx + size/2, cy,
            cx, cy + size/2,
            cx - size/2, cy
        }
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", pts)
        love.graphics.setLineWidth(1)

        -- Ojo del boss
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", cx, cy, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", cx, cy, 1.5)

        -- Health bar (mapped to food collected)
        local cfg = constants.BOSS_HEALTH_BAR
        local bx = cx - cfg.width / 2
        local by = cy + cfg.yOffset
        -- Background
        love.graphics.setColor(cfg.bgColor)
        love.graphics.rectangle("fill", bx, by, cfg.width, cfg.height)
        -- Border
        love.graphics.setColor(cfg.borderColor)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx - 1, by - 1, cfg.width + 2, cfg.height + 2)
        -- Foreground fill
        local fillW = math.floor(math.max(0, math.min(1, enemies.boss._uiBarFill)) * cfg.width)
        love.graphics.setColor(cfg.fgColor)
        love.graphics.rectangle("fill", bx, by, fillW, cfg.height)
        -- Counter text
        local txt = string.format("%d / %d", enemies.boss.foodCollected or 0, enemies.boss.foodTarget or constants.BOSS_FOOD_TARGET)
        local txtW = love.graphics.getFont():getWidth(txt)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(txt, cx - txtW / 2, by - 14)
    end
end

return enemies

-- entities/bossAttacks.lua — Definiciones de ataques del boss y su ejecución (sin navegar el estado interno de enemies)
local bossAttacks = {}
local constants = require("constants")

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

-- Exponer definiciones para inspección, pruebas y sistemas externos
bossAttacks.ATTACKS = BOSS_ATTACKS
bossAttacks.definitions = BOSS_ATTACKS

local ATTACK_KEYS = {
    "projectile_spread",
    "spawn_adds",
    "radial_pulse",
    "teleport",
}

function bossAttacks.get(name)
    if not name then return nil end
    return BOSS_ATTACKS[name]
end

function bossAttacks.getAll()
    return BOSS_ATTACKS
end

function bossAttacks.isPhaseValid(attackName, phase)
    local atk = bossAttacks.get(attackName)
    if not atk then return false end
    phase = phase or 1
    return atk.minPhase <= phase
end

function bossAttacks.getAvailable(phase)
    phase = phase or 1
    local available = {}
    for _, key in ipairs(ATTACK_KEYS) do
        local attack = BOSS_ATTACKS[key]
        if attack and attack.minPhase <= phase then
            table.insert(available, attack)
        end
    end
    return available
end

function bossAttacks.computePositions(boss, attack, ctx)
    local positions = {}
    if not boss or not attack then return positions end

    ctx = ctx or {}
    local anchoGrilla = ctx.anchoGrilla or constants.MAX_GRID_COLS or 40
    local altoGrilla = ctx.altoGrilla or constants.MAX_GRID_ROWS or 28
    local attackName = (type(attack) == "table" and attack.name) or attack

    if attackName == "projectile_spread" then
        local dirs = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}
        for _, d in ipairs(dirs) do
            local tx = boss.x + d[1]
            local ty = boss.y + d[2]
            if tx >= 0 and tx < anchoGrilla and ty >= 0 and ty < altoGrilla then
                table.insert(positions, {x = tx, y = ty})
            end
        end
    elseif attackName == "spawn_adds" then
        local dirs = {{2,0},{-2,0},{0,2},{0,-2}}
        for _, d in ipairs(dirs) do
            local tx = boss.x + d[1]
            local ty = boss.y + d[2]
            if tx >= 0 and tx < anchoGrilla and ty >= 0 and ty < altoGrilla then
                table.insert(positions, {x = tx, y = ty})
            end
        end
    elseif attackName == "radial_pulse" then
        for dx = -2, 2 do
            for dy = -2, 2 do
                if math.abs(dx) + math.abs(dy) <= 2 then
                    local tx = boss.x + dx
                    local ty = boss.y + dy
                    if tx >= 0 and tx < anchoGrilla and ty >= 0 and ty < altoGrilla then
                        table.insert(positions, {x = tx, y = ty})
                    end
                end
            end
        end
    elseif attackName == "teleport" then
        -- No telegraph tiles previos; el teleport se telegrafía en origen al ejecutarse
    end
    return positions
end

-- ctx: {anchoGrilla, altoGrilla, snakeHead, snakeBody, obstacles, canSpawn, enemies, speedMult}
function bossAttacks.execute(boss, attack, dt, ctx)
    if not boss then return end
    ctx = ctx or {}
    local enemiesMod = ctx.enemies or require("entities.enemies")
    local anchoGrilla = ctx.anchoGrilla or constants.MAX_GRID_COLS or 40
    local altoGrilla = ctx.altoGrilla or constants.MAX_GRID_ROWS or 28
    local phase = boss.phase or 1
    local attackName = (type(attack) == "table" and attack.name) or attack

    if attackName == "projectile_spread" then
        local n = 4 + math.max(0, phase - 1) * 1
        local speed = 40 + (phase - 1) * 15
        local angleStep = 2 * math.pi / n
        for i = 0, n - 1 do
            local angle = i * angleStep
            enemiesMod.addProjectile(boss.x, boss.y, math.cos(angle) * speed, math.sin(angle) * speed, 3.0, 1)
        end
    elseif attackName == "spawn_adds" then
        local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
        local spawnCount = 0
        -- Shuffle directions to avoid bias
        for i = #dirs, 2, -1 do
            local j = love.math.random(1, i)
            dirs[i], dirs[j] = dirs[j], dirs[i]
        end
        local speedMult = ctx.speedMult or 1.0
        local enemyList = enemiesMod.list or {}

        for _, d in ipairs(dirs) do
            if spawnCount >= 2 then break end
            if ctx.canSpawn and not ctx.canSpawn("patroller") then break end
            local nx = boss.x + d[1] * 2
            local ny = boss.y + d[2] * 2
            if nx >= 0 and nx < anchoGrilla and ny >= 0 and ny < altoGrilla then
                local occupied = false
                for _, e in ipairs(enemyList) do
                    if e.alive and e.x == nx and e.y == ny then occupied = true; break end
                end
                -- Evitar spawnear encima del jugador
                if ctx.snakeHead and ctx.snakeHead.x == nx and ctx.snakeHead.y == ny then
                    occupied = true
                end
                if ctx.snakeBody then
                    for _, seg in ipairs(ctx.snakeBody) do
                        if seg.x == nx and seg.y == ny then occupied = true; break end
                    end
                end
                -- Evitar obstáculos
                if ctx.obstacles and ctx.obstacles.pos then
                    for _, obs in ipairs(ctx.obstacles.pos) do
                        if obs.x == nx and obs.y == ny then occupied = true; break end
                    end
                end

                if not occupied then
                    enemiesMod.spawnAt("patroller", nx, ny, {
                        dirX = d[1],
                        dirY = d[2],
                        dropCoins = 0,
                        moveInterval = constants.ENEMY_PATROLLER_SPEED / speedMult
                    })
                    spawnCount = spawnCount + 1
                end
            end
        end
    elseif attackName == "radial_pulse" then
        enemiesMod.addRadialPulse(boss.x, boss.y, 8, 3, 1)
    elseif attackName == "teleport" then
        local minX = 2
        local maxX = math.max(minX, anchoGrilla - 3)
        local minY = 2
        local maxY = math.max(minY, altoGrilla - 3)
        local headX = (ctx.snakeHead and ctx.snakeHead.x) or math.floor(anchoGrilla / 2)
        local headY = (ctx.snakeHead and ctx.snakeHead.y) or math.floor(altoGrilla / 2)

        local attempts = 0
        local nx, ny
        repeat
            nx = love.math.random(minX, maxX)
            ny = love.math.random(minY, maxY)
            attempts = attempts + 1
        until attempts > 30 or (math.abs(nx - headX) + math.abs(ny - headY) > 5)

        if nx and ny then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local tx = boss.x + dx
                    local ty = boss.y + dy
                    if tx >= 0 and tx < anchoGrilla and ty >= 0 and ty < altoGrilla then
                        enemiesMod.addTelegraph(tx, ty, 0.3, "teleport")
                    end
                end
            end
            boss.x = nx
            boss.y = ny
        end
    end
end

return bossAttacks
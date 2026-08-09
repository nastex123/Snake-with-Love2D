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

function bossAttacks.getAvailable(phase)
    local available = {}
    for _, attack in pairs(BOSS_ATTACKS) do
        if attack.minPhase <= phase then
            table.insert(available, attack)
        end
    end
    return available
end

function bossAttacks.computePositions(boss, attack, ctx)
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

-- ctx: {anchoGrilla, altoGrilla, snakeHead, canSpawn, enemies}
function bossAttacks.execute(boss, attackName, dt, ctx)
    if attackName == "projectile_spread" then
        local n = 4 + math.max(0, boss.phase - 1) * 1
        local speed = 40 + (boss.phase - 1) * 15
        local angleStep = 2 * math.pi / n
        for i = 0, n - 1 do
            local angle = i * angleStep
            ctx.enemies.addProjectile(boss.x, boss.y, math.cos(angle) * speed, math.sin(angle) * speed, 3.0, 1)
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
            if not ctx.canSpawn("patroller") then break end
            local nx, ny = boss.x + d[1]*2, boss.y + d[2]*2
            if nx >= 0 and nx < ctx.anchoGrilla and ny >= 0 and ny < ctx.altoGrilla then
                local occupied = false
                for _, e in ipairs(ctx.enemies.list) do
                    if e.alive and e.x == nx and e.y == ny then occupied = true; break end
                end
                if not occupied then
                    local e = {
                        x = nx, y = ny, type = "patroller", alive = true,
                        dirX = d[1], dirY = d[2], moveTimer = 0, spawnTimer = 0,
                        moveInterval = constants.ENEMY_PATROLLER_SPEED,
                        dropCoins = 0, spawnTime = love.timer.getTime()
                    }
                    table.insert(ctx.enemies.list, e)
                    spawnCount = spawnCount + 1
                end
            end
        end
    elseif attackName == "radial_pulse" then
        ctx.enemies.addRadialPulse(boss.x, boss.y, 8, 3, 1)
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
                        ctx.enemies.addTelegraph(tx, ty, 0.3, "teleport")
                    end
                end
            end
            boss.x = nx
            boss.y = ny
        end
    end
end

return bossAttacks
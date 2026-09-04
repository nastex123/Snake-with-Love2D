-- entities/obstacles.lua
-- Obstacle and hazard entity management with biomes, destructibility, and collision queries.
local obstacles = {}
local constants = require("constants")
local Log = require("core.logger")
local BiomeHazards = require("world.biomeHazards")
obstacles.pos = {}
obstacles.list = obstacles.pos
obstacles.flashTimers = {}
-- Obstacle Types Definition
obstacles.TYPES = {
    WALL = "wall",
    TRAP = "trap",
    LAVA = "lava",
    ICE = "ice",
    SLIME = "slime",
    PRESSURE_SPIKE = "pressure_spike"
}
-- Default properties per type
obstacles.TYPE_DEFAULTS = {
    wall = {
        type = "wall",
        destructible = true,
        hp = 1,
        maxHp = 1,
        hazard = false,
        damage = 1,
        slowFactor = 1.0,
        slip = 0,
        color = {0.45, 0.48, 0.55}
    },
    trap = {
        type = "trap",
        destructible = true,
        hp = 1,
        maxHp = 1,
        hazard = true,
        damage = 1,
        slowFactor = 1.0,
        slip = 0,
        color = {0.75, 0.25, 0.25}
    },
    lava = BiomeHazards.DEFAULTS.lava,
    ice = BiomeHazards.DEFAULTS.ice,
    slime = BiomeHazards.DEFAULTS.slime,
    pressure_spike = BiomeHazards.DEFAULTS.pressure_spike
}
function obstacles.init()
    obstacles.pos = {}
    obstacles.list = obstacles.pos
    obstacles.flashTimers = {}
end
function obstacles.reset()
    obstacles.init()
end
function obstacles.clear()
    obstacles.init()
end
-- Helper: Synchronize parallel flashTimers array with obstacles.pos
function obstacles.syncFlashTimers()
    obstacles.flashTimers = {}
    for i, obs in ipairs(obstacles.pos) do
        obstacles.flashTimers[i] = obs.flashTimer or 0
    end
end
-- Helper: Validate coordinate values
local function sanitizeCoords(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil
    end
    -- Check for NaN or infinity
    if x ~= x or y ~= y or x == math.huge or x == -math.huge or y == math.huge or y == -math.huge then
        return nil, nil
    end
    return math.floor(x), math.floor(y)
end
-- Helper: Extract snake segments from either snake table or body array
local function extractSnakeBody(snake)
    if not snake then return {} end
    if type(snake) == "table" and type(snake.body) == "table" then
        return snake.body
    end
    if type(snake) == "table" then
        return snake
    end
    return {}
end

-- Query: Check if an obstacle exists at (x, y)
function obstacles.isObstacle(x, y)
    local gx, gy = sanitizeCoords(x, y)
    if not gx or not gy then return false, nil end

    for _, obs in ipairs(obstacles.pos) do
        if obs.x == gx and obs.y == gy then
            return true, obs
        end
    end
    return false, nil
end

-- Query: Get obstacle and its index at (x, y)
function obstacles.getObstacleAt(x, y)
    local gx, gy = sanitizeCoords(x, y)
    if not gx or not gy then return nil, nil end

    for i, obs in ipairs(obstacles.pos) do
        if obs.x == gx and obs.y == gy then
            return obs, i
        end
    end
    return nil, nil
end

function obstacles.getAt(x, y)
    return obstacles.getObstacleAt(x, y)
end

-- Query: Check if position contains a hazard
function obstacles.isHazard(x, y)
    local obs = obstacles.getObstacleAt(x, y)
    if obs and obs.hazard then
        return true, obs.type, obs
    end
    return false, nil, nil
end

function obstacles.getHazardAt(x, y)
    return obstacles.isHazard(x, y)
end

-- Query: Check if position contains a hazard that is currently in a lethal/damaging state
function obstacles.isHazardLethal(x, y)
    local obs = obstacles.getObstacleAt(x, y)
    if not obs or not obs.hazard then return false, nil end
    return BiomeHazards.isLethal(obs), obs
end

-- Query: Get tile physics modifiers (slip momentum, movement slow factor)
function obstacles.getTileModifier(x, y)
    local obs = obstacles.getObstacleAt(x, y)
    if not obs then return 0, 1.0 end
    return BiomeHazards.getTileModifier(obs)
end

-- Trigger pressure spike immediately upon contact
function obstacles.triggerPressureSpike(x, y)
    local obs = obstacles.getObstacleAt(x, y)
    BiomeHazards.triggerPressureSpike(obs)
end

-- Add / Spawn an obstacle at specific grid coordinates
function obstacles.agregar(x, y, tipo, destructible, hp, opts)
    local gx, gy = sanitizeCoords(x, y)
    if not gx or not gy then
        Log.warn("obstacles.agregar: Invalid coordinates passed (" .. tostring(x) .. ", " .. tostring(y) .. ")")
        return false, "invalid_coords"
    end

    -- Check for duplicate obstacle at same position
    local existing, idx = obstacles.getObstacleAt(gx, gy)
    if existing then
        -- Update existing obstacle if explicit type passed
        if tipo and tipo ~= existing.type then
            local def = obstacles.TYPE_DEFAULTS[tipo] or obstacles.TYPE_DEFAULTS.wall
            existing.type = tipo
            existing.hazard = def.hazard
            existing.damage = def.damage
            existing.slowFactor = def.slowFactor
            existing.slip = def.slip
            existing.color = def.color
            existing.state = def.state
            existing.timer = def.timer
            if destructible ~= nil then
                existing.destructible = destructible
            end
            if hp ~= nil then
                existing.hp = hp
                existing.maxHp = hp
            end
        end
        return false, "already_exists", existing
    end

    local typeKey = (tipo and obstacles.TYPE_DEFAULTS[tipo]) and tipo or "wall"
    local defaults = obstacles.TYPE_DEFAULTS[typeKey]

    local isDestructible = defaults.destructible
    if destructible ~= nil then
        isDestructible = (destructible == true)
    end

    local maxHealth = (hp and hp > 0) and hp or defaults.hp

    local newObs = {
        x = gx,
        y = gy,
        type = typeKey,
        destructible = isDestructible,
        hp = maxHealth,
        maxHp = maxHealth,
        hazard = defaults.hazard,
        damage = defaults.damage,
        slowFactor = defaults.slowFactor,
        slip = defaults.slip,
        color = defaults.color,
        state = defaults.state or "idle",
        timer = defaults.timer or 0,
        flashTimer = 0.4
    }

    if opts and type(opts) == "table" then
        for k, v in pairs(opts) do
            if newObs[k] == nil or (k ~= "x" and k ~= "y") then
                newObs[k] = v
            end
        end
    end

    table.insert(obstacles.pos, newObs)
    table.insert(obstacles.flashTimers, newObs.flashTimer)

    return true, newObs
end

function obstacles.spawnAt(gx, gy, tipo, destructible, hp, opts)
    return obstacles.agregar(gx, gy, tipo, destructible, hp, opts)
end

-- Generate a random obstacle ensuring no overlap with snake, food, or other obstacles
function obstacles.generar(snake, foodPos, anchoGrilla, altoGrilla, tipo, destructible, hp, opts)
    local width = (anchoGrilla and anchoGrilla > 0) and anchoGrilla or (constants.MAX_GRID_COLS or 32)
    local height = (altoGrilla and altoGrilla > 0) and altoGrilla or (constants.MAX_GRID_ROWS or 18)
    local snakeBody = extractSnakeBody(snake)

    local nuevaX, nuevaY
    local colisiona
    local attempts = 0
    local maxAttempts = 500

    repeat
        if love and love.math and love.math.random then
            nuevaX = love.math.random(0, width - 1)
            nuevaY = love.math.random(0, height - 1)
        else
            nuevaX = math.random(0, width - 1)
            nuevaY = math.random(0, height - 1)
        end

        colisiona = false
        attempts = attempts + 1

        -- 1. Check snake body collision
        for _, segmento in ipairs(snakeBody) do
            if segmento and nuevaX == segmento.x and nuevaY == segmento.y then
                colisiona = true
                break
            end
        end

        -- 2. Check food collision (supports single food table or array of foods)
        if not colisiona and foodPos then
            if type(foodPos) == "table" then
                if foodPos.x ~= nil and foodPos.y ~= nil then
                    if nuevaX == foodPos.x and nuevaY == foodPos.y then
                        colisiona = true
                    end
                else
                    for _, f in ipairs(foodPos) do
                        if f and nuevaX == f.x and nuevaY == f.y then
                            colisiona = true
                            break
                        end
                    end
                end
            end
        end

        -- 3. Check existing obstacles
        if not colisiona then
            for _, obs in ipairs(obstacles.pos) do
                if nuevaX == obs.x and nuevaY == obs.y then
                    colisiona = true
                    break
                end
            end
        end
    until not colisiona or attempts >= maxAttempts

    if colisiona then
        Log.debug("obstacles.generar: Could not find free position after " .. attempts .. " attempts")
        return false, "grid_full"
    end

    local ok, obs = obstacles.agregar(nuevaX, nuevaY, tipo, destructible, hp, opts)
    return ok, obs
end

-- Generate biome-specific obstacles
function obstacles.generarPorBioma(bioma, snake, foodPos, anchoGrilla, altoGrilla, count, opts)
    local total = (count and count > 0) and count or 1
    local biomeStr = "catacumbas"

    if type(bioma) == "number" then
        local biomeMap = {
            [1] = "catacumbas",
            [2] = "hielo",
            [3] = "volcan",
            [4] = "colmena",
            [5] = "vacio"
        }
        biomeStr = biomeMap[bioma] or "catacumbas"
    elseif type(bioma) == "string" then
        biomeStr = bioma:lower()
    end

    local spawned = {}
    for _ = 1, total do
        local rnd = (love and love.math and love.math.random) and love.math.random() or math.random()
        local typeToSpawn = BiomeHazards.getSpawnForBiome(biomeStr, rnd)
        local ok, obs = obstacles.generar(snake, foodPos, anchoGrilla, altoGrilla, typeToSpawn, nil, nil, opts)
        if ok and obs then
            table.insert(spawned, obs)
        end
    end

    return spawned
end

-- Destroy an obstacle at (x, y) with optional force flag (overriding indestructible)
function obstacles.destruir(x, y, force)
    local obs, idx = obstacles.getObstacleAt(x, y)
    if not obs or not idx then
        return false, "not_found"
    end

    if not obs.destructible and not force then
        return false, "indestructible", obs
    end

    table.remove(obstacles.pos, idx)
    if idx <= #obstacles.flashTimers then
        table.remove(obstacles.flashTimers, idx)
    end
    obstacles.syncFlashTimers()

    return true, obs
end

function obstacles.destroyAt(x, y, force)
    return obstacles.destruir(x, y, force)
end

-- Damage an obstacle at (x, y)
function obstacles.damageAt(x, y, dmg, force)
    local obs, idx = obstacles.getObstacleAt(x, y)
    if not obs or not idx then
        return false, 0, nil
    end

    if not obs.destructible and not force then
        return false, obs.hp, obs
    end
    local amount = (dmg and dmg > 0) and dmg or 1
    obs.hp = obs.hp - amount

    if obs.hp <= 0 then
        local ok, destroyedObs = obstacles.destruir(x, y, force)
        return ok, 0, destroyedObs or obs
    end

    return false, obs.hp, obs
end

-- Destroy obstacles in a given Chebyshev radius around (cx, cy)
function obstacles.destruirEnRadio(cx, cy, radius, force)
    local gx, gy = sanitizeCoords(cx, cy)
    if not gx or not gy then return 0, {} end
    local rad = (radius and radius >= 0) and radius or 1

    local destroyed = {}
    for i = #obstacles.pos, 1, -1 do
        local obs = obstacles.pos[i]
        local dist = math.max(math.abs(obs.x - gx), math.abs(obs.y - gy))
        if dist <= rad then
            if obs.destructible or force then
                table.insert(destroyed, obs)
                table.remove(obstacles.pos, i)
                if i <= #obstacles.flashTimers then
                    table.remove(obstacles.flashTimers, i)
                end
            end
        end
    end

    obstacles.syncFlashTimers()
    return #destroyed, destroyed
end

-- Update flash animations and hazard states
function obstacles.update(dt)
    local delta = dt or 0.016
    for i = 1, #obstacles.pos do
        local obs = obstacles.pos[i]
        if obs.flashTimer and obs.flashTimer > 0 then
            obs.flashTimer = math.max(0, obs.flashTimer - delta)
        end
    end
    BiomeHazards.update(delta, obstacles.pos)
    for i = 1, #obstacles.flashTimers do
        obstacles.flashTimers[i] = math.max(0, (obstacles.flashTimers[i] or 0) - delta)
    end
end

-- Count obstacles by type
function obstacles.getCountsByType()
    local counts = {
        wall = 0,
        trap = 0,
        lava = 0,
        ice = 0,
        slime = 0,
        pressure_spike = 0,
        total = #obstacles.pos
    }
    for _, obs in ipairs(obstacles.pos) do
        local t = obs.type or "wall"
        counts[t] = (counts[t] or 0) + 1
    end
    return counts
end

-- Procedural render of obstacles according to type and flash animation
function obstacles.draw()
    if not love or not love.graphics then return end

    local tam = constants.TAMANIO_BLOQUE or 20
    local time = (love.timer and love.timer.getTime) and love.timer.getTime() or 0

    for i, obs in ipairs(obstacles.pos) do
        local flash = obs.flashTimer or (obstacles.flashTimers and obstacles.flashTimers[i]) or 0
        local obsType = obs.type or "wall"
        local baseColor = obs.color or (obstacles.TYPE_DEFAULTS[obsType] and obstacles.TYPE_DEFAULTS[obsType].color) or {0.45, 0.48, 0.55}

        if flash > 0 then
            -- Spawn flash animation (scale up from center with bright alpha)
            local frac = 1 - flash / 0.4
            local sc = frac * frac * (3 - 2 * frac)
            local drawSize = math.max(2, (tam - 1) * sc)
            local drawOff = ((tam - 1) - drawSize) / 2

            love.graphics.setColor(1, 1, 1, (1 - frac) * 0.85 + 0.15)
            love.graphics.rectangle("fill",
                obs.x * tam + drawOff, obs.y * tam + drawOff,
                drawSize, drawSize, 3, 3)
        else
            -- Render type-specific aesthetics
            local pulse = math.sin(time * 2.5 + i * 1.3) * 0.05
            local size = (tam - 1) * (1 + pulse * 0.4)
            local off = ((tam - 1) - size) / 2 + 0.5
            local px = obs.x * tam + off
            local py = obs.y * tam + off

            if BiomeHazards.draw(obs, px, py, size, time, i) then
            elseif obsType == "trap" then
                -- Metallic hazard spike trap
                love.graphics.setColor(0.25, 0.25, 0.28, 1.0)
                love.graphics.rectangle("fill", px, py, size, size, 2, 2)

                -- Warning crimson cross
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.95)
                local arm = size * 0.25
                love.graphics.rectangle("fill", px + (size - arm) / 2, py + 2, arm, size - 4)
                love.graphics.rectangle("fill", px + 2, py + (size - arm) / 2, size - 4, arm)

                -- Metal border
                love.graphics.setColor(0.85, 0.3, 0.3, 1.0)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", px, py, size, size, 2, 2)

            else
                -- Standard stone wall
                love.graphics.setColor(baseColor[1] + pulse, baseColor[2] + pulse, baseColor[3] + pulse * 0.5, 1.0)
                love.graphics.rectangle("fill", px, py, size, size, 3, 3)

                -- Stone mortar outline
                love.graphics.setColor(0.25 + pulse * 0.3, 0.25 + pulse * 0.3, 0.30 + pulse * 0.2, 1.0)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", px, py, size, size, 3, 3)
            end
        end
    end
end

return obstacles

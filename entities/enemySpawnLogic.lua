-- =============================================================================
-- MÓDULO: enemySpawnLogic.lua
-- Parte de P01 — Split de entities/enemies.lua (634 → 4 módulos)
-- Gestiona canSpawn, spawnAt y generar (pesos por etapa, validación, caps de boss).
-- Extraído de entities/enemies.lua sin cambios de semántica.
-- =============================================================================
local spawnLogic = {}

local constants = require("constants")
local enemyHelpers = require("entities.enemyHelpers")
local chaserAI = require("entities.chaserAI")
local patrollerAI = require("entities.patrollerAI")

-- ---------------------------------------------------------------------------
-- canSpawn — respeta caps de boss (BOSS_MAX_RED / BOSS_MAX_BLUE)
-- ---------------------------------------------------------------------------
function spawnLogic.canSpawn(boss, list, type)
    if not boss or not boss.alive then return true end
    local counts = enemyHelpers.countEnemiesByType(list)
    if type == "chaser" and (counts.chaser or 0) >= constants.BOSS_MAX_RED then return false end
    if type == "patroller" and (counts.patroller or 0) >= constants.BOSS_MAX_BLUE then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- spawnAt — crea un enemigo tipado en (gx,gy) y lo inserta en list
-- ---------------------------------------------------------------------------
function spawnLogic.spawnAt(list, type, gx, gy, params)
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
    table.insert(list, e)
    return e
end

-- ---------------------------------------------------------------------------
-- generar — selección ponderada por stageModifier + validación de posición
-- ---------------------------------------------------------------------------
function spawnLogic.generar(list, boss, snake, foodPos, obstacles, anchoGrilla, altoGrilla, stageModifier)
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

    -- Respeta caps de boss con fallback de tipo
    local function can(type) return spawnLogic.canSpawn(boss, list, type) end
    if not can(eType) then
        if eType == "chaser" and can("patroller") then
            eType = "patroller"
        elseif eType == "patroller" and can("chaser") then
            eType = "chaser"
        elseif not can("chaser") and not can("patroller") then
            eType = "spawner"
        end
    end
    if not can(eType) then return end

    local x, y
    local attempts = 0
    repeat
        x = love.math.random(0, anchoGrilla - 1)
        y = love.math.random(0, altoGrilla - 1)
        attempts = attempts + 1
    until (enemyHelpers.validarPos(x, y, snake, foodPos, obstacles, anchoGrilla, altoGrilla, list) or attempts > 100)
    if attempts > 100 then return end

    local etapa = (mod and mod.stage) or 1
    local chaserInterval = math.max(0.15, (constants.ENEMY_CHASER_SPEED / speedMult) * (0.90 ^ (math.max(1, etapa) - 1)))

    return spawnLogic.spawnAt(list, eType, x, y, {
        moveInterval = (eType == "chaser" and chaserInterval)
            or (eType == "patroller" and constants.ENEMY_PATROLLER_SPEED / speedMult)
            or nil
    })
end

return spawnLogic

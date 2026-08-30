local constants = require("constants")
local populate = {}

local function buildAvoidList(snakeBody, obstaclesPos, enemiesList, foodPos, twinPos)
    local list = {}
    if snakeBody then
        for _, s in ipairs(snakeBody) do
            list[#list + 1] = {x = s.x, y = s.y, radius = 0}
        end
    end
    if obstaclesPos then
        for _, o in ipairs(obstaclesPos) do
            list[#list + 1] = {x = o.x, y = o.y, radius = 0}
        end
    end
    if enemiesList then
        for _, e in ipairs(enemiesList) do
            if e.alive then
                list[#list + 1] = {x = e.x, y = e.y, radius = 1}
            end
        end
    end
    if foodPos and foodPos.x and foodPos.y then
        list[#list + 1] = {x = foodPos.x, y = foodPos.y, radius = 0}
    end
    if twinPos and twinPos.x and twinPos.y then
        list[#list + 1] = {x = twinPos.x, y = twinPos.y, radius = 0}
    end
    return list
end

local function samplePosition(ancho, alto, avoidList, attempts, minDist)
    minDist = minDist or 1
    attempts = attempts or 60
    for _ = 1, attempts do
        local gx = love.math.random(0, ancho - 1)
        local gy = love.math.random(0, alto - 1)
        local valid = true
        for _, a in ipairs(avoidList) do
            local dist = math.abs(gx - a.x) + math.abs(gy - a.y)
            local reqDist = math.max(a.radius or 0, minDist)
            if dist < reqDist then
                valid = false
                break
            end
        end
        if valid then return gx, gy end
    end
    return nil, nil
end

local function reservePosition(avoidList, gx, gy, radius)
    table.insert(avoidList, {x = gx, y = gy, radius = radius or 2})
end

local function placeNEntities(spawnFn, count, ancho, alto, avoidList, params)
    params = params or {}
    local placed = 0
    local initialMinDist = params.minDist or 1
    local minFallback = 1
    for _ = 1, count do
        local gx, gy
        local curMinDist = initialMinDist
        while curMinDist >= minFallback do
            gx, gy = samplePosition(ancho, alto, avoidList, params.attempts or 60, curMinDist)
            if gx then break end
            curMinDist = math.floor(curMinDist / 2)
        end
        if gx then
            spawnFn(gx, gy)
            reservePosition(avoidList, gx, gy, params.avoidRadius or 2)
            placed = placed + 1
        else
            break
        end
    end
    return placed
end

function populate.populateRoom(worldOrSnake, snakeOrW, wOrH, hOrObs, obsOrFood, foodOrEnemies, enemiesOrObsMod, optObsMod)
    local world, snakeBody, anchoGrilla, altoGrilla, obstaclesList, foodMod, enemiesMod, obstaclesMod
    if type(snakeOrW) == "number" and type(wOrH) == "number" then
        world = require("world.world")
        snakeBody = worldOrSnake
        anchoGrilla = snakeOrW
        altoGrilla = wOrH
        obstaclesList = hOrObs
        foodMod = obsOrFood
        enemiesMod = foodOrEnemies
        obstaclesMod = enemiesOrObsMod
    else
        world = worldOrSnake or require("world.world")
        snakeBody = snakeOrW
        anchoGrilla = wOrH
        altoGrilla = hOrObs
        obstaclesList = obsOrFood
        foodMod = foodOrEnemies
        enemiesMod = enemiesOrObsMod
        obstaclesMod = optObsMod
    end

    local room = world.getCurrentRoom and world.getCurrentRoom()
    if not room then
        if foodMod and foodMod.generar then
            foodMod.generar(snakeBody, anchoGrilla, altoGrilla, obstaclesList)
        end
        if enemiesMod and enemiesMod.generar then
            enemiesMod.generar(snakeBody, foodMod and foodMod.pos, obstaclesList, anchoGrilla, altoGrilla, world.getModifier and world.getModifier() or {})
        end
        return
    end

    local template = world.roomTemplates and world.roomTemplates[room.template]
    if not template then
        if foodMod and foodMod.generar then
            foodMod.generar(snakeBody, anchoGrilla, altoGrilla, obstaclesList)
        end
        if enemiesMod and enemiesMod.generar then
            enemiesMod.generar(snakeBody, foodMod and foodMod.pos, obstaclesList, anchoGrilla, altoGrilla, world.getModifier and world.getModifier() or {})
        end
        return
    end

    local rules = template.spawnRules or {}
    local stageMod = (world.getStageMod and world.getStageMod()) or { countMult = 1.0, hpMult = 1.0 }
    local enemiesRules = rules.enemies or {}
    local foodRule = rules.food or {baseCount = 1}
    local obstaclesRule = rules.obstacles or {baseCount = 0}
    local bossRule = rules.boss
    local isBossRoom = (bossRule ~= nil) or (world.esJefe and world.esJefe())

    -- Build avoid list from snake body + existing obstacles + existing enemies + food
    local avoidList = buildAvoidList(
        snakeBody,
        (obstaclesMod and obstaclesMod.pos) or obstaclesList,
        enemiesMod and enemiesMod.list,
        foodMod and foodMod.pos,
        foodMod and foodMod.twinPos
    )

    -- 1. Si es sala de jefe, reservar PRIMERO el centro + 8 celdas adyacentes (área 3x3)
    -- para evitar que obstáculos, comida o adds aparezcan sobre el boss
    if isBossRoom then
        local cx = math.floor(anchoGrilla / 2)
        local cy = math.floor(altoGrilla / 2)
        for dx = -1, 1 do
            for dy = -1, 1 do
                local rx, ry = cx + dx, cy + dy
                if rx >= 0 and rx < anchoGrilla and ry >= 0 and ry < altoGrilla then
                    reservePosition(avoidList, rx, ry, 1)
                end
            end
        end
    end

    -- 2. Place obstacles y peligros ambientales de bioma
    local obsBase = obstaclesRule.baseCount or 0
    local obsCount = (obsBase > 0) and math.max(1, math.floor(obsBase * stageMod.countMult)) or 0
    if obsCount > 0 and obstaclesMod and obstaclesMod.spawnAt then
        local biomeIndex = world.etapa or 1
        placeNEntities(function(gx, gy)
            local rnd = love.math.random()
            local obsType = "wall"
            if biomeIndex == 2 then -- Cripta Helada
                obsType = (rnd < 0.70) and "ice" or "wall"
            elseif biomeIndex == 3 then -- Caverna Volcánica
                obsType = (rnd < 0.65) and "lava" or "wall"
            elseif biomeIndex == 4 then -- Colmena Tóxica
                obsType = (rnd < 0.65) and "slime" or "wall"
            elseif biomeIndex == 5 then -- Santuario del Vacío
                obsType = (rnd < 0.50) and "pressure_spike" or ((rnd < 0.75) and "trap" or "wall")
            else -- Catacumbas de Piedra
                obsType = (rnd < 0.25) and "trap" or "wall"
            end
            obstaclesMod.spawnAt(gx, gy, obsType)
        end, obsCount, anchoGrilla, altoGrilla, avoidList, {avoidRadius = 1, minDist = 1})
    end

    -- 3. Place food (one item; type based on room template odds)
    local foodType
    local r = love.math.random()
    if r < (foodRule.coinChance or 0.15) then
        foodType = constants.FOOD_COIN
    elseif r < ((foodRule.coinChance or 0.15) + (foodRule.goldChance or 0.15)) then
        foodType = constants.FOOD_GOLD
    else
        foodType = constants.FOOD_NORMAL
    end
    do
        local gx, gy = samplePosition(anchoGrilla, altoGrilla, avoidList, 60, 2)
        if gx then
            foodMod.generar(snakeBody, anchoGrilla, altoGrilla, (obstaclesMod and obstaclesMod.pos) or obstaclesList, foodType, gx, gy)
            reservePosition(avoidList, gx, gy, 1)
        else
            foodMod.generar(snakeBody, anchoGrilla, altoGrilla, (obstaclesMod and obstaclesMod.pos) or obstaclesList, foodType)
        end
    end

    -- 4. Place enemies using spawnAt and placement helpers
    local stageModifier = (world.getModifier and world.getModifier()) or {}
    local speedMult = stageModifier.enemySpeed or 1.0
    for _, erule in ipairs(enemiesRules) do
        local base = erule.baseCount or 1
        local count = math.max(0, math.floor(base * stageMod.countMult))
        for _ = 1, count do
            if love.math.random() <= (erule.weight or 1.0) then
                local spawnFn = function(gx, gy)
                    local pDirX, pDirY = nil, nil
                    if erule.type == "patroller" then
                        local function countClear(dx, dy)
                            local clear = 0
                            for dist = 1, 5 do
                                local cx, cy = gx + dx * dist, gy + dy * dist
                                if cx < 0 or cx >= anchoGrilla or cy < 0 or cy >= altoGrilla then break end
                                local blocked = false
                                for _, o in ipairs((obstaclesMod and obstaclesMod.pos) or obstaclesList or {}) do
                                    if o.x == cx and o.y == cy then blocked = true; break end
                                end
                                if blocked then break end
                                clear = clear + 1
                            end
                            return clear
                        end
                        local freeH = countClear(1, 0) + countClear(-1, 0)
                        local freeV = countClear(0, 1) + countClear(0, -1)
                        if freeH > freeV then
                            pDirX = (countClear(1, 0) >= countClear(-1, 0)) and 1 or -1
                            pDirY = 0
                        elseif freeV > freeH then
                            pDirX = 0
                            pDirY = (countClear(0, 1) >= countClear(0, -1)) and 1 or -1
                        end
                    end
                    local etapa = world.etapa or 1
                    local chaserInterval = math.max(0.15, (constants.ENEMY_CHASER_SPEED / speedMult) * (0.90 ^ (math.max(1, etapa) - 1)))
                    local params = {
                        moveInterval = (erule.type == "chaser" and chaserInterval)
                            or (erule.type == "patroller" and constants.ENEMY_PATROLLER_SPEED / speedMult)
                            or nil,
                        dirX = pDirX,
                        dirY = pDirY,
                    }
                    if enemiesMod and enemiesMod.spawnAt then
                        enemiesMod.spawnAt(erule.type, gx, gy, params)
                    end
                end
                placeNEntities(spawnFn, 1, anchoGrilla, altoGrilla, avoidList, {
                    avoidRadius = 3,
                    minDist = 8,
                    attempts = 40,
                })
            end
        end
    end

    -- 5. Boss room spawn
    if isBossRoom and enemiesMod and enemiesMod.spawnBoss then
        local hp = math.floor(((bossRule and bossRule.baseHP) or 3) * stageMod.hpMult)
        local coins = ((bossRule and bossRule.dropCoins) or 5) + (world.etapa or 1) * 2
        enemiesMod.spawnBoss(world.etapa or 1, anchoGrilla, altoGrilla, hp, coins)
    end
end

-- Export helpers for testing
populate.buildAvoidList = buildAvoidList
populate.samplePosition = samplePosition
populate.reservePosition = reservePosition
populate.placeNEntities = placeNEntities

return populate

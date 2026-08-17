local constants = require("constants")
local populate = {}

local function buildAvoidList(snakeBody, obstaclesPos, enemiesList, foodPos)
    local list = {}
    for _, s in ipairs(snakeBody) do
        list[#list + 1] = {x = s.x, y = s.y, radius = 0}
    end
    for _, o in ipairs(obstaclesPos) do
        list[#list + 1] = {x = o.x, y = o.y, radius = 0}
    end
    for _, e in ipairs(enemiesList) do
        if e.alive then
            list[#list + 1] = {x = e.x, y = e.y, radius = 1}
        end
    end
    if foodPos then
        list[#list + 1] = {x = foodPos.x, y = foodPos.y, radius = 0}
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
            if dist < (a.radius or minDist) then
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
    for _ = 1, count do
        local gx, gy = samplePosition(ancho, alto, avoidList, params.attempts or 60, params.minDist or 1)
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

function populate.populateRoom(world, snakeBody, anchoGrilla, altoGrilla, obstaclesList, foodMod, enemiesMod, obstaclesMod)
    local room = world.getCurrentRoom()
    if not room then
        foodMod.generar(snakeBody, anchoGrilla, altoGrilla, obstaclesList)
        enemiesMod.generar(snakeBody, foodMod.pos, obstaclesList, anchoGrilla, altoGrilla, world.getModifier())
        return
    end

    local template = world.roomTemplates[room.template]
    if not template then
        foodMod.generar(snakeBody, anchoGrilla, altoGrilla, obstaclesList)
        enemiesMod.generar(snakeBody, foodMod.pos, obstaclesList, anchoGrilla, altoGrilla, world.getModifier())
        return
    end

    local rules = template.spawnRules
    local stageMod = world.getStageMod()
    local enemiesRules = rules.enemies or {}
    local foodRule = rules.food or {baseCount = 1}
    local obstaclesRule = rules.obstacles or {baseCount = 0}
    local bossRule = rules.boss

    -- Build avoid list from snake body + existing obstacles + existing enemies
    local avoidList = buildAvoidList(snakeBody, obstaclesMod.pos, enemiesMod.list, foodMod.pos)

    -- Place obstacles first (so food/enemies can avoid them)
    local obsCount = math.max(1, math.floor(obstaclesRule.baseCount * stageMod.countMult))
    if obsCount > 0 then
        placeNEntities(function(gx, gy)
            obstaclesMod.spawnAt(gx, gy)
        end, obsCount, anchoGrilla, altoGrilla, avoidList, {avoidRadius = 1, minDist = 1})
    end

    -- Si es sala de jefe, reservar centro + 8 celdas adyacentes para evitar que comida
    -- o enemigos aparezcan sobre el boss
    if bossRule and world.esJefe() then
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

    -- Place food (one item; type based on room template odds)
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
            foodMod.generar(snakeBody, anchoGrilla, altoGrilla, obstaclesMod.pos, foodType, gx, gy)
            reservePosition(avoidList, gx, gy, 1)
        else
            foodMod.generar(snakeBody, anchoGrilla, altoGrilla, obstaclesMod.pos, foodType)
        end
    end

    -- Place enemies using spawnAt and placement helpers
    local stageModifier = world.getModifier()
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
                                for _, o in ipairs(obstaclesMod.pos or {}) do
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
                    enemiesMod.spawnAt(erule.type, gx, gy, params)
                end
                placeNEntities(spawnFn, 1, anchoGrilla, altoGrilla, avoidList, {
                    avoidRadius = 3,
                    minDist = 8,
                    attempts = 40,
                })
            end
        end
    end

    -- Boss room
    if bossRule and world.esJefe() then
        local hp = math.floor((bossRule.baseHP or 3) * stageMod.hpMult)
        local coins = (bossRule.dropCoins or 5) + world.etapa * 2
        enemiesMod.spawnBoss(world.etapa, anchoGrilla, altoGrilla, hp, coins)
    end
end

return populate

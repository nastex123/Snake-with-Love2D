local constants = require("constants")
local dungeonGen = {}

dungeonGen.stageModifiers = {
    [1] = { biome = "catacumbas", name = "Catacumbas de Piedra", wallWrap = true, spawnRate = 1.0, enemySpeed = 1.0, chaserWeight = 0.40, patrollerWeight = 0.35, spawnerWeight = 0.25, targetMult = 1.0, bossVida = 3 },
    [2] = { biome = "hielo", name = "Cripta Helada", wallWrap = true, isIce = true, spawnRate = 1.2, enemySpeed = 1.15, chaserWeight = 0.50, patrollerWeight = 0.30, spawnerWeight = 0.20, targetMult = 1.3, bossVida = 4 },
    [3] = { biome = "volcan", name = "Caverna Volcánica", wallWrap = true, hazardLava = true, spawnRate = 1.4, enemySpeed = 1.3, chaserWeight = 0.35, patrollerWeight = 0.30, spawnerWeight = 0.35, targetMult = 1.6, bossVida = 5 },
    [4] = { biome = "colmena", name = "Colmena Tóxica", wallWrap = true, isSlime = true, spawnRate = 1.6, enemySpeed = 1.5, chaserWeight = 0.50, patrollerWeight = 0.20, spawnerWeight = 0.30, targetMult = 2.0, bossVida = 6 },
    [5] = { biome = "vacio", name = "Santuario del Vacío", wallWrap = false, spawnRate = 2.0, enemySpeed = 1.8, chaserWeight = 0.40, patrollerWeight = 0.25, spawnerWeight = 0.35, targetMult = 2.5, bossVida = 8 },
}

-- Stage modifiers map (countMult, hpMult, spawnMult, objectiveMult)
dungeonGen.stageMod = {
    [1] = { countMult = 1.0, hpMult = 1.0, objMult = 1.0, bossHP = 3 },
    [2] = { countMult = 1.2, hpMult = 1.15, objMult = 1.3, bossHP = 4 },
    [3] = { countMult = 1.4, hpMult = 1.3, objMult = 1.6, bossHP = 5 },
    [4] = { countMult = 1.7, hpMult = 1.6, objMult = 2.0, bossHP = 6 },
    [5] = { countMult = 2.0, hpMult = 2.2, objMult = 2.5, bossHP = 8 },
}

-- Room template registry with spawn rules
dungeonGen.roomTemplates = {
    corridor = {
        id = "corridor",
        name = "Pasillo",
        weight = 0.25,
        objectiveBase = 30,
        constraints = { minW = 5, minH = 5 },
        spawnRules = {
            enemies = {
                { type = "patroller", baseCount = 1, weight = 0.5 },
            },
            food = { baseCount = 1, goldChance = 0.10, coinChance = 0.15 },
            obstacles = { baseCount = 0 },
            items = { chance = 0 },
        },
    },
    arena = {
        id = "arena",
        name = "Arena",
        weight = 0.30,
        objectiveBase = 60,
        constraints = { minW = 7, minH = 7 },
        spawnRules = {
            enemies = {
                { type = "chaser", baseCount = 3, weight = 1.0 },
                { type = "patroller", baseCount = 1, weight = 0.4 },
            },
            food = { baseCount = 1, goldChance = 0.20, coinChance = 0.10 },
            obstacles = { baseCount = 3 },
            items = { chance = 0.15, possible = {"extraCoin"} },
        },
    },
    choke = {
        id = "choke",
        name = "Embudo",
        weight = 0.15,
        objectiveBase = 50,
        constraints = { minW = 5, minH = 5 },
        spawnRules = {
            enemies = {
                { type = "chaser", baseCount = 2, weight = 1.0 },
                { type = "spawner", baseCount = 1, weight = 0.3 },
            },
            food = { baseCount = 1, goldChance = 0.10, coinChance = 0.10 },
            obstacles = { baseCount = 4 },
            items = { chance = 0 },
        },
    },
    hub = {
        id = "hub",
        name = "Encrucijada",
        weight = 0.10,
        objectiveBase = 80,
        constraints = { minW = 9, minH = 7 },
        spawnRules = {
            enemies = {
                { type = "chaser", baseCount = 2, weight = 1.0 },
                { type = "patroller", baseCount = 2, weight = 0.6 },
                { type = "spawner", baseCount = 1, weight = 0.2 },
            },
            food = { baseCount = 2, goldChance = 0.25, coinChance = 0.20 },
            obstacles = { baseCount = 2 },
            items = { chance = 0.30, possible = {"extraCoin", "speedReducer"} },
        },
    },
    treasure = {
        id = "treasure",
        name = "Tesoro",
        weight = 0.08,
        objectiveBase = 30,
        constraints = { minW = 5, minH = 5 },
        spawnRules = {
            enemies = {
                { type = "chaser", baseCount = 1, weight = 0.3 },
            },
            food = { baseCount = 1, goldChance = 0.60, coinChance = 0.30 },
            obstacles = { baseCount = 1 },
            items = { chance = 0.80, possible = {"extraCoin", "speedReducer", "hunger"} },
        },
    },
    spawner = {
        id = "spawner",
        name = "Nido",
        weight = 0.07,
        objectiveBase = 70,
        constraints = { minW = 6, minH = 6 },
        spawnRules = {
            enemies = {
                { type = "spawner", baseCount = 2, weight = 1.0 },
                { type = "chaser", baseCount = 1, weight = 0.5 },
            },
            food = { baseCount = 1, goldChance = 0.10, coinChance = 0.10 },
            obstacles = { baseCount = 3 },
            items = { chance = 0 },
        },
    },
    boss = {
        id = "boss",
        name = "Jefe",
        weight = 0,
        objectiveBase = 100,
        constraints = { minW = 8, minH = 8 },
        spawnRules = {
            enemies = {},
            food = { baseCount = 0 },
            obstacles = { baseCount = 0 },
            items = { chance = 0 },
            boss = { baseHP = 3, dropCoins = 5 },
        },
    },
}

-- Template IDs ordered by weight for selection
local templateIds = {"corridor", "arena", "choke", "hub", "treasure", "spawner"}

function dungeonGen.getStageModifier(stage)
    local s = math.max(1, math.min(5, stage or 1))
    return dungeonGen.stageModifiers[s] or dungeonGen.stageModifiers[1]
end

function dungeonGen.getStageMod(stage)
    local s = math.max(1, math.min(5, stage or 1))
    return dungeonGen.stageMod[s] or dungeonGen.stageMod[1]
end

function dungeonGen.getRoomTemplate(templateId)
    return dungeonGen.roomTemplates[templateId]
end

function dungeonGen.getTemplateIds()
    local copy = {}
    for i, v in ipairs(templateIds) do copy[i] = v end
    return copy
end

local function bspSplit(rect, depth, maxDepth, minLeaf, minReqW, minReqH)
    if depth >= maxDepth then return {rect} end
    
    local minSplitW = math.max(minLeaf, minReqW or 150)
    local minSplitH = math.max(minLeaf, minReqH or 120)
    
    local canSplitH = rect.w >= minSplitW * 2
    local canSplitV = rect.h >= minSplitH * 2
    
    if not canSplitH and not canSplitV then
        return {rect}
    end
    
    local splitH
    if canSplitH and canSplitV then
        if rect.w >= rect.h * 1.25 then
            splitH = true
        elseif rect.h >= rect.w * 1.25 then
            splitH = false
        else
            splitH = (love.math.random() < 0.5)
        end
    elseif canSplitH then
        splitH = true
    else
        splitH = false
    end
    
    local childA, childB
    if splitH then
        local minCut = minSplitW
        local maxCut = rect.w - minSplitW
        if minCut > maxCut then return {rect} end
        local cut = (minCut == maxCut) and minCut or love.math.random(minCut, maxCut)
        childA = { x = rect.x, y = rect.y, w = cut, h = rect.h }
        childB = { x = rect.x + cut, y = rect.y, w = rect.w - cut, h = rect.h }
    else
        local minCut = minSplitH
        local maxCut = rect.h - minSplitH
        if minCut > maxCut then return {rect} end
        local cut = (minCut == maxCut) and minCut or love.math.random(minCut, maxCut)
        childA = { x = rect.x, y = rect.y, w = rect.w, h = cut }
        childB = { x = rect.x, y = rect.y + cut, w = rect.w, h = rect.h - cut }
    end
    
    local leaves = {}
    for _, r in ipairs(bspSplit(childA, depth + 1, maxDepth, minLeaf, minReqW, minReqH)) do table.insert(leaves, r) end
    for _, r in ipairs(bspSplit(childB, depth + 1, maxDepth, minLeaf, minReqW, minReqH)) do table.insert(leaves, r) end
    return leaves
end

local function carveRoomInLeaf(leaf, minW, minH, maxW, maxH, padding)
    local pad = padding or 15
    local availW = math.max(10, leaf.w - pad * 2)
    local availH = math.max(10, leaf.h - pad * 2)
    
    local rMinW = math.min(minW, availW)
    local rMaxW = math.max(rMinW, math.min(maxW, availW))
    local roomW = (rMinW >= rMaxW) and rMinW or love.math.random(rMinW, rMaxW)
    
    local rMinH = math.min(minH, availH)
    local rMaxH = math.max(rMinH, math.min(maxH, availH))
    local roomH = (rMinH >= rMaxH) and rMinH or love.math.random(rMinH, rMaxH)
    
    local maxOx = math.max(0, availW - roomW)
    local maxOy = math.max(0, availH - roomH)
    local ox = maxOx > 0 and love.math.random(0, maxOx) or 0
    local oy = maxOy > 0 and love.math.random(0, maxOy) or 0
    
    return {
        x = leaf.x + pad + ox,
        y = leaf.y + pad + oy,
        w = roomW,
        h = roomH,
    }
end

local function corridorPath(ax, ay, bx, by, width)
    local tiles = {}
    local x, y = ax, ay
    local w = width or 20
    local step = math.max(1, math.ceil(w / 2))
    local dirX = bx >= ax and step or -step
    local dirY = by >= ay and step or -step
    
    if love.math.random() < 0.5 then
        -- horizontal first, then vertical
        while math.abs(x - bx) > step do
            x = x + dirX
            table.insert(tiles, {x = x, y = y, w = w, h = w})
        end
        x = bx
        table.insert(tiles, {x = x, y = y, w = w, h = w})
        while math.abs(y - by) > step do
            y = y + dirY
            table.insert(tiles, {x = x, y = y, w = w, h = w})
        end
    else
        -- vertical first, then horizontal
        while math.abs(y - by) > step do
            y = y + dirY
            table.insert(tiles, {x = x, y = y, w = w, h = w})
        end
        y = by
        table.insert(tiles, {x = x, y = y, w = w, h = w})
        while math.abs(x - bx) > step do
            x = x + dirX
            table.insert(tiles, {x = x, y = y, w = w, h = w})
        end
    end
    -- final step
    table.insert(tiles, {x = bx, y = by, w = w, h = w})
    return tiles
end

local function selectTemplateForRoom(roomRect, roomIndex, totalRooms)
    local isLast = (roomIndex == totalRooms)
    if isLast then return "boss" end
    local isFirst = (roomIndex == 1)
    
    -- Weight selection based on room size, position, and stage
    local weights = {}
    for _, tid in ipairs(templateIds) do
        local tpl = dungeonGen.roomTemplates[tid]
        local w = tpl.weight
        -- Arena more likely for large rooms
        if roomRect.w >= 180 and roomRect.h >= 150 and tid == "arena" then
            w = w * 1.5
        end
        -- Corridor more likely for narrow rooms
        if (roomRect.w < 140 or roomRect.h < 110) and tid == "corridor" then
            w = w * 1.5
        end
        -- Treasure weighted toward later rooms but not last
        if roomIndex >= 3 and tid == "treasure" then
            w = w * 1.3
        end
        -- First room more likely hub or arena
        if isFirst and (tid == "hub" or tid == "arena") then
            w = w * 1.5
        end
        table.insert(weights, {tid = tid, w = w})
    end
    
    local totalW = 0
    for _, e in ipairs(weights) do totalW = totalW + e.w end
    local r = love.math.random() * totalW
    local accum = 0
    for _, e in ipairs(weights) do
        accum = accum + e.w
        if r <= accum then return e.tid end
    end
    return "arena"
end

function dungeonGen.checkConnectivity(dungeon)
    if not dungeon or not dungeon.rooms or #dungeon.rooms == 0 then return false, 0 end
    local numRooms = #dungeon.rooms
    if numRooms == 1 then return true, 1 end
    
    local adj = {}
    for i = 1, numRooms do adj[i] = {} end
    
    for _, corr in ipairs(dungeon.corridors or {}) do
        if corr.from and corr.to and adj[corr.from] and adj[corr.to] then
            adj[corr.from][corr.to] = true
            adj[corr.to][corr.from] = true
        end
    end
    
    local visited = {}
    local queue = { 1 }
    visited[1] = true
    local count = 1
    local head = 1
    
    while head <= #queue do
        local curr = queue[head]
        head = head + 1
        for neighbor in pairs(adj[curr]) do
            if not visited[neighbor] then
                visited[neighbor] = true
                count = count + 1
                table.insert(queue, neighbor)
            end
        end
    end
    
    return count == numRooms, count
end

-- Expose internal helper functions for testing/diagnostics
dungeonGen._bspSplit = bspSplit
dungeonGen._carveRoomInLeaf = carveRoomInLeaf
dungeonGen._corridorPath = corridorPath
dungeonGen._selectTemplateForRoom = selectTemplateForRoom

function dungeonGen.generar(worldOrW, anchoVirtualOrH, altoVirtualOrRooms, targetRoomsOrSeed, optionalSeed)
    local worldObj
    local vw, vh, n, seed
    
    if type(worldOrW) == "table" then
        worldObj = worldOrW
        vw = anchoVirtualOrH or constants.DUNGEON_VIRTUAL_W or 800
        vh = altoVirtualOrRooms or constants.DUNGEON_VIRTUAL_H or 600
        n = targetRoomsOrSeed or constants.DUNGEON_TARGET_ROOMS or 5
        seed = optionalSeed
    else
        -- Called as generar(anchoVirtual, altoVirtual, targetRooms, seed)
        worldObj = {}
        vw = worldOrW or constants.DUNGEON_VIRTUAL_W or 800
        vh = anchoVirtualOrH or constants.DUNGEON_VIRTUAL_H or 600
        n = altoVirtualOrRooms or constants.DUNGEON_TARGET_ROOMS or 5
        seed = targetRoomsOrSeed
    end
    
    if n < 1 then n = 1 end
    if vw < 200 then vw = 200 end
    if vh < 200 then vh = 200 end
    
    if seed ~= nil then
        love.math.setRandomSeed(seed)
    else
        local stageNum = (type(worldObj) == "table" and type(worldObj.etapa) == "number") and worldObj.etapa or 1
        love.math.setRandomSeed(os.time() + stageNum * 1000 + love.math.random(1, 99999))
    end
    
    local minLeaf = constants.DUNGEON_BSP_MIN_LEAF or 180
    local minW = constants.DUNGEON_MIN_ROOM_W or 120
    local minH = constants.DUNGEON_MIN_ROOM_H or 90
    local maxW = constants.DUNGEON_MAX_ROOM_W or 250
    local maxH = constants.DUNGEON_MAX_ROOM_H or 200
    local padding = constants.DUNGEON_ROOM_PADDING or 15
    local corrW = constants.DUNGEON_CORRIDOR_WIDTH or 20
    
    local minReqW = minW + padding * 2
    local minReqH = minH + padding * 2
    local minSplitW = math.max(minLeaf, minReqW)
    local minSplitH = math.max(minLeaf, minReqH)
    
    -- Calculate max BSP depth to get at least n leaves
    local maxDepth = math.max(1, math.ceil(math.log(math.max(2, n)) / math.log(2)) + 2)
    local root = { x = 0, y = 0, w = vw, h = vh }
    local leaves = bspSplit(root, 0, maxDepth, minLeaf, minReqW, minReqH)
    
    -- Truncate or pad leaves to match n
    while #leaves < n do
        -- Find largest leaf that can still be split
        local largestArea, li = 0, nil
        for i, l in ipairs(leaves) do
            local canSplit = (l.w >= minSplitW * 2) or (l.h >= minSplitH * 2)
            if canSplit then
                local area = l.w * l.h
                if area > largestArea then
                    largestArea = area
                    li = i
                end
            end
        end
        
        if li then
            local l = leaves[li]
            local sub = {}
            local canSplitH = l.w >= minSplitW * 2
            local canSplitV = l.h >= minSplitH * 2
            
            if canSplitH and (l.w >= l.h or not canSplitV) then
                local cut = (minSplitW == l.w - minSplitW) and minSplitW or love.math.random(minSplitW, l.w - minSplitW)
                sub = {{x = l.x, y = l.y, w = cut, h = l.h}, {x = l.x + cut, y = l.y, w = l.w - cut, h = l.h}}
            elseif canSplitV then
                local cut = (minSplitH == l.h - minSplitH) and minSplitH or love.math.random(minSplitH, l.h - minSplitH)
                sub = {{x = l.x, y = l.y, w = l.w, h = cut}, {x = l.x, y = l.y + cut, w = l.w, h = l.h - cut}}
            else
                break
            end
            
            table.remove(leaves, li)
            for _, s in ipairs(sub) do table.insert(leaves, s) end
        else
            break
        end
    end
    
    -- Cap to n rooms
    while #leaves > n do table.remove(leaves) end
    
    -- If no leaves generated (e.g. root smaller than minLeaf), fallback to root
    if #leaves == 0 then
        leaves = { { x = 0, y = 0, w = vw, h = vh } }
    end
    
    -- Carve rooms in leaves
    local rooms = {}
    for _, leaf in ipairs(leaves) do
        local rect = carveRoomInLeaf(leaf, minW, minH, maxW, maxH, padding)
        table.insert(rooms, rect)
    end
    
    -- Sort rooms left to right for natural progression
    table.sort(rooms, function(a, b) return a.x + a.y * 0.1 < b.x + b.y * 0.1 end)
    
    -- Assign templates (sala 3 = encuentro élite con mini-jefe, GDD §5)
    for i, rect in ipairs(rooms) do
        local tid = selectTemplateForRoom(rect, i, #rooms)
        local tpl = dungeonGen.roomTemplates[tid] or dungeonGen.roomTemplates.arena
        rooms[i] = {
            id = i,
            rect = rect,
            template = tid,
            name = tpl.name,
            objectiveBase = tpl.objectiveBase,
            centerX = rect.x + rect.w / 2,
            centerY = rect.y + rect.h / 2,
            visited = (i == 1),
            cleared = false,
            isElite = (i == 3),
        }
    end
    
    -- Build corridors connecting consecutive rooms + some random extra edges
    local corridors = {}
    local roomGraph = {}
    for i = 1, #rooms do roomGraph[i] = {} end
    for i = 1, #rooms - 1 do
        local a, b = rooms[i], rooms[i + 1]
        local pts = corridorPath(a.centerX, a.centerY, b.centerX, b.centerY, corrW)
        local edge = {from = i, to = i + 1, path = pts}
        table.insert(corridors, edge)
        roomGraph[i][i + 1] = true
        roomGraph[i + 1][i] = true
    end
    
    -- Add some random extra connections (loops)
    if #rooms >= 3 then
        local extraEdges = love.math.random(0, math.floor(#rooms / 3))
        for _ = 1, extraEdges do
            local a = love.math.random(1, #rooms)
            local b = love.math.random(1, #rooms)
            if a ~= b and not roomGraph[a][b] and math.abs(a - b) > 1 then
                local pts = corridorPath(rooms[a].centerX, rooms[a].centerY, rooms[b].centerX, rooms[b].centerY, corrW)
                table.insert(corridors, {from = a, to = b, path = pts})
                roomGraph[a][b] = true
                roomGraph[b][a] = true
            end
        end
    end
    
    local dungeonData = {
        rooms = rooms,
        corridors = corridors,
        roomGraph = roomGraph,
        virtualW = vw,
        virtualH = vh,
    }
    
    if type(worldObj) == "table" then
        worldObj.dungeon = dungeonData
        worldObj.sala = 1
        worldObj.puntajeSala = 0
        if type(worldObj.calcularObjetivo) == "function" then
            local ok, obj = pcall(function() return worldObj:calcularObjetivo() end)
            if not ok or type(obj) ~= "number" then
                ok, obj = pcall(function() return worldObj.calcularObjetivo() end)
            end
            worldObj.objetivoSala = (ok and type(obj) == "number") and obj or 50
        else
            worldObj.objetivoSala = 50
        end
    end
    
    return dungeonData
end

return dungeonGen

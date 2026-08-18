local constants = require("constants")
local dungeonGen = {}

dungeonGen.stageModifiers = {
    [1] = { spawnRate = 1.0, enemySpeed = 1.0, chaserWeight = 0.40, patrollerWeight = 0.35, spawnerWeight = 0.25, targetMult = 1.0, bossVida = 3 },
    [2] = { spawnRate = 1.2, enemySpeed = 1.15, chaserWeight = 0.50, patrollerWeight = 0.30, spawnerWeight = 0.20, targetMult = 1.3, bossVida = 4 },
    [3] = { spawnRate = 1.4, enemySpeed = 1.3, chaserWeight = 0.35, patrollerWeight = 0.30, spawnerWeight = 0.35, targetMult = 1.6, bossVida = 5 },
    [4] = { spawnRate = 1.6, enemySpeed = 1.5, chaserWeight = 0.50, patrollerWeight = 0.20, spawnerWeight = 0.30, targetMult = 2.0, bossVida = 6 },
    [5] = { spawnRate = 2.0, enemySpeed = 1.8, chaserWeight = 0.40, patrollerWeight = 0.25, spawnerWeight = 0.35, targetMult = 2.5, bossVida = 8 },
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

local function bspSplit(rect, depth, maxDepth, minLeaf)
    if depth >= maxDepth then return {rect} end
    local splitH = rect.w > rect.h and rect.w >= rect.h * 1.3
    local splitV = rect.h > rect.w and rect.h >= rect.w * 1.3
    if not splitH and not splitV then
        if love.math.random() < 0.5 then splitH = true else splitV = true end
    end
    local half, remainder, childA, childB
    if splitH then
        half = math.floor(rect.w / 2)
        if half < minLeaf then return {rect} end
        local cut = love.math.random(math.floor(minLeaf * 0.7), math.min(half + math.floor(minLeaf * 0.3), rect.w - minLeaf))
        childA = { x = rect.x, y = rect.y, w = cut, h = rect.h }
        childB = { x = rect.x + cut, y = rect.y, w = rect.w - cut, h = rect.h }
    else
        half = math.floor(rect.h / 2)
        if half < minLeaf then return {rect} end
        local cut = love.math.random(math.floor(minLeaf * 0.7), math.min(half + math.floor(minLeaf * 0.3), rect.h - minLeaf))
        childA = { x = rect.x, y = rect.y, w = rect.w, h = cut }
        childB = { x = rect.x, y = rect.y + cut, w = rect.w, h = rect.h - cut }
    end
    local leaves = {}
    for _, r in ipairs(bspSplit(childA, depth + 1, maxDepth, minLeaf)) do table.insert(leaves, r) end
    for _, r in ipairs(bspSplit(childB, depth + 1, maxDepth, minLeaf)) do table.insert(leaves, r) end
    return leaves
end

local function carveRoomInLeaf(leaf, minW, minH, maxW, maxH, padding)
    local roomW = love.math.random(minW, math.min(maxW, leaf.w - padding * 2))
    local roomH = love.math.random(minH, math.min(maxH, leaf.h - padding * 2))
    local maxOx = leaf.w - padding - roomW
    local maxOy = leaf.h - padding - roomH
    local ox = maxOx > 0 and love.math.random(0, maxOx) or 0
    local oy = maxOy > 0 and love.math.random(0, maxOy) or 0
    return {
        x = leaf.x + padding + ox,
        y = leaf.y + padding + oy,
        w = roomW,
        h = roomH,
    }
end

local function corridorPath(ax, ay, bx, by, width)
    local tiles = {}
    local x, y = ax, ay
    local step = math.ceil(width / 2)
    if love.math.random() < 0.5 then
        -- horizontal first, then vertical
        while math.abs(x - bx) > step do
            x = x + (bx > ax and step or -step)
            table.insert(tiles, {x = x, y = y, w = width, h = width})
        end
        while math.abs(y - by) > step do
            y = y + (by > ay and step or -step)
            table.insert(tiles, {x = x, y = y, w = width, h = width})
        end
    else
        -- vertical first, then horizontal
        while math.abs(y - by) > step do
            y = y + (by > ay and step or -step)
            table.insert(tiles, {x = x, y = y, w = width, h = width})
        end
        while math.abs(x - bx) > step do
            x = x + (bx > ax and step or -step)
            table.insert(tiles, {x = x, y = y, w = width, h = width})
        end
    end
    -- final step
    table.insert(tiles, {x = bx, y = by, w = width, h = width})
    return tiles
end

local function selectTemplateForRoom(roomRect, roomIndex, totalRooms)
    local isLast = roomIndex == totalRooms
    if isLast then return "boss" end
    local isFirst = roomIndex == 1
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

function dungeonGen.generar(world, anchoVirtual, altoVirtual, targetRooms)
    love.math.setRandomSeed(os.time() + world.etapa * 1000 + love.math.random(1, 99999))
    local vw = anchoVirtual or constants.DUNGEON_VIRTUAL_W
    local vh = altoVirtual or constants.DUNGEON_VIRTUAL_H
    local n = targetRooms or constants.DUNGEON_TARGET_ROOMS
    local minLeaf = constants.DUNGEON_BSP_MIN_LEAF
    local minW = constants.DUNGEON_MIN_ROOM_W
    local minH = constants.DUNGEON_MIN_ROOM_H
    local maxW = constants.DUNGEON_MAX_ROOM_W
    local maxH = constants.DUNGEON_MAX_ROOM_H
    local padding = constants.DUNGEON_ROOM_PADDING
    local corrW = constants.DUNGEON_CORRIDOR_WIDTH
    -- Calculate max BSP depth to get at least n leaves
    local maxDepth = math.ceil(math.log(n) / math.log(2)) + 2
    local root = { x = 0, y = 0, w = vw, h = vh }
    local leaves = bspSplit(root, 0, maxDepth, minLeaf)
    -- Truncate or pad leaves to match n
    while #leaves < n do
        -- re-split largest leaf
        local largest, li = nil, nil
        for i, l in ipairs(leaves) do
            local area = l.w * l.h
            if not largest or area > largest then
                largest = area
                li = i
            end
        end
        if li then
            local l = leaves[li]
            local sub = {}
            if l.w > l.h then
                local cut = math.floor(l.w / 2)
                sub = {{x=l.x, y=l.y, w=cut, h=l.h}, {x=l.x+cut, y=l.y, w=l.w-cut, h=l.h}}
            else
                local cut = math.floor(l.h / 2)
                sub = {{x=l.x, y=l.y, w=l.w, h=cut}, {x=l.x, y=l.y+cut, w=l.w, h=l.h-cut}}
            end
            table.remove(leaves, li)
            for _, s in ipairs(sub) do table.insert(leaves, s) end
        else
            break
        end
    end
    -- Cap to n rooms
    while #leaves > n do table.remove(leaves) end
    -- Carve rooms in leaves
    local rooms = {}
    for _, leaf in ipairs(leaves) do
        local rect = carveRoomInLeaf(leaf, minW, minH, maxW, maxH, padding)
        table.insert(rooms, rect)
    end
    -- Sort rooms left to right for natural progression
    table.sort(rooms, function(a, b) return a.x + a.y * 0.1 < b.x + b.y * 0.1 end)
    -- Assign templates
    for i, rect in ipairs(rooms) do
        local tid = selectTemplateForRoom(rect, i, #rooms)
        local tpl = dungeonGen.roomTemplates[tid]
        rooms[i] = {
            id = i,
            rect = rect,
            template = tid,
            name = tpl.name,
            objectiveBase = tpl.objectiveBase,
            centerX = rect.x + rect.w / 2,
            centerY = rect.y + rect.h / 2,
            visited = false,
            cleared = false,
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
    world.dungeon = {
        rooms = rooms,
        corridors = corridors,
        roomGraph = roomGraph,
        virtualW = vw,
        virtualH = vh,
    }
    world.sala = 1
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
    if world.dungeon.rooms[1] then
        world.dungeon.rooms[1].visited = true
    end
end

return dungeonGen

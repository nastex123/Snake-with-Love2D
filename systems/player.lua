-- systems/player.lua — Helpers de jugador/items (sin globals, estado via core.world)
local player = {}
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end
local hasEvents, Events = pcall(require, "core.events")
if not hasEvents or type(Events) ~= "table" then Events = nil end
local shop = require("systems.shop")
local foodMod = require("entities.food")
local obstaclesMod = require("entities.obstacles")
local enemiesMod = require("entities.enemies")
local snakeMod = require("entities.snake")
local particles = require("render.particles")
local sound = require("audio.sound")
local uiMod = require("ui.ui")
local achievementsMod = require("systems.achievements")
local itemsMod = require("systems.items")

--- Cálculo exhaustivo de velocidad del jugador considerando base, frutas y modificadores.
-- @param base number: velocidad base (segundos por paso, default VELOCIDAD_INICIAL)
-- @param fruits number: frutas comidas
-- @param opts table|nil: modificadores opcionales ({turbo, speedReducer, slowdown, isSlime})
-- @return number: velocidad resultante en segundos por casilla (clamped a [VELOCIDAD_MINIMA, MAX_BASE_SPEED])
function player.calcSpeed(base, fruits, opts)
    opts = opts or {}
    local st = world.state
    base = base or (st and st.baseSpeed) or constants.VELOCIDAD_INICIAL
    fruits = fruits or (st and st.frutasContador) or 0

    local speedReduction = math.floor(fruits / 5) * constants.SPEED_ADJUST_INCREMENT
    local current = math.max(constants.VELOCIDAD_MINIMA, base - speedReduction)

    -- Evaluar Turbo activo (vía parámetro explícito o timers pool)
    local hasTurbo = opts.turbo
    if hasTurbo == nil and st and st.activeTimers then
        for _, t in ipairs(st.activeTimers) do
            if t.id == "turbo" then
                if t._handle and timers.isActive(t._handle) then
                    hasTurbo = true
                    break
                elseif not t._handle and t.remaining and t.remaining > 0 then
                    -- compatibilidad con inserts manuales de tests (sin _handle)
                    hasTurbo = true
                    break
                end
            end
        end
    end
    if hasTurbo then
        current = current * (constants.TURBO_MULTIPLIER or 0.7)
    end

    -- Evaluar ralentizaciones de terreno o debuffs (e.g. Baba Slime 1.25x)
    if opts.isSlime or opts.slowdown then
        local factor = type(opts.slowdown) == "number" and opts.slowdown or 1.25
        -- Botas Ligeras (GDD item 55): reducen la penalizacion a la mitad
        if opts.isSlime and shop.inventory and shop.inventory.lightBoots then
            factor = 1 + (factor - 1) * 0.5
        end
        current = current * factor
    end

    return math.max(constants.VELOCIDAD_MINIMA, math.min(constants.MAX_BASE_SPEED, current))
end

--- Wrapper retrocompatible para calculateCurrentSpeed
function player.calculateCurrentSpeed(base, fruits, opts)
    return player.calcSpeed(base, fruits, opts)
end

function player.itemColor(itemId)
    local colors = {
        shield = {0, 0.85, 1}, armor = {0.3, 0.7, 1}, ghost = {0.6, 0.4, 1},
        magnet = {0, 0.85, 1}, bomb = {1, 0.4, 0.2}, hunger = {1, 0.6, 0.2},
        speedReducer = {0.2, 0.9, 0.3}, speed_reducer = {0.2, 0.9, 0.3},
        turbo = {0, 1, 0.5}, slow = {0.5, 0.5, 1},
        doubler = {1, 0.84, 0}, extraCoin = {1, 0.84, 0}, extra_coin = {1, 0.84, 0},
        star = {1, 0.84, 0},
        tailSpike = {1, 0.3, 0.3}, hourglass = {0.5, 0.8, 1},
        orbitalBeam = {0.4, 0.9, 1}, holoDecoy = {0.7, 0.2, 0.9},
        lightBoots = {0.4, 1, 0.6}, goldenTooth = {1, 0.75, 0.1},
        emergencyBattery = {1, 0.2, 0.2}, doubleHarvest = {0.3, 1, 0.3},
        lottery = {1, 0.9, 0.3}, refractorPrism = {0.8, 0.5, 1}
    }
    local c = colors[itemId]
    if not c and itemsMod and itemsMod.get then
        local def = itemsMod.get(itemId)
        if def and colors[def.id] then
            c = colors[def.id]
        end
    end
    return c and c[1] or 1, c and c[2] or 1, c and c[3] or 1
end

--- Helper interno para refrescar o añadir un temporizador vía core/timers pool (HUD visible en activeTimers)
local function addOrRefreshTimer(st, timerId, duration, onEndFn)
    duration = math.max(0, duration or 0)
    -- Buscar existente
    for _, t in ipairs(st.activeTimers) do
        if t.id == timerId then
            if t._handle then timers.cancel(t._handle) end
            t.duration = duration
            t.remaining = duration
            t.onEnd = onEndFn
            -- crear nuevo handle pooled
            local handle = timers.after(duration, function()
                -- remover entrada HUD y ejecutar callback una sola vez
                for i = #st.activeTimers, 1, -1 do
                    if st.activeTimers[i].id == timerId and st.activeTimers[i] == t then
                        table.remove(st.activeTimers, i)
                        break
                    end
                end
                if onEndFn then
                    local ok, err = pcall(onEndFn)
                    if not ok and Log and Log.error then Log.error("onEnd error ["..timerId.."]:", tostring(err)) end
                end
            end)
            t._handle = handle
            return t
        end
    end
    local entry = {
        id = timerId,
        duration = duration,
        remaining = duration,
        onEnd = onEndFn,
        _handle = nil,
    }
    local handle = timers.after(duration, function()
        for i = #st.activeTimers, 1, -1 do
            if st.activeTimers[i].id == timerId and st.activeTimers[i] == entry then
                table.remove(st.activeTimers, i)
                break
            end
        end
        if onEndFn then
            local ok, err = pcall(onEndFn)
            if not ok and Log and Log.error then Log.error("onEnd error ["..timerId.."]:", tostring(err)) end
        end
    end)
    entry._handle = handle
    table.insert(st.activeTimers, entry)
    return entry
end

--- Busca un temporizador activo por ID (usa handle pooled si existe)
function player.getActiveTimer(timerId)
    local st = world.state
    if not st or not st.activeTimers then return nil end
    for _, t in ipairs(st.activeTimers) do
        if t.id == timerId then
            if t._handle then
                if timers.isActive(t._handle) then return t end
            elseif t.remaining and t.remaining > 0 then
                return t -- compat legacy inserts sin handle (tests)
            end
        end
    end
    return nil
end

--- Cancela un temporizador activo de forma segura (cancela handle pooled)
function player.clearActiveTimer(timerId, runOnEnd)
    local st = world.state
    if not st or not st.activeTimers then return false end
    for i = #st.activeTimers, 1, -1 do
        local t = st.activeTimers[i]
        if t.id == timerId then
            if t._handle then timers.cancel(t._handle) end
            local cb = t.onEnd
            table.remove(st.activeTimers, i)
            if runOnEnd and cb then
                local ok, err = pcall(cb)
                if not ok and Log and Log.error then Log.error("onEnd error ["..timerId.."]:", tostring(err)) end
            end
            return true
        end
    end
    return false
end

-- Helper HUD: remaining dinámico desde handle (para ui/hudUI.lua)
function player.getTimerRemaining(entry)
    if not entry then return 0 end
    if entry._handle then
        -- timers pool: delay - accum
        local h = entry._handle
        if h and h.active and h.delay and h.accum then
            local rem = h.delay - h.accum
            return rem > 0 and rem or 0
        end
        return 0
    end
    return entry.remaining or 0
end

function player.getTimerDuration(entry)
    if not entry then return 0 end
    return entry.duration or entry.remaining or 0
end

--- Retorna el multiplicador de puntuación efectivo
function player.getScoreMultiplier()
    local st = world.state
    return (st and st.scoreMultiplier) or 1
end

--- Retorna el bonus de monedas por fruta
function player.getCoinBonus()
    local st = world.state
    return (st and st.coinBonus) or 0
end

function player.aplicarItem(itemId)
    local def = itemsMod.get and itemsMod.get(itemId) or itemsMod.registry[itemId]
    local canonicalId = def and def.id or itemId
    local st = world.state
    if not st then return end
    st.activeTimers = st.activeTimers or {}
    st.player = st.player or snakeMod.reset()

    if canonicalId == "shield" then
        shop.shieldActive = true

    elseif canonicalId == "armor" then
        st.player.armor = (st.player.armor or 0) + 2

    elseif canonicalId == "ghost" then
        st.player.ghost = true
        st.player.ghostTimer = math.max(st.player.ghostTimer or 0, constants.GHOST_DURATION)
        addOrRefreshTimer(st, "ghost", constants.GHOST_DURATION, function()
            if (st.player.ghostTimer or 0) <= 0 then
                st.player.ghost = false
            end
        end)

    elseif canonicalId == "magnet" then
        shop.magnetTimer = constants.MAGNET_DURATION
        st.magnetRange = constants.MAGNET_RANGE
        addOrRefreshTimer(st, "magnet", constants.MAGNET_DURATION, function()
            shop.magnetTimer = 0
            st.magnetRange = 0
        end)

    elseif canonicalId == "bomb" then
        local p = st.player.body and st.player.body[1]
        local r = constants.BOMB_RADIUS or 3
        if p then
            if obstaclesMod and obstaclesMod.pos then
                for i = #obstaclesMod.pos, 1, -1 do
                    local obs = obstaclesMod.pos[i]
                    if math.abs(obs.x - p.x) <= r and math.abs(obs.y - p.y) <= r then
                        table.remove(obstaclesMod.pos, i)
                    end
                end
            end
            if enemiesMod and enemiesMod.list then
                for i = #enemiesMod.list, 1, -1 do
                    local e = enemiesMod.list[i]
                    if e.alive and math.abs(e.x - p.x) <= r and math.abs(e.y - p.y) <= r then
                        local result = enemiesMod.killEnemy(i)
                        if result then
                            st.monedas = (st.monedas or 0) + (result.coins or 1)
                            uiMod.addPopup("+" .. (result.coins or 1) .. "$", result.gx, result.gy)
                            local cols = {
                                chaser = constants.COLOR_ENEMY_CHASER,
                                patroller = constants.COLOR_ENEMY_PATROLLER,
                                spawner = constants.COLOR_ENEMY_SPAWNER
                            }
                            local c = cols[result.type]
                            if c and particles.enemyKill then
                                table.insert(st.activePS, {
                                    ps = particles.enemyKill(result.px, result.py, c[1], c[2], c[3])
                                })
                            end
                            if Events then
                                Events.emit("enemyKilled")
                                Events.emit("coinsChanged", {totalCoins = st.monedas})
                            else
                                achievementsMod.check("enemyKilled")
                                achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                            end
                        end
                    end
                end
            end
            -- Ítem Bomba vs mini-jefe sala 3 (GDD §5: 2 de daño directo)
            do
                local mb = enemiesMod.getMiniBoss and enemiesMod.getMiniBoss()
                if mb and mb.alive and math.abs(mb.x - p.x) <= r and math.abs(mb.y - p.y) <= r then
                    local loot = enemiesMod.hitMiniBoss(2, {enemies = enemiesMod})
                    if loot then
                        st.monedas = (st.monedas or 0) + (loot.coins or 5)
                        uiMod.addPopup("+" .. (loot.coins or 5) .. "$ JEFE!", loot.gx, loot.gy)
                        if Events then
                            Events.emit("enemyKilled")
                            Events.emit("coinsChanged", {totalCoins = st.monedas})
                        else
                            achievementsMod.check("enemyKilled")
                            achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                        end
                    end
                end
            end
            sound.play("enemyKill")
        end

    elseif canonicalId == "hunger" then
        st.frutasContador = (st.frutasContador or 0) + 2
        st.puntuacion = (st.puntuacion or 0) + 20 * (st.scoreMultiplier or 1)
        st.monedas = (st.monedas or 0) + 2 + (st.coinBonus or 0)
        local wGrilla = st.anchoGrilla or math.floor(constants.canvasWidth / constants.TAMANIO_BLOQUE)
        local hGrilla = st.altoGrilla or math.floor((constants.canvasHeight - constants.GRID_OFFSET_Y) / constants.TAMANIO_BLOQUE)
        local obsPos = obstaclesMod and obstaclesMod.pos or {}
        foodMod.generar(st.player.body, wGrilla, hGrilla, obsPos, constants.FOOD_GOLD)
        st.velocidadActual = player.calcSpeed(st.baseSpeed, st.frutasContador)
        if st.player and st.player.body and st.player.body[1] then
            uiMod.addPopup("+20 (HAMBRE)", st.player.body[1].x, st.player.body[1].y)
        end

    elseif canonicalId == "speedReducer" then
        shop.inventory.speedReducer = true
        st.baseSpeed = math.min(constants.MAX_BASE_SPEED, (st.baseSpeed or constants.VELOCIDAD_INICIAL) + constants.SPEED_REDUCER_AMOUNT)
        st.velocidadActual = player.calcSpeed(st.baseSpeed, st.frutasContador)

    elseif canonicalId == "turbo" then
        st.velocidadActual = player.calcSpeed(st.baseSpeed, st.frutasContador, { turbo = true })
        addOrRefreshTimer(st, "turbo", constants.TURBO_DURATION, function()
            st.velocidadActual = player.calcSpeed(st.baseSpeed, st.frutasContador)
        end)

    elseif canonicalId == "slow" then
        st.timeScale = constants.SLOW_TIMESCALE
        addOrRefreshTimer(st, "slow", constants.SLOW_DURATION, function()
            st.timeScale = 1
        end)

    elseif canonicalId == "doubler" then
        for i = #st.activeTimers, 1, -1 do
            local t = st.activeTimers[i]
            if t.id == "star" or t.id == "doubler" then
                if t._handle then timers.cancel(t._handle) end
                table.remove(st.activeTimers, i)
            end
        end
        st.scoreMultiplier = 2
        addOrRefreshTimer(st, "doubler", constants.DOUBLER_DURATION, function()
            st.scoreMultiplier = 1
        end)

    elseif canonicalId == "extraCoin" then
        st.coinBonus = 1
        addOrRefreshTimer(st, "extraCoin", constants.EXTRA_COIN_DURATION, function()
            st.coinBonus = (shop.inventory and shop.inventory.extraCoin) and 1 or 0
        end)

    elseif canonicalId == "star" then
        for i = #st.activeTimers, 1, -1 do
            local t = st.activeTimers[i]
            if t.id == "star" or t.id == "doubler" then
                if t._handle then timers.cancel(t._handle) end
                table.remove(st.activeTimers, i)
            end
        end
        st.scoreMultiplier = 3
        st.coinBonus = 0
        addOrRefreshTimer(st, "star", constants.STAR_DURATION, function()
            st.scoreMultiplier = 1
            st.coinBonus = (shop.inventory and shop.inventory.extraCoin) and 1 or 0
        end)

    -- Arsenal extendido 51-60 (GDD Fase 8)
    elseif canonicalId == "tailSpike" then
        local tail = st.player.body and st.player.body[#st.player.body]
        if tail then
            st.placedTraps = st.placedTraps or {}
            table.insert(st.placedTraps, {x = tail.x, y = tail.y})
            while #st.placedTraps > (constants.TRAP_MAX or 3) do
                table.remove(st.placedTraps, 1)
            end
            uiMod.addPopup("TRAMPA +1", tail.x, tail.y)
            sound.play("buy")
        end

    elseif canonicalId == "hourglass" then
        local hist = st.historyBuffer
        if hist and #hist > 0 then
            local snap = hist[1]
            if snap.body and #snap.body >= 2 then
                local newBody = {}
                for i, seg in ipairs(snap.body) do
                    newBody[i] = {x = seg.x, y = seg.y}
                end
                st.player.body = newBody
                st.player.prevBody = {}
                for i, seg in ipairs(newBody) do
                    st.player.prevBody[i] = {x = seg.x, y = seg.y}
                end
                local h, n = newBody[1], newBody[2]
                st.player.dirX = (h.x ~= n.x) and (h.x > n.x and 1 or -1) or 0
                st.player.dirY = (h.x == n.x and h.y ~= n.y) and (h.y > n.y and 1 or -1) or 0
                st.player.lastMovedDirX = st.player.dirX
                st.player.lastMovedDirY = st.player.dirY
                st.player.inputQueue = {}
                if snap.enemies then
                    local newList = {}
                    for i, e in ipairs(snap.enemies) do
                        local c = {}
                        for k, v in pairs(e) do
                            if type(v) ~= "table" then c[k] = v end
                        end
                        newList[i] = c
                    end
                    enemiesMod.list = newList
                end
                if snap.boss and enemiesMod.boss then
                    enemiesMod.boss.x = snap.boss.x
                    enemiesMod.boss.y = snap.boss.y
                end
                enemiesMod.clearAttackObjects()
                uiMod.addPopup("REBOBINADO -2s", h.x, h.y)
                sound.play("highScore")
            end
        end

    elseif canonicalId == "orbitalBeam" then
        local head = st.player.body and st.player.body[1]
        if head then
            st.orbitalBeam = {x = head.x, timer = constants.ORBITAL_DURATION or 2.5}
            uiMod.addPopup("RAYO ORBITAL!", head.x, head.y)
            sound.play("enemyKill")
        end

    elseif canonicalId == "holoDecoy" then
        local head = st.player.body and st.player.body[1]
        if head then
            st.player.decoys = st.player.decoys or {}
            local dur = constants.HOLO_DECOY_DURATION or 4.0
            table.insert(st.player.decoys, {x = head.x, y = head.y, timer = dur, maxTimer = dur})
            uiMod.addPopup("SENUUELO!", head.x, head.y)
            sound.play("buy")
        end

    elseif canonicalId == "lightBoots" then
        shop.inventory.lightBoots = true
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("BOTAS LIGERAS", head.x, head.y) end
        sound.play("buy")

    elseif canonicalId == "goldenTooth" then
        shop.inventory.goldenTooth = true
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("DIENTE DE ORO", head.x, head.y) end
        sound.play("buy")

    elseif canonicalId == "emergencyBattery" then
        shop.inventory.emergencyBattery = true
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("BATERIA LISTA", head.x, head.y) end
        sound.play("buy")

    elseif canonicalId == "doubleHarvest" then
        shop.inventory.doubleHarvest = true
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("COSECHA DOBLE", head.x, head.y) end
        sound.play("buy")

    elseif canonicalId == "lottery" then
        local win = love.math.random(0, constants.LOTTERY_MAX or 35)
        st.monedas = (st.monedas or 0) + win
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("LOTERIA +" .. win .. "$", head.x, head.y) end
        sound.play("highScore")
        if Events then
            Events.emit("coinsChanged", {totalCoins = st.monedas})
        else
            achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
        end

    elseif canonicalId == "refractorPrism" then
        shop.inventory.refractorPrism = true
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("PRISMA LISTO", head.x, head.y) end
        sound.play("buy")
    end
end

function player.aplicarComida(tipo)
    local st = world.state
    local streak = st.survivalStreak or 1.0
    local p = st.player and st.player.body and st.player.body[1]
    if not p then return end
    local tam = constants.TAMANIO_BLOQUE
    local cx = p.x * tam + tam / 2
    local cy = p.y * tam + tam / 2

    if tipo == "fire_pepper" then
        st.player.firePepperTimer = constants.FIRE_PEPPER_DURATION or 3.5
        table.insert(st.activePS, { ps = particles.fireTrail(cx, cy) })
        uiMod.addPopup("FUEGO INCENDIARIO!", p.x, p.y)
        sound.play("eat")

    elseif tipo == "frost_berry" then
        st.enemyFreezeTimer = constants.FROST_BERRY_DURATION or 2.5
        table.insert(st.activePS, { ps = particles.frostFreeze(cx, cy) })
        uiMod.addPopup("CONGELACIÓN!", p.x, p.y)
        sound.play("shieldBreak")

    elseif tipo == "constrictor_berry" then
        st.player.constrictorBuffTimer = constants.CONSTRICTOR_BUFF_DURATION or 5.0
        table.insert(st.activePS, { ps = particles.streakDiamond(cx, cy) })
        uiMod.addPopup("LAZO CONSTRICTOR!", p.x, p.y)
        sound.play("highScore")

    elseif tipo == "slimming_berry" then
        local cut = snakeMod.applySlimming(st.player)
        if cut then
            table.insert(st.activePS, { ps = particles.slimmingBurst(cx, cy) })
            uiMod.addPopup("PODA -50%", p.x, p.y)
            sound.play("buy")
        else
            uiMod.addPopup("+15 PTS", p.x, p.y)
            sound.play("eat")
        end

    elseif tipo == "repelling_orbit" then
        local pts = math.floor(35 * (st.scoreMultiplier or 1) * streak)
        local coins = math.floor(3 * streak)
        st.puntuacion = (st.puntuacion or 0) + pts
        st.monedas = (st.monedas or 0) + coins
        uiMod.addPopup("+" .. pts .. " +" .. coins .. "$", p.x, p.y)
        sound.play("eat")

    elseif tipo == "bomb" then
        local r = 4
        table.insert(st.activePS, { ps = particles.bombExplosion(cx, cy) })
        sound.play("enemyKill")

        if enemiesMod and enemiesMod.list then
            for i = #enemiesMod.list, 1, -1 do
                local e = enemiesMod.list[i]
                if e.alive and math.abs(e.x - p.x) <= r and math.abs(e.y - p.y) <= r then
                    local result = enemiesMod.killEnemy(i)
                    if result then
                        local earnedCoins = math.floor((result.coins or 1) * streak)
                        st.monedas = (st.monedas or 0) + earnedCoins
                        uiMod.addPopup("+" .. earnedCoins .. "$", result.gx, result.gy)
                        if Events then
                            Events.emit("enemyKilled")
                            Events.emit("coinsChanged", {totalCoins = st.monedas})
                        else
                            achievementsMod.check("enemyKilled")
                            achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                        end
                    end
                end
            end
        end
        -- Bomba vs mini-jefe sala 3 (GDD §5: vulnerable al daño directo, 2 de daño)
        do
            local mb = enemiesMod.getMiniBoss and enemiesMod.getMiniBoss()
            if mb and mb.alive and math.abs(mb.x - p.x) <= r and math.abs(mb.y - p.y) <= r then
                local loot = enemiesMod.hitMiniBoss(2, {enemies = enemiesMod})
                if loot then
                    st.monedas = (st.monedas or 0) + (loot.coins or 5)
                    uiMod.addPopup("+" .. (loot.coins or 5) .. "$ JEFE!", loot.gx, loot.gy)
                    if Events then
                        Events.emit("enemyKilled")
                        Events.emit("coinsChanged", {totalCoins = st.monedas})
                    else
                        achievementsMod.check("enemyKilled")
                        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                    end
                end
            end
        end
        local pts = math.floor(30 * (st.scoreMultiplier or 1) * streak)
        st.puntuacion = (st.puntuacion or 0) + pts
        uiMod.addPopup("+" .. pts .. " (BOMBA)", p.x, p.y)

    elseif tipo == "prismatic" then
        local buff = foodMod.getPrismaticBuff()
        if buff == "speed" then
            player.aplicarItem("turbo")
            uiMod.addPopup("TURBO PRISMA", p.x, p.y)
        elseif buff == "shield" then
            player.aplicarItem("shield")
            uiMod.addPopup("ESCUDO PRISMA", p.x, p.y)
        elseif buff == "magnet" then
            player.aplicarItem("magnet")
            uiMod.addPopup("IMÁN PRISMA", p.x, p.y)
        elseif buff == "ghost" then
            player.aplicarItem("ghost")
            uiMod.addPopup("FANTASMA PRISMA", p.x, p.y)
        end

    elseif tipo == "streak_diamond" then
        st.survivalStreak = (st.survivalStreak or 1.0) + 0.5
        st.highestStreak = math.max(st.highestStreak or 1.0, st.survivalStreak)
        local cGains = math.floor(15 * streak)
        st.monedas = (st.monedas or 0) + cGains
        table.insert(st.activePS, { ps = particles.streakDiamond(cx, cy) })
        uiMod.addPopup("+0.5x RACHA +" .. cGains .. "$", p.x, p.y)
        sound.play("highScore")

    elseif tipo == "twin" then
        local pts = math.floor(50 * (st.scoreMultiplier or 1) * streak)
        st.puntuacion = (st.puntuacion or 0) + pts
        uiMod.addPopup("+" .. pts .. " (GEMELAS)", p.x, p.y)
        sound.play("eat")
    end
end

return player
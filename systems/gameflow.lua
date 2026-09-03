-- systems/gameflow.lua — Flujo de partida: arranque de juego/salas, perfiles (sin globals)
local gameflow = {}
local constants = require("constants")
local world = require("core.world")
local persistence = require("systems.persistence")
local items = require("systems.items")
local shop = require("systems.shop")
local playerMod = require("systems.player")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local uiMod = require("ui.ui")
local sound = require("audio.sound")

function gameflow.applyActiveProfile()
    local profile = persistence.getActiveProfile()
    local st = world.state
    shop.reset(false)
    if not profile then
        st.monedas = 0
        st.highScore = persistence.cargar() or 0
        st.highestStreak = 1.0
        return
    end
    st.monedas = profile.monedas or 0
    st.highScore = profile.highScore or 0
    if profile.stats and profile.stats.highestStreak then
        st.highestStreak = profile.stats.highestStreak
    else
        st.highestStreak = 1.0
    end
    -- Apply persistent passive unlocks to shop inventory
    for id, unlocked in pairs(profile.unlocks or {}) do
        if unlocked and items.registry[id] then
            local def = items.registry[id]
            if def.itemType == "passive" then
                shop.inventory[id] = true
            end
        end
    end
end

function gameflow.calculateCurrentSpeed(base, fruits)
    return playerMod.calculateCurrentSpeed(base, fruits)
end

function gameflow.resetGame(keepShopInventory)
    local st = world.state
    st.player = snakeMod.reset()
    st.cronometro = 0
    st.baseSpeed = constants.VELOCIDAD_INICIAL
    st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, 0)
    st.puntuacion = 0
    st.frutasContador = 0
    if not keepShopInventory then
        st.monedas = 0
        st.survivalStreak = 1.0
    end
    st.survivalStreak = st.survivalStreak or 1.0
    st.highestStreak = st.highestStreak or 1.0
    st.deathModalOpen = false
    st.roomDamaged = false
    st.deathAnimTimer = 0
    st.lastObstacleScore = 0
    st.magnetRange = 0
    -- P05: cancelar handles pooled antes de limpiar (evitar onEnd tardío)
    if st.activeTimers then
        local timers = require("core.timers")
        for _, t in ipairs(st.activeTimers) do
            if t._handle then pcall(function() timers.cancel(t._handle) end) end
        end
    end
    st.activeTimers = {}
    st.scoreMultiplier = 1
    st.coinBonus = 0
    st.timeScale = 1
    st.activePS = {}
    st.transitionTarget = nil
    st.transitionPhase = nil
    st.transitionHoldTimer = 0
    obstaclesMod.init()
    enemiesMod.init()
    uiMod.resetPopups()
    -- cancelar tweens de shockwaves pendientes
    if st.shockwaves then
        local timers = require("core.timers")
        for _, sw in ipairs(st.shockwaves) do
            if sw._tween then pcall(function() timers.cancel(sw._tween) end) end
        end
    end
    st.shockwaves = {}
    st.comboFlashTimer = 0
    st.comboCount = 0
    st.comboDisplay = 0
    st.comboIntensity = 0
    st.lastEatTime = 0
    if keepShopInventory then
        for id, owned in pairs(shop.inventory) do
            if owned then
                if id == "speedReducer" then
                    st.baseSpeed = math.min(constants.MAX_BASE_SPEED, (st.baseSpeed or constants.VELOCIDAD_INICIAL) + constants.SPEED_REDUCER_AMOUNT)
                    st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador or 0)
                elseif id == "extraCoin" then
                    st.coinBonus = 1
                end
            end
        end
    else
        shop.reset()
    end
end

function gameflow.iniciarSala(keepInventory)
    local st = world.state
    if not st.anchoGrilla or st.anchoGrilla == 0 or not st.altoGrilla or st.altoGrilla == 0 then
        gameflow.recalcularGrilla()
    end
    gameflow.resetGame(keepInventory)
    worldMod.puntajeSala = 0
    st.puntuacion = 0
    worldMod.populateRoom(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, foodMod, enemiesMod, obstaclesMod)
    if worldMod.sala == 1 then
        local bName = worldMod.getBiomeName()
        uiMod.addPopup("ETAPA " .. worldMod.etapa .. ": " .. string.upper(bName), math.floor(st.anchoGrilla / 2), math.floor(st.altoGrilla / 2) - 3)
    end
    if enemiesMod.boss and enemiesMod.boss.alive then
        uiMod.addPopup("Derrota al jefe recogiendo " .. constants.BOSS_FOOD_TARGET .. " comidas", math.floor(st.anchoGrilla / 2), math.floor(st.altoGrilla / 2) - 2)
    end
end

function gameflow.revivePlayer()
    local st = world.state
    local cost = constants.REVIVE_COIN_COST or 30
    if (st.monedas or 0) < cost then return false end

    st.monedas = st.monedas - cost
    persistence.syncActiveProfile()

    st.deathModalOpen = false
    st.player = st.player or snakeMod.reset()
    st.player.ghost = true
    st.player.ghostTimer = constants.REVIVE_GHOST_DURATION or 3.0
    st.player.flashTimer = constants.REVIVE_GHOST_DURATION or 3.0

    -- Limpiar enemigos en un radio de 3 casillas de la cabeza de la serpiente
    local head = st.player.body and st.player.body[1]
    if head then
        for i = #enemiesMod.list, 1, -1 do
            local e = enemiesMod.list[i]
            if e.alive and math.abs(e.x - head.x) <= 3 and math.abs(e.y - head.y) <= 3 then
                enemiesMod.killEnemy(i)
            end
        end
    end

    st.gameState = constants.GAME_STATE_PLAYING
    sound.play("highScore")
    return true
end

function gameflow.recalcularGrilla()
    local st = world.state
    local w, h = 640, 360
    if love.graphics and love.graphics.getWidth and love.graphics.getHeight then
        w = love.graphics.getWidth() or 640
        h = love.graphics.getHeight() or 360
        -- Fallback to getDimensions for high-DPI correctness
        if love.graphics.getDimensions then
            local gw, gh = love.graphics.getDimensions()
            if gw and gh and gw > 0 and gh > 0 then w, h = gw, gh end
        end
    elseif love.window and love.window.getMode then
        local ww, wh = love.window.getMode()
        if ww and wh then w, h = ww, wh end
    end
    local rawCols = math.floor(w / constants.TAMANIO_BLOQUE)
    local rawRows = math.floor((h - constants.GRID_OFFSET_Y) / constants.TAMANIO_BLOQUE)
    st.anchoGrilla = math.max(10, math.min(rawCols, constants.MAX_GRID_COLS))
    st.altoGrilla  = math.max(10, math.min(rawRows, constants.MAX_GRID_ROWS))
    local gridW = st.anchoGrilla * constants.TAMANIO_BLOQUE
    local gridH = st.altoGrilla * constants.TAMANIO_BLOQUE
    local gameH = constants.GRID_OFFSET_Y + gridH
    -- Centrado horizontal perfecto (floor para pixel-perfect)
    st.gridOffsetX = math.floor((w - gridW) / 2)
    st.gridOffsetY = constants.GRID_OFFSET_Y
    -- Centrado vertical del bloque completo (HUD+grid) en ventana
    st.gameOffsetY = math.floor(math.max(0, h - gameH) / 2)
    -- Clamp para evitar offsets negativos si ventana muy pequeña
    if st.gridOffsetX < 0 then st.gridOffsetX = 0 end
    if st.gameOffsetY < 0 then st.gameOffsetY = 0 end
end

function gameflow.startRun()
    local st = world.state
    worldMod.init()
    st.mundoCompletado = false
    gameflow.iniciarSala(false)
    st.fadeAlpha = 0
    st.fadeDir = 0
    st.gameState = constants.GAME_STATE_PLAYING
end

function gameflow.transitionToShop()
    local st = world.state
    persistence.syncActiveProfile()
    st.gameState = constants.GAME_STATE_SHOP
    sound.playSegment("intro")
    shop.abrir(st.monedas)
end

function gameflow.returnToMenu()
    local st = world.state
    persistence.syncActiveProfile()
    shop.reset()
    st.fadeDir = -1
    st.gameState = constants.GAME_STATE_MENU
    st.introTimer = 0
    st.pendingAchievements = {}
end

function gameflow.continueFromShop()
    local st = world.state
    persistence.syncActiveProfile()
    st.fadeAlpha = 1
    st.fadeDir = -1
    local monedasGuardadas = st.monedas
    gameflow.iniciarSala(true)
    st.monedas = monedasGuardadas
    persistence.syncActiveProfile()
    st.bossHealthDisplay = nil
    st.gameState = constants.GAME_STATE_PLAYING
    st.pendingAchievements = {}
end

return gameflow

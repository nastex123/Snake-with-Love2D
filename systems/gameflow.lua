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

function gameflow.applyActiveProfile()
    local profile = persistence.getActiveProfile()
    if not profile then return end
    local st = world.state
    st.monedas = profile.monedas
    st.highScore = profile.highScore
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
    end
    st.deathAnimTimer = 0
    st.lastObstacleScore = 0
    st.magnetRange = 0
    st.activeTimers = {}
    st.scoreMultiplier = 1
    st.coinBonus = 0
    st.timeScale = 1
    st.activePS = {}
    obstaclesMod.init()
    enemiesMod.init()
    uiMod.resetPopups()
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
                    st.velocidadActual = math.max(constants.VELOCIDAD_MINIMA, st.velocidadActual - constants.SPEED_REDUCER_AMOUNT)
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
    gameflow.resetGame(keepInventory)
    worldMod.puntajeSala = 0
    st.puntuacion = 0
    worldMod.populateRoom(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, foodMod, enemiesMod, obstaclesMod)
    if enemiesMod.boss and enemiesMod.boss.alive then
        uiMod.addPopup("Derrota al jefe recogiendo " .. constants.BOSS_FOOD_TARGET .. " comidas", math.floor(st.anchoGrilla / 2), math.floor(st.altoGrilla / 2) - 2)
    end
end

function gameflow.recalcularGrilla()
    local st = world.state
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local rawCols = math.floor(w / constants.TAMANIO_BLOQUE)
    local rawRows = math.floor((h - constants.GRID_OFFSET_Y) / constants.TAMANIO_BLOQUE)
    st.anchoGrilla = math.min(rawCols, constants.MAX_GRID_COLS)
    st.altoGrilla  = math.min(rawRows, constants.MAX_GRID_ROWS)
    local gameH = constants.GRID_OFFSET_Y + st.altoGrilla * constants.TAMANIO_BLOQUE
    st.gridOffsetX = math.floor((w - st.anchoGrilla * constants.TAMANIO_BLOQUE) / 2)
    st.gridOffsetY = constants.GRID_OFFSET_Y
    st.gameOffsetY = math.floor(math.max(0, h - gameH) / 2)
end

return gameflow

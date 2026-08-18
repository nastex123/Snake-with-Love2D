-- systems/player.lua — Helpers de jugador/items (sin globals, estado via core.world)
local player = {}
local constants = require("constants")
local world = require("core.world")
local shop = require("systems.shop")
local foodMod = require("entities.food")
local obstaclesMod = require("entities.obstacles")
local enemiesMod = require("entities.enemies")
local particles = require("render.particles")
local sound = require("audio.sound")
local uiMod = require("ui.ui")
local achievementsMod = require("systems.achievements")

function player.calculateCurrentSpeed(base, fruits)
    local speedReduction = math.floor(fruits / 5) * constants.SPEED_ADJUST_INCREMENT
    return math.max(constants.VELOCIDAD_MINIMA, base - speedReduction)
end

function player.itemColor(itemId)
    local colors = {
        shield = {0, 0.85, 1}, armor = {0.3, 0.7, 1}, ghost = {0.6, 0.4, 1},
        magnet = {0, 0.85, 1}, bomb = {1, 0.4, 0.2}, hunger = {1, 0.6, 0.2},
        speedReducer = {0.2, 0.9, 0.3}, turbo = {0, 1, 0.5}, slow = {0.5, 0.5, 1},
        doubler = {1, 0.84, 0}, extraCoin = {1, 0.84, 0}, star = {1, 0.84, 0}
    }
    local c = colors[itemId]
    return c and c[1] or 1, c and c[2] or 1, c and c[3] or 1
end

function player.aplicarItem(itemId)
    local st = world.state
    if itemId == "shield" then
        shop.shieldActive = true
    elseif itemId == "armor" then
        st.player.armor = 2
    elseif itemId == "ghost" then
        st.player.ghost = true
        table.insert(st.activeTimers, {
            id = "ghost", remaining = constants.GHOST_DURATION,
            onEnd = function() st.player.ghost = false end
        })
    elseif itemId == "magnet" then
        shop.magnetTimer = constants.MAGNET_DURATION
        st.magnetRange = constants.MAGNET_RANGE
        table.insert(st.activeTimers, {
            id = "magnet", remaining = constants.MAGNET_DURATION,
            onEnd = function() shop.magnetTimer = 0; st.magnetRange = 0 end
        })
    elseif itemId == "bomb" then
        local p = st.player.body[1]
        local r = constants.BOMB_RADIUS
        for i = #obstaclesMod.pos, 1, -1 do
            local obs = obstaclesMod.pos[i]
            if math.abs(obs.x - p.x) <= r and math.abs(obs.y - p.y) <= r then
                table.remove(obstaclesMod.pos, i)
            end
        end
        for i = #enemiesMod.list, 1, -1 do
            local e = enemiesMod.list[i]
            if e.alive and math.abs(e.x - p.x) <= r and math.abs(e.y - p.y) <= r then
                local result = enemiesMod.killEnemy(i)
                if result then
                    st.monedas = st.monedas + result.coins
                    uiMod.addPopup("+" .. result.coins .. "$", result.gx, result.gy)
                    local cols = {
                        chaser = constants.COLOR_ENEMY_CHASER,
                        patroller = constants.COLOR_ENEMY_PATROLLER,
                        spawner = constants.COLOR_ENEMY_SPAWNER
                    }
                    local c = cols[result.type]
                    if c then
                        table.insert(st.activePS, {
                            ps = particles.enemyKill(result.px, result.py, c[1], c[2], c[3])
                        })
                    end
                    achievementsMod.check("enemyKilled")
                    achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                end
            end
        end
        sound.play("enemyKill")
    elseif itemId == "hunger" then
        st.frutasContador = st.frutasContador + 2
        st.puntuacion = st.puntuacion + 20 * st.scoreMultiplier
        st.monedas = st.monedas + 2 + st.coinBonus
        foodMod.generar(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, constants.FOOD_GOLD)
        if st.player and st.player.body and st.player.body[1] then
            uiMod.addPopup("+20 (HAMBRE)", st.player.body[1].x, st.player.body[1].y)
        end
    elseif itemId == "speedReducer" then
        st.velocidadActual = math.max(constants.VELOCIDAD_MINIMA, st.velocidadActual - constants.SPEED_REDUCER_AMOUNT)
    elseif itemId == "turbo" then
        st.velocidadActual = math.max(constants.VELOCIDAD_MINIMA, st.velocidadActual * constants.TURBO_MULTIPLIER)
        table.insert(st.activeTimers, {
            id = "turbo", remaining = constants.TURBO_DURATION,
            onEnd = function()
                st.velocidadActual = player.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
            end
        })
    elseif itemId == "slow" then
        st.timeScale = constants.SLOW_TIMESCALE
        table.insert(st.activeTimers, {
            id = "slow", remaining = constants.SLOW_DURATION,
            onEnd = function() st.timeScale = 1 end
        })
    elseif itemId == "doubler" then
        for i = #st.activeTimers, 1, -1 do
            if st.activeTimers[i].id == "star" or st.activeTimers[i].id == "doubler" then
                if st.activeTimers[i].onEnd then st.activeTimers[i].onEnd() end
                table.remove(st.activeTimers, i)
            end
        end
        st.scoreMultiplier = 2
        st.coinBonus = 0
        table.insert(st.activeTimers, {
            id = "doubler", remaining = constants.DOUBLER_DURATION,
            onEnd = function() st.scoreMultiplier = 1 end
        })
    elseif itemId == "extraCoin" then
        st.coinBonus = 1
        table.insert(st.activeTimers, {
            id = "extraCoin", remaining = constants.EXTRA_COIN_DURATION,
            onEnd = function() st.coinBonus = 0 end
        })
    elseif itemId == "star" then
        for i = #st.activeTimers, 1, -1 do
            if st.activeTimers[i].id == "star" or st.activeTimers[i].id == "doubler" then
                if st.activeTimers[i].onEnd then st.activeTimers[i].onEnd() end
                table.remove(st.activeTimers, i)
            end
        end
        st.scoreMultiplier = 3
        st.coinBonus = 0
        table.insert(st.activeTimers, {
            id = "star", remaining = constants.STAR_DURATION,
            onEnd = function() st.scoreMultiplier = 1 end
        })
    end
end

return player
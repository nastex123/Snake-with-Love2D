-- =============================================================================
-- MÓDULO: systems/gamestates/playingPickups.lua
-- Maneja consumo de frutas, combos, economía, shockwaves y objetivos de sala.
-- Submódulo desacoplado de playing.lua (Zero-GC en loops de frame).
-- =============================================================================
local playingPickups = {}

local constants = require("constants")
local sound = require("audio.sound")
local shop = require("systems.shop")
local uiMod = require("ui.ui")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local particles = require("render.particles")
local achievementsMod = require("systems.achievements")
local playerMod = require("systems.player")
local timers = require("core.timers")
local tarotMod = require("systems.tarot")
local statusFx = require("systems.statusFx")
local mutatorsMod = require("systems.roomMutators")
local mysteryMod = require("systems.mystery")
local playingEvents = require("systems.gamestates.playingEvents")

local hasEvents, Events = pcall(require, "core.events")
if not hasEvents or type(Events) ~= "table" then Events = nil end

-- Procesa el consumo de fruta (normal, oro, moneda, especial o twin)
function playingPickups.handleFoodPickup(st, comioTwin)
    sound.play("eat")
    local tipo = foodMod.tipo
    local streak = st.survivalStreak or 1.0

    local isSpecial = (tipo == "fire_pepper" or tipo == "frost_berry" or tipo == "constrictor_berry" or
                       tipo == "slimming_berry" or tipo == "repelling_orbit" or tipo == "bomb" or
                       tipo == "prismatic" or tipo == "streak_diamond" or tipo == "twin")

    if isSpecial then
        playerMod.aplicarComida(tipo)
        if tipo == "twin" then
            if comioTwin then
                foodMod.twinPos = nil
            else
                if foodMod.twinPos then
                    foodMod.pos.x = foodMod.twinPos.x
                    foodMod.pos.y = foodMod.twinPos.y
                    foodMod.twinPos = nil
                end
            end
        end
    else
        local puntosBase, monedasExtra, textPopup
        if tipo == constants.FOOD_GOLD then
            puntosBase = 25
            monedasExtra = 2
            textPopup = "+25"
        elseif tipo == constants.FOOD_COIN then
            puntosBase = 5
            monedasExtra = 3
            textPopup = "+5$"
        else
            puntosBase = 10
            monedasExtra = constants.COINS_PER_FRUIT
            textPopup = "+10"
        end
        -- Pacto del Titan (GDD §19.70): +50 puntos base por fruta
        puntosBase = puntosBase + mutatorsMod.titanFruitBonus()

        if st.time - st.lastEatTime <= tarotMod.comboWindow() then
            st.comboCount = st.comboCount + 1
            st.comboFlashTimer = 0.3
            if st.comboCount >= 4 then
                if Events then
                    Events.emit("comboAchieved", {count = st.comboCount + 1})
                else
                    achievementsMod.check("comboAchieved", {count = st.comboCount + 1})
                end
            end
            -- Overdrive (GDD §16.1): combo x6 activa frenesi; refresh silencioso
            local odApplied, odFresh = statusFx.checkOverdrive(st.comboCount + 1)
            if odApplied and odFresh then
                local head = st.player.body and st.player.body[1]
                if head then uiMod.addPopup("OVERDRIVE!", head.x, head.y) end
                sound.play("highScore")
            end
        else
            st.comboCount = 0
        end
        st.lastEatTime = st.time
        local comboMult = tarotMod.comboMult(1 + st.comboCount * constants.COMBO_MULTIPLIER)
        local total = math.floor(puntosBase * comboMult * (st.scoreMultiplier or 1) * streak)

        st.puntuacion = st.puntuacion + total
        st.frutasContador = st.frutasContador + 1
        st.monedas = st.monedas + math.floor((monedasExtra + st.coinBonus) * streak)
        -- Midas Avaro (GDD §19.62): +2 monedas por fruta
        st.monedas = st.monedas + mutatorsMod.midasFruitBonus()
        -- Apostador (GDD §15.1): 3 doradas con apuesta = 40$ + item + racha
        if tipo == constants.FOOD_GOLD and mysteryMod.gamblerGoldEaten() == "win" then
            st.monedas = st.monedas + (constants.GAMBLER_WIN_COINS or 40)
            st.survivalStreak = (st.survivalStreak or 1.0) + 0.3
            local hasItems, itemsMod = pcall(require, "systems.items")
            if hasItems then
                local pool = {}
                for id, def in pairs(itemsMod.registry or {}) do
                    if type(def) == "table" and not shop.isOwned(def.id or id) then
                        pool[#pool + 1] = def.id or id
                    end
                end
                for _ = 1, math.min(5, #pool) do
                    local pick = table.remove(pool, love.math.random(#pool))
                    local res = shop.procesarCompra(st.monedas, pick, 0)
                    if res then
                        local head = st.player.body and st.player.body[1]
                        if head then uiMod.addPopup("PREMIO: " .. string.upper(pick), head.x, head.y) end
                        break
                    end
                end
            end
            local head = st.player.body and st.player.body[1]
            if head then uiMod.addPopup("APUESTA +40$", head.x, head.y) end
            sound.play("highScore")
        end
        -- Dualidad (GDD §19.69): la fruta espejo se consume sin bonus extra
        if comioTwin then foodMod.twinPos = nil; foodMod.dualTwin = nil end
        -- Espejo (GDD §15.2): 3 frutas normales lo disuelven
        if tipo == constants.FOOD_NORMAL and mysteryMod.doppelFed() == "dissolve" then
            playingEvents.awardDoppel(st)
        end
        -- Diente de Oro (GDD item 56): +1 moneda por fruta cada 10 segmentos
        if shop.inventory and shop.inventory.goldenTooth then
            local tooth = math.floor(#st.player.body / 10)
            if tooth > 0 then
                st.monedas = st.monedas + tooth
                uiMod.addPopup("DIENTE +" .. tooth .. "$", foodMod.pos.x, foodMod.pos.y)
            end
        end
        st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
        st.player.flashTimer = constants.DURACION_FLASH_COMER

        local tam = constants.TAMANIO_BLOQUE
        local fx = foodMod.pos.x * tam + tam / 2
        local fy = foodMod.pos.y * tam + tam / 2
        table.insert(st.activePS, {
            ps = particles.comer(fx, fy)
        })

        -- P05: shockwave via timers.tween (0.4s, radio 0->48, alpha 1->0), sin loop manual
        local sw = {x = fx, y = fy, radio = 0, alpha = 1}
        table.insert(st.shockwaves, sw)
        sw._tween = timers.tween(0.4, sw, {radio = 48, alpha = 0}, function()
            for i = #st.shockwaves, 1, -1 do
                if st.shockwaves[i] == sw then
                    table.remove(st.shockwaves, i)
                    break
                end
            end
        end)

        if st.comboCount > 0 then
            uiMod.addPopup(textPopup .. " x" .. (st.comboCount + 1), foodMod.pos.x, foodMod.pos.y)
        else
            uiMod.addPopup(textPopup, foodMod.pos.x, foodMod.pos.y)
        end
    end

    if enemiesMod.boss and enemiesMod.boss.alive then
        local tam2 = constants.TAMANIO_BLOQUE
        table.insert(st.activePS, {
            ps = particles.bossFoodTick(foodMod.pos.x * tam2 + tam2 / 2, foodMod.pos.y * tam2 + tam2 / 2)
        })
    end

    -- Re-generación segura de comida evitando colisiones con Boss o enemigos
    if tipo ~= "twin" or not foodMod.twinPos then
        local avoid = {}
        if enemiesMod.boss and enemiesMod.boss.alive then avoid[#avoid+1]=enemiesMod.boss end
        for _,e in ipairs(enemiesMod.list) do if e.alive then avoid[#avoid+1]=e end end
        local extra = (#avoid>0) and avoid or nil
        local ok = foodMod.generar(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, nil, nil, nil)
        if ok and extra then
            local blocked=false
            for _,a in ipairs(extra) do if foodMod.pos.x==a.x and foodMod.pos.y==a.y then blocked=true; break end end
            if blocked then
                for attempt=1,20 do
                    local nx, ny = require("entities.enemyHelpers").sampleFreeTile(st.anchoGrilla, st.altoGrilla, st.player.body, obstaclesMod, enemiesMod.list, 2, 30)
                    if nx and ny then foodMod.pos.x=nx; foodMod.pos.y=ny; break end
                end
            end
        end
    end

    -- Apostador (GDD §15.1): mientras falten doradas, los respawns nacen oro
    if mysteryMod.gamblerNeedsGold() then foodMod.tipo = constants.FOOD_GOLD end

    if st.puntuacion >= st.lastObstacleScore + constants.OBSTACLE_SPAWN_INTERVAL then
        st.lastObstacleScore = math.floor(st.puntuacion / constants.OBSTACLE_SPAWN_INTERVAL) * constants.OBSTACLE_SPAWN_INTERVAL
        local mod = worldMod.getModifier()
        obstaclesMod.generar(st.player.body, foodMod.pos, st.anchoGrilla, st.altoGrilla)
        enemiesMod.generar(st.player.body, foodMod.pos, obstaclesMod.pos, st.anchoGrilla, st.altoGrilla, mod)
    end
end

-- Verifica si la puntuación alcanzó el objetivo de sala y transiciona. Retorna true si transicionó.
function playingPickups.checkRoomObjective(st)
    local mbGate = enemiesMod.getMiniBoss and enemiesMod.getMiniBoss()
    local miniAlive = mbGate and mbGate.alive
    if miniAlive and st.puntuacion >= worldMod.objetivoSala and not st.transitionTarget then
        st.lastMiniGateHint = st.lastMiniGateHint or -10
        if (st.time or 0) - st.lastMiniGateHint > 4 then
            st.lastMiniGateHint = st.time or 0
            local head = st.player.body and st.player.body[1]
            if head then uiMod.addPopup("DERROTA AL MINI-JEFE PARA AVANZAR", head.x, head.y) end
        end
    end

    if st.puntuacion >= worldMod.objetivoSala and not worldMod.esJefe() and not miniAlive and not st.transitionTarget then
        -- Contrarreloj (GDD §19.66): premio si el objetivo se cumple a tiempo
        if mutatorsMod.has("time_trial") and not mutatorsMod.data().rewarded then
            mutatorsMod.data().rewarded = true
            if mutatorsMod.timeTrialWon() then
                local pick = playingEvents.grantRandomItem(st, true)
                if pick then
                    local head = st.player.body and st.player.body[1]
                    if head then uiMod.addPopup("CRONO: " .. string.upper(pick), head.x, head.y) end
                    sound.play("highScore")
                end
            end
        end
        st.transitionTarget = "siguienteSala"
        st.transitionPhase = 1
        st.fadeDir = 1
        st.gameState = constants.GAME_STATE_TRANSITION
        sound:playSegment("intro")
        return true
    end
    return false
end

return playingPickups

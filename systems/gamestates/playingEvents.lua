-- =============================================================================
-- MÓDULO: systems/gamestates/playingEvents.lua
-- Maneja mutadores ambientales de sala (GDD §19) y salas de misterio (GDD §15).
-- Submódulo desacoplado de playing.lua (Zero-GC en loops de frame).
-- =============================================================================
local playingEvents = {}

local constants = require("constants")
local world = require("core.world")
local sound = require("audio.sound")
local shop = require("systems.shop")
local uiMod = require("ui.ui")
local mutatorsMod = require("systems.roomMutators")
local mysteryMod = require("systems.mystery")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local gameflow = require("systems.gameflow")

-- Item aleatorio no poseido via tienda costo 0 (premios Contrarreloj/Espejo/Altar)
function playingEvents.grantRandomItem(st, onlyPassive)
    local hasItems, itemsMod = pcall(require, "systems.items")
    if not hasItems then return nil end
    local pool = {}
    for id, def in pairs(itemsMod.registry or {}) do
        if type(def) == "table" and not shop.isOwned(def.id or id)
            and (not onlyPassive or def.itemType == "passive") then
            pool[#pool + 1] = def.id or id
        end
    end
    for _ = 1, math.min(5, #pool) do
        local pick = table.remove(pool, love.math.random(#pool))
        local res = shop.procesarCompra(st.monedas, pick, 0)
        if res then return pick end
    end
    return nil
end

-- Espejo disuelto (GDD §15.2): 30$ + cofre dorado (item aleatorio)
function playingEvents.awardDoppel(st)
    local d = mysteryMod.data()
    if d.doppelDone then return end
    d.doppelDone = true
    d.doppel = nil
    st.monedas = (st.monedas or 0) + (constants.DOPPEL_REWARD_COINS or 30)
    local head = st.player.body and st.player.body[1]
    local pick = playingEvents.grantRandomItem(st)
    if head then
        uiMod.addPopup("ESPEJO +30$", head.x, head.y)
        if pick then uiMod.addPopup("PREMIO: " .. string.upper(pick), head.x, head.y) end
    end
    sound.play("highScore")
end

-- Bendicion del Fenix (GDD §19.67): revive gratis 1 vez por etapa (3 segmentos + 3s fantasma)
function playingEvents.phoenixRevive(st)
    if not mutatorsMod.phoenixAvailable() then return false end
    local p = st.player
    if not (p and p.body and #p.body > 0) then return false end
    mutatorsMod.phoenixConsume()
    while #p.body > 3 do table.remove(p.body) end
    p.ghost = true
    p.ghostTimer = 3.0
    p.flashTimer = 3.0
    local head = p.body[1]
    for i = #enemiesMod.list, 1, -1 do
        local e = enemiesMod.list[i]
        if e and e.alive and math.abs(e.x - head.x) <= 3 and math.abs(e.y - head.y) <= 3 then
            enemiesMod.killEnemy(i)
        end
    end
    uiMod.addPopup("FENIX!", head.x, head.y)
    sound.play("highScore")
    return true
end

-- Actualiza mutadores y misterios por frame. Retorna true si causó muerte o transición.
function playingEvents.updateRoomEvents(st, dt)
    -- Room Mutators tick (GDD §19): drenaje Midas + expiracion Contrarreloj
    mutatorsMod.midasDrain(dt)
    if mutatorsMod.timeTrialTick(dt) == "expired" then
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("CRONO AGOTADO", head.x, head.y) end
    end

    -- Sombra Acechante (GDD §19.65): muerte al contacto (Fenix puede salvar)
    if mutatorsMod.shadowTick(dt, st.player.body and st.player.body[1]) == "kill" then
        if playingEvents.phoenixRevive(st) then return false end
        gameflow.triggerDeathAnimation()
        return true
    end

    -- Guarida del Apostador (GDD §15.1): apuesta en la ruleta + temporizador
    local head0 = st.player.body and st.player.body[1]
    if mysteryMod.gamblerActive(worldMod) then
        local gd = mysteryMod.data()
        if not gd.bet and head0 then
            local r = mysteryMod.gamblerRoulette(st.anchoGrilla, st.altoGrilla)
            if head0.x == r.x and head0.y == r.y then
                if mysteryMod.gamblerPlaceBet(st.monedas or 0) then
                    st.monedas = st.monedas - mysteryMod.gamblerBet()
                    uiMod.addPopup("APUESTA -10$", head0.x, head0.y)
                    sound.play("buy")
                elseif not gd.refused then
                    gd.refused = true
                    uiMod.addPopup("SIN FONDOS", head0.x, head0.y)
                end
            end
        end
        if mysteryMod.gamblerTick(dt) == "lose" then
            local helpersOk, helpers = pcall(require, "entities.enemyHelpers")
            for _ = 1, (constants.GAMBLER_LOSE_CHASERS or 2) do
                local nx, ny
                if helpersOk then
                    nx, ny = helpers.sampleFreeTile(st.anchoGrilla, st.altoGrilla, st.player.body, obstaclesMod, enemiesMod.list, 2, 30)
                end
                if nx and enemiesMod.spawnAt then enemiesMod.spawnAt("chaser", nx, ny, {}) end
            end
            if head0 then uiMod.addPopup("APUESTA PERDIDA", head0.x, head0.y) end
            sound.play("death")
        end
    end

    -- Fiebre del Oro (GDD §15.3): monedas rebotando + puerta a los 12s
    if mysteryMod.goldRushActive(worldMod) then
        local got, done = mysteryMod.goldRushTick(dt, head0)
        if got > 0 then
            st.monedas = (st.monedas or 0) + got
            sound.play("buttonClick")
        end
        if done and not st.transitionTarget then
            st.transitionTarget = "siguienteSala"
            st.transitionPhase = 1
            st.fadeDir = 1
            st.gameState = constants.GAME_STATE_TRANSITION
            sound:playSegment("intro")
            return true
        end
    end

    -- Espejo (GDD §15.2): replica con retraso + contacto letal
    if mysteryMod.doppelActive(worldMod) then
        local dd = mysteryMod.data().doppel
        if dd then
            local p = st.player
            mysteryMod.doppelTick(dt, dd, {x = p.dirX or 0, y = p.dirY or 0}, st.time or 0, st.velocidadActual or 0.13)
            if head0 and mysteryMod.doppelTouchesHead(dd, head0) then
                if playingEvents.phoenixRevive(st) then return false end
                gameflow.triggerDeathAnimation()
                return true
            end
        end
    end

    -- Sellos (GDD §15.4): orden 1-2-3 en menos de 10s
    if mysteryMod.triadsActive(worldMod) then
        local tr = mysteryMod.data().triads
        if tr then
            tr.timer = tr.timer - dt
            local step = mysteryMod.triadsStep(tr, head0)
            if step == "next" then
                if head0 then uiMod.addPopup("SELLO " .. tr.progress .. "/3", head0.x, head0.y) end
                sound.play("buy")
            elseif step == "reset" then
                if head0 then uiMod.addPopup("SELLOS RESET", head0.x, head0.y) end
            elseif step == "complete" then
                st.monedas = (st.monedas or 0) + (constants.TRIADS_REWARD_COINS or 50)
                playingEvents.grantRandomItem(st)
                playingEvents.grantRandomItem(st)
                if head0 then uiMod.addPopup("ALTAR LEGENDARIO", head0.x, head0.y) end
                sound.play("highScore")
            elseif tr.timer <= 0 then
                tr.done = true
                if head0 then uiMod.addPopup("SELLOS APAGADOS", head0.x, head0.y) end
            end
        end
    end

    return false
end

return playingEvents

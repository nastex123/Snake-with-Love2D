-- =============================================================================
-- systems/roomEvents.lua
-- Motor Data-Driven de Eventos Aleatorios Intra-Sala (GDD §22 / TDD §10.31)
-- Implementa eventos E1 a E7 con vetos por tipo de sala, mutador y Cero-GC.
-- =============================================================================
local roomEvents = {}
local constants = require("constants")

roomEvents.EVENT_CHANCE = 0.25

roomEvents.DEFS = {
    gold_rain = {
        id = "gold_rain",
        name = "LLUVIA DE ORO",
        tag = "ORO",
        duration = 9.0,
        color = {1.0, 0.84, 0.0},
        onStart = function(st, data)
            data.coinsLeft = 6
            data.dropTimer = 0.3
        end,
        onUpdate = function(dt, st, data, enemiesMod, uiMod)
            data.dropTimer = (data.dropTimer or 0) - dt
            if data.dropTimer <= 0 and (data.coinsLeft or 0) > 0 then
                data.coinsLeft = data.coinsLeft - 1
                data.dropTimer = 1.2
                st.monedas = (st.monedas or 0) + 1
                local head = st.player and st.player.body and st.player.body[1]
                if head and uiMod then
                    uiMod.addPopup("+1$ LLUVIA", head.x, head.y)
                end
            end
        end,
    },
    big_hunt = {
        id = "big_hunt",
        name = "CAZA MAYOR",
        tag = "CAZA",
        duration = 15.0,
        color = {0.95, 0.30, 0.20},
        onStart = function(st, data, enemiesMod)
            if enemiesMod and enemiesMod.list and #enemiesMod.list > 0 then
                for _, e in ipairs(enemiesMod.list) do
                    if e.alive then
                        e.isChampion = true
                        e.coins = (e.coins or 2) * 3
                        data.target = e
                        break
                    end
                end
            end
        end,
        onUpdate = function(dt, st, data) end,
    },
    merchant = {
        id = "merchant",
        name = "MERCADER ERRANTE",
        tag = "MERCADER",
        duration = 12.0,
        color = {0.20, 0.85, 0.40},
        onStart = function(st, data)
            data.interacted = false
            data.mx = math.floor((st.anchoGrilla or 20) / 2)
            data.my = math.floor((st.altoGrilla or 14) / 2)
        end,
        onUpdate = function(dt, st, data, enemiesMod, uiMod)
            if data.interacted then return end
            local head = st.player and st.player.body and st.player.body[1]
            if head and head.x == data.mx and head.y == data.my then
                data.interacted = true
                st.monedas = (st.monedas or 0) + 15
                if uiMod then uiMod.addPopup("MERCADER: +15$", head.x, head.y) end
            end
        end,
    },
    eclipse = {
        id = "eclipse",
        name = "ECLIPSE PARCIAL",
        tag = "ECLIPSE",
        duration = 10.0,
        color = {0.45, 0.15, 0.65},
        onStart = function(st, data)
            data.radius = 7
        end,
        onUpdate = function(dt, st, data) end,
        onEnd = function(st, data, uiMod)
            st.monedas = (st.monedas or 0) + 15
            local head = st.player and st.player.body and st.player.body[1]
            if head and uiMod then uiMod.addPopup("ECLIPSE SUPERADO: +15$", head.x, head.y) end
        end,
    },
    duel = {
        id = "duel",
        name = "DUELO DE CAMPEONES",
        tag = "DUELO",
        duration = 12.0,
        color = {1.0, 0.50, 0.10},
        onStart = function(st, data, enemiesMod)
            data.savedRespawns = true
        end,
        onUpdate = function(dt, st, data) end,
    },
    void_echo = {
        id = "void_echo",
        name = "ECO DEL VACIO",
        tag = "ECO",
        duration = 8.0,
        color = {0.30, 0.70, 1.0},
        onStart = function(st, data)
            st.comboCount = (st.comboCount or 0) + 2
        end,
        onUpdate = function(dt, st, data) end,
    },
    blood_offer = {
        id = "blood_offer",
        name = "OFRENDA DE SANGRE",
        tag = "OFRENDA",
        duration = 14.0,
        color = {0.80, 0.05, 0.15},
        onStart = function(st, data)
            data.accepted = false
        end,
        onUpdate = function(dt, st, data, enemiesMod, uiMod)
            if data.accepted then return end
            if st.player and st.player.body and #st.player.body >= 8 and (st.monedas or 0) < 10 then
                data.accepted = true
                for _ = 1, 2 do
                    if #st.player.body > 4 then table.remove(st.player.body) end
                end
                st.monedas = (st.monedas or 0) + 25
                local head = st.player.body[1]
                if head and uiMod then uiMod.addPopup("OFRENDA: +25$", head.x, head.y) end
            end
        end,
    },
}

roomEvents.EVENT_KEYS = {"gold_rain", "big_hunt", "merchant", "eclipse", "duel", "void_echo", "blood_offer"}

local activeEventId = nil
local activeEventTimer = 0
local activeEventData = {}

function roomEvents.getDef(id)
    return id and roomEvents.DEFS[id]
end

function roomEvents.getCurrent()
    return activeEventId, activeEventTimer, activeEventData
end

function roomEvents.canTrigger(worldMod, st)
    if not worldMod then return false end
    if worldMod.esJefe and worldMod.esJefe() then return false end
    if (worldMod.sala or 0) == 3 then return false end
    local room = worldMod.getCurrentRoom and worldMod.getCurrentRoom()
    if room and (room.isElite or room.template == "boss" or room.mystery) then return false end
    local mutMods = package.loaded["systems.roomMutators"]
    if mutMods and mutMods.has and mutMods.has("time_trial") then return false end
    return true
end

function roomEvents.roll(worldMod, st, enemiesMod)
    roomEvents.reset()
    if not roomEvents.canTrigger(worldMod, st) then return nil end
    if love.math.random() > roomEvents.EVENT_CHANCE then return nil end

    local keys = roomEvents.EVENT_KEYS
    local chosenKey = keys[love.math.random(1, #keys)]
    local def = roomEvents.DEFS[chosenKey]
    if not def then return nil end

    activeEventId = chosenKey
    activeEventTimer = def.duration or 10.0
    activeEventData = {}
    st.roomEvent = chosenKey
    st.roomEventTimer = activeEventTimer

    if def.onStart then
        def.onStart(st, activeEventData, enemiesMod)
    end
    return chosenKey
end

function roomEvents.update(dt, st, enemiesMod, uiMod, sound)
    if not activeEventId then return false end
    activeEventTimer = activeEventTimer - dt
    st.roomEventTimer = math.max(0, activeEventTimer)

    local def = roomEvents.DEFS[activeEventId]
    if def and def.onUpdate then
        def.onUpdate(dt, st, activeEventData, enemiesMod, uiMod)
    end

    if activeEventTimer <= 0 then
        if def and def.onEnd then
            def.onEnd(st, activeEventData, uiMod)
        end
        roomEvents.reset()
        st.roomEvent = nil
        st.roomEventTimer = nil
        return true
    end
    return false
end

function roomEvents.reset()
    activeEventId = nil
    activeEventTimer = 0
    activeEventData = {}
end

return roomEvents

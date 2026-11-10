-- Progresion de una etapa sin cambiar de arena durante sus encuentros.
local stageFlow = {}
local constants = require("constants")
local enemies = require("entities.enemies")
local obstacles = require("entities.obstacles")
local food = require("entities.food")
local helpers = require("entities.enemyHelpers")
local worldMod = require("world.world")
local ui = require("ui.ui")
local populate = require("world.populate")

local function findPosition(st, size)
    local body = st.player and st.player.body or {}
    local head = body[1]
    local w, h = st.anchoGrilla, st.altoGrilla
    for y = 1, h - size - 1 do
        for x = 1, w - size - 1 do
            local safe = not head or math.abs(x - head.x) + math.abs(y - head.y) >= 6
            if safe then
                for dy = 0, size - 1 do
                    for dx = 0, size - 1 do
                        if not helpers.validarPos(x + dx, y + dy, body, food.pos, obstacles, w, h, enemies.list) then
                            safe = false
                        end
                    end
                end
            end
            if safe then return x, y end
        end
    end
end

function stageFlow.start(st)
    if st.modo == "boss_rush" then
        st.stagePhase = worldMod.etapa <= 5 and "miniboss" or "boss"
    else
        st.stagePhase = "survival"
    end
    st.stageEncounterSpawned = false
end

-- Salta una fase desde el depurador; devuelve false para la fase de jefe,
-- cuya salida debe usar la transicion normal de etapa.
function stageFlow.skipPhase(st)
    if st.stagePhase == "survival" then
        st.waveCurrent = st.waveTotal
        st.waveTimer = 0
        return true
    elseif st.stagePhase == "miniboss" then
        if st.modo == "boss_rush" then
            require("entities.enemyMiniBoss").clear()
            st.stageEncounterSpawned = true
            return true
        end
        require("entities.enemyMiniBoss").clear()
        st.stagePhase = "boss"
        st.stageEncounterSpawned = false
        return true
    end
    return false
end

function stageFlow.update(st, dt)
    if not st.stagePhase or st.transitionTarget then return end
    if st.stagePhase == "survival" then
        st.waveTimer = math.max(0, st.waveTimer - dt)
        if st.waveTimer > 0 then return end
        if st.waveCurrent < st.waveTotal then
            st.waveCurrent = st.waveCurrent + 1
            st.waveTimer = st.waveMaxTimer
            populate.spawnWave(st.waveCurrent, worldMod.etapa, worldMod.getCurrentRoom(), st.player.body,
                st.anchoGrilla, st.altoGrilla, obstacles, enemies)
            ui.addPopup("OLEADA " .. st.waveCurrent .. "/" .. st.waveTotal, math.floor(st.anchoGrilla / 2), 2)
        else
            require("systems.roomEvents").reset(st)
            require("systems.mystery").finishStageEvent(worldMod)
            st.stagePhase = "miniboss"
            st.stageEncounterSpawned = false
        end
    elseif st.stagePhase == "miniboss" then
        if not st.stageEncounterSpawned then
            local x, y = findPosition(st, 2)
            if not x then return end
            local boss = enemies.spawnMiniBoss(worldMod.etapa, x, y)
            if boss then
                st.stageEncounterSpawned = true
                ui.addPopup("MINI-JEFE: " .. boss.name, x, y)
            end
        elseif not enemies.getMiniBoss() then
            if st.modo == "boss_rush" then
                st.stagePhase = "intermission"
                st.transitionTarget = "siguienteEtapa"
                st.transitionPhase = 1
                st.fadeDir = 1
                st.gameState = constants.GAME_STATE_TRANSITION
                return
            end
            st.stagePhase = "boss"
            st.stageEncounterSpawned = false
        end
    elseif st.stagePhase == "boss" and not st.stageEncounterSpawned then
        local x, y = findPosition(st, 1)
        if not x then return end
        local mod = worldMod.getStageMod()
        local hp = st.modo == "boss_rush" and (constants.BOSS_HEADBUTT_HP or 12)
            or math.floor((constants.BOSS_HEADBUTT_HP or 12) * (mod.hpMult or 1))
        local boss = enemies.spawnBoss(worldMod.etapa, st.anchoGrilla, st.altoGrilla, hp, 5 + worldMod.etapa * 2)
        if boss then
            boss.x, boss.y = x, y
            st.stageEncounterSpawned = true
            ui.addPopup("JEFE: CABECEALO CON COMBO x2+", x, y)
        end
    end
end

return stageFlow

-- =============================================================================
-- MÓDULO: systems/gamestates/transition.lua
-- Parte de P03 — Split de systems/gamestates.lua (643 → 4 módulos)
-- Contiene updateTransition (fade 1 → hold 2s → fade 2 → SHOP)
-- Extraído de systems/gamestates.lua sin cambios de semántica.
-- =============================================================================
local transition = {}
local constants = require("constants")
local world = require("core.world")
local sound = require("audio.sound")
local shop = require("systems.shop")
local tarotMod = require("systems.tarot")
local mutatorsMod = require("systems.roomMutators")
local worldMod = require("world.world")
local achievementsMod = require("systems.achievements")
local persistence = require("systems.persistence")
local uiMod = require("ui.ui")

local function flushPendingAchievements()
    if not world.state.pendingAchievements or #world.state.pendingAchievements == 0 then return end
    for _, aid in ipairs(world.state.pendingAchievements) do
        local reg = achievementsMod and achievementsMod.registry and achievementsMod.registry[aid]
        if reg then
            uiMod.showToast({id=aid, title=reg.title, subtitle=reg.desc, reward=reg.reward})
        end
    end
    world.state.pendingAchievements = {}
end

function transition.update(dt)
    local st = world.state
    if st.transitionPhase == 1 and st.fadeAlpha >= 1 then
        if not st.roomDamaged then
            st.survivalStreak = (st.survivalStreak or 1.0) + (constants.SURVIVAL_STREAK_INCREMENT or 0.1)
            st.highestStreak = math.max(st.highestStreak or 1.0, st.survivalStreak)
            persistence.syncActiveProfile()
        end
        st.roomDamaged = false

        -- Tarot XI. Corazón de Hierro: sala superada con <5 segmentos = Escudo gratis
        if st.transitionTarget == "siguienteSala" and tarotMod.has("iron_heart")
            and st.player and st.player.body and #st.player.body < 5
            and not world.get("shop.shieldActive", false) then
            if st.modo == "pacifista" then
                st.monedas = (st.monedas or 0) + 10
                local headC = st.player.body[1]
                uiMod.addPopup("CORAZON +10$", headC.x, headC.y)
            else
                shop.shieldActive = true
                local head = st.player.body[1]
                uiMod.addPopup("CORAZON +ESCUDO", head.x, head.y)
            end
        end

        -- Velo Silencioso (GDD §19.64): duplica las monedas ganadas en la sala
        if st.transitionTarget == "siguienteSala" and mutatorsMod.has("silent_veil") then
            local bonus = mutatorsMod.silentClearBonus(st.monedas or 0)
            if bonus > 0 then
                st.monedas = st.monedas + bonus
                local head = st.player.body and st.player.body[1]
                if head then uiMod.addPopup("VELO x2 +" .. bonus .. "$", head.x, head.y) end
            end
        end

        if st.transitionTarget == "siguienteSala" then
            worldMod.avanzarSala()
        elseif st.transitionTarget == "siguienteEtapa" then
            worldMod.avanzarEtapa()
            achievementsMod.check("stageChanged", {stage = worldMod.etapa})
        elseif st.transitionTarget == "completado" then
            local okM, modesMod = pcall(require, "systems.modes")
            local endless = okM and modesMod and modesMod.current() == "endless"
            local prof = persistence.getActiveProfile()
            if prof then
                prof.stats = prof.stats or {}
                if not prof.stats.endlessUnlocked then
                    prof.stats.endlessUnlocked = true
                    persistence.saveProfiles()
                end
                if endless then
                    local okUi, ui = pcall(require, "ui.ui")
                    if okUi and ui then
                        pcall(function() ui.showToast({id = "endless", title = "ABISMO " .. (worldMod.etapa + 1), subtitle = "La mazmorra continua", reward = ""}) end)
                    end
                end
            end
            if endless then
                st.transitionTarget = "siguienteEtapa"
                worldMod.avanzarEtapa()
                achievementsMod.check("stageChanged", {stage = worldMod.etapa})
            else
                st.mundoCompletado = true
                if st.modo == "pacifista" and st.runNoBomb ~= false and st.runNoShield ~= false then
                    local okUiP, uiP = pcall(require, "ui.ui")
                    if okUiP and uiP then
                        pcall(function() uiP.showToast({id = "pacifista", title = "PACIFISTA COMPLETO", subtitle = "Sin bomba ni escudo", reward = ""}) end)
                    end
                end
            end
        end
        st.transitionPhase = "hold"
        st.transitionHoldTimer = 0
        flushPendingAchievements()
    elseif st.transitionPhase == "hold" then
        st.transitionHoldTimer = st.transitionHoldTimer + dt
        if st.transitionHoldTimer >= 2.0 then
            st.transitionPhase = 2
            st.fadeDir = -1
        end
    elseif st.transitionPhase == 2 and st.fadeAlpha <= 0 then
        st.transitionTarget = nil
        st.transitionPhase = nil
        st.gameState = constants.GAME_STATE_SHOP
        sound:playSegment("intro")
        shop.abrir(st.monedas, true)
    end
end

return transition

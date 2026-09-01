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

        if st.transitionTarget == "siguienteSala" then
            worldMod.avanzarSala()
        elseif st.transitionTarget == "siguienteEtapa" then
            worldMod.avanzarEtapa()
            achievementsMod.check("stageChanged", {stage = worldMod.etapa})
        elseif st.transitionTarget == "completado" then
            st.mundoCompletado = true
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
        shop.abrir(st.monedas)
    end
end

return transition

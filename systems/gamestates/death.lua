-- =============================================================================
-- MÓDULO: systems/gamestates/death.lua
-- Parte de P03 — Split de systems/gamestates.lua (643 → 4 módulos)
-- Contiene updateDeath (despiece + SHOP/HIGH_SCORE) y updateHighScore.
-- Extraído de systems/gamestates.lua sin cambios de semántica.
-- =============================================================================
local death = {}
local constants = require("constants")
local world = require("core.world")
local sound = require("audio.sound")
local shop = require("systems.shop")
local worldMod = require("world.world")
local particles = require("render.particles")
local achievementsMod = require("systems.achievements")
local persistence = require("systems.persistence")
local gameflow = require("systems.gameflow")
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

function death.updateDeath(dt)
    local st = world.state
    st.deathAnimTimer = st.deathAnimTimer + dt
    if st.deathAnimTimer >= constants.DEATH_ANIMATION_SEGMENT_DELAY then
        st.deathAnimTimer = 0
        if #st.player.body > 0 then
            local seg = st.player.body[#st.player.body]
            local tam = constants.TAMANIO_BLOQUE
            table.insert(st.activePS, {
                ps = particles.muerte(seg.x * tam + tam / 2, seg.y * tam + tam / 2)
            })
            table.remove(st.player.body, #st.player.body)
        else
            st.fadeDir = -1
            worldMod.init()
            if st.nuevoHighScore then
                st.celebrationTimer = constants.HIGH_SCORE_CELEBRATION_DURATION
                st.gameState = constants.GAME_STATE_HIGH_SCORE
            else
                flushPendingAchievements()
                gameflow.applyActiveProfile()
                st.gameState = constants.GAME_STATE_SHOP
                sound:playSegment("intro")
                shop.abrir(st.monedas)
            end
        end
    end
end

function death.updateHighScore(dt)
    local st = world.state
    st.celebrationTimer = st.celebrationTimer - dt
    if st.celebrationTimer <= 0 then
        st.fadeDir = -1
        flushPendingAchievements()
        gameflow.applyActiveProfile()
        st.gameState = constants.GAME_STATE_SHOP
        sound:playSegment("intro")
        shop.abrir(st.monedas)
    end
end

return death

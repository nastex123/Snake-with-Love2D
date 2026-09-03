-- systems/gamestates.lua — Fachada (P03)
-- P03 Split 643 → fachada ~190L + 3 submódulos:
--   systems/gamestates/playing.lua    (updatePlaying 372L)
--   systems/gamestates/transition.lua (updateTransition 40L)
--   systems/gamestates/death.lua      (updateDeath + updateHighScore 40L)
-- Mantiene API pública idéntica.
local states = {}
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
local sound = require("audio.sound")
local shop = require("systems.shop")
local uiMod = require("ui.ui")
local obstaclesMod = require("entities.obstacles")
local enemiesMod = require("entities.enemies")
local shadersMod = require("render.shaders")
local achievementsMod = require("systems.achievements")

local playing = require("systems.gamestates.playing")
local transition = require("systems.gamestates.transition")
local death = require("systems.gamestates.death")

function states.overlaysOpen()
    local profilesMod = require("systems.profiles")
    local settingsMod = require("systems.settings")
    return (profilesMod and profilesMod.visible)
        or (settingsMod and settingsMod.visible)
        or world.state.debugAchievementsOpen
end

function states.flushPendingAchievements()
    if not world.state.pendingAchievements or #world.state.pendingAchievements == 0 then return end
    for _, aid in ipairs(world.state.pendingAchievements) do
        local reg = achievementsMod and achievementsMod.registry and achievementsMod.registry[aid]
        if reg then
            uiMod.showToast({id=aid, title=reg.title, subtitle=reg.desc, reward=reg.reward})
        end
    end
    world.state.pendingAchievements = {}
end

local function processToasts()
    local st = world.state
    if st.scheduledToasts and #st.scheduledToasts > 0 then
        local i = 1
        while i <= #st.scheduledToasts do
            local toast = st.scheduledToasts[i]
            if st.time >= toast.showAt then
                if states.overlaysOpen() then
                    i = i + 1
                else
                    uiMod.showToast(toast.payload)
                    if st.scheduledIndex then st.scheduledIndex[toast.id] = nil end
                    if st.pendingAchievements then
                        for j = #st.pendingAchievements, 1, -1 do
                            if st.pendingAchievements[j] == toast.id then
                                table.remove(st.pendingAchievements, j)
                            end
                        end
                    end
                    table.remove(st.scheduledToasts, i)
                end
            else
                i = i + 1
            end
        end
    end
end

local prevComboActive = false

function states.updateCommon(dt)
    local st = world.state
    st.time = st.time + dt

    timers.update(dt)
    shadersMod.update(dt)
    processToasts()

    sound:update(dt)
    if st.gameState == constants.GAME_STATE_MENU then
        if sound:getCurrentSegment() ~= "intro" or not sound:isPlaying() then
            sound:playSegment("intro")
        end
        prevComboActive = false
    elseif st.gameState == constants.GAME_STATE_PLAYING then
        local comboActive = (st.comboCount and st.comboCount > 0)
        if enemiesMod.boss and enemiesMod.boss.alive then
            if sound:getCurrentSegment() ~= "boss" or not sound:isPlaying() then
                sound:playSegment("boss")
            end
            prevComboActive = false
        elseif comboActive then
            if not prevComboActive then
                sound:crossfadeTo("comboEnter")
            end
            prevComboActive = true
        else
            if sound:getCurrentSegment() ~= "intro" or not sound:isPlaying() then
                sound:playSegment("intro")
            end
            prevComboActive = false
        end
    else
        prevComboActive = false
    end

    if st.shakeTimer > 0 then
        st.shakeTimer = st.shakeTimer - dt
    end

    if st.fadeDir ~= 0 then
        st.fadeAlpha = math.max(0, math.min(1, st.fadeAlpha + st.fadeDir * constants.FADE_SPEED * dt))
        if st.fadeAlpha <= 0 or st.fadeAlpha >= 1 then
            st.fadeDir = 0
        end
    end

    local settingsMod = require("systems.settings")
    if settingsMod and settingsMod.update then settingsMod.update(dt) end

    for i = #st.activePS, 1, -1 do
        local entry = st.activePS[i]
        entry.ps:update(dt)
        if entry.ps:getCount() == 0 then
            table.remove(st.activePS, i)
        end
    end

    obstaclesMod.update(dt)
    if st.menuPS and st.menuPS.update then st.menuPS:update(dt) end

    -- P05: shockwaves tweeneados por core/timers (playing.lua), mantener compat legacy con timer
    for i = #st.shockwaves, 1, -1 do
        local sw = st.shockwaves[i]
        if sw.timer ~= nil then
            sw.radio = sw.radio + 120 * dt
            sw.timer = sw.timer + dt
            sw.alpha = 1 - sw.timer / 0.4
            if sw.alpha <= 0 then
                table.remove(st.shockwaves, i)
            end
        end
    end

    -- P05: activeTimers ahora vive en core/timers pool (player.lua addOrRefreshTimer usa timers.after)
    -- Mantener compatibilidad solo para inserts legacy de tests (sin _handle)
    for i = #st.activeTimers, 1, -1 do
        local t = st.activeTimers[i]
        if not t._handle then
            t.remaining = math.max(0, (t.remaining or 0) - dt)
            if t.remaining <= 0 then
                local cb = t.onEnd
                table.remove(st.activeTimers, i)
                if cb then pcall(cb) end
            end
        else
            -- pooled: sincronizar remaining para HUD (opcional, no afecta onEnd)
            if t._handle and t._handle.delay then
                local rem = t._handle.delay - (t._handle.accum or 0)
                t.remaining = rem > 0 and rem or 0
            end
        end
    end

    if world.state.gameState ~= constants.GAME_STATE_SHOP then
        shop.update(dt)
    end
end

function states.updateMenu(dt)
    world.state.introTimer = world.state.introTimer + dt
end

-- Delegaciones — mantienen API idéntica para tests y main.lua
states.updatePlaying = playing.update
states.updateTransition = transition.update
states.updateDeath = death.updateDeath
states.updateHighScore = death.updateHighScore

function states.updateShop(dt)
    shop.update(dt)
end

function states.updatePaused(dt)
end

function states.update(dt)
    states.updateCommon(dt)
    local g = world.state.gameState
    if g == constants.GAME_STATE_MENU then
        return states.updateMenu(dt)
    elseif g == constants.GAME_STATE_PLAYING then
        return states.updatePlaying(dt)
    elseif g == constants.GAME_STATE_DEATH_ANIMATION then
        return states.updateDeath(dt)
    elseif g == constants.GAME_STATE_HIGH_SCORE then
        return states.updateHighScore(dt)
    elseif g == constants.GAME_STATE_SHOP then
        return states.updateShop(dt)
    elseif g == constants.GAME_STATE_PAUSED then
        return states.updatePaused(dt)
    elseif g == constants.GAME_STATE_TRANSITION then
        return states.updateTransition(dt)
    end
end

return states

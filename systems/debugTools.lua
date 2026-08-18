-- systems/debugTools.lua — Herramientas de depuración (menú Tab + modal de logros)
local debugTools = {}
local constants = require("constants")
local world = require("core.world")
local uiMod = require("ui.ui")
local persistence = require("systems.persistence")
local achievementsMod = require("systems.achievements")
local worldMod = require("world.world")
local gameflow = require("systems.gameflow")

function debugTools.getAchievementState(id)
    local profile = persistence.getActiveProfile()
    if not profile or not profile.achievements then return false end
    local a = profile.achievements[id]
    return a and a.done or false
end

function debugTools.toggleDebugAchievement(id)
    local profile = persistence.getActiveProfile()
    if not profile then return end
    profile.achievements = profile.achievements or {}
    local was = profile.achievements[id] and profile.achievements[id].done
    if was then
        profile.achievements[id] = nil
    else
        profile.achievements[id] = {done = true, at = os.time()}
        local reg = achievementsMod.registry[id]
        if reg then
            local pending = world.get("pendingAchievements")
            if pending then
                local exists = false
                for _, x in ipairs(pending) do if x == id then exists = true break end end
                if not exists then table.insert(pending, id) end
            elseif uiMod.showToast then
                uiMod.showToast({id = id, title = reg.title, subtitle = reg.desc})
            end
        end
    end
    persistence.saveProfiles()
end

function debugTools.dibujarDebugMenu()
    local st = world.state
    local px, py = 10, 50
    local pw = 210
    local bh = 26
    local gap = 4
    local pad = 8
    local bw = pw - pad * 2
    local halfW = (bw - gap) / 2

    -- Background panel
    love.graphics.setColor(0.08, 0.08, 0.15, 0.88)
    love.graphics.rectangle("fill", px, py, pw, 300, 6)

    -- Title
    love.graphics.setColor(0, 0.85, 1, 1)
    love.graphics.setFont(uiMod.fontSmall)
    love.graphics.print("DEBUG", px + pad, py + 6)

    local y = py + 26
    st.debugButtons = {}

    local function addBtn(label, action, x, w, color)
        color = color or {0.2, 0.2, 0.35, 1}
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", x, y, w, bh, 4)
        table.insert(st.debugButtons, {x = x, y = y, w = w, h = bh, action = action})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(uiMod.fontSmall)
        love.graphics.print(label, x + 6, y + (bh - uiMod.fontSmall:getHeight()) / 2)
    end

    addBtn("[K] Skip Room", "skip", px + pad, bw)
    y = y + bh + gap

    addBtn("Skip Stage", "skipStage", px + pad, bw)
    y = y + bh + gap

    addBtn("[L] +10 Coins", "coins", px + pad, bw)
    y = y + bh + gap

    local immuneColor = st.debugImmune and {0.5, 0.1, 0.1, 1} or {0.2, 0.2, 0.35, 1}
    addBtn("Inmune: " .. (st.debugImmune and "ON" or "OFF"), "immune", px + pad, bw, immuneColor)
    y = y + bh + gap

    addBtn("Speed +", "speedUp", px + pad, halfW)
    addBtn("Speed -", "speedDown", px + pad + halfW + gap, halfW)
    y = y + bh + gap

    addBtn("Racha +", "comboUp", px + pad, halfW)
    addBtn("Racha -", "comboDown", px + pad + halfW + gap, halfW)
    y = y + bh + gap

    addBtn("Logros", "achievements", px + pad, bw, st.debugAchievementsOpen and {0.5, 0.1, 0.1, 1} or nil)
    y = y + bh + gap

    addBtn("Mapa", "dungeonMap", px + pad, bw, st.debugDungeonOverlay and {0.5, 0.1, 0.5, 1} or nil)
    y = y + bh + gap

    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.setFont(uiMod.fontSmall)
    love.graphics.print("Vel: " .. string.format("%.3f", st.baseSpeed), px + pad, y + 4)
    love.graphics.print("Racha: " .. (st.comboCount or 0), px + pad + 100, y + 4)
end

function debugTools.drawDebugAchievementsModal()
    local st = world.state
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mw, mh = 440, math.min(360, h - 80)
    local mx = (w - mw) / 2
    local my = 30

    -- background
    love.graphics.setColor(0.08, 0.08, 0.15, 0.95)
    love.graphics.rectangle("fill", mx, my, mw, mh, 8)
    love.graphics.setColor(0, 0.85, 1, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mw, mh, 8)

    -- title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(uiMod.fontLarge)
    love.graphics.printf("LOGROS (DEBUG)", mx, my + 8, mw, "center")

    -- list achievements
    love.graphics.setFont(uiMod.fontSmall)
    local ry = my + 40
    local rowH = 26
    local pad = 8
    local btnW = 100
    local textX = mx + pad
    local btnX = mx + mw - pad - btnW
    local lineH = love.graphics.getFont():getHeight()

    st.debugAchievementModalButtons = {}

    local ordered = {"first_kill","enemy_25","enemy_100","combo_5","combo_10","coins_100","coins_500","stage_3","boss_kill","score_1000","score_5000"}
    for _, id in ipairs(ordered) do
        local reg = achievementsMod.registry[id]
        if not reg then break end
        if ry + rowH <= my + mh - 8 then
            local unlocked = debugTools.getAchievementState(id)

            love.graphics.setColor(unlocked and constants.COLOR_GOLD[1] or 0.5, unlocked and constants.COLOR_GOLD[2] or 0.5, unlocked and constants.COLOR_GOLD[3] or 0.5, 1)
            local txt = (unlocked and "[X] " or "[ ] ") .. reg.title .. " - " .. reg.desc
            love.graphics.print(txt, textX, ry + (rowH - lineH) / 2)

            local btnColor = unlocked and {0.3, 0.3, 0.5, 1} or {0.5, 0.2, 0.1, 1}
            local btnLabel = unlocked and "BLOQUEAR" or "DESBLOQUEAR"
            love.graphics.setColor(btnColor)
            love.graphics.rectangle("fill", btnX, ry + 2, btnW, rowH - 4, 4)
            table.insert(st.debugAchievementModalButtons, {x = btnX, y = ry + 2, w = btnW, h = rowH - 4, id = id})
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(btnLabel, btnX + 4, ry + (rowH - lineH) / 2)

            ry = ry + rowH
        end
    end
end

-- Procesa clicks del menú debug (Tab) y del modal de logros.
-- Devuelve true si el clic fue consumido por las herramientas de debug.
function debugTools.mousepressed(x, y, button)
    local st = world.state

    if st.debugMenuOpen and button == 1 then
        for _, btn in ipairs(st.debugButtons or {}) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == "skip" then
                    if not st.transitionTarget then
                        if worldMod.esJefe() then
                            st.transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                        else
                            st.transitionTarget = "siguienteSala"
                        end
                        st.transitionPhase = 1
                        st.fadeDir = 1
                        st.gameState = constants.GAME_STATE_TRANSITION
                    end
                elseif btn.action == "skipStage" then
                    if not st.transitionTarget then
                        st.transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                        st.transitionPhase = 1
                        st.fadeDir = 1
                        st.gameState = constants.GAME_STATE_TRANSITION
                    end
                elseif btn.action == "coins" then
                    st.monedas = st.monedas + 10
                elseif btn.action == "immune" then
                    st.debugImmune = not st.debugImmune
                elseif btn.action == "speedUp" then
                    st.baseSpeed = math.max(constants.MIN_BASE_SPEED, st.baseSpeed - constants.SPEED_ADJUST_INCREMENT)
                    st.velocidadActual = gameflow.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
                elseif btn.action == "speedDown" then
                    st.baseSpeed = math.min(constants.MAX_BASE_SPEED, st.baseSpeed + constants.SPEED_ADJUST_INCREMENT)
                    st.velocidadActual = gameflow.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
                elseif btn.action == "comboUp" then
                    st.comboCount = (st.comboCount or 0) + 1
                elseif btn.action == "comboDown" then
                    st.comboCount = math.max(0, (st.comboCount or 0) - 1)
                elseif btn.action == "achievements" then
                    st.debugAchievementsOpen = not st.debugAchievementsOpen
                elseif btn.action == "dungeonMap" then
                    st.debugDungeonOverlay = not st.debugDungeonOverlay
                end
                return true
            end
        end
    end

    -- Achievement debug modal clicks
    if st.debugAchievementsOpen and button == 1 then
        for _, abtn in ipairs(st.debugAchievementModalButtons or {}) do
            if x >= abtn.x and x <= abtn.x + abtn.w and y >= abtn.y and y <= abtn.y + abtn.h then
                debugTools.toggleDebugAchievement(abtn.id)
                return true
            end
        end
        -- click outside → close modal
        local w, h = love.graphics.getDimensions()
        local mw, mh = 440, math.min(360, h - 80)
        local mx = (w - mw) / 2
        local my = 30
        if x < mx or x > mx + mw or y < my or y > my + mh then
            st.debugAchievementsOpen = false
            return true
        end
    end

    return false
end

return debugTools
-- systems/debugTools.lua — Herramientas de depuración (menú Tab + modal de logros + debug logo F2)
local debugTools = {}
local constants = require("constants")
local world = require("core.world")
local uiMod = require("ui.ui")
local persistence = require("systems.persistence")
local achievementsMod = require("systems.achievements")
local worldMod = require("world.world")
local gameflow = require("systems.gameflow")
local menuUI = require("ui.menuUI")
local sound = require("audio.sound")

-- Estado del Debug de Posición de Logo (F2)
local logoDebugDragging = false
local logoDragStartX = 0
local logoDragStartY = 0
local logoInitialOffsetX = 0
local logoInitialOffsetY = 0
local logoDebugButtons = {}

function debugTools.isLogoDebugOpen()
    return world.state.debugLogoOpen == true
end

function debugTools.toggleLogoDebug()
    world.state.debugLogoOpen = not world.state.debugLogoOpen
    if world.state.debugLogoOpen then
        sound.play("buttonClick")
        if uiMod.showToast then
            uiMod.showToast({title = "DEBUG LOGO [F2]", subtitle = "Arrastra con ratón o usa Flechas. Enter/F2 para guardar."})
        end
    else
        sound.play("buttonClick")
        persistence.saveLogoConfig()
        if uiMod.showToast then
            uiMod.showToast({title = "GUARDADO PERMANENTE", subtitle = "Posición y escala del logo guardadas con éxito."})
        end
    end
end

function debugTools.drawLogoDebug()
    local st = world.state
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local t = st.time or 0

    local cfg = persistence.getLogoConfig()
    local startX, startY, totalW, totalH, depth, pScale, spacing = menuUI.getLogoBounds(t)

    -- 1. Rectángulo delimitador y retícula sobre el logo
    local bx = startX - depth - 4
    local by = startY - 4
    local bw = totalW + depth + 8
    local bh = totalH + depth + 8

    -- Cuadro delimitador pulsante cian/oro
    local pulse = 0.7 + math.sin(t * 6) * 0.3
    love.graphics.setColor(0, 0.94, 1, pulse * 0.4)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3)
    love.graphics.setColor(0, 0.94, 1, pulse)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 3)

    -- Retícula central
    local cx = startX + math.floor(totalW / 2)
    local cy = startY + math.floor(totalH / 2)
    love.graphics.setColor(1, 0.82, 0.25, 0.9)
    love.graphics.line(cx - 10, cy, cx + 10, cy)
    love.graphics.line(cx, cy - 10, cx, cy + 10)

    -- Badge flotante con coordenadas exactas sobre el logo
    local fontS = uiMod.fontSmall or love.graphics.getFont()
    love.graphics.setFont(fontS)
    local coordStr = string.format("X: %d (Off: %+d)  Y: %d (Off: %+d)", startX, cfg.offsetX or 0, startY, cfg.offsetY or 0)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", bx, by - 16, fontS:getWidth(coordStr) + 8, 14, 2)
    love.graphics.setColor(0, 0.94, 1, 1)
    love.graphics.print(coordStr, bx + 4, by - 15)

    -- 2. Panel HUD Táctico de Control (Esquina Superior Derecha)
    local pw = 286
    local ph = 180
    local px = w - pw - 10
    local py = 10

    logoDebugButtons = {}

    -- Fondo del panel
    love.graphics.setColor(0.04, 0.08, 0.14, 0.94)
    love.graphics.rectangle("fill", px, py, pw, ph, 6)
    love.graphics.setColor(0, 0.94, 1, 0.8)
    love.graphics.rectangle("line", px, py, pw, ph, 6)

    -- Cabecera
    love.graphics.setColor(0, 0.94, 1, 1)
    love.graphics.print("AJUSTES DE LOGO [F2]", px + 8, py + 6)
    love.graphics.setColor(0.6, 0.75, 0.9, 1)
    love.graphics.print(string.format("Offset: X:%+d  Y:%+d", cfg.offsetX or 0, cfg.offsetY or 0), px + 8, py + 22)
    love.graphics.print(string.format("Escala: %d  Espacio: %d  Prof: %d", pScale, spacing, depth), px + 8, py + 34)

    -- Función auxiliar para añadir botones al HUD
    local function addHBtn(id, label, bx, by, bw, bh, col)
        col = col or {0.12, 0.22, 0.35, 1}
        love.graphics.setColor(col)
        love.graphics.rectangle("fill", bx, by, bw, bh, 3)
        love.graphics.setColor(0, 0.94, 1, 0.6)
        love.graphics.rectangle("line", bx, by, bw, bh, 3)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, bx, by + math.floor((bh - fontS:getHeight()) / 2), bw, "center")
        table.insert(logoDebugButtons, {id = id, x = bx, y = by, w = bw, h = bh})
    end

    -- Fila 1: Posición X / Y
    local by1 = py + 50
    addHBtn("x_dec", "X -", px + 8, by1, 62, 22)
    addHBtn("x_inc", "X +", px + 74, by1, 62, 22)
    addHBtn("y_dec", "Y -", px + 148, by1, 62, 22)
    addHBtn("y_inc", "Y +", px + 214, by1, 62, 22)

    -- Fila 2: Escala / Profundidad
    local by2 = py + 76
    addHBtn("scale_dec", "Esc -", px + 8, by2, 62, 22)
    addHBtn("scale_inc", "Esc +", px + 74, by2, 62, 22)
    addHBtn("depth_dec", "Prof -", px + 148, by2, 62, 22)
    addHBtn("depth_inc", "Prof +", px + 214, by2, 62, 22)

    -- Fila 3: Acciones (Reset / Guardar / Cerrar)
    local by3 = py + 104
    addHBtn("reset", "RESET", px + 8, by3, 80, 24, {0.35, 0.15, 0.15, 1})
    addHBtn("save", "GUARDAR", px + 94, by3, 94, 24, {0.15, 0.45, 0.25, 1})
    addHBtn("close", "CERRAR", px + 194, by3, 82, 24, {0.25, 0.25, 0.35, 1})

    -- Leyenda de atajos
    love.graphics.setColor(0.5, 0.65, 0.8, 1)
    love.graphics.print("Flechas: Mover (Shift: 10px)", px + 8, py + 134)
    love.graphics.print("[]: Escala | -/+: Prof | R: Reset", px + 8, py + 148)
    love.graphics.print("Enter / F2: Guardar permanentemente", px + 8, py + 162)
    love.graphics.setLineWidth(1)
end

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

-- Procesa clicks del menú debug (Tab), modal de logros y ajuste de logo (F2).
function debugTools.mousepressed(x, y, button)
    local st = world.state

    -- 1. Logo Debug Clicks & Dragging
    if st.debugLogoOpen and button == 1 then
        local cfg = persistence.getLogoConfig()

        -- Clicks en botones del panel HUD
        for _, btn in ipairs(logoDebugButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                sound.play("buttonClick")
                if btn.id == "x_dec" then
                    cfg.offsetX = (cfg.offsetX or 0) - 1
                elseif btn.id == "x_inc" then
                    cfg.offsetX = (cfg.offsetX or 0) + 1
                elseif btn.id == "y_dec" then
                    cfg.offsetY = (cfg.offsetY or 0) - 1
                elseif btn.id == "y_inc" then
                    cfg.offsetY = (cfg.offsetY or 0) + 1
                elseif btn.id == "scale_dec" then
                    cfg.scale = math.max(2, (cfg.scale or 6) - 1)
                elseif btn.id == "scale_inc" then
                    cfg.scale = math.min(12, (cfg.scale or 6) + 1)
                elseif btn.id == "depth_dec" then
                    cfg.depth = math.max(1, (cfg.depth or 5) - 1)
                elseif btn.id == "depth_inc" then
                    cfg.depth = math.min(10, (cfg.depth or 5) + 1)
                elseif btn.id == "reset" then
                    cfg.offsetX = 0
                    cfg.offsetY = 0
                    cfg.scale = 6
                    cfg.spacing = 10
                    cfg.depth = 5
                    persistence.saveLogoConfig()
                    if uiMod.showToast then uiMod.showToast({title = "RESET LOGO", subtitle = "Valores restaurados por defecto."}) end
                elseif btn.id == "save" then
                    persistence.saveLogoConfig()
                    if uiMod.showToast then uiMod.showToast({title = "GUARDADO PERMANENTE", subtitle = "Posición y escala guardadas."}) end
                elseif btn.id == "close" then
                    debugTools.toggleLogoDebug()
                end
                persistence.saveLogoConfig()
                return true
            end
        end

        -- Click dentro del rectángulo delimitador del logo para arrastre directo
        local startX, startY, totalW, totalH, depth = menuUI.getLogoBounds(st.time)
        local bx = startX - depth - 4
        local by = startY - 4
        local bw = totalW + depth + 8
        local bh = totalH + depth + 8

        if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
            logoDebugDragging = true
            logoDragStartX = x
            logoDragStartY = y
            logoInitialOffsetX = cfg.offsetX or 0
            logoInitialOffsetY = cfg.offsetY or 0
            return true
        end
    end

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

function debugTools.mousemoved(x, y, dx, dy)
    if world.state.debugLogoOpen and logoDebugDragging then
        local cfg = persistence.getLogoConfig()
        cfg.offsetX = math.floor(logoInitialOffsetX + (x - logoDragStartX))
        cfg.offsetY = math.floor(logoInitialOffsetY + (y - logoDragStartY))
        return true
    end
    return false
end

function debugTools.mousereleased(x, y, button)
    if world.state.debugLogoOpen and logoDebugDragging then
        logoDebugDragging = false
        persistence.saveLogoConfig()
        return true
    end
    return false
end

function debugTools.keypressed(tecla)
    if tecla == "f2" then
        debugTools.toggleLogoDebug()
        return true
    end

    if world.state.debugLogoOpen then
        local cfg = persistence.getLogoConfig()
        local step = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 1

        if tecla == "return" or tecla == "kpenter" or tecla == "enter" or tecla == "escape" then
            debugTools.toggleLogoDebug()
            return true
        elseif tecla == "left" then
            cfg.offsetX = (cfg.offsetX or 0) - step
            persistence.saveLogoConfig()
            return true
        elseif tecla == "right" then
            cfg.offsetX = (cfg.offsetX or 0) + step
            persistence.saveLogoConfig()
            return true
        elseif tecla == "up" then
            cfg.offsetY = (cfg.offsetY or 0) - step
            persistence.saveLogoConfig()
            return true
        elseif tecla == "down" then
            cfg.offsetY = (cfg.offsetY or 0) + step
            persistence.saveLogoConfig()
            return true
        elseif tecla == "[" then
            cfg.scale = math.max(2, (cfg.scale or 6) - 1)
            persistence.saveLogoConfig()
            return true
        elseif tecla == "]" then
            cfg.scale = math.min(12, (cfg.scale or 6) + 1)
            persistence.saveLogoConfig()
            return true
        elseif tecla == "-" or tecla == "kp-" then
            cfg.depth = math.max(1, (cfg.depth or 5) - 1)
            persistence.saveLogoConfig()
            return true
        elseif tecla == "=" or tecla == "+" or tecla == "kp+" then
            cfg.depth = math.min(10, (cfg.depth or 5) + 1)
            persistence.saveLogoConfig()
            return true
        elseif tecla == "r" then
            cfg.offsetX = 0
            cfg.offsetY = 0
            cfg.scale = 6
            cfg.spacing = 10
            cfg.depth = 5
            persistence.saveLogoConfig()
            if uiMod.showToast then uiMod.showToast({title = "RESET LOGO", subtitle = "Valores restaurados por defecto."}) end
            return true
        end
    end

    return false
end

return debugTools
local playModalUI = {}
local CYAN = {0.0, 0.94, 1.0}
local GOLD = {1.0, 0.82, 0.25}
local BG_BOX = {0.039, 0.051, 0.094}

playModalUI.visible = false
playModalUI.hoverId = nil
playModalUI.msg = nil
playModalUI.msgTimer = 0
playModalUI._buttons = {}

function playModalUI.open()
    playModalUI.visible = true
    playModalUI.hoverId = nil
    playModalUI.msg = nil
    playModalUI.msgTimer = 0
end

function playModalUI.close()
    playModalUI.visible = false
    playModalUI.hoverId = nil
    playModalUI._buttons = {}
end

function playModalUI.update(dt)
    if playModalUI.msgTimer > 0 then
        playModalUI.msgTimer = playModalUI.msgTimer - dt
        if playModalUI.msgTimer <= 0 then playModalUI.msg = nil end
    end
end

function playModalUI.draw(ui)
    if not playModalUI.visible then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    -- Overlay oscurecido
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    local mw = 420
    local mh = 310
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)
    
    -- Caja principal cyberpunk
    love.graphics.setColor(BG_BOX[1], BG_BOX[2], BG_BOX[3], 0.96)
    love.graphics.rectangle("fill", mx, my, mw, mh, 8)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.85)
    love.graphics.rectangle("line", mx, my, mw, mh, 8)
    
    -- Cabecera
    if ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
    love.graphics.printf("SELECCIONAR MODO DE JUEGO", mx, my + 16, mw, "center")
    
    -- Obtener perfil y estado diario
    local persistence = require("systems.persistence")
    local profile = persistence.getActiveProfile and persistence.getActiveProfile()
    local dailyMod = require("systems.daily")
    local alreadyDone = dailyMod.hasAttemptedToday(profile)
    local todayDate = dailyMod.getDateString()
    
    playModalUI._buttons = {}
    
    local btnW = 340
    local btnH = 44
    local bx = mx + math.floor((mw - btnW) / 2)
    local by = my + 54
    local gap = 14
    
    local options = {
        {
            id = "play_standard",
            title = "EXPEDICION ESTANDAR",
            desc = "Avanza por las 5 etapas y derrota al Boss",
            enabled = true,
            color = CYAN,
        },
        {
            id = "play_daily",
            title = "DESAFIO DIARIO (" .. todayDate .. ")",
            desc = alreadyDone and "YA COMPLETADO HOY (1 intento por dia)" or "Semilla diaria fija, tabla competitiva",
            enabled = not alreadyDone,
            color = alreadyDone and {0.5, 0.5, 0.5} or GOLD,
        },
        {
            id = "view_daily_history",
            title = "HISTORIAL DIARIO",
            desc = "Ver puntuaciones registradas en Desafios Diarios",
            enabled = true,
            color = {0.8, 0.8, 0.9},
        },
        {
            id = "close_modal",
            title = "VOLVER AL MENU",
            desc = "",
            enabled = true,
            color = {0.7, 0.7, 0.7},
        }
    }
    
    for i, opt in ipairs(options) do
        local curY = by + (i - 1) * (btnH + gap)
        local isHover = (playModalUI.hoverId == opt.id) and opt.enabled
        
        playModalUI._buttons[#playModalUI._buttons + 1] = {
            id = opt.id,
            x = bx,
            y = curY,
            w = btnW,
            h = btnH,
            enabled = opt.enabled
        }
        
        love.graphics.setColor(0.06, 0.08, 0.14, 0.9)
        love.graphics.rectangle("fill", bx, curY, btnW, btnH, 4)
        
        if isHover then
            love.graphics.setColor(opt.color[1], opt.color[2], opt.color[3], 0.95)
        else
            love.graphics.setColor(opt.color[1], opt.color[2], opt.color[3], 0.4)
        end
        love.graphics.rectangle("line", bx, curY, btnW, btnH, 4)
        
        -- Textos
        if ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
        if isHover then
            love.graphics.setColor(opt.color[1], opt.color[2], opt.color[3], 1)
        elseif opt.enabled then
            love.graphics.setColor(1, 1, 1, 0.9)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        end
        
        if opt.desc and #opt.desc > 0 then
            love.graphics.printf(opt.title, bx, curY + 6, btnW, "center")
            if ui and ui.fontSmall then love.graphics.setFont(ui.fontSmall) end
            if not opt.enabled then love.graphics.setColor(0.9, 0.3, 0.3, 0.9) end
            love.graphics.printf(opt.desc, bx, curY + 24, btnW, "center")
        else
            love.graphics.printf(opt.title, bx, curY + 14, btnW, "center")
        end
    end
    
    if playModalUI.msg and playModalUI.msgTimer > 0 then
        love.graphics.setColor(1, 0.3, 0.3, 0.95)
        if ui and ui.fontSmall then love.graphics.setFont(ui.fontSmall) end
        love.graphics.printf(playModalUI.msg, mx, my + mh - 26, mw, "center")
    end
end

function playModalUI.mousemoved(x, y)
    if not playModalUI.visible then return end
    playModalUI.hoverId = nil
    for _, btn in ipairs(playModalUI._buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            if btn.enabled then
                playModalUI.hoverId = btn.id
            end
            return
        end
    end
end

function playModalUI.mousepressed(x, y, button)
    if not playModalUI.visible then return false end
    if button ~= 1 then return true end
    
    for _, btn in ipairs(playModalUI._buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            local sound = require("audio.sound")
            if not btn.enabled then
                playModalUI.msg = "¡Ya has realizado tu intento diario de hoy!"
                playModalUI.msgTimer = 2.5
                sound.play("buttonClick")
                return true
            end
            
            sound.play("buttonClick")
            if btn.id == "play_standard" then
                playModalUI.close()
                local gameflow = require("systems.gameflow")
                gameflow.startRun()
                return true
            elseif btn.id == "play_daily" then
                playModalUI.close()
                local gameflow = require("systems.gameflow")
                local world = require("core.world")
                world.state.modo = "daily"
                gameflow.startDailyRun()
                return true
            elseif btn.id == "view_daily_history" then
                local dailyResultUI = require("ui.dailyResultUI")
                dailyResultUI.openHistory()
                return true
            elseif btn.id == "close_modal" then
                playModalUI.close()
                return true
            end
        end
    end
    return true
end

return playModalUI

local dailyResultUI = {}
local CYAN = {0.0, 0.94, 1.0}
local GOLD = {1.0, 0.82, 0.25}
local BG_BOX = {0.039, 0.051, 0.094}

dailyResultUI.visible = false
dailyResultUI.entry = nil
dailyResultUI.isHistoryMode = false
dailyResultUI._closeBtn = nil

function dailyResultUI.openResult(entry)
    dailyResultUI.visible = true
    dailyResultUI.entry = entry
    dailyResultUI.isHistoryMode = false
end

function dailyResultUI.openHistory()
    dailyResultUI.visible = true
    dailyResultUI.isHistoryMode = true
    dailyResultUI.entry = nil
end

function dailyResultUI.close()
    dailyResultUI.visible = false
    dailyResultUI.entry = nil
    dailyResultUI.isHistoryMode = false
    dailyResultUI._closeBtn = nil
end

function dailyResultUI.draw(ui)
    if not dailyResultUI.visible then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    local mw = 480
    local mh = 340
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)
    
    love.graphics.setColor(BG_BOX[1], BG_BOX[2], BG_BOX[3], 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 8)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
    love.graphics.rectangle("line", mx, my, mw, mh, 8)
    
    if ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
    
    if not dailyResultUI.isHistoryMode then
        -- Modo resultado de la partida recién completada
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
        love.graphics.printf("RESUMEN DEL DESAFIO DIARIO", mx, my + 18, mw, "center")
        
        local entry = dailyResultUI.entry or {}
        local dateStr = entry.date or "Hoy"
        local score = entry.score or 0
        local stage = entry.stage or 1
        local rooms = entry.roomsCleared or 0
        
        love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
        if ui and ui.fontSmall then love.graphics.setFont(ui.fontSmall) end
        love.graphics.printf("Fecha: " .. dateStr, mx, my + 48, mw, "center")
        
        -- Tarjeta de métricas
        local cardW = 380
        local cardH = 140
        local cx = mx + math.floor((mw - cardW) / 2)
        local cy = my + 76
        
        love.graphics.setColor(0.06, 0.08, 0.14, 0.9)
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 4)
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.5)
        love.graphics.rectangle("line", cx, cy, cardW, cardH, 4)
        
        if ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf("PUNTUACION FINAL:", cx + 20, cy + 20, cardW - 40, "left")
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
        love.graphics.printf(tostring(score), cx + 20, cy + 20, cardW - 40, "right")
        
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf("ETAPA ALCANZADA:", cx + 20, cy + 54, cardW - 40, "left")
        love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 1)
        love.graphics.printf("Etapa " .. tostring(stage), cx + 20, cy + 54, cardW - 40, "right")
        
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf("SALAS COMPLETADAS:", cx + 20, cy + 88, cardW - 40, "left")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(rooms), cx + 20, cy + 88, cardW - 40, "right")
        
        if ui and ui.fontSmall then love.graphics.setFont(ui.fontSmall) end
        love.graphics.setColor(0.6, 0.7, 0.8, 0.8)
        love.graphics.printf("¡Registro guardado en tu perfil para este dia!", mx, my + 230, mw, "center")
    else
        -- Modo Historial / Tabla local
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
        love.graphics.printf("HISTORIAL DE DESAFIOS DIARIOS", mx, my + 16, mw, "center")
        
        local persistence = require("systems.persistence")
        local profile = persistence.getActiveProfile and persistence.getActiveProfile()
        local dailyMod = require("systems.daily")
        local list = dailyMod.getHistoryList(profile, 5)
        
        if #list == 0 then
            love.graphics.setColor(0.6, 0.6, 0.7, 0.8)
            if ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
            love.graphics.printf("No hay desafios diarios registrados aun.\n¡Completa uno hoy para empezar tu historial!", mx + 20, my + 110, mw - 40, "center")
        else
            if ui and ui.fontSmall then love.graphics.setFont(ui.fontSmall) end
            love.graphics.setColor(0.6, 0.7, 0.85, 0.9)
            love.graphics.printf("FECHA", mx + 30, my + 46, 120, "left")
            love.graphics.printf("PUNTOS", mx + 160, my + 46, 100, "center")
            love.graphics.printf("ETAPA", mx + 270, my + 46, 80, "center")
            love.graphics.printf("SALAS", mx + 360, my + 46, 70, "center")
            love.graphics.setColor(0.3, 0.4, 0.5, 0.6)
            love.graphics.line(mx + 26, my + 62, mx + mw - 26, my + 62)
            
            local yOff = my + 72
            for idx, item in ipairs(list) do
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.printf(item.date, mx + 30, yOff, 120, "left")
                love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
                love.graphics.printf(tostring(item.score), mx + 160, yOff, 100, "center")
                love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 1)
                love.graphics.printf("E" .. tostring(item.stage), mx + 270, yOff, 80, "center")
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.printf(tostring(item.roomsCleared), mx + 360, yOff, 70, "center")
                yOff = yOff + 28
            end
        end
    end
    
    -- Botón de cierre
    local btnW = 180
    local btnH = 36
    local bx = mx + math.floor((mw - btnW) / 2)
    local by = my + mh - 50
    dailyResultUI._closeBtn = {x = bx, y = by, w = btnW, h = btnH}
    
    love.graphics.setColor(0.08, 0.12, 0.2, 0.95)
    love.graphics.rectangle("fill", bx, by, btnW, btnH, 4)
    love.graphics.setColor(CYAN[1], CYAN[2], CYAN[3], 0.8)
    love.graphics.rectangle("line", bx, by, btnW, btnH, 4)
    
    if ui and ui.fontNormal then love.graphics.setFont(ui.fontNormal) end
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf("CONTINUAR", bx, by + 10, btnW, "center")
end

function dailyResultUI.mousepressed(x, y, button)
    if not dailyResultUI.visible then return false end
    if button ~= 1 then return true end
    local btn = dailyResultUI._closeBtn
    if btn and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        local sound = require("audio.sound")
        sound.play("buttonClick")
        dailyResultUI.close()
        return true
    end
    return true
end

return dailyResultUI

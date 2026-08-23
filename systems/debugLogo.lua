-- systems/debugLogo.lua - Herramienta F2 de ajuste de logo (extraído de debugTools.lua)
local debugLogo = {}
local world = require("core.world")
local uiMod = require("ui.ui")
local persistence = require("systems.persistence")
local sound = require("audio.sound")
local menuLogo = require("ui.menuLogo")

local dragging = false
local dragStartX = 0
local dragStartY = 0
local initialOffsetX = 0
local initialOffsetY = 0
local buttons = {}

function debugLogo.isOpen()
    return world.state.debugLogoOpen == true
end

function debugLogo.toggle()
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

function debugLogo.draw()
    local st = world.state
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local t = st.time or 0
    local cfg = persistence.getLogoConfig()
    local startX, startY, totalW, totalH, depth, pScale, spacing = menuLogo.getBounds(t)
    local bx = startX - depth - 4
    local by = startY - 4
    local bw = totalW + depth + 8
    local bh = totalH + depth + 8
    local pulse = 0.7 + math.sin(t * 6) * 0.3
    love.graphics.setColor(0, 0.94, 1, pulse * 0.4)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3)
    love.graphics.setColor(0, 0.94, 1, pulse)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 3)
    local cx = startX + math.floor(totalW / 2)
    local cy = startY + math.floor(totalH / 2)
    love.graphics.setColor(1, 0.82, 0.25, 0.9)
    love.graphics.line(cx - 10, cy, cx + 10, cy)
    love.graphics.line(cx, cy - 10, cx, cy + 10)
    local fontS = uiMod.fontSmall or love.graphics.getFont()
    love.graphics.setFont(fontS)
    local coordStr = string.format("X: %d (Off: %+d)  Y: %d (Off: %+d)", startX, cfg.offsetX or 0, startY, cfg.offsetY or 0)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", bx, by - 16, fontS:getWidth(coordStr) + 8, 14, 2)
    love.graphics.setColor(0, 0.94, 1, 1)
    love.graphics.print(coordStr, bx + 4, by - 15)
    local pw = 286
    local ph = 180
    local px = w - pw - 10
    local py = 10
    buttons = {}
    love.graphics.setColor(0.04, 0.08, 0.14, 0.94)
    love.graphics.rectangle("fill", px, py, pw, ph, 6)
    love.graphics.setColor(0, 0.94, 1, 0.8)
    love.graphics.rectangle("line", px, py, pw, ph, 6)
    love.graphics.setColor(0, 0.94, 1, 1)
    love.graphics.print("AJUSTES DE LOGO [F2]", px + 8, py + 6)
    love.graphics.setColor(0.6, 0.75, 0.9, 1)
    love.graphics.print(string.format("Offset: X:%+d  Y:%+d", cfg.offsetX or 0, cfg.offsetY or 0), px + 8, py + 22)
    love.graphics.print(string.format("Escala: %d  Espacio: %d  Prof: %d", pScale, spacing, depth), px + 8, py + 34)
    local function addHBtn(id, label, bx2, by2, bw2, bh2, col)
        col = col or {0.12, 0.22, 0.35, 1}
        love.graphics.setColor(col)
        love.graphics.rectangle("fill", bx2, by2, bw2, bh2, 3)
        love.graphics.setColor(0, 0.94, 1, 0.6)
        love.graphics.rectangle("line", bx2, by2, bw2, bh2, 3)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, bx2, by2 + math.floor((bh2 - fontS:getHeight()) / 2), bw2, "center")
        table.insert(buttons, {id = id, x = bx2, y = by2, w = bw2, h = bh2})
    end
    local by1 = py + 50
    addHBtn("x_dec", "X -", px + 8, by1, 62, 22)
    addHBtn("x_inc", "X +", px + 74, by1, 62, 22)
    addHBtn("y_dec", "Y -", px + 148, by1, 62, 22)
    addHBtn("y_inc", "Y +", px + 214, by1, 62, 22)
    local by2 = py + 76
    addHBtn("scale_dec", "Esc -", px + 8, by2, 62, 22)
    addHBtn("scale_inc", "Esc +", px + 74, by2, 62, 22)
    addHBtn("depth_dec", "Prof -", px + 148, by2, 62, 22)
    addHBtn("depth_inc", "Prof +", px + 214, by2, 62, 22)
    local by3 = py + 104
    addHBtn("reset", "RESET", px + 8, by3, 80, 24, {0.35, 0.15, 0.15, 1})
    addHBtn("save", "GUARDAR", px + 94, by3, 94, 24, {0.15, 0.45, 0.25, 1})
    addHBtn("close", "CERRAR", px + 194, by3, 82, 24, {0.25, 0.25, 0.35, 1})
    love.graphics.setColor(0.5, 0.65, 0.8, 1)
    love.graphics.print("Flechas: Mover (Shift: 10px)", px + 8, py + 134)
    love.graphics.print("[]: Escala | -/+: Prof | R: Reset", px + 8, py + 148)
    love.graphics.print("Enter / F2: Guardar permanentemente", px + 8, py + 162)
    love.graphics.setLineWidth(1)
end

function debugLogo.mousepressed(x, y, button)
    if not world.state.debugLogoOpen or button ~= 1 then return false end
    local cfg = persistence.getLogoConfig()
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            sound.play("buttonClick")
            if btn.id == "x_dec" then cfg.offsetX = (cfg.offsetX or 0) - 1
            elseif btn.id == "x_inc" then cfg.offsetX = (cfg.offsetX or 0) + 1
            elseif btn.id == "y_dec" then cfg.offsetY = (cfg.offsetY or 0) - 1
            elseif btn.id == "y_inc" then cfg.offsetY = (cfg.offsetY or 0) + 1
            elseif btn.id == "scale_dec" then cfg.scale = math.max(2, (cfg.scale or 6) - 1)
            elseif btn.id == "scale_inc" then cfg.scale = math.min(12, (cfg.scale or 6) + 1)
            elseif btn.id == "depth_dec" then cfg.depth = math.max(1, (cfg.depth or 5) - 1)
            elseif btn.id == "depth_inc" then cfg.depth = math.min(10, (cfg.depth or 5) + 1)
            elseif btn.id == "reset" then
                cfg.offsetX = 0; cfg.offsetY = 0; cfg.scale = 6; cfg.spacing = 10; cfg.depth = 5
                persistence.saveLogoConfig()
                if uiMod.showToast then uiMod.showToast({title = "RESET LOGO", subtitle = "Valores restaurados por defecto."}) end
            elseif btn.id == "save" then
                persistence.saveLogoConfig()
                if uiMod.showToast then uiMod.showToast({title = "GUARDADO PERMANENTE", subtitle = "Posición y escala guardadas."}) end
            elseif btn.id == "close" then debugLogo.toggle() end
            persistence.saveLogoConfig()
            return true
        end
    end
    local t = world.state.time or 0
    local startX, startY, totalW, totalH, depth = menuLogo.getBounds(t)
    local bx = startX - depth - 4
    local by = startY - 4
    local bw = totalW + depth + 8
    local bh = totalH + depth + 8
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        dragging = true
        dragStartX = x; dragStartY = y
        initialOffsetX = cfg.offsetX or 0; initialOffsetY = cfg.offsetY or 0
        return true
    end
    return false
end

function debugLogo.mousemoved(x, y)
    if world.state.debugLogoOpen and dragging then
        local cfg = persistence.getLogoConfig()
        cfg.offsetX = math.floor(initialOffsetX + (x - dragStartX))
        cfg.offsetY = math.floor(initialOffsetY + (y - dragStartY))
        return true
    end
    return false
end

function debugLogo.mousereleased()
    if world.state.debugLogoOpen and dragging then
        dragging = false
        persistence.saveLogoConfig()
        return true
    end
    return false
end

function debugLogo.keypressed(tecla)
    if tecla == "f2" then debugLogo.toggle(); return true end
    if not world.state.debugLogoOpen then return false end
    local cfg = persistence.getLogoConfig()
    local step = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 1
    if tecla == "return" or tecla == "kpenter" or tecla == "enter" or tecla == "escape" then debugLogo.toggle(); return true
    elseif tecla == "left" then cfg.offsetX = (cfg.offsetX or 0) - step; persistence.saveLogoConfig(); return true
    elseif tecla == "right" then cfg.offsetX = (cfg.offsetX or 0) + step; persistence.saveLogoConfig(); return true
    elseif tecla == "up" then cfg.offsetY = (cfg.offsetY or 0) - step; persistence.saveLogoConfig(); return true
    elseif tecla == "down" then cfg.offsetY = (cfg.offsetY or 0) + step; persistence.saveLogoConfig(); return true
    elseif tecla == "[" then cfg.scale = math.max(2, (cfg.scale or 6) - 1); persistence.saveLogoConfig(); return true
    elseif tecla == "]" then cfg.scale = math.min(12, (cfg.scale or 6) + 1); persistence.saveLogoConfig(); return true
    elseif tecla == "-" or tecla == "kp-" then cfg.depth = math.max(1, (cfg.depth or 5) - 1); persistence.saveLogoConfig(); return true
    elseif tecla == "=" or tecla == "+" or tecla == "kp+" then cfg.depth = math.min(10, (cfg.depth or 5) + 1); persistence.saveLogoConfig(); return true
    elseif tecla == "r" then cfg.offsetX=0; cfg.offsetY=0; cfg.scale=6; cfg.spacing=10; cfg.depth=5; persistence.saveLogoConfig(); if uiMod.showToast then uiMod.showToast({title="RESET LOGO", subtitle="Valores restaurados por defecto."}) end; return true
    end
    return false
end

return debugLogo

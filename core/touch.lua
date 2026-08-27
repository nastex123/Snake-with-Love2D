-- core/touch.lua — Controles táctiles para pantallas (Android/iOS sin teclado)
--  - Swipe sobre cualquier zona de juego: cambia la dirección de la serpiente
--  - Toque en el botón de pausa (esquina superior derecha): pausa/reanuda
local touch = {}
local world = require("core.world")
local snakeMod = require("entities.snake")
local constants = require("constants")

local SWIPE_MIN = 18

local activeTouches = {}

function touch.hasActiveTouch()
    for _ in pairs(activeTouches) do return true end
    return false
end

function touch.touchpressed(id, x, y)
    activeTouches[id] = {x = x, y = y, moved = false}
end

function touch.touchmoved(id, x, y)
    local t = activeTouches[id]
    if t then
        t.moved = true
        t.x = x
        t.y = y
    end
end

function touch.touchreleased(id, x, y)
    local t = activeTouches[id]
    activeTouches[id] = nil
    if not t then return end

    local st = world.state
    if not st or st.gameState == constants.GAME_STATE_MENU then return end

    -- Botón de pausa: toque en esquina inferior derecha
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local btnSize = math.min(56, w * 0.12)
    local btnX = w - btnSize - 14
    local btnY = h - btnSize - 14
    if not t.moved and x >= btnX and x <= btnX + btnSize and y >= btnY and y <= btnY + btnSize then
        if st.gameState == constants.GAME_STATE_PLAYING then
            st.gameState = constants.GAME_STATE_PAUSED
        elseif st.gameState == constants.GAME_STATE_PAUSED then
            st.gameState = constants.GAME_STATE_PLAYING
        end
        return
    end

    -- Swipe: solo durante el juego activo
    if st.gameState ~= constants.GAME_STATE_PLAYING then return end

    local dx = x - t.x
    local dy = y - t.y
    if math.abs(dx) < SWIPE_MIN and math.abs(dy) < SWIPE_MIN then return end

    local player = st.player
    if not player then return end

    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then
            snakeMod.encolarDireccion(player, 1, 0)
        elseif dx < 0 then
            snakeMod.encolarDireccion(player, -1, 0)
        end
    else
        if dy > 0 then
            snakeMod.encolarDireccion(player, 0, 1)
        elseif dy < 0 then
            snakeMod.encolarDireccion(player, 0, -1)
        end
    end
end

function touch.draw(alpha)
    local st = world.state
    if not st then return end
    if st.gameState ~= constants.GAME_STATE_PLAYING and st.gameState ~= constants.GAME_STATE_PAUSED then return end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local btnSize = math.min(56, w * 0.12)
    local btnX = w - btnSize - 14
    local btnY = h - btnSize - 14
    local isPaused = st.gameState == constants.GAME_STATE_PAUSED

    local pulse
    if alpha then
        pulse = alpha
    else
        pulse = 0.5 + math.sin(love.timer.getTime() * 4) * 0.15
    end

    love.graphics.setColor(0.05, 0.05, 0.12, 0.55)
    love.graphics.rectangle("fill", btnX, btnY, btnSize, btnSize, 8, 8)
    love.graphics.setColor(0.4, 0.6, 1, isPaused and (0.5 + pulse * 0.5) or pulse)
    love.graphics.rectangle("line", btnX, btnY, btnSize, btnSize, 8, 8)

    local cx = btnX + btnSize / 2
    local cy = btnY + btnSize / 2
    local barW = btnSize * 0.11
    local barH = btnSize * 0.42
    love.graphics.setColor(1, 1, 1, 0.9)
    if isPaused then
        love.graphics.polygon("fill", cx - barW, cy - barH, cx + barW, cy, cx - barW, cy + barH)
        love.graphics.polygon("fill", cx + barW, cy - barH, cx - barW, cy, cx + barW, cy + barH)
    else
        love.graphics.rectangle("fill", cx - barW * 1.5, cy - barH, barW, barH * 2)
        love.graphics.rectangle("fill", cx + barW * 0.5, cy - barH, barW, barH * 2)
    end
end

return touch
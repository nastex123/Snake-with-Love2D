-- core/touch.lua — Controles táctiles para pantallas (Android/iOS/Táctil)
--  - Swipe sobre cualquier zona de juego: cambia la dirección de la serpiente (en tiempo real o al soltar)
--  - Toque en el botón de pausa (esquina inferior derecha): pausa/reanuda
local touch = {}
local world = require("core.world")
local constants = require("constants")

local SWIPE_MIN = 18
local TAP_DEADZONE = 12

local activeTouches = {}

touch.SWIPE_MIN = SWIPE_MIN
touch.TAP_DEADZONE = TAP_DEADZONE

--- Convierte coordenadas normalizadas [0, 1] a coordenadas virtuales de pantalla si es necesario.
-- @param x number Coordenada X (normalizada o en píxeles).
-- @param y number Coordenada Y (normalizada o en píxeles).
-- @return number, number Coordenadas virtuales en píxeles.
function touch.toVirtual(x, y)
    local w = love.graphics and love.graphics.getWidth and love.graphics.getWidth() or 640
    local h = love.graphics and love.graphics.getHeight and love.graphics.getHeight() or 360
    if x and y and x >= 0 and x <= 1.0 and y >= 0 and y <= 1.0 and (w > 10 and h > 10) then
        return x * w, y * h
    end
    return x or 0, y or 0
end

--- Obtiene el umbral mínimo de desplazamiento para registrar un swipe.
-- @return number
function touch.getSwipeMin()
    return SWIPE_MIN
end

--- Configura el umbral mínimo de desplazamiento para registrar un swipe.
-- @param val number
function touch.setSwipeMin(val)
    if type(val) == "number" and val > 0 then
        SWIPE_MIN = val
        touch.SWIPE_MIN = val
    end
end

--- Obtiene la distancia máxima de movimiento tolerada para registrar un tap.
-- @return number
function touch.getTapMaxDist()
    return TAP_DEADZONE
end

--- Configura la distancia máxima de movimiento tolerada para registrar un tap.
-- @param val number
function touch.setTapMaxDist(val)
    if type(val) == "number" and val >= 0 then
        TAP_DEADZONE = val
        touch.TAP_DEADZONE = val
    end
end

--- Resetea todos los toques activos en memoria.
function touch.reset()
    for k in pairs(activeTouches) do
        activeTouches[k] = nil
    end
end
touch.load = touch.reset
touch.clear = touch.reset

--- Retorna la información de un toque activo específico.
-- @param id any Identificador del toque.
-- @return table|nil
function touch.getActiveTouch(id)
    return activeTouches[id]
end

--- Retorna el mapa completo de toques activos.
-- @return table
function touch.getActiveTouches()
    return activeTouches
end

--- Retorna el número de toques activos actualmente.
-- @return number
function touch.getActiveTouchCount()
    local count = 0
    for _ in pairs(activeTouches) do count = count + 1 end
    return count
end

--- Indica si hay al menos un toque activo en pantalla.
-- @return boolean
function touch.hasActiveTouch()
    return next(activeTouches) ~= nil
end

--- Obtiene el rectángulo del botón de pausa táctil (esquina inferior derecha).
-- @return number, number, number, number x, y, ancho, alto
function touch.getPauseButtonRect()
    local w = love.graphics and love.graphics.getWidth and love.graphics.getWidth() or 640
    local h = love.graphics and love.graphics.getHeight and love.graphics.getHeight() or 360
    local btnSize = math.min(56, w * 0.12)
    local btnX = w - btnSize - 14
    local btnY = h - btnSize - 14
    return btnX, btnY, btnSize, btnSize
end

--- Comprueba si una coordenada se encuentra dentro del botón de pausa táctil.
-- @param x number
-- @param y number
-- @return boolean
function touch.isInsidePauseButton(x, y)
    local vx, vy = touch.toVirtual(x, y)
    local btnX, btnY, btnSize = touch.getPauseButtonRect()
    return vx >= btnX and vx <= btnX + btnSize and vy >= btnY and vy <= btnY + btnSize
end

--- Procesa una dirección de swipe y la encola en el jugador activo.
-- @param dirX number Dirección X (-1, 0, 1)
-- @param dirY number Dirección Y (-1, 0, 1)
-- @return boolean True si se encoló la dirección
function touch.processSwipe(dirX, dirY)
    local st = world.state
    if not st or not st.player then return false end
    local ok, snakeMod = pcall(require, "entities.snake")
    if not ok or not snakeMod or not snakeMod.encolarDireccion then return false end
    snakeMod.encolarDireccion(st.player, dirX, dirY)
    return true
end

--- Callback al presionar la pantalla táctil.
-- @param id any Identificador del toque.
-- @param x number Coordenada X.
-- @param y number Coordenada Y.
function touch.touchpressed(id, x, y)
    local vx, vy = touch.toVirtual(x, y)
    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
    activeTouches[id] = {
        id = id,
        startX = vx,
        startY = vy,
        x = vx,
        y = vy,
        moved = false,
        swiped = false,
        time = now
    }
end

--- Callback al mover el dedo por la pantalla táctil.
-- @param id any Identificador del toque.
-- @param x number Coordenada X.
-- @param y number Coordenada Y.
function touch.touchmoved(id, x, y)
    local t = activeTouches[id]
    if not t then return end

    local vx, vy = touch.toVirtual(x, y)
    t.x = vx
    t.y = vy

    local dx = vx - t.startX
    local dy = vy - t.startY
    local distSq = dx * dx + dy * dy

    if distSq > (TAP_DEADZONE * TAP_DEADZONE) then
        t.moved = true
    end

    local st = world.state
    if st and st.gameState == constants.GAME_STATE_PLAYING then
        if math.abs(dx) >= SWIPE_MIN or math.abs(dy) >= SWIPE_MIN then
            local dirX, dirY = 0, 0
            if math.abs(dx) > math.abs(dy) then
                dirX = dx > 0 and 1 or -1
            else
                dirY = dy > 0 and 1 or -1
            end
            touch.processSwipe(dirX, dirY)
            t.swiped = true
            t.startX = vx
            t.startY = vy
        end
    end
end

--- Callback al levantar el dedo de la pantalla táctil.
-- @param id any Identificador del toque.
-- @param x number Coordenada X.
-- @param y number Coordenada Y.
function touch.touchreleased(id, x, y)
    local t = activeTouches[id]
    activeTouches[id] = nil
    if not t then return end

    local vx, vy = touch.toVirtual(x, y)
    local st = world.state
    if not st or st.gameState == constants.GAME_STATE_MENU then return end

    local btnX, btnY, btnSize = touch.getPauseButtonRect()
    local startInBtn = (t.startX >= btnX and t.startX <= btnX + btnSize and t.startY >= btnY and t.startY <= btnY + btnSize)
    local releaseInBtn = (vx >= btnX and vx <= btnX + btnSize and vy >= btnY and vy <= btnY + btnSize)
    local totalDistSq = (vx - t.startX) * (vx - t.startX) + (vy - t.startY) * (vy - t.startY)
    local isTap = (totalDistSq <= TAP_DEADZONE * TAP_DEADZONE) or (startInBtn and releaseInBtn)

    -- Botón de pausa: toque en esquina inferior derecha (requiere tap completo dentro)
    if isTap and startInBtn and releaseInBtn then
        if st.gameState == constants.GAME_STATE_PLAYING then
            st.gameState = constants.GAME_STATE_PAUSED
        elseif st.gameState == constants.GAME_STATE_PAUSED then
            st.gameState = constants.GAME_STATE_PLAYING
        end
        return
    end

    -- Swipe: solo durante el juego activo si no fue consumido en touchmoved
    if st.gameState ~= constants.GAME_STATE_PLAYING then return end

    if not t.swiped then
        local dx = vx - t.startX
        local dy = vy - t.startY
        if math.abs(dx) >= SWIPE_MIN or math.abs(dy) >= SWIPE_MIN then
            local dirX, dirY = 0, 0
            if math.abs(dx) > math.abs(dy) then
                dirX = dx > 0 and 1 or -1
            else
                dirY = dy > 0 and 1 or -1
            end
            touch.processSwipe(dirX, dirY)
        end
    end
end

--- Dibuja el botón de pausa táctil en pantalla.
-- @param alpha number|nil Transparencia opcional.
function touch.draw(alpha)
    local st = world.state
    if not st then return end
    if st.gameState ~= constants.GAME_STATE_PLAYING and st.gameState ~= constants.GAME_STATE_PAUSED then return end

    local btnX, btnY, btnSize = touch.getPauseButtonRect()
    local isPaused = st.gameState == constants.GAME_STATE_PAUSED

    local pulse
    if alpha then
        pulse = alpha
    else
        local t = love.timer and love.timer.getTime and love.timer.getTime() or 0
        pulse = 0.5 + math.sin(t * 4) * 0.15
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
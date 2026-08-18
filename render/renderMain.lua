-- render/renderMain.lua — Dibujo principal del juego (love.draw completo)
local renderMain = {}
local constants = require("constants")
local world = require("core.world")
local uiMod = require("ui.ui")
local shop = require("systems.shop")
local itemsMod = require("systems.items")
local obstaclesMod = require("entities.obstacles")
local enemiesMod = require("entities.enemies")
local foodMod = require("entities.food")
local snakeMod = require("entities.snake")
local worldMod = require("world.world")
local shadersMod = require("render.shaders")
local debugTools = require("systems.debugTools")
local settingsMod = require("systems.settings")
local profilesMod = require("systems.profiles")
local touchMod = require("core.touch")

local function isGameState(g)
    return g == constants.GAME_STATE_PLAYING or g == constants.GAME_STATE_PAUSED or g == constants.GAME_STATE_DEATH_ANIMATION or g == constants.GAME_STATE_HIGH_SCORE or g == constants.GAME_STATE_SHOP or g == constants.GAME_STATE_TRANSITION
end

-- Dibuja el mundo (menú o juego) al canvas principal y aplica post-proceso.
function renderMain.drawScene(dt)
    local st = world.state
    love.graphics.setBackgroundColor(constants.COLOR_BG[1], constants.COLOR_BG[2], constants.COLOR_BG[3])

    if st.gameState == constants.GAME_STATE_MENU then
        renderMain.drawMenu(dt)
    elseif isGameState(st.gameState) then
        renderMain.drawGame(dt)
    end
end

function renderMain.drawMenu(dt)
    local st = world.state
    -- Menu: capturar en canvasScene, aplicar heat distortion + CRT
    shadersMod.beginScene()
    local s = 0.8
    if st.introTimer > 1.5 and st.introTimer < 3.0 then
        s = 0.8 + 0.2 * math.min(1, (st.introTimer - 1.5) / 0.5)
    elseif st.introTimer >= 3.0 and st.introTimer < 4.5 then
        s = 0.8 + 0.2 * math.max(0, 1 - (st.introTimer - 3.0) / 1.5)
    end
    shadersMod.drawBalatroBG(st.time, s)
    uiMod.drawBalatroIntro(st.introTimer, st.time, false)
    love.graphics.draw(st.menuPS, 0, 0)
    if st.introTimer >= 2.8 then
        uiMod.drawMenu(st.introTimer, st.time, st.highScore)
    end
    if settingsMod and settingsMod.draw then settingsMod.draw() end
    if profilesMod and profilesMod.visible then profilesMod.draw() end
    love.graphics.setCanvas()

    -- glow: solo elementos luminosos de la intro
    shadersMod.beginGlow()
    uiMod.drawBalatroIntro(st.introTimer, st.time, true)
    love.graphics.setCanvas()

    shadersMod.beginShadow()
    love.graphics.setCanvas()

    shadersMod.composite(st.time, 0.85, st.introTimer >= 3.0)
end

function renderMain.drawGame(dt)
    local st = world.state

    -- CRT más suave cuando hay shake (muerte)
    local crtIntensity = st.shakeTimer > 0
        and (0.6 + 0.4 * (st.shakeTimer / constants.SHAKE_DURATION))
        or 0.75

    -- ---- CANVAS SCENE: todo el juego ----
    shadersMod.beginScene()

    if st.shakeTimer > 0 then
        local intensidad = constants.SHAKE_INTENSITY * (st.shakeTimer / constants.SHAKE_DURATION)
        local t = constants.SHAKE_DURATION - st.shakeTimer
        local sx = math.sin(t * 55) * intensidad
        local sy = math.cos(t * 47) * intensidad
        love.graphics.push()
        love.graphics.translate(sx, sy)
    end

    -- fondo fluido Balatro procedural (siempre llena toda la pantalla)
    shadersMod.drawBalatroBG(st.time, 0.8 + st.comboIntensity * 0.2)

    -- HUD fijo en la parte superior de la pantalla (escala con resolución)
    local hudScale = love.graphics.getHeight() / 600
    uiMod.drawHUD(st.puntuacion, st.highScore, st.monedas, shop.shieldActive, shop.magnetTimer, constants.MAGNET_DURATION, st.baseSpeed, nil, st.comboCount, st.activeTimers, worldMod.etapa, worldMod.sala, worldMod.objetivoSala, hudScale)

    -- Slots en la parte inferior (fijo, fuera del bloque centrado)
    if st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_PAUSED then
        local slotDisplay = {}
        for i = 1, 3 do
            local id = shop.slots[i]
            slotDisplay[i] = id and {name = itemsMod.registry[id].name} or nil
        end
        uiMod.drawSlots(slotDisplay)
    end

    -- Botón de pausa táctil (esquina inferior derecha)
    if st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_PAUSED then
        touchMod.draw()
    end

    -- Dungeon minimap (top-right, fijo)
    if st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_PAUSED then
        uiMod.drawDungeonMap(worldMod.getDungeonMapData())
    end

    -- Debug dungeon overlay (fijo)
    if st.debugDungeonOverlay and (st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_PAUSED) then
        uiMod.drawDebugDungeonOverlay(worldMod.getDungeonMapData())
    end

    -- centrar verticalmente el bloque de juego (grilla + separador + overlays internos)
    love.graphics.push()
    love.graphics.translate(0, st.gameOffsetY)

    -- separador visual HUD / gameplay
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, constants.GRID_OFFSET_Y - 1, love.graphics.getWidth(), constants.GRID_OFFSET_Y - 1)

    -- Boss health bar (encima de la grilla, dentro del bloque de juego)
    if st.bossHealthDisplay and st.gameState == constants.GAME_STATE_PLAYING then
        local w = love.graphics.getWidth()
        local barW = 160
        local barH = 8
        local bx = (w - barW) / 2
        local by = 32
        local frac = st.bossHealthDisplay.vida / st.bossHealthDisplay.vidaMax
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", bx, by, barW, barH, 4, 4)
        love.graphics.setColor(1, 0.2 * frac + 0.6, 0.2 * frac + 0.2, 0.9)
        love.graphics.rectangle("fill", bx, by, barW * frac, barH, 4, 4)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, barW, barH, 4, 4)
    end

    -- offset de grilla
    love.graphics.push()
    love.graphics.translate(st.gridOffsetX, constants.GRID_OFFSET_Y)

    uiMod.drawGrid(st.anchoGrilla, st.altoGrilla, st.time, st.comboIntensity)

    if st.gameState ~= constants.GAME_STATE_SHOP then
        obstaclesMod.draw()
        enemiesMod.draw(st.player and st.player.body and st.player.body[1])
        foodMod.draw(st.time, dt)
        local alpha = (st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_DEATH_ANIMATION)
            and (st.cronometro / st.velocidadActual) or 1
        snakeMod.draw(st.player, alpha)

        if st.magnetRange > 0 and (st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_PAUSED) then
            local tam = constants.TAMANIO_BLOQUE
            local hx = st.player.body[1].x * tam + tam / 2
            local hy = st.player.body[1].y * tam + tam / 2
            local mr = st.magnetRange * tam
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.1)
            love.graphics.circle("fill", hx, hy, mr)
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.25)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", hx, hy, mr)
        end
    end

    for _, entry in ipairs(st.activePS) do
        love.graphics.draw(entry.ps, 0, 0)
    end

    for _, sw in ipairs(st.shockwaves) do
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], sw.alpha * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", sw.x, sw.y, sw.radio)
        love.graphics.setLineWidth(1)
    end

    if st.gameState ~= constants.GAME_STATE_SHOP then
        uiMod.drawPopups()
    end

    love.graphics.pop()  -- fin offset grilla

    love.graphics.pop()  -- fin bloque vertical (st.gameOffsetY)

    if st.shakeTimer > 0 then
        love.graphics.pop()
    end

    uiMod.drawComboFlash(st.time, st.comboCount, st.comboFlashTimer)

    if st.gameState == constants.GAME_STATE_HIGH_SCORE then
        uiMod.drawHighScoreCelebration(st.puntuacion, st.highScore)
    elseif st.gameState == constants.GAME_STATE_SHOP then
        shop.draw(st.monedas, st.velocidadActual)
    elseif st.gameState == constants.GAME_STATE_PAUSED then
        uiMod.drawPauseOverlay()
    end

    if st.mundoCompletado then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        love.graphics.setFont(uiMod.fontTitle)
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
        love.graphics.printf("VICTORIA", 0, h / 2 - 60, w, "center")
        love.graphics.setFont(uiMod.fontNormal)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Has conquistado la mazmorra", 0, h / 2 - 20, w, "center")
    end

    if st.fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, st.fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- Sala completada text (sobre el fade)
    if st.gameState == constants.GAME_STATE_TRANSITION and st.fadeAlpha > 0 then
        if st.transitionPhase == 1 or st.transitionPhase == "hold" then
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            local label = st.transitionTarget == "siguienteSala" and "SALA COMPLETADA"
                or st.transitionTarget == "siguienteEtapa" and "ETAPA COMPLETADA"
                or st.transitionTarget == "completado" and "MAZMORRA SUPERADA"
                or ""
            if label ~= "" then
                local textAlpha = st.transitionPhase == "hold" and 1 or math.min(1, st.fadeAlpha * 2)
                love.graphics.setFont(uiMod.fontLarge)
                love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], textAlpha)
                love.graphics.printf(label, 0, h / 2 - 20, w, "center")
            end
        end
    end

    love.graphics.setCanvas()  -- fin canvasScene

    -- ---- CANVAS GLOW: serpiente + comida + partículas ----
    renderMain.drawGameGlow(dt)

    -- ---- CANVAS SHADOW: silueta de la serpiente ----
    renderMain.drawGameShadow(dt)

    -- ---- COMPOSITE final ----
    shadersMod.composite(st.time, crtIntensity, false)
    if st.debugMenuOpen and (st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_PAUSED) then
        debugTools.dibujarDebugMenu()
    end
    if st.debugAchievementsOpen then
        debugTools.drawDebugAchievementsModal()
    end
    -- draw toasts on top of everything
    if uiMod.drawToasts then uiMod.drawToasts() end
end

function renderMain.drawGameGlow(dt)
    local st = world.state
    love.graphics.setCanvas()
    shadersMod.beginGlow()
    if (st.fadeAlpha and st.fadeAlpha >= 1) or (st.gameState == constants.GAME_STATE_TRANSITION and st.transitionPhase == "hold") then
        love.graphics.setCanvas()
        return
    end
    if st.gameState ~= constants.GAME_STATE_SHOP then
        local moveAlpha = (st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_DEATH_ANIMATION)
            and (st.cronometro / st.velocidadActual) or 1
        local fadeFactor = 1 - math.max(0, math.min(1, st.fadeAlpha or 0))
        if fadeFactor > 0.001 then
            love.graphics.push()
            love.graphics.translate(st.gridOffsetX, constants.GRID_OFFSET_Y + st.gameOffsetY)
            love.graphics.setColor(1, 1, 1, fadeFactor)
            snakeMod.draw(st.player, moveAlpha)
            foodMod.draw(st.time, dt)
            for _, entry in ipairs(st.activePS) do
                love.graphics.draw(entry.ps, 0, 0)
            end
            love.graphics.pop()
        end
    end
    love.graphics.setCanvas()
end

function renderMain.drawGameShadow(dt)
    local st = world.state
    -- ---- CANVAS SHADOW: silueta de la serpiente ----
    shadersMod.beginShadow()
    if (st.fadeAlpha and st.fadeAlpha >= 1) or (st.gameState == constants.GAME_STATE_TRANSITION and st.transitionPhase == "hold") then
        love.graphics.setCanvas()
        return
    end
    if st.gameState ~= constants.GAME_STATE_SHOP then
        local moveAlpha = (st.gameState == constants.GAME_STATE_PLAYING or st.gameState == constants.GAME_STATE_DEATH_ANIMATION)
            and (st.cronometro / st.velocidadActual) or 1
        local fadeFactor = 1 - math.max(0, math.min(1, st.fadeAlpha or 0))
        if fadeFactor > 0.001 then
            love.graphics.push()
            love.graphics.translate(st.gridOffsetX, constants.GRID_OFFSET_Y + st.gameOffsetY)
            love.graphics.setColor(1, 1, 1, fadeFactor)
            snakeMod.draw(st.player, moveAlpha)
            love.graphics.pop()
        end
    end
    love.graphics.setCanvas()
end

return renderMain
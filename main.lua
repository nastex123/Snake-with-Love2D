local constants = require("constants")
local world = require("core.world")
local snakeMod = require("entities.snake")
local uiMod = require("ui.ui")
local persistenceMod = require("systems.persistence")
local shop = require("systems.shop")
local particles = require("render.particles")
local sound = require("audio.sound")
local shadersMod = require("render.shaders")
local itemsMod = require("systems.items")
local worldMod = require("world.world")
local settingsMod = require('systems.settings')
local profilesMod = require('systems.profiles')
local gameflow = require('systems.gameflow')
local playerMod = require('systems.player')
local states = require('systems.gamestates')
local debugTools = require('systems.debugTools')
local renderMain = require('render.renderMain')
local touch = require('core.touch')
local achievementsMod = require('systems.achievements')

-- pending achievements queue (global) - populated by achievementsMod
world.state.pendingAchievements = world.state.pendingAchievements or {}
-- scheduled toast system: delayed, overlay-aware
world.state.scheduledToasts = world.state.scheduledToasts or {}
world.state.scheduledIndex = world.state.scheduledIndex or {}

local function applyActiveProfile()
    gameflow.applyActiveProfile()
end

local function iniciarSala(keepInventory)
    gameflow.iniciarSala(keepInventory)
end

local function recalcularGrilla()
    gameflow.recalcularGrilla()
end

local function triggerDeathAnimation()
    local st = world.state
    st.deathModalOpen = false
    st.shakeTimer = constants.SHAKE_DURATION
    st.hitPause = 0.08
    shadersMod.triggerDamage(1.0, 0.9)
    st.fadeDir = 1
    st.gameState = constants.GAME_STATE_DEATH_ANIMATION
    local oldHighScore = st.highScore
    st.highScore = persistenceMod.guardar(st.puntuacion, st.highScore)
    persistenceMod.syncActiveProfile()
    achievementsMod.check("scoreReached", {score = st.highScore})
    st.nuevoHighScore = st.highScore > oldHighScore
    if st.nuevoHighScore then
        local cx = love.graphics.getWidth() / 2
        local cy = love.graphics.getHeight() / 2
        table.insert(st.activePS, {
            ps = particles.highScore(cx, cy)
        })
        sound.play("highScore")
    end
    st.deathAnimTimer = 0
    local tam = constants.TAMANIO_BLOQUE
    for _, seg in ipairs(st.player.body) do
        table.insert(st.activePS, {
            ps = particles.muerte(seg.x * tam + tam / 2, seg.y * tam + tam / 2)
        })
    end
    sound.play("death")
end

function love.load()
    world.state.gridOffsetY = constants.GRID_OFFSET_Y

    persistenceMod.init()
    persistenceMod.initProfiles()

    local activeProfile = persistenceMod.getActiveProfile()
    if activeProfile then
        applyActiveProfile()
    else
        world.state.highScore = persistenceMod.cargar()
        profilesMod.open()
    end

    uiMod.load()
    particles.load()
    shop.loadFonts()
    sound.load()
    shadersMod.load()

    -- Cargar y aplicar configuración DESPUÉS de inicializar subsistemas (sound/shaders/ui)
    persistenceMod.loadSettings()
    persistenceMod.applySettings(persistenceMod.settings)
    recalcularGrilla()

    world.state.menuPS = particles.menuFondo()

    world.state.activePS = {}
    world.state.activeTimers = {}
    world.state.scoreMultiplier = 1
    world.state.coinBonus = 0
    world.state.timeScale = 1
    world.state.shockwaves = {}
    world.state.comboFlashTimer = 0
    world.state.gameState = constants.GAME_STATE_MENU
    world.state.time = 0
    world.state.introTimer = 0
    world.state.celebrationTimer = 0
    world.state.comboDisplay = 0
    world.state.comboIntensity = 0
    world.state.nuevoHighScore = false
    world.state.shakeTimer = 0
    world.state.fadeAlpha = 0
    world.state.fadeDir = 0
    world.state.transitionTarget = nil
    world.state.transitionPhase = nil
    world.state.transitionHoldTimer = 0
    world.state.bossHealthDisplay = nil
    world.state.mundoCompletado = false
    world.state.debugMenuOpen = false
    world.state.debugImmune = false
    world.state.debugAchievementsOpen = false
    world.state.debugDungeonOverlay = false
    world.state.controlMode = world.state.controlMode or "tactical"
    world.state.scheduledToasts = world.state.scheduledToasts or {}
    world.state.scheduledIndex = world.state.scheduledIndex or {}

    -- Check for screenshot suite automation argument
    if arg then
        for _, a in ipairs(arg) do
            if a == "--screenshot-suite" then
                world.state.screenshotSuite = {frame = 0}
            end
        end
    end
end

function love.update(dt)
    dt = dt * (world.state.timeScale or 1)
    states.update(dt)

    -- Screenshot suite automation
    if world.state.screenshotSuite then
        local ss = world.state.screenshotSuite
        ss.frame = ss.frame + 1
        if ss.frame == 10 then
            world.state.introTimer = 4.5
        elseif ss.frame == 15 then
            love.graphics.captureScreenshot(function(imgData)
                imgData:encode("png", "screenshot_menu.png")
            end)
        elseif ss.frame == 20 then
            settingsMod.open()
        elseif ss.frame == 30 then
            love.graphics.captureScreenshot(function(imgData)
                imgData:encode("png", "screenshot_settings.png")
            end)
        elseif ss.frame == 35 then
            settingsMod.close()
            gameflow.iniciarSala(false)
            world.state.gameState = constants.GAME_STATE_PLAYING
        elseif ss.frame == 50 then
            love.graphics.captureScreenshot(function(imgData)
                imgData:encode("png", "screenshot_gameplay.png")
            end)
        elseif ss.frame >= 60 then
            love.event.quit()
        end
    end
end

function love.draw()
    renderMain.drawScene(love.timer.getDelta())
    if settingsMod and settingsMod.visible then
        settingsMod.draw()
    end
end

function love.resize(w, h)
    recalcularGrilla()
    if shadersMod.recreateCanvases then
        shadersMod.recreateCanvases()
    end
end

function love.mousepressed(x, y, button)
    -- Si el modal de muerte está abierto, capturar clicks
    if world.state.deathModalOpen then
        local action = uiMod.deathMousePressed(x, y)
        if action == "revive" then
            gameflow.revivePlayer()
            return
        elseif action == "accept" then
            world.state.survivalStreak = 1.0
            triggerDeathAnimation()
            return
        end
        return
    end

    -- Update menu button pressed state for visuals
    if world.state.gameState == constants.GAME_STATE_MENU then
        local hit = uiMod.menuMousePressed(x,y)
        if hit then uiMod.setMenuPressed(hit) end
    end

    -- Tools de debug primero
    if debugTools.mousepressed(x, y, button) then
        return
    end

    -- If profiles menu is open, route clicks there first
    if profilesMod and profilesMod.visible then
        if profilesMod.mousepressed then profilesMod.mousepressed(x,y,button) end
        return
    end

    -- If config menu is open, route clicks there first
    if settingsMod and settingsMod.visible then
        if settingsMod.mousepressed then settingsMod.mousepressed(x,y,button) end
        return
    end

    -- Menu main buttons
    if button == 1 and world.state.gameState == constants.GAME_STATE_MENU then
        local hit = uiMod.menuMousePressed(x, y)
        if hit then
            sound.play("buttonClick")
            if hit == 'play' then
                worldMod.init()
                world.state.mundoCompletado = false
                iniciarSala(false)
                world.state.fadeAlpha = 0
                world.state.fadeDir = 0
                world.state.gameState = constants.GAME_STATE_PLAYING
                return
            elseif hit == 'profiles' or hit == 'card_profile' then
                profilesMod.open()
                return
            elseif hit == 'settings' then
                settingsMod.open()
                return
            elseif hit == 'exit' then
                love.event.quit()
                return
            end
        end
    end

    if button == 1 and world.state.gameState == constants.GAME_STATE_SHOP then
        local resultado = shop.mousepressed(x, y, world.state.monedas)
        if resultado == "exit" then
            persistenceMod.syncActiveProfile()
            shop.reset()
            world.state.fadeDir = -1
            world.state.gameState = constants.GAME_STATE_MENU
            world.state.introTimer = 0
            world.state.pendingAchievements = {}
        elseif resultado == "continue" then
            persistenceMod.syncActiveProfile()
            world.state.fadeAlpha = 1
            world.state.fadeDir = -1
            local monedasGuardadas = world.state.monedas
            iniciarSala(true)
            world.state.monedas = monedasGuardadas
            persistenceMod.syncActiveProfile()
            world.state.bossHealthDisplay = nil
            world.state.gameState = constants.GAME_STATE_PLAYING
            world.state.pendingAchievements = {}
        elseif resultado then
            world.state.monedas = world.state.monedas - resultado.costo
            -- Save unlock to profile if passive item
            if resultado.item and itemsMod.registry[resultado.item] then
                local def = itemsMod.registry[resultado.item]
                if def.itemType == "passive" then
                    local profile = persistenceMod.getActiveProfile()
                    if profile then
                        profile.unlocks = profile.unlocks or {}
                        profile.unlocks[resultado.item] = true
                        persistenceMod.syncUnlocks(profile.unlocks)
                    end
                end
            end
            persistenceMod.syncActiveProfile()
            sound.play("buy")
            shop.abrir(world.state.monedas)
        end
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    touch.touchpressed(id, x, y)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    touch.touchmoved(id, x, y)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    touch.touchreleased(id, x, y)
end

function love.mousereleased(x,y,button)
    if world.state and world.state.gameState == constants.GAME_STATE_MENU and uiMod and uiMod.clearMenuPressed then
        uiMod.clearMenuPressed()
    end
    if debugTools.mousereleased and debugTools.mousereleased(x,y,button) then
        return
    end
    if settingsMod and settingsMod.mousereleased and settingsMod.visible then
        settingsMod.mousereleased(x,y,button)
    end
end

function love.mousemoved(x,y,dx,dy)
    if debugTools.mousemoved and debugTools.mousemoved(x,y,dx,dy) then
        return
    end
    if settingsMod and settingsMod.mousemoved and settingsMod.visible then
        settingsMod.mousemoved(x,y,dx,dy)
    end
    if world.state.gameState == constants.GAME_STATE_MENU then uiMod.updateMenuHover(x,y) end
end

function love.wheelmoved(dx, dy)
    if settingsMod and settingsMod.visible and settingsMod.wheelmoved then
        if settingsMod.wheelmoved(dx, dy) then return end
    end
    if profilesMod and profilesMod.visible and profilesMod.wheelmoved then
        profilesMod.wheelmoved(dx, dy)
    end
end

function love.quit()
    if persistenceMod then
        persistenceMod.syncActiveProfile()
    end
    if sound and sound.stop then
        sound:stop()
    end
    if shadersMod and shadersMod.releaseCanvases then
        shadersMod.releaseCanvases()
    end
    if particles and particles.release then
        particles.release()
    end
end

function love.textinput(text)
    if profilesMod and profilesMod.visible and profilesMod.textinput then
        profilesMod.textinput(text)
    end
end

function love.keypressed(tecla)
    if tecla == "f12" then
        love.graphics.captureScreenshot(function(imgData)
            local filename = "screenshot_" .. os.date("%Y%m%d_%H%M%S") .. ".png"
            imgData:encode("png", filename)
            uiMod.showToast({title = "Captura Guardada", subtitle = filename})
        end)
        return
    end

    if debugTools.keypressed and debugTools.keypressed(tecla) then
        return
    end

    -- Si el modal de muerte está abierto, capturar teclas
    if world.state.deathModalOpen then
        if tecla == "1" or tecla == "return" or tecla == "kpenter" then
            if gameflow.revivePlayer() then
                return
            end
        elseif tecla == "2" or tecla == "escape" then
            world.state.survivalStreak = 1.0
            triggerDeathAnimation()
            return
        end
        return
    end

    -- Route to settings manager first
    if settingsMod and settingsMod.visible then
        if settingsMod.keypressed and settingsMod.keypressed(tecla) then return end
    end

    -- Route to profiles manager first
    if profilesMod and profilesMod.visible then
        if profilesMod.keypressed then profilesMod.keypressed(tecla) end
        return
    end

    if world.state.gameState == constants.GAME_STATE_MENU then
        if world.state.introTimer < 4.5 then return end
        if tecla == "return" or tecla == "kpenter" then
            world.state.fadeAlpha = 1
            world.state.fadeDir = -1
            worldMod.init()
            world.state.mundoCompletado = false
            iniciarSala(false)
            world.state.gameState = constants.GAME_STATE_PLAYING
        end

    elseif world.state.gameState == constants.GAME_STATE_PLAYING then
        if tecla == "space" or tecla == "escape" then
            world.state.gameState = constants.GAME_STATE_PAUSED
            return
        end

        if tecla == "q" then
            local ok, pos = snakeMod.triggerAutotomy(world.state.player)
            if ok then
                local tam = constants.TAMANIO_BLOQUE
                table.insert(world.state.activePS, {
                    ps = particles.autotomyDecoy(pos.x * tam + tam / 2, pos.y * tam + tam / 2)
                })
                sound.play("buy")
                uiMod.addPopup("AUTOTOMÍA", pos.x, pos.y)
            end
            return
        end

        if tecla == "r" then
            local ok, pos = snakeMod.triggerReverseSlither(world.state.player)
            if ok then
                local tam = constants.TAMANIO_BLOQUE
                table.insert(world.state.activePS, {
                    ps = particles.tailSnapShockwave(pos.x * tam + tam / 2, pos.y * tam + tam / 2)
                })
                sound.play("buy")
                uiMod.addPopup("INVERSIÓN!", pos.x, pos.y)
            end
            return
        end

        local num = tonumber(tecla)
        if num and num >= 1 and num <= 3 then
            local itemId = shop.slotActivate(num)
            if itemId then
                playerMod.aplicarItem(itemId)
                local r, g, b = playerMod.itemColor(itemId)
                local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
                table.insert(world.state.activePS, {
                    ps = particles.activacion(cx, cy, r, g, b)
                })
                sound.play("buy")
            end
            return
        end

        if tecla == "l" then
            world.state.monedas = world.state.monedas + 10
            return
        end

        if tecla == "k" and not world.state.transitionTarget then
            if worldMod.esJefe() then
                world.state.transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
            else
                world.state.transitionTarget = "siguienteSala"
            end
            world.state.transitionPhase = 1
            world.state.fadeDir = 1
            world.state.gameState = constants.GAME_STATE_TRANSITION
            sound:playSegment("intro")
            return
        end

        snakeMod.cambiarDireccion(world.state.player, tecla)

        if tecla == "+" then
            world.state.baseSpeed = math.max(constants.MIN_BASE_SPEED, world.state.baseSpeed - constants.SPEED_ADJUST_INCREMENT)
            world.state.velocidadActual = playerMod.calculateCurrentSpeed(world.state.baseSpeed, world.state.frutasContador)
        elseif tecla == "-" then
            world.state.baseSpeed = math.min(constants.MAX_BASE_SPEED, world.state.baseSpeed + constants.SPEED_ADJUST_INCREMENT)
            world.state.velocidadActual = playerMod.calculateCurrentSpeed(world.state.baseSpeed, world.state.frutasContador)
        end

    elseif world.state.gameState == constants.GAME_STATE_PAUSED then
        if tecla == "space" or tecla == "escape" then
            world.state.gameState = constants.GAME_STATE_PLAYING
        end

    elseif world.state.gameState == constants.GAME_STATE_SHOP then
        local resultado = shop.keypressed(tecla, world.state.monedas)
        if resultado == "exit" then
            persistenceMod.syncActiveProfile()
            shop.reset()
            world.state.fadeDir = -1
            world.state.gameState = constants.GAME_STATE_MENU
            world.state.introTimer = 0
            world.state.pendingAchievements = {}
        elseif resultado == "continue" then
            persistenceMod.syncActiveProfile()
            world.state.fadeAlpha = 1
            world.state.fadeDir = -1
            local monedasGuardadas = world.state.monedas
            iniciarSala(true)
            world.state.monedas = monedasGuardadas
            persistenceMod.syncActiveProfile()
            world.state.bossHealthDisplay = nil
            world.state.gameState = constants.GAME_STATE_PLAYING
            world.state.pendingAchievements = {}
        elseif resultado then
            world.state.monedas = world.state.monedas - resultado.costo
            -- Save unlock to profile if passive item
            if resultado.item and itemsMod.registry[resultado.item] then
                local def = itemsMod.registry[resultado.item]
                if def.itemType == "passive" then
                    local profile = persistenceMod.getActiveProfile()
                    if profile then
                        profile.unlocks = profile.unlocks or {}
                        profile.unlocks[resultado.item] = true
                        persistenceMod.syncUnlocks(profile.unlocks)
                    end
                end
            end
            persistenceMod.syncActiveProfile()
            sound.play("buy")
            shop.abrir(world.state.monedas)
        end
    end
end

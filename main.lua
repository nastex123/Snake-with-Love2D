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
local shrineUI = require('systems.shrineUI')
local gameflow = require('systems.gameflow')
local playerMod = require('systems.player')
local states = require('systems.gamestates')
local debugTools = require('systems.debugTools')
local renderMain = require('render.renderMain')
local touch = require('core.touch')
local achievementsMod = require('systems.achievements')
local mutatorsMod = require('systems.roomMutators')
local livecoding = require('core.livecoding')
local playModalUI = require('ui.playModalUI')
local dailyResultUI = require('ui.dailyResultUI')

local FIXED_DT = 1 / 60
local accumulator = 0
local MAX_ACCUMULATOR = 0.25

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
    gameflow.triggerDeathAnimation()
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
    persistenceMod.applySettings(persistenceMod.settings, {heavy = true})
    recalcularGrilla()
    livecoding.init()

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
    world.state.introPlayed = false
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
    world.state.controlMode = "classic"
    world.state.scheduledToasts = world.state.scheduledToasts or {}
    world.state.scheduledIndex = world.state.scheduledIndex or {}

    if world.DEBUG then
        local ok, err = pcall(function() world.validate() end)
        if not ok and world.DEBUG then
            local hasLogger, Log = pcall(require, "core.logger")
            if hasLogger and Log and Log.error then Log.error("World.validate failed:", tostring(err)) end
        end
    end

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
    livecoding.update(dt)
    if shrineUI and shrineUI.update then shrineUI.update(dt) end
    if playModalUI and playModalUI.update then playModalUI.update(dt) end
    local scaled = dt * (world.state.timeScale or 1)
    accumulator = accumulator + scaled
    if accumulator > MAX_ACCUMULATOR then accumulator = MAX_ACCUMULATOR end
    while accumulator >= FIXED_DT do
        states.update(FIXED_DT)
        accumulator = accumulator - FIXED_DT
    end

    -- Screenshot suite automation
    if world.state.screenshotSuite then
        local ss = world.state.screenshotSuite
        ss.frame = ss.frame + 1
        if ss.frame == 10 then
            world.state.introTimer = 4.5
            if profilesMod then profilesMod.close() end
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
    if shrineUI and shrineUI.visible then
        shrineUI.draw()
    end
    if playModalUI and playModalUI.visible then
        playModalUI.draw(uiMod)
    end
    if world.state and world.state.dailyModalOpen then
        dailyResultUI.openResult(world.state.lastDailyResult)
        world.state.dailyModalOpen = false
    end
    if dailyResultUI and dailyResultUI.visible then
        dailyResultUI.draw(uiMod)
    end
    livecoding.draw()
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
            gameflow.acceptDeath()
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

    -- If shrine is open, route clicks there first
    if shrineUI and shrineUI.visible then
        if shrineUI.mousepressed then shrineUI.mousepressed(x,y,button) end
        return
    end

    -- If play modal selector is open, route clicks there first
    if playModalUI and playModalUI.visible then
        if playModalUI.mousepressed then playModalUI.mousepressed(x,y,button) end
        return
    end

    -- If daily result / history is open, route clicks there first
    if dailyResultUI and dailyResultUI.visible then
        if dailyResultUI.mousepressed then dailyResultUI.mousepressed(x,y,button) end
        return
    end

    -- Menu main buttons
    if button == 1 and world.state.gameState == constants.GAME_STATE_MENU then
        local hit = uiMod.menuMousePressed(x, y)
        if hit then
            sound.play("buttonClick")
            if hit == 'play' then
                playModalUI.open()
                return
            elseif hit == 'profiles' or hit == 'card_profile' then
                profilesMod.open()
                return
            elseif hit == 'settings' then
                settingsMod.open()
                return
            elseif hit == 'shrine' then
                shrineUI.open()
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
            world.state.introTimer = world.state.introPlayed and (constants.INTRO_READY or 4.5) or 0
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
    if playModalUI and playModalUI.visible and playModalUI.mousemoved then
        playModalUI.mousemoved(x, y)
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

-- Dispatcher de teclado en main_keypressed.lua (TD-5.2 split)
local keyHandlerOk, keyHandlers = pcall(require, "main_keypressed")
if keyHandlerOk and keyHandlers then
    love.keypressed = keyHandlers.attach({
        livecoding = livecoding,
        debugTools = debugTools,
        world = world,
        constants = constants,
        gameflow = gameflow,
        settingsMod = settingsMod,
        profilesMod = profilesMod,
        shrineUI = shrineUI,
        snakeMod = snakeMod,
        particles = particles,
        sound = sound,
        uiMod = uiMod,
        shop = shop,
        playerMod = playerMod,
        worldMod = worldMod,
        itemsMod = itemsMod,
        persistenceMod = persistenceMod,
        mutatorsMod = mutatorsMod,
        iniciarSala = iniciarSala,
    })
end

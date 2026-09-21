local Handlers = {}
function Handlers.attach(env)
    local livecoding = env.livecoding
    local debugTools = env.debugTools
    local world = env.world
    local constants = env.constants
    local gameflow = env.gameflow
    local settingsMod = env.settingsMod
    local profilesMod = env.profilesMod
    local shrineUI = env.shrineUI
    local snakeMod = env.snakeMod
    local particles = env.particles
    local sound = env.sound
    local uiMod = env.uiMod
    local shop = env.shop
    local playerMod = env.playerMod
    local worldMod = env.worldMod
    local itemsMod = env.itemsMod
    local persistenceMod = env.persistenceMod
    local mutatorsMod = env.mutatorsMod
    local iniciarSala = env.iniciarSala
    local function onKeypressed(tecla)
        if tecla == "f5" then
            livecoding.reloadAll()
            return
        end
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
        if world.state.deathModalOpen then
            if tecla == "1" or tecla == "return" or tecla == "kpenter" then
                if gameflow.revivePlayer() then
                    return
                end
            elseif tecla == "2" or tecla == "escape" then
                gameflow.acceptDeath()
                return
            end
            return
        end
        if settingsMod and settingsMod.visible then
            if settingsMod.keypressed and settingsMod.keypressed(tecla) then return end
        end
        if profilesMod and profilesMod.visible then
            if profilesMod.keypressed then profilesMod.keypressed(tecla) end
            return
        end
        if shrineUI and shrineUI.visible then
            if shrineUI.keypressed and shrineUI.keypressed(tecla) then return end
            return
        end
        if world.state.gameState == constants.GAME_STATE_MENU then
            if world.state.introTimer < 4.5 then return end
            if tecla == "return" or tecla == "kpenter" then
                gameflow.startRun()
                world.state.fadeAlpha = 1
                world.state.fadeDir = -1
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
                if world.state.gameState == constants.GAME_STATE_PLAYING and mutatorsMod.itemsSealed() then
                    local head = world.state.player and world.state.player.body and world.state.player.body[1]
                    if head then uiMod.addPopup("SELLADO", head.x, head.y) end
                    return
                end
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
    return onKeypressed
end
return Handlers

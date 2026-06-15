local constants = require("constants")
local snakeMod  = require("snake")
local foodMod   = require("food")
local uiMod     = require("ui")
local persistenceMod = require("persistence")
local shop      = require("shop")
local obstaclesMod = require("obstacles")
local particles = require("particles")
local sound = require("sound")
local shadersMod = require("shaders")
local itemsMod = require("items")
local enemiesMod = require("enemies")
local worldMod = require("world")
local settingsMod = require('settings')

local function calculateCurrentSpeed(base, fruits)
    local speedReduction = math.floor(fruits / 5) * constants.SPEED_ADJUST_INCREMENT
    return math.max(constants.VELOCIDAD_MINIMA, base - speedReduction)
end

local function itemColor(itemId)
    local colors = {
        shield = {0, 0.85, 1}, armor = {0.3, 0.7, 1}, ghost = {0.6, 0.4, 1},
        magnet = {0, 0.85, 1}, bomb = {1, 0.4, 0.2}, hunger = {1, 0.6, 0.2},
        speedReducer = {0.2, 0.9, 0.3}, turbo = {0, 1, 0.5}, slow = {0.5, 0.5, 1},
        doubler = {1, 0.84, 0}, extraCoin = {1, 0.84, 0}, star = {1, 0.84, 0}
    }
    local c = colors[itemId]
    return c and c[1] or 1, c and c[2] or 1, c and c[3] or 1
end

local function aplicarItem(itemId)
    if itemId == "shield" then
        shop.shieldActive = true
    elseif itemId == "armor" then
        player.armor = 2
    elseif itemId == "ghost" then
        player.ghost = true
        table.insert(activeTimers, {
            id = "ghost", remaining = constants.GHOST_DURATION,
            onEnd = function() player.ghost = false end
        })
    elseif itemId == "magnet" then
        shop.magnetTimer = constants.MAGNET_DURATION
        magnetRange = constants.MAGNET_RANGE
        table.insert(activeTimers, {
            id = "magnet", remaining = constants.MAGNET_DURATION,
            onEnd = function() shop.magnetTimer = 0; magnetRange = 0 end
        })
    elseif itemId == "bomb" then
        local hx, hy = player.body[1].x, player.body[1].y
        local r = constants.BOMB_RADIUS
        for i = #obstaclesMod.pos, 1, -1 do
            local obs = obstaclesMod.pos[i]
            if math.abs(obs.x - hx) <= r and math.abs(obs.y - hy) <= r then
                table.remove(obstaclesMod.pos, i)
            end
        end
        for i = #enemiesMod.list, 1, -1 do
            local e = enemiesMod.list[i]
            if e.alive and math.abs(e.x - hx) <= r and math.abs(e.y - hy) <= r then
                local result = enemiesMod.killEnemy(i)
                if result then
                    monedas = monedas + result.coins
                    uiMod.addPopup("+" .. result.coins .. "$", result.gx, result.gy)
                    local cols = {
                        chaser = constants.COLOR_ENEMY_CHASER,
                        patroller = constants.COLOR_ENEMY_PATROLLER,
                        spawner = constants.COLOR_ENEMY_SPAWNER
                    }
                    local c = cols[result.type]
                    if c then
                        table.insert(activePS, {
                            ps = particles.enemyKill(result.px, result.py, c[1], c[2], c[3])
                        })
                    end
                end
            end
        end
        sound.play("enemyKill")
    elseif itemId == "hunger" then
        foodMod.generar(player.body, anchoGrilla, altoGrilla, obstaclesMod.pos)
        foodMod.generar(player.body, anchoGrilla, altoGrilla, obstaclesMod.pos)
    elseif itemId == "speedReducer" then
        velocidadActual = math.max(constants.VELOCIDAD_MINIMA, velocidadActual - constants.SPEED_REDUCER_AMOUNT)
    elseif itemId == "turbo" then
        local savedSpeed = velocidadActual
        velocidadActual = math.max(constants.VELOCIDAD_MINIMA, velocidadActual * constants.TURBO_MULTIPLIER)
        table.insert(activeTimers, {
            id = "turbo", remaining = constants.TURBO_DURATION,
            onEnd = function()
                velocidadActual = calculateCurrentSpeed(baseSpeed, frutasContador)
            end
        })
    elseif itemId == "slow" then
        timeScale = constants.SLOW_TIMESCALE
        table.insert(activeTimers, {
            id = "slow", remaining = constants.SLOW_DURATION,
            onEnd = function() timeScale = 1 end
        })
    elseif itemId == "doubler" then
        for i = #activeTimers, 1, -1 do
            if activeTimers[i].id == "star" or activeTimers[i].id == "doubler" then
                if activeTimers[i].onEnd then activeTimers[i].onEnd() end
                table.remove(activeTimers, i)
            end
        end
        scoreMultiplier = 2
        coinBonus = 0
        table.insert(activeTimers, {
            id = "doubler", remaining = constants.DOUBLER_DURATION,
            onEnd = function() scoreMultiplier = 1 end
        })
    elseif itemId == "extraCoin" then
        coinBonus = 1
        table.insert(activeTimers, {
            id = "extraCoin", remaining = constants.EXTRA_COIN_DURATION,
            onEnd = function() coinBonus = 0 end
        })
    elseif itemId == "star" then
        for i = #activeTimers, 1, -1 do
            if activeTimers[i].id == "star" or activeTimers[i].id == "doubler" then
                if activeTimers[i].onEnd then activeTimers[i].onEnd() end
                table.remove(activeTimers, i)
            end
        end
        scoreMultiplier = 3
        coinBonus = 0
        table.insert(activeTimers, {
            id = "star", remaining = constants.STAR_DURATION,
            onEnd = function() scoreMultiplier = 1 end
        })
    end
end

local function resetGame(keepShopInventory)
    player = snakeMod.reset()
    cronometro = 0
    baseSpeed = constants.VELOCIDAD_INICIAL
    velocidadActual = calculateCurrentSpeed(baseSpeed, 0)
    puntuacion = 0
    frutasContador = 0
    if not keepShopInventory then
        monedas = 0
    end
    deathAnimTimer = 0
    lastObstacleScore = 0
    magnetRange = 0
    activeTimers = {}
    scoreMultiplier = 1
    coinBonus = 0
    timeScale = 1
    activePS = {}
    obstaclesMod.init()
    enemiesMod.init()
    uiMod.popups = {}
    shockwaves = {}
    comboFlashTimer = 0
    comboCount = 0
    comboDisplay = 0
    comboIntensity = 0
    lastEatTime = 0
    if keepShopInventory then
        for id, owned in pairs(shop.inventory) do
            if owned then
                if id == "speedReducer" then
                    velocidadActual = math.max(constants.VELOCIDAD_MINIMA, velocidadActual - constants.SPEED_REDUCER_AMOUNT)
                elseif id == "extraCoin" then
                    coinBonus = 1
                end
            end
        end
    else
        shop.reset()
    end
end

local function iniciarSala(keepInventory)
    resetGame(keepInventory)
    worldMod.puntajeSala = 0
    puntuacion = 0
    local mod = worldMod.getModifier()
    local etapa = worldMod.etapa
    foodMod.generar(player.body, anchoGrilla, altoGrilla, obstaclesMod.pos)
    enemiesMod.generar(player.body, foodMod.pos, obstaclesMod.pos, anchoGrilla, altoGrilla, mod)
    if worldMod.esJefe() then
        enemiesMod.spawnBoss(etapa, anchoGrilla, altoGrilla, mod.bossVida, 5 + etapa * 2)
    end
end

function love.load()
    anchoGrilla = love.graphics.getWidth() / constants.TAMANIO_BLOQUE
    altoGrilla  = math.floor((love.graphics.getHeight() - constants.GRID_OFFSET_Y) / constants.TAMANIO_BLOQUE)
    gridOffsetY = constants.GRID_OFFSET_Y

    persistenceMod.init()
    highScore = persistenceMod.cargar()

    uiMod.load()
    particles.load()
    shop.loadFonts()
    sound.load()
    shadersMod.load()

    -- Cargar y aplicar configuración DESPUÉS de inicializar subsistemas (sound/shaders/ui)
    persistenceMod.loadSettings()
    persistenceMod.applySettings(persistenceMod.settings)

    menuPS = particles.menuFondo()

    activePS = {}
    activeTimers = {}
    scoreMultiplier = 1
    coinBonus = 0
    timeScale = 1
    shockwaves = {}
    comboFlashTimer = 0
    gameState = constants.GAME_STATE_MENU
    time = 0
    introTimer = 0
    celebrationTimer = 0
    comboDisplay = 0
    comboIntensity = 0
    nuevoHighScore = false
    shakeTimer = 0
    fadeAlpha = 0
    fadeDir = 0
    transitionTarget = nil
    transitionPhase = nil
    transitionHoldTimer = 0
    bossHealthDisplay = nil
    mundoCompletado = false
    debugMenuOpen = false
    debugImmune = false
end

function love.update(dt)
    dt = dt * timeScale
    time = time + dt

    -- Guardar estado previo de racha para detectar su finalización
    local wasCombo = (comboCount and comboCount > 0)

    -- -----------------------------------------------------------------
    --  Música ambiental: actualizar bucle y cambiar segmento según estado
    -- -----------------------------------------------------------------
    sound:update(dt)
    if gameState == constants.GAME_STATE_MENU then
        if sound:getCurrentSegment() ~= "intro" then
            sound:playSegment("intro")
        end
    elseif gameState == constants.GAME_STATE_PLAYING then
        if enemiesMod.boss and enemiesMod.boss.alive then
            sound:playSegment("boss")
        elseif comboCount and comboCount > 0 then
            if not wasCombo then
                sound:crossfadeTo("comboEnter")
            else
                sound:playSegment("comboLoop")
            end
        else
            if sound:getCurrentSegment() ~= "intro" then
                sound:playSegment("intro")
            end
        end
    else
        -- Durante Transición, HighScore, Shop, etc. mantenemos la música en su estado actual
    end

    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
    end

    if fadeDir ~= 0 then
        fadeAlpha = math.max(0, math.min(1, fadeAlpha + fadeDir * constants.FADE_SPEED * dt))
        if fadeAlpha <= 0 or fadeAlpha >= 1 then
            fadeDir = 0
        end
    end

    -- Menu subsystem update (UI toasts, etc.)
    if settingsMod and settingsMod.update then settingsMod.update(dt) end

    for i = #activePS, 1, -1 do
        local entry = activePS[i]
        entry.ps:update(dt)
        if entry.ps:getCount() == 0 then
            table.remove(activePS, i)
        end
    end

    obstaclesMod.update(dt)
    menuPS:update(dt)

    for i = #shockwaves, 1, -1 do
        local sw = shockwaves[i]
        sw.radio = sw.radio + 120 * dt
        sw.timer = sw.timer + dt
        sw.alpha = 1 - sw.timer / 0.4
        if sw.alpha <= 0 then
            table.remove(shockwaves, i)
        end
    end

    for i = #activeTimers, 1, -1 do
        local t = activeTimers[i]
        t.remaining = t.remaining - dt
        if t.remaining <= 0 then
            if t.onEnd then
                t.onEnd()
            end
            table.remove(activeTimers, i)
        end
    end

    shop.update(dt)

    if gameState == constants.GAME_STATE_MENU then
        introTimer = introTimer + dt

    elseif gameState == constants.GAME_STATE_PLAYING then
        enemiesMod.update(dt, player.body, anchoGrilla, altoGrilla, obstaclesMod)
        if player.flashTimer > 0 then
            player.flashTimer = player.flashTimer - dt
        end

        if shop.magnetTimer > 0 then
            shop.magnetTimer = shop.magnetTimer - dt
            if shop.magnetTimer <= 0 then
                magnetRange = 0
            else
                magnetRange = constants.MAGNET_RANGE
            end
        end

        cronometro = cronometro + dt

        if cronometro >= velocidadActual then
            cronometro = 0
            local shieldBefore = shop.shieldActive
            local vivo, comio, enemyKilled, bossResult = snakeMod.mover(player, foodMod.pos, anchoGrilla, altoGrilla, obstaclesMod.pos, magnetRange)

            if enemyKilled then
                monedas = monedas + enemyKilled.coins
                uiMod.addPopup("+" .. enemyKilled.coins .. "$", enemyKilled.gx, enemyKilled.gy)
                local cols = {
                    chaser = constants.COLOR_ENEMY_CHASER,
                    patroller = constants.COLOR_ENEMY_PATROLLER,
                    spawner = constants.COLOR_ENEMY_SPAWNER
                }
                local c = cols[enemyKilled.type]
                if c then
                    table.insert(activePS, {
                        ps = particles.enemyKill(enemyKilled.px, enemyKilled.py, c[1], c[2], c[3])
                    })
                end
                sound.play("enemyKill")
            end

            if bossResult then
                if bossResult.hit then
                    bossHealthDisplay = bossResult
                    sound.play("enemyKill")
                elseif bossResult.type == "boss" then
                    monedas = monedas + bossResult.coins
                    uiMod.addPopup("+" .. bossResult.coins .. "$", bossResult.gx, bossResult.gy)
                    table.insert(activePS, {
                        ps = particles.enemyKill(bossResult.px, bossResult.py, 1, 0.4, 0.6)
                    })
                    sound.play("enemyKill")
                    bossHealthDisplay = nil
                    if worldMod.sala == 5 then
                        transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                        transitionPhase = 1
                        fadeDir = 1
                        gameState = constants.GAME_STATE_TRANSITION
                        return
                    end
                end
            end

            if not vivo then
                love.timer.sleep(0.08)
                shakeTimer = constants.SHAKE_DURATION
                fadeDir = 1
                gameState = constants.GAME_STATE_DEATH_ANIMATION
                local oldHighScore = highScore
                highScore = persistenceMod.guardar(puntuacion, highScore)
                nuevoHighScore = highScore > oldHighScore
                if nuevoHighScore then
                    local cx = love.graphics.getWidth() / 2
                    local cy = love.graphics.getHeight() / 2
                    table.insert(activePS, {
                        ps = particles.highScore(cx, cy)
                    })
                    sound.play("highScore")
                end
                deathAnimTimer = 0
                local tam = constants.TAMANIO_BLOQUE
                for _, seg in ipairs(player.body) do
                    table.insert(activePS, {
                        ps = particles.muerte(seg.x * tam + tam / 2, seg.y * tam + tam / 2)
                    })
                end
                sound.play("death")
                return
            end

            if shieldBefore and not shop.shieldActive then
                sound.play("shieldBreak")
            end

            if comio then
                sound.play("eat")
                local tipo = foodMod.tipo
                local puntosBase, monedasExtra, textPopup
                if tipo == constants.FOOD_GOLD then
                    puntosBase = 25
                    monedasExtra = 2
                    textPopup = "+25"
                elseif tipo == constants.FOOD_COIN then
                    puntosBase = 5
                    monedasExtra = 3
                    textPopup = "+5$"
                else
                    puntosBase = 10
                    monedasExtra = constants.COINS_PER_FRUIT
                    textPopup = "+10"
                end

                if time - lastEatTime <= constants.COMBO_WINDOW then
                    comboCount = comboCount + 1
                    comboFlashTimer = 0.3
                else
                    comboCount = 0
                end
                lastEatTime = time
                local comboMult = 1 + comboCount * constants.COMBO_MULTIPLIER
                local puntosFinal = math.floor(puntosBase * comboMult * scoreMultiplier)

                puntuacion = puntuacion + puntosFinal
                frutasContador = frutasContador + 1
                monedas = monedas + monedasExtra + coinBonus
                velocidadActual = calculateCurrentSpeed(baseSpeed, frutasContador)
                player.flashTimer = constants.DURACION_FLASH_COMER

                local tam = constants.TAMANIO_BLOQUE
                local fx = foodMod.pos.x * tam + tam / 2
                local fy = foodMod.pos.y * tam + tam / 2
                table.insert(activePS, {
                    ps = particles.comer(fx, fy)
                })

                table.insert(shockwaves, {x = fx, y = fy, radio = 0, alpha = 1, timer = 0})

                if comboCount > 0 then
                    uiMod.addPopup(textPopup .. " x" .. (comboCount + 1), foodMod.pos.x, foodMod.pos.y)
                else
                    uiMod.addPopup(textPopup, foodMod.pos.x, foodMod.pos.y)
                end

                foodMod.generar(player.body, anchoGrilla, altoGrilla, obstaclesMod.pos)

                if puntuacion >= lastObstacleScore + constants.OBSTACLE_SPAWN_INTERVAL then
                    lastObstacleScore = math.floor(puntuacion / constants.OBSTACLE_SPAWN_INTERVAL) * constants.OBSTACLE_SPAWN_INTERVAL
                    local mod = worldMod.getModifier()
                    obstaclesMod.generar(player.body, foodMod.pos, anchoGrilla, altoGrilla)
                    enemiesMod.generar(player.body, foodMod.pos, obstaclesMod.pos, anchoGrilla, altoGrilla, mod)
                end

                if puntuacion >= worldMod.objetivoSala and not worldMod.esJefe() and not transitionTarget then
                    transitionTarget = "siguienteSala"
                    transitionPhase = 1
                    fadeDir = 1
                    gameState = constants.GAME_STATE_TRANSITION
-- Al iniciar la transición volver a la música de intro (1‑9)
                    sound:playSegment("intro")
                    return
                end
            end
        end

        uiMod.updatePopups(dt)

        if comboFlashTimer > 0 then
            comboFlashTimer = comboFlashTimer - dt
        end

        local target = comboCount
        comboDisplay = comboDisplay + (target - comboDisplay) * math.min(1, dt * 4)
        comboIntensity = math.min(1, comboDisplay / 5)

    elseif gameState == constants.GAME_STATE_DEATH_ANIMATION then
        deathAnimTimer = deathAnimTimer + dt
        if deathAnimTimer >= constants.DEATH_ANIMATION_SEGMENT_DELAY then
            deathAnimTimer = 0
            if #player.body > 0 then
                local seg = player.body[#player.body]
                local tam = constants.TAMANIO_BLOQUE
                table.insert(activePS, {
                    ps = particles.muerte(seg.x * tam + tam / 2, seg.y * tam + tam / 2)
                })
                table.remove(player.body, #player.body)
            else
                fadeDir = -1
                worldMod.init()
                if nuevoHighScore then
                    celebrationTimer = constants.HIGH_SCORE_CELEBRATION_DURATION
                    gameState = constants.GAME_STATE_HIGH_SCORE
                else
                    gameState = constants.GAME_STATE_SHOP
                    sound:playSegment("intro")
                    shop.abrir(monedas)
                end
            end
        end

    elseif gameState == constants.GAME_STATE_HIGH_SCORE then
        celebrationTimer = celebrationTimer - dt
        if celebrationTimer <= 0 then
            fadeDir = -1
            gameState = constants.GAME_STATE_SHOP
            sound:playSegment("intro")
            shop.abrir(monedas)
        end

    elseif gameState == constants.GAME_STATE_TRANSITION then
        if transitionPhase == 1 and fadeAlpha >= 1 then
            -- phase 1 done: cambiar sala, empezar hold
            if transitionTarget == "siguienteSala" then
                worldMod.avanzarSala()
            elseif transitionTarget == "siguienteEtapa" then
                worldMod.avanzarEtapa()
            elseif transitionTarget == "completado" then
                mundoCompletado = true
            end
            transitionPhase = "hold"
            transitionHoldTimer = 0
        elseif transitionPhase == "hold" then
            transitionHoldTimer = transitionHoldTimer + dt
            if transitionHoldTimer >= 2.0 then
transitionPhase = 2
                    fadeDir = -1
                end
                elseif transitionPhase == 2 and fadeAlpha <= 0 then
                    transitionTarget = nil
                    transitionPhase = nil
                    gameState = constants.GAME_STATE_SHOP
                    -- Al entrar a la tienda volver a la musica de intro (1-9)
                    sound:playSegment("intro")
                    shop.abrir(monedas)
        end
    elseif gameState == constants.GAME_STATE_SHOP then
    end
end

function love.draw()
    love.graphics.setBackgroundColor(constants.COLOR_BG[1], constants.COLOR_BG[2], constants.COLOR_BG[3])

    if gameState == constants.GAME_STATE_MENU then
        -- Menu: capturar en canvasScene, aplicar heat distortion + CRT
        shadersMod.beginScene()
        local s = 0.8
        if introTimer > 1.5 and introTimer < 3.0 then
            s = 0.8 + 0.2 * math.min(1, (introTimer - 1.5) / 0.5)
        elseif introTimer >= 3.0 and introTimer < 4.5 then
            s = 0.8 + 0.2 * math.max(0, 1 - (introTimer - 3.0) / 1.5)
        end
        shadersMod.drawBalatroBG(time, s)
        uiMod.drawBalatroIntro(introTimer, time, false)
        love.graphics.draw(menuPS, 0, 0)
        if introTimer >= 3.0 then
            uiMod.drawMenu(introTimer, time, highScore)
        end
        if settingsMod and settingsMod.draw then settingsMod.draw() end
        love.graphics.setCanvas()

        -- glow: solo elementos luminosos de la intro
        shadersMod.beginGlow()
        uiMod.drawBalatroIntro(introTimer, time, true)
        love.graphics.setCanvas()

        shadersMod.beginShadow()
        love.graphics.setCanvas()

        shadersMod.composite(time, 0.85, introTimer >= 3.0)

    elseif gameState == constants.GAME_STATE_PLAYING or
           gameState == constants.GAME_STATE_PAUSED or
           gameState == constants.GAME_STATE_DEATH_ANIMATION or
           gameState == constants.GAME_STATE_HIGH_SCORE or
           gameState == constants.GAME_STATE_SHOP or
           gameState == constants.GAME_STATE_TRANSITION then

        -- CRT más suave cuando hay shake (muerte)
        local crtIntensity = shakeTimer > 0
            and (0.6 + 0.4 * (shakeTimer / constants.SHAKE_DURATION))
            or 0.75

        -- ---- CANVAS SCENE: todo el juego ----
        shadersMod.beginScene()

        if shakeTimer > 0 then
            local intensidad = constants.SHAKE_INTENSITY * (shakeTimer / constants.SHAKE_DURATION)
            local t = constants.SHAKE_DURATION - shakeTimer
            local sx = math.sin(t * 55) * intensidad
            local sy = math.cos(t * 47) * intensidad
            love.graphics.push()
            love.graphics.translate(sx, sy)
        end

        -- separador visual HUD / gameplay
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.25)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, constants.GRID_OFFSET_Y - 1, love.graphics.getWidth(), constants.GRID_OFFSET_Y - 1)

        -- fondo fluido Balatro procedural (antes del grid)
        shadersMod.drawBalatroBG(time, 0.8 + comboIntensity * 0.2)

        -- offset de grilla para que no quede bajo el HUD
        love.graphics.push()
        love.graphics.translate(0, constants.GRID_OFFSET_Y)

        uiMod.drawGrid(anchoGrilla, altoGrilla, time, comboIntensity)

        if gameState ~= constants.GAME_STATE_SHOP then
            obstaclesMod.draw()
            enemiesMod.draw()
            foodMod.draw(time, dt)
            local alpha = (gameState == constants.GAME_STATE_PLAYING or gameState == constants.GAME_STATE_DEATH_ANIMATION)
                and (cronometro / velocidadActual) or 1
            snakeMod.draw(player, alpha)

            if magnetRange > 0 and (gameState == constants.GAME_STATE_PLAYING or gameState == constants.GAME_STATE_PAUSED) then
                local tam = constants.TAMANIO_BLOQUE
                local hx = player.body[1].x * tam + tam / 2
                local hy = player.body[1].y * tam + tam / 2
                local mr = magnetRange * tam
                love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.1)
                love.graphics.circle("fill", hx, hy, mr)
                love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.25)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", hx, hy, mr)
            end
        end

        for _, entry in ipairs(activePS) do
            love.graphics.draw(entry.ps, 0, 0)
        end

        for _, sw in ipairs(shockwaves) do
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], sw.alpha * 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", sw.x, sw.y, sw.radio)
            love.graphics.setLineWidth(1)
        end

        if gameState ~= constants.GAME_STATE_SHOP then
            uiMod.drawPopups()
        end

        love.graphics.pop()  -- fin offset grilla

        if shakeTimer > 0 then
            love.graphics.pop()
        end

        uiMod.drawHUD(puntuacion, highScore, monedas, shop.shieldActive, shop.magnetTimer, constants.MAGNET_DURATION, baseSpeed, nil, comboCount, activeTimers, worldMod.etapa, worldMod.sala, worldMod.objetivoSala)
        if gameState == constants.GAME_STATE_PLAYING or gameState == constants.GAME_STATE_PAUSED then
            local slotDisplay = {}
            for i = 1, 3 do
                local id = shop.slots[i]
                slotDisplay[i] = id and {name = itemsMod.registry[id].name} or nil
            end
            uiMod.drawSlots(slotDisplay)
        end

        -- Boss health bar
        if bossHealthDisplay and gameState == constants.GAME_STATE_PLAYING then
            local w = love.graphics.getWidth()
            local barW = 160
            local barH = 8
            local bx = (w - barW) / 2
            local by = 32
            local frac = bossHealthDisplay.vida / bossHealthDisplay.vidaMax
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", bx, by, barW, barH, 4, 4)
            love.graphics.setColor(1, 0.2 * frac + 0.6, 0.2 * frac + 0.2, 0.9)
            love.graphics.rectangle("fill", bx, by, barW * frac, barH, 4, 4)
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", bx, by, barW, barH, 4, 4)
        end

        uiMod.drawComboFlash(time, comboCount, comboFlashTimer)

        if gameState == constants.GAME_STATE_HIGH_SCORE then
            uiMod.drawHighScoreCelebration(puntuacion, highScore)
        elseif gameState == constants.GAME_STATE_SHOP then
            shop.draw(monedas, velocidadActual)
        elseif gameState == constants.GAME_STATE_PAUSED then
            uiMod.drawPauseOverlay()
        end

        if mundoCompletado then
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            love.graphics.setFont(uiMod.fontTitle)
            love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
            love.graphics.printf("VICTORIA", 0, h / 2 - 60, w, "center")
            love.graphics.setFont(uiMod.fontNormal)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("Has conquistado la mazmorra", 0, h / 2 - 20, w, "center")
        end

        if fadeAlpha > 0 then
            love.graphics.setColor(0, 0, 0, fadeAlpha)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        end

        -- Sala completada text (sobre el fade)
        if gameState == constants.GAME_STATE_TRANSITION and fadeAlpha > 0 then
            if transitionPhase == 1 or transitionPhase == "hold" then
                local w = love.graphics.getWidth()
                local h = love.graphics.getHeight()
                local label = transitionTarget == "siguienteSala" and "SALA COMPLETADA"
                    or transitionTarget == "siguienteEtapa" and "ETAPA COMPLETADA"
                    or transitionTarget == "completado" and "MAZMORRA SUPERADA"
                    or ""
                if label ~= "" then
                    local textAlpha = transitionPhase == "hold" and 1 or math.min(1, fadeAlpha * 2)
                    love.graphics.setFont(uiMod.fontLarge)
                    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], textAlpha)
                    love.graphics.printf(label, 0, h / 2 - 20, w, "center")
                end
            end
        end

        love.graphics.setCanvas()  -- fin canvasScene

        -- ---- CANVAS GLOW: serpiente + comida + particulas ----
        shadersMod.beginGlow()
        if gameState ~= constants.GAME_STATE_SHOP then
            local alpha = (gameState == constants.GAME_STATE_PLAYING or gameState == constants.GAME_STATE_DEATH_ANIMATION)
                and (cronometro / velocidadActual) or 1
            love.graphics.push()
            love.graphics.translate(0, constants.GRID_OFFSET_Y)
            snakeMod.draw(player, alpha)
            foodMod.draw(time, dt)
            for _, entry in ipairs(activePS) do
                love.graphics.draw(entry.ps, 0, 0)
            end
            love.graphics.pop()
        end
        love.graphics.setCanvas()

        -- ---- CANVAS SHADOW: silueta de la serpiente ----
        shadersMod.beginShadow()
        if gameState ~= constants.GAME_STATE_SHOP then
            local alpha = (gameState == constants.GAME_STATE_PLAYING or gameState == constants.GAME_STATE_DEATH_ANIMATION)
                and (cronometro / velocidadActual) or 1
            love.graphics.push()
            love.graphics.translate(0, constants.GRID_OFFSET_Y)
            love.graphics.setColor(1, 1, 1, 1)
            snakeMod.draw(player, alpha)
            love.graphics.pop()
        end
        love.graphics.setCanvas()

        -- ---- COMPOSITE final ----
        shadersMod.composite(time, crtIntensity, false)
        if debugMenuOpen and (gameState == constants.GAME_STATE_PLAYING or gameState == constants.GAME_STATE_PAUSED) then
            dibujarDebugMenu()
        end
    end
end

function love.mousepressed(x, y, button)
    -- Update menu button pressed state for visuals
    if gameState == constants.GAME_STATE_MENU then
        local hit = uiMod.menuMousePressed(x,y)
        if hit then uiMod.setMenuPressed(hit) end
    end
    if debugMenuOpen and button == 1 then
        for _, btn in ipairs(debugButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == "skip" then
                    if not transitionTarget then
                        if worldMod.esJefe() then
                            transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                        else
                            transitionTarget = "siguienteSala"
                        end
                        transitionPhase = 1
                        fadeDir = 1
                        gameState = constants.GAME_STATE_TRANSITION
                        sound:playSegment("intro")
                    end
                elseif btn.action == "skipStage" then
                    if not transitionTarget then
                        transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                        transitionPhase = 1
                        fadeDir = 1
                        gameState = constants.GAME_STATE_TRANSITION
                        sound:playSegment("intro")
                    end
                elseif btn.action == "coins" then
                    monedas = monedas + 10
                elseif btn.action == "immune" then
                    debugImmune = not debugImmune
                elseif btn.action == "speedUp" then
                    baseSpeed = math.max(constants.MIN_BASE_SPEED, baseSpeed - constants.SPEED_ADJUST_INCREMENT)
                    velocidadActual = calculateCurrentSpeed(baseSpeed, frutasContador)
                elseif btn.action == "speedDown" then
                    baseSpeed = math.min(constants.MAX_BASE_SPEED, baseSpeed + constants.SPEED_ADJUST_INCREMENT)
                    velocidadActual = calculateCurrentSpeed(baseSpeed, frutasContador)
                elseif btn.action == "comboUp" then
                    comboCount = (comboCount or 0) + 1
                elseif btn.action == "comboDown" then
                    comboCount = math.max(0, (comboCount or 0) - 1)
                end
                return
            end
        end
    end

    -- If config menu is open, route clicks there first
    if settingsMod and settingsMod.visible then
        if settingsMod.mousepressed then settingsMod.mousepressed(x,y,button) end
        return
    end

    -- Menu main buttons
    if button == 1 and gameState == constants.GAME_STATE_MENU then
        local hit = uiMod.menuMousePressed(x, y)
        if hit == 'play' then
            fadeAlpha = 1
            fadeDir = -1
            worldMod.init()
            mundoCompletado = false
            iniciarSala(false)
            gameState = constants.GAME_STATE_PLAYING
            return
        elseif hit == 'settings' then
            settingsMod.open()
            return
        elseif hit == 'exit' then
            love.event.quit()
            return
        end
    end

    if button == 1 and gameState == constants.GAME_STATE_SHOP then
        local resultado = shop.mousepressed(x, y, monedas)
        if resultado == "exit" then
            shop.reset()
            fadeDir = -1
            gameState = constants.GAME_STATE_MENU
            introTimer = 0
        elseif resultado == "continue" then
            fadeAlpha = 1
            fadeDir = -1
            local monedasGuardadas = monedas
            iniciarSala(true)
            monedas = monedasGuardadas
            bossHealthDisplay = nil
            gameState = constants.GAME_STATE_PLAYING
        elseif resultado then
            monedas = monedas - resultado.costo
            sound.play("buy")
            shop.abrir(monedas)
        end
    end
end

function love.mousereleased(x,y,button)
    if settingsMod and settingsMod.mousereleased and settingsMod.visible then
        settingsMod.mousereleased(x,y,button)
    end
end

function love.mousemoved(x,y,dx,dy)
    if settingsMod and settingsMod.mousemoved and settingsMod.visible then
        settingsMod.mousemoved(x,y,dx,dy)
    end
    if gameState == constants.GAME_STATE_MENU then uiMod.updateMenuHover(x,y) end
end

debugButtons = {}

function dibujarDebugMenu()
    local px, py = 10, 50
    local pw = 210
    local bh = 26
    local gap = 4
    local pad = 8
    local bw = pw - pad * 2
    local halfW = (bw - gap) / 2

    -- Background panel
    love.graphics.setColor(0.08, 0.08, 0.15, 0.88)
    love.graphics.rectangle("fill", px, py, pw, 250, 6)

    -- Title
    love.graphics.setColor(0, 0.85, 1, 1)
    love.graphics.setFont(uiMod.fontSmall)
    love.graphics.print("DEBUG", px + pad, py + 6)

    local y = py + 26
    debugButtons = {}

    local function addBtn(label, action, x, w, color)
        color = color or {0.2, 0.2, 0.35, 1}
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", x, y, w, bh, 4)
        table.insert(debugButtons, {x = x, y = y, w = w, h = bh, action = action})
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

    local immuneColor = debugImmune and {0.5, 0.1, 0.1, 1} or {0.2, 0.2, 0.35, 1}
    addBtn("Inmune: " .. (debugImmune and "ON" or "OFF"), "immune", px + pad, bw, immuneColor)
    y = y + bh + gap

    addBtn("Speed +", "speedUp", px + pad, halfW)
    addBtn("Speed -", "speedDown", px + pad + halfW + gap, halfW)
    y = y + bh + gap

    addBtn("Racha +", "comboUp", px + pad, halfW)
    addBtn("Racha -", "comboDown", px + pad + halfW + gap, halfW)
    y = y + bh + gap

    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.setFont(uiMod.fontSmall)
    love.graphics.print("Vel: " .. string.format("%.3f", baseSpeed), px + pad, y + 4)
    love.graphics.print("Racha: " .. (comboCount or 0), px + pad + 100, y + 4)
end

function love.keypressed(tecla)
    if tecla == "tab" then
        debugMenuOpen = not debugMenuOpen
        return
    end

    if gameState == constants.GAME_STATE_MENU then
        if introTimer < 4.5 then return end
        if tecla == "return" or tecla == "kpenter" then
            fadeAlpha = 1
            fadeDir = -1
            worldMod.init()
            mundoCompletado = false
            iniciarSala(false)
            gameState = constants.GAME_STATE_PLAYING
        end

    elseif gameState == constants.GAME_STATE_PLAYING then
        if tecla == "space" or tecla == "escape" then
            gameState = constants.GAME_STATE_PAUSED
            return
        end

        local num = tonumber(tecla)
        if num and num >= 1 and num <= 3 then
            local itemId = shop.slotActivate(num)
            if itemId then
                aplicarItem(itemId)
                local r, g, b = itemColor(itemId)
                local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
                table.insert(activePS, {
                    ps = particles.activacion(cx, cy, r, g, b)
                })
                sound.play("buy")
            end
            return
        end

        if tecla == "l" then
            monedas = monedas + 10
            return
        end

        if tecla == "k" and not transitionTarget then
            if worldMod.esJefe() then
                transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
            else
                transitionTarget = "siguienteSala"
            end
            transitionPhase = 1
            fadeDir = 1
            gameState = constants.GAME_STATE_TRANSITION
            -- Al saltar la ronda manualmente, volver a la musica de intro (1-9)
            sound:playSegment("intro")
            return
        end

        snakeMod.cambiarDireccion(player, tecla)

        if tecla == "+" then
            baseSpeed = math.max(constants.MIN_BASE_SPEED, baseSpeed - constants.SPEED_ADJUST_INCREMENT)
            velocidadActual = calculateCurrentSpeed(baseSpeed, frutasContador)
        elseif tecla == "-" then
            baseSpeed = math.min(constants.MAX_BASE_SPEED, baseSpeed + constants.SPEED_ADJUST_INCREMENT)
            velocidadActual = calculateCurrentSpeed(baseSpeed, frutasContador)
        end

    elseif gameState == constants.GAME_STATE_PAUSED then
        if tecla == "space" or tecla == "escape" then
            gameState = constants.GAME_STATE_PLAYING
        end

    elseif gameState == constants.GAME_STATE_SHOP then
        local resultado = shop.keypressed(tecla, monedas)
        if resultado == "exit" then
            shop.reset()
            fadeDir = -1
            gameState = constants.GAME_STATE_MENU
            introTimer = 0
        elseif resultado == "continue" then
            fadeAlpha = 1
            fadeDir = -1
            local monedasGuardadas = monedas
            iniciarSala(true)
            monedas = monedasGuardadas
            bossHealthDisplay = nil
            gameState = constants.GAME_STATE_PLAYING
        elseif resultado then
            monedas = monedas - resultado.costo
            sound.play("buy")
            shop.abrir(monedas)
        end
    end
end

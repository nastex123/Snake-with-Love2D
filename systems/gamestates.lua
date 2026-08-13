-- systems/gamestates.lua — Update por estado (MENU/PLAYING/DEATH/HIGH_SCORE/TRANSITION)
local states = {}
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
local sound = require("audio.sound")
local shop = require("systems.shop")
local uiMod = require("ui.ui")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local particles = require("render.particles")
local shadersMod = require("render.shaders")
local achievementsMod = require("systems.achievements")
local persistence = require("systems.persistence")
local gameflow = require("systems.gameflow")
local playerMod = require("systems.player")

-- colores de popup según tipo
local ENEMY_COLORS = {
    chaser = "chaser", patroller = "patroller", spawner = "spawner"
}

function states.overlaysOpen()
    local profilesMod = require("systems.profiles")
    local settingsMod = require("systems.settings")
    return (profilesMod and profilesMod.visible)
        or (settingsMod and settingsMod.visible)
        or world.state.debugAchievementsOpen
end

function states.flushPendingAchievements()
    if not world.state.pendingAchievements or #world.state.pendingAchievements == 0 then return end
    for _, aid in ipairs(world.state.pendingAchievements) do
        local reg = achievementsMod and achievementsMod.registry and achievementsMod.registry[aid]
        if reg then
            uiMod.showToast({id=aid, title=reg.title, subtitle=reg.desc, reward=reg.reward})
        end
    end
    world.state.pendingAchievements = {}
end

local function processToasts()
    local st = world.state
    if st.scheduledToasts and #st.scheduledToasts > 0 then
        local i = 1
        while i <= #st.scheduledToasts do
            local toast = st.scheduledToasts[i]
            if st.time >= toast.showAt then
                if states.overlaysOpen() then
                    i = i + 1  -- defer
                else
                    uiMod.showToast(toast.payload)
                    if st.scheduledIndex then st.scheduledIndex[toast.id] = nil end
                    if st.pendingAchievements then
                        for j = #st.pendingAchievements, 1, -1 do
                            if st.pendingAchievements[j] == toast.id then
                                table.remove(st.pendingAchievements, j)
                            end
                        end
                    end
                    table.remove(st.scheduledToasts, i)
                end
            else
                i = i + 1
            end
        end
    end
end

local function processToasts()
    local st = world.state
    if st.scheduledToasts and #st.scheduledToasts > 0 then
        local i = 1
        while i <= #st.scheduledToasts do
            local toast = st.scheduledToasts[i]
            if st.time >= toast.showAt then
                if states.overlaysOpen() then
                    i = i + 1  -- defer
                else
                    uiMod.showToast(toast.payload)
                    if st.scheduledIndex then st.scheduledIndex[toast.id] = nil end
                    if st.pendingAchievements then
                        for j = #st.pendingAchievements, 1, -1 do
                            if st.pendingAchievements[j] == toast.id then
                                table.remove(st.pendingAchievements, j)
                            end
                        end
                    end
                    table.remove(st.scheduledToasts, i)
                end
            else
                i = i + 1
            end
        end
    end
end

function states.updateCommon(dt)
    local st = world.state
    st.time = st.time + dt

    timers.update(dt)
    shadersMod.update(dt)
    processToasts()

    -- Guardar estado previo de racha para detectar su finalización
    local wasCombo = (st.comboCount and st.comboCount > 0)

    -- Música ambiental
    sound:update(dt)
    if st.gameState == constants.GAME_STATE_MENU then
        if sound:getCurrentSegment() ~= "intro" then
            sound:playSegment("intro")
        end
    elseif st.gameState == constants.GAME_STATE_PLAYING then
        if enemiesMod.boss and enemiesMod.boss.alive then
            sound:playSegment("boss")
        elseif st.comboCount and st.comboCount > 0 then
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
    end

    if st.shakeTimer > 0 then
        st.shakeTimer = st.shakeTimer - dt
    end

    if st.fadeDir ~= 0 then
        st.fadeAlpha = math.max(0, math.min(1, st.fadeAlpha + st.fadeDir * constants.FADE_SPEED * dt))
        if st.fadeAlpha <= 0 or st.fadeAlpha >= 1 then
            st.fadeDir = 0
        end
    end

    -- Menu subsystem update (UI toasts, etc.)
    local settingsMod = require("systems.settings")
    if settingsMod and settingsMod.update then settingsMod.update(dt) end

    for i = #st.activePS, 1, -1 do
        local entry = st.activePS[i]
        entry.ps:update(dt)
        if entry.ps:getCount() == 0 then
            table.remove(st.activePS, i)
        end
    end

    obstaclesMod.update(dt)
    st.menuPS:update(dt)

    for i = #st.shockwaves, 1, -1 do
        local sw = st.shockwaves[i]
        sw.radio = sw.radio + 120 * dt
        sw.timer = sw.timer + dt
        sw.alpha = 1 - sw.timer / 0.4
        if sw.alpha <= 0 then
            table.remove(st.shockwaves, i)
        end
    end

    for i = #st.activeTimers, 1, -1 do
        local t = st.activeTimers[i]
        t.remaining = t.remaining - dt
        if t.remaining <= 0 then
            if t.onEnd then
                t.onEnd()
            end
            table.remove(st.activeTimers, i)
        end
    end

    shop.update(dt)
end

function states.updateMenu(dt)
    world.state.introTimer = world.state.introTimer + dt
end

-- Retorna true si cambió state a muerte
function states.updatePlaying(dt)
    local st = world.state
    enemiesMod.update(dt, st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod)
    if st.player.flashTimer > 0 then
        st.player.flashTimer = st.player.flashTimer - dt
    end

    if shop.magnetTimer > 0 then
        shop.magnetTimer = shop.magnetTimer - dt
        if shop.magnetTimer <= 0 then
            st.magnetRange = 0
        else
            st.magnetRange = constants.MAGNET_RANGE
        end
    end

    st.cronometro = st.cronometro + dt

    if st.cronometro >= st.velocidadActual then
        st.cronometro = 0
        local shieldBefore = shop.shieldActive
        local vivo, comio, enemyKilled, bossResult, attackHit = snakeMod.mover(st.player, foodMod.pos, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, st.magnetRange)

        if attackHit then
            st.shakeTimer = 0.15
            shadersMod.triggerDamage(0.7, 0.5)
        end

        if enemyKilled then
            st.monedas = st.monedas + enemyKilled.coins
            uiMod.addPopup("+" .. enemyKilled.coins .. "$", enemyKilled.gx, enemyKilled.gy)
            local cols = {
                chaser = constants.COLOR_ENEMY_CHASER,
                patroller = constants.COLOR_ENEMY_PATROLLER,
                spawner = constants.COLOR_ENEMY_SPAWNER
            }
            local c = cols[enemyKilled.type]
            if c then
                table.insert(st.activePS, {
                    ps = particles.enemyKill(enemyKilled.px, enemyKilled.py, c[1], c[2], c[3])
                })
            end
            sound.play("enemyKill")
            achievementsMod.check("enemyKilled")
            achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
        end

        if bossResult then
            if bossResult.hit then
                st.bossHealthDisplay = bossResult
                sound.play("enemyKill")
            elseif bossResult.type == "boss" then
                st.monedas = st.monedas + bossResult.coins
                uiMod.addPopup("+" .. bossResult.coins .. "$", bossResult.gx, bossResult.gy)
                table.insert(st.activePS, {
                    ps = particles.enemyKill(bossResult.px, bossResult.py, 1, 0.4, 0.6)
                })
                sound.play("enemyKill")
                achievementsMod.check("bossDefeated")
                achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                st.bossHealthDisplay = nil
                if worldMod.isLastRoom() then
                    st.transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                    st.transitionPhase = 1
                    st.fadeDir = 1
                    st.gameState = constants.GAME_STATE_TRANSITION
                    return true
                end
            end
        end

        if not vivo then
            love.timer.sleep(0.08)
            st.shakeTimer = constants.SHAKE_DURATION
            shadersMod.triggerDamage(1.0, 0.9)
            st.fadeDir = 1
            st.gameState = constants.GAME_STATE_DEATH_ANIMATION
            local oldHighScore = st.highScore
            st.highScore = persistence.guardar(st.puntuacion, st.highScore)
            persistence.syncActiveProfile()
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
            return true
        end

        if shieldBefore and not shop.shieldActive then
            sound.play("shieldBreak")
            shadersMod.triggerDamage(0.5, 0.5)
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

            if st.time - st.lastEatTime <= constants.COMBO_WINDOW then
                st.comboCount = st.comboCount + 1
                st.comboFlashTimer = 0.3
                if st.comboCount >= 4 then
                    achievementsMod.check("comboAchieved", {count = st.comboCount + 1})
                end
            else
                st.comboCount = 0
            end
            st.lastEatTime = st.time
            local comboMult = 1 + st.comboCount * constants.COMBO_MULTIPLIER
            local total = math.floor(puntosBase * comboMult * st.scoreMultiplier)

            st.puntuacion = st.puntuacion + total
            st.frutasContador = st.frutasContador + 1
            st.monedas = st.monedas + monedasExtra + st.coinBonus
            st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
            st.player.flashTimer = constants.DURACION_FLASH_COMER

            local tam = constants.TAMANIO_BLOQUE
            local fx = foodMod.pos.x * tam + tam / 2
            local fy = foodMod.pos.y * tam + tam / 2
            table.insert(st.activePS, {
                ps = particles.comer(fx, fy)
            })

            table.insert(st.shockwaves, {x = fx, y = fy, radio = 0, alpha = 1, timer = 0})

            if st.comboCount > 0 then
                uiMod.addPopup(textPopup .. " x" .. (st.comboCount + 1), foodMod.pos.x, foodMod.pos.y)
            else
                uiMod.addPopup(textPopup, foodMod.pos.x, foodMod.pos.y)
            end

            -- Boss food counter
            if enemiesMod.boss and enemiesMod.boss.alive and foodMod.tipo ~= constants.FOOD_COIN then
                enemiesMod.boss.foodCollected = enemiesMod.boss.foodCollected + 1
                local ratio = enemiesMod.boss.foodCollected / enemiesMod.boss.foodTarget
                enemiesMod.boss._uiBarTarget = math.max(0, 1 - ratio)
                sound.play("boss_food_tick")
                local tam2 = constants.TAMANIO_BLOQUE
                table.insert(st.activePS, {
                    ps = particles.bossFoodTick(foodMod.pos.x * tam2 + tam2 / 2, foodMod.pos.y * tam2 + tam2 / 2)
                })
                if enemiesMod.boss.foodCollected >= enemiesMod.boss.foodTarget then
                    local bossResult = enemiesMod.onBossDefeatedByFood()
                    if bossResult then
                        st.monedas = st.monedas + bossResult.coins
                        uiMod.addPopup("+" .. bossResult.coins .. "$", bossResult.gx, bossResult.gy)
                        table.insert(st.activePS, {
                            ps = particles.bossDeath(bossResult.px, bossResult.py)
                        })
                        sound.play("boss_defeated")
                        sound.play("enemyKill")
                        achievementsMod.check("bossDefeated")
                        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                        if worldMod.isLastRoom() then
                            st.transitionTarget = worldMod.etapa >= 5 and "completado" or "siguienteEtapa"
                            st.transitionPhase = 1
                            st.fadeDir = 1
                            st.gameState = constants.GAME_STATE_TRANSITION
                            sound:playSegment("intro")
                            return true
                        end
                    end
                end
            end

            foodMod.generar(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos)

            if st.puntuacion >= st.lastObstacleScore + constants.OBSTACLE_SPAWN_INTERVAL then
                st.lastObstacleScore = math.floor(st.puntuacion / constants.OBSTACLE_SPAWN_INTERVAL) * constants.OBSTACLE_SPAWN_INTERVAL
                local mod = worldMod.getModifier()
                obstaclesMod.generar(st.player.body, foodMod.pos, st.anchoGrilla, st.altoGrilla)
                enemiesMod.generar(st.player.body, foodMod.pos, obstaclesMod.pos, st.anchoGrilla, st.altoGrilla, mod)
            end

            if st.puntuacion >= worldMod.objetivoSala and not worldMod.esJefe() and not st.transitionTarget then
                st.transitionTarget = "siguienteSala"
                st.transitionPhase = 1
                st.fadeDir = 1
                st.gameState = constants.GAME_STATE_TRANSITION
                sound:playSegment("intro")
                return true
            end
        end
    end

    uiMod.updatePopups(dt)
    if uiMod.updateToasts then uiMod.updateToasts(dt) end

    if st.comboFlashTimer > 0 then
        st.comboFlashTimer = st.comboFlashTimer - dt
    end

    local target = st.comboCount
    st.comboDisplay = st.comboDisplay + (target - st.comboDisplay) * math.min(1, dt * 4)
    st.comboIntensity = math.min(1, st.comboDisplay / 5)
    return false
end

function states.updateDeath(dt)
    local st = world.state
    st.deathAnimTimer = st.deathAnimTimer + dt
    if st.deathAnimTimer >= constants.DEATH_ANIMATION_SEGMENT_DELAY then
        st.deathAnimTimer = 0
        if #st.player.body > 0 then
            local seg = st.player.body[#st.player.body]
            local tam = constants.TAMANIO_BLOQUE
            table.insert(st.activePS, {
                ps = particles.muerte(seg.x * tam + tam / 2, seg.y * tam + tam / 2)
            })
            table.remove(st.player.body, #st.player.body)
        else
            st.fadeDir = -1
            worldMod.init()
            if st.nuevoHighScore then
                st.celebrationTimer = constants.HIGH_SCORE_CELEBRATION_DURATION
                st.gameState = constants.GAME_STATE_HIGH_SCORE
            else
                states.flushPendingAchievements()
                gameflow.applyActiveProfile()
                st.gameState = constants.GAME_STATE_SHOP
                sound:playSegment("intro")
                shop.abrir(st.monedas)
            end
        end
    end
end

function states.updateHighScore(dt)
    local st = world.state
    st.celebrationTimer = st.celebrationTimer - dt
    if st.celebrationTimer <= 0 then
        st.fadeDir = -1
        states.flushPendingAchievements()
        gameflow.applyActiveProfile()
        st.gameState = constants.GAME_STATE_SHOP
        sound:playSegment("intro")
        shop.abrir(st.monedas)
    end
end

function states.updateTransition(dt)
    local st = world.state
    if st.transitionPhase == 1 and st.fadeAlpha >= 1 then
        if st.transitionTarget == "siguienteSala" then
            worldMod.avanzarSala()
        elseif st.transitionTarget == "siguienteEtapa" then
            worldMod.avanzarEtapa()
            achievementsMod.check("stageChanged", {stage = worldMod.etapa})
        elseif st.transitionTarget == "completado" then
            st.mundoCompletado = true
        end
        st.transitionPhase = "hold"
        st.transitionHoldTimer = 0
        states.flushPendingAchievements()
    elseif st.transitionPhase == "hold" then
        st.transitionHoldTimer = st.transitionHoldTimer + dt
        if st.transitionHoldTimer >= 2.0 then
            st.transitionPhase = 2
            st.fadeDir = -1
        end
    elseif st.transitionPhase == 2 and st.fadeAlpha <= 0 then
        st.transitionTarget = nil
        st.transitionPhase = nil
        st.gameState = constants.GAME_STATE_SHOP
        sound:playSegment("intro")
        shop.abrir(st.monedas)
    end
end

return states
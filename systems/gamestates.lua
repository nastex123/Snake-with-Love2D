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

local prevComboActive = false

function states.updateCommon(dt)
    local st = world.state
    st.time = st.time + dt

    timers.update(dt)
    shadersMod.update(dt)
    processToasts()

    -- Música ambiental
    sound:update(dt)
    if st.gameState == constants.GAME_STATE_MENU then
        if sound:getCurrentSegment() ~= "intro" or not sound:isPlaying() then
            sound:playSegment("intro")
        end
        prevComboActive = false
    elseif st.gameState == constants.GAME_STATE_PLAYING then
        local comboActive = (st.comboCount and st.comboCount > 0)
        if enemiesMod.boss and enemiesMod.boss.alive then
            if sound:getCurrentSegment() ~= "boss" or not sound:isPlaying() then
                sound:playSegment("boss")
            end
            prevComboActive = false
        elseif comboActive then
            if not prevComboActive then
                sound:crossfadeTo("comboEnter")
            end
            prevComboActive = true
        else
            if sound:getCurrentSegment() ~= "intro" or not sound:isPlaying() then
                sound:playSegment("intro")
            end
            prevComboActive = false
        end
    else
        prevComboActive = false
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
    if st.menuPS and st.menuPS.update then st.menuPS:update(dt) end

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
        t.remaining = math.max(0, t.remaining - dt)
        if t.remaining <= 0 then
            if t.onEnd then
                t.onEnd()
            end
            table.remove(st.activeTimers, i)
        end
    end

    if world.state.gameState ~= constants.GAME_STATE_SHOP then
        shop.update(dt)
    end
end

function states.updateMenu(dt)
    world.state.introTimer = world.state.introTimer + dt
end

-- Retorna true si cambió state a muerte
function states.updatePlaying(dt)
    local st = world.state
    if st.deathModalOpen then return end

    if st.enemyFreezeTimer and st.enemyFreezeTimer > 0 then
        st.enemyFreezeTimer = math.max(0, st.enemyFreezeTimer - dt)
    end

    if snakeMod.update then snakeMod.update(st.player, dt) end

    foodMod.onBombExpired = function(bx, by)
        obstaclesMod.agregar(bx, by)
        local tam = constants.TAMANIO_BLOQUE
        table.insert(st.activePS, { ps = particles.bombExplosion(bx * tam + tam / 2, by * tam + tam / 2) })
        sound.play("enemyKill")
        uiMod.addPopup("BOMBA DETONADA!", bx, by)
        foodMod.generar(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos)
    end

    if foodMod.update then
        foodMod.update(dt, st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos)
    end

    enemiesMod.update(dt, st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod, worldMod.etapa, worldMod.getModifier(), st.player.decoys)
    if st.player.flashTimer > 0 then
        st.player.flashTimer = st.player.flashTimer - dt
    end

    -- Comprobacion de incineracion por rastro de fuego
    if st.player.fireTrail and #st.player.fireTrail > 0 then
        local fireKills = enemiesMod.checkFireTrail(st.player.fireTrail)
        if fireKills and #fireKills > 0 then
            local streak = st.survivalStreak or 1.0
            for _, fk in ipairs(fireKills) do
                local earnedCoins = math.floor((fk.coins or 1) * streak)
                st.monedas = st.monedas + earnedCoins
                uiMod.addPopup("FUEGO +" .. earnedCoins .. "$", fk.gx, fk.gy)
                table.insert(st.activePS, {
                    ps = particles.fireTrail(fk.px, fk.py)
                })
                sound.play("enemyKill")
                achievementsMod.check("enemyKilled")
                achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
            end
        end
    end

    -- Comprobacion de Tail Snap (Onda en giro en U)
    if snakeMod.checkTailSnap then
        local snap = snakeMod.checkTailSnap(st.player)
        if snap then
            local affected = enemiesMod.applyTailSnap(snap.gx, snap.gy, constants.TAIL_SNAP_PUSH_DIST, constants.TAIL_SNAP_STUN_DURATION, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos)
            table.insert(st.activePS, { ps = particles.tailSnapShockwave(snap.px, snap.py) })
            sound.play("shieldBreak")
            uiMod.addPopup("TAIL SNAP!", snap.gx, snap.gy)
        end
    end

    -- Comprobación del lazo constrictor
    if snakeMod.checkConstrictorLoop then
        local loopKills = snakeMod.checkConstrictorLoop(st.player, enemiesMod.list)
        if loopKills and #loopKills > 0 then
            sound.play("highScore")
            local streak = st.survivalStreak or 1.0
            for _, lk in ipairs(loopKills) do
                local res = enemiesMod.killEnemy(lk.index)
                if res then
                    local earnedCoins = math.floor((res.coins or 1) * 2 * streak)
                    st.monedas = st.monedas + earnedCoins
                    uiMod.addPopup("CONSTRICTOR +" .. earnedCoins .. "$", res.gx, res.gy)
                    table.insert(st.activePS, {
                        ps = particles.constrictorBurst(res.px, res.py)
                    })
                    achievementsMod.check("enemyKilled")
                    achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                end
            end
            st.comboCount = st.comboCount + 2
            st.comboFlashTimer = 0.3
        end
    end

    -- Comprobacion continua de colision de enemigos contra el cuerpo/cabeza (y seccionamiento de cola)
    if snakeMod.checkEnemyCollisions then
        local col = snakeMod.checkEnemyCollisions(st.player, enemiesMod.list)
        if col then
            if col.type == "death" then
                st.roomDamaged = true
                st.deathModalOpen = true
                return true
            elseif col.type == "shield_block" then
                st.roomDamaged = true
                sound.play("shieldBreak")
                shadersMod.triggerDamage(0.5, 0.5)
            elseif col.type == "armor_block" then
                st.roomDamaged = true
                sound.play("shieldBreak")
                shadersMod.triggerDamage(0.4, 0.4)
            elseif col.type == "slice" then
                local tam = constants.TAMANIO_BLOQUE or 20
                local px = col.gx * tam + tam / 2
                local py = col.gy * tam + tam / 2
                table.insert(st.activePS, { ps = particles.tailSnapShockwave(px, py) })
                sound.play("shieldBreak")
                uiMod.addPopup("COLA CORTADA! -" .. col.removedCount, col.gx, col.gy)
                st.comboCount = 0
                st.shakeTimer = 0.2
                shadersMod.triggerDamage(0.5, 0.3)
            end
        end
    end

    if shop.magnetTimer > 0 then
        shop.magnetTimer = shop.magnetTimer - dt
        if shop.magnetTimer <= 0 then
            st.magnetRange = 0
        else
            st.magnetRange = constants.MAGNET_RANGE
        end
    end

    -- Respuesta reactiva inmediata y buffer de esquina (Corner Buffering)
    local controlMode = world.get("controlMode") or "tactical"
    local isInputActive = (#st.player.inputQueue > 0)
    if not isInputActive and love.keyboard and love.keyboard.isDown then
        isInputActive = love.keyboard.isDown("up", "w", "down", "s", "left", "a", "right", "d")
    end
    local touchMod = package.loaded["core.touch"]
    if not isInputActive and touchMod and touchMod.hasActiveTouch and touchMod.hasActiveTouch() then
        isInputActive = true
    end

    if controlMode == "tactical" and st.player.standstill then
        if isInputActive then
            st.cronometro = st.velocidadActual
        end
    elseif isInputActive and st.player.hasNewInput then
        st.player.hasNewInput = false
        local bufferRatio = constants.CORNER_BUFFER_RATIO or 0.75
        if st.cronometro >= st.velocidadActual * bufferRatio then
            st.cronometro = st.velocidadActual
        end
    end

    st.cronometro = st.cronometro + dt

    if st.cronometro >= st.velocidadActual then
        st.cronometro = 0
        local shieldBefore = shop.shieldActive
        local vivo, comio, enemyKilled, bossResult, attackHit, comioTwin = snakeMod.mover(st.player, foodMod.pos, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, st.magnetRange, foodMod.twinPos)

        if attackHit then
            st.roomDamaged = true
            st.shakeTimer = 0.15
            shadersMod.triggerDamage(0.7, 0.5)
        end

        if enemyKilled then
            local earnedCoins = math.floor((enemyKilled.coins or 1) * (st.survivalStreak or 1.0))
            st.monedas = st.monedas + earnedCoins
            uiMod.addPopup("+" .. earnedCoins .. "$", enemyKilled.gx, enemyKilled.gy)
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
                local earnedCoins = math.floor((bossResult.coins or 5) * (st.survivalStreak or 1.0))
                st.monedas = st.monedas + earnedCoins
                uiMod.addPopup("+" .. earnedCoins .. "$", bossResult.gx, bossResult.gy)
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
            st.roomDamaged = true
            st.deathModalOpen = true
            return true
        end

        if shieldBefore and not shop.shieldActive then
            st.roomDamaged = true
            sound.play("shieldBreak")
            shadersMod.triggerDamage(0.5, 0.5)
        end

        if comio then
            sound.play("eat")
            local tipo = foodMod.tipo
            local streak = st.survivalStreak or 1.0

            local isSpecial = (tipo == "fire_pepper" or tipo == "frost_berry" or tipo == "constrictor_berry" or
                               tipo == "slimming_berry" or tipo == "repelling_orbit" or tipo == "bomb" or
                               tipo == "prismatic" or tipo == "streak_diamond" or tipo == "twin")

            if isSpecial then
                playerMod.aplicarComida(tipo)
                if tipo == "twin" then
                    if comioTwin then
                        foodMod.twinPos = nil
                    else
                        if foodMod.twinPos then
                            foodMod.pos.x = foodMod.twinPos.x
                            foodMod.pos.y = foodMod.twinPos.y
                            foodMod.twinPos = nil
                        end
                    end
                end
            else
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
                local total = math.floor(puntosBase * comboMult * (st.scoreMultiplier or 1) * streak)

                st.puntuacion = st.puntuacion + total
                st.frutasContador = st.frutasContador + 1
                st.monedas = st.monedas + math.floor((monedasExtra + st.coinBonus) * streak)
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
                        st.monedas = st.monedas + math.floor(bossResult.coins * (st.survivalStreak or 1.0))
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

            -- Spawn siguiente comida (si no quedan gemelas pendientes) - evita boss y enemigos
            if tipo ~= "twin" or not foodMod.twinPos then
                local avoid = {}
                if enemiesMod.boss and enemiesMod.boss.alive then avoid[#avoid+1]=enemiesMod.boss end
                for _,e in ipairs(enemiesMod.list) do if e.alive then avoid[#avoid+1]=e end end
                local extra = (#avoid>0) and avoid or nil
                -- usar find via generar con extraAvoid: pasar avoid como 6to param si generar soporta extraAvoid
                local ok = foodMod.generar(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, nil, nil, nil)
                -- si comida cayó sobre boss/enemigo, reintentar con avoid
                if ok and extra then
                    local blocked=false
                    for _,a in ipairs(extra) do if foodMod.pos.x==a.x and foodMod.pos.y==a.y then blocked=true; break end end
                    if blocked then
                        for attempt=1,20 do
                            local nx, ny = require("entities.enemyHelpers").sampleFreeTile(st.anchoGrilla, st.altoGrilla, st.player.body, obstaclesMod, enemiesMod.list, 2, 30)
                            if nx and ny then foodMod.pos.x=nx; foodMod.pos.y=ny; break end
                        end
                    end
                end
            end

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
        if not st.roomDamaged then
            st.survivalStreak = (st.survivalStreak or 1.0) + (constants.SURVIVAL_STREAK_INCREMENT or 0.1)
            st.highestStreak = math.max(st.highestStreak or 1.0, st.survivalStreak)
            persistence.syncActiveProfile()
        end
        st.roomDamaged = false

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

function states.updateShop(dt)
    shop.update(dt)
end

function states.updatePaused(dt)
    -- Paused state (no gameplay progression)
end

function states.update(dt)
    states.updateCommon(dt)
    local g = world.state.gameState
    if g == constants.GAME_STATE_MENU then
        return states.updateMenu(dt)
    elseif g == constants.GAME_STATE_PLAYING then
        return states.updatePlaying(dt)
    elseif g == constants.GAME_STATE_DEATH_ANIMATION then
        return states.updateDeath(dt)
    elseif g == constants.GAME_STATE_HIGH_SCORE then
        return states.updateHighScore(dt)
    elseif g == constants.GAME_STATE_SHOP then
        return states.updateShop(dt)
    elseif g == constants.GAME_STATE_PAUSED then
        return states.updatePaused(dt)
    elseif g == constants.GAME_STATE_TRANSITION then
        return states.updateTransition(dt)
    end
end

return states
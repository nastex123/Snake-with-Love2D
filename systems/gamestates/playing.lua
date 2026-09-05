-- =============================================================================
-- MÓDULO: systems/gamestates/playing.lua
-- Parte de P03 — Split de systems/gamestates.lua (643 → 4 módulos)
-- Contiene updatePlaying (372L) — orquesta movimiento, colisiones, economía, boss.
-- Extraído de systems/gamestates.lua sin cambios de semántica.
-- =============================================================================
local playing = {}
local constants = require("constants")
local world = require("core.world")
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
local timers = require("core.timers")
local hasEvents, Events = pcall(require, "core.events")
if not hasEvents or type(Events) ~= "table" then Events = nil end
local Input = require("core.input")

-- Batería de Emergencia (GDD item 57): bullet-time 0.1x con dt escalado
-- (pendingDeathTimer en tiempo escalado ≈ 1.5s reales); retorna true si se activó
local function triggerBattery(st)
    if shop.inventory and shop.inventory.emergencyBattery and not st.batteryUsed then
        st.batteryUsed = true
        st.timeScale = constants.EMERGENCY_BULLET_TIME or 0.1
        st.pendingDeathTimer = (constants.EMERGENCY_DURATION or 1.5) * (constants.EMERGENCY_BULLET_TIME or 0.1)
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("BATERIA! TIEMPO LENTO", head.x, head.y) end
        sound.play("shieldBreak")
        return true
    end
    return false
end

-- Recompensa kills de Púa de Cola y Rayo Orbital (igual que enemyKilled normal)
local function awardItemKill(st, res)
    local streak = st.survivalStreak or 1.0
    local earnedCoins = math.floor((res.coins or 1) * streak)
    st.monedas = st.monedas + earnedCoins
    uiMod.addPopup("+" .. earnedCoins .. "$", res.gx, res.gy)
    local cols = {
        chaser = constants.COLOR_ENEMY_CHASER,
        patroller = constants.COLOR_ENEMY_PATROLLER,
        spawner = constants.COLOR_ENEMY_SPAWNER
    }
    local c = cols[res.type]
    if c then
        table.insert(st.activePS, {
            ps = particles.enemyKill(res.px, res.py, c[1], c[2], c[3])
        })
    end
    sound.play("enemyKill")
    if Events then
        Events.emit("enemyKilled")
        Events.emit("coinsChanged", {totalCoins = st.monedas})
    else
        achievementsMod.check("enemyKilled")
        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
    end
end

function playing.update(dt)
    local st = world.state
    if st.deathModalOpen then return end

    -- Batería de Emergencia (GDD item 57): cuenta atrás del bullet-time con dt escalado
    -- (0.15 escalado ≈ 1.5s reales a timeScale 0.1); el mundo gatea en cámara lenta
    if st.pendingDeathTimer and st.pendingDeathTimer > 0 then
        st.pendingDeathTimer = st.pendingDeathTimer - dt
        if st.pendingDeathTimer <= 0 then
            st.pendingDeathTimer = nil
            st.timeScale = 1
            st.roomDamaged = true
            st.deathModalOpen = true
            return true
        end
        return
    end

    if st.enemyFreezeTimer and st.enemyFreezeTimer > 0 then
        st.enemyFreezeTimer = math.max(0, st.enemyFreezeTimer - dt)
    end

    -- Reloj de Arena (GDD item 52): anillo de 120 estados (2.0s a 60Hz)
    if st.player and st.player.body then
        st.historyBuffer = st.historyBuffer or {}
        local snap = {body = {}, enemies = {}, boss = nil}
        for i, seg in ipairs(st.player.body) do
            snap.body[i] = {x = seg.x, y = seg.y}
        end
        for i, e in ipairs(enemiesMod.list) do
            local c = {}
            for k, v in pairs(e) do
                if type(v) ~= "table" then c[k] = v end
            end
            snap.enemies[i] = c
        end
        if enemiesMod.boss and enemiesMod.boss.alive then
            snap.boss = {x = enemiesMod.boss.x, y = enemiesMod.boss.y}
        end
        table.insert(st.historyBuffer, snap)
        while #st.historyBuffer > (constants.HISTORY_FRAMES or 120) do
            table.remove(st.historyBuffer, 1)
        end
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
                if Events then
                    Events.emit("enemyKilled")
                    Events.emit("coinsChanged", {totalCoins = st.monedas})
                else
                    achievementsMod.check("enemyKilled")
                    achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                end
            end
        end
    end

    -- Púa de Cola (GDD item 51): el primer enemigo que pise la trampa muere
    if st.placedTraps and #st.placedTraps > 0 then
        for ti = #st.placedTraps, 1, -1 do
            local trap = st.placedTraps[ti]
            for i = #enemiesMod.list, 1, -1 do
                local e = enemiesMod.list[i]
                if e.alive and e.x == trap.x and e.y == trap.y then
                    local res = enemiesMod.killEnemy(i)
                    table.remove(st.placedTraps, ti)
                    if res then awardItemKill(st, res) end
                    break
                end
            end
        end
    end

    -- Rayo Orbital (GDD item 53): vaporiza enemigos en la columna + proyectiles
    if st.orbitalBeam and st.orbitalBeam.timer and st.orbitalBeam.timer > 0 then
        st.orbitalBeam.timer = st.orbitalBeam.timer - dt
        local bx = st.orbitalBeam.x
        for i = #enemiesMod.list, 1, -1 do
            local e = enemiesMod.list[i]
            if e.alive and e.x == bx then
                local res = enemiesMod.killEnemy(i)
                if res then awardItemKill(st, res) end
            end
        end
        for _, ao in ipairs(enemiesMod.getAttackObjects()) do
            if ao.type == "projectile" and math.abs(ao.x - bx) < 0.6 then
                ao.lifetime = 0
            end
        end
        if st.orbitalBeam.timer <= 0 then st.orbitalBeam = nil end
    end

    if snakeMod.checkTailSnap then
        local snap = snakeMod.checkTailSnap(st.player)
        if snap then
            local affected = enemiesMod.applyTailSnap(snap.gx, snap.gy, constants.TAIL_SNAP_PUSH_DIST, constants.TAIL_SNAP_STUN_DURATION, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos)
            table.insert(st.activePS, { ps = particles.tailSnapShockwave(snap.px, snap.py) })
            sound.play("shieldBreak")
            uiMod.addPopup("TAIL SNAP!", snap.gx, snap.gy)
        end
    end

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
                    if Events then
                        Events.emit("enemyKilled")
                        Events.emit("coinsChanged", {totalCoins = st.monedas})
                    else
                        achievementsMod.check("enemyKilled")
                        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                    end
                end
            end
            st.comboCount = st.comboCount + 2
            st.comboFlashTimer = 0.3
        end
    end

    if snakeMod.checkEnemyCollisions then
        local col = snakeMod.checkEnemyCollisions(st.player, enemiesMod.list)
        if col then
            if col.type == "death" then
                if triggerBattery(st) then return end
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

    -- Baba Slime + Botas Ligeras (GDD item 55): recalcular paso while en slime
    if st.player.slimeSlowTimer and st.player.slimeSlowTimer > 0 then
        st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador, {isSlime = true})
        st._wasSlimeSlowed = true
    elseif st._wasSlimeSlowed then
        st._wasSlimeSlowed = false
        st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
    end

    -- P05: magnetTimer ahora via core/timers (player.addOrRefreshTimer usa timers.after)
    -- Sincronizar HUD desde handle pooled en vez de decrementar manual
    local magnetEntry = playerMod.getActiveTimer("magnet")
    if magnetEntry then
        shop.magnetTimer = playerMod.getTimerRemaining(magnetEntry)
        st.magnetRange = constants.MAGNET_RANGE
    else
        if world.get("shop.magnetTimer", 0) > 0 then
            -- fallback legacy sin handle (tests)
            shop.magnetTimer = math.max(0, world.get("shop.magnetTimer", 0) - dt)
            if shop.magnetTimer <= 0 then
                st.magnetRange = 0
            else
                st.magnetRange = constants.MAGNET_RANGE
            end
        else
            shop.magnetTimer = 0
            st.magnetRange = 0
        end
    end

    local controlMode = world.get("controlMode") or "tactical"
    local isInputActive = (#st.player.inputQueue > 0) or Input.isAnyHeld() or Input.hasActiveTouch()

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
        local shieldBefore = world.get("shop.shieldActive", false)
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
            if Events then
                Events.emit("enemyKilled")
                Events.emit("coinsChanged", {totalCoins = st.monedas})
            else
                achievementsMod.check("enemyKilled")
                achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
            end
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
                if Events then
                    Events.emit("bossDefeated")
                    Events.emit("coinsChanged", {totalCoins = st.monedas})
                else
                    achievementsMod.check("bossDefeated")
                    achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                end
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
            -- Batería de Emergencia (GDD item 57): bullet-time 0.1x antes del modal
            if triggerBattery(st) then return end
            st.roomDamaged = true
            st.deathModalOpen = true
            return true
        end

        if shieldBefore and not world.get("shop.shieldActive", false) then
            st.roomDamaged = true
            sound.play("shieldBreak")
            shadersMod.triggerDamage(0.5, 0.5)
        end

        -- Prisma Refractor (GDD item 60): el proyectil absorbido vale 3 monedas
        if st.player.prismRefract then
            st.player.prismRefract = false
            local pc = constants.REFRACTOR_COINS or 3
            st.monedas = st.monedas + pc
            local head = st.player.body and st.player.body[1]
            if head then uiMod.addPopup("PRISMA +" .. pc .. "$", head.x, head.y) end
            sound.play("buy")
        end

        -- Cosecha Doble (GDD item 58): aviso del proc sin crecimiento
        if st.player.doubleHarvestProc then
            st.player.doubleHarvestProc = false
            local head = st.player.body and st.player.body[1]
            if head then uiMod.addPopup("COSECHA DOBLE!", head.x, head.y) end
            sound.play("eat")
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
                        if Events then
                            Events.emit("comboAchieved", {count = st.comboCount + 1})
                        else
                            achievementsMod.check("comboAchieved", {count = st.comboCount + 1})
                        end
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
                -- Diente de Oro (GDD item 56): +1 moneda por fruta cada 10 segmentos
                if shop.inventory and shop.inventory.goldenTooth then
                    local tooth = math.floor(#st.player.body / 10)
                    if tooth > 0 then
                        st.monedas = st.monedas + tooth
                        uiMod.addPopup("DIENTE +" .. tooth .. "$", foodMod.pos.x, foodMod.pos.y)
                    end
                end
                st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
                st.player.flashTimer = constants.DURACION_FLASH_COMER

                local tam = constants.TAMANIO_BLOQUE
                local fx = foodMod.pos.x * tam + tam / 2
                local fy = foodMod.pos.y * tam + tam / 2
                table.insert(st.activePS, {
                    ps = particles.comer(fx, fy)
                })

                -- P05: shockwave via timers.tween (0.4s, radio 0->48, alpha 1->0), sin loop manual
                local sw = {x = fx, y = fy, radio = 0, alpha = 1}
                table.insert(st.shockwaves, sw)
                sw._tween = timers.tween(0.4, sw, {radio = 48, alpha = 0}, function()
                    for i = #st.shockwaves, 1, -1 do
                        if st.shockwaves[i] == sw then
                            table.remove(st.shockwaves, i)
                            break
                        end
                    end
                end)

                if st.comboCount > 0 then
                    uiMod.addPopup(textPopup .. " x" .. (st.comboCount + 1), foodMod.pos.x, foodMod.pos.y)
                else
                    uiMod.addPopup(textPopup, foodMod.pos.x, foodMod.pos.y)
                end
            end

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
                    local bossResult2 = enemiesMod.onBossDefeatedByFood()
                    if bossResult2 then
                        st.monedas = st.monedas + math.floor(bossResult2.coins * (st.survivalStreak or 1.0))
                        uiMod.addPopup("+" .. bossResult2.coins .. "$", bossResult2.gx, bossResult2.gy)
                        table.insert(st.activePS, {
                            ps = particles.bossDeath(bossResult2.px, bossResult2.py)
                        })
                        sound.play("boss_defeated")
                        sound.play("enemyKill")
                        if Events then
                            Events.emit("bossDefeated")
                            Events.emit("coinsChanged", {totalCoins = st.monedas})
                        else
                            achievementsMod.check("bossDefeated")
                            achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                        end
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

            if tipo ~= "twin" or not foodMod.twinPos then
                local avoid = {}
                if enemiesMod.boss and enemiesMod.boss.alive then avoid[#avoid+1]=enemiesMod.boss end
                for _,e in ipairs(enemiesMod.list) do if e.alive then avoid[#avoid+1]=e end end
                local extra = (#avoid>0) and avoid or nil
                local ok = foodMod.generar(st.player.body, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos, nil, nil, nil)
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

return playing

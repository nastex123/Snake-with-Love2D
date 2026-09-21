-- =============================================================================
-- MÓDULO: systems/gamestates/playing.lua
-- Fachada orquestadora del estado PLAYING (Zero-GC, modular <350L).
-- Delega en:
--   - systems/gamestates/playingCombat.lua (armas, parry, ram, jefes y daño)
--   - systems/gamestates/playingPickups.lua (frutas, combos, shockwaves, objetivos)
--   - systems/gamestates/playingEvents.lua (mutadores de sala, misterios, fenix)
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
local playerMod = require("systems.player")
local Input = require("core.input")
local tarotMod = require("systems.tarot")
local statusFx = require("systems.statusFx")
local mysteryMod = require("systems.mystery")
local gameflow = require("systems.gameflow")

local playingCombat = require("systems.gamestates.playingCombat")
local playingPickups = require("systems.gamestates.playingPickups")
local playingEvents = require("systems.gamestates.playingEvents")

local hasEvents, Events = pcall(require, "core.events")
if not hasEvents or type(Events) ~= "table" then Events = nil end

function playing.update(dt)
    local st = world.state
    if st.deathModalOpen then return end

    local okModes, modesMod = pcall(require, "systems.modes")
    if okModes and modesMod and not st.timeUp then
        if modesMod.updateRush(dt) then
            local head = st.player and st.player.body and st.player.body[1]
            if head then uiMod.addPopup("TIEMPO AGOTADO", head.x, head.y) end
            gameflow.acceptDeath()
            return true
        end
    end

    -- Batería de Emergencia (GDD item 57): cuenta atrás bullet-time con dt escalado
    if st.pendingDeathTimer and st.pendingDeathTimer > 0 then
        st.pendingDeathTimer = st.pendingDeathTimer - dt
        if st.pendingDeathTimer <= 0 then
            st.pendingDeathTimer = nil
            st.timeScale = 1
            gameflow.triggerDeathAnimation()
            return true
        end
        return
    end

    if st.enemyFreezeTimer and st.enemyFreezeTimer > 0 then
        st.enemyFreezeTimer = math.max(0, st.enemyFreezeTimer - dt)
    end

    -- Cryo (GDD §16.4): aura del Golem de Escarcha criogeniza en radio
    if enemiesMod.getMiniBoss and st.player and st.player.body and st.player.body[1] then
        statusFx.checkGolemAura(st.player.body[1], enemiesMod.getMiniBoss())
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

    -- Actualización de armas e ítems de daño pasivo
    playingCombat.updateActiveWeapons(st, dt)

    -- Habilidades especiales de la serpiente (Tail Snap, Constrictor Loop)
    if snakeMod.checkTailSnap then
        local snap = snakeMod.checkTailSnap(st.player)
        if snap then
            enemiesMod.applyTailSnap(snap.gx, snap.gy, constants.TAIL_SNAP_PUSH_DIST, constants.TAIL_SNAP_STUN_DURATION, st.anchoGrilla, st.altoGrilla, obstaclesMod.pos)
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
                    tarotMod.extendBuffs(0.5)
                end
            end
            st.comboCount = st.comboCount + 2
            st.comboFlashTimer = 0.3
        end
    end

    -- Espejo (GDD §15.2): encerrar la sombra con el lazo la disuelve
    if mysteryMod.doppelActive(worldMod) then
        local dh = mysteryMod.doppelHead()
        local colOk, collisions = pcall(require, "entities.snake.collisions")
        if dh and colOk and collisions.pointInPolygon and st.player.body and #st.player.body >= 8 then
            if collisions.pointInPolygon(dh.x + 0.5, dh.y + 0.5, st.player.body) then
                playingEvents.awardDoppel(st)
            end
        end
    end

    -- Colisiones con enemigos pasivas
    if snakeMod.checkEnemyCollisions then
        local col = snakeMod.checkEnemyCollisions(st.player, enemiesMod.list)
        if col then
            if col.type == "death" then
                if playingCombat.triggerBattery(st) then return end
                if playingEvents.phoenixRevive(st) then return true end
                gameflow.triggerDeathAnimation()
                return true
            elseif col.type == "kill" or col.type == "iron_spine_block" or col.type == "shatter_kill" then
                local res = enemiesMod.killEnemy(col.index)
                if res then
                    local earnedCoins = math.floor((res.coins or 1) * (st.survivalStreak or 1.0))
                    st.monedas = st.monedas + earnedCoins
                    local label = col.type == "iron_spine_block" and "ESPINA +" or "QUEBRADO +"
                    uiMod.addPopup(label .. earnedCoins .. "$", res.gx, res.gy)
                    sound.play("enemyKill")
                    if Events then
                        Events.emit("enemyKilled")
                        Events.emit("coinsChanged", {totalCoins = st.monedas})
                    else
                        achievementsMod.check("enemyKilled")
                        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                    end
                    tarotMod.extendBuffs(0.5)
                end
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

    -- Combate con Mini-Jefe
    if playingCombat.handleMiniBossInteractions(st) then
        return true
    end

    -- Baba Slime + Botas Ligeras (GDD item 55): recalcular paso while en slime
    if st.player.slimeSlowTimer and st.player.slimeSlowTimer > 0 then
        st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador, {isSlime = true})
        st._wasSlimeSlowed = true
    elseif st._wasSlimeSlowed then
        st._wasSlimeSlowed = false
        st.velocidadActual = playerMod.calculateCurrentSpeed(st.baseSpeed, st.frutasContador)
    end

    -- P05: magnetTimer sincronizado desde core/timers + base pasiva del Santuario
    local okShrineMg, shrineMg = pcall(require, "systems.shrine")
    local magnetBase = (okShrineMg and shrineMg.magnetBase()) or 0
    local magnetEntry = playerMod.getActiveTimer("magnet")
    if magnetEntry then
        shop.magnetTimer = playerMod.getTimerRemaining(magnetEntry)
        st.magnetRange = math.max(magnetBase, constants.MAGNET_RANGE)
    else
        if world.get("shop.magnetTimer", 0) > 0 then
            shop.magnetTimer = math.max(0, world.get("shop.magnetTimer", 0) - dt)
            st.magnetRange = math.max(magnetBase, (shop.magnetTimer > 0) and constants.MAGNET_RANGE or 0)
        else
            shop.magnetTimer = 0
            st.magnetRange = magnetBase
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
                        Events.emit("enemyKilled", {source = "constrictor"})
                        Events.emit("coinsChanged", {totalCoins = st.monedas})
                    else
                        achievementsMod.check("enemyKilled")
                        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
                    end
                    local okBo, bountyMod = pcall(require, "systems.bounty")
                    if okBo and bountyMod then
                        local b = world.get("bounties")
                        if type(b) == "table" then
                            b.constrictorKills = (b.constrictorKills or 0) + 1
                            bountyMod.progress("cerco_maestro", 1)
                        end
                    end
                    tarotMod.extendBuffs(0.5)
        end

        -- Tarot IV. Ladrón de Sombras: rozar da +1 moneda
        if vivo and tarotMod.has("shadow_thief") and st.player.prevBody and st.player.prevBody[1] then
            local head = st.player.body[1]
            local prev = st.player.prevBody[1]
            for _, e in ipairs(enemiesMod.list) do
                if e.alive then
                    local function adj(p)
                        return math.abs(e.x - p.x) <= 1 and math.abs(e.y - p.y) <= 1
                            and not (e.x == p.x and e.y == p.y)
                    end
                    if adj(head) and not adj(prev) then
                        st.monedas = st.monedas + 1
                        uiMod.addPopup("+1$", head.x, head.y)
                        sound.play("buttonClick")
                        break
                    end
                end
            end
        end

        -- Combate y derrota del Boss
        if bossResult then
            if playingCombat.handleBossResult(st, bossResult) then
                return true
            end
        end

        if not vivo then
            if playingCombat.triggerBattery(st) then return end
            if playingEvents.phoenixRevive(st) then return true end
            gameflow.triggerDeathAnimation()
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
            playingPickups.handleFoodPickup(st, comioTwin)
            if playingPickups.checkRoomObjective(st) then
                return true
            end
        end
    end

    uiMod.updatePopups(dt)
    if uiMod.updateToasts then uiMod.updateToasts(dt) end

    -- Eventos de sala (mutadores de sala y misterios)
    if playingEvents.updateRoomEvents(st, dt) then
        return true
    end

    if st.comboFlashTimer > 0 then
        st.comboFlashTimer = st.comboFlashTimer - dt
    end

    local target = st.comboCount
    st.comboDisplay = st.comboDisplay + (target - st.comboDisplay) * math.min(1, dt * 4)
    st.comboIntensity = math.min(1, st.comboDisplay / 5)
    return false
end

return playing

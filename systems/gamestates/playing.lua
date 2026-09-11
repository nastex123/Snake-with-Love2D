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
local tarotMod = require("systems.tarot")
local statusFx = require("systems.statusFx")
local combatRam = require("systems.combatRam")
local mutatorsMod = require("systems.roomMutators")
local mysteryMod = require("systems.mystery")

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

local miniBossRewards = {
    wall_crusher = "shield", frost_golem = "freeze", magma_wyrm = "fire",
    brood_queen = "constrictor", void_phantom = "streak",
}

-- Recompensa de mini-jefe sala 3: monedas + bonus de racha + cofre dorado (buff temático)
local function awardMiniBoss(st, loot)
    local streak = st.survivalStreak or 1.0
    local earnedCoins = math.floor((loot.coins or 5) * streak)
    st.monedas = st.monedas + earnedCoins
    local bonus = (loot.id == "void_phantom") and 0.3 or 0.2
    st.survivalStreak = (st.survivalStreak or 1.0) + bonus
    st.highestStreak = math.max(st.highestStreak or 1.0, st.survivalStreak)
    uiMod.addPopup("+" .. earnedCoins .. "$ JEFE! +" .. bonus .. "x", loot.gx, loot.gy)
    table.insert(st.activePS, {ps = particles.bossDeath(loot.px, loot.py)})
    sound.play("boss_defeated")
    local reward = miniBossRewards[loot.id]
    if reward == "shield" then
        shop.shieldActive = true
        uiMod.addPopup("COFRE: ESCUDO", loot.gx, loot.gy)
    elseif reward == "freeze" then
        st.enemyFreezeTimer = 2.5
        uiMod.addPopup("COFRE: CONGELACION", loot.gx, loot.gy)
    elseif reward == "fire" then
        st.player.firePepperTimer = 3.5
        uiMod.addPopup("COFRE: FUEGO", loot.gx, loot.gy)
    elseif reward == "constrictor" then
        st.player.constrictorBuffTimer = 5.0
        uiMod.addPopup("COFRE: LAZO", loot.gx, loot.gy)
    elseif reward == "streak" then
        uiMod.addPopup("COFRE LEGENDARIO!", loot.gx, loot.gy)
    end
    if Events then
        Events.emit("enemyKilled")
        Events.emit("coinsChanged", {totalCoins = st.monedas})
    else
        achievementsMod.check("enemyKilled")
        achievementsMod.check("coinsChanged", {totalCoins = st.monedas})
    end
end

-- Daño directo al mini-jefe (escudo, armadura, bomba, fuego). Premia si muere.
local function damageMiniBoss(st, dmg)
    local mb = enemiesMod.getMiniBoss()
    if not mb or not mb.alive then return nil end
    local loot = enemiesMod.hitMiniBoss(dmg, {enemies = enemiesMod})
    if loot then awardMiniBoss(st, loot) end
    return loot
end

-- ¿Cabeza dentro del bloque 2x2 del mini-jefe?
local function headOnMiniBoss(st, mb)
    local head = st.player.body and st.player.body[1]
    if not head or not mb then return false end
    return head.x >= mb.x and head.x <= mb.x + 1 and head.y >= mb.y and head.y <= mb.y + 1
end

-- Item aleatorio no poseido via tienda costo 0 (premios Contrarreloj/Espejo/Altar)
local function grantRandomItem(st, onlyPassive)
    local hasItems, itemsMod = pcall(require, "systems.items")
    if not hasItems then return nil end
    local pool = {}
    for id, def in pairs(itemsMod.registry or {}) do
        if type(def) == "table" and not shop.isOwned(def.id or id)
            and (not onlyPassive or def.itemType == "passive") then
            pool[#pool + 1] = def.id or id
        end
    end
    for _ = 1, math.min(5, #pool) do
        local pick = table.remove(pool, love.math.random(#pool))
        local res = shop.procesarCompra(st.monedas, pick, 0)
        if res then return pick end
    end
    return nil
end

-- Espejo disuelto (GDD §15.2): 30$ + cofre dorado (item aleatorio)
local function awardDoppel(st)
    local d = mysteryMod.data()
    if d.doppelDone then return end
    d.doppelDone = true
    d.doppel = nil
    st.monedas = (st.monedas or 0) + (constants.DOPPEL_REWARD_COINS or 30)
    local head = st.player.body and st.player.body[1]
    local pick = grantRandomItem(st)
    if head then
        uiMod.addPopup("ESPEJO +30$", head.x, head.y)
        if pick then uiMod.addPopup("PREMIO: " .. string.upper(pick), head.x, head.y) end
    end
    sound.play("highScore")
end

-- Bendicion del Fenix (GDD §19.67): revive gratis 1 vez por etapa (3 segmentos + 3s fantasma)
local function phoenixRevive(st)    if not mutatorsMod.phoenixAvailable() then return false end
    local p = st.player
    if not (p and p.body and #p.body > 0) then return false end
    mutatorsMod.phoenixConsume()
    while #p.body > 3 do table.remove(p.body) end
    p.ghost = true
    p.ghostTimer = 3.0
    p.flashTimer = 3.0
    local head = p.body[1]
    for i = #enemiesMod.list, 1, -1 do
        local e = enemiesMod.list[i]
        if e and e.alive and math.abs(e.x - head.x) <= 3 and math.abs(e.y - head.y) <= 3 then
            enemiesMod.killEnemy(i)
        end
    end
    uiMod.addPopup("FENIX!", head.x, head.y)
    sound.play("highScore")
    return true
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

    -- Rastro de fuego vs mini-jefe: ya no daña (GDD §5 rework, solo cabezazos).

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
                awardDoppel(st)
            end
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
            elseif col.type == "iron_spine_block" or col.type == "frozen_shatter" then
                -- Tarot II/VII: la cola de hierro y el hielo frágil matan con recompensa
                local res = col.result
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

    -- Cabezazo al mini-jefe sala 3 (GDD §5 rework): daño por combo + rebote seguro + parry
    do
        local mb = enemiesMod.getMiniBoss()
        if mb and mb.alive and headOnMiniBoss(st, mb) then
            local comboDisplay = (st.comboCount or 0) + 1
            local dmg = combatRam.damageFor(comboDisplay)
            local head0 = st.player.body and st.player.body[1]
            combatRam.ram(st.player, st.anchoGrilla, st.altoGrilla, {
                body = st.player.body,
                avoidRects = {{x0 = mb.x, y0 = mb.y, x1 = mb.x + 1, y1 = mb.y + 1}},
            })
            local head = st.player.body and st.player.body[1]
            if head0 and head and (head.x ~= head0.x or head.y ~= head0.y) then
                uiMod.addPopup("REBOTE!", head.x, head.y)
            end
            local parryCtx = {
                enemies = enemiesMod,
                obstacles = obstaclesMod,
                attackRegistry = enemiesMod,
                head = head,
                tail = st.player.body and st.player.body[#st.player.body],
                anchoGrilla = st.anchoGrilla,
                altoGrilla = st.altoGrilla,
            }
            if enemiesMod.parryMiniBoss and enemiesMod.parryMiniBoss(parryCtx) then
                if head then uiMod.addPopup("¡PARRY!", head.x, head.y) end
                sound.play("shieldBreak")
            end
            if dmg > 0 then
                sound.play("enemyKill")
                if head then uiMod.addPopup("-" .. dmg .. " CABEZAZO!", head.x, head.y) end
                damageMiniBoss(st, dmg)
            else
                st.lastRamHint = st.lastRamHint or -10
                if head and (st.time or 0) - st.lastRamHint > 3 then
                    st.lastRamHint = st.time or 0
                    uiMod.addPopup("SUBE EL COMBO (x2+)!", head.x, head.y)
                end
            end
        end
        -- Detonación de singularidad del Espectro: golpe letal telegrafiado
        if mb and mb.pendingHit then
            mb.pendingHit = false
            if not (st.player.ghost or world.get("debugImmune", false)) then
                if world.get("shop.shieldActive", false) then
                    shop.shieldActive = false
                    sound.play("shieldBreak")
                    shadersMod.triggerDamage(0.5, 0.5)
                elseif st.player.armor and st.player.armor > 0 then
                    st.player.armor = st.player.armor - 1
                    sound.play("shieldBreak")
                    shadersMod.triggerDamage(0.4, 0.4)
                else
                    if triggerBattery(st) then return end
                    st.roomDamaged = true
                    st.deathModalOpen = true
                    return true
                end
            end
        end
        -- Embestida del Triturador: sacudida no letal (aturdido, GDD)
        if mb and mb.slammed then
            mb.slammed = false
            st.shakeTimer = 0.3
            shadersMod.triggerDamage(0.6, 0.4)
            uiMod.addPopup("TERREMOTO!", mb.x, mb.y)
            sound.play("shieldBreak")
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
            tarotMod.extendBuffs(0.5)
        end

        -- Tarot IV. Ladrón de Sombras: rozar (nueva adyacencia) da +1 moneda
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

        if bossResult then
            if bossResult.hit then
                -- Cabezazo al boss (GDD §5 rework): daño por combo + rebote seguro
                local comboDisplay = (st.comboCount or 0) + 1
                local dmg = combatRam.damageFor(comboDisplay)
                local boss = enemiesMod.boss
                local avoid = nil
                if boss and boss.alive then
                    avoid = {{x0 = boss.x, y0 = boss.y, x1 = boss.x, y1 = boss.y}}
                end
                combatRam.ram(st.player, st.anchoGrilla, st.altoGrilla, {body = st.player.body, avoidRects = avoid})
                -- Display HUD desde el boss real (modelo hp único), nunca el {hit} pelado del mover
                local function refreshBossDisplay()
                    local b = enemiesMod.boss
                    if b and b.alive then
                        st.bossHealthDisplay = {hp = b.hp, maxHp = b.maxHp}
                    end
                end
                local head = st.player.body and st.player.body[1]
                if dmg > 0 then
                    sound.play("enemyKill")
                    if head then uiMod.addPopup("-" .. dmg .. " CABEZAZO!", head.x, head.y) end
                    local ramLoot = enemiesMod.hitBossRam(dmg)
                    if ramLoot and ramLoot.type == "boss" then
                        bossResult = ramLoot
                    else
                        refreshBossDisplay()
                        -- Enrage al cruzar el umbral de HP (GDD §5 rework)
                        local boss = enemiesMod.boss
                        if boss and boss.alive and not boss.enraged
                            and (boss.hp or 99) <= (constants.BOSS_ENRAGE_THRESHOLD or 3) then
                            boss.enraged = true
                            boss.enrageFlash = constants.BOSS_ENRAGE_FLASH or 1.2
                            uiMod.addPopup("FURIA DEL JEFE!", boss.x, boss.y)
                            sound.play("enemyKill")
                            st.shakeTimer = 0.3
                            shadersMod.triggerDamage(0.8, 0.6)
                        end
                    end
                else
                    refreshBossDisplay()
                    st.lastRamHint = st.lastRamHint or -10
                    if head and (st.time or 0) - st.lastRamHint > 3 then
                        st.lastRamHint = st.time or 0
                        uiMod.addPopup("SUBE EL COMBO (x2+)!", head.x, head.y)
                    end
                end
            end
            if bossResult and bossResult.type == "boss" then
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
                tarotMod.extendBuffs(0.5)
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
            -- Bendicion del Fenix (GDD §19.67): revive gratis antes del modal
            if phoenixRevive(st) then return true end
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
                -- Pacto del Titan (GDD §19.70): +50 puntos base por fruta
                puntosBase = puntosBase + mutatorsMod.titanFruitBonus()

                if st.time - st.lastEatTime <= tarotMod.comboWindow() then
                    st.comboCount = st.comboCount + 1
                    st.comboFlashTimer = 0.3
                    if st.comboCount >= 4 then
                        if Events then
                            Events.emit("comboAchieved", {count = st.comboCount + 1})
                        else
                            achievementsMod.check("comboAchieved", {count = st.comboCount + 1})
                        end
                    end
                    -- Overdrive (GDD §16.1): combo x6 activa frenesi; refresh silencioso
                    local odApplied, odFresh = statusFx.checkOverdrive(st.comboCount + 1)
                    if odApplied and odFresh then
                        local head = st.player.body and st.player.body[1]
                        if head then uiMod.addPopup("OVERDRIVE!", head.x, head.y) end
                        sound.play("highScore")
                    end
                else
                    st.comboCount = 0
                end
                st.lastEatTime = st.time
                local comboMult = tarotMod.comboMult(1 + st.comboCount * constants.COMBO_MULTIPLIER)
                local total = math.floor(puntosBase * comboMult * (st.scoreMultiplier or 1) * streak)

                st.puntuacion = st.puntuacion + total
                st.frutasContador = st.frutasContador + 1
                st.monedas = st.monedas + math.floor((monedasExtra + st.coinBonus) * streak)
                -- Midas Avaro (GDD §19.62): +2 monedas por fruta
                st.monedas = st.monedas + mutatorsMod.midasFruitBonus()
                -- Apostador (GDD §15.1): 3 doradas con apuesta = 40$ + item + racha
                if tipo == constants.FOOD_GOLD and mysteryMod.gamblerGoldEaten() == "win" then
                    st.monedas = st.monedas + (constants.GAMBLER_WIN_COINS or 40)
                    st.survivalStreak = (st.survivalStreak or 1.0) + 0.3
                    local hasItems, itemsMod = pcall(require, "systems.items")
                    if hasItems then
                        local pool = {}
                        for id, def in pairs(itemsMod.registry or {}) do
                            if type(def) == "table" and not shop.isOwned(def.id or id) then
                                pool[#pool + 1] = def.id or id
                            end
                        end
                        for _ = 1, math.min(5, #pool) do
                            local pick = table.remove(pool, love.math.random(#pool))
                            local res = shop.procesarCompra(st.monedas, pick, 0)
                            if res then
                                local head = st.player.body and st.player.body[1]
                                if head then uiMod.addPopup("PREMIO: " .. string.upper(pick), head.x, head.y) end
                                break
                            end
                        end
                    end
                    local head = st.player.body and st.player.body[1]
                    if head then uiMod.addPopup("APUESTA +40$", head.x, head.y) end
                    sound.play("highScore")
                end
                -- Dualidad (GDD §19.69): la fruta espejo se consume sin bonus extra
                if comioTwin then foodMod.twinPos = nil; foodMod.dualTwin = nil end
                -- Espejo (GDD §15.2): 3 frutas normales lo disuelven
                if tipo == constants.FOOD_NORMAL and mysteryMod.doppelFed() == "dissolve" then
                    awardDoppel(st)
                end
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

            if enemiesMod.boss and enemiesMod.boss.alive then
                local tam2 = constants.TAMANIO_BLOQUE
                table.insert(st.activePS, {
                    ps = particles.bossFoodTick(foodMod.pos.x * tam2 + tam2 / 2, foodMod.pos.y * tam2 + tam2 / 2)
                })
            end

            -- Mini-jefe sala 3 (GDD §5 rework): la comida ya no lo debilita,
            -- solo da puntos/monedas; el daño es solo por cabezazos.

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
            -- Apostador (GDD §15.1): mientras falten doradas, los respawns nacen oro
            if mysteryMod.gamblerNeedsGold() then foodMod.tipo = constants.FOOD_GOLD end

            if st.puntuacion >= st.lastObstacleScore + constants.OBSTACLE_SPAWN_INTERVAL then
                st.lastObstacleScore = math.floor(st.puntuacion / constants.OBSTACLE_SPAWN_INTERVAL) * constants.OBSTACLE_SPAWN_INTERVAL
                local mod = worldMod.getModifier()
                obstaclesMod.generar(st.player.body, foodMod.pos, st.anchoGrilla, st.altoGrilla)
                enemiesMod.generar(st.player.body, foodMod.pos, obstaclesMod.pos, st.anchoGrilla, st.altoGrilla, mod)
            end

            -- Gating elite (GDD §5 rework): con mini vivo no hay salida por puntos
            local mbGate = enemiesMod.getMiniBoss and enemiesMod.getMiniBoss()
            local miniAlive = mbGate and mbGate.alive
            if miniAlive and st.puntuacion >= worldMod.objetivoSala and not st.transitionTarget then
                st.lastMiniGateHint = st.lastMiniGateHint or -10
                if (st.time or 0) - st.lastMiniGateHint > 4 then
                    st.lastMiniGateHint = st.time or 0
                    local head = st.player.body and st.player.body[1]
                    if head then uiMod.addPopup("DERROTA AL MINI-JEFE PARA AVANZAR", head.x, head.y) end
                end
            end

            if st.puntuacion >= worldMod.objetivoSala and not worldMod.esJefe() and not miniAlive and not st.transitionTarget then
                -- Contrarreloj (GDD §19.66): premio si el objetivo se cumple a tiempo
                if mutatorsMod.has("time_trial") and not mutatorsMod.data().rewarded then
                    mutatorsMod.data().rewarded = true
                    if mutatorsMod.timeTrialWon() then
                        local pick = grantRandomItem(st, true)
                        if pick then
                            local head = st.player.body and st.player.body[1]
                            if head then uiMod.addPopup("CRONO: " .. string.upper(pick), head.x, head.y) end
                            sound.play("highScore")
                        end
                    end
                end
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

    -- Room Mutators tick (GDD §19): drenaje Midas + expiracion Contrarreloj
    mutatorsMod.midasDrain(dt)
    if mutatorsMod.timeTrialTick(dt) == "expired" then
        local head = st.player.body and st.player.body[1]
        if head then uiMod.addPopup("CRONO AGOTADO", head.x, head.y) end
    end
    -- Sombra Acechante (GDD §19.65): muerte al contacto (Fenix puede salvar)
    if mutatorsMod.shadowTick(dt, st.player.body and st.player.body[1]) == "kill" then
        if phoenixRevive(st) then return true end
        st.roomDamaged = true
        st.deathModalOpen = true
        return true
    end
    -- Guarida del Apostador (GDD §15.1): apuesta en la ruleta + temporizador
    local head0 = st.player.body and st.player.body[1]
    if mysteryMod.gamblerActive(worldMod) then
        local gd = mysteryMod.data()
        if not gd.bet and head0 then
            local r = mysteryMod.gamblerRoulette(st.anchoGrilla, st.altoGrilla)
            if head0.x == r.x and head0.y == r.y then
                if mysteryMod.gamblerPlaceBet(st.monedas or 0) then
                    st.monedas = st.monedas - mysteryMod.gamblerBet()
                    uiMod.addPopup("APUESTA -10$", head0.x, head0.y)
                    sound.play("buy")
                elseif not gd.refused then
                    gd.refused = true
                    uiMod.addPopup("SIN FONDOS", head0.x, head0.y)
                end
            end
        end
        if mysteryMod.gamblerTick(dt) == "lose" then
            local helpersOk, helpers = pcall(require, "entities.enemyHelpers")
            for _ = 1, (constants.GAMBLER_LOSE_CHASERS or 2) do
                local nx, ny
                if helpersOk then
                    nx, ny = helpers.sampleFreeTile(st.anchoGrilla, st.altoGrilla, st.player.body, obstaclesMod, enemiesMod.list, 2, 30)
                end
                if nx and enemiesMod.spawnAt then enemiesMod.spawnAt("chaser", nx, ny, {}) end
            end
            if head0 then uiMod.addPopup("APUESTA PERDIDA", head0.x, head0.y) end
            sound.play("death")
        end
    end
    -- Fiebre del Oro (GDD §15.3): monedas rebotando + puerta a los 12s
    if mysteryMod.goldRushActive(worldMod) then
        local got, done = mysteryMod.goldRushTick(dt, head0)
        if got > 0 then
            st.monedas = (st.monedas or 0) + got
            sound.play("buttonClick")
        end
        if done and not st.transitionTarget then
            st.transitionTarget = "siguienteSala"
            st.transitionPhase = 1
            st.fadeDir = 1
            st.gameState = constants.GAME_STATE_TRANSITION
            sound:playSegment("intro")
            return true
        end
    end
    -- Espejo (GDD §15.2): replica con retraso + contacto letal
    if mysteryMod.doppelActive(worldMod) then
        local dd = mysteryMod.data().doppel
        if dd then
            local p = st.player
            mysteryMod.doppelTick(dt, dd, {x = p.dirX or 0, y = p.dirY or 0}, st.time or 0, st.velocidadActual or 0.13)
            if head0 and mysteryMod.doppelTouchesHead(dd, head0) then
                if phoenixRevive(st) then return true end
                st.roomDamaged = true
                st.deathModalOpen = true
                return true
            end
        end
    end
    -- Sellos (GDD §15.4): orden 1-2-3 en menos de 10s
    if mysteryMod.triadsActive(worldMod) then
        local tr = mysteryMod.data().triads
        if tr then
            tr.timer = tr.timer - dt
            local step = mysteryMod.triadsStep(tr, head0)
            if step == "next" then
                if head0 then uiMod.addPopup("SELLO " .. tr.progress .. "/3", head0.x, head0.y) end
                sound.play("buy")
            elseif step == "reset" then
                if head0 then uiMod.addPopup("SELLOS RESET", head0.x, head0.y) end
            elseif step == "complete" then
                st.monedas = (st.monedas or 0) + (constants.TRIADS_REWARD_COINS or 50)
                grantRandomItem(st)
                grantRandomItem(st)
                if head0 then uiMod.addPopup("ALTAR LEGENDARIO", head0.x, head0.y) end
                sound.play("highScore")
            elseif tr.timer <= 0 then
                tr.done = true
                if head0 then uiMod.addPopup("SELLOS APAGADOS", head0.x, head0.y) end
            end
        end
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

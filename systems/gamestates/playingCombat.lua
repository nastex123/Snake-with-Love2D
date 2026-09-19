-- =============================================================================
-- MÓDULO: systems/gamestates/playingCombat.lua
-- Maneja combate con jefes/mini-jefes, parry, cabezazos (ram), triturador, proyectiles y trampas.
-- Submódulo desacoplado de playing.lua (Zero-GC en loops de frame).
-- =============================================================================
local playingCombat = {}

local constants = require("constants")
local world = require("core.world")
local sound = require("audio.sound")
local shop = require("systems.shop")
local uiMod = require("ui.ui")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local particles = require("render.particles")
local shadersMod = require("render.shaders")
local achievementsMod = require("systems.achievements")
local tarotMod = require("systems.tarot")
local combatRam = require("systems.combatRam")
local playingEvents = require("systems.gamestates.playingEvents")

local hasEvents, Events = pcall(require, "core.events")
if not hasEvents or type(Events) ~= "table" then Events = nil end

-- Batería de Emergencia (GDD item 57): bullet-time 0.1x con dt escalado
function playingCombat.triggerBattery(st)
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
function playingCombat.awardItemKill(st, res)
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
function playingCombat.awardMiniBoss(st, loot)
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
function playingCombat.damageMiniBoss(st, dmg)
    local mb = enemiesMod.getMiniBoss()
    if not mb or not mb.alive then return nil end
    local loot = enemiesMod.hitMiniBoss(dmg, {enemies = enemiesMod})
    if loot then playingCombat.awardMiniBoss(st, loot) end
    return loot
end

local function headOnMiniBoss(st, mb)
    local head = st.player.body and st.player.body[1]
    if not head or not mb then return false end
    return head.x >= mb.x and head.x <= mb.x + 1 and head.y >= mb.y and head.y <= mb.y + 1
end

local function headOnChargeLane(st, lane)
    local head = st.player.body and st.player.body[1]
    if not head or not lane then return false end
    if lane.horizontal then
        return head.y == lane.fixed0 or head.y == lane.fixed1
    end
    return head.x == lane.fixed0 or head.x == lane.fixed1
end

local function resolveTrampleCut(st, mb)
    local body = st.player.body
    if not body or #body <= 3 then return 0 end
    local base = constants.CRUSHER_TRAMPLE_CUT_BASE or 2
    local maxCut = constants.CRUSHER_TRAMPLE_CUT_MAX or 4
    local cut = math.min(base + (mb.trampleHits or 0), maxCut)
    cut = math.min(cut, #body - 3)
    for _ = 1, cut do table.remove(body) end
    st.player.prevBody = {}
    for i, b in ipairs(body) do
        st.player.prevBody[i] = {x = b.x, y = b.y}
    end
    st.player.sliceGraceTimer = constants.PATROLLER_SLICE_GRACE_TIME or 1.0
    mb.trampleHits = (mb.trampleHits or 0) + 1
    return cut
end

-- Actualiza habilidades activas e items pasivos de ataque (fire trail, trampas, rayo orbital)
function playingCombat.updateActiveWeapons(st, dt)
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

    -- Púa de Cola (GDD item 51): trampa mata al primer enemigo
    if st.placedTraps and #st.placedTraps > 0 then
        for ti = #st.placedTraps, 1, -1 do
            local trap = st.placedTraps[ti]
            for i = #enemiesMod.list, 1, -1 do
                local e = enemiesMod.list[i]
                if e.alive and e.x == trap.x and e.y == trap.y then
                    local res = enemiesMod.killEnemy(i)
                    table.remove(st.placedTraps, ti)
                    if res then playingCombat.awardItemKill(st, res) end
                    break
                end
            end
        end
    end

    -- Rayo Orbital (GDD item 53): vaporiza columna y proyectiles
    if st.orbitalBeam and st.orbitalBeam.timer and st.orbitalBeam.timer > 0 then
        st.orbitalBeam.timer = st.orbitalBeam.timer - dt
        local bx = st.orbitalBeam.x
        for i = #enemiesMod.list, 1, -1 do
            local e = enemiesMod.list[i]
            if e.alive and e.x == bx then
                local res = enemiesMod.killEnemy(i)
                if res then playingCombat.awardItemKill(st, res) end
            end
        end
        for _, ao in ipairs(enemiesMod.getAttackObjects()) do
            if ao.type == "projectile" and math.abs(ao.x - bx) < 0.6 then
                ao.lifetime = 0
            end
        end
        if st.orbitalBeam.timer <= 0 then st.orbitalBeam = nil end
    end
end

-- Procesa combate del mini-jefe (cabezazo, parry, singularidad y arrollamiento triturador)
function playingCombat.handleMiniBossInteractions(st)
    local mb = enemiesMod.getMiniBoss and enemiesMod.getMiniBoss()
    if not mb or not mb.alive then return false end

    if headOnMiniBoss(st, mb) then
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
            playingCombat.damageMiniBoss(st, dmg)
        else
            st.lastRamHint = st.lastRamHint or -10
            if head and (st.time or 0) - st.lastRamHint > 3 then
                st.lastRamHint = st.time or 0
                uiMod.addPopup("SUBE EL COMBO (x2+)!", head.x, head.y)
            end
        end
    end

    -- Detonación de singularidad del Espectro: golpe letal telegrafiado
    if mb.pendingHit then
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
                if playingCombat.triggerBattery(st) then return true end
                st.roomDamaged = true
                st.deathModalOpen = true
                return true
            end
        end
    end

    -- Embestida del Triturador: arrollamiento con corte de cola (GDD §5)
    if mb.slammed then
        mb.slammed = false
        st.shakeTimer = 0.3
        shadersMod.triggerDamage(0.6, 0.4)
        uiMod.addPopup("TERREMOTO!", mb.x, mb.y)
        sound.play("shieldBreak")
        if headOnChargeLane(st, mb.chargeLane) then
            local ghost = st.player.ghost or world.get("debugImmune", false)
                or (combatRam and combatRam.hasGhost(st.player))
            if ghost then
                -- Intangible: arrollamiento pasa sin efecto
            elseif world.get("shop.shieldActive", false) then
                shop.shieldActive = false
                sound.play("shieldBreak")
                local head = st.player.body and st.player.body[1]
                if head then uiMod.addPopup("ESCUDO: ARROLLAMIENTO BLOQUEADO", head.x, head.y) end
            elseif st.player.armor and st.player.armor > 0 then
                st.player.armor = st.player.armor - 1
                sound.play("shieldBreak")
                local head = st.player.body and st.player.body[1]
                if head then uiMod.addPopup("ARMADURA: ARROLLAMIENTO BLOQUEADO", head.x, head.y) end
            else
                local cut = resolveTrampleCut(st, mb)
                local head = st.player.body and st.player.body[1]
                if cut > 0 and head then
                    local step = constants.CRUSHER_TRAMPLE_STREAK_STEP or 0.1
                    st.roomDamaged = true
                    st.survivalStreak = math.max(1.0, (st.survivalStreak or 1.0) - step * (mb.trampleHits or 1))
                    local pen = string.format("%.1f", step * (mb.trampleHits or 1))
                    uiMod.addPopup("¡COLA SEGADA -" .. cut .. "! RACHA -" .. pen .. "x", head.x, head.y)
                elseif head then
                    uiMod.addPopup("¡AGUANTA!", head.x, head.y)
                end
            end
        end
        mb.chargeLane = nil
    end

    return false
end

-- Procesa cabezazo y resolución de Boss principal
function playingCombat.handleBossResult(st, bossResult)
    if not bossResult then return false end

    if bossResult.hit then
        local comboDisplay = (st.comboCount or 0) + 1
        local dmg = combatRam.damageFor(comboDisplay)
        local boss = enemiesMod.boss
        local avoid = nil
        if boss and boss.alive then
            avoid = {{x0 = boss.x, y0 = boss.y, x1 = boss.x, y1 = boss.y}}
        end
        combatRam.ram(st.player, st.anchoGrilla, st.altoGrilla, {body = st.player.body, avoidRects = avoid})

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
                local b = enemiesMod.boss
                if b and b.alive and not b.enraged
                    and (b.hp or 99) <= (constants.BOSS_ENRAGE_THRESHOLD or 3) then
                    b.enraged = true
                    b.enrageFlash = constants.BOSS_ENRAGE_FLASH or 1.2
                    uiMod.addPopup("FURIA DEL JEFE!", b.x, b.y)
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

    return false
end

return playingCombat

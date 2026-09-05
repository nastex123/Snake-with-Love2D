-- =============================================================================
-- MÓDULO: enemyBossLogic.lua
-- Parte de P01 — Split de entities/enemies.lua (634 → 4 módulos)
-- Gestiona ciclo de vida del boss y su máquina de estados (enrage, fases, ataques).
-- Extraído de entities/enemies.lua sin cambios de semántica.
-- =============================================================================
local bossLogic = {}

local constants = require("constants")
local bossAttacks = require("entities.bossAttacks")

-- ---------------------------------------------------------------------------
-- Spawn / Hit / Defeat (food-based)
-- ---------------------------------------------------------------------------
function bossLogic.spawnBoss(enemiesMod, etapa, anchoGrilla, altoGrilla, bossVida, dropCoins, attackRegistry)
    local cx = math.floor(anchoGrilla / 2)
    local cy = math.floor(altoGrilla / 2)
    enemiesMod.boss = {
        x = cx, y = cy,
        vida = bossVida,
        vidaMax = bossVida,
        bossType = "teleporter",
        alive = true,
        moveTimer = 0,
        spawnTimer = 0,
        dropCoins = dropCoins or 5,
        phase = 1,
        state = "idle",
        stateTimer = 0,
        attackCooldown = 2.0,
        currentAttack = nil,
        telegraphPositions = {},
        foodCollected = 0,
        foodTarget = constants.BOSS_FOOD_TARGET,
        invulnerable = true,
        enraged = false,
        enrageFlash = 0,
        _uiBarFill = 1.0,
        _uiBarTarget = 1.0,
    }
    if attackRegistry then
        attackRegistry.clearAll()
    end
    return enemiesMod.boss
end

function bossLogic.hitBoss(enemiesMod, attackRegistry)
    local boss = enemiesMod.boss
    if not boss or not boss.alive then return nil end
    if boss.invulnerable then
        return {hit = true, vida = boss.vida, vidaMax = boss.vidaMax}
    end
    -- Defensive: tests may create boss without vida initialized (e.g. direct table)
    boss.vida = (boss.vida or boss.vidaMax or boss.hp or 3) - 1
    boss.vidaMax = boss.vidaMax or boss.vida + 1
    if boss.vida <= 0 then
        boss.alive = false
        if attackRegistry then attackRegistry.clearAll() end
        local tam = constants.TAMANIO_BLOQUE
        return {
            px = boss.x * tam + tam / 2,
            py = boss.y * tam + tam / 2,
            gx = boss.x, gy = boss.y,
            coins = boss.dropCoins,
            type = "boss"
        }
    end
    return {hit = true, vida = boss.vida, vidaMax = boss.vidaMax}
end

function bossLogic.onBossDefeatedByFood(enemiesMod, attackRegistry)
    local boss = enemiesMod.boss
    if not boss or not boss.alive then return nil end
    boss.alive = false
    boss.invulnerable = false
    if attackRegistry then attackRegistry.clearAll() end
    local tam = constants.TAMANIO_BLOQUE
    return {
        px = boss.x * tam + tam / 2,
        py = boss.y * tam + tam / 2,
        gx = boss.x, gy = boss.y,
        coins = boss.dropCoins,
        type = "boss"
    }
end

-- ---------------------------------------------------------------------------
-- Update — máquina de estados del boss (idle → telegraph → execute → cooldown)
-- ---------------------------------------------------------------------------
function bossLogic.updateBoss(dt, boss, ctx, attackRegistry, enemiesMod)
    if not boss or not boss.alive then return end

    -- Actualiza fase por vida / food progress
    local vidaFrac
    if boss.foodTarget and boss.foodTarget > 0 then
        vidaFrac = math.max(0, 1 - (boss.foodCollected or 0) / boss.foodTarget)
    else
        vidaFrac = (boss.vidaMax and boss.vidaMax > 0) and (boss.vida / boss.vidaMax) or 1.0
    end

    if vidaFrac <= 0.30 then
        boss.phase = 3
    elseif vidaFrac <= 0.60 then
        boss.phase = 2
    else
        boss.phase = 1
    end

    local enrageAt = (boss.foodTarget or constants.BOSS_FOOD_TARGET) - (constants.BOSS_ENRAGE_THRESHOLD or 3)
    local wasEnraged = boss.enraged
    if boss.foodTarget and (boss.foodCollected or 0) >= enrageAt then
        boss.enraged = true
    else
        boss.enraged = false
    end
    -- Flanco de activacion: pulso carmesi visible al entrar en furia
    if boss.enraged and not wasEnraged then
        boss.enrageFlash = constants.BOSS_ENRAGE_FLASH or 1.2
    end
    if boss.enrageFlash and boss.enrageFlash > 0 then
        boss.enrageFlash = math.max(0, boss.enrageFlash - dt)
    end

    local enrageMult = constants.BOSS_ENRAGE_MULT or 1.35
    local speedMult = 1.0 + (boss.phase - 1) * 0.2
    if boss.enraged then
        speedMult = speedMult * enrageMult
    end

    local innerCtx = {
        snakeHead = ctx.snakeHead or ctx.head,
        anchoGrilla = ctx.anchoGrilla,
        altoGrilla = ctx.altoGrilla,
        canSpawn = ctx.canSpawn or (enemiesMod and enemiesMod.canSpawn),
        enemies = ctx.enemies or enemiesMod,
        speedMult = speedMult,
    }

    if boss.state == "idle" then
        boss.attackCooldown = boss.attackCooldown - dt
        if boss.attackCooldown <= 0 then
            local attacks = bossAttacks.getAvailable(boss.phase)
            if #attacks > 0 then
                local chosen = attacks[love.math.random(1, #attacks)]
                boss.currentAttack = chosen
                boss.telegraphPositions = bossAttacks.computePositions(boss, chosen, innerCtx)
                -- Furia: telegrafiados 35% mas rapidos (GDD Fase de Furia)
                local telegraphTime = chosen.telegraphTime
                if boss.enraged then
                    telegraphTime = telegraphTime / enrageMult
                end
                for _, pos in ipairs(boss.telegraphPositions) do
                    attackRegistry.addTelegraph(pos.x, pos.y, telegraphTime, chosen.name)
                end
                boss.state = "telegraph"
                boss.stateTimer = telegraphTime
            end
        end

    elseif boss.state == "telegraph" then
        boss.stateTimer = boss.stateTimer - dt
        if boss.stateTimer <= 0 then
            bossAttacks.execute(boss, boss.currentAttack.name, dt, innerCtx)
            -- Limpia telegraphs visibles al ejecutar
            local telegraphs = attackRegistry.getTelegraphs()
            for i = #telegraphs, 1, -1 do table.remove(telegraphs, i) end
                boss.state = "cooldown"
                local cd = boss.currentAttack.cooldown * (boss.phase == 3 and 0.7 or 1.0)
                if boss.enraged then cd = cd / enrageMult end
                boss.stateTimer = cd
        end

    elseif boss.state == "cooldown" then
        boss.stateTimer = boss.stateTimer - dt
        if boss.stateTimer <= 0 then
            boss.state = "idle"
            boss.attackCooldown = 1.0
        end
    end
end

function bossLogic.updateBarLerp(boss, dt)
    if not boss or not boss.alive then return end
    local lerpSpeed = constants.BOSS_HEALTH_BAR.lerpSpeed or 6.0
    -- Defensive defaults: tests may create boss without bar fields
    if boss._uiBarFill == nil then boss._uiBarFill = 1.0 end
    if boss._uiBarTarget == nil then boss._uiBarTarget = boss._uiBarFill end
    boss._uiBarFill = boss._uiBarFill + (boss._uiBarTarget - boss._uiBarFill) * math.min(1, dt * lerpSpeed)
end

return bossLogic

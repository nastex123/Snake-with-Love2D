-- =============================================================================
-- MÓDULO: entities/snake/core.lua
-- Parte de P02 — Split de entities/snake.lua (922 → 4 submódulos + fachada)
-- Gestiona estado base de la serpiente: reset e update de timers.
-- Extraído de entities/snake.lua sin cambios de semántica.
-- =============================================================================
local core = {}
local constants = require("constants")
local world = require("core.world")
local shop = require("systems.shop") -- legacy proxy, prefer World.get("shop.ghostActive")

function core.reset()
    return {
        body = {
            {x = 5, y = 5},
            {x = 4, y = 5},
            {x = 3, y = 5}
        },
        dirX = 1,
        dirY = 0,
        lastMovedDirX = 1,
        lastMovedDirY = 0,
        inputQueue = {},
        prevBody = {
            {x = 5, y = 5},
            {x = 4, y = 5},
            {x = 3, y = 5}
        },
        trail = {},
        ghost = false,
        ghostTimer = 0,
        armor = 0,
        flashTimer = 0,
        autotomyCooldown = 0,
        decoys = {},
        constrictorBuffTimer = 0,
        reverseSlitherTimer = 0,
        reverseSlitherCooldown = 0,
        firePepperTimer = 0,
        slimeSlowTimer = 0,
        fireTrail = {},
        turnHistory = {},
        pendingTailSnap = false,
        standstill = true,
        hasNewInput = false,
        sliceGraceTimer = 0
    }
end

function core.update(s, dt)
    if not s then return end
    if s.flashTimer and s.flashTimer > 0 then
        s.flashTimer = math.max(0, s.flashTimer - dt)
    end
    if s.sliceGraceTimer and s.sliceGraceTimer > 0 then
        s.sliceGraceTimer = math.max(0, s.sliceGraceTimer - dt)
    end
    if s.ghostTimer and s.ghostTimer > 0 then
        s.ghostTimer = math.max(0, s.ghostTimer - dt)
        if s.ghostTimer <= 0 and not world.get("shop.ghostActive", false) then
            s.ghost = false
        end
    end
    if s.autotomyCooldown and s.autotomyCooldown > 0 then
        s.autotomyCooldown = math.max(0, s.autotomyCooldown - dt)
    end
    if s.reverseSlitherTimer and s.reverseSlitherTimer > 0 then
        s.reverseSlitherTimer = math.max(0, s.reverseSlitherTimer - dt)
    end
    if s.reverseSlitherCooldown and s.reverseSlitherCooldown > 0 then
        s.reverseSlitherCooldown = math.max(0, s.reverseSlitherCooldown - dt)
    end
    if s.constrictorBuffTimer and s.constrictorBuffTimer > 0 then
        s.constrictorBuffTimer = math.max(0, s.constrictorBuffTimer - dt)
    end
    if s.firePepperTimer and s.firePepperTimer > 0 then
        s.firePepperTimer = math.max(0, s.firePepperTimer - dt)
    end
    if s.slimeSlowTimer and s.slimeSlowTimer > 0 then
        s.slimeSlowTimer = math.max(0, s.slimeSlowTimer - dt)
    end
    if s.bumpGhostTimer and s.bumpGhostTimer > 0 then
        s.bumpGhostTimer = math.max(0, s.bumpGhostTimer - dt)
    end
    if s.fireTrail then
        for i = #s.fireTrail, 1, -1 do
            local ft = s.fireTrail[i]
            ft.timer = ft.timer - dt
            if ft.timer <= 0 then
                table.remove(s.fireTrail, i)
            end
        end
    end
    if s.decoys then
        for i = #s.decoys, 1, -1 do
            local dec = s.decoys[i]
            dec.timer = dec.timer - dt
            if dec.timer <= 0 then
                table.remove(s.decoys, i)
            end
        end
    end
end

function core.setDeathCause(reason)
    local okW, worldMod = pcall(require, "world.world")
    local roomNum = 1
    if okW and worldMod then
        roomNum = worldMod.sala or (type(worldMod.getCurrentRoom) == "function" and worldMod.getCurrentRoom() and worldMod.getCurrentRoom().id) or 1
    end
    if type(roomNum) ~= "number" then roomNum = tonumber(roomNum) or 1 end
    local causeStr = string.format("CAUSA: %s en Sala %d", reason or "Desconocida", roomNum)
    world.set("deathCause", causeStr)
end

function core.setHazardDeath(hazardObs)
    local hazardName = (hazardObs and hazardObs.type == "lava" and "Fisura de Magma ardiente")
        or (hazardObs and hazardObs.type == "pressure_spike" and "Trampa de Pinchos de Presión")
        or "Peligro ambiental letal"
    core.setDeathCause(hazardName)
end

function core.setAttackDeath(ao)
    local atkName = (ao and ao.type == "laser" and "Rayo Láser Perimetral del Boss")
        or (ao and ao.type == "radial_pulse" and "Onda Expansiva del Boss")
        or (ao and ao.type == "projectile" and "Proyectil Balístico del Boss")
        or "Ataque letal del Boss"
    core.setDeathCause(atkName)
end

function core.setEnemyDeath(e)
    local enemyName = "Emboscada letal de Cazador"
    if e and e.type == "patroller" then
        enemyName = "Impacto frontal letal contra Dron Patrullero"
    elseif e and e.type == "spawner" then
        enemyName = "Impacto contra Generador de Espinas"
    elseif e and (e.type == "miniboss" or e.name) then
        enemyName = "Impacto letal contra " .. tostring(e.name or "Mini-Jefe")
    end
    core.setDeathCause(enemyName)
end

return core

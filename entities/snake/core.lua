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

return core

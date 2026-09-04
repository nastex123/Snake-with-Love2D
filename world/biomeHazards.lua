local BiomeHazards = {}
local constants = require("constants")

BiomeHazards.HAZARD_TYPES = {
    LAVA = "lava",
    ICE = "ice",
    SLIME = "slime",
    PRESSURE_SPIKE = "pressure_spike",
    TRAP = "trap"
}

BiomeHazards.DEFAULTS = {
    lava = {
        type = "lava",
        destructible = false,
        hp = 999,
        maxHp = 999,
        hazard = true,
        damage = 2,
        slowFactor = 1.0,
        slip = 0,
        color = {1.0, 0.40, 0.10},
        state = "cooldown",
        timer = 2.5
    },
    ice = {
        type = "ice",
        destructible = true,
        hp = 1,
        maxHp = 1,
        hazard = true,
        damage = 0,
        slowFactor = 1.0,
        slip = 1,
        color = {0.30, 0.85, 1.0}
    },
    slime = {
        type = "slime",
        destructible = true,
        hp = 1,
        maxHp = 1,
        hazard = true,
        damage = 0,
        slowFactor = 0.5,
        slip = 0,
        color = {0.35, 0.90, 0.25}
    },
    pressure_spike = {
        type = "pressure_spike",
        destructible = false,
        hp = 999,
        maxHp = 999,
        hazard = true,
        damage = 1,
        slowFactor = 1.0,
        slip = 0,
        color = {0.60, 0.62, 0.68},
        state = "idle",
        timer = 2.0
    }
}

function BiomeHazards.isHazardType(t)
    return t == "lava" or t == "ice" or t == "slime" or t == "pressure_spike" or t == "trap"
end

function BiomeHazards.isLethal(obs)
    if not obs or not obs.hazard then return false end
    if obs.type == "lava" then return obs.state == "active"
    elseif obs.type == "pressure_spike" then return obs.state == "extended"
    elseif obs.type == "trap" then return true
    end
    return false
end

function BiomeHazards.getTileModifier(obs)
    if not obs then return 0, 1.0 end
    return (obs.slip or 0), (obs.slowFactor or 1.0)
end

function BiomeHazards.triggerPressureSpike(obs)
    if obs and obs.type == "pressure_spike" and obs.state == "idle" then
        obs.state = "warning"
        obs.timer = constants.PRESSURE_SPIKE_TRIGGER_DELAY or 0.5
        return true
    end
    return false
end

function BiomeHazards.update(dt, obstaclesPos)
    local delta = dt or 0.016
    if not obstaclesPos then return end
    for i = 1, #obstaclesPos do
        local obs = obstaclesPos[i]
        if obs.type == "lava" then
            obs.timer = (obs.timer or 2.5) - delta
            if obs.timer <= 0 then
                if obs.state == "cooldown" then
                    obs.state = "warning"
                    obs.timer = constants.MAGMA_WARNING_TIME or 1.2
                elseif obs.state == "warning" then
                    obs.state = "active"
                    obs.timer = constants.MAGMA_ACTIVE_TIME or 1.5
                else
                    obs.state = "cooldown"
                    obs.timer = constants.MAGMA_COOLDOWN_TIME or 2.5
                end
            end
        elseif obs.type == "pressure_spike" then
            obs.timer = (obs.timer or 2.0) - delta
            if obs.timer <= 0 then
                if obs.state == "idle" then
                    obs.state = "warning"
                    obs.timer = constants.PRESSURE_SPIKE_TRIGGER_DELAY or 0.5
                elseif obs.state == "warning" then
                    obs.state = "extended"
                    obs.timer = constants.PRESSURE_SPIKE_ACTIVE_DURATION or 1.2
                elseif obs.state == "extended" then
                    obs.state = "retracting"
                    obs.timer = 0.4
                else
                    obs.state = "idle"
                    obs.timer = 2.5
                end
            end
        end
    end
end

function BiomeHazards.draw(obs, px, py, size, time, i)
    local obsType = obs.type or "wall"
    if obsType == "lava" then
        local st = obs.state or "cooldown"
        if st == "warning" then
            local warnPulse = 0.5 + math.sin(time * 12.0) * 0.5
            love.graphics.setColor(0.30, 0.15, 0.10, 0.95)
            love.graphics.rectangle("fill", px, py, size, size, 4, 4)
            love.graphics.setColor(1.0, 0.55, 0.10, 0.5 + warnPulse * 0.5)
            love.graphics.rectangle("fill", px + 3, py + size / 2 - 2, size - 6, 4, 2, 2)
            love.graphics.rectangle("fill", px + size / 2 - 2, py + 3, 4, size - 6, 2, 2)
            love.graphics.setColor(1.0, 0.80, 0.20, warnPulse)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", px, py, size, size, 4, 4)
        elseif st == "active" then
            local heat = math.sin(time * 6.0 + i * 2.0) * 0.15
            love.graphics.setColor(0.60, 0.22, 0.18, 0.90)
            love.graphics.rectangle("fill", px, py, size, size, 4, 4)
            love.graphics.setColor(1.0, 0.90 + heat * 0.5, 0.25, 0.95)
            local coreSize = size * 0.65
            local coreOff = (size - coreSize) / 2
            love.graphics.rectangle("fill", px + coreOff, py + coreOff, coreSize, coreSize, 3, 3)
            love.graphics.setColor(1.0, 0.30, 0.05, 1.0)
            love.graphics.setLineWidth(2.0)
            love.graphics.rectangle("line", px, py, size, size, 4, 4)
        else
            love.graphics.setColor(0.22, 0.18, 0.18, 0.90)
            love.graphics.rectangle("fill", px, py, size, size, 4, 4)
            love.graphics.setColor(0.45, 0.20, 0.12, 0.60)
            love.graphics.rectangle("line", px, py, size, size, 4, 4)
        end
        return true
    elseif obsType == "pressure_spike" then
        local st = obs.state or "idle"
        love.graphics.setColor(0.35, 0.38, 0.44, 1.0)
        love.graphics.rectangle("fill", px, py, size, size, 3, 3)
        love.graphics.setColor(0.20, 0.22, 0.26, 1.0)
        love.graphics.rectangle("line", px, py, size, size, 3, 3)
        if st == "warning" then
            local warnP = 0.5 + math.sin(time * 14.0) * 0.5
            love.graphics.setColor(1.0, 0.20, 0.20, warnP)
            love.graphics.setLineWidth(1.8)
            love.graphics.rectangle("line", px + 1, py + 1, size - 2, size - 2, 2, 2)
            love.graphics.setColor(0.9, 0.3, 0.3, 0.8)
            love.graphics.circle("fill", px + size * 0.3, py + size * 0.3, 2.5)
            love.graphics.circle("fill", px + size * 0.7, py + size * 0.3, 2.5)
            love.graphics.circle("fill", px + size * 0.3, py + size * 0.7, 2.5)
            love.graphics.circle("fill", px + size * 0.7, py + size * 0.7, 2.5)
        elseif st == "extended" then
            love.graphics.setColor(0.95, 0.98, 1.0, 1.0)
            local spW = size * 0.25
            for sy = 0, 1 do
                for sx = 0, 1 do
                    local spX = px + 2 + sx * (size - spW - 4)
                    local spY = py + 2 + sy * (size - spW - 4)
                    love.graphics.polygon("fill", spX + spW / 2, spY, spX + spW, spY + spW, spX, spY + spW)
                end
            end
            love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", px, py, size, size, 3, 3)
        elseif st == "retracting" then
            love.graphics.setColor(0.6, 0.65, 0.70, 0.7)
            love.graphics.circle("fill", px + size / 2, py + size / 2, size * 0.2)
        else
            love.graphics.setColor(0.0, 0.85, 1.0, 0.6)
            love.graphics.rectangle("fill", px + 2, py + 2, 2, 2)
            love.graphics.rectangle("fill", px + size - 4, py + 2, 2, 2)
            love.graphics.rectangle("fill", px + 2, py + size - 4, 2, 2)
            love.graphics.rectangle("fill", px + size - 4, py + size - 4, 2, 2)
        end
        return true
    elseif obsType == "ice" then
        love.graphics.setColor(0.30, 0.85, 1.0, 0.85)
        love.graphics.rectangle("fill", px, py, size, size, 3, 3)
        love.graphics.setColor(0.9, 0.98, 1.0, 0.7)
        local midX = px + size / 2
        local midY = py + size / 2
        local glint = size * 0.28
        love.graphics.polygon("fill", midX, py + 2, px + size - 2, midY, midX, py + size - 2, px + 2, midY)
        love.graphics.setColor(0.7, 0.95, 1.0, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", px, py, size, size, 3, 3)
        return true
    elseif obsType == "slime" then
        local gooPulse = math.sin(time * 3.0 + i * 1.7) * 0.08
        love.graphics.setColor(0.35 * (0.8 + gooPulse), 0.90, 0.25 * (0.8 + gooPulse), 0.9)
        love.graphics.rectangle("fill", px, py, size, size, 6, 6)
        local bSize = size * 0.35
        love.graphics.setColor(0.7, 1.0, 0.4, 0.8)
        love.graphics.circle("fill", px + size * 0.35, py + size * 0.35, bSize * 0.5)
        love.graphics.setColor(0.2, 0.65, 0.15, 0.9)
        love.graphics.setLineWidth(1.2)
        love.graphics.rectangle("line", px, py, size, size, 6, 6)
        return true
    end
    return false
end

function BiomeHazards.getSpawnForBiome(biomeStr, rnd)
    rnd = rnd or 0.5
    if biomeStr == "hielo" then
        return (rnd < 0.70) and "ice" or "wall"
    elseif biomeStr == "volcan" then
        return (rnd < 0.65) and "lava" or "wall"
    elseif biomeStr == "colmena" then
        return (rnd < 0.65) and "slime" or "wall"
    elseif biomeStr == "vacio" then
        return (rnd < 0.50) and "pressure_spike" or ((rnd < 0.75) and "trap" or "wall")
    else
        return (rnd < 0.20) and "trap" or "wall"
    end
end

function BiomeHazards.isHazardAt(obstaclesPos, x, y)
    if not obstaclesPos then return false, nil, nil end
    for _, obs in ipairs(obstaclesPos) do
        if obs.x == x and obs.y == y and obs.hazard then
            return true, obs.type, obs
        end
    end
    return false, nil, nil
end

return BiomeHazards

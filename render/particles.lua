local particles = {}
local constants = require("constants")

local texture

function particles.getTexture()
    return texture
end

function particles.release()
    if texture and texture.release then
        pcall(function() texture:release() end)
    end
    texture = nil
end

function particles.load()
    particles.release()
    local newImageData = (love.image and love.image.newImageData) or (love.graphics and love.graphics.newImageData)
    local imgData = newImageData and newImageData(4, 4)
    if imgData then
        for y = 0, 3 do
            for x = 0, 3 do
                imgData:setPixel(x, y, 1, 1, 1, 1)
            end
        end
        texture = love.graphics.newImage(imgData)
        if texture then
            texture:setFilter("nearest", "nearest")
        end
        if imgData.release then
            pcall(function() imgData:release() end)
        end
    end
end

local function ensureTexture()
    if not texture then
        particles.load()
    end
    return texture
end

function particles.comer(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, constants.PARTICLE_COMER_COUNT)
    ps:setEmissionRate(0)
    ps:setSpeed(30, 80)
    ps:setLinearAcceleration(0, 40)
    ps:setColors(0.2, 0.9, 0.3, 1,  1.0, 0.84, 0.0, 0)
    ps:setSizes(1, 0.2)
    ps:setParticleLifetime(0.3, 0.6)
    ps:setPosition(x, y)
    ps:emit(constants.PARTICLE_COMER_COUNT)
    return ps
end

function particles.muerte(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, constants.PARTICLE_MUERTE_COUNT)
    ps:setEmissionRate(0)
    ps:setSpeed(40, 120)
    ps:setLinearAcceleration(0, 60)
    ps:setColors(1.0, 0.2, 0.2, 1,  0.0, 0.85, 1.0, 0)
    ps:setSizes(1.5, 0.3)
    ps:setParticleLifetime(0.4, 0.8)
    ps:setPosition(x, y)
    ps:emit(constants.PARTICLE_MUERTE_COUNT)
    return ps
end

function particles.highScore(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 30)
    ps:setEmissionRate(0)
    ps:setSpeed(60, 140)
    ps:setLinearAcceleration(0, -50)
    ps:setColors(1.0, 0.84, 0.0, 1,  1, 1, 1, 0)
    ps:setSizes(2, 0.3)
    ps:setParticleLifetime(0.5, 1.0)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(30)
    return ps
end

function particles.activacion(x, y, r, g, b)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 15)
    ps:setEmissionRate(0)
    ps:setSpeed(30, 70)
    ps:setLinearAcceleration(0, -20)
    ps:setColors(r, g, b, 1,  r, g, b, 0)
    ps:setSizes(1, 0.2)
    ps:setParticleLifetime(0.3, 0.6)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(15)
    return ps
end

function particles.enemyKill(x, y, r, g, b)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, constants.PARTICLE_ENEMY_COUNT)
    ps:setEmissionRate(0)
    ps:setSpeed(20, 60)
    ps:setLinearAcceleration(0, -30)
    ps:setColors(r, g, b, 1,  r, g, b, 0)
    ps:setSizes(1, 0.2)
    ps:setParticleLifetime(0.3, 0.6)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(constants.PARTICLE_ENEMY_COUNT)
    return ps
end

function particles.bossFoodTick(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 6)
    ps:setEmissionRate(0)
    ps:setSpeed(20, 50)
    ps:setLinearAcceleration(0, -20)
    ps:setColors(0.2, 0.9, 0.3, 1,  1.0, 0.84, 0.0, 0)
    ps:setSizes(0.8, 0.2)
    ps:setParticleLifetime(0.2, 0.4)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(6)
    return ps
end

function particles.bossDeath(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 30)
    ps:setEmissionRate(0)
    ps:setSpeed(50, 120)
    ps:setLinearAcceleration(0, -40)
    ps:setColors(1.0, 0.2, 0.2, 1,  1.0, 0.84, 0.0, 0,  0.0, 0.85, 1.0, 0)
    ps:setSizes(2, 0.3)
    ps:setParticleLifetime(0.4, 0.8)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(30)
    return ps
end

function particles.bombExplosion(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 40)
    ps:setEmissionRate(0)
    ps:setSpeed(80, 200)
    ps:setLinearAcceleration(0, 40)
    ps:setColors(1.0, 0.4, 0.1, 1,  1.0, 0.8, 0.0, 0.8,  0.8, 0.1, 0.1, 0)
    ps:setSizes(2.0, 0.4)
    ps:setParticleLifetime(0.4, 0.8)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(40)
    return ps
end

function particles.constrictorBurst(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 45)
    ps:setEmissionRate(0)
    ps:setSpeed(60, 160)
    ps:setLinearAcceleration(0, -30)
    ps:setColors(0.0, 0.94, 1.0, 1,  1.0, 0.84, 0.0, 1,  1.0, 1.0, 1.0, 0)
    ps:setSizes(1.8, 0.2)
    ps:setParticleLifetime(0.5, 0.9)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(45)
    return ps
end

function particles.streakDiamond(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 35)
    ps:setEmissionRate(0)
    ps:setSpeed(50, 130)
    ps:setLinearAcceleration(0, -40)
    ps:setColors(0.0, 0.94, 1.0, 1,  0.8, 0.3, 1.0, 0.8,  1.0, 1.0, 1.0, 0)
    ps:setSizes(1.5, 0.3)
    ps:setParticleLifetime(0.5, 1.0)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(35)
    return ps
end

function particles.autotomyDecoy(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 25)
    ps:setEmissionRate(0)
    ps:setSpeed(20, 60)
    ps:setLinearAcceleration(0, -20)
    ps:setColors(0.6, 0.2, 0.9, 0.9,  0.2, 0.8, 0.9, 0.6,  1.0, 1.0, 1.0, 0)
    ps:setSizes(1.6, 0.3)
    ps:setParticleLifetime(0.4, 0.8)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(25)
    return ps
end

function particles.fireTrail(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 16)
    ps:setEmissionRate(0)
    ps:setSpeed(15, 45)
    ps:setLinearAcceleration(0, -30)
    ps:setColors(1.0, 0.4, 0.1, 1,  1.0, 0.8, 0.0, 0.7,  0.8, 0.1, 0.1, 0)
    ps:setSizes(1.4, 0.2)
    ps:setParticleLifetime(0.3, 0.6)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(16)
    return ps
end

function particles.frostFreeze(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 40)
    ps:setEmissionRate(0)
    ps:setSpeed(40, 110)
    ps:setLinearAcceleration(0, 0)
    ps:setColors(0.3, 0.85, 1.0, 1,  0.7, 0.95, 1.0, 0.8,  1.0, 1.0, 1.0, 0)
    ps:setSizes(1.8, 0.3)
    ps:setParticleLifetime(0.5, 1.0)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(40)
    return ps
end

function particles.tailSnapShockwave(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 30)
    ps:setEmissionRate(0)
    ps:setSpeed(60, 150)
    ps:setLinearAcceleration(0, 0)
    ps:setColors(1.0, 0.9, 0.4, 1,  0.2, 0.9, 1.0, 0.7,  1.0, 1.0, 1.0, 0)
    ps:setSizes(1.6, 0.2)
    ps:setParticleLifetime(0.3, 0.6)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(30)
    return ps
end

function particles.slimmingBurst(x, y)
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 28)
    ps:setEmissionRate(0)
    ps:setSpeed(30, 80)
    ps:setLinearAcceleration(0, 40)
    ps:setColors(0.3, 0.9, 0.4, 1,  0.1, 0.7, 0.2, 0.7,  1.0, 1.0, 1.0, 0)
    ps:setSizes(1.5, 0.3)
    ps:setParticleLifetime(0.4, 0.7)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(28)
    return ps
end

function particles.menuFondo()
    local tex = ensureTexture()
    local ps = love.graphics.newParticleSystem(tex, 80)
    ps:setEmissionRate(4)
    ps:setSpeed(8, 25)
    ps:setLinearAcceleration(-2, -8)
    ps:setColors(1, 1, 1, 0.4,  0, 0.85, 1, 0.2,  1, 0.84, 0, 0.1,  1, 1, 1, 0)
    ps:setSizes(0.8, 0.2)
    ps:setParticleLifetime(5, 10)
    ps:setPosition(love.graphics.getWidth() / 2, love.graphics.getHeight() + 10)
    ps:setSpread(3.14)
    ps:start()
    return ps
end

return particles

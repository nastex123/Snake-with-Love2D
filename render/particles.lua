local particles = {}
local constants = require("constants")

local texture

function particles.load()
    local imgData = love.image.newImageData(4, 4)
    for y = 0, 3 do
        for x = 0, 3 do
            imgData:setPixel(x, y, 1, 1, 1, 1)
        end
    end
    texture = love.graphics.newImage(imgData)
    texture:setFilter("nearest", "nearest")
end

function particles.comer(x, y)
    local ps = love.graphics.newParticleSystem(texture, constants.PARTICLE_COMER_COUNT)
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
    local ps = love.graphics.newParticleSystem(texture, constants.PARTICLE_MUERTE_COUNT)
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

function particles.compra(x, y)
    local ps = love.graphics.newParticleSystem(texture, 20)
    ps:setEmissionRate(0)
    ps:setSpeed(40, 90)
    ps:setLinearAcceleration(0, -30)
    ps:setColors(1.0, 0.84, 0.0, 1,  0.0, 0.85, 1.0, 0)
    ps:setSizes(1, 0.3)
    ps:setParticleLifetime(0.3, 0.6)
    ps:setPosition(x, y)
    ps:setSpread(6.28)
    ps:emit(20)
    return ps
end

function particles.highScore(x, y)
    local ps = love.graphics.newParticleSystem(texture, 30)
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
    local ps = love.graphics.newParticleSystem(texture, 15)
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
    local ps = love.graphics.newParticleSystem(texture, constants.PARTICLE_ENEMY_COUNT)
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
    local ps = love.graphics.newParticleSystem(texture, 6)
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
    local ps = love.graphics.newParticleSystem(texture, 30)
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

function particles.menuFondo()
    local ps = love.graphics.newParticleSystem(texture, 80)
    ps:setEmissionRate(4)
    ps:setSpeed(8, 25)
    ps:setLinearAcceleration(-2, -8)
    local t = love.timer.getTime()
    ps:setColors(1, 1, 1, 0.4,  0, 0.85, 1, 0.2,  1, 0.84, 0, 0.1,  1, 1, 1, 0)
    ps:setSizes(0.8, 0.2)
    ps:setParticleLifetime(5, 10)
    ps:setPosition(love.graphics.getWidth() / 2, love.graphics.getHeight() + 10)
    ps:setSpread(3.14)
    ps:start()
    return ps
end

function particles.fondo()
    local ps = love.graphics.newParticleSystem(texture, 60)
    ps:setEmissionRate(3)
    ps:setSpeed(5, 15)
    ps:setLinearAcceleration(0, 0)
    ps:setColors(0.4, 0.5, 0.8, 0.3,  0.2, 0.3, 0.6, 0)
    ps:setSizes(1, 0.3)
    ps:setParticleLifetime(4, 8)
    ps:setPosition(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    ps:setSpread(6.28)
    ps:start()
    return ps
end

return particles

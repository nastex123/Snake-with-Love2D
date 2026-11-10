-- ui/gearWaveHud.lua - Indicador de oleada con estetica de engranaje (Gear Wave HUD)
local GearWaveHUD = {}
GearWaveHUD.__index = GearWaveHUD

local M = {}

local instance = nil
local instanceRadius = nil

function GearWaveHUD.new(x, y, radius)
    local self = setmetatable({}, GearWaveHUD)
    self.x = x or 0
    self.y = y or 0
    self.radius = radius or 34
    self.toothDepth = math.max(2, math.floor(self.radius * 0.2))
    self.innerHoleRadius = math.max(4, math.floor(self.radius * 0.7))
    self.teethCount = 12
    self.rotation = 0
    self.rotationSpeed = 0.5
    self.vertices = self:_generateGearVertices()
    return self
end

function GearWaveHUD:_generateGearVertices()
    local verts = {}
    local step = (math.pi * 2) / self.teethCount

    for i = 0, self.teethCount - 1 do
        local angleStart = i * step
        local a1 = angleStart
        local a2 = angleStart + step * 0.3
        local a3 = angleStart + step * 0.7
        local a4 = angleStart + step

        table.insert(verts, math.cos(a1) * self.radius)
        table.insert(verts, math.sin(a1) * self.radius)

        table.insert(verts, math.cos(a2) * (self.radius + self.toothDepth))
        table.insert(verts, math.sin(a2) * (self.radius + self.toothDepth))

        table.insert(verts, math.cos(a3) * (self.radius + self.toothDepth))
        table.insert(verts, math.sin(a3) * (self.radius + self.toothDepth))

        table.insert(verts, math.cos(a4) * self.radius)
        table.insert(verts, math.sin(a4) * self.radius)
    end
    return verts
end

function GearWaveHUD:update(dt, isAdvancing)
    local speedMult = isAdvancing and 3.0 or 1.0
    self.rotation = (self.rotation + self.rotationSpeed * speedMult * dt) % (math.pi * 2)
end

function GearWaveHUD:draw(currentWave, totalWaves, fontSmall, fontBig, progress)
    progress = progress or 1
    progress = math.max(0, math.min(1, progress))

    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    -- Arco de tiempo restante (color del engranaje, barrido circular)
    local arcR = self.radius + math.max(2, math.floor(self.radius * 0.25))
    local startAngle = -math.pi / 2
    local endAngle = startAngle + math.pi * 2 * progress
    -- color: ambar -> rojo segun progreso
    local r = 0.90 + (1 - progress) * 0.10
    local g = 0.65 - (1 - progress) * 0.45
    local b = 0.18 - (1 - progress) * 0.05
    love.graphics.setLineWidth(math.max(2, math.floor(self.radius * 0.18)))
    love.graphics.setColor(r, g, b, 0.95)
    if progress > 0.001 then
        love.graphics.arc("line", "open", 0, 0, arcR, startAngle, endAngle, 48)
    end
    -- pista de fondo del arco
    love.graphics.setColor(0.15, 0.10, 0.05, 0.5)
    love.graphics.arc("line", "open", 0, 0, arcR, startAngle + math.pi * 2 * progress, startAngle + math.pi * 2, 48)

    love.graphics.push()
    love.graphics.rotate(self.rotation)

    love.graphics.setColor(0.12, 0.08, 0.02, 0.8)
    love.graphics.polygon("fill", self.vertices)

    love.graphics.setColor(0.85, 0.55, 0.12, 1.0)
    love.graphics.polygon("line", self.vertices)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.95, 0.70, 0.20, 0.6)
    love.graphics.circle("line", 0, 0, self.radius - 2)

    love.graphics.pop()

    love.graphics.setColor(0.05, 0.05, 0.07, 0.95)
    love.graphics.circle("fill", 0, 0, self.innerHoleRadius)

    love.graphics.setColor(0.95, 0.65, 0.15, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, self.innerHoleRadius)

    love.graphics.setColor(0.4, 0.25, 0.05, 0.8)
    love.graphics.circle("line", 0, 0, self.innerHoleRadius - 3)

    local prevFont = love.graphics.getFont()

    if fontSmall then love.graphics.setFont(fontSmall) end
    local label = "OLEADA"
    local lw = fontSmall and fontSmall:getWidth(label) or 20
    love.graphics.setColor(0.95, 0.75, 0.25, 0.9)
    love.graphics.print(label, -lw / 2, -14)

    local countStr = string.format("%d/%d", currentWave or 1, totalWaves or 1)
    if fontBig then love.graphics.setFont(fontBig) end
    local cw = fontBig and fontBig:getWidth(countStr) or 16
    love.graphics.setColor(1.0, 0.95, 0.85, 1.0)
    love.graphics.print(countStr, -cw / 2, -2)

    if prevFont then love.graphics.setFont(prevFont) end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

function M.draw(x, y, radius, currentWave, totalWaves, s, fontSmall, fontBig, isAdvancing, dt, progress)
    if not instance or instanceRadius ~= radius then
        instance = GearWaveHUD.new(x, y, radius)
        instanceRadius = radius
    end
    instance.x = x
    instance.y = y
    instance.radius = radius
    -- regenerate vertices if radius changed
    if instance.toothDepth ~= math.max(2, math.floor(radius * 0.2)) then
        instance.toothDepth = math.max(2, math.floor(radius * 0.2))
        instance.innerHoleRadius = math.max(4, math.floor(radius * 0.7))
        instance.vertices = instance:_generateGearVertices()
    end
    if dt and dt > 0 then
        instance:update(dt, isAdvancing)
    end
    instance:draw(currentWave, totalWaves, fontSmall, fontBig, progress)
end

return M
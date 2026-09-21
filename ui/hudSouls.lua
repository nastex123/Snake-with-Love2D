-- ui/hudSouls.lua - Componente Soulsborne: Propuesta 13 (Maldición del Anillo / Dark Sign Ring)
-- Cabecera solemne de cripta, Eclipse Darksign animado con partículas Zero-GC y dock de piedra forjada
local hudSouls = {}

local constants = require("constants")
local Assets = require("core.assets")

-- ============================================================================
-- PALETA CROMATICA CANONICA ZERO-GC (Preasignada a nivel de módulo)
-- ============================================================================
local COLOR_EMBER            = {0.851, 0.420, 0.153}
local COLOR_EMBER_BRIGHT     = {0.976, 0.451, 0.086}
local COLOR_ASH              = {0.039, 0.035, 0.031, 0.94}
local COLOR_BONE             = {0.812, 0.780, 0.722}
local COLOR_BONE_DIM         = {0.550, 0.510, 0.420}
local COLOR_HOLLOW_BLOOD     = {0.431, 0.114, 0.094}
local COLOR_LORD_GOLD        = {0.761, 0.651, 0.286}
local COLOR_LORD_GOLD_BRIGHT = {0.984, 0.749, 0.141}
local COLOR_BRONZE           = {0.302, 0.239, 0.141}
local COLOR_BRONZE_LIGHT     = {0.451, 0.322, 0.133}
local COLOR_HP_BG            = {0.055, 0.047, 0.043, 0.95}
local COLOR_HP_RED           = {0.725, 0.110, 0.110}
local COLOR_HP_RESIDUAL      = {0.573, 0.251, 0.055}

-- ============================================================================
-- POOL ESTATICO DE PARTICULAS PROCEDURALES (Zero-GC, 40 particulas recicladas)
-- ============================================================================
local MAX_PARTICLES = 40
local particles = {}
for i = 1, MAX_PARTICLES do
    particles[i] = {
        active = false,
        x = 0, y = 0,
        vx = 0, vy = 0,
        life = 0,
        decay = 1,
        size = 2,
        isHollow = false
    }
end

local nextParticleIdx = 1
local spawnTimer = 0
local residualHpDisplay = 1.0

local function getCachedFont(fontSize)
    return Assets.getFont(constants.FONT_FILE, fontSize) or Assets.getFont(fontSize)
end

function hudSouls.update(dt, isHollow, comboCount)
    local comboFactor = math.max(0, comboCount or 0)
    spawnTimer = spawnTimer + dt

    local interval = isHollow and 0.08 or math.max(0.012, 0.055 / (1 + comboFactor * 0.45))
    if spawnTimer >= interval then
        spawnTimer = 0
        local p = particles[nextParticleIdx]
        nextParticleIdx = (nextParticleIdx % MAX_PARTICLES) + 1

        local angle = love.math.random() * math.pi * 2
        local dist = (22 + math.min(8, comboFactor * 1.5)) + (love.math.random() * 6 - 3)
        p.active = true
        p.x = math.cos(angle) * dist
        p.y = math.sin(angle) * dist
        p.vx = (love.math.random() - 0.5) * (14 + comboFactor * 5)
        p.comboLevel = comboFactor
        if isHollow then
            p.vy = -(love.math.random() * 18 + 10)
            p.life = 1.0
            p.decay = 0.85
            p.size = 3.5 + love.math.random() * 3.0
            p.isHollow = true
        else
            p.vy = -(love.math.random() * 45 + 30 + comboFactor * 16)
            p.life = 1.0
            p.decay = 1.1 + love.math.random() * 0.7
            p.size = 1.8 + love.math.random() * (1.6 + comboFactor * 0.35)
            p.isHollow = false
        end
    end

    for i = 1, MAX_PARTICLES do
        local p = particles[i]
        if p.active then
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - p.decay * dt
            if p.life <= 0 then
                p.active = false
            end
        end
    end
end

-- ============================================================================
-- WIDGET CENTRAL DEL ECLIPSE DARKSIGN (LA SEÑAL OSCURA)
-- ============================================================================
function hudSouls.drawDarksign(cx, cy, radius, comboCount, isHollow, s, time)
    love.graphics.push()
    love.graphics.translate(cx, cy)

    local comboFactor = math.max(0, comboCount or 0)

    -- Particulas activas del pool
    for i = 1, MAX_PARTICLES do
        local p = particles[i]
        if p.active then
            local alpha = math.max(0, math.min(1, p.life))
            local sz = p.size * (p.isHollow and (1.5 - p.life * 0.5) or p.life) * s
            if p.isHollow then
                love.graphics.setColor(0.12, 0.10, 0.10, alpha * 0.6)
            elseif p.comboLevel and p.comboLevel >= 3 and (i % 3 == 0) then
                love.graphics.setColor(1.0, 0.95, 0.7, alpha * 0.95)
            else
                love.graphics.setColor(COLOR_EMBER[1], COLOR_EMBER[2], COLOR_EMBER[3], alpha * 0.85)
            end
            love.graphics.circle("fill", p.x * s, p.y * s, sz)
        end
    end

    if not isHollow then
        -- Resplandor exterior de ascua viva escalando con el combo
        local glowIntensity = math.min(1.0, 0.3 + comboFactor * 0.16)
        local pulseSpeed = 6 + comboFactor * 2.5
        local pulse = math.sin(time * pulseSpeed) * (0.1 + comboFactor * 0.02) + 0.9

        local outerR = (radius + 10 + comboFactor * 4) * s
        love.graphics.setColor(COLOR_EMBER[1], COLOR_EMBER[2], COLOR_EMBER[3], 0.22 * glowIntensity * pulse)
        love.graphics.circle("fill", 0, 0, outerR)

        local midR = (radius + 5 + comboFactor * 2) * s
        love.graphics.setColor(COLOR_EMBER_BRIGHT[1], COLOR_EMBER_BRIGHT[2], COLOR_EMBER_BRIGHT[3], 0.35 * glowIntensity)
        love.graphics.circle("fill", 0, 0, midR)

        if comboFactor >= 2 then
            love.graphics.setColor(COLOR_LORD_GOLD_BRIGHT[1], COLOR_LORD_GOLD_BRIGHT[2], COLOR_LORD_GOLD_BRIGHT[3], 0.25 * glowIntensity * pulse)
            love.graphics.circle("fill", 0, 0, (radius + 2 + comboFactor) * s)
        end

        -- Anillo flameante con ondulaciones sinusoidales crecientes
        local animSpeed = 6.0 + comboFactor * 3.2
        local waveAmp = (1.2 + comboFactor * 0.55) * s
        local waveFreq = 4 + math.min(6, math.floor(comboFactor * 1.1))
        local ringThickness = math.min(6.5 * s, (3.5 + comboFactor * 0.5) * s)

        love.graphics.setColor(COLOR_EMBER[1], COLOR_EMBER[2], COLOR_EMBER[3], 0.95)
        love.graphics.setLineWidth(ringThickness)
        local segments = 32
        for i = 0, segments - 1 do
            local a1 = (i / segments) * math.pi * 2
            local a2 = ((i + 1) / segments) * math.pi * 2
            local w1 = math.sin(time * animSpeed + a1 * waveFreq) * waveAmp
            local w2 = math.sin(time * animSpeed + a2 * waveFreq) * waveAmp
            local r1 = radius * s + w1
            local r2 = radius * s + w2
            love.graphics.line(math.cos(a1) * r1, math.sin(a1) * r1, math.cos(a2) * r2, math.sin(a2) * r2)
        end

        -- Aro interior dorado incandescente
        love.graphics.setColor(COLOR_LORD_GOLD_BRIGHT[1], COLOR_LORD_GOLD_BRIGHT[2], COLOR_LORD_GOLD_BRIGHT[3], math.min(1.0, 0.85 + comboFactor * 0.05))
        love.graphics.setLineWidth((1.5 + math.min(1.5, comboFactor * 0.3)) * s)
        love.graphics.circle("line", 0, 0, (radius - 1) * s)
    else
        -- Estado Hueco: carbón negro frío y sangre marchita
        love.graphics.setColor(0.15, 0.15, 0.16, 0.95)
        love.graphics.setLineWidth(3.0 * s)
        love.graphics.circle("line", 0, 0, radius * s)

        love.graphics.setColor(COLOR_HOLLOW_BLOOD[1], COLOR_HOLLOW_BLOOD[2], COLOR_HOLLOW_BLOOD[3], 0.8)
        love.graphics.setLineWidth(1.0 * s)
        love.graphics.circle("line", 0, 0, (radius - 2) * s)
    end

    -- Núcleo negro de obsidiana puro (El Eclipse)
    love.graphics.setColor(COLOR_ASH[1], COLOR_ASH[2], COLOR_ASH[3], 1.0)
    love.graphics.circle("fill", 0, 0, (radius - 3) * s)

    -- Multiplicador de Combo en el núcleo
    local fontSmall = getCachedFont(math.max(6, math.floor(constants.FONT_SMALL * s)))
    love.graphics.setFont(fontSmall)
    local comboStr = isHollow and "x1" or ("x" .. (comboFactor + 1))
    local tw = fontSmall:getWidth(comboStr)
    local th = fontSmall:getHeight()

    if not isHollow then
        if comboFactor >= 4 then
            love.graphics.setColor(1.0, 0.95, 0.80, 0.98)
        elseif comboFactor >= 1 then
            love.graphics.setColor(COLOR_LORD_GOLD_BRIGHT[1], COLOR_LORD_GOLD_BRIGHT[2], COLOR_LORD_GOLD_BRIGHT[3], 0.98)
        else
            love.graphics.setColor(COLOR_BONE[1], COLOR_BONE[2], COLOR_BONE[3], 0.88)
        end
    else
        love.graphics.setColor(0.45, 0.45, 0.48, 0.9)
    end

    -- Micro-pulso tipográfico al encadenar combos
    local py = math.floor(-th / 2)
    if not isHollow and comboFactor >= 2 then
        py = py + math.floor(math.sin(time * 12) * math.min(1.5 * s, comboFactor * 0.4 * s))
    end
    love.graphics.print(comboStr, math.floor(-tw / 2), py)

    -- Leyenda inferior de la Señal Oscura
    local tagStr = isHollow and "HUECO MORTAL" or (comboFactor >= 3 and "FURIA OSCURA" or "SENAL OSCURA")
    local tagW = fontSmall:getWidth(tagStr)
    if not isHollow then
        if comboFactor >= 3 then
            love.graphics.setColor(COLOR_EMBER_BRIGHT[1], COLOR_EMBER_BRIGHT[2], COLOR_EMBER_BRIGHT[3], 0.95)
        else
            love.graphics.setColor(COLOR_EMBER[1], COLOR_EMBER[2], COLOR_EMBER[3], 0.88)
        end
    else
        love.graphics.setColor(COLOR_HOLLOW_BLOOD[1], COLOR_HOLLOW_BLOOD[2], COLOR_HOLLOW_BLOOD[3], 0.9)
    end
    love.graphics.print(tagStr, math.floor(-tagW / 2), math.floor(radius * s + 3 * s))

    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- CABECERA SUPERIOR SOULSBORNE (Piedra, Bronce, Relicario y Lord Souls)
-- ============================================================================
function hudSouls.drawTopBar(w, hh, s, font, etapa, sala, monedas, puntuacion, objetivoSala, isBoss)
    love.graphics.setColor(COLOR_ASH[1], COLOR_ASH[2], COLOR_ASH[3], COLOR_ASH[4])
    love.graphics.rectangle("fill", 0, 0, w, hh)

    -- Filete de bronce forjado
    love.graphics.setColor(COLOR_BRONZE[1], COLOR_BRONZE[2], COLOR_BRONZE[3], 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(0, hh, w, hh)
    love.graphics.setColor(COLOR_LORD_GOLD[1], COLOR_LORD_GOLD[2], COLOR_LORD_GOLD[3], 0.35)
    love.graphics.line(0, hh - 1.5, w, hh - 1.5)
    love.graphics.setLineWidth(1)

    local fontH = font:getHeight()
    local cy = math.floor((hh - fontH) / 2)
    local x = 12 * s

    -- Izquierda: Calabozo en Oro y Nivel en Hueso
    if etapa and sala then
        local worldMod = package.loaded["world.world"]
        local bData = worldMod and worldMod.getBiomeData and worldMod.getBiomeData()
        local bName = bData and bData.name and string.upper(bData.name) or "CATACUMBAS"

        love.graphics.setColor(COLOR_LORD_GOLD[1], COLOR_LORD_GOLD[2], COLOR_LORD_GOLD[3], 0.95)
        love.graphics.print(bName, x, cy)
        x = x + font:getWidth(bName) + 6 * s

        local levelStr = "// " .. etapa .. "-" .. sala
        love.graphics.setColor(COLOR_BONE[1], COLOR_BONE[2], COLOR_BONE[3], 0.8)
        love.graphics.print(levelStr, x, cy)
        x = x + font:getWidth(levelStr) + 14 * s
    end

    return x
end

-- ============================================================================
-- DOCK INFERIOR COMPLETO DE LA PROPUESTA 13 (HABILIDADES, DARKSIGN Y SALUD)
-- ============================================================================
function hudSouls.drawBottomDock(w, h, s, font, player, slotDisplay, comboCount, isHollow, time)
    local slotH = math.floor(26 * s)
    local btnW = math.floor(74 * s)
    local gap = math.floor(6 * s)
    local y = h - slotH - math.floor(6 * s)
    local fontH = font:getHeight()

    -- 1. HABILIDADES A LA IZQUIERDA EN PIEDRA DE CRIPTA
    local leftX = math.floor(10 * s)
    local function drawSoulsBtn(bx, key, name, cd, maxCd, canUse)
        love.graphics.setColor(0.06, 0.05, 0.05, 0.92)
        love.graphics.rectangle("fill", bx, y, btnW, slotH, 3 * s)

        local borderCol = canUse and COLOR_BRONZE_LIGHT or COLOR_BRONZE
        love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], 0.9)
        love.graphics.rectangle("line", bx, y, btnW, slotH, 3 * s)

        -- Remaches dorados
        love.graphics.setColor(COLOR_LORD_GOLD[1], COLOR_LORD_GOLD[2], COLOR_LORD_GOLD[3], 0.75)
        local rw = 2 * s
        love.graphics.rectangle("fill", bx, y, rw, rw)
        love.graphics.rectangle("fill", bx + btnW - rw, y, rw, rw)
        love.graphics.rectangle("fill", bx, y + slotH - rw, rw, rw)
        love.graphics.rectangle("fill", bx + btnW - rw, y + slotH - rw, rw, rw)

        if canUse then
            love.graphics.setColor(COLOR_EMBER[1], COLOR_EMBER[2], COLOR_EMBER[3], 0.95)
            love.graphics.print("[" .. key .. "] " .. name, bx + 4 * s, y + math.floor((slotH - fontH) / 2))
        else
            local frac = cd > 0 and (cd / maxCd) or 0
            if cd > 0 then
                love.graphics.setColor(COLOR_EMBER[1] * 0.4, COLOR_EMBER[2] * 0.4, COLOR_EMBER[3] * 0.4, 0.4)
                love.graphics.rectangle("fill", bx, y, btnW * (1 - frac), slotH, 3 * s)
            end
            love.graphics.setColor(COLOR_BONE_DIM[1], COLOR_BONE_DIM[2], COLOR_BONE_DIM[3], 0.75)
            local txt = cd > 0 and string.format("[%s] %.0fs", key, cd) or ("[" .. key .. "] " .. name)
            love.graphics.print(txt, bx + 4 * s, y + math.floor((slotH - fontH) / 2))
        end
    end

    if player then
        local qCd = player.autotomyCooldown or 0
        local qCan = (qCd <= 0 and player.body and #player.body >= 4)
        drawSoulsBtn(leftX, "Q", "COLA", qCd, constants.AUTOTOMY_COOLDOWN or 8.0, qCan)

        local rCd = player.reverseSlitherCooldown or 0
        local rCan = (rCd <= 0 and player.body and #player.body >= 2)
        drawSoulsBtn(leftX + btnW + gap, "R", "INVERT", rCd, constants.REVERSE_SLITHER_COOLDOWN or 10.0, rCan)
    end

    -- 2. EL ECLIPSE DARKSIGN CENTRAL (REACTIVO AL COMBO)
    local cx = math.floor(w / 2)
    local cy = y + math.floor(slotH / 2) - 4 * s
    hudSouls.drawDarksign(cx, cy, 22, comboCount, isHollow, s, time)

    -- 3. INTEGRIDAD DE CUERPO Y ARSENAL A LA DERECHA
    local rightW = math.floor(160 * s)
    local touchOffset = 0
    local rightX = w - rightW - touchOffset
    local ry = y

    love.graphics.setColor(COLOR_BONE_DIM[1], COLOR_BONE_DIM[2], COLOR_BONE_DIM[3], 0.85)
    local tagStr = "INTEGRIDAD"
    love.graphics.print(tagStr, rightX, ry - fontH - 2 * s)

    -- Chasis de vida
    local barW = rightW
    local barH = math.floor(9 * s)
    love.graphics.setColor(COLOR_HP_BG[1], COLOR_HP_BG[2], COLOR_HP_BG[3], COLOR_HP_BG[4])
    love.graphics.rectangle("fill", rightX, ry, barW, barH, 2 * s, 2 * s)
    love.graphics.setColor(COLOR_BRONZE[1], COLOR_BRONZE[2], COLOR_BRONZE[3], 0.9)
    love.graphics.rectangle("line", rightX, ry, barW, barH, 2 * s, 2 * s)

    local targetFrac = 0.85
    if player and player.body then
        local maxSegments = 16
        targetFrac = math.max(0.1, math.min(1.0, #player.body / maxSegments))
    end
    if isHollow then targetFrac = 0.1 end

    residualHpDisplay = residualHpDisplay + (targetFrac - residualHpDisplay) * 0.05

    -- Barra residual ámbar
    love.graphics.setColor(COLOR_HP_RESIDUAL[1], COLOR_HP_RESIDUAL[2], COLOR_HP_RESIDUAL[3], 0.8)
    love.graphics.rectangle("fill", rightX + 1, ry + 1, (barW - 2) * residualHpDisplay, barH - 2, 1, 1)

    -- Barra activa roja
    if isHollow then
        local p = math.sin(time * 12) * 0.3 + 0.7
        love.graphics.setColor(COLOR_HP_RED[1], COLOR_HP_RED[2], COLOR_HP_RED[3], p)
    else
        love.graphics.setColor(COLOR_HP_RED[1], COLOR_HP_RED[2], COLOR_HP_RED[3], 0.95)
    end
    love.graphics.rectangle("fill", rightX + 1, ry + 1, (barW - 2) * targetFrac, barH - 2, 1, 1)

    -- Slots de reliquias (1-3)
    local slotItemW = math.floor((barW - gap * 2) / 3)
    local slotItemY = ry + barH + 4 * s
    for i = 1, 3 do
        local sx = rightX + (i - 1) * (slotItemW + gap)
        love.graphics.setColor(0.08, 0.07, 0.06, 0.75)
        love.graphics.rectangle("fill", sx, slotItemY, slotItemW, 12 * s, 2 * s)
        love.graphics.setColor(COLOR_BRONZE[1], COLOR_BRONZE[2], COLOR_BRONZE[3], 0.7)
        love.graphics.rectangle("line", sx, slotItemY, slotItemW, 12 * s, 2 * s)

        local slot = slotDisplay and slotDisplay[i]
        if slot and slot.name then
            love.graphics.setColor(COLOR_LORD_GOLD_BRIGHT[1], COLOR_LORD_GOLD_BRIGHT[2], COLOR_LORD_GOLD_BRIGHT[3], 0.9)
            local itemStr = string.sub(slot.name, 1, 3)
            love.graphics.print(itemStr, sx + 2 * s, slotItemY + 1)
        else
            love.graphics.setColor(COLOR_BONE_DIM[1], COLOR_BONE_DIM[2], COLOR_BONE_DIM[3], 0.4)
            love.graphics.print(tostring(i), sx + 4 * s, slotItemY + 1)
        end
    end
end

return hudSouls

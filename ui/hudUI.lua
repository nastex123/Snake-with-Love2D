-- ui/hudUI.lua - HUD: grid, barra superior, slots y combo flash
local hud = {}
local constants = require("constants")

function hud.drawGrid(ui, anchoGrilla, altoGrilla, time, comboIntensity)
    local tam = constants.TAMANIO_BLOQUE
    local w = anchoGrilla * tam
    local h = altoGrilla * tam

    local worldMod = package.loaded["world.world"]
    local biome = worldMod and worldMod.getBiomeData and worldMod.getBiomeData()

    local baseC = (biome and biome.gridAccent) or constants.COLOR_ACCENT
    local hotC = constants.COLOR_GRID_HOT_A

    local r = baseC[1] + (hotC[1] - baseC[1]) * comboIntensity
    local g = baseC[2] + (hotC[2] - baseC[2]) * comboIntensity
    local b = baseC[3] + (hotC[3] - baseC[3]) * comboIntensity
    local alpha = 0.15 + comboIntensity * 0.35

    love.graphics.setLineWidth(1)

    -- lineas verticales
    for x = 0, anchoGrilla do
        local px = x * tam
        local wave = math.sin(time * constants.SHIMMER_SPEED + x * 0.5) * 0.02
        love.graphics.setColor(
            math.min(1, r + wave),
            math.min(1, g + wave * 0.5),
            math.min(1, b - wave * 0.3),
            alpha
        )
        love.graphics.line(px, 0, px, h)
    end

    -- lineas horizontales
    for y = 0, altoGrilla do
        local py = y * tam
        local wave = math.sin(time * constants.SHIMMER_SPEED + y * 0.3) * 0.02
        love.graphics.setColor(
            math.min(1, r + wave),
            math.min(1, g + wave * 0.5),
            math.min(1, b - wave * 0.3),
            alpha
        )
        love.graphics.line(0, py, w, py)
    end

    -- borde exterior
    love.graphics.setColor(r, g, b, math.min(0.5, alpha + 0.2))
    love.graphics.rectangle("line", 0, 0, w, h)

    -- Alerta perimetral para Santuario del Vacío (sin Wall-Wrap / caída mortal)
    if biome and biome.wallWrap == false then
        local warnP = 0.5 + math.sin(time * 8) * 0.4
        love.graphics.setColor(1.0, 0.2, 0.8, warnP * 0.85)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", -2, -2, w + 4, h + 4, 2, 2)
        love.graphics.setColor(1.0, 0.4, 0.2, warnP * 0.5)
        love.graphics.setLineWidth(1.0)
        love.graphics.rectangle("line", -4, -4, w + 8, h + 8, 4, 4)
        love.graphics.setLineWidth(1)
    end
end

local fontCache = {}

local function getCachedFont(fontSize)
    if not fontCache[fontSize] then
        local font
        local ok = pcall(function() font = love.graphics.newFont(constants.FONT_FILE, fontSize) end)
        if not ok or not font then
            font = love.graphics.newFont(fontSize)
        end
        fontCache[fontSize] = font
    end
    return fontCache[fontSize]
end

function hud.drawHUD(ui, puntuacion, highScore, monedas, shieldActive, magnetTimer, magnetDuration, baseSpeed, velocidadActual, comboCount, activeTimers, etapa, sala, objetivoSala, scale)
    local s = scale or (ui and ui.scale) or 1

    -- Fuente escalada para que el texto crezca con la barra (obtenida del cache)
    local fontSize = math.max(6, math.floor(constants.FONT_NORMAL * s))
    local font = getCachedFont(fontSize)
    love.graphics.setFont(font)

    local hh = constants.HUD_HEIGHT * s          -- alto total de la barra
    local fontH = font:getHeight()
    local cy = math.floor((hh - fontH) / 2)       -- centrado vertical del texto

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), hh)

    local x = 8 * s                               -- margen izquierdo

    -- Indicador de sala y bioma
    if etapa and sala then
        local worldMod = package.loaded["world.world"]
        local bData = worldMod and worldMod.getBiomeData and worldMod.getBiomeData()
        local bName = bData and bData.name and string.upper(bData.name) or "CATACUMBAS"
        local isBoss = sala == 5
        local roomText = etapa .. "-" .. sala
        if isBoss then
            love.graphics.setColor(1, 0.3, 0.5)
        else
            local acc = bData and bData.gridAccent or constants.COLOR_ACCENT
            love.graphics.setColor(acc[1], acc[2], acc[3])
        end
        love.graphics.print(roomText, x, cy)
        x = x + font:getWidth(roomText) + 8 * s

        love.graphics.setColor(0.5, 0.6, 0.7, 0.85)
        love.graphics.print(bName, x, cy)
        x = x + font:getWidth(bName) + 14 * s
    end

    love.graphics.setColor(1, 0.84, 0.0)
    love.graphics.print("$" .. monedas, x, cy)
    x = x + font:getWidth("$" .. monedas) + 14 * s

    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.print("" .. puntuacion, x, cy)
    x = x + font:getWidth("" .. puntuacion) + 14 * s

    local world = require("core.world")
    local streak = world.state and world.state.survivalStreak or 1.0
    if streak > 1.0 then
        local streakText = string.format("STREAK %.1fx", streak)
        local sPulse = math.sin(love.timer.getTime() * 8) * 0.2 + 0.8
        love.graphics.setColor(0.0, 0.94, 1.0, sPulse)
        love.graphics.print(streakText, x, cy)
        x = x + font:getWidth(streakText) + 14 * s
    end

    -- Barra de progreso hacia el objetivo de la sala
    if objetivoSala and objetivoSala > 0 and sala and sala < 5 then
        local barW = 50 * s
        local barH = 6 * s
        local barY2 = math.floor(hh / 2) - 3 * s
        local frac = math.min(1, puntuacion / objetivoSala)
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", x, barY2, barW, barH, 2 * s, 2 * s)
        love.graphics.setColor(frac, 1 - frac, 0)
        love.graphics.rectangle("fill", x, barY2, barW * frac, barH, 2 * s, 2 * s)
        x = x + barW + 8 * s
    end

    local barY = math.floor(hh / 2) - 3 * s

    if shieldActive then
        local pulse = math.sin(love.timer.getTime() * 6) * 0.3 + 0.7
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pulse)
        love.graphics.print("S", x, cy)
        x = x + font:getWidth("S") + 6 * s
    end

    if magnetTimer and magnetDuration and magnetTimer > 0 and magnetDuration > 0 then
        local frac = magnetTimer / magnetDuration
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("M", x, cy)
        x = x + font:getWidth("M") + 4 * s
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", x, barY, 30 * s, 6 * s, 2 * s, 2 * s)
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.rectangle("fill", x, barY, 30 * s * frac, 6 * s, 2 * s, 2 * s)
        x = x + 36 * s
    end

    if baseSpeed then
        local frac = (baseSpeed - constants.MIN_BASE_SPEED) / (constants.MAX_BASE_SPEED - constants.MIN_BASE_SPEED)
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", x, barY, 40 * s, 6 * s, 2 * s, 2 * s)
        love.graphics.setColor(frac, 1 - frac, 0)
        love.graphics.rectangle("fill", x, barY, 40 * s * (1 - frac), 6 * s, 2 * s, 2 * s)
        x = x + 46 * s
    end

    if comboCount and comboCount > 0 then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("x" .. (comboCount + 1), x, cy)
        x = x + font:getWidth("x" .. (comboCount + 1)) + 8 * s
    end

    if activeTimers then
        local labels = {
            ghost = "G", turbo = "T", slow = "S",
            doubler = "D", extraCoin = "C", star = "*"
        }
        local colors = {
            ghost = {0.6, 0.4, 1}, turbo = {0, 1, 0.5},
            slow = {0.5, 0.5, 1}, doubler = {1, 0.84, 0},
            extraCoin = {1, 0.84, 0}, star = {1, 0.5, 0}
        }
        for i, t in ipairs(activeTimers) do
            local label = labels[t.id]
            if label then
                local c = colors[t.id]
                love.graphics.setColor(c[1], c[2], c[3])
                love.graphics.print(label, x, cy)
                x = x + font:getWidth(label) + 2 * s
                love.graphics.setColor(0.25, 0.25, 0.25)
                love.graphics.rectangle("fill", x, barY, 20 * s, 6 * s, 2 * s, 2 * s)
                love.graphics.setColor(c[1], c[2], c[3])
                local dur = t.duration or constants.TURBO_DURATION or 10
                love.graphics.rectangle("fill", x, barY, 20 * s * math.min(1, t.remaining / dur), 6 * s, 2 * s, 2 * s)
                x = x + 26 * s
            end
        end
    end

    -- Restaurar fuente por defecto para el resto de la UI
    love.graphics.setFont(ui.fontNormal)
end

function hud.drawSlots(ui, slotDisplay)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local s = math.min(ui and ui.scale or 1.0, w / 520)
    local slotW = math.floor(88 * s)
    local slotH = math.floor(24 * s)
    local gap = math.floor(5 * s)
    local totalW = slotW * 5 + gap * 4
    local startX = math.floor((w - totalW) / 2)
    local y = h - slotH - math.floor(6 * s)

    local fontSize = math.max(6, math.floor(constants.FONT_SMALL * s))
    local font = getCachedFont(fontSize)
    love.graphics.setFont(font)
    local fontH = font:getHeight()

    local world = require("core.world")
    local player = world.state and world.state.player

    -- Slot [Q] Autotomia
    if player then
        local qX = startX
        local cd = player.autotomyCooldown or 0
        local maxCd = constants.AUTOTOMY_COOLDOWN or 8.0
        local canUse = (cd <= 0 and player.body and #player.body >= 4)

        if canUse then
            local pulse = math.sin(love.timer.getTime() * 6) * 0.2 + 0.8
            love.graphics.setColor(0.18, 0.10, 0.30, 0.85)
            love.graphics.rectangle("fill", qX, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.8, 0.3, 1.0, pulse)
            love.graphics.rectangle("line", qX, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.8, 0.4, 1.0)
            love.graphics.print("[Q]", qX + 3 * s, y + (slotH - fontH) / 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("COLA", qX + 22 * s, y + (slotH - fontH) / 2)
        else
            local cdFrac = cd > 0 and (cd / maxCd) or 0
            love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
            love.graphics.rectangle("fill", qX, y, slotW, slotH, 3 * s)
            if cd > 0 then
                love.graphics.setColor(0.5, 0.2, 0.7, 0.45)
                love.graphics.rectangle("fill", qX, y, slotW * (1 - cdFrac), slotH, 3 * s)
            end
            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
            love.graphics.rectangle("line", qX, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
            local txt = cd > 0 and string.format("[Q] %.0fs", cd) or "[Q] COLA"
            love.graphics.print(txt, qX + 3 * s, y + (slotH - fontH) / 2)
        end

        -- Slot [R] Inversion
        local rX = startX + (slotW + gap)
        local rCd = player.reverseSlitherCooldown or 0
        local rMaxCd = constants.REVERSE_SLITHER_COOLDOWN or 10.0
        local rCanUse = (rCd <= 0 and player.body and #player.body >= 2)

        if rCanUse then
            local pulse = math.sin(love.timer.getTime() * 6) * 0.2 + 0.8
            love.graphics.setColor(0.08, 0.18, 0.25, 0.85)
            love.graphics.rectangle("fill", rX, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.0, 0.94, 0.8, pulse)
            love.graphics.rectangle("line", rX, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.0, 0.94, 0.8)
            love.graphics.print("[R]", rX + 3 * s, y + (slotH - fontH) / 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("INVERT", rX + 22 * s, y + (slotH - fontH) / 2)
        else
            local rFrac = rCd > 0 and (rCd / rMaxCd) or 0
            love.graphics.setColor(0.1, 0.15, 0.15, 0.5)
            love.graphics.rectangle("fill", rX, y, slotW, slotH, 3 * s)
            if rCd > 0 then
                love.graphics.setColor(0.1, 0.6, 0.6, 0.45)
                love.graphics.rectangle("fill", rX, y, slotW * (1 - rFrac), slotH, 3 * s)
            end
            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
            love.graphics.rectangle("line", rX, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
            local txt = rCd > 0 and string.format("[R] %.0fs", rCd) or "[R] INVERT"
            love.graphics.print(txt, rX + 3 * s, y + (slotH - fontH) / 2)
        end
    end

    -- 3 Slots de items (indices 1..3)
    for i = 1, 3 do
        local x = startX + (i + 1) * (slotW + gap)
        local slot = slotDisplay[i]

        if slot then
            love.graphics.setColor(0.12, 0.12, 0.22, 0.85)
            love.graphics.rectangle("fill", x, y, slotW, slotH, 3 * s)
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
            love.graphics.rectangle("line", x, y, slotW, slotH, 3 * s)
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.print(i .. ".", x + 3 * s, y + (slotH - fontH) / 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(slot.name, x + 15 * s, y + (slotH - fontH) / 2)
        else
            love.graphics.setColor(0.12, 0.12, 0.22, 0.4)
            love.graphics.rectangle("fill", x, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
            love.graphics.rectangle("line", x, y, slotW, slotH, 3 * s)
            love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
            love.graphics.print(i .. ".", x + 3 * s, y + (slotH - fontH) / 2)
        end
    end
    love.graphics.setFont(ui.fontNormal)
end

function hud.drawComboFlash(ui, time, comboCount, timer)
    if timer <= 0 then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local frac = timer / 0.3
    local pulse = math.sin(time * 30) * 0.5 + 0.5

    love.graphics.setColor(1, 0.5, 0, frac * 0.15)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(ui.fontLarge)
    local r = 1
    local g = 0.5 + pulse * 0.3
    love.graphics.setColor(r, g, 0, frac * (0.6 + pulse * 0.4))
    love.graphics.printf("x" .. (comboCount + 1) .. " COMBO!", 0, h / 2 - 30, w, "center")
end

return hud
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

local Assets = require("core.assets")

local function getCachedFont(fontSize)
    return Assets.getFont(constants.FONT_FILE, fontSize) or Assets.getFont(fontSize)
end

function hud.drawHUD(ui, puntuacion, highScore, monedas, shieldActive, magnetTimer, magnetDuration, baseSpeed, velocidadActual, comboCount, activeTimers, etapa, sala, objetivoSala, scale)
    local s = scale or (ui and ui.scale) or 1
    local w = love.graphics.getWidth()

    local fontSize = math.max(6, math.floor(constants.FONT_NORMAL * s))
    local font = getCachedFont(fontSize)
    love.graphics.setFont(font)

    local hh = constants.HUD_HEIGHT * s
    local fontH = font:getHeight()
    local cy = math.floor((hh - fontH) / 2)

    local worldMod = package.loaded["world.world"]
    local isBoss = (sala == 5)
    local enemiesMod = package.loaded["entities.enemies"]
    local boss = enemiesMod and enemiesMod.boss

    -- Fondo Hades: obsidiana oscura con borde inferior de bronce
    love.graphics.setColor(0.06, 0.08, 0.14, 0.90)
    love.graphics.rectangle("fill", 0, 0, w, hh)
    love.graphics.setColor(0.85, 0.65, 0.15, 0.85)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(0, hh, w, hh)
    love.graphics.setLineWidth(1)

    local x = 8 * s

    -- Indicador de sala y bioma
    if etapa and sala then
        local bData = worldMod and worldMod.getBiomeData and worldMod.getBiomeData()
        local bName = bData and bData.name and string.upper(bData.name) or "CATACUMBAS"
        local roomText = etapa .. "-" .. sala
        if isBoss then
            love.graphics.setColor(0.98, 0.75, 0.14)
        else
            local acc = bData and bData.gridAccent or constants.COLOR_ACCENT
            love.graphics.setColor(acc[1], acc[2], acc[3])
        end
        love.graphics.print(roomText, x, cy)
        x = x + font:getWidth(roomText) + 6 * s

        love.graphics.setColor(0.65, 0.70, 0.80, 0.85)
        love.graphics.print(bName, x, cy)
        x = x + font:getWidth(bName) + 12 * s
    end

    -- Badges de mutadores y eventos (solo si no es boss)
    if not isBoss then
        local mutMods = package.loaded["systems.roomMutators"]
        local mutDef = mutMods and mutMods.getDef and mutMods.getDef()
        local function printTag(tag, col)
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.print(tag, x, cy)
            x = x + font:getWidth(tag) + 10 * s
        end
        if mutDef then printTag(mutDef.tag, mutDef.color) end
        if mutMods and mutMods.stageShadowActive and mutMods.stageShadowActive()
            and (not mutDef or mutDef.id ~= "stalking_shadow") then
            printTag("SOMBRA", {0.6, 0.3, 0.9})
        end
        if mutMods and mutMods.phoenixAvailable and mutMods.phoenixAvailable()
            and (not mutDef or mutDef.id ~= "phoenix_blessing") then
            printTag("FENIX", {1.0, 0.4, 0.2})
        end
        local mysMods = package.loaded["systems.mystery"]
        local mysDef = mysMods and mysMods.currentDef and mysMods.currentDef(worldMod)
        if mysDef then printTag(mysDef.tag, mysDef.color) end
    end

    -- Monedas y puntuacion
    love.graphics.setColor(1, 0.84, 0.0)
    love.graphics.print("$" .. monedas, x, cy)
    x = x + font:getWidth("$" .. monedas) + 12 * s

    if not isBoss then
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
        love.graphics.print("" .. puntuacion, x, cy)
        x = x + font:getWidth("" .. puntuacion) + 12 * s
    end

    local world = require("core.world")
    local streak = world.state and world.state.survivalStreak or 1.0
    if streak > 1.0 then
        local streakText = string.format("STREAK %.1fx", streak)
        local sPulse = math.sin(love.timer.getTime() * 8) * 0.2 + 0.8
        love.graphics.setColor(0.0, 0.94, 1.0, sPulse)
        love.graphics.print(streakText, x, cy)
        x = x + font:getWidth(streakText) + 12 * s
    end

    -- Barra de progreso hacia el objetivo de sala (salas normales)
    if not isBoss and objetivoSala and objetivoSala > 0 and sala and sala < 5 then
        local barW = 50 * s
        local barH = 6 * s
        local barY2 = math.floor(hh / 2) - 3 * s
        local frac = math.min(1, puntuacion / objetivoSala)
        love.graphics.setColor(0.20, 0.20, 0.25)
        love.graphics.rectangle("fill", x, barY2, barW, barH, 2 * s, 2 * s)
        love.graphics.setColor(frac, 1 - frac, 0)
        love.graphics.rectangle("fill", x, barY2, barW * frac, barH, 2 * s, 2 * s)
        love.graphics.setColor(0.85, 0.65, 0.15, 0.8)
        love.graphics.rectangle("line", x - 1, barY2 - 1, barW + 2, barH + 2, 2 * s, 2 * s)
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

    if baseSpeed and not isBoss then
        local frac = (baseSpeed - constants.MIN_BASE_SPEED) / (constants.MAX_BASE_SPEED - constants.MIN_BASE_SPEED)
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", x, barY, 36 * s, 6 * s, 2 * s, 2 * s)
        love.graphics.setColor(frac, 1 - frac, 0)
        love.graphics.rectangle("fill", x, barY, 36 * s * (1 - frac), 6 * s, 2 * s, 2 * s)
        x = x + 42 * s
    end

    if comboCount and comboCount > 0 then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("x" .. (comboCount + 1), x, cy)
        x = x + font:getWidth("x" .. (comboCount + 1)) + 8 * s
    end

    if activeTimers then
        local labels = {
            ghost = "G", turbo = "T", slow = "S",
            doubler = "D", extraCoin = "C", star = "*",
            status_overdrive = "OV", status_medusa = "ME",
            status_venom = "VN", status_cryo = "CR"
        }
        local colors = {
            ghost = {0.6, 0.4, 1}, turbo = {0, 1, 0.5},
            slow = {0.5, 0.5, 1}, doubler = {1, 0.84, 0},
            extraCoin = {1, 0.84, 0}, star = {1, 0.5, 0},
            status_overdrive = {1, 0.84, 0.2}, status_medusa = {0.6, 0.6, 0.65},
            status_venom = {0.3, 1, 0.3}, status_cryo = {0.5, 0.9, 1}
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
                local rem = t.remaining or dur
                if t._handle and t._handle.delay then
                    rem = math.max(0, t._handle.delay - (t._handle.accum or 0))
                end
                love.graphics.rectangle("fill", x, barY, 20 * s * math.min(1, rem / dur), 6 * s, 2 * s, 2 * s)
                x = x + 26 * s
            end
        end
    end

    -- ESTANDARTE HEROICO FLOTANTE HADES 8.1 (OPCION 1)
    if isBoss then
        local bMaxHp = boss and (boss.maxHp or constants.BOSS_HEADBUTT_HP) or 12
        local bHp = boss and (boss.hp or bMaxHp) or 12
        local hpFrac = math.max(0, math.min(1, bHp / bMaxHp))
        local fillLerp = boss and boss._uiBarFill or hpFrac
        local ghostFrac = math.max(hpFrac, math.min(1, fillLerp))

        local bannerW = math.floor(math.min(w * 0.45, 260 * s))
        local bannerH = math.floor(26 * s)
        local bannerX = math.floor((w - bannerW) / 2)
        local bannerY = math.floor(hh + 6 * s)

        -- Placa de fondo de obsidiana con marco de bronce
        love.graphics.setColor(0.06, 0.08, 0.14, 0.92)
        love.graphics.rectangle("fill", bannerX, bannerY, bannerW, bannerH, 3 * s, 3 * s)

        love.graphics.setColor(0.85, 0.65, 0.15, 0.95)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bannerX, bannerY, bannerW, bannerH, 3 * s, 3 * s)

        -- Remaches dorados en las 4 esquinas del estandarte
        love.graphics.setColor(0.98, 0.85, 0.25, 0.9)
        love.graphics.rectangle("fill", bannerX - 1, bannerY - 1, 3 * s, 3 * s)
        love.graphics.rectangle("fill", bannerX + bannerW - 2 * s, bannerY - 1, 3 * s, 3 * s)
        love.graphics.rectangle("fill", bannerX - 1, bannerY + bannerH - 2 * s, 3 * s, 3 * s)
        love.graphics.rectangle("fill", bannerX + bannerW - 2 * s, bannerY + bannerH - 2 * s, 3 * s, 3 * s)

        -- Titulo del jefe centrado en la placa con fuente ajustada
        local bFont = getCachedFont(math.max(6, math.floor(constants.FONT_SMALL * s)))
        love.graphics.setFont(bFont)

        local isEnraged = boss and boss.enraged or (bHp <= 3)
        local titleText = isEnraged
            and ("FURIA: CABEZAZO x2+ [" .. bHp .. "/" .. bMaxHp .. "]")
            or ("GOLEM DE CRIPTA [" .. bHp .. "/" .. bMaxHp .. "]")

        if isEnraged then
            local pulse = math.sin(love.timer.getTime() * 10) * 0.2 + 0.8
            love.graphics.setColor(1.0, 0.25, 0.20, pulse)
        else
            love.graphics.setColor(0.98, 0.85, 0.25, 0.95)
        end
        love.graphics.printf(titleText, bannerX, bannerY + math.floor(3 * s), bannerW, "center")

        -- Barra de salud interna
        local barW = bannerW - math.floor(20 * s)
        local barH = math.floor(7 * s)
        local barX = bannerX + math.floor(10 * s)
        local barY = bannerY + math.floor(15 * s)

        -- Marco oscuro de la barra
        love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 2 * s, 2 * s)

        -- Ghost HP (amarillo residual tras golpes de cabezazo)
        if ghostFrac > hpFrac then
            love.graphics.setColor(0.98, 0.90, 0.40, 0.45)
            love.graphics.rectangle("fill", barX, barY, math.floor(barW * ghostFrac), barH, 2 * s, 2 * s)
        end

        -- Barra de vida real (rojo carmesi noble / fuego si enrage)
        if isEnraged then
            love.graphics.setColor(0.95, 0.35, 0.10, 0.95)
        else
            love.graphics.setColor(0.85, 0.15, 0.25, 0.95)
        end
        love.graphics.rectangle("fill", barX, barY, math.floor(barW * hpFrac), barH, 2 * s, 2 * s)

        -- Borde de bronce fino de la barra
        love.graphics.setColor(0.85, 0.65, 0.15, 0.85)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX - 1, barY - 1, barW + 2, barH + 2, 2 * s, 2 * s)

        -- Gemas de fase de rubi a 33% y 66%
        local gs = 2.5 * s
        local function drawRuby(rx, ry, active)
            if active then
                love.graphics.setColor(0.95, 0.20, 0.30)
            else
                love.graphics.setColor(0.30, 0.30, 0.35)
            end
            love.graphics.polygon("fill", rx, ry - gs, rx + gs, ry, rx, ry + gs, rx - gs, ry)
            love.graphics.setColor(0.98, 0.85, 0.25)
            love.graphics.polygon("line", rx, ry - gs, rx + gs, ry, rx, ry + gs, rx - gs, ry)
        end
        drawRuby(barX + math.floor(barW * 0.33), barY + math.floor(barH / 2), bHp >= 4)
        drawRuby(barX + math.floor(barW * 0.66), barY + math.floor(barH / 2), bHp >= 8)
    end

    love.graphics.setFont(ui.fontNormal)
end

function hud.drawSlots(ui, slotDisplay)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local s = math.min(ui and ui.scale or 1.0, w / 520)

    local btnW = math.floor(76 * s)
    local slotH = math.floor(24 * s)
    local gap = math.floor(4 * s)
    local margin = math.floor(6 * s)
    local y = h - slotH - margin

    local fontSize = math.max(6, math.floor(constants.FONT_SMALL * s))
    local font = getCachedFont(fontSize)
    love.graphics.setFont(font)
    local fontH = font:getHeight()

    local world = require("core.world")
    local player = world.state and world.state.player

    -- ==========================================
    -- ALA IZQUIERDA: HABILIDADES DE EVASIÓN [Q] Y [R]
    -- ==========================================
    local leftW = btnW * 2 + gap + 8 * s
    local leftX = margin

    -- Panel contenedor ala izquierda (bronce + mármol)
    love.graphics.setColor(0.06, 0.08, 0.14, 0.90)
    love.graphics.rectangle("fill", leftX, y - 2 * s, leftW, slotH + 4 * s, 4 * s, 4 * s)
    love.graphics.setColor(0.85, 0.65, 0.18, 0.85)
    love.graphics.rectangle("line", leftX, y - 2 * s, leftW, slotH + 4 * s, 4 * s, 4 * s)

    if player then
        -- Slot [Q] Autotomia
        local qX = leftX + 4 * s
        local cd = player.autotomyCooldown or 0
        local maxCd = constants.AUTOTOMY_COOLDOWN or 8.0
        local canUse = (cd <= 0 and player.body and #player.body >= 4)

        if canUse then
            local pulse = math.sin(love.timer.getTime() * 6) * 0.2 + 0.8
            love.graphics.setColor(0.18, 0.10, 0.30, 0.85)
            love.graphics.rectangle("fill", qX, y, btnW, slotH, 3 * s)
            love.graphics.setColor(0.8, 0.3, 1.0, pulse)
            love.graphics.rectangle("line", qX, y, btnW, slotH, 3 * s)
            love.graphics.setColor(0.8, 0.4, 1.0)
            love.graphics.print("[Q]", qX + 3 * s, y + (slotH - fontH) / 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("COLA", qX + 22 * s, y + (slotH - fontH) / 2)
        else
            local cdFrac = cd > 0 and (cd / maxCd) or 0
            love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
            love.graphics.rectangle("fill", qX, y, btnW, slotH, 3 * s)
            if cd > 0 then
                love.graphics.setColor(0.5, 0.2, 0.7, 0.45)
                love.graphics.rectangle("fill", qX, y, btnW * (1 - cdFrac), slotH, 3 * s)
            end
            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
            love.graphics.rectangle("line", qX, y, btnW, slotH, 3 * s)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
            local txt = cd > 0 and string.format("[Q] %.0fs", cd) or "[Q] COLA"
            love.graphics.print(txt, qX + 3 * s, y + (slotH - fontH) / 2)
        end

        -- Slot [R] Inversion
        local rX = qX + btnW + gap
        local rCd = player.reverseSlitherCooldown or 0
        local rMaxCd = constants.REVERSE_SLITHER_COOLDOWN or 10.0
        local rCanUse = (rCd <= 0 and player.body and #player.body >= 2)

        if rCanUse then
            local pulse = math.sin(love.timer.getTime() * 6) * 0.2 + 0.8
            love.graphics.setColor(0.08, 0.18, 0.25, 0.85)
            love.graphics.rectangle("fill", rX, y, btnW, slotH, 3 * s)
            love.graphics.setColor(0.0, 0.94, 0.8, pulse)
            love.graphics.rectangle("line", rX, y, btnW, slotH, 3 * s)
            love.graphics.setColor(0.0, 0.94, 0.8)
            love.graphics.print("[R]", rX + 3 * s, y + (slotH - fontH) / 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("INVERT", rX + 22 * s, y + (slotH - fontH) / 2)
        else
            local rFrac = rCd > 0 and (rCd / rMaxCd) or 0
            love.graphics.setColor(0.1, 0.15, 0.15, 0.5)
            love.graphics.rectangle("fill", rX, y, btnW, slotH, 3 * s)
            if rCd > 0 then
                love.graphics.setColor(0.1, 0.6, 0.6, 0.45)
                love.graphics.rectangle("fill", rX, y, btnW * (1 - rFrac), slotH, 3 * s)
            end
            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
            love.graphics.rectangle("line", rX, y, btnW, slotH, 3 * s)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
            local txt = rCd > 0 and string.format("[R] %.0fs", rCd) or "[R] INVERT"
            love.graphics.print(txt, rX + 3 * s, y + (slotH - fontH) / 2)
        end
    end

    -- ==========================================
    -- ALA DERECHA: ARSENAL (SLOTS 1-3)
    -- ==========================================
    local itemSlotW = math.floor(52 * s)
    local rightW = itemSlotW * 3 + gap * 2 + 8 * s
    local touchOffset = math.floor(64 * s)
    local rightX = w - rightW - touchOffset

    -- Panel contenedor ala derecha
    love.graphics.setColor(0.06, 0.08, 0.14, 0.90)
    love.graphics.rectangle("fill", rightX, y - 2 * s, rightW, slotH + 4 * s, 4 * s, 4 * s)
    love.graphics.setColor(0.85, 0.65, 0.18, 0.85)
    love.graphics.rectangle("line", rightX, y - 2 * s, rightW, slotH + 4 * s, 4 * s, 4 * s)

    for i = 1, 3 do
        local x = rightX + 4 * s + (i - 1) * (itemSlotW + gap)
        local slot = slotDisplay and slotDisplay[i]

        if slot then
            love.graphics.setColor(0.12, 0.12, 0.22, 0.85)
            love.graphics.rectangle("fill", x, y, itemSlotW, slotH, 3 * s)
            love.graphics.setColor(0.85, 0.65, 0.18, 0.6)
            love.graphics.rectangle("line", x, y, itemSlotW, slotH, 3 * s)
            love.graphics.setColor(0.98, 0.85, 0.25, 0.8)
            love.graphics.print(i .. ".", x + 2 * s, y + (slotH - fontH) / 2)
            love.graphics.setColor(1, 1, 1)
            local itemName = slot.name or ""
            if font:getWidth(itemName) > itemSlotW - 14 * s then
                itemName = string.sub(itemName, 1, 4) .. "."
            end
            love.graphics.print(itemName, x + 12 * s, y + (slotH - fontH) / 2)
        else
            love.graphics.setColor(0.12, 0.12, 0.22, 0.4)
            love.graphics.rectangle("fill", x, y, itemSlotW, slotH, 3 * s)
            love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
            love.graphics.rectangle("line", x, y, itemSlotW, slotH, 3 * s)
            love.graphics.setColor(0.4, 0.4, 0.4, 0.5)
            love.graphics.print(i .. ".", x + 2 * s, y + (slotH - fontH) / 2)
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
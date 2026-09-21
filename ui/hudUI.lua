-- ui/hudUI.lua - HUD: grid, barra superior, slots y combo flash
local hud = {}
local constants = require("constants")
local hudSouls = require("ui.hudSouls")

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

local MINIBOSS_THEMES = {
    wall_crusher = {name = "TRITURADOR", color = {0.98, 0.42, 0.12}, accent = {1.00, 0.70, 0.20}},
    frost_golem  = {name = "GOLEM ESCARCHA", color = {0.20, 0.85, 1.00}, accent = {0.60, 0.95, 1.00}},
    magma_wyrm   = {name = "SIERPE MAGMA", color = {1.00, 0.28, 0.08}, accent = {1.00, 0.60, 0.20}},
    brood_queen  = {name = "REINA LARVA", color = {0.80, 0.18, 0.90}, accent = {0.95, 0.45, 1.00}},
    void_phantom = {name = "ESPECTRO VACIO", color = {0.65, 0.30, 0.98}, accent = {0.85, 0.60, 1.00}},
}

local function drawFloatingBanner(w, hh, s, fontSmall, title, hp, maxHp, mainCol, accCol, isTelegraph, ghostFrac, isEnraged)
    local bannerW = math.floor(math.min(w * 0.45, 260 * s))
    local bannerH = math.floor(26 * s)
    local bannerX = math.floor((w - bannerW) / 2)
    local bannerY = math.floor(hh + 6 * s)

    love.graphics.setColor(0.06, 0.08, 0.14, 0.92)
    love.graphics.rectangle("fill", bannerX, bannerY, bannerW, bannerH, 3 * s, 3 * s)

    love.graphics.setColor(mainCol[1], mainCol[2], mainCol[3], 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", bannerX, bannerY, bannerW, bannerH, 3 * s, 3 * s)

    love.graphics.setColor(accCol[1], accCol[2], accCol[3], 0.9)
    local rw, rh = 3 * s, 3 * s
    love.graphics.rectangle("fill", bannerX - 1, bannerY - 1, rw, rh)
    love.graphics.rectangle("fill", bannerX + bannerW - rw, bannerY - 1, rw, rh)
    love.graphics.rectangle("fill", bannerX - 1, bannerY + bannerH - rh, rw, rh)
    love.graphics.rectangle("fill", bannerX + bannerW - rw, bannerY + bannerH - rh, rw, rh)

    love.graphics.setFont(fontSmall)
    if isEnraged then
        local pulse = math.sin(love.timer.getTime() * 10) * 0.2 + 0.8
        love.graphics.setColor(1.0, 0.25, 0.20, pulse)
    elseif isTelegraph then
        local pulse = math.sin(love.timer.getTime() * 12) * 0.2 + 0.8
        love.graphics.setColor(1.0, 0.84, 0.0, pulse)
    else
        love.graphics.setColor(accCol[1], accCol[2], accCol[3], 0.95)
    end
    love.graphics.printf(title, bannerX, bannerY + math.floor(3 * s), bannerW, "center")

    local barW = bannerW - math.floor(20 * s)
    local barH = math.floor(7 * s)
    local barX = bannerX + math.floor(10 * s)
    local barY = bannerY + math.floor(15 * s)
    local hpFrac = math.max(0, math.min(1, hp / maxHp))

    love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 2 * s, 2 * s)

    if ghostFrac and ghostFrac > hpFrac then
        love.graphics.setColor(0.98, 0.90, 0.40, 0.45)
        love.graphics.rectangle("fill", barX, barY, math.floor(barW * ghostFrac), barH, 2 * s, 2 * s)
    end

    if isEnraged then
        love.graphics.setColor(0.95, 0.35, 0.10, 0.95)
    else
        love.graphics.setColor(mainCol[1], mainCol[2], mainCol[3], 0.95)
    end
    love.graphics.rectangle("fill", barX, barY, math.floor(barW * hpFrac), barH, 2 * s, 2 * s)

    love.graphics.setColor(mainCol[1], mainCol[2], mainCol[3], 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barW + 2, barH + 2, 2 * s, 2 * s)

    local gs = 2.5 * s
    local function drawDiamond(rx, ry, active, color)
        if active then love.graphics.setColor(color[1], color[2], color[3])
        else love.graphics.setColor(0.25, 0.25, 0.30) end
        love.graphics.polygon("fill", rx, ry - gs, rx + gs, ry, rx, ry + gs, rx - gs, ry)
        love.graphics.setColor(accCol[1], accCol[2], accCol[3])
        love.graphics.polygon("line", rx, ry - gs, rx + gs, ry, rx, ry + gs, rx - gs, ry)
    end

    if maxHp > 1 and maxHp <= 6 then
        for step = 1, maxHp - 1 do
            local dx = barX + math.floor(barW * (step / maxHp))
            drawDiamond(dx, barY + math.floor(barH / 2), hp > step, accCol)
        end
    else
        drawDiamond(barX + math.floor(barW * 0.33), barY + math.floor(barH / 2), hp >= 4, {0.95, 0.20, 0.30})
        drawDiamond(barX + math.floor(barW * 0.66), barY + math.floor(barH / 2), hp >= 8, {0.95, 0.20, 0.30})
    end
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

    -- Renderizar cabecera solemne Soulsborne (Propuesta 13)
    hudSouls.drawTopBar(w, hh, s, font, etapa, sala, monedas, puntuacion, objetivoSala, isBoss)

    local okWm, worldState = pcall(require, "core.world")
    local rushLeft = okWm and worldState.get("timeLimit")
    if rushLeft ~= nil then
        local mm = math.floor(rushLeft / 60)
        local ss = math.floor(rushLeft % 60)
        love.graphics.setColor(1.0, 0.3, 0.2)
        local t = string.format("%d:%02d", mm, ss)
        love.graphics.print(t, math.floor(w - font:getWidth(t) - 8 * s), cy)
    end

    -- Badges de mutadores y buffs a la derecha del relicario central (sin colisionar)
    local relW = math.floor(180 * s)
    local x = (not isBoss and objetivoSala and objetivoSala > 0 and sala and sala < 5)
        and math.floor((w + relW) / 2 + 10 * s)
        or math.floor(w * 0.45)
    if not isBoss then
        local mutMods = package.loaded["systems.roomMutators"]
        local mutDef = mutMods and mutMods.getDef and mutMods.getDef()
        local function printTag(tag, col)
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.print(tag, x, cy)
            x = x + font:getWidth(tag) + 8 * s
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

    -- ESTANDARTE HEROICO FLOTANTE (BOSS O MINI-BOSS)
    local bFont = getCachedFont(math.max(6, math.floor(constants.FONT_SMALL * s)))
    if isBoss and boss and boss.alive then
        local bMaxHp = boss.maxHp or constants.BOSS_HEADBUTT_HP or 12
        local bHp = boss.hp or bMaxHp
        local hpFrac = math.max(0, math.min(1, bHp / bMaxHp))
        local fillLerp = boss._uiBarFill or hpFrac
        local ghostFrac = math.max(hpFrac, math.min(1, fillLerp))
        local isEnraged = boss.enraged or (bHp <= 3)
        local title = isEnraged
            and ("FURIA: CABEZAZO x2+ [" .. bHp .. "/" .. bMaxHp .. "]")
            or ("GOLEM DE CRIPTA [" .. bHp .. "/" .. bMaxHp .. "]")
        drawFloatingBanner(w, hh, s, bFont, title, bHp, bMaxHp,
            {0.85, 0.65, 0.15}, {0.98, 0.85, 0.25}, false, ghostFrac, isEnraged)
    else
        local mb = enemiesMod and enemiesMod.getMiniBoss and enemiesMod.getMiniBoss()
        if mb and mb.alive then
            local defId = mb.defId or "wall_crusher"
            local theme = MINIBOSS_THEMES[defId] or {
                name = mb.name or "ELITE",
                color = mb.color or {0.98, 0.42, 0.12},
                accent = {1.00, 0.70, 0.20}
            }
            local isTelegraph = (mb.state == "telegraph")
            local title = isTelegraph
                and ("¡VULNERABLE: CABEZAZO! [" .. (mb.hp or 1) .. "/" .. (mb.maxHp or 1) .. "]")
                or (theme.name .. " [" .. (mb.hp or 1) .. "/" .. (mb.maxHp or 1) .. "]")
            drawFloatingBanner(w, hh, s, bFont, title, mb.hp or 1, mb.maxHp or 1,
                theme.color, theme.accent, isTelegraph, nil, false)
        end
    end

    love.graphics.setFont(ui.fontNormal)
end

function hud.drawSlots(ui, slotDisplay)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local s = math.min(ui and ui.scale or 1.0, w / 520)

    local fontSize = math.max(6, math.floor(constants.FONT_SMALL * s))
    local font = getCachedFont(fontSize)
    love.graphics.setFont(font)

    local world = require("core.world")
    local player = world.state and world.state.player
    local comboCount = (world.state and world.state.comboCount) or 0
    local isHollow = (player and player.body and #player.body <= 1)
    local time = love.timer.getTime()

    -- Actualizar fisica procedural de particulas del Darksign segun combo
    hudSouls.update(love.timer.getDelta(), isHollow, comboCount)

    -- Renderizar Dock Soulsborne 1:1 de la Propuesta 13 con combo creciente
    hudSouls.drawBottomDock(w, h, s, font, player, slotDisplay, comboCount, isHollow, time)

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
-- ui/menuUI.lua - Menu principal asimetrico: panel vertical izquierdo, titulo Estilo #12 y high score
local menu = {}
local constants = require("constants")
local sound = require("audio.sound")
local persistence = require("systems.persistence")

-- Paleta Arcade Alto Contraste
local COLOR_CYAN     = {0.0, 0.94, 1.0}
local COLOR_MAGENTA  = {1.0, 0.0, 0.33}
local COLOR_GOLD     = {1.0, 0.82, 0.25}
local COLOR_GREEN    = {0.22, 1.0, 0.08}
local COLOR_BG_BOX   = {0.039, 0.051, 0.094}
local COLOR_BG_HOVER = {0.06, 0.09, 0.18}
local COLOR_BG_PRESS = {0.02, 0.03, 0.06}

-- Texturas del logotipo Estilo #12 (Calca 1:1 HD)
local titleImage = nil
local titleGlowImage = nil
local titleLoaded = false

local function loadTitleAssets()
    if titleLoaded then return end
    titleLoaded = true
    pcall(function()
        if love.filesystem.getInfo("assets/title_style12.png") then
            titleImage = love.graphics.newImage("assets/title_style12.png")
            titleImage:setFilter("linear", "linear")
        end
        if love.filesystem.getInfo("assets/title_style12_glow.png") then
            titleGlowImage = love.graphics.newImage("assets/title_style12_glow.png")
            titleGlowImage:setFilter("linear", "linear")
        end
    end)
end

function menu.getLogoBounds(t)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local panelW = math.floor(w * 0.40)
    local rightCenterX = panelW + math.floor((w - panelW) / 2)
    local floatOffset = math.sin((t or 0) * 1.5) * 3

    local logoCfg = persistence.getLogoConfig()
    local pScale = logoCfg.scale or 6
    local spacing = logoCfg.spacing or 10
    local depth = logoCfg.depth or 5
    local totalW = 5 * (7 * pScale) + 4 * spacing
    local totalH = 7 * pScale
    local startX = rightCenterX - math.floor(totalW / 2) + (logoCfg.offsetX or 0)
    local startY = math.floor(h * 0.36 - totalH / 2) + floatOffset + (logoCfg.offsetY or 0)

    return startX, startY, totalW, totalH, depth, pScale, spacing, floatOffset
end

function menu.draw(ui, menuTime, globalTime, highScore)
    loadTitleAssets()

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local panelW = math.floor(w * 0.40)
    local rightCenterX = panelW + math.floor((w - panelW) / 2)

    -- Timings para aparicion
    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.4))
    local panelAlpha = math.min(1, math.max(0, (menuTime - 2.6) / 0.5))

    -- === PANEL LATERAL IZQUIERDO (40% de ancho, 100% de alto) ===
    if panelAlpha > 0 then
        -- 1. Fondo solido oscuro translúcido con leve degradado
        love.graphics.setColor(COLOR_BG_BOX[1], COLOR_BG_BOX[2], COLOR_BG_BOX[3], panelAlpha * 0.92)
        love.graphics.rectangle("fill", 0, 0, panelW, h)

        -- 2. Linea divisoria vertical neón en el borde derecho
        local lineGlow = 0.75 + math.sin((globalTime or menuTime) * 3) * 0.25
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0, 0, 0, panelAlpha * 0.8)
        love.graphics.line(panelW + 2, 0, panelW + 2, h)

        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], panelAlpha * lineGlow * 0.85)
        love.graphics.line(panelW, 0, panelW, h)

        -- Marcadores arcade en los extremos de la linea
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], panelAlpha * 0.95)
        love.graphics.rectangle("fill", panelW - 2, 0, 4, 12)
        love.graphics.rectangle("fill", panelW - 2, h - 12, 4, 12)
        love.graphics.setLineWidth(1)
    end

    -- === TITULO "S N A K E" (LOGOTIPO PROCEDURAL ISOMÉTRICO 2.5D EN COLOR CIAN NEÓN #09 + #16) ===
    if titleAlpha > 0 then
        local t = (globalTime or menuTime)
        local startX, startY, totalW, totalH, depth, pScale, spacing = menu.getLogoBounds(t)

        local titleLetters = {
            {" XXXXX ", "XX   XX", "XX     ", " XXXXX ", "     XX", "XX   XX", " XXXXX "}, -- S
            {"XX   XX", "XXX  XX", "XXXX XX", "XX XXXX", "XX  XXX", "XX   XX", "XX   XX"}, -- N
            {" XXXXX ", "XX   XX", "XX   XX", "XXXXXXX", "XX   XX", "XX   XX", "XX   XX"}, -- A
            {"XX   XX", "XX  XX ", "XX XX  ", "XXXX   ", "XX XX  ", "XX  XX ", "XX   XX"}, -- K
            {"XXXXXXX", "XX     ", "XX     ", "XXXXXX ", "XX     ", "XX     ", "XXXXXXX"}  -- E
        }

        local sweepX = (t * 160) % (totalW + 100) - 50

        -- 1. Capas de Extrusión Isométrica 3D hacia (-d, d)
        for d = depth, 1, -1 do
            local offX = -d
            local offY = d
            local curX = startX + offX
            local col = (d == depth) and {0.0, 0.0, 0.0, titleAlpha * 0.95} or ((d > 2) and {0.0, 0.28, 0.38, titleAlpha} or {0.0, 0.55, 0.70, titleAlpha})

            love.graphics.setColor(col[1], col[2], col[3], col[4])
            for i = 1, 5 do
                local mat = titleLetters[i]
                for r = 1, 7 do
                    local line = mat[r]
                    for c = 1, 7 do
                        if line:sub(c, c) == 'X' then
                            love.graphics.rectangle("fill", curX + (c - 1) * pScale, startY + offY + (r - 1) * pScale, pScale, pScale)
                        end
                    end
                end
                curX = curX + 7 * pScale + spacing
            end
        end

        -- 2. Fachada Frontal en Cian Neón con Bisel de Platino y Barrido Especular
        local curX = startX
        for i = 1, 5 do
            local mat = titleLetters[i]
            for r = 1, 7 do
                local line = mat[r]
                for c = 1, 7 do
                    if line:sub(c, c) == 'X' then
                        local px = curX + (c - 1) * pScale
                        local py = startY + (r - 1) * pScale
                        local distToSweep = math.abs(px - (startX + sweepX))

                        if distToSweep < 12 then
                            love.graphics.setColor(1.0, 1.0, 1.0, titleAlpha) -- Destello blanco puro
                        elseif r == 1 or c == 1 then
                            love.graphics.setColor(0.70, 0.96, 1.0, titleAlpha) -- Arista de platino / cian hielo
                        elseif r <= 3 then
                            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha) -- Cian neón
                        elseif r <= 5 then
                            love.graphics.setColor(0.0, 0.72, 0.85, titleAlpha) -- Cian medio
                        else
                            love.graphics.setColor(0.0, 0.45, 0.58, titleAlpha) -- Cian profundo
                        end

                        love.graphics.rectangle("fill", px, py, pScale, pScale)
                    end
                end
            end
            curX = curX + 7 * pScale + spacing
        end

        -- 3. Destello Estroboscópico en Cruz Blanca (#16)
        local glintX = startX + sweepX
        if glintX >= startX and glintX <= startX + totalW then
            local glintY = startY + 12
            love.graphics.setColor(1, 1, 1, titleAlpha)
            love.graphics.rectangle("fill", glintX - 8, glintY - 1, 17, 3)
            love.graphics.rectangle("fill", glintX - 1, glintY - 8, 3, 17)
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * 0.85)
            love.graphics.rectangle("fill", glintX - 4, glintY - 4, 9, 9)
            love.graphics.setColor(1, 1, 1, titleAlpha)
            love.graphics.rectangle("fill", glintX - 1, glintY - 1, 3, 3)
        end
    end

    -- === BOTONES DEL MENU (Centrados Verticalmente en Panel Izquierdo) ===
    ui.menuButtons = {}
    local bw = 260
    local bh = 40
    local gap = 14
    local labels = {
        {id = 'play', text = 'JUGAR'},
        {id = 'profiles', text = 'PERFILES'},
        {id = 'settings', text = 'CONFIGURACIÓN'},
        {id = 'exit', text = 'SALIR'}
    }

    local totalMenuHeight = #labels * bh + (#labels - 1) * gap
    local bx = math.floor((panelW - bw) / 2)
    local by = math.floor((h - totalMenuHeight) / 2)

    for i, btn in ipairs(labels) do
        local btnStart = 3.0 + (i - 1) * 0.08
        local btnAlpha = math.min(1, math.max(0, (menuTime - btnStart) / 0.35))

        if btnAlpha > 0 then
            local isHover = (ui.menuHoverId == btn.id)
            local isPressed = (ui.menuPressedId == btn.id)
            local yOffset = isPressed and 2 or (isHover and -2 or 0)
            local slideX = (1 - btnAlpha) * -16
            local x = bx + slideX
            local y = by + (i - 1) * (bh + gap) + yOffset

            ui.menuButtons[#ui.menuButtons + 1] = {id = btn.id, x = x, y = y, w = bw, h = bh}

            -- =========================================================================
            -- RENDERIZADO DEL BOTÓN MAESTRO (OPCIÓN A - SPRITES PNG + GPU BATCHING)
            -- =========================================================================
            local t = (globalTime or menuTime)
            local midY = y + bh / 2
            local ecx = x + bw / 2
            local ecy = midY

            -- 1. Placa Base del Botón (Textura Horneada Cyber-Step #03 + Zarpazos #06)
            local btnTex = isPressed and ui.btnTexPress or (isHover and ui.btnTexHover or ui.btnTexNormal)
            if btnTex then
                love.graphics.setColor(1, 1, 1, btnAlpha)
                love.graphics.draw(btnTex, x - 3, y - 3)
            else
                -- Fallback procedural si no estuviera la textura
                local c = 6
                local poly = {
                    x + c, y, x + bw - c, y, x + bw, y + c, x + bw, y + bh - c,
                    x + bw - c, y + bh, x + c, y + bh, x, y + bh - c, x, y + c
                }
                love.graphics.setColor(0, 0, 0, btnAlpha * 0.85)
                love.graphics.polygon('fill', x + c + 2, y + 3, x + bw - c + 2, y + 3, x + bw + 2, y + c + 3, x + bw + 2, y + bh - c + 3, x + bw - c + 2, y + bh + 3, x + c + 2, y + bh + 3, x + 2, y + bh - c + 3, x + 2, y + c + 3)
                love.graphics.setColor(isPressed and COLOR_BG_PRESS or (isHover and COLOR_BG_HOVER or COLOR_BG_BOX))
                love.graphics.polygon('fill', poly)
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * (isHover and 0.9 or 0.5))
                love.graphics.polygon('line', poly)
            end

            -- 2. Ojo de Víbora Central (Parpadeo Continuo + Eye-Tracking)
            local blinkCycle = 3.5
            local blinkProg = (t + (i - 1) * 0.75) % blinkCycle
            local blink = 0.0
            if blinkProg < 0.28 then
                blink = math.sin((blinkProg / 0.28) * math.pi)
            end

            local eyeW = 26
            local eyeH = 13
            local openH = eyeH * (1.0 - blink)

            -- Eye-Tracking hacia el cursor
            local mx, my = love.mouse.getPosition()
            local lookX, lookY = 0, 0
            if mx and my then
                local dx = mx - ecx
                local dy = my - ecy
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    lookX = (dx / dist) * math.min(3.8, dist / 20)
                    lookY = (dy / dist) * math.min(2.0, dist / 40)
                end
            end

            -- 2a. Fondo oscuro del rombo central
            love.graphics.setColor(0.02, 0.04, 0.08, btnAlpha * 0.95)
            love.graphics.polygon('fill', ecx - eyeW, ecy, ecx, ecy - eyeH, ecx + eyeW, ecy, ecx, ecy + eyeH)

            -- 2b. El Ojo (Delante del fondo del rombo, recortado al interior del rombo)
            if openH > 0.5 then
                love.graphics.setScissor(ecx - eyeW, ecy - eyeH, eyeW * 2, eyeH * 2)

                local irisX = ecx + lookX
                local irisY = ecy + lookY

                if ui.eyeIrisTexture then
                    love.graphics.setColor(1, 1, 1, btnAlpha * (openH / eyeH))
                    love.graphics.draw(ui.eyeIrisTexture, irisX, irisY, 0, 1, openH / eyeH, 14, 14)
                else
                    love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * 0.9)
                    love.graphics.circle('fill', irisX, irisY, 10.5 * (openH / eyeH))
                    love.graphics.setColor(0, 0, 0, btnAlpha)
                    love.graphics.polygon('fill', irisX - 1.5, irisY - 8, irisX + 1.5, irisY - 8, irisX + 1.5, irisY + 8, irisX - 1.5, irisY + 8)
                end

                love.graphics.setScissor()
            end

            -- 2c. Borde azul del rombo (Capa superior: el ojo queda detrás de este borde)
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * (isHover and 0.85 or 0.45))
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon('line', ecx - eyeW, ecy, ecx, ecy - eyeH, ecx + eyeW, ecy, ecx, ecy + eyeH)

            -- Línea de párpado cerrado
            if blink > 0.1 then
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * 0.95 * blink)
                love.graphics.line(ecx - eyeW + 2, ecy, ecx + eyeW - 2, ecy)
            end
            love.graphics.setLineWidth(1)

            -- 3. Mirilla Reticular HUD Lock-On (#11) en Hover (Capa superior sobre el ojo)
            if isHover then
                local o = 3
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * 0.95)
                love.graphics.setLineWidth(1.5)
                -- Corchetes alrededor del ojo central
                love.graphics.line(ecx - 32 - o, ecy - 12, ecx - 32, ecy - 12)
                love.graphics.line(ecx - 32, ecy - 12, ecx - 32, ecy - 12 + o)
                love.graphics.line(ecx + 32 + o, ecy - 12, ecx + 32, ecy - 12)
                love.graphics.line(ecx + 32, ecy - 12, ecx + 32, ecy - 12 + o)
                love.graphics.line(ecx - 32 - o, ecy + 12, ecx - 32, ecy + 12)
                love.graphics.line(ecx - 32, ecy + 12, ecx - 32, ecy + 12 - o)
                love.graphics.line(ecx + 32 + o, ecy + 12, ecx + 32, ecy + 12)
                love.graphics.line(ecx + 32, ecy + 12, ecx + 32, ecy + 12 - o)
                love.graphics.setLineWidth(1)
            end

            -- 4. Micro-Engranajes Laterales de Relojería (#03)
            local gearSpeed = isHover and 5.0 or 1.5
            local gearAngle = (t * gearSpeed) % (math.pi * 2)
            local lx = x + 18
            local rx = x + bw - 18

            if ui.gearTexture then
                love.graphics.setColor(1, 1, 1, btnAlpha)
                love.graphics.draw(ui.gearTexture, lx, midY, gearAngle, 1, 1, 12, 12)
                love.graphics.draw(ui.gearTexture, rx, midY, -gearAngle, 1, 1, 12, 12)
            else
                -- Fallback procedural de engranajes
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha * (isHover and 0.9 or 0.6))
                love.graphics.circle('line', lx, midY, 5)
                love.graphics.circle('line', rx, midY, 5)
            end

            -- 5. Texto del botón centrado con sombra profunda
            love.graphics.setFont(ui.fontNormal)
            local textY = y + (bh - ui.fontNormal:getHeight()) / 2

            love.graphics.setColor(0, 0, 0, btnAlpha * 0.95)
            love.graphics.printf(btn.text, x + 1, textY + 1, bw, 'center')

            if isHover then
                love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], btnAlpha)
            elseif isPressed then
                love.graphics.setColor(0.7, 0.8, 0.9, btnAlpha * 0.9)
            else
                love.graphics.setColor(1, 1, 1, btnAlpha * 0.95)
            end
            love.graphics.printf(btn.text, x, textY, bw, 'center')
        end
    end

    -- === TARJETA COMBINADA DE PERFIL Y HIGH SCORE (#11 CHUNKY + MEDALLA #01 + MONEDA CIRCULAR 3D #01) ===
    if cardAlpha > 0 then
        local persistence = require("systems.persistence")
        local activeProfile = persistence.getActiveProfile()
        local profileName = (activeProfile and activeProfile.name) or "SLAYER_01"
        local coins = (activeProfile and activeProfile.monedas) or 0
        local stageMax = (activeProfile and activeProfile.stats and activeProfile.stats.highestStage) or 1
        if stageMax < 1 then stageMax = 1 end
        if stageMax > 5 then stageMax = 5 end

        local cardW = 344
        local cardH = 76
        local cardX = rightCenterX - math.floor(cardW / 2) + 200
        local cardY = h - cardH - 18

        local isCardHover = (ui.menuHoverId == 'card_profile')
        local t = (globalTime or menuTime)
        local g = 3

        -- Registrar interactividad de la tarjeta
        ui.menuButtons[#ui.menuButtons + 1] = {id = 'card_profile', x = cardX, y = cardY, w = cardW, h = cardH}

        -- Sombra negra sólida de la tarjeta
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.rectangle("fill", cardX - g + 4, cardY - g + 4, cardW + g * 2, cardH + g * 2)

        -- 1. Fondo Izquierdo (#050c17)
        love.graphics.setColor(0.02, 0.05, 0.09, cardAlpha * 0.96)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)

        -- 2. Fondo Derecho a 60° (#0c1b2c)
        love.graphics.setColor(isCardHover and 0.07 or 0.05, isCardHover and 0.14 or 0.11, isCardHover and 0.22 or 0.17, cardAlpha * 0.96)
        local splitStartX = cardX + math.floor(cardW * 0.52)
        for py = 0, cardH - 1 do
            local currentSplitX = splitStartX + math.floor(py * 0.45)
            love.graphics.rectangle("fill", currentSplitX, cardY + py, (cardX + cardW) - currentSplitX, 1)
        end

        -- 3. Línea Divisoria a 60°
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 0.9 or 0.45))
        for py = 0, cardH - 1, 2 do
            local currentSplitX = splitStartX + math.floor(py * 0.45)
            love.graphics.rectangle("fill", currentSplitX, cardY + py, 2, 2)
        end

        -- 4. Marco #11 Chunky con Contorno Negro Exterior
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.98)
        love.graphics.rectangle("fill", cardX - g - 1, cardY - g - 1, cardW + g * 2 + 2, cardH + g * 2 + 2)

        love.graphics.setColor(0.02, 0.05, 0.09, cardAlpha * 0.96)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)
        love.graphics.setColor(isCardHover and 0.07 or 0.05, isCardHover and 0.14 or 0.11, isCardHover and 0.22 or 0.17, cardAlpha * 0.96)
        for py = 0, cardH - 1 do
            local currentSplitX = splitStartX + math.floor(py * 0.45)
            love.graphics.rectangle("fill", currentSplitX, cardY + py, (cardX + cardW) - currentSplitX, 1)
        end
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 0.9 or 0.45))
        for py = 0, cardH - 1, 2 do
            local currentSplitX = splitStartX + math.floor(py * 0.45)
            love.graphics.rectangle("fill", currentSplitX, cardY + py, 2, 2)
        end

        -- Borde Chunky Cian (2px)
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 0.95 or 0.75))
        love.graphics.rectangle("fill", cardX - g, cardY - g, cardW + g * 2, 2)
        love.graphics.rectangle("fill", cardX - g, cardY + cardH + g - 2, cardW + g * 2, 2)
        love.graphics.rectangle("fill", cardX - g, cardY - g, 2, cardH + g * 2)
        love.graphics.rectangle("fill", cardX + cardW + g - 2, cardY - g, 2, cardH + g * 2)

        -- Filo interior fino
        love.graphics.setColor(1, 1, 1, cardAlpha * (isCardHover and 0.4 or 0.15))
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH)

        -- 4 Condensadores Pesados de 6x6 px en las Esquinas
        local corners = {
            {cardX - g - 1, cardY - g - 1},
            {cardX + cardW + g - 5, cardY - g - 1},
            {cardX - g - 1, cardY + cardH + g - 5},
            {cardX + cardW + g - 5, cardY + cardH + g - 5}
        }
        for _, c in ipairs(corners) do
            love.graphics.setColor(0, 0, 0, cardAlpha)
            love.graphics.rectangle("fill", c[1], c[2], 6, 6)
            love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 1.0 or 0.85))
            love.graphics.rectangle("fill", c[1] + 1, c[2] + 1, 4, 4)
            love.graphics.setColor(1, 1, 1, cardAlpha * (isCardHover and 1.0 or 0.6))
            love.graphics.rectangle("fill", c[1] + 2, c[2] + 2, 2, 2)
        end

        -- ================= DATOS IZQUIERDOS =================
        -- Nombre del Jugador / Perfil
        local fontS = ui.fontSmall or ui.fontNormal
        love.graphics.setFont(fontS)
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.print(profileName, cardX + 15, cardY + 13)
        love.graphics.setColor(1, 1, 1, cardAlpha * 0.95)
        love.graphics.print(profileName, cardX + 14, cardY + 12)

        -- 5 Celdas de Mazmorra (Macro-Detalle #12)
        for s = 1, 5 do
            local sx = cardX + 14 + (s - 1) * 15
            local isBoss = (s == 5)
            local isCurrent = (s == stageMax)
            local isCleared = (s < stageMax)

            local pulse = isCurrent and ((math.floor(t * 8) % 2 == 0) and {1, 1, 1} or COLOR_CYAN) or COLOR_CYAN
            love.graphics.setColor(0.01, 0.02, 0.04, cardAlpha)
            love.graphics.rectangle("fill", sx, cardY + 34, 12, 7)

            if isCleared then
                love.graphics.setColor(COLOR_CYAN[1] * 0.6, COLOR_CYAN[2] * 0.6, COLOR_CYAN[3] * 0.6, cardAlpha)
            elseif isCurrent then
                love.graphics.setColor(pulse[1], pulse[2], pulse[3], cardAlpha)
            else
                love.graphics.setColor(0.06, 0.10, 0.16, cardAlpha)
            end
            love.graphics.rectangle("fill", sx + 1, cardY + 35, 10, 5)

            if isBoss then
                -- Calavera de Boss Pixel Art en Celda 5
                local skull = {
                    " XXXXX ",
                    "X X X X",
                    "XXXXXXX",
                    " XXXXX ",
                    " X X X "
                }
                local skullColor = (stageMax >= 5) and {1, 1, 1} or {0.35, 0.45, 0.55}
                for r = 1, 5 do
                    local line = skull[r]
                    for c = 1, 7 do
                        if line:sub(c, c) == 'X' then
                            love.graphics.setColor(skullColor[1], skullColor[2], skullColor[3], cardAlpha)
                            love.graphics.rectangle("fill", sx + 2 + c, cardY + 35 + r - 1, 1, 1)
                        end
                    end
                end
            end
        end

        love.graphics.setColor(0.55, 0.65, 0.75, cardAlpha * 0.85)
        love.graphics.print(string.format("STAGE 0%d/05", stageMax), cardX + 94, cardY + 33)

        -- Moneda Circular #01 en Rotación 3D Elipsoidal a 60 FPS
        local coinAngle = t * 4.5
        local coinCosA = math.cos(coinAngle)
        local coinAbsCos = math.abs(coinCosA)
        local coinR = 5.0
        local coinRx = math.max(0.5, coinR * coinAbsCos)
        local coinThickness = math.max(1, math.floor(2.0 * (1 - coinAbsCos) + 0.5))
        local coinCx = cardX + 19
        local coinCy = cardY + 57

        -- Canto 3D
        if coinAbsCos < 0.95 and coinThickness > 0 then
            local edgeSide = coinCosA >= 0 and -1 or 1
            for py = -math.floor(coinR), math.floor(coinR) do
                local normY = py / coinR
                local inside = 1 - normY * normY
                if inside > 0 then
                    local halfRowW = coinRx * math.sqrt(inside)
                    local startPx = coinCx + (edgeSide > 0 and halfRowW or (-halfRowW - coinThickness))
                    love.graphics.setColor(0.36, 0.27, 0.0, cardAlpha)
                    love.graphics.rectangle("fill", startPx, coinCy + py, coinThickness, 1)
                end
            end
        end

        -- Disco Circular / Elíptico
        for py = -math.floor(coinR), math.floor(coinR) do
            local normY = py / coinR
            local inside = 1 - normY * normY
            if inside > 0 then
                local spanW = coinRx * math.sqrt(inside)
                love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
                love.graphics.rectangle("fill", coinCx - spanW, coinCy + py, spanW * 2, 1)

                if math.abs(py) < coinR - 1 and spanW > 1.5 then
                    local innerNormY = py / (coinR - 1)
                    local innerInside = 1 - innerNormY * innerNormY
                    if innerInside > 0 then
                        local innerSpanW = (coinRx - 1) * math.sqrt(innerInside)
                        love.graphics.setColor(0.79, 0.59, 0.0, cardAlpha)
                        love.graphics.rectangle("fill", coinCx - innerSpanW, coinCy + py, innerSpanW * 2, 1)
                    end
                end
            end
        end

        -- Sello Circular Paramétrico de Serpiente
        if coinRx > 2.0 then
            love.graphics.setColor(0.29, 0.21, 0.0, cardAlpha)
            for theta = 0, math.pi * 2, (math.pi * 2 / 10) do
                local sx = math.cos(theta) * 2.2 * coinAbsCos
                local sy = math.sin(theta) * 2.2
                love.graphics.rectangle("fill", coinCx + sx - 0.5, coinCy + sy - 0.5, 1, 1)
            end
            love.graphics.setColor(1, 1, 1, cardAlpha)
            love.graphics.rectangle("fill", coinCx - 0.5, coinCy - 0.5, 1, 1)
        end

        -- Texto de Monedas
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.print(string.format("%d G", coins), cardX + 31, cardY + 53)
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
        love.graphics.print(string.format("%d G", coins), cardX + 30, cardY + 52)

        -- ================= DATOS DERECHOS =================
        local rightSideX = cardX + math.floor(cardW * 0.58)

        -- Medalla Oficial #01 (Cinta Bicolor en V + Disco de Oro)
        local medalMx = rightSideX + 4
        local medalMy = cardY + 12
        local ribbon = {
            "BBBBRRRRBBBB",
            " BBBBRRRRBB ",
            "  BBBBRRRR  ",
            "   BBBBRR   ",
            "    BBBR    ",
            "     BR     "
        }
        for r = 1, 6 do
            local line = ribbon[r]
            for c = 1, 12 do
                local ch = line:sub(c, c)
                if ch == 'B' then
                    love.graphics.setColor(0.20, 0.53, 1.0, cardAlpha * (isCardHover and 1.0 or 0.85))
                    love.graphics.rectangle("fill", medalMx + c - 2, medalMy + r - 1, 1, 1)
                elseif ch == 'R' then
                    love.graphics.setColor(1.0, 0.20, 0.33, cardAlpha * (isCardHover and 1.0 or 0.85))
                    love.graphics.rectangle("fill", medalMx + c - 2, medalMy + r - 1, 1, 1)
                end
            end
        end
        local medalDisc = {
            "  YYYY  ",
            " YOOOOY ",
            "YOO  OOY",
            "YO    OY",
            "YO    OY",
            "YOO  OOY",
            " YOOOOY ",
            "  DDDD  "
        }
        for r = 1, 8 do
            local line = medalDisc[r]
            for c = 1, 8 do
                local ch = line:sub(c, c)
                if ch == 'Y' then
                    love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
                    love.graphics.rectangle("fill", medalMx + c, medalMy + 4 + r, 1, 1)
                elseif ch == 'O' then
                    love.graphics.setColor(0.79, 0.59, 0.0, cardAlpha)
                    love.graphics.rectangle("fill", medalMx + c, medalMy + 4 + r, 1, 1)
                elseif ch == 'D' then
                    love.graphics.setColor(0.36, 0.27, 0.0, cardAlpha)
                    love.graphics.rectangle("fill", medalMx + c, medalMy + 4 + r, 1, 1)
                end
            end
        end
        love.graphics.setColor(1, 1, 1, cardAlpha)
        love.graphics.rectangle("fill", medalMx + 4, medalMy + 7, 2, 2)

        -- Etiqueta HI-SCORE
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.print("HI-SCORE", rightSideX + 21, cardY + 16)
        love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
        love.graphics.print("HI-SCORE", rightSideX + 20, cardY + 15)

        -- Puntuación High Score
        local fontL = ui.fontLarge or ui.fontNormal
        love.graphics.setFont(fontL)
        local scoreStr = tostring(highScore or 0)
        love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
        love.graphics.print(scoreStr, rightSideX + 5, cardY + 39)
        love.graphics.setColor(1, 1, 1, cardAlpha)
        love.graphics.print(scoreStr, rightSideX + 4, cardY + 38)
    end
end

function menu.drawGlow(ui, menuTime, globalTime)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local panelW = math.floor(w * 0.40)
    local rightCenterX = panelW + math.floor((w - panelW) / 2)

    local titleAlpha = math.min(1, math.max(0, (menuTime - 2.8) / 0.5))
    if titleAlpha <= 0 then return end

    local t = (globalTime or menuTime)
    local startX, startY, totalW, totalH, depth, pScale, spacing = menu.getLogoBounds(t)
    local sweepX = (t * 160) % (totalW + 100) - 50

    local glowPulse = 0.8 + math.sin(t * 3.5) * 0.2

    -- Resplandor del Destello en Cruz
    local glintX = startX + sweepX
    if glintX >= startX and glintX <= startX + totalW then
        local glintY = startY + 12
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], titleAlpha * glowPulse * 0.95)
        love.graphics.rectangle("fill", glintX - 10, glintY - 2, 21, 5)
        love.graphics.rectangle("fill", glintX - 2, glintY - 10, 5, 21)
        love.graphics.setColor(1, 1, 1, titleAlpha * glowPulse)
        love.graphics.rectangle("fill", glintX - 2, glintY - 2, 5, 5)
    end
end

function menu.mousePressed(ui, x, y)
    if not ui.menuButtons then return nil end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return b.id
        end
    end
    return nil
end

function menu.updateHover(ui, x, y)
    local prevHover = ui.menuHoverId
    ui.menuHoverId = nil
    if not ui.menuButtons then return end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            ui.menuHoverId = b.id
            if prevHover ~= b.id then
                sound.play("buttonHover")
            end
            return
        end
    end
end

function menu.setPressed(ui, id)
    ui.menuPressedId = id
end

function menu.clearPressed(ui)
    ui.menuPressedId = nil
end

return menu
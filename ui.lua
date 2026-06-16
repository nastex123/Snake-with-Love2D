local ui = {}
local constants = require("constants")

ui.popups = {}

local function hsv2rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p end
    if i == 1 then return q, v, p end
    if i == 2 then return p, v, t end
    if i == 3 then return p, q, v end
    if i == 4 then return t, p, v end
    return v, p, q
end

function ui.load()
    local ok, err = pcall(function()
        ui.fontTitle = love.graphics.newFont(constants.FONT_FILE, constants.FONT_TITLE)
        ui.fontLarge = love.graphics.newFont(constants.FONT_FILE, constants.FONT_LARGE)
        ui.fontNormal = love.graphics.newFont(constants.FONT_FILE, constants.FONT_NORMAL)
        ui.fontSmall = love.graphics.newFont(constants.FONT_FILE, constants.FONT_SMALL)
    end)
    if not ok then
        ui.fontTitle = love.graphics.newFont(constants.FONT_TITLE)
        ui.fontLarge = love.graphics.newFont(constants.FONT_LARGE)
        ui.fontNormal = love.graphics.newFont(constants.FONT_NORMAL)
        ui.fontSmall = love.graphics.newFont(constants.FONT_SMALL)
    end
end

-- Ajustes de accesibilidad y escala aplicables en runtime
ui.scale = 1.0
ui.highContrast = false
ui.colorblind = 'off'

function ui.setScale(s)
    ui.scale = s or 1.0
    -- ajustar fuentes si se desea (se recarga en load en próximas iteraciones)
end

function ui.applyHighContrast(flag)
    ui.highContrast = not not flag
end

function ui.applyColorblind(mode)
    ui.colorblind = mode or 'off'
end

function ui.drawBalatroIntro(t, globalTime, glowPass)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local cx, cy = w / 2, h / 2

    -- Fade from black (0-0.5s) — scene pass only
    if not glowPass then
        local fadeAlpha = math.max(0, math.min(1, 1 - t / 0.5))
        if fadeAlpha > 0 then
            love.graphics.setColor(0, 0, 0, fadeAlpha)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end

    -- Diamond rise (0.5-1.5s)
    if t >= 0.5 then
        local riseProgress = math.min(1, (t - 0.5) / 1.0)
        local c1 = 1.70158
        local c3 = c1 + 1
        local eased = 1 + c3 * (riseProgress - 1)^3 + c1 * (riseProgress - 1)^2
        local diamondY = cy + (1 - eased) * 150

        -- Outer glow
        local glowR = 40 + math.sin(t * 2) * 5
        local glowA = math.sin(riseProgress * math.pi) * 0.35
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], glowA)
        love.graphics.circle("fill", cx, diamondY, glowR)

        -- Core diamond
        local ds = 18 + (1 - riseProgress) * 5
        love.graphics.push()
        love.graphics.translate(cx, diamondY)
        love.graphics.rotate(math.pi / 4 + math.sin(t * 2) * 0.05)
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 1)
        love.graphics.rectangle("fill", -ds, -ds, ds * 2, ds * 2)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("fill", -ds * 0.4, -ds * 0.4, ds * 0.8, ds * 0.8)
        love.graphics.pop()
    end

    -- Spiral build (1.5-2.5s)
    if t >= 1.5 then
        local sp = math.min(1, (t - 1.5) / 1.0)
        local numShapes = 35
        local maxRadius = math.min(w, h) * 0.55
        local speedMult = 1 + sp * 3

        for i = 0, numShapes - 1 do
            local frac = i / numShapes
            local angle = frac * 6.2832 + (t - 1.5) * speedMult * 2 + i * 0.1
            local radius = (1 - sp) * maxRadius * (0.6 + frac * 0.4)
            radius = radius + math.sin(angle * 2 + t * 3) * 4
            local px = cx + math.cos(angle) * radius
            local py = cy + math.sin(angle) * radius

            if px >= -20 and px <= w + 20 and py >= -20 and py <= h + 20 then
                local hue = (frac + (t - 1.5) * 0.05) % 1
                local cr, cg, cb = hsv2rgb(hue, 0.65, 0.85 + math.sin(t * 2 + i) * 0.15)
                local a = (1 - sp * 0.7) * 0.6 + 0.2

                love.graphics.setColor(cr, cg, cb, a)

                local size = 12 + math.sin(t * 4 + i * 1.7) * 4
                if i % 3 == 0 then
                    love.graphics.rectangle("fill", px - size / 2, py - size / 2, size, size)
                elseif i % 3 == 1 then
                    love.graphics.circle("fill", px, py, size / 2)
                else
                    local pts = {px, py - size / 2, px + size / 2, py, px, py + size / 2, px - size / 2, py}
                    love.graphics.polygon("fill", pts)
                end
            end
        end

        -- Center glow intensifies
        local centerGlow = 0.3 + sp * 0.7
        love.graphics.setColor(1, 1, 1, centerGlow * 0.4)
        love.graphics.circle("fill", cx, cy, 35 + sp * 20)
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], centerGlow * 0.3)
        love.graphics.circle("fill", cx, cy, 50 + sp * 25)
    end

    -- Flash (2.5-3.0s) — scene pass only
    if not glowPass then
        if t >= 2.5 and t < 3.0 then
            local fp = (t - 2.5) / 0.5
            local flashAlpha = math.sin(fp * math.pi)
            if flashAlpha > 0 then
                love.graphics.setColor(1, 1, 1, flashAlpha)
                love.graphics.rectangle("fill", 0, 0, w, h)
            end
        end
    end
end

function ui.drawHighScoreCelebration(puntuacion, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf("NUEVO HIGH SCORE!", 0, h / 2 - 40, w, "center")
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(puntuacion .. " puntos", 0, h / 2, w, "center")
end

function ui.drawMenu(menuTime, globalTime, highScore)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local cx = w / 2

    -- Timings shifted for Balatro intro (flash ends at 3.0s)
    local titleAlpha = math.min(1, math.max(0, (menuTime - 3.0) / 0.5))
    local cardAlpha = math.min(1, math.max(0, (menuTime - 3.3) / 0.5))
    local pillAlpha = math.min(1, math.max(0, (menuTime - 3.5) / 0.5))
    local enterAlpha = math.min(1, math.max(0, (menuTime - 4.0) / 0.3))

    -- === TITLE ===
    if titleAlpha > 0 then
        local titleText = "S N A K E"
        local ty = h / 2 - 70
        local letterSpread = 1 + math.sin(globalTime * 0.6) * 0.04
        local glowPulse = 0.5 + math.sin(globalTime * 1.5) * 0.3

        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(letterSpread, 1)
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))

        -- outer glow
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], titleAlpha * glowPulse * 0.2)
        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(1.06, 1.06)
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))
        love.graphics.printf(titleText, 0, ty, w, "center")
        love.graphics.pop()

        -- mid glow
        love.graphics.setColor(1, 1, 1, titleAlpha * (0.2 + glowPulse * 0.2))
        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(1.03, 1.03)
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))
        love.graphics.printf(titleText, 0, ty, w, "center")
        love.graphics.pop()

        -- core text (scaled bigger)
        love.graphics.push()
        love.graphics.translate(cx, ty + ui.fontTitle:getHeight() / 2)
        love.graphics.scale(1.4, 1.4) -- increase title size
        love.graphics.translate(-cx, -(ty + ui.fontTitle:getHeight() / 2))
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], titleAlpha)
        love.graphics.printf(titleText, 0, ty, w, "center")
        love.graphics.pop()

        love.graphics.pop()
    end

    -- === HIGH SCORE CARD ===
    if cardAlpha > 0 then
        local cardW = 280
        local cardH = 44
        local cardX = (w - cardW) / 2
        local cardY = h / 2 + 10
        local shimmer = math.sin(globalTime * 2) * 0.3 + 0.7

        -- bg glassmorphism
        love.graphics.setColor(0.12, 0.12, 0.22, cardAlpha * 0.6)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6)
        -- border
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], cardAlpha * 0.3 * shimmer)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6)
        -- star icon
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha)
        local starX = cardX + 14
        local starY = cardY + cardH / 2
        local pts = {}
        for i = 0, 9 do
            local angle = math.pi / 2 - i * math.pi * 2 / 10
            local ri = i % 2 == 0 and 8 or 3
            table.insert(pts, starX + math.cos(angle) * ri)
            table.insert(pts, starY + math.sin(angle) * ri)
        end
        love.graphics.polygon("fill", pts)
        -- text
        love.graphics.setFont(ui.fontLarge)
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], cardAlpha)
        love.graphics.print("HIGH SCORE: " .. highScore, starX + 20, starY - ui.fontLarge:getHeight() / 2)
        love.graphics.setLineWidth(1)
    end

    -- === CONTROL PILLS ===
    if pillAlpha > 0 then
        local pillY = h - 36
        local pills = {
            {text = "WASD / FLECHAS", x = cx - 120},
            {text = "+ / - VELOCIDAD", x = cx + 20}
        }

        for _, pill in ipairs(pills) do
            local pw = ui.fontSmall:getWidth(pill.text) + 16
            local ph = 20
            local px = pill.x
            local py = pillY

            love.graphics.setColor(0.12, 0.12, 0.22, pillAlpha * 0.5)
            love.graphics.rectangle("fill", px, py, pw, ph, 10)
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pillAlpha * 0.25)
            love.graphics.rectangle("line", px, py, pw, ph, 10)

            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 1, 1, pillAlpha * 0.7)
            love.graphics.print(pill.text, px + 8, py + (ph - ui.fontSmall:getHeight()) / 2)
        end
    end

    -- (Removed the ENTER prompt - UI uses buttons and mouse now)

    -- === MAIN MENU BUTTONS (Play / Settings / Exit) ===
    -- Buttons are stored in ui.menuButtons for click handling
    ui.menuButtons = ui.menuButtons or {}
    ui.menuButtons = {}
    if enterAlpha > 0 then
        local bw = 220
        local bh = 44
        local bx = cx - bw/2
        local by = h/2 + 80
        local gap = 14
            local labels = { {id='play', text='JUGAR'}, {id='profiles', text='PERFILES'}, {id='settings', text='CONFIGURACIÓN'}, {id='exit', text='SALIR'} }
        for i, btn in ipairs(labels) do
            local x = bx
            local y = by + (i-1) * (bh + gap)
            ui.menuButtons[#ui.menuButtons+1] = {id = btn.id, x=x, y=y, w=bw, h=bh}
            local isHover = (ui.menuHoverId == btn.id)
            local isPressed = (ui.menuPressedId == btn.id)
            local alpha = enterAlpha * 0.95
            local baseColor = {0.12, 0.12, 0.22}
            if isPressed then
                love.graphics.setColor(baseColor[1]*0.6, baseColor[2]*0.6, baseColor[3]*0.6, alpha)
            elseif isHover then
                love.graphics.setColor(baseColor[1]*0.8, baseColor[2]*0.8, baseColor[3]*0.8, alpha)
            else
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], alpha)
            end
            love.graphics.rectangle('fill', x, y, bw, bh, 8)
            love.graphics.setColor(1,1,1, enterAlpha)
            love.graphics.setFont(ui.fontNormal)
            love.graphics.printf(btn.text, x, y + (bh - ui.fontNormal:getHeight())/2, bw, 'center')
        end
    end
end

function ui.menuMousePressed(x, y)
    if not ui.menuButtons then return nil end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return b.id
        end
    end
    return nil
end

-- Hover / pressed visual state helpers
ui.menuHoverId = nil
ui.menuPressedId = nil

function ui.updateMenuHover(x,y)
    ui.menuHoverId = nil
    if not ui.menuButtons then return end
    for _, b in ipairs(ui.menuButtons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            ui.menuHoverId = b.id
            return
        end
    end
end

function ui.setMenuPressed(id)
    ui.menuPressedId = id
end

function ui.clearMenuPressed()
    ui.menuPressedId = nil
end

function ui.drawGrid(anchoGrilla, altoGrilla, time, comboIntensity)
    local tam = constants.TAMANIO_BLOQUE
    local w = anchoGrilla * tam
    local h = altoGrilla * tam

    local baseC = constants.COLOR_ACCENT
    local hotC = constants.COLOR_GRID_HOT_A

    local r = baseC[1] + (hotC[1] - baseC[1]) * comboIntensity
    local g = baseC[2] + (hotC[2] - baseC[2]) * comboIntensity
    local b = baseC[3] + (hotC[3] - baseC[3]) * comboIntensity
    local alpha = 0.15 + comboIntensity * 0.35

    love.graphics.setLineWidth(1)

    -- vertical lines
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

    -- horizontal lines
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

    -- outer border
    love.graphics.setColor(r, g, b, math.min(0.5, alpha + 0.2))
    love.graphics.rectangle("line", 0, 0, w, h)
end

-- Toasts API
ui.toasts = ui.toasts or {}
ui._toastQueue = ui._toastQueue or {}

-- Show a toast immediately (or enqueue). payload: {id, title, subtitle, reward}
function ui.showToast(payload)
    payload = payload or {}
    local t = {
        id = payload.id,
        title = payload.title or "LOGRO",
        subtitle = payload.subtitle or "",
        reward = payload.reward or "",
        t = 0,
        state = 'in' -- in, hold, out
    }
    table.insert(ui._toastQueue, t)
end

function ui.updateToasts(dt)
    if #ui._toastQueue == 0 then return end
    local first = ui._toastQueue[1]
    first.t = first.t + dt
    local fade = constants.TOAST_FADE
    local total = constants.TOAST_SHOW_DURATION + fade * 2
    if first.t >= total then
        table.remove(ui._toastQueue, 1)
        -- continue; next toast will start from t=0
    end
end

function ui.drawToasts()
    if #ui._toastQueue == 0 then return end
    local w = love.graphics.getWidth()
    local x = w / 2
    local y = 18
    local toast = ui._toastQueue[1]
    local fade = constants.TOAST_FADE
    local show = constants.TOAST_SHOW_DURATION
    local alpha = 1
    if toast.t < fade then
        alpha = toast.t / fade
    elseif toast.t > fade + show then
        alpha = math.max(0, 1 - (toast.t - (fade + show)) / fade)
    end

    love.graphics.setFont(ui.fontNormal)
    local titleH = ui.fontNormal:getHeight()
    local subtitleH = ui.fontSmall:getHeight()
    local rewardH = ui.fontSmall:getHeight()

    local contentW = math.max(ui.fontNormal:getWidth(toast.title), ui.fontSmall:getWidth(toast.subtitle), ui.fontSmall:getWidth(toast.reward))
    local boxW = math.min(constants.TOAST_MAX_WIDTH, contentW + constants.TOAST_ICON_SIZE + constants.TOAST_PADDING * 3)
    local boxH = constants.TOAST_PADDING + titleH + subtitleH + rewardH + constants.TOAST_PADDING/2
    local bx = x - boxW / 2
    -- slide animation: start slightly above and slide down by TOAST_SLIDE pixels
    local slideAmt = constants.TOAST_SLIDE or 12
    local by = y - slideAmt * (1 - alpha)

    -- background
    love.graphics.setColor(constants.TOAST_BG_COLOR[1], constants.TOAST_BG_COLOR[2], constants.TOAST_BG_COLOR[3], (constants.TOAST_BG_COLOR[4] or 0.95) * alpha)
    love.graphics.rectangle('fill', bx, by, boxW, boxH, 8)
    -- border (gold)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 0.9 * alpha)
    love.graphics.rectangle('line', bx, by, boxW, boxH, 8)

    local ix = bx + constants.TOAST_PADDING
    local iy = by + constants.TOAST_PADDING
    -- placeholder icon (circle)
    love.graphics.setColor(1,1,1,0.9 * alpha)
    love.graphics.circle('fill', ix + constants.TOAST_ICON_SIZE/2, iy + constants.TOAST_ICON_SIZE/2, constants.TOAST_ICON_SIZE/2)

    -- texts
    local tx = ix + constants.TOAST_ICON_SIZE + constants.TOAST_PADDING
    local ty = iy
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 1 * alpha)
    love.graphics.print(toast.title or "", tx, ty)
    ty = ty + titleH
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1,1,1,0.9 * alpha)
    love.graphics.print(toast.subtitle or "", tx, ty)
    ty = ty + subtitleH
    -- reward in light gray
    love.graphics.setColor(0.85,0.85,0.9, 0.9 * alpha)
    love.graphics.print(toast.reward or "", tx, ty)
end

function ui.drawHUD(puntuacion, highScore, monedas, shieldActive, magnetTimer, magnetDuration, baseSpeed, velocidadActual, comboCount, activeTimers, etapa, sala, objetivoSala, scale)
    --[[
    A J U S T E   D E   T A M A Ñ O
    scale = altoPantalla / 600
      - 600:  punto de referencia (la barra mide 28px a 600px de alto)
      - >1:   la barra crece (1080/600=1.8x en 1080p)
      - <1:   la barra se encoge (no ocurre porque 600 es el mínimo)

    Para cambiar la agresividad del escalado:
      - Cambia '600' por un número más bajo (ej: 400) → más grande
      - Cambia '600' por un número más alto  (ej: 800) → más pequeño
      - Pon scale=1 siempre → tamaño fijo sin importar resolución
    --]]
    local s = scale or 1

    -- Fuente escalada para que el texto crezca con la barra
    local fontSize = math.max(6, math.floor(constants.FONT_NORMAL * s))
    local font
    local ok = pcall(function() font = love.graphics.newFont(constants.FONT_FILE, fontSize) end)
    if not ok then
        font = love.graphics.newFont(fontSize)
    end
    love.graphics.setFont(font)

    local hh = constants.HUD_HEIGHT * s          -- alto total de la barra
    local fontH = font:getHeight()
    local cy = math.floor((hh - fontH) / 2)       -- centrado vertical del texto

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), hh)

    local x = 8 * s                               -- margen izquierdo

    -- Indicador de sala
    if etapa and sala then
        local roomText = etapa .. "-" .. sala
        local isBoss = sala == 5
        if isBoss then
            love.graphics.setColor(1, 0.3, 0.5)
        else
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
        end
        love.graphics.print(roomText, x, cy)
        x = x + font:getWidth(roomText) + 14 * s
    end

    love.graphics.setColor(1, 0.84, 0.0)
    love.graphics.print("$" .. monedas, x, cy)
    x = x + font:getWidth("$" .. monedas) + 14 * s

    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.print("" .. puntuacion, x, cy)
    x = x + font:getWidth("" .. puntuacion) + 14 * s

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

    if magnetTimer > 0 then
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
                love.graphics.rectangle("fill", x, barY, 20 * s * (t.remaining / 10), 6 * s, 2 * s, 2 * s)
                x = x + 26 * s
            end
        end
    end

    -- Restaurar fuente por defecto para el resto de la UI
    love.graphics.setFont(ui.fontNormal)
end

function ui.drawSlots(slotDisplay)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local slotW = 120
    local slotH = 26
    local gap = 8
    local totalW = slotW * 3 + gap * 2
    local startX = (w - totalW) / 2
    local y = h - slotH - 6

    love.graphics.setFont(ui.fontSmall)

    for i = 1, 3 do
        local x = startX + (i - 1) * (slotW + gap)
        local slot = slotDisplay[i]

        if slot then
            love.graphics.setColor(0.12, 0.12, 0.22, 0.85)
            love.graphics.rectangle("fill", x, y, slotW, slotH, 3)
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
            love.graphics.rectangle("line", x, y, slotW, slotH, 3)
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.print(i .. ".", x + 4, y + (slotH - ui.fontSmall:getHeight()) / 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(slot.name, x + 18, y + (slotH - ui.fontSmall:getHeight()) / 2)
        else
            love.graphics.setColor(0.12, 0.12, 0.22, 0.4)
            love.graphics.rectangle("fill", x, y, slotW, slotH, 3)
            love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
            love.graphics.rectangle("line", x, y, slotW, slotH, 3)
            love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
            love.graphics.print(i .. ".", x + 4, y + (slotH - ui.fontSmall:getHeight()) / 2)
        end
    end
end

function ui.addPopup(text, gridX, gridY)
    local tam = constants.TAMANIO_BLOQUE
    table.insert(ui.popups, {
        text = text,
        x = gridX * tam + tam / 2,
        y = gridY * tam,
        alpha = 1,
        timer = 0,
        scale = 0
    })
end

function ui.updatePopups(dt)
    for i = #ui.popups, 1, -1 do
        local p = ui.popups[i]
        p.timer = p.timer + dt
        p.y = p.y - constants.SCORE_POPUP_SPEED * dt
        p.alpha = 1 - (p.timer / constants.SCORE_POPUP_LIFETIME)
        -- scale-in rápido los primeros 0.1s
        p.scale = math.min(1.0, p.timer / 0.10)
        p.scale = p.scale * p.scale * (3 - 2 * p.scale)  -- smoothstep
        if p.alpha <= 0 then
            table.remove(ui.popups, i)
        end
    end
end

function ui.drawPopups()
    love.graphics.setFont(ui.fontNormal)
    for _, p in ipairs(ui.popups) do
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], p.alpha)
        local tw = ui.fontNormal:getWidth(p.text)
        local th = ui.fontNormal:getHeight()
        local cx = p.x
        local cy = p.y
        love.graphics.push()
        love.graphics.translate(cx, cy + th / 2)
        love.graphics.scale(p.scale, p.scale)
        love.graphics.translate(-cx, -(cy + th / 2))
        love.graphics.print(p.text, p.x - tw / 2, p.y)
        love.graphics.pop()
    end
end

function ui.drawComboFlash(time, comboCount, timer)
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

function ui.drawPauseOverlay()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(ui.fontTitle)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("PAUSA", 0, h / 2 - 30, w, "center")

    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("ESPACIO / ESC PARA CONTINUAR", 0, h / 2 + 10, w, "center")
end

-- Dungeon minimap (top-right corner)
function ui.drawDungeonMap(dungeonData)
    if not dungeonData then return end
    local w = love.graphics.getWidth()
    local mapW = 140
    local mapH = 100
    local mx = w - mapW - 8
    local my = 34
    local scaleX = mapW / dungeonData.virtualW
    local scaleY = mapH / dungeonData.virtualH

    -- Background
    love.graphics.setColor(0.06, 0.06, 0.10, 0.75)
    love.graphics.rectangle("fill", mx, my, mapW, mapH, 4)
    love.graphics.setColor(0.2, 0.2, 0.3, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mapW, mapH, 4)

    -- Corridors
    love.graphics.setColor(0.3, 0.3, 0.4, 0.4)
    for _, c in ipairs(dungeonData.corridors) do
        for _, pt in ipairs(c.path or {}) do
            love.graphics.rectangle("fill", mx + pt.x * scaleX, my + pt.y * scaleY, pt.w * scaleX, pt.h * scaleY)
        end
    end

    -- Rooms
    for _, r in ipairs(dungeonData.rooms) do
        local rx = mx + r.rect.x * scaleX
        local ry = my + r.rect.y * scaleY
        local rw = math.max(2, r.rect.w * scaleX)
        local rh = math.max(2, r.rect.h * scaleY)

        if r.current then
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.7)
        elseif r.cleared then
            love.graphics.setColor(0.3, 0.7, 0.3, 0.5)
        elseif r.visited then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
        else
            love.graphics.setColor(0.2, 0.2, 0.25, 0.3)
        end
        love.graphics.rectangle("fill", rx, ry, rw, rh, 2)

        if r.current then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", rx, ry, rw, rh, 2)
        end
    end
end

-- Debug dungeon overlay: draw full room rects and info
function ui.drawDebugDungeonOverlay(dungeonData)
    if not dungeonData then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local scaleX = w / dungeonData.virtualW
    local scaleY = h / dungeonData.virtualH
    love.graphics.setFont(ui.fontSmall)

    -- Corridors
    love.graphics.setColor(0.6, 0.6, 0.3, 0.15)
    for _, c in ipairs(dungeonData.corridors) do
        for _, pt in ipairs(c.path or {}) do
            love.graphics.rectangle("fill", pt.x * scaleX, pt.y * scaleY, pt.w * scaleX, pt.h * scaleY)
        end
    end

    -- Rooms
    for _, r in ipairs(dungeonData.rooms) do
        local rx = r.rect.x * scaleX
        local ry = r.rect.y * scaleY
        local rw = math.max(4, r.rect.w * scaleX)
        local rh = math.max(4, r.rect.h * scaleY)

        local color = r.current and {0, 0.85, 1, 0.3} or {0.3, 0.3, 0.5, 0.2}
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", rx, ry, rw, rh)
        love.graphics.setColor(0.8, 0.8, 0.8, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rx, ry, rw, rh)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(r.id .. ":" .. r.name, rx + 2, ry + 2)
    end

    -- Connections
    love.graphics.setColor(0, 0.85, 1, 0.3)
    for _, c in ipairs(dungeonData.corridors) do
        local ra = dungeonData.rooms[c.from]
        local rb = dungeonData.rooms[c.to]
        if ra and rb then
            love.graphics.line(ra.centerX * scaleX, ra.centerY * scaleY, rb.centerX * scaleX, rb.centerY * scaleY)
        end
    end
end

return ui

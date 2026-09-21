local settings = {}
local persistence = require('systems.persistence')
local helpers = require('core.helpers')
local settingsDraw = require('systems.settingsDraw')

-- State
settings.visible = false

settings.editing = nil
settings.lastSaved = nil
settings.activeTab = 'Audio'
settings.toastTimer = 0
settings.toastText = ''
settings.toastError = false
settings.dragState = nil
settings.openDropdown = nil
settings.g = {}
settings.PW = 500
settings.PH = 380
settings.previewTimer = 0
settings.previewOriginal = nil

-- Exposed for persistence
settings.audio = {}
settings.graphics = {}
settings.accessibility = {}

-- Helpers: LIVE vs HEAVY clasificacion (sin crear tablas por frame excesivo) ----
local world = require('core.world')

local function isLiveKey(k)
    return k == 'audio.master' or k == 'audio.music' or k == 'audio.sfx'
        or k == 'accessibility.uiScale' or k == 'accessibility.highContrast' or k == 'accessibility.colorblind'
        or k == 'gameplay.controlMode' or k == 'controls.controlMode'
        or k == 'graphics.filter'
end

local function isHeavyKey(k)
    return k == 'graphics.pixelScale' or k == 'graphics.fullscreen' or k == 'graphics.vsync'
end

local function applyLiveImmediate()
    if not settings.editing then return end
    pcall(function() persistence.applyLive(settings.editing) end)
end

local function applyLiveForKey(k)
    if isLiveKey(k) then
        applyLiveImmediate()
    end
end

-- Public API ----------------------------------------------------------------

function settings.open()
    local s = persistence.settings or persistence.loadSettings()
    settings.lastSaved = helpers.deep_copy(s)
    settings.editing = helpers.deep_copy(s)
    settings.activeTab = 'Audio'
    settings.openDropdown = nil
    settings.dragState = nil
    settings.visible = true
end

function settings.close()
    settings.visible = false
    settings.editing = nil
    settings.lastSaved = nil
    settings.activeTab = 'Audio'
    settings.toastTimer = 0
    settings.toastText = ''
    settings.toastError = false
    settings.dragState = nil
    settings.openDropdown = nil
    settings.g = {}
    settings.previewTimer = 0
    settings.previewOriginal = nil
end

function settings.update(dt)
    if settings.toastTimer > 0 then
        settings.toastTimer = settings.toastTimer - dt
        if settings.toastTimer < 0 then settings.toastTimer = 0 end
    end
    -- P05: resolutionConfirmTimer via core/timers pool (persistence._previewTimer)
    -- Sincronizar display desde handle pooled; fallback manual solo si no hay handle (tests)
    local hasHandle = persistence and persistence._previewTimer and persistence._previewTimer.active
    if hasHandle then
        local h = persistence._previewTimer
        local rem = (h.delay or 5) - (h.accum or 0)
        if rem > 0.01 then
            world.state.resolutionConfirmTimer = rem
        else
            world.state.resolutionConfirmTimer = nil
        end
    elseif world and world.state and world.state.resolutionConfirmTimer and type(world.state.resolutionConfirmTimer) == 'number' then
        -- Fallback legacy (tests sin timers)
        world.state.resolutionConfirmTimer = math.max(0, world.state.resolutionConfirmTimer - dt)
        if world.state.resolutionConfirmTimer <= 0 then
            world.state.resolutionConfirmTimer = nil
        end
    end
end

-- Main draw (rediseño cyberpunk cian, responsive, anti-overflow) -----------

function settings.draw()
    if not settings.visible then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    -- responsive sizing se calcula dentro de panelXY y sincroniza PW/PH
    local px, py = settingsDraw.panelXY(settings)
    settings.g = {}

    -- Dim background (oscurece juego detrás)
    love.graphics.setColor(0, 0, 0, 0.68)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Panel background doble borde cyber
    -- sombra exterior
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', px + 3, py + 4, settings.PW, settings.PH, 12)
    -- fondo panel oscuro translúcido
    love.graphics.setColor(0.07, 0.09, 0.15, 0.97)
    love.graphics.rectangle('fill', px, py, settings.PW, settings.PH, 12)
    -- matriz de puntos HUD #14 sutil (como menuUI) dentro del panel
    local gap = 16
    local t = love.timer.getTime()
    for pyy = py + 10, py + settings.PH - 10, gap do
        for pxx = px + 10, px + settings.PW - 10, gap do
            local dist = math.sqrt((pxx - (px + settings.PW / 2)) ^ 2 + (pyy - (py + settings.PH / 2)) ^ 2)
            local wave = math.sin(dist * 0.045 - t * 2.2)
            local a = (wave > 0.55) and 0.18 or 0.05
            love.graphics.setColor(0, 0.94, 1.0, a)
            love.graphics.rectangle('fill', pxx - 1, pyy - 1, 2, 2)
        end
    end
    -- borde outer negro 1px
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', px, py, settings.PW, settings.PH, 12)
    -- borde inner cyan glow 0.6
    love.graphics.setColor(0, 0.94, 1.0, 0.60)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle('line', px + 1.2, py + 1.2, settings.PW - 2.4, settings.PH - 2.4, 10)
    love.graphics.setLineWidth(1)
    -- glow externo sutil
    love.graphics.setColor(0, 0.94, 1.0, 0.14)
    love.graphics.rectangle('line', px - 2, py - 2, settings.PW + 4, settings.PH + 4, 14)

    -- Title + header línea glow cyan
    love.graphics.setColor(1, 1, 1)
    settingsDraw.setFont(settings, 'Large')
    love.graphics.printf('CONFIGURACIÓN', px + 18, py + 14, settings.PW - 70, 'left')
    -- subtítulo jerarquía tipográfica
    settingsDraw.setFont(settings, 'Small')
    love.graphics.setColor(0, 0.94, 1.0, 0.75)
    love.graphics.print('SISTEMA / AJUSTES', px + 18, py + 34)
    -- línea glow bajo header
    love.graphics.setColor(0, 0.94, 1.0, 0.85)
    love.graphics.rectangle('fill', px + 14, py + 46, settings.PW - 28, 1.6, 1)
    love.graphics.setColor(0, 0.94, 1.0, 0.18)
    love.graphics.rectangle('fill', px + 14, py + 47.5, settings.PW - 28, 6, 2)

    -- Close [X] cyber
    local cx = px + settings.PW - 36
    local cy = py + 12
    local mx, my = love.mouse.getPosition()
    local closeHover = mx and my and mx >= cx and mx <= cx + 24 and my >= cy and my <= cy + 24
    if closeHover then
        love.graphics.setColor(0, 0.94, 1.0, 0.22)
        love.graphics.rectangle('fill', cx - 2, cy - 2, 28, 28, 7)
    end
    love.graphics.setColor(closeHover and {0.85, 0.15, 0.18} or {0.62, 0.14, 0.16})
    love.graphics.rectangle('fill', cx, cy, 24, 24, 6)
    love.graphics.setColor(0, 0.94, 1.0, closeHover and 0.95 or 0.55)
    love.graphics.rectangle('line', cx, cy, 24, 24, 6)
    love.graphics.setColor(1, 1, 1)
    settingsDraw.setFont(settings, 'Normal')
    love.graphics.printf('X', cx, cy + 4, 24, 'center')
    settings.g.closeBtn = {cx, cy, 24, 24}

    -- Tabs e indicador activo subrayado cyan + hover pulse
    local tabs = {'Audio', 'Gráficos', 'Accesibilidad'}
    local tabW = math.floor((settings.PW - 44) / 3)
    local tabY = py + 56
    local tx = px + 22
    settings.g.tabs = {}
    for i, tname in ipairs(tabs) do
        local isActive = (tname == settings.activeTab)
        local isHover = mx and my and mx >= tx and mx <= tx + tabW and my >= tabY and my <= tabY + 30
        -- fondo tab
        if isActive then
            love.graphics.setColor(0.06, 0.14, 0.20, 1)
        else
            love.graphics.setColor(isHover and {0.12, 0.16, 0.24} or {0.10, 0.12, 0.16})
        end
        love.graphics.rectangle('fill', tx, tabY, tabW, 30, 7)
        -- borde
        if isActive then
            love.graphics.setColor(0, 0.94, 1.0, 0.92)
        else
            love.graphics.setColor(0, 0.94, 1.0, isHover and 0.45 or 0.18)
        end
        love.graphics.rectangle('line', tx, tabY, tabW, 30, 7)
        -- hover pulse glow
        if isHover and not isActive then
            local pulse = 0.5 + math.sin(love.timer.getTime() * 6 + i) * 0.35
            love.graphics.setColor(0, 0.94, 1.0, 0.16 * pulse)
            love.graphics.rectangle('line', tx - 1, tabY - 1, tabW + 2, 32, 8)
        end
        -- texto tab
        love.graphics.setColor(isActive and {1, 1, 1} or {0.70, 0.75, 0.82})
        settingsDraw.setFont(settings, 'Normal')
        love.graphics.printf(tname, tx, tabY + 7, tabW, 'center')
        -- indicador subrayado activo
        if isActive then
            love.graphics.setColor(0, 0.94, 1.0, 1)
            love.graphics.rectangle('fill', tx + 8, tabY + 27, tabW - 16, 2.5, 1)
            love.graphics.setColor(0, 0.94, 1.0, 0.28)
            love.graphics.rectangle('fill', tx + 6, tabY + 29, tabW - 12, 5, 2)
        end
        settings.g.tabs[#settings.g.tabs + 1] = {tx, tabY, tabW, 30, name = tname}
        tx = tx + tabW + 4
    end

    -- Content area con scissor si excede
    local contentX = px + 22
    local contentY = py + 98
    local by = py + settings.PH - 54
    local contentBottom = by - 12
    local contentH = contentBottom - contentY
    if contentH < 40 then contentH = 40 end
    local contentW = settings.PW - 44

    -- scissor pre-contenido (evita overflow vertical)
    local needScissor = contentH < 200 -- siempre scissor para garantizar recorte
    if needScissor then love.graphics.setScissor(contentX - 2, contentY - 2, contentW + 4, contentH + 4) end

    if settings.activeTab == 'Audio' then
        settingsDraw.drawAudioTab(settings, contentX, contentY, contentW)
    elseif settings.activeTab == 'Gráficos' then
        settingsDraw.drawGraphicsTab(settings, contentX, contentY, contentW)
    elseif settings.activeTab == 'Accesibilidad' then
        settingsDraw.drawAccessibilityTab(settings, contentX, contentY, contentW)
    end

    if needScissor then love.graphics.setScissor() end

    -- Bottom buttons (estilo Cyber-Step, Guardar deshabilitado gris si diff empty)
    local btnW = math.floor((settings.PW - 56) / 3)
    settings.g.resetBtn = {settingsDraw.drawButton(settings, px + 18, by, btnW, 34, 'Restablecer', {0.10, 0.22, 0.16})}
    settings.g.cancelBtn = {settingsDraw.drawButton(settings, px + 22 + btnW, by, btnW, 34, 'Cancelar', {0.38, 0.12, 0.14})}
    settings.g.saveBtn = {settingsDraw.drawButton(settings, px + 26 + btnW * 2, by, btnW, 34, 'Guardar', {0.08, 0.32, 0.22})}

    -- Dropdown list on top of everything (ya con clamp anti-overflow)
    if settings.openDropdown then
        settingsDraw.drawDropdownList(settings)
    end

    -- Toast badge cian slide
    if settings.toastTimer > 0 and settings.toastText then
        settingsDraw.drawToast(settings, w, h)
    end
end

-- Input handling en systems/settingsInput.lua (TD-5.1 split) ------------------
local settingsInputOk, settingsInput = pcall(require, "systems.settingsInput")
if settingsInputOk and settingsInput then
    settingsInput.attach(settings, {
        persistence = persistence,
        helpers = helpers,
        settingsDraw = settingsDraw,
        world = world,
        isLiveKey = isLiveKey,
        applyLiveForKey = applyLiveForKey,
    })
end

function settings.mousereleased(x, y, button)
    if button ~= 1 then return end
    settings.dragState = nil
end

function settings.mousemoved(x, y, dx, dy)
    if not settings.dragState or not settings.editing then return end
    local rel = math.max(0, math.min(1, (x - settings.dragState.bx) / settings.dragState.bw))
    if settings.dragState.type == 'master' then
        if settings.editing.audio then
            settings.editing.audio.master = rel
            pcall(function() persistence.applyLive(settings.editing) end)
        end
    elseif settings.dragState.type == 'uiScale' then
        if settings.editing.accessibility then
            local minS = settings.dragState.min or 0.8
            local maxS = settings.dragState.max or 1.5
            settings.editing.accessibility.uiScale = minS + rel * (maxS - minS)
            pcall(function() persistence.applyLive(settings.editing) end)
        end
    end
end

function settings.wheelmoved(dx, dy)
    if not settings.visible or not settings.openDropdown then return false end
    local dd = settings.openDropdown
    if not dd._needScroll then return false end
    local maxScroll = math.max(0, (dd._totalH or dd.h) - (dd._visibleH or dd.h))
    if maxScroll <= 0 then return false end
    dd.scrollY = math.max(0, math.min(maxScroll, (dd.scrollY or 0) - dy * 28))
    return true
end

function settings.keypressed(key)
    if not settings.visible then return false end
    if key == 'escape' then
        if settings.openDropdown then
            settings.openDropdown = nil
            return true
        end
        if settings.lastSaved then
            local diff = persistence.diffSettings(settings.lastSaved, settings.editing)
            settings.editing = helpers.deep_copy(settings.lastSaved)
            if diff.audio or diff.ui or diff.filter then
                pcall(function() persistence.applyLive(settings.lastSaved) end)
            end
            if diff.resolution and persistence._previewPrev then
                pcall(function() persistence.revertResolutionPreview() end)
            end
        end
        settings.close()
        return true
    end
    return false
end

return settings

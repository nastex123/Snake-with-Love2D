local persistence = {}
local sound = require('sound')
local ui = require('ui')
local shaders = require('shaders')
local helpers = require('helpers')

function persistence.init()
    love.filesystem.setIdentity("Snake_Brandon_IUB")
end

local settingsDefaults = {
    audio = { master = 1.0, music = true, sfx = true },
    controls = { inputType = 'autodetect', sensitivity = 1.0 },
    graphics = { pixelScale = 2, filter = 'nearest', fullscreen = false, vsync = true, resolution = { width = 800, height = 600 } },
    gameplay = { difficulty = 'normal', tutorials = true, tradeKill = true },
    accessibility = { uiScale = 1.0, highContrast = false, colorblind = 'off' }
}

function persistence.defaults()
    return helpers.deep_copy(settingsDefaults)
end

local function deep_merge(dest, src)
    for k, v in pairs(src) do
        if type(v) == 'table' then
            if type(dest[k]) ~= 'table' then dest[k] = {} end
            deep_merge(dest[k], v)
        else
            if dest[k] == nil then dest[k] = v end
        end
    end
    return dest
end

-- We save settings in Lua table format so that load() can read them directly
-- without any JSON-to-Lua conversion. This avoids fragility with gsub/load.

local function isIdentifier(s)
    return type(s) == 'string' and s:match('^[a-zA-Z_][a-zA-Z0-9_]*$')
end

local function lua_encode(val)
    local tv = type(val)
    if tv == 'number' then
        return tostring(val)
    elseif tv == 'boolean' then
        return val and 'true' or 'false'
    elseif tv == 'string' then
        local s = val:gsub('\\', '\\\\')
        s = s:gsub('"', '\\"')
        s = s:gsub('\n', '\\n')
        s = s:gsub('\r', '\\r')
        return '"' .. s .. '"'
    elseif tv == 'table' then
        local parts = {}
        -- Check if it's an array (consecutive integer keys starting at 1)
        local isArray, idx = true, 1
        for _ in pairs(val) do
            if val[idx] == nil then isArray = false; break end
            idx = idx + 1
        end
        if isArray then
            for i = 1, #val do
                parts[#parts + 1] = lua_encode(val[i])
            end
            return '{' .. table.concat(parts, ',') .. '}'
        else
            for k, v in pairs(val) do
                if isIdentifier(k) then
                    parts[#parts + 1] = tostring(k) .. '=' .. lua_encode(v)
                else
                    parts[#parts + 1] = '[' .. lua_encode(k) .. ']=' .. lua_encode(v)
                end
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    else
        return 'nil'
    end
end

local function lua_decode(text)
    if type(text) ~= 'string' or #text == 0 then return nil end
    local fn, err = load('return ' .. text)
    if not fn then return nil, err end
    local ok, res = pcall(fn)
    if not ok then return nil, res end
    return res
end

local settingsPath = 'config/settings.dat'

function persistence.loadSettings()
    if love.filesystem.getInfo(settingsPath) then
        local contents = love.filesystem.read(settingsPath)
        if contents and #contents > 0 then
            local decoded, err = lua_decode(contents)
            if decoded and type(decoded) == 'table' then
                deep_merge(decoded, settingsDefaults)
                persistence.settings = decoded
                return persistence.settings
            end
        end
    end
    persistence.settings = helpers.deep_copy(settingsDefaults)
    return persistence.settings
end

function persistence.saveSettings(tbl)
    local encoded = lua_encode(tbl)
    if type(encoded) ~= 'string' or #encoded == 0 then
        return false, 'encode failed'
    end
    local written, err = love.filesystem.write(settingsPath, encoded)
    if not written then
        pcall(function() love.filesystem.createDirectory('config') end)
        written, err = love.filesystem.write(settingsPath, encoded)
        if not written then return false, err end
    end
    persistence.settings = tbl
    return true
end

function persistence.applySettings(settings)
    if type(settings.audio) == 'table' then
        pcall(function() sound.setMasterVolume(settings.audio.master) end)
        pcall(function() sound.enableMusic(settings.audio.music) end)
        pcall(function() sound.enableSfx(settings.audio.sfx) end)
    end
    if type(settings.graphics) == 'table' then
        local g = settings.graphics
        pcall(function()
            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            if g.resolution and type(g.resolution.width) == 'number' and type(g.resolution.height) == 'number' then
                w, h = g.resolution.width, g.resolution.height
            end
            local dw, dh = love.window.getDesktopDimensions(1)
            if dw and dh and (w > dw or h > dh) and not g.fullscreen then
                w, h = math.min(w, dw), math.min(h, dh)
            end
            local ok2 = pcall(function()
                love.window.setMode(w, h, {fullscreen = g.fullscreen, vsync = g.vsync, fullscreentype = 'desktop'})
            end)
            if not ok2 then
                love.window.setMode(dw or 800, dh or 600, {fullscreen = g.fullscreen, vsync = g.vsync, fullscreentype = 'desktop'})
            end
        end)
        pcall(function() shaders.recreateCanvases(g.pixelScale, g.filter) end)
    end
    if type(settings.accessibility) == 'table' then
        local a = settings.accessibility
        pcall(function() ui.setScale(a.uiScale) end)
        pcall(function() ui.applyHighContrast(a.highContrast) end)
        pcall(function() ui.applyColorblind(a.colorblind) end)
    end
    persistence.settings = settings
end

function persistence.saveAndApply(tbl)
    local ok, err = persistence.saveSettings(tbl)
    if not ok then return false, err end
    persistence.applySettings(tbl)
    persistence.settings = tbl
    return true
end

function persistence.cargar()
    local f = 'highscore.txt'
    if love.filesystem.getInfo(f) then
        return tonumber(love.filesystem.read(f)) or 0
    end
    return 0
end

function persistence.guardar(puntajeActual, recordActual)
    if puntajeActual > recordActual then
        love.filesystem.write('highscore.txt', tostring(puntajeActual))
        return puntajeActual
    end
    return recordActual
end

return persistence

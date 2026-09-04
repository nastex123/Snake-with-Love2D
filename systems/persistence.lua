local persistence = {}
local sound = require('audio.sound')
local shaders = require('render.shaders')
local helpers = require('core.helpers')
local world = require('core.world')

function persistence.init()
    love.filesystem.setIdentity("Snake_Brandon_IUB")
end

local settingsDefaults = {
    audio = { master = 1.0, music = true, sfx = true },
    controls = { inputType = 'autodetect', sensitivity = 1.0, controlMode = 'tactical' },
    graphics = { pixelScale = 2, filter = 'linear', fullscreen = false, vsync = true, resolution = { width = 800, height = 600 } },
    gameplay = { difficulty = 'normal', tutorials = true, tradeKill = true, controlMode = 'tactical' },
    accessibility = { uiScale = 1.0, highContrast = false, colorblind = 'off' },
    logo = { offsetX = 0, offsetY = 0, scale = 6, spacing = 10, depth = 5 }
}

function persistence.getLogoConfig()
    if not persistence.settings then persistence.loadSettings() end
    if not persistence.settings.logo or type(persistence.settings.logo) ~= 'table' then
        persistence.settings.logo = helpers.deep_copy(settingsDefaults.logo)
    end
    return persistence.settings.logo
end

persistence.loadLogoConfig = persistence.getLogoConfig

function persistence.saveLogoConfig(cfg)
    if not persistence.settings then persistence.loadSettings() end
    if cfg and type(cfg) == 'table' then
        persistence.settings.logo = cfg
    elseif not persistence.settings.logo or type(persistence.settings.logo) ~= 'table' then
        persistence.settings.logo = helpers.deep_copy(settingsDefaults.logo)
    end
    return persistence.saveSettings(persistence.settings)
end

function persistence.defaults()
    return helpers.deep_copy(settingsDefaults)
end

local function deep_merge(dest, src)
    for k, v in pairs(src) do
        if type(v) == 'table' then
            if type(dest[k]) ~= 'table' then dest[k] = {} end
            deep_merge(dest[k], v)
        else
            if dest[k] == nil or type(dest[k]) ~= type(v) then
                dest[k] = v
            end
        end
    end
    return dest
end

-- We save settings in Lua table format so that load() can read them directly
-- without any JSON-to-Lua conversion. This avoids fragility with gsub/load.

local LUA_KEYWORDS = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true
}

local function isIdentifier(s)
    return type(s) == 'string' and s:match('^[a-zA-Z_][a-zA-Z0-9_]*$') and not LUA_KEYWORDS[s]
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
    if type(text) ~= 'string' or #text == 0 then return nil, "empty input" end
    if text:match('^%s*$') then return nil, "whitespace only" end
    local loader = loadstring or load
    local fn, err
    if _VERSION == "Lua 5.1" or (jit and type(setfenv) == "function") then
        fn, err = loader('return ' .. text)
        if fn then
            setfenv(fn, {}) -- empty sandbox environment
        end
    else
        fn, err = loader('return ' .. text, "=(safe_load)", "t", {})
    end
    if not fn then return nil, err end
    local ok, res = pcall(fn)
    if not ok then return nil, res end
    return res
end

-- Export encoding/decoding helpers for unit testing
persistence._lua_encode = lua_encode
persistence._lua_decode = lua_decode

local settingsPath = 'config/settings.dat'
local profilesPath = 'config/profiles.dat'

-- ============================================================
-- Profiles system (max 3 profiles, per-profile data)
-- ============================================================

local MAX_NAME_LENGTH = 14

function persistence.initProfiles()
    persistence.profilesData = nil
    if love.filesystem.getInfo(profilesPath) then
        local contents = love.filesystem.read(profilesPath)
        if contents and #contents > 0 then
            local decoded = lua_decode(contents)
            if decoded and type(decoded) == 'table' then
                persistence.profilesData = decoded
                if type(persistence.profilesData.profiles) ~= 'table' then
                    persistence.profilesData.profiles = {}
                end
                for k, p in pairs(persistence.profilesData.profiles) do
                    if type(k) ~= 'number' or k < 1 or k > 3 or type(p) ~= 'table' then
                        persistence.profilesData.profiles[k] = nil
                    else
                        p.name = (type(p.name) == 'string' and #p.name > 0) and p.name or ("Jugador " .. k)
                        p.monedas = (type(p.monedas) == 'number' and p.monedas >= 0) and p.monedas or 0
                        p.highScore = (type(p.highScore) == 'number' and p.highScore >= 0) and p.highScore or 0
                        p.achievements = type(p.achievements) == 'table' and p.achievements or {}
                        p.unlocks = type(p.unlocks) == 'table' and p.unlocks or {}
                        p.stats = type(p.stats) == 'table' and p.stats or {
                            kills = 0,
                            bossesKilled = 0,
                            highestStage = 1,
                            highestScore = 0,
                            totalCoins = 0,
                            highestStreak = 1.0
                        }
                    end
                end
                local act = persistence.profilesData.activeProfileIndex
                if act and (type(act) ~= 'number' or act < 1 or act > 3 or not persistence.profilesData.profiles[act]) then
                    persistence.profilesData.activeProfileIndex = nil
                    for i = 1, 3 do
                        if persistence.profilesData.profiles[i] then
                            persistence.profilesData.activeProfileIndex = i
                            break
                        end
                    end
                end
                return
            end
        end
    end
    persistence.profilesData = {
        version = 1,
        activeProfileIndex = nil,
        profiles = {}
    }
end

function persistence.saveProfiles()
    if not persistence.profilesData then return true end
    local encoded = lua_encode(persistence.profilesData)
    if type(encoded) ~= 'string' or #encoded == 0 then
        return false, 'encode failed'
    end
    local written, err = love.filesystem.write(profilesPath, encoded)
    if not written then
        pcall(function() love.filesystem.createDirectory('config') end)
        written, err = love.filesystem.write(profilesPath, encoded)
        if not written then return false, err end
    end
    return true
end

function persistence.getProfiles()
    if not persistence.profilesData or type(persistence.profilesData.profiles) ~= 'table' then
        return {}
    end
    return persistence.profilesData.profiles
end

function persistence.getActiveProfile()
    local idx = persistence.getActiveProfileIndex()
    if idx and persistence.profilesData and persistence.profilesData.profiles then
        local p = persistence.profilesData.profiles[idx]
        if p then return p end
    end
    return nil
end

function persistence.getActiveProfileIndex()
    if not persistence.profilesData then return nil end
    local idx = persistence.profilesData.activeProfileIndex
    if idx and type(idx) == 'number' and idx >= 1 and idx <= 3 then
        if persistence.profilesData.profiles and persistence.profilesData.profiles[idx] then
            return idx
        end
    end
    return nil
end

function persistence.createProfile(name)
    if not persistence.profilesData then persistence.initProfiles() end
    local profiles = persistence.profilesData.profiles
    for i = 1, 3 do
        if profiles[i] == nil then
            local cleanName = name
            if cleanName then
                cleanName = tostring(cleanName):gsub("^%s*(.-)%s*$", "%1")
                if #cleanName > MAX_NAME_LENGTH then cleanName = cleanName:sub(1, MAX_NAME_LENGTH) end
            end
            if not cleanName or #cleanName == 0 then
                cleanName = "Jugador " .. i
            end
            profiles[i] = {
                name = cleanName,
                createdAt = os.time(),
                monedas = 0,
                highScore = 0,
                achievements = {},
                unlocks = {},
                stats = {
                    kills = 0,
                    bossesKilled = 0,
                    highestStage = 1,
                    highestScore = 0,
                    totalCoins = 0,
                    highestStreak = 1.0
                }
            }
            persistence.profilesData.activeProfileIndex = i
            persistence.saveProfiles()
            return true, nil, i
        end
    end
    return false, "Máximo 3 perfiles alcanzado", nil
end

function persistence.selectProfile(index)
    if not persistence.profilesData then persistence.initProfiles() end
    if type(index) ~= 'number' or index < 1 or index > 3 then
        return false, "Índice inválido"
    end
    if not persistence.profilesData.profiles[index] then
        return false, "Perfil vacío"
    end
    persistence.profilesData.activeProfileIndex = index
    persistence.saveProfiles()
    return true, nil, persistence.profilesData.profiles[index]
end

function persistence.renameProfile(index, newName)
    if not persistence.profilesData then persistence.initProfiles() end
    if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
    local profile = persistence.profilesData.profiles[index]
    if not profile then return false, "Perfil vacío" end
    local cleanName = newName and tostring(newName):gsub("^%s*(.-)%s*$", "%1") or ""
    if #cleanName > MAX_NAME_LENGTH then cleanName = cleanName:sub(1, MAX_NAME_LENGTH) end
    if #cleanName == 0 then cleanName = "Jugador " .. index end
    profile.name = cleanName
    persistence.saveProfiles()
    return true
end

function persistence.deleteProfile(index)
    if not persistence.profilesData then persistence.initProfiles() end
    if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
    if not persistence.profilesData.profiles or not persistence.profilesData.profiles[index] then
        return false, "Perfil vacío"
    end
    persistence.profilesData.profiles[index] = nil
    if persistence.profilesData.activeProfileIndex == index then
        local found = false
        for i = 1, 3 do
            if persistence.profilesData.profiles[i] ~= nil then
                persistence.profilesData.activeProfileIndex = i
                found = true
                break
            end
        end
        if not found then
            persistence.profilesData.activeProfileIndex = nil
        end
    end
    persistence.saveProfiles()
    return true
end

function persistence.resetProfile(index)
    if not persistence.profilesData then persistence.initProfiles() end
    if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
    local old = persistence.profilesData.profiles[index]
    if not old then return false, "Perfil vacío" end
    persistence.profilesData.profiles[index] = {
        name = old.name,
        createdAt = os.time(),
        monedas = 0,
        highScore = 0,
        achievements = {},
        unlocks = {},
        stats = {
            kills = 0,
            bossesKilled = 0,
            highestStage = 1,
            highestScore = 0,
            totalCoins = 0,
            highestStreak = 1.0
        }
    }
    persistence.saveProfiles()
    return true
end

function persistence.syncActiveProfile()
    local profile = persistence.getActiveProfile()
    if not profile then return false end
    if world and world.get then
        local wMonedas = world.get("monedas")
        if type(wMonedas)=="number" and wMonedas==wMonedas and wMonedas>=0 then profile.monedas = math.floor(wMonedas) end
        local wHighScore = world.get("highScore")
        if type(wHighScore)=="number" and wHighScore==wHighScore and wHighScore>=0 then profile.highScore = math.floor(wHighScore) end
        profile.stats = profile.stats or {}
        local curStreak = world.get("highestStreak") or 1.0
        profile.stats.highestStreak = math.max(profile.stats.highestStreak or 1.0, curStreak)
        local curHighScore = world.get("highScore") or profile.highScore or 0
        profile.stats.highestScore = math.max(profile.stats.highestScore or 0, curHighScore)
        profile.stats.totalCoins = math.max(profile.stats.totalCoins or 0, profile.monedas)
    end
    persistence.saveProfiles()
    return true
end

function persistence.syncUnlocks(unlocksTable)
    local profile = persistence.getActiveProfile()
    if not profile then return false end
    local helpers = require("core.helpers")
    profile.unlocks = helpers.deep_copy(unlocksTable or {})
    persistence.saveProfiles()
    return true
end

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
    tbl = tbl or persistence.settings or persistence.defaults()
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

local function _graphicsDiff(a, b)
    if not a or not b then return true end
    if a.pixelScale ~= b.pixelScale then return true end
    if a.filter ~= b.filter then return true end
    if a.fullscreen ~= b.fullscreen then return true end
    if a.vsync ~= b.vsync then return true end
    local ra, rb = a.resolution, b.resolution
    if (ra == nil) ~= (rb == nil) then return true end
    if ra and rb then
        if ra.width ~= rb.width or ra.height ~= rb.height then return true end
    end
    return false
end

local function _audioDiff(a, b)
    if not a or not b then return true end
    if a.master ~= b.master then return true end
    if a.music ~= b.music then return true end
    if a.sfx ~= b.sfx then return true end
    return false
end

-- Helpers internos LIVE / HEAVY  (selective apply sin recargas)
local function _applyAudio(tbl)
    if not tbl or type(tbl.audio) ~= 'table' then return end
    pcall(function() sound.setMasterVolume(tbl.audio.master) end)
    pcall(function() sound.enableMusic(tbl.audio.music) end)
    pcall(function() sound.enableSfx(tbl.audio.sfx) end)
end

local function _applyFilter(filter)
    if not filter then return end
    pcall(function()
        if shaders and shaders.setFilter then
            shaders.setFilter(filter)
        else
            local canv = shaders.getCanvases and shaders.getCanvases()
            if canv then
                for _, c in pairs(canv) do
                    if c and c.setFilter then pcall(function() c:setFilter(filter, filter) end) end
                end
            end
        end
    end)
end

local function _applyUI(tbl)
    if not tbl then return end
    if type(tbl.accessibility) == 'table' then
        local a = tbl.accessibility
        local ok, ui = pcall(require, 'ui.ui')
        if ok and ui then
            pcall(function() ui.setScale(a.uiScale) end)
            pcall(function() ui.applyHighContrast(a.highContrast) end)
            pcall(function() ui.applyColorblind(a.colorblind) end)
        end
    end
    if type(tbl.gameplay) == 'table' and tbl.gameplay.controlMode then
        world.state.controlMode = tbl.gameplay.controlMode
    elseif type(tbl.controls) == 'table' and tbl.controls.controlMode then
        world.state.controlMode = tbl.controls.controlMode
    else
        world.state.controlMode = 'tactical'
    end
end

local function _recalcGrid()
    pcall(function()
        local ok, gameflow = pcall(require, "systems.gameflow")
        if ok and gameflow and gameflow.recalcularGrilla then
            gameflow.recalcularGrilla()
        end
    end)
end

local function _applyHeavy(tbl, oldTbl)
    if not tbl or type(tbl.graphics) ~= 'table' then return end
    local g = tbl.graphics
    pcall(function()
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        if g.resolution and type(g.resolution.width) == 'number' and type(g.resolution.height) == 'number' then
            w, h = g.resolution.width, g.resolution.height
        elseif g.resolution == nil then
            w, h = love.graphics.getWidth(), love.graphics.getHeight()
        end
        local dw, dh = love.window.getDesktopDimensions(1)
        if dw and dh and (w > dw or h > dh) and not g.fullscreen then
            w, h = math.min(w, dw), math.min(h, dh)
        end
        local ok2 = pcall(function()
            love.window.setMode(w, h, {fullscreen = g.fullscreen, vsync = g.vsync, fullscreentype = 'desktop'})
        end)
        if not ok2 and dw and dh then
            pcall(function() love.window.setMode(dw or 800, dh or 600, {fullscreen = g.fullscreen, vsync = g.vsync, fullscreentype = 'desktop'}) end)
        end
    end)
    pcall(function()
        if not shaders then return end
        local need = true
        if shaders.needsRecreate and oldTbl and oldTbl.graphics and tbl.graphics then
            need = shaders.needsRecreate(oldTbl.graphics, tbl.graphics)
        elseif oldTbl and oldTbl.graphics then
            local pg = oldTbl.graphics
            local eq = (pg.pixelScale == g.pixelScale and pg.fullscreen == g.fullscreen and pg.vsync == g.vsync)
            local ra, rb = pg.resolution, g.resolution
            local resEq = false
            if ra == rb then resEq = true elseif ra == nil and rb == nil then resEq = true elseif ra and rb and ra.width == rb.width and ra.height == rb.height then resEq = true end
            if eq and resEq and pg.filter == g.filter then need = false end
            if pg.filter ~= g.filter and eq and resEq then need = false end
        end
        if need and shaders.recreateCanvases then
            shaders.recreateCanvases(g.pixelScale, g.filter)
        elseif not need and g.filter then
            _applyFilter(g.filter)
        end
    end)
    _recalcGrid()
end

function persistence.applyAudio(tbl) _applyAudio(tbl) end
function persistence.applyUI(tbl) _applyUI(tbl) end
function persistence.applyHeavy(tbl, oldTbl) _applyHeavy(tbl, oldTbl) end
function persistence.applyFilter(filter) _applyFilter(filter) end

function persistence.applyLive(tbl)
    if not tbl or type(tbl) ~= 'table' then return end
    _applyAudio(tbl)
    _applyUI(tbl)
    if tbl.graphics and tbl.graphics.filter then
        _applyFilter(tbl.graphics.filter)
    end
end

function persistence.diffSettings(a, b)
    if not a or not b or type(a) ~= 'table' or type(b) ~= 'table' then
        return {audio = false, ui = false, heavy = false, filter = false, resolution = false, empty = true}
    end
    local d = {audio = false, ui = false, heavy = false, filter = false, resolution = false, empty = true}
    local aa = a.audio or {}
    local ba = b.audio or {}
    if aa.master ~= ba.master or aa.music ~= ba.music or aa.sfx ~= ba.sfx then d.audio = true end
    local aAcc = a.accessibility or {}
    local bAcc = b.accessibility or {}
    if aAcc.uiScale ~= bAcc.uiScale or aAcc.highContrast ~= bAcc.highContrast or aAcc.colorblind ~= bAcc.colorblind then d.ui = true end
    local aCM = (a.gameplay and a.gameplay.controlMode) or (a.controls and a.controls.controlMode)
    local bCM = (b.gameplay and b.gameplay.controlMode) or (b.controls and b.controls.controlMode)
    if aCM ~= bCM then d.ui = true end
    local aG = a.graphics or {}
    local bG = b.graphics or {}
    if aG.filter ~= bG.filter then d.filter = true end
    if aG.pixelScale ~= bG.pixelScale or aG.fullscreen ~= bG.fullscreen or aG.vsync ~= bG.vsync then d.heavy = true end
    local aRes = aG.resolution
    local bRes = bG.resolution
    local resEq = false
    if aRes == bRes then resEq = true
    elseif aRes == nil and bRes == nil then resEq = true
    elseif aRes == nil or bRes == nil then resEq = false
    elseif type(aRes) == 'table' and type(bRes) == 'table' and aRes.width == bRes.width and aRes.height == bRes.height then resEq = true end
    if not resEq then d.resolution = true end
    d.empty = not (d.audio or d.ui or d.heavy or d.filter or d.resolution)
    return d
end

function persistence.needsHeavy(diff)
    return diff and diff.heavy == true
end

function persistence.applySettingsSelective(last, cur)
    if not cur or type(cur) ~= 'table' then return end
    if not last or type(last) ~= 'table' then
        persistence.applySettings(cur)
        return
    end
    local diff = persistence.diffSettings(last, cur)
    if diff.empty then return end
    if diff.audio or diff.ui or diff.filter then
        persistence.applyLive(cur)
    end
    if diff.heavy or diff.resolution then
        _applyHeavy(cur, last)
    end
    persistence.settings = cur
end

function persistence.saveAndApplySelective(last, cur)
    if not cur or type(cur) ~= 'table' then return false, 'no settings' end
    if not last or type(last) ~= 'table' then last = persistence.settings or persistence.defaults() end
    local diff = persistence.diffSettings(last, cur)
    if diff.empty then return false, 'no_changes' end
    local ok, err = persistence.saveSettings(cur)
    if not ok then return false, err end
    if diff.audio or diff.ui or diff.filter then
        persistence.applyLive(cur)
    end
    if diff.heavy or diff.resolution then
        _applyHeavy(cur, last)
    end
    if diff.resolution and persistence._previewTimer then
        persistence.confirmResolutionPreview()
    end
    persistence.settings = cur
    return true
end

persistence._previewPrev = nil
persistence._previewTimer = nil

function persistence.previewResolution(newRes)
    if not newRes or type(newRes) ~= 'table' or not newRes.width or not newRes.height then
        return false
    end
    local g = persistence.settings and persistence.settings.graphics or {fullscreen = false, vsync = true, pixelScale = 2, filter = 'linear'}
    local curW, curH = love.graphics.getWidth(), love.graphics.getHeight()
    if not persistence._previewPrev then
        persistence._previewPrev = {width = curW, height = curH}
    end
    if persistence._previewTimer then
        pcall(function() persistence._previewTimer:cancel() end)
        persistence._previewTimer = nil
    end
    local fullscreen = g.fullscreen
    local vsync = g.vsync
    if vsync == nil then vsync = true end
    pcall(function()
        love.window.setMode(newRes.width, newRes.height, {fullscreen = fullscreen, vsync = vsync, fullscreentype = 'desktop'})
    end)
    pcall(function()
        if shaders and shaders.recreateCanvases then
            shaders.recreateCanvases(g.pixelScale, g.filter)
        end
    end)
    pcall(function()
        local ok, gf = pcall(require, 'systems.gameflow')
        if ok and gf and gf.recalcularGrilla then gf.recalcularGrilla() end
    end)
    world.state.resolutionConfirmTimer = 5
    local okT, timersMod = pcall(require, 'core.timers')
    if okT and timersMod and timersMod.after then
        persistence._previewTimer = timersMod.after(5, function()
            persistence.revertResolutionPreview()
        end)
    end
    return true
end

function persistence.confirmResolutionPreview()
    if persistence._previewTimer then
        pcall(function() persistence._previewTimer:cancel() end)
        persistence._previewTimer = nil
    end
    persistence._previewPrev = nil
    world.state.resolutionConfirmTimer = nil
end

function persistence.revertResolutionPreview()
    if persistence._previewTimer then
        pcall(function() persistence._previewTimer:cancel() end)
        persistence._previewTimer = nil
    end
    if persistence._previewPrev then
        local prev = persistence._previewPrev
        local g = persistence.settings and persistence.settings.graphics or {fullscreen = false, vsync = true, pixelScale = 2, filter = 'linear'}
        local fullscreen = g.fullscreen
        local vsync = g.vsync
        if vsync == nil then vsync = true end
        pcall(function()
            love.window.setMode(prev.width, prev.height, {fullscreen = fullscreen, vsync = vsync, fullscreentype = 'desktop'})
        end)
        pcall(function()
            if shaders and shaders.recreateCanvases then
                shaders.recreateCanvases(g.pixelScale, g.filter)
            end
        end)
        pcall(function()
            local ok, gf = pcall(require, 'systems.gameflow')
            if ok and gf and gf.recalcularGrilla then gf.recalcularGrilla() end
        end)
        persistence._previewPrev = nil
        pcall(function()
            local sMod = require('systems.settings')
            local sDraw = require('systems.settingsDraw')
            if sMod and sMod.visible and sMod.editing and sMod.lastSaved then
                if sMod.lastSaved.graphics and sMod.lastSaved.graphics.resolution then
                    sMod.editing.graphics.resolution = helpers.deep_copy(sMod.lastSaved.graphics.resolution)
                elseif persistence.settings and persistence.settings.graphics and persistence.settings.graphics.resolution then
                    sMod.editing.graphics.resolution = helpers.deep_copy(persistence.settings.graphics.resolution)
                else
                    sMod.editing.graphics.resolution = nil
                end
                sDraw.showToast(sMod, 'Resolución revertida', true)
            end
        end)
    end
    world.state.resolutionConfirmTimer = nil
end

function persistence.applySettings(settings, opts)
    if not settings or type(settings) ~= 'table' then return end
    if opts and type(opts) == 'table' then
        if opts.liveOnly then
            persistence.applyLive(settings)
            persistence.settings = settings
            return
        end
        if opts.heavy == false then
            persistence.applyLive(settings)
            persistence.settings = settings
            return
        end
        if opts.heavy == true then
            persistence.applyLive(settings)
            _applyHeavy(settings, nil)
            persistence.settings = settings
            return
        end
    end
    local prev = persistence.settings
    if type(settings.audio) == 'table' then
        if not prev or not prev.audio or _audioDiff(settings.audio, prev.audio) then
            _applyAudio(settings)
        end
    end
    if type(settings.graphics) == 'table' then
        local g = settings.graphics
        local pg = prev and prev.graphics
        local filterOnly = false
        if pg and g.filter ~= pg.filter and g.pixelScale == pg.pixelScale and g.fullscreen == pg.fullscreen and g.vsync == pg.vsync then
            local ra, rb = pg.resolution, g.resolution
            local resEq = false
            if ra == rb then resEq = true elseif ra == nil and rb == nil then resEq = true elseif ra and rb and ra.width == rb.width and ra.height == rb.height then resEq = true end
            if resEq then filterOnly = true end
        end
        if filterOnly then
            _applyFilter(g.filter)
        else
            local needsHeavy = not prev or not prev.graphics or _graphicsDiff(g, prev.graphics)
            if needsHeavy then
                _applyHeavy(settings, prev)
            end
        end
    end
    _applyUI(settings)
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
        local content = love.filesystem.read(f)
        return tonumber(content) or 0
    end
    return 0
end

function persistence.guardar(puntajeActual, recordActual)
    puntajeActual = puntajeActual or 0
    recordActual = recordActual or 0
    if puntajeActual > recordActual then
        love.filesystem.write('highscore.txt', tostring(puntajeActual))
        return puntajeActual
    end
    return recordActual
end

-- P06 Event Bus wiring (sin circular: Events no requiere persistence)
local okEvents, Events = pcall(require, "core.events")
if okEvents and Events and Events.on then
    Events.on("coinsChanged", function() pcall(function() persistence.syncActiveProfile() end) end)
    Events.on("scoreReached", function() pcall(function() persistence.syncActiveProfile() end) end)
    Events.on("stageChanged", function() pcall(function() persistence.syncActiveProfile() end) end)
    Events.on("profileDirty", function() pcall(function() persistence.syncActiveProfile() end) end)
    Events.on("unlocksDirty", function(payload) pcall(function() persistence.syncUnlocks(payload and payload.unlocks) end) end)
end

return persistence

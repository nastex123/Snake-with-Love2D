local persistence = {}
local sound = require('audio.sound')
local shaders = require('render.shaders')
local helpers = require('core.helpers')
local world = require('core.world')

function persistence.init()
    love.filesystem.setIdentity("Snake_Brandon_IUB")
end

local PSettings = require("systems.persistenceSettings")
local settingsDefaults = PSettings.defaultsTable

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

persistence.defaults = PSettings.defaults
local deep_merge = PSettings.deep_merge

-- We save settings in Lua table format so that load() can read them directly
-- without any JSON-to-Lua conversion. This avoids fragility with gsub/load.

local Codec = require("systems.persistenceCodec")

local function lua_encode(val) return Codec.encode(val) end
local function lua_decode(text) return Codec.decode(text) end
persistence._lua_encode = Codec.encode
persistence._lua_decode = Codec.decode

local settingsPath = 'config/settings.dat'
local profilesPath = 'config/profiles.dat'
local SCHEMA_VERSION = 3
local profileSchemaOk, profileSchema = pcall(require, "systems.profileSchema")

local function atomicWrite(path, data) return Codec.atomicWrite(path, data) end

-- ============================================================
-- Profiles system (max 3 profiles, per-profile data)
-- ============================================================

local MAX_NAME_LENGTH = 14

-- CRUD de perfiles en systems/persistenceProfiles.lua (AUD-3 split)

local ProfilesSub = require("systems.persistenceProfiles")
ProfilesSub.attach(persistence, {
    profilesPath = profilesPath,
    SCHEMA_VERSION = SCHEMA_VERSION,
    MAX_NAME_LENGTH = MAX_NAME_LENGTH,
    encode = lua_encode,
    decode = lua_decode,
    atomicWrite = atomicWrite,
    helpers = helpers,
    world = world,
    profileSchema = profileSchemaOk and profileSchema or nil,
    profileSchemaOk = profileSchemaOk,
})

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

local _graphicsDiff = PSettings.graphicsDiff
local _audioDiff = PSettings.audioDiff

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
        if love and love.graphics and love.graphics.setDefaultFilter then
            love.graphics.setDefaultFilter(filter, filter)
        end
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
    world.state.controlMode = 'classic'
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
        local curW, curH = love.graphics.getWidth(), love.graphics.getHeight()
        local w, h = curW, curH
        if g.resolution and type(g.resolution.width) == 'number' and type(g.resolution.height) == 'number' then
            w, h = g.resolution.width, g.resolution.height
        end
        local dw, dh = love.window.getDesktopDimensions(1)
        if dw and dh and (w > dw or h > dh) and not g.fullscreen then
            w, h = math.min(w, dw), math.min(h, dh)
        end
        local needsModeChange = (curW ~= w or curH ~= h)
        if oldTbl and oldTbl.graphics then
            if oldTbl.graphics.fullscreen ~= g.fullscreen or oldTbl.graphics.vsync ~= g.vsync then
                needsModeChange = true
            end
        else
            needsModeChange = true
        end
        if needsModeChange then
            local ok2 = pcall(function()
                love.window.setMode(w, h, {fullscreen = g.fullscreen, vsync = g.vsync, fullscreentype = 'desktop'})
            end)
            if not ok2 and dw and dh then
                pcall(function() love.window.setMode(dw or 800, dh or 600, {fullscreen = g.fullscreen, vsync = g.vsync, fullscreentype = 'desktop'}) end)
            end
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
    local g = persistence.settings and persistence.settings.graphics or {fullscreen = false, vsync = true, pixelScale = 1, filter = 'linear'}
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
        local g = persistence.settings and persistence.settings.graphics or {fullscreen = false, vsync = true, pixelScale = 1, filter = 'linear'}
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
    Events.on("talentsDirty", function(payload) pcall(function() persistence.syncTalents(payload and payload.talents) end) end)
    Events.on("modeSkinDirty", function(payload) pcall(function() persistence.syncModeSkin(payload and payload.modo, payload and payload.skin) end) end)
    Events.on("bountiesDirty", function(payload) pcall(function() persistence.syncBounties(payload and payload.history) end) end)
    Events.on("codexDirty", function() pcall(function() persistence.syncCodex() end) end)
    Events.on("dailyDirty", function(payload) pcall(function() persistence.syncDailyHistory(payload and payload.entry) end) end)
end

return persistence

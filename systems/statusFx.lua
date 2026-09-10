-- systems/statusFx.lua — Status Effects Engine (GDD §16, TDD §10.31)
-- Micro-estados temporales data-driven: overdrive, medusa, venom, cryo.
-- Estado en World.state.statusFx (mapa id->true); temporizadores pooled con
-- entrada HUD en st.activeTimers (id "status_<id>").
local statusFx = {}
local constants = require("constants")
local world = require("core.world")
local timers = require("core.timers")
local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end

statusFx.STATUS_DEFS = {
    overdrive = {label = "OVERDRIVE", color = {1.0, 0.84, 0.2}},
    medusa = {label = "MEDUSA", color = {0.6, 0.6, 0.65}},
    venom = {label = "VENENO", color = {0.3, 1.0, 0.3}},
    cryo = {label = "CRIO", color = {0.5, 0.9, 1.0}},
}

local function timerId(id) return "status_" .. tostring(id) end

local function findDef(id)
    return statusFx.STATUS_DEFS[id]
end

function statusFx.getActive()
    local st = world.state
    if type(st.statusFx) ~= "table" then st.statusFx = {} end
    return st.statusFx
end

function statusFx.has(id)
    if not findDef(id) then return false end
    return statusFx.getActive()[id] == true
end

function statusFx.durationFor(id)
    if id == "overdrive" then return constants.STATUS_OVERDRIVE_DURATION or 4.0 end
    if id == "medusa" then return constants.STATUS_MEDUSA_DURATION or 2.0 end
    if id == "venom" then return constants.STATUS_VENOM_DURATION or 1.8 end
    if id == "cryo" then return constants.STATUS_CRYO_DURATION or 2.5 end
    return 0
end

-- Aplica el estado y agenda su limpieza; refresca si ya estaba activo
function statusFx.apply(id, duration)
    if not findDef(id) then return false end
    local st = world.state
    st.activeTimers = st.activeTimers or {}
    statusFx.getActive()[id] = true
    local ok, playerMod = pcall(require, "systems.player")
    if ok and playerMod and playerMod.addOrRefreshTimer then
        playerMod.addOrRefreshTimer(st, timerId(id), duration or statusFx.durationFor(id), function()
            if world.state.statusFx then world.state.statusFx[id] = nil end
        end)
    else
        if Log then Log.warn("statusFx sin player.addOrRefreshTimer para " .. tostring(id)) end
    end
    return true
end

function statusFx.clear(id)
    if world.state.statusFx then world.state.statusFx[id] = nil end
    local ok, playerMod = pcall(require, "systems.player")
    if ok and playerMod and playerMod.clearActiveTimer then
        playerMod.clearActiveTimer(timerId(id), false)
    end
end

function statusFx.clearAll()
    for id in pairs(statusFx.getActive()) do statusFx.clear(id) end
    world.state.statusFx = {}
end

-- Decide y aplica overdrive segun combo display; retorna applied, fresh
function statusFx.checkOverdrive(comboDisplay)
    if (comboDisplay or 0) >= (constants.STATUS_OVERDRIVE_COMBO or 6) then
        local fresh = not statusFx.has("overdrive")
        statusFx.apply("overdrive")
        return true, fresh
    end
    return false, false
end

-- Producto de multiplicadores de intervalo de paso (hook de player.calcSpeed)
function statusFx.speedMult()
    local m = 1.0
    if statusFx.has("overdrive") then m = m * (constants.STATUS_OVERDRIVE_SPEED_MULT or 0.8) end
    if statusFx.has("cryo") then m = m * (constants.STATUS_CRYO_SLOW_MULT or 1.43) end
    return m
end

return statusFx

local Timers = {}
local world = require("core.world")
local timers = require("core.timers")
local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end
function Timers.addOrRefreshTimer(st, timerId, duration, onEndFn)
    duration = math.max(0, duration or 0)
    for _, t in ipairs(st.activeTimers) do
        if t.id == timerId then
            if t._handle then timers.cancel(t._handle) end
            t.duration = duration
            t.remaining = duration
            t.onEnd = onEndFn
            local handle = timers.after(duration, function()
                for i = #st.activeTimers, 1, -1 do
                    if st.activeTimers[i].id == timerId and st.activeTimers[i] == t then
                        table.remove(st.activeTimers, i)
                        break
                    end
                end
                if onEndFn then
                    local ok, err = pcall(onEndFn)
                    if not ok and Log and Log.error then Log.error("onEnd error [" .. timerId .. "]:", tostring(err)) end
                end
            end)
            t._handle = handle
            return t
        end
    end
    local entry = {id = timerId, duration = duration, remaining = duration, onEnd = onEndFn, _handle = nil}
    local handle = timers.after(duration, function()
        for i = #st.activeTimers, 1, -1 do
            if st.activeTimers[i].id == timerId and st.activeTimers[i] == entry then
                table.remove(st.activeTimers, i)
                break
            end
        end
        if onEndFn then
            local ok, err = pcall(onEndFn)
            if not ok and Log and Log.error then Log.error("onEnd error [" .. timerId .. "]:", tostring(err)) end
        end
    end)
    entry._handle = handle
    table.insert(st.activeTimers, entry)
    return entry
end
function Timers.getActiveTimer(timerId)
    local st = world.state
    if not st or not st.activeTimers then return nil end
    for _, t in ipairs(st.activeTimers) do
        if t.id == timerId then
            if t._handle then
                if timers.isActive(t._handle) then return t end
            elseif t.remaining and t.remaining > 0 then
                return t
            end
        end
    end
    return nil
end
function Timers.clearActiveTimer(timerId, runOnEnd)
    local st = world.state
    if not st or not st.activeTimers then return false end
    for i = #st.activeTimers, 1, -1 do
        local t = st.activeTimers[i]
        if t.id == timerId then
            if t._handle then timers.cancel(t._handle) end
            local cb = t.onEnd
            table.remove(st.activeTimers, i)
            if runOnEnd and cb then
                local ok, err = pcall(cb)
                if not ok and Log and Log.error then Log.error("onEnd error [" .. timerId .. "]:", tostring(err)) end
            end
            return true
        end
    end
    return false
end
function Timers.getTimerRemaining(entry)
    if not entry then return 0 end
    if entry._handle then
        local h = entry._handle
        if h and h.active and h.delay and h.accum then
            local rem = h.delay - h.accum
            return rem > 0 and rem or 0
        end
        return 0
    end
    return entry.remaining or 0
end
function Timers.getTimerDuration(entry)
    if not entry then return 0 end
    return entry.duration or entry.remaining or 0
end
function Timers.getScoreMultiplier()
    local st = world.state
    return (st and st.scoreMultiplier) or 1
end
function Timers.getCoinBonus()
    local st = world.state
    return (st and st.coinBonus) or 0
end
return Timers

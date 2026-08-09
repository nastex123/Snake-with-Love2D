local timers = {}

local active = {}   -- list of active timer objects (preallocated, pooled)
local free = {}     -- pool of free timer objects
local idCounter = 0

local Timer = {}
Timer.__index = Timer

local function newTimer()
    return setmetatable({
        id = 0,
        active = false,
        delay = 0,
        accum = 0,
        loops = false,
        callback = nil,
    }, Timer)
end

function Timer:cancel()
    self.active = false
    self.callback = nil
end

local function acquire(delay, loops, cb)
    local t = table.remove(free)
    if not t then t = newTimer() end
    idCounter = idCounter + 1
    t.id = idCounter
    t.active = true
    t.delay = delay
    t.accum = 0
    t.loops = loops
    t.callback = cb
    active[#active + 1] = t
    return t
end

function timers.after(delay, cb)
    return acquire(delay, false, cb)
end

function timers.every(delay, cb)
    return acquire(delay, true, cb)
end

function timers.cancel(timer)
    if not timer or not timer.active then return end
    timer.active = false
    timer.callback = nil
    free[#free + 1] = timer
end

function timers.clear()
    for i = #active, 1, -1 do
        timers.cancel(active[i])
        active[i] = nil
    end
end

function timers.update(dt)
    local i = 1
    while i <= #active do
        local t = active[i]
        if not t.active then
            table.remove(active, i)
        else
            t.accum = t.accum + dt
            if t.accum >= t.delay then
                t.accum = t.accum - t.delay
                local cb = t.callback
                if cb then cb() end
                if not t.active then
                    table.remove(active, i)
                elseif t.loops then
                    i = i + 1
                else
                    t.active = false
                    t.callback = nil
                    free[#free + 1] = t
                    table.remove(active, i)
                end
            else
                i = i + 1
            end
        end
    end
end

return timers
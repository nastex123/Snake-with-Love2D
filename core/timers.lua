local timers = {}

local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then
    Log = nil
end

local active = {}   -- list of active timer objects
local free = {}     -- pool of free timer objects
local idCounter = 0

local Timer = {}
Timer.__index = Timer

-- Easing Library
local easings = {}

easings.linear = function(t)
    return t
end

easings.quadIn = function(t)
    return t * t
end

easings.quadOut = function(t)
    return t * (2 - t)
end

easings.quadInOut = function(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

easings.cubicIn = function(t)
    return t * t * t
end

easings.cubicOut = function(t)
    local p = t - 1
    return p * p * p + 1
end

easings.cubicInOut = function(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        local p = 2 * t - 2
        return 0.5 * p * p * p + 1
    end
end

easings.quartIn = function(t)
    return t * t * t * t
end

easings.quartOut = function(t)
    local p = t - 1
    return 1 - p * p * p * p
end

easings.quartInOut = function(t)
    if t < 0.5 then
        return 8 * t * t * t * t
    else
        local p = t - 1
        return 1 - 8 * p * p * p * p
    end
end

easings.quintIn = function(t)
    return t * t * t * t * t
end

easings.quintOut = function(t)
    local p = t - 1
    return p * p * p * p * p + 1
end

easings.quintInOut = function(t)
    if t < 0.5 then
        return 16 * t * t * t * t * t
    else
        local p = 2 * t - 2
        return 0.5 * p * p * p * p * p + 1
    end
end

easings.sineIn = function(t)
    return 1 - math.cos(t * math.pi * 0.5)
end

easings.sineOut = function(t)
    return math.sin(t * math.pi * 0.5)
end

easings.sineInOut = function(t)
    return -0.5 * (math.cos(math.pi * t) - 1)
end

easings.expoIn = function(t)
    return t == 0 and 0 or (2 ^ (10 * (t - 1)))
end

easings.expoOut = function(t)
    return t == 1 and 1 or (1 - 2 ^ (-10 * t))
end

easings.expoInOut = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    if t < 0.5 then
        return 0.5 * (2 ^ (20 * t - 10))
    else
        return 1 - 0.5 * (2 ^ (-20 * t + 10))
    end
end

easings.circIn = function(t)
    return 1 - math.sqrt(math.max(0, 1 - t * t))
end

easings.circOut = function(t)
    local p = t - 1
    return math.sqrt(math.max(0, 1 - p * p))
end

easings.circInOut = function(t)
    local p = t * 2
    if p < 1 then
        return -0.5 * (math.sqrt(math.max(0, 1 - p * p)) - 1)
    else
        p = p - 2
        return 0.5 * (math.sqrt(math.max(0, 1 - p * p)) + 1)
    end
end

easings.backIn = function(t)
    local s = 1.70158
    return t * t * ((s + 1) * t - s)
end

easings.backOut = function(t)
    local s = 1.70158
    local p = t - 1
    return p * p * ((s + 1) * p + s) + 1
end

easings.backInOut = function(t)
    local s = 1.70158 * 1.525
    local p = t * 2
    if p < 1 then
        return 0.5 * (p * p * ((s + 1) * p - s))
    else
        p = p - 2
        return 0.5 * (p * p * ((s + 1) * p + s) + 2)
    end
end

local function bounceOut(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        local p = t - 1.5 / 2.75
        return 7.5625 * p * p + 0.75
    elseif t < 2.5 / 2.75 then
        local p = t - 2.25 / 2.75
        return 7.5625 * p * p + 0.9375
    else
        local p = t - 2.625 / 2.75
        return 7.5625 * p * p + 0.984375
    end
end

easings.bounceOut = bounceOut

easings.bounceIn = function(t)
    return 1 - bounceOut(1 - t)
end

easings.bounceInOut = function(t)
    if t < 0.5 then
        return (1 - bounceOut(1 - 2 * t)) * 0.5
    else
        return bounceOut(2 * t - 1) * 0.5 + 0.5
    end
end

easings.elasticIn = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local p = 0.3
    local s = p / 4
    local t1 = t - 1
    return -(2 ^ (10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p))
end

easings.elasticOut = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local p = 0.3
    local s = p / 4
    return 2 ^ (-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
end

easings.elasticInOut = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local p = 0.3 * 1.5
    local s = p / 4
    local t1 = t * 2 - 1
    if t1 < 0 then
        return -0.5 * (2 ^ (10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p))
    else
        return 0.5 * (2 ^ (-10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p)) + 1
    end
end

timers.easings = easings

local function resolveEasing(easing)
    if type(easing) == "function" then
        return easing
    elseif type(easing) == "string" and easings[easing] then
        return easings[easing]
    end
    return easings.linear
end

local function safeCall(fn, ...)
    if not fn then return true end
    local ok, err = pcall(fn, ...)
    if not ok and Log and Log.error then
        Log.error("Timer callback error:", tostring(err))
    end
    return ok, err
end

local function newTimer()
    return setmetatable({
        id = 0,
        active = false,
        delay = 0,
        accum = 0,
        loops = false,
        callback = nil,
        isTween = false,
        subject = nil,
        target = nil,
        initial = {},
        easing = nil,
        onComplete = nil,
    }, Timer)
end

local function recycleTimer(t)
    t.active = false
    t.callback = nil
    t.onComplete = nil
    t.subject = nil
    t.target = nil
    t.easing = nil
    t.isTween = false
    t.loops = false
    t.delay = 0
    t.accum = 0
    if t.initial then
        for k in pairs(t.initial) do
            t.initial[k] = nil
        end
    end
    free[#free + 1] = t
end

function Timer:cancel()
    timers.cancel(self)
end

function Timer:isActive()
    return self.active == true
end

local isUpdating = false

local function acquire()
    local t = table.remove(free)
    if not t then
        t = newTimer()
    end
    idCounter = idCounter + 1
    t.id = idCounter
    t.active = true
    t.accum = 0
    return t
end

function timers.after(delay, cb)
    local t = acquire()
    t.delay = math.max(0, delay or 0)
    t.loops = false
    t.callback = cb
    t.isTween = false
    active[#active + 1] = t
    return t
end

function timers.every(delay, cb)
    local t = acquire()
    t.delay = math.max(0.0001, delay or 0.0001)
    t.loops = true
    t.callback = cb
    t.isTween = false
    active[#active + 1] = t
    return t
end

function timers.tween(duration, subject, target, easing, onComplete)
    if type(subject) ~= "table" or type(target) ~= "table" then
        local cb = (type(onComplete) == "function" and onComplete) or (type(easing) == "function" and easing)
        if cb then safeCall(cb) end
        return nil
    end

    local easingFn
    local completeCb

    if type(easing) == "function" then
        if type(onComplete) == "function" then
            easingFn = easing
            completeCb = onComplete
        else
            easingFn = easings.linear
            completeCb = easing
        end
    else
        easingFn = resolveEasing(easing)
        completeCb = (type(onComplete) == "function") and onComplete or nil
    end

    local t = acquire()
    t.delay = math.max(0, duration or 0)
    t.loops = false
    t.isTween = true
    t.subject = subject
    t.target = target
    t.easing = easingFn
    t.onComplete = completeCb

    if not t.initial then t.initial = {} end
    for k in pairs(t.initial) do t.initial[k] = nil end
    for k, _ in pairs(target) do
        t.initial[k] = subject[k] or 0
    end

    active[#active + 1] = t

    if t.delay == 0 then
        for k, v in pairs(target) do
            subject[k] = v
        end
        if completeCb then
            safeCall(completeCb)
        end
        t.active = false
    end

    return t
end

function timers.cancel(timer)
    if not timer or not timer.active then return end
    timer.active = false
    timer.callback = nil
    timer.onComplete = nil
    timer.subject = nil
    timer.target = nil
    timer.easing = nil
    if timer.initial then
        for k in pairs(timer.initial) do
            timer.initial[k] = nil
        end
    end

    if not isUpdating then
        for i = 1, #active do
            if active[i] == timer then
                table.remove(active, i)
                break
            end
        end
        free[#free + 1] = timer
    end
end

function timers.clear()
    for i = #active, 1, -1 do
        local t = active[i]
        active[i] = nil
        if t then
            recycleTimer(t)
        end
    end
end
timers.clearAll = timers.clear

function timers.isActive(timer)
    return timer ~= nil and timer.active == true
end

function timers.has(timer)
    return timers.isActive(timer)
end

function timers.getActiveCount()
    return #active
end

function timers.getFreeCount()
    return #free
end

function timers.getPoolSize()
    return #free
end

function timers.reset()
    timers.clear()
    for i = #free, 1, -1 do
        free[i] = nil
    end
    idCounter = 0
end

function timers.update(dt)
    if not dt or dt <= 0 then return end

    isUpdating = true
    local count = #active
    local i = 1

    while i <= count and i <= #active do
        local t = active[i]
        if not t.active then
            table.remove(active, i)
            recycleTimer(t)
            count = count - 1
        else
            if t.isTween then
                t.accum = math.min(t.accum + dt, t.delay)
                local progress = t.delay > 0 and (t.accum / t.delay) or 1
                if progress > 1 then progress = 1 end
                local eased = t.easing(progress)

                local subject = t.subject
                local target = t.target
                local initial = t.initial
                if subject and target and initial then
                    for k, targetVal in pairs(target) do
                        local startVal = initial[k] or 0
                        if type(targetVal) == "number" and type(startVal) == "number" then
                            subject[k] = startVal + (targetVal - startVal) * eased
                        else
                            subject[k] = targetVal
                        end
                    end
                end

                if t.accum >= t.delay then
                    if subject and target then
                        for k, targetVal in pairs(target) do
                            subject[k] = targetVal
                        end
                    end
                    local completeCb = t.onComplete
                    t.active = false
                    if completeCb then
                        safeCall(completeCb)
                    end
                    if active[i] == t then
                        table.remove(active, i)
                        recycleTimer(t)
                        count = count - 1
                    end
                else
                    i = i + 1
                end
            else
                t.accum = t.accum + dt
                if t.accum >= t.delay then
                    if t.loops then
                        local MAX_TICKS_PER_FRAME = 20
                        local ticks = 0
                        while t.accum >= t.delay and t.active and ticks < MAX_TICKS_PER_FRAME do
                            ticks = ticks + 1
                            t.accum = t.accum - t.delay
                            local cb = t.callback
                            if cb then
                                safeCall(cb)
                            end
                        end
                        if t.accum >= t.delay and t.active then
                            t.accum = t.accum % t.delay
                        end
                        if not t.active then
                            if active[i] == t then
                                table.remove(active, i)
                                recycleTimer(t)
                                count = count - 1
                            end
                        else
                            i = i + 1
                        end
                    else
                        t.active = false
                        local cb = t.callback
                        if cb then
                            safeCall(cb)
                        end
                        if active[i] == t then
                            table.remove(active, i)
                            recycleTimer(t)
                            count = count - 1
                        end
                    end
                else
                    i = i + 1
                end
            end
        end
    end
    isUpdating = false
end

return timers
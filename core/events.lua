local Events = {}

local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end

local listeners = {}
local onceWrappers = {}

local function ensureList(event)
    if not listeners[event] then listeners[event] = {} end
    return listeners[event]
end

function Events.on(event, callback)
    if type(event) ~= "string" or type(callback) ~= "function" then
        if Log and Log.warn then Log.warn("Events.on: invalid event/callback", tostring(event)) end
        return function() end
    end
    local list = ensureList(event)
    table.insert(list, callback)
    local active = true
    return function()
        if not active then return end
        active = false
        Events.off(event, callback)
    end
end

Events.subscribe = Events.on
Events.addListener = Events.on

function Events.once(event, callback)
    if type(event) ~= "string" or type(callback) ~= "function" then
        if Log and Log.warn then Log.warn("Events.once: invalid event/callback", tostring(event)) end
        return function() end
    end
    local wrapper
    wrapper = function(payload)
        Events.off(event, wrapper)
        local ok, err = pcall(callback, payload)
        if not ok and Log and Log.error then Log.error("Events.once callback error ["..event.."]:", tostring(err)) end
    end
    return Events.on(event, wrapper)
end

function Events.off(event, callback)
    if type(event) ~= "string" or type(callback) ~= "function" then return false end
    local list = listeners[event]
    if not list then return false end
    for i = #list, 1, -1 do
        if list[i] == callback then
            table.remove(list, i)
            if #list == 0 then listeners[event] = nil end
            return true
        end
    end
    -- check once wrappers mapping
    local wrappers = onceWrappers[event]
    if wrappers then
        for i = #wrappers, 1, -1 do
            if wrappers[i].original == callback then
                local w = wrappers[i].wrapper
                for j = #list, 1, -1 do
                    if list[j] == w then table.remove(list, j) end
                end
                table.remove(wrappers, i)
                if #list == 0 then listeners[event] = nil end
                return true
            end
        end
    end
    return false
end

Events.removeListener = Events.off
Events.unsubscribe = Events.off

function Events.emit(event, payload)
    if type(event) ~= "string" then
        if Log and Log.warn then Log.warn("Events.emit: invalid event", tostring(event)) end
        return 0
    end
    local list = listeners[event]
    if not list or #list == 0 then return 0 end
    -- copy to avoid mutation during iteration
    local snapshot = {}
    for i = 1, #list do snapshot[i] = list[i] end
    local count = 0
    for i = 1, #snapshot do
        local cb = snapshot[i]
        local ok, err = pcall(cb, payload)
        if not ok and Log and Log.error then Log.error("Events.emit callback error ["..event.."]:", tostring(err)) end
        if ok then count = count + 1 end
    end
    return count
end

Events.publish = Events.emit
Events.trigger = Events.emit

function Events.clear(event)
    if event then
        listeners[event] = nil
        onceWrappers[event] = nil
    else
        for k in pairs(listeners) do listeners[k] = nil end
        for k in pairs(onceWrappers) do onceWrappers[k] = nil end
    end
end

Events.removeAllListeners = Events.clear

function Events.has(event)
    local list = listeners[event]
    return list ~= nil and #list > 0
end

function Events.getListenerCount(event)
    if event then
        local list = listeners[event]
        return list and #list or 0
    end
    local total = 0
    for _, list in pairs(listeners) do total = total + #list end
    return total
end

function Events.getEvents()
    local res = {}
    for k in pairs(listeners) do res[#res+1] = k end
    return res
end

return Events

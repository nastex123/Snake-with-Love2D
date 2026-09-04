local Input = {}

local hasConfig, config = pcall(require, "core.config")
if not hasConfig or type(config) ~= "table" then config = {} end

local hasTouch, touch = pcall(require, "core.touch")
if not hasTouch or type(touch) ~= "table" then touch = nil end

local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end

local function safeIsDown(...)
    if love and love.keyboard and love.keyboard.isDown then
        local ok, res = pcall(love.keyboard.isDown, ...)
        if ok then return res end
        if Log and Log.warn then Log.warn("Input.isDown pcall failed", tostring(res)) end
    end
    return false
end

function Input.isDown(...)
    return safeIsDown(...)
end

function Input.isHeld(dir)
    if not dir or type(dir) ~= "string" then return false end
    local binds = config.KEYBINDS and config.KEYBINDS[dir]
    if binds then
        for i = 1, #binds do
            if safeIsDown(binds[i]) then return true end
        end
        return false
    end
    return safeIsDown(dir)
end

function Input.isAnyHeld()
    local dirs = {"up", "down", "left", "right"}
    for i = 1, #dirs do
        if Input.isHeld(dirs[i]) then return true end
    end
    return false
end

function Input.isAnyDirectionHeld()
    return Input.isAnyHeld()
end

function Input.hasActiveTouch()
    if touch and touch.hasActiveTouch then
        local ok, res = pcall(touch.hasActiveTouch)
        if ok then return not not res end
    end
    return false
end

function Input.isGamepadHeld(dir)
    if not dir then return false end
    if love and love.joystick then
        local joys = love.joystick.getJoysticks()
        for i = 1, #joys do
            local j = joys[i]
            if j and j.isGamepad and j:isGamepad() then
                if dir == "up" and j:isGamepadDown("dpup") then return true end
                if dir == "down" and j:isGamepadDown("dpdown") then return true end
                if dir == "left" and j:isGamepadDown("dpleft") then return true end
                if dir == "right" and j:isGamepadDown("dpright") then return true end
            end
        end
    end
    return false
end

function Input.isHeldWithTouch(dir)
    return Input.isHeld(dir) or Input.hasActiveTouch() or Input.isGamepadHeld(dir)
end

function Input.isAnyHeldWithTouch()
    return Input.isAnyHeld() or Input.hasActiveTouch()
end

function Input.getBoundKeys(dir)
    if config.KEYBINDS and config.KEYBINDS[dir] then
        local copy = {}
        for i, k in ipairs(config.KEYBINDS[dir]) do copy[i] = k end
        return copy
    end
    return {dir}
end

return Input

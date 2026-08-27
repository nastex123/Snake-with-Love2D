local Log = {}

-- Log level constants
Log.LEVEL_DEBUG = 1
Log.LEVEL_INFO  = 2
Log.LEVEL_WARN  = 3
Log.LEVEL_ERROR = 4
Log.LEVEL_OFF   = 5

-- Current active log level (default: LEVEL_INFO)
Log.level = Log.LEVEL_INFO

-- Custom writer function (nil uses default io.stdout)
Log.writer = nil

-- Tag representation for log levels
local LEVEL_TAG = {
    [Log.LEVEL_DEBUG] = "DEBUG",
    [Log.LEVEL_INFO]  = "INFO",
    [Log.LEVEL_WARN]  = "WARN",
    [Log.LEVEL_ERROR] = "ERROR",
    [Log.LEVEL_OFF]   = "OFF",
}

-- String to level mapping for flexible level configuration
local STRING_TO_LEVEL = {
    ["DEBUG"]   = Log.LEVEL_DEBUG,
    ["INFO"]    = Log.LEVEL_INFO,
    ["WARN"]    = Log.LEVEL_WARN,
    ["WARNING"] = Log.LEVEL_WARN,
    ["ERROR"]   = Log.LEVEL_ERROR,
    ["OFF"]     = Log.LEVEL_OFF,
    ["NONE"]    = Log.LEVEL_OFF,
    ["SILENT"]  = Log.LEVEL_OFF,
}

-- Safe timestamp retrieval with fallback
local function getTimeString()
    if os and os.date then
        local ok, str = pcall(os.date, "%H:%M:%S")
        if ok and type(str) == "string" then
            return str
        end
    end
    return "00:00:00"
end

-- Key comparator for deterministic table key sorting
local function compareKeys(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        return ta < tb
    end
    if ta == "number" or ta == "string" then
        return a < b
    end
    return tostring(a) < tostring(b)
end

-- Recursive table serializer with circular reference protection
local function serializeValue(val, visited, depth, maxDepth)
    local valType = type(val)
    if val == nil then
        return "nil"
    elseif valType == "string" then
        if depth == 0 then
            return val
        end
        return string.format("%q", val)
    elseif valType == "number" or valType == "boolean" then
        return tostring(val)
    elseif valType ~= "table" then
        return tostring(val)
    end

    -- Check custom __tostring in metatable
    local mt = getmetatable(val)
    if mt and mt.__tostring then
        local ok, res = pcall(tostring, val)
        if ok and type(res) == "string" then
            return res
        end
    end

    -- Circular reference detection
    if visited[val] then
        return "<circular>"
    end

    -- Recursion depth limit
    if depth >= maxDepth then
        return "{...}"
    end

    visited[val] = true

    -- Count total keys and check sequential array
    local totalKeys = 0
    for _ in pairs(val) do
        totalKeys = totalKeys + 1
    end

    if totalKeys == 0 then
        visited[val] = nil
        return "{}"
    end

    local isArray = true
    local arrayLen = #val
    if arrayLen > 0 and arrayLen == totalKeys then
        for i = 1, arrayLen do
            if val[i] == nil then
                isArray = false
                break
            end
        end
    else
        isArray = false
    end

    local parts = {}
    if isArray then
        for i = 1, arrayLen do
            parts[#parts + 1] = serializeValue(val[i], visited, depth + 1, maxDepth)
        end
    else
        local keys = {}
        for k in pairs(val) do
            keys[#keys + 1] = k
        end
        table.sort(keys, compareKeys)

        for _, k in ipairs(keys) do
            local keyStr
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                keyStr = k
            else
                keyStr = "[" .. serializeValue(k, visited, depth + 1, maxDepth) .. "]"
            end
            local valStr = serializeValue(val[k], visited, depth + 1, maxDepth)
            parts[#parts + 1] = keyStr .. " = " .. valStr
        end
    end

    visited[val] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- Public serialization helper
function Log.serialize(val, maxDepth)
    return serializeValue(val, {}, 0, maxDepth or 4)
end

-- Formats argument list with printf support and safe value conversion
local function formatArguments(...)
    local count = select("#", ...)
    if count == 0 then
        return ""
    end

    local first = select(1, ...)
    -- Try printf style format if first argument is a format string
    if type(first) == "string" and count > 1 and first:find("%%") then
        local ok, formatted = pcall(string.format, ...)
        if ok then
            return formatted
        end
    end

    local parts = {}
    for i = 1, count do
        local v = select(i, ...)
        if type(v) == "table" then
            parts[#parts + 1] = serializeValue(v, {}, 1, 4)
        else
            parts[#parts + 1] = tostring(v)
        end
    end
    return table.concat(parts, " ")
end

-- Formats complete log line with timestamp, level tag, and content
function Log.formatMessage(level, ...)
    local tag = LEVEL_TAG[level] or "INFO"
    local now = getTimeString()
    local content = formatArguments(...)
    if content == "" then
        return "[" .. now .. "] [" .. tag .. "]"
    end
    return "[" .. now .. "] [" .. tag .. "] " .. content
end

-- Internal write dispatcher
local function write(level, ...)
    if Log.level >= Log.LEVEL_OFF or level < Log.level then
        return nil
    end

    local msg = Log.formatMessage(level, ...)
    if Log.writer then
        local ok, err = pcall(Log.writer, msg, level, ...)
        if not ok and io and io.stderr and io.stderr.write then
            io.stderr:write("Logger writer error: " .. tostring(err) .. "\n")
        end
    else
        if io and io.stdout and io.stdout.write then
            io.stdout:write(msg .. "\n")
            if io.stdout.flush then
                io.stdout:flush()
            end
        elseif print then
            print(msg)
        end
    end
    return msg
end

-- Public log methods
function Log.debug(...) return write(Log.LEVEL_DEBUG, ...) end
function Log.info(...)  return write(Log.LEVEL_INFO, ...)  end
function Log.warn(...)  return write(Log.LEVEL_WARN, ...)  end
function Log.error(...) return write(Log.LEVEL_ERROR, ...) end

-- Sets active logging level by number or string
function Log.setLevel(level)
    if type(level) == "number" then
        if level >= Log.LEVEL_DEBUG and level <= Log.LEVEL_OFF then
            Log.level = level
        end
    elseif type(level) == "string" then
        local upper = string.upper(level)
        if STRING_TO_LEVEL[upper] then
            Log.level = STRING_TO_LEVEL[upper]
        end
    end
end

-- Returns current numeric level
function Log.getLevel()
    return Log.level
end

-- Returns uppercase string name for a level
function Log.getLevelName(level)
    local target = level or Log.level
    return LEVEL_TAG[target] or "UNKNOWN"
end

-- Checks if a level is enabled under current Log.level
function Log.isLevelEnabled(level)
    if Log.level >= Log.LEVEL_OFF then
        return false
    end
    return (level or Log.LEVEL_INFO) >= Log.level
end

-- Convenience level check functions
function Log.isDebugEnabled() return Log.isLevelEnabled(Log.LEVEL_DEBUG) end
function Log.isInfoEnabled()  return Log.isLevelEnabled(Log.LEVEL_INFO)  end
function Log.isWarnEnabled()  return Log.isLevelEnabled(Log.LEVEL_WARN)  end
function Log.isErrorEnabled() return Log.isLevelEnabled(Log.LEVEL_ERROR) end

-- Custom output writer management
function Log.setWriter(fn)
    if type(fn) == "function" then
        Log.writer = fn
    end
end

function Log.resetWriter()
    Log.writer = nil
end

return Log
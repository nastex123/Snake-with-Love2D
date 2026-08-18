local Log = {}

Log.LEVEL_DEBUG = 1
Log.LEVEL_INFO  = 2
Log.LEVEL_WARN  = 3
Log.LEVEL_ERROR = 4

Log.level = Log.LEVEL_INFO

local LEVEL_TAG = {
    [Log.LEVEL_DEBUG] = "DEBUG",
    [Log.LEVEL_INFO]  = "INFO",
    [Log.LEVEL_WARN]  = "WARN",
    [Log.LEVEL_ERROR] = "ERROR",
}

local function formatMessage(level, ...)
    local tag = LEVEL_TAG[level] or "INFO"
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = tostring(v)
    end
    local now = os.time and os.date("%H:%M:%S") or "00:00:00"
    return "[" .. now .. "] [" .. tag .. "] " .. table.concat(parts, " ")
end

local function write(level, ...)
    if level < Log.level then return end
    local msg = formatMessage(level, ...)
    io.stdout:write(msg .. "\n")
end

function Log.debug(...) write(Log.LEVEL_DEBUG, ...) end
function Log.info(...) write(Log.LEVEL_INFO, ...) end
function Log.warn(...) write(Log.LEVEL_WARN, ...) end
function Log.error(...) write(Log.LEVEL_ERROR, ...) end

function Log.setLevel(level)
    if level >= Log.LEVEL_DEBUG and level <= Log.LEVEL_ERROR then
        Log.level = level
    end
end

return Log
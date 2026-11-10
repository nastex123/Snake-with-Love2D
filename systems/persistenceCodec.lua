local Codec = {}
local LUA_KEYWORDS = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true,
}
local function isIdentifier(s)
    return type(s) == 'string' and s:match('^[a-zA-Z_][a-zA-Z0-9_]*$') and not LUA_KEYWORDS[s]
end
function Codec.encode(val)
    local tv = type(val)
    if tv == 'number' then return tostring(val) end
    if tv == 'boolean' then return val and 'true' or 'false' end
    if tv == 'string' then
        local s = val:gsub('\\', '\\\\')
        s = s:gsub('"', '\\"')
        s = s:gsub('\n', '\\n')
        s = s:gsub('\r', '\\r')
        return '"' .. s .. '"'
    end
    if tv == 'table' then
        local parts = {}
        local isArray, idx = true, 1
        for _ in pairs(val) do
            if val[idx] == nil then isArray = false; break end
            idx = idx + 1
        end
        if isArray then
            for i = 1, #val do parts[#parts + 1] = Codec.encode(val[i]) end
            return '{' .. table.concat(parts, ',') .. '}'
        end
        for k, v in pairs(val) do
            if isIdentifier(k) then parts[#parts + 1] = tostring(k) .. '=' .. Codec.encode(v)
            else parts[#parts + 1] = '[' .. Codec.encode(k) .. ']=' .. Codec.encode(v) end
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return 'nil'
end
function Codec.decode(text)
    if type(text) ~= 'string' or #text == 0 then return nil, "empty input" end
    if text:match('^%s*$') then return nil, "whitespace only" end
    local loader = loadstring or load
    local fn, err
    if _VERSION == "Lua 5.1" or (jit and type(setfenv) == "function") then
        fn, err = loader('return ' .. text)
        if fn then setfenv(fn, {}) end
    else
        fn, err = loader('return ' .. text, "=(safe_load)", "t", {})
    end
    if not fn then return nil, err end
    local ok, res = pcall(fn)
    if not ok then return nil, res end
    return res
end
function Codec.atomicWrite(path, data)
    local tmpPath = path .. ".tmp"
    local bakPath = path .. ".bak"
    local ok, err = pcall(love.filesystem.write, tmpPath, data)
    if not ok or not love.filesystem.getInfo(tmpPath) then
        local ok2, err2 = pcall(love.filesystem.write, path, data)
        if not ok2 then return false, err2 or err end
        return true
    end
    local saveDir = nil
    pcall(function() saveDir = love.filesystem.getSaveDirectory() end)
    if saveDir and saveDir ~= "" then
        local fullTmp = saveDir .. "/" .. tmpPath
        local fullPath = saveDir .. "/" .. path
        local fullBak = saveDir .. "/" .. bakPath
        if love.filesystem.getInfo(path) then
            local bakOk, bakSuccess = pcall(os.rename, fullPath, fullBak)
            if not (bakOk and bakSuccess) then
                local content = love.filesystem.read(path)
                if content then pcall(love.filesystem.write, bakPath, content) end
            end
        end
        local okRename, renameSuccess = pcall(os.rename, fullTmp, fullPath)
        if okRename and renameSuccess and love.filesystem.getInfo(path) then
            pcall(love.filesystem.remove, tmpPath)
            return true
        end
    end
    local content = love.filesystem.read(tmpPath)
    if content then
        local ok2 = pcall(love.filesystem.write, path, content)
        if ok2 then
            if love.filesystem.getInfo(bakPath) == nil and love.filesystem.getInfo(path) then
                pcall(love.filesystem.write, bakPath, content)
            end
            pcall(love.filesystem.remove, tmpPath)
            return true
        end
    end
    return pcall(love.filesystem.write, path, data)
end
return Codec

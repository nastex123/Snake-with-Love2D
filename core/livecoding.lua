-- core/livecoding.lua - Sistema de livecoding y hot-reload en tiempo real para Love2D
local livecoding = {}

local Log = require("core.logger")
local eventsOk, Events = pcall(require, "core.events")

livecoding.enabled = true
livecoding.checkInterval = 0.25 -- comprobar cada 250ms
livecoding.timer = 0
livecoding.trackedFiles = {}   -- [path] = modtime
livecoding.lastError = nil      -- nil o {file = str, message = str, time = number}
livecoding.recentReload = nil   -- nil o {name = str, time = number}

local WATCH_DIRS = {
    "core",
    "entities",
    "world",
    "systems",
    "ui",
    "render",
    "audio"
}

local WATCH_ROOT_FILES = {
    "constants.lua",
    "main.lua"
}

local function pathToModuleName(path)
    local s = path:gsub("\\", "/")
    if s:sub(-4) == ".lua" then
        s = s:sub(1, -5)
    end
    s = s:gsub("/", ".")
    return s
end

local function patchTable(target, source, seen)
    seen = seen or {}
    if seen[target] then return end
    seen[target] = true

    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            patchTable(target[k], v, seen)
        else
            target[k] = v
        end
    end

    for k, v in pairs(target) do
        if source[k] == nil and type(v) ~= "table" then
            target[k] = nil
        end
    end
end

local function scanDirectory(dir)
    local results = {}
    if not (love and love.filesystem and love.filesystem.getDirectoryItems) then
        return results
    end

    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
        local fullPath = (dir == "" or dir == ".") and item or (dir .. "/" .. item)
        local info = love.filesystem.getInfo(fullPath)
        if info then
            if info.type == "file" and item:sub(-4) == ".lua" then
                table.insert(results, fullPath)
            elseif info.type == "directory" then
                local sub = scanDirectory(fullPath)
                for _, s in ipairs(sub) do
                    table.insert(results, s)
                end
            end
        end
    end
    return results
end

function livecoding.getAllTrackedFiles()
    local files = {}
    for _, f in ipairs(WATCH_ROOT_FILES) do
        if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(f) then
            table.insert(files, f)
        end
    end
    for _, d in ipairs(WATCH_DIRS) do
        local found = scanDirectory(d)
        for _, f in ipairs(found) do
            table.insert(files, f)
        end
    end
    return files
end

function livecoding.init()
    livecoding.trackedFiles = {}
    livecoding.lastError = nil
    livecoding.recentReload = nil
    livecoding.timer = 0

    if not (love and love.filesystem and love.filesystem.getInfo) then return end

    local allFiles = livecoding.getAllTrackedFiles()
    for _, path in ipairs(allFiles) do
        local info = love.filesystem.getInfo(path)
        if info and info.modtime then
            livecoding.trackedFiles[path] = info.modtime
        end
    end
    Log.info(string.format("[LiveReload] Inicializado con %d archivos rastreados", #allFiles))
end

function livecoding.reloadFile(filepath)
    if not (love and love.filesystem) then
        return false, "love.filesystem no disponible"
    end

    local info = love.filesystem.getInfo and love.filesystem.getInfo(filepath)
    if not info or (info.size and info.size == 0) then
        -- Archivo temporalmente vacio durante escritura atomica de editor
        return false, "Archivo vacio o no accesible"
    end

    -- 1. Cargar chunk (detecta errores de sintaxis sin crashear)
    local chunk, err
    if love.filesystem.read then
        local content, readErr = love.filesystem.read(filepath)
        if content then
            local loader = loadstring or load
            chunk, err = loader(content, filepath)
        else
            err = readErr
        end
    end
    if not chunk and love.filesystem.load then
        chunk, err = love.filesystem.load(filepath)
    end

    if not chunk then
        livecoding.lastError = {
            file = filepath,
            message = tostring(err),
            time = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
        }
        Log.error(string.format("[LiveReload] Error de sintaxis en %s: %s", filepath, tostring(err)))
        return false, err
    end

    -- 2. Ejecutar chunk de forma segura
    local ok, newMod = pcall(chunk)
    if not ok then
        livecoding.lastError = {
            file = filepath,
            message = tostring(newMod),
            time = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
        }
        Log.error(string.format("[LiveReload] Error de runtime al recargar %s: %s", filepath, tostring(newMod)))
        return false, newMod
    end

    -- Limpiar error si este archivo tenia un fallo previo
    if livecoding.lastError and livecoding.lastError.file == filepath then
        livecoding.lastError = nil
    end

    -- 3. Mapear y actualizar en package.loaded
    local modName = pathToModuleName(filepath)
    if modName and modName ~= "main" then
        local oldMod = package.loaded[modName]
        if type(newMod) == "table" and type(oldMod) == "table" then
            patchTable(oldMod, newMod)
            package.loaded[modName] = oldMod
        else
            package.loaded[modName] = newMod
        end
    end

    -- 4. Hooks de subsistemas especificos
    if filepath == "render/shaders.lua" then
        local shadersMod = package.loaded["render.shaders"]
        if shadersMod and shadersMod.load then pcall(shadersMod.load) end
    elseif filepath == "ui/ui.lua" then
        local uiMod = package.loaded["ui.ui"]
        if uiMod and uiMod.load then pcall(uiMod.load) end
    end

    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
    livecoding.recentReload = {
        name = filepath,
        time = now
    }

    Log.info(string.format("[LiveReload] Modulo recargado con exito: %s", filepath))

    if eventsOk and Events and Events.emit then
        pcall(function()
            Events.emit("toast", {
                title = "LIVE RELOAD",
                subtitle = filepath .. " recargado"
            })
        end)
    end

    return true
end

function livecoding.reloadAll()
    Log.info("[LiveReload] Forzando recarga de todos los archivos...")
    local files = livecoding.getAllTrackedFiles()
    local reloaded = 0
    local errors = 0
    for _, path in ipairs(files) do
        local ok = livecoding.reloadFile(path)
        if ok then
            local info = love.filesystem.getInfo(path)
            if info and info.modtime then
                livecoding.trackedFiles[path] = info.modtime
            end
            reloaded = reloaded + 1
        else
            errors = errors + 1
        end
    end
    Log.info(string.format("[LiveReload] Recarga masiva: %d exitosos, %d fallidos", reloaded, errors))
    return reloaded, errors
end

function livecoding.update(dt)
    if not livecoding.enabled then return end
    if not (love and love.filesystem and love.filesystem.getInfo) then return end

    livecoding.timer = livecoding.timer + (dt or 0)
    if livecoding.timer < livecoding.checkInterval then
        return
    end
    livecoding.timer = 0

    local allFiles = livecoding.getAllTrackedFiles()
    for _, path in ipairs(allFiles) do
        local info = love.filesystem.getInfo(path)
        if info and info.modtime then
            local prevTime = livecoding.trackedFiles[path]
            if prevTime == nil then
                -- Archivo nuevo detectado
                livecoding.trackedFiles[path] = info.modtime
            elseif info.modtime > prevTime then
                -- Modificacion detectada
                livecoding.trackedFiles[path] = info.modtime
                livecoding.reloadFile(path)
            end
        end
    end
end

function livecoding.draw()
    if not love or not love.graphics then return end

    local w = love.graphics.getWidth()
    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0

    -- 1. Banner de Error (si hay syntax/runtime error)
    if livecoding.lastError then
        local err = livecoding.lastError
        local barH = 32
        love.graphics.setColor(0.85, 0.10, 0.10, 0.95)
        love.graphics.rectangle("fill", 0, 0, w, barH)
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.rectangle("line", 0, 0, w, barH)

        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local msg = string.format("[LIVE RELOAD ERROR] %s: %s", err.file or "desconocido", err.message or "")
        -- Recortar mensaje si es muy largo
        if font and font:getWidth(msg) > w - 20 then
            while #msg > 20 and font:getWidth(msg .. "...") > w - 20 do
                msg = msg:sub(1, -2)
            end
            msg = msg .. "..."
        end
        love.graphics.print(msg, 10, 9)
        return
    end

    -- 2. Notificacion de recarga exitosa (dura 1.8 segundos)
    if livecoding.recentReload then
        local elapsed = now - livecoding.recentReload.time
        if elapsed < 1.8 then
            local alpha = math.min(1.0, math.max(0, (1.8 - elapsed) / 0.5))
            local boxW = 280
            local boxH = 24
            local bx = w - boxW - 12
            local by = 12
            love.graphics.setColor(0.04, 0.20, 0.10, alpha * 0.90)
            love.graphics.rectangle("fill", bx, by, boxW, boxH, 4)
            love.graphics.setColor(0.15, 0.95, 0.40, alpha * 0.95)
            love.graphics.rectangle("line", bx, by, boxW, boxH, 4)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.print("[LIVE RELOAD] " .. livecoding.recentReload.name, bx + 8, by + 5)
        else
            livecoding.recentReload = nil
        end
    end
end

return livecoding

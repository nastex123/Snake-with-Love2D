local Assets = {}

local hasLogger, Log = pcall(require, "core.logger")
if not hasLogger or type(Log) ~= "table" then Log = nil end

local fonts = {}
local images = {}
local canvases = {}
local imageDatas = {}

local function fontKey(file, size)
    return (file or "default") .. ":" .. tostring(size)
end

local function canvasKey(w, h)
    return tostring(w) .. "x" .. tostring(h)
end

function Assets.getFont(a, b)
    local file, size
    if type(a) == "string" and type(b) == "number" then
        file = a
        size = b
    elseif type(a) == "number" and b == nil then
        file = nil
        size = a
    elseif type(a) == "string" and b == nil then
        -- a is file with no size? fallback to default size
        file = a
        size = 12
    else
        file = nil
        size = a or 12
    end

    local key = fontKey(file, size)
    if fonts[key] then return fonts[key] end

    local font
    local ok
    if file then
        ok = pcall(function() font = love.graphics.newFont(file, size) end)
        if not ok or not font then
            ok = pcall(function() font = love.graphics.newFont(size) end)
        end
    else
        ok = pcall(function() font = love.graphics.newFont(size) end)
    end
    if not ok or not font then
        if Log and Log.warn then Log.warn("Assets.getFont failed", tostring(file), tostring(size)) end
        return nil
    end
    fonts[key] = font
    return font
end

function Assets.getImage(path)
    if not path or type(path) ~= "string" then return nil end
    if images[path] then return images[path] end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        pcall(function() if img.setFilter then img:setFilter("nearest", "nearest") end end)
        images[path] = img
        return img
    end
    if Log and Log.warn then Log.warn("Assets.getImage failed", path) end
    return nil
end

function Assets.getCanvas(w, h, filter)
    w = math.floor(w or 0)
    h = math.floor(h or 0)
    if w <= 0 or h <= 0 then return nil end
    local key = canvasKey(w, h)
    local entry = canvases[key]
    if entry and entry.canvas then
        local cw, ch = entry.canvas:getWidth(), entry.canvas:getHeight()
        if cw == w and ch == h then
            if filter and entry.filter ~= filter then
                pcall(function() entry.canvas:setFilter(filter, filter) end)
                entry.filter = filter
            end
            return entry.canvas
        else
            pcall(function() entry.canvas:release() end)
        end
    end
    local ok, canv = pcall(love.graphics.newCanvas, w, h)
    if not ok or not canv then
        if Log and Log.warn then Log.warn("Assets.getCanvas failed", w, h) end
        return nil
    end
    if filter then pcall(function() canv:setFilter(filter, filter) end) end
    canvases[key] = {canvas = canv, filter = filter}
    return canv
end

function Assets.getImageData(w, h)
    local key = canvasKey(w, h)
    if imageDatas[key] then return imageDatas[key] end
    local imgData
    local ok
    if love.image and love.image.newImageData then
        ok = pcall(function() imgData = love.image.newImageData(w, h) end)
    elseif love.graphics and love.graphics.newImageData then
        ok = pcall(function() imgData = love.graphics.newImageData(w, h) end)
    end
    if ok and imgData then
        imageDatas[key] = imgData
        return imgData
    end
    return nil
end

function Assets.clearFonts()
    fonts = {}
end

function Assets.clearImages()
    for _, img in pairs(images) do pcall(function() if img.release then img:release() end end) end
    images = {}
end

function Assets.clearCanvases()
    for _, entry in pairs(canvases) do pcall(function() if entry.canvas and entry.canvas.release then entry.canvas:release() end end) end
    canvases = {}
end

function Assets.clearAll()
    Assets.clearFonts()
    Assets.clearImages()
    Assets.clearCanvases()
    imageDatas = {}
end

function Assets.getStats()
    local fCount, iCount, cCount = 0, 0, 0
    for _ in pairs(fonts) do fCount = fCount + 1 end
    for _ in pairs(images) do iCount = iCount + 1 end
    for _ in pairs(canvases) do cCount = cCount + 1 end
    return {fonts = fCount, images = iCount, canvases = cCount}
end

return Assets

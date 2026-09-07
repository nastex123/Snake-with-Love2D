-- systems/tarotArt.lua — texturas PNG de las 12 Cartas del Destino (GDD §14)
-- Mapa id estable -> asset 20x20 con lazy-load cacheado via core/assets.lua.
local tarotArt = {}

local assetsOk, Assets = pcall(require, "core.assets")
if not assetsOk or type(Assets) ~= "table" then Assets = nil end

-- Rutas de las 12 texturas elegidas (variantes del prototipo tarot-cards.html)
tarotArt.PATHS = {
    mercury = "assets/tarot/mercury-20x20.png",
    iron_spine = "assets/tarot/iron_spine-20x20.png",
    eagle_eye = "assets/tarot/eagle_eye-20x20.png",
    shadow_thief = "assets/tarot/shadow_thief-20x20.png",
    alchemical_digestion = "assets/tarot/alchemical_digestion-20x20.png",
    dragon_blood = "assets/tarot/dragon_blood-20x20.png",
    absolute_zero = "assets/tarot/absolute_zero-20x20.png",
    magic_circle = "assets/tarot/magic_circle-20x20.png",
    astral_mirror = "assets/tarot/astral_mirror-20x20.png",
    midas_pouch = "assets/tarot/midas_pouch-20x20.png",
    iron_heart = "assets/tarot/iron_heart-20x20.png",
    reaper = "assets/tarot/reaper-20x20.png",
}

-- Cache de imagenes ya cargadas (sin allocs por frame tras el primer draw)
local cache = {}

-- Devuelve la imagen cacheada o nil si no hay backend disponible
function tarotArt.get(id)
    if not id or not tarotArt.PATHS[id] then return nil end
    if cache[id] ~= nil then return cache[id] end
    local img = nil
    if Assets and Assets.getImage then
        local ok, res = pcall(Assets.getImage, tarotArt.PATHS[id])
        if ok then img = res end
    elseif love and love.graphics and love.graphics.newImage then
        local ok, res = pcall(love.graphics.newImage, tarotArt.PATHS[id])
        if ok then img = res end
    end
    cache[id] = img
    return img
end

-- Dibuja la carta escalada a size px; retorna true o false (fallback por caller)
function tarotArt.draw(id, x, y, size)
    local img = tarotArt.get(id)
    if not img or not img.getWidth then return false end
    local wOk, w = pcall(function() return img:getWidth() end)
    if not wOk or not w or w <= 0 then return false end
    local s = (size or w) / w
    love.graphics.draw(img, x, y, 0, s, s)
    return true
end

return tarotArt

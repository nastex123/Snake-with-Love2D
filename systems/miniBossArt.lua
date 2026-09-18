-- systems/miniBossArt.lua — texturas PNG del Triturador Perforador de Plasma (GDD §5)
-- Mapa defId estable -> 6 assets 16x16 con lazy-load cacheado via core/assets.lua.
local miniBossArt = {}

local assetsOk, Assets = pcall(require, "core.assets")
if not assetsOk or type(Assets) ~= "table" then Assets = nil end

-- Rutas de las 6 texturas del Triturador (variante Perforador de Plasma)
miniBossArt.PATHS = {
    wall_crusher_idle_f1 = "assets/enemies/crusher/plasma_idle_f1.png",
    wall_crusher_idle_f2 = "assets/enemies/crusher/plasma_idle_f2.png",
    wall_crusher_attack_f1 = "assets/enemies/crusher/plasma_attack_f1.png",
    wall_crusher_attack_f2 = "assets/enemies/crusher/plasma_attack_f2.png",
    wall_crusher_telegraph_f1 = "assets/enemies/crusher/plasma_telegraph_f1.png",
    wall_crusher_telegraph_f2 = "assets/enemies/crusher/plasma_telegraph_f2.png",
}

-- Cache de imagenes ya cargadas (sin allocs por frame tras el primer draw)
local cache = {}

-- Devuelve la imagen cacheada o nil si no hay backend disponible
function miniBossArt.get(id)
    if not id or not miniBossArt.PATHS[id] then return nil end
    if cache[id] ~= nil then return cache[id] end
    local img = nil
    if Assets and Assets.getImage then
        local ok, res = pcall(Assets.getImage, miniBossArt.PATHS[id])
        if ok then img = res end
    elseif love and love.graphics and love.graphics.newImage then
        local ok, res = pcall(love.graphics.newImage, miniBossArt.PATHS[id])
        if ok then img = res end
    end
    cache[id] = img
    return img
end

-- Frame del cuerpo 2x2 segun estado de la maquina (idle 4 FPS, ataque en telegraph/execute)
function miniBossArt.frameFor(defId, state, time)
    if defId ~= "wall_crusher" then return nil end
    local t = time or 0
    if state == "telegraph" or state == "execute" then
        return t % 0.4 < 0.2 and "wall_crusher_attack_f1" or "wall_crusher_attack_f2"
    end
    return t % 0.5 < 0.25 and "wall_crusher_idle_f1" or "wall_crusher_idle_f2"
end

-- Tile del telegraph del charge por fraccion de progreso (F1 si frac < 0.5)
function miniBossArt.tileFor(frac)
    if (frac or 0) < 0.5 then return "wall_crusher_telegraph_f1" end
    return "wall_crusher_telegraph_f2"
end

-- Dibuja el sprite escalado a size px; retorna true o false (fallback por caller)
function miniBossArt.draw(id, x, y, size)
    local img = miniBossArt.get(id)
    if not img or not img.getWidth then return false end
    local wOk, w = pcall(function() return img:getWidth() end)
    if not wOk or not w or w <= 0 then return false end
    local s = (size or w) / w
    love.graphics.draw(img, x, y, 0, s, s)
    return true
end

return miniBossArt

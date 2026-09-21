local Settings = {}
local helpers = require("core.helpers")
Settings.defaultsTable = {
    audio = {master = 1.0, music = true, sfx = true},
    controls = {inputType = 'autodetect', sensitivity = 1.0, controlMode = 'tactical'},
    graphics = {pixelScale = 1, filter = 'linear', fullscreen = false, vsync = true, resolution = {width = 800, height = 600}},
    gameplay = {difficulty = 'normal', tutorials = true, tradeKill = true, controlMode = 'tactical'},
    accessibility = {uiScale = 1.0, highContrast = false, colorblind = 'off'},
    logo = {offsetX = 0, offsetY = 0, scale = 6, spacing = 10, depth = 5},
}
function Settings.deep_merge(dest, src)
    for k, v in pairs(src) do
        if type(v) == 'table' then
            if type(dest[k]) ~= 'table' then dest[k] = {} end
            Settings.deep_merge(dest[k], v)
        else
            if dest[k] == nil or type(dest[k]) ~= type(v) then dest[k] = v end
        end
    end
    return dest
end
function Settings.defaults()
    return helpers.deep_copy(Settings.defaultsTable)
end
function Settings.graphicsDiff(a, b)
    if not a or not b then return true end
    if a.pixelScale ~= b.pixelScale then return true end
    if a.filter ~= b.filter then return true end
    if a.fullscreen ~= b.fullscreen then return true end
    if a.vsync ~= b.vsync then return true end
    local ra, rb = a.resolution, b.resolution
    if (ra == nil) ~= (rb == nil) then return true end
    if ra and rb then
        if ra.width ~= rb.width or ra.height ~= rb.height then return true end
    end
    return false
end
function Settings.audioDiff(a, b)
    if not a or not b then return true end
    if a.master ~= b.master then return true end
    if a.music ~= b.music then return true end
    if a.sfx ~= b.sfx then return true end
    return false
end
return Settings

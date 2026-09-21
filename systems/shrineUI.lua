local shrineUI = {}
shrineUI.visible = false
shrineUI._rects = nil
shrineUI._msg = nil
shrineUI._msgTimer = 0
function shrineUI.open()
    shrineUI.visible = true
    shrineUI._msg = nil
    shrineUI._msgTimer = 0
end
function shrineUI.close()
    shrineUI.visible = false
    shrineUI._rects = nil
end
function shrineUI.draw()
    if not shrineUI.visible then return end
    local shop = require("systems.shrineShop")
    local draw = require("systems.shrineDraw")
    local p = shop.state()
    local modeInfo = nil
    local okModes, modesMod = pcall(require, "systems.modes")
    if okModes and modesMod then
        local okW, worldm = pcall(require, "core.world")
        modeInfo = {current = (okW and worldm.get("modo")) or (p and p.modo) or "estandar", list = {}}
        for _, id in ipairs(modesMod.LIST) do
            modeInfo.list[#modeInfo.list + 1] = {id = id, unlocked = modesMod.isUnlocked(id, p)}
        end
    end
    shrineUI._rects = draw.draw(shop.balance(), p and p.talents, modeInfo)
    if shrineUI._msg and shrineUI._msgTimer > 0 then
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.printf(shrineUI._msg, 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
    end
end
function shrineUI.update(dt)
    if shrineUI._msgTimer > 0 then shrineUI._msgTimer = shrineUI._msgTimer - dt end
end
local function inside(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end
function shrineUI.mousepressed(x, y, button)
    if not shrineUI.visible then return false end
    if button ~= 1 then return true end
    local r = shrineUI._rects
    if not r then return true end
    if inside(x, y, r.close) then
        local ok, sound = pcall(require, "audio.sound")
        if ok and sound and sound.play then pcall(function() sound.play("buttonClick") end) end
        shrineUI.close()
        return true
    end
    for _, b in ipairs(r.buttons or {}) do
        if inside(x, y, b) then
            local shop = require("systems.shrineShop")
            local okShop, bought, errMsg = pcall(shop.buy, b.id)
            if not okShop or not bought then
                shrineUI._msg = errMsg or "No disponible"
                shrineUI._msgTimer = 2.0
            else
                local okS, sound = pcall(require, "audio.sound")
                if okS and sound and sound.play then pcall(function() sound.play("buy") end) end
            end
            return true
        end
    end
    for _, m in ipairs(r.modes or {}) do
        if inside(x, y, m) then
            local okP, persistence = pcall(require, "systems.persistence")
            if okP and persistence then
                local prof = persistence.getActiveProfile()
                if prof then
                    prof.modo = m.id
                    persistence.saveProfiles()
                    local okW, worldm = pcall(require, "core.world")
                    if okW and worldm then worldm.set("modo", m.id) end
                    if persistence.syncModeSkin then
                        pcall(function() persistence.syncModeSkin(m.id, prof.skin) end)
                    end
                    local okS, sound = pcall(require, "audio.sound")
                    if okS and sound and sound.play then pcall(function() sound.play("buttonClick") end) end
                end
            end
            return true
        end
    end
    return true
end
function shrineUI.keypressed(tecla)
    if not shrineUI.visible then return false end
    if tecla == "escape" or tecla == "return" or tecla == "kpenter" then
        shrineUI.close()
        return true
    end
    return false
end
return shrineUI

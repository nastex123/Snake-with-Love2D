-- ui/popupsUI.lua - Popups de puntos flotantes
local popupsMod = {}
local constants = require("constants")

function popupsMod.add(ui, text, gridX, gridY)
    local tam = constants.TAMANIO_BLOQUE
    table.insert(ui.popups, {
        text = text,
        x = gridX * tam + tam / 2,
        y = gridY * tam,
        alpha = 1,
        timer = 0,
        scale = 0
    })
end

function popupsMod.update(ui, dt)
    for i = #ui.popups, 1, -1 do
        local p = ui.popups[i]
        p.timer = p.timer + dt
        p.y = p.y - constants.SCORE_POPUP_SPEED * dt
        p.alpha = 1 - (p.timer / constants.SCORE_POPUP_LIFETIME)
        -- scale-in rápido los primeros 0.1s
        p.scale = math.min(1.0, p.timer / 0.10)
        p.scale = p.scale * p.scale * (3 - 2 * p.scale)  -- smoothstep
        if p.alpha <= 0 then
            table.remove(ui.popups, i)
        end
    end
end

function popupsMod.draw(ui)
    love.graphics.setFont(ui.fontNormal)
    for _, p in ipairs(ui.popups) do
        love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], p.alpha)
        local tw = ui.fontNormal:getWidth(p.text)
        local th = ui.fontNormal:getHeight()
        local cx = p.x
        local cy = p.y
        love.graphics.push()
        love.graphics.translate(cx, cy + th / 2)
        love.graphics.scale(p.scale, p.scale)
        love.graphics.translate(-cx, -(cy + th / 2))
        love.graphics.print(p.text, p.x - tw / 2, p.y)
        love.graphics.pop()
    end
end

return popupsMod
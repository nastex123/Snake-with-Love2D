-- ui/toastsUI.lua - Toasts de logros (cola, animacion, dibujo)
local toasts = {}
local constants = require("constants")

function toasts.show(ui, payload)
    payload = payload or {}
    local t = {
        id = payload.id,
        title = payload.title or "LOGRO",
        subtitle = payload.subtitle or "",
        reward = payload.reward or "",
        t = 0,
        state = 'in' -- in, hold, out
    }
    table.insert(ui._toastQueue, t)
end

function toasts.update(ui, dt)
    if #ui._toastQueue == 0 then return end
    local first = ui._toastQueue[1]
    first.t = first.t + dt
    local fade = constants.TOAST_FADE
    local total = constants.TOAST_SHOW_DURATION + fade * 2
    if first.t >= total then
        table.remove(ui._toastQueue, 1)
        -- continue; next toast will start from t=0
    end
end

function toasts.draw(ui)
    if #ui._toastQueue == 0 then return end
    local w = love.graphics.getWidth()
    local x = w / 2
    local y = 18
    local toast = ui._toastQueue[1]
    local fade = constants.TOAST_FADE
    local show = constants.TOAST_SHOW_DURATION
    local alpha = 1
    if toast.t < fade then
        alpha = toast.t / fade
    elseif toast.t > fade + show then
        alpha = math.max(0, 1 - (toast.t - (fade + show)) / fade)
    end

    love.graphics.setFont(ui.fontNormal)
    local titleH = ui.fontNormal:getHeight()
    local subtitleH = ui.fontSmall:getHeight()
    local rewardH = ui.fontSmall:getHeight()

    local contentW = math.max(ui.fontNormal:getWidth(toast.title), ui.fontSmall:getWidth(toast.subtitle), ui.fontSmall:getWidth(toast.reward))
    local boxW = math.min(constants.TOAST_MAX_WIDTH, contentW + constants.TOAST_ICON_SIZE + constants.TOAST_PADDING * 3)
    local boxH = constants.TOAST_PADDING + titleH + subtitleH + rewardH + constants.TOAST_PADDING/2
    local bx = x - boxW / 2
    -- slide animation: start slightly above and slide down by TOAST_SLIDE pixels
    local slideAmt = constants.TOAST_SLIDE or 12
    local by = y - slideAmt * (1 - alpha)

    -- background
    love.graphics.setColor(constants.TOAST_BG_COLOR[1], constants.TOAST_BG_COLOR[2], constants.TOAST_BG_COLOR[3], (constants.TOAST_BG_COLOR[4] or 0.95) * alpha)
    love.graphics.rectangle('fill', bx, by, boxW, boxH, 8)
    -- border (gold)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 0.9 * alpha)
    love.graphics.rectangle('line', bx, by, boxW, boxH, 8)

    local ix = bx + constants.TOAST_PADDING
    local iy = by + constants.TOAST_PADDING
    -- placeholder icon (circle)
    love.graphics.setColor(1,1,1,0.9 * alpha)
    love.graphics.circle('fill', ix + constants.TOAST_ICON_SIZE/2, iy + constants.TOAST_ICON_SIZE/2, constants.TOAST_ICON_SIZE/2)

    -- texts
    local tx = ix + constants.TOAST_ICON_SIZE + constants.TOAST_PADDING
    local ty = iy
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 1 * alpha)
    love.graphics.print(toast.title or "", tx, ty)
    ty = ty + titleH
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1,1,1,0.9 * alpha)
    love.graphics.print(toast.subtitle or "", tx, ty)
    ty = ty + subtitleH
    -- reward in light gray
    love.graphics.setColor(0.85,0.85,0.9, 0.9 * alpha)
    love.graphics.print(toast.reward or "", tx, ty)
end

return toasts
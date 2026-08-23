-- ui/menuCard.lua - Tarjeta combinada perfil + HIGH SCORE #11 Chunky (extraído de menuUI.lua)
local menuCard = {}

local COLOR_CYAN = {0.0, 0.94, 1.0}
local COLOR_GOLD = {1.0, 0.82, 0.25}

function menuCard.draw(ui, cardAlpha, globalTime, menuTime, highScore, rightCenterX, h)
    if cardAlpha <= 0 then return end
    local persistence = require("systems.persistence")
    local activeProfile = persistence.getActiveProfile()
    local profileName = (activeProfile and activeProfile.name) or "SLAYER_01"
    local coins = (activeProfile and activeProfile.monedas) or 0
    local stageMax = (activeProfile and activeProfile.stats and activeProfile.stats.highestStage) or 1
    if stageMax < 1 then stageMax = 1 end
    if stageMax > 5 then stageMax = 5 end
    local cardW = 344
    local cardH = 76
    local cardX = rightCenterX - math.floor(cardW / 2) + 200
    local cardY = h - cardH - 18
    local isCardHover = (ui.menuHoverId == 'card_profile')
    local t = (globalTime or menuTime)
    local g = 3
    ui.menuButtons[#ui.menuButtons + 1] = {id = 'card_profile', x = cardX, y = cardY, w = cardW, h = cardH}
    love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
    love.graphics.rectangle("fill", cardX - g + 4, cardY - g + 4, cardW + g * 2, cardH + g * 2)
    love.graphics.setColor(0.02, 0.05, 0.09, cardAlpha * 0.96)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)
    love.graphics.setColor(isCardHover and 0.07 or 0.05, isCardHover and 0.14 or 0.11, isCardHover and 0.22 or 0.17, cardAlpha * 0.96)
    local splitStartX = cardX + math.floor(cardW * 0.52)
    for py = 0, cardH - 1 do
        local currentSplitX = splitStartX + math.floor(py * 0.45)
        love.graphics.rectangle("fill", currentSplitX, cardY + py, (cardX + cardW) - currentSplitX, 1)
    end
    love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 0.9 or 0.45))
    for py = 0, cardH - 1, 2 do
        local currentSplitX = splitStartX + math.floor(py * 0.45)
        love.graphics.rectangle("fill", currentSplitX, cardY + py, 2, 2)
    end
    love.graphics.setColor(0, 0, 0, cardAlpha * 0.98)
    love.graphics.rectangle("fill", cardX - g - 1, cardY - g - 1, cardW + g * 2 + 2, cardH + g * 2 + 2)
    love.graphics.setColor(0.02, 0.05, 0.09, cardAlpha * 0.96)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH)
    love.graphics.setColor(isCardHover and 0.07 or 0.05, isCardHover and 0.14 or 0.11, isCardHover and 0.22 or 0.17, cardAlpha * 0.96)
    for py = 0, cardH - 1 do
        local currentSplitX = splitStartX + math.floor(py * 0.45)
        love.graphics.rectangle("fill", currentSplitX, cardY + py, (cardX + cardW) - currentSplitX, 1)
    end
    love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 0.9 or 0.45))
    for py = 0, cardH - 1, 2 do
        local currentSplitX = splitStartX + math.floor(py * 0.45)
        love.graphics.rectangle("fill", currentSplitX, cardY + py, 2, 2)
    end
    love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 0.95 or 0.75))
    love.graphics.rectangle("fill", cardX - g, cardY - g, cardW + g * 2, 2)
    love.graphics.rectangle("fill", cardX - g, cardY + cardH + g - 2, cardW + g * 2, 2)
    love.graphics.rectangle("fill", cardX - g, cardY - g, 2, cardH + g * 2)
    love.graphics.rectangle("fill", cardX + cardW + g - 2, cardY - g, 2, cardH + g * 2)
    love.graphics.setColor(1, 1, 1, cardAlpha * (isCardHover and 0.4 or 0.15))
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH)
    local corners = {
        {cardX - g - 1, cardY - g - 1},
        {cardX + cardW + g - 5, cardY - g - 1},
        {cardX - g - 1, cardY + cardH + g - 5},
        {cardX + cardW + g - 5, cardY + cardH + g - 5}
    }
    for _, c in ipairs(corners) do
        love.graphics.setColor(0, 0, 0, cardAlpha)
        love.graphics.rectangle("fill", c[1], c[2], 6, 6)
        love.graphics.setColor(COLOR_CYAN[1], COLOR_CYAN[2], COLOR_CYAN[3], cardAlpha * (isCardHover and 1.0 or 0.85))
        love.graphics.rectangle("fill", c[1] + 1, c[2] + 1, 4, 4)
        love.graphics.setColor(1, 1, 1, cardAlpha * (isCardHover and 1.0 or 0.6))
        love.graphics.rectangle("fill", c[1] + 2, c[2] + 2, 2, 2)
    end
    local fontS = ui.fontSmall or ui.fontNormal
    love.graphics.setFont(fontS)
    love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
    love.graphics.print(profileName, cardX + 15, cardY + 13)
    love.graphics.setColor(1, 1, 1, cardAlpha * 0.95)
    love.graphics.print(profileName, cardX + 14, cardY + 12)
    for s = 1, 5 do
        local sx = cardX + 14 + (s - 1) * 15
        local isBoss = (s == 5)
        local isCurrent = (s == stageMax)
        local isCleared = (s < stageMax)
        local pulse = isCurrent and ((math.floor(t * 8) % 2 == 0) and {1, 1, 1} or COLOR_CYAN) or COLOR_CYAN
        love.graphics.setColor(0.01, 0.02, 0.04, cardAlpha)
        love.graphics.rectangle("fill", sx, cardY + 34, 12, 7)
        if isCleared then
            love.graphics.setColor(COLOR_CYAN[1] * 0.6, COLOR_CYAN[2] * 0.6, COLOR_CYAN[3] * 0.6, cardAlpha)
        elseif isCurrent then
            love.graphics.setColor(pulse[1], pulse[2], pulse[3], cardAlpha)
        else
            love.graphics.setColor(0.06, 0.10, 0.16, cardAlpha)
        end
        love.graphics.rectangle("fill", sx + 1, cardY + 35, 10, 5)
        if isBoss then
            local skull = {" XXXXX ", "X X X X", "XXXXXXX", " XXXXX ", " X X X "}
            local skullColor = (stageMax >= 5) and {1, 1, 1} or {0.35, 0.45, 0.55}
            for r = 1, 5 do
                local line = skull[r]
                for c = 1, 7 do
                    if line:sub(c, c) == 'X' then
                        love.graphics.setColor(skullColor[1], skullColor[2], skullColor[3], cardAlpha)
                        love.graphics.rectangle("fill", sx + 2 + c, cardY + 35 + r - 1, 1, 1)
                    end
                end
            end
        end
    end
    love.graphics.setColor(0.55, 0.65, 0.75, cardAlpha * 0.85)
    love.graphics.print(string.format("STAGE 0%d/05", stageMax), cardX + 94, cardY + 33)
    local coinAngle = t * 4.5
    local coinCosA = math.cos(coinAngle)
    local coinAbsCos = math.abs(coinCosA)
    local coinR = 5.0
    local coinRx = math.max(0.5, coinR * coinAbsCos)
    local coinThickness = math.max(1, math.floor(2.0 * (1 - coinAbsCos) + 0.5))
    local coinCx = cardX + 19
    local coinCy = cardY + 57
    if coinAbsCos < 0.95 and coinThickness > 0 then
        local edgeSide = coinCosA >= 0 and -1 or 1
        for py = -math.floor(coinR), math.floor(coinR) do
            local normY = py / coinR
            local inside = 1 - normY * normY
            if inside > 0 then
                local halfRowW = coinRx * math.sqrt(inside)
                local startPx = coinCx + (edgeSide > 0 and halfRowW or (-halfRowW - coinThickness))
                love.graphics.setColor(0.36, 0.27, 0.0, cardAlpha)
                love.graphics.rectangle("fill", startPx, coinCy + py, coinThickness, 1)
            end
        end
    end
    for py = -math.floor(coinR), math.floor(coinR) do
        local normY = py / coinR
        local inside = 1 - normY * normY
        if inside > 0 then
            local spanW = coinRx * math.sqrt(inside)
            love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
            love.graphics.rectangle("fill", coinCx - spanW, coinCy + py, spanW * 2, 1)
            if math.abs(py) < coinR - 1 and spanW > 1.5 then
                local innerNormY = py / (coinR - 1)
                local innerInside = 1 - innerNormY * innerNormY
                if innerInside > 0 then
                    local innerSpanW = (coinRx - 1) * math.sqrt(innerInside)
                    love.graphics.setColor(0.79, 0.59, 0.0, cardAlpha)
                    love.graphics.rectangle("fill", coinCx - innerSpanW, coinCy + py, innerSpanW * 2, 1)
                end
            end
        end
    end
    if coinRx > 2.0 then
        love.graphics.setColor(0.29, 0.21, 0.0, cardAlpha)
        for theta = 0, math.pi * 2, (math.pi * 2 / 10) do
            local sx = math.cos(theta) * 2.2 * coinAbsCos
            local sy = math.sin(theta) * 2.2
            love.graphics.rectangle("fill", coinCx + sx - 0.5, coinCy + sy - 0.5, 1, 1)
        end
        love.graphics.setColor(1, 1, 1, cardAlpha)
        love.graphics.rectangle("fill", coinCx - 0.5, coinCy - 0.5, 1, 1)
    end
    love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
    love.graphics.print(string.format("%d G", coins), cardX + 31, cardY + 53)
    love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
    love.graphics.print(string.format("%d G", coins), cardX + 30, cardY + 52)
    local rightSideX = cardX + math.floor(cardW * 0.58)
    local medalMx = rightSideX + 4
    local medalMy = cardY + 12
    local ribbon = {"BBBBRRRRBBBB", " BBBBRRRRBB ", "  BBBBRRRR  ", "   BBBBRR   ", "    BBBR    ", "     BR     "}
    for r = 1, 6 do
        local line = ribbon[r]
        for c = 1, 12 do
            local ch = line:sub(c, c)
            if ch == 'B' then
                love.graphics.setColor(0.20, 0.53, 1.0, cardAlpha * (isCardHover and 1.0 or 0.85))
                love.graphics.rectangle("fill", medalMx + c - 2, medalMy + r - 1, 1, 1)
            elseif ch == 'R' then
                love.graphics.setColor(1.0, 0.20, 0.33, cardAlpha * (isCardHover and 1.0 or 0.85))
                love.graphics.rectangle("fill", medalMx + c - 2, medalMy + r - 1, 1, 1)
            end
        end
    end
    local medalDisc = {"  YYYY  ", " YOOOOY ", "YOO  OOY", "YO    OY", "YO    OY", "YOO  OOY", " YOOOOY ", "  DDDD  "}
    for r = 1, 8 do
        local line = medalDisc[r]
        for c = 1, 8 do
            local ch = line:sub(c, c)
            if ch == 'Y' then
                love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
                love.graphics.rectangle("fill", medalMx + c, medalMy + 4 + r, 1, 1)
            elseif ch == 'O' then
                love.graphics.setColor(0.79, 0.59, 0.0, cardAlpha)
                love.graphics.rectangle("fill", medalMx + c, medalMy + 4 + r, 1, 1)
            elseif ch == 'D' then
                love.graphics.setColor(0.36, 0.27, 0.0, cardAlpha)
                love.graphics.rectangle("fill", medalMx + c, medalMy + 4 + r, 1, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, cardAlpha)
    love.graphics.rectangle("fill", medalMx + 4, medalMy + 7, 2, 2)
    love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
    love.graphics.print("HI-SCORE", rightSideX + 21, cardY + 16)
    love.graphics.setColor(COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3], cardAlpha)
    love.graphics.print("HI-SCORE", rightSideX + 20, cardY + 15)
    local fontL = ui.fontLarge or ui.fontNormal
    love.graphics.setFont(fontL)
    local scoreStr = tostring(highScore or 0)
    love.graphics.setColor(0, 0, 0, cardAlpha * 0.95)
    love.graphics.print(scoreStr, rightSideX + 5, cardY + 39)
    love.graphics.setColor(1, 1, 1, cardAlpha)
    love.graphics.print(scoreStr, rightSideX + 4, cardY + 38)
end

return menuCard

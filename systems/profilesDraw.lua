local profilesDraw = {}
local persistence = require('systems.persistence')
local constants = require('constants')
local ui = require('ui.ui')
local achMod = require('systems.achievements')

function profilesDraw.drawSelect(profilesMod, w, h)
    profilesMod.cardRects = {}
    profilesMod.buttonRects = {}
    profilesMod.backBtn = {}

    local profiles = persistence.getProfiles()
    local activeIdx = persistence.getActiveProfileIndex()
    local mx, my = love.mouse.getPosition()
    local pad = profilesMod.panelPad
    local innerX = profilesMod.panelX + pad
    local innerW = profilesMod.panelW - pad * 2

    -- Title
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("GESTOR DE PERFILES", profilesMod.panelX, profilesMod.panelY + 10, profilesMod.panelW, "center")

    -- Responsive card dimensions
    local titleAreaH = 40
    local bottomBtnH = 44
    local availH = profilesMod.panelH - titleAreaH - bottomBtnH - pad
    local n = 3
    local gap = 8
    local cardH = math.min(profilesMod.CARD_H, math.floor((availH - (n - 1) * gap) / n))

    if cardH < profilesMod.CARD_H_MIN then
        profilesMod.scrollEnabled = true
        cardH = profilesMod.CARD_H_MIN
        local contentH = cardH * n + (n - 1) * gap
        local visibleH = availH
        profilesMod.maxScroll = math.max(0, contentH - visibleH)
        if profilesMod.scrollOffset > profilesMod.maxScroll then profilesMod.scrollOffset = profilesMod.maxScroll end
    else
        profilesMod.scrollEnabled = false
        profilesMod.scrollOffset = 0
        profilesMod.maxScroll = 0
    end

    local startY = profilesMod.panelY + titleAreaH + pad - profilesMod.scrollOffset

    for i = 1, n do
        local cy = startY + (i - 1) * (cardH + gap)
        local profile = profiles[i]
        local isActive = (activeIdx == i)

        local cardColor = isActive and {0.12, 0.18, 0.3, 0.9} or {0.12, 0.12, 0.22, 0.8}
        love.graphics.setColor(cardColor)
        love.graphics.rectangle("fill", innerX, cy, innerW, cardH, 6)

        if isActive then
            local pulse = math.sin(love.timer.getTime() * 3) * 0.3 + 0.7
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pulse)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", innerX, cy, innerW, cardH, 6)
        love.graphics.setLineWidth(1)

        love.graphics.setFont(ui.fontSmall)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.print("SLOT " .. i, innerX + 8, cy + 6)

        if profile then
            love.graphics.setFont(ui.fontNormal)
            love.graphics.setColor(1, 1, 1)
            local pName = tostring(profile.name or ("Jugador " .. i))
            if #pName > 14 then pName = pName:sub(1, 14) end
            love.graphics.print(pName, innerX + 56, cy + 6)

            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
            love.graphics.print("$" .. (profile.monedas or 0), innerX + 56, cy + 26)
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.print("SCORE: " .. (profile.highScore or 0), innerX + 56, cy + 36)

            local aCount = 0
            if type(profile.achievements) == 'table' then
                for _, v in pairs(profile.achievements) do
                    if v and (v == true or (type(v) == 'table' and v.done)) then aCount = aCount + 1 end
                end
            end
            local uCount = 0
            if type(profile.unlocks) == 'table' then
                for _, v in pairs(profile.unlocks) do
                    if v then uCount = uCount + 1 end
                end
            end
            love.graphics.setColor(0.6, 0.6, 0.8, 0.5)
            local statY = (cardH >= 90) and (cy + 46) or (cy + cardH - 28)
            love.graphics.print("Logros: " .. aCount .. "  Desbloqueos: " .. uCount, innerX + 56, statY)

            local achY2 = math.min(cy + cardH - 18, statY + ((cardH >= 90) and 14 or 0))
            local achX = innerX + 56
            local achW = 70
            local achH = 14
            if profilesMod.buttonHover(achX, achY2, achW, achH, mx, my) then
                love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.7)
            else
                love.graphics.setColor(0.4, 0.4, 0.6, 0.4)
            end
            love.graphics.setFont(ui.fontSmall)
            love.graphics.print("Ver Logros", achX, achY2)
            profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = achX, y = achY2, w = achW, h = achH, action = "achievements", index = i}

            -- Right-side action buttons
            local bw = 82
            local bh = math.min(24, math.max(14, math.floor((cardH - 16 - 9) / 4)))
            local bgap = math.min(4, math.max(2, math.floor((cardH - 16 - 4 * bh) / 3)))
            local btnStartX = innerX + innerW - 8 - bw
            local by = cy + 8

            if isActive then
                love.graphics.setColor(0.2, 0.5, 0.2, 0.8)
                love.graphics.rectangle("fill", btnStartX, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.printf("ACTIVO", btnStartX, by + math.floor((bh - 8) / 2), bw, "center")
            elseif bh >= 14 then
                if profilesMod.buttonHover(btnStartX, by, bw, bh, mx, my) then
                    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.8)
                else
                    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
                end
                love.graphics.rectangle("fill", btnStartX, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("SELECCIONAR", btnStartX, by + math.floor((bh - 8) / 2), bw, "center")
                profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = btnStartX, y = by, w = bw, h = bh, action = "select", index = i}
            end

            by = by + bh + bgap
            if bh >= 14 then
                if profilesMod.buttonHover(btnStartX, by, bw, bh, mx, my) then
                    love.graphics.setColor(0.3, 0.3, 0.5, 0.8)
                else
                    love.graphics.setColor(0.2, 0.2, 0.35, 0.6)
                end
                love.graphics.rectangle("fill", btnStartX, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.printf("RENOMBRAR", btnStartX, by + math.floor((bh - 8) / 2), bw, "center")
                profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = btnStartX, y = by, w = bw, h = bh, action = "rename", index = i}
            end

            by = by + bh + bgap
            if bh >= 14 then
                if profilesMod.buttonHover(btnStartX, by, bw, bh, mx, my) then
                    love.graphics.setColor(0.5, 0.3, 0.2, 0.8)
                else
                    love.graphics.setColor(0.35, 0.2, 0.15, 0.6)
                end
                love.graphics.rectangle("fill", btnStartX, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.printf("RESTABLECER", btnStartX, by + math.floor((bh - 8) / 2), bw, "center")
                profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = btnStartX, y = by, w = bw, h = bh, action = "reset", index = i}
            end

            by = by + bh + bgap
            if bh >= 14 then
                if profilesMod.buttonHover(btnStartX, by, bw, bh, mx, my) then
                    love.graphics.setColor(0.5, 0.15, 0.15, 0.8)
                else
                    love.graphics.setColor(0.3, 0.1, 0.1, 0.6)
                end
                love.graphics.rectangle("fill", btnStartX, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 0.6, 0.6, 0.8)
                love.graphics.printf("BORRAR", btnStartX, by + math.floor((bh - 8) / 2), bw, "center")
                profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = btnStartX, y = by, w = bw, h = bh, action = "delete", index = i}
            end

            profilesMod.cardRects[#profilesMod.cardRects + 1] = {x = innerX, y = cy, w = innerW, h = cardH, index = i, profile = profile}
        else
            love.graphics.setFont(ui.fontNormal)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.print("VACÍO", innerX + 56, cy + math.floor((cardH - 22) / 2))

            local bx2 = innerX + innerW - 90
            local by2 = cy + math.floor((cardH - 30) / 2)
            local bw2 = 80
            local bh2 = 30
            if profilesMod.buttonHover(bx2, by2, bw2, bh2, mx, my) then
                love.graphics.setColor(0.2, 0.5, 0.2, 0.8)
            else
                love.graphics.setColor(0.15, 0.35, 0.15, 0.6)
            end
            love.graphics.rectangle("fill", bx2, by2, bw2, bh2, 4)
            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("CREAR", bx2, by2 + math.floor((bh2 - 8) / 2), bw2, "center")
            profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = bx2, y = by2, w = bw2, h = bh2, action = "create", index = i}
        end
    end

    -- Back button
    local bwx = profilesMod.panelX + math.floor((profilesMod.panelW - 140) / 2)
    local bwy = profilesMod.panelY + profilesMod.panelH - 38
    local bww = 140
    local bwh = 30
    if profilesMod.buttonHover(bwx, bwy, bww, bwh, mx, my) then
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
    else
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.35)
    end
    love.graphics.rectangle("fill", bwx, bwy, bww, bwh, 4)
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("VOLVER", bwx, bwy + 6, bww, "center")
    profilesMod.backBtn = {x = bwx, y = bwy, w = bww, h = bwh}
end

function profilesDraw.drawInputModal(profilesMod)
    local mw = 360
    local mh = 150
    local mx = profilesMod.panelX + (profilesMod.panelW - mw) / 2
    local my = profilesMod.panelY + (profilesMod.panelH - mh) / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx - 20, my - 20, mw + 40, mh + 40)

    love.graphics.setColor(0.15, 0.15, 0.25, 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, 6)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mw, mh, 6)

    local prompt = (profilesMod.confirmType == "rename") and "Nuevo nombre:" or "Nombre del perfil:"
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(prompt, mx + 20, my + 20)

    local fx = mx + 20
    local fy = my + 50
    local fw = mw - 40
    local fh = 30
    profilesMod.inputRect = {x = fx, y = fy, w = fw, h = fh}
    local mouseX, mouseY = love.mouse.getPosition()

    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    love.graphics.rectangle("fill", fx, fy, fw, fh, 4)
    if profilesMod.textInputActive then
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
    else
        love.graphics.setColor(0.3, 0.3, 0.4, 0.4)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", fx, fy, fw, fh, 4)

    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    local displayText = profilesMod.nameInput
    if profilesMod.textInputActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        displayText = displayText .. "|"
    end
    love.graphics.print(displayText, fx + 8, fy + 6)

    local bw2 = 100
    local bh2 = 28
    local by2 = fy + fh + 14
    local gap = 12
    local totalW = bw2 * 2 + gap
    local startX = mx + (mw - totalW) / 2

    if profilesMod.buttonHover(startX, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.2, 0.45, 0.2, 0.8)
    else
        love.graphics.setColor(0.15, 0.35, 0.15, 0.6)
    end
    love.graphics.rectangle("fill", startX, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("ACEPTAR", startX, by2 + 5, bw2, "center")
    profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = startX, y = by2, w = bw2, h = bh2, action = "input_confirm"}

    if profilesMod.buttonHover(startX + bw2 + gap, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.4, 0.2, 0.2, 0.8)
    else
        love.graphics.setColor(0.25, 0.15, 0.15, 0.6)
    end
    love.graphics.rectangle("fill", startX + bw2 + gap, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 0.7, 0.7)
    love.graphics.printf("CANCELAR", startX + bw2 + gap, by2 + 5, bw2, "center")
    profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = startX + bw2 + gap, y = by2, w = bw2, h = bh2, action = "input_cancel"}
end

function profilesDraw.drawConfirmModal(profilesMod)
    local mw = 360
    local mh = 140
    local mx = profilesMod.panelX + (profilesMod.panelW - mw) / 2
    local my = profilesMod.panelY + (profilesMod.panelH - mh) / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx - 20, my - 20, mw + 40, mh + 40)

    love.graphics.setColor(0.15, 0.15, 0.25, 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, 6)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mw, mh, 6)

    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(profilesMod.confirmMsg, mx + 20, my + 30, mw - 40, "center")

    local bw2 = 100
    local bh2 = 28
    local by2 = my + mh - 48
    local gap = 12
    local totalW = bw2 * 2 + gap
    local startX = mx + (mw - totalW) / 2
    local mouseX, mouseY = love.mouse.getPosition()

    if profilesMod.buttonHover(startX, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.5, 0.2, 0.2, 0.8)
    else
        love.graphics.setColor(0.3, 0.15, 0.15, 0.6)
    end
    love.graphics.rectangle("fill", startX, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 0.6, 0.6)
    love.graphics.printf("CONFIRMAR", startX, by2 + 5, bw2, "center")
    profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = startX, y = by2, w = bw2, h = bh2, action = "confirm_yes"}

    if profilesMod.buttonHover(startX + bw2 + gap, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
    end
    love.graphics.rectangle("fill", startX + bw2 + gap, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("CANCELAR", startX + bw2 + gap, by2 + 5, bw2, "center")
    profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = startX + bw2 + gap, y = by2, w = bw2, h = bh2, action = "confirm_no"}
end

function profilesDraw.drawAchievements(profilesMod)
    profilesMod.buttonRects = {}

    local pad = profilesMod.panelPad
    local cw = math.min(profilesMod.panelW - pad * 2, 600)
    local ch = math.min(profilesMod.panelH - pad * 2 - 10, 520)
    local cx = profilesMod.panelX + (profilesMod.panelW - cw) / 2
    local cy = profilesMod.panelY + (profilesMod.panelH - ch) / 2

    -- darken inside panel behind modal
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", profilesMod.panelX, profilesMod.panelY, profilesMod.panelW, profilesMod.panelH)

    -- container
    love.graphics.setColor(0.08, 0.08, 0.16, 1)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 8)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx, cy, cw, ch, 8)
    love.graphics.setLineWidth(1)

    -- title
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("LOGROS", cx, cy + 12, cw, "center")

    -- profile
    local profiles = persistence.getProfiles()
    local profile = profilesMod.confirmIndex and profiles[profilesMod.confirmIndex]
    local aDone = {}
    local aCount = 0
    if profile and profile.achievements then
        for id, v in pairs(profile.achievements) do
            if v.done then
                aDone[id] = true
                aCount = aCount + 1
            end
        end
    end

    local registry = achMod and achMod.registry or {}
    local orderedIds = {
        "first_kill", "enemy_25", "enemy_100",
        "combo_5", "combo_10",
        "coins_100", "coins_500",
        "stage_3", "boss_kill",
        "score_1000", "score_5000"
    }
    local totalAch = #orderedIds

    -- progress
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(0.6, 0.6, 0.8, 0.6)
    love.graphics.printf(aCount .. " / " .. totalAch .. " desbloqueados", cx, cy + 34, cw, "center")

    -- responsive tile grid
    local tileW = math.min(210, math.floor((cw - 40 - 3 * 10) / 4))
    local tileH = math.min(96, math.floor((ch - 90 - 3 * 10) / 3))
    tileW = math.max(140, tileW)
    tileH = math.max(60, tileH)
    local gapX = 10
    local gapY = 10
    local cols = math.max(2, math.floor((cw - 36 + gapX) / (tileW + gapX)))
    local rows = math.ceil(#orderedIds / cols)
    local gridStartX = cx + math.floor((cw - (cols * tileW + (cols - 1) * gapX)) / 2)
    local gridStartY = cy + 58

    local mouseX, mouseY = love.mouse.getPosition()

    for i, id in ipairs(orderedIds) do
        local def = registry[id]
        if def then
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local tx = gridStartX + col * (tileW + gapX)
            local ty = gridStartY + row * (tileH + gapY)

            if ty + tileH <= cy + ch - 40 then
                local isUnlocked = aDone[id]

                if isUnlocked then
                    love.graphics.setColor(0.12, 0.2, 0.34, 0.92)
                else
                    love.graphics.setColor(0.09, 0.09, 0.16, 0.75)
                end
                love.graphics.rectangle("fill", tx, ty, tileW, tileH, 6)

                if isUnlocked then
                    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 0.5)
                else
                    love.graphics.setColor(0.2, 0.22, 0.25, 0.3)
                end
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", tx, ty, tileW, tileH, 6)

                local iconSize = math.min(28, math.floor(tileH * 0.3))
                local iconX = tx + 8
                local iconY = ty + (tileH - iconSize) / 2

                if isUnlocked then
                    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 0.85)
                    love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 4)
                    love.graphics.setColor(0.08, 0.08, 0.16, 0.6)
                    love.graphics.setFont(ui.fontSmall)
                    love.graphics.printf("*", iconX, iconY + math.floor((iconSize - 8) / 2), iconSize, "center")
                else
                    love.graphics.setColor(0.25, 0.25, 0.28, 0.5)
                    love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 4)
                    love.graphics.setColor(0.35, 0.35, 0.38, 0.5)
                    love.graphics.setFont(ui.fontSmall)
                    love.graphics.printf("?", iconX, iconY + math.floor((iconSize - 8) / 2), iconSize, "center")
                end

                local textX = iconX + iconSize + 6
                local textW = tileW - textX + tx - 6

                if isUnlocked then
                    love.graphics.setColor(1, 1, 1, 0.92)
                else
                    love.graphics.setColor(0.45, 0.45, 0.48, 0.6)
                end
                love.graphics.setFont(ui.fontSmall)
                love.graphics.printf(def.title or id, textX, ty + 10, textW, "left")

                if isUnlocked then
                    love.graphics.setColor(0.65, 0.65, 0.78, 0.65)
                else
                    love.graphics.setColor(0.35, 0.35, 0.38, 0.4)
                end
                love.graphics.setFont(ui.fontSmall)
                love.graphics.printf(def.desc or "", textX, ty + tileH - 22, textW, "left")

                if not isUnlocked then
                    love.graphics.setColor(0.15, 0.15, 0.15, 0.18)
                    love.graphics.rectangle("fill", tx, ty, tileW, tileH, 6)
                    local lx = tx + tileW - 18
                    local ly = ty + 5
                    love.graphics.setColor(0.5, 0.5, 0.5, 0.45)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", lx, ly + 4, 10, 8, 2)
                    love.graphics.arc("line", "open", lx + 5, ly + 4, 4, math.pi, 0)
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end

    -- close button
    local bww = 130
    local bhh = 28
    local bxx = cx + (cw - bww) / 2
    local byy = cy + ch - 36

    if profilesMod.buttonHover(bxx, byy, bww, bhh, mouseX, mouseY) then
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
    else
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.35)
    end
    love.graphics.rectangle("fill", bxx, byy, bww, bhh, 4)
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("CERRAR", bxx, byy + 6, bww, "center")
    profilesMod.buttonRects[#profilesMod.buttonRects + 1] = {x = bxx, y = byy, w = bww, h = bhh, action = "close_achievements"}
end

return profilesDraw

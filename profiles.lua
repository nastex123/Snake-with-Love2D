local profilesMod = {}
local persistence = require('persistence')
local constants = require('constants')
local ui = require('ui')

profilesMod.visible = false

local state = 'select'
local nameInput = ""
local pendingName = ""
local inputIndex = nil
local confirmIndex = nil
local confirmType = nil
local confirmMsg = ""
local textInputActive = false
local prevActiveProfile = nil
local cardRects = {}
local buttonRects = {}
local backBtn = {}
local inputRect = {}

local CARD_W = 460
local CARD_H = 90
local CARD_GAP = 10

local function font(n)
    local fs = {ui.fontNormal, ui.fontLarge, ui.fontSmall}
    return fs[n] or ui.fontNormal
end

function profilesMod.open()
    profilesMod.visible = true
    state = 'select'
    nameInput = ""
    pendingName = ""
    inputIndex = nil
    confirmIndex = nil
    confirmType = nil
    confirmMsg = ""
    textInputActive = false
    prevActiveProfile = persistence.getActiveProfileIndex()
end

function profilesMod.close()
    profilesMod.visible = false
    textInputActive = false
end

function profilesMod.draw()
    if not profilesMod.visible then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- overlay background
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- title
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("GESTOR DE PERFILES", 0, 16, w, "center")

    if state == 'select' then
        profilesMod.drawSelect(w, h)
    elseif state == 'input' then
        profilesMod.drawSelect(w, h)
        profilesMod.drawInputModal(w, h)
    elseif state == 'confirm' then
        profilesMod.drawSelect(w, h)
        profilesMod.drawConfirmModal(w, h)
    elseif state == 'achievements' then
        profilesMod.drawAchievements(w, h)
    end
end

function profilesMod.drawSelect(w, h)
    cardRects = {}
    buttonRects = {}
    backBtn = {}

    local profiles = persistence.getProfiles()
    local activeIdx = persistence.getActiveProfileIndex()
    local mx, my = love.mouse.getPosition()

    local startY = 58
    local cardX = (w - CARD_W) / 2

    for i = 1, 3 do
        local cy = startY + (i - 1) * (CARD_H + CARD_GAP)
        local profile = profiles[i]
        local isActive = (activeIdx == i)

        -- card background
        local cardColor = isActive and {0.12, 0.18, 0.3, 0.9} or {0.12, 0.12, 0.22, 0.8}
        love.graphics.setColor(cardColor)
        love.graphics.rectangle("fill", cardX, cy, CARD_W, CARD_H, 6)

        -- border
        if isActive then
            local pulse = math.sin(love.timer.getTime() * 3) * 0.3 + 0.7
            love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], pulse)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", cardX, cy, CARD_W, CARD_H, 6)
        love.graphics.setLineWidth(1)

        -- slot number badge
        love.graphics.setFont(ui.fontSmall)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.print("SLOT " .. i, cardX + 8, cy + 6)

        if profile then
            -- name
            love.graphics.setFont(ui.fontNormal)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(profile.name, cardX + 60, cy + 8)

            -- stats
            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
            love.graphics.print("$" .. profile.monedas, cardX + 60, cy + 32)
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.print("SCORE: " .. profile.highScore, cardX + 60, cy + 48)

            -- achievement/unlock count
            local aCount = 0
            for _, v in pairs(profile.achievements) do
                if v.done then aCount = aCount + 1 end
            end
            local uCount = 0
            for _, v in pairs(profile.unlocks) do
                if v then uCount = uCount + 1 end
            end
            love.graphics.setColor(0.6, 0.6, 0.8, 0.5)
            love.graphics.print("Logros: " .. aCount .. "  Desbloqueos: " .. uCount, cardX + 60, cy + 64)

            -- small "VER LOGROS" link
            local achX = cardX + 60
            local achY2 = cy + 72
            local achW = 70
            local achH = 14
            if profilesMod.buttonHover(achX, achY2, achW, achH, mx, my) then
                love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.7)
            else
                love.graphics.setColor(0.4, 0.4, 0.6, 0.4)
            end
            love.graphics.setFont(ui.fontSmall)
            love.graphics.print("Ver Logros", achX, achY2)
            buttonRects[#buttonRects + 1] = {x = achX, y = achY2, w = achW, h = achH, action = "achievements", index = i}

            -- buttons row
            local bx = cardX + CARD_W - 8
            local bw = 82
            local bh = 24
            local bgap = 4
            local by = cy + 8

            if isActive then
                love.graphics.setColor(0.2, 0.5, 0.2, 0.8)
                love.graphics.rectangle("fill", bx - bw, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.printf("ACTIVO", bx - bw, by + 4, bw, "center")
            else
                if profilesMod.buttonHover(bx - bw, by, bw, bh, mx, my) then
                    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.8)
                else
                    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
                end
                love.graphics.rectangle("fill", bx - bw, by, bw, bh, 4)
                love.graphics.setFont(ui.fontSmall)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("SELECCIONAR", bx - bw, by + 4, bw, "center")
                buttonRects[#buttonRects + 1] = {x = bx - bw, y = by, w = bw, h = bh, action = "select", index = i}
            end

            by = by + bh + bgap
            if profilesMod.buttonHover(bx - bw, by, bw, bh, mx, my) then
                love.graphics.setColor(0.3, 0.3, 0.5, 0.8)
            else
                love.graphics.setColor(0.2, 0.2, 0.35, 0.6)
            end
            love.graphics.rectangle("fill", bx - bw, by, bw, bh, 4)
            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("RENOMBRAR", bx - bw, by + 4, bw, "center")
            buttonRects[#buttonRects + 1] = {x = bx - bw, y = by, w = bw, h = bh, action = "rename", index = i}

            by = by + bh + bgap
            if profilesMod.buttonHover(bx - bw, by, bw, bh, mx, my) then
                love.graphics.setColor(0.5, 0.3, 0.2, 0.8)
            else
                love.graphics.setColor(0.35, 0.2, 0.15, 0.6)
            end
            love.graphics.rectangle("fill", bx - bw, by, bw, bh, 4)
            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("RESTABLECER", bx - bw, by + 4, bw, "center")
            buttonRects[#buttonRects + 1] = {x = bx - bw, y = by, w = bw, h = bh, action = "reset", index = i}

            by = by + bh + bgap
            if profilesMod.buttonHover(bx - bw, by, bw, bh, mx, my) then
                love.graphics.setColor(0.5, 0.15, 0.15, 0.8)
            else
                love.graphics.setColor(0.3, 0.1, 0.1, 0.6)
            end
            love.graphics.rectangle("fill", bx - bw, by, bw, bh, 4)
            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 0.6, 0.6, 0.8)
            love.graphics.printf("BORRAR", bx - bw, by + 4, bw, "center")
            buttonRects[#buttonRects + 1] = {x = bx - bw, y = by, w = bw, h = bh, action = "delete", index = i}

            cardRects[#cardRects + 1] = {x = cardX, y = cy, w = CARD_W, h = CARD_H, index = i, profile = profile}
        else
            -- empty slot
            love.graphics.setFont(ui.fontNormal)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.print("VACÍO", cardX + 60, cy + 28)

            -- crear button
            local bx = cardX + CARD_W - 90
            local by2 = cy + (CARD_H - 30) / 2
            local bw2 = 80
            local bh2 = 30
            if profilesMod.buttonHover(bx, by2, bw2, bh2, mx, my) then
                love.graphics.setColor(0.2, 0.5, 0.2, 0.8)
            else
                love.graphics.setColor(0.15, 0.35, 0.15, 0.6)
            end
            love.graphics.rectangle("fill", bx, by2, bw2, bh2, 4)
            love.graphics.setFont(ui.fontSmall)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("CREAR", bx, by2 + 6, bw2, "center")
            buttonRects[#buttonRects + 1] = {x = bx, y = by2, w = bw2, h = bh2, action = "create", index = i}
        end
    end

    -- back button
    local bwx = 120
    local bwy = h - 44
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
    backBtn = {x = bwx, y = bwy, w = bww, h = bwh}
end

function profilesMod.drawInputModal(w, h)
    local mw = 360
    local mh = 150
    local mx = (w - mw) / 2
    local my = (h - mh) / 2

    -- dim background
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx - 20, my - 20, mw + 40, mh + 40)

    -- modal bg
    love.graphics.setColor(0.15, 0.15, 0.25, 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, 6)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mw, mh, 6)

    -- prompt
    local prompt = (confirmType == "rename") and "Nuevo nombre:" or "Nombre del perfil:"
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(prompt, mx + 20, my + 20)

    -- text input field
    local fx = mx + 20
    local fy = my + 50
    local fw = mw - 40
    local fh = 30
    inputRect = {x = fx, y = fy, w = fw, h = fh}
    local mouseX, mouseY = love.mouse.getPosition()

    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    love.graphics.rectangle("fill", fx, fy, fw, fh, 4)
    if textInputActive then
        love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.6)
    else
        love.graphics.setColor(0.3, 0.3, 0.4, 0.4)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", fx, fy, fw, fh, 4)

    -- text display
    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    local displayText = nameInput
    if textInputActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        displayText = displayText .. "|"
    end
    love.graphics.print(displayText, fx + 8, fy + 6)

    -- buttons
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
    buttonRects[#buttonRects + 1] = {x = startX, y = by2, w = bw2, h = bh2, action = "input_confirm"}

    if profilesMod.buttonHover(startX + bw2 + gap, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.4, 0.2, 0.2, 0.8)
    else
        love.graphics.setColor(0.25, 0.15, 0.15, 0.6)
    end
    love.graphics.rectangle("fill", startX + bw2 + gap, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 0.7, 0.7)
    love.graphics.printf("CANCELAR", startX + bw2 + gap, by2 + 5, bw2, "center")
    buttonRects[#buttonRects + 1] = {x = startX + bw2 + gap, y = by2, w = bw2, h = bh2, action = "input_cancel"}
end

function profilesMod.drawConfirmModal(w, h)
    local mw = 360
    local mh = 140
    local mx = (w - mw) / 2
    local my = (h - mh) / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx - 20, my - 20, mw + 40, mh + 40)

    love.graphics.setColor(0.15, 0.15, 0.25, 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, 6)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mw, mh, 6)

    love.graphics.setFont(ui.fontNormal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(confirmMsg, mx + 20, my + 30, mw - 40, "center")

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
    buttonRects[#buttonRects + 1] = {x = startX, y = by2, w = bw2, h = bh2, action = "confirm_yes"}

    if profilesMod.buttonHover(startX + bw2 + gap, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
    end
    love.graphics.rectangle("fill", startX + bw2 + gap, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("CANCELAR", startX + bw2 + gap, by2 + 5, bw2, "center")
    buttonRects[#buttonRects + 1] = {x = startX + bw2 + gap, y = by2, w = bw2, h = bh2, action = "confirm_no"}
end

function profilesMod.buttonHover(x, y, w, h, mx, my)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function profilesMod.mousepressed(x, y, button)
    if button ~= 1 then return end
    if not profilesMod.visible then return end

    -- check modals first
    if state == 'input' then
        -- check text input click
        if inputRect and profilesMod.buttonHover(inputRect.x, inputRect.y, inputRect.w, inputRect.h, x, y) then
            textInputActive = true
            return
        end
        -- check modal buttons
        for _, btn in ipairs(buttonRects) do
            if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
                if btn.action == "input_confirm" then
                    profilesMod.handleInputConfirm()
                elseif btn.action == "input_cancel" then
                    state = 'select'
                    textInputActive = false
                    nameInput = ""
                end
                return
            end
        end
        return
    end

    if state == 'confirm' then
        for _, btn in ipairs(buttonRects) do
            if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
                if btn.action == "confirm_yes" then
                    profilesMod.handleConfirmYes()
                elseif btn.action == "confirm_no" then
                    state = 'select'
                    confirmIndex = nil
                    confirmType = nil
                end
                return
            end
        end
        return
    end

    if state == 'achievements' then
        for _, btn in ipairs(buttonRects) do
            if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
                if btn.action == "close_achievements" then
                    state = 'select'
                end
                return
            end
        end
        return
    end

    -- check back button
    if backBtn and profilesMod.buttonHover(backBtn.x, backBtn.y, backBtn.w, backBtn.h, x, y) then
        profilesMod.close()
        return
    end

    -- check buttons
    for _, btn in ipairs(buttonRects) do
        if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
            if btn.action == "create" then
                state = 'input'
                confirmType = "create"
                inputIndex = btn.index
                nameInput = ""
                textInputActive = true
            elseif btn.action == "select" then
                profilesMod.handleSelect(btn.index)
            elseif btn.action == "rename" then
                state = 'input'
                confirmType = "rename"
                inputIndex = btn.index
                local profiles = persistence.getProfiles()
                if profiles[btn.index] then
                    nameInput = profiles[btn.index].name
                else
                    nameInput = ""
                end
                textInputActive = true
            elseif btn.action == "reset" then
                state = 'confirm'
                confirmType = "reset"
                confirmIndex = btn.index
                local profiles = persistence.getProfiles()
                local pname = profiles[btn.index] and profiles[btn.index].name or "este perfil"
                confirmMsg = "¿Restablecer " .. pname .. "?\nSe perderán monedas, puntuación y progreso."
            elseif btn.action == "achievements" then
                state = 'achievements'
                confirmIndex = btn.index
            elseif btn.action == "delete" then
                state = 'confirm'
                confirmType = "delete"
                confirmIndex = btn.index
                local profiles = persistence.getProfiles()
                local pname = profiles[btn.index] and profiles[btn.index].name or "este perfil"
                confirmMsg = "¿Borrar " .. pname .. "?\nEsta acción no se puede deshacer."
            end
            return
        end
    end
end

function profilesMod.handleSelect(index)
    local ok, msg, profile = persistence.selectProfile(index)
    if ok and profile then
        applyActiveProfile()
    end
end

function profilesMod.handleInputConfirm()
    local text = nameInput:gsub("^%s*(.-)%s*$", "%1")
    if #text == 0 then
        text = "Jugador " .. inputIndex
    end
    if confirmType == "create" then
        local ok, msg = persistence.createProfile(text)
        if ok then
            applyActiveProfile()
        end
    elseif confirmType == "rename" then
        persistence.renameProfile(inputIndex, text)
    end
    state = 'select'
    textInputActive = false
    nameInput = ""
    confirmType = nil
    inputIndex = nil
end

function profilesMod.handleConfirmYes()
    if confirmType == "delete" then
        persistence.deleteProfile(confirmIndex)
        if persistence.getActiveProfile() then
            applyActiveProfile()
        end
    elseif confirmType == "reset" then
        persistence.resetProfile(confirmIndex)
        applyActiveProfile()
    end
    state = 'select'
    confirmIndex = nil
    confirmType = nil
end

function profilesMod.textinput(text)
    if not profilesMod.visible then return end
    if state == 'input' and textInputActive then
        nameInput = nameInput .. text
    end
end

function profilesMod.keypressed(key)
    if not profilesMod.visible then return end
    if state == 'input' and textInputActive then
        if key == "backspace" then
            nameInput = nameInput:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            profilesMod.handleInputConfirm()
        elseif key == "escape" then
            state = 'select'
            textInputActive = false
            nameInput = ""
        end
    elseif state == 'achievements' then
        if key == "escape" then
            state = 'select'
        end
    elseif state == 'select' then
        if key == "escape" then
            profilesMod.close()
        end
    end
end

function profilesMod.drawAchievements(w, h)
    local mw = 460
    local mh = 400
    local mx = (w - mw) / 2
    local my = (h - mh) / 2

    -- dim background
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx - 20, my - 20, mw + 40, mh + 40)

    -- modal bg
    love.graphics.setColor(0.12, 0.12, 0.22, 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, 6)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx, my, mw, mh, 6)

    -- title
    love.graphics.setFont(ui.fontLarge)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3])
    love.graphics.printf("LOGROS", mx, my + 10, mw, "center")

    -- Get profile's achievements
    local profiles = persistence.getProfiles()
    local profile = confirmIndex and profiles[confirmIndex]
    local aDone = {}
    if profile and profile.achievements then
        for id, v in pairs(profile.achievements) do
            if v.done then aDone[id] = true end
        end
    end

    -- Import achievements registry
    local achMod = require('achievements')
    local registry = achMod and achMod.registry or {}

    local yOff = my + 50
    local itemH = 24
    local count = 0

    love.graphics.setFont(ui.fontSmall)
    for id, def in pairs(registry) do
        local isUnlocked = aDone[id]
        local y2 = yOff + count * itemH

        if y2 + itemH > my + mh - 40 then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.print("...", mx + 20, y2)
            break
        end

        -- icon/color
        if isUnlocked then
            love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3], 0.9)
            love.graphics.print("\238", mx + 16, y2) -- star symbol
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 0.5)
            love.graphics.print("?", mx + 16, y2)
        end

        -- title
        if isUnlocked then
            love.graphics.setColor(1, 1, 1, 0.9)
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
        end
        love.graphics.print(def.title or id, mx + 36, y2)

        -- description
        if isUnlocked then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.6)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
        end
        love.graphics.print(def.desc or "", mx + 160, y2)

        count = count + 1
    end

    -- close button
    local bx = mx + mw - 80
    local by2 = my + mh - 32
    local bw2 = 60
    local bh2 = 22
    local mouseX, mouseY = love.mouse.getPosition()
    if profilesMod.buttonHover(bx, by2, bw2, bh2, mouseX, mouseY) then
        love.graphics.setColor(0.3, 0.3, 0.5, 0.8)
    else
        love.graphics.setColor(0.2, 0.2, 0.3, 0.6)
    end
    love.graphics.rectangle("fill", bx, by2, bw2, bh2, 4)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("CERRAR", bx, by2 + 4, bw2, "center")
    buttonRects[#buttonRects + 1] = {x = bx, y = by2, w = bw2, h = bh2, action = "close_achievements"}
end

return profilesMod

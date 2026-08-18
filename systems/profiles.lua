local profilesMod = {}
local persistence = require('systems.persistence')
local constants = require('constants')
local ui = require('ui.ui')
local achMod = require('systems.achievements')
local gameflow = require('systems.gameflow')
local profilesDraw = require('systems.profilesDraw')

profilesMod.visible = false

profilesMod.state = 'select'
profilesMod.nameInput = ""
profilesMod.pendingName = ""
profilesMod.inputIndex = nil
profilesMod.confirmIndex = nil
profilesMod.confirmType = nil
profilesMod.confirmMsg = ""
profilesMod.textInputActive = false
profilesMod.prevActiveProfile = nil
profilesMod.cardRects = {}
profilesMod.buttonRects = {}
profilesMod.backBtn = {}
profilesMod.inputRect = {}
profilesMod.CARD_W = 460
profilesMod.CARD_H = 90
profilesMod.CARD_GAP = 10
profilesMod.CARD_H_MIN = 64
profilesMod.panelX, profilesMod.panelY, profilesMod.panelW, profilesMod.panelH, profilesMod.panelPad = 0,0,0,0,16
profilesMod.scrollOffset = 0
profilesMod.maxScroll = 0
profilesMod.scrollEnabled = false






























function profilesMod.open()
    profilesMod.visible = true
    profilesMod.state = 'select'
    profilesMod.nameInput = ""
    profilesMod.pendingName = ""
    profilesMod.inputIndex = nil
    profilesMod.confirmIndex = nil
    profilesMod.confirmType = nil
    profilesMod.confirmMsg = ""
    profilesMod.textInputActive = false
    profilesMod.prevActiveProfile = persistence.getActiveProfileIndex()
end

function profilesMod.close()
    profilesMod.visible = false

profilesMod.state = 'select'
profilesMod.nameInput = ""
profilesMod.pendingName = ""
profilesMod.inputIndex = nil
profilesMod.confirmIndex = nil
profilesMod.confirmType = nil
profilesMod.confirmMsg = ""
profilesMod.textInputActive = false
profilesMod.prevActiveProfile = nil
profilesMod.cardRects = {}
profilesMod.buttonRects = {}
profilesMod.backBtn = {}
profilesMod.inputRect = {}
profilesMod.CARD_W = 460
profilesMod.CARD_H = 90
profilesMod.CARD_GAP = 10
profilesMod.CARD_H_MIN = 64
profilesMod.panelX, profilesMod.panelY, profilesMod.panelW, profilesMod.panelH, profilesMod.panelPad = 0,0,0,0,16
profilesMod.scrollOffset = 0
profilesMod.maxScroll = 0
profilesMod.scrollEnabled = false

    profilesMod.textInputActive = false
end

function profilesMod.draw()
    if not profilesMod.visible then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- responsive panel dimensions
    local maxW = 1100
    local maxH = math.min(760, h - 20)
    profilesMod.panelW = math.min(maxW, math.floor(w * 0.88))
    profilesMod.panelH = math.min(maxH, math.floor(h * 0.86))
    profilesMod.panelX = math.floor((w - profilesMod.panelW) / 2)
    profilesMod.panelY = math.floor((h - profilesMod.panelH) / 2)

    -- overlay
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- panel background
    love.graphics.setColor(constants.COLOR_PANEL)
    love.graphics.rectangle("fill", profilesMod.panelX, profilesMod.panelY, profilesMod.panelW, profilesMod.panelH, 10)
    love.graphics.setColor(constants.COLOR_ACCENT[1], constants.COLOR_ACCENT[2], constants.COLOR_ACCENT[3], 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", profilesMod.panelX, profilesMod.panelY, profilesMod.panelW, profilesMod.panelH, 10)
    love.graphics.setLineWidth(1)

    -- clip all content inside panel
    local oldSc = {love.graphics.getScissor()}
    love.graphics.setScissor(profilesMod.panelX, profilesMod.panelY, profilesMod.panelW, profilesMod.panelH)

    if profilesMod.state == 'select' then
        profilesDraw.drawSelect(profilesMod, w, h)
    elseif profilesMod.state == 'input' then
        profilesDraw.drawSelect(profilesMod, w, h)
        profilesDraw.drawInputModal(profilesMod)
    elseif profilesMod.state == 'confirm' then
        profilesDraw.drawSelect(profilesMod, w, h)
        profilesDraw.drawConfirmModal(profilesMod)
    elseif profilesMod.state == 'achievements' then
        profilesDraw.drawAchievements(profilesMod)
    end

    -- restore scissor
    if oldSc[1] then
        love.graphics.setScissor(oldSc[1], oldSc[2], oldSc[3], oldSc[4])
    else
        love.graphics.setScissor()
    end
end




function profilesMod.buttonHover(x, y, w, h, mx, my)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function profilesMod.mousepressed(x, y, button)
    if button ~= 1 then return end
    if not profilesMod.visible then return end

    -- check modals first
    if profilesMod.state == 'input' then
        -- check text input click
        if profilesMod.inputRect and profilesMod.buttonHover(profilesMod.inputRect.x, profilesMod.inputRect.y, profilesMod.inputRect.w, profilesMod.inputRect.h, x, y) then
            profilesMod.textInputActive = true
            return
        end
        -- check modal buttons
        for _, btn in ipairs(profilesMod.buttonRects) do
            if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
                if btn.action == "input_confirm" then
                    profilesMod.handleInputConfirm()
                elseif btn.action == "input_cancel" then
                    profilesMod.state = 'select'
                    profilesMod.textInputActive = false
                    profilesMod.nameInput = ""
                end
                return
            end
        end
        return
    end

    if profilesMod.state == 'confirm' then
        for _, btn in ipairs(profilesMod.buttonRects) do
            if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
                if btn.action == "confirm_yes" then
                    profilesMod.handleConfirmYes()
                elseif btn.action == "confirm_no" then
                    profilesMod.state = 'select'
                    profilesMod.confirmIndex = nil
                    profilesMod.confirmType = nil
                end
                return
            end
        end
        return
    end

    if profilesMod.state == 'achievements' then
        for _, btn in ipairs(profilesMod.buttonRects) do
            if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
                if btn.action == "close_achievements" then
                    profilesMod.state = 'select'
                end
                return
            end
        end
        return
    end

    -- check back button
    if profilesMod.backBtn and profilesMod.buttonHover(profilesMod.backBtn.x, profilesMod.backBtn.y, profilesMod.backBtn.w, profilesMod.backBtn.h, x, y) then
        profilesMod.close()
        return
    end

    -- check buttons
    for _, btn in ipairs(profilesMod.buttonRects) do
        if profilesMod.buttonHover(btn.x, btn.y, btn.w, btn.h, x, y) then
            if btn.action == "create" then
                profilesMod.state = 'input'
                profilesMod.confirmType = "create"
                profilesMod.inputIndex = btn.index
                profilesMod.nameInput = ""
                profilesMod.textInputActive = true
            elseif btn.action == "select" then
                profilesMod.handleSelect(btn.index)
            elseif btn.action == "rename" then
                profilesMod.state = 'input'
                profilesMod.confirmType = "rename"
                profilesMod.inputIndex = btn.index
                local profiles = persistence.getProfiles()
                if profiles[btn.index] then
                    profilesMod.nameInput = profiles[btn.index].name
                else
                    profilesMod.nameInput = ""
                end
                profilesMod.textInputActive = true
            elseif btn.action == "reset" then
                profilesMod.state = 'confirm'
                profilesMod.confirmType = "reset"
                profilesMod.confirmIndex = btn.index
                local profiles = persistence.getProfiles()
                local pname = profiles[btn.index] and profiles[btn.index].name or "este perfil"
                profilesMod.confirmMsg = "¿Restablecer " .. pname .. "?\nSe perderán monedas, puntuación y progreso."
            elseif btn.action == "achievements" then
                profilesMod.state = 'achievements'
                profilesMod.confirmIndex = btn.index
            elseif btn.action == "delete" then
                profilesMod.state = 'confirm'
                profilesMod.confirmType = "delete"
                profilesMod.confirmIndex = btn.index
                local profiles = persistence.getProfiles()
                local pname = profiles[btn.index] and profiles[btn.index].name or "este perfil"
                profilesMod.confirmMsg = "¿Borrar " .. pname .. "?\nEsta acción no se puede deshacer."
            end
            return
        end
    end
end

function profilesMod.handleSelect(index)
    local ok, msg, profile = persistence.selectProfile(index)
    if ok and profile then
        gameflow.applyActiveProfile()
    end
end

function profilesMod.handleInputConfirm()
    local text = profilesMod.nameInput:gsub("^%s*(.-)%s*$", "%1")
    if #text == 0 then
        text = "Jugador " .. profilesMod.inputIndex
    end
    if profilesMod.confirmType == "create" then
        local ok, msg = persistence.createProfile(text)
        if ok then
            gameflow.applyActiveProfile()
        end
    elseif profilesMod.confirmType == "rename" then
        persistence.renameProfile(profilesMod.inputIndex, text)
    end
    profilesMod.state = 'select'
    profilesMod.textInputActive = false
    profilesMod.nameInput = ""
    profilesMod.confirmType = nil
    profilesMod.inputIndex = nil
end

function profilesMod.handleConfirmYes()
    if profilesMod.confirmType == "delete" then
        persistence.deleteProfile(profilesMod.confirmIndex)
        if persistence.getActiveProfile() then
            gameflow.applyActiveProfile()
        end
    elseif profilesMod.confirmType == "reset" then
        persistence.resetProfile(profilesMod.confirmIndex)
        gameflow.applyActiveProfile()
    end
    profilesMod.state = 'select'
    profilesMod.confirmIndex = nil
    profilesMod.confirmType = nil
end

function profilesMod.textinput(text)
    if not profilesMod.visible then return end
    if profilesMod.state == 'input' and profilesMod.textInputActive then
        profilesMod.nameInput = profilesMod.nameInput .. text
    end
end

function profilesMod.keypressed(key)
    if not profilesMod.visible then return end
    if profilesMod.state == 'input' and profilesMod.textInputActive then
        if key == "backspace" then
            profilesMod.nameInput = profilesMod.nameInput:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            profilesMod.handleInputConfirm()
        elseif key == "escape" then
            profilesMod.state = 'select'
            profilesMod.textInputActive = false
            profilesMod.nameInput = ""
        end
    elseif profilesMod.state == 'achievements' then
        if key == "escape" then
            profilesMod.state = 'select'
        end
    elseif profilesMod.state == 'select' then
        if key == "escape" then
            profilesMod.close()
        end
    end
end


function profilesMod.wheelmoved(dx, dy)
    if not profilesMod.visible then return end
    if profilesMod.state ~= 'select' or not profilesMod.scrollEnabled or profilesMod.maxScroll <= 0 then return end
    profilesMod.scrollOffset = math.max(0, math.min(profilesMod.scrollOffset - dy * 24, profilesMod.maxScroll))
end

return profilesMod

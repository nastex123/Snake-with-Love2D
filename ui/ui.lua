-- ui/ui.lua - Facade de UI: estado y fuentes, delega dibujo a submódulos
-- Submodulos: introUI, menuUI, hudUI, toastsUI, popupsUI, overlaysUI
local ui = {}
local constants = require("constants")

local intro = require("ui.introUI")
local menu = require("ui.menuUI")
local hud = require("ui.hudUI")
local toastsUI = require("ui.toastsUI")
local popupsUI = require("ui.popupsUI")
local overlays = require("ui.overlaysUI")

-- Estado
ui.popups = {}
ui.toasts = ui.toasts or {}
ui._toastQueue = ui._toastQueue or {}
ui.menuButtons = {}
ui.menuHoverId = nil
ui.menuPressedId = nil

-- Ajustes de accesibilidad y escala aplicables en runtime
ui.scale = 1.0
ui.highContrast = false
ui.colorblind = 'off'

function ui.load()
    local ok, err = pcall(function()
        ui.fontTitle = love.graphics.newFont(constants.FONT_FILE, constants.FONT_TITLE)
        ui.fontLarge = love.graphics.newFont(constants.FONT_FILE, constants.FONT_LARGE)
        ui.fontNormal = love.graphics.newFont(constants.FONT_FILE, constants.FONT_NORMAL)
        ui.fontSmall = love.graphics.newFont(constants.FONT_FILE, constants.FONT_SMALL)
    end)
    if not ok then
        ui.fontTitle = love.graphics.newFont(constants.FONT_TITLE)
        ui.fontLarge = love.graphics.newFont(constants.FONT_LARGE)
        ui.fontNormal = love.graphics.newFont(constants.FONT_NORMAL)
        ui.fontSmall = love.graphics.newFont(constants.FONT_SMALL)
    end
end

function ui.setScale(s)
    ui.scale = s or 1.0
end

function ui.applyHighContrast(flag)
    ui.highContrast = not not flag
end

function ui.applyColorblind(mode)
    ui.colorblind = mode or 'off'
end

function ui.resetPopups()
    ui.popups = {}
end

-- Intro
function ui.drawBalatroIntro(t, globalTime, glowPass)
    intro.draw(ui, t, globalTime, glowPass)
end

function ui.drawHighScoreCelebration(puntuacion, highScore)
    intro.drawHighScore(ui, puntuacion, highScore)
end

-- Menu
function ui.drawMenu(menuTime, globalTime, highScore)
    menu.draw(ui, menuTime, globalTime, highScore)
end

function ui.drawMenuGlow(menuTime, globalTime)
    menu.drawGlow(ui, menuTime, globalTime)
end

function ui.menuMousePressed(x, y)
    return menu.mousePressed(ui, x, y)
end

function ui.updateMenuHover(x, y)
    menu.updateHover(ui, x, y)
end

function ui.setMenuPressed(id)
    menu.setPressed(ui, id)
end

function ui.clearMenuPressed()
    menu.clearPressed(ui)
end

-- HUD
function ui.drawGrid(anchoGrilla, altoGrilla, time, comboIntensity)
    hud.drawGrid(ui, anchoGrilla, altoGrilla, time, comboIntensity)
end

function ui.drawHUD(puntuacion, highScore, monedas, shieldActive, magnetTimer, magnetDuration, baseSpeed, velocidadActual, comboCount, activeTimers, etapa, sala, objetivoSala, scale)
    hud.drawHUD(ui, puntuacion, highScore, monedas, shieldActive, magnetTimer, magnetDuration, baseSpeed, velocidadActual, comboCount, activeTimers, etapa, sala, objetivoSala, scale)
end

function ui.drawSlots(slotDisplay)
    hud.drawSlots(ui, slotDisplay)
end

function ui.drawComboFlash(time, comboCount, timer)
    hud.drawComboFlash(ui, time, comboCount, timer)
end

-- Toasts
function ui.showToast(payload)
    toastsUI.show(ui, payload)
end

function ui.updateToasts(dt)
    toastsUI.update(ui, dt)
end

function ui.drawToasts()
    toastsUI.draw(ui)
end

-- Popups
function ui.addPopup(text, gridX, gridY)
    popupsUI.add(ui, text, gridX, gridY)
end

function ui.updatePopups(dt)
    popupsUI.update(ui, dt)
end

function ui.drawPopups()
    popupsUI.draw(ui)
end

-- Overlays
function ui.drawPauseOverlay()
    overlays.drawPause(ui)
end

function ui.drawDungeonMap(dungeonData)
    overlays.drawDungeonMap(ui, dungeonData)
end

function ui.drawDebugDungeonOverlay(dungeonData)
    overlays.drawDebugDungeon(ui, dungeonData)
end

return ui
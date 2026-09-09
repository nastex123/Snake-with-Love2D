-- tests/test_scope_27_display_settings.lua
-- Suite de pruebas automatizadas para el pipeline de pantalla y ajustes graficos (AUDIT-SETTINGS-DISPLAY)

local harness = require("tests.test_harness")
local helper = require("tests.test_systems_helper")
local setupCleanWorld = helper.setupCleanWorld
local persistence = helper.persistence
local settings = helper.settings
local shaders = require("render.shaders")
local Input = require("core.input")
local Assets = require("core.assets")

harness.describe("Scope 27: Display Pipeline & Settings Integration", function()
    harness.before_each(function()
        setupCleanWorld()
    end)

    harness.it("persistence.applySettings with heavy=true applies saved resolution mode", function()
        local setModeCalled = false
        local setModeW, setModeH = 0, 0
        local origSetMode = love.window.setMode
        love.window.setMode = function(w, h, flags)
            setModeCalled = true
            setModeW, setModeH = w, h
            return true
        end

        local customSettings = persistence.defaults()
        customSettings.graphics.resolution = {width = 1280, height = 720}
        customSettings.graphics.fullscreen = false

        persistence.applySettings(customSettings, {heavy = true})

        harness.assert_true(setModeCalled, "love.window.setMode must be called when heavy=true")
        harness.assert_equal(1280, setModeW, "Window width must match saved resolution")
        harness.assert_equal(720, setModeH, "Window height must match saved resolution")

        love.window.setMode = origSetMode
    end)

    harness.it("persistence.applyFilter propagates setDefaultFilter and updates shaders filter", function()
        local defaultFilterCalled = false
        local assignedFilter = nil
        local origSetDefFilter = love.graphics.setDefaultFilter
        love.graphics.setDefaultFilter = function(min, mag)
            defaultFilterCalled = true
            assignedFilter = min
        end

        persistence.applyFilter("nearest")
        harness.assert_true(defaultFilterCalled, "setDefaultFilter must be called globally")
        harness.assert_equal("nearest", assignedFilter, "Global default filter must be nearest")
        harness.assert_equal("nearest", shaders.getFilter(), "Shaders getFilter() must return nearest")

        persistence.applyFilter("linear")
        harness.assert_equal("linear", assignedFilter, "Global default filter must update to linear")
        harness.assert_equal("linear", shaders.getFilter(), "Shaders getFilter() must return linear")

        love.graphics.setDefaultFilter = origSetDefFilter
    end)

    harness.it("shaders.recreateCanvases calculates reduced virtual resolution when pixelScale > 1", function()
        shaders.recreateCanvases(2, "nearest")
        harness.assert_equal(2, shaders.getPixelScale(), "PixelScale must equal 2")

        local realW, realH = love.graphics.getWidth(), love.graphics.getHeight()
        local expectedW = math.floor(realW / 2)
        local expectedH = math.floor(realH / 2)

        local canvases = shaders.getCanvases()
        harness.assert_not_nil(canvases.scene, "canvasScene must exist")
        harness.assert_not_nil(canvases.final, "canvasFinal must exist")

        -- Restore pixelScale 1
        shaders.recreateCanvases(1, "linear")
        harness.assert_equal(1, shaders.getPixelScale(), "PixelScale restored to 1")
    end)

    harness.it("Input.getMousePosition scales coordinates inversely when pixelScale > 1", function()
        local origGetPos = love.mouse.getPosition
        love.mouse.getPosition = function()
            return 200, 100
        end

        shaders.pixelScale = 2
        local mx, my = Input.getMousePosition()
        harness.assert_equal(100, mx, "X coordinate must be divided by pixelScale")
        harness.assert_equal(50, my, "Y coordinate must be divided by pixelScale")

        shaders.pixelScale = 1
        local normX, normY = Input.getMousePosition()
        harness.assert_equal(200, normX, "X coordinate must remain 1:1 when pixelScale is 1")
        harness.assert_equal(100, normY, "Y coordinate must remain 1:1 when pixelScale is 1")

        love.mouse.getPosition = origGetPos
    end)

    harness.it("Assets.applyFilter updates cached images filter mode", function()
        local setFilterCalled = false
        local filterArg = nil
        local mockImg = {
            setFilter = function(self, min, mag)
                setFilterCalled = true
                filterArg = min
            end
        }
        Assets.clearImages()
        local origNewImage = love.graphics.newImage
        love.graphics.newImage = function(p) return mockImg end

        local img = Assets.getImage("test_sprite.png")
        harness.assert_not_nil(img, "Image must be loaded")

        Assets.applyFilter("linear")
        harness.assert_true(setFilterCalled, "applyFilter must trigger setFilter on images")
        harness.assert_equal("linear", filterArg, "Filter argument must match linear")

        love.graphics.newImage = origNewImage
        Assets.clearImages()
    end)
end)

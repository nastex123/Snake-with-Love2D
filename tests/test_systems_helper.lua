local helper = {}
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local items = require("systems.items")
local shop = require("systems.shop")
local persistence = require("systems.persistence")
local settings = require("systems.settings")
local settingsDraw = require("systems.settingsDraw")
local profilesMod = require("systems.profiles")
local profilesDraw = require("systems.profilesDraw")
local achievementsMod = require("systems.achievements")
local playerMod = require("systems.player")
local gameflow = require("systems.gameflow")
local gamestates = require("systems.gamestates")
local debugTools = require("systems.debugTools")
local debugLogo = require("systems.debugLogo")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local worldMod = require("world.world")
local uiMod = require("ui.ui")

function helper.setupCleanWorld()
    love.filesystem.__clearVFS()
    persistence.init()
    persistence.initProfiles()
    world.reset()
    world.stateInit({
        time = 0,
        gameState = constants.GAME_STATE_PLAYING,
        monedas = 100,
        puntuacion = 0,
        highScore = 0,
        highestStreak = 1.0,
        survivalStreak = 1.0,
        baseSpeed = constants.VELOCIDAD_INICIAL,
        velocidadActual = constants.VELOCIDAD_INICIAL,
        anchoGrilla = 32,
        altoGrilla = 18,
        frutasContador = 0,
        lastObstacleScore = 0,
        magnetRange = 0,
        activeTimers = {},
        scoreMultiplier = 1,
        coinBonus = 0,
        timeScale = 1,
        activePS = {},
        menuPS = { update = function() end, emit = function() end, getCount = function() return 0 end },
        shockwaves = {},
        comboCount = 0,
        comboDisplay = 0,
        comboIntensity = 0,
        comboFlashTimer = 0,
        lastEatTime = 0,
        fadeDir = 0,
        fadeAlpha = 0,
        shakeTimer = 0,
        introTimer = 0,
        deathAnimTimer = 0,
        celebrationTimer = 0,
        deathModalOpen = false,
        roomDamaged = false,
        debugImmune = false,
        debugMenuOpen = false,
        debugAchievementsOpen = false,
        debugDungeonOverlay = false,
        debugLogoOpen = false,
        pendingAchievements = {},
        scheduledToasts = {},
        scheduledIndex = {},
        player = snakeMod.reset()
    })
    shop.reset()
    obstaclesMod.init()
    enemiesMod.init()
    worldMod.init()
end

helper.harness = harness
helper.constants = constants
helper.world = world
helper.items = items
helper.shop = shop
helper.persistence = persistence
helper.settings = settings
helper.settingsDraw = settingsDraw
helper.profilesMod = profilesMod
helper.profilesDraw = profilesDraw
helper.achievementsMod = achievementsMod
helper.playerMod = playerMod
helper.gameflow = gameflow
helper.gamestates = gamestates
helper.debugTools = debugTools
helper.debugLogo = debugLogo
helper.snakeMod = snakeMod
helper.foodMod = foodMod
helper.enemiesMod = enemiesMod
helper.obstaclesMod = obstaclesMod
helper.worldMod = worldMod
helper.uiMod = uiMod

return helper

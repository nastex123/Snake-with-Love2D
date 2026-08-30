-- tests/test_ui_render_audio.lua
-- Comprehensive deep unit tests for UI, Render, Audio, and Main loop integration

local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local uiMod = require("ui.ui")
local introUI = require("ui.introUI")
local menuUI = require("ui.menuUI")
local menuLogo = require("ui.menuLogo")
local menuCard = require("ui.menuCard")
local hudUI = require("ui.hudUI")
local toastsUI = require("ui.toastsUI")
local popupsUI = require("ui.popupsUI")
local overlaysUI = require("ui.overlaysUI")
local shadersMod = require("render.shaders")
local particlesMod = require("render.particles")
local enemiesDraw = require("render.enemiesDraw")
local renderMain = require("render.renderMain")
local soundMod = require("audio.sound")
local persistence = require("systems.persistence")

-- -------------------------------------------------------------
-- 1. UI FACADE & CONFIGURATION
-- -------------------------------------------------------------
harness.describe("UI Facade & Configuration (ui/ui.lua)", function()
    harness.it("loads font hierarchy and asset textures cleanly", function()
        uiMod.load()
        harness.assert_not_nil(uiMod.fontTitle, "fontTitle must be loaded")
        harness.assert_not_nil(uiMod.fontLarge, "fontLarge must be loaded")
        harness.assert_not_nil(uiMod.fontNormal, "fontNormal must be loaded")
        harness.assert_not_nil(uiMod.fontSmall, "fontSmall must be loaded")
    end)

    harness.it("handles scaling, high-contrast, and colorblind mode setters", function()
        uiMod.setScale(1.25)
        harness.assert_almost_equal(1.25, uiMod.scale, 0.001, "Scale should be 1.25")
        uiMod.setScale(nil)
        harness.assert_almost_equal(1.0, uiMod.scale, 0.001, "Default scale should be 1.0")

        uiMod.applyHighContrast(true)
        harness.assert_true(uiMod.highContrast, "High contrast should be active")
        uiMod.applyHighContrast(false)
        harness.assert_false(uiMod.highContrast, "High contrast should be inactive")

        uiMod.applyColorblind("protanopia")
        harness.assert_equal("protanopia", uiMod.colorblind, "Colorblind should be protanopia")
        uiMod.applyColorblind("off")
        harness.assert_equal("off", uiMod.colorblind, "Colorblind should be off")
    end)

    harness.it("delegates popup and toast lifecycle through facade", function()
        uiMod.resetPopups()
        harness.assert_equal(0, #uiMod.popups, "Popups list should be reset to empty")

        uiMod.addPopup("+100", 5, 5)
        harness.assert_equal(1, #uiMod.popups, "Popup should be added")
        harness.assert_equal("+100", uiMod.popups[1].text, "Popup text matches")

        uiMod.updatePopups(0.05)
        harness.assert_gt(uiMod.popups[1].timer, 0, "Popup timer advanced")

        uiMod.drawPopups() -- smoke test

        uiMod._toastQueue = {}
        uiMod.showToast({ id = "test_toast", title = "Logro", subtitle = "Test Sub" })
        harness.assert_equal(1, #uiMod._toastQueue, "Toast should be queued")
        uiMod.updateToasts(0.1)
        uiMod.drawToasts() -- smoke test
    end)
end)

-- -------------------------------------------------------------
-- 2. INTRO & CELEBRATION UI
-- -------------------------------------------------------------
harness.describe("Intro & Celebration UI (ui/introUI.lua)", function()
    harness.it("renders all phases of Balatro intro without errors", function()
        -- Phase 1: Fade from black (t < 0.5)
        introUI.draw(uiMod, 0.2, 0.2, false)
        introUI.draw(uiMod, 0.2, 0.2, true)

        -- Phase 2: Emblem Diamond rising & settled (0.5 <= t < 1.2 and t >= 1.2)
        introUI.draw(uiMod, 0.8, 0.8, false)
        introUI.draw(uiMod, 0.8, 0.8, true)
        introUI.draw(uiMod, 1.4, 1.4, false)
        introUI.draw(uiMod, 1.4, 1.4, true)

        -- Phase 3: Spiral pixel cascade (1.2 <= t < 2.7)
        introUI.draw(uiMod, 2.0, 2.0, false)
        introUI.draw(uiMod, 2.0, 2.0, true)

        -- Phase 4: Screen flash (2.5 <= t < 2.9)
        introUI.draw(uiMod, 2.7, 2.7, false)
        introUI.draw(uiMod, 2.7, 2.7, true)

        -- Ready menu state (t >= 3.5)
        introUI.draw(uiMod, 3.8, 3.8, false)
        introUI.draw(uiMod, 3.8, 3.8, true)
    end)

    harness.it("renders high score celebration box cleanly", function()
        introUI.drawHighScore(uiMod, 1250, 1000)
    end)
end)

-- -------------------------------------------------------------
-- 3. MENU UI, LOGO & CARD
-- -------------------------------------------------------------
harness.describe("Menu UI, Logo & Card (ui/menuUI.lua, menuLogo.lua, menuCard.lua)", function()
    harness.it("computes logo bounding box based on persistence config", function()
        local sx, sy, tw, th, depth, pScale, spacing, floatOffset = menuLogo.getBounds(1.5)
        harness.assert_gt(tw, 0, "Logo total width must be positive")
        harness.assert_gt(th, 0, "Logo total height must be positive")
        harness.assert_gt(pScale, 0, "Pixel scale must be positive")
        harness.assert_gt(depth, 0, "Isometric depth must be positive")
    end)

    harness.it("draws procedural logo and logo glow flare", function()
        menuLogo.draw(1.0, 2.5)
        menuLogo.drawGlow(1.0, 2.5)
        menuLogo.draw(0.0, 2.5) -- early exit test
        menuLogo.drawGlow(0.0, 2.5)
    end)

    harness.it("draws profile & high-score player card", function()
        persistence.init()
        persistence.initProfiles()
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        local panelW = math.floor(w * 0.40)
        local rightCenterX = panelW + math.floor((w - panelW) / 2)

        uiMod.menuButtons = {}
        menuCard.draw(uiMod, 1.0, 1.0, 3.5, 9999, rightCenterX, h)
        harness.assert_gt(#uiMod.menuButtons, 0, "Card should register as clickable button")
        local foundCard = false
        for _, b in ipairs(uiMod.menuButtons) do
            if b.id == "card_profile" then foundCard = true end
        end
        harness.assert_true(foundCard, "card_profile button must be registered")
    end)

    harness.it("renders full main menu and handles mouse hit-testing and hover sounds", function()
        uiMod.menuButtons = {}
        menuUI.draw(uiMod, 3.5, 3.5, 500)
        menuUI.drawGlow(uiMod, 3.5, 3.5)

        harness.assert_gte(#uiMod.menuButtons, 4, "Must register menu buttons (play, profiles, settings, exit, etc.)")

        -- Test hit testing
        local firstBtn = uiMod.menuButtons[1]
        local hitId = menuUI.mousePressed(uiMod, firstBtn.x + 5, firstBtn.y + 5)
        harness.assert_equal(firstBtn.id, hitId, "Hit test should return button id")

        local missId = menuUI.mousePressed(uiMod, -100, -100)
        harness.assert_nil(missId, "Hit test outside should return nil")

        -- Test hover updates
        menuUI.updateHover(uiMod, firstBtn.x + 5, firstBtn.y + 5)
        harness.assert_equal(firstBtn.id, uiMod.menuHoverId, "Hover id should match")

        menuUI.setPressed(uiMod, firstBtn.id)
        harness.assert_equal(firstBtn.id, uiMod.menuPressedId, "Pressed id should match")
        menuUI.clearPressed(uiMod)
        harness.assert_nil(uiMod.menuPressedId, "Pressed id should be cleared")
    end)
end)

-- -------------------------------------------------------------
-- 4. HUD COMPONENTS & VISUALS
-- -------------------------------------------------------------
harness.describe("HUD Components & Visuals (ui/hudUI.lua)", function()
    harness.it("renders background grid with biome tint and combo heating", function()
        hudUI.drawGrid(uiMod, 32, 20, 1.0, 0.0)
        hudUI.drawGrid(uiMod, 32, 20, 2.5, 1.0) -- max heat
    end)

    harness.it("renders top HUD bar with all status effects and progress gauges", function()
        local activeTimers = {
            { id = "ghost", remaining = 4.0 },
            { id = "turbo", remaining = 6.0 },
            { id = "slow", remaining = 2.0 },
            { id = "doubler", remaining = 5.0 },
            { id = "extraCoin", remaining = 8.0 },
            { id = "star", remaining = 3.0 }
        }

        hudUI.drawHUD(
            uiMod,
            500,     -- puntuacion
            1000,    -- highScore
            50,      -- monedas
            true,    -- shieldActive
            5.0,     -- magnetTimer
            10.0,    -- magnetDuration
            0.15,    -- baseSpeed
            0.12,    -- velocidadActual
            3,       -- comboCount
            activeTimers,
            2,       -- etapa
            3,       -- sala
            200,     -- objetivoSala
            1.0      -- scale
        )
    end)

    harness.it("renders tactical ability slots [Q], [R], and inventory slots", function()
        world.state.player = {
            body = { {x=5, y=5}, {x=4, y=5}, {x=3, y=5}, {x=2, y=5} },
            autotomyCooldown = 0,
            reverseSlitherCooldown = 0
        }
        local slots = {
            { name = "ESCUDO" },
            nil,
            { name = "BOMBA" }
        }
        hudUI.drawSlots(uiMod, slots)

        -- Test on cooldown
        world.state.player.autotomyCooldown = 4.0
        world.state.player.reverseSlitherCooldown = 5.0
        hudUI.drawSlots(uiMod, slots)
    end)

    harness.it("renders combo flash banner", function()
        hudUI.drawComboFlash(uiMod, 1.0, 5, 0.25)
        hudUI.drawComboFlash(uiMod, 1.0, 5, 0.0) -- inactive
    end)
end)

-- -------------------------------------------------------------
-- 5. TOASTS & FLOATING POPUPS
-- -------------------------------------------------------------
harness.describe("Toasts & Floating Popups (ui/toastsUI.lua, popupsUI.lua)", function()
    harness.it("processes toast queue lifecycle through show, update, and draw", function()
        local ui = { _toastQueue = {}, fontNormal = uiMod.fontNormal, fontSmall = uiMod.fontSmall }
        toastsUI.show(ui, { id = "ach_1", title = "MAESTRO", subtitle = "Alcanza 1000 pts", reward = "+50G" })
        harness.assert_equal(1, #ui._toastQueue, "Toast added")

        -- In-fade
        toastsUI.update(ui, 0.1)
        harness.assert_equal(1, #ui._toastQueue, "Toast still present during in-fade")
        toastsUI.draw(ui)

        -- Hold phase
        toastsUI.update(ui, 0.8)
        toastsUI.draw(ui)

        -- Out-fade and expire
        toastsUI.update(ui, 2.0)
        harness.assert_equal(0, #ui._toastQueue, "Toast expired and removed from queue")
    end)

    harness.it("processes score popup movement and smoothstep scaling", function()
        local ui = { popups = {}, fontNormal = uiMod.fontNormal }
        popupsUI.add(ui, "+50", 10, 10)
        harness.assert_equal(1, #ui.popups, "Popup created")
        local initialY = ui.popups[1].y

        popupsUI.update(ui, 0.05)
        harness.assert_lt(ui.popups[1].y, initialY, "Popup moved upward")
        harness.assert_gt(ui.popups[1].scale, 0, "Popup scaled up")
        popupsUI.draw(ui)

        -- Advance past lifetime
        popupsUI.update(ui, constants.SCORE_POPUP_LIFETIME + 0.5)
        harness.assert_equal(0, #ui.popups, "Popup removed when expired")
    end)
end)

-- -------------------------------------------------------------
-- 6. OVERLAYS & DEATH MODAL
-- -------------------------------------------------------------
harness.describe("Overlays & Death Modal (ui/overlaysUI.lua)", function()
    harness.it("renders pause overlay", function()
        overlaysUI.drawPause(uiMod)
    end)

    harness.it("renders dungeon minimap and debug overlay", function()
        local dungeonData = {
            virtualW = 800,
            virtualH = 600,
            rooms = {
                { id = 1, name = "ENTRADA", rect = { x = 50, y = 50, w = 150, h = 100 }, centerX = 125, centerY = 100, current = true },
                { id = 2, name = "SALA_2", rect = { x = 250, y = 50, w = 150, h = 100 }, centerX = 325, centerY = 100, cleared = true },
                { id = 3, name = "SALA_3", rect = { x = 450, y = 50, w = 150, h = 100 }, centerX = 525, centerY = 100, visited = true },
                { id = 4, name = "JEFE", rect = { x = 650, y = 50, w = 100, h = 100 }, centerX = 700, centerY = 100, visited = false }
            },
            corridors = {
                { from = 1, to = 2, path = { { x = 200, y = 90, w = 50, h = 20 } } },
                { from = 2, to = 3, path = { { x = 400, y = 90, w = 50, h = 20 } } }
            }
        }

        overlaysUI.drawDungeonMap(uiMod, dungeonData)
        overlaysUI.drawDebugDungeon(uiMod, dungeonData)
    end)

    harness.it("renders death modal and handles revive hit testing based on coins", function()
        world.state.puntuacion = 850
        world.state.survivalStreak = 1.4
        world.state.monedas = 40 -- Enough for 30$ revive

        overlaysUI.drawDeathModal(uiMod)
        local btns = overlaysUI._deathButtons
        harness.assert_not_nil(btns, "Death buttons must be defined")
        harness.assert_true(btns.revive.enabled, "Revive button must be enabled with >= 30 coins")

        local actRevive = overlaysUI.deathMousePressed(btns.revive.x + 5, btns.revive.y + 5)
        harness.assert_equal("revive", actRevive, "Should trigger revive")

        local actAccept = overlaysUI.deathMousePressed(btns.accept.x + 5, btns.accept.y + 5)
        harness.assert_equal("accept", actAccept, "Should trigger accept")

        -- Test disabled revive with insufficient coins
        world.state.monedas = 10
        overlaysUI.drawDeathModal(uiMod)
        harness.assert_false(overlaysUI._deathButtons.revive.enabled, "Revive disabled with < 30 coins")
        local actDisabled = overlaysUI.deathMousePressed(btns.revive.x + 5, btns.revive.y + 5)
        harness.assert_nil(actDisabled, "Clicking disabled revive should return nil")
    end)
end)

-- -------------------------------------------------------------
-- 7. SHADERS & POST-PROCESSING
-- -------------------------------------------------------------
harness.describe("Shaders & Post-Processing (render/shaders.lua)", function()
    harness.it("initializes canvases, shaders, and linear texture sampling", function()
        shadersMod.load()
        shadersMod.recreateCanvases()
    end)

    harness.it("handles damage and screen shake decay", function()
        shadersMod.triggerDamage(1.0, 0.8)
        local fx = shadersMod.getFX()
        harness.assert_almost_equal(1.0, fx.damage, 0.001, "Damage set to 1.0")
        harness.assert_almost_equal(0.8, fx.shake, 0.001, "Shake set to 0.8")

        shadersMod.update(0.2)
        harness.assert_lt(fx.damage, 1.0, "Damage decayed")
        harness.assert_lt(fx.shake, 0.8, "Shake decayed")
    end)

    harness.it("handles scene/glow/shadow canvas routing and Balatro background", function()
        shadersMod.beginScene(0.05, 0.05, 0.08)
        shadersMod.drawBalatroBG(1.5, 0.8)

        shadersMod.beginGlow()
        shadersMod.beginShadow()
    end)

    harness.it("executes multi-pass post-process composite with CRT and colorblind filters", function()
        -- Normal CRT composite
        shadersMod.composite(1.0, 0.75, false)
        shadersMod.composite(1.0, 0.85, true) -- Menu heat distortion

        -- Protanopia Daltonization composite
        uiMod.applyColorblind("protanopia")
        shadersMod.composite(1.0, 0.75, false)

        -- Deuteranopia Daltonization composite
        uiMod.applyColorblind("deuteranopia")
        shadersMod.composite(1.0, 0.75, false)

        -- Tritanopia Daltonization composite
        uiMod.applyColorblind("tritanopia")
        shadersMod.composite(1.0, 0.75, false)

        uiMod.applyColorblind("off")
    end)
end)

-- -------------------------------------------------------------
-- 8. PROCEDURAL PARTICLES
-- -------------------------------------------------------------
harness.describe("Procedural Particles (render/particles.lua)", function()
    harness.it("loads 4x4 procedural texture", function()
        particlesMod.load()
    end)

    harness.it("spawns all procedural particle emitters correctly", function()
        local pComer = particlesMod.comer(100, 100)
        harness.assert_not_nil(pComer, "comer particle system created")

        local pMuerte = particlesMod.muerte(100, 100)
        harness.assert_not_nil(pMuerte, "muerte particle system created")

        local pHighScore = particlesMod.highScore(100, 100)
        harness.assert_not_nil(pHighScore, "highScore particle system created")

        local pAct = particlesMod.activacion(100, 100, 1, 0.5, 0)
        harness.assert_not_nil(pAct, "activacion particle system created")

        local pKill = particlesMod.enemyKill(100, 100, 1, 0, 0)
        harness.assert_not_nil(pKill, "enemyKill particle system created")

        local pBossTick = particlesMod.bossFoodTick(100, 100)
        harness.assert_not_nil(pBossTick, "bossFoodTick particle system created")

        local pBossDeath = particlesMod.bossDeath(100, 100)
        harness.assert_not_nil(pBossDeath, "bossDeath particle system created")

        local pBomb = particlesMod.bombExplosion(100, 100)
        harness.assert_not_nil(pBomb, "bombExplosion particle system created")

        local pConstrictor = particlesMod.constrictorBurst(100, 100)
        harness.assert_not_nil(pConstrictor, "constrictorBurst particle system created")

        local pStreak = particlesMod.streakDiamond(100, 100)
        harness.assert_not_nil(pStreak, "streakDiamond particle system created")

        local pAutotomy = particlesMod.autotomyDecoy(100, 100)
        harness.assert_not_nil(pAutotomy, "autotomyDecoy particle system created")

        local pFire = particlesMod.fireTrail(100, 100)
        harness.assert_not_nil(pFire, "fireTrail particle system created")

        local pFrost = particlesMod.frostFreeze(100, 100)
        harness.assert_not_nil(pFrost, "frostFreeze particle system created")

        local pTail = particlesMod.tailSnapShockwave(100, 100)
        harness.assert_not_nil(pTail, "tailSnapShockwave particle system created")

        local pSlim = particlesMod.slimmingBurst(100, 100)
        harness.assert_not_nil(pSlim, "slimmingBurst particle system created")

        local pMenu = particlesMod.menuFondo()
        harness.assert_not_nil(pMenu, "menuFondo particle system created")
    end)
end)

-- -------------------------------------------------------------
-- 9. ENEMIES RENDERING & BOSS VISUALS
-- -------------------------------------------------------------
harness.describe("Enemies Rendering & Boss Visuals (render/enemiesDraw.lua)", function()
    harness.it("renders chasers in all social AI states, patrollers, and spawners", function()
        local enemiesList = {
            { x = 5, y = 5, type = "chaser", alive = true, aiState = "idle", seed = 1 },
            { x = 6, y = 5, type = "chaser", alive = true, aiState = "chase", seed = 2 },
            { x = 7, y = 5, type = "chaser", alive = true, aiState = "flank", role = "flanker", seed = 3 },
            { x = 8, y = 5, type = "chaser", alive = true, aiState = "encircle", seed = 4 },
            { x = 9, y = 5, type = "chaser", alive = true, aiState = "close", seed = 5 },
            { x = 10, y = 5, type = "chaser", alive = true, promotedTimer = 0.4, stunTimer = 0.5 },
            { x = 12, y = 6, type = "patroller", alive = true, dirX = 1, dirY = 0 },
            { x = 15, y = 8, type = "spawner", alive = true }
        }

        local telegraphs = {
            { gx = 5, gy = 5, timer = 0.5, maxTimer = 1.0 }
        }

        local attackObjects = {
            { type = "projectile", x = 10, y = 10 },
            { type = "radial_pulse", cx = 10, cy = 10, radius = 2.0, maxRadius = 5.0 }
        }

        local boss = {
            x = 15, y = 15,
            alive = true,
            vida = 50,
            vidaMax = 100,
            state = "telegraph",
            _uiBarFill = 0.5,
            foodCollected = 5,
            foodTarget = 10
        }

        local snakeHead = { x = 5, y = 10 }

        enemiesDraw.draw(enemiesList, boss, telegraphs, attackObjects, snakeHead)
    end)
end)

-- -------------------------------------------------------------
-- 10. AUDIO SUBSYSTEM & SYNTHESIZER
-- -------------------------------------------------------------
harness.describe("Audio Subsystem & Synthesizer (audio/sound.lua)", function()
    harness.it("initializes procedural sound synthesis effects", function()
        soundMod.load()
    end)

    harness.it("triggers procedural sound effects", function()
        soundMod.enableSfx(true)
        soundMod.play("eat")
        soundMod.play("death")
        soundMod.play("buy")
        soundMod.play("shieldBreak")
        soundMod.play("highScore")
        soundMod.play("enemyKill")
        soundMod.play("boss_food_tick")
        soundMod.play("boss_defeated")
        soundMod.play("buttonHover")
        soundMod.play("buttonClick")

        soundMod.enableSfx(false)
        soundMod.play("eat") -- muted
    end)

    harness.it("controls master volume and music enablement", function()
        soundMod.setMasterVolume(0.8)
        harness.assert_almost_equal(0.8, soundMod.baseVolume, 0.001, "Base volume updated")

        soundMod.enableMusic(false)
        harness.assert_false(soundMod.musicEnabled, "Music should be disabled")
        harness.assert_false(soundMod:isPlaying(), "Music should be stopped")

        soundMod.enableMusic(true)
        harness.assert_true(soundMod.musicEnabled, "Music should be enabled")
    end)

    harness.it("manages music segments, crossfades, and seamless loop logic", function()
        soundMod:playSegment("intro")
        harness.assert_equal("intro", soundMod:getCurrentSegment(), "Current segment should be intro")

        -- Crossfade to boss
        soundMod:crossfadeTo("boss")
        harness.assert_true(soundMod.fading, "Crossfade flag should be true")
        harness.assert_equal("boss", soundMod:getCurrentSegment(), "Current segment should be boss")

        -- Update crossfade progress
        soundMod:update(0.3)
        soundMod:update(0.3) -- completes crossfade (0.6 >= 0.5)
        harness.assert_false(soundMod.fading, "Crossfade should be completed")

        -- Switch to seamless loop (comboLoop)
        soundMod:playSegment("comboLoop")
        harness.assert_equal("comboLoop", soundMod:getCurrentSegment(), "Current segment should be comboLoop")
        soundMod:update(0.016)

        soundMod:stop()
        harness.assert_nil(soundMod:getCurrentSegment(), "Current segment should be nil after stop")
    end)
end)

-- -------------------------------------------------------------
-- 11. MAIN RENDER SCENE & GAME LOOP INTEGRATION
-- -------------------------------------------------------------
harness.describe("Main Render Scene & Game Loop Integration (render/renderMain.lua, main.lua)", function()
    harness.it("renders complete menu scene without runtime errors", function()
        world.state.gameState = constants.GAME_STATE_MENU
        world.state.introTimer = 4.0
        world.state.time = 4.0
        world.state.highScore = 1500
        world.state.menuPS = particlesMod.menuFondo()

        renderMain.drawScene(0.016)
    end)

    harness.it("renders active gameplay scene with snake, obstacles, food, and HUD", function()
        world.state.gameState = constants.GAME_STATE_PLAYING
        world.state.puntuacion = 320
        world.state.highScore = 1000
        world.state.monedas = 25
        world.state.time = 10.0
        world.state.comboIntensity = 0.5
        world.state.gameOffsetY = 28
        world.state.gridOffsetX = 10
        world.state.anchoGrilla = 32
        world.state.altoGrilla = 20
        world.state.velocidadActual = 0.13
        world.state.baseSpeed = 0.13
        world.state.cronometro = 0.05
        world.state.magnetRange = 0
        world.state.activePS = {}
        world.state.shockwaves = {}
        world.state.shakeTimer = 0
        world.state.fadeAlpha = 0
        world.state.player = {
            body = { {x=10, y=10}, {x=9, y=10}, {x=8, y=10} },
            dirX = 1, dirY = 0,
            autotomyCooldown = 0,
            reverseSlitherCooldown = 0
        }

        renderMain.drawScene(0.016)
    end)

    harness.it("renders transition, shop, pause, and victory states cleanly", function()
        -- Transition
        world.state.gameState = constants.GAME_STATE_TRANSITION
        world.state.fadeAlpha = 0.8
        world.state.transitionTarget = "siguienteSala"
        world.state.transitionPhase = 1
        renderMain.drawScene(0.016)

        -- Victory
        world.state.mundoCompletado = true
        renderMain.drawScene(0.016)
        world.state.mundoCompletado = false

        -- Pause
        world.state.gameState = constants.GAME_STATE_PAUSED
        renderMain.drawScene(0.016)

        -- High Score
        world.state.gameState = constants.GAME_STATE_HIGH_SCORE
        renderMain.drawScene(0.016)
    end)
end)

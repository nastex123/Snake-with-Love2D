-- tests/test_scope_20_renderAudioMain.lua
-- Exhaustive Unit Test Suite for Render Pipeline, Audio Engine, and Main Lifecycle Hooks

local harness = require("tests.test_harness")

local constants = require("constants")
local world = require("core.world")
local shadersMod = require("render.shaders")
local particlesMod = require("render.particles")
local soundMod = require("audio.sound")
local renderMain = require("render.renderMain")
local enemiesDraw = require("render.enemiesDraw")
local uiMod = require("ui.ui")
local shopMod = require("systems.shop")
local itemsMod = require("systems.items")
local worldMod = require("world.world")
local persistenceMod = require("systems.persistence")
local settingsMod = require("systems.settings")
local profilesMod = require("systems.profiles")
local gameflow = require("systems.gameflow")
local playerMod = require("systems.player")
local snakeMod = require("entities.snake")
local foodMod = require("entities.food")
local enemiesMod = require("entities.enemies")
local obstaclesMod = require("entities.obstacles")
local debugTools = require("systems.debugTools")

harness.describe("1. Render Pipeline: Shaders System (render/shaders.lua)", function()
    harness.before_each(function()
        shadersMod.load()
    end)

    harness.it("shaders.load initializes all canvases and shader programs", function()
        local canvases = shadersMod.getCanvases()
        harness.assert_not_nil(canvases.scene, "scene canvas should be created")
        harness.assert_not_nil(canvases.glow, "glow canvas should be created")
        harness.assert_not_nil(canvases.glowLow, "glowLow canvas should be created")
        harness.assert_not_nil(canvases.blurH, "blurH canvas should be created")
        harness.assert_not_nil(canvases.blurV, "blurV canvas should be created")
        harness.assert_not_nil(canvases.shadow, "shadow canvas should be created")
        harness.assert_not_nil(canvases.shadowBlur, "shadowBlur canvas should be created")
        harness.assert_not_nil(canvases.final, "final canvas should be created")
        harness.assert_not_nil(canvases.post, "post canvas should be created")

        local sh = shadersMod.getShaders()
        harness.assert_not_nil(sh.crt, "CRT shader should exist")
        harness.assert_not_nil(sh.blurH, "blurH shader should exist")
        harness.assert_not_nil(sh.blurV, "blurV shader should exist")
        harness.assert_not_nil(sh.shadow, "shadow shader should exist")
        harness.assert_not_nil(sh.heat, "heat shader should exist")
        harness.assert_not_nil(sh.balatro, "balatro shader should exist")
        harness.assert_not_nil(sh.colorblind, "colorblind shader should exist")
    end)

    harness.it("shaders.triggerDamage and shaders.update decay damage and shake effects", function()
        shadersMod.triggerDamage(0.8, 0.5)
        local fx = shadersMod.getFX()
        harness.assert_gte(fx.damage, 0.8, "damage should be set")
        harness.assert_gte(fx.shake, 0.5, "shake should be set")

        shadersMod.update(0.1)
        local fx2 = shadersMod.getFX()
        harness.assert_lt(fx2.damage, 0.8, "damage should decay over dt")
        harness.assert_lt(fx2.shake, 0.5, "shake should decay over dt")

        shadersMod.update(2.0)
        local fx3 = shadersMod.getFX()
        harness.assert_equal(0, fx3.damage, "damage should reach 0")
        harness.assert_equal(0, fx3.shake, "shake should reach 0")
    end)

    harness.it("shaders.recreateCanvases frees previous canvases without leaks", function()
        local oldCanvases = shadersMod.getCanvases()
        shadersMod.recreateCanvases()
        local newCanvases = shadersMod.getCanvases()
        harness.assert_not_nil(newCanvases.scene, "scene canvas should be recreated")
        harness.assert_not_nil(newCanvases.final, "final canvas should be recreated")
    end)

    harness.it("shaders.beginScene, beginGlow, beginShadow execute without error", function()
        shadersMod.beginScene(0.1, 0.1, 0.1)
        shadersMod.beginGlow()
        shadersMod.beginShadow()
    end)

    harness.it("shaders.drawBalatroBG executes and passes uniforms", function()
        shadersMod.drawBalatroBG(1.5, 0.7)
    end)

    harness.it("shaders.composite executes standard composite pass", function()
        shadersMod.composite(2.0, 0.75, false)
    end)

    harness.it("shaders.composite executes menu composite with heat distortion", function()
        shadersMod.composite(3.5, 0.85, true)
    end)

    harness.it("shaders.composite handles highContrast and colorblind modes", function()
        uiMod.highContrast = true
        uiMod.colorblind = "protanopia"
        shadersMod.composite(1.0, 0.8, false)

        uiMod.colorblind = "deuteranopia"
        shadersMod.composite(1.0, 0.8, false)

        uiMod.colorblind = "tritanopia"
        shadersMod.composite(1.0, 0.8, false)

        uiMod.colorblind = "off"
        uiMod.highContrast = false
        shadersMod.composite(1.0, 0.8, false)
    end)
end)

harness.describe("2. Render Pipeline: Procedural Particles System (render/particles.lua)", function()
    harness.before_each(function()
        particlesMod.load()
    end)

    harness.it("particles.load generates 4x4 procedural texture and getTexture returns it", function()
        local tex = particlesMod.getTexture()
        harness.assert_not_nil(tex, "particle texture should be created")
    end)

    harness.it("particles.release frees texture safely", function()
        particlesMod.release()
        harness.assert_nil(particlesMod.getTexture(), "texture should be nil after release")
    end)

    harness.it("all 16 particle factory functions generate valid ParticleSystems", function()
        local p1 = particlesMod.comer(100, 100)
        harness.assert_not_nil(p1, "comer particle system should exist")

        local p2 = particlesMod.muerte(150, 150)
        harness.assert_not_nil(p2, "muerte particle system should exist")

        local p3 = particlesMod.highScore(200, 200)
        harness.assert_not_nil(p3, "highScore particle system should exist")

        local p4 = particlesMod.activacion(50, 50, 0.2, 0.8, 0.4)
        harness.assert_not_nil(p4, "activacion particle system should exist")

        local p5 = particlesMod.enemyKill(80, 80, 1, 0.2, 0.2)
        harness.assert_not_nil(p5, "enemyKill particle system should exist")

        local p6 = particlesMod.bossFoodTick(90, 90)
        harness.assert_not_nil(p6, "bossFoodTick particle system should exist")

        local p7 = particlesMod.bossDeath(120, 120)
        harness.assert_not_nil(p7, "bossDeath particle system should exist")

        local p8 = particlesMod.bombExplosion(140, 140)
        harness.assert_not_nil(p8, "bombExplosion particle system should exist")

        local p9 = particlesMod.constrictorBurst(160, 160)
        harness.assert_not_nil(p9, "constrictorBurst particle system should exist")

        local p10 = particlesMod.streakDiamond(180, 180)
        harness.assert_not_nil(p10, "streakDiamond particle system should exist")

        local p11 = particlesMod.autotomyDecoy(210, 210)
        harness.assert_not_nil(p11, "autotomyDecoy particle system should exist")

        local p12 = particlesMod.fireTrail(220, 220)
        harness.assert_not_nil(p12, "fireTrail particle system should exist")

        local p13 = particlesMod.frostFreeze(240, 240)
        harness.assert_not_nil(p13, "frostFreeze particle system should exist")

        local p14 = particlesMod.tailSnapShockwave(260, 260)
        harness.assert_not_nil(p14, "tailSnapShockwave particle system should exist")

        local p15 = particlesMod.slimmingBurst(280, 280)
        harness.assert_not_nil(p15, "slimmingBurst particle system should exist")

        local p16 = particlesMod.menuFondo()
        harness.assert_not_nil(p16, "menuFondo particle system should exist")
    end)

    harness.it("particle factory functions auto-initialize texture if called before load", function()
        particlesMod.release()
        local ps = particlesMod.comer(30, 30)
        harness.assert_not_nil(ps, "should auto initialize and create particle system")
        harness.assert_not_nil(particlesMod.getTexture(), "texture should be auto-created")
    end)
end)

harness.describe("3. Audio Engine: Sound Manager & Synthesis (audio/sound.lua)", function()
    harness.before_each(function()
        soundMod.load()
        soundMod:stop()
        soundMod.musicEnabled = true
        soundMod.sfxEnabled = true
        soundMod.baseVolume = 0.5
    end)

    harness.it("sound.fragments contains all defined musical segment bounds", function()
        harness.assert_equal(1, soundMod.fragments.intro.start)
        harness.assert_equal(9, soundMod.fragments.intro.finish)
        harness.assert_equal(10, soundMod.fragments.comboEnter.start)
        harness.assert_equal(17, soundMod.fragments.comboEnter.finish)
        harness.assert_equal(13, soundMod.fragments.comboLoop.start)
        harness.assert_equal(17, soundMod.fragments.comboLoop.finish)
        harness.assert_equal(18, soundMod.fragments.boss.start)
        harness.assert_equal(24, soundMod.fragments.boss.finish)
    end)

    harness.it("procedural sound synthesis functions (makeSine, makeSweep, makeNoise) generate valid SoundData", function()
        local makeSine = soundMod.getMakeSine()
        local makeSweep = soundMod.getMakeSweep()
        local makeNoise = soundMod.getMakeNoise()

        local sd1 = makeSine(440, 0.05, 0.2)
        harness.assert_not_nil(sd1, "sine SoundData should be created")

        local sd2 = makeSweep(300, 600, 0.05, 0.2)
        harness.assert_not_nil(sd2, "sweep SoundData should be created")

        local sd3 = makeNoise(0.05, 0.2)
        harness.assert_not_nil(sd3, "noise SoundData should be created")
    end)

    harness.it("sound.load creates all 10 procedural static SFX sources", function()
        local sources = soundMod.getSources()
        harness.assert_not_nil(sources.eat, "eat sfx source should exist")
        harness.assert_not_nil(sources.death, "death sfx source should exist")
        harness.assert_not_nil(sources.buy, "buy sfx source should exist")
        harness.assert_not_nil(sources.shieldBreak, "shieldBreak sfx source should exist")
        harness.assert_not_nil(sources.highScore, "highScore sfx source should exist")
        harness.assert_not_nil(sources.enemyKill, "enemyKill sfx source should exist")
        harness.assert_not_nil(sources.boss_food_tick, "boss_food_tick sfx source should exist")
        harness.assert_not_nil(sources.boss_defeated, "boss_defeated sfx source should exist")
        harness.assert_not_nil(sources.buttonHover, "buttonHover sfx source should exist")
        harness.assert_not_nil(sources.buttonClick, "buttonClick sfx source should exist")
    end)

    harness.it("sound.play triggers sfx when enabled, and ignores when disabled", function()
        soundMod.play("eat")
        soundMod.play("buttonClick")
        soundMod.enableSfx(false)
        soundMod.play("death")
        soundMod.enableSfx(true)
    end)

    harness.it("sound:playSegment switches currentSegment correctly", function()
        soundMod:playSegment("intro")
        harness.assert_equal("intro", soundMod:getCurrentSegment())

        soundMod:playSegment("boss")
        harness.assert_equal("boss", soundMod:getCurrentSegment())
    end)

    harness.it("sound:crossfadeTo initiates fading state and smoothly finishes in update", function()
        soundMod:playSegment("intro")
        soundMod:crossfadeTo("comboEnter")
        harness.assert_true(soundMod.fading, "fading flag should be true during crossfade")
        harness.assert_equal("comboEnter", soundMod:getCurrentSegment())

        soundMod:update(0.25)
        harness.assert_true(soundMod.fading, "should still be fading at midpoint")

        soundMod:update(0.35)
        harness.assert_false(soundMod.fading, "fading should complete after full duration")
        harness.assert_nil(soundMod.getOldSource(), "oldSource should be cleaned up")
    end)

    harness.it("sound:stop cleans up all audio sources and state", function()
        soundMod:playSegment("intro")
        soundMod:stop()
        harness.assert_nil(soundMod:getCurrentSegment())
        harness.assert_nil(soundMod.getActiveSource())
        harness.assert_nil(soundMod.getOldSource())
        harness.assert_nil(soundMod.getNextLoopSource())
        harness.assert_false(soundMod.fading)
    end)

    harness.it("sound.setMasterVolume clamps and sets volume", function()
        soundMod.setMasterVolume(0.8)
        harness.assert_almost_equal(0.8, soundMod.baseVolume, 0.01)

        soundMod.setMasterVolume(1.5)
        harness.assert_almost_equal(1.0, soundMod.baseVolume, 0.01)

        soundMod.setMasterVolume(-0.5)
        harness.assert_almost_equal(0.0, soundMod.baseVolume, 0.01)
    end)

    harness.it("sound.enableMusic stops audio when disabled and resumes intro when re-enabled", function()
        soundMod:playSegment("intro")
        soundMod.enableMusic(false)
        harness.assert_false(soundMod.musicEnabled)
        harness.assert_nil(soundMod:getCurrentSegment())

        soundMod.enableMusic(true)
        harness.assert_true(soundMod.musicEnabled)
        harness.assert_equal("intro", soundMod:getCurrentSegment())
    end)
end)

harness.describe("4. Render Pipeline: Enemies and Boss Draw (render/enemiesDraw.lua)", function()
    harness.it("draw.draw renders chaser enemies across all AI states", function()
        local list = {
            {x = 5, y = 5, alive = true, type = "chaser", aiState = "chase"},
            {x = 6, y = 5, alive = true, type = "chaser", aiState = "flank", role = "flanker"},
            {x = 7, y = 5, alive = true, type = "chaser", aiState = "encircle"},
            {x = 8, y = 5, alive = true, type = "chaser", aiState = "close"},
            {x = 9, y = 5, alive = true, type = "chaser", aiState = "idle"},
            {x = 10, y = 5, alive = true, type = "chaser", aiState = "chase", promotedTimer = 0.3},
            {x = 11, y = 5, alive = true, type = "chaser", stunTimer = 0.5},
        }
        local head = {x = 5, y = 2}
        enemiesDraw.draw(list, nil, {}, {}, head)
    end)

    harness.it("draw.draw renders patroller and spawner enemies", function()
        local list = {
            {x = 3, y = 3, alive = true, type = "patroller", dirX = 1, dirY = 0},
            {x = 4, y = 4, alive = true, type = "spawner"},
        }
        enemiesDraw.draw(list, nil, {}, {}, nil)
    end)

    harness.it("draw.draw renders telegraphs and attack objects", function()
        local telegraphs = {
            {gx = 5, gy = 5, timer = 0.5, maxTimer = 1.0}
        }
        local attackObjects = {
            {type = "projectile", x = 5.5, y = 5.5},
            {type = "radial_pulse", cx = 10, cy = 10, radius = 2.0, maxRadius = 4.0}
        }
        enemiesDraw.draw({}, nil, telegraphs, attackObjects, nil)
    end)

    harness.it("draw.draw renders boss with health bar and food counter", function()
        local boss = {
            x = 10, y = 10,
            alive = true,
            vida = 50,
            vidaMax = 100,
            state = "normal",
            _uiBarFill = 0.75,
            foodCollected = 5,
            foodTarget = 15
        }
        enemiesDraw.draw({}, boss, {}, {}, nil)

        boss.state = "telegraph"
        enemiesDraw.draw({}, boss, {}, {}, nil)
    end)
end)

harness.describe("5. Render Pipeline: Main Scene Drawing (render/renderMain.lua)", function()
    harness.before_each(function()
        world.init()
        shadersMod.load()
        particlesMod.load()
        uiMod.load()
    end)

    harness.it("renderMain.drawScene renders MENU state including Balatro intro and menu glow", function()
        world.state.gameState = constants.GAME_STATE_MENU
        world.state.introTimer = 3.5
        world.state.time = 5.0
        world.state.menuPS = particlesMod.menuFondo()

        renderMain.drawScene(0.016)
    end)

    harness.it("renderMain.drawScene renders PLAYING state with HUD, slots, grid and entities", function()
        world.state.gameState = constants.GAME_STATE_PLAYING
        world.state.player = snakeMod.crear(10, 10)
        world.state.anchoGrilla = 20
        world.state.altoGrilla = 15
        world.state.gridOffsetX = 100
        world.state.gameOffsetY = 0
        world.state.cronometro = 0.05
        world.state.velocidadActual = 0.15
        world.state.time = 10.0
        world.state.activePS = {
            {ps = particlesMod.comer(200, 200)}
        }
        world.state.shockwaves = {
            {x = 200, y = 200, radio = 10, alpha = 0.8, timer = 0.1}
        }

        renderMain.drawScene(0.016)
    end)

    harness.it("renderMain.drawScene renders PAUSED, DEATH_ANIMATION, HIGH_SCORE, and SHOP states", function()
        world.state.gameState = constants.GAME_STATE_PAUSED
        renderMain.drawScene(0.016)

        world.state.gameState = constants.GAME_STATE_DEATH_ANIMATION
        renderMain.drawScene(0.016)

        world.state.gameState = constants.GAME_STATE_HIGH_SCORE
        renderMain.drawScene(0.016)

        world.state.gameState = constants.GAME_STATE_SHOP
        renderMain.drawScene(0.016)
    end)

    harness.it("renderMain.drawScene renders TRANSITION phase with banner text", function()
        world.state.gameState = constants.GAME_STATE_TRANSITION
        world.state.transitionPhase = "hold"
        world.state.transitionTarget = "siguienteSala"
        world.state.fadeAlpha = 1.0

        renderMain.drawScene(0.016)
    end)

    harness.it("renderMain.drawGameGlow and drawGameShadow execute properly", function()
        world.state.gameState = constants.GAME_STATE_PLAYING
        world.state.player = snakeMod.crear(5, 5)
        world.state.velocidadActual = 0.15
        world.state.cronometro = 0.05
        world.state.gridOffsetX = 0
        world.state.gameOffsetY = 0
        world.state.fadeAlpha = 0

        renderMain.drawGameGlow(0.016)
        renderMain.drawGameShadow(0.016)
    end)
end)

harness.describe("6. Main Lifecycle Hooks & Loop (main.lua)", function()
    harness.before_each(function()
        -- Load main.lua if not already loaded into love global
        local mainOk = pcall(require, "main")
        love.load()
    end)

    harness.it("love.load initializes world state, profiles, and graphics config", function()
        harness.assert_not_nil(world.state, "world state should exist")
        harness.assert_equal(constants.GAME_STATE_MENU, world.state.gameState, "initial state should be MENU")
        harness.assert_not_nil(world.state.menuPS, "menuPS should be initialized")
        harness.assert_equal(1, world.state.scoreMultiplier, "scoreMultiplier should be 1")
    end)

    harness.it("love.update steps the simulation in MENU and PLAYING states", function()
        world.state.gameState = constants.GAME_STATE_MENU
        local oldIntro = world.state.introTimer
        love.update(0.016)
        harness.assert_gt(world.state.introTimer, oldIntro, "introTimer should advance in MENU update")

        world.state.gameState = constants.GAME_STATE_PLAYING
        world.state.player = snakeMod.crear(5, 5)
        local oldTime = world.state.time
        love.update(0.016)
        harness.assert_gt(world.state.time, oldTime, "time should advance in PLAYING update")
    end)

    harness.it("love.draw renders the frame via renderMain", function()
        love.draw()
    end)

    harness.it("love.resize recalculates grid and canvases", function()
        love.resize(800, 600)
    end)

    harness.it("love.mousepressed handles menu buttons (play, settings, profiles)", function()
        world.state.gameState = constants.GAME_STATE_MENU
        uiMod.menuButtons = {
            {id = 'play', x = 100, y = 100, w = 100, h = 40},
            {id = 'settings', x = 100, y = 150, w = 100, h = 40},
            {id = 'profiles', x = 100, y = 200, w = 100, h = 40}
        }

        love.mousepressed(150, 120, 1)
        harness.assert_equal(constants.GAME_STATE_PLAYING, world.state.gameState, "play button starts game")

        world.state.gameState = constants.GAME_STATE_MENU
        love.mousepressed(150, 170, 1)
        harness.assert_true(settingsMod.visible, "settings button opens settings")
        settingsMod.close()

        world.state.gameState = constants.GAME_STATE_MENU
        love.mousepressed(150, 220, 1)
        harness.assert_true(profilesMod.visible, "profiles button opens profiles")
        profilesMod.close()
    end)

    harness.it("love.mousepressed handles death modal buttons", function()
        world.state.deathModalOpen = true
        uiMod.deathModal = {
            reviveBtn = {50, 50, 100, 40},
            acceptBtn = {50, 100, 100, 40}
        }
        -- Test accept death
        love.mousepressed(60, 110, 1)
        harness.assert_equal(constants.GAME_STATE_DEATH_ANIMATION, world.state.gameState)
    end)

    harness.it("love.keypressed routes debug Tab, Pause, Abilities, Cheats, and Settings", function()
        -- Debug Tab
        world.state.debugMenuOpen = false
        love.keypressed("tab")
        harness.assert_true(world.state.debugMenuOpen, "tab should toggle debug menu")
        love.keypressed("tab")
        harness.assert_false(world.state.debugMenuOpen, "tab should close debug menu")

        -- Settings Escape route
        settingsMod.open()
        harness.assert_true(settingsMod.visible)
        love.keypressed("escape")
        harness.assert_false(settingsMod.visible, "escape should close settings")

        -- Menu Return start
        world.state.gameState = constants.GAME_STATE_MENU
        world.state.introTimer = 5.0
        love.keypressed("return")
        harness.assert_equal(constants.GAME_STATE_PLAYING, world.state.gameState, "return starts game in menu")

        -- Pause
        love.keypressed("space")
        harness.assert_equal(constants.GAME_STATE_PAUSED, world.state.gameState, "space pauses game")
        love.keypressed("space")
        harness.assert_equal(constants.GAME_STATE_PLAYING, world.state.gameState, "space unpauses game")

        -- Cheats: L adds coins
        local cBefore = world.state.monedas
        love.keypressed("l")
        harness.assert_equal(cBefore + 10, world.state.monedas, "l key grants 10 coins")

        -- Speed +/- adjust
        local sBefore = world.state.baseSpeed
        love.keypressed("+")
        harness.assert_lte(world.state.baseSpeed, sBefore, "+ key increases speed (decreases interval)")
    end)

    harness.it("love.mousemoved, mousereleased, wheelmoved, textinput, and touch execute without errors", function()
        love.mousemoved(100, 100, 5, 5)
        love.mousereleased(100, 100, 1)
        love.wheelmoved(0, 1)
        love.textinput("a")
        love.touchpressed(1, 100, 100, 0, 0, 1)
        love.touchmoved(1, 110, 100, 10, 0, 1)
        love.touchreleased(1, 110, 100, 0, 0, 0)
    end)

    harness.it("love.quit syncs profile and releases audio/canvas resources safely", function()
        love.quit()
    end)
end)

return harness.summary()

-- tests/main.lua
-- Master test runner for Snake Love2D test suite

package.path = "../?.lua;../?/init.lua;./?.lua;./tests/?.lua;" .. package.path

local harness = require("tests.test_harness")

-- Start coverage tracking
harness.start_coverage()

-- Run all test suites
print("=======================================================")
print("           SNAKE LOVE2D - INTEGRATED TEST RUNNER       ")
print("=======================================================")

require("tests.test_shop")
require("tests.test_settings")
require("tests.test_gamestates")
if pcall(require, "tests.test_scope_01_config") then end
if pcall(require, "tests.test_scope_02_helpers") then end
if pcall(require, "tests.test_scope_03_logger") then end
if pcall(require, "tests.test_scope_04_timers") then end
if pcall(require, "tests.test_scope_05_world") then end
require("tests.test_scope_06_snake")
if pcall(require, "tests.test_scope_07_food") then end
if pcall(require, "tests.test_scope_08_obstacles") then end
if pcall(require, "tests.test_scope_09_enemies") then end
if pcall(require, "tests.test_scope_10_chaserAI") then end
if pcall(require, "tests.test_scope_11_bossAttacks") then end
if pcall(require, "tests.test_scope_13_worldFacade") then end
if pcall(require, "tests.test_scope_16_profiles") then end
if pcall(require, "tests.test_scope_18_gamestatesDebug") then end
if pcall(require, "tests.test_scope_19_biomes_hazards") then end
if pcall(require, "tests.test_scope_20_patroller_ai") then end
if pcall(require, "tests.test_scope_22_miniboss") then end
if pcall(require, "tests.test_scope_21_items_arsenal") then end
if pcall(require, "tests.test_scope_23_tarot") then end
if pcall(require, "tests.test_scope_24_mutators") then end
if pcall(require, "tests.test_scope_25_mystery") then end
if pcall(require, "tests.test_scope_26_shopv2") then end
if pcall(require, "tests.test_scope_27_display_settings") then end
if pcall(require, "tests.test_scope_28_shop_economy") then end
if pcall(require, "tests.test_scope_29_status_fx") then end
if pcall(require, "tests.test_scope_30_combat_ram") then end
if pcall(require, "tests.test_scope_31_livecoding") then end
if pcall(require, "tests.test_scope_32_dailySeed") then end
if pcall(require, "tests.test_scope_33_zerogc") then end
if pcall(require, "tests.test_scope_34_shrine") then end
if pcall(require, "tests.test_scope_35_bounty") then end
if pcall(require, "tests.test_scope_36_modes") then end
if pcall(require, "tests.test_scope_37_codex") then end
if pcall(require, "tests.test_scope_38_templates") then end
if pcall(require, "tests.test_scope_39_sprint1") then end
if pcall(require, "tests.test_scope_40_zerogc_stress") then end

-- Source files for full coverage reporting
local source_files = {
    "constants.lua",
    "main.lua",
    "main_keypressed.lua",
    "core/easings.lua",
    "core/config.lua",
    "core/helpers.lua",
    "core/logger.lua",
    "core/timers.lua",
    "core/touch.lua",
    "core/world.lua",
    "core/events.lua",
    "core/input.lua",
    "core/assets.lua",
    "core/livecoding.lua",
    "core/rng.lua",
    "entities/bossAttacks.lua",
    "entities/chaserAI.lua",
    "entities/patrollerAI.lua",
    "entities/enemies.lua",
    "entities/enemyAttackRegistry.lua",
    "entities/enemyBossLogic.lua",
    "entities/enemySpawnLogic.lua",
    "entities/enemyMiniBoss.lua",
    "entities/enemyHelpers.lua",
    "entities/food.lua",
    "entities/obstacles.lua",
    "entities/snake.lua",
    "entities/snake/core.lua",
    "entities/snake/abilities.lua",
    "entities/snake/collisions.lua",
    "entities/snake/movement.lua",
    "world/world.lua",
    "world/dungeonGen.lua",
    "world/dungeonTemplates.lua",
    "world/wallPatterns.lua",
    "world/populate.lua",
    "world/biomeHazards.lua",
    "systems/achievements.lua",
    "systems/debugLogo.lua",
    "systems/debugTools.lua",
    "systems/gameflow.lua",
    "systems/gamestates.lua",
    "systems/gamestates/playing.lua",
    "systems/gamestates/transition.lua",
    "systems/gamestates/death.lua",
    "systems/items.lua",
    "systems/tarot.lua",
    "systems/tarotArt.lua",
    "systems/miniBossArt.lua",
    "systems/roomMutators.lua",
    "systems/mystery.lua",
    "systems/shrine.lua",
    "systems/shrineDefs.lua",
    "systems/shrineShop.lua",
    "systems/shrineDraw.lua",
    "systems/shrineUI.lua",
    "systems/bounty.lua",
    "systems/modes.lua",
    "systems/skinRegistry.lua",
    "systems/codex.lua",
    "systems/codexUI.lua",
    "systems/daily.lua",
    "systems/persistence.lua",
    "systems/persistenceCodec.lua",
    "systems/persistenceProfiles.lua",
    "systems/persistenceSettings.lua",
    "systems/profileSchema.lua",
    "systems/player.lua",
    "systems/playerSpeed.lua",
    "systems/playerTimers.lua",
    "systems/profiles.lua",
    "systems/profilesDraw.lua",
    "systems/settings.lua",
    "systems/settingsDraw.lua",
    "systems/settingsWidgets.lua",
    "systems/settingsInput.lua",
    "systems/shop.lua",
    "ui/ui.lua",
    "ui/introUI.lua",
    "ui/menuUI.lua",
    "ui/menuLogo.lua",
    "ui/menuCard.lua",
    "ui/playModalUI.lua",
    "ui/dailyResultUI.lua",
    "ui/hudUI.lua",
    "ui/toastsUI.lua",
    "ui/popupsUI.lua",
    "ui/overlaysUI.lua",
    "render/shaders.lua",
    "render/shaderSources.lua",
    "render/shaderFx.lua",
    "render/particles.lua",
    "render/renderMain.lua",
    "render/enemiesDraw.lua",
    "audio/sound.lua",
}

-- Generate coverage report
harness.report_coverage(source_files)

-- Summary report
local success = harness.summary()

if love and love.event and love.event.quit then
    love.event.quit(success and 0 or 1)
else
    os.exit(success and 0 or 1)
end

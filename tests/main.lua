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
if pcall(require, "tests.test_scope_13_worldFacade") then end
if pcall(require, "tests.test_scope_16_profiles") then end
if pcall(require, "tests.test_scope_18_gamestatesDebug") then end
if pcall(require, "tests.test_scope_19_biomes_hazards") then end
if pcall(require, "tests.test_scope_20_patroller_ai") then end

-- Source files for full coverage reporting
local source_files = {
    "constants.lua",
    "main.lua",
    "core/config.lua",
    "core/helpers.lua",
    "core/logger.lua",
    "core/timers.lua",
    "core/touch.lua",
    "core/world.lua",
    "entities/bossAttacks.lua",
    "entities/chaserAI.lua",
    "entities/patrollerAI.lua",
    "entities/enemies.lua",
    "entities/enemyHelpers.lua",
    "entities/food.lua",
    "entities/obstacles.lua",
    "entities/snake.lua",
    "world/world.lua",
    "world/dungeonGen.lua",
    "world/populate.lua",
    "systems/achievements.lua",
    "systems/debugLogo.lua",
    "systems/debugTools.lua",
    "systems/gameflow.lua",
    "systems/gamestates.lua",
    "systems/items.lua",
    "systems/persistence.lua",
    "systems/player.lua",
    "systems/profiles.lua",
    "systems/profilesDraw.lua",
    "systems/settings.lua",
    "systems/settingsDraw.lua",
    "systems/shop.lua",
    "ui/ui.lua",
    "ui/introUI.lua",
    "ui/menuUI.lua",
    "ui/menuLogo.lua",
    "ui/menuCard.lua",
    "ui/hudUI.lua",
    "ui/toastsUI.lua",
    "ui/popupsUI.lua",
    "ui/overlaysUI.lua",
    "render/shaders.lua",
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

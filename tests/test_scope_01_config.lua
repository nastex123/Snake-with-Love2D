-- tests/test_scope_01_config.lua
-- Comprehensive Unit Test Suite for core/config.lua and constants.lua (Scope 01)

local harness = require("tests.test_harness")
local describe = harness.describe
local it = harness.it
local assert_equal = harness.assert_equal
local assert_not_equal = harness.assert_not_equal
local assert_true = harness.assert_true
local assert_false = harness.assert_false
local assert_nil = harness.assert_nil
local assert_not_nil = harness.assert_not_nil
local assert_table_equal = harness.assert_table_equal
local assert_almost_equal = harness.assert_almost_equal
local assert_gt = harness.assert_gt
local assert_gte = harness.assert_gte
local assert_lt = harness.assert_lt
local assert_lte = harness.assert_lte
local assert_type = harness.assert_type

local config = require("core.config")
local constants = require("constants")

-- Helper: validate RGBA color table
local function validate_color(c, name, expected_len)
    assert_type(c, "table", name .. " must be a table")
    local len = #c
    if expected_len then
        assert_equal(expected_len, len, name .. " must have " .. tostring(expected_len) .. " components")
    else
        assert_true(len == 3 or len == 4, name .. " must have 3 (RGB) or 4 (RGBA) components, got " .. tostring(len))
    end
    for idx, val in ipairs(c) do
        assert_type(val, "number", name .. "[" .. idx .. "] must be a number")
        assert_gte(val, 0.0, name .. "[" .. idx .. "] must be >= 0.0")
        assert_lte(val, 1.0, name .. "[" .. idx .. "] must be <= 1.0")
    end
end

-- =========================================================================
-- SUITE 1: Shim & Module Compatibility
-- =========================================================================
describe("Scope 01 - Shim Compatibility (constants.lua vs core/config.lua)", function()
    it("should export a valid table from core/config.lua", function()
        assert_type(config, "table", "core/config must return a table")
        local count = 0
        for _ in pairs(config) do count = count + 1 end
        assert_gt(count, 50, "core/config must have at least 50 configured keys")
    end)

    it("constants.lua shim must return the exact core.config table reference", function()
        assert_type(constants, "table", "constants shim must return a table")
        assert_equal(config, constants, "constants shim must point to the identical table instance of core/config")
    end)

    it("accessing any key via constants or config must yield identical values", function()
        for k, v in pairs(config) do
            assert_equal(v, constants[k], "Mismatch on key: " .. tostring(k))
        end
    end)
end)

-- =========================================================================
-- SUITE 2: Canvas, Resolution and Grid Dimensions
-- =========================================================================
describe("Scope 01 - Canvas, Resolution & Grid Sizes", function()
    it("should have correct virtual canvas dimensions (640x360, 16:9)", function()
        assert_type(config.canvasWidth, "number", "canvasWidth must be number")
        assert_type(config.canvasHeight, "number", "canvasHeight must be number")
        assert_equal(640, config.canvasWidth, "canvasWidth must be 640")
        assert_equal(360, config.canvasHeight, "canvasHeight must be 360")
        assert_almost_equal(16 / 9, config.canvasWidth / config.canvasHeight, 0.001, "Aspect ratio must be 16:9")
    end)

    it("should have consistent tile sizes between modern and legacy aliases", function()
        assert_type(config.tileSize, "number", "tileSize must be number")
        assert_type(config.TAMANIO_BLOQUE, "number", "TAMANIO_BLOQUE must be number")
        assert_equal(20, config.tileSize, "tileSize must be 20")
        assert_equal(20, config.TAMANIO_BLOQUE, "TAMANIO_BLOQUE must be 20")
        assert_equal(config.tileSize, config.TAMANIO_BLOQUE, "tileSize and TAMANIO_BLOQUE must match")
    end)

    it("should define valid grid bounds and HUD offsets", function()
        assert_type(config.MAX_GRID_COLS, "number", "MAX_GRID_COLS must be number")
        assert_type(config.MAX_GRID_ROWS, "number", "MAX_GRID_ROWS must be number")
        assert_gt(config.MAX_GRID_COLS, 0, "MAX_GRID_COLS must be > 0")
        assert_gt(config.MAX_GRID_ROWS, 0, "MAX_GRID_ROWS must be > 0")
        assert_equal(40, config.MAX_GRID_COLS, "MAX_GRID_COLS must be 40")
        assert_equal(28, config.MAX_GRID_ROWS, "MAX_GRID_ROWS must be 28")

        assert_type(config.HUD_HEIGHT, "number", "HUD_HEIGHT must be number")
        assert_type(config.GRID_OFFSET_Y, "number", "GRID_OFFSET_Y must be number")
        assert_equal(28, config.HUD_HEIGHT, "HUD_HEIGHT must be 28")
        assert_equal(28, config.GRID_OFFSET_Y, "GRID_OFFSET_Y must be 28")
    end)
end)

-- =========================================================================
-- SUITE 3: Game State Machine Constants
-- =========================================================================
describe("Scope 01 - Game State Constants", function()
    local state_keys = {
        "GAME_STATE_MENU",
        "GAME_STATE_PLAYING",
        "GAME_STATE_DEATH_ANIMATION",
        "GAME_STATE_HIGH_SCORE",
        "GAME_STATE_SHOP",
        "GAME_STATE_PAUSED",
        "GAME_STATE_TRANSITION",
    }

    it("should define all 7 required game states as numbers", function()
        for _, key in ipairs(state_keys) do
            assert_not_nil(config[key], "Missing state: " .. key)
            assert_type(config[key], "number", key .. " must be number")
        end
    end)

    it("game states must map to integers 0 through 6 uniquely", function()
        assert_equal(0, config.GAME_STATE_MENU, "GAME_STATE_MENU must be 0")
        assert_equal(1, config.GAME_STATE_PLAYING, "GAME_STATE_PLAYING must be 1")
        assert_equal(2, config.GAME_STATE_DEATH_ANIMATION, "GAME_STATE_DEATH_ANIMATION must be 2")
        assert_equal(3, config.GAME_STATE_HIGH_SCORE, "GAME_STATE_HIGH_SCORE must be 3")
        assert_equal(4, config.GAME_STATE_SHOP, "GAME_STATE_SHOP must be 4")
        assert_equal(5, config.GAME_STATE_PAUSED, "GAME_STATE_PAUSED must be 5")
        assert_equal(6, config.GAME_STATE_TRANSITION, "GAME_STATE_TRANSITION must be 6")

        local seen = {}
        for _, key in ipairs(state_keys) do
            local val = config[key]
            assert_nil(seen[val], "Duplicate state value: " .. tostring(val) .. " for " .. key)
            seen[val] = key
        end
    end)
end)

-- =========================================================================
-- SUITE 4: Movement, Speed & Input Buffering
-- =========================================================================
describe("Scope 01 - Movement, Speed & Input Buffering", function()
    it("should configure initial and minimum speeds within logical bounds", function()
        assert_type(config.VELOCIDAD_INICIAL, "number", "VELOCIDAD_INICIAL must be number")
        assert_type(config.VELOCIDAD_MINIMA, "number", "VELOCIDAD_MINIMA must be number")
        assert_gt(config.VELOCIDAD_INICIAL, 0, "VELOCIDAD_INICIAL must be > 0")
        assert_gt(config.VELOCIDAD_MINIMA, 0, "VELOCIDAD_MINIMA must be > 0")
        assert_lte(config.VELOCIDAD_MINIMA, config.VELOCIDAD_INICIAL, "VELOCIDAD_MINIMA must be <= VELOCIDAD_INICIAL")
        assert_equal(0.13, config.VELOCIDAD_INICIAL, "VELOCIDAD_INICIAL should be 0.13")
        assert_equal(0.05, config.VELOCIDAD_MINIMA, "VELOCIDAD_MINIMA should be 0.05")
    end)

    it("should configure speed adjust limits and increment", function()
        assert_type(config.SPEED_ADJUST_INCREMENT, "number", "SPEED_ADJUST_INCREMENT must be number")
        assert_type(config.MIN_BASE_SPEED, "number", "MIN_BASE_SPEED must be number")
        assert_type(config.MAX_BASE_SPEED, "number", "MAX_BASE_SPEED must be number")
        assert_gt(config.SPEED_ADJUST_INCREMENT, 0, "SPEED_ADJUST_INCREMENT must be > 0")
        assert_lt(config.MIN_BASE_SPEED, config.MAX_BASE_SPEED, "MIN_BASE_SPEED must be < MAX_BASE_SPEED")
        assert_equal(0.01, config.SPEED_ADJUST_INCREMENT)
        assert_equal(0.05, config.MIN_BASE_SPEED)
        assert_equal(0.30, config.MAX_BASE_SPEED)
    end)

    it("should define corner buffer ratio and input buffer max correctly", function()
        assert_type(config.CORNER_BUFFER_RATIO, "number", "CORNER_BUFFER_RATIO must be number")
        assert_gt(config.CORNER_BUFFER_RATIO, 0, "CORNER_BUFFER_RATIO must be > 0")
        assert_lte(config.CORNER_BUFFER_RATIO, 1.0, "CORNER_BUFFER_RATIO must be <= 1.0")
        assert_equal(0.75, config.CORNER_BUFFER_RATIO)

        assert_type(config.INPUT_BUFFER_MAX, "number", "INPUT_BUFFER_MAX must be number")
        assert_gte(config.INPUT_BUFFER_MAX, 1, "INPUT_BUFFER_MAX must be at least 1")
        assert_equal(2, config.INPUT_BUFFER_MAX)
    end)
end)

-- =========================================================================
-- SUITE 5: Timings, Animations and Transitions
-- =========================================================================
describe("Scope 01 - Timings, Delays & Animations", function()
    it("should configure death and celebration animations", function()
        assert_type(config.HIGH_SCORE_CELEBRATION_DURATION, "number")
        assert_gt(config.HIGH_SCORE_CELEBRATION_DURATION, 0)
        assert_equal(1.3, config.HIGH_SCORE_CELEBRATION_DURATION)

        assert_type(config.DEATH_ANIMATION_SEGMENT_DELAY, "number")
        assert_gt(config.DEATH_ANIMATION_SEGMENT_DELAY, 0)
        assert_equal(0.05, config.DEATH_ANIMATION_SEGMENT_DELAY)

        assert_type(config.DURACION_FLASH_COMER, "number")
        assert_gt(config.DURACION_FLASH_COMER, 0)
        assert_equal(0.6, config.DURACION_FLASH_COMER)
    end)

    it("should configure screen shake and fade parameters", function()
        assert_type(config.SHAKE_DURATION, "number")
        assert_type(config.SHAKE_INTENSITY, "number")
        assert_type(config.FADE_SPEED, "number")
        assert_type(config.TRANSITION_DURATION, "number")

        assert_gt(config.SHAKE_DURATION, 0)
        assert_gt(config.SHAKE_INTENSITY, 0)
        assert_gt(config.FADE_SPEED, 0)
        assert_gt(config.TRANSITION_DURATION, 0)

        assert_equal(0.3, config.SHAKE_DURATION)
        assert_equal(4, config.SHAKE_INTENSITY)
        assert_equal(3, config.FADE_SPEED)
        assert_equal(0.8, config.TRANSITION_DURATION)
    end)

    it("should define a monotonic timeline for the Balatro-style intro sequence", function()
        local intro_stages = {
            {"INTRO_FADE_END", config.INTRO_FADE_END, 0.5},
            {"INTRO_CARD_RISE", config.INTRO_CARD_RISE, 0.5},
            {"INTRO_SPIRAL_START", config.INTRO_SPIRAL_START, 1.5},
            {"INTRO_FLASH_START", config.INTRO_FLASH_START, 2.5},
            {"INTRO_FLASH_END", config.INTRO_FLASH_END, 3.0},
            {"INTRO_LOGO_START", config.INTRO_LOGO_START, 3.0},
            {"INTRO_MENU_START", config.INTRO_MENU_START, 3.5},
            {"INTRO_READY", config.INTRO_READY, 4.5},
        }

        local prev_time = 0
        for _, stage in ipairs(intro_stages) do
            local name, val, expected = stage[1], stage[2], stage[3]
            assert_type(val, "number", name .. " must be number")
            assert_equal(expected, val, name .. " value mismatch")
            assert_gte(val, prev_time, name .. " must be >= previous intro step")
            prev_time = val
        end
        assert_equal(4.5, config.INTRO_READY, "INTRO_READY total duration must be 4.5 seconds")
    end)
end)

-- =========================================================================
-- SUITE 6: Items & Shop Pricing
-- =========================================================================
describe("Scope 01 - Items & Shop Registry Values", function()
    local item_cost_keys = {
        {"SHIELD_COST", 30},
        {"ARMOR_COST", 40},
        {"GHOST_COST", 25},
        {"MAGNET_COST", 20},
        {"BOMB_COST", 25},
        {"HUNGER_COST", 15},
        {"SPEED_REDUCER_COST", 15},
        {"TURBO_COST", 20},
        {"SLOW_COST", 25},
        {"DOUBLER_COST", 35},
        {"EXTRA_COIN_COST", 20},
        {"STAR_COST", 40},
    }

    it("should define valid positive costs for all 12 shop items", function()
        for _, item in ipairs(item_cost_keys) do
            local key, expected_cost = item[1], item[2]
            local cost = config[key]
            assert_not_nil(cost, "Missing item cost: " .. key)
            assert_type(cost, "number", key .. " must be number")
            assert_gt(cost, 0, key .. " must be > 0")
            assert_equal(expected_cost, cost, key .. " cost mismatch")
        end
    end)

    it("should define valid item durations and specific modifiers", function()
        assert_equal(5, config.GHOST_DURATION)
        assert_equal(10, config.MAGNET_DURATION)
        assert_equal(2, config.MAGNET_RANGE)
        assert_equal(3, config.BOMB_RADIUS)
        assert_equal(0.02, config.SPEED_REDUCER_AMOUNT)
        assert_equal(0.7, config.TURBO_MULTIPLIER)
        assert_equal(8, config.TURBO_DURATION)
        assert_equal(0.5, config.SLOW_TIMESCALE)
        assert_equal(5, config.SLOW_DURATION)
        assert_equal(8, config.DOUBLER_DURATION)
        assert_equal(10, config.EXTRA_COIN_DURATION)
        assert_equal(5, config.STAR_DURATION)
        assert_equal(1, config.COINS_PER_FRUIT)
    end)
end)

-- =========================================================================
-- SUITE 7: Combo System, Scoring and Food Types
-- =========================================================================
describe("Scope 01 - Combo, Score Popups & Food Types", function()
    it("should configure combo window and multipliers", function()
        assert_type(config.COMBO_WINDOW, "number")
        assert_type(config.COMBO_MULTIPLIER, "number")
        assert_gt(config.COMBO_WINDOW, 0)
        assert_gt(config.COMBO_MULTIPLIER, 0)
        assert_equal(8.0, config.COMBO_WINDOW)
        assert_equal(0.5, config.COMBO_MULTIPLIER)
    end)

    it("should define standard food type identifiers (NORMAL, GOLD, COIN)", function()
        assert_equal(1, config.FOOD_NORMAL)
        assert_equal(2, config.FOOD_GOLD)
        assert_equal(3, config.FOOD_COIN)
        assert_not_equal(config.FOOD_NORMAL, config.FOOD_GOLD)
        assert_not_equal(config.FOOD_NORMAL, config.FOOD_COIN)
        assert_not_equal(config.FOOD_GOLD, config.FOOD_COIN)
    end)

    it("should configure score popup lifetime and vertical speed", function()
        assert_type(config.SCORE_POPUP_LIFETIME, "number")
        assert_type(config.SCORE_POPUP_SPEED, "number")
        assert_gt(config.SCORE_POPUP_LIFETIME, 0)
        assert_gt(config.SCORE_POPUP_SPEED, 0)
        assert_equal(1.0, config.SCORE_POPUP_LIFETIME)
        assert_equal(40, config.SCORE_POPUP_SPEED)
    end)
end)

-- =========================================================================
-- SUITE 8: Enemies, Spawns and Boss Specifications
-- =========================================================================
describe("Scope 01 - Enemies, Spawns & Boss Configuration", function()
    it("should configure enemy speeds, drops, and intervals", function()
        assert_equal(0.3, config.ENEMY_CHASER_SPEED)
        assert_equal(0.2, config.ENEMY_PATROLLER_SPEED)
        assert_equal(3, config.ENEMY_SPAWNER_INTERVAL)
        assert_equal(50, config.ENEMY_SPAWN_INTERVAL)
        assert_equal(50, config.OBSTACLE_SPAWN_INTERVAL)

        assert_equal(3, config.ENEMY_DROP_CHASER)
        assert_equal(2, config.ENEMY_DROP_PATROLLER)
        assert_equal(1, config.ENEMY_DROP_SPAWNER)
    end)

    it("should configure boss caps, food target, respawns, and health bar", function()
        assert_equal(15, config.BOSS_FOOD_TARGET, "Boss defeat requires 15 non-coin foods")
        assert_equal(3, config.BOSS_MAX_RED)
        assert_equal(4, config.BOSS_MAX_BLUE)
        assert_equal(15, config.BOSS_ENEMY_LIFETIME)
        assert_equal(5, config.BOSS_RESPAWN_DELAY)
        assert_equal(40, config.BOSS_RESPAWN_RETRY)

        assert_equal("teleporter", config.BOSS_TYPE_TELEPORTER)
        assert_equal("spawner_boss", config.BOSS_TYPE_SPAWNER)

        assert_type(config.BOSS_COLORS, "table")
        validate_color(config.BOSS_COLORS.teleporter, "BOSS_COLORS.teleporter", 3)
        validate_color(config.BOSS_COLORS.spawner_boss, "BOSS_COLORS.spawner_boss", 3)

        assert_type(config.BOSS_HEALTH_BAR, "table")
        assert_equal(96, config.BOSS_HEALTH_BAR.width)
        assert_equal(8, config.BOSS_HEALTH_BAR.height)
        assert_equal(-24, config.BOSS_HEALTH_BAR.yOffset)
        assert_equal(6.0, config.BOSS_HEALTH_BAR.lerpSpeed)
        validate_color(config.BOSS_HEALTH_BAR.bgColor, "BOSS_HEALTH_BAR.bgColor", 4)
        validate_color(config.BOSS_HEALTH_BAR.fgColor, "BOSS_HEALTH_BAR.fgColor", 4)
        validate_color(config.BOSS_HEALTH_BAR.borderColor, "BOSS_HEALTH_BAR.borderColor", 4)
    end)

    it("should configure Chaser social AI parameters", function()
        assert_equal(8, config.CHASER_AGGRO_RADIUS)
        assert_equal(1.15, config.CHASER_PACK_SLOWDOWN)
        assert_equal(1.5, config.CHASER_SPREAD_PENALTY)
        assert_equal(8, config.CHASER_RING_CYCLE)
        assert_equal(0.7, config.CHASER_IDLE_SPIN)
        assert_equal(10, config.CHASER_CLOSE_SPIN)
        assert_equal(7, config.CHASER_ROT_LERP)
    end)
end)

-- =========================================================================
-- SUITE 9: Dungeon Generation & Room Templates
-- =========================================================================
describe("Scope 01 - Dungeon Generation Constants", function()
    it("should define dungeon sizing, leaves, and room constraints", function()
        assert_equal(5, config.DUNGEON_TARGET_ROOMS)
        assert_equal(800, config.DUNGEON_VIRTUAL_W)
        assert_equal(600, config.DUNGEON_VIRTUAL_H)
        assert_equal(120, config.DUNGEON_MIN_ROOM_W)
        assert_equal(90, config.DUNGEON_MIN_ROOM_H)
        assert_equal(250, config.DUNGEON_MAX_ROOM_W)
        assert_equal(200, config.DUNGEON_MAX_ROOM_H)
        assert_equal(180, config.DUNGEON_BSP_MIN_LEAF)
        assert_equal(20, config.DUNGEON_CORRIDOR_WIDTH)
        assert_equal(15, config.DUNGEON_ROOM_PADDING)
    end)

    it("should define all 7 standard room type strings", function()
        local room_types = {
            {"ROOM_CORRIDOR", "corridor"},
            {"ROOM_ARENA", "arena"},
            {"ROOM_CHOKE", "choke"},
            {"ROOM_HUB", "hub"},
            {"ROOM_TREASURE", "treasure"},
            {"ROOM_SPAWNER", "spawner"},
            {"ROOM_BOSS", "boss"},
        }
        for _, rt in ipairs(room_types) do
            local key, expected_val = rt[1], rt[2]
            assert_not_nil(config[key], "Missing room type: " .. key)
            assert_equal(expected_val, config[key], key .. " mismatch")
        end
    end)
end)

-- =========================================================================
-- SUITE 10: Combat & Survival Package (Phase 8)
-- =========================================================================
describe("Scope 01 - Combat & Survival Package (Phase 8)", function()
    it("should configure autotomy, decoy, revive, and constrictor parameters", function()
        assert_equal(8.0, config.AUTOTOMY_COOLDOWN)
        assert_equal(1.5, config.AUTOTOMY_GHOST_DURATION)
        assert_equal(4.0, config.AUTOTOMY_DECOY_DURATION)
        assert_equal(5.0, config.CONSTRICTOR_BUFF_DURATION)
        assert_equal(30, config.REVIVE_COIN_COST)
        assert_equal(3.0, config.REVIVE_GHOST_DURATION)
        assert_equal(0.1, config.SURVIVAL_STREAK_INCREMENT)
    end)

    it("should configure berry, pepper, and slimming food mechanics", function()
        assert_equal(3.5, config.FIRE_PEPPER_DURATION)
        assert_equal(1.8, config.FIRE_TRAIL_LIFETIME)
        assert_equal(2.5, config.FROST_BERRY_DURATION)
        assert_equal(12, config.SLIMMING_MIN_LENGTH)
        assert_equal(0.5, config.SLIMMING_FACTOR)
        assert_gt(config.SLIMMING_FACTOR, 0)
        assert_lt(config.SLIMMING_FACTOR, 1.0)
    end)

    it("should configure reverse slither, tail snap, and repelling timers", function()
        assert_equal(3.0, config.REVERSE_SLITHER_DURATION)
        assert_equal(10.0, config.REVERSE_SLITHER_COOLDOWN)
        assert_equal(0.8, config.TAIL_SNAP_STUN_DURATION)
        assert_equal(1, config.TAIL_SNAP_PUSH_DIST)
        assert_equal(1.5, config.REPELLING_MOVE_INTERVAL)
        assert_equal(5.0, config.FOOD_COUNTDOWN_TIMER)
        assert_equal(4.0, config.FOOD_TWIN_TIMER)
        assert_equal(4.0, config.FOOD_TWIN_WINDOW)
    end)
end)

-- =========================================================================
-- SUITE 11: Biomes Registry & Stage Modifiers Validation
-- =========================================================================
describe("Scope 01 - Biomes Registry Structure & Validity", function()
    it("should define exactly 5 biomes indexed 1 through 5", function()
        assert_type(config.BIOMES, "table", "BIOMES must be a table")
        assert_equal(5, #config.BIOMES, "BIOMES must contain 5 stages")
    end)

    it("each biome must possess all required schema fields and valid types", function()
        local expected_biomes = {
            [1] = { id = "catacumbas", name = "Catacumbas de Piedra", wallWrap = true, isIce = false, hazardLava = false, isSlime = false },
            [2] = { id = "hielo", name = "Cripta Helada", wallWrap = true, isIce = true, hazardLava = false, isSlime = false },
            [3] = { id = "volcan", name = "Caverna Volcánica", wallWrap = true, isIce = false, hazardLava = true, isSlime = false },
            [4] = { id = "colmena", name = "Colmena Tóxica", wallWrap = true, isIce = false, hazardLava = false, isSlime = true },
            [5] = { id = "vacio", name = "Santuario del Vacío", wallWrap = false, isIce = false, hazardLava = false, isSlime = false },
        }

        for stage = 1, 5 do
            local b = config.BIOMES[stage]
            local exp = expected_biomes[stage]
            assert_not_nil(b, "Missing biome for stage " .. stage)
            assert_equal(exp.id, b.id, "Stage " .. stage .. " id mismatch")
            assert_equal(exp.name, b.name, "Stage " .. stage .. " name mismatch")
            assert_type(b.subtitle, "string", "Stage " .. stage .. " subtitle must be string")
            assert_equal(exp.wallWrap, b.wallWrap, "Stage " .. stage .. " wallWrap mismatch")
            assert_equal(exp.isIce, b.isIce, "Stage " .. stage .. " isIce mismatch")
            assert_equal(exp.hazardLava, b.hazardLava, "Stage " .. stage .. " hazardLava mismatch")
            assert_equal(exp.isSlime, b.isSlime, "Stage " .. stage .. " isSlime mismatch")

            validate_color(b.gridColor, "BIOMES[" .. stage .. "].gridColor", 3)
            validate_color(b.gridAccent, "BIOMES[" .. stage .. "].gridAccent", 3)
            validate_color(b.bgTint, "BIOMES[" .. stage .. "].bgTint", 3)
            validate_color(b.wallColor, "BIOMES[" .. stage .. "].wallColor", 3)
        end
    end)
end)

-- =========================================================================
-- SUITE 12: Color Palette & Shader Colors Validation
-- =========================================================================
describe("Scope 01 - Color Palettes & Shading", function()
    it("should define valid normalized RGB/RGBA colors for UI and World", function()
        validate_color(config.COLOR_BG, "COLOR_BG", 3)
        validate_color(config.COLOR_GRID_A, "COLOR_GRID_A", 3)
        validate_color(config.COLOR_GRID_B, "COLOR_GRID_B", 3)
        validate_color(config.COLOR_ACCENT, "COLOR_ACCENT", 3)
        validate_color(config.COLOR_GRID_HOT_A, "COLOR_GRID_HOT_A", 3)
        validate_color(config.COLOR_GRID_HOT_B, "COLOR_GRID_HOT_B", 3)
        validate_color(config.COLOR_GOLD, "COLOR_GOLD", 3)
        validate_color(config.COLOR_PANEL, "COLOR_PANEL", 4)
        validate_color(config.COLOR_RED, "COLOR_RED", 3)
        validate_color(config.COLOR_GREEN, "COLOR_GREEN", 3)
        validate_color(config.COLOR_ENEMY_CHASER, "COLOR_ENEMY_CHASER", 3)
        validate_color(config.COLOR_ENEMY_PATROLLER, "COLOR_ENEMY_PATROLLER", 3)
        validate_color(config.COLOR_ENEMY_SPAWNER, "COLOR_ENEMY_SPAWNER", 3)
        validate_color(config.TOAST_BG_COLOR, "TOAST_BG_COLOR", 4)

        assert_type(config.SHIMMER_SPEED, "number")
        assert_gt(config.SHIMMER_SPEED, 0)
        assert_equal(2.0, config.SHIMMER_SPEED)
    end)
end)

-- =========================================================================
-- SUITE 13: Typography & Font Hierarchy
-- =========================================================================
describe("Scope 01 - Typography & Font Size Hierarchy", function()
    it("should define font file name and strictly descending font sizes", function()
        assert_type(config.FONT_FILE, "string")
        assert_equal("PressStart2P-Regular.ttf", config.FONT_FILE)

        assert_type(config.FONT_TITLE, "number")
        assert_type(config.FONT_LARGE, "number")
        assert_type(config.FONT_NORMAL, "number")
        assert_type(config.FONT_SMALL, "number")

        assert_equal(28, config.FONT_TITLE)
        assert_equal(16, config.FONT_LARGE)
        assert_equal(11, config.FONT_NORMAL)
        assert_equal(8, config.FONT_SMALL)

        assert_gt(config.FONT_TITLE, config.FONT_LARGE, "TITLE must be > LARGE")
        assert_gt(config.FONT_LARGE, config.FONT_NORMAL, "LARGE must be > NORMAL")
        assert_gt(config.FONT_NORMAL, config.FONT_SMALL, "NORMAL must be > SMALL")
        assert_gt(config.FONT_SMALL, 0, "SMALL must be > 0")
    end)
end)

-- =========================================================================
-- SUITE 14: Particles & Toasts UI
-- =========================================================================
describe("Scope 01 - Particles & Toasts UI Specifications", function()
    it("should configure positive integer particle burst counts", function()
        assert_equal(15, config.PARTICLE_COMER_COUNT)
        assert_equal(25, config.PARTICLE_MUERTE_COUNT)
        assert_equal(10, config.PARTICLE_ENEMY_COUNT)
    end)

    it("should configure toast layout and animation settings", function()
        assert_equal(1.5, config.TOAST_SHOW_DURATION)
        assert_equal(0.25, config.TOAST_FADE)
        assert_equal(600, config.TOAST_MAX_WIDTH)
        assert_equal(12, config.TOAST_PADDING)
        assert_equal(28, config.TOAST_ICON_SIZE)
        assert_equal(14, config.TOAST_SLIDE)
        assert_equal(0.5, config.TOAST_SCHEDULE_DELAY)
    end)
end)

-- =========================================================================
-- SUITE 15: Immutability & Deep Consistency
-- =========================================================================
describe("Scope 01 - Consistency & Immutability Patterns", function()
    it("modifying a clone should not mutate the canonical config", function()
        local helpers = require("core.helpers")
        local cfg_copy = helpers.deep_copy(config)
        cfg_copy.canvasWidth = 9999
        cfg_copy.BIOMES[1].name = "Mutated Biome"

        assert_equal(640, config.canvasWidth, "Original canvasWidth must remain 640")
        assert_equal("Catacumbas de Piedra", config.BIOMES[1].name, "Original Biome name must remain unmutated")
    end)

    it("all numbers in config must be finite (not NaN, not Inf)", function()
        for k, v in pairs(config) do
            if type(v) == "number" then
                assert_true(v == v, "Value for " .. tostring(k) .. " is NaN")
                assert_true(v ~= math.huge and v ~= -math.huge, "Value for " .. tostring(k) .. " is Infinite")
            end
        end
    end)
end)

return harness

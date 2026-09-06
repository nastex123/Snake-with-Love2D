-- tests/test_scope_23_tarot.lua — Stage Tarot Draft System (GDD §14, TDD §10.13)
-- Suite consola-only: motor de draft, ciclo de vida y cableado de estado. Sin love.graphics.
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local tarot = require("systems.tarot")

harness.describe("Scope 23 - Tarot catalog (12 defs)", function()
    harness.it("defines exactly 12 cards with unique stable ids", function()
        harness.assert_equal(12, #tarot.TAROT_DEFS, "must be 12 cards")
        local seen = {}
        for _, d in ipairs(tarot.TAROT_DEFS) do
            harness.assert_not_nil(d.id, "card needs id")
            harness.assert_not_nil(d.name, "card needs name")
            harness.assert_not_nil(d.desc, "card needs desc")
            harness.assert_nil(seen[d.id], "duplicate card id: " .. tostring(d.id))
            seen[d.id] = true
        end
    end)

    harness.it("includes the hook ids referenced by gameplay (mercury/iron_spine/etc)", function()
        for _, id in ipairs({"mercury", "iron_spine", "eagle_eye", "shadow_thief",
            "alchemical_digestion", "dragon_blood", "absolute_zero", "magic_circle",
            "astral_mirror", "midas_pouch", "iron_heart", "reaper"}) do
            harness.assert_true(tarot.has(id) == false or true, "catalog check " .. id)
            local found = false
            for _, d in ipairs(tarot.TAROT_DEFS) do if d.id == id then found = true end end
            harness.assert_true(found, "missing card in catalog: " .. id)
        end
    end)

    harness.it("exposes GAME_STATE_TAROT = 7 without shifting states 0-6", function()
        harness.assert_equal(7, constants.GAME_STATE_TAROT, "TAROT must be 7")
        harness.assert_equal(6, constants.GAME_STATE_TRANSITION, "TRANSITION stays 6")
    end)
end)

harness.describe("Scope 23 - Tarot draft lifecycle", function()
    harness.it("reset clears stageCards and draft", function()
        tarot.reset()
        harness.assert_equal(0, tarot.count(), "empty after reset")
        harness.assert_false(tarot.isOpen(), "no draft open after reset")
    end)

    harness.it("sampleOptions returns 3 distinct unequipped ids", function()
        tarot.reset()
        local opts = tarot.sampleOptions()
        harness.assert_equal(3, #opts, "3 options")
        harness.assert_true(opts[1] ~= opts[2] and opts[1] ~= opts[3] and opts[2] ~= opts[3], "distinct")
    end)

    harness.it("sampleOptions excludes already equipped cards", function()
        tarot.reset()
        world.state.stageCards = {"mercury", "reaper"}
        for _ = 1, 10 do
            local opts = tarot.sampleOptions()
            for _, id in ipairs(opts) do
                harness.assert_true(id ~= "mercury" and id ~= "reaper", "equipped excluded: " .. tostring(id))
            end
        end
        tarot.reset()
    end)

    harness.it("shouldOffer only on rooms 1/2/4 with < 3 active", function()
        tarot.reset()
        harness.assert_true(tarot.shouldOffer(1), "room 1 offers")
        harness.assert_true(tarot.shouldOffer(2), "room 2 offers")
        harness.assert_false(tarot.shouldOffer(3), "room 3 (elite) skips")
        harness.assert_true(tarot.shouldOffer(4), "room 4 offers")
        harness.assert_false(tarot.shouldOffer(5), "room 5 (boss) skips")
        world.state.stageCards = {"mercury", "reaper", "midas_pouch"}
        harness.assert_false(tarot.shouldOffer(1), "full deck skips")
        tarot.reset()
    end)

    harness.it("open sets TAROT state; choose applies card and routes to TRANSITION", function()
        tarot.reset()
        tarot.open(2)
        harness.assert_true(tarot.isOpen(), "draft open")
        harness.assert_equal(constants.GAME_STATE_TAROT, world.state.gameState, "TAROT state")
        local id = tarot.choose(1)
        harness.assert_not_nil(id, "choose returns id")
        harness.assert_true(tarot.has(id), "card equipped: " .. tostring(id))
        harness.assert_equal(1, tarot.count(), "one active")
        harness.assert_false(tarot.isOpen(), "draft closed")
        harness.assert_equal(constants.GAME_STATE_TRANSITION, world.state.gameState, "routes to TRANSITION")
        harness.assert_equal("siguienteSala", world.state.transitionTarget, "next room target")
        harness.assert_equal(1, world.state.transitionPhase, "fade-out phase")
        tarot.reset()
    end)

    harness.it("choose caps at MAX_STAGE_CARDS and ignores bad index", function()
        tarot.reset()
        world.state.stageCards = {"mercury", "reaper", "midas_pouch"}
        tarot.open(1)
        local before = tarot.count()
        tarot.choose(1)
        harness.assert_equal(before, tarot.count(), "cap respected")
        tarot.reset()
        tarot.open(1)
        harness.assert_nil(tarot.choose(9), "bad index returns nil")
        harness.assert_true(tarot.isOpen(), "draft stays open on bad index")
        tarot.reset()
    end)

    harness.it("keypressed maps 1/2/3 and mousepressed misses safely headless", function()
        tarot.reset()
        tarot.open(4)
        local id = tarot.keypressed("2")
        harness.assert_not_nil(id, "key 2 chooses")
        harness.assert_equal(1, tarot.count(), "equipped via key")
        tarot.reset()
        tarot.open(1)
        harness.assert_nil(tarot.mousepressed(-9999, -9999), "off-card click misses")
        harness.assert_nil(tarot.keypressed("x"), "other keys ignored")
        harness.assert_true(tarot.isOpen(), "draft still open")
        tarot.reset()
    end)
end)

harness.describe("Scope 23 - Tarot hook helpers (B1 movement/combo)", function()
    harness.it("speedFactor 0.85 with mercury, 1.0 without", function()
        tarot.reset()
        harness.assert_equal(1.0, tarot.speedFactor(), "no card = 1.0")
        world.state.stageCards = {"mercury"}
        harness.assert_equal(0.85, tarot.speedFactor(), "mercury = 0.85")
        tarot.reset()
    end)

    harness.it("calcSpeed is faster (lower) with mercury equipped", function()
        local playerMod = require("systems.player")
        tarot.reset()
        local base = playerMod.calcSpeed(0.13, 0)
        world.state.stageCards = {"mercury"}
        local fast = playerMod.calcSpeed(0.13, 0)
        harness.assert_true(fast < base, "mercury speeds up")
        tarot.reset()
    end)

    harness.it("comboWindow 12.0 with eagle_eye, base otherwise", function()
        tarot.reset()
        harness.assert_equal(constants.COMBO_WINDOW, tarot.comboWindow(), "base window")
        world.state.stageCards = {"eagle_eye"}
        harness.assert_equal(12.0, tarot.comboWindow(), "eagle eye window")
        tarot.reset()
    end)

    harness.it("comboMult doubles with mercury", function()
        tarot.reset()
        harness.assert_equal(2.5, tarot.comboMult(2.5), "passthrough")
        world.state.stageCards = {"mercury"}
        harness.assert_equal(5.0, tarot.comboMult(2.5), "doubled")
        tarot.reset()
    end)

    harness.it("ironSpineProtects covers last 3 segments only", function()
        tarot.reset()
        harness.assert_false(tarot.ironSpineProtects(6, 6), "no card = false")
        world.state.stageCards = {"iron_spine"}
        harness.assert_false(tarot.ironSpineProtects(3, 6), "seg 3 of 6 unprotected")
        harness.assert_true(tarot.ironSpineProtects(4, 6), "seg 4 of 6 protected")
        harness.assert_true(tarot.ironSpineProtects(6, 6), "tail protected")
        tarot.reset()
    end)

    harness.it("iron spine kills chaser biting the tail, death without it", function()
        local enemiesMod = require("entities.enemies")
        local collisions = require("entities.snake.collisions")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        enemiesMod.init()
        local function tailBiteSetup()
            local e = enemiesMod.spawnAt("chaser", 10, 5)
            local s = {
                body = {{x = 5, y = 5}, {x = 6, y = 5}, {x = 7, y = 5},
                        {x = 8, y = 5}, {x = 9, y = 5}, {x = 10, y = 5}},
            }
            return e, s
        end
        tarot.reset()
        local e1, s1 = tailBiteSetup()
        local col1 = collisions.checkEnemyCollisions(s1, enemiesMod.list)
        harness.assert_equal("death", col1.type, "tail bite kills without card")
        harness.assert_true(e1.alive, "chaser survives")
        enemiesMod.init()
        world.state.stageCards = {"iron_spine"}
        local e2, s2 = tailBiteSetup()
        local col2 = collisions.checkEnemyCollisions(s2, enemiesMod.list)
        harness.assert_equal("iron_spine_block", col2.type, "iron spine blocks")
        harness.assert_false(e2.alive, "chaser destroyed")
        tarot.reset()
        enemiesMod.init()
    end)

    harness.it("astral mirror grants 1 wall wrap per room on no-wrap biome", function()
        local worldMod = require("world.world")
        local snakeMod = require("entities.snake")
        local shop = require("systems.shop")
        local enemiesMod = require("entities.enemies")
        world.reset()
        shop.reset(false)
        enemiesMod.init()
        worldMod.setEtapa(5) -- vacio: wallWrap = false
        world.set("controlMode", "tactical")
        local function wallSnake()
            local s = snakeMod.reset()
            s.body = {{x = 0, y = 5}}
            s.dirX, s.dirY = -1, 0
            s.inputQueue = {{x = -1, y = 0}}
            return s
        end
        tarot.reset()
        local s1 = wallSnake()
        local vivo1 = snakeMod.mover(s1, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_false(vivo1, "wall kills without card")
        world.state.stageCards = {"astral_mirror"}
        world.state.astralWrapUsed = false
        local s2 = wallSnake()
        local vivo2 = snakeMod.mover(s2, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_true(vivo2, "mirror wrap saves once")
        harness.assert_equal(31, s2.body[1].x, "wrapped to far edge")
        harness.assert_true(world.state.astralWrapUsed, "wrap charge spent")
        local s3 = wallSnake()
        s3.body = {{x = 0, y = 6}}
        local vivo3 = snakeMod.mover(s3, {x = 20, y = 20}, 32, 18, nil, 0, nil)
        harness.assert_false(vivo3, "second wall kills (charge spent)")
        tarot.reset()
        worldMod.init()
        world.set("controlMode", "classic")
    end)
end)

harness.describe("Scope 23 - Tarot hook helpers (B2 food/buffs)", function()
    harness.it("fire/freeze durations upgrade with dragon_blood/absolute_zero", function()
        tarot.reset()
        harness.assert_equal(3.5, tarot.fireBuffDuration(), "base fire")
        harness.assert_equal(2.5, tarot.freezeDuration(), "base freeze")
        harness.assert_equal(0, tarot.constrictReach(), "base reach")
        harness.assert_false(tarot.isShatterFrozen(), "no shatter unfrozen")
        world.state.stageCards = {"dragon_blood", "absolute_zero", "magic_circle"}
        harness.assert_equal(6.0, tarot.fireBuffDuration(), "dragon fire")
        harness.assert_equal(4.0, tarot.freezeDuration(), "zero freeze")
        harness.assert_equal(1, tarot.constrictReach(), "circle reach")
        world.state.enemyFreezeTimer = 3.0
        harness.assert_true(tarot.isShatterFrozen(), "shatter while frozen")
        world.state.enemyFreezeTimer = 0
        harness.assert_false(tarot.isShatterFrozen(), "no shatter expired")
        tarot.reset()
    end)

    harness.it("alchemical_digestion converts rolled normal into gold (25%)", function()
        local foodMod = require("entities.food")
        local realRandom = love.math.random
        local function stubRandom(seq)
            local i = 0
            love.math.random = function()
                i = i + 1
                return seq[i] or seq[#seq]
            end
        end
        local body = {{x = 1, y = 1}, {x = 1, y = 2}, {x = 1, y = 3}}
        tarot.reset()
        stubRandom({0.99})
        foodMod.generar(body, 32, 18, nil, nil, 5, 5)
        harness.assert_equal(constants.FOOD_NORMAL, foodMod.tipo, "normal without card")
        world.state.stageCards = {"alchemical_digestion"}
        stubRandom({0.99, 0.10})
        foodMod.generar(body, 32, 18, nil, nil, 5, 5)
        harness.assert_equal(constants.FOOD_GOLD, foodMod.tipo, "gold with card + lucky roll")
        stubRandom({0.99, 0.90})
        foodMod.generar(body, 32, 18, nil, nil, 5, 5)
        harness.assert_equal(constants.FOOD_NORMAL, foodMod.tipo, "normal with card + unlucky roll")
        love.math.random = realRandom
        tarot.reset()
    end)

    harness.it("frozen enemies shatter on head contact with absolute_zero", function()
        local enemiesMod = require("entities.enemies")
        local collisions = require("entities.snake.collisions")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        enemiesMod.init()
        tarot.reset()
        world.state.enemyFreezeTimer = 3.0
        local e1 = enemiesMod.spawnAt("chaser", 5, 5)
        local col1 = collisions.checkEnemyCollisions({body = {{x = 5, y = 5}}}, enemiesMod.list)
        harness.assert_equal("death", col1.type, "frozen still lethal without card")
        enemiesMod.init()
        world.state.stageCards = {"absolute_zero"}
        world.state.enemyFreezeTimer = 3.0
        local e2 = enemiesMod.spawnAt("chaser", 5, 5)
        local col2 = collisions.checkEnemyCollisions({body = {{x = 5, y = 5}}}, enemiesMod.list)
        harness.assert_equal("frozen_shatter", col2.type, "shatters with card")
        harness.assert_false(e2.alive, "enemy destroyed")
        harness.assert_not_nil(col2.result, "kill result attached")
        tarot.reset()
        world.state.enemyFreezeTimer = 0
        enemiesMod.init()
    end)

    harness.it("magic_circle attracts adjacent enemies into constrictor kills", function()
        local enemiesMod = require("entities.enemies")
        local collisions = require("entities.snake.collisions")
        local shop = require("systems.shop")
        world.reset()
        shop.reset(false)
        enemiesMod.init()
        local function lineSnake()
            local body = {}
            for x = 5, 12 do body[#body + 1] = {x = x, y = 5} end
            return {body = body}
        end
        tarot.reset()
        enemiesMod.spawnAt("chaser", 5, 6)
        local k1 = collisions.checkConstrictorLoop(lineSnake(), enemiesMod.list)
        harness.assert_nil(k1, "adjacent not killed without card")
        enemiesMod.init()
        world.state.stageCards = {"magic_circle"}
        enemiesMod.spawnAt("chaser", 5, 6)
        local k2 = collisions.checkConstrictorLoop(lineSnake(), enemiesMod.list)
        harness.assert_not_nil(k2, "adjacent killed with card")
        harness.assert_equal(1, #k2, "one attracted kill")
        tarot.reset()
        enemiesMod.init()
    end)

    harness.it("reaper extendBuffs adds +0.5s only with card equipped", function()
        tarot.reset()
        world.state.activeTimers = {{remaining = 2.0}, {_handle = {delay = 3.0, accum = 1.0}}}
        harness.assert_equal(0, tarot.extendBuffs(0.5), "no-op without card")
        harness.assert_equal(2.0, world.state.activeTimers[1].remaining, "legacy untouched")
        world.state.stageCards = {"reaper"}
        harness.assert_equal(2, tarot.extendBuffs(0.5), "two buffs extended")
        harness.assert_equal(2.5, world.state.activeTimers[1].remaining, "legacy extended")
        harness.assert_equal(3.5, world.state.activeTimers[2]._handle.delay, "pooled extended")
        world.state.activeTimers = {}
        tarot.reset()
    end)

    harness.it("iron_heart grants a free shield on short-body room clear", function()
        local worldMod = require("world.world")
        local shop = require("systems.shop")
        local snakeMod = require("entities.snake")
        local transition = require("systems.gamestates.transition")
        world.reset()
        shop.reset(false)
        worldMod.init()
        tarot.reset()
        world.state.stageCards = {"iron_heart"}
        world.state.player = snakeMod.reset()
        world.state.player.body = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
        world.state.transitionTarget = "siguienteSala"
        world.state.transitionPhase = 1
        world.state.fadeAlpha = 1
        transition.update(0.016)
        harness.assert_true(world.get("shop.shieldActive", false), "shield granted")
        harness.assert_equal("hold", world.state.transitionPhase, "room advanced")
        tarot.reset()
        worldMod.init()
    end)
end)

harness.describe("Scope 23 - Tarot stage lifecycle (avanzarEtapa)", function()
    harness.it("avanzarEtapa clears the stage deck", function()
        local worldMod = require("world.world")
        tarot.reset()
        world.state.stageCards = {"mercury", "eagle_eye"}
        worldMod.avanzarEtapa()
        harness.assert_equal(0, tarot.count(), "deck cleared on new stage")
        tarot.reset()
        worldMod.init()
    end)
end)

-- tests/test_scope_23_tarot.lua — Cartas del Destino comprables en tienda (GDD §14, TDD §10.13)
-- Suite consola-only: catalogo, compra, ciclo de vida por etapa y hooks de gameplay. Sin love.graphics.
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

    harness.it("reset clears stageCards", function()
        tarot.reset()
        harness.assert_equal(0, tarot.count(), "empty after reset")
        world.state.stageCards = {"mercury"}
        tarot.reset()
        harness.assert_equal(0, tarot.count(), "clears equipped")
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

harness.describe("Scope 23 - Tarot art loader (PNG assets/tarot)", function()
    local tarotArt = require("systems.tarotArt")

    harness.it("maps all 12 catalog ids to .png paths", function()
        local n = 0
        for _, d in ipairs(tarot.TAROT_DEFS) do
            local p = tarotArt.PATHS[d.id]
            harness.assert_not_nil(p, "missing art path: " .. tostring(d.id))
            harness.assert_true(p:sub(-4) == ".png", "path must end .png: " .. tostring(p))
            n = n + 1
        end
        harness.assert_equal(12, n, "must map 12 cards")
    end)

    harness.it("get() lazy-loads and caches the same handle per id", function()
        local a = tarotArt.get("mercury")
        harness.assert_not_nil(a, "mocked backend must return an image")
        harness.assert_true(tarotArt.get("mercury") == a, "second call must hit cache")
    end)

    harness.it("draw() scales to the requested size without crashing", function()
        harness.assert_true(tarotArt.draw("reaper", 10, 20, 80), "draw must succeed")
    end)

    harness.it("unknown id returns nil/false without crashing", function()
        harness.assert_nil(tarotArt.get("no_existe"), "unknown id must be nil")
        harness.assert_true(tarotArt.draw("no_existe", 0, 0, 80) == false, "draw must fail soft")
    end)
end)

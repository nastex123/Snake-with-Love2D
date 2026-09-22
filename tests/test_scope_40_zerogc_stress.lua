-- tests/test_scope_40_zerogc_stress.lua — Estres Zero-GC 60s con boss + mutadores (R-5)
-- Dos niveles: A) rutas pooled + draws (estricto); B) enemies.update full (guardia regresion).
local harness = require("tests.test_harness")
local constants = require("constants")
local enemiesMod = require("entities.enemies")
local registry = require("entities.enemyAttackRegistry")
local snakeMod = require("entities.snake")

-- Setup aislado: suites previas degradan keys de constants en la misma VM
-- (p. ej. love.load real en suites de render). Se restauran desde disco.
local simTime = 100.0
love.timer.getTime = function() return simTime end
do
    local found = package.searchpath and package.searchpath("core.config", package.path)
    local fresh = nil
    if found then
        local okL, chunk = pcall(loadfile, found)
        if okL and type(chunk) == "function" then
            local ok2, res = pcall(chunk)
            if ok2 and type(res) == "table" then fresh = res end
        end
    end
    if fresh then
        local n = 0
        for k, v in pairs(fresh) do
            if constants[k] == nil then constants[k] = v; n = n + 1 end
        end
        print(string.format("--- SCOPE40 config restauradas: %d keys (%s) ---", n, tostring(found)))
    else
        print("--- SCOPE40 config restore FALLIDO: " .. tostring(found) .. " ---")
    end
end

local function buildSnake()
    local s = {
        body = {}, prevBody = {}, dirX = 1, dirY = 0,
        flashTimer = 0, trail = {}, fireTrail = {}, decoys = {},
    }
    for i = 1, 24 do
        s.body[i] = {x = 5 + i, y = 5}
        s.prevBody[i] = {x = 5 + i, y = 5}
    end
    return s
end

local function buildArena()
    enemiesMod.init()
    enemiesMod.spawnAt("chaser", 8, 8, {moveInterval = 0.3})
    enemiesMod.spawnAt("chaser", 20, 10, {moveInterval = 0.3})
    enemiesMod.spawnAt("patroller", 12, 12, {moveInterval = 0.35, dirX = 1, dirY = 0})
    enemiesMod.spawnAt("spawner", 25, 15)
    enemiesMod.spawnBoss(3, 40, 28, 12, 11)
    for i = 1, 8 do enemiesMod.addProjectile(10 + i, 10, 1, 0, 5.0, 1) end
    for i = 1, 4 do enemiesMod.addTelegraph(10 + i, 12, 1.0, "projectile_spread") end
    enemiesMod.addRadialPulse(20, 14, 6, 3, 1, 4.0)
    enemiesMod.addLaser(5, 5, 30, 20, 4.0, 1)
end

local function stressDelta(ticks, fn)
    for _ = 1, 300 do fn() end
    collectgarbage("collect")
    local before = collectgarbage("count")
    for _ = 1, ticks do fn() end
    collectgarbage("collect")
    return collectgarbage("count") - before
end

harness.describe("ZeroGC stress 60s: pooled + draws sin asignacion por frame", function()
    harness.it("registry + draws estables en 3600 ticks", function()
        local s = buildSnake()
        buildArena()
        local t = 0
        local d = stressDelta(3600, function()
            t = t + 1
            registry.updateAttackObjects(1 / 60, 40, 28, false)
            registry.updateTelegraphs(1 / 60, false)
            snakeMod.draw(s, t * 1 / 60)
            enemiesMod.draw(s.body[1])
        end)
        print(string.format("--- ZEROGC-STRESS-A pooled+draws 3600 ticks: delta %.1f KB ---", d))
        harness.assert_true(d < 128, "Delta KB < 128 en 3600 ticks, got " .. tostring(d))
        registry.clearAll()
    end)
end)

harness.describe("ZeroGC stress 60s: enemies.update full como guardia regresion", function()
    harness.it("full update acotado en 3600 ticks con boss vivo", function()
        local s = buildSnake()
        buildArena()
        local d = stressDelta(3600, function()
            simTime = simTime + 1 / 60
            enemiesMod.update(1 / 60, s.body, 40, 28, nil, 3, {countMult = 1.4}, nil)
        end)
        print(string.format("--- ZEROGC-STRESS-B full update 3600 ticks: delta %.1f KB ---", d))
        harness.assert_true(d < 2048, "Delta KB < 2048 en 3600 ticks, got " .. tostring(d))
        registry.clearAll()
    end)
end)

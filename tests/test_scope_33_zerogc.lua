local harness = require("tests.test_harness")
local snakeMod = require("entities.snake")
harness.describe("ZeroGC: draw serpiente sin asignacion por frame", function()
    harness.it("reutiliza buffers en 3600 frames", function()
        local s = {
            body = {},
            prevBody = {},
            dirX = 1, dirY = 0,
            flashTimer = 0,
            trail = {},
            fireTrail = {},
            decoys = {},
        }
        for i = 1, 24 do
            s.body[i] = {x = 5 + i, y = 5}
            s.prevBody[i] = {x = 5 + i, y = 5}
        end
        collectgarbage("collect")
        local before = collectgarbage("count")
        for f = 1, 3600 do snakeMod.draw(s, 1.0) end
        collectgarbage("collect")
        local after = collectgarbage("count")
        local delta = after - before
        harness.assert_true(delta < 64, "Delta KB < 64 en 3600 draws, got " .. tostring(delta))
    end)
end)

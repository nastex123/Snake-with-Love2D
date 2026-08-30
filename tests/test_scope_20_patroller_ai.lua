-- tests/test_scope_20_patroller_ai.lua
-- Suite de pruebas unitarias para la IA Táctica del Patroller y Guillotine Slice

local harness = require("tests.test_harness")
local constants = require("constants")
local patrollerAI = require("entities.patrollerAI")
local snake = require("entities.snake")

harness.describe("Patroller Tactical AI - Mode Initialization", function()
    harness.it("assigns corridor_sweep mode in corridor rooms", function()
        local e = {x = 10, y = 10, dirX = 1, dirY = 0}
        patrollerAI.init(e, "corridor", 40, 28)
        harness.assert_equal("corridor_sweep", e.patrolMode)
        harness.assert_equal("patrol", e.aiState)
    end)

    harness.it("assigns perimeter_orbit mode in arena and boss rooms", function()
        local e = {x = 15, y = 15}
        patrollerAI.init(e, "arena", 40, 28)
        harness.assert_equal("perimeter_orbit", e.patrolMode)
        harness.assert_not_nil(e.orbitDir)
    end)

    harness.it("assigns radar_sentry mode in treasure rooms", function()
        local e = {x = 5, y = 5}
        patrollerAI.init(e, "treasure", 40, 28)
        harness.assert_equal("radar_sentry", e.patrolMode)
    end)
end)

harness.describe("Patroller Tactical AI - 90-Degree Turn Resolution", function()
    harness.it("turns 90 degrees when front is blocked but side is open", function()
        local e = {x = 10, y = 0, dirX = 0, dirY = -1, patrolMode = "corridor_sweep"} -- moviéndose hacia arriba (bloqueada por pared y=0)
        local turnX, turnY = patrollerAI.resolveTurn(e, 40, 28, nil, nil, {})
        -- El frente (0, -1) está bloqueado (y < 0). Debe girar a izquierda (-1, 0) o derecha (1, 0)
        harness.assert_true(turnX ~= 0 and turnY == 0, "Must turn horizontally at top border")
    end)

    harness.it("rebounds 180 degrees only if both sides are also blocked", function()
        local e = {x = 0, y = 0, dirX = -1, dirY = 0, patrolMode = "corridor_sweep"}
        -- En (0,0), el frente (-1,0) y un lado (0,-1) están fuera de grilla. Bloqueamos el otro lado (0,1)
        local obstacles = { pos = { {x = 0, y = 1, type = "wall"} } }
        local turnX, turnY = patrollerAI.resolveTurn(e, 40, 28, obstacles, nil, {})
        -- Al estar frente y ambos lados bloqueados, debe retroceder hacia atrás (1, 0)
        harness.assert_equal(1, turnX)
        harness.assert_equal(0, turnY)
    end)
end)

harness.describe("Patroller Tactical AI - Line of Sight & Dash", function()
    harness.it("detects snake head in direct line of sight within range", function()
        local e = {x = 10, y = 10, dirX = 1, dirY = 0}
        local head = {x = 14, y = 10}
        local hasLOS = patrollerAI.checkLineOfSight(e, head, nil, 40, 28)
        harness.assert_true(hasLOS)
    end)

    harness.it("discards line of sight if an obstacle is in between", function()
        local e = {x = 10, y = 10, dirX = 1, dirY = 0}
        local head = {x = 14, y = 10}
        local obstacles = { pos = { {x = 12, y = 10, type = "wall"} } }
        local hasLOS = patrollerAI.checkLineOfSight(e, head, obstacles, 40, 28)
        harness.assert_false(hasLOS)
    end)

    harness.it("discards line of sight if beyond maximum range", function()
        local e = {x = 5, y = 10, dirX = 1, dirY = 0}
        local head = {x = 15, y = 10} -- distancia 10 > PATROLLER_LOS_RANGE (6)
        local hasLOS = patrollerAI.checkLineOfSight(e, head, nil, 40, 28)
        harness.assert_false(hasLOS)
    end)

    harness.it("transitions from patrol to alert to dash", function()
        local e = {
            x = 10, y = 10, dirX = 1, dirY = 0,
            aiState = "patrol", moveTimer = 0, moveInterval = 0.2
        }
        local head = {x = 13, y = 10}
        local ctx = {
            anchoGrilla = 40, altoGrilla = 28,
            snake = {body = {head}}, dt = 0.05
        }

        -- En paso 1, detecta LOS y pasa a 'alert'
        patrollerAI.step(e, ctx)
        harness.assert_equal("alert", e.aiState)

        -- Simular avance del temporizador de alert (0.25s)
        e.alertTimer = 0.01
        patrollerAI.step(e, ctx)
        harness.assert_equal("dash", e.aiState)
        harness.assert_equal(constants.PATROLLER_DASH_TILES or 3, e.dashTilesLeft)
    end)
end)

harness.describe("Patroller Combat - Guillotine Slice Mechanic", function()
    harness.it("slices tail from segment 4 onwards when snake has >= 5 segments", function()
        local s = snake.reset()
        -- Crear serpiente de 7 segmentos: [(5,5), (4,5), (3,5), (2,5), (1,5), (0,5), (0,6)]
        s.body = {
            {x = 10, y = 10}, -- 1 Cabeza
            {x = 9,  y = 10}, -- 2 Cuello
            {x = 8,  y = 10}, -- 3 Cuello
            {x = 7,  y = 10}, -- 4 Cuerpo (Impacto aqui!)
            {x = 6,  y = 10}, -- 5 Cola
            {x = 5,  y = 10}, -- 6 Cola
            {x = 4,  y = 10}  -- 7 Cola
        }

        -- Patroller impacta en segmento 4 (x=7, y=10)
        local enemiesList = {
            {alive = true, type = "patroller", x = 7, y = 10}
        }

        local slice = snake.checkPatrollerSlice(s, enemiesList)
        harness.assert_not_nil(slice)
        harness.assert_equal(4, slice.fromIndex)
        harness.assert_equal(4, slice.removedCount)
        harness.assert_equal(3, #s.body, "Snake must have only 3 remaining segments")
        harness.assert_true(s.sliceGraceTimer > 0, "Grace invulnerability timer must be set")
    end)

    harness.it("does not slice if snake has less than 5 segments", function()
        local s = snake.reset()
        s.body = {
            {x = 10, y = 10},
            {x = 9,  y = 10},
            {x = 8,  y = 10},
            {x = 7,  y = 10} -- solo 4 segmentos
        }

        local enemiesList = {
            {alive = true, type = "patroller", x = 7, y = 10}
        }

        local slice = snake.checkPatrollerSlice(s, enemiesList)
        harness.assert_nil(slice, "Must not slice when length < 5 (it is lethal instead)")
        harness.assert_equal(4, #s.body)
    end)
end)

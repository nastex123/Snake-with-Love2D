-- entities/patrollerAI.lua — IA tactica del Patroller (Interceptor Delta)
-- 4 Modos contextuales: corridor_sweep, perimeter_orbit, diagonal_bounce, radar_sentry.
-- Resolucion de esquinas a 90 grados con anti-deadlock de 180 grados.
-- Line-of-Sight Dash: raycast ortogonal, alerta fotonica y aceleracion turbo.
local patrollerAI = {}
local constants = require("constants")

local TAU = math.pi * 2

local function isBlocked(cx, cy, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList, selfEnemy)
    if cx < 0 or cx >= anchoGrilla or cy < 0 or cy >= altoGrilla then
        return true
    end
    if obstaclesMod then
        local obs = obstaclesMod.pos or obstaclesMod
        for _, o in ipairs(obs) do
            if o.x == cx and o.y == cy then return true end
        end
    end
    if boss and boss.alive and boss.x == cx and boss.y == cy then
        return true
    end
    for _, oe in ipairs(enemiesList or {}) do
        if oe ~= selfEnemy and oe.alive and oe.x == cx and oe.y == cy then
            return true
        end
    end
    return false
end

function patrollerAI.init(e, roomType, anchoGrilla, altoGrilla)
    e.aiState = "patrol" -- "patrol", "alert", "dash", "cooldown"
    e.alertTimer = 0
    e.dashTilesLeft = 0
    e.cooldownTimer = 0
    e.sentryWaitTimer = 0
    e.sentryStepCount = 0

    -- Asignacion de modo contextual por sala
    if roomType == "corridor" or roomType == "choke" then
        e.patrolMode = "corridor_sweep"
    elseif roomType == "arena" or roomType == "hub" or roomType == "boss" then
        e.patrolMode = "perimeter_orbit"
        e.orbitDir = (love and love.math and love.math.random() < 0.5) and 1 or -1
    elseif roomType == "treasure" or roomType == "spawner" then
        e.patrolMode = "radar_sentry"
    else
        e.patrolMode = "diagonal_bounce"
    end

    if not e.dirX or not e.dirY or (e.dirX == 0 and e.dirY == 0) then
        e.dirX = 1
        e.dirY = 0
    end
    e.visRot = math.atan2(e.dirY, e.dirX)
end

function patrollerAI.checkLineOfSight(e, snakeHead, obstaclesMod, anchoGrilla, altoGrilla)
    if not snakeHead or not e.dirX or not e.dirY then return false end
    if e.dirX == 0 and e.dirY == 0 then return false end

    -- Solo detectar si la serpiente esta en el vector directo de avance
    local dx = snakeHead.x - e.x
    local dy = snakeHead.y - e.y

    local maxRange = constants.PATROLLER_LOS_RANGE or 6

    if e.dirX ~= 0 and dy == 0 then
        local dist = dx * e.dirX
        if dist > 0 and dist <= maxRange then
            -- Raycast para verificar muros intermedios
            local step = e.dirX
            local currX = e.x + step
            while currX ~= snakeHead.x do
                if obstaclesMod then
                    local obs = obstaclesMod.pos or obstaclesMod
                    for _, o in ipairs(obs) do
                        if o.x == currX and o.y == e.y and (o.type == "wall" or o.type == "stone" or not o.type) then
                            return false
                        end
                    end
                end
                currX = currX + step
            end
            return true
        end
    elseif e.dirY ~= 0 and dx == 0 then
        local dist = dy * e.dirY
        if dist > 0 and dist <= maxRange then
            local step = e.dirY
            local currY = e.y + step
            while currY ~= snakeHead.y do
                if obstaclesMod then
                    local obs = obstaclesMod.pos or obstaclesMod
                    for _, o in ipairs(obs) do
                        if o.x == e.x and o.y == currY and (o.type == "wall" or o.type == "stone" or not o.type) then
                            return false
                        end
                    end
                end
                currY = currY + step
            end
            return true
        end
    end
    return false
end

function patrollerAI.resolveTurn(e, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList)
    local dx, dy = e.dirX, e.dirY
    -- Direcciones ortogonales a 90 grados: izquierda (-dy, dx) y derecha (dy, -dx)
    local leftX, leftY = -dy, dx
    local rightX, rightY = dy, -dx

    local leftBlocked = isBlocked(e.x + leftX, e.y + leftY, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList, e)
    local rightBlocked = isBlocked(e.x + rightX, e.y + rightY, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList, e)

    -- Prioridad en modo perimeter_orbit segun sentido de orbita
    if e.patrolMode == "perimeter_orbit" then
        if e.orbitDir == 1 then
            if not rightBlocked then return rightX, rightY end
            if not leftBlocked then return leftX, leftY end
        else
            if not leftBlocked then return leftX, leftY end
            if not rightBlocked then return rightX, rightY end
        end
    else
        -- En pasillos / rebote: elegir lado libre preferente o pseudoaleatorio
        if not leftBlocked and not rightBlocked then
            local chooseLeft = (love and love.math and love.math.random() < 0.5)
            if chooseLeft then return leftX, leftY else return rightX, rightY end
        elseif not leftBlocked then
            return leftX, leftY
        elseif not rightBlocked then
            return rightX, rightY
        end
    end

    -- Si ambos lados a 90 grados estan bloqueados: rebote retroceso a 180 grados
    local backX, backY = -dx, -dy
    if not isBlocked(e.x + backX, e.y + backY, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList, e) then
        return backX, backY
    end

    return 0, 0
end

function patrollerAI.step(e, ctx)
    local anchoGrilla = ctx.anchoGrilla or 40
    local altoGrilla = ctx.altoGrilla or 28
    local snake = ctx.snake
    local snakeHead = snake and snake.body and snake.body[1]
    local snakeBody = snake and snake.body
    local obstaclesMod = ctx.obstacles
    local boss = ctx.boss
    local enemiesList = ctx.enemiesList
    local dt = ctx.dt or (1/60)

    if not e.patrolMode then
        patrollerAI.init(e, ctx.roomType or "corridor", anchoGrilla, altoGrilla)
    end

    -- Actualizacion de cooldowns temporales continuos
    if e.cooldownTimer and e.cooldownTimer > 0 then
        e.cooldownTimer = e.cooldownTimer - dt
        if e.cooldownTimer <= 0 then
            e.cooldownTimer = 0
            if e.aiState == "cooldown" then
                e.aiState = "patrol"
            end
        end
    end

    -- 1. Estado ALERT (Telegrafiado de intercepcion, se frena 0.25s)
    if e.aiState == "alert" then
        e.alertTimer = (e.alertTimer or 0) - dt
        if e.alertTimer <= 0 then
            e.aiState = "dash"
            e.dashTilesLeft = constants.PATROLLER_DASH_TILES or 3
            e.moveTimer = 0
        end
        return
    end

    -- 2. Verificacion pasiva de Line of Sight durante PATROL (solo si cooldown listo)
    if e.aiState == "patrol" and (not e.cooldownTimer or e.cooldownTimer <= 0) then
        if patrollerAI.checkLineOfSight(e, snakeHead, obstaclesMod, anchoGrilla, altoGrilla) then
            e.aiState = "alert"
            e.alertTimer = constants.PATROLLER_ALERT_TIME or 0.25
            return
        end
    end

    -- 3. Cadencia de paso segun estado
    local baseInterval = e.moveInterval or constants.ENEMY_PATROLLER_SPEED or 0.35
    local currentInterval = baseInterval
    if e.aiState == "dash" then
        currentInterval = baseInterval / (constants.PATROLLER_DASH_SPEED_MULT or 1.8)
    end

    if e.moveTimer < currentInterval then
        return
    end
    e.moveTimer = 0

    -- 4. Radar Sentry: pausa de escaneo cada 4 casillas
    if e.patrolMode == "radar_sentry" and e.aiState == "patrol" then
        if e.sentryWaitTimer and e.sentryWaitTimer > 0 then
            e.sentryWaitTimer = e.sentryWaitTimer - currentInterval
            return
        end
    end

    -- 5. Calculo de siguiente celda
    local nx = e.x + e.dirX
    local ny = e.y + e.dirY

    if isBlocked(nx, ny, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList, e) then
        -- Bloqueo frontal: resolver giro a 90 grados o rebote 180 grados
        local turnX, turnY = patrollerAI.resolveTurn(e, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList)
        e.dirX = turnX
        e.dirY = turnY

        if turnX ~= 0 or turnY ~= 0 then
            e.x = e.x + turnX
            e.y = e.y + turnY
        end

        -- Si estaba en dash y choca: termina la embestida e inicia cooldown
        if e.aiState == "dash" then
            e.aiState = "cooldown"
            e.cooldownTimer = constants.PATROLLER_DASH_COOLDOWN or 3.0
            e.dashTilesLeft = 0
        end
    else
        e.x = nx
        e.y = ny

        if e.aiState == "dash" then
            e.dashTilesLeft = (e.dashTilesLeft or 1) - 1
            if e.dashTilesLeft <= 0 then
                e.aiState = "cooldown"
                e.cooldownTimer = constants.PATROLLER_DASH_COOLDOWN or 3.0
            end
        elseif e.patrolMode == "radar_sentry" then
            e.sentryStepCount = (e.sentryStepCount or 0) + 1
            if e.sentryStepCount >= 4 then
                e.sentryStepCount = 0
                e.sentryWaitTimer = 0.5
                -- Gira 90 grados para cubrir otro cuadrante
                local turnX, turnY = patrollerAI.resolveTurn(e, anchoGrilla, altoGrilla, obstaclesMod, boss, enemiesList)
                if turnX ~= 0 or turnY ~= 0 then
                    e.dirX = turnX
                    e.dirY = turnY
                end
            end
        end
    end

    if e.dirX ~= 0 or e.dirY ~= 0 then
        e.visRot = math.atan2(e.dirY, e.dirX)
    end
end

return patrollerAI

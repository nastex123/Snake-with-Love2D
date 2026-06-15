local world = {}
local constants = require("constants")

world.etapa = 1
world.sala = 1
world.puntajeSala = 0
world.objetivoSala = 50

local stageModifiers = {
    [1] = { spawnRate = 1.0, enemySpeed = 1.0, chaserWeight = 0.40, patrollerWeight = 0.35, spawnerWeight = 0.25, targetMult = 1.0, bossVida = 3 },
    [2] = { spawnRate = 1.2, enemySpeed = 1.15, chaserWeight = 0.50, patrollerWeight = 0.30, spawnerWeight = 0.20, targetMult = 1.3, bossVida = 4 },
    [3] = { spawnRate = 1.4, enemySpeed = 1.3, chaserWeight = 0.35, patrollerWeight = 0.30, spawnerWeight = 0.35, targetMult = 1.6, bossVida = 5 },
    [4] = { spawnRate = 1.6, enemySpeed = 1.5, chaserWeight = 0.50, patrollerWeight = 0.20, spawnerWeight = 0.30, targetMult = 2.0, bossVida = 6 },
    [5] = { spawnRate = 2.0, enemySpeed = 1.8, chaserWeight = 0.40, patrollerWeight = 0.25, spawnerWeight = 0.35, targetMult = 2.5, bossVida = 8 },
}

function world.calcularObjetivo()
    local base = 50 + world.sala * 30
    local mult = stageModifiers[world.etapa].targetMult
    return math.floor(base * mult)
end

function world.init()
    world.etapa = 1
    world.sala = 1
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
    mundoCompletado = false
end

function world.getModifier()
    return stageModifiers[world.etapa] or stageModifiers[5]
end

function world.esJefe()
    return world.sala == 5
end

function world.avanzarSala()
    world.sala = world.sala + 1
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
end

function world.avanzarEtapa()
    world.etapa = world.etapa + 1
    world.sala = 1
    world.puntajeSala = 0
    world.objetivoSala = world.calcularObjetivo()
end

function world.etapaCompletada()
    return world.etapa > 5
end

return world

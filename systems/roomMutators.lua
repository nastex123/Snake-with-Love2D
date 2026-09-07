-- systems/roomMutators.lua — Room Mutators, Curses & Blessings (GDD §19, TDD §10.27)
-- Mazo data-driven de 10 mutadores por sala: roll en iniciarSala, max 1 por sala.
-- Estado en World.state: roomMutator (id activo), roomMutatorData (runtime por mutador).
local mutators = {}
local constants = require("constants")
local world = require("core.world")

-- 61-70: id estable usado por hasMutator() en los hooks de gameplay.
mutators.MUTATOR_DEFS = {
    {id = "zero_gravity",    name = "61. Gravedad Cero",       tag = "GRAVEDAD-0", type = "entorno",   color = {0.4, 0.9, 1.0}, desc = "Inercia sin friccion: solo giras al pulsar."},
    {id = "midas_curse",     name = "62. Maldicion de Midas",  tag = "MIDAS",      type = "maldicion", color = {1.0, 0.8, 0.2}, desc = "Frutas +2$ pero -1 punto por segundo."},
    {id = "feather_blessing",name = "63. Bendicion de Pluma",  tag = "PLUMA",      type = "bendicion", color = {0.7, 1.0, 0.7}, desc = "Giras con agilidad de 3 segmentos."},
    {id = "silent_veil",     name = "64. Velo Silencioso",     tag = "VELO",       type = "desafio",   color = {0.5, 0.5, 0.6}, desc = "Items sellados; superarla da doble moneda."},
    {id = "stalking_shadow", name = "65. Sombra Acechante",    tag = "SOMBRA",     type = "maldicion", color = {0.6, 0.3, 0.9}, desc = "Un espectro invulnerable te persigue."},
    {id = "time_trial",      name = "66. Contrarreloj",        tag = "CRONO",      type = "desafio",   color = {1.0, 0.6, 0.2}, desc = "10.0s para el objetivo: premio legendario."},
    {id = "phoenix_blessing",name = "67. Bendicion del Fenix", tag = "FENIX",      type = "bendicion", color = {1.0, 0.4, 0.2}, desc = "Revives 1 vez gratis con 3 segmentos."},
    {id = "tunnel_vision",   name = "68. Vision de Tunel",     tag = "TUNEL",      type = "maldicion", color = {0.3, 0.4, 0.8}, desc = "Oscuridad salvo radio 5 de la cabeza."},
    {id = "dual_room",       name = "69. Sala de Dualidad",    tag = "DUAL",       type = "entorno",   color = {0.9, 0.5, 1.0}, desc = "Spawns de enemigos y frutas duplicados."},
    {id = "titan_pact",      name = "70. Pacto del Titan",     tag = "TITAN",      type = "pacto",     color = {0.8, 0.5, 0.3}, desc = "Cuerpo 1.5x grueso, frutas +50 puntos."},
}

local function findDef(id)
    for _, d in ipairs(mutators.MUTATOR_DEFS) do
        if d.id == id then return d end
    end
    return nil
end

function mutators.get()
    return world.state.roomMutator
end

function mutators.getDef(id)
    return findDef(id or mutators.get())
end

function mutators.has(id)
    return id ~= nil and world.state.roomMutator == id
end

function mutators.data()
    if type(world.state.roomMutatorData) ~= "table" then
        world.state.roomMutatorData = {}
    end
    return world.state.roomMutatorData
end

function mutators.clear()
    world.state.roomMutator = nil
    world.state.roomMutatorData = {}
end

-- Roll puro: nil ~65% de salas; boss (template/sala 5) y elite siempre nil.
function mutators.roll(sala, room)
    if room and (room.template == "boss" or room.isElite) then return nil end
    if (sala or 0) == 5 then return nil end
    local chance = constants.ROOM_MUTATOR_CHANCE
    if type(chance) ~= "number" then chance = 0.35 end
    if love.math.random() > chance then return nil end
    return mutators.MUTATOR_DEFS[love.math.random(#mutators.MUTATOR_DEFS)].id
end

-- Aplica el roll a la sala actual y devuelve el id (o nil sin mutador).
function mutators.apply(sala, room)
    local id = mutators.roll(sala, room)
    world.state.roomMutator = id
    world.state.roomMutatorData = {}
    -- Sombra y Fenix persisten toda la etapa una vez sorteados
    if id == "stalking_shadow" then world.state.stageShadow = true end
    if id == "phoenix_blessing" then world.state.stagePhoenixArmed = true end
    return id
end

-- === P2: helpers de mutadores simples (GDD §19.62/64/66/69) ===

-- 62. Midas Avaro: +2 monedas por fruta
function mutators.midasFruitBonus()
    return mutators.has("midas_curse") and 2 or 0
end

-- 62. Midas Avaro: drena 1 punto/seg de la puntuacion; retorna lo drenado
function mutators.midasDrain(dt)
    if not mutators.has("midas_curse") then return 0 end
    local st = world.state
    local d = mutators.data()
    d.midasAcc = (d.midasAcc or 0) + (dt or 0)
    local drained = 0
    while d.midasAcc >= 1.0 do
        d.midasAcc = d.midasAcc - 1.0
        if (st.puntuacion or 0) > 0 then
            st.puntuacion = st.puntuacion - 1
            drained = drained + 1
        end
    end
    return drained
end

-- 64. Velo Silencioso: items de slots sellados en PLAYING
function mutators.itemsSealed()
    return mutators.has("silent_veil")
end

-- 64. Velo: registra monedas al entrar; al superar duplica lo ganado en sala
function mutators.silentMarkCoins(monedas)
    mutators.data().startCoins = monedas or 0
end

function mutators.silentClearBonus(monedas)
    if not mutators.has("silent_veil") then return 0 end
    local start = mutators.data().startCoins
    if type(start) ~= "number" then return 0 end
    return math.max(0, math.floor((monedas or 0) - start))
end

-- 66. Contrarreloj: limite en segundos para cumplir el objetivo
function mutators.timeTrialLimit()
    return constants.ROOM_TIME_TRIAL_DURATION or 10.0
end

-- Avanza el crono; retorna "expired" una sola vez al agotarse
function mutators.timeTrialTick(dt)
    if not mutators.has("time_trial") then return nil end
    local d = mutators.data()
    if d.expired then return nil end
    d.elapsed = (d.elapsed or 0) + (dt or 0)
    if d.elapsed >= mutators.timeTrialLimit() then
        d.expired = true
        return "expired"
    end
    return nil
end

function mutators.timeTrialWon()
    if not mutators.has("time_trial") then return false end
    local d = mutators.data()
    return not d.expired and (d.elapsed or 0) <= mutators.timeTrialLimit()
end

-- Elige un pasivo no poseido (registry, inventory) o nil si todos poseidos
function mutators.randomUnownedPassive(registry, inventory)
    if type(registry) ~= "table" then return nil end
    inventory = inventory or {}
    local pool = {}
    for id, def in pairs(registry) do
        if type(def) == "table" and def.itemType == "passive"
            and not inventory[def.id or id] then
            pool[#pool + 1] = def
        end
    end
    if #pool == 0 then return nil end
    return pool[love.math.random(#pool)]
end

-- 69. Dualidad activa
function mutators.dualActive()
    return mutators.has("dual_room")
end

-- === P3: helpers de mutadores medios (GDD §19.61/63/70) ===

-- 61. Gravedad Cero: deriva con inercia (ignora el reposo tactico)
function mutators.zeroGDrift()
    return mutators.has("zero_gravity")
end

-- 63. Pluma: solo los 3 primeros segmentos son letales
function mutators.featherActive()
    return mutators.has("feather_blessing")
end

-- 70. Titan: grosor 1.5x (cruz propia letal) + 50 puntos por fruta
function mutators.titanGirth()
    return mutators.has("titan_pact")
end

function mutators.titanFruitBonus()
    return mutators.has("titan_pact") and 50 or 0
end

-- === P4: helpers de mutadores pesados (GDD §19.65/67/68) ===

local function sgn(n)
    if n > 0 then return 1 elseif n < 0 then return -1 end
    return 0
end

-- 65. Sombra: activa toda la etapa una vez sorteada
function mutators.stageShadowActive()
    return world.state.stageShadow == true
end

function mutators.getShadow()
    return mutators.data().shadow
end

-- Paso puro de persecucion Chebyshev (testeable sin estado)
function mutators.shadowStep(sh, head)
    if not sh then return nil end
    if not head then return {x = sh.x, y = sh.y} end
    return {x = sh.x + sgn(head.x - sh.x), y = sh.y + sgn(head.y - sh.y)}
end

-- Esquina libre mas lejana a la cabeza (spawn del espectro)
function mutators.spawnShadowPos(head, ancho, alto, obstaclesPos)
    local w = (type(ancho) == "number" and ancho > 0) and ancho or 10
    local h = (type(alto) == "number" and alto > 0) and alto or 10
    local corners = {{x = 0, y = 0}, {x = w - 1, y = 0}, {x = 0, y = h - 1}, {x = w - 1, y = h - 1}}
    local best, bestD = nil, -1
    for _, c in ipairs(corners) do
        local blocked = false
        for _, o in ipairs(obstaclesPos or {}) do
            if o.x == c.x and o.y == c.y then blocked = true; break end
        end
        if not blocked then
            local dist = head and (math.abs(c.x - head.x) + math.abs(c.y - head.y)) or 0
            if dist > bestD then best, bestD = {x = c.x, y = c.y}, dist end
        end
    end
    if best then return best end
    return {x = math.max(0, w - 2), y = math.max(0, h - 2)}
end

-- Tick del espectro; retorna "kill" al contactar la cabeza
function mutators.shadowTick(dt, head)
    if not mutators.stageShadowActive() then return nil end
    local d = mutators.data()
    local sh = d.shadow
    if not sh then return nil end
    if head and sh.x == head.x and sh.y == head.y then return "kill" end
    d.shadowAcc = (d.shadowAcc or 0) + (dt or 0)
    local interval = constants.ROOM_SHADOW_INTERVAL or 0.9
    if d.shadowAcc >= interval then
        d.shadowAcc = 0
        if head then
            local nxt = mutators.shadowStep(sh, head)
            sh.x, sh.y = nxt.x, nxt.y
            if sh.x == head.x and sh.y == head.y then return "kill" end
        end
    end
    return nil
end

-- 67. Fenix: armado toda la etapa al sortearse, un solo uso
function mutators.phoenixAvailable()
    return world.state.stagePhoenixArmed == true and not world.state.stagePhoenixUsed
end

function mutators.phoenixConsume()
    world.state.stagePhoenixUsed = true
end

-- Limpia banderas de etapa (llamar en init/avanzarEtapa)
function mutators.resetStage()
    world.state.stageShadow = false
    world.state.stagePhoenixArmed = false
    world.state.stagePhoenixUsed = false
end

-- 68. Tunel activo en la sala
function mutators.tunnelActive()
    return mutators.has("tunnel_vision")
end

return mutators

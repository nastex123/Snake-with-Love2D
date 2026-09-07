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
    return id
end

return mutators

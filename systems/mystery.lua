-- systems/mystery.lua — Special Mystery Rooms (GDD §15, TDD §10.28)
-- 4 salas especiales que sustituyen una sala estandar (6%): apuesta, espejo,
-- fiebre del oro y prueba de sellos. Flag persistente en dungeon.rooms[].mystery.
local mystery = {}
local constants = require("constants")
local world = require("core.world")

-- ids estables usados por los hooks de gameplay (P2/P3).
mystery.MYSTERY_DEFS = {
    {id = "gambler_den",  name = "Guarida del Apostador", tag = "APUESTA", type = "apuesta",  color = {1.0, 0.8, 0.2}, desc = "Apuesta 10$: 3 doradas en 15s o 2 Chasers."},
    {id = "doppelganger", name = "Sombra Espejo",         tag = "ESPEJO",  type = "duelo",    color = {0.5, 0.1, 0.8}, desc = "Replica tus giros con 1.2s de retraso."},
    {id = "gold_rush",    name = "Fiebre del Oro",        tag = "ORO",     type = "bonus",    color = {1.0, 0.9, 0.3}, desc = "20 monedas rebotando durante 12s."},
    {id = "trial_triads", name = "Prueba de los Sellos",  tag = "SELLOS",  type = "prueba",   color = {0.4, 0.9, 1.0}, desc = "Pisa 1-2-3 en orden en menos de 10s."},
}

local function findDef(id)
    for _, d in ipairs(mystery.MYSTERY_DEFS) do
        if d.id == id then return d end
    end
    return nil
end

function mystery.getDef(id)
    return findDef(id)
end

-- Decide si la sala i (1-based) puede ser misterio: nunca boss, elite ni sala 1.
function mystery.canBeMystery(room, idx)
    if not room then return false end
    if (idx or room.id or 0) == 1 then return false end
    if room.template == "boss" or room.isElite then return false end
    return true
end

-- Roll puro: id de misterio o nil (6% por sala candidata).
function mystery.roll(room, idx)
    if not mystery.canBeMystery(room, idx) then return nil end
    local chance = constants.ROOM_MYSTERY_CHANCE
    if type(chance) ~= "number" then chance = 0.06 end
    if love.math.random() > chance then return nil end
    return mystery.MYSTERY_DEFS[love.math.random(#mystery.MYSTERY_DEFS)].id
end

-- Asigna misterio a las salas candidatas de la mazmorra (tras generar).
function mystery.assign(dungeon)
    if not dungeon or not dungeon.rooms then return 0 end
    local n = 0
    for i, room in ipairs(dungeon.rooms) do
        room.mystery = mystery.roll(room, i)
        if room.mystery then n = n + 1 end
    end
    return n
end

-- Misterio de la sala actual (o nil en sala normal).
function mystery.current(worldMod)
    local room = worldMod and worldMod.getCurrentRoom and worldMod.getCurrentRoom()
    return room and room.mystery or nil
end

function mystery.currentDef(worldMod)
    return findDef(mystery.current(worldMod))
end

-- Runtime por sala (timers, contadores); se renueva al entrar.
function mystery.data()
    if type(world.state.mysteryData) ~= "table" then
        world.state.mysteryData = {}
    end
    return world.state.mysteryData
end

function mystery.begin()
    world.state.mysteryData = {}
    return world.state.mysteryData
end

return mystery

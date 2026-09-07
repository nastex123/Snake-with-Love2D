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

-- === P2: Guarida del Apostador + Fiebre del Oro (GDD §15.1/15.3) ===

function mystery.gamblerActive(worldMod)
    return mystery.current(worldMod) == "gambler_den"
end

-- Casilla central de la ruleta (pura, testeable)
function mystery.gamblerRoulette(ancho, alto)
    return {x = math.floor((ancho or 10) / 2), y = math.floor((alto or 10) / 2)}
end

function mystery.gamblerBet()
    return constants.GAMBLER_BET or 10
end

function mystery.gamblerTime()
    return constants.GAMBLER_TIME or 15.0
end

function mystery.gamblerGolds()
    return constants.GAMBLER_GOLDS or 3
end

-- Coloca la apuesta; retorna true si habia fondos
function mystery.gamblerPlaceBet(monedas)
    local d = mystery.data()
    if d.bet then return false end
    if (monedas or 0) < mystery.gamblerBet() then return false end
    d.bet = true
    d.timer = mystery.gamblerTime()
    d.goldGot = 0
    return true
end

-- Avanza el temporizador; retorna "lose" una sola vez al agotarse
function mystery.gamblerTick(dt)
    local d = mystery.data()
    if not d.bet or d.done then return nil end
    d.timer = (d.timer or mystery.gamblerTime()) - (dt or 0)
    if d.timer <= 0 then
        d.timer = 0
        d.done = true
        return "lose"
    end
    return nil
end

-- Cuenta una dorada comida con apuesta activa; retorna "win" al completar
function mystery.gamblerGoldEaten()
    local d = mystery.data()
    if not d.bet or d.done then return nil end
    d.goldGot = (d.goldGot or 0) + 1
    if d.goldGot >= mystery.gamblerGolds() then
        d.done = true
        return "win"
    end
    return nil
end

-- Mientras falten doradas, los respawns deben forzarse a oro
function mystery.gamblerNeedsGold()
    local d = mystery.data()
    return d.bet and not d.done
end

-- === Fiebre del Oro ===

function mystery.goldRushActive(worldMod)
    return mystery.current(worldMod) == "gold_rush"
end

function mystery.goldRushTime()
    return constants.GOLDRUSH_TIME or 12.0
end

function mystery.goldRushCoins()
    return constants.GOLDRUSH_COINS or 20
end

-- Inicializa las 20 monedas rebotando (pos float + dir + velocidad)
function mystery.beginGoldRush(ancho, alto)
    local d = mystery.data()
    local w = (type(ancho) == "number" and ancho > 0) and ancho or 10
    local h = (type(alto) == "number" and alto > 0) and alto or 10
    local coins = {}
    for _ = 1, mystery.goldRushCoins() do
        local dx, dy = 0, 0
        while dx == 0 and dy == 0 do
            dx = love.math.random(-1, 1)
            dy = love.math.random(-1, 1)
        end
        coins[#coins + 1] = {
            x = love.math.random() * (w - 1),
            y = love.math.random() * (h - 1),
            dx = dx, dy = dy,
            speed = 6.0,
        }
    end
    d.rush = {timer = mystery.goldRushTime(), coins = coins}
    return d.rush
end

-- Mueve las monedas con rebote elastico (puro respecto a la lista)
function mystery.stepCoins(coins, ancho, alto, dt)
    if type(coins) ~= "table" then return end
    local w = (ancho or 10) - 1
    local h = (alto or 10) - 1
    for _, c in ipairs(coins) do
        c.x = c.x + c.dx * c.speed * (dt or 0)
        c.y = c.y + c.dy * c.speed * (dt or 0)
        if c.x < 0 then c.x = 0; c.dx = 1
        elseif c.x > w then c.x = w; c.dx = -1 end
        if c.y < 0 then c.y = 0; c.dy = 1
        elseif c.y > h then c.y = h; c.dy = -1 end
    end
end

-- Recoge las que tocan la cabeza (radio 0.7); retorna cantidad
function mystery.collectCoins(coins, head)
    if type(coins) ~= "table" or not head then return 0 end
    local got = 0
    for i = #coins, 1, -1 do
        local c = coins[i]
        local dist = math.abs(c.x - head.x) + math.abs(c.y - head.y)
        if dist < 1.4 then
            table.remove(coins, i)
            got = got + 1
        end
    end
    return got
end

-- Tick de la fiebre; retorna got y done por separado via rush table
function mystery.goldRushTick(dt, head)
    local d = mystery.data()
    local rush = d.rush
    if not rush then return 0, false end
    rush.timer = rush.timer - (dt or 0)
    local got = mystery.collectCoins(rush.coins, head)
    if rush.timer <= 0 then
        rush.timer = 0
        return got, true
    end
    return got, false
end

return mystery

-- systems/tarot.lua — Cartas del Destino comprables en tienda (GDD §14, TDD §10.13)
-- Mazo data-driven de 12 cartas: compra en tienda, activas durante la etapa en curso.
-- Estado en World.state: stageCards (array de ids activos).
local tarot = {}
local constants = require("constants")
local world = require("core.world")

-- Catálogo maestro: id estable usado por hasTarot() en los hooks de gameplay.
tarot.TAROT_DEFS = {
    {id = "mercury",             name = "I. El Mercurio",        color = {0.4, 0.9, 1.0},  desc = "+15% velocidad. Cada comida duplica el multiplicador de combo."},
    {id = "iron_spine",          name = "II. La Espina Dorsal",  color = {0.7, 0.7, 0.8},  desc = "Tus 3 ultimos segmentos son de hierro: destruyen Chasers que muerdan la cola."},
    {id = "eagle_eye",           name = "III. El Ojo de Aguila", color = {1.0, 0.85, 0.3}, desc = "Ventana de combo extendida de 8.0s a 12.0s."},
    {id = "shadow_thief",        name = "IV. Ladron de Sombras", color = {0.5, 0.3, 0.9},  desc = "Rozar enemigos (celda contigua) genera +1 moneda."},
    {id = "alchemical_digestion",name = "V. Digestion Alquimica",color = {0.4, 1.0, 0.5},  desc = "25% de que cada comida normal nazca como comida de Oro."},
    {id = "dragon_blood",        name = "VI. Sangre de Dragon",  color = {1.0, 0.4, 0.2},  desc = "El rastro de fuego picante dura 6.0s (base 3.5s)."},
    {id = "absolute_zero",       name = "VII. Cero Absoluto",    color = {0.6, 0.9, 1.0},  desc = "La Fruta Helada congela 4.0s y vuelve fragiles a los enemigos."},
    {id = "magic_circle",        name = "VIII. El Circulo Magico",color = {0.9, 0.5, 1.0}, desc = "Radio de atraccion del bucle de constriccion +1 casilla."},
    {id = "astral_mirror",       name = "IX. Espejo Astral",     color = {0.5, 1.0, 0.9},  desc = "Atraviesa paredes exteriores 1 vez por sala sin morir."},
    {id = "midas_pouch",         name = "X. La Bolsa de Midas",  color = {1.0, 0.8, 0.2},  desc = "Al iniciar cada sala caen 3 monedas en celdas aleatorias."},
    {id = "iron_heart",          name = "XI. Corazon de Hierro", color = {1.0, 1.0, 1.0},  desc = "Superar una sala con menos de 5 segmentos da 1 Escudo gratis."},
    {id = "reaper",              name = "XII. El Segador",       color = {0.7, 0.3, 1.0},  desc = "Cada enemigo eliminado extiende tus buffs activos +0.5s."},
}

local function findDef(id)
    for _, d in ipairs(tarot.TAROT_DEFS) do
        if d.id == id then return d end
    end
    return nil
end

function tarot.getActive()
    local st = world.state
    if type(st.stageCards) ~= "table" then st.stageCards = {} end
    return st.stageCards
end

function tarot.reset()
    world.state.stageCards = {}
end

function tarot.has(id)
    for _, cid in ipairs(tarot.getActive()) do
        if cid == id then return true end
    end
    return false
end

function tarot.count()
    return #tarot.getActive()
end

-- Tienda v2 (GDD §13 rework): precio por carta (tier S60/A45/B30/C20)
function tarot.price(id)
    local prices = constants.TAROT_PRICES
    if type(prices) == "table" and type(prices[id]) == "number" then
        return prices[id]
    end
    return 30
end

-- Pool comprable: definitivas no equipadas (sin tope, manda el stock)
function tarot.shopPool()
    local pool = {}
    for _, d in ipairs(tarot.TAROT_DEFS) do
        if not tarot.has(d.id) then pool[#pool + 1] = d.id end
    end
    return pool
end

-- Compra desde la tienda; retorna el id o nil si ya equipada/invalida
function tarot.buy(id)
    if not findDef(id) or tarot.has(id) then return nil end
    local active = tarot.getActive()
    active[#active + 1] = id
    return id
end

-- === Helpers de hooks (puros, testeables sin love.graphics) ===
function tarot.speedFactor()
    return tarot.has("mercury") and 0.85 or 1.0
end

function tarot.comboWindow()
    if tarot.has("eagle_eye") then return 12.0 end
    return constants.COMBO_WINDOW or 8.0
end

function tarot.comboMult(m)
    if tarot.has("mercury") then return m * 2 end
    return m
end

-- Espina Dorsal: protege los 3 últimos segmentos contra mordiscos Chaser
function tarot.ironSpineProtects(segIdx, bodyLen)
    return tarot.has("iron_spine") and segIdx ~= nil and bodyLen ~= nil and segIdx > bodyLen - 3
end

-- Sangre de Dragón: rastro de fuego 6.0s (base 3.5s, GDD §14)
function tarot.fireBuffDuration()
    if tarot.has("dragon_blood") then return 6.0 end
    return constants.FIRE_PEPPER_DURATION or 3.5
end

-- Cero Absoluto: congelación 4.0s + fragilidad letal (GDD §14)
function tarot.freezeDuration()
    if tarot.has("absolute_zero") then return 4.0 end
    return constants.FROST_BERRY_DURATION or 2.5
end

function tarot.isShatterFrozen()
    return tarot.has("absolute_zero") and (world.state.enemyFreezeTimer or 0) > 0
end

-- Círculo Mágico: alcance de constricción +1 casilla (adyacencia Chebyshev)
function tarot.constrictReach()
    return tarot.has("magic_circle") and 1 or 0
end

-- El Segador: cada kill extiende buffs activos +0.5s (no-op sin la carta)
function tarot.extendBuffs(amount)
    if not tarot.has("reaper") then return 0 end
    amount = amount or 0.5
    local st = world.state
    if type(st.activeTimers) ~= "table" then return 0 end
    local n = 0
    for _, t in ipairs(st.activeTimers) do
        if t._handle and t._handle.delay then
            t._handle.delay = t._handle.delay + amount
            n = n + 1
        elseif t.remaining and t.remaining > 0 then
            t.remaining = t.remaining + amount
            n = n + 1
        end
    end
    return n
end


return tarot

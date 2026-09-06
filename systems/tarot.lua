-- systems/tarot.lua — Stage Tarot Draft System (GDD §14, TDD §10.13)
-- Mazo data-driven de 12 Cartas del Destino: draft en salas 1/2/4, max 3 por etapa.
-- Estado en World.state: stageCards (array de ids activos), tarotDraft (opciones abiertas).
local tarot = {}
local constants = require("constants")
local world = require("core.world")

tarot.DRAFT_ROOMS = {1, 2, 4}
tarot.MAX_STAGE_CARDS = 3
tarot.OPTIONS_COUNT = 3

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

-- Rects de hitboxes (reutilizada, sin allocs por frame salvo draw)
tarot.g = {cards = {}}

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
    world.state.tarotDraft = nil
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

-- Muestrea N opciones aleatorias no equipadas (Fisher-Yates parcial, sin reemplazo)
function tarot.sampleOptions(n)
    n = n or tarot.OPTIONS_COUNT
    local pool = {}
    for _, d in ipairs(tarot.TAROT_DEFS) do
        if not tarot.has(d.id) then pool[#pool + 1] = d.id end
    end
    local out = {}
    local m = math.min(n, #pool)
    for i = 1, m do
        local j = i + math.random(#pool - i + 1) - 1
        pool[i], pool[j] = pool[j], pool[i]
        out[#out + 1] = pool[i]
    end
    return out
end

function tarot.shouldOffer(sala)
    if tarot.count() >= tarot.MAX_STAGE_CARDS then return false end
    for _, r in ipairs(tarot.DRAFT_ROOMS) do
        if r == sala then return true end
    end
    return false
end

function tarot.isOpen()
    return world.state.tarotDraft ~= nil
end

function tarot.open(sala)
    local st = world.state
    st.tarotDraft = {options = tarot.sampleOptions(), sala = sala}
    st.gameState = constants.GAME_STATE_TAROT
end

-- Aplica la carta elegida y continúa a TRANSITION (flujo idéntico a sala completada)
function tarot.choose(index)
    local st = world.state
    local draft = st.tarotDraft
    if not draft or not draft.options[index] then return nil end
    local id = draft.options[index]
    local active = tarot.getActive()
    if #active < tarot.MAX_STAGE_CARDS and not tarot.has(id) then
        active[#active + 1] = id
    end
    st.tarotDraft = nil
    st.transitionTarget = "siguienteSala"
    st.transitionPhase = 1
    st.fadeDir = 1
    st.gameState = constants.GAME_STATE_TRANSITION
    local sound = require("audio.sound")
    if sound.play then sound.play("buy") end
    if sound.playSegment then sound:playSegment("intro") end
    return id
end

function tarot.update(dt)
    -- El draft es modal estático; st.time (updateCommon) anima el brillo.
end

function tarot.mousepressed(x, y)
    local g = tarot.g
    if not tarot.isOpen() or not g.cards then return nil end
    for i, r in ipairs(g.cards) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            return tarot.choose(i)
        end
    end
    return nil
end

function tarot.keypressed(tecla)
    if not tarot.isOpen() then return nil end
    local idx = ({["1"] = 1, ["2"] = 2, ["3"] = 3})[tecla]
    if idx then return tarot.choose(idx) end
    return nil
end

function tarot.draw()
    local st = world.state
    local draft = st.tarotDraft
    if not draft then return end
    local uiMod = require("ui.ui")
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    love.graphics.setColor(0.02, 0.02, 0.06, 0.88)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setFont(uiMod.fontTitle)
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf("ELIGE TU DESTINO", 0, h * 0.10, w, "center")
    love.graphics.setFont(uiMod.fontNormal)
    love.graphics.setColor(0.7, 0.7, 0.85)
    love.graphics.printf("Sala " .. tostring(draft.sala or "?") .. " completada — 1 carta bendice tu etapa", 0, h * 0.10 + 34, w, "center")

    local cw, chh = 150, 190
    local gap = 24
    local totalW = cw * 3 + gap * 2
    local x0 = (w - totalW) / 2
    local y0 = h * 0.5 - chh / 2
    tarot.g.cards = {}
    for i = 1, 3 do
        local id = draft.options[i]
        local def = id and findDef(id) or nil
        local cx = x0 + (i - 1) * (cw + gap)
        tarot.g.cards[i] = {x = cx, y = y0, w = cw, h = chh}
        local pulse = 0.5 + 0.5 * math.sin((st.time or 0) * 3 + i * 2.1)
        if def then
            love.graphics.setColor(def.color[1] * 0.25, def.color[2] * 0.25, def.color[3] * 0.25, 1)
            love.graphics.rectangle("fill", cx, y0, cw, chh, 8, 8)
            love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.65 + 0.35 * pulse)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx, y0, cw, chh, 8, 8)
            love.graphics.setFont(uiMod.fontNormal)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(def.name, cx + 8, y0 + 14, cw - 16, "center")
            love.graphics.setFont(uiMod.fontSmall)
            love.graphics.setColor(0.85, 0.85, 0.9)
            love.graphics.printf(def.desc, cx + 8, y0 + 62, cw - 16, "center")
        else
            love.graphics.setColor(0.15, 0.15, 0.2, 1)
            love.graphics.rectangle("fill", cx, y0, cw, chh, 8, 8)
        end
        love.graphics.setFont(uiMod.fontSmall)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.printf("[" .. i .. "]", cx, y0 + chh + 8, cw, "center")
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

return tarot

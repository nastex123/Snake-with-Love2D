local codex = {}
codex.BESTIARY = {
    {id = "chaser", kind = "enemy", name = "Cazador", desc = "Persigue la cabeza en manada"},
    {id = "patroller", kind = "enemy", name = "Patrullero", desc = "Intercepta en linea de vision"},
    {id = "spawner", kind = "enemy", name = "Generador", desc = "Siembra obstaculos"},
    {id = "boss", kind = "boss", name = "Lord de la Camara", desc = "Cae a cabezazos con combo x2+"},
    {id = "wall_crusher", kind = "mini", name = "Triturador", desc = "Embestida sismica 2 lineas"},
    {id = "frost_golem", kind = "mini", name = "Golem Escarcha", desc = "Aliento gelido y nova"},
    {id = "magma_wyrm", kind = "mini", name = "Sierpe Magma", desc = "Rastro de lava 4s"},
    {id = "brood_queen", kind = "mini", name = "Reina Larva", desc = "Enjambre y red pegajosa"},
    {id = "void_phantom", kind = "mini", name = "Espectro Vacio", desc = "Singularidad y desfase"},
}
codex.MINI_BY_STAGE = {"wall_crusher", "frost_golem", "magma_wyrm", "brood_queen", "void_phantom"}
codex.SYNERGIES = {
    {id = "reactive_shield", name = "Escudo Reactivo", items = {"shield", "bomb"}, desc = "Al romperse detona radio 3"},
    {id = "golden_vortex", name = "Vortice Dorado", items = {"magnet", "doubler"}, desc = "Atraccion con doble recompensa"},
    {id = "spectral_comet", name = "Cometa Espectral", items = {"ghost", "turbo"}, desc = "Atraviesa destruyendo"},
    {id = "voracious_hunger", name = "Hambre Voraz", items = {"hunger", "speedReducer"}, desc = "Comida extra acelera giro"},
    {id = "supernova", name = "Supernova", items = {"bomb", "star"}, desc = "Radio 6 y botin de muros"},
    {id = "mirror_armor", name = "Armadura Espejo", items = {"armor", "star"}, desc = "Rebota proyectiles"},
    {id = "gravity_well", name = "Pozo Gravitatorio", items = {"magnet", "slow"}, desc = "Frena chasers en radio 4"},
    {id = "time_overload", name = "Sobrecarga Temporal", items = {"turbo", "slow"}, desc = "Bullet time total"},
}
local function profile()
    local ok, persistence = pcall(require, "systems.persistence")
    if not ok or not persistence then return nil end
    return persistence.getActiveProfile()
end
local function save(p)
    local ok, persistence = pcall(require, "systems.persistence")
    if not ok or not persistence then return end
    if p then
        if persistence.saveProfiles then persistence.saveProfiles() end
        local okEv, Events = pcall(require, "core.events")
        if okEv and Events and Events.emit then
            pcall(function() Events.emit("codexDirty", {}) end)
        end
    end
end
function codex.seeEnemy(etype)
    if type(etype) ~= "string" then return false end
    local p = profile()
    if not p then return false end
    p.codex = p.codex or {enemiesSeen = {}, miniBossesSeen = {}, synergies = {}}
    p.codex.enemiesSeen = p.codex.enemiesSeen or {}
    if p.codex.enemiesSeen[etype] then return false end
    p.codex.enemiesSeen[etype] = true
    save(p)
    return true
end
function codex.seeMiniBoss(etapa)
    local id = codex.MINI_BY_STAGE[math.max(1, math.min(5, etapa or 1))]
    if not id then return false end
    local p = profile()
    if not p then return false end
    p.codex = p.codex or {enemiesSeen = {}, miniBossesSeen = {}, synergies = {}}
    p.codex.miniBossesSeen = p.codex.miniBossesSeen or {}
    if p.codex.miniBossesSeen[id] then return false end
    p.codex.miniBossesSeen[id] = true
    save(p)
    return true
end
local function owned(id, shop)
    if not shop or not id then return false end
    if shop.inventory and shop.inventory[id] then return true end
    if shop.slots then
        for i = 1, 3 do if shop.slots[i] == id then return true end end
    end
    return false
end
function codex.checkSynergies(shop)
    local p = profile()
    if not p then return {} end
    p.codex = p.codex or {enemiesSeen = {}, miniBossesSeen = {}, synergies = {}}
    p.codex.synergies = p.codex.synergies or {}
    local found = {}
    for _, s in ipairs(codex.SYNERGIES) do
        if not p.codex.synergies[s.id] and owned(s.items[1], shop) and owned(s.items[2], shop) then
            p.codex.synergies[s.id] = true
            found[#found + 1] = s.id
        end
    end
    if #found > 0 then save(p) end
    return found
end
function codex.counts()
    local p = profile()
    if not p or not p.codex then return 0, 0, 0 end
    local e, m, s = 0, 0, 0
    for _ in pairs(p.codex.enemiesSeen or {}) do e = e + 1 end
    for _ in pairs(p.codex.miniBossesSeen or {}) do m = m + 1 end
    for _ in pairs(p.codex.synergies or {}) do s = s + 1 end
    return e, m, s
end
return codex

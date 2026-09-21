local Defs = {}
Defs.BRANCHES = {"Fortuna", "Alquimia", "Misticismo", "Combate"}
Defs.LIST = {
    {id = "heritage_pouch", branch = "Fortuna", name = "Bolsa de Herencia", desc = "Inicia la run con monedas extra", ranks = {[1] = "+5 monedas", [2] = "+10 monedas", [3] = "+15 monedas"}},
    {id = "residual_magnet", branch = "Fortuna", name = "Iman Residual", desc = "Atrae monedas en radio pasivo", ranks = {[1] = "Radio 1", [2] = "Radio 2"}},
    {id = "dragon_stomach", branch = "Alquimia", name = "Estomago Dragon", desc = "Alarga buffs de comida", ranks = {[1] = "+1.0s buffs", [2] = "+2.0s buffs"}},
    {id = "thick_potions", branch = "Alquimia", name = "Pociones Espesas", desc = "Slow-mo dura mas", ranks = {[1] = "+1.5s slow"}},
    {id = "sixth_sense", branch = "Misticismo", name = "Sexto Sentido", desc = "Revela el tipo de la proxima sala", ranks = {[1] = "Icono en puerta"}},
    {id = "mercy_pact", branch = "Misticismo", name = "Pacto Piedad", desc = "Revivir cuesta menos", ranks = {[1] = "Revive 25$", [2] = "Revive 20$"}},
    {id = "iron_body", branch = "Combate", name = "Cuerpo Temple", desc = "Perdona 1 autocolision por etapa", ranks = {[1] = "1 perdon/etapa"}},
    {id = "hunter_focus", branch = "Combate", name = "Foco Cazador", desc = "Ventana de combo mas amplia", ranks = {[1] = "9.0s combo", [2] = "10.0s combo"}},
}
Defs.BY_ID = {}
for _, d in ipairs(Defs.LIST) do Defs.BY_ID[d.id] = d end
function Defs.cost(id, nextRank)
    local okCfg, cfg = pcall(require, "core.config")
    if not okCfg or not cfg.SHRINE_TALENTS or not cfg.SHRINE_TALENTS[id] then return nil end
    local costs = cfg.SHRINE_TALENTS[id].costs or {}
    return costs[nextRank]
end
function Defs.maxRank(id)
    local okCfg, cfg = pcall(require, "core.config")
    if not okCfg or not cfg.SHRINE_TALENTS or not cfg.SHRINE_TALENTS[id] then return 0 end
    return cfg.SHRINE_TALENTS[id].maxRank or 0
end
return Defs

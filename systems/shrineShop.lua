local shrineShop = {}
local defs = require("systems.shrineDefs")
function shrineShop.state()
    local ok, persistence = pcall(require, "systems.persistence")
    if not ok or not persistence then return nil end
    return persistence.getActiveProfile()
end
function shrineShop.balance()
    local p = shrineShop.state()
    if not p then return 0 end
    return p.shrineCoins or 0
end
function shrineShop.canBuy(id)
    local p = shrineShop.state()
    if not p then return false, "Sin perfil" end
    local maxR = defs.maxRank(id)
    if maxR <= 0 then return false, "Talento desconocido" end
    local cur = (p.talents and p.talents[id]) or 0
    if cur >= maxR then return false, "Rango maximo" end
    local price = defs.cost(id, cur + 1)
    if not price then return false, "Sin precio" end
    if (p.shrineCoins or 0) < price then return false, "Fondos insuficientes" end
    return true, nil, price
end
function shrineShop.buy(id)
    local ok, can, errMsg, price = pcall(shrineShop.canBuy, id)
    if not ok or not can then return false, errMsg or "No disponible" end
    local persistence = require("systems.persistence")
    local p = persistence.getActiveProfile()
    if not p then return false, "Sin perfil" end
    p.shrineCoins = (p.shrineCoins or 0) - price
    p.talents = p.talents or {}
    p.talents[id] = ((p.talents[id] or 0) + 1)
    persistence.saveProfiles()
    local okEv, Events = pcall(require, "core.events")
    if okEv and Events and Events.emit then pcall(function() Events.emit("talentsDirty", {talents = p.talents}) end) end
    return true, nil, price
end
return shrineShop

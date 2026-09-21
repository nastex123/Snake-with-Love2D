local bounty = {}
local world = require("core.world")
local TARGETS = {cerco_maestro = 4, rapido_furioso = 3, pacifista_tactico = 1}
function bounty.targets()
    return TARGETS
end
function bounty.active()
    local b = world.get("bounties")
    if type(b) ~= "table" or type(b.active) ~= "table" then return {} end
    return b.active
end
function bounty.roll(pool)
    pool = pool or {}
    if #pool == 0 then
        local okCfg, cfg = pcall(require, "core.config")
        if okCfg and cfg.BOUNTY_POOL then pool = cfg.BOUNTY_POOL end
    end
    local active = {}
    for i = 1, math.min(2, #pool) do
        local def = pool[i]
        if def and def.id then
            active[#active + 1] = {id = def.id, progress = 0, target = TARGETS[def.id] or 1, done = false}
        end
    end
    world.set("bounties", {active = active, furiosoStreak = 0, constrictorKills = 0})
    return active
end
function bounty.find(id)
    for _, a in ipairs(bounty.active()) do
        if a.id == id then return a end
    end
    return nil
end
function bounty.progress(id, amount)
    local a = bounty.find(id)
    if not a or a.done then return false end
    a.progress = (a.progress or 0) + (amount or 1)
    if a.progress >= (a.target or 1) then
        bounty.complete(a)
        return true
    end
    return false
end
function bounty.complete(a)
    if not a or a.done then return false end
    a.done = true
    local st = world.state
    local reward = 0
    local okCfg, cfg = pcall(require, "core.config")
    if okCfg and cfg.BOUNTY_POOL then
        for _, def in ipairs(cfg.BOUNTY_POOL) do
            if def.id == a.id then reward = def.reward or 0; break end
        end
    end
    st.monedas = (st.monedas or 0) + reward
    local head = st.player and st.player.body and st.player.body[1]
    local okUi, ui = pcall(require, "ui.ui")
    if okUi and ui and head then
        pcall(function() ui.addPopup("+" .. reward .. "$ CONTRATO", head.x, head.y) end)
        pcall(function()
            ui.showToast({id = "bounty_" .. a.id, title = "CONTRATO CUMPLIDO", subtitle = a.id, reward = "+" .. reward .. "$"})
        end)
    end
    local okEv, Events = pcall(require, "core.events")
    if okEv and Events and Events.emit then
        pcall(function() Events.emit("bountyCompleted", {id = a.id, reward = reward}) end)
        pcall(function() Events.emit("coinsChanged", {totalCoins = st.monedas}) end)
    end
    if a.id == "rapido_furioso" then
        local okShop, shop = pcall(require, "systems.shop")
        if okShop and shop then shop.shieldActive = true end
        if okUi and ui and head then
            pcall(function() ui.addPopup("COFRE: ESCUDO", head.x, head.y) end)
        end
    end
    return true
end
function bounty.archive()
    local list = bounty.active()
    if #list == 0 then return 0 end
    local ok, persistence = pcall(require, "systems.persistence")
    if not ok or not persistence then return 0 end
    local p = persistence.getActiveProfile()
    if not p then return 0 end
    p.bounties = p.bounties or {active = {}, history = {}}
    p.bounties.history = p.bounties.history or {}
    local n = 0
    for _, a in ipairs(list) do
        if a.done then
            p.bounties.history[#p.bounties.history + 1] = {id = a.id, at = os.time()}
            n = n + 1
        end
    end
    persistence.saveProfiles()
    local okEv, Events = pcall(require, "core.events")
    if okEv and Events and Events.emit then
        pcall(function() Events.emit("bountiesDirty", {history = p.bounties.history}) end)
    end
    world.set("bounties", {active = {}, furiosoStreak = 0, constrictorKills = 0})
    return n
end
return bounty

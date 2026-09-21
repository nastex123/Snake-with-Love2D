local shrine = {}
local constants = require("constants")
local world = require("core.world")
function shrine.rank(id)
    local ok, persistence = pcall(require, "systems.persistence")
    if not ok or not persistence then return 0 end
    local p = persistence.getActiveProfile()
    if not p or type(p.talents) ~= "table" then return 0 end
    local v = p.talents[id]
    if type(v) ~= "number" or v < 0 then return 0 end
    return math.floor(v)
end
function shrine.magnetBase()
    return shrine.rank("residual_magnet")
end
function shrine.comboWindow()
    local okTarot, tarot = pcall(require, "systems.tarot")
    local base = 8.0
    if okTarot and tarot and tarot.comboWindow then base = tarot.comboWindow() end
    local r = shrine.rank("hunter_focus")
    if r > 0 then base = math.max(base, 8.0 + r * 1.0) end
    return base
end
function shrine.dragonBonus()
    local r = shrine.rank("dragon_stomach")
    if r >= 2 then return 2.0 end
    if r >= 1 then return 1.0 end
    return 0
end
function shrine.fireDuration()
    local okTarot, tarot = pcall(require, "systems.tarot")
    local base = 3.5
    if okTarot and tarot and tarot.fireBuffDuration then base = tarot.fireBuffDuration() end
    return base + shrine.dragonBonus()
end
function shrine.freezeDuration()
    local okTarot, tarot = pcall(require, "systems.tarot")
    local base = 2.5
    if okTarot and tarot and tarot.freezeDuration then base = tarot.freezeDuration() end
    return base + shrine.dragonBonus()
end
function shrine.buffDuration(dur, kind)
    local d = (dur or 0) + shrine.dragonBonus()
    if kind == "slow" and shrine.rank("thick_potions") > 0 then d = d + 1.5 end
    return d
end
function shrine.reviveCost()
    local base = constants.REVIVE_COIN_COST or 30
    local r = shrine.rank("mercy_pact")
    if r >= 2 then return math.max(0, base - 10) end
    if r >= 1 then return math.max(0, base - 5) end
    return base
end
function shrine.heritageCoins()
    local r = shrine.rank("heritage_pouch")
    if r >= 3 then return 15 end
    if r >= 2 then return 10 end
    if r >= 1 then return 5 end
    return 0
end
function shrine.consumeIronBody(st)
    st = st or world.state
    if shrine.rank("iron_body") == 0 then return false end
    if st.ironBodyUsed then return false end
    st.ironBodyUsed = true
    return true
end
function shrine.hasSixthSense()
    return shrine.rank("sixth_sense") > 0
end
return shrine

local modes = {}
local world = require("core.world")
modes.LIST = {"estandar", "endless", "rush", "pacifista"}
function modes.isUnlocked(id, profile)
    if id == "estandar" then return true end
    if not profile then return false end
    if id == "endless" then
        return (profile.stats and (profile.stats.endlessUnlocked or (profile.stats.highestStage or 1) > 5)) == true
    end
    if id == "rush" then
        return (profile.highScore or 0) >= 3000 or (profile.stats and (profile.stats.highestScore or 0) >= 3000)
    end
    if id == "pacifista" then
        if profile.achievements and profile.achievements.stage_3 then return true end
        return (profile.stats and (profile.stats.highestStage or 1) >= 3)
    end
    return false
end
function modes.current()
    return world.get("modo") or "estandar"
end
function modes.applyOnStart(st)
    st = st or world.state
    local m = st.modo or "estandar"
    st.runNoBomb = true
    st.runNoShield = true
    st.timeLimit = nil
    st.scoreMultiplier = 1
    if m == "rush" then
        local okCfg, cfg = pcall(require, "core.config")
        st.timeLimit = (okCfg and cfg.RUSH_TIME_LIMIT) or 180
        st.scoreMultiplier = 3
    end
    return m
end
function modes.scaleStage(n)
    n = math.max(6, n or 6)
    local k = n - 5
    return {
        biome = "vacio",
        name = "Abismo " .. n,
        wallWrap = false,
        spawnRate = 2.0 + k * 0.2,
        enemySpeed = 1.8 + k * 0.05,
        chaserWeight = 0.40,
        patrollerWeight = 0.25,
        spawnerWeight = 0.35,
        targetMult = 2.5 + k * 0.3,
        bossVida = 8,
        countMult = 2.0 + k * 0.2,
        hpMult = 2.2 + k * 0.2,
        objMult = 2.5 + k * 0.3,
        bossHP = 8,
    }
end
function modes.updateRush(dt)
    local st = world.state
    if (st.modo or "estandar") ~= "rush" then return false end
    if st.timeLimit == nil then return false end
    st.timeLimit = st.timeLimit - dt
    if st.timeLimit <= 0 then
        st.timeLimit = 0
        st.timeUp = true
        return true
    end
    return false
end
return modes
